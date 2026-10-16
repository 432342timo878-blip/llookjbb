extends SceneTree
## Dev tool: a fingerprint of races (session C5: "quick mode unchanged with the club coach"). 40 quick races and 20 watched races
## (answered with the sensible answers) with fixed fields and dice, over all three plans and several meet mixes, printed as one
## hash of every finishing order and time. An engine change that must not change the races (the coach's shouts, his advice) leaves
## the hash the same: run it before and after (e.g. on a git worktree of the last commit).
## Run: godot --headless --path . -s res://tools/quick_fingerprint.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var RaceS = load("res://scripts/core/race.gd")
	var rows := []
	var mixes := ["local", "district", "heat", "final", "chase"]
	for i in 60:
		var watched := i >= 40
		var frng := RandomNumberGenerator.new()
		frng.seed = 11000 + i
		var n := 8 + i % 5
		var entrants := []
		for k in n - 1:
			var ab: float = 9.0 + frng.randfn(0.0, 0.6)
			entrants.append({"name": "Rival R%d" % k, "club": "", "ability": ab, "speed": ab + frng.randfn(0.0, 2.0),
					"anaerobic": frng.randfn(0.0, 2.0), "tactics": clampf(frng.randfn(8.0, 3.0), 1.0, 20.0),
					"consistency": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0), "composure": 10.0,
					"competitiveness": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0)})
		var pa: float = 9.0 + frng.randfn(0.0, 0.8)
		entrants.append({"name": "You Player", "club": "", "ability": pa, "speed": pa, "anaerobic": frng.randfn(0.0, 2.0), "tactics": 10.0,
				"consistency": 10.0, "composure": 10.0, "determination": 10.0, "is_player": true})
		var rng := RandomNumberGenerator.new()
		rng.seed = 21000 + i
		var race = RaceS.new()
		race.interactive = watched
		race.setup(entrants, "male" if i % 2 == 0 else "female", i % 3 == 0, 10.0, rng, i % 4 == 0, mixes[i % mixes.size()])
		race.coach_id = ["calm", "drill", "warm", "tactician"][i % 4]
		race.set_player_plan(["front", "pack", "back"][i % 3])
		if watched:
			var guard := 0
			while not race.finished and race.time < 400.0 and guard < 20000:
				guard += 1
				if not race.pending.is_empty():
					race.choose(race.sensible_choice(race.pending.id))
					continue
				race.step()
		else:
			race.run()
		var res: Array = race.results()
		rows.append(res.map(func(r): return "%s %.3f" % [str(r.name), float(r.time)]))
	var all := JSON.stringify(rows)
	print("races fingerprint: ", all.md5_text(), " (", rows.size(), " races)")
	quit()
