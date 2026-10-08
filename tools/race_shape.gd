extends SceneTree
## Dev tool: how the field spreads out during an 800 m and how often the order changes late.
## Run: godot --headless --path . -s res://tools/race_shape.gd [-- races_per_row [rows, e.g. 2,5]]
##      godot --headless --path . -s res://tools/race_shape.gd -- races_per_delta duel[0.5|1|2]   (the duel rows)
## Prints per row: gap 1st-last and 1st-4th (metres) when the leader passes 200 / 400 / 600 m, runners within
## 5 m of the leader at 400 m, how often the leader at 400 / 600 m wins, pair swaps between the 600 m order and
## the finish (out of 28 pairs for 8 runners), the rank correlation of the 400 / 600 m order with the finish (real
## 2012 Olympic 800 m: 0.61 / 0.84, Renfree et al. 2014), winner's laps, the median finishing gaps 1st-2nd / 1st-4th /
## 1st-last finisher, the share of races won by under 0.2 s, and the median race time / time table time (rivals'
## off-screen races use the table, so this should stay near 1.00). A second line per row counts the R2 events:
## moves, covers, kick answers, boxes (and how they ended), contacts, stumbles, falls (and per runner-race), DNF, DQ.
## Real numbers to compare with: GDD 4.3.1 "Measured".
## Duel rows (GDD 4.3.1 "Upsets"): runner A is stronger than runner B by delta ability, in an even final of 8.
## Each race is run five times with the same field and dice: both neutral, A with a bad race (leads too fast /
## waits boxed at the back / kicks from 400 m) against B with a good race, and A with a good race. Prints how often
## B beats A and how much a bad race costs A against a good one (% of time, measured against the median time of the
## other six in the same race, since a scripted fast pace changes everyone's time).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	if args.size() > 2:   # tuning: numbers to try, e.g. `-- 100 5 kick_per_speed=0.005,box.gap=1.2,shapes.tactical.lap1=0.9|0.94`
		for pair in args[2].split(","):   # (paths start in races.json "engine" unless they start with shapes. / personalities.)
			var kv: PackedStringArray = pair.split("=")
			var path: PackedStringArray = kv[0].split(".")
			var node: Dictionary = root.get_node("Data").races
			if not path[0] in ["shapes", "personalities"]:
				node = node.engine
			for k in path.size() - 1:
				node = node[path[k]]
			if "|" in kv[1]:
				node[path[-1]] = Array(kv[1].split("|")).map(func(x): return float(x))
			else:
				node[path[-1]] = float(kv[1])
		print("overrides: ", args[2])
	if args.size() > 1 and args[1].begins_with("duel"):
		var deltas := [0.5, 1.0, 2.0]
		if args[1].length() > 4:
			deltas = [float(args[1].substr(4))]
		_duels(n, deltas)
		quit()
		return
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
		# (8th value: the field's mean consistency, default 9 like the rival pool)
		["senior final, consistent field", "male", false, 15.0, 0.25, true, "final", 13.0],
	]
	print("%-32s | %-18s | %-17s | %4s | %-9s | %5s | %-11s | %-11s | %-22s | %5s | %s" % ["row", "1st-last 200/400/600",
			"1st-4th", "pack", "lead wins", "swaps", "r 400/600", "winner laps", "median gaps 2nd/4th/last", "<0.2s", "time/table"])
	if args.size() > 1:   # only some rows, e.g. `-- 50 2,5` (0 = the first)
		var keep := []
		for k in args[1].split(","):
			keep.append(rows[int(k)])
		rows = keep
	for row in rows:
		_row(row, n)
	quit()


