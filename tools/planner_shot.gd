extends SceneTree
## Dev tool (session L1a): screenshots of the Sunday week planner in a real career, for looking at the screen while building it.
## A career on the coach's ★ season plan in the real game (every system on, fixed dice), the first stops answered with their
## defaults, then the Dev jump runs `weeks` weeks (races as quick pack races) and stops on a Monday, the planner of the next week.
## Shots: the planner, a day open in the editor, the Play week question (when choices wait), Season, Career, People, Calendar.
## Run (needs a window; the phone with --resolution 390x844):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 -s res://tools/planner_shot.gd -- <out_dir> [weeks] [seed]
## Uses its own save folder (user://tour_saves/), never the player's saves.

var _out := "user://planner_shots"
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()
	create_timer(300.0).timeout.connect(func():
		print("  FAIL  did not finish (a SCRIPT ERROR? read stderr)")
		quit(1))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var weeks: int = args[1].to_int() if args.size() > 1 else 3
	var seed_value: int = args[2].to_int() if args.size() > 2 else 3
	load("res://scripts/core/save_game.gd").DIR = "user://tour_saves/"
	var GC = load("res://scripts/core/game_config.gd")
	GC.fixed_seed = seed_value
	GC.use("real")
	await _frames(10)
	_main = current_scene
	var game = _main.get_node("/root/Game")
	var data = _main.get_node("/root/Data")
	var router = _main.get_node("/root/Router")
	var dev = load("res://scripts/core/dev_tools.gd")
	game.autosave = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	var a = load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Aino", "last_name": "Virtanen", "gender": "female", "hometown": "Sastamala", "club_id": "",
		"main_event": "800m", "birth_date": {"year": 2012, "month": 3, "day": 14}, "answers": answers}, rng)
	game.start_career(a)
	while not game.pending_event().is_empty():
		var e: Dictionary = game.pending_event()
		game.answer_event(e.id, dev.default_answer(e))
	var cal = load("res://scripts/core/calendar.gd")
	for m in cal.meets_between(game.date, game.add_days(game.date, 120)):
		if cal.coach_recommends(a, m, game.date):
			game.enter(m.key)
	var res: Dictionary = dev.jump(game.add_days(game.date, 7 * weeks), true)
	while not game.pending_event().is_empty():
		var e: Dictionary = game.pending_event()
		game.answer_event(e.id, dev.default_answer(e))
	print("jumped: ", res, " to ", cal.format_day(game.date))
	router.go("career_hub")
	await _frames(8)
	var hub: Control = _main.get_node("ScreenHost").get_child(-1)
	hub._show("week")
	await _frames(6)
	await _shot("1_planner")
	var planner = hub._planner
	if planner != null:
		print("open choices: ", load("res://scripts/ui/week_planner.gd").open_choices().size())
	hub._scroll.scroll_vertical = 2000
	await _frames(4)
	await _shot("1b_planner_bottom")
	hub._scroll.scroll_vertical = 0
	hub._open_day(3)
	await _frames(6)
	await _shot("2_day_open")
	hub._close_day()
	await _frames(4)
	if load("res://scripts/ui/week_planner.gd").open_choices().size() > 0:
		hub._on_play_pressed(true)
		await _frames(4)
		await _shot("3_play_confirm")
		hub._close_play_confirm()
	for tab in ["season", "career", "people", "calendar", "report"]:
		hub._show(tab)
		await _frames(6)
		await _shot("4_" + tab)
	hub._show("week")
	await _frames(4)
	hub._toggle_help()
	await _frames(6)
	await _shot("5_help")
	quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
