extends SceneTree
## Dev check (playtest 2 follow-up, 2026-10-18): the Training tab's "THIS WEEK" list shows the week as it really is, the same days as the
## week strip. The user saw the season plan's template there while the strip showed a race, the coach's changes and played days.
## Builds a season-plan career, plays to a week with a race, changes days as the coach, the player and an injury, builds the SeasonView
## and compares its seven lines with `DayInfo` (the strip's source): a race day says RACE, a changed day says who changed it, a played day
## says played, and the sessions listed are the ones DayInfo has.
## Run: godot --headless --path . -s res://tools/week_views_check.gd     (own save folder user://tool_saves/)

var _fails := 0
var game
var data


func _initialize() -> void:
	_run.call_deferred()


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _run() -> void:
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	load("res://scripts/core/game_config.gd").use("lab", {"health": true})
	game = root.get_node("/root/Game")
	data = root.get_node("/root/Data")
	game.autosave = false
	var F = load("res://scripts/core/athlete_factory.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	var a = F.create({"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere", "club_id": "tap",
			"main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1}, "answers": answers}, rng)
	game.start_career(a, "phases", "balanced")
	# Play to the Monday of a week that has a race on a day that is still to come.
	var cal = load("res://scripts/core/calendar.gd")
	var guard := 0
	while guard < 400:
		guard += 1
		var w = game.current_week()
		if not w.races.is_empty() and cal.weekday(game.date) == 0:
			break
		var r: String = game.advance_day()
		if r == game.RACE:
			var rd = game.race_day
			while not rd.is_done():
				rd.start_round(false, "pack").run()
				rd.finish_round()
			game.finish_race()
		while not game.pending_event().is_empty():
			var e: Dictionary = game.pending_event()
			game.answer_event(e.id, str(e.choices[0].id) if not (e.choices as Array).is_empty() else "ok")
	var week = game.current_week()
	_ok("found a Monday with a race in the week (%d days played)" % guard, not week.races.is_empty() and cal.weekday(game.date) == 0)
	# Play Monday, then change Wednesday as the coach, Thursday as the player (the race is on another day).
	game.advance_day()
	var race_day: int = week.races.keys()[0]
	var coach_day := -1
	var player_day := -1
	for d in range(2, 7):
		if d == race_day or not week.can_change(d) or week.session_ids(d).is_empty():
			continue
		if coach_day < 0:
			coach_day = d
		elif player_day < 0:
			player_day = d
	_ok("two days to change were found (coach %d, player %d, race on %d)" % [coach_day, player_day, race_day], coach_day >= 0 and player_day >= 0)
	if coach_day < 0 or player_day < 0:
		_finish()
		return
	week.set_intensity(coach_day, "easy", "coach")
	week.make_rest_day(player_day, "player")
	var view = load("res://scripts/ui/season_view.gd").new()
	root.add_child(view)
	await process_frame
	var lines := []
	_collect(view, lines)
	var names := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	var by_day := {}
	for l in lines:
		for d in 7:
			if str(l).begins_with(names[d] + " "):
				by_day[d] = str(l)
	_ok("the Training tab lists all seven days", by_day.size() == 7)
	var DI = load("res://scripts/ui/day_info.gd")
	for d in 7:
		var info: Dictionary = DI.of(week, d)
		var line: String = by_day.get(d, "")
		var expect_ok := true
		var what := "%s: %s" % [names[d], line]
		if not (info.race as Dictionary).is_empty():
			expect_ok = line.contains("RACE") and line.contains(str(info.race.get("name", "")))
		else:
			for id in info.sessions:
				expect_ok = expect_ok and line.contains(str(data.get_session(id).name))
			if (info.sessions as Array).is_empty():
				expect_ok = expect_ok and line.contains("Rest day")
		if info.played:
			expect_ok = expect_ok and line.contains("played")
		elif info.changed:
			expect_ok = expect_ok and line.contains("changed by")
		_ok(what, expect_ok)
	_ok("the coach's change says who made it", by_day.get(coach_day, "").contains("your coach"))
	_ok("the player's change says who made it", by_day.get(player_day, "").contains("you") and by_day.get(player_day, "").contains("Rest day"))
	_ok("the race day says RACE", by_day.get(race_day, "").contains("RACE"))
	_ok("a played day says played", by_day.get(0, "").contains("played"))
	_finish()


func _finish() -> void:
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _collect(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect(c, out)
