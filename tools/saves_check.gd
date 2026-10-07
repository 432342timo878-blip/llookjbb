extends SceneTree
## Dev tool: loads every save in a folder of COPIES of the player's saves and plays a few days on each, to prove
## older saves still load and play (they come back as repeat mode). Never point it at the real saves folder:
## it autosaves into the folder it is given (switched off here, but copy first anyway).
## Run: godot --headless --path . -s res://tools/saves_check.gd -- <folder with copies of the .json saves> [days]
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <folder with copies of the saves> [days]")
		quit(1)
		return
	var folder: String = args[0].replace("\\", "/").trim_suffix("/") + "/"
	var days := int(args[1]) if args.size() > 1 else 10
	var game = root.get_node("Game")
	var saves = load("res://scripts/core/save_game.gd")
	saves.DIR = folder
	game.autosave = false
	load("res://scripts/core/health_system.gd").model_enabled = true   # the real game: health on
	var slots := []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".json"):
			slots.append(file.trim_suffix(".json"))
	_ok("found saves in %s: %d" % [folder, slots.size()], slots.size() > 0)
	for slot in slots:
		var text := FileAccess.get_file_as_string(folder + slot + ".json")
		var version := int(JSON.parse_string(text).get("version", 1))
		var loaded: bool = saves.load_slot(slot)
		_ok("%s (version %d) loads" % [slot, version], loaded)
		if not loaded:
			continue
		var start: Dictionary = game.date.duplicate()
		var mode: String = game.season.mode
		var athlete: String = game.athlete.full_name()
		var played := 0
		for i in days:
			var r: String = game.advance_day()
			if r == game.RACE:
				var rd = game.race_day
				while not rd.is_done():
					var race = rd.start_round(false, "pack")
					race.run()
					rd.finish_round()
				r = game.finish_race()
			while not game.pending_event().is_empty():
				var e: Dictionary = game.pending_event()
				var choice: String = e.choices[0].id if not e.choices.is_empty() else "ok"
				game.answer_event(e.id, choice)
			played += 1
		var week: Dictionary = game.season.week_for(game.week_monday())
		print("    %s: %s, %s → %s, mode %s, %d days played, plan has %d day entries" % [athlete,
				load("res://scripts/core/calendar.gd").format_day(start), version, load("res://scripts/core/calendar.gd").format_day(game.date),
				mode, played, week.days.size()])
		_ok("%s plays %d days in repeat mode" % [slot, days], mode == "repeat" and played == days and week.days.size() == 7)
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1
