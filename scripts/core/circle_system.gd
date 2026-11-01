class_name CircleSystem
extends GameSystem
## People as state plus shared time (GDD 4.10 decision 6, session P2a). GameSystem id "circle". The numbers are in data/circle.json.
##   - CLOSENESS is the `relation` 0-100 of StoryletSystem.people. Each Sunday night every person you know gets the week's shared
##     time: a free-time slot spent WITH them (HabitSystem's companion of the slot, or an invitation of theirs you went to), a friends
##     slot with nobody named (shared among your friends), a family slot (shared among the family), the group's days (a teammate).
##     Time grows closeness (slower the closer you are); too little time fades it. Family never fades.
##   - NEW PEOPLE come from places: a new class (the first when the career starts, the path's school after grade 9) brings a few
##     acquaintances (thread "circle"). An acquaintance becomes a friend at 50 and 3 slots spent; a friend who stays below 32 for
##     three weeks drifts back to an acquaintance; an acquaintance below 12 is gone.
##   - INVITATIONS: the third skip in a row and that person stops asking for a while (`quiet`).
##   - THE TRAINING GROUP: fixed days (the plan holds the group's session; WeekSim.is_group_day), a pull on the group days' HARD
##     sessions by the group's level against yours, and leaving it (train alone: free days, no pull, the teammates fade, the coach
##     sees less of you: his judgements get noisier).
## Recording only where it can be: every change of closeness has a cause in the person's log (kind "time" / "fade" / "group").
## The dice: new people are drawn from a generator seeded by the career's name and the place (no state to save); nothing else
## here uses dice. Off in `lab` (GameConfig "circle"): every fingerprint is identical there.

## GameConfig "circle" (off in `lab`).
static var enabled := false

var met := {}            # person id -> {at (place), since (day no), slots (slots spent with them in all), low (weeks below drift_below)}
var arrivals := {}       # place key -> day number the people of that place arrived
var in_group := true     # the player trains with the head coach's group
var group_coach := ""    # the coach whose group `group_shift` / `in_group` are about
var group_shift := 0.0   # how much the group's level has grown since it was made (data group.growth_per_week)
var skips := {}          # person id -> {n (invitations skipped in a row), quiet_until (day number; 0 = not quiet)}
var tally := {}          # the week so far: {named {pid: slots}, crowd_friends, crowd_family, group_days}
var last_week := {}      # person id -> {slots, gain, fade} of the last Sunday night (the person page, the causes)
var left_day := -1       # day number the player left the group (-1 = in it)


func _init() -> void:
	id = "circle"
	_reset_tally()


static func cfg() -> Dictionary:
	return Data.circle


static func sys() -> CircleSystem:
	return Game.get_system("circle") as CircleSystem


## The circle works: the option is on, the career has its systems and the people are made (StoryletSystem.people_enabled).
static func active() -> bool:
	if not enabled or Game.athlete == null:
		return false
	var s := sys()
	return s != null and StoryletSystem.people_enabled and s._ms() != null


func _ms() -> StoryletSystem:
	var ms := Game.get_system("moments") as StoryletSystem
	return ms if ms != null and ms.active() else null


func _reset_tally() -> void:
	tally = {"named": {}, "crowd_friends": 0, "crowd_family": 0, "group_days": 0}


# --- Kinds ---------------------------------------------------------------------------------------------------------------------

## What kind of person this is for shared time: best_friend / friend / acquaintance / teammate / former / family, "" for the
## rest (teachers, rivals, the coach: their closeness is not about free evenings).
func kind_of(p: Dictionary) -> String:
	if not bool(p.get("active", false)):
		return ""
	match str(p.get("role", "")):
		"best_friend", "friend", "acquaintance":
			return str(p.role)
		"mum", "dad", "sibling":
			return "family"
	if str(p.get("thread", "")) == "group":
		return "teammate" if in_group else "former"
	return ""


