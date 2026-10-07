extends SceneTree
## Dev tool: headless checks for the day-by-day engine (GDD 4.5 / 4.7). Prints PASS / FAIL per check.
## Run: godot --headless --path . -s res://tools/day_engine_check.gd [-- <a version-1 save file to also load>]
## Uses its own save folder, never the player's saves. The health model is switched off here (these checks
## compare day-by-day play with the plain weekly simulation; a random cold would change that): the health
## model has its own checks in tools/health_check.gd.

var game
var saves
var Cal
var T
var A
var WP
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Loaded at runtime: autoload names (Data, Game) only exist once the tree is running.
	game = root.get_node("Game")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	Cal = load("res://scripts/core/calendar.gd")
	T = load("res://scripts/core/training.gd")
	A = load("res://scripts/core/athlete.gd")
	WP = load("res://scripts/core/week_plan.gd")
	load("res://scripts/core/health_system.gd").model_enabled = false

	_check_exact_numbers()
	_check_same_as_weekly()
	_check_day_changes()
	_check_midweek_save()
	_check_week_plan()
	_check_v1_save()
	_check_v2_save()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_check_real_v1_file(args[0])
	_check_race_week(false)
	_check_race_week(true)
	_check_rival_personalities()
	_check_race_repeatable()
	_check_stop_events()
	_check_day_start_stop()
	_check_ui_models()
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


# --- Checks ------------------------------------------------------------------------------------

## Saved numbers read back bit for bit (Godot's own JSON reader misses the last digit now and then).
func _check_exact_numbers() -> void:
	print("-- exact numbers in saves")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var values := []
	for i in 20000:
		values.append(rng.randf_range(-5.0, 120.0) + rng.randf() * 1e-9)
	var text := JSON.stringify({"v": values, "s": "text with 1.5 and \"quoted 2.5\""}, " ", true, true)
	var plain: Dictionary = JSON.parse_string(text)
	var off := 0
	for i in values.size():
		if plain.v[i] != values[i]:
			off += 1
	var exact: Dictionary = JSON.parse_string(text)
	saves._exact_numbers(exact, saves._number_tokens(text), {"i": 0})
	var still_off := 0
	for i in values.size():
		if exact.v[i] != values[i]:
			still_off += 1
			if still_off <= 3:
				print("    still off: wrote %s, read %s" % [JSON.stringify(values[i], "", true, true),
						JSON.stringify(exact.v[i], "", true, true)])
	if still_off > 0:
		print("    %d still off" % still_off)
	print("    Godot's reader: %d of %d numbers off in the last digit" % [off, values.size()])
	_ok("all 20000 read back exactly", still_off == 0)


## Playing day by day through the game gives exactly the same athlete as the weekly simulation.
func _check_same_as_weekly() -> void:
	print("-- day by day = weekly simulation")
	_new_career(1)
	var copy = A.from_dict(game.athlete.to_dict().duplicate(true))
	var monday: Dictionary = game.date.duplicate()
	for w in 8:
		T.simulate_week(copy, game.season.repeat_week, monday)
		monday = game.add_days(monday, 7)
	for d in 8 * 7:
		game.advance_day()
	_ok("8 weeks: same attributes and fatigue to full precision", _json(game.athlete.to_dict()) == _json(copy.to_dict()))
	_ok("date moved 56 days", game.date == game.add_days(game.START_DATE, 56))
	_ok("day log keeps %d days" % game.LOG_DAYS, game.day_log.size() == game.LOG_DAYS)


