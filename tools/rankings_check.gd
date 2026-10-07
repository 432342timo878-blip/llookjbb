extends SceneTree
## Dev tool: plays 40 weeks (no races entered) and prints the season ranking, to check the list fills up.
## Run: godot --headless --path . -s res://tools/rankings_check.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"   # never touch the user's real saves
	var factory = load("res://scripts/core/athlete_factory.gd")
	var rankings = load("res://scripts/core/rankings.gd")
	var Cal = load("res://scripts/core/calendar.gd")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a = factory.create({"first_name": "Test", "last_name": "Runner", "gender": "male", "club_id": "",
			"hometown": "Oulu", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
			"answers": {}}, rng)
	game.start_career(a, "repeat")
	for w in 40:
		var result: String = game.advance_week()
		while result == game.STOP:   # a health stop event (random): answer it, or the date never moves on
			game.answer_event(game.pending_event().id, "ok")
			result = game.advance_week()
		if w in [3, 15, 39]:
			var season: int = rankings.season_of(game.date)
			var rows: Array = rankings.season_list(game.athlete, game.rivals, season)
			print("--- week %d (%s), season %s: %d on the list" % [w + 1, Cal.format_day(game.date),
					rankings.season_label(season), rows.size()])
			for r in rows.slice(0, 5):
				print("%2d. %-22s %s" % [r.rank, r.name, Cal.format_time(r.time)])
	quit()
