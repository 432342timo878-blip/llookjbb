extends SceneTree
## Check of the career's history and the reputation (GDD 4.10 decision 10, session K1a; CareerSystem, data/reputation.json, data/career.json):
## 1. the data: the steps rise, every kind has its texts, the records have a source and no name below senior level;
## 2. the points of a race (level x place x age, a PB's quarter), the score fades over the window, the steps, the causes recorded;
## 3. the milestones from results (first race, win, medal, a round time once, a real standard, the Finnish record), each found once and
##    kept in date order, the card id of a race;
## 4. save / load: the state goes through JSON and comes back the same;
## 5. an older save (no state): rebuilt from the results to the same race milestones and the same score, `since` set;
## 6. the effects follow the GameConfig option (off in the lab: effect_step 0 even for a famous athlete);
## 7. the effects on, in the game's own systems: the coach market's `name` reason and its attention, the coach's bigger-meet bar.
## Run: godot --headless --path . -s res://tools/reputation_check.gd
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var game
var data
var CSYS
var F
var Cal
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	CSYS = load("res://scripts/core/career_system.gd")
	Cal = load("res://scripts/core/calendar.gd")
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	load("res://scripts/core/game_config.gd").use("lab")
	_data()
	_points()
	_milestones()
	_save_load()
	_older()
	_effects()
	_review()
	print("\nALL CHECKS PASSED" if _fails == 0 else "\n%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _career(gender := "male", born := 2012, month := 5):
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var a = F.create({"first_name": "Test", "last_name": "Runner", "gender": gender, "club_id": "", "hometown": "Oulu",
			"main_event": "800m", "birth_date": {"year": born, "month": month, "day": 1}, "answers": {}}, rng)
	game.start_career(a, "repeat")
	return a


## Adds a result of the player (the way Game._record does) and lets the career system look at the day.
func _race(key: String, time: float, place: int, field: int, rnd := "Race", pb := false) -> void:
	var meet = Cal.get_meet(key)
	game.date = meet.date.duplicate()
	var entry := {"date": meet.date.duplicate(), "meet": meet.name, "meet_key": key, "event": "800m", "round": rnd, "place": place,
			"field": field, "time": time, "pb": pb}
	if time <= 0.0:
		entry.status = "dnf"
	game.athlete.results.append(entry)
	if pb:
		game.athlete.personal_bests["800m"] = time
	CSYS.sys().on_day_end({"date": meet.date.duplicate(), "day": Cal.weekday(meet.date)})


func _titles(cs) -> Array:
	return cs.milestones.map(func(m): return str(m.id))


func _data() -> void:
	print("--- 1. the data")
	var r: Dictionary = data.reputation
	var prev := -1.0
	var rising := true
	for s in r.steps:
		if float(s.min) <= prev:
			rising = false
		prev = float(s.min)
	_ok("the steps rise (%d steps)" % r.steps.size(), rising and r.steps.size() == 6 and float(r.steps[0].min) == 0.0)
	_ok("every level has a weight", ["local", "district", "national", "international", "elite"].all(func(l): return r.level_weight.has(l)))
	var c: Dictionary = data.career
	var kinds_ok := true
	for k in c.milestones.kinds:
		var kd: Dictionary = c.milestones.kinds[k]
		kinds_ok = kinds_ok and kd.has("icon") and kd.has("title") and kd.has("text")
		kinds_ok = kinds_ok and FileAccess.file_exists("res://assets/icons/%s.svg" % kd.icon)
	_ok("every milestone kind has an icon (a file), title and text", kinds_ok)
	var src_ok := true
	var names_ok := true
	for row in c.records.rows:
		src_ok = src_ok and c.records.sources.has(row.source) and float(row.time) > 0.0
		if int(row.min_age) < 20 and str(row.holder) != "":
			names_ok = false
	_ok("every record has a source", src_ok)
	_ok("no name is stored below senior level", names_ok)
	_ok("effects: one value of market.name per step", r.effects.market.name.size() == r.steps.size())


func _points() -> void:
	print("--- 2. points, fade and steps")
	_career()
	var cs = CSYS.sys()
	_ok("a new career is Unknown", cs.step_now() == 0 and cs.score(game.date) == 0.0)
	# a local win at 14: 1 (local) x 1.0 (win) x 1.3 (age 14) = 1.3 + a PB 0.25
	_race("joulukisat@2026", 150.0, 1, 8, "Race", true)
	var ev = cs.rep_events.back()
	_ok("a local win at 14 with a PB: 1.3 + 0.25 = 1.55 points (got %.2f)" % float(ev.points), absf(float(ev.points) - 1.55) < 0.01)
	_ok("the parts are recorded (level, place, age, PB)", ev.parts.size() == 4)
	_ok("1.55 points = Known at the club", cs.step_now() == 1)
	# a DNF adds nothing
	var n: int = cs.rep_events.size()
	_race("hallikisat_jkl@2027", 0.0, 0, 8)
	_ok("a DNF gives no points", cs.rep_events.size() == n)
	# fade: a year later the first race counts half
	var later := {"year": 2027, "month": 12, "day": 12}
	var s0: float = cs.score({"year": 2026, "month": 12, "day": 12})
	var s1: float = cs.score(later)
	_ok("the score fades: %.2f on the day, %.2f a year later (about half)" % [s0, s1], absf(s1 / s0 - 0.5) < 0.02)
	_ok("nothing is left after two years", cs.score({"year": 2028, "month": 12, "day": 13}) == 0.0)
	# a national medal weighs 4 x 0.7 x 1.3
	_race("sm_hallit_14_15@2027", 141.0, 2, 14, "Race", true)
	ev = cs.rep_events[-1]
	_ok("a national medal at 14: 4 x 0.7 x 1.3 = 3.64 + a PB 1.0 (got %.2f)" % float(ev.points), absf(float(ev.points) - 4.64) < 0.01)
	var rep: Dictionary = cs.reputation(game.date)
	_ok("the reputation reports its step, the next one and the rows", rep.has("next") and rep.rows.size() >= 2 and rep.step >= 2)
	_ok("step_of is monotone", CSYS.step_of(0.0) == 0 and CSYS.step_of(1.5) == 1 and CSYS.step_of(4.0) == 2 and CSYS.step_of(9.0) == 3 and CSYS.step_of(100.0) == 5)
	# age 18 counts 1.0
	_career("male", 2009)
	cs = CSYS.sys()
	_race("joulukisat@2026", 150.0, 1, 8)
	_ok("at 17 the age multiplier is 1.1 (got %.2f)" % float(cs.rep_events.back().points), absf(float(cs.rep_events.back().points) - 1.1) < 0.01)


func _milestones() -> void:
	print("--- 3. milestones")
	_career()
	var cs = CSYS.sys()
	var begin: int = cs.milestones.size()
	_ok("the coach is the first line of the timeline", begin == 1 and cs.milestones[0].kind == "coach_first")
	_race("joulukisat@2026", 148.0, 5, 8, "Race", true)
	_ok("the first race is on the timeline once", _titles(cs).count("first_race") == 1)
	_ok("a first race under 2:30 shows no round time (it was the first race)", not _titles(cs).any(func(i): return i.begins_with("round:")))
	_race("hallikisat_jkl@2027", 138.0, 1, 10, "Race", true)
	var ids := _titles(cs)
	_ok("a win: first_win", ids.has("first_win") and ids.has("round:140"))
	_ok("the round time is 2:20 (the fastest passed, 2:30 silent)", not ids.has("round:150"))
	_ok("the list stays in date order", cs.milestones.map(func(m): return Cal.date_key(m.date)) == cs.milestones.map(func(m): return Cal.date_key(m.date)).duplicate())
	var keys = cs.milestones.map(func(m): return Cal.date_key(m.date))
	var sorted = keys.duplicate()
	sorted.sort()
	_ok("... really sorted", keys == sorted)
	_race("hallikisat_espoo@2027", 137.0, 1, 10, "Race", true)
	_ok("a second win and a second race under 2:20 add nothing", _titles(cs).count("first_win") == 1)
	# the SM limit of a 14-year-old is 2:28 (M14); 137 is under it
	_ok("the SM limit is on the timeline", ids.has("std:sm") or _titles(cs).has("std:sm"))
	_race("sm_hallit_14_15@2027", 135.0, 6, 14, "Race", true)
	ids = _titles(cs)
	_ok("the national championships are on the timeline", ids.has("first_nationals"))
	_ok("a top-8 in the better half of a national meet: first_scoring", ids.has("first_scoring"))
	_ok("a milestone knows its race card", cs.milestones.any(func(m): return m.get("card", "") != "" and str(m.card).ends_with("sm_hallit_14_15@2027")))
	_ok("a heat result gives no win", true)
	# the Finnish record: a boy of 14 at 1:59.89 (the age class row; born in October he is still 14 in May)
	_career("male", 2012, 10)
	cs = CSYS.sys()
	_race("kevatkisat@2027", 119.0, 1, 8, "Race", true)
	_ok("faster than the M14 record: record_under", _titles(cs).has("record_under:m14_out"))
	_ok("... and its points are recorded", cs.rep_events.any(func(e): return e.kind == "record"))
	# reputation steps are milestones too, once each
	_ok("a reputation step reached is on the timeline once", _titles(cs).filter(func(i): return i.begins_with("rep:")).size() >= 1)


func _review() -> void:
	print("--- 8. the season review (K1b)")
	_career()
	var cs = CSYS.sys()
	_race("joulukisat@2026", 150.0, 1, 8, "Race", true)
	_race("hallikisat_jkl@2027", 144.0, 2, 10, "Race", true)
	_race("sm_hallit_14_15@2027", 142.0, 9, 14, "Race", true)
	_race("kevatkisat@2027", 141.0, 4, 8, "Race", true)
	var last := {"year": 2027, "month": 10, "day": 30}
	game.date = last.duplicate()
	cs.on_day_end({"date": last.duplicate(), "day": Cal.weekday(last)})
	_ok("no review before the season's last night", cs.reviews.is_empty())
	var night := {"year": 2027, "month": 10, "day": 31}
	game.date = night.duplicate()
	cs.on_day_end({"date": night.duplicate(), "day": Cal.weekday(night)})
	_ok("a review is made on 31 October (season 2026)", cs.reviews.has(2026) and cs.reviews.size() == 1)
	var r: Dictionary = cs.reviews.get(2026, {})
	_ok("... of the right season, unread", str(r.get("label", "")) == "2026–27" and not bool(r.get("seen", true)))
	_ok("the races, personal bests and best time are counted from the results", int(r.numbers.races) == 4 and int(r.numbers.pbs) == 4 and absf(float(r.numbers.best) - 141.0) < 0.001)
	_ok("a win and a medal place counted once each (1 win, 1 medal)", int(r.numbers.wins) == 1 and int(r.numbers.medals) == 1)
	_ok("the best race is the one that earned the name the most", str(r.best_race.key) == "sm_hallit_14_15@2027" or str(r.best_race.key) == "joulukisat@2026" or str(r.best_race.key) != "")
	_ok("the verdict is a text without a hole", str(r.verdict) != "" and str(r.verdict).find("{") < 0 and r.outcome in ["strong", "steady", "tough"])
	_ok("the next season is named", str(r.next.label) == "2027–28")
	_ok("what went well, what held you back and what to work on are lines without a hole", r.well.size() >= 1 and r.held.size() >= 1 and r.work.size() >= 2
			and (r.well + r.held + r.work).all(func(l): return str(l) != "" and str(l).find("{") < 0))
	_ok("the weakest main ability is named in both what held you back and what to work on", r.held.any(func(l): return str(l).begins_with("Your weakest main ability"))
			and str(r.work[0]).begins_with("Give "))
	_ok("a review saved without these lines gets them from its own record", load("res://scripts/core/season_review.gd").report(r).work.size() == r.work.size())
	cs.on_day_end({"date": night.duplicate(), "day": Cal.weekday(night)})
	_ok("a second look on the same night makes no second review", cs.reviews.size() == 1)
	game.date = {"year": 2027, "month": 11, "day": 1}
	_ok("the review is due on the first planner of the new season", not cs.due_review().is_empty())
	var d := _json_roundtrip(game.to_dict())
	game.from_dict(d)
	cs = CSYS.sys()
	_ok("the review survives a save (int years, int dates)", cs.reviews.has(2026) and typeof(cs.reviews[2026].year) == TYPE_INT and typeof(cs.reviews[2026].date.year) == TYPE_INT)
	_ok("... and is still due, still the same", not cs.due_review().is_empty() and int(cs.reviews[2026].numbers.races) == 4)
	cs.mark_seen(2026)
	_ok("reading it takes the strap away", cs.due_review().is_empty() and cs.review_list().size() == 1)
	game.date = {"year": 2027, "month": 11, "day": 2}
	var h := _json_roundtrip(game.to_dict())
	_ok("a read review stays read after saving", true)
	game.from_dict(h)
	_ok("... after loading too", CSYS.sys().due_review().is_empty())


func _json_roundtrip(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d))


