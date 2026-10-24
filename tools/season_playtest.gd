extends SceneTree
## Dev tool (M2 step 5): plays a whole season (2 Nov – 31 Oct) through the REAL career hub, like a player would:
## Play week while healthy, Next day while hurt, answering every stop event with the policy's choice, races run in
## quick mode on the race screen. The health model is on. It takes a screenshot the first time each kind of stop
## event appears and at a few other moments, and prints a summary: stop events per kind, weeks with a stop, how
## long the hub took to redraw after each button press, and how big and slow the autosave is.
## Run (needs a window, so not --headless; add `--resolution 390x844` before `-s` for the phone layout):
##   godot --path . --rendering-driver opengl3 -s res://tools/season_playtest.gd -- <out_dir> [plan] [policy] [seed] [days]
##   plan: coach (default, the repeating coach week) / hard (a hard repeating week) / season (the coach's season plan on
##         the ★, with the coach's offers: they take the ★ plan; easing back in is accepted)
##   policy: careful (default: easy when sore) / neutral (keeps going when sore) / player (careful + a real reply to every
##         moment and school stop, picked at random from the seed, and the coach's goals set: plays like a person who
##         answers; careful and neutral answer "ok", which a moment counts as no answer)
##   seed: another athlete and other luck (default 1); days: how long (default 364).
## The summary also counts the stops by kind (week talk, proposal, people by thread, school, goals, market...) week by
## week, and the messages that did not stop (check-in 2026-10-18).
## Uses its own save folder (user://tour_saves/), never the player's saves.

const HARD := [["intervals_800", "strength"], ["tempo_run", "drills"], ["long_run"], ["intervals_800", "hill_sprints"],
		["tempo_run"], ["long_run", "speed_strides"], ["fartlek"]]

