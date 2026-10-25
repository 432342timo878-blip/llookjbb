extends SceneTree
## Dev check (session L2b, GDD 4.10 "L2b's questions"): causes everywhere, in a `real` career (fixed dice).
##   1. The data: data/causes.json has its parts; every `people_does` claim matches a storylet's relation condition (role = its
##      `from`, the limit = its `relation`); trust_does has every trust level; no bare he / his / him in it.
##   2. The records add up, week by week (8 weeks with races): an attribute's parts add up to its change; the stimulus by source
##      adds up to the week's stimulus; the race's share is recorded; each body area's strain log adds up day by day (after the day
##      before − faded + added = after) and ends at the strain now; each mood's drift target = base + its recorded pulls; every row
##      has a title and a detail.
##   3. Recording only: building every row and tap text three times leaves the career's save text identical.
##   4. A save in the middle of a week and its load play on to the same Sunday as the career that was not saved (save text equal).
##   5. People: an answer that moves a relationship records it (the person's log with the reply, the moment's `rel`) and the
##      result card shows it as a word; the roster's rows have a tap.
##   6. Older saves: without the new records the rows still build and say a cause was not recorded.
##   7. The screens: the planner's left column, "Last week in full" and the body / mood taps open their numbers.
## Run: godot --headless --path . -s res://tools/causes_check.gd      (~2 min; own save folder user://tool_saves/)
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var _fails := 0
var game
var data
var main
var WC
var cal


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()
	create_timer(600.0).timeout.connect(func():
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
	load("res://scripts/core/game_config.gd").fixed_seed = 23
	load("res://scripts/core/game_config.gd").use("real", {"health": true})
	await _frames(10)
	main = current_scene
	game = main.get_node("/root/Game")
	data = main.get_node("/root/Data")
	WC = load("res://scripts/ui/week_causes.gd")
	cal = load("res://scripts/core/calendar.gd")
	game.autosave = false
	game.start_career(_athlete())
	_answer_all()

	print("1. The data")
	_data_check()

	print("2. The records add up")
	await _weeks(8)

	print("3. Recording only")
	_read_only()

	print("4. A save in the middle of a week")
	_mid_week(SG)

	print("5. People")
	await _people()

	print("6. Older saves")
	_older()

	print("7. The screens")
	await _screens()

	SG.delete("causes_check")
	print("\n%s (%d failed)" % ["ALL CHECKS PASSED" if _fails == 0 else "SOME CHECKS FAILED", _fails])
	quit(0 if _fails == 0 else 1)


func _athlete():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	return load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Aino", "last_name": "Laine", "gender": "female", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 3, "day": 14},
		"answers": answers}, rng)


func _answer_all() -> void:
	var DT = load("res://scripts/core/dev_tools.gd")
	var guard := 0
	while not game.pending_event().is_empty() and guard < 50:
		guard += 1
		var e: Dictionary = game.pending_event()
		game.answer_event(e.id, DT.default_answer(e))


## Plays one day (a race in quick mode), answering stops. Returns what advance_day returned.
func _day() -> String:
	var r: String = game.advance_day()
	if r == game.RACE:
		var rd = game.race_day
		while not rd.is_done():
			var race = rd.start_round(false, "pack")
			race.run()
			rd.finish_round()
		r = game.finish_race()
	if r == game.STOP or not game.pending_event().is_empty():
		_answer_all()
	return r


## Plays to the end of the week (Sunday night): true when the week ended.
func _to_sunday() -> bool:
	var monday: int = cal.date_key(game.week_monday())
	for i in 10:
		var r := _day()
		if r == game.WEEK_DONE or cal.date_key(game.week_monday()) != monday:
			return true
	return false


# --- 1 ----------------------------------------------------------------------------------------------------------------------

func _data_check() -> void:
	var c: Dictionary = data.causes
	var need := ["small", "attr", "body", "mood", "people", "people_does", "trust_does", "tests", "slots", "invites", "report", "more", "less"]
	_ok("data/causes.json has its parts", need.all(func(k): return c.has(k)))
	var claims := 0
	var good := 0
	for role in c.people_does:
		if str(role).begins_with("_"):
			continue
		for x in c.people_does[role]:
			claims += 1
			var s := {}
			for st in data.storylets:
				if str(st.id) == str(x.get("storylet", "")):
					s = st
			var rel: Array = s.get("when", {}).get("relation", [])
			var ok: bool = not s.is_empty() and str(s.get("from", "")) == str(role) and rel.size() == 2
			if ok and x.has("below"):
				ok = rel[0] == null and float(rel[1]) == float(x.below)
			elif ok and x.has("from"):
				ok = float(rel[0]) == float(x.from) and rel[1] == null
			if ok:
				good += 1
	_ok("every 'does' line of a relationship is a real storylet condition (%d of %d)" % [good, claims], claims > 0 and good == claims)
	var levels: Dictionary = data.coaching.trust.words
	_ok("trust_does has every trust level", levels.keys().all(func(k): return c.trust_does.has(k)))
	var text := FileAccess.get_file_as_string("res://data/causes.json")
	var re := RegEx.create_from_string("(?<![{A-Za-z])(he|his|him|He|His|Him)(?![}A-Za-z])")
	_ok("no bare he / his / him in data/causes.json", re.search(text) == null)


