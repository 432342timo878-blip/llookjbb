extends SceneTree
## Dev tool (measuring only, no engine change): do surges and kicks pay off, and how much do heat runners ease off?
## Run: godot --headless --path . -s res://tools/race_surge_ease.gd [-- races [moves|ease|all [row]]]
## Rival-only races (no player), same field generator as race_moves.gd / race_shape.gd.
##
## Part A, moves and kicks. Every surge ("move" event) and every kick ("kick" event) is followed to the line:
##   p0 = the mover's place when it starts, best = the best place they reach after it, end = their finishing place.
##   gained = finished ahead of where they moved (end < p0); caught = reached a better place but lost it again
##   (end > best); won = won the race. Buckets by the mover's strength on the day (rank of their even speed in the
##   field, 1 = strongest) and by the distance to go. Kicks: the first kick of the race (nobody kicked before) apart
##   from the answers to a kick.
## Part B, heats easing. Each heat is run three times from the same field and dice: as a heat with N automatic
##   places (easing on), as the same heat with no automatic places (nobody eases: the cost of easing), and as a final
##   (the final's race-shape mix, no easing). Prints where easing starts (metres to go), what it costs the easers, how
##   often an easer drops out of the automatic places, and heat time vs the same runners in the final and vs their
##   ability on the day (time / even time).

const MOVE_ROWS := [
	# name, gender, ability, field sd, mix, consistency mean
	["youth championship final", "male", 9.0, 0.5, "final", 9.0],
	["tight final (sd 0.3)", "male", 9.0, 0.3, "final", 9.0],
	["youth even field (district)", "male", 7.0, 0.8, "district", 9.0],
	["senior national final", "male", 15.0, 0.4, "final", 9.0],
]

const EASE_ROWS := [
	# name, gender, ability, field sd, runners, indoor, automatic places
	["outdoor youth heat, 8 runners, 2 Q", "male", 9.0, 0.8, 8, false, 2],
	["outdoor youth heat, 8 runners, 3 Q (WA 2 heats)", "male", 9.0, 0.8, 8, false, 3],
	["indoor youth heat, 6 runners, 2 Q", "male", 9.0, 0.8, 6, true, 2],
	["girls outdoor heat, 8 runners, 2 Q", "female", 9.0, 0.8, 8, false, 2],
	["senior heat (Kalevan kisat), 8 runners, 3 Q", "male", 15.0, 0.6, 8, false, 3],
]

var RaceScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RaceScript = load("res://scripts/core/race.gd")
	var n := 200
	var part := "all"
	var only := -1
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	if args.size() > 1:
		part = args[1]
	if args.size() > 2:
		only = int(args[2])
	if part in ["moves", "all"]:
		for k in MOVE_ROWS.size():
			if only < 0 or only == k:
				_moves_row(MOVE_ROWS[k], n)
	if part in ["ease", "all"]:
		for k in EASE_ROWS.size():
			if only < 0 or only == k:
				_ease_row(EASE_ROWS[k], n)
	quit()


func _field(gender_ability: float, sd: float, size: int, cons: float, i: int) -> Array:
	var frng := RandomNumberGenerator.new()
	frng.seed = 1000 + i
	var out := []
	for k in size:
		var ab: float = gender_ability + frng.randfn(0, sd)
		out.append({"name": "R%d" % k, "club": "", "ability": ab, "speed": ab + frng.randfn(0, 2),
				"anaerobic": frng.randfn(0, 2), "tactics": clampf(frng.randfn(8.0, 3.0), 1.0, 20.0),
				"consistency": clampf(frng.randfn(cons, 3.0), 1.0, 20.0), "composure": 10.0,
				"competitiveness": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0)})
	return out


