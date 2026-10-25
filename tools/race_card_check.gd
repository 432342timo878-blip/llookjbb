extends SceneTree
## Dev check (session L2a, GDD 4.10 "L2's questions"): the "what this race did" card and the scratch card, through the real hub and
## race screen of a `real` career (fixed dice).
##   1. The data: data/race_recap.json has every text the card uses; the coach's scratch lines have no bare he / his.
##   2. A race of each kind ends on the card: a single race (quick), a watched race, sections and heats (quick). The race day has
##      ended when the card shows (the date moved on), the card has the result, the splits (4 parts), Form, what changed (the race's
##      Sunday training, tiredness, consistency), the coach's line, the next race; sections name the section, heats the rounds.
##      Full results opens the tables, Back to the card returns; Continue goes back to the hub.
##   3. Recording only: building the card again and again changes nothing in the career (its save text is the same).
##   4. The cards are kept: Game.card(id), a save and load gives the same cards, an older save without them loads with none.
##   5. The planner's race strap opens the card page; the scratch: every cause has its why, the coach's line (also after his own
##      advice, not posted twice), what it means, the next race; the hub shows the scratch card once; the strap says "Scratched".
##   6. Play week resumes after the card (finish_race = end_race_day + resume_after_race).
## Run: godot --headless --path . -s res://tools/race_card_check.gd      (~1 min; own save folder user://tool_saves/)
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var _fails := 0
var game
var data
var router
var main
var cal
var RDS


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()
	create_timer(400.0).timeout.connect(func():
		print("  FAIL  the check did not finish (a SCRIPT ERROR? read stderr)")
		quit(1))


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var SG = load("res://scripts/core/save_game.gd")
	SG.DIR = "user://tool_saves/"
	load("res://scripts/core/game_config.gd").fixed_seed = 11
	load("res://scripts/core/game_config.gd").use("real", {"health": true})
	await _frames(10)
	main = current_scene
	router = main.get_node("/root/Router")
	game = main.get_node("/root/Game")
	data = main.get_node("/root/Data")
	cal = load("res://scripts/core/calendar.gd")
	RDS = load("res://scripts/core/race_day.gd")
	game.autosave = false
	router.go("new_career")
	await _frames(5)
	var wizard: Control = main.get_node("ScreenHost").get_child(-1)
	wizard._choices.first_name = "Eetu"
	wizard._choices.last_name = "Koskinen"
	wizard._choices.gender = "male"
	wizard._choices.hometown = "Tampere"
	wizard._choices.club_id = ""
	for q in data.background_questions:
		wizard._choices.answers[q.id] = 0
	for step in 4:
		wizard._on_next()
		await _frames(3)
	wizard._on_next()
	await _frames(5)
	_answer_all()

	print("1. The data")
	_data_check()

	print("2. A race of each kind ends on the card")
	var single: Dictionary = await _race("single", false, 1)
	await _race("single", true, 2)
	await _race("sections", false, 3)
	await _race("heats", false, 4)

	print("3. Recording only")
	_read_only()

	print("4. The cards are kept")
	_kept(SG, single)

	print("5. The planner's strap, the scratch")
	await _strap_and_scratch()

	print("6. Play week resumes after the card")
	await _resume()

	print("\n%s (%d failed)" % ["ALL CHECKS PASSED" if _fails == 0 else "SOME CHECKS FAILED", _fails])
	quit(0 if _fails == 0 else 1)


func _answer_all() -> void:
	var DT = load("res://scripts/core/dev_tools.gd")
	var guard := 0
	while not game.pending_event().is_empty() and guard < 50:
		guard += 1
		var e: Dictionary = game.pending_event()
		game.answer_event(e.id, DT.default_answer(e))


func _hub() -> Control:
	return main.get_node("ScreenHost").get_child(-1)


# --- 1 -------------------------------------------------------------------------------------------------------------------

