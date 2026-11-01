class_name CareerSystem
extends GameSystem
## The career's history (GDD 4.10 decision 10, session K1a): the timeline of milestones, the reputation and the season-list log. GameSystem
## id "career", last but one in Game.systems (it only READS what the others did and RECORDS it; it changes nothing in the game itself).
##
## - Every race day the new results (`seen` counts the ones already looked at) are turned into: milestones (first race, first win, first
##   under a round time, a real standard reached, the Finnish record, ...) and a REPUTATION EVENT (the points of the race with the parts
##   that made them: data/reputation.json). The score is the points of the last `window_days`, fading linearly.
## - Each day the other systems' state is looked at: the head coach, the school path, the town, the healed injuries, the goals met.
## - At the end of every month the player's place on the season list is logged (the rankings history).
## An older save (no state here) is REBUILT from what the game really holds: the results (all of the timeline's race kinds and the
## reputation), the healed injuries, the goals met; what the game never recorded (earlier coach changes, moves) starts at `since`.
## No dice. The effects of the reputation (the coach market, the broadcast, the coach's bigger-meet suggestions) are on only with
## `effects_enabled` (GameConfig "reputation": real = on, lab = off, so the fingerprints stay identical).

static var effects_enabled := false

var seen := 0                    # athlete.results already looked at
var milestones: Array = []       # [{id, kind, date, title, text, icon, meet?, card?}] oldest first
var rep_events: Array = []       # [{day, date, kind ("race" / "standard" / "record"), meet, key, points, parts [{text, value}]}]
var rank_log: Array = []         # [{year, month, rank, of, time}] the player's place on the season list at each month's end
var found := {}                  # milestone key -> true (so it is found once)
var reviews := {}                # (K1b) season year -> the season review's snapshot (SeasonReview.build), kept for Career -> Seasons
var since: Dictionary = {}       # {} for a career recorded from the start; else the date this save was first looked at
var last := {"coach": "", "path": "", "town": "", "step": -1}
var _legacy := false             # (not saved) the state was empty when loaded: after_load() rebuilds it


func _init() -> void:
	id = "career"


static func sys() -> CareerSystem:
	return Game.get_system("career") as CareerSystem


static func rcfg() -> Dictionary:
	return Data.reputation


static func ccfg() -> Dictionary:
	return Data.career


# --- The day loop --------------------------------------------------------------------------------------------------------------

## A new career: the coach is the first thing on the timeline.
func begin() -> void:
	if Game.athlete == null:
		return
	last.coach = Game.athlete.coach_id
	last.step = 0
	_coach_milestone("", Game.date)


func on_day_end(ctx: Dictionary) -> void:
	if Game.athlete == null:
		return
	var date: Dictionary = ctx.date
	_process_results()
	_poll(date)
	_month_end(date)
	_close_season(date)


## The last night of a training season (31 Oct): the season review's snapshot (the goals closed on the same night, before this system).
func _close_season(date: Dictionary) -> void:
	var year := SeasonPlan.year_of(date)
	if SeasonPlan.year_of(Game.add_days(date, 1)) == year or reviews.has(year):
		return
	reviews[year] = SeasonReview.build(year, self, date)


## The review waiting for the player: the latest not read yet and still within its weeks ({} = none). It is a strap on This week, never
## a stop and never a choice waiting.
func due_review() -> Dictionary:
	var best := {}
	for y in reviews:
		var r: Dictionary = reviews[y]
		if not bool(r.seen) and Calendar.date_key(Game.date) <= int(r["until"]) and Calendar.date_key(Game.date) > Calendar.date_key(r.date):
			if best.is_empty() or int(y) > int(best.year):
				best = r
	return best


func mark_seen(year: int) -> void:
	if reviews.has(year):
		reviews[year].seen = true


## The reviews, newest season first.
func review_list() -> Array:
	var out := []
	for y in reviews:
		out.append(reviews[y])
	out.sort_custom(func(x, y): return int(x.year) > int(y.year))
	return out


# --- Results -> milestones and reputation -------------------------------------------------------------------------------------