var _out := "user://playtest"
var _main: Node
var _game
var _data
var _cal
var _router
var _shots := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var plan_id: String = args[1] if args.size() > 1 else "coach"
	var policy: String = args[2] if args.size() > 2 else "careful"
	var seed_value: int = args[3].to_int() if args.size() > 3 else 1
	var days: int = args[4].to_int() if args.size() > 4 else 364

	var saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tour_saves/"
	await _frames(10)
	_main = current_scene
	_game = _main.get_node("/root/Game")
	_data = _main.get_node("/root/Data")
	_router = _main.get_node("/root/Router")
	_cal = load("res://scripts/core/calendar.gd")

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var answers := {}
	for q in _data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	var a = load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Aino", "last_name": "Virtanen", "gender": "male" if seed_value % 2 == 1 else "female",
		"hometown": "Tampere", "club_id": "tap", "main_event": "800m",
		"birth_date": {"year": 2012, "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)
	if plan_id == "season":
		_game.start_career(a)   # the coach's season plan on the ★, with the coach's offer first (M2 step 6f)
	else:
		_game.start_career(a, "repeat")
	var health = _game.get_system("health")
	health.rng.seed = seed_value
	if plan_id == "hard":
		_game.season.repeat_week = load("res://scripts/core/week_plan.gd").make(HARD.duplicate(true))
	for m in _cal.meets_between(_game.START_DATE, _game.add_days(_game.START_DATE, 364)):
		if _cal.coach_recommends(a, m, _game.START_DATE):
			_game.enter(m.key)
	_router.go("career_hub")
	await _frames(5)
	var hub := _hub()
	print("Playtest: %s, %s, born %s, plan %s, policy %s, seed %d, window %dx%d" % [
			"boy" if a.gender == "male" else "girl", a.full_name(), _cal.format_day(a.birth_date), plan_id, policy,
			seed_value, root.size.x, root.size.y])

	var end_key: int = _cal.date_key(_game.add_days(_game.START_DATE, days))
	var stops := {}
	var stop_weeks := {}
	var by_week := {}
	_answer_rng.seed = seed_value * 7919 + 13
	var advance_ms := []
	var event_ms := []
	var presses := 0
	var guard := 0
	# Session L1a: a stop comes either AT THE PLANNER (the week not started yet: Sunday evening's or Monday morning's, the planner is
	# open anyway) or MID-WEEK (a day of the week was played; a race day counts as one). Clicks: the planner's answers, Play week /
	# Next day, "Play anyway" when choices are left, and each mid-week stop's answer.
	var midweek := {}        # week -> mid-week stops (races included)
	var planner_stops := {}  # week -> stops at the planner
	var clicks := {}         # week -> clicks
	while _cal.date_key(_game.date) < end_key and guard < 3000:
		guard += 1
		var e: Dictionary = _game.pending_event()
		var wk: int = _cal.date_key(_game.week_monday())
		var cw = _game.current_week()
		var at_planner: bool = cw.day == 0 and not cw.day_started
		if not e.is_empty():
			var kind: String = e.get("kind", e.source)
			stops[kind] = int(stops.get(kind, 0)) + 1
			stop_weeks[wk] = true
			var cat := _category(e)
			var row: Dictionary = by_week.get(wk, {})
			row[cat] = int(row.get(cat, 0)) + 1
			by_week[wk] = row
			if at_planner:
				planner_stops[wk] = int(planner_stops.get(wk, 0)) + 1
			else:
				midweek[wk] = int(midweek.get(wk, 0)) + 1
			clicks[wk] = int(clicks.get(wk, 0)) + 1
			await _frames(3)
			if kind == "offer":   # the career-start offer and the autumn offer for next season both get a shot
				kind += "_first" if e.get("first", false) else "_next"
			await _shot_once("event_" + kind)
			var choice := _choice(e, policy)
			var t0 := Time.get_ticks_usec()
			hub._on_event_answer(e.id, choice)
			event_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
			await _frames(2)
			if hub.has_method("_end_result_card"):   # (a moment's result card, e.g. the people's moments of session P1)
				hub._end_result_card()
			if kind == "diagnosis":
				await _shot_once("after_diagnosis_today_card")
			continue
		if health.soreness().any(func(x): return int(x.level) > 0) and not _shots.has("today_card_a_bit_sore"):
			hub._show("overview")
			await _frames(3)
			await _shot_once("today_card_a_bit_sore")
		if not health.injuries.is_empty() and not _shots.has("today_card_" + health.injuries[0].tier):
			hub._show("overview")
			await _frames(3)
			await _shot_once("today_card_" + health.injuries[0].tier)
		if _game.season.return_week_on(_game.date) > 0 and not _shots.has("easing_back_in_week"):
			hub._show("overview")
			await _frames(3)
			await _shot_once("easing_back_in_week")
		var injured: bool = not health.injuries.is_empty()
		if at_planner:   # the Sunday planner: the player policy answers what waits; the others leave it (Play anyway)
			if policy == "player":
				clicks[wk] = int(clicks.get(wk, 0)) + _answer_planner()
			await _shot_once("planner_first")
		var left: int = load("res://scripts/ui/week_planner.gd").open_choices().size()
		if not injured and left > 0:
			clicks[wk] = int(clicks.get(wk, 0)) + 1   # ("Play anyway")
		clicks[wk] = int(clicks.get(wk, 0)) + 1
		var t0 := Time.get_ticks_usec()
		hub._on_advance(not injured)
		advance_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		presses += 1
		await _frames(2)
		if _game.race_day != null:
			midweek[wk] = int(midweek.get(wk, 0)) + 1   # (a race day is a mid-week stop: the week's payoff)
			await _run_race(policy)
			hub = _hub()
			await _shot_once("after_first_race")
		if not _game.last_report.is_empty():
			await _shot_once("week_report")
		hub = _hub()

	print("\n== Summary")
	print("Played to %s (%d button presses; Next day while hurt, Play week otherwise)." % [_cal.format_day(_game.date), presses])
	print("Stop events: %s; weeks with a stop: %d of %d" % [JSON.stringify(stops), stop_weeks.size(), int(ceil(days / 7.0))])
	_print_weeks(by_week, days)
	_print_loop(midweek, planner_stops, clicks, days)
	print("Hub redraw after Next day / Play week: average %.1f ms, slowest %.1f ms; after answering an event: average %.1f ms, slowest %.1f ms" % [
			_avg(advance_ms), _max(advance_ms), _avg(event_ms), _max(event_ms)])
	var t1 := Time.get_ticks_usec()
	saves.save(saves.AUTOSAVE)
	var size := FileAccess.get_file_as_bytes(saves.DIR + saves.AUTOSAVE + ".json").size()
	print("Autosave: %.1f ms, %d KB" % [(Time.get_ticks_usec() - t1) / 1000.0, size / 1024])
	print(health.debug_text())
	quit()


## What the player answers: the sore warning by policy, the coach's offer the ★, easing back in accepted, everything
## else OK. A race tomorrow: race.
func _choice(e: Dictionary, policy: String) -> String:
	if e.get("kind", "") == "offer":
		return str(e.pick)
	if e.get("kind", "") == "return":
		return "accept"
	if e.get("kind", "") == "sore":
		var ids: Array = e.choices.map(func(c): return c.id)
		if "easy" in ids:
			return "easy" if policy != "neutral" else "keep"
		return "keep"
	if policy == "player":
		if e.get("kind", "") == "goals":
			return "set"
		var choices: Array = e.get("choices", [])
		if not choices.is_empty():
			return str(choices[_answer_rng.randi_range(0, choices.size() - 1)].id)
	return "ok"


var _answer_rng := RandomNumberGenerator.new()


## What kind of stop it is, in the words of the check-in: the coach's week talk, his proposals, goals, suggestions,
## the market's messages, the people's moments by thread, school stops, health and season stops.
func _category(e: Dictionary) -> String:
	var kind := str(e.get("kind", e.source))
	if kind != "moment":
		if kind.begins_with("school") or kind.begins_with("lukio") or kind.begins_with("matric"):
			return "school:" + kind
		return kind
	var moments = _game.get_system("moments")
	var m: Dictionary = moments.moment(str(e.get("moment", "")))
	if m.is_empty():
		return "moment:?"
	if bool(m.get("talk", false)):
		return "week_talk"
	var mk := str(m.get("kind", "moment"))
	if mk != "moment":
		return mk   # proposal / goal / suggest / market / rule
	return "people:" + str(m.get("thread", "?")) if str(m.get("thread", "")) != "coach" else "coach_moment"


## Session L1a: what the planner leaves open, answered like a player (each a click): the coach's notes (Make it easy / Keep mine with
## a reason / left), the moments waiting (a reply), a meet-and-tests clash (an option). Returns the clicks.
func _answer_planner() -> int:
	var n := 0
	var cp = _game.get_system("proposals")
	for p in cp.open_notes(_game.week_monday()):
		var pick: String = ["accept", "veto_fine", ""][_answer_rng.randi_range(0, 2)]
		if pick != "":
			cp.answer_note(str(p.id), pick)
			n += 2 if pick != "accept" else 1   # (Keep mine + its reason)
	var ms = _game.get_system("moments")
	for m in ms.waiting():
		ms.answer(str(m.id), str(m.replies[_answer_rng.randi_range(0, m.replies.size() - 1)].id))
		n += 1
	var clash: Dictionary = load("res://scripts/ui/week_planner.gd")._clash()
	if not clash.is_empty():
		var ss = _game.get_system("school")
		ss.settle_week(int(clash.monday), str(clash.meet), str(clash.choices[_answer_rng.randi_range(0, clash.choices.size() - 1)].id))
		n += 1
	return n


## The loop's numbers (session L1a, GDD 4.10 decision 1): mid-week stops a week (races included), weeks without one, stops at the
## planner, clicks a week (a normal week = Play week alone, or with a "Play anyway").
func _print_loop(midweek: Dictionary, planner_stops: Dictionary, clicks: Dictionary, days: int) -> void:
	var weeks := 0
	var mid := 0
	var mid_no_race := 0
	var quiet := 0
	var plan := 0
	var all_clicks := []
	var monday: Dictionary = _cal.monday_of(_game.START_DATE)
	while _cal.date_key(monday) < _cal.date_key(_game.add_days(_game.START_DATE, days)):
		weeks += 1
		var wk: int = _cal.date_key(monday)
		mid += int(midweek.get(wk, 0))
		if int(midweek.get(wk, 0)) == 0:
			quiet += 1
		plan += int(planner_stops.get(wk, 0))
		all_clicks.append(int(clicks.get(wk, 0)))
		monday = _game.add_days(monday, 7)
	print("Clicks by week: %s" % [all_clicks])   # (session L1b: to compare two runs week by week)
	all_clicks.sort()
	print("\n== The loop (session L1a)")
	print("Mid-week stops a week (races included): %.2f; weeks with none: %d of %d; stops at the planner a week: %.2f" % [
			mid / float(maxi(1, weeks)), quiet, weeks, plan / float(maxi(1, weeks))])
	var total := 0
	for c in all_clicks:
		total += c
	print("Clicks a week: average %.2f, median %d, most %d" % [total / float(maxi(1, weeks)), all_clicks[all_clicks.size() / 2] if not all_clicks.is_empty() else 0,
			all_clicks.back() if not all_clicks.is_empty() else 0])
	# Session L1b: the invitations that landed in the slots (each a planner card until answered).
	var inv: Array = _game.get_system("moments").fired.filter(func(f): return bool(f.get("invite", false)))
	var by := {}
	for f in inv:
		by[str(f.storylet)] = int(by.get(str(f.storylet), 0)) + 1
	print("Invitations in the slots: %d in %d weeks %s" % [inv.size(), weeks, JSON.stringify(by)])


## Week by week: the stops by kind and the moments that only waited in the threads (no stop).
func _print_weeks(by_week: Dictionary, days: int) -> void:
	var moments = _game.get_system("moments")
	var quiet := {}
	for f in moments.fired:
		if not bool(f.get("stop", false)):
			var t: Dictionary = Time.get_datetime_dict_from_unix_time(int(f.day) * 86400 + 43200)   # (StoryletSystem.day_no)
			var d := {"year": t.year, "month": t.month, "day": t.day}
			var wk: int = _cal.date_key(_cal.monday_of(d))
			quiet[wk] = int(quiet.get(wk, 0)) + 1
	print("\n== Stops week by week (kind x count; 'quiet' = moments that waited in the threads without stopping)")
	var totals := {}
	var hist := {}
	var monday: Dictionary = _cal.monday_of(_game.START_DATE)
	var weeks := 0
	while _cal.date_key(monday) < _cal.date_key(_game.add_days(_game.START_DATE, days)):
		weeks += 1
		var wk: int = _cal.date_key(monday)
		var row: Dictionary = by_week.get(wk, {})
		var n := 0
		var parts := []
		for k in row:
			n += int(row[k])
			totals[k] = int(totals.get(k, 0)) + int(row[k])
			parts.append("%s %d" % [k, row[k]])
		hist[mini(n, 5)] = int(hist.get(mini(n, 5), 0)) + 1
		print("%s  stops %d  %s%s" % [_cal.format_day(monday), n, ", ".join(parts), "" if not quiet.has(wk) else "  | quiet %d" % quiet[wk]])
		monday = _game.add_days(monday, 7)
	var all := 0
	for k in totals:
		all += int(totals[k])
	var keys := totals.keys()
	keys.sort_custom(func(x, y): return int(totals[x]) > int(totals[y]))
	print("Per week on average over %d weeks: all stops %.2f" % [weeks, all / float(maxi(1, weeks))])
	for k in keys:
		print("  %-28s %4d  (%.2f a week)" % [k, totals[k], totals[k] / float(maxi(1, weeks))])
	var q := 0
	for k in quiet:
		q += int(quiet[k])
	print("  quiet moments (no stop)      %4d  (%.2f a week)" % [q, q / float(maxi(1, weeks))])
	print("Weeks by number of stops: %s (5 = 5 or more)" % JSON.stringify(hist))


## A race day reached from the hub: the race screen, quick mode, through every round, then back to the hub.
func _run_race(_policy: String) -> void:
	await _frames(4)
	var screen: Control = _main.get_node("ScreenHost").get_child(-1)
	var rounds := 0
	while rounds < 4 and screen.has_method("_start"):
		rounds += 1
		screen._start(false)
		await _frames(2)
		if screen._result.done:
			break
		screen._show_pre()
		await _frames(2)
	await _shot_once("race_result")
	screen._leave()
	await _frames(5)
	if _game.race_day != null:   # a second race in the same Play week
		await _run_race(_policy)


func _hub() -> Control:
	return _main.get_node("ScreenHost").get_child(-1)


func _avg(list: Array) -> float:
	var total := 0.0
	for x in list:
		total += x
	return total / maxf(1.0, list.size())


func _max(list: Array) -> float:
	var best := 0.0
	for x in list:
		best = maxf(best, x)
	return best


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot_once(name: String) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name, " on ", _cal.format_day(_game.date))
