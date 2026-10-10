extends SceneTree
## Dev tool: the rival pool's growth over 7 years (step 7). Makes N pools of 150 (Rivals.generate), trains them week
## by week with Rivals.train_week (the game's own rule, from data/races.json "rivals") and prints, per age class (the
## summer's), the pool's ability quantiles and the times of the 1st / 3rd / 8th / 20th / 50th / 75th best of the pool,
## with the real Finnish bands from GDD 4.2 "Multi-year check" next to them. Injuries and own races are not simulated
## (they hardly move the quantiles). Fast: ~1 s per pool.
## Run: godot --headless --path . -s res://tools/rival_curves.gd [-- pools [male|female|both] [key=value,...]]
## key=value overrides data/races.json "rivals" numbers for a what-if (e.g. ceiling_mean=11,ceiling_sd=2); arrays with |.

const AGES := [15, 16, 17, 18, 19, 20, 21]
## Real bands [low, high] in seconds for the 1st / 8th / 20th best of a birth year (GDD 4.2 "Multi-year check", sources there).
const REAL := {
	"male": {15: [[120, 126], [129, 135], [136, 143]], 16: [[117, 122], [125, 131], [132, 138]], 17: [[111, 117], [122, 127], [127, 133]],
			18: [[110, 115], [119, 124], [124, 130]], 19: [[109, 114], [118, 123], [122, 128]], 20: [[108, 113], [117, 121], [121, 127]],
			21: [[107, 112], [116, 120], [121, 127]]},
	"female": {15: [[131, 136], [140, 145], [146, 154]], 16: [[130, 135], [139, 145], [145, 153]], 17: [[129, 135], [138, 144], [144, 152]],
			18: [[128, 134], [137, 143], [143, 150]], 19: [[127, 133], [136, 142], [142, 149]], 20: [[126, 132], [135, 141], [141, 148]],
			21: [[125, 131], [134, 140], [140, 147]]},
}

var data
var RV
var RP


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	data = root.get_node("/root/Data")
	RV = load("res://scripts/core/rivals.gd")
	RP = load("res://scripts/core/race_performance.gd")
	var F = load("res://scripts/core/athlete_factory.gd")
	var args := OS.get_cmdline_user_args()
	var pools := int(args[0]) if args.size() > 0 else 20
	var genders := ["male", "female"] if args.size() < 2 or args[1] == "both" else [args[1]]
	if args.size() > 2:
		for kv in args[2].split(","):
			var p := kv.split("=")
			if p.size() == 2 and p[0].begins_with("growth_"):   # growth_male=14.5:0.6|16:0.4|...
				data.races.rivals.growth_by_age[p[0].trim_prefix("growth_")] = Array(p[1].split("|")).map(
						func(x): return [float(x.split(":")[0]), float(x.split(":")[1])])
			elif p.size() == 2:
				data.races.rivals[p[0]] = _value(p[1])
	var has_age := false   # (the rule before step 7 had no birth year)
	for m in RV.get_script_method_list():
		if m.name == "train_week":
			has_age = m.args.size() >= 4
	print("rival_curves: %d pools per gender, rivals = %s" % [pools, JSON.stringify(data.races.rivals)])
	for g in genders:
		var by_age := {}
		for age in AGES:
			by_age[age] = {"q": {}, "rank": {}}
		for k in pools:
			seed(500 + k)
			var a = F.create({"first_name": "T", "last_name": "R", "gender": g, "hometown": "Tampere", "club_id": "tap",
					"main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1}, "answers": {}}, RandomNumberGenerator.new())
			var rng := RandomNumberGenerator.new()
			rng.seed = 777 + k
			var pool: Array = RV.generate(a, rng)
			var monday := {"year": 2026, "month": 11, "day": 2}
			for season in AGES.size():
				for w in 52:
					if has_age:
						RV.train_week(pool, g, monday, 2012)
					else:
						RV.train_week(pool, g, monday)
					monday = _add(monday, 7)
				var age: int = AGES[season]
				var ab: Array = pool.map(func(r): return float(r.ability))
				ab.sort()
				for q in [0.1, 0.25, 0.5, 0.75, 0.9]:
					_push(by_age[age].q, q, ab[int(q * (ab.size() - 1))])
				_push(by_age[age].q, 1.0, ab[-1])
				for rank in [1, 3, 8, 20, 50, 75]:
					_push(by_age[age].rank, rank, RP.time_for(ab[ab.size() - rank], g))
		print("\n=== %s: ability quantiles | time of the n-th best of 150 [real band] ===" % g.to_upper())
		print("  age   p10   p25   p50   p75   p90   max | 1st              3rd      8th               20th              50th     75th")
		for age in AGES:
			var q: Dictionary = by_age[age].q
			var r: Dictionary = by_age[age].rank
			var real: Array = REAL[g][age]
			print("  %3d %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f | %s %s %s %s %s %s %s %s %s" % [age, _m(q[0.1]), _m(q[0.25]), _m(q[0.5]),
					_m(q[0.75]), _m(q[0.9]), _m(q[1.0]), _t(_m(r[1])), _band(_m(r[1]), real[0]), _t(_m(r[3])), _t(_m(r[8])),
					_band(_m(r[8]), real[1]), _t(_m(r[20])), _band(_m(r[20]), real[2]), _t(_m(r[50])), _t(_m(r[75]))])
	print("rival_curves done")
	quit()


func _value(s: String) -> Variant:
	if s.contains("|"):
		return Array(s.split("|")).map(func(x): return float(x))
	return float(s)


func _push(d: Dictionary, k, v: float) -> void:
	if not d.has(k):
		d[k] = []
	d[k].append(v)


func _m(v: Array) -> float:
	var s := 0.0
	for x in v:
		s += x
	return s / maxf(v.size(), 1)


func _band(sec: float, band: Array) -> String:
	var mark := "ok"
	if sec < float(band[0]):
		mark = "%.0fs fast" % (float(band[0]) - sec)
	elif sec > float(band[1]):
		mark = "%.0fs slow" % (sec - float(band[1]))
	return "[%s–%s %-8s]" % [_t(band[0]).left(4), _t(band[1]).left(4), mark]


func _t(sec: float) -> String:
	return "%d:%05.2f" % [int(sec) / 60, fmod(sec, 60.0)]


func _add(d: Dictionary, days: int) -> Dictionary:
	var t := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12})
	var r := Time.get_datetime_dict_from_unix_time(t + days * 86400)
	return {"year": r.year, "month": r.month, "day": r.day}
