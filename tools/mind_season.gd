extends SceneTree
## Dev tool (session M1, GDD 4.9.4 / 4.9.7): plays seasons through the game loop and prints the moods week by week, by plan and
## policy, with a summary of how often each word came up.
## Run: godot --headless --path . -s res://tools/mind_season.gd -- [plan] [policy] [athletes] [weeks] [first] [quiet]
##   plan:    steady | balanced | ambitious | repeat (the coach's repeating week, never changed) | all   (default balanced)
##   policy:  sensible (the coach's meets, all three mental sessions, races run with the pack plan)
##            passive  (the coach's meets, no mental training)
##            racer    (every meet the athlete may enter, all three mental sessions)
##            norace   (no meets at all)
##            all                                                                                       (default sensible)
##   athletes: how many random 14-year-olds per row (default 1; boys and girls alternate)          weeks: default 52
##   first:   the first athlete's number (the same number = the same athlete in every row)          quiet: only the summaries
## The health model is on (its own dice), the moments engine has no real content yet (only the Sunday talk would add some: off
## here, as in every tool), the coach is the career's real club coach. Races are quick races (the pack plan). ~20 s an athlete-season.

var game
var data
var Cal
var F
var MI
var H


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	Cal = load("res://scripts/core/calendar.gd")
	F = load("res://scripts/core/athlete_factory.gd")
	MI = load("res://scripts/core/mind_system.gd")
	H = load("res://scripts/core/health_system.gd")
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	game.autosave = false
	var args := OS.get_cmdline_user_args()
	var plans := ["balanced"]
	var policies := ["sensible"]
	var n := 1
	var weeks := 52
	var first := 0
	if args.size() > 0:
		plans = ["steady", "balanced", "ambitious", "repeat"] if args[0] == "all" else [args[0]]
	if args.size() > 1:
		policies = ["sensible", "passive", "racer", "norace"] if args[1] == "all" else [args[1]]
	if args.size() > 2 and args[2].is_valid_int():
		n = args[2].to_int()
	if args.size() > 3 and args[3].is_valid_int():
		weeks = args[3].to_int()
	if args.size() > 4 and args[4].is_valid_int():
		first = args[4].to_int()
	var quiet := "quiet" in args
	print("== The moods week by week (session M1): %d athlete(s) per row, %d weeks from 2 Nov 2026" % [n, weeks])
	for plan in plans:
		for policy in policies:
			_row(plan, policy, n, weeks, first, quiet)
	quit()


func _row(plan: String, policy: String, n: int, weeks: int, first: int, quiet: bool) -> void:
	print("\n-- %s / %s" % [plan, policy])
	var counts := {"confidence": {}, "motivation": {}, "stress": {}}
	var total_weeks := 0
	var q_sum := 0.0
	var terms := []
	var races := 0
	for i in range(first, first + n):
		H.model_enabled = true
		var a = _athlete(i)
		if plan == "repeat":
			game.start_career(a, "repeat")
		else:
			game.start_career(a, "phases", plan)
		var ms = game.get_system("mind")
		if policy in ["sensible", "racer"]:
			ms.set_plan(["imagery", "relaxation", "self_talk"])
		var cs = game.get_system("coach")
		var c: Dictionary = cs.head()
		if not quiet:
			print("  athlete %d (%s, ambition %.0f, temperament %s): coach %s (%s, style %d, motivating %d, mental coaching %d), fit %s" % [
					i, a.gender, a.get_attr("ambition"), a.temperament, c.name, c.voice, int(c.style), int(c.attributes.motivating),
					int(c.attributes.mental_coaching), cs.fit()])
		for w in weeks:
			_enter_meets(policy)
			var monday: Dictionary = game.week_monday()
			var raced := []
			var end: int = Cal.date_key(game.add_days(monday, 7))
			var steps := 0
			while Cal.date_key(game.date) < end and steps < 30:
				steps += 1
				var r: String = game.advance_day()
				if r == game.RACE:
					terms.append(game.race_day.mind if game.race_day else 0.0)
					raced.append(_run_race())
					races += 1
				while not game.pending_event().is_empty():
					game.answer_event(game.pending_event().id, "ok")
			total_weeks += 1
			q_sum += ms.training_quality()
			for mood in counts:
				var id: String = ms.word(mood).id
				counts[mood][id] = int(counts[mood].get(id, 0)) + 1
			if not quiet:
				var phase := ""
				if game.season.mode == "phases":
					phase = str(game.season.week_for(monday).get("phase", ""))
				var hurt := ""
				for x in game.get_system("health").active():
					hurt = " +" + str(x.name)
				print("  %-16s %-18s conf %3.0f %-9s mot %3.0f %-8s str %3.0f %-11s q %.3f%s%s" % [Cal.format_day(monday), phase.substr(0, 18),
						ms.value("confidence"), _w(ms, "confidence"), ms.value("motivation"), _w(ms, "motivation"),
						ms.value("stress"), _w(ms, "stress"), ms.training_quality(), hurt,
						("  | " + "; ".join(raced)) if not raced.is_empty() else ""])
	var lines := []
	for mood in counts:
		var parts := []
		for w in data.mind.moods[mood].words:
			var k: int = int(counts[mood].get(str(w.id), 0))
			if k > 0:
				parts.append("%s %d %%" % [w.name, roundi(100.0 * k / total_weeks)])
		lines.append("%s: %s" % [mood, ", ".join(parts)])
	print("  SUMMARY %s / %s (%d weeks, %d races): %s" % [plan, policy, total_weeks, races, " | ".join(lines)])
	var t_sum := 0.0
	var t_on := 0
	for t in terms:
		t_sum += t
		if t != 0.0:
			t_on += 1
	print("    average training quality %.4f; races with a confidence term %d of %d (mean %+.3f %%)" % [q_sum / maxi(1, total_weeks),
			t_on, terms.size(), 100.0 * t_sum / maxi(1, terms.size())])


func _w(ms, mood: String) -> String:
	var a: int = ms.arrow(mood)
	return str(ms.word(mood).name) + (" ▲" if a > 0 else (" ▼" if a < 0 else ""))


func _enter_meets(policy: String) -> void:
	if policy == "norace":
		return
	for m in Cal.meets_between(game.date, game.add_days(game.date, 14)):
		if m.key in game.entries or m.get("watch", false):
			continue
		if (policy == "racer" or m.get("coach", false)) and Cal.can_enter(game.athlete, m, game.date).ok:
			game.enter(m.key)


## A quick race (the pack plan); returns "meet: place/field time (PB)".
func _run_race() -> String:
	var rd = game.race_day
	while not rd.is_done():
		var race = rd.start_round(false, "pack")
		race.run()
		rd.finish_round()
	var last: Dictionary = rd.player_results.back() if not rd.player_results.is_empty() else {}
	var text := "%s %d/%d %s%s" % [str(rd.meet.name).substr(0, 22), int(last.get("place", 0)), int(last.get("field", 0)),
			Cal.format_time(float(last.get("time", 0.0))), (" " + str(last.mark)) if str(last.get("mark", "")) != "" else ""]
	game.finish_race()
	return text


func _athlete(i: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	return F.create({
		"first_name": "Mind", "last_name": "Runner%d" % i, "gender": "male" if i % 2 == 0 else "female",
		"hometown": "Tampere", "club_id": "tap", "main_event": "800m",
		"birth_date": {"year": 2012, "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)