# --- 2 ----------------------------------------------------------------------------------------------------------------------

func _weeks(n: int) -> void:
	# Two races entered in the weeks played (the race's share of the Sunday stimulus).
	var entered := 0
	for m in cal.meets_between(game.add_days(game.date, 3), game.add_days(game.date, 7 * n - 3)):
		if entered < 2 and not m.key in game.entries and cal.can_enter(game.athlete, m, game.date).ok:
			game.enter(m.key)
			entered += 1
	var parts_ok := true
	var src_ok := true
	var strain_ok := true
	var drift_ok := true
	var rows_ok := true
	var race_share := 0
	var drifts := 0
	var attr_rows := 0
	var worst := 0.0
	var bad := ""
	for w in n:
		if not _to_sunday():
			_ok("week %d ends" % w, false)
			return
		var r: Dictionary = game.last_report
		for id in r.get("attrs", {}):
			var d := float(r.attrs[id].after) - float(r.attrs[id].before)
			var sum := 0.0
			for k in r.get("parts", {}).get(id, {}):
				sum += float(r.parts[id][k])
			var clamped: bool = float(r.attrs[id].after) >= 20.0 or float(r.attrs[id].after) <= 1.0
			if absf(sum - d) > 1e-9 and not clamped:
				parts_ok = false
				bad = "%s %.6f vs %.6f" % [id, sum, d]
			worst = maxf(worst, absf(sum - d))
		for id in r.get("stimulus", {}):
			var sum := 0.0
			for k in r.get("sources", {}).get(id, {}):
				sum += float(r.sources[id][k])
				if str(k).begins_with("race:"):
					race_share += 1
			if absf(sum - float(r.stimulus[id])) > 1e-9 * maxf(1.0, float(r.stimulus[id])):
				src_ok = false
		var h = game.get_system("health")
		var log: Array = h.strain_log
		for i in range(1, log.size()):
			for aid in log[i].after:
				var prev := float(log[i - 1].after.get(aid, 0.0))
				var add := 0.0
				for s in log[i].add.get(aid, {}):
					add += float(log[i].add[aid][s])
				if absf(prev - float(log[i].fade.get(aid, 0.0)) + add - float(log[i].after[aid])) > 1e-6:
					strain_ok = false
		for aid in h.strain:
			if float(h.strain[aid]) > 0.0 and absf(float(log.back().after.get(aid, 0.0)) - float(h.strain[aid])) > 1e-12:
				strain_ok = false
		var mind = game.get_system("mind")
		for m in ["confidence", "motivation", "stress"]:
			if mind.drift.has(m):
				drifts += 1
				var t := float(data.mind.drift[m].base)
				for p in mind.drift[m].pulls:
					t += float(p.delta)
				if absf(clampf(t, 0.0, 100.0) - float(mind.drift[m].target)) > 1e-9:
					drift_ok = false
		for row in WC.rows(r):
			if str(row.title) == "" or str(row.detail) == "":
				rows_ok = false
				bad += " row %s:%s" % [row.kind, row.id]
			if str(row.kind) == "attr":
				attr_rows += 1
	_ok("an attribute's parts add up to its change, every week (worst difference %s)%s" % [str(worst), "" if parts_ok else " " + bad], parts_ok)
	_ok("the stimulus by source adds up to the week's stimulus", src_ok)
	_ok("the race's share of the Sunday stimulus is recorded (%d attribute-weeks)" % race_share, race_share > 0)
	_ok("each body area's strain log adds up day by day and ends at the strain now", strain_ok)
	_ok("each mood's Sunday drift target = base + its recorded pulls (%d drifts)" % drifts, drift_ok and drifts > 0)
	_ok("every row has a title and a detail (%d attribute rows over the weeks)%s" % [attr_rows, "" if rows_ok else bad], rows_ok and attr_rows > 0)


# --- 3 ----------------------------------------------------------------------------------------------------------------------

func _read_only() -> void:
	var before := JSON.stringify(game.to_dict())
	for i in 3:
		WC.rows(game.last_report)
		WC.tired_now()
		for area in data.health.areas.list:
			WC.area_now(str(area.id))
		for m in ["confidence", "motivation", "stress"]:
			WC.mood_now(m)
		var ms = game.get_system("moments")
		for pid in ms.people:
			WC.person_lines(ms, ms.people[pid], ms.people[pid].get("log", []))
	var after := JSON.stringify(game.to_dict())
	_ok("building every row and tap text 3 times changes nothing (save text identical, %d chars)" % before.length(), before == after)