func _process_results() -> void:
	var results: Array = Game.athlete.results
	while seen < results.size():
		var first: Dictionary = results[seen]
		var j := seen + 1
		while j < results.size() and str(results[j].meet_key) == str(first.meet_key) \
				and Calendar.date_key(Game.int_date(results[j].date)) == Calendar.date_key(Game.int_date(first.date)):
			j += 1
		_race(results.slice(seen, j))
		seen = j


## One meet day: `group` = the player's results of its rounds, in order.
func _race(group: Array) -> void:
	var a := Game.athlete
	var final_r: Dictionary = group.back()
	var date := Game.int_date(final_r.date)
	var meet := Calendar.get_meet(str(final_r.meet_key))
	var level := str(meet.get("level", "local"))
	var main: bool = str(final_r.get("event", "")) == a.main_event
	var ok: bool = str(final_r.get("status", "")) == ""
	var best := 0.0
	var any_pb := false
	for r in group:
		if str(r.get("status", "")) == "" and float(r.time) > 0.0:
			if best <= 0.0 or float(r.time) < best:
				best = float(r.time)
			if bool(r.get("pb", false)):
				any_pb = true
	var is_final: bool = not (str(final_r.get("round", "Race")).begins_with("Heat") or str(final_r.get("round", "Race")).begins_with("Semi"))
	var place := int(final_r.get("place", 0))
	var field := int(final_r.get("field", 0))
	var fill := {"meet": str(final_r.meet), "result": Race.result_text(final_r, " in "), "time": Calendar.format_time(best) if best > 0.0 else ""}
	var card := "%d_%s" % [Calendar.date_key(date), str(final_r.meet_key)]
	var extra := {"meet": str(final_r.meet_key), "card": card}
	var first_race: bool = not found.has("first_race")
	if first_race:
		_add("first_race", "first_race", date, fill, extra)
	if ok and main and is_final and place > 0:
		var half := ceili(field / 2.0)
		if place == 1 and field >= 4:
			_add("first_win", "first_win", date, fill, extra)
			found["first_medal"] = true
		elif place <= 3 and field >= 4:
			_add("first_medal", "first_medal", date, fill, extra)
		if level in ccfg().milestones.national_levels and place <= 8 and place <= half and field >= 6:
			_add("first_scoring", "first_scoring", date, fill, extra)
		if str(meet.get("id", "")) in ccfg().milestones.championship_ids:
			_add("first_nationals", "first_nationals", date, fill, extra)
	if ok and main and best > 0.0:
		_round_time(best, date, fill, extra, first_race)
		_standards(best, date, meet, fill, extra)
		_records(best, date, meet, fill, extra)
	_comeback(date, fill, extra)
	# the reputation event of the race
	if ok and main and place > 0:
		_race_points(final_r, date, meet, level, is_final, any_pb, place, field)
	_check_step(date)


## Points of one race with the parts that made them (data/reputation.json).
func _race_points(r: Dictionary, date: Dictionary, meet: Dictionary, level: String, is_final: bool, any_pb: bool, place: int, field: int) -> void:
	var c := rcfg()
	var texts: Dictionary = c.texts.parts
	var lw := float(c.level_weight.get(level, 1.0))
	var pf := float(c.place.rest)
	if is_final:
		var half := ceili(field / 2.0)
		if place == 1:
			pf = float(c.place.win)
		elif place <= 3:
			pf = float(c.place.medal)
		elif place <= 8 and place <= half:
			pf = float(c.place.scoring)
		elif place <= half:
			pf = float(c.place.half)
	var age := Game.athlete.age_on(date)
	var am := 1.0
	for row in c.age:
		if age >= int(row[0]):
			am = float(row[1])
	var pts := lw * pf * am
	var parts := [
		{"text": str(texts.level).format({"level": str(Data.competitions.levels.get(level, level))}), "value": "×%s" % _num(lw)},
		{"text": str(texts.place).format({"place": Race._ordinal(place), "field": field}), "value": "×%s" % _num(pf)},
		{"text": str(texts.age).format({"age": age}), "value": "×%s" % _num(am)},
	]
	if any_pb:
		var bonus := float(c.pb_share) * lw
		pts += bonus
		parts.append({"text": str(texts.pb), "value": "+%s" % _num(bonus)})
	_event("race", date, str(r.meet), str(r.meet_key), pts, parts)