func _check_day_changes() -> void:
	print("-- day changes")
	_new_career(2)
	var w = game.current_week()
	var plan_before: String = _json(game.season.repeat_week)
	_ok("swap Mon slot 0", w.swap_session(0, 0, "tempo_run") and w.session_ids(0) == ["tempo_run", "drills"])
	_ok("remembers who changed it", w.changed_by(0) == {"sessions": "player"})
	_ok("no 3rd session on a day", not w.add_session(0, "mobility"))
	_ok("skip Tue's only session", w.skip_session(1, 0) and w.session_ids(1).is_empty())
	_ok("add a session to Fri", w.add_session(4, "easy_run") and w.session_ids(4) == ["mobility", "easy_run"])
	_ok("Sat rest day", w.make_rest_day(5) and w.session_ids(5).is_empty())
	_ok("Thu Hard", w.set_intensity(3, "hard") and w.intensity(3) == "hard")
	_ok("Sun Easy", w.set_intensity(6, "easy"))
	_ok("unknown intensity refused", not w.set_intensity(2, "extreme") and not w.set_intensity(2, "_note"))
	_ok("unknown session refused", not w.add_session(6, "teleport"))
	_ok("unknown 'by' refused", not w.make_rest_day(2, "alien"))
	_ok("back to the plan = no change", w.swap_session(0, 0, "easy_run") and not w.changes.has(0))
	_ok("weekly plan untouched", _json(game.season.repeat_week) == plan_before)
	var fartlek_normal: float = T.session_load(game.athlete, game.get_node("/root/Data").get_session("fartlek"))
	for d in 4:
		game.advance_day()
	_ok("played day can't be changed", not w.set_intensity(0, "easy") and not w.can_change(3))
	var log_by_day := {}
	for e in game.day_log:
		log_by_day[Cal.weekday(e.date)] = e
	_ok("log: Tue rest", log_by_day[1].sessions.is_empty())
	_ok("log: Thu Hard, load ×%.2f" % _mult("hard", "load"),
			log_by_day[3].intensity == "hard" and is_equal_approx(log_by_day[3].load, fartlek_normal * _mult("hard", "load")))
	_ok("log: day type", log_by_day[0].day_type == "weekday")
	game.advance_week()
	_ok("Sat/Sun logged as weekend, Sat rest", game.day_log[-2].day_type == "weekend" and game.day_log[-2].sessions.is_empty())
	_ok("next week starts without changes", game.current_week().changes.is_empty() and game.current_week().day == 0)


## Save on a Thursday morning, load: the same state, and the rest of the week plays out the same.
func _check_midweek_save() -> void:
	print("-- mid-week save / load")
	_new_career(3)
	var w = game.current_week()
	w.set_intensity(4, "easy")
	w.make_rest_day(5)
	for d in 3:
		game.advance_day()
	game.post_event("health", "A note", "Just a logged event.")
	saves.save("mid")
	var before: String = _json(game.to_dict())
	game.advance_week()
	var after_a: String = _json(game.athlete.to_dict()) + _json(game.last_report)
	game.date = game.START_DATE.duplicate()   # scramble before loading
	_ok("load the mid-week save", saves.load_slot("mid"))
	_ok("same state after loading", _json(game.to_dict()) == before)
	_ok("still Thursday, 3 days played", Cal.weekday(game.date) == 3 and game.current_week().day == 3)
	_ok("this week's changes kept", game.current_week().intensity(4) == "easy" and game.current_week().changed_by(5).sessions == "player")
	game.advance_week()
	var after_b: String = _json(game.athlete.to_dict()) + _json(game.last_report)
	_ok("rest of the week plays out exactly the same", after_b == after_a)
	if after_b != after_a:
		for i in mini(after_a.length(), after_b.length()):
			if after_a[i] != after_b[i]:
				print("    first difference:\n    A ", after_a.substr(maxi(0, i - 80), 160), "\n    B ", after_b.substr(maxi(0, i - 80), 160))
				break
	saves.delete("mid")


