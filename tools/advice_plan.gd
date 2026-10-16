extends SceneTree
## Dev tool: which pre-race plan (Lead / Sit in the pack / Wait at the back) is worth what, for which athlete? (session C5, GDD 4.9.2
## "Race advice by personality": the coach's advice is built on this measurement.)
## Every scenario is played with each plan on the SAME races (the same field and dice), as a quick result (the athlete answers the
## cards by race tactics 10, as quick mode does). Prints the mean place (1 = best) and the mean time per plan, and which plan was best.
## Run: godot --headless --path . -s res://tools/advice_plan.gd [-- races [mix [size [rows]]]]
##   races = races per plan and scenario (default 40); mix = local / district / heat / final / chase (default final);
##   size = runners in the race (default 8); rows = only the scenarios whose name contains this text.
## Scenarios: the player's ability against the field's mean (-1.5 / -0.5 / +0.5 / +1.5) x the player's anaerobic fitness (-3 / 0 / +3).

const PLANS := ["front", "pack", "back"]
const EDGES := [-1.5, -0.5, 0.5, 1.5]
const ANAEROBIC := [-3.0, 0.0, 3.0]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 40
	var mix: String = args[1] if args.size() > 1 else "final"
	var size := int(args[2]) if args.size() > 2 else 8
	var only: String = args[3] if args.size() > 3 else ""
	var t0 := Time.get_ticks_msec()
	print("quick races, mix %s, %d runners, %d races per plan and scenario" % [mix, size, n])
	print("%-26s %-22s %-22s %s" % ["scenario", "mean place (front / pack / back)", "mean time s", "best"])
	for edge in EDGES:
		for an in ANAEROBIC:
			var name := "edge %+.1f anaerobic %+d" % [edge, int(an)]
			if only != "" and not name.contains(only):
				continue
			var place := {}
			var time := {}
			for plan in PLANS:
				var p := 0.0
				var t := 0.0
				var fin := 0
				for i in n:
					var r := _play(i, plan, edge, an, mix, size)
					p += r.place
					if r.finished:
						t += r.time
						fin += 1
				place[plan] = p / n
				time[plan] = t / maxf(fin, 1)
			var best := PLANS[0]
			for plan in PLANS:
				if place[plan] < place[best]:
					best = plan
			print("%-26s %5.2f / %5.2f / %5.2f      %6.2f / %6.2f / %6.2f   %s" % [name, place.front, place.pack, place.back,
					time.front, time.pack, time.back, best])
	print("(%.0f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


## One quick race: a field of `size` (mean ability 9, spread 0.6) and the player `edge` better, with the plan.
func _play(i: int, plan: String, edge: float, anaerobic: float, mix: String, size: int) -> Dictionary:
	var RaceScript = load("res://scripts/core/race.gd")
	var frng := RandomNumberGenerator.new()
	frng.seed = 3000 + i
	var entrants := []
	for k in size - 1:
		var ab: float = 9.0 + frng.randfn(0.0, 0.6)
		entrants.append({"name": "Rival R%d" % k, "club": "", "ability": ab, "speed": ab + frng.randfn(0.0, 2.0),
				"anaerobic": frng.randfn(0.0, 2.0), "tactics": clampf(frng.randfn(8.0, 3.0), 1.0, 20.0),
				"consistency": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0), "composure": 10.0,
				"competitiveness": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0)})
	var pa: float = 9.0 + edge
	entrants.append({"name": "You Player", "club": "", "ability": pa, "speed": pa + anaerobic * 0.6, "anaerobic": anaerobic,
			"tactics": 10.0, "consistency": 10.0, "composure": 10.0, "determination": 10.0, "is_player": true})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + i
	var race = RaceScript.new()
	race.setup(entrants, "male", false, 10.0, rng, false, mix)
	race.set_player_plan(plan)
	race.run()
	var res: Array = race.results()
	var place := res.map(func(x): return x.is_player).find(true) + 1
	return {"time": race.player.t, "finished": race.player.status == "", "place": float(place)}
