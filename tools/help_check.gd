extends SceneTree
## Dev tool: checks the in-game help (GDD 5 "Help").
##   1. data/help.json: every entry has a title, a version and sections with a heading and text (at most MAX_WORDS
##      words); every "See also" points to a topic.
##   2. Every screen's "?": visits the wizard, the hub's tabs and Training pages, the day editor, the health stop
##      panels and the race (before, a decision, the result), presses each "?" and checks that it opens an entry
##      that exists, in the right place (hub on PC: the side slot; elsewhere: a HelpOverlay).
##   3. Every screen entry is opened by some "?", every topic is reachable through "See also".
##   4. See also / Back, the "new" dot (gone once read, back when the version goes up), Esc closes the help.
## Run (headless is fine):
##   godot --headless --path . -s res://tools/help_check.gd
## Prints ALL CHECKS PASSED at the end; read stderr too (a SCRIPT ERROR can abort a check part-way).

const MAX_WORDS := 60

var _fails := 0
var _checks := 0
var _opened := {}   # entry id -> where its "?" was found
var Help        # scripts/ui/help.gd (loaded at run time: it uses the Data autoload)
var _button_script
var _overlay_script


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	load("res://scripts/core/health_system.gd").model_enabled = false
	Help = load("res://scripts/ui/help.gd")
	_button_script = load("res://scripts/ui/help_button.gd")
	_overlay_script = load("res://scripts/ui/help_overlay.gd")
	Help.SEEN_PATH = "user://tool_help_seen.cfg"
	Help.reset_seen()
	await _frames(10)
	var main := current_scene
	var data = main.get_node("/root/Data")

	print("--- 1. data/help.json")
	_check_data(data.help)

	print("--- 2. every screen's ?")
	var router = main.get_node("/root/Router")
	var game = main.get_node("/root/Game")
	router.go("dev_menu")   # (debug builds only; the tool is one)
	await _frames(5)
	await _press_help(main.get_node("ScreenHost").get_child(-1), "dev menu", "dev_menu", false)
	router.go("new_career")
	await _frames(5)
	var wizard: Control = main.get_node("ScreenHost").get_child(-1)
	wizard._choices.first_name = "Aino"
	wizard._choices.last_name = "Virtanen"
	for q in data.background_questions:
		wizard._choices.answers[q.id] = 0
	for step in 5:
		await _frames(3)
		await _press_help(wizard, "wizard step %d" % (step + 1), "new_career", false)
		if step < 4:
			wizard._on_next()
	wizard._on_next()   # start the career
	await _frames(6)
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	# A new career opens with the coach's offer of the three plans (M2 step 6f).
	hub._show_pending_event()
	await _frames(4)
	_check(game.pending_event().get("kind", "") == "offer", "a new career starts with the coach's offer")
	await _press_help(hub._event_overlay, "offer panel", "season_offer", false)
	_check(_overlay_on_top(hub), "the offer's help sheet is above the stop-event layer")
	_close_overlays(hub)
	game.answer_event(game.pending_event().id, "later")
	hub._show_pending_event()
	game.advance_day()
	hub._refresh_week_ui()

	# The hub: each tab, and the Training tab's three pages.
	for v in [["overview", "overview"], ["progress", "progress"], ["calendar", "calendar"], ["rankings", "rankings"],
			["report", "report"], ["training", "training_season"]]:
		hub._show(v[0])
		await _frames(3)
		await _press_help(hub, "hub " + v[0], v[1], true)
	hub._phase_open = "spring_base"
	hub._show("training")
	await _frames(3)
	await _press_help(hub, "hub phase editor", "phase_editor", true)
	hub._phase_open = ""
	game.season.switch_to_repeat(game.week_monday())
	hub._show("training")
	await _frames(3)
	await _press_help(hub, "hub repeating week", "training_repeat", true)
	game.use_season_plan()
	hub._show("training")
	await _frames(3)

	# Help follows the tab: opened on Overview, then Calendar is shown.
	hub._show("overview")
	await _frames(2)
	hub._toggle_help()
	hub._show("calendar")
	await _frames(3)
	_check(hub._help_stack == ["calendar"], "help opened with the header ? follows the tab (stack %s)" % [hub._help_stack])
	hub._toggle_help()
	_check(hub._help_stack.is_empty(), "the header ? closes the help again")

	# The day editor (tomorrow), its "?", and the help covering it: Close returns to the day.
	hub._show("overview")
	hub._open_day(2)
	await _frames(4)
	await _press_help(hub._editor, "day editor", "day_editor", false, hub)
	var pc: bool = hub._help != null
	if pc:
		_check(hub._help_stack == ["day_editor"] and not hub._editor.visible and hub._help.visible,
				"day editor ? opens its help over the editor (PC side slot)")
		hub._help.close_requested.emit()
	else:
		_check(hub._help_stack == ["day_editor"] and _overlay_on_top(hub), "day editor ? opens the help sheet over the day")
		_close_overlays(hub)
	await _frames(2)
	_check(hub._help_stack.is_empty() and hub._editor.visible and (hub._side.visible if pc else hub._sheet.visible),
			"closing the help shows the day editor again")
	# Escape: the help first, then the day.
	hub._open_help("overview", true)
	_key(hub, KEY_ESCAPE)
	_check(hub._help_stack.is_empty() and hub._selected_day == 2, "Esc closes the help first, the day stays open")
	_key(hub, KEY_F1)
	_check(hub._help_stack == ["overview"], "F1 opens the help of the tab")
	_key(hub, KEY_ESCAPE)
	hub._close_day()

	# See also and Back (PC side slot).
	hub._open_help("overview", true)
	await _frames(2)
	var see: Button = _find_button_prefix(hub, "See also: Race form")
	_check(see != null, "Overview help has a See also: Race form button")
	if see:
		see.pressed.emit()
		await _frames(2)
		_check(hub._help_stack == ["overview", "form"], "See also opens the topic (stack %s)" % [hub._help_stack])
		var back: Button = _find_button_prefix(hub, "◀  Back to Overview")
		_check(back != null, "a topic has ◀ Back to the screen's help")
		if back:
			back.pressed.emit()
			await _frames(2)
			_check(hub._help_stack == ["overview"], "Back returns to the screen's help")
	hub._close_help()

	# The health stop panels (health model on for these two).
	load("res://scripts/core/health_system.gd").model_enabled = true
	var health = game.get_system("health")
	health._ensure_started()
	var news := []
	health._start(data.get_injury("shin_splints"), game.date, news)
	health._post_diagnosis(news[0])
	hub._show_pending_event()
	await _frames(4)
	await _press_help(hub._event_overlay, "diagnosis panel", "health_event", false)
	_check(_overlay_on_top(hub), "the health help sheet is above the stop-event layer")
	_close_overlays(hub)
	game.answer_event(game.pending_event().id, "ok")
	health.injuries.clear()
	health.levels.clear()
	health.warned.clear()
	health.strain["calves"] = 60.0
	health._update_soreness(true)
	hub._show_pending_event()
	await _frames(4)
	if game.pending_event().get("kind", "") == "sore":
		await _press_help(hub._event_overlay, "sore panel", "health_event", false)
		_close_overlays(hub)
		game.answer_event(game.pending_event().id, "keep")
	else:
		_check(false, "a sore stop event was posted")
	hub._show_pending_event()
	for area in health.strain:
		health.strain[area] = 0.0
	health.levels.clear()
	health._apply_restrictions(game.current_week())
	# Easing back in after a layoff (M2 step 6f).
	health.days_without_running = 20
	game.get_system("season")._post_return(health, game.add_days(game.date, 1))
	hub._show_pending_event()
	await _frames(4)
	await _press_help(hub._event_overlay, "easing back in panel", "return_block", false)
	_close_overlays(hub)
	game.answer_event(game.pending_event().id, "decline")
	hub._show_pending_event()
	health.days_without_running = 0
	load("res://scripts/core/health_system.gd").model_enabled = false

	# The race: before, a decision, the result.
	var cal = load("res://scripts/core/calendar.gd")
	for m in cal.meets_between(game.date, game.add_days(game.date, 120)):
		if cal.coach_recommends(game.athlete, m, game.date):
			game.enter(m.key)
	var guard := 0
	while game.race_day == null and guard < 40:
		guard += 1
		if game.advance_week() != game.RACE:
			while not game.pending_event().is_empty():
				game.answer_event(game.pending_event().id, "ok")
	_check(game.race_day != null, "reached a race day")
	if game.race_day != null:
		router.go("race")
		await _frames(6)
		var screen: Control = main.get_node("ScreenHost").get_child(-1)
		await _press_help(screen, "race before", "race_before", false)
		_close_overlays(screen)
		screen._start(true)
		await _frames(2)
		var race = screen._race
		var steps := 0
		while race.pending.is_empty() and not race.finished and steps < 20000:
			race.step()
			steps += 1
		await _frames(3)
		_check(not race.pending.is_empty(), "a race decision came up")
		await _press_help(screen._decision, "race decision card", "race_running", false)
		_check(screen._help != null, "the race knows its help is open (it waits)")
		_close_overlays(screen)
		await _press_help(screen, "race running (header)", "race_running", false)
		_close_overlays(screen)
		screen._decision.visible = false
		race.choose(race.pending.options[0].id)
		while not race.finished:
			if not race.pending.is_empty():
				race.choose(race.pending.options[0].id)
			race.step()
		screen._running = false
		screen._show_result()
		await _frames(3)
		await _press_help(screen, "race result", "race_result", false)
		_close_overlays(screen)

	print("--- 3. every entry is used")
	for id in data.help.get("screens", {}):
		_check(_opened.has(id), "screen entry '%s' is opened by a ?" % id)
	var linked := {}
	for kind in ["screens", "topics"]:
		for id in data.help.get(kind, {}):
			for s in data.help[kind][id].get("sections", []):
				for t in s.get("see", []):
					linked[t] = true
	for id in data.help.get("topics", {}):
		_check(linked.has(id), "topic '%s' is linked by a See also" % id)
	for id in _opened:
		_check(Help.exists(id), "entry '%s' (from %s) exists" % [id, _opened[id]])

	print("--- 4. the new dot")
	Help.reset_seen()
	var b = _button_script.new("calendar")
	root.add_child(b)
	await _frames(1)
	_check(b._dot.visible, "an unread entry shows the dot")
	Help.mark_seen("calendar")
	_check(not b._dot.visible, "the dot goes once the entry was read")
	data.help.screens.calendar.version = int(data.help.screens.calendar.version) + 1
	b.refresh()
	_check(b._dot.visible, "the dot comes back when the entry's version goes up")
	data.help.screens.calendar.version = int(data.help.screens.calendar.version) - 1
	b.queue_free()
	Help.reset_seen()

	print("%d checks, %d failed" % [_checks, _fails])
	print("ALL CHECKS PASSED" if _fails == 0 else "SOME CHECKS FAILED")
	quit()


