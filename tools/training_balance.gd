extends SceneTree
## Dev tool: simulates a year of training with a few plans and prints the results, to tune the model.
## 1. M1 rows: one athlete, the weekly simulation only (no health model). The "easy"/"hard" rows play the
##    coach plan with every day at that intensity (day changes, data/health.json). Their fingerprints must
##    never change unless the training model itself is meant to change.
## 2. The same rows played day by day through the game with the health model switched off: the
##    fingerprints must be identical to part 1 (proves the health model changes nothing when it's off).
## 3. Health (GDD 4.6): 200 athletes per row (random backgrounds, boys and girls), 1 year from age 14
##    through the game's day loop with the health model on, entering the coach's recommended meets.
##    Policies: neutral = follows injury limits, ignores soreness; careful = takes it easy when sore
##    (rest when painful); ignore = keeps going and trains through every limit that isn't locked.
## 4. The coach's three season plans (GDD 4.8, M2 step 6d): 200 athletes per row, the first season (2 Nov 2026 –
##    1 Nov 2027) from age 14 through the game loop with health and form on, the two targets and the coach's
##    recommended meets entered. Rows: the old repeating coach week (reference, same meets) and Steady / Balanced /
##    Ambitious, each neutral and careful. Races are not run: each race's expected time is worked out (ability with
##    the injury slowdown and race-day form, the race's fatigue and composure rules; no dice) to find the season best.
## Run: godot --headless --path . -s res://tools/training_balance.gd [-- <athletes per row, default 200> [rows [start age]]]
## rows: only these rows, comma-separated, spaces as underscores (e.g. coach,hard_careful,balanced_careful);
## "all" = every row of parts 3 and 4 (the default), "part3" / "part4" = the rows of one part.
## start age: 14 (default), 15 or 16. Only the birth date moves (the attributes are still a 14-year-old's), so
## it shows how age and the growth spurt change injuries, not how a real 16-year-old trains.
## Each row also prints a second line with boys vs girls, colds per month and how often the game would stop.

