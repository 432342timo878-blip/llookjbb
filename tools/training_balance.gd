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
## Run: godot --headless --path . -s res://tools/training_balance.gd [-- <athletes per row, default 200> [rows]]
## rows: only these rows, comma-separated, spaces as underscores (e.g. coach,hard_careful).

var game
var data
var Cal
var T
var F
var W
var RP
var H


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Loaded at runtime: autoload names (Data, Game) only exist once the tree is running.
	T = load("res://scripts/core/training.gd")
	F = load("res://scripts/core/athlete_factory.gd")
	W = load("res://scripts/core/week_sim.gd")
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

	var n := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		n = args[0].to_int()
	print("\n== 3. Health model ON: %d athletes per row, 1 year from age 14, coach-recommended meets entered" % n)
	print("   inj/yr = injuries (not illness) per athlete, an escalated one counts once at its worst tier; nig/inj/ser =")
	print("   share by tier; warned = overuse injuries that came after the area had been sore / only a bit sore (week")
	print("   before); days inj/out = days with an injury / with no running allowed; ill = illnesses per year (share")
	print("   Nov–Mar, share flu, days ill); ability = 800 m ability gain (M1 coach plan, no health: compare part 1).")
	var rows := [
		["coach", "coach", "neutral"], ["coach careful", "coach", "careful"], ["lazy", "lazy", "neutral"],
		["hard ignore", "hard", "ignore"], ["hard neutral", "hard", "neutral"], ["hard careful", "hard", "careful"],
		["ramp", "ramp", "neutral"], ["ramp careful", "ramp", "careful"],
	]
	if args.size() > 1:
		rows = rows.filter(func(r): return r[0] in args[1].replace("_", " ").split(","))
	for row in rows:
		_health_row(row, plans, n)
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
func _m1_row(run: Array, plans: Dictionary, through_game: bool) -> String:
	var a = _m1_athlete()
	var start := {}
	for id in ["aerobic_capacity", "lactate_threshold", "speed_endurance", "speed", "strength", "running_technique", "race_tactics"]:
		start[id] = a.get_attr(id)
	var date: Dictionary = game.START_DATE.duplicate()
	var peak := 0.0
	var fat_sum := 0.0
	if through_game:
		game.start_career(a)
		game.training_plan = plans[run[1]].duplicate(true)
	for w in 52:
		var r: Dictionary
		if through_game:
			var week = game.current_week()
			if run[2] != "normal":
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
		line += " %s %.1f→%.1f" % [id.substr(0, 8), start[id], a.get_attr(id)]
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
		"birth_date": {"year": 2012, "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)},
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
			"ill_winter": 0, "flu": 0, "days_injured": 0, "days_out": 0, "days_ill": 0, "ability": 0.0,
			"zero": 0, "three_plus": 0, "fatigue": 0.0, "risk": {"low": 0, "moderate": 0, "high": 0},
			"rivals_out": 0.0, "escalated": 0, "slight": 0, "early": 0, "cap26": 0.0}
	var end_key: int = Cal.date_key(game.add_days(game.START_DATE, 364))
	for i in n:
		var a = _random_athlete(i)
		game.start_career(a)
		var health = game.get_system("health")
		health.rng.seed = 5000 + i
		for m in Cal.meets_between(game.START_DATE, game.add_days(game.START_DATE, 364)):
			if Cal.coach_recommends(a, m, game.START_DATE):
				game.enter(m.key)
		var start_ability: float = RP.ability(a)
		var w := 0
		var fat_sum := 0.0
		var days := 0
		while Cal.date_key(game.date) < end_key:
			if Cal.weekday(game.date) == 0 and game.current_week().day == 0:
				game.training_plan = _plan_for(row[1], w, plans)
				game.current_week()
				if w == 12:
					s.risk[health.plan_risk(game.training_plan)] += 1
				w += 1
			_before_day(health, policy)
			var r: String = game.advance_day()
			if r == game.RACE:
				r = game.finish_race()   # the race itself isn't run: only its load and strain matter here
			while not game.pending_event().is_empty():
				var e: Dictionary = game.pending_event()
				var answer := "ok"
				if e.get("kind", "") == "sore":
					answer = "easy" if policy == "careful" else "keep"
				game.answer_event(e.id, answer)
			fat_sum += a.fatigue
			days += 1
			if days == 182:
				s.cap26 += health.capacity()
			if Cal.weekday(game.date) == 0:
				s.rivals_out += game.rivals.filter(func(x): return int(x.get("out_weeks", 0)) > 0).size() / float(game.rivals.size())
		s.fatigue += fat_sum / days
		s.ability += RP.ability(a) - start_ability
		var count := 0
		for inj in health.history + health.injuries:
			if inj.tier == "illness":
				s.ill += 1
				if int(inj.started.month) in [11, 12, 1, 2, 3]:
					s.ill_winter += 1
				if inj.id == "flu":
					s.flu += 1
				continue
			count += 1
			s.inj += 1
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
		s.days_ill += health.counters.days_ill
	var inj := maxf(1.0, s.inj)
	print("%-13s inj/yr %4.2f (nig %2d%% inj %2d%% ser %2d%%, acute %2d%%, escalated %2d%%, warned %2d%%/%2d%%) | days inj %3d out %3d | 0 inj %2d%% 3+ %2d%% | ill %4.2f (winter %2d%%, flu %2d%%, %2d days) | fatigue %2d | ability %+.2f | %.0fs" % [
		row[0], s.inj / float(n), 100 * s.niggle / inj, 100 * s.injury / inj, 100 * s.serious / inj,
		100 * s.acute / inj, 100 * s.escalated / inj, 100 * s.warned / maxf(1.0, s.overuse), 100 * s.slight / maxf(1.0, s.overuse),
		roundi(s.days_injured / float(n)), roundi(s.days_out / float(n)), 100 * s.zero / n, 100 * s.three_plus / n,
		s.ill / float(n), 100 * s.ill_winter / maxf(1.0, s.ill), 100 * s.flu / maxf(1.0, s.ill), roundi(s.days_ill / float(n)),
		roundi(s.fatigue / n), s.ability / n, (Time.get_ticks_msec() - t0) / 1000.0])
	print("              injuries in the first 8 weeks %.2f | capacity at week 26 ×%.2f | plan risk at week 12: Low %d%% Moderate %d%% High %d%%" % [
			s.early / float(n), s.cap26 / n, 100 * s.risk.low / n, 100 * s.risk.moderate / n, 100 * s.risk.high / n])
	if row[0] == "coach":
		print("              rivals injured at any time: %.1f%%" % (100.0 * s.rivals_out / (52.0 * n)))


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
