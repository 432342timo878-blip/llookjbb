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
	var days := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 10
	var game = root.get_node("Game")
	var saves = load("res://scripts/core/save_game.gd")
	saves.DIR = folder
	game.autosave = false
	# `real` (session L1a): the player's game (the coach's notes, moments waiting for Sunday, the school's decisions); else lab with
	# health on and everything free.
	if "real" in args:
		load("res://scripts/core/game_config.gd").use("real")
	else:
		load("res://scripts/core/game_config.gd").use("lab", {"health": true, "coach_neutral": false, "mind_neutral": false, "school_neutral": false})
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
		var planner = load("res://scripts/ui/week_planner.gd").new()   # (session L1a: the planner builds from an older save)
		root.add_child(planner)
		_ok("%s: the week planner builds (%d choices waiting)" % [slot, load("res://scripts/ui/week_planner.gd").open_choices().size()],
				planner.get_child_count() >= 1)
		planner.free()
		# Session L1b (save version 5): an older save's study effort / free time became the nearest habits; the Season tab shows them.
		var parsed_save: Dictionary = JSON.parse_string(text)
		var hs = game.get_system("habits")
		var school_state: Dictionary = parsed_save.get("game", {}).get("systems", {}).get("school", {})
		var effort := str(school_state.get("effort", "normal"))
		var free := str(school_state.get("free_time", "normal"))
		var habits_ok: bool = hs != null and hs.habits.size() == 7
		if version < 5 and hs != null:
			habits_ok = habits_ok and hs.habits == root.get_node("Data").habits.from_old["%s|%s" % [effort, free]]
		var section = load("res://scripts/ui/habits_ui.gd").section()
		_ok("%s: habits %s (the save's study effort %s / free time %s), the Season tab's section builds: %s" % [slot,
				hs.habits if hs != null else [], effort, free, hs.summary() if hs != null else "-"], habits_ok and section != null)
		if section != null:
			section.free()
		# Session L3b1 (save version 6): an older save's weekly mental plan became the same sessions on the plan's days.
		var old_plan: Array = parsed_save.get("game", {}).get("systems", {}).get("mind", {}).get("plan", [])
		var WPl = load("res://scripts/core/week_plan.gd")
		var on_days: Array = WPl.mental(game.season.week_for(game.week_monday()))
		var all_in := old_plan.all(func(k): return str(k) in on_days or str(k) in WPl.mental(game.season.week_for(game.add_days(game.week_monday(), 7))))
		_ok("%s: its mental plan %s is now sessions on the days (this week: %s)" % [slot, old_plan, on_days.filter(func(k): return k != "")],
				all_in and game.get_system("mind").legacy_plan.is_empty())
		var start: Dictionary = game.date.duplicate()
		var mode: String = game.season.mode
		var athlete: String = game.athlete.full_name()
		var played := 0
		# Session L2a: the days played include a race (one is entered when none is), and it ends with its card.
		var cal = load("res://scripts/core/calendar.gd")
		var has_race := false
		for m in cal.meets_between(game.date, game.add_days(game.date, days - 1)):
			has_race = has_race or m.key in game.entries
		var added := ""
		if not has_race and days >= 3:
			for m in cal.meets_between(game.add_days(game.date, 1), game.add_days(game.date, days - 2)):
				if cal.can_enter(game.athlete, m, game.date).ok:
					game.enter(m.key)
					added = str(m.name)
					break
		var cards_before: int = game.race_cards.size()
		var raced := 0
		for i in days:
			var r: String = game.advance_day()
			if r == game.RACE:
				var rd = game.race_day
				while not rd.is_done():
					var race = rd.start_round(false, "pack")
					race.run()
					rd.finish_round()
				r = game.finish_race()
				raced += 1
			while not game.pending_event().is_empty():
				var e: Dictionary = game.pending_event()
				var choice: String = e.choices[0].id if not e.choices.is_empty() else "ok"
				game.answer_event(e.id, choice)
			played += 1
		# Session L2b: the week report's causes build from an older save's first week (its days before the load were not recorded).
		var WC = load("res://scripts/ui/week_causes.gd")
		var crows: Array = WC.rows(game.last_report) if not game.last_report.is_empty() else []
		_ok("%s: the week report's causes build (%d rows; \"%s\")" % [slot, crows.size(), str(crows[0].title) + " " + str(crows[0].value) if not crows.is_empty() else "-"],
				crows.all(func(x): return str(x.title) != "" and str(x.detail) != ""))
		var week: Dictionary = game.season.week_for(game.week_monday())
		print("    %s: %s, %s → %s, mode %s, %d days played, plan has %d day entries" % [athlete,
				load("res://scripts/core/calendar.gd").format_day(start), version, load("res://scripts/core/calendar.gd").format_day(game.date),
				mode, played, week.days.size()])
		# Version 1–2 saves come back as repeat mode; version 3 (6a on) keeps its mode (a season plan since 6b).
		_ok("%s plays %d days (%s)" % [slot, days, "repeat mode" if version < 3 else mode],
				(mode == "repeat" or version >= 3) and played == days and week.days.size() == 7
				and (mode != "phases" or str(week.get("phase", "")) != ""))
		if days >= 3:
			# No race could be entered in those days (the season is over, nothing open): play on to the next one it can enter.
			var more := 0
			if raced == 0:
				for m in cal.meets_between(game.add_days(game.date, 1), game.add_days(game.date, 150)):
					if not m.key in game.entries and cal.can_enter(game.athlete, m, game.date).ok:
						game.enter(m.key)
						added = "%s, %s" % [m.name, cal.format_day(m.date)]
						break
				while raced == 0 and more < 160:
					more += 1
					var r2: String = game.advance_day()
					if r2 == game.RACE:
						var rd2 = game.race_day
						while not rd2.is_done():
							var race2 = rd2.start_round(false, "pack")
							race2.run()
							rd2.finish_round()
						game.finish_race()
						raced += 1
					while not game.pending_event().is_empty():
						var e2: Dictionary = game.pending_event()
						game.answer_event(e2.id, e2.choices[0].id if not e2.choices.is_empty() else "ok")
			_ok("%s: %d race(s)%s%s, each with its card (%d new)" % [slot, raced, " (entered %s)" % added if added != "" else "",
					" after %d more days" % more if more > 0 else "", game.race_cards.size() - cards_before],
					raced >= 1 and game.race_cards.size() - cards_before >= raced)
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1
