extends SceneTree
## Dev tool: the spread of starting athletes from character creation (GDD 4.1.1).
## N random 14-year-olds (random background answers, boys and girls alternating, seed 1000 + i), each spent four
## ways: no points, the coach's spread (AthleteFactory.coach_spread when it exists, else the same rule here: by 800 m
## weight, +cap each), all points into mental attributes, and (pool) the size of the pool. Prints attribute means,
## 800 m ability, the 800 m time it gives and where that sits in the rival pool at the start (Data.races.rivals).
## Run: godot --headless --path . -s res://tools/start_spread.gd [-- <athletes, default 500>]

var F
var RP
var data


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	RP = load("res://scripts/core/race_performance.gd")
	data = root.get_node("/root/Data")
	var n := 500
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var methods := []
	for m in F.get_script_method_list():
		methods.append(m.name)
	var has_pool: bool = "pool_for" in methods
	print("start_spread: %d athletes, factory %s" % [n, "with a points pool" if has_pool else "with the fixed 12 points"])

	var spends := ["none", "coach", "mental"]
	var ab := {}
	var times := {"male": {}, "female": {}}
	for s in spends:
		ab[s] = []
		times.male[s] = []
		times.female[s] = []
	var cat_sum := {"physical": 0.0, "technical": 0.0, "mental": 0.0}
	var cat_n := {"physical": 0, "technical": 0, "mental": 0}
	var pools := []
	var trainability := []
	var potential := []
	var by_pool := {}   # pool size -> [abilities with the coach's spread]
	var by_pool_tr := {}
	for i in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var answers := {}
		for q in data.background_questions:
			answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
		var gender := "male" if i % 2 == 0 else "female"
		var choices := {"first_name": "Test", "last_name": "Runner%d" % i, "gender": gender, "hometown": "Tampere",
				"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": rng.randi_range(1, 10),
				"day": rng.randi_range(1, 28)}, "answers": answers}
		var pool: int = F.pool_for(answers) if has_pool else 12
		pools.append(pool)
		for s in spends:
			var r2 := RandomNumberGenerator.new()
			r2.seed = 1000 + i
			var a = F.create(choices, r2)
			var pts := {}
			if s == "coach":
				pts = F.coach_spread(a, pool) if "coach_spread" in methods else _coach_spread(a, pool)
			elif s == "mental":
				pts = _spread(a, pool, ["determination", "race_tactics", "pain_tolerance", "professionalism", "composure"])
			for id in pts:
				a.set_attr(id, a.get_attr(id) + pts[id])
			var x: float = RP.ability(a)
			ab[s].append(x)
			times[gender][s].append(RP.time_for(x, gender))
			if s == "coach":
				for c in cat_sum:
					for attr in data.attributes_in(c):
						cat_sum[c] += a.get_attr(attr.id)
						cat_n[c] += 1
				trainability.append(a.get_attr("trainability"))
				potential.append(a.get_attr("potential"))
				if not by_pool.has(pool):
					by_pool[pool] = []
					by_pool_tr[pool] = []
				by_pool[pool].append(x)
				by_pool_tr[pool].append(a.get_attr("trainability"))

	pools.sort()
	print("pool: min %d  p25 %d  median %d  p75 %d  max %d  mean %.2f" % [pools[0], _q(pools, 0.25), _q(pools, 0.5),
			_q(pools, 0.75), pools[-1], _mean(pools)])
	print("attribute means (coach's spread): physical %.2f  technical %.2f  mental %.2f" % [
			cat_sum.physical / cat_n.physical, cat_sum.technical / cat_n.technical, cat_sum.mental / cat_n.mental])
	trainability.sort()
	potential.sort()
	print("trainability: p5 %.1f  median %.1f  p95 %.1f   potential: p5 %.1f  median %.1f  p95 %.1f  max %.1f" % [
			_q(trainability, 0.05), _q(trainability, 0.5), _q(trainability, 0.95),
			_q(potential, 0.05), _q(potential, 0.5), _q(potential, 0.95), potential[-1]])
	var cfg: Dictionary = data.races.rivals
	print("rival pool at the start: ability N(%.1f, %.1f)" % [cfg.ability_mean, cfg.ability_sd])
	for s in spends:
		var v: Array = ab[s]
		v.sort()
		print("%-7s ability p5 %.2f  p25 %.2f  median %.2f  p75 %.2f  p95 %.2f   rival percentile at p25/median/p75: %d / %d / %d" % [
				s, _q(v, 0.05), _q(v, 0.25), _q(v, 0.5), _q(v, 0.75), _q(v, 0.95),
				_pct(_q(v, 0.25), cfg), _pct(_q(v, 0.5), cfg), _pct(_q(v, 0.75), cfg)])
		for g in ["male", "female"]:
			var t: Array = times[g][s]
			t.sort()
			print("          %-6s 800 m: fastest 5 %% %s  p25 %s  median %s  p75 %s  slowest 5 %% %s" % [g,
					_fmt(_q(t, 0.05)), _fmt(_q(t, 0.25)), _fmt(_q(t, 0.5)), _fmt(_q(t, 0.75)), _fmt(_q(t, 0.95))])
	if has_pool:
		print("by pool size (coach's spread): pool  athletes  median ability  rival percentile  median trainability")
		var keys := by_pool.keys()
		keys.sort()
		for k in keys:
			var v: Array = by_pool[k]
			v.sort()
			var tr: Array = by_pool_tr[k]
			tr.sort()
			print("                                %2d  %8d  %15.2f  %16d  %19.1f" % [k, v.size(), _q(v, 0.5),
					_pct(_q(v, 0.5), cfg), _q(tr, 0.5)])
	_stories(methods, cfg)
	print("start_spread done")


