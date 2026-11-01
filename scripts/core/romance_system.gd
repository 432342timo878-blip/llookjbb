class_name RomanceSystem
extends GameSystem
## A first relationship (GDD 4.10 decision 6, session P2b). GameSystem id "romance". Numbers and texts: data/romance.json.
##   - THE CARD: from age 15 a card may come on Sunday night (the planner shows it; never a stop, never a choice that waits for Play
##     week) with up to three people you know well enough. The PLAYER picks who the character is interested in (`choose`), or nobody
##     (`decline`). The answer comes the next Sunday night from the career's own dice, by closeness: a yes = together (`stage`
##     "dating"), a no = still friends, a small dip and a long quiet.
##   - TOGETHER: the activity "partner" fills Saturday / Sunday slots (HabitSystem); a week with a partner slot is time together
##     (closeness grows, the moods are pulled up, MindSystem.pulls -> mood_pulls), a week with none is neglect (a warning in week 2, they
##     end it in week 3). Late texting is a setting on their page (`texting`): "whenever" turns two school evenings a week into late
##     nights (HabitSystem.load_parts -> text_late), "off" does not.
##   - ENDING: you (the person's page) or them (neglect). A dip: the moods drop at once and the Sunday drift's targets are lowered for
##     two weeks (mood_pulls), recorded as causes. The person goes back to who they were.
## Nothing here uses saved dice: the answer is drawn from a generator seeded by the career and the person; the texting evenings are a
## hash of the career and the week. Off in `lab` (GameConfig "romance"): every fingerprint is identical there.

## GameConfig "romance" (off in `lab`).
static var enabled := false

var stage := ""             # "" (nothing) / "crush" (you picked someone; the answer comes on Sunday) / "dating"
var partner := ""           # person id of the crush / the sweetheart
var since := 0              # day number the stage began
var texting := "whenever"   # "whenever" / "off"
var neglect := 0            # weeks in a row without a partner slot while together
var warned := false         # they have said so (week `warn_weeks`)
var slots_week := 0         # partner slots played this week (the tally; Sunday night makes it `slots_last`)
var slots_last := 0
var offer := {}             # the card: {cands [person ids], day (the day number it came)} or {}
var quiet_until := 0        # day number: no card before it
var asked := {}             # person id -> day number they said no
var dip := {}               # a breakup's weight on the moods: {weeks (Sunday nights left), mode "them" / "you", name}
var history := []           # [{pid, from, to, by}]: the relationships that ended
var _nights := {}           # monday key -> the texting evenings of that week (a pure function of the career; not saved)


func _init() -> void:
	id = "romance"


static func cfg() -> Dictionary:
	return Data.romance


static func sys() -> RomanceSystem:
	return Game.get_system("romance") as RomanceSystem


## The relationship works: the option is on and the circle (the people) is.
static func active() -> bool:
	if not enabled or not CircleSystem.active():
		return false
	return sys() != null


func _ms() -> StoryletSystem:
	var c := CircleSystem.sys()
	return c._ms() if c != null else null