var start_age := 14
var game
var data
var Cal
var T
var F
var W
var WP
var RP
var H


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Loaded at runtime: autoload names (Data, Game) only exist once the tree is running.
	T = load("res://scripts/core/training.gd")
	F = load("res://scripts/core/athlete_factory.gd")
	W = load("res://scripts/core/week_sim.gd")
	WP = load("res://scripts/core/week_plan.gd")
	Cal = load("res://scripts/core/calendar.gd")
	RP = load("res://scripts/core/race_performance.gd")
	H = load("res://scripts/core/health_system.gd")
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	var plans := {
		"coach": T.coach_plan(),
		"hard": [["intervals_800", "strength"], ["tempo_run", "drills"], ["long_run"], ["intervals_800", "hill_sprints"],
				["tempo_run"], ["long_run", "speed_strides"], ["fartlek"]],
		"lazy": [["easy_run"], [], [], ["easy_run"], [], [], []],
	}
	# [row name, plan, intensity for every day]
	var runs := [["coach", "coach", "normal"], ["hard", "hard", "normal"], ["lazy", "lazy", "normal"],
			["coach easy", "coach", "easy"], ["coach hard", "coach", "hard"]]
	print("== 1. M1 balance (weekly simulation, no health model)")
	var fingerprints := []
	for run in runs:
		fingerprints.append(_m1_row(run, plans, false))
	print("\n== 2. The same, day by day through the game with the health model OFF")
	H.model_enabled = false
	var same := true
	for i in runs.size():
		var fp: String = _m1_row(runs[i], plans, true)
		same = same and fp == fingerprints[i]
	H.model_enabled = true
	print("   fingerprints identical to part 1: %s" % ("YES" if same else "NO  <-- the M1 balance changed!"))

	# Step 6a: intensity stored in the week plan (instead of as day changes) gives exactly the same results.
	print("\n== 2b. Intensity in the week plan (M2 step 6a) instead of day changes: same fingerprints")
	H.model_enabled = false
	var same_plan := true
	for i in runs.size():
		same_plan = same_plan and _m1_row(runs[i], plans, true, true) == fingerprints[i]
	H.model_enabled = true
	print("   fingerprints identical to part 1: %s" % ("YES" if same_plan else "NO  <-- plan-level intensity differs!"))

	var n := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		n = args[0].to_int()
	if n == 0:
		print("\n(0 athletes asked for: part 3 skipped)")
		quit()
		return
	var rows := [
		["coach", "coach", "neutral"], ["coach careful", "coach", "careful"], ["lazy", "lazy", "neutral"],
		["hard ignore", "hard", "ignore"], ["hard neutral", "hard", "neutral"], ["hard careful", "hard", "careful"],
		["ramp", "ramp", "neutral"], ["ramp careful", "ramp", "careful"],
	]
	# [row name, plan ("week" = the old repeating coach week, else the coach's season plan), policy]
	var season_rows := [
		["week", "week", "neutral"], ["week careful", "week", "careful"],
		["steady", "steady", "neutral"], ["steady careful", "steady", "careful"],
		["balanced", "balanced", "neutral"], ["balanced careful", "balanced", "careful"],
		["ambitious", "ambitious", "neutral"], ["ambitious careful", "ambitious", "careful"],
	]
	var pick: String = args[1] if args.size() > 1 else "all"
	if pick == "part3":
		season_rows = []
	elif pick == "part4":
		rows = []
	elif pick != "all":
		var names: PackedStringArray = pick.replace("_", " ").split(",")
		rows = rows.filter(func(r): return r[0] in names)
		season_rows = season_rows.filter(func(r): return r[0] in names)
		# Any other variant in data/periodization.json can be tried by name too (tuning): "<id>" or "<id> careful".
		for name in names:
			var id: String = name.trim_suffix(" careful")
			if data.periodization.variants.has(id) and not season_rows.any(func(r): return r[0] == name):
				season_rows.append([name, id, "careful" if name.ends_with(" careful") else "neutral"])
	if args.size() > 2 and args[2].is_valid_int():
		start_age = args[2].to_int()
	if not rows.is_empty():
		print("\n== 3. Health model ON: %d athletes per row, 1 year from age 14, coach-recommended meets entered" % n)
		print("   inj/yr = injuries (not illness) per athlete, an escalated one counts once at its worst tier; nig/inj/ser =")
		print("   share by tier; warned = overuse injuries that came after the area had been sore / only a bit sore (week")
		print("   before); days inj/out = days with an injury / with no running allowed; ill = illnesses per year (share")
		print("   Novâ€“Mar, share flu, days ill); ability = 800 m ability gain (M1 coach plan, no health: compare part 1).")
		if start_age != 14:
			print("   start age %d (birth date moved only)" % start_age)
		for row in rows:
			_health_row(row, plans, n)
	if not season_rows.is_empty():
		print("\n== 4. The coach's season plans (M2 step 6d): %d athletes per row, the 2026-27 season from age %d, health and form on," % [n, start_age])
		print("   the two targets + the coach's recommended meets entered. load = average weekly training load as in the weekly")
		print("   report (after durability; races included); form = average race-day form at the targets / at the other races, and how often a")
		print("   target reads Peaking; SB at target = share of athletes whose fastest indoor / outdoor race (expected time) was the target;")
		print("   risk = plan risk of the week's plan every 4th Monday (share Low / Moderate / High) and athletes ever High.")
		_planned_loads()
		for row in season_rows:
			_season_row(row, n)
	quit()


# --- Parts 1 and 2 -----------------------------------------------------------------------------------

func _m1_athlete():
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	return F.create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)


