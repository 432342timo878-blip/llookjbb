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
		# Bloom age (talent session): a late bloomer (bloom > 0) is behind at 14 and keeps growing longer.
		var bloom := clampf(rng.randfn(0.0, float(cfg.get("bloom_sd", 0.0))), -float(cfg.get("bloom_max", 0.0)), float(cfg.get("bloom_max", 0.0)))
		ability = clampf(ability - bloom * float(cfg.get("bloom_start", 0.0)), cfg.ability_min, cfg.ability_max)
		pool.append({
			"bloom": bloom,
			"id": "r%d" % i,
			"first_name": first, "last_name": last,
			"club_id": Data.clubs.pick_random().id,
			"ability": ability,
			"ceiling": minf(maxf(ability + 1.0, rng.randfn(cfg.ceiling_mean, cfg.ceiling_sd)), float(cfg.ceiling_max)),
			"trainability": rng.randf_range(0.6, 1.4),
			"speed": clampf(ability + rng.randfn(0.0, 2.0), 1.0, 20.0),
			"anaerobic": rng.randfn(0.0, 2.0),
			"tactics": clampf(rng.randfn(8.0, 3.0), 1.0, 20.0),
			"consistency": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0),
			"composure": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0),
			"competitiveness": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0),
			"pb": 0.0,
		})
	ensure_personalities(pool)
	return pool


## Every rival gets a race personality (GDD 4.3.1) and a "met" count (races against the player). Old saves
## have neither: the personality is made from the rival's anaerobic value and a hash of its id, so it needs no
## dice and is the same every time the save loads.
static func ensure_personalities(pool: Array) -> void:
	for r in pool:
		if not r.has("personality"):
			var h := String(r.id).hash()
			h = (h * 2654435761) & 0xffffffff   # spread the hash of similar ids ("r1", "r2", ...)
			r.personality = personality_from(float(r.anaerobic), float(h) / 4294967296.0)
		if not r.has("met"):
			r.met = 0
		if not r.has("bloom"):   # (older saves: from the id hash, no dice; none when bloom_max is 0)
			var u := float((String(r.id).hash() * 40503) & 0xffff) / 65535.0
			r.bloom = (u * 2.0 - 1.0) * 0.75 * float(Data.races.rivals.get("bloom_max", 0.0))


## The personality for this anaerobic value; u in [0, 1) picks from the weights in data/races.json.
static func personality_from(anaerobic: float, u: float) -> String:
	var types: Dictionary = Data.races.personalities
	var weights := {}
	var total := 0.0
	for id in types:
		if id.begins_with("_"):
			continue
		var w := maxf(0.02, float(types[id].base) + float(types[id].per_anaerobic) * anaerobic)
		weights[id] = w
		total += w
	var x := u * total
	for id in weights:
		x -= weights[id]
		if x < 0.0:
			return id
	return weights.keys().back()


## One week of training for every rival (similar growth model to the player's: slows near the ceiling and stops at
## it, and slows with age: data/races.json rivals growth_by_age, step 7). `birth_year` is the cohort's (the player's).
## Churn (talent session, GDD 4.2 "Talent balance"): each rival's growth curve is shifted by their bloom age (a late
## bloomer at 17 grows like a 16-year-old), the ceiling drifts a little every week (ceiling_drift_sd a year, never
## above ceiling_max): some stall below the ceiling they had at 14, some break through it; and each autumn a rival's
## pace for the year is drawn (pace_sd, pace_keep): good years and flat years.
## They also race elsewhere: each week a rival may run an 800 m of their own (more often in summer),
## which feeds their season best for the rankings. Injured rivals (out_weeks > 0, set by HealthSystem)
## neither train nor race.
static func train_week(pool: Array, gender: String, monday: Dictionary, birth_year: int) -> void:
	var cfg: Dictionary = Data.races.rivals
	var chances: Array = cfg.race_chance_by_month
	var chance := float(chances[int(monday.month) - 1])
	# The ceiling's drift wanders around the rival's own ceiling: stationary sd ceiling_drift_sd, pulled back over about
	# ceiling_drift_years (so it can't run away), never below ceiling_floor under the rival's own ceiling.
	var drift_sd := float(cfg.get("ceiling_drift_sd", 0.0))
	var pull := 1.0 / (52.0 * maxf(float(cfg.get("ceiling_drift_years", 3.0)), 0.1))
	var drift := drift_sd * sqrt(2.0 * pull)
	var pace_sd := float(cfg.get("pace_sd", 0.0))
	var new_year := int(monday.month) == 11 and int(monday.day) <= 7   # the season's first week
	for r in pool:
		if new_year and pace_sd > 0.0:
			# A good or a flat year: the pace carries over partly (pace_keep) and is redrawn each autumn (log-normal,
			# mean 1), so some rivals break through and others stall for a year or two.
			var lp := log(float(r.get("pace", 1.0))) * float(cfg.get("pace_keep", 0.0)) + randfn(0.0, pace_sd)
			r.pace = exp(lp - pace_sd * pace_sd / 2.0)
		if is_out(r):
			continue
		var by_age := growth_by_age(gender, monday, birth_year, float(r.get("bloom", 0.0))) * float(r.get("pace", 1.0))
		if drift > 0.0:
			r.drift = float(r.get("drift", 0.0)) * (1.0 - pull) + randfn(0.0, drift)
		var ceiling := minf(float(r.ceiling) + maxf(float(r.get("drift", 0.0)), -float(cfg.get("ceiling_floor", 99.0))),
				float(cfg.ceiling_max))   # (older saves' ceilings had no cap)
		if float(r.ability) > ceiling:   # (the ceiling drifted below them: a stagnating runner slowly loses the excess)
			r.ability = float(r.ability) - (float(r.ability) - ceiling) * float(cfg.get("above_ceiling_fall", 0.0))
		var headroom := clampf((ceiling - float(r.ability)) / 5.0, 0.0, 1.0)
		r.ability = float(r.ability) + float(cfg.weekly_rate) * float(r.trainability) * headroom * randf_range(0.4, 1.6) * by_age
		r.speed = minf(float(r.speed) + 0.03 * randf() * by_age, Athlete.MAX_VALUE)
		if randf() < chance:
			# Even-effort time plus a usually-slower bad-day factor; consistent runners vary less.
			var spread := 0.02 - float(r.consistency) * 0.0007
			var factor := maxf(1.0 + randfn(0.008, spread), 0.99)
			record_time(r, RacePerformance.time_for(float(r.ability), gender) * factor, monday)