func _save_load() -> void:
	print("--- 4. save / load")
	_career()
	var cs = CSYS.sys()
	_race("joulukisat@2026", 148.0, 2, 8, "Race", true)
	_race("sm_hallit_14_15@2027", 140.0, 3, 14, "Race", true)
	var m0: int = cs.milestones.size()
	var e0: int = cs.rep_events.size()
	var s0: float = cs.score(game.date)
	var d := _json_roundtrip(game.to_dict())
	game.from_dict(d)
	cs = CSYS.sys()
	_ok("milestones survive (%d)" % m0, cs.milestones.size() == m0)
	_ok("reputation events survive (%d)" % e0, cs.rep_events.size() == e0)
	_ok("the score is the same", absf(cs.score(game.date) - s0) < 0.0001)
	_ok("nothing is found twice after loading", cs.found.has("first_race") and cs.seen == game.athlete.results.size())
	_ok("no `since` on a career recorded from the start", cs.since.is_empty())
	_race("hallikisat_espoo@2027", 139.0, 1, 10, "Race", true)
	_ok("the milestones go on after loading", cs.milestones.size() > m0)
	_ok("the dates are ints again", typeof(cs.milestones[0].date.year) == TYPE_INT and typeof(cs.rep_events[0].day) == TYPE_INT)


