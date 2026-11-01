extends SceneTree
## Check of the in-game playtest notes (session K1c; PlaytestNotes, PlaytestView, data/playtest.json):
## 1. the data: every question has an id (unique), a text and a kind; a pick question has options;
## 2. answering: a pick and a note are saved and found again, clearing both removes the answer, a note alone counts, the count follows;
## 3. the file: what was saved is there after opening again, a quick note is stamped with the game's date and the page, one can be removed;
## 4. the text: every question appears in the markdown with its answer, "(no answer)" for the others, the quick notes at the end;
## 5. the page builds with the answers in place (a picked button is pressed) and a press on an option saves it;
## 6. the notes never touch the career (the career's autosave is untouched by answering).
## Run: godot --headless --path . -s res://tools/playtest_check.gd
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _run() -> void:
	var PN = load("res://scripts/core/playtest_notes.gd")
	PN.DIR = "user://tool_playtest/"   # never the player's notes
	var game = root.get_node("/root/Game")
	var data = root.get_node("/root/Data")
	game.autosave = false
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	load("res://scripts/core/game_config.gd").use("lab")
	if FileAccess.file_exists(PN.path()):
		DirAccess.remove_absolute(PN.path())
	print("--- 1. the data")
	var ids := {}
	var fine := true
	var pick_fine := true
	var n := 0
	for s in data.playtest.sections:
		for q in s.questions:
			n += 1
			fine = fine and q.has("id") and q.has("text") and not ids.has(str(q.id)) and str(q.kind) in ["pick", "text"]
			ids[str(q.id)] = true
			if str(q.kind) == "pick":
				pick_fine = pick_fine and q.has("options") and q.options.size() >= 2
	_ok("%d questions with unique ids, texts and kinds" % n, fine and n >= 20)
	_ok("every pick question has at least two options", pick_fine)
	print("--- 2. answering")
	var notes = PN.open()
	_ok("a new run has nothing answered", notes.answered() == 0 and notes.total() == n)
	notes.set_answer("clicks", "About right", "", "week")
	notes.set_answer("stops", "", "the Monday stop", "week")
	_ok("a pick and a note alone each count (2 answered)", notes.answered() == 2)
	_ok("the answer is found again", str(notes.answer_of("clicks").pick) == "About right")
	notes.set_answer("stops", "", "", "week")
	_ok("clearing the pick and the note removes the answer", notes.answered() == 1 and notes.answer_of("stops").is_empty())
	print("--- 3. the file")
	notes.add_note("The strap is nice", "career")
	notes.add_note("", "career")
	var again = PN.open()
	_ok("after opening again the answer and the note are there", again.answered() == 1 and again.data.notes.size() == 1)
	_ok("the answer is stamped with the page", str(again.answer_of("clicks").context.page) == "week")
	_ok("the quick note is stamped with the page and the text (an empty note is not kept)", str(again.data.notes[0].context.page) == "career" and str(again.data.notes[0].text) == "The strap is nice")
	again.add_note("second", "week")
	again.remove_note(0)
	_ok("a note can be removed", again.data.notes.size() == 1 and str(again.data.notes[0].text) == "second")
	print("--- 4. the text")
	var md: String = again.to_markdown()
	var every := true
	for s in data.playtest.sections:
		for q in s.questions:
			every = every and md.find(str(q.text)) >= 0
	_ok("every question is in the text", every)
	_ok("the answer and the quick note are in it, the others say (no answer)", md.find("About right") >= 0 and md.find("second") >= 0 and md.find(str(data.playtest.ui.md_none)) >= 0)
	var path: String = again.save_text()
	_ok("the text file is written (%s)" % path, FileAccess.file_exists(path))
	print("--- 5. the page")
	var athlete = load("res://scripts/core/athlete_factory.gd").create({"first_name": "Test", "last_name": "Runner", "gender": "male", "club_id": "",
			"hometown": "Oulu", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1}, "answers": {}}, RandomNumberGenerator.new())
	game.start_career(athlete, "repeat")
	var view = load("res://scripts/ui/playtest_view.gd").new("week")
	root.add_child(view)
	await process_frame
	var pressed := _pressed_buttons(view)
	_ok("the page builds and the saved pick is pressed (%s)" % ", ".join(pressed), "About right" in pressed and pressed.size() == 1)
	var target := _find_button(view, "Too many")
	if target != null:
		target.button_pressed = true
		target.pressed.emit()
	var saved = PN.open()
	_ok("pressing an option saves it", str(saved.answer_of("clicks").pick) == "Too many")
	if target != null:
		target.button_pressed = false
		target.pressed.emit()
	_ok("pressing it again clears it", PN.open().answer_of("clicks").is_empty())
	view.free()
	print("--- 6. the career is untouched")
	var ctx: Dictionary = PN.context("week")
	_ok("the stamp reads the game's date and age", str(ctx.date) != "" and int(ctx.age) == 14)
	print("--- 7. the cards: the right questions on the right pages")
	if FileAccess.file_exists(PN.path()):
		DirAccess.remove_absolute(PN.path())
	var fresh = PN.open()
	game.date = game.START_DATE.duplicate()
	_ok("in the first week nothing about This week is due yet", fresh.due("week").is_empty())
	_ok("the Career tab's Now page is due at once (the next big thing), the Results page too", fresh.due("career:now").size() >= 1 and fresh.due("career:results").size() == 1)
	_ok("a page that asks nothing has no card", PN.open() != null and load("res://scripts/ui/playtest_card.gd").build("career:seasons") == null)
	game.date = game.add_days(game.START_DATE, 21)
	var due: Array = fresh.due("week")
	var due_ids: Array = due.map(func(q): return str(q.id))
	_ok("after three weeks: the strap, the clicks and the stops come first, at most card_max (%s)" % ", ".join(due_ids), due_ids == ["strap_use", "strap_need", "clicks"])
	_ok("a question that needs a goals card is not asked in the lab", not (fresh.due("week").any(func(q): return str(q.id) == "goals_card")))
	fresh.set_answer("strap_use", "Useful", "", "week")
	_ok("an answered question is not asked again, the next one takes its place", fresh.due("week").map(func(q): return str(q.id)) == ["strap_need", "clicks", "stops"])
	fresh.skip(fresh.due("week"))
	_ok("Done skips what was left: they are not asked again", not fresh.due("week").any(func(q): return str(q.id) in ["strap_need", "clicks", "stops"]))
	var reopened = PN.open()
	_ok("the skips and the answer are saved", reopened.data.skipped.has("clicks") and not reopened.answer_of("strap_use").is_empty())
	_ok("the card builds when something is due", load("res://scripts/ui/playtest_card.gd").build("week") != null)
	reopened.set_on(false)
	_ok("with the playtest off nothing is due and there is no card", PN.open().due("week").is_empty() and load("res://scripts/ui/playtest_card.gd").build("week") == null)
	_ok("... the notes page still has every question", PN.open().total() == n)
	reopened.set_on(true)
	game.date = game.add_days(game.START_DATE, 7 * 8)
	var late: Array = PN.open().due("week").map(func(q): return str(q.id))
	_ok("by week 8 the sizes and the free questions come (%s)" % ", ".join(late), late.size() > 0 and late.size() <= 3)
	if FileAccess.file_exists(PN.path()):
		DirAccess.remove_absolute(PN.path())
	print("\nALL CHECKS PASSED" if _fails == 0 else "\n%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _pressed_buttons(node: Node) -> Array:
	var out := []
	if node is Button and (node as Button).toggle_mode and (node as Button).button_pressed:
		out.append((node as Button).text)
	for c in node.get_children():
		out.append_array(_pressed_buttons(c))
	return out


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null