func _data_check() -> void:
	var r: Dictionary = data.recap
	var need := ["keep", "title", "meet_line", "of_field", "section_line", "out_line", "rounds_line", "delta_pb", "delta_vs", "splits_line",
			"splits_who", "splits_who_group", "form_head", "form_line", "form_terms", "form_detail", "changes_head", "more", "nothing_else",
			"mood_detail", "attr_causes", "attr_detail", "later_title", "later_cause", "later_detail", "body_cause", "body_detail",
			"tired_cause", "tired_detail", "coach_role", "messages_head", "goal_line", "next_race", "next_when", "next_none", "continue",
			"full_results", "back_to_card", "scratch_title", "scratch_why", "scratch_day", "scratch_target", "scratch_days_back",
			"strap_scratched", "strap_scratched_line", "form_short", "form_slow"]
	var missing := need.filter(func(k): return not r.has(k))
	_ok("race_recap.json has every text the card uses %s" % ("" if missing.is_empty() else str(missing)), missing.is_empty())
	var rx := RegEx.create_from_string("(?i)\\b(he|his|him)\\b")
	var bad := []
	for key in ["coach", "coach_plain"]:
		for line in data.coach_talk.scratched.get(key, []):
			if rx.search(str(line)) != null:
				bad.append(line)
	_ok("the coach's scratch-card lines exist and have no bare he / his", data.coach_talk.scratched.has("coach") and bad.is_empty())


# --- 2 -------------------------------------------------------------------------------------------------------------------

## Finds a meet of format `fmt` (from the career's date on), enters it, jumps to its day and plays to the race; runs it through the
## race screen (quick, or watched and run to the end) and checks the card. Returns the card.
func _race(fmt: String, watched: bool, n: int) -> Dictionary:
	var label := "%d. %s, %s" % [n, fmt, "watched" if watched else "quick"]
	RDS.format_override = "heats" if fmt == "heats" else ""
	var meet := {}
	var from: Dictionary = game.add_days(game.date, 1)
	for m in cal.meets_between(from, game.add_days(from, 500)):
		if m.get("watch", false) or m.key in game.entries:
			continue
		var cand = RDS.new(m, game.athlete, game.rivals)
		var ok: bool = cand.format == fmt and (fmt == "single") == (not cand.is_group_round())
		if ok:
			meet = m
			break
	if meet.is_empty():
		RDS.format_override = ""
		_ok("%s: a meet of that format" % label, false)
		return {}
	game.enter(meet.key)
	game.date = meet.date.duplicate()
	game._week = null
	game.current_week()
	var r: String = game.advance_day()
	var guard := 0
	while r == game.STOP and guard < 20:
		guard += 1
		_answer_all()
		r = game.advance_day()
	RDS.format_override = ""
	if r != game.RACE:
		_ok("%s: the race day comes (got %s)" % [label, r], false)
		return {}
	router.go("race")
	await _frames(6)
	var screen: Control = main.get_node("ScreenHost").get_child(-1)
	var day_key: int = cal.date_key(game.date)
	var rounds := 0
	while rounds < 4:
		rounds += 1
		if watched:
			screen._start(true)
			await _frames(2)
			screen._running = false
			var race = screen._race
			race.print_events = false
			race.interactive = false
			race.run()
			screen._show_result()
		else:
			screen._start(false)
		await _frames(3)
		if screen._result.done:
			break
		_ok("%s: a round before the final shows the tables, no card yet" % label, screen._card.is_empty() and not screen._day_ended)
		screen._show_pre()
		await _frames(2)
	var c: Dictionary = screen._card
	_ok("%s (%s): the race ends on the card, the day has ended (%s → %s)" % [label, meet.name, day_key, cal.date_key(game.date)],
			not c.is_empty() and screen._day_ended and cal.date_key(game.date) > day_key and game.race_day == null)
	if c.is_empty():
		return {}
	var view := _find(screen, "RaceRecapView")
	_ok("%s: the race screen shows RaceRecapView" % label, view != null)
	var ok_res: bool = str(c.status) != "" or (int(c.place) >= 1 and int(c.place) <= int(c.field) and float(c.time) > 0.0)
	_ok("%s: result %s / %s in %.2f %s %s" % [label, c.place, c.field, float(c.time), c.mark, c.delta_text], ok_res)
	var sp: Dictionary = c.get("splits", {})
	var you: Array = sp.get("you", [])
	_ok("%s: 200 m splits %s vs %s (%s)" % [label, you, sp.get("other", []), sp.get("label", "")],
			you.size() == 4 and float(you[0]) > 20.0 and float(you[0]) < 60.0 and sp.get("other", []).size() == 4)
	_ok("%s: Form on the day '%s' (fresh %s, sharp %s)" % [label, c.form.get("word", ""), c.form.get("fresh", ""), c.form.get("sharp", "")],
			str(c.form.get("word", "")) != "")
	var kinds: Array = c.changes.map(func(x): return str(x.kind))
	var titles: Array = c.changes.map(func(x): return "%s %s" % [x.title, x.value])
	_ok("%s: what changed: %s" % [label, ", ".join(titles)], "later" in kinds and "tired" in kinds and
			c.changes.any(func(x): return str(x.kind) == "attr" and str(x.id) == "consistency"))
	_ok("%s: every change has a cause or a detail for the tap" % label, c.changes.all(func(x): return str(x.get("detail", "")) != ""))
	_ok("%s: the coach's line '%s' (%s)" % [label, c.coach.line, c.coach.name], str(c.coach.line) != "" and str(c.coach.name) != "")
	_ok("%s: the sub line '%s'" % [label, c.sub], str(c.sub).contains("800 m"))
	_ok("%s: the next race %s" % [label, c.next], c.next.is_empty() or int(c.next.days) >= 1)
	if fmt == "sections":
		_ok("%s: the section's place '%s' and the section winner '%s'" % [label, c.line, sp.label], str(c.line).contains("section") and str(sp.label).contains("section"))
	if fmt == "heats":
		_ok("%s: the rounds %s / '%s'" % [label, c.rounds, c.line], c.rounds.size() >= 2 or str(c.line).begins_with("Out"))
	_ok("%s: the card is kept (Game.card)" % label, not game.card(str(c.id)).is_empty())
	# Full results and back.
	view.results_pressed.emit()
	await _frames(3)
	_ok("%s: Full results shows the tables" % label, screen._full_open and _find(screen, "RaceRecapView") == null)
	screen._full_open = false
	screen._show_result(false)
	await _frames(3)
	_ok("%s: back to the card" % label, _find(screen, "RaceRecapView") != null)
	screen._leave()
	await _frames(5)
	_ok("%s: Continue goes back to the hub" % label, _hub().has_method("_show_pending_event"))
	_answer_all()
	return c