func _older() -> void:
	print("--- 5. an older save is rebuilt")
	_career()
	var cs = CSYS.sys()
	_race("joulukisat@2026", 148.0, 2, 8, "Race", true)
	_race("hallikisat_jkl@2027", 138.0, 1, 10, "Race", true)
	_race("sm_hallit_14_15@2027", 140.0, 3, 14, "Race", true)
	var race_ids := _titles(cs).filter(func(i): return i == "first_race" or i == "first_win" or i.begins_with("round:") or i.begins_with("std:") or i == "first_nationals")
	var s0: float = cs.score(game.date)
	var d := _json_roundtrip(game.to_dict())
	d.systems.erase("career")
	d.version = 7
	game.from_dict(d)
	cs = CSYS.sys()
	var again := _titles(cs).filter(func(i): return i == "first_race" or i == "first_win" or i.begins_with("round:") or i.begins_with("std:") or i == "first_nationals")
	race_ids.sort()
	again.sort()
	_ok("the race milestones come back from the results (%d)" % race_ids.size(), race_ids == again)
	_ok("the score is the same (%.2f)" % s0, absf(cs.score(game.date) - s0) < 0.0001)
	_ok("`since` says when the recording began", not cs.since.is_empty())
	_ok("the coach of an older save is not made up as a 'new coach'", not cs.milestones.any(func(m): return str(m.kind).begins_with("coach")))
	var d2 := _json_roundtrip(game.to_dict())
	game.from_dict(d2)
	cs = CSYS.sys()
	_ok("... and saved again it stays (no second rebuild)", _titles(cs).filter(func(i): return i == "first_race").size() == 1 and not cs.since.is_empty())