func _new_race(field: Array, gender: String, i: int, indoor: bool, mix: String, auto: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + i
	var race = RaceScript.new()
	race.setup(field, gender, false, 20.0, rng, indoor, mix)
	race.auto_places = auto
	return race


func _place_of(race, idx: int) -> int:
	var res: Array = race.results()
	var name: String = race.runners[idx].name
	for k in res.size():
		if res[k].name == name:
			return k + 1
	return res.size()


## Strength on the day: rank of the runner's even speed in the field (1 = strongest).
func _rank(race, idx: int) -> int:
	var v: float = race.runners[idx].even_v
	var rank := 1
	for r in race.runners:
		if r.even_v > v:
			rank += 1
	return rank


# ---------------------------------------------------------------- Part A: moves and kicks

func _moves_row(row: Array, n: int) -> void:
	print("== MOVES AND KICKS: %s, %d races" % [row[0], n])
	var surges := {}     # bucket -> [n, gained, caught, won, places gained sum]
	var first_k := {}
	var answers := {}
	for i in n:
		var race = _new_race(_field(row[2], row[3], 8, row[5], i), row[1], i, false, row[4], 0)
		var tracked := []   # {kind, i, p0, best, to_go}
		var seen := 0
		var kicked := false
		while not race.finished and race.time < 400.0:
			race.step()
			for k in range(seen, race.events.size()):
				var ev: Dictionary = race.events[k]
				if ev.type == "move":
					tracked.append({"kind": "surge", "i": int(ev.i), "p0": int(ev.pos), "best": int(ev.pos),
							"to_go": 800.0 - float(ev.d)})
				elif ev.type == "kick":
					var kind := "answer" if (kicked or String(ev.get("answer_to", "")) != "") else "first"
					kicked = true
					tracked.append({"kind": kind, "i": int(ev.i), "p0": int(ev.pos), "best": int(ev.pos),
							"to_go": float(ev.get("to_go", 800.0 - float(ev.d)))})
			seen = race.events.size()
			if not tracked.is_empty():
				var order: Array = race.standings()
				for tr in tracked:
					var pos: int = order.find(race.runners[tr.i]) + 1
					if pos > 0 and pos < tr.best:
						tr.best = pos
		for tr in tracked:
			var r = race.runners[tr.i]
			if r.status != "":
				continue
			var end := _place_of(race, tr.i)
			var rank := _rank(race, tr.i)
			var rb := "strongest on the day" if rank == 1 else ("2nd-3rd strongest" if rank <= 3 else (
					"4th-5th strongest" if rank <= 5 else "6th-8th strongest"))
			var db := ("to go > 400 m" if tr.to_go > 400.0 else ("to go 250-400 m" if tr.to_go > 250.0 else
					("to go 150-250 m" if tr.to_go > 150.0 else "to go < 150 m")))
			var target: Dictionary = surges if tr.kind == "surge" else (first_k if tr.kind == "first" else answers)
			for b in ["all", rb, db]:
				var a: Array = target.get(b, [0, 0, 0, 0, 0.0])
				a[0] += 1
				a[1] += 1 if end < tr.p0 else 0
				a[2] += 1 if end > tr.best else 0
				a[3] += 1 if end == 1 else 0
				a[4] += float(tr.p0 - end)
				target[b] = a
	_print_moves("surges (a rival's mid-race move)", surges, n)
	_print_moves("first kick of the race", first_k, n)
	_print_moves("answers to a kick (kicks after the first)", answers, n)


func _print_moves(title: String, data: Dictionary, n: int) -> void:
	var total: int = data.get("all", [0])[0]
	print("  %s: %.2f per race" % [title, float(total) / n])
	var order := ["all", "strongest on the day", "2nd-3rd strongest", "4th-5th strongest", "6th-8th strongest",
			"to go > 400 m", "to go 250-400 m", "to go 150-250 m", "to go < 150 m"]
	for b in order:
		if not data.has(b):
			continue
		var a: Array = data[b]
		var c: float = maxf(a[0], 1)
		print("    %-22s n %4d  gained places %3d %%  caught %3d %%  won %3d %%  places gained %+.2f" % [b, a[0],
				roundi(100.0 * a[1] / c), roundi(100.0 * a[2] / c), roundi(100.0 * a[3] / c), a[4] / c])


# ---------------------------------------------------------------- Part B: heats easing

func _ease_row(row: Array, n: int) -> void:
	print("== HEAT EASING: %s, %d heats" % [row[0], n])
	var auto: int = row[6]
	var heats_with_ease := 0
	var easers := 0
	var ease_to_go := []
	var cost := []          # seconds an easer lost (heat with easing - same heat without)
	var lost_q := 0         # easers who finished outside the automatic places
	var winner_eased := 0
	var w_heat_vs_none := []
	var w_heat_vs_final := []
	var w_heat_vs_even := []
	var w_none_vs_even := []
	var w_final_vs_even := []
	var q_heat_vs_even := []     # all automatic qualifiers: heat time / even time
	var q_final_vs_even := []
	var last_q_gap := []         # seconds from the last automatic place to the first runner outside it
	var last_q_gap_none := []
	for i in n:
		var field := _field(row[2], row[3], row[4], 9.0, i)
		var h = _new_race(field, row[1], i, row[5], "heat", auto)
		h.run()
		var h0 = _new_race(field, row[1], i, row[5], "heat", 0)
		h0.run()
		var f = _new_race(field, row[1], i, row[5], "final", 0)
		f.run()
		var eased := {}
		for ev in h.events:
			if ev.type == "ease":
				eased[int(ev.i)] = 800.0 - float(ev.d)
		if not eased.is_empty():
			heats_with_ease += 1
		for idx in eased:
			easers += 1
			ease_to_go.append(eased[idx])
			if h.runners[idx].status == "" and h0.runners[idx].status == "":
				cost.append(h.runners[idx].t - h0.runners[idx].t)
			if _place_of(h, idx) > auto:
				lost_q += 1
		var res_h: Array = h.results()
		var res_h0: Array = h0.results()
		if res_h.is_empty() or res_h[0].get("status", "") != "":
			continue
		var w: int = _index_of(h, res_h[0].name)
		if eased.has(w):
			winner_eased += 1
		var wr = h.runners[w]
		w_heat_vs_even.append(wr.t / wr.even_time)
		if h0.runners[w].status == "":
			w_heat_vs_none.append(wr.t - h0.runners[w].t)
		if f.runners[w].status == "":
			w_heat_vs_final.append(wr.t - f.runners[w].t)
			w_final_vs_even.append(f.runners[w].t / f.runners[w].even_time)
		if res_h0[0].get("status", "") == "":
			var w0 = h0.runners[_index_of(h0, res_h0[0].name)]
			w_none_vs_even.append(w0.t / w0.even_time)
		for k in mini(auto, res_h.size()):
			if res_h[k].get("status", "") != "":
				continue
			var q = h.runners[_index_of(h, res_h[k].name)]
			q_heat_vs_even.append(q.t / q.even_time)
			var qf = f.runners[q.index]
			if qf.status == "":
				q_final_vs_even.append(qf.t / qf.even_time)
		if res_h.size() > auto and res_h[auto].get("status", "") == "":
			last_q_gap.append(float(res_h[auto].time) - float(res_h[auto - 1].time))
		if res_h0.size() > auto and res_h0[auto].get("status", "") == "":
			last_q_gap_none.append(float(res_h0[auto].time) - float(res_h0[auto - 1].time))
	print("  heats where someone eased: %d %%; easers per heat %.2f (of %d automatic places)" % [
			roundi(100.0 * heats_with_ease / n), float(easers) / n, auto])
	print("  easing starts (metres to go): median %.0f, 10-90 %% %.0f-%.0f" % [_q(ease_to_go, 0.5), _q(ease_to_go, 0.1),
			_q(ease_to_go, 0.9)])
	print("  what easing costs an easer: median %+.2f s, mean %+.2f s, 90 %% under %+.2f s" % [_q(cost, 0.5), _mean(cost),
			_q(cost, 0.9)])
	print("  easers who dropped out of the automatic places: %d of %d" % [lost_q, easers])
	print("  heat winner eased: %d %% of heats" % roundi(100.0 * winner_eased / n))
	print("  heat winner: time with easing - same heat without: median %+.2f s, mean %+.2f s" % [_q(w_heat_vs_none, 0.5),
			_mean(w_heat_vs_none)])
	print("  heat winner: heat time - same runner in a final (final's shape mix): median %+.2f s, mean %+.2f s" % [
			_q(w_heat_vs_final, 0.5), _mean(w_heat_vs_final)])
	print("  heat winner: time / own even time on the day: heat %.4f, same heat without easing %.4f, final %.4f" % [
			_mean(w_heat_vs_even), _mean(w_none_vs_even), _mean(w_final_vs_even)])
	print("  automatic qualifiers: time / own even time: heat %.4f, same runners in a final %.4f" % [_mean(q_heat_vs_even),
			_mean(q_final_vs_even)])
	print("  gap last automatic place -> first outside: median %.2f s with easing, %.2f s without" % [_q(last_q_gap, 0.5),
			_q(last_q_gap_none, 0.5)])


func _index_of(race, name: String) -> int:
	for r in race.runners:
		if r.name == name:
			return r.index
	return 0


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()


func _q(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[clampi(roundi(q * (b.size() - 1)), 0, b.size() - 1)])
