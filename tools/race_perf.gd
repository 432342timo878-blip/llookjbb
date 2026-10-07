extends SceneTree
## Dev tool: measures the race screen's frame times. Needs a window (not --headless):
##   godot --path . --rendering-driver opengl3 -s res://tools/race_perf.gd -- [speed 2/4/8] [indoor|outdoor] [old]
## Add `--resolution 390x844` before `-s` for the phone layout.
## Plays a watched race in real time, answers every decision through the real decision buttons, and prints,
## per phase (before the first decision, after each one), the frame time (avg / worst / frames over 33 ms),
## nodes in the tree, orphan nodes and draw calls.

var _speed := 4.0
var _outdoor := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_speed = float(args[0])
	if args.size() > 1 and args[1] == "outdoor":
		_outdoor = true
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	load("res://scripts/core/health_system.gd").model_enabled = false
	await _frames(10)
	var main := current_scene
	var router = main.get_node("/root/Router")
	var game = main.get_node("/root/Game")
	router.go("new_career")
	await _frames(5)
	var wizard: Control = main.get_node("ScreenHost").get_child(-1)
	wizard._choices.first_name = "Aino"
	wizard._choices.last_name = "Virtanen"
	wizard._choices.gender = "female"
	wizard._choices.hometown = "Sastamala"
	wizard._choices.club_id = ""
	wizard._show_step()
	for i in range(5):
		wizard._on_next()
		await _frames(3)
	game.autosave = false
	var cal = load("res://scripts/core/calendar.gd")
	for m in cal.meets_between(game.date, game.add_days(game.date, 330)):
		if cal.coach_recommends(game.athlete, m, game.date):
			game.enter(m.key)
	_to_race(game)
	if _outdoor:   # skip the indoor season: quick-run races until an outdoor meet comes up
		while game.race_day.meet.get("indoor", false):
			var rd = game.race_day
			while not rd.is_done():
				rd.start_round(false, "pack").run()
				rd.finish_round()
			game.finish_race()
			_to_race(game)
	router.go("race")
	await _frames(5)
	var screen: Control = main.get_node("ScreenHost").get_child(-1)
	screen._speed = _speed
	# Frame time of the pre-race screen as a baseline (nothing but the UI).
	var t0 := Time.get_ticks_usec()
	await _frames(60)
	print("baseline pre-race screen: avg %.1f ms/frame" % ((Time.get_ticks_usec() - t0) / 60000.0))
	screen._start(true)
	if OS.get_cmdline_user_args().has("old"):   # the pre-fix behaviour for an A/B comparison: the hall track redrawn every frame
		var view = screen._runners_view
		if view.race.indoor:
			view.get_parent().get_child(0).queue_free()
			view.indoor_floor_below = false
	print("window ", get_root().size, " compact=", get_root().size.x < get_root().size.y, " speed ", _speed, "x")

	var phase := 0
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	var decisions := 0
	while not screen._race.finished or screen._running:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		var race = screen._race
		if not race.pending.is_empty():
			_report("phase %d" % phase, times, screen)
			times.clear()
			phase += 1
			await _frames(5)   # the overlay is shown
			# Answer through the real first button on the card.
			var card = screen._decision.get_node("Margin/Center/Card")
			var btn := _first_button(card)
			if btn:
				btn.pressed.emit()
			else:
				race.choose(race.pending.options[0].id)
			decisions += 1
			last = Time.get_ticks_usec()
	_report("phase %d (to the finish)" % phase, times, screen)
	print("decisions answered: ", decisions)
	quit()


## Plays weeks until a race day; stop events (the coach's "three plans" offer since step 6f) are answered
## "ok" (= later), or the loop would never end.
func _to_race(game) -> void:
	var r: String = game.advance_week()
	while r != game.RACE:
		if r == game.STOP:
			game.answer_event(game.pending_event().id, "ok")
		r = game.advance_week()


## The card's first answer button (not its "?" help button, which would open the help and pause the race).
func _first_button(n: Node) -> Button:
	if n is Button and not (n.get_script() and n.get_script().resource_path.ends_with("help_button.gd")):
		return n
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		var b := _first_button(c)
		if b:
			return b
	return null


func _report(label: String, times: Array[float], screen: Control) -> void:
	if times.is_empty():
		return
	var sum := 0.0
	var worst := 0.0
	var slow := 0
	for t in times:
		sum += t
		worst = maxf(worst, t)
		if t > 33.0:
			slow += 1
	print("%s: %d frames, avg %.1f ms, worst %.1f ms, >33 ms: %d | nodes %d, orphans %d, draw calls %d, standings kids %d, commentary kids %d" % [
			label, times.size(), sum / times.size(), worst, slow,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			screen._standings.get_child_count() if is_instance_valid(screen._standings) else -1,
			screen._commentary.get_child_count() if is_instance_valid(screen._commentary) else -1])