# --- 4 ----------------------------------------------------------------------------------------------------------------------

func _mid_week(SG) -> void:
	for e in game.entries.duplicate():   # (no race in these weeks: a race uses the global dice)
		game.withdraw(e)
	_to_sunday()
	for i in 3:
		_day()
	SG.save("causes_check")
	_to_sunday()
	var a := JSON.stringify(game.to_dict())
	var report_a := JSON.stringify(game.last_report)
	SG.load_slot("causes_check")
	_to_sunday()
	var b := JSON.stringify(game.to_dict())
	_ok("a save on Thursday and its load play to the same Sunday (report identical)", report_a == JSON.stringify(game.last_report))
	# (The rivals' weekly training draws from the global dice, which a save does not keep (since R1): left out.)
	var da: Dictionary = JSON.parse_string(a)
	var db: Dictionary = JSON.parse_string(b)
	da.erase("rivals")
	db.erase("rivals")
	var diff := _diff(da, db, "")
	_ok("... and the whole career's save text (but the rivals) is identical (%d chars)%s" % [a.length(), "" if diff == "" else ": " + diff], diff == "")


## Where two parsed save texts first differ ("" when equal).
func _diff(x, y, path: String) -> String:
	if typeof(x) != typeof(y):
		return path + " (type)"
	if x is Dictionary:
		for k in x:
			if not y.has(k):
				return path + "/" + str(k) + " (missing after load)"
			var d := _diff(x[k], y[k], path + "/" + str(k))
			if d != "":
				return d
		for k in y:
			if not x.has(k):
				return path + "/" + str(k) + " (only after load)"
		return ""
	if x is Array:
		if x.size() != y.size():
			return path + " (size %d vs %d)" % [x.size(), y.size()]
		for i in x.size():
			var d := _diff(x[i], y[i], path + "/" + str(i))
			if d != "":
				return d
		return ""
	return "" if x == y else "%s (%s vs %s)" % [path, str(x), str(y)]


# --- 5 ----------------------------------------------------------------------------------------------------------------------

func _people() -> void:
	var ms = game.get_system("moments")
	var answered := {}
	var guard := 0
	while answered.is_empty() and guard < 20:
		guard += 1
		game.current_week()   # (session L3a: the new week opens as the planner does: its invitations and story beat are posted)
		for m in ms.pending():
			var s: Dictionary = ms.storylet(str(m.get("storylet", "")))
			for rep in s.get("replies", []):
				if float(rep.get("effects", {}).get("relation", 0.0)) != 0.0 and str(ms.people.get(str(m.from), {}).get("role", "")) != "coach" \
						and m.replies.any(func(x): return str(x.id) == str(rep.id)):
					ms.answer(str(m.id), str(rep.id))
					# (session L3a: what waits is an invitation or a story beat; an invitation's answer happens on its evening)
					var days := 0
					while m.has("invite") and str(m.answer) == "" and days < 9:
						days += 1
						_day()
					answered = ms.moment(str(m.id))
					break
			if not answered.is_empty():
				break
		if answered.is_empty():
			_to_sunday()
	_ok("a moment with a relationship effect was found and answered", not answered.is_empty())
	if answered.is_empty():
		return
	var p: Dictionary = ms.people.get(str(answered.from), {})
	var last: Dictionary = p.get("log", [{}]).back()
	var label := ""
	for r in answered.replies:
		if str(r.id) == str(answered.answer):
			label = str(r.label)
	_ok("the person's log has the change with the reply (\"%s\")" % label, str(last.get("reply", "")) == label and float(last.get("delta", 0.0)) != 0.0)
	_ok("the moment keeps whose relationship moved (rel)", not answered.get("rel", []).is_empty())
	var PU = load("res://scripts/ui/people_ui.gd")
	_ok("the result card is shown for it", load("res://scripts/ui/moment_event_panel.gd").has_result({"kind": "moment", "moment": answered.id}))
	var panel: Control = PU.changes_panel(answered.get("changes", []), answered)
	root.add_child(panel)
	await _frames(2)
	var rows := []
	_collect_meta(panel, rows)
	var word := ""
	for l in _labels(panel):
		if " → " in l or "▲" in l or "▼" in l:
			word = l
	_ok("the result card shows the relationship as a word with a tap (%s)" % word, not rows.is_empty() and word != "")
	panel.queue_free()
	var roster: Control = PU.roster(ms, "family")
	root.add_child(roster)
	await _frames(2)
	var rrows := []
	_collect_meta(roster, rrows)
	var ropen := rrows.filter(func(r): return _tap(r)).size()
	_ok("the family's people are rows that open their numbers on a tap (%d of %d)" % [ropen, rrows.size()], rrows.size() >= 1 and ropen == rrows.size())
	roster.queue_free()