## Who the player can meet in a free-time slot (friends first, then acquaintances, by closeness; teammates after): person dicts.
func meetable() -> Array:
	var ms := _ms()
	var out := []
	if ms == null:
		return out
	for p in ms.people.values():
		var k := kind_of(p)
		if k in ["best_friend", "friend", "acquaintance", "teammate", "former"]:
			out.append(p)
	var order := {"best_friend": 0, "friend": 1, "acquaintance": 2, "teammate": 3, "former": 4}
	out.sort_custom(func(a, b):
		var ka := int(order[kind_of(a)])
		var kb := int(order[kind_of(b)])
		if ka != kb:
			return ka < kb
		return str(a.id) < str(b.id))
	return out


# --- New people ------------------------------------------------------------------------------------------------------------------

func _rng(what: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var a := Game.athlete
	var b := a.birth_date
	rng.seed = ("circle|%s|%s|%d-%d-%d" % [what, a.full_name(), int(b.get("year", 0)), int(b.get("month", 0)), int(b.get("day", 0))]).hash()
	return rng


## The place key of the school stage the athlete is in now ("" = no school now): "comp" for grades 8-9, else the path's school.
func _class_key() -> String:
	var ss := SchoolSystem.sys()
	if ss == null:
		return ""
	var stage := ss.stage_of(Game.date)
	if not bool(stage.get("subjects", false)):
		return ""
	if str(stage.id) in ["grade_8", "grade_9"]:
		return "comp"
	var path := ss.current_path()
	return "%s_%d" % [str(path.get("school", "")) if str(path.get("school", "")) != "" else str(path.get("kind", "sec")), int(path.get("start_year", 0))]


## A new class brings its faces once. `key` = the place. Returns the new people (empty when the class had come already).
func arrive_class(key: String) -> Array:
	var ms := _ms()
	if ms == null or key == "" or arrivals.has("class." + key):
		return []
	var c: Dictionary = cfg().places.classmates
	var rng := _rng("class|" + key)
	var n := rng.randi_range(int(c.count[0]), int(c.count[1]))
	var a := Game.athlete
	var used := {}
	for p in ms.people.values():
		used[str(p.get("first_name", ""))] = true
	var out := []
	for i in n:
		var g := a.gender if rng.randf() < 0.5 else ("female" if a.gender == "male" else "male")
		var p := {"id": "cl.%s.%d" % [key, i + 1], "thread": "circle", "role": "acquaintance", "first_name": "", "last_name": "", "gender": g,
				"birth_year": int(a.birth_date.get("year", 2012)), "word": str(c.met), "relation": float(cfg().status.acquaintance_start),
				"active": true, "memory": {}}
		for _try in 40:
			var first := str(Data.names[g][rng.randi_range(0, Data.names[g].size() - 1)])
			if not used.has(first):
				p.first_name = first
				used[first] = true
				break
		if str(p.first_name) == "":
			p.first_name = str(Data.names[g][rng.randi_range(0, Data.names[g].size() - 1)])
		p.last_name = str(Data.names.surnames[rng.randi_range(0, Data.names.surnames.size() - 1)])
		p.trait = Cast._weighted(rng, c.traits)
		ms.people[p.id] = p
		met[p.id] = {"at": "class." + key, "since": StoryletSystem.day_no(Game.date), "slots": 0, "low": 0}
		out.append(p)
	arrivals["class." + key] = StoryletSystem.day_no(Game.date)
	var names: Array = out.map(func(q): return str(q.first_name))
	var text := str(c.arrival if key == "comp" else cfg().places.class_secondary).format({"names": ", ".join(names)})
	ms.say("circle", "system", text)
	return out


# --- The week --------------------------------------------------------------------------------------------------------------------

func on_week_start(_w: WeekSim) -> void:
	if not active():
		return
	arrive_class(_class_key())
	_follow_group()


## A new head coach has a new group.
func _follow_group() -> void:
	var cs := Game.get_system("coach") as CoachSystem
	var head: Dictionary = cs.head() if cs != null else {}
	var cid := str(head.get("id", ""))
	if cid != group_coach:
		group_coach = cid
		group_shift = 0.0
		in_group = true
		left_day = -1


func on_day_end(ctx: Dictionary) -> void:
	if not active():
		return
	var hs := HabitSystem.sys()
	if hs == null:
		return
	var act := hs.activity_on(ctx.date)
	var inv := HabitSystem.invitation_on(ctx.date)
	var with := hs.companion_on(ctx.date)
	var named: Dictionary = tally.named
	if not inv.is_empty() and HabitSystem.going(inv):
		var who := str(inv.get("from", ""))
		if who != "":
			named[who] = float(named.get(who, 0.0)) + 1.0
	elif act == "friends":
		if with != "":
			named[with] = float(named.get(with, 0.0)) + 1.0
		else:
			tally.crowd_friends = int(tally.crowd_friends) + 1
	elif act == "family":
		if with != "":
			named[with] = float(named.get(with, 0.0)) + 1.0
		else:
			tally.crowd_family = int(tally.crowd_family) + 1
	var g := group_day(Calendar.weekday(ctx.date))
	if in_group and has_group() and not g.is_empty():
		var rec: Dictionary = ctx.get("record", {})
		if str(g.session) in rec.get("sessions", []):
			tally.group_days = int(tally.group_days) + 1


## Sunday night: the week's shared time becomes closeness (gain) and the lack of it fades (fade); statuses follow.
func on_week_end(_ctx: Dictionary) -> void:
	if not active():
		return
	var ms := _ms()
	var t: Dictionary = cfg().time
	var friends := ms.people.values().filter(func(p): return kind_of(p) in ["best_friend", "friend"])
	var family := ms.people.values().filter(func(p): return kind_of(p) == "family")
	var crowd_f := float(tally.crowd_friends) / maxi(friends.size(), 1) if not friends.is_empty() else 0.0
	var crowd_m := float(tally.crowd_family) / maxi(family.size(), 1) if not family.is_empty() else 0.0
	var group_days := int(tally.group_days)
	last_week = {}
	for pid in ms.people.keys():
		var p: Dictionary = ms.people[pid]
		var k := kind_of(p)
		if k == "":
			continue
		var rel := float(p.get("relation", 50.0))
		var slots := float(tally.named.get(pid, 0.0))
		var gain := 0.0
		var fade := 0.0
		match k:
			"family":
				slots += crowd_m
				gain = slots * float(t.family_gain_per_slot) * (1.0 - rel / 100.0)
			"best_friend", "friend":
				slots += crowd_f
				gain = slots * float(t.gain_per_slot) * (1.0 - rel / 100.0)
			"acquaintance", "former":
				gain = slots * float(t.gain_per_slot) * (1.0 - rel / 100.0)
			"teammate":
				gain = slots * float(t.gain_per_slot) * (1.0 - rel / 100.0)
				gain += group_days * float(t.group_gain_per_day) * (1.0 - rel / 100.0) * (1.5 if bool(p.get("close", false)) else 1.0)
				slots += group_days * 0.5
		var need := float(t.need.get(k, 0.0))
		if need > 0.0 and slots < need:
			fade = float(t.fade_per_week) * float(t.fade_factor.get(k, 1.0)) * (1.0 - slots / need)
		var delta := gain - fade
		if k == "best_friend":
			delta = maxf(delta, float(cfg().status.best_floor) - rel) if rel + delta < float(cfg().status.best_floor) else delta
		if absf(delta) >= 0.005:
			ms.add_relation(str(pid), delta, {"kind": "time" if gain >= fade else "fade", "slots": slots, "group_days": group_days if k == "teammate" else 0})
		if pid in met:
			met[pid].slots = int(met[pid].slots) + roundi(float(tally.named.get(pid, 0.0)))
		last_week[pid] = {"slots": slots, "gain": gain, "fade": fade}
	_statuses(ms)
	if has_group():
		group_shift += float(cfg().group.growth_per_week)
	_reset_tally()


## Acquaintances become friends, friends drift, acquaintances go.
func _statuses(ms: StoryletSystem) -> void:
	var st: Dictionary = cfg().status
	var ui: Dictionary = cfg().ui
	for pid in ms.people.keys():
		var p: Dictionary = ms.people[pid]
		if not bool(p.get("active", false)):
			continue
		var rel := float(p.get("relation", 0.0))
		var role := str(p.get("role", ""))
		var m: Dictionary = met.get(pid, {"at": "", "since": 0, "slots": 0, "low": 0})
		if role == "acquaintance":
			if rel >= float(st.friend_at) and int(m.slots) >= int(st.min_slots):
				p.role = "friend"
				p.thread = "friends"
				p.word = str(Data.cast.friends.word)
				m.low = 0
				ms.say("friends", "system", str(ui.become_friend).format({"name": StoryletSystem.short_name(p)}))
			elif rel < float(st.gone_below) and str(p.thread) == "circle":
				p.active = false
				p.gone = true
				ms.say("circle", "system", str(ui.gone_note).format({"name": StoryletSystem.short_name(p)}))
		elif role == "friend":
			if rel < float(st.drift_below):
				m.low = int(m.low) + 1
				if int(m.low) >= int(st.drift_weeks):
					p.role = "acquaintance"
					p.thread = "circle"
					p.word = str(cfg().places.classmates.met)
					m.low = 0
					ms.say("circle", "system", str(ui.drift_note).format({"name": StoryletSystem.short_name(p)}))
			else:
				m.low = 0
		if role in ["friend", "acquaintance"] or met.has(pid):
			met[pid] = m   # (the weeks a friend has been below the line are kept between Sundays)


# --- Invitations: the third skip ---------------------------------------------------------------------------------------------------

## An invitation was settled on its evening: `went` = the player went. The third skip in a row and the sender stops asking.
func on_invite_settled(m: Dictionary, went: bool) -> void:
	if not active():
		return
	var pid := str(m.get("from", ""))
	var ms := _ms()
	if pid == "" or not ms.people.has(pid) or kind_of(ms.people[pid]) not in ["best_friend", "friend", "acquaintance"]:
		return
	var s: Dictionary = skips.get(pid, {"n": 0, "quiet_until": 0})
	if went:
		s.n = 0
		s.quiet_until = 0
	else:
		s.n = int(s.n) + 1
		var iv: Dictionary = cfg().invites
		if int(s.n) >= int(iv.skips):
			s.n = 0
			s.quiet_until = StoryletSystem.day_no(Game.date) + int(iv.quiet_days)
			var p: Dictionary = ms.people[pid]
			var them := "her" if str(p.get("gender", "")) == "female" else "him"
			ms.say("friends" if str(p.thread) == "friends" else "circle", pid, str(iv.message).format({"name": StoryletSystem.short_name(p), "them": them}))
	skips[pid] = s


## This person has stopped asking for now (StoryletSystem._senders reads it).
func quiet(pid: String) -> bool:
	return int(skips.get(pid, {}).get("quiet_until", 0)) > StoryletSystem.day_no(Game.date)


static func is_quiet(pid: String) -> bool:
	var s := sys()
	return s != null and active() and s.quiet(pid)


# --- The training group -----------------------------------------------------------------------------------------------------------

func _head() -> Dictionary:
	var cs := Game.get_system("coach") as CoachSystem
	return cs.head() if cs != null else {}


## The head coach has a group you know of (real coaches' groups are not known: empty).
func has_group() -> bool:
	return not (_head().get("group", []) as Array).is_empty()


## The group's fixed session for weekday `wd`: {session, intensity} or {} (no group, you left it, or not a group day).
func group_day(wd: int) -> Dictionary:
	if not has_group():
		return {}
	for g in cfg().group.days:
		if int(g.day) == wd:
			return g
	return {}


## The group's mean level now (the teammates' level plus its growth).
func group_level() -> float:
	var members: Array = _head().get("group", [])
	if members.is_empty():
		return 0.0
	var sum := 0.0
	for t in members:
		sum += float(t.level)
	return sum / members.size() + group_shift


## The size factor of the pull (a group of size_ref counts fully).
func size_factor() -> float:
	var p: Dictionary = cfg().group.pull
	var n := float((_head().get("group", []) as Array).size())
	return clampf(n / float(p.size_ref), float(p.size_min), float(p.size_max))


## The group's effect on a hard session as a fraction (+0.03 = 3 % better), 0.0 when there is no pull.
func pull() -> float:
	if not has_group():
		return 0.0
	var p: Dictionary = cfg().group.pull
	var gap := group_level() - CoachSystem.athlete_level(Game.athlete)
	var x := clampf(gap * float(p.per_point), -float(p.max_down), float(p.max_up)) * size_factor()
	return clampf(x, -float(p.max_down), float(p.max_up))


## The word for the group's level against yours.
func level_word() -> String:
	var gap := group_level() - CoachSystem.athlete_level(Game.athlete)
	var w: Dictionary = cfg().group.words
	if gap >= 2.0:
		return str(w.much_stronger)
	if gap >= 0.7:
		return str(w.stronger)
	if gap > -0.7:
		return str(w.level)
	if gap > -2.0:
		return str(w.weaker)
	return str(w.much_weaker)


## What WeekSim asks: the multiplier of a hard group session's effect (exactly 1.0 when the circle is off or you are not in the group).
static func pull_mult() -> float:
	if not active():
		return 1.0
	var s := sys()
	if not s.in_group or not s.has_group():
		return 1.0
	return 1.0 + s.pull()


## True when the plan holds the group's fixed session on weekday `wd` (WeekSim.is_group_day): you are in the group, it trains that day
## and the day is not a race day or the day before / after one (the race calendar wins over the group).
static func fixed_day(wd: int, races := {}) -> bool:
	if not active():
		return false
	var s := sys()
	return s.in_group and not s.group_day(wd).is_empty() and not races.has(wd) and not races.has(wd + 1) and not races.has(wd - 1)


## WeekSim: puts the group's fixed sessions into a week's plan (copies the arrays first; races keep their day).
static func overlay(days: Array, intensity: Array, races: Dictionary) -> Array:
	if not active():
		return [days, intensity]
	var s := sys()
	if not s.in_group or not s.has_group():
		return [days, intensity]
	var out_days := days
	var out_int := intensity
	var copied := false
	for g in cfg().group.days:
		var d := int(g.day)
		if not fixed_day(d, races):
			continue
		if not copied:
			out_days = days.duplicate(true)
			out_int = intensity.duplicate()
			copied = true
		out_days[d] = [str(g.session)]
		# (a day the season plan made easy, e.g. in a taper, stays easy: the group's session is done lightly)
		out_int[d] = "easy" if str(intensity[d]) == "easy" else str(g.intensity)
	return [out_days, out_int]


## Leave the group (train alone).
func leave_group() -> bool:
	if not in_group or not has_group():
		return false
	in_group = false
	left_day = StoryletSystem.day_no(Game.date)
	HabitSystem.touch()
	return true


func join_group() -> bool:
	if in_group or not has_group():
		return false
	in_group = true
	left_day = -1
	HabitSystem.touch()
	return true


## Training alone makes the coach's judgements noisier: 1.0 in the group (and when the circle is off).
static func alone_factor() -> float:
	if not active():
		return 1.0
	var s := sys()
	if s.in_group or not s.has_group():
		return 1.0
	return float(cfg().group.alone.noise_mult)


## What the person page / group card needs of the group: {has, in, coach, size, level, mine, word, pull, days [{name, session}], members}.
func group_info() -> Dictionary:
	var head := _head()
	var members: Array = head.get("group", [])
	var days := []
	for g in cfg().group.days:
		days.append({"day": int(g.day), "name": Training.DAY_NAMES[int(g.day)], "session": str(Data.get_session(str(g.session)).get("name", g.session))})
	return {"has": not members.is_empty(), "in": in_group, "coach": str(head.get("name", "")).split(" ")[0], "size": members.size(),
			"level": group_level(), "mine": CoachSystem.athlete_level(Game.athlete), "word": level_word(), "pull": pull(), "days": days}


# --- A person ------------------------------------------------------------------------------------------------------------------------

## What the person page shows about person `p` (read only): {kind, close, word, need, slots_last, gain_last, fade_last, gives [], costs [], met}.
func page_of(p: Dictionary) -> Dictionary:
	var k := kind_of(p)
	var c: Dictionary = cfg()
	var rel := float(p.get("relation", 50.0))
	var them := "her" if str(p.get("gender", "")) == "female" else "him"
	var they := "she" if str(p.get("gender", "")) == "female" else "he"
	var their := "her" if str(p.get("gender", "")) == "female" else "his"
	var fill := {"name": StoryletSystem.short_name(p), "need": "a slot", "them": them, "they": they, "their": their}
	var gives: Array = []
	var role := str(p.get("role", ""))
	for key in [role, k]:
		if c.gives.has(key) and gives.is_empty():
			for line in c.gives[key]:
				gives.append(str(line).format(fill))
	var costs: Array = []
	var need := float(c.time.need.get(k, 0.0))
	if k == "family":
		costs.append(str(c.gives.costs.time_family).format(fill))
	elif need > 0.0:
		fill.need = str(c.gives.costs.need_1 if need >= 1.0 else (c.gives.costs.need_half if need <= 0.5 else c.gives.costs.need_most))
		costs.append(str(c.gives.costs.time).format(fill))
	if str(p.get("trait", "")) == "partygoer":
		costs.append(str(c.gives.costs.partygoer).format(fill))
	if k == "acquaintance":
		costs.append(str(c.gives.costs.none_acq).format(fill))
	var lw: Dictionary = last_week.get(str(p.get("id", "")), {})
	return {"kind": k, "rel": rel, "word": Cast.relation_word(rel), "gives": gives, "costs": costs, "last": lw,
			"met": met.get(str(p.get("id", "")), {}), "slots_total": int(met.get(str(p.get("id", "")), {}).get("slots", 0)),
			"quiet": quiet(str(p.get("id", ""))), "to_friend": maxi(0, int(c.status.min_slots) - int(met.get(str(p.get("id", "")), {}).get("slots", 0)))}


# --- Save / load -------------------------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := {}
	if not met.is_empty():
		d.met = met
	if not arrivals.is_empty():
		d.arrivals = arrivals
	if not in_group:
		d.in_group = false
	if group_coach != "":
		d.group_coach = group_coach
	if group_shift != 0.0:
		d.group_shift = group_shift
	if not skips.is_empty():
		d.skips = skips
	if left_day >= 0:
		d.left_day = left_day
	if not (tally.named.is_empty() and int(tally.crowd_friends) == 0 and int(tally.crowd_family) == 0 and int(tally.group_days) == 0):
		d.tally = tally
	if not last_week.is_empty():
		d.last_week = last_week
	return d


func from_dict(d: Dictionary) -> void:
	met = d.get("met", {})
	for m in met.values():
		m.since = int(m.since)
		m.slots = int(m.slots)
		m.low = int(m.low)
	arrivals = d.get("arrivals", {})
	for k in arrivals:
		arrivals[k] = int(arrivals[k])
	in_group = bool(d.get("in_group", true))
	group_coach = str(d.get("group_coach", ""))
	group_shift = float(d.get("group_shift", 0.0))
	skips = d.get("skips", {})
	for s in skips.values():
		s.n = int(s.n)
		s.quiet_until = int(s.quiet_until)
	left_day = int(d.get("left_day", -1))
	_reset_tally()
	if d.has("tally"):
		var t: Dictionary = d.tally
		tally.named = t.get("named", {})
		tally.crowd_friends = int(t.get("crowd_friends", 0))
		tally.crowd_family = int(t.get("crowd_family", 0))
		tally.group_days = int(t.get("group_days", 0))
	last_week = d.get("last_week", {})