func _find(node: Node, cls: String) -> Node:
	for ch in node.get_children():
		if ch.get_script() != null and ch.get_script().get_global_name() == cls:
			return ch
		var f := _find(ch, cls)
		if f != null:
			return f
	return null


# --- 3 -------------------------------------------------------------------------------------------------------------------

func _read_only() -> void:
	var RR = load("res://scripts/core/race_recap.gd")
	# A race day to read (not run: the reads need only its meet and its numbers).
	var meet := {}
	for m in cal.meets_between(game.add_days(game.date, 1), game.add_days(game.date, 300)):
		meet = m
		break
	var rd = RDS.new(meet, game.athlete, game.rivals)
	var cards_before: int = game.race_cards.size()
	var before := JSON.stringify(game.to_dict())
	for i in 3:
		var b: Dictionary = RR.before(rd)
		RR.build(rd, b)   # ({} : this race was not run; the reads still happen)
		rd.player_results = [{"round": "Race", "place": 3, "field": 8, "time": 130.0, "status": "", "mark": ""}]
		RR.build(rd, b)
		rd.player_results = []
		RR.scratch_why("player")
		RR.plan_until(meet)
		RR.sore_area_name()
	var after := JSON.stringify(game.to_dict())
	_ok("reading the career for a card 3 times changes nothing in it (save text identical, %d chars)" % before.length(), before == after and game.race_cards.size() == cards_before)
	# Only the causes of THIS race's evening (an earlier race the same day, or older news, is not this race's cause).
	var a := {"date": {"year": 2027, "month": 1, "day": 9}, "delta": 10.0, "text": "A personal best at X"}
	var b2 := {"date": {"year": 2027, "month": 1, "day": 9}, "delta": -4.0, "text": "Slower than your level at X"}
	var a2 := a.duplicate(true)   # (the same news again tonight: equal, but a new entry)
	_ok("new_entries: only what came after the snapshot", RR.new_entries([a], [a, b2]) == [b2] and RR.new_entries([], [a]) == [a]
			and RR.new_entries([a], [a]).is_empty() and RR.new_entries([{"x": 1}], [a, b2]) == [a, b2]
			and RR.new_entries([a], [a, a2]).size() == 1 and is_same(RR.new_entries([a], [a, a2])[0], a2))


