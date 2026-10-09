extends SceneTree
## Dev tool: are moves decisive? (GDD 4.3.1 decision 23, step R5)
## Run: godot --headless --path . -s res://tools/race_moves.gd [-- races [row 0-3 | all]]
## Rival-only races (no player), like race_shape.gd. For every surge ("move" event) the runners who reacted to it
## (cover / let go events right after it) are recorded with:
##   - the mover's edge over that runner: the reserve share left at the move (mover - runner), the kick speed
##     (mover / runner - 1) and the day's even speed (mover / runner - 1);
##   - whether the mover finished ahead of them.
## Part 1 (observed): how often the mover finished ahead of those who let it go and of those who covered it.
## Part 2 (what covering is worth): the race played again twice from the same field and dice with that runner
## scripted to cover every move (script cover 1) and to let every move go (script cover 0). Prints the runner's
## time and place, covering minus letting go (negative = covering pays), and how often the mover finished ahead
## of them either way, by the mover's edge: "mover stronger" = the mover's even speed for the day is higher.

const ROWS := [
	# name, gender, ability, field sd, mix, consistency mean
	["youth championship final", "male", 9.0, 0.5, "final", 9.0],
	["tight final (sd 0.3)", "male", 9.0, 0.3, "final", 9.0],
	["youth even field", "male", 7.0, 0.8, "district", 9.0],
	["senior national final", "male", 15.0, 0.4, "final", 9.0],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := 100
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var rows := ROWS
	if args.size() > 1 and args[1] != "all":
		rows = [ROWS[int(args[1])]]
	for row in rows:
		_row(row, n)
	quit()


func _field(row: Array, i: int) -> Array:
	var frng := RandomNumberGenerator.new()
	frng.seed = 1000 + i
	var out := []
	for k in 8:
		var ab: float = row[2] + frng.randfn(0, row[3])
		out.append({"name": "R%d" % k, "club": "", "ability": ab, "speed": ab + frng.randfn(0, 2),
				"anaerobic": frng.randfn(0, 2), "tactics": clampf(frng.randfn(8.0, 3.0), 1.0, 20.0),
				"consistency": clampf(frng.randfn(row[5], 3.0), 1.0, 20.0), "composure": 10.0,
				"competitiveness": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0)})
	return out