# --- 6 ----------------------------------------------------------------------------------------------------------------------

func _older() -> void:
	var d: Dictionary = game.to_dict()
	var keep := JSON.stringify(d)
	d.last_report.erase("parts")
	d.last_report.erase("attrs")
	d.last_report.erase("sources")
	d.last_report.erase("slots")
	d.systems.health.erase("strain_log")
	d.systems.mind.erase("drift")
	d.systems.mind.erase("week_start")
	for pid in d.systems.moments.get("people", {}):
		d.systems.moments.people[pid].erase("log")
	game.from_dict(JSON.parse_string(JSON.stringify(d)))
	var rows: Array = WC.rows(game.last_report)
	var said := rows.filter(func(x): return str(x.kind) == "attr").all(func(x): return str(data.causes.attr.not_recorded) in str(x.detail))
	_ok("an older save's week builds its rows (%d), each attribute says its cause was not recorded" % rows.size(), said)
	_ok("an older save's body tap says it records from now on", str(data.causes.body.none_yet) in WC.area_now(str(data.health.areas.list[0].id)))
	game.from_dict(JSON.parse_string(keep))


# --- 7 ----------------------------------------------------------------------------------------------------------------------

func _screens() -> void:
	main.get_node("/root/Router").go("career_hub")
	await _frames(6)
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	hub._show("week")
	await _frames(4)
	var rows := []
	_collect_meta(hub, rows)
	var kinds := {}
	for r in rows:
		kinds[str(r.get_meta("cause_row")).get_slice(":", 0)] = true
	_ok("the planner has rows with a tap: %s" % ", ".join(kinds.keys()), kinds.has("tired") and kinds.has("mood"))
	var opened := 0
	var closed := []
	for r in rows:
		if _tap(r):
			opened += 1
		else:
			closed.append(str(r.get_meta("cause_row")))
	_ok("every row of the planner opens its numbers on a tap (%d of %d)%s" % [opened, rows.size(), "" if closed.is_empty() else "; not: " + ", ".join(closed)],
			opened == rows.size() and opened > 0)
	hub._show("report")
	await _frames(4)
	var rrows := []
	_collect_meta(hub, rrows)
	var ropen := 0
	for r in rrows:
		if _tap(r):
			ropen += 1
	_ok("\"Last week in full\" has rows that open their numbers (%d of %d)" % [ropen, rrows.size()], ropen == rrows.size() and ropen >= 5)
	var small := []
	_small(hub, small)
	_ok("nothing tappable on these screens is under 44 px (%s)" % ", ".join(small), small.is_empty())


## Taps a row (a left-button press and release): true when the detail under it opened.
func _tap(row: Control) -> bool:
	var box := row.get_parent()
	if box is HFlowContainer:
		return _pill_tap(row)
	if box == null or box.get_child_count() < 2:
		return _pill_tap(row)
	var detail: Control = box.get_child(box.get_child_count() - 1)
	if detail == row:
		return _pill_tap(row)
	var was := detail.visible
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = Vector2(5, 5)
		row.gui_input.emit(ev)
	var opened := detail.visible != was
	if opened:
		for pressed in [true, false]:   # (close it again)
			var ev2 := InputEventMouseButton.new()
			ev2.button_index = MOUSE_BUTTON_LEFT
			ev2.pressed = pressed
			ev2.position = Vector2(5, 5)
			row.gui_input.emit(ev2)
	return opened


## A phone pill: its tap fills the one detail box under the flow.
func _pill_tap(row: Control) -> bool:
	var flow := row.get_parent()
	if flow == null or not flow is HFlowContainer:
		return false
	var detail: Control = flow.get_parent().get_child(flow.get_parent().get_child_count() - 1)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = Vector2(5, 5)
		row.gui_input.emit(ev)
	return detail.visible


func _collect_meta(node: Node, out: Array) -> void:
	if node is Control and node.has_meta("cause_row") and node.is_visible_in_tree():
		out.append(node)
	for c in node.get_children():
		_collect_meta(c, out)


func _labels(node: Node) -> Array:
	var out := []
	if node is Label:
		out.append(node.text)
	for c in node.get_children():
		out.append_array(_labels(c))
	return out


func _small(node: Node, out: Array) -> void:
	if node is Control and node.is_visible_in_tree() and (node.has_meta("cause_row") or str(node.name) == "MoreCauses"):
		if node.size.y < 43.5:
			out.append("%s %d px" % [str(node.get_meta("cause_row", node.name)), roundi(node.size.y)])
	for c in node.get_children():
		_small(c, out)
