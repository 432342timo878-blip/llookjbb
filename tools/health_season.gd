extends SceneTree
## Dev tool: watch the health model (GDD 4.6) at work. Plays one athlete's first season day by day through
## the game and prints every day: what was done, fatigue, sore body areas, injuries and illness, and the
## events (with the answer this "player" gave). The coach's recommended meets are entered (races are run
## in quick mode).
## Run: godot --headless --path . -s res://tools/health_season.gd -- [plan] [policy] [seed] [days]
##   plan: coach (default) / hard / ramp / lazy     policy: neutral (default) / careful / ignore
##   neutral = follows injury limits, keeps going when sore; careful = takes it easy when sore, rests when
##   painful; ignore = keeps going and trains through every limit that isn't locked.
##   seed: a number for a different athlete and different luck (default 1); days: how long (default 364).

const HARD := [["intervals_800", "strength"], ["tempo_run", "drills"], ["long_run"], ["intervals_800", "hill_sprints"],
		["tempo_run"], ["long_run", "speed_strides"], ["fartlek"]]
const LAZY := [["easy_run"], [], [], ["easy_run"], [], [], []]

var game
var data
var Cal
var H
var RP


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Loaded at runtime: autoload names (Data, Game) only exist once the tree is running.
	game = root.get_node("Game")
	data = root.get_node("Data")
	Cal = load("res://scripts/core/calendar.gd")
	H = load("res://scripts/core/health_system.gd")
	RP = load("res://scripts/core/race_performance.gd")
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	game.autosave = false
	var args := OS.get_cmdline_user_args()
	var plan_id: String = args[0] if args.size() > 0 else "coach"
	var policy: String = args[1] if args.size() > 1 else "neutral"
	var seed_value: int = args[2].to_int() if args.size() > 2 else 1
	var days: int = args[3].to_int() if args.size() > 3 else 364

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	var a = load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test", "last_name": "Runner", "gender": "male" if seed_value % 2 == 1 else "female",
		"hometown": "Tampere", "club_id": "tap", "main_event": "800m",
		"birth_date": {"year": 2012, "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)
	game.start_career(a)
	var health = game.get_system("health")
	health.rng.seed = seed_value
	for m in Cal.meets_between(game.START_DATE, game.add_days(game.START_DATE, 364)):
		if Cal.coach_recommends(a, m, game.START_DATE):
			game.enter(m.key)
	print("%s %s, %s, born %s (maturation: %s). Plan: %s, policy: %s, seed %d." % [
			"Boy" if a.gender == "male" else "Girl", a.full_name(), a.training_base, Cal.format_day(a.birth_date),
			a.maturation, plan_id, policy, seed_value])
	print("Durability %.1f, recovery rate %.1f (hidden), professionalism %.1f, injury proneness %.1f (hidden). 800 m ability %.2f.\n" % [
			a.get_attr("durability"), a.get_attr("recovery_rate"), a.get_attr("professionalism"),
			a.get_attr("injury_proneness"), RP.ability(a)])
	print("Sessions marked * were changed by an injury limit, + by the player. Soreness only shows sore areas.\n")

	var start_ability: float = RP.ability(a)
	var w := 0
	for i in days:
		if Cal.weekday(game.date) == 0 and game.current_week().day == 0:
			game.training_plan = _plan(plan_id, w)
			game.current_week()
			health.refresh()
			w += 1
		_policy(health, policy)
		var week = game.current_week()
		var by: Dictionary = week.changed_by(week.day)
		var r: String = game.advance_day()
		if r == game.RACE:
			var rd = game.race_day
			while not rd.is_done():
				var race = rd.start_round(false, "pack")
				race.run()
				rd.finish_round()
			game.finish_race()
		var e: Dictionary = game.day_log[-1]
		print(_day_line(e, by, health))
		for ev in game.events:
			if ev.id in e.events:
				var answer := ""
				if ev.stop:
					var choice := "keep" if ev.get("kind", "") == "sore" else "ok"
					if ev.get("kind", "") == "sore" and policy == "careful":
						choice = "easy"
					game.answer_event(ev.id, choice)
					answer = "  → you chose: %s" % _choice_label(ev, choice)
				print("      >> %s%s" % [ev.title, answer])
				if ev.get("kind", "") == "diagnosis":
					print("         %s" % ev.text.replace("\n\n", "\n         "))
		while not game.pending_event().is_empty():   # anything left (none expected): just OK it
			game.answer_event(game.pending_event().id, "ok")
		if Cal.weekday(e.date) == 6:
			print("   -- week %d: fatigue avg %d, 800 m ability %.2f (%+.2f), plan risk %s, load vs normal %d%%" % [w,
					roundi(game.last_report.get("fatigue_avg", 0.0)), RP.ability(a), RP.ability(a) - start_ability,
					H.RISK_NAMES[health.plan_risk(game.training_plan)], health.load_vs_normal(game.current_week())])
	print("\n" + health.debug_text())
	print("800 m ability %.2f → %.2f (%+.2f)" % [start_ability, RP.ability(a), RP.ability(a) - start_ability])
	quit()


func _day_line(e: Dictionary, by: Dictionary, health) -> String:
	var what: String
	if e.race != "":
		what = "RACE: " + Cal.get_meet(e.race).get("name", e.race)
	elif e.sessions.is_empty():
		what = "Rest"
	else:
		var names := []
		for sid in e.sessions:
			names.append(data.get_session(sid).name)
		what = " + ".join(names)
	var mark := ""
	if by.values().has("injury"):
		mark = "*"
	elif not by.is_empty():
		mark = "+"
	var level: String = "" if e.race != "" or e.sessions.is_empty() else data.health.intensity[e.intensity].name
	var sore := []
	for area_id in e.get("soreness", {}):
		var lvl := int(e.soreness[area_id])
		if lvl >= 1:
			sore.append("%s %s" % [_area_name(area_id), H.soreness_word(lvl).to_lower()])
	var line := "%-17s %-42s %-6s fatigue %2d" % [Cal.format_day(e.date), (what + mark).left(42), level, roundi(e.fatigue)]
	if not sore.is_empty():
		line += " | " + ", ".join(sore)
	var hurt := []
	for x in health.active():
		hurt.append("%s: %s, %d d left" % [x.name, x.allowed, x.days_left])
	if not hurt.is_empty():
		line += " | " + "; ".join(hurt)
	return line


func _area_name(area_id: String) -> String:
	for x in H.areas():
		if x.id == area_id:
			return x.name
	return area_id


func _choice_label(ev: Dictionary, choice: String) -> String:
	for c in ev.choices:
		if c.id == choice:
			return c.label
	return "OK"


## "ramp" builds from the coach plan to the hard plan over 8 weeks, a day at a time.
func _plan(plan_id: String, w: int) -> Array:
	var coach: Array = data.training.coach_plan.days
	match plan_id:
		"hard": return HARD.duplicate(true)
		"lazy": return LAZY.duplicate(true)
		"ramp":
			if w >= 8:
				return HARD.duplicate(true)
			var hard_days := roundi((w + 1) * 7 / 8.0)
			var plan := []
			for d in 7:
				plan.append((HARD[d] if d < hard_days else coach[d]).duplicate())
			return plan
	return coach.duplicate(true)


func _policy(health, policy: String) -> void:
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
