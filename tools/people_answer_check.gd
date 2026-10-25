extends SceneTree
## Dev check (playtest 2 follow-up, 2026-10-18): a message that waits in a People thread can be answered by pressing its reply button.
## The user reported that with "Play week stops for: Important only" the chats went to People and none of their answers could be picked:
## the card bound the moment id and the reply id with two `bind` calls, which reach the handler in the wrong order, so nothing happened.
## Plays the real game (the `real` preset, no injuries) with the real hub until a message waits without a stop in the family / friends /
## group / school thread, opens that thread, presses the reply buttons of three such messages (each `pressed.emit()` like a click) and
## checks that every one was answered with the reply that was pressed.
## Run: godot --headless --path . -s res://tools/people_answer_check.gd     (~30 s; own save folder user://tour_saves/)
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var _fails := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _run() -> void:
	load("res://scripts/core/save_game.gd").DIR = "user://tour_saves/"
	load("res://scripts/core/game_config.gd").use("real", {"health": false})
	await _frames(10)
	var main := current_scene
	var router = main.get_node("/root/Router")
	var game = main.get_node("/root/Game")
	var data = main.get_node("/root/Data")
	game.autosave = false
	router.go("new_career")
	await _frames(5)
	var wizard: Control = main.get_node("ScreenHost").get_child(-1)
	wizard._choices.first_name = "Aino"
	wizard._choices.last_name = "Virtanen"
	wizard._choices.gender = "female"
	wizard._choices.hometown = "Sastamala"
	wizard._choices.club_id = ""
	for q in data.background_questions:
		wizard._choices.answers[q.id] = 0
	for step in 4:
		wizard._on_next()
		await _frames(3)
	wizard._on_next()
	await _frames(5)
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	var ms = game.get_system("moments")
	_ok("the default setting is 'Important only' (messages without a stop wait in the threads)", ms.stop_mode() == "important")
	var tested := 0
	var days := 0
	while tested < 3 and days < 150:
		days += 1
		var guard := 0
		while not game.pending_event().is_empty() and guard < 20:
			guard += 1
			var e: Dictionary = game.pending_event()
			game.answer_event(e.id, str(e.choices[0].id) if not (e.choices as Array).is_empty() else "ok")
		var r: String = game.advance_day()
		if r == game.RACE:
			var rd = game.race_day
			while not rd.is_done():
				rd.start_round(false, "pack").run()
				rd.finish_round()
			game.finish_race()
		var waiting := {}
		for m in ms.pending():
			if not bool(m.stop) and str(m.thread) in ["family", "friends", "group", "school", "rivals"] and str(m.kind) == "moment" \
					and str(m.get("planned", "")) == "":
				waiting = m
				break
		if waiting.is_empty():
			continue
		var pick: Dictionary = waiting.replies[tested % waiting.replies.size()]
		hub._refresh_week_ui()
		hub._people_page = "school" if str(waiting.thread) == "school" else str(waiting.thread)
		hub._show("people")
		await _frames(6)
		var btn := _find_button(hub, str(pick.label))
		_ok("message %s (%s): its reply '%s' is a button in the thread" % [waiting.id, waiting.thread, pick.label], btn != null)
		if btn == null:
			continue
		btn.pressed.emit()
		await _frames(4)
		var after: Dictionary = ms.moment(str(waiting.id))
		# (session L3a: what waits in a thread is an invitation or a story beat; an invitation's answer only plans it until its evening)
		var got := str(after.get("planned", "")) if after.has("invite") else str(after.answer)
		_ok("... pressing it answers the %s with that reply (%s)" % ["invitation" if after.has("invite") else "message", got], got == str(pick.id))
		tested += 1
	_ok("three waiting messages were found and tested in %d days" % days, tested == 3)
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as Button).is_visible_in_tree():
		return node
	for c in node.get_children():
		var f := _find_button(c, text)
		if f != null:
			return f
	return null


func _frames(n: int) -> void:
	for i in n:
		await process_frame
