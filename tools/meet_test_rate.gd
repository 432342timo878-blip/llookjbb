extends SceneTree
## Dev tool (session S3a): how often the meet-and-tests decision (data/school_life.json decisions.meet_test) would stop Play week:
## for several athletes, every meet a 14-15-year-old could enter in the school terms of 2026-27 and 2027-28 (and, with `lukio`, a
## 16-year-old's 2028-29), entered one at a time, asking meet_test_clash on the Monday of its week. Prints the share of clash weeks
## with `test_day_before` on and off. S2 measured 33 % with it on; S3a (user: drop 'test the day before') turned it off.
## Run: godot --headless --path . -s res://tools/meet_test_rate.gd [-- athletes, default 12]
## Reads only; no saves are written.

var game
var data
var Cal
var SCal
var _n := 12


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	Cal = load("res://scripts/core/calendar.gd")
	SCal = load("res://scripts/core/school_calendar.gd")
	load("res://scripts/core/health_system.gd").model_enabled = false
	load("res://scripts/core/coach_system.gd").neutral_club = true
	game.autosave = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		_n = args[0].to_int()
	var cfg: Dictionary = data.school_life.decisions.meet_test
	var results := {}
	var variants := [
		{"name": "as S2 (day before on, race day on, busy week with >= 2 tests left)", "before": true, "race_day": true, "left": 2},
		{"name": "S3a (day before off)", "before": false, "race_day": true, "left": 2},
		{"name": "only a test on the race day", "before": false, "race_day": true, "left": 99},
		{"name": "only a busy week with >= 2 tests left", "before": false, "race_day": false, "left": 2},
		{"name": "busy week with >= 3 tests left + race day", "before": false, "race_day": true, "left": 3},
		{"name": "busy week with >= 4 tests left + race day", "before": false, "race_day": true, "left": 4}]
	for v in variants:
		cfg.test_day_before = v.before
		cfg.test_on_race_day = v.race_day
		cfg.min_left_busy = v.left
		var flag: String = v.name
		var meets := 0
		var clashes := 0
		var per_athlete := []
		for i in _n:
			game.start_career(_athlete(i), "repeat")
			var ss = game.get_system("school")
			ss._ensure_started()
			var count := 0
			for m in Cal.meets_between({"year": 2026, "month": 11, "day": 2}, {"year": 2028, "month": 6, "day": 3}):
				if not bool(Cal.can_enter(game.athlete, m, {"year": 2026, "month": 11, "day": 2}).ok):
					continue
				var info: Dictionary = SCal.day("Tampere", m.date)
				if not (str(info.kind) in ["school", "weekend"] and str(info["break"]) == ""):   # (inside a term, not in a break)
					continue
				meets += 1
				var monday: Dictionary = Cal.monday_of(m.date)
				game.entries = [str(m.key)]
				ss.week_choices = {}
				if not ss.meet_test_clash(monday).is_empty():
					clashes += 1
					count += 1
			per_athlete.append(count)
		results[flag] = {"meets": meets, "clashes": clashes}
		print("%s: %d meets in school terms, %d clash weeks = %.0f %% (per athlete: %s)" % [flag, meets, clashes,
				100.0 * clashes / maxf(1.0, meets), per_athlete])
	cfg.test_day_before = false
	cfg.test_on_race_day = true
	cfg.min_left_busy = 2
	quit()


func _athlete(i: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = 42 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	var a = load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test%d" % i, "last_name": "Runner", "gender": "male" if i % 2 == 0 else "female", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 1 + i % 12, "day": 1 + i},
		"answers": answers}, rng)
	return a