func _row(row: Array, n: int) -> void:
	var RaceScript = load("res://scripts/core/race.gd")
	var Perf = load("res://scripts/core/race_performance.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var acc := {"last": [0.0, 0.0, 0.0], "fourth": [0.0, 0.0, 0.0], "pack": 0.0, "w400": 0.0, "w600": 0.0,
			"swaps": 0.0, "lap1": 0.0, "lap2": 0.0, "photo": 0.0}
	var count := {}   # R2 event counts
	var g2 := []
	var g4 := []
	var glast := []
	var ratios := []
	var shapes := {}
	var runner_races := 0
	var box_secs := []
	var e2 := []   # the same gaps if everyone ran their even time for the day (no race tactics at all)
	var e4 := []
	var elast := []
	for i in n:
		var entrants := []
		for k in 8:
			var ab: float = row[3] + rng.randfn(0, row[4])
			entrants.append({"name": "R%d" % k, "club": "", "ability": ab,
					"speed": ab + rng.randfn(0, 2), "anaerobic": rng.randfn(0, 2),
					"tactics": clampf(rng.randfn(8.0, 3.0), 1.0, 20.0) if row[5] else 10.0,
					"consistency": clampf(rng.randfn(row[7] if row.size() > 7 else 9.0, 3.0), 1.0, 20.0) if row[5] \
							else (20.0 if row[4] == 0.0 else 10.0),
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
		runner_races += race.runners.size()
		var evens: Array = race.runners.map(func(r): return r.even_time)   # race-day ability (after form), no tactics
		evens.sort()
		e2.append(evens[1] - evens[0])
		e4.append(evens[3] - evens[0])
		elast.append(evens[-1] - evens[0])
		for ev in race.events:
			var key: String = ev.type
			if key == "escape":
				box_secs.append(float(ev.seconds))
				key = "escape_" + str(ev.way)
			count[key] = int(count.get(key, 0)) + 1
			if key == "kick" and ev.answer_to != "":
				count.answer = int(count.get("answer", 0)) + 1
			if key in ["contact", "fall"]:
				var w: String = "%s_%s" % [key, ev.get("where", "")]
				count[w] = int(count.get(w, 0)) + 1
		var res: Array = race.results()
		var fin_res: Array = res.filter(func(r): return r.status == "")
		var sh: Array = shapes.get(race.shape, [0, 0.0, 0.0, 0.0])
		sh[0] += 1   # races, winner's lap 1 and lap 2, 1st-4th finish gap
		sh[1] += res[0].split_400
		sh[2] += res[0].time - res[0].split_400
		sh[3] += fin_res[mini(3, fin_res.size() - 1)].time - res[0].time
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
		g2.append(fin_res[1].time - fin_res[0].time)
		g4.append(fin_res[mini(3, fin_res.size() - 1)].time - fin_res[0].time)
		glast.append(fin_res[-1].time - fin_res[0].time)
		if fin_res[1].time - fin_res[0].time < 0.2:
			acc.photo += 1.0
		# Race time against the time table for the runner's entry ability (rivals' off-screen races use the table).
		for k in entrants.size():
			for r in fin_res:
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
	print("    even-time gaps of the day's abilities (no tactics): %.1f / %.1f / %.1f s" % [_median(e2), _median(e4), _median(elast)])
	var falls := int(count.get("fall", 0)) + int(count.get("brought_down", 0))
	print("    per race: moves %.2f, covers %.2f, let go %.2f, kicks %.2f (answers %.2f), boxed %.2f (out by wait %.2f / ease %.2f / push %.2f), gaps opened %.2f" % [
			_per(count, "move", n), _per(count, "cover", n), _per(count, "let_go", n), _per(count, "kick", n),
			_per(count, "answer", n), _per(count, "boxed", n), _per(count, "escape_wait", n),
			_per(count, "escape_ease", n), _per(count, "escape_push", n), _per(count, "gap_opens", n)])
	print("    incidents in %d races: contacts %d, stumbles %d, falls %d (%d brought down), spiked %d, DNF %d, DQ %d; falls: 1 per %s runner-races" % [
			n, int(count.get("contact", 0)), int(count.get("stumble", 0)), falls, int(count.get("brought_down", 0)),
			int(count.get("spiked", 0)), int(count.get("dnf", 0)), int(count.get("dq", 0)),
			("%d" % roundi(float(runner_races) / falls)) if falls > 0 else "-"])
	var long_boxes := box_secs.filter(func(s): return s >= 2.0).size()
	print("    contacts at the break / swinging out / bends / straights / pushing: %d / %d / %d / %d / %d; falls %d / %d / %d / %d / %d; boxes lasting 2 s or more: %.2f per race (median box %.1f s)" % [
			int(count.get("contact_break", 0)), int(count.get("contact_swing", 0)), int(count.get("contact_bend", 0)),
			int(count.get("contact_straight", 0)), int(count.get("contact_push", 0)), int(count.get("fall_break", 0)),
			int(count.get("fall_swing", 0)), int(count.get("fall_bend", 0)), int(count.get("fall_straight", 0)),
			int(count.get("fall_push", 0)), float(long_boxes) / n, _median(box_secs) if not box_secs.is_empty() else 0.0])


## The duel rows (GDD 4.3.1 "Upsets").
func _duels(n: int, deltas: Array) -> void:
	var RaceScript = load("res://scripts/core/race.gd")
	var good := {"perfect": true, "want": "pack", "kick_at": 200.0, "box_way": "ease"}
	var configs := [
		# name, A's script, B's script
		["neutral", {}, {}],
		["leads too fast", {"want": "lead", "lead_pace": 1.07, "kick_at": 300.0}, good],
		["waits boxed", {"want": "back", "box_way": "wait", "kick_at": 120.0, "cover": 0.0, "answer": 0.0}, good],
		["kicks from 400", {"kick_at": 400.0, "answer": 1.0}, good],
		["A good", good, {}],
	]
	for delta in deltas:
		var beats := {}
		var a_times := {}
		var b_times := {}
		for c in configs:
			beats[c[0]] = 0
			a_times[c[0]] = []
			b_times[c[0]] = []
		for i in n:
			for c in configs:
				var rng := RandomNumberGenerator.new()
				rng.seed = 5000 + i
				var entrants := []
				for k in 6:
					var ab: float = 9.0 + delta / 2.0 + rng.randfn(0, 0.5)
					entrants.append({"name": "R%d" % k, "club": "", "ability": ab, "speed": ab + rng.randfn(0, 2),
							"anaerobic": rng.randfn(0, 2), "tactics": clampf(rng.randfn(8.0, 3.0), 1.0, 20.0),
							"consistency": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0), "composure": 10.0,
							"competitiveness": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0)})
				for who in [["A", 9.0 + delta, c[1]], ["B", 9.0, c[2]]]:
					entrants.append({"name": who[0], "club": "", "ability": who[1], "speed": who[1], "anaerobic": 0.0,
							"tactics": 10.0, "consistency": 10.0, "composure": 10.0, "competitiveness": 10.0,
							"personality": "pack", "script": who[2]})
				var race = RaceScript.new()
				race.setup(entrants, "male", false, 20.0, rng, false, "final")
				race.run()
				var res: Array = race.results()
				var ia := -1
				var ib := -1
				for k in res.size():
					if res[k].name == "A":
						ia = k
					elif res[k].name == "B":
						ib = k
				if ib < ia:
					beats[c[0]] += 1
				# Times relative to the median of the other six (a scripted pace changes everyone's time).
				var others: Array = res.filter(func(x): return x.status == "" and not x.name in ["A", "B"]).map(
						func(x): return x.time)
				var med := _median(others) if not others.is_empty() else 0.0
				a_times[c[0]].append(res[ia].time / med if res[ia].status == "" and med > 0.0 else 0.0)
				b_times[c[0]].append(res[ib].time / med if res[ib].status == "" and med > 0.0 else 0.0)
		var parts := []
		for c in configs:
			parts.append("%s %d%%" % [c[0], roundi(100.0 * beats[c[0]] / n)])
		print("delta %.1f: B beats A: %s" % [delta, ", ".join(parts)])
		var costs := []
		for c in configs.slice(1, 4):
			costs.append("%s %+.2f%%" % [c[0], _pct(a_times[c[0]], a_times["A good"])])
		print("    A's bad race vs A's good race (time): %s; A neutral vs good %+.2f%%; B good vs neutral %+.2f%%" % [
				", ".join(costs), _pct(a_times["neutral"], a_times["A good"]),
				_pct(b_times["leads too fast"], b_times["neutral"])])


## Mean of x / y - 1 in %, over the races where both have a time.
func _pct(x: Array, y: Array) -> float:
	var s := 0.0
	var k := 0
	for i in x.size():
		if x[i] > 0.0 and y[i] > 0.0:
			s += x[i] / y[i] - 1.0
			k += 1
	return 100.0 * s / maxf(k, 1)


func _per(count: Dictionary, key: String, n: int) -> float:
	return float(count.get(key, 0)) / n


func _median(values: Array) -> float:
	var v := values.duplicate()
	v.sort()
	return v[v.size() / 2] if v.size() % 2 == 1 else (v[v.size() / 2 - 1] + v[v.size() / 2]) / 2.0
