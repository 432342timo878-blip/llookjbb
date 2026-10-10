extends SceneTree
## Dev tool (fix session 2026-10-10): checks the Dev menu and what is behind it (DevTools).
##   - the menu opens, its jump buttons are disabled without a career, "Start test race" makes a test career and opens the race
##   - a test career is never saved (the player's autosave file stays byte for byte as it was; no snapshot file appears), the
##     health model is off in it, and a new or loaded career ends test mode (saving works again, the health model is on)
##   - a jump plays the career to a date (or stops at a race day / a stop event) and saves once
## Run: godot --headless --path . -s res://tools/dev_menu_check.gd
## Saves go to user://tool_saves/, never over the player's own. Read stderr too (a SCRIPT ERROR may not show in the result).

var _fails := 0
var _checks := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var SG = load("res://scripts/core/save_game.gd")
	SG.DIR = "user://tool_saves/"
	var DT = load("res://scripts/core/dev_tools.gd")
	var Health = load("res://scripts/core/health_system.gd")
	await _frames(10)
	var main := current_scene
	var router = main.get_node("/root/Router")
	var game = main.get_node("/root/Game")
	_ok(DT.available(), "the Dev menu is available in a debug build")

	# 1. The menu, without a career
	router.go("dev_menu")
	await _frames(5)
	var screen: Control = main.get_node("ScreenHost").get_child(-1)
	_ok(screen.get_script().resource_path.ends_with("dev_menu.gd"), "the dev menu screen opens")
	var jump_buttons := _buttons(screen).filter(func(b): return b.text.begins_with("To "))
	_ok(jump_buttons.size() >= 6, "the menu offers the next race day and 5+ dates (got %d)" % jump_buttons.size())
	_ok(game.athlete == null and jump_buttons.all(func(b): return b.disabled), "the jump buttons are disabled without a career")

	# 2. A real career whose autosave must stay as it is
	game.autosave = true
	var athlete = load("res://scripts/core/athlete_factory.gd").create({"first_name": "Real", "last_name": "Career", "gender": "male",
			"hometown": "Sastamala", "club_id": "", "main_event": "800m", "answers": {}, "birth_date": {"year": 2012, "month": 3, "day": 14}},
			_rng(5))
	game.start_career(athlete, "repeat")
	var auto_path: String = SG.DIR + "autosave.json"
	var before := FileAccess.get_file_as_string(auto_path)
	_ok(before != "", "a real career wrote an autosave")
	var files_before := DirAccess.get_files_at(SG.DIR).size()

	# 3. The test race through the menu buttons (indoor, any), then the other mix straight through DevTools
	router.go("dev_menu")
	await _frames(5)
	screen = main.get_node("ScreenHost").get_child(-1)
	_ok(not _buttons(screen).filter(func(b): return b.text.begins_with("To ")).any(func(b): return b.disabled),
			"the jump buttons work with a career open")
	var start: Button = _buttons(screen).filter(func(b): return b.text == "Start test race")[0]
	start.pressed.emit()
	await _frames(4)   # (the race is made between frames; the screen changes when it is done)
	var waited := 0
	while not game.dev_test and waited < 600:
		await _frames(5)
		waited += 5
	await _frames(10)
	_ok(game.dev_test, "Start test race makes a test career")
	_ok(game.race_day != null and game.race_day.meet.get("indoor", false), "the test race is an indoor race (the default pick)")
	_ok(main.get_node("ScreenHost").get_child(-1).get_script().resource_path.ends_with("race_screen.gd"), "the race screen is open")
	_ok(not Health.model_enabled, "the health model is off in a test career")
	_ok(FileAccess.get_file_as_string(auto_path) == before, "the player's autosave is untouched by the test career")
	SG.save_snapshot()
	_ok(DirAccess.get_files_at(SG.DIR).size() == files_before, "a snapshot of a test career writes no file")

	var res: Dictionary = DT.start_test_race({"indoor": false, "round": "", "level": "national", "female": true})
	_ok(res.ok, "an outdoor national test race for a girl is found: %s" % res.message)
	if res.ok:
		_ok(not game.race_day.meet.get("indoor", false) and str(game.race_day.meet.level) == "national", "it is outdoor and national")
		_ok(game.athlete.gender == "female", "the test runner is a girl")
	res = DT.start_test_race({"indoor": true, "round": "heats", "level": ""})
	_ok(res.ok and game.race_day.format == "heats", "a heats race is found (forced): %s" % res.message)
	_ok(game.race_day.rounds.size() >= 2 or game.race_day.format == "single", "heats have rounds")
	_ok(load("res://scripts/core/race_day.gd").format_override == "", "the forced format is switched off again")
	_ok(FileAccess.get_file_as_string(auto_path) == before, "the autosave is still untouched after more test careers")

	# 4. A jump on the test career is not saved either; then a real career ends test mode
	game.race_day = null
	var today_before: Dictionary = game.date.duplicate()
	var jump: Dictionary = DT.jump(DT.next_first_of(12))
	_ok(int(jump.days) > 0 or jump.result in [game.RACE, game.STOP], "a jump plays days (%d, %s)" % [jump.days, jump.result])
	_ok(FileAccess.get_file_as_string(auto_path) == before, "a jump in a test career writes no autosave")
	game.start_career(athlete, "repeat")
	_ok(not game.dev_test and Health.model_enabled, "a new career ends test mode: saving and the health model are back")
	_ok(FileAccess.get_file_as_string(auto_path) != before, "...and its autosave is written again")

	# 5. A jump in a real career: to a date, one autosave at the end
	var target: Dictionary = DT.next_first_of(1)   # (1 Jan 2027 from 2 Nov 2026)
	_ok(int(target.year) == 2027 and int(target.month) == 1, "the next 1 January from 2 Nov 2026 is in 2027 (%s)" % [target])
	jump = DT.jump(target)
	if jump.result in [game.DAY_DONE, game.WEEK_DONE]:
		_ok(game.date.year == 2027 and game.date.month == 1 and game.date.day == 1, "a jump to 1 Jan ends on 1 Jan (today %s)" % [game.date])
	else:
		_ok(jump.result in [game.RACE, game.STOP], "a jump ends early only at a race or a stop event (%s)" % jump.result)
	var saved := FileAccess.get_file_as_string(auto_path)
	_ok(saved.contains("\"year\": %d" % int(game.date.year)), "the jump saved the career once at the end")
	jump = DT.jump({})
	_ok(jump.result in [game.RACE, game.STOP] or int(jump.days) == 800, "a jump with no date goes to a race day, a stop event, or the 800-day limit (%s, %d days)" % [jump.result, jump.days])

	print("")
	print("dev_menu_check: %d checks, %d failed -> %s" % [_checks, _fails, "ALL CHECKS PASSED" if _fails == 0 else "SOME CHECKS FAILED"])
	quit()


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _buttons(node: Node) -> Array:
	var out := []
	if node is Button and (node as Control).is_visible_in_tree():
		out.append(node)
	for c in node.get_children():
		out.append_array(_buttons(c))
	return out