# --- 4 -------------------------------------------------------------------------------------------------------------------

func _kept(SG, single: Dictionary) -> void:
	var n: int = game.race_cards.size()
	_ok("the cards of this check are kept (%d)" % n, n >= 4)
	var before := JSON.stringify(game.race_cards)
	SG.save("race_card_check")
	SG.load_slot("race_card_check")
	_ok("a save and load gives the same cards", JSON.stringify(game.race_cards) == before)
	_ok("a card's date is a date of ints after loading", typeof(game.race_cards[0].date.day) == TYPE_INT)
	var d: Dictionary = game.to_dict()
	d.erase("race_cards")
	game.from_dict(d)
	_ok("an older save without cards loads with none", game.race_cards.is_empty())
	SG.load_slot("race_card_check")
	_ok("... and the saved one has them again", game.race_cards.size() == n and not game.card(str(single.get("id", ""))).is_empty())
	SG.delete("race_card_check")


# --- 5 -------------------------------------------------------------------------------------------------------------------

func _strap_and_scratch() -> void:
	# Play to the end of the week of the last race (a week report with the race in it), then the planner's strap opens the card.
	var guard := 0
	while guard < 30:
		guard += 1
		var r: String = game.advance_day()
		if r == game.STOP:
			_answer_all()
		elif r == game.RACE:
			game.race_day = null   # (not expected: no other race entered this week)
		elif r == game.WEEK_DONE:
			break
	router.go("career_hub")
	await _frames(6)
	var hub := _hub()
	hub._show("week")
	await _frames(4)
	var straps: Array = []
	_collect(hub, "OpenCard", straps)
	_ok("the planner's last week has a race strap that opens a card (%d)" % straps.size(), not straps.is_empty())
	if not straps.is_empty():
		straps[0].pressed.emit()
		await _frames(4)
		_ok("the strap opens the card page (view %s)" % hub._view, hub._view == "race_card" and _find(hub, "RaceRecapView") != null)
		hub._show("week")
		await _frames(3)
	# The scratch, by every cause.
	for cause in ["player", "school", "coach"]:
		var meet := {}
		for m in cal.meets_between(game.add_days(game.date, 2), game.add_days(game.date, 6)):
			if not m.key in game.entries and cal.can_enter(game.athlete, m, game.date).ok:
				meet = m
				break
		if meet.is_empty():
			for m in cal.meets_between(game.add_days(game.date, 2), game.add_days(game.date, 120)):
				if not m.key in game.entries and cal.can_enter(game.athlete, m, game.date).ok:
					meet = m
					break
		if meet.is_empty():
			_ok("a meet to scratch from (%s)" % cause, false)
			continue
		game.enter(meet.key)
		game.current_week()
		var ms = game.get_system("moments")
		var before: int = ms.thread("coach").size()
		game.scratch_race(meet.key, cause)
		var c: Dictionary = game.scratch_card
		var posted: int = ms.thread("coach").size() - before
		_ok("scratch (%s) %s: why '%s', coach '%s', means %s, next %s" % [cause, meet.name, c.get("why", ""), c.get("coach", {}).get("line", ""),
				c.get("means", []), c.get("next", {})], not c.is_empty() and str(c.why) != "" and str(c.coach.line) != "")
		_ok("scratch (%s): his thread got %d message(s) (1 for yours / school, 0 after his own advice)" % [cause, posted], posted == (0 if cause == "coach" else 1))
		_ok("scratch (%s): the card is kept" % cause, not game.card(str(c.id)).is_empty() and str(game.card(str(c.id)).kind) == "scratch")
		var thisweek: bool = cal.date_key(meet.date) <= cal.date_key(game.add_days(game.week_monday(), 6))
		if thisweek:
			_ok("scratch (%s): it says what the day is now ('%s')" % [cause, c.means], not c.means.is_empty())
	hub._refresh_week_ui()
	await _frames(4)
	var overlay = hub._event_overlay
	_ok("the hub shows the scratch card once", overlay != null and overlay.visible and _has_text(overlay, str(data.recap.scratch_title)))
	var oks: Array = []
	_collect_text(overlay, str(data.recap.ok), oks)
	if not oks.is_empty():
		oks[0].pressed.emit()
		await _frames(3)
	_ok("OK closes it", game.scratch_card.is_empty() and (overlay == null or not overlay.visible or not _has_text(overlay, str(data.recap.scratch_title))))
	# The scratched strap in next week's planner: the last scratch was in the week just played? Make one in a week, end the week.
	var w = game.current_week()
	var meet2 := {}
	for m in cal.meets_between(game.add_days(game.date, 1), game.add_days(w.monday, 6)):
		if not m.key in game.entries and cal.can_enter(game.athlete, m, game.date).ok:
			meet2 = m
			break
	if meet2.is_empty():
		print("  (no meet left in this week to show the scratched strap; skipped)")
		return
	game.enter(meet2.key)
	game.scratch_race(meet2.key)
	game.scratch_card = {}
	guard = 0
	while guard < 10:
		guard += 1
		var r: String = game.advance_day()
		if r == game.STOP:
			_answer_all()
		elif r == game.WEEK_DONE:
			break
	hub._show("week")
	await _frames(4)
	_ok("next week's planner has a 'Scratched' strap", _has_text(hub, str(data.recap.strap_scratched)))