# --- Data ------------------------------------------------------------------------------------------------

func _check_data(help: Dictionary) -> void:
	var topics: Dictionary = help.get("topics", {})
	_check(help.get("screens", {}).size() > 0 and topics.size() > 0, "help.json has screens and topics")
	for kind in ["screens", "topics"]:
		for id in help.get(kind, {}):
			var e: Dictionary = help[kind][id]
			_check(str(e.get("title", "")) != "", "%s: title" % id)
			_check(int(e.get("version", 0)) >= 1, "%s: version" % id)
			_check(e.get("sections", []).size() > 0, "%s: has sections" % id)
			for s in e.get("sections", []):
				var words: int = str(s.get("text", "")).split(" ", false).size()
				_check(str(s.get("heading", "")) != "" and words > 0, "%s: section '%s' has a heading and text" % [id, s.get("heading", "")])
				_check(words <= MAX_WORDS, "%s: section '%s' is short (%d words, at most %d)" % [id, s.get("heading", ""), words, MAX_WORDS])
				for t in s.get("see", []):
					_check(topics.has(t), "%s: See also '%s' is a topic" % [id, t])
			if kind == "screens" and topics.has(id):
				_check(false, "id '%s' is both a screen and a topic" % id)


# --- Pressing a "?" --------------------------------------------------------------------------------------

