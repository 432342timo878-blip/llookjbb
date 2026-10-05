extends SceneTree
## Dev tool: simulates a year of training with a few plans and prints the results, to tune the model.
## The "easy"/"hard" rows play the coach plan with every day at that intensity (day changes, data/health.json).
## Run: godot --headless --path . -s res://tools/training_balance.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Loaded at runtime: autoload names (Data, Game) only exist once the tree is running.
	var T = load("res://scripts/core/training.gd")
	var F = load("res://scripts/core/athlete_factory.gd")
	var W = load("res://scripts/core/week_sim.gd")
	var data = root.get_node("/root/Data")
	var game = root.get_node("/root/Game")
	var plans := {
		"coach": T.coach_plan(),
		"hard": [["intervals_800", "strength"], ["tempo_run", "drills"], ["long_run"], ["intervals_800", "hill_sprints"],
				["tempo_run"], ["long_run", "speed_strides"], ["fartlek"]],
		"lazy": [["easy_run"], [], [], ["easy_run"], [], [], []],
	}
	# [row name, plan, intensity for every day]
	var runs := [["coach", "coach", "normal"], ["hard", "hard", "normal"], ["lazy", "lazy", "normal"],
			["coach easy", "coach", "easy"], ["coach hard", "coach", "hard"]]
	for run in runs:
		var plan_name: String = run[0]
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
			var r: Dictionary
			if run[2] == "normal":
				r = T.simulate_week(a, plans[run[1]], date)
			else:
				var week = W.new(a, plans[run[1]], date)
				for d in 7:
					week.set_intensity(d, run[2])
				r = week.finish()
			date = game.add_days(date, 7)
			peak = maxf(peak, r.fatigue_peak)
			fat_sum += r.fatigue_avg
		var line := "%-10s avg fatigue %3d peak %3d |" % [plan_name, roundi(fat_sum / 52), roundi(peak)]
		for id in start:
			line += " %s %.1f→%.1f" % [id.substr(0, 8), start[id], a.get_attr(id)]
		print(line)
		# Full precision, to prove that an engine change leaves the results exactly the same.
		var total := 0.0
		for id in a.attributes:
			total += a.get_attr(id)
		print("           fingerprint: attributes %.9f fatigue %.9f fatigue-sum %.9f" % [total, a.fatigue, fat_sum])
	quit()