func _collect(node: Node, name: String, out: Array) -> void:
	for ch in node.get_children():
		if ch.name == name:
			out.append(ch)
		_collect(ch, name, out)


func _collect_text(node: Node, text: String, out: Array) -> void:
	for ch in node.get_children():
		if ch is Button and (ch as Button).text == text:
			out.append(ch)
		_collect_text(ch, text, out)


func _has_text(node: Node, text: String) -> bool:
	for ch in node.get_children():
		if ch is Label and (ch as Label).text.contains(text):
			return true
		if _has_text(ch, text):
			return true
	return false


# --- 6 -------------------------------------------------------------------------------------------------------------------

func _resume() -> void:
	# A race in the middle of a week, reached by Play week: finish_race (= end + resume) plays on to Sunday or a stop.
	var meet := {}
	for m in cal.meets_between(game.add_days(game.date, 1), game.add_days(game.date, 400)):
		if not m.key in game.entries and not m.get("watch", false) and cal.weekday(m.date) <= 4 and cal.can_enter(game.athlete, m, game.date).ok:
			meet = m
			break
	if meet.is_empty():
		print("  (no midweek meet found; skipped)")
		return
	game.enter(meet.key)
	game.date = cal.monday_of(meet.date)
	game._week = null
	game.current_week()
	var r: String = game.advance_week()
	var guard := 0
	while r == game.STOP and guard < 20:
		guard += 1
		_answer_all()
		r = game.advance_week()
	if r != game.RACE:
		_ok("Play week reaches the race (got %s)" % r, false)
		return
	var rd = game.race_day
	var race = rd.start_round(false, "pack")
	race.run()
	rd.story = {"line": "x"}
	rd.finish_round()
	var cards: int = game.race_cards.size()
	var end: String = game.end_race_day()
	_ok("end_race_day stops after the race day (%s) with its card" % end, end in [game.DAY_DONE, game.STOP] and game.race_cards.size() == cards + 1)
	var res: String = game.resume_after_race()
	_ok("resume_after_race plays on (%s, today %s)" % [res, cal.format_day(game.date)], res in [game.WEEK_DONE, game.STOP, game.RACE] or cal.weekday(game.date) == 0)
