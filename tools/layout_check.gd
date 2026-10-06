extends SceneTree
## Dev tool: resizes the window live through several sizes (PC, phone portrait, tablet, narrow strip)
## and screenshots the main screens at each, to check that nothing overflows or gets cut off.
## Run (needs a display):
##   godot --path . --rendering-driver opengl3 -s res://tools/layout_check.gd -- <output_dir>

const SIZES := [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(390, 844), Vector2i(1000, 900), Vector2i(844, 390)]

var _out := "user://layout_check"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	load("res://scripts/core/save_game.gd").DIR = "user://tour_saves/"
	await _frames(10)
	var main := current_scene
	var router = main.get_node("/root/Router")
	var game = main.get_node("/root/Game")
	var data = main.get_node("/root/Data")

	# A short career so the hub has something to show.
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
	wizard._on_next()   # start the career
	await _frames(5)
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	game.advance_day()   # a mid-week date in the header (Wednesday)
	game.advance_day()
	hub._refresh_week_ui()

	for size in SIZES:
		root.size = size
		await _frames(8)
		var tag := "%dx%d" % [size.x, size.y]
		print("size ", tag, " compact=", main.get_node("/root/Router") != null and Layout.compact, " logical=", root.content_scale_size)
		for view in ["overview", "training", "calendar", "rankings", "report"]:
			hub._show(view)
			await _frames(4)
			await _shot("%s_%s" % [tag, view])
			_check_overflow(hub, "%s %s" % [tag, view])
		# The day editor: an editable day with changes (Thu: Hard + a second session), the "add session" row,
		# and a played day (Mon). Side panel on PC, bottom sheet on a phone.
		hub._show("overview")
		game.current_week().set_intensity(3, "hard")
		game.current_week().add_session(3, "mobility")
		hub._on_day_changed()
		hub._open_day(3)
		await _frames(6)
		await _shot("%s_editor_thu" % tag)
		_check_overflow(hub, "%s editor_thu" % tag)
		hub._editor._adding = true
		hub._editor.refresh()
		await _frames(6)
		await _shot("%s_editor_adding" % tag)
		_check_overflow(hub, "%s editor_adding" % tag)
		hub._open_day(0)
		await _frames(6)
		await _shot("%s_editor_played" % tag)
		_check_overflow(hub, "%s editor_played" % tag)
		game.current_week().reset_day(3)
		hub._close_day()
		hub._on_day_changed()
		await _frames(3)
		# The stop-event panel (a test event with three choices).
		var e: Dictionary = game.post_event("dev", "Test: heavy legs",
				"Your legs feel heavy after today's training. What do you do tomorrow?", [
					{"id": "keep", "label": "Keep going", "detail": "Train as planned."},
					{"id": "easy", "label": "Take it easy", "detail": "Tomorrow's sessions at Easy intensity."},
					{"id": "rest", "label": "Rest day", "detail": "No training tomorrow."}], true)
		hub._show_pending_event()
		await _frames(4)
		await _shot("%s_stop_event" % tag)
		hub._on_event_answer(e.id, "keep")
		router.go("main_menu")
		await _frames(6)
		await _shot("%s_menu" % tag)
		router.go("career_hub")
		await _frames(6)
		hub = main.get_node("ScreenHost").get_child(-1)
	quit()


## Prints OVERFLOW for every visible control that sticks out past the window or past the scroll area it is in.
func _check_overflow(node: Node, label: String) -> void:
	var count := [0]
	_walk_overflow(node, label, count)
	if count[0] == 0:
		print("  no overflow: ", label)


func _walk_overflow(node: Node, label: String, count: Array) -> void:
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is Control and node.get_parent() is Control:
		var c := node as Control
		var clip := Rect2(Vector2.ZERO, root.get_visible_rect().size)   # the window, in logical px
		var p := node.get_parent()
		while p:
			if p is ScrollContainer and (p as Control).is_visible_in_tree():
				clip = (p as Control).get_global_rect()
				break
			p = p.get_parent()
		var r := c.get_global_rect()
		if r.size.x > 0.0 and (r.end.x > clip.end.x + 1.5 or r.position.x < clip.position.x - 1.5) \
				and not (c is ScrollContainer):
			count[0] += 1
			if count[0] <= 5:
				print("  OVERFLOW ", label, ": ", c.get_path(), " rect ", r, " clip ", clip)
	for child in node.get_children():
		_walk_overflow(child, label, count)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name)
