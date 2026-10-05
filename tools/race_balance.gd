extends SceneTree
## Dev tool: runs many quick 800 m races to check that times match the calibration anchors.
## Run: godot --headless --path . -s res://tools/race_balance.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var RaceScript = load("res://scripts/core/race.gd")
	var Perf = load("res://scripts/core/race_performance.gd")
	var cal = load("res://scripts/core/calendar.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for setup in [["female", false], ["male", false], ["male", true]]:
		var gender: String = setup[0]
		for ability in [5.0, 7.0, 9.0, 11.0, 13.0]:
			var sum_mid := 0.0
			var sum_win := 0.0
			var sum_split := 0.0
			var n := 12
			for i in n:
				var entrants := []
				for k in 8:
					entrants.append({"name": "R%d" % k, "club": "", "ability": ability + rng.randfn(0, 0.8),
							"speed": ability + rng.randfn(0, 2), "anaerobic": rng.randfn(0, 2),
							"tactics": 10.0, "consistency": 10.0, "composure": 10.0})
				var race = RaceScript.new()
				race.setup(entrants, gender, false, 20.0, rng, setup[1])
				var t0 := Time.get_ticks_msec()
				while not race.finished and race.time < 400.0:
					race.step()
				if not race.finished:
					for r in race.runners:
						print("STUCK d=%.1f v=%.2f lat=%.2f lat_t=%.2f dleft=%.1f cs=%.2f done=%s kick=%s" % [r.d, r.v, r.lat, r.lat_target, r.dleft, r.cs, r.done, r.kicking])
					quit()
					return
				var res: Array = race.results()
				sum_win += res[0].time
				sum_mid += (res[3].time + res[4].time) / 2.0
				sum_split += res[0].split_400
			print(("indoor " if setup[1] else "") + "%-6s ability %4.1f  target %s  median %s  winner %s  winner 400 split %s" % [gender, ability,
					cal.format_time(Perf.time_for(ability, gender)), cal.format_time(sum_mid / n),
					cal.format_time(sum_win / n), cal.format_time(sum_split / n)])
	quit()