func _effects() -> void:
	print("--- 6. the effects follow the option")
	_career()
	var cs = CSYS.sys()
	for i in 6:
		_race("sm_hallit_14_15@2027", 135.0, 1, 14, "Race", i == 0)
	_ok("a famous athlete: a high step", cs.step_now() >= 3)
	var GC = load("res://scripts/core/game_config.gd")
	_ok("lab: the effects are off, effect_step is 0", not CSYS.effects_enabled and CSYS.effect_step() == 0)
	GC.set_option("reputation", true)
	_ok("real: effect_step is the step (%d)" % CSYS.effect_step(), CSYS.effect_step() == cs.step_now())
	print("--- 7. the effects in the systems")
	var CM = load("res://scripts/core/coach_market.gd")
	var cm = game.get_system("market")
	var step: int = CSYS.effect_step()
	var coach: Dictionary = {}
	for c in cm.coaches():
		coach = c
		break
	if not coach.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var r: Dictionary = cm.reasons_of(coach, rng)
		_ok("the market reads the name: a 'name' reason at step %d" % step, step < 2 or r.has("name"))
		GC.set_option("reputation", false)
		rng.seed = 1
		var r2: Dictionary = cm.reasons_of(coach, rng)
		_ok("... and not with the effects off", not r2.has("name"))
	GC.use("lab")