## Three fixed stories, 200 rolls each, spent the coach's way: median ability, percentile, boys' time, trainability.
func _stories(methods: Array, cfg: Dictionary) -> void:
	var stories := {
		"beginner": ["Never really exercised", "Nobody, it was your own idea", "Not sporty at all", "Nowhere yet",
				"About average", "No idea, I've never raced", "Doing fine"],
		"average": ["Football", "Friends from school", "Sporty family, recreational level", "A small-town outdoor track",
				"About average", "Feel nervous but manage it", "Doing fine"],
		"trained": ["Athletics school since I was little", "Your parents signed you up", "A parent competed in athletics",
				"A big club with an indoor hall", "About average", "Feel nervous but manage it", "Doing fine"],
	}
	print("fixed stories (200 rolls each, coach's spread): story  pool  median ability  rival percentile  boys' 800 m  trainability")
	for name in stories:
		var answers := {}
		for q in data.background_questions:
			for k in q.answers.size():
				if q.answers[k].text in stories[name]:
					answers[q.id] = k
		var pool: int = F.pool_for(answers) if "pool_for" in methods else 12
		var v := []
		var tr := []
		for i in 200:
			var rng := RandomNumberGenerator.new()
			rng.seed = 5000 + i
			var a = F.create({"first_name": "T", "last_name": "R", "gender": "male", "hometown": "Tampere", "club_id": "tap",
					"main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1}, "answers": answers}, rng)
			var pts: Dictionary = F.coach_spread(a, pool) if "coach_spread" in methods else _coach_spread(a, pool)
			for id in pts:
				a.set_attr(id, a.get_attr(id) + pts[id])
			v.append(RP.ability(a))
			tr.append(a.get_attr("trainability"))
		v.sort()
		tr.sort()
		print("  %-9s %4d  %15.2f  %16d  %11s  %12.1f" % [name, pool, _q(v, 0.5), _pct(_q(v, 0.5), cfg),
				_fmt(RP.time_for(_q(v, 0.5), "male")), _q(tr, 0.5)])
	quit()


## The coach's rule (same as AthleteFactory.coach_spread): the attributes that count most for the 800 m first, +cap each.
func _coach_spread(a, pool: int) -> Dictionary:
	var ids := []
	for id in data.races.ability_weights:
		if not str(id).begins_with("_"):
			ids.append(id)
	ids.sort_custom(func(x, y): return float(data.races.ability_weights[x]) > float(data.races.ability_weights[y]))
	return _spread(a, pool, ids)


func _spread(a, pool: int, ids: Array) -> Dictionary:
	var pts := {}
	var left := pool
	for id in ids:
		var add := mini(mini(3, left), int(floor(20.0 - a.get_attr(id))))
		if add > 0:
			pts[id] = add
			left -= add
	return pts


func _q(v: Array, p: float):
	return v[clampi(int(p * (v.size() - 1) + 0.5), 0, v.size() - 1)]


func _mean(v: Array) -> float:
	var s := 0.0
	for x in v:
		s += float(x)
	return s / v.size()


## Percentile of `x` in the rival pool's normal distribution.
func _pct(x: float, cfg: Dictionary) -> int:
	var z := (x - float(cfg.ability_mean)) / float(cfg.ability_sd)
	return roundi(100.0 * 0.5 * (1.0 + _erf(z / sqrt(2.0))))


func _erf(x: float) -> float:
	# Abramowitz-Stegun 7.1.26
	var t := 1.0 / (1.0 + 0.3275911 * absf(x))
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
	return y if x >= 0.0 else -y


func _fmt(sec: float) -> String:
	return "%d:%05.2f" % [int(sec) / 60, fmod(sec, 60.0)]