## One M1 row; through_game = play it day by day with Game.advance_day(). Returns the fingerprint line.
## plan_level: the row's intensity is stored in the week plan (WeekPlan) instead of set as day changes.
func _m1_row(run: Array, plans: Dictionary, through_game: bool, plan_level := false) -> String:
	var a = _m1_athlete()
	var start := {}
	for id in ["aerobic_capacity", "lactate_threshold", "speed_endurance", "speed", "strength", "running_technique", "race_tactics"]:
		start[id] = a.get_attr(id)
	var date: Dictionary = game.START_DATE.duplicate()
	var peak := 0.0
	var fat_sum := 0.0
	if through_game:
		game.start_career(a, "repeat")
		game.season.repeat_week = WP.make(plans[run[1]], [run[2], run[2], run[2], run[2], run[2], run[2], run[2]] if plan_level else [])
	for w in 52:
		var r: Dictionary
		if through_game:
			var week = game.current_week()
			if run[2] != "normal" and not plan_level:
				for d in 7:
					week.set_intensity(d, run[2])
			while game.advance_day() != game.WEEK_DONE:
				pass
			r = game.last_report
		elif run[2] == "normal":
			r = T.simulate_week(a, plans[run[1]], date)
		else:
			var week = W.new(a, plans[run[1]], date)
			for d in 7:
				week.set_intensity(d, run[2])
			r = week.finish()
		date = game.add_days(date, 7)
		peak = maxf(peak, r.fatigue_peak)
		fat_sum += r.fatigue_avg
	var line := "%-10s avg fatigue %3d peak %3d |" % [run[0], roundi(fat_sum / 52), roundi(peak)]
	for id in start:
		line += " %s %.1fâ†’%.1f" % [id.substr(0, 8), start[id], a.get_attr(id)]
	if not through_game:
		print(line)
	# Full precision, to prove that an engine change leaves the results exactly the same.
	var total := 0.0
	for id in a.attributes:
		total += a.get_attr(id)
	var fp := "fingerprint: attributes %.9f fatigue %.9f fatigue-sum %.9f" % [total, a.fatigue, fat_sum]
	print(("%-10s " % run[0] if through_game else "           ") + fp)
	return fp


# --- Part 3: health -----------------------------------------------------------------------------

