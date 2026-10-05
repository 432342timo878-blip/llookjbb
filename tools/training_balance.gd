extends SceneTree
## Dev tool: simulates a year of training with a few plans and prints the results, to tune the model.
## Run: godot --headless --path . -s res://tools/training_balance.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Loaded at runtime: autoload names (Data, Game) only exist once the tree is running.
	var T = load("res://scripts/core/training.gd")
	var F = load("res://scripts/core/athlete_factory.gd")
	var data = root.get_node("/root/Data")
	var game = root.get_node("/root/Game")
	var plans := {
		"coach": T.coach_plan(),
		"hard": [["intervals_800", "strength"], ["tempo_run", "drills"], ["long_run"], ["intervals_800", "hill_sprints"],
				["tempo_run"], ["long_run", "speed_strides"], ["fartlek"]],
		"lazy": [["easy_run"], [], [], ["easy_run"], [], [], []],
	}
	for plan_name in plans:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		var answers := {}
		for q in data.background_questions:
			answers[q.id] = 0
		var a = F.create({
			"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
			"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
			"answers": answers}, rng)
		var start := {}
		for id in ["aerobic_capacity", "lactate_threshold", "speed_endurance", "speed", "strength", "running_technique", "race_tactics"]:
			start[id] = a.get_attr(id)
		var date: Dictionary = game.START_DATE.duplicate()
		var peak := 0.0
		var fat_sum := 0.0
		for w in 52:
			var r: Dictionary = T.simulate_week(a, plans[plan_name], date)
			date = game.add_days(date, 7)
			peak = maxf(peak, r.fatigue_peak)
			fat_sum += r.fatigue_avg
		var line := "%-6s avg fatigue %3d peak %3d |" % [plan_name, roundi(fat_sum / 52), roundi(peak)]
		for id in start:
			line += " %s %.1f→%.1f" % [id.substr(0, 8), start[id], a.get_attr(id)]
		print(line)
	quit()