## One race; `script_of` = {runner index: script}. Returns the race (finished).
func _race(row: Array, i: int, script_of := {}):
	var RaceScript = load("res://scripts/core/race.gd")
	var f := _field(row, i)
	for k in script_of:
		f[k]["script"] = script_of[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + i
	var race = RaceScript.new()
	race.setup(f, row[1], false, 20.0, rng, false, row[4])
	# The mover's and reactors' state at each move, taken when the move event appears.
	var seen := 0
	var snaps := []   # {mover, d, reactors: [{i, way, share}], mover_share}
	while not race.finished and race.time < 400.0:
		race.step()
		for k in range(seen, race.events.size()):
			var ev: Dictionary = race.events[k]
			if ev.type == "move":
				var m = race.runners[ev.i]
				snaps.append({"mover": ev.i, "d": float(ev.d), "mover_share": m.dleft / m.dprime, "reactors": []})
			elif ev.type in ["cover", "let_go"] and not ev.get("kick", false) and not snaps.is_empty():
				var o = race.runners[ev.i]
				var last: Dictionary = snaps[-1]
				if race.runners[last.mover].name == ev.of:
					last.reactors.append({"i": ev.i, "way": ev.type, "share": o.dleft / o.dprime})
		seen = race.events.size()
	race.set_meta("snaps", snaps)
	return race


func _place(race, idx: int) -> int:
	var res: Array = race.results()
	var name: String = race.runners[idx].name
	for k in res.size():
		if res[k].name == name:
			return k + 1
	return res.size()


func _row(row: Array, n: int) -> void:
	print("== %s, %d races" % [row[0], n])
	# Part 1: observed.
	var obs := {}   # bucket -> {way -> [ahead, total]}
	var cf := {}    # bucket -> {n, dt, dp, ahead_cover, ahead_let}
	var moves := 0
	var reacts := 0
	for i in n:
		var race = _race(row, i)
		var snaps: Array = race.get_meta("snaps")
		moves += snaps.size()
		for s in snaps:
			var m = race.runners[s.mover]
			for rc in s.reactors:
				reacts += 1
				var o = race.runners[rc.i]
				var ahead := _place(race, s.mover) < _place(race, rc.i)
				for b in _buckets(m, o, s, rc):
					var e: Dictionary = obs.get(b, {})
					var a: Array = e.get(rc.way, [0, 0])
					a[0] += 1 if ahead else 0
					a[1] += 1
					e[rc.way] = a
					obs[b] = e
		# Part 2: the first move with reactors: each reactor covers / lets go every move.
		for s in snaps:
			if s.reactors.is_empty():
				continue
			var m = race.runners[s.mover]
			for rc in s.reactors:
				var o = race.runners[rc.i]
				var rc_cover = _race(row, i, {rc.i: {"cover": 1.0}})
				var rc_let = _race(row, i, {rc.i: {"cover": 0.0}})
				var tc: float = rc_cover.runners[rc.i].t if rc_cover.runners[rc.i].status == "" else 0.0
				var tl: float = rc_let.runners[rc.i].t if rc_let.runners[rc.i].status == "" else 0.0
				for b in _buckets(m, o, s, rc):
					var e: Dictionary = cf.get(b, {"n": 0, "nt": 0, "dt": 0.0, "dp": 0.0, "ac": 0, "al": 0})
					e.n += 1
					if tc > 0.0 and tl > 0.0:
						e.nt += 1
						e.dt += tc - tl
					e.dp += _place(rc_cover, rc.i) - _place(rc_let, rc.i)
					e.ac += 1 if _place(rc_cover, s.mover) < _place(rc_cover, rc.i) else 0
					e.al += 1 if _place(rc_let, s.mover) < _place(rc_let, rc.i) else 0
					cf[b] = e
			break
	print("  %.2f moves per race, %.2f reactions per move" % [float(moves) / n, float(reacts) / maxf(moves, 1)])
	print("  observed: the mover finished ahead of those who let it go / covered it")
	for b in _order(obs.keys()):
		var e: Dictionary = obs[b]
		var lg: Array = e.get("let_go", [0, 0])
		var cv: Array = e.get("cover", [0, 0])
		print("    %-34s let go %3d %%  (%3d)   covered %3d %%  (%3d)" % [b, roundi(100.0 * lg[0] / maxf(lg[1], 1)), lg[1],
				roundi(100.0 * cv[0] / maxf(cv[1], 1)), cv[1]])
	print("  counterfactual: covering every move vs letting every move go (same field and dice), for the reactor")
	for b in _order(cf.keys()):
		var e: Dictionary = cf[b]
		print("    %-34s n %3d  cover - let go: time %+.2f s, place %+.2f   mover ahead: covered %3d %% / let go %3d %%" % [b,
				e.n, e.dt / maxf(e.nt, 1), e.dp / maxf(e.n, 1), roundi(100.0 * e.ac / maxf(e.n, 1)), roundi(100.0 * e.al / maxf(e.n, 1))])


## The buckets a reaction counts in: all, by distance to go, by the mover's edge in day ability, kick and reserve.
func _buckets(m, o, s: Dictionary, rc: Dictionary) -> Array:
	var out := ["all"]
	var to_go: float = 800.0 - s.d
	out.append("to go > 400 m" if to_go > 400.0 else ("to go 250-400 m" if to_go > 250.0 else "to go < 250 m"))
	var ab: float = m.even_v / o.even_v - 1.0
	out.append("mover stronger (day)" if ab > 0.0 else "mover weaker (day)")
	if absf(ab) <= 0.01:
		out.append("close (within 1 %)")
		out.append("close, mover stronger" if ab > 0.0 else "close, mover weaker")
	elif ab > 0.01:
		out.append("mover over 1 % stronger")
	else:
		out.append("mover over 1 % weaker")
	var kick: float = m.kick_v / o.kick_v - 1.0
	out.append("mover's kick better" if kick > 0.0 else "mover's kick worse")
	var res: float = s.mover_share - rc.share
	out.append("mover more reserve left" if res > 0.0 else "mover less reserve left")
	if ab > 0.0 and kick > 0.0:
		out.append("mover stronger + better kick")
	elif ab < 0.0 and kick < 0.0:
		out.append("mover weaker + worse kick")
	return out


func _order(keys: Array) -> Array:
	var order := ["all", "to go > 400 m", "to go 250-400 m", "to go < 250 m", "mover stronger (day)", "mover weaker (day)",
			"mover over 1 % stronger", "close (within 1 %)", "close, mover stronger", "close, mover weaker", "mover over 1 % weaker",
			"mover's kick better", "mover's kick worse", "mover more reserve left", "mover less reserve left",
			"mover stronger + better kick", "mover weaker + worse kick"]
	return order.filter(func(k): return keys.has(k))