## M2 step 6a: the week plan {days, intensity}, intensity in the plan, the season plan and save version 3.
func _check_week_plan() -> void:
	print("-- week plan (days + intensity in the plan)")
	var coach_days: Array = T.coach_plan()
	var wp: Dictionary = WP.of(coach_days)
	_ok("the old plain Array becomes a week plan, every day Normal",
			wp.days == coach_days and wp.intensity == ["normal", "normal", "normal", "normal", "normal", "normal", "normal"])
	_ok("WeekPlan.of leaves a week plan as it is", WP.of(wp) == wp and WP.equals(wp, coach_days))
	_ok("equals tells Hard from Normal", not WP.equals(wp, WP.make(coach_days, ["normal", "normal", "normal", "hard"])))
	_ok("make fills in missing and unknown parts", WP.make([["easy_run"]], ["extreme"]).intensity[0] == "normal"
			and WP.make().days.size() == 7)

	# Normal plan vs a plan with Hard days: load, the day's real load and the training effect all go up.
	_new_career(11)
	var normal_plan: Dictionary = WP.coach()
	var hard_plan: Dictionary = WP.make(coach_days, ["normal", "hard", "normal", "hard", "normal", "normal", "normal"])
	var month := 11
	var pn: Dictionary = T.preview(game.athlete, normal_plan, month)
	var ph: Dictionary = T.preview(game.athlete, hard_plan, month)
	_ok("preview: Hard days raise the plan's load (%d → %d)" % [roundi(pn.load), roundi(ph.load)], ph.load > pn.load)
	_ok("preview of the old Array = the Normal week plan", T.preview(game.athlete, coach_days, month).load == pn.load)
	var fn: Dictionary = T.expected_fatigue(game.athlete, normal_plan, game.date)
	var fh: Dictionary = T.expected_fatigue(game.athlete, hard_plan, game.date)
	_ok("expected fatigue is higher with Hard days (%d → %d)" % [roundi(fn.avg), roundi(fh.avg)], fh.avg > fn.avg)

	# The game plays the plan's intensity, and a day change equal to the plan is dropped.
	game.season.repeat_week = hard_plan.duplicate(true)
	var w = game.current_week()
	_ok("the week takes its intensity from the plan", w.intensity(1) == "hard" and w.intensity(0) == "normal"
			and w.plan_intensity == hard_plan.intensity)
	_ok("Tue is not a day change (it is the plan)", not w.changes.has(1) and not w.changed_by(1).has("intensity"))
	_ok("a change equal to the plan's Hard is dropped", w.set_intensity(1, "hard") and not w.changes.has(1))
	_ok("Easy on Tue is a change", w.set_intensity(1, "easy") and w.intensity(1) == "easy" and w.changed_by(1).intensity == "player")
	_ok("back to the plan's Hard drops it again", w.set_intensity(1, "hard") and not w.changes.has(1))
	_ok("Normal on Tue is now a change (the plan says Hard)", w.set_intensity(1, "normal") and w.changes.has(1))
	_ok("Back to plan = Hard", w.reset_day(1) and w.intensity(1) == "hard")
	_ok("Mon Normal equals the plan: no change", w.set_intensity(0, "normal") and not w.changes.has(0))
	# Editing the plan: the week follows, and a change that has become the plan is dropped.
	w.set_intensity(2, "hard")
	game.season.repeat_week.intensity[2] = "hard"
	w = game.current_week()
	_ok("the week follows an edited plan, and the change that now equals it is gone", w.intensity(2) == "hard" and not w.changes.has(2))
	# Played: Tue is Hard (fartlek-like club session at ×hard).
	var data = game.get_node("/root/Data")
	var club_normal: float = T.session_load(game.athlete, data.get_session(coach_days[1][0]))
	game.advance_day()
	var fatigue_after_mon: float = game.athlete.fatigue
	game.advance_day()
	var tue: Dictionary = game.day_log[-1]
	_ok("Tue was played at Hard: load ×%.2f" % _mult("hard", "load"),
			tue.intensity == "hard" and is_equal_approx(tue.load, club_normal * _mult("hard", "load")) and fatigue_after_mon > 0.0)
	_ok("Mon was played at Normal", game.day_log[-2].intensity == "normal")

	# Save version 3 stores the season plan and brings it back exactly.
	var before: String = _json(game.season.to_dict())
	saves.save("v3")
	game.season = load("res://scripts/core/season_plan.gd").new()   # scramble
	_ok("load the version-3 save", saves.load_slot("v3"))
	_ok("the season plan comes back the same (repeat mode, Hard days)", game.season.mode == "repeat"
			and _json(game.season.to_dict()) == before and game.season.repeat_week.intensity[1] == "hard")
	_ok("the week in progress follows it", game.current_week().intensity(3) == "hard" and game.current_week().plan_intensity[1] == "hard")
	var text := FileAccess.get_file_as_string(saves.DIR + "v3.json")
	_ok("the file says version 3 and has no training_plan", text.contains("\"version\": 3") and text.contains("\"season\"")
			and not text.contains("\"training_plan\""))
	saves.delete("v3")


