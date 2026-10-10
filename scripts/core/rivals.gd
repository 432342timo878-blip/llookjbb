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
## They also race elsewhere: each week a rival may run an 800 m of their own (more often in summer),
## which feeds their season best for the rankings. Injured rivals (out_weeks > 0, set by HealthSystem)
## neither train nor race.
static func train_week(pool: Array, gender: String, monday: Dictionary, birth_year: int) -> void:
	var cfg: Dictionary = Data.races.rivals
	var chances: Array = cfg.race_chance_by_month
	var chance := float(chances[int(monday.month) - 1])
	var by_age := growth_by_age(gender, monday, birth_year)
	for r in pool:
		if is_out(r):
			continue
		var ceiling := minf(float(r.ceiling), float(cfg.ceiling_max))   # (older saves' ceilings had no cap)
		var headroom := clampf((ceiling - float(r.ability)) / 5.0, 0.0, 1.0)
		r.ability = float(r.ability) + float(cfg.weekly_rate) * float(r.trainability) * headroom * randf_range(0.4, 1.6) * by_age
		r.speed = minf(float(r.speed) + 0.03 * randf() * by_age, Athlete.MAX_VALUE)
		if randf() < chance:
			# Even-effort time plus a usually-slower bad-day factor; consistent runners vary less.
			var spread := 0.02 - float(r.consistency) * 0.0007
			var factor := maxf(1.0 + randfn(0.008, spread), 0.99)
			record_time(r, RacePerformance.time_for(float(r.ability), gender) * factor, monday)


## The rivals' weekly growth share at the cohort's age on `monday` (born mid-`birth_year` on average): 1.0 = the
## youngest rate, interpolated in data/races.json rivals growth_by_age ([age, share] by gender).
static func growth_by_age(gender: String, monday: Dictionary, birth_year: int) -> float:
	var table: Array = Data.races.rivals.growth_by_age[gender]
	var age := float(monday.year) + (float(monday.month) - 1.0) / 12.0 + float(monday.day) / 365.0 - (float(birth_year) + 0.5)
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
