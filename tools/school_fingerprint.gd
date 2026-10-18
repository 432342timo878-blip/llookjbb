extends SceneTree
## Dev tool (session S3b): a fingerprint of a whole grade 8-9 career at school, to prove that a school change leaves grades 8-9
## exactly as they were. Plays a 14-year-old from 2 Nov 2026 to 31 Jul 2028 (grade 8, grade 9, the application and its results)
## twice: the tools' way (no school stops) and the real game's way (SchoolSystem.decisions_enabled, every stop answered with its
## first choice), and prints a hash of the school state, the athlete and the day log of each. Run it on the old code and on the
## new: the two lines must be the same.
## Run: godot --headless --path . -s res://tools/school_fingerprint.gd      (~1-2 minutes; own save folder user://tool_saves/)

var game
var data


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	# Lab (no injuries, a club coach of 10s) with the school and the moods free: that is what the hashes were made with.
	load("res://scripts/core/game_config.gd").use("lab", {"school_neutral": false, "mind_neutral": false})
	game.autosave = false
	var SC = load("res://scripts/core/school_system.gd")
	var all := ""
	for mode in ["tools", "decisions"]:
		SC.decisions_enabled = mode == "decisions"
		for school_index in [0, 2]:
			game.start_career(_athlete(school_index), "repeat")
			var stops := 0
			var stop_key: int = 20280731
			while _key(game.date) < stop_key:
				game.advance_day()
				while not game.pending_event().is_empty():
					var e: Dictionary = game.pending_event()
					var choice := "ok"
					if str(e.source) == "school" and not (e.choices as Array).is_empty():
						choice = str(e.choices[0].id)
					stops += 1
					game.answer_event(e.id, choice)
			var school: Dictionary = game.get_system("school").to_dict()
			var text := JSON.stringify(school, "", true, true) + JSON.stringify(game.athlete.to_dict(), "", true, true) + JSON.stringify(game.day_log, "", true, true)
			print("school fingerprint %s answer %d: %s (%d stops, %d report cards)" % [mode, school_index, text.md5_text(), stops, (school.get("reports", []) as Array).size()])
			all += text.md5_text()
	print("school fingerprint all: %s" % all.md5_text())   # (the four above together: run_all_checks looks for this line)
	SC.decisions_enabled = false
	quit(0)


func _key(d: Dictionary) -> int:
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


func _athlete(school_index: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = school_index if str(q.id) == "school" else 0
	return load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)