func _rng(what: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var a := Game.athlete
	var b := a.birth_date
	rng.seed = ("romance|%s|%s|%d-%d-%d" % [what, a.full_name(), int(b.get("year", 0)), int(b.get("month", 0)), int(b.get("day", 0))]).hash()
	return rng


static func _today() -> int:
	return StoryletSystem.day_no(Game.date)


# --- State -------------------------------------------------------------------------------------------------------------------------

## True when the character is together with someone now.
static func dating() -> bool:
	return active() and sys().stage == "dating"


## The sweetheart's (or the crush's) person dict, {} when none.
func partner_person() -> Dictionary:
	var ms := _ms()
	return ms.people.get(partner, {}) if ms != null and partner != "" else {}


## "single" / "crush" / "dating" / "ended" (a relationship ended in the last 56 days): the `romance` condition of storylets.
func state_now() -> String:
	if stage != "":
		return stage
	if not history.is_empty() and _today() - int(history.back().to) <= 56:
		return "ended"
	return "single"


## Whole weeks together (0 when not together).
func weeks_together() -> int:
	return maxi(0, floori((_today() - since) / 7.0)) if stage == "dating" else 0


## The partner activity can fill slot `i` (Monday = 0): only while together, on the slot days (Saturday, Sunday).
static func allows_partner(i: int) -> bool:
	return dating() and i in (cfg().dating.slot_days as Array).map(func(x): return int(x))


# --- Candidates and the card -------------------------------------------------------------------------------------------------------------

## The people the character could be interested in now, closest first: [person dicts].
func candidates() -> Array:
	var ms := _ms()
	var out := []
	if ms == null:
		return out
	var o: Dictionary = cfg().offer
	var circle := CircleSystem.sys()
	var today := _today()
	for p in ms.people.values():
		if not bool(p.get("active", false)) or bool(p.get("dating", false)):
			continue
		if circle.kind_of(p) not in o.kinds:
			continue
		if float(p.get("relation", 0.0)) < float(o.min_closeness):
			continue
		if today - int(asked.get(str(p.id), -100000)) < int(o.no_quiet_days):
			continue
		out.append(p)
	out.sort_custom(func(a, b):
		var ra := float(a.get("relation", 0.0))
		var rb := float(b.get("relation", 0.0))
		if ra != rb:
			return ra > rb
		return str(a.id) < str(b.id))
	return out


## The card now, if any: {cands [person dicts]} or {} (a person who stopped being around is left out).
func card() -> Dictionary:
	if not active() or offer.is_empty() or stage != "":
		return {}
	var ms := _ms()
	var cands := []
	for pid in offer.cands:
		var p: Dictionary = ms.people.get(str(pid), {})
		if not p.is_empty() and bool(p.get("active", false)):
			cands.append(p)
	return {"cands": cands} if not cands.is_empty() else {}


## Words for one candidate on the card: how close ("Fine" ... "Close") and what they are to you.
func candidate_line(p: Dictionary) -> String:
	return str(cfg().ui.card_line).format({"name": StoryletSystem.person_name(p), "word": str(p.get("word", "")),
			"close": Cast.relation_word(float(p.get("relation", 50.0)))})


## The chance that `p` likes you back (shown nowhere as a number: the card says only that closeness matters).
func chance_for(p: Dictionary) -> float:
	var a: Dictionary = cfg().answer
	return clampf(float(a.base) + (float(p.get("relation", 0.0)) - float(a.at)) * float(a.per_point), float(a.min), float(a.max))


## The player picks who they are interested in. The answer comes on Sunday night.
func choose(pid: String) -> bool:
	var ms := _ms()
	if not active() or stage != "" or ms == null or not ms.people.has(pid):
		return false
	stage = "crush"
	partner = pid
	since = _today()
	offer = {}
	ms.say("together", "system", str(cfg().texts.asked).format({"name": StoryletSystem.short_name(ms.people[pid])}))
	return true


## "Nobody right now": the card goes and stays away for a while.
func decline() -> void:
	offer = {}
	quiet_until = _today() + int(cfg().offer.decline_quiet_weeks) * 7


# --- The texting setting ---------------------------------------------------------------------------------------------------------------

func set_texting(option: String) -> bool:
	if not cfg().texting.options.has(option):
		return false
	texting = option
	HabitSystem.touch()
	return true


## True when the evening `idx` (weekday number: 0 = Monday, 6 = Sunday) of the week starting `monday` is a late-texting night: together,
## the setting is "whenever", and the evening is one of the week's `nights` picked by a hash of the career and the week. Not on an
## evening the caller says is taken (rest, friends, partner, an invitation): see HabitSystem.load_parts.
static func text_late(monday: Dictionary, idx: int) -> bool:
	if not dating():
		return false
	var s := sys()
	if s.texting != "whenever":
		return false
	return idx in s._week_nights(monday)


func _week_nights(monday: Dictionary) -> Array:
	var key := Calendar.date_key(monday)
	if _nights.has(key):
		return _nights[key]
	if _nights.size() > 120:
		_nights.clear()
	var t: Dictionary = cfg().texting
	var a := Game.athlete
	var scored := []
	for e in t.evenings:
		scored.append([("txt|%s|%d|%d" % [a.full_name(), key, int(e)]).hash(), int(e)])
	scored.sort()
	var out := []
	for i in mini(int(t.nights), scored.size()):
		out.append(scored[i][1])
	_nights[key] = out
	return out


# --- The week --------------------------------------------------------------------------------------------------------------------------

func on_day_end(ctx: Dictionary) -> void:
	if not active() or stage != "dating":
		return
	var hs := HabitSystem.sys()
	if hs != null and hs.activity_on(ctx.date) == "partner":
		slots_week += 1


## Sunday night: the crush's answer, time together or neglect, the breakup's weeks, and maybe a new card.
func on_week_end(_ctx: Dictionary) -> void:
	if not active():
		return
	var ms := _ms()
	if ms == null:
		return
	slots_last = slots_week
	slots_week = 0
	if not dip.is_empty():
		dip.weeks = int(dip.weeks) - 1   # (the mind has already used this Sunday's pull: it runs before this system)
		if int(dip.weeks) <= 0:
			dip = {}
	if stage == "crush":
		_answer(ms)
	elif stage == "dating":
		_together(ms)
	_roll_card(ms)


func _answer(ms: StoryletSystem) -> void:
	var p: Dictionary = ms.people.get(partner, {})
	if p.is_empty() or not bool(p.get("active", false)):   # (they are not around any more: nothing to answer)
		_clear()
		return
	var name := StoryletSystem.short_name(p)
	var rng := _rng("answer|%s|%d" % [partner, since])
	var yes := rng.randf() < chance_for(p)
	var t: Dictionary = cfg().texts
	if yes:
		stage = "dating"
		since = _today()
		neglect = 0
		warned = false
		p.dating = true
		p.word = str(cfg().words.together)
		var need := float(cfg().dating.start_min) - float(p.get("relation", 0.0))
		if need > 0.0:
			ms.add_relation(partner, need, {"kind": "romance", "note": str(t.start_relation).format({"name": name})})
		ms.say("together", partner, _pick(rng, t.yes))
		ms.say("together", "system", str(t.start_note).format({"name": name}))
		HabitSystem.touch()
	else:
		var a: Dictionary = cfg().answer
		var no: Dictionary = a.no
		asked[partner] = _today()
		quiet_until = maxi(quiet_until, _today() + int(cfg().offer.no_quiet_days))
		ms.add_relation(partner, float(no.relation), {"kind": "romance", "note": str(t.no_relation).format({"name": name})})
		_mood_now({"confidence": float(no.confidence), "motivation": float(no.motivation)}, str(t.mood_no).format({"name": name}))
		ms.say("together", partner, _pick(rng, t.no))
		ms.say("together", "system", str(t.no_note).format({"name": name}))
		_clear()


func _together(ms: StoryletSystem) -> void:
	var p: Dictionary = ms.people.get(partner, {})
	if p.is_empty():
		_clear()
		return
	var d: Dictionary = cfg().dating
	if slots_last > 0:
		neglect = 0
		warned = false
		return
	neglect += 1
	if neglect >= int(d.end_weeks):
		breakup("them")
	elif neglect >= int(d.warn_weeks) and not warned:
		warned = true
		ms.say("together", partner, _pick(_rng("warn|%d" % _today()), cfg().texts.warn))


static func _pick(rng: RandomNumberGenerator, list: Array) -> String:
	return str(list[rng.randi_range(0, list.size() - 1)])


func _clear() -> void:
	stage = ""
	partner = ""
	neglect = 0
	warned = false
	offer = {}


## The relationship ends: by "you" or "them". The person goes back to who they were; the moods drop and stay low for `weeks`.
func breakup(by: String) -> bool:
	var ms := _ms()
	if stage != "dating" or ms == null:
		return false
	var p: Dictionary = ms.people.get(partner, {})
	var name := StoryletSystem.short_name(p)
	var b: Dictionary = cfg().breakup[by]
	var t: Dictionary = cfg().texts
	if not p.is_empty():
		p.dating = false
		p.ex = _today()
		p.word = str(cfg().words.ex)
		ms.add_relation(partner, float(b.relation), {"kind": "romance", "note": str(t.ended_relation).format({"name": name})})
		if by == "them":
			ms.say("together", partner, _pick(_rng("ended|%d" % _today()), t.ended_them))
		else:
			ms.say("together", "system", str(t.ended_you).format({"name": name}))
			ms.say("together", partner, str(t.ended_you_reply))
	_mood_now(b.now, str(t.mood_now_them if by == "them" else t.mood_now_you).format({"name": name}))
	dip = {"weeks": int(cfg().breakup.weeks), "mode": by, "name": name}
	history.append({"pid": partner, "from": since, "to": _today(), "by": by})
	quiet_until = maxi(quiet_until, _today() + int(cfg().offer.after_breakup_days))
	var hs := HabitSystem.sys()
	if hs != null:
		hs.drop_partner()
	_clear()
	HabitSystem.touch()
	return true


## The player ends it (the person's page).
func end_it() -> bool:
	return breakup("you")


func _mood_now(deltas: Dictionary, text: String) -> void:
	var mind := MindSystem.sys()
	if mind == null:
		return
	for m in deltas:
		mind.add(str(m), float(deltas[m]), text)


## A new card on Sunday night: nothing going on, not quiet, the right age, someone close enough, a small chance a week.
func _roll_card(ms: StoryletSystem) -> void:
	var o: Dictionary = cfg().offer
	var today := _today()
	if not offer.is_empty() and today - int(offer.day) > int(o.weeks_open) * 7:
		offer = {}
	if stage != "" or not offer.is_empty() or today < quiet_until:
		return
	var age := Game.athlete.age_on(Game.date)
	if age < int(o.age_min):
		return
	var chances: Dictionary = o.chance
	var chance := float(chances.get(str(age), chances[chances.keys().back()]))
	var cands := candidates()
	if cands.is_empty():
		return
	if _rng("card|%d" % today).randf() >= chance:
		return
	offer = {"cands": cands.slice(0, int(o.max_candidates)).map(func(p): return str(p.id)), "day": today}


# --- Moods -----------------------------------------------------------------------------------------------------------------------------

## The pulls on a mood's target from the relationship (MindSystem.pulls): [{text, delta}] for the week starting `monday`.
func mood_pulls(mood: String, monday: Dictionary) -> Array:
	var out := []
	if not active():
		return out
	var t: Dictionary = cfg().texts
	if stage == "dating":
		var e: Dictionary = cfg().effects
		var hs := HabitSystem.sys()
		var n := int(HabitSystem.counts(hs.week_activities(monday)).get("partner", 0)) if hs != null else 0
		var name := StoryletSystem.short_name(partner_person())
		if mood == "motivation" and n > 0:
			out.append({"text": str(t.pull_slots).format({"name": name, "n": n}), "delta": float(mini(n, int(e.max_slots))) * float(e.motivation_per_slot)})
		elif mood == "confidence" and n > 0:
			out.append({"text": str(t.pull_together).format({"name": name}), "delta": float(e.confidence)})
	if not dip.is_empty() and int(dip.weeks) > 0:
		var pull: Dictionary = cfg().breakup[str(dip.mode)].pull
		if pull.has(mood):
			out.append({"text": str(t.pull_dip_them if str(dip.mode) == "them" else t.pull_dip_you), "delta": float(pull[mood])})
	return out


# --- For the screens ---------------------------------------------------------------------------------------------------------------------

## What the person page's TOGETHER box shows about person `pid`: {mode ("crush" / "dating" / "ex" / ""), weeks, slots_last, neglect}.
func box_of(pid: String) -> Dictionary:
	if stage != "" and partner == pid:
		return {"mode": stage, "weeks": weeks_together(), "slots_last": slots_last, "neglect": neglect}
	var ms := _ms()
	var p: Dictionary = ms.people.get(pid, {}) if ms != null else {}
	if int(p.get("ex", 0)) > 0:
		return {"mode": "ex", "weeks": 0, "slots_last": 0, "neglect": 0, "ex_day": int(p.ex)}
	return {}


# --- Save / load ---------------------------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := {}
	if stage != "":
		d.stage = stage
		d.partner = partner
		d.since = since
	if texting != "whenever":
		d.texting = texting
	if neglect > 0:
		d.neglect = neglect
	if warned:
		d.warned = true
	if slots_week > 0:
		d.slots_week = slots_week
	if slots_last > 0:
		d.slots_last = slots_last
	if not offer.is_empty():
		d.offer = offer
	if quiet_until > 0:
		d.quiet_until = quiet_until
	if not asked.is_empty():
		d.asked = asked
	if not dip.is_empty():
		d.dip = dip
	if not history.is_empty():
		d.history = history
	return d


func from_dict(d: Dictionary) -> void:
	stage = str(d.get("stage", ""))
	partner = str(d.get("partner", ""))
	since = int(d.get("since", 0))
	texting = str(d.get("texting", "whenever"))
	neglect = int(d.get("neglect", 0))
	warned = bool(d.get("warned", false))
	slots_week = int(d.get("slots_week", 0))
	slots_last = int(d.get("slots_last", 0))
	offer = d.get("offer", {})
	if not offer.is_empty():
		offer.day = int(offer.day)
	quiet_until = int(d.get("quiet_until", 0))
	asked = d.get("asked", {})
	for k in asked:
		asked[k] = int(asked[k])
	dip = d.get("dip", {})
	if not dip.is_empty():
		dip.weeks = int(dip.weeks)
	history = d.get("history", [])
	for h in history:
		h.from = int(h.from)
		h.to = int(h.to)
	_nights = {}