func _event(kind: String, date: Dictionary, meet_name: String, key: String, points: float, parts: Array) -> void:
	rep_events.append({"day": StoryletSystem.day_no(date), "date": date.duplicate(), "kind": kind, "meet": meet_name, "key": key,
			"points": snappedf(points, 0.01), "parts": parts})


static func _num(x: float) -> String:
	return ("%.2f" % x).rstrip("0").rstrip(".")


## The fastest round time newly passed (the slower ones are marked found without a line; the first race of the career shows none).
func _round_time(best: float, date: Dictionary, fill: Dictionary, extra: Dictionary, first_race: bool) -> void:
	var ladder: Array = ccfg().round_times["male" if Game.athlete.gender == "male" else "female"]
	var fastest := -1.0
	for t in ladder:
		if best < float(t) and not found.has("round:%d" % int(t)):
			if fastest < 0.0 or float(t) < fastest:
				fastest = float(t)
			if first_race:
				found["round:%d" % int(t)] = true
	if fastest > 0.0 and not first_race:
		var f := fill.duplicate()
		f.round = _round_text(fastest)
		for t in ladder:
			if best < float(t):
				found["round:%d" % int(t)] = true
		found.erase("round:%d" % int(fastest))
		_add("round:%d" % int(fastest), "round_time", date, f, extra)


static func _round_text(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]


## A real limit met for the first time (data/standards.json) and the reputation points for it.
func _standards(best: float, date: Dictionary, meet: Dictionary, fill: Dictionary, extra: Dictionary) -> void:
	for sid in Standards.ids():
		var key := "std:" + str(sid)
		if found.has(key):
			continue
		var limit := Standards.time(str(sid), Game.athlete, int(date.year))
		if limit <= 0.0 or best > limit:
			continue
		var set := Standards.set_of(str(sid))
		var f := fill.duplicate()
		f.name = str(set.name)
		f.limit = Calendar.format_time(limit)
		_add(key, "standard", date, f, extra)
		var pts := float(rcfg().standard_points.get(sid, 0.0))
		if pts > 0.0:
			_event("standard", date, str(fill.meet), str(extra.meet), pts, [{"text": str(rcfg().texts.parts.standard).format({"name": str(set.short)}), "value": "+%s" % _num(pts)}])


## The Finnish record of the athlete's class (data/career.json records): within 3 % and under, once each.
func _records(best: float, date: Dictionary, meet: Dictionary, fill: Dictionary, extra: Dictionary) -> void:
	var a := Game.athlete
	var age := a.age_on(date)
	for row in ccfg().records.rows:
		if str(row.gender) != a.gender or bool(row.indoor) != bool(meet.get("indoor", false)):
			continue
		if age < int(row.min_age) or (row.has("max_age") and age > int(row.max_age)):
			continue
		var rec := float(row.time)
		var kind := ""
		if best <= rec:
			kind = "record_under"
		elif best <= rec * (1.0 + float(rcfg().record_near)):
			kind = "record_near"
		if kind == "" or found.has("%s:%s" % [kind, row.id]):
			continue
		if kind == "record_under":
			found["record_near:%s" % row.id] = true
		var f := fill.duplicate()
		f["class"] = str(row["class"])
		f.record = Calendar.format_time(rec)
		_add("%s:%s" % [kind, row.id], kind, date, f, extra)
		var pts := float(rcfg().record_points["under" if kind == "record_under" else "near"])
		_event("record", date, str(fill.meet), str(extra.meet), pts, [{"text": str(rcfg().texts.parts.record).format({"kind": "Within 3 % of" if kind == "record_near" else "Faster than", "class": str(row["class"])}), "value": "+%s" % _num(pts)}])


## The first race after a long injury healed.
func _comeback(date: Dictionary, fill: Dictionary, extra: Dictionary) -> void:
	for m in milestones:
		if str(m.kind) == "injury" and not found.has("comeback:" + str(m.id)) and Calendar.date_key(date) > Calendar.date_key(m.date):
			found["comeback:" + str(m.id)] = true
			var f := fill.duplicate()
			f.injury = str(m.get("name", "injury")).to_lower()
			_add("comeback:" + str(m.id), "comeback", date, f, extra)


# --- The reputation ---------------------------------------------------------------------------------------------------------------

