class_name Rivals
## The pool of fictional runners of the player's age and gender. They train and improve every week,
## keep their PBs, and fill the fields of the meets the player enters.


static func generate(a: Athlete, rng: RandomNumberGenerator) -> Array:
	var cfg: Dictionary = Data.races.rivals
	var pool := []
	var used_names := {}
	for i in int(cfg.count):
		var first: String = Data.names[a.gender].pick_random()
		var last: String = Data.names.surnames.pick_random()
		var tries := 0
		while used_names.has(first + last) and tries < 50:
			tries += 1
			first = Data.names[a.gender].pick_random()
			last = Data.names.surnames.pick_random()
		used_names[first + last] = true
		var ability := clampf(rng.randfn(cfg.ability_mean, cfg.ability_sd), cfg.ability_min, cfg.ability_max)
		pool.append({
			"id": "r%d" % i,
			"first_name": first, "last_name": last,
			"club_id": Data.clubs.pick_random().id,
			"ability": ability,
			"ceiling": maxf(ability + 1.0, rng.randfn(cfg.ceiling_mean, cfg.ceiling_sd)),
			"trainability": rng.randf_range(0.6, 1.4),
			"speed": clampf(ability + rng.randfn(0.0, 2.0), 1.0, 20.0),
			"anaerobic": rng.randfn(0.0, 2.0),
			"tactics": clampf(rng.randfn(8.0, 3.0), 1.0, 20.0),
			"consistency": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0),
			"composure": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0),
			"competitiveness": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0),
			"pb": 0.0,
		})
	return pool


## One week of training for every rival (similar growth model to the player's: slows near the ceiling).
## They also race elsewhere: each week a rival may run an 800 m of their own (more often in summer),
## which feeds their season best for the rankings. Injured rivals (out_weeks > 0, set by HealthSystem)
## neither train nor race.
static func train_week(pool: Array, gender: String, monday: Dictionary) -> void:
	var chances: Array = Data.races.rivals.race_chance_by_month
	var chance := float(chances[int(monday.month) - 1])
	for r in pool:
		if is_out(r):
			continue
		var headroom := clampf((float(r.ceiling) - float(r.ability)) / 5.0, 0.05, 1.0)
		r.ability = float(r.ability) + 0.055 * float(r.trainability) * headroom * randf_range(0.4, 1.6)
		r.speed = float(r.speed) + 0.03 * randf()
		if randf() < chance:
			# Even-effort time plus a usually-slower bad-day factor; consistent runners vary less.
			var spread := 0.02 - float(r.consistency) * 0.0007
			var factor := maxf(1.0 + randfn(0.008, spread), 0.99)
			record_time(r, RacePerformance.time_for(float(r.ability), gender) * factor, monday)


## Updates a rival's PB and season best (SB counts only for the season it was run in).
static func record_time(r: Dictionary, time: float, date: Dictionary) -> void:
	if float(r.pb) == 0.0 or time < float(r.pb):
		r.pb = time
	var season := Rankings.season_of(date)
	if int(r.get("sb_season", -1)) != season or time < float(r.get("sb", 0.0)):
		r.sb = time
		r.sb_season = season


## Opponents for a race at a meet of this level.
static func pick_field(pool: Array, level: String, rng: RandomNumberGenerator, standard_ability := 0.0) -> Array:
	var cfg: Dictionary = Data.races.fields.get(level, Data.races.fields.local)
	var sorted := pool.filter(func(r): return not is_out(r))   # injured rivals don't race
	sorted.sort_custom(func(x, y): return x.ability < y.ability)
	var lo := int(float(cfg.pool_range[0]) * sorted.size())
	var hi := int(float(cfg.pool_range[1]) * sorted.size())
	var candidates := sorted.slice(lo, hi)
	if level == "national" and standard_ability > 0.0:
		# Everyone with the standard enters, plus some who use their one event without it.
		candidates = sorted.filter(func(r): return r.ability >= standard_ability or rng.randf() < 0.12)
	candidates.shuffle()
	var size := rng.randi_range(int(cfg.size[0]), int(cfg.size[1]))
	if level == "national" and standard_ability > 0.0:
		size = 40   # championships take everyone who enters (then run heats)
	return candidates.slice(0, mini(size, candidates.size()))


## Injured: out for this many more weeks (GDD 4.6, HealthSystem rolls it every week).
static func is_out(r: Dictionary) -> bool:
	return int(r.get("out_weeks", 0)) > 0


static func full_name(r: Dictionary) -> String:
	return "%s %s" % [r.first_name, r.last_name]