## A version-2 save has a plain `training_plan` and no season: it loads as repeat mode, every day Normal, and
## from there plays bit for bit like the same game that was never saved.
func _check_v2_save() -> void:
	print("-- version-2 save (plain training_plan)")
	_new_career(12)
	for d in 10:
		game.advance_day()   # a week in progress (Thursday), some days of log
	var g: Dictionary = game.to_dict().duplicate(true)
	var days: Array = g.season.repeat_week.days
	g.erase("season")
	g["training_plan"] = days
	var v2 := {"version": 2, "saved_at": "2026-10-05 12:00:00", "summary": "old", "game": g}
	var f := FileAccess.open(saves.DIR + "v2.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(v2, " ", true, true))   # as version 2 wrote it
	f.close()
	game.advance_week()
	game.advance_week()
	var continued: String = _json(game.athlete.to_dict()) + _json(game.last_report) + _json(game.day_log)
	_ok("loads", saves.load_slot("v2"))
	_ok("repeat mode with its old plan, every day Normal", game.season.mode == "repeat" and game.season.repeat_week.days == days
			and game.season.repeat_week.intensity == ["normal", "normal", "normal", "normal", "normal", "normal", "normal"])
	_ok("the week in progress is kept", game.current_week().day == Cal.weekday(game.date) and game.current_week().plan == days)
	game.advance_week()
	game.advance_week()
	var loaded: String = _json(game.athlete.to_dict()) + _json(game.last_report) + _json(game.day_log)
	_ok("plays on bit for bit like the game that was never saved", loaded == continued)
	saves.delete("v2")


## A version-1 save (Monday, no week in progress) loads and plays.
func _check_v1_save() -> void:
	print("-- version-1 save")
	_new_career(4)
	game.advance_week()
	game.advance_week()
	var g: Dictionary = game.to_dict()
	var v1 := {"version": 1, "saved_at": "2026-10-01 12:00:00", "summary": "old",
			"game": {"athlete": g.athlete, "date": g.date, "training_plan": g.season.repeat_week.days, "entries": g.entries,
					"rivals": g.rivals}}
	var f := FileAccess.open(saves.DIR + "v1.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(v1, " "))   # as M1 wrote it
	f.close()
	_load_and_play_v1("v1")
	saves.delete("v1")


func _check_real_v1_file(path: String) -> void:
	print("-- real version-1 save file: ", path)
	DirAccess.copy_absolute(path, ProjectSettings.globalize_path(saves.DIR + "v1_real.json"))
	_load_and_play_v1("v1_real")
	saves.delete("v1_real")


func _load_and_play_v1(slot: String) -> void:
	_ok("loads", saves.load_slot(slot))
	_ok("Monday, nothing in progress", Cal.weekday(game.date) == 0 and game.day_log.is_empty() and game.events.is_empty())
	var start: Dictionary = game.date.duplicate()
	game.advance_day()
	_ok("Next day works", game.date == game.add_days(start, 1))
	var r: String = game.advance_week()
	while r == game.RACE:
		_run_race()
		r = game.finish_race()
	_ok("Play week finishes the week", r == game.WEEK_DONE and game.date == game.add_days(start, 7))


## A week with a race: reached with Next day or Play week, then finish_race completes the race day.
func _check_race_week(play_week: bool) -> void:
	print("-- race week with ", "Play week" if play_week else "Next day")
	_new_career(5)
	var meet := {}
	for m in Cal.meets_between(game.date, game.add_days(game.date, 120)):
		if Cal.coach_recommends(game.athlete, m, game.date):
			meet = m
			break
	game.enter(meet.key)
	var r: String = game.DAY_DONE
	var guard := 0
	while r != game.RACE and guard < 200:
		r = game.advance_week() if play_week else game.advance_day()
		guard += 1
	_ok("stops on the race day (%s)" % Cal.format_day(meet.date), r == game.RACE and game.date == meet.date)
	var d: int = Cal.weekday(game.date)
	_ok("race day can't be changed", not game.current_week().can_change(d))
	_ok("pressing again doesn't skip the race", (game.advance_day() if not play_week else game.advance_week()) == game.RACE
			and game.date == meet.date)
	var rd = game.race_day
	_run_race()
	r = game.finish_race()
	_ok("result recorded", game.athlete.results.size() >= 1 and game.athlete.results[-1].meet_key == meet.key)
	var expected := {}   # rival id -> races run together with the player today (heat + final can be 2)
	var rivals_here := {}
	for res in rd.all_results:
		var with_player: bool = res.any(func(row): return row.is_player)
		for row in res:
			if not row.rival.is_empty():
				rivals_here[row.rival.id] = row.rival
				expected[row.rival.id] = int(expected.get(row.rival.id, 0)) + (1 if with_player else 0)
	var met_ok := not expected.is_empty()
	for id in expected:
		met_ok = met_ok and int(rivals_here[id].met) == expected[id]
	_ok("the rivals have met the player once per race run together (%d rivals)" % expected.size(), met_ok)
	_ok("race in the day log", game.day_log.any(func(e): return e.race == meet.key and e.date == meet.date))
	if play_week:
		_ok("Play week goes on to Sunday night", r == game.WEEK_DONE and Cal.weekday(game.date) == 0)
	else:
		_ok("Next day: just the race day", r == game.DAY_DONE and game.date == game.add_days(meet.date, 1))
		while r == game.DAY_DONE:
			r = game.advance_day()
		_ok("rest of the week by Next day", r == game.WEEK_DONE)
	_ok("race in the weekly report", game.last_report.races.size() == 1 and game.last_report.races[0].meet_key == meet.key)


## Race personalities (GDD 4.3.1, step R1): every rival has one; a save from before R1 gets the same one on
## every load (made from anaerobic + a hash of the id, no dice) and a met count of 0.
func _check_rival_personalities() -> void:
	print("-- rival personalities")
	_new_career(6)
	var types: Dictionary = game.get_node("/root/Data").races.personalities
	var counts := {}
	for rv in game.rivals:
		counts[rv.personality] = counts.get(rv.personality, 0) + 1
	print("    ", counts)
	var known: bool = game.rivals.all(func(rv): return types.has(rv.personality) and int(rv.met) == 0)
	_ok("every rival has a known personality and met 0", known)
	_ok("all four kinds occur", counts.size() == 4)
	var before: Array = game.rivals.map(func(rv): return rv.personality)
	var g: Dictionary = game.to_dict().duplicate(true)
	for rv in g.rivals:
		rv.erase("personality")
		rv.erase("met")
	var old := {"version": 3, "saved_at": "2026-10-07 12:00:00", "summary": "old", "game": g}
	var f := FileAccess.open(saves.DIR + "pre_r1.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(old, " ", true, true))
	f.close()
	_ok("a save without personalities loads", saves.load_slot("pre_r1"))
	var first: Array = game.rivals.map(func(rv): return rv.personality)
	var met_zero: bool = game.rivals.all(func(rv): return int(rv.met) == 0)
	_ok("... and gets the same personalities as made at the start, met 0", first == before and met_zero)
	saves.load_slot("pre_r1")
	_ok("... the same again on the next load", game.rivals.map(func(rv): return rv.personality) == first)
	saves.delete("pre_r1")


## All of a race's dice come from its own RNG: the same seed gives the same race, step by step.
func _check_race_repeatable() -> void:
	print("-- race repeatable")
	var RaceScript = load("res://scripts/core/race.gd")
	var out := []
	for k in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var entrants := []
		for i in 8:
			entrants.append({"name": "R%d" % i, "club": "", "ability": 9.0 + rng.randfn(0, 0.6), "speed": 9.0,
					"anaerobic": rng.randfn(0, 2), "tactics": 9.0, "consistency": 9.0, "composure": 9.0})
		seed(k * 1000 + 3)   # the global dice differ: they must not matter
		var race = RaceScript.new()
		race.setup(entrants, "male", false, 10.0, rng, false, "final")
		race.run()
		out.append([race.shape, race.results().map(func(x): return [x.name, x.time, x.split_400])])
	_ok("same seed, same shape and results (%s)" % out[0][0], out[0] == out[1])


## A stop event at day end pauses Play week; answering it changes tomorrow.
func _check_stop_events() -> void:
	print("-- stop events")
	_new_career(6)
	var dev = game.get_system("dev")
	_ok("debug test system present", dev != null)
	if dev == null:
		return
	dev.armed = true
	var r: String = game.advance_week()
	_ok("Play week stops after Monday", r == game.STOP and Cal.weekday(game.date) == 1)
	var e: Dictionary = game.pending_event()
	_ok("event format", e.source == "dev" and e.stop and e.choices.size() == 3 and e.date == game.START_DATE)
	_ok("event in Monday's log", e.id in game.day_log[-1].events)
	_ok("nothing plays while it waits", game.advance_day() == game.STOP and Cal.weekday(game.date) == 1)
	saves.save("stop")
	saves.load_slot("stop")
	_ok("still waiting after save/load", game.pending_event().get("id", "") == e.id)
	saves.delete("stop")
	game.answer_event(e.id, "rest")
	_ok("answer made Tuesday a rest day (by player)", game.current_week().session_ids(1).is_empty()
			and game.current_week().changed_by(1).sessions == "player")
	_ok("answered", game.pending_event().is_empty())
	r = game.advance_week()
	_ok("Play week runs on to Sunday night", r == game.WEEK_DONE)
	_ok("Tuesday was rested", game.day_log[-6].sessions.is_empty())


## A stop event at day start: the day isn't played until it's answered, and day start doesn't run twice.
func _check_day_start_stop() -> void:
	print("-- stop event at day start")
	_new_career(7)
	var script := GDScript.new()
	script.source_code = """extends GameSystem
var fired := 0
func _init():
	id = "start_test"
func on_day_start(ctx):
	if ctx.day == 2:
		fired += 1
		Game.post_event(id, "Morning", "Stops before Wednesday is played.", [], true)
"""
	script.reload()
	var sys = script.new()
	game.systems.append(sys)
	var r: String = game.advance_week()
	_ok("stops on Wednesday morning", r == game.STOP and Cal.weekday(game.date) == 2 and game.current_week().day == 2)
	game.answer_event(game.pending_event().id, "ok")
	r = game.advance_week()
	_ok("then plays Wednesday and the rest", r == game.WEEK_DONE and game.day_log.size() == 7)
	_ok("day start ran once", sys.fired == 1)
	game.systems.erase(sys)


## The week strip, day editor, Today card and Report (M2 step 2): they build without errors, the planned load
## shown for a day is what the engine then plays, and a day change gives the same strip data after save/load.
func _check_ui_models() -> void:
	print("-- UI models (week strip, day editor, Today card, Report)")
	_new_career(8)
	var DI = load("res://scripts/ui/day_info.gd")
	var Strip = load("res://scripts/ui/week_strip.gd")
	var Editor = load("res://scripts/ui/day_editor.gd")
	var Card = load("res://scripts/ui/today_card.gd")
	var Report = load("res://scripts/ui/report_view.gd")
	var DayInfoClass = load("res://scripts/ui/day_info.gd")
	var meet := {}
	for m in Cal.meets_between(game.date, game.add_days(game.date, 120)):
		if Cal.coach_recommends(game.athlete, m, game.date):
			meet = m
			break
	game.enter(meet.key)
	var w = game.current_week()
	w.set_intensity(3, "hard")
	w.add_session(3, "easy_run")
	w.make_rest_day(4)
	var thu = DI.of(w, 3)
	_ok("Thu shows 2 sessions at Hard, changed by you", thu.sessions.size() == 2 and thu.intensity == "hard"
			and thu.changed and DI.changed_text(thu) == "Changed by you")
	_ok("Fri is a changed rest day with no load", DI.of(w, 4).sessions.is_empty() and DI.of(w, 4).load == 0.0)
	_ok("Mon is as planned (not changed)", not DI.of(w, 0).changed and DI.of(w, 0).fatigue < 0.0)
	var planned_thu: float = thu.load
	for d in 4:
		game.advance_day()
	_ok("planned load = played load (%d)" % roundi(planned_thu),
			is_equal_approx(planned_thu, game.day_log[-1].load) and Cal.weekday(game.day_log[-1].date) == 3)
	w = game.current_week()
	_ok("played days: fatigue known, cannot be changed", DI.of(w, 3).played and DI.of(w, 3).fatigue >= 0.0 and not DI.of(w, 3).editable)
	_ok("the played day still says it was changed", DI.of(w, 3).changed)
	_ok("reason a session isn't possible (skiing in November)",
			DI.unavailable_text(game.get_node("/root/Data").get_session("xc_skiing")) == "only Dec–Mar"
			and DI.unavailable_text(game.get_node("/root/Data").get_session("easy_run")) == "")
	var week_json := func() -> String:
		var list := []
		for d in 7:
			list.append(DI.of(game.current_week(), d))
		return _json(list)
	var before: String = week_json.call()
	var strip = Strip.new()
	strip.refresh()
	_ok("strip has 7 cells", strip.get_child_count() == 7)
	var editor = Editor.new()
	var built := 0
	for d in 7:
		editor.show_day(d)
		built += 1 if editor.get_child_count() >= 2 else 0
	_ok("day editor builds for all 7 days (played, changed, rest, plain)", built == 7)
	var card = Card.new()
	_ok("Today card builds", card.get_child_count() == 1)   # one padded column: the top part is a button, the health part its own taps
	var info: Dictionary = DayInfoClass.of(game.current_week(), 0)
	_ok("day info has the health fields (empty with the health model off)", info.has("sore") and info.sore == 0
			and info.health.is_empty() and info.limited == false and info.tier == "")
	var report = Report.new()
	root.add_child(report)   # ReportView builds itself when it enters the tree
	_ok("Report builds", report.get_child_count() >= 3)
	report.queue_free()
	saves.save("ui")
	game.date = game.START_DATE.duplicate()
	_ok("load", saves.load_slot("ui"))
	_ok("the strip data comes back the same after save/load", week_json.call() == before)
	saves.delete("ui")
	strip.free()
	editor.free()
	card.free()


# --- Helpers -------------------------------------------------------------------------------------

func _new_career(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var answers := {}
	for q in game.get_node("/root/Data").background_questions:
		answers[q.id] = 0
	var a = load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)
	game.start_career(a, "repeat")


func _run_race() -> void:
	var rd = game.race_day
	while not rd.is_done():
		var race = rd.start_round(false, "pack")
		race.run()
		rd.finish_round()


func _mult(level: String, key: String) -> float:
	return float(game.get_node("/root/Data").health.intensity[level][key])


## Full-precision JSON, read back once (exactly, like a save) so ints and floats compare the same way.
func _json(v: Variant) -> String:
	var text := JSON.stringify(v, "", true, true)
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	return JSON.stringify(parsed, "", true, true)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1