## The score on a date: the points of the last window_days, each fading linearly to nothing over the window.
func score(on: Dictionary) -> float:
	var today := StoryletSystem.day_no(on)
	var window := float(rcfg().window_days)
	var sum := 0.0
	for e in rep_events:
		var age := today - int(e.day)
		if age >= 0 and age < window:
			sum += float(e.points) * (1.0 - age / window)
	return sum


## The index of the step a score has reached (data steps).
static func step_of(sc: float) -> int:
	var steps: Array = rcfg().steps
	var out := 0
	for i in steps.size():
		if sc >= float(steps[i].min):
			out = i
	return out


## {score, step (index), name, short, next (the next step's name or ""), next_min, to_next, rows (the events that count now, newest
## first, each with its weight now), faded (events more than a year old)}.
func reputation(on: Dictionary) -> Dictionary:
	var steps: Array = rcfg().steps
	var sc := score(on)
	var i := step_of(sc)
	var today := StoryletSystem.day_no(on)
	var window := float(rcfg().window_days)
	var rows := []
	var old := 0
	for e in rep_events:
		var age := today - int(e.day)
		if age < 0 or age >= window:
			continue
		var w := 1.0 - age / window
		if age > 365:
			old += 1
		rows.append({"event": e, "weight": w, "now": float(e.points) * w})
	rows.reverse()
	var out := {"score": sc, "step": i, "name": str(steps[i].name), "short": str(steps[i].short), "rows": rows, "faded": old,
			"next": "", "next_min": 0.0, "to_next": 0.0, "hint": str(steps[i].next)}
	if i + 1 < steps.size():
		out.next = str(steps[i + 1].name)
		out.next_min = float(steps[i + 1].min)
		out.to_next = float(steps[i + 1].min) - sc
	return out


## The step index now (0 without the system's effects: use effect_step() for the game's own decisions).
func step_now() -> int:
	return step_of(score(Game.date))


## The step the game's decisions read: 0 whenever the reputation's effects are off (the lab).
static func effect_step() -> int:
	if not effects_enabled or Game.athlete == null:
		return 0
	var cs := sys()
	return cs.step_now() if cs != null else 0


func _check_step(date: Dictionary) -> void:
	var i := step_of(score(date))
	if i > int(last.step):
		var steps: Array = rcfg().steps
		for k in range(maxi(int(last.step), 0) + 1, i + 1):
			var s: Dictionary = steps[k]
			_add("rep:" + str(s.id), "reputation", date, {"step": str(s.name), "short": str(s.short)})
	last.step = i


# --- Looking at the other systems -----------------------------------------------------------------------------------------------

func _poll(date: Dictionary) -> void:
	var a := Game.athlete
	# the head coach
	if str(last.coach) != a.coach_id:
		var was := str(last.coach)
		last.coach = a.coach_id
		if was != "":
			_coach_milestone(was, date)
	# the school path (a new school year)
	var ss := SchoolSystem.sys()
	if ss != null and SchoolSystem.model_enabled:
		var seg := ss.current_path()
		var key := "%s|%s|%s" % [str(seg.get("kind", "")), str(seg.get("school", "")), str(seg.get("start_year", ""))]
		if key != str(last.path):
			last.path = key
			if not seg.is_empty() and str(seg.kind) in ["urheilulukio", "lukio", "vocational", "grade_10"] and not _before_first_path(seg):
				_school_milestone(seg, date)
	# the town
	var town := a.training_town
	if town != str(last.town):
		if str(last.town) != "" and town != "":
			_add("moved:" + town + ":" + str(Calendar.date_key(date)), "moved", date, {"town": town}, {})
		last.town = town
	_injuries()
	_goals()


## The first path segment is only "begins" news when it is a new start (the default segment of a tool career is not).
func _before_first_path(seg: Dictionary) -> bool:
	return bool(seg.get("default", false))


func _coach_milestone(was: String, date: Dictionary) -> void:
	var cs := Game.get_system("coach") as CoachSystem
	if cs == null:
		return
	var c: Dictionary = cs.coaches.get(Game.athlete.coach_id, {})
	if c.is_empty():
		return
	var old: Dictionary = cs.coaches.get(was, {})
	var text := ("Replaces %s." % str(old.get("name", ""))) if not old.is_empty() else "Your club coach."
	_add("coach:%s:%d" % [Game.athlete.coach_id, Calendar.date_key(date)], "coach" if was != "" else "coach_first", date, {"coach": str(c.get("name", "")), "was": text}, {})


