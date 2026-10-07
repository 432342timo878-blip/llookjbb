extends SceneTree
## Dev tool: how the field spreads out during an 800 m and how often the order changes late.
## Run: godot --headless --path . -s res://tools/race_shape.gd [-- races_per_row [rows, e.g. 2,5]]
## Prints per row: gap 1st-last and 1st-4th (metres) when the leader passes 200 / 400 / 600 m, runners within
## 5 m of the leader at 400 m, how often the leader at 400 / 600 m wins, pair swaps between the 600 m order and
## the finish (out of 28 pairs for 8 runners), the rank correlation of the 400 / 600 m order with the finish (real
## 2012 Olympic 800 m: 0.61 / 0.84, Renfree et al. 2014), winner's laps, the median finishing gaps 1st-2nd / 1st-4th /
## 1st-last, the share of races won by under 0.2 s, and the median race time / time table time (rivals' off-screen
## races use the table, so this should stay near 1.00). Real numbers to compare with: GDD 4.3.1 "Measured".


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var RaceScript = load("res://scripts/core/race.gd")
	var Perf = load("res://scripts/core/race_performance.gd")
	var n := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var rows := [
		# name, gender, indoor, ability, field spread (sd of ability), tactics like the rival pool, race-shape mix
		["youth even field (race_balance)", "male", false, 7.0, 0.8, false, ""],
		["youth local meet, wide field", "male", false, 7.0, 1.6, true, "local"],
		["youth championship final", "male", false, 9.0, 0.5, true, "final"],
		["youth indoor", "male", true, 7.0, 0.8, true, "district"],
		["girls even field", "female", false, 7.0, 0.8, true, "district"],
		["senior national final", "male", false, 15.0, 0.4, true, "final"],
		# Equal ability and consistency 20: what is left is the race shape, the places, drafting and kick timing.
		["identical runners", "male", false, 9.0, 0.0, false, "final"],
	]
	print("%-32s | %-18s | %-17s | %4s | %-9s | %5s | %-11s | %-11s | %-22s | %5s | %s" % ["row", "1st-last 200/400/600",
			"1st-4th", "pack", "lead wins", "swaps", "r 400/600", "winner laps", "median gaps 2nd/4th/last", "<0.2s", "time/table"])
	if args.size() > 1:   # only some rows, e.g. `-- 50 2,5` (0 = the first)
		var keep := []
		for k in args[1].split(","):
			keep.append(rows[int(k)])
		rows = keep
	for row in rows:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var acc := {"last": [0.0, 0.0, 0.0], "fourth": [0.0, 0.0, 0.0], "pack": 0.0, "w400": 0.0, "w600": 0.0,
				"swaps": 0.0, "lap1": 0.0, "lap2": 0.0, "photo": 0.0}
		var g2 := []
		var g4 := []
		var glast := []
		var ratios := []
		var shapes := {}
		for i in n:
			var entrants := []
			for k in 8:
				var ab: float = row[3] + rng.randfn(0, row[4])
				entrants.append({"name": "R%d" % k, "club": "", "ability": ab,
						"speed": ab + rng.randfn(0, 2), "anaerobic": rng.randfn(0, 2),
						"tactics": clampf(rng.randfn(8.0, 3.0), 1.0, 20.0) if row[5] else 10.0,
						"consistency": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0) if row[5] else (20.0 if row[4] == 0.0 else 10.0),
						"composure": 10.0, "competitiveness": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0) if row[5] else 10.0})
			var race = RaceScript.new()
			race.setup(entrants, row[1], false, 20.0, rng, row[2], row[6])
			var marks := [200.0, 400.0, 600.0]
			var orders := {}
			var mi := 0
			while not race.finished and race.time < 400.0:
				race.step()
				if mi < marks.size():
					var order: Array = race.standings()
					if order[0].d >= marks[mi]:
						var lead: float = order[0].d
						acc.last[mi] += lead - order[-1].d
						acc.fourth[mi] += lead - order[3].d
						if mi == 1:
							for r in order:
								if lead - r.d <= 5.0:
									acc.pack += 1.0
						orders[marks[mi]] = order.map(func(r): return r.name)
						mi += 1
			var res: Array = race.results()
			var sh: Array = shapes.get(race.shape, [0, 0.0, 0.0, 0.0])
			sh[0] += 1   # races, winner's lap 1 and lap 2, 1st-4th finish gap
			sh[1] += res[0].split_400
			sh[2] += res[0].time - res[0].split_400
			sh[3] += res[3].time - res[0].time
			shapes[race.shape] = sh
			var fin: Array = res.map(func(r): return r.name)
			if orders[400.0][0] == fin[0]:
				acc.w400 += 1.0
			if orders[600.0][0] == fin[0]:
				acc.w600 += 1.0
			# Rank correlation (Spearman) of the 400 m / 600 m order with the finish, as in Renfree et al. 2014.
			for m in [400.0, 600.0]:
				var dsq := 0.0
				for k in fin.size():
					dsq += pow(float(orders[m].find(fin[k]) - k), 2.0)
				acc["r%d" % int(m)] = acc.get("r%d" % int(m), 0.0) + 1.0 - 6.0 * dsq / (8.0 * 63.0)
			var o6: Array = orders[600.0]
			for a in o6.size():
				for b in range(a + 1, o6.size()):
					if fin.find(o6[a]) > fin.find(o6[b]):
						acc.swaps += 1.0
			acc.lap1 += res[0].split_400
			acc.lap2 += res[0].time - res[0].split_400
			g2.append(res[1].time - res[0].time)
			g4.append(res[3].time - res[0].time)
			glast.append(res[-1].time - res[0].time)
			if res[1].time - res[0].time < 0.2:
				acc.photo += 1.0
			# Race time against the time table for the runner's entry ability (rivals' off-screen races use the table).
			for k in entrants.size():
				for r in res:
					if r.name == entrants[k].name:
						ratios.append(r.time / Perf.time_for(entrants[k].ability, row[1]))
		print("%-32s | last %3.0f/%3.0f/%3.0f m | 4th %3.0f/%3.0f/%3.0f m | %4.1f | %3.0f%%/%3.0f%% | %5.1f | r %.2f/%.2f | %4.1f + %4.1f | %3.1f / %3.1f / %4.1f s | %3.0f%% | %.4f" % [
				row[0], acc.last[0] / n, acc.last[1] / n, acc.last[2] / n, acc.fourth[0] / n, acc.fourth[1] / n,
				acc.fourth[2] / n, acc.pack / n, acc.w400 / n * 100.0, acc.w600 / n * 100.0, acc.swaps / n,
				acc.r400 / n, acc.r600 / n, acc.lap1 / n, acc.lap2 / n, _median(g2), _median(g4), _median(glast),
				acc.photo / n * 100.0, _median(ratios)])
		var parts := []
		for k in shapes:
			var sh: Array = shapes[k]
			parts.append("%s %d%% (winner %.1f + %.1f, 1st-4th %.1f s)" % [k, roundi(100.0 * sh[0] / n),
					sh[1] / sh[0], sh[2] / sh[0], sh[3] / sh[0]])
		print("    shapes: ", ", ".join(parts))
	quit()


func _median(values: Array) -> float:
	var v := values.duplicate()
	v.sort()
	return v[v.size() / 2] if v.size() % 2 == 1 else (v[v.size() / 2 - 1] + v[v.size() / 2]) / 2.0