## A random 14-year-old: background answers, gender, birth date and hidden values all vary with `i`.
func _random_athlete(i: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	return F.create({
		"first_name": "Test", "last_name": "Runner%d" % i, "gender": "male" if i % 2 == 0 else "female",
		"hometown": "Tampere", "club_id": "tap", "main_event": "800m",
		"birth_date": {"year": 2012 - (start_age - 14), "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)


## The plan for week `w`: "ramp" builds from the coach plan to the hard plan over 8 weeks, a day at a time.
func _plan_for(plan_id: String, w: int, plans: Dictionary) -> Array:
	if plan_id != "ramp":
		return plans[plan_id].duplicate(true)
	if w >= 8:
		return plans.hard.duplicate(true)
	var hard_days := roundi((w + 1) * 7 / 8.0)
	var plan := []
	for d in 7:
		plan.append((plans.hard[d] if d < hard_days else plans.coach[d]).duplicate())
	return plan


func _health_row(row: Array, plans: Dictionary, n: int) -> void:
	var t0 := Time.get_ticks_msec()
	var policy: String = row[2]
	var s := {"inj": 0, "niggle": 0, "injury": 0, "serious": 0, "acute": 0, "overuse": 0, "warned": 0, "ill": 0,
			"ill_winter": 0, "flu": 0, "days_injured": 0, "days_out": 0, "days_ill": 0, "ability": 0.0, "ability2": 0.0,
			"zero": 0, "three_plus": 0, "fatigue": 0.0, "risk": {"low": 0, "moderate": 0, "high": 0},
			"rivals_out": 0.0, "escalated": 0, "slight": 0, "early": 0, "cap26": 0.0,
			"ill_month": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "stops_sore": 0, "stops_diag": 0, "stop_weeks": 0,
			"sore_bit": 0, "sore_sore": 0, "sore_areas": 0, "days": 0,
			"male": {"n": 0, "inj": 0, "serious": 0, "out": 0, "areas": {}}, "female": {"n": 0, "inj": 0, "serious": 0, "out": 0, "areas": {}}}
	var end_key: int = Cal.date_key(game.add_days(game.START_DATE, 364))
	for i in n:
		var a = _random_athlete(i)
		game.start_career(a, "repeat")
		var health = game.get_system("health")
		health.rng.seed = 5000 + i
		for m in Cal.meets_between(game.START_DATE, game.add_days(game.START_DATE, 364)):
			if Cal.coach_recommends(a, m, game.START_DATE):
				game.enter(m.key)
		var start_ability: float = RP.ability(a)
		var w := 0
		var fat_sum := 0.0
		var days := 0
		var stopped_this_week := false
		while Cal.date_key(game.date) < end_key:
			if Cal.weekday(game.date) == 0 and game.current_week().day == 0:
				s.stop_weeks += 1 if stopped_this_week else 0
				stopped_this_week = false
				game.season.repeat_week = WP.make(_plan_for(row[1], w, plans))
				game.current_week()
				if w == 12:
					s.risk[health.plan_risk(game.season.repeat_week)] += 1
				w += 1
			_before_day(health, policy)
			var r: String = game.advance_day()
			if r == game.RACE:
				r = game.finish_race()   # the race itself isn't run: only its load and strain matter here
			while not game.pending_event().is_empty():
				var e: Dictionary = game.pending_event()
				var answer := "ok"
				stopped_this_week = true
				if e.get("kind", "") == "sore":
					s.stops_sore += 1
					answer = "easy" if policy == "careful" else "keep"
				else:
					s.stops_diag += 1
				game.answer_event(e.id, answer)
			fat_sum += a.fatigue
			days += 1
			var worst := 0
			var bit_sore_areas := 0
			for lvl in health.levels.values():
				worst = maxi(worst, int(lvl))
				bit_sore_areas += 1 if int(lvl) >= 1 else 0
			s.sore_bit += 1 if worst >= 1 else 0
			s.sore_sore += 1 if worst >= 2 else 0
			s.sore_areas += bit_sore_areas
			s.days += 1
			if days == 182:
				s.cap26 += health.capacity()
			if Cal.weekday(game.date) == 0:
				s.rivals_out += game.rivals.filter(func(x): return int(x.get("out_weeks", 0)) > 0).size() / float(game.rivals.size())
		s.fatigue += fat_sum / days
		s.ability += RP.ability(a) - start_ability
		s.ability2 += pow(RP.ability(a) - start_ability, 2.0)
		var count := 0
		var g: Dictionary = s[a.gender]
		g.n += 1
		for inj in health.history + health.injuries:
			if inj.tier == "illness":
				s.ill += 1
				s.ill_month[int(inj.started.month) - 1] += 1
				if int(inj.started.month) in [11, 12, 1, 2, 3]:
					s.ill_winter += 1
				if inj.id == "flu":
					s.flu += 1
				continue
			count += 1
			s.inj += 1
			g.inj += 1
			g.areas[inj.area] = int(g.areas.get(inj.area, 0)) + 1
			if inj.tier == "serious":
				g.serious += 1
			if Cal.days_between(game.START_DATE, inj.started) < 56:
				s.early += 1
			s[inj.tier] += 1
			if inj.escalated:
				s.escalated += 1
			if inj.cause == "acute":
				s.acute += 1
			else:
				s.overuse += 1
				if inj.warning >= H.SORE:
					s.warned += 1
				elif inj.warning >= 1:
					s.slight += 1
		s.zero += 1 if count == 0 else 0
		s.three_plus += 1 if count >= 3 else 0
		s.days_injured += health.counters.days_injured
		s.days_out += health.counters.days_out
		g.out += health.counters.days_out
		s.days_ill += health.counters.days_ill
	var inj := maxf(1.0, s.inj)
	print("%-13s inj/yr %4.2f (nig %2d%% inj %2d%% ser %2d%%, acute %2d%%, escalated %2d%%, warned %2d%%/%2d%%) | days inj %3d out %3d | 0 inj %2d%% 3+ %2d%% | ill %4.2f (winter %2d%%, flu %2d%%, %2d days) | fatigue %2d | ability %+.2f (se %.2f) | %.0fs" % [
		row[0], s.inj / float(n), 100 * s.niggle / inj, 100 * s.injury / inj, 100 * s.serious / inj,
		100 * s.acute / inj, 100 * s.escalated / inj, 100 * s.warned / maxf(1.0, s.overuse), 100 * s.slight / maxf(1.0, s.overuse),
		roundi(s.days_injured / float(n)), roundi(s.days_out / float(n)), 100 * s.zero / n, 100 * s.three_plus / n,
		s.ill / float(n), 100 * s.ill_winter / maxf(1.0, s.ill), 100 * s.flu / maxf(1.0, s.ill), roundi(s.days_ill / float(n)),
		roundi(s.fatigue / n), s.ability / n, sqrt(maxf(0.0, s.ability2 / n - pow(s.ability / n, 2.0)) / n), (Time.get_ticks_msec() - t0) / 1000.0])
	print("              injuries in the first 8 weeks %.2f | capacity at week 26 Ã—%.2f | plan risk at week 12: Low %d%% Moderate %d%% High %d%%" % [
			s.early / float(n), s.cap26 / n, 100 * s.risk.low / n, 100 * s.risk.moderate / n, 100 * s.risk.high / n])
	var months := []
	for mo in [11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		months.append("%.2f" % (s.ill_month[mo - 1] / float(n)))
	var boys: Dictionary = s.male
	var girls: Dictionary = s.female
	print("              boys %.2f inj/yr, %.0f%% serious, %d days out | girls %.2f inj/yr, %.0f%% serious, %d days out | stops/yr: sore %.1f, new injury or illness %.1f, weeks with a stop %.1f of 52" % [
			boys.inj / maxf(1.0, boys.n), 100.0 * boys.serious / maxf(1.0, boys.inj), roundi(boys.out / maxf(1.0, boys.n)),
			girls.inj / maxf(1.0, girls.n), 100.0 * girls.serious / maxf(1.0, girls.inj), roundi(girls.out / maxf(1.0, girls.n)),
			s.stops_sore / float(n), s.stops_diag / float(n), s.stop_weeks / float(n)])
	var by_area := []
	for area in H.areas():
		by_area.append("%s %.2f/%.2f" % [area.id, int(boys.areas.get(area.id, 0)) / maxf(1.0, boys.n), int(girls.areas.get(area.id, 0)) / maxf(1.0, girls.n)])
	print("              injuries per athlete by area, boys/girls: %s" % ", ".join(by_area))
	print("              days with a sore area: at least a bit sore %.0f%%, at least sore %.0f%% | areas a bit sore or worse on an average day %.2f" % [
			100.0 * s.sore_bit / maxf(1.0, s.days), 100.0 * s.sore_sore / maxf(1.0, s.days), s.sore_areas / maxf(1.0, s.days)])
	print("              colds+flu per athlete by month Nov..Oct: %s" % " ".join(months))
	if row[0] == "coach":
		print("              rivals injured at any time: %.1f%%" % (100.0 * s.rivals_out / (52.0 * n)))


# --- Part 4: the coach's season plans ------------------------------------------------------------

## The plans' own weekly load (session load × intensity, before durability; targets' tapers in, no other races),
## averaged over the 2026-27 season and per phase, against Balanced's.
func _planned_loads() -> void:
	var SP = load("res://scripts/core/season_plan.gd")
	var a = _random_athlete(0)
	var totals := {}
	for id in data.periodization.variants:
		if id.begins_with("_"):
			continue
		var plan = SP.phased(a, game.START_DATE, id)
		var by_phase := {}
		var sum := 0.0
		for w in 52:
			var week: Dictionary = plan.week_for(game.add_days(game.START_DATE, 7 * w), [])
			var load := 0.0
			for d in 7:
				for s in week.days[d]:
					load += float(data.get_session(s).load) * float(data.health.intensity[week.intensity[d]].load)
			sum += load
			by_phase[week.phase] = by_phase.get(week.phase, []) + [load]
		totals[id] = {"avg": sum / 52.0, "phases": by_phase}
	var ref: float = totals.balanced.avg
	for id in totals:
		var parts := []
		for ph in totals[id].phases:
			var list: Array = totals[id].phases[ph]
			parts.append("%s %d" % [ph, roundi(list.reduce(func(x, y): return x + y, 0.0) / list.size())])
		print("   planned load %-9s %3d a week (%3d %% of Balanced): %s" % [id, roundi(totals[id].avg), roundi(100.0 * totals[id].avg / ref), ", ".join(parts)])

func _season_row(row: Array, n: int) -> void:
	var t0 := Time.get_ticks_msec()
	var SP = load("res://scripts/core/season_plan.gd")
	var policy: String = row[2]
	var phase_ids := []
	for p in data.periodization.phases:
		phase_ids.append(p.id)
	var s := {"inj": 0, "serious": 0, "days_out": 0, "ill": 0, "ability": 0.0, "ability2": 0.0, "fatigue": 0.0, "load": 0.0,
			"form_t": 0.0, "n_t": 0, "peak_t": 0, "form_o": 0.0, "n_o": 0, "sb_indoor": 0, "sb_outdoor": 0, "has_indoor": 0, "has_outdoor": 0,
			"risk": {"low": 0, "moderate": 0, "high": 0}, "ever_high": 0, "stops": 0,
			"phase": {}, "target_words": {}}
	for id in phase_ids:
		s.phase[id] = {"sum": 0.0, "days": 0, "max": 0.0, "athletes": 0, "gain": 0.0, "risk_n": 0, "risky": 0, "inj": 0}
	var end_key: int = Cal.date_key(game.add_days(game.START_DATE, 364))
	for i in n:
		var a = _random_athlete(i)
		var targets: Array
		if row[1] == "week":
			game.start_career(a, "repeat")
			targets = SP.phased(a, game.START_DATE).targets(2026)
			for key in targets:
				game.enter(key)
		else:
			game.start_career(a, "phases", row[1])
			targets = game.season.targets(2026)
		var health = game.get_system("health")
		health.rng.seed = 5000 + i
		for m in Cal.meets_between(game.START_DATE, game.add_days(game.START_DATE, 364)):
			if Cal.coach_recommends(a, m, game.START_DATE) and not m.key in game.entries:
				game.enter(m.key)
		var start_ability: float = RP.ability(a)
		var fat_sum := 0.0
		var days := 0
		var monday_no := 0
		var high := false
		var best := {"indoor": INF, "outdoor": INF}
		var target_time := {"indoor": INF, "outdoor": INF}
		var phase_max := {}
		# The repeating week has no phases: its days are counted in the phases Balanced would have.
		var ref = game.season if row[1] != "week" else SP.phased(a, game.START_DATE, "balanced")
		var phase := ""
		while Cal.date_key(game.date) < end_key:
			var plan: Dictionary = game.season.week_for(game.week_monday())
			if Cal.weekday(game.date) == 0:
				phase = ref.week_for(game.week_monday(), []).phase
				if monday_no % 4 == 0:
					var risk: String = health.plan_risk(plan)
					s.risk[risk] += 1
					high = high or risk == "high"
					s.phase[phase].risk_n += 1
					s.phase[phase].risky += 0 if risk == "low" else 1
				monday_no += 1
			var before: float = RP.ability(a)
			_before_day(health, policy)
			var r: String = game.advance_day()
			if r == game.RACE:
				var rd = game.race_day
				var kind := "indoor" if rd.meet.get("indoor", false) else "outdoor"
				var time := _expected_time(a, rd)
				best[kind] = minf(best[kind], time)
				if rd.meet.key in targets:
					target_time[kind] = time
					s.form_t += rd.form
					s.n_t += 1
					var word: String = game.get_system("form").word_for(rd.form, a.fatigue).name
					s.target_words[word] = int(s.target_words.get(word, 0)) + 1
					s.peak_t += 1 if word == "Peaking" else 0
				else:
					s.form_o += rd.form
					s.n_o += 1
				r = game.finish_race()
			while not game.pending_event().is_empty():
				var e: Dictionary = game.pending_event()
				s.stops += 1
				game.answer_event(e.id, ("easy" if policy == "careful" else "keep") if e.get("kind", "") == "sore" else "ok")
			if r == game.WEEK_DONE:
				s.load += game.last_report.load
			fat_sum += a.fatigue
			days += 1
			if phase != "":
				var ph: Dictionary = s.phase[phase]
				ph.gain += RP.ability(a) - before
				ph.sum += a.fatigue
				ph.days += 1
				phase_max[phase] = maxf(float(phase_max.get(phase, 0.0)), a.fatigue)
		for id in phase_max:
			s.phase[id].max += phase_max[id]
			s.phase[id].athletes += 1
		for kind in ["indoor", "outdoor"]:
			if target_time[kind] < INF:
				s["has_" + kind] += 1
				s["sb_" + kind] += 1 if target_time[kind] <= best[kind] else 0
		s.ever_high += 1 if high else 0
		s.fatigue += fat_sum / days
		s.ability += RP.ability(a) - start_ability
		s.ability2 += pow(RP.ability(a) - start_ability, 2.0)
		for inj in health.history + health.injuries:
			if inj.tier == "illness":
				s.ill += 1
				continue
			s.inj += 1
			s.serious += 1 if inj.tier == "serious" else 0
			var at: String = ref.week_for(Cal.monday_of(inj.started), []).phase
			s.phase[at].inj += 1
		s.days_out += health.counters.days_out
	var risks: int = maxi(1, s.risk.low + s.risk.moderate + s.risk.high)
	print("%-17s inj/yr %4.2f (ser %2d%%) out %2d d | ill %3.1f | load %3d | fatigue %2d | ability %+.2f (se %.2f) | form targets %+.2f %% (Peaking %2d%%) other %+.2f %% | SB at target in %2d%% out %2d%% | risk L/M/H %2d/%2d/%2d%%, ever High %2d%% | stops %.1f | %.0fs" % [
			row[0], s.inj / float(n), roundi(100.0 * s.serious / maxf(1.0, s.inj)), roundi(s.days_out / float(n)), s.ill / float(n),
			roundi(s.load / (52.0 * n)), roundi(s.fatigue / n), s.ability / n, sqrt(maxf(0.0, s.ability2 / n - pow(s.ability / n, 2.0)) / n),
			100.0 * s.form_t / maxf(1.0, s.n_t), roundi(100.0 * s.peak_t / maxf(1.0, s.n_t)), 100.0 * s.form_o / maxf(1.0, s.n_o),
			roundi(100.0 * s.sb_indoor / maxf(1.0, s.has_indoor)), roundi(100.0 * s.sb_outdoor / maxf(1.0, s.has_outdoor)),
			roundi(100.0 * s.risk.low / risks), roundi(100.0 * s.risk.moderate / risks), roundi(100.0 * s.risk.high / risks),
			roundi(100.0 * s.ever_high / n), s.stops / float(n), (Time.get_ticks_msec() - t0) / 1000.0])
	var parts := []
	var gains := []
	var risky := []
	for id in phase_ids:
		var ph: Dictionary = s.phase[id]
		if ph.days > 0:
			parts.append("%s %d/%d" % [id, roundi(ph.sum / ph.days), roundi(ph.max / maxf(1.0, ph.athletes))])
			gains.append("%s %+.2f" % [id, ph.gain / n])
			risky.append("%s %d%% (inj %.2f)" % [id, roundi(100.0 * ph.risky / maxf(1.0, ph.risk_n)), ph.inj / float(n)])
	print("                  plan risk Moderate or High by phase (injuries per athlete started in it): %s" % ", ".join(risky))
	print("                  fatigue by phase (average / highest): %s | target words %s | races: %.1f targets, %.1f other per athlete" % [
			", ".join(parts), s.target_words, s.n_t / float(n), s.n_o / float(n)])
	print("                  ability gain by phase (Balanced's phases for the repeating week): %s" % ", ".join(gains))


## A race's expected time without dice: ability with the injury slowdown and race-day form (RaceDay), then the
## race's own fatigue and composure rules (Race.setup) without its random spread.
func _expected_time(a, rd) -> float:
	var ab: float = RP.ability(a)
	if rd.slowdown != 0.0 or rd.form != 0.0:
		ab = RP.ability_for_time(RP.time_for(ab, a.gender) * (1.0 + rd.slowdown - rd.form), a.gender)
	if a.fatigue > 25.0:
		ab -= (a.fatigue - 25.0) / 75.0 * 1.5
	elif a.fatigue < 10.0:
		ab += 0.1
	if rd.is_big_meet():
		ab += (a.get_attr("composure") - 10.0) * 0.04
	return RP.time_for(ab, a.gender)


## The policy's own day changes before a day is played.
func _before_day(health, policy: String) -> void:
	var week = game.current_week()
	var d: int = week.day
	if d >= 7 or not week.can_change(d):
		return
	match policy:
		"careful":
			var worst := 0
			for x in health.soreness():
				worst = maxi(worst, x.level)
			if worst >= H.PAINFUL:
				week.make_rest_day(d)
			elif worst >= H.SORE and week.intensity(d) != "easy":
				week.set_intensity(d, "easy")
		"ignore":
			if health.can_override(d):
				health.override_day(d)