func _school_milestone(seg: Dictionary, date: Dictionary) -> void:
	var kind := str(seg.kind)
	var name := str(Data.school_life.stages.secondary.get(kind, {}).get("name", kind))
	var school := ""
	for s in Data.urheilulukiot.schools:
		if str(s.id) == str(seg.get("school", "")):
			school = "%s, %s" % [str(s.name), str(s.town)]
	if school == "":
		school = str(seg.get("town", ""))
	_add("school:%s:%s:%s" % [kind, str(seg.get("school", "")), str(seg.get("start_year", ""))], "school", date, {"path": name, "school": school}, {})


## Injuries (not illnesses) that kept the athlete out for at least injury_min_days, when they healed.
func _injuries() -> void:
	var hs := Game.get_system("health") as HealthSystem
	if hs == null:
		return
	var min_days := int(ccfg().milestones.injury_min_days)
	for inj in hs.history:
		if str(inj.get("tier", "")) == "illness" or not inj.has("healed"):
			continue
		var key := "inj:%s:%d" % [str(inj.get("id", "")), Calendar.date_key(Game.int_date(inj.started))]
		if found.has(key):
			continue
		var healed := Game.int_date(inj.healed)
		var days := Calendar.days_between(Game.int_date(inj.started), healed)
		if days < min_days:
			found[key] = true
			continue
		var name := str(inj.get("name", "injury"))
		_add(key, "injury", healed, {"weeks": maxi(1, roundi(days / 7.0)), "injury": name.to_lower(), "back": "Back on the track after %d days." % days}, {"name": name})


func _goals() -> void:
	var sg := Game.get_system("goals") as SeasonGoals
	if sg == null:
		return
	for y in sg.seasons:
		for g in sg.seasons[y].get("goals", []):
			if str(g.get("status", "")) != "met":
				continue
			var key := "goal:%s:%s" % [str(y), str(g.id)]
			if found.has(key):
				continue
			var on: Dictionary = Game.int_date(g.met_on) if not g.get("met_on", {}).is_empty() else Game.date
			_add(key, "goal", on, {"goal": SeasonGoals.goal_text(g, int(y)), "opened": SeasonGoals.opened_text(g)}, {})


# --- The season list -------------------------------------------------------------------------------------------------------------

## On the last day of a month: the player's place on the season list (the rankings history) and the first time in the top 10 / 5 / 3 / 1.
func _month_end(date: Dictionary) -> void:
	if int(Game.add_days(date, 1).day) != 1:
		return
	var year := Rankings.season_of(date)
	var list := Rankings.season_list(Game.athlete, Game.rivals, year)
	for row in list:
		if bool(row.is_player):
			for i in range(rank_log.size() - 1, -1, -1):
				if int(rank_log[i].year) == int(date.year) and int(rank_log[i].month) == int(date.month):
					rank_log.remove_at(i)
			rank_log.append({"year": int(date.year), "month": int(date.month), "rank": int(row.rank), "of": list.size(), "time": float(row.time)})
			_rank_milestone(int(row.rank), list.size(), float(row.time), year, date)
			break


func _rank_milestone(rank: int, of: int, time: float, year: int, date: Dictionary) -> void:
	var steps: Array = ccfg().milestones.rank_steps
	var best := -1
	for s in steps:
		if rank <= int(s) and of >= maxi(5, int(s)) and not found.has("rank:%d" % int(s)):
			found["rank:%d" % int(s)] = true
			best = int(s)   # (steps run 10, 5, 3, 1: the last one passed is the highest)
	if best > 0:
		_add("rank:%d" % best, "rank", date, {"rank_word": str(ccfg().milestones.rank_words[str(best)]), "year": year, "rank": rank,
				"of": of, "time": Calendar.format_time(time)})


# --- Adding a milestone -----------------------------------------------------------------------------------------------------------

