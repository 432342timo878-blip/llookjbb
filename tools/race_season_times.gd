extends SceneTree
## Dev tool: where do the race-time swings of a season come from? (playtest fix 1, 2026-10-10)
## Run: godot --headless --path . -s res://tools/race_season_times.gd [-- athletes [first_index [quick|sensible [health_off]]]]
## Each athlete plays 2 Nov 2026 to 31 Oct 2027 through the game loop (Balanced plan, health and form on, "sore"
## warnings answered "keep going", every meet they may enter entered) and RUNS every race: quick mode or a watched
## race answered with the sensible answers. Prints one line per race (time against the table time of the athlete's
## ability, with the form, the injury slowdown, the fatigue and the place) and, at the end, the spread of
## time / table time, how often two races in a row differ by more than 15 s, and the same split by what was
## wrong on the day (an injury or illness slowdown, tired, rusty), so the cause can be read off.

var game
var data
var F
var RP
var Cal
var SS
var H
var SP
var rows: Array = []   # per race: {athlete, date, meet, level, mix, table, time, form, slow, fat, place, field, status}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	RP = load("res://scripts/core/race_performance.gd")
	Cal = load("res://scripts/core/calendar.gd")
	SS = load("res://scripts/core/season_system.gd")
	H = load("res://scripts/core/health_system.gd")
	SP = load("res://scripts/core/season_plan.gd")
	var saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	H.model_enabled = true
	SS.offers_enabled = true
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 12
	var first := int(args[1]) if args.size() > 1 else 0
	var mode: String = args[2] if args.size() > 2 else "quick"
	if args.size() > 3 and args[3] == "health_off":
		H.model_enabled = false
	for i in n:
		_career(first + i, mode)
	_report()
	quit()


func _career(i: int, mode: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	var a = F.create({"first_name": "Test", "last_name": "Runner%d" % i, "gender": "male" if i % 2 == 0 else "female",
			"hometown": "Tampere", "club_id": "tap", "main_event": "800m",
			"birth_date": {"year": 2012, "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)},
			"answers": answers}, rng)
	F.spend(a, F.coach_spread(a, F.pool_for(answers)))
	game.start_career(a)
	game.get_system("health").rng.seed = 7000 + i
	_answer()
	for m in Cal.meets_between(game.date, {"year": 2027, "month": 10, "day": 31}):
		if Cal.can_enter(game.athlete, m, game.date).ok:
			game.enter(m.key)
	var end := 20271101
	var guard := 0
	while Cal.date_key(game.date) < end and guard < 500:
		guard += 1
		var r: String = game.advance_day()
		if r == game.RACE:
			_run_race(i, mode)
			r = game.finish_race()
		_answer()


func _answer() -> void:
	var guard := 0
	while not game.pending_event().is_empty() and guard < 20:
		guard += 1
		var e: Dictionary = game.pending_event()
		var answer := "ok"
		match str(e.get("kind", "")):
			"offer": answer = "balanced"
			"return": answer = "accept"
			"sore": answer = "keep"
		game.answer_event(e.id, answer)


func _run_race(i: int, mode: String) -> void:
	var rd = game.race_day
	var a = game.athlete
	var table: float = RP.time_for(RP.ability(a), a.gender)
	var guard := 0
	while not rd.is_done() and guard < 8:
		guard += 1
		var race = rd.start_round(mode != "quick", "pack")
		if mode == "quick":
			race.run()
		else:
			while not race.finished and race.time < 400.0:
				if not race.pending.is_empty():
					race.choose(race.sensible_choice(race.pending.id))
					continue
				race.step()
		rd.finish_round()
	for pr in rd.player_results:
		rows.append({"athlete": i, "date": rd.meet.date, "meet": rd.meet.name, "level": rd.meet.get("level", ""),
				"format": rd.format, "table": table, "time": float(pr.time), "form": rd.form, "slow": rd.slowdown,
				"fat": rd.fatigue, "place": pr.place, "field": pr.field, "status": pr.get("status", ""), "round": pr.round})


func _report() -> void:
	var by_ath := {}
	for r in rows:
		if r.status != "":
			continue
		if not by_ath.has(r.athlete):
			by_ath[r.athlete] = []
		by_ath[r.athlete].append(r)
	var all_ratio := []
	var diffs := 0
	var big := 0
	var big_why := {"slowdown": 0, "tired": 0, "rusty": 0, "other": 0}
	var shown := 0
	for ai in by_ath:
		var list: Array = by_ath[ai]
		for k in list.size():
			var r: Dictionary = list[k]
			all_ratio.append(r.time / r.table)
			if shown < 40 and ai - by_ath.keys()[0] < 3:
				shown += 1
				print("  #%d %s %-34s %-9s table %.1f time %.2f (%+.1f%%) form %+.2f%% slow %.1f%% fat %.0f place %d/%d" % [ai,
						Cal.format_day(r.date), r.meet.left(34), r.level, r.table, r.time, 100.0 * (r.time / r.table - 1.0),
						100.0 * r.form, 100.0 * r.slow, r.fat, r.place, r.field])
			if k > 0:
				diffs += 1
				var prev: Dictionary = list[k - 1]
				if absf(r.time / r.table - prev.time / prev.table) * r.table > 15.0 * 0.0 + 15.0:
					big += 1
					var why := "other"
					if r.slow > 0.0 or prev.slow > 0.0:
						why = "slowdown"
					elif r.fat > 25.0 or prev.fat > 25.0:
						why = "tired"
					elif r.form < -0.005 or prev.form > 0.005 or r.form > 0.005 or prev.form < -0.005:
						why = "rusty"
					big_why[why] += 1
	var mean := 0.0
	for x in all_ratio:
		mean += x
	mean /= maxi(all_ratio.size(), 1)
	var v := 0.0
	for x in all_ratio:
		v += pow(x - mean, 2)
	print("%d races by %d athletes; time / table time: mean %.3f, sd %.1f %% of the time" % [all_ratio.size(), by_ath.size(),
			mean, 100.0 * sqrt(v / maxi(all_ratio.size(), 1))])
	print("two races in a row more than 15 s apart (against the table): %d of %d = %.1f %%; why: %s" % [big, diffs,
			100.0 * big / maxi(diffs, 1), big_why])
	var groups := {"healthy and fresh": [], "injury / illness slowdown": [], "tired (fatigue > 25)": []}
	for r in rows:
		if r.status != "":
			continue
		var g := "healthy and fresh"
		if r.slow > 0.0:
			g = "injury / illness slowdown"
		elif r.fat > 25.0:
			g = "tired (fatigue > 25)"
		groups[g].append(r.time / r.table)
	for g in groups:
		var arr: Array = groups[g]
		if arr.is_empty():
			continue
		var m := 0.0
		for x in arr:
			m += x
		m /= arr.size()
		var s := 0.0
		for x in arr:
			s += pow(x - m, 2)
		print("  %-28s %3d races: mean %.3f, sd %.1f %%" % [g, arr.size(), m, 100.0 * sqrt(s / arr.size())])
	var starts := 0
	var counts := {}
	for r in rows:
		counts[r.level] = int(counts.get(r.level, 0)) + 1
	print("races by meet level: %s" % [counts])