## What a rival's ability is expected to be on `to` (a Monday on or after `from`), without any dice and without touching the global ones
## (the coach's estimate of a field, GDD 4.9.2, session C5): every week the mean of train_week's gain (the random factor's mean is 1),
## drift and the ceiling's pull ignored. A rival who is out keeps the ability they have.
static func expected_ability(r: Dictionary, gender: String, from: Dictionary, to: Dictionary, birth_year: int) -> float:
	var cfg: Dictionary = Data.races.rivals
	var ability := float(r.ability)
	var ceiling := minf(float(r.ceiling), float(cfg.ceiling_max))
	var weeks := roundi(Calendar.days_between(from, to) / 7.0)
	for w in weeks:
		var monday := Game.add_days(from, 7 * w)
		var by_age := growth_by_age(gender, monday, birth_year, float(r.get("bloom", 0.0))) * float(r.get("pace", 1.0))
		var headroom := clampf((ceiling - ability) / 5.0, 0.0, 1.0)
		ability += float(cfg.weekly_rate) * float(r.trainability) * headroom * by_age
	return ability


## The rivals' weekly growth share at the cohort's age on `monday` (born mid-`birth_year` on average): 1.0 = the
## youngest rate, interpolated in data/races.json rivals growth_by_age ([age, share] by gender).
static func growth_by_age(gender: String, monday: Dictionary, birth_year: int, bloom := 0.0) -> float:
	var table: Array = Data.races.rivals.growth_by_age[gender]
	var age := float(monday.year) + (float(monday.month) - 1.0) / 12.0 + float(monday.day) / 365.0 - (float(birth_year) + 0.5) - bloom
	if age <= float(table[0][0]):
		return float(table[0][1])
	for i in range(1, table.size()):
		if age <= float(table[i][0]):
			return lerpf(float(table[i - 1][1]), float(table[i][1]), (age - float(table[i - 1][0])) / (float(table[i][0]) - float(table[i - 1][0])))
	return float(table.back()[1])


## Updates a rival's PB and season best (SB counts only for the season it was run in).
static func record_time(r: Dictionary, time: float, date: Dictionary) -> void:
	if float(r.pb) == 0.0 or time < float(r.pb):
		r.pb = time
	var season := Rankings.season_of(date)
	if int(r.get("sb_season", -1)) != season or time < float(r.get("sb", 0.0)):
		r.sb = time
		r.sb_season = season


## Opponents for a race at a meet of this level. `entries` = [min, max] runners of a championship with real entry
## numbers (competitions.json "field", step 7): then the best of the age group enter (each may skip it) plus a few
## weaker ones using their one event without the standard (races.json fields.championship).
static func pick_field(pool: Array, level: String, rng: RandomNumberGenerator, standard_ability := 0.0, entries := []) -> Array:
	var cfg: Dictionary = Data.races.fields.get(level, Data.races.fields.local)
	var sorted := pool.filter(func(r): return not is_out(r))   # injured rivals don't race
	sorted.sort_custom(func(x, y): return x.ability < y.ability)
	if entries.size() == 2:
		var ch: Dictionary = Data.races.fields.championship
		var size := mini(rng.randi_range(int(entries[0]), int(entries[1])) - 1, sorted.size())   # (the player is one of them)
		var tail := roundi(size * float(ch.tail))
		var field := []
		var rest := []
		for k in range(sorted.size() - 1, -1, -1):   # best first
			if field.size() < size - tail and rng.randf() >= float(ch.skip):
				field.append(sorted[k])
			else:
				rest.append(sorted[k])
		rest.shuffle()
		return field + rest.slice(0, size - field.size())
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