## Finds the visible "?" under `node`, checks its entry and presses it: the help must show that entry (the hub on PC
## in its side slot, `in_hub_side`; everything else in a HelpOverlay). Closes nothing.
func _press_help(node: Node, where: String, expected: String, in_hub_side: bool, hub = null) -> void:
	var b = _find_help_button(node)
	_check(b != null, "%s: has a ?" % where)
	if b == null:
		return
	_check(b.entry_id == expected, "%s: ? opens '%s' (expected '%s')" % [where, b.entry_id, expected])
	_check(Help.exists(b.entry_id), "%s: entry '%s' exists in help.json" % [where, b.entry_id])
	_check(b.size.x >= 44.0 and b.size.y >= 44.0, "%s: ? is at least 44 × 44 (%s)" % [where, b.size])
	_opened[b.entry_id] = where
	b.pressed.emit()
	await _frames(3)
	var shown := ""
	# The help shows in the hub's side slot on PC (also for the day editor's "?", which sits in that slot's neighbour: pass
	# the hub as `hub`), as a HelpOverlay on a phone (fix session: the PC case of the day editor used to look for an overlay).
	var host = node if in_hub_side else hub
	if host != null and host.get("_help") != null:
		shown = host._help.current() if host._help.visible else ""
		if in_hub_side:
			_check(host._side.visible, "%s: the side panel is shown" % where)
	else:
		var o = _find_overlay(current_scene)
		shown = o.panel.current() if o else ""
	_check(shown == expected, "%s: the help shows '%s' (got '%s')" % [where, expected, shown])
	if node.has_method("_close_help"):
		node._close_help()
		await _frames(2)


func _find_help_button(node: Node):
	if node.get_script() == _button_script and (node as Control).is_visible_in_tree():
		return node
	for c in node.get_children():
		if c.get_script() == _overlay_script:
			continue
		var found = _find_help_button(c)
		if found:
			return found
	return null


func _find_overlay(node: Node):
	if node.get_script() == _overlay_script and not node.is_queued_for_deletion():
		return node
	for c in node.get_children():
		var found = _find_overlay(c)
		if found:
			return found
	return null


func _overlay_on_top(hub: Control) -> bool:
	var last: Node = null
	for c in hub.get_children():
		if (c as Control) and (c as Control).visible and not c.is_queued_for_deletion():
			last = c
	return last != null and last.get_script() == _overlay_script


func _close_overlays(node: Node) -> void:
	var o = _find_overlay(node)
	while o:
		o.close()
		o = _find_overlay(node)


func _find_button_prefix(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix) and (node as Button).is_visible_in_tree():
		return node
	for c in node.get_children():
		var found := _find_button_prefix(c, prefix)
		if found:
			return found
	return null


func _key(node: Node, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	node._unhandled_key_input(ev)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  FAIL: ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
