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
	# Same screens every run: no random colds or injuries (the health UI gets its own shots in M2 step 4).
	load("res://scripts/core/health_system.gd").model_enabled = false
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
		await _health_views(main, game, data, tag)
		hub = main.get_node("ScreenHost").get_child(-1)
		await _season_views(main, game, tag)
		hub = main.get_node("ScreenHost").get_child(-1)
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


# --- The health UI (M2 step 4): seeded states at this window size ----------------------------------------------

## A sore body (three areas), a niggle + a cold (then a locked injury), the diagnosis and "sore" panels, the Training
## tab's body strain, the Report with health lines, and a race day while injured (day editor and race screen).
## Everything is put back afterwards, and the health model is switched off again.
func _health_views(main: Node, game, data, tag: String) -> void:
	load("res://scripts/core/health_system.gd").model_enabled = true
	var health = game.get_system("health")
	health._ensure_started()
	var router = main.get_node("/root/Router")
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	var today: int = load("res://scripts/core/calendar.gd").weekday(game.date)

	# Sore: a bit sore, sore and painful; a niggle and a cold. Today card with a row open, then today's editor.
	_reset_health(game, health)
	health.strain["shins"] = 36.0
	health.strain["achilles"] = 55.0
	health.strain["calves"] = 75.0
	_start_problem(health, data, game, "shin_splints")
	_start_problem(health, data, game, "cold")
	health._apply_restrictions(game.current_week())
	hub._show("overview")
	hub._refresh_week_ui()
	await _frames(5)
	hub._today_card.open_area("achilles")
	await _frames(5)
	await _shot("%s_health_today_card" % tag)
	_check_overflow(hub, "%s health_today_card" % tag)
	hub._open_day(today)
	await _frames(6)
	await _shot("%s_health_editor_limits" % tag)
	_check_overflow(hub, "%s health_editor_limits" % tag)
	var through := _find_button(hub, "Train through it…")
	if through:
		through.pressed.emit()
		await _frames(6)
		await _shot("%s_health_train_through" % tag)
		_check_overflow(hub, "%s health_train_through" % tag)
		var yes := _find_button(hub, "Train through it anyway")
		if yes:   # then the day is trained through: the box offers "Follow the limits again"
			yes.pressed.emit()
			await _frames(6)
			await _shot("%s_health_trained_through" % tag)
			_check_overflow(hub, "%s health_trained_through" % tag)
			var back := _find_button(hub, "Follow the limits again")
			if back:
				back.pressed.emit()
				await _frames(4)
	hub._close_day()

	# A locked injury on top: banned sessions, no override.
	_start_problem(health, data, game, "hamstring_strain")
	health._apply_restrictions(game.current_week())
	hub._refresh_week_ui()
	hub._open_day(today)
	await _frames(6)
	await _shot("%s_health_editor_locked" % tag)
	_check_overflow(hub, "%s health_editor_locked" % tag)
	hub._close_day()
	hub._show("overview")
	await _frames(5)
	await _shot("%s_health_today_three_problems" % tag)
	_check_overflow(hub, "%s health_today_three_problems" % tag)

	# The two stop panels: the diagnosis of the injury, and the "sore" warning with its decision.
	var news := []
	health._start(data.get_injury("tibial_stress_reaction"), game.date, news)
	health._post_diagnosis(news[0])
	hub._show_pending_event()
	await _frames(6)
	await _shot("%s_health_diagnosis" % tag)
	_check_overflow(hub, "%s health_diagnosis" % tag)
	game.answer_event(game.pending_event().id, "ok")
	health.injuries.erase(news[0])
	health.levels.clear()
	health.warned.clear()
	health._update_soreness(true)
	hub._show_pending_event()
	await _frames(6)
	await _shot("%s_health_sore_event" % tag)
	_check_overflow(hub, "%s health_sore_event" % tag)
	if not game.pending_event().is_empty():
		game.answer_event(game.pending_event().id, "keep")
	hub._show_pending_event()

	# The Training tab (body strain), and the Report with sore days, injuries and the proneness hint.
	_reset_health(game, health)
	_start_problem(health, data, game, "shin_splints")
	game.season.mode = "repeat"   # a new career runs the season plan; this view needs the weekly editor (put back below)
	game.season.repeat_week = load("res://scripts/core/week_plan.gd").make(
			[["intervals_800", "strength"], ["tempo_run", "drills"], ["long_run"], ["intervals_800", "hill_sprints"],
			["tempo_run"], ["long_run", "speed_strides"], ["fartlek"]],
			["hard", "normal", "easy", "hard", "normal", "normal", "easy"])   # a mix, so the Training tab shows all three
	hub._show("training")
	await _frames(6)
	var strain := _find_label(hub, "BODY STRAIN")
	if strain:
		hub._scroll.ensure_control_visible(strain)
		await _frames(4)
	await _shot("%s_health_training" % tag)
	_check_overflow(hub, "%s health_training" % tag)
	game.season.repeat_week = load("res://scripts/core/week_plan.gd").coach()
	game.season.mode = "phases"
	for e in game.day_log:   # the two played days: put some health into their day log entries
		e["soreness"] = {"shins": 1, "calves": 2}
		e["health"] = ["shin_splints"]
	for i in 2:
		health.history.append({"id": "calf_tightness", "first": "calf_tightness", "tier": "niggle", "area": "calves",
				"cause": "overuse", "started": game.add_days(game.date, -40 - i * 30), "days": [7], "phase": 1, "left": 0,
				"through_days": 0, "warning": 0, "escalated": false, "healed": game.add_days(game.date, -30 - i * 30),
				"healed_no": health.day_no - 30})
	hub._refresh_week_ui()
	hub._show("report")
	await _frames(6)
	await _shot("%s_health_report" % tag)
	_check_overflow(hub, "%s health_report" % tag)
	health.history.clear()
	for e in game.day_log:
		e.erase("soreness")
		e.erase("health")

	# A race day while injured: a few days earlier in the calendar, the Saturday race entered.
	var cal = load("res://scripts/core/calendar.gd")
	var saved_date: Dictionary = game.date.duplicate()
	var saved_week = game._week
	var meet := {}
	for m in cal.meets_between({"year": 2027, "month": 1, "day": 1}, {"year": 2027, "month": 3, "day": 31}):
		if cal.coach_recommends(game.athlete, m, {"year": 2027, "month": 1, "day": 1}) and cal.weekday(m.date) >= 5:
			meet = m
			break
	if not meet.is_empty():
		game.date = game.add_days(cal.monday_of(meet.date), 2)
		game._week = null
		game.enter(meet.key)
		_reset_health(game, health)
		_start_problem(health, data, game, "shin_splints")
		hub._refresh_week_ui()
		hub._show("overview")
		hub._open_day(cal.weekday(meet.date))
		await _frames(6)
		await _shot("%s_health_race_day_editor" % tag)
		_check_overflow(hub, "%s health_race_day_editor" % tag)
		var scratch := _find_button(hub, "Scratch from this race")
		if scratch:
			scratch.pressed.emit()
			await _frames(5)
			await _shot("%s_health_race_day_scratch" % tag)
			_check_overflow(hub, "%s health_race_day_scratch" % tag)
		hub._close_day()
		game.date = meet.date.duplicate()
		game._week = null
		game.current_week()
		game.race_day = load("res://scripts/core/race_day.gd").new(meet, game.athlete, game.rivals)
		router.go("race")
		await _frames(8)
		var screen: Control = main.get_node("ScreenHost").get_child(-1)
		await _shot("%s_health_race_screen" % tag)
		_check_overflow(screen, "%s health_race_screen" % tag)
		game.race_day = null
		game.withdraw(meet.key)
	game.date = saved_date
	game._week = saved_week
	_reset_health(game, health)
	game.current_week()
	router.go("career_hub")
	await _frames(6)
	load("res://scripts/core/health_system.gd").model_enabled = false


