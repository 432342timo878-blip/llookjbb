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
	hub._refresh_header()

	for size in SIZES:
		root.size = size
		await _frames(8)
		var tag := "%dx%d" % [size.x, size.y]
		print("size ", tag, " compact=", main.get_node("/root/Router") != null and Layout.compact, " logical=", root.content_scale_size)
		for view in ["overview", "training", "calendar", "rankings"]:
			hub._show(view)
			await _frames(4)
			await _shot("%s_%s" % [tag, view])
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name)