## Adds a milestone once (`key`). `fill` fills the title and text of the kind (data/career.json milestones.kinds). The list stays in
## date order.
func _add(key: String, kind: String, date: Dictionary, fill: Dictionary, extra := {}) -> void:
	if found.has(key):
		return
	found[key] = true
	var k: Dictionary = ccfg().milestones.kinds[kind]
	var m := {"id": key, "kind": kind, "date": date.duplicate(), "icon": str(k.icon),
			"title": CoachSystem.words(str(k.title).format(fill)), "text": CoachSystem.words(str(k.text).format(fill)).strip_edges()}
	for e in extra:
		m[e] = extra[e]
	var at := milestones.size()
	while at > 0 and Calendar.date_key(milestones[at - 1].date) > Calendar.date_key(date):
		at -= 1
	milestones.insert(at, m)


# --- Older saves --------------------------------------------------------------------------------------------------------------------

## After loading: a save from before version 8 has no state here; it is rebuilt from the results, the healed injuries and the goals met.
func after_load() -> void:
	if not _legacy or Game.athlete == null:
		return
	_legacy = false
	since = Game.date.duplicate()
	var a := Game.athlete
	last.coach = a.coach_id
	last.town = a.training_town
	var ss := SchoolSystem.sys()
	if ss != null and SchoolSystem.model_enabled:
		var seg := ss.current_path()
		last.path = "%s|%s|%s" % [str(seg.get("kind", "")), str(seg.get("school", "")), str(seg.get("start_year", ""))]
	last.step = 0
	_process_results()
	_injuries()
	_goals()
	_comeback_all()


## An older save: every healed long injury gets its comeback race from the results.
func _comeback_all() -> void:
	for m in milestones.duplicate():
		if str(m.kind) != "injury" or found.has("comeback:" + str(m.id)):
			continue
		for r in Game.athlete.results:
			if Calendar.date_key(Game.int_date(r.date)) > Calendar.date_key(m.date):
				var d := Game.int_date(r.date)
				found["comeback:" + str(m.id)] = true
				_add("comeback:" + str(m.id), "comeback", d, {"meet": str(r.meet), "result": Race.result_text(r, " in "), "injury": str(m.get("name", "injury")).to_lower()},
						{"meet": str(r.meet_key), "card": "%d_%s" % [Calendar.date_key(d), str(r.meet_key)]})
				break


# --- Reading for the screens --------------------------------------------------------------------------------------------------------

## The personal bests over time: [{date, time, meet}] oldest first (from the results' pb flags).
static func pb_series(a: Athlete) -> Array:
	var out := []
	for r in a.results:
		if bool(r.get("pb", false)) and str(r.get("event", "")) == a.main_event and float(r.time) > 0.0:
			out.append({"date": Game.int_date(r.date), "time": float(r.time), "meet": str(r.meet)})
	return out


# --- Save / load ------------------------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"v": 1, "seen": seen, "milestones": milestones, "rep_events": rep_events, "rank_log": rank_log, "found": found, "since": since, "last": last,
			"reviews": reviews}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		_legacy = true
		return
	seen = int(d.get("seen", 0))
	milestones = d.get("milestones", [])
	for m in milestones:
		m.date = Game.int_date(m.date)
	rep_events = d.get("rep_events", [])
	for e in rep_events:
		e.day = int(e.day)
		e.date = Game.int_date(e.date)
	rank_log = d.get("rank_log", [])
	for r in rank_log:
		r.year = int(r.year)
		r.month = int(r.month)
		r.rank = int(r.rank)
		r.of = int(r.of)
	found = d.get("found", {})
	since = Game.int_date(d.since) if not d.get("since", {}).is_empty() else {}
	last = d.get("last", last)
	last.step = int(last.get("step", -1))
	reviews = {}
	var saved: Dictionary = d.get("reviews", {})
	for y in saved:
		var r: Dictionary = saved[y]
		r.year = int(r.year)
		r.date = Game.int_date(r.date)
		r["until"] = int(r["until"])
		r.met = int(r.met)
		r.age = int(r.age)
		for k in ["races", "pbs", "wins", "medals", "scoring", "injured"]:
			r.numbers[k] = int(r.numbers[k])
		for row in r.rank:
			row.rank = int(row.rank)
			row.of = int(row.of)
		for row in r.life:
			row.date = Game.int_date(row.date)
		if not r.best_race.is_empty():
			r.best_race.date = Game.int_date(r.best_race.date)
		r.next.year = int(r.next.year)
		reviews[int(y)] = r