# --- The season plan UI (M2 step 6e) at this window size ------------------------------------------------------

## The plan cards with the "replaces your changes" warning (an edited phase), the phase editor of a future phase
## (health on: body strain after the lead-in) and of the phase running now, a lighter week and a taper week (strip
## caption + the day editor's reason), and the Report with last week's phase line. Everything is put back afterwards.
func _season_views(main: Node, game, tag: String) -> void:
	var SeasonView = load("res://scripts/ui/season_view.gd")
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	var year: int = game.season.plan_year(game.week_monday())
	var week: Dictionary = game.season.edit_phase(year, "spring_base")
	week.intensity[1] = "hard"
	var current: String = game.season.variant(year)
	SeasonView.cards_open = true
	SeasonView.pending_variant = "ambitious" if current != "ambitious" else "steady"
	hub._show("training")
	await _frames(5)
	var caption := _find_label(hub, "COACH'S PLAN")
	if caption:
		hub._scroll.ensure_control_visible(caption)
		await _frames(3)
	await _shot("%s_season_cards" % tag)
	_check_overflow(hub, "%s season_cards" % tag)
	SeasonView.pending_variant = ""
	SeasonView.cards_open = false
	hub._show("training")
	await _frames(5)
	var phases := _find_label(hub, "THE SEASON")
	if phases:
		hub._scroll.ensure_control_visible(phases)
		await _frames(3)
	await _shot("%s_season_phases" % tag)
	_check_overflow(hub, "%s season_phases" % tag)

	# The phase editor: a future phase (health on for the lead-in), then the phase running now.
	load("res://scripts/core/health_system.gd").model_enabled = true
	game.get_system("health")._ensure_started()
	hub._phase_open = "spring_base"
	hub._show("training")
	await _frames(5)
	await _shot("%s_phase_editor" % tag)
	_check_overflow(hub, "%s phase_editor" % tag)
	var strain := _find_label(hub, "BODY STRAIN")
	if strain:
		hub._scroll.ensure_control_visible(strain)
		await _frames(3)
	await _shot("%s_phase_editor_strain" % tag)
	_check_overflow(hub, "%s phase_editor_strain" % tag)
	load("res://scripts/core/health_system.gd").model_enabled = false
	hub._phase_open = game.season.week_for(game.week_monday()).phase
	hub._show("training")
	await _frames(5)
	var edges := _find_label(hub, "WHEN IT RUNS")
	if edges:
		hub._scroll.ensure_control_visible(edges)
		await _frames(3)
	await _shot("%s_phase_editor_now" % tag)
	_check_overflow(hub, "%s phase_editor_now" % tag)
	hub._phase_open = ""
	game.season.reset_phase(year, "spring_base")

	# A lighter week and a taper week: the strip caption and the day editor's reason. Then the Report with a week
	# report that has its phase (made on a copy of the athlete).
	var saved_date: Dictionary = game.date.duplicate()
	var saved_week = game._week
	var saved_report: Dictionary = game.last_report
	for kind in ["lighter", "taper"]:
		var monday: Dictionary = game.add_days(game.week_monday(), 7)
		for i in 60:
			if game.season.week_for(monday).kind == kind:
				break
			monday = game.add_days(monday, 7)
		game.date = game.add_days(monday, 2)
		game._week = null
		game.current_week()
		hub._refresh_week_ui()
		hub._show("overview")
		var with_why := 4
		var wplan: Dictionary = game.season.week_for(game.week_monday())
		for d in range(2, 7):
			if wplan.why[d] != "":
				with_why = d
				break
		hub._open_day(with_why)
		await _frames(6)
		var why := _find_label(hub._editor, "Season plan")
		if why:
			var p := why.get_parent()
			while p and not p is ScrollContainer:
				p = p.get_parent()
			if p:
				(p as ScrollContainer).ensure_control_visible(why)
			await _frames(3)
		await _shot("%s_season_%s_week" % [tag, kind])
		_check_overflow(hub, "%s season_%s_week" % [tag, kind])
		hub._close_day()
	var copy = load("res://scripts/core/athlete.gd").from_dict(game.athlete.to_dict().duplicate(true))
	var plan: Dictionary = game.season.week_for(game.week_monday())
	var report: Dictionary = load("res://scripts/core/week_sim.gd").new(copy, plan, game.week_monday()).finish()
	report.plan = {"phase": plan.phase, "phase_week": plan.phase_week, "phase_weeks": plan.phase_weeks, "kind": plan.kind,
			"target": plan.target}
	game.last_report = report
	hub._show("report")
	await _frames(5)
	await _shot("%s_season_report" % tag)
	_check_overflow(hub, "%s season_report" % tag)
	game.last_report = saved_report
	game.date = saved_date
	game._week = saved_week
	game.current_week()
	hub._refresh_week_ui()
	hub._show("overview")
	await _frames(4)


func _reset_health(game, health) -> void:
	for area_id in health.strain:
		health.strain[area_id] = 0.0
	health.injuries.clear()
	health.levels.clear()
	health.warned.clear()
	health.last_level.clear()
	health.overrides.clear()
	health._apply_restrictions(game.current_week())


func _start_problem(health, data, game, injury_id: String) -> void:
	health._start(data.get_injury(injury_id), game.date, [])


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as Button).is_visible_in_tree():
		return node
	for c in node.get_children():
		var found := _find_button(c, text)
		if found:
			return found
	return null


func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text and (node as Label).is_visible_in_tree():
		return node
	for c in node.get_children():
		var found := _find_label(c, text)
		if found:
			return found
	return null


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
