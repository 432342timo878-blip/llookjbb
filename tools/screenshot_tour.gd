extends SceneTree
## Dev tool: clicks through character creation and saves a screenshot of every step.
## Run (needs a display, e.g. xvfb-run):
##   godot --path . --rendering-driver opengl3 -s res://tools/screenshot_tour.gd -- <output_dir>
## Add `--resolution 390x844` before `-s` to tour the phone layout (default window is 1600x900).

var _out := "user://tour"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	# Keep the tour's saves away from the player's real saves (loaded here: autoloads exist now).
	load("res://scripts/core/save_game.gd").DIR = "user://tour_saves/"
	# Same screens every run: no random colds or injuries (the health UI gets its own shots in M2 step 4).
	load("res://scripts/core/health_system.gd").model_enabled = false
	await _frames(10)
	await _shot("0_main_menu")
	var main := current_scene
	main.get_node("/root/Router").go("new_career")
	await _frames(5)
	var wizard: Control = main.get_node("ScreenHost").get_child(-1)
	wizard._choices.first_name = "Aino"
	wizard._choices.last_name = "Virtanen"
	wizard._choices.gender = "female"
	wizard._choices.hometown = "Sastamala"
	wizard._choices.club_id = ""
	wizard._show_step()
	await _frames(5)
	await _shot("1_identity")
	for i in range(4):
		if i == 1:
			for q in wizard.get_node("/root/Data").background_questions:
				wizard._choices.answers[q.id] = q.answers.size() - 1
		wizard._on_next()
		await _frames(5)
		await _shot("%d_%s" % [i + 2, wizard.STEPS[i + 1].to_lower().replace(" ", "_")])
	wizard._on_next()
	await _frames(5)
	await _shot("6_career_hub")
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	hub._show("training")
	await _frames(5)
	await _shot("7_training")
	hub._scroll.scroll_vertical = 640
	await _frames(5)
	await _shot("7b_training_summary")
	# Enter every meet the coach recommends, then play until the first race (9 Jan 2027).
	var game = main.get_node("/root/Game")
	var cal = load("res://scripts/core/calendar.gd")
	for m in cal.meets_between(game.date, game.add_days(game.date, 330)):
		if cal.coach_recommends(game.athlete, m, game.date):
			game.enter(m.key)
	hub._show("calendar")
	await _frames(5)
	await _shot("8_calendar")
	hub._scroll.scroll_vertical = 700
	await _frames(5)
	await _shot("8b_calendar_scrolled")
	# Next day twice: the header shows Wednesday.
	hub._show("overview")
	hub._on_advance(false)
	hub._on_advance(false)
	await _frames(5)
	await _shot("8c_hub_wednesday")   # week strip (Mon, Tue played) + Today card
	# Day editor: Thursday with a change (Hard) open, then a played day (Monday), then closed again.
	game.current_week().set_intensity(3, "hard")
	hub._on_day_changed()
	hub._open_day(3)
	await _frames(6)
	await _shot("8c2_day_editor")
	hub._open_day(0)
	await _frames(6)
	await _shot("8c3_day_editor_played")
	hub._close_day()
	game.current_week().reset_day(3)
	hub._on_day_changed()
	# A test stop event at the end of Wednesday: Play week stops and shows the decision panel.
	game.get_system("dev").armed = true
	hub._on_advance(true)
	await _frames(5)
	await _shot("8d_stop_event")
	hub._on_event_answer(game.pending_event().id, "easy")
	await _frames(3)
	# Play weeks until the first race day stops the week.
	var router = main.get_node("/root/Router")
	while game.advance_week() != game.RACE:
		pass
	# The race day on the strip and in the day editor (read-only, with the meet).
	hub._refresh_week_ui()
	hub._show("overview")
	hub._open_day(cal.weekday(game.date))
	await _frames(6)
	await _shot("8e_race_day_editor")
	hub._close_day()
	router.go("race")
	await _frames(5)
	await _shot("9_race_field")
	var screen: Control = main.get_node("ScreenHost").get_child(-1)
	screen._start(true)
	Engine.time_scale = 3.0
	var shots := {"decision": false, "mid": false}
	while not screen._race.finished or screen._running:
		await process_frame
		var race = screen._race
		if not race.pending.is_empty():
			if not shots.decision:
				shots.decision = true
				await _frames(3)
				await _shot("10_race_decision")
			screen._decision.visible = false
			race.choose(race.pending.options[0].id)
		if not shots.mid and race.player.d > 560.0:
			shots.mid = true
			await _shot("11_race_mid")
	Engine.time_scale = 1.0
	await _frames(5)
	await _shot("12_race_result")
	screen._leave()
	await _frames(5)
	await _shot("13_week_report_after_race")
	hub = main.get_node("ScreenHost").get_child(-1)
	hub._show("overview")
	await _frames(5)
	await _shot("14_overview_with_pb")
	hub._show("rankings")
	await _frames(5)
	await _shot("14b_rankings")

	# The Report tab in the middle of a week: this week so far, then last week.
	game.advance_day()
	game.advance_day()
	hub._refresh_week_ui()
	hub._show("report")
	await _frames(5)
	await _shot("14c_report_midweek")
	hub._show("overview")

	# A day change must survive save and load: Friday easy + a rest-day Saturday, this week only.
	var week = game.current_week()
	week.set_intensity(4, "easy")
	week.make_rest_day(5)
	hub._on_day_changed()
	var changed_json := JSON.stringify(week.changes)

	# Save, go back to the menu, load the snapshot again.
	var saves = load("res://scripts/core/save_game.gd")
	var slot: String = saves.save_snapshot()
	router.go("main_menu")
	await _frames(5)
	await _shot("15_main_menu_with_save")
	router.go("load_game")
	await _frames(5)
	await _shot("16_load_game")
	game.date = game.START_DATE.duplicate()   # scramble, then load to prove it restores
	saves.load_slot(slot)
	print("loaded date ", game.date, " athlete ", game.athlete.full_name(), " entries ", game.entries.size())
	router.go("career_hub")
	await _frames(5)
	await _shot("17_hub_after_load")
	hub = main.get_node("ScreenHost").get_child(-1)
	print("day changes survive save/load: ", JSON.stringify(game.current_week().changes) == changed_json,
			" (", game.current_week().changes.size(), " changed days)")
	hub._open_day(4)
	await _frames(6)
	await _shot("18_day_editor_after_load")
	hub._close_day()
	await _health_tour(main, hub)
	saves.delete(slot)
	quit()


# --- The health UI (M2 step 4): seeded states, the health model on --------------------------------------------

const HARD := [["intervals_800", "strength"], ["tempo_run", "drills"], ["long_run"], ["intervals_800", "hill_sprints"],
		["tempo_run"], ["long_run", "speed_strides"], ["fartlek"]]


func _health_tour(main: Node, hub_in: Control) -> void:
	var game = main.get_node("/root/Game")
	var data = main.get_node("/root/Data")
	var router = main.get_node("/root/Router")
	var cal = load("res://scripts/core/calendar.gd")
	load("res://scripts/core/health_system.gd").model_enabled = true
	var health = game.get_system("health")
	health.rng.seed = 7
	health._ensure_started()
	var hub := hub_in

	# 1. Sore: shins and Achilles a bit sore. The Today card, a row opened, then calves sore and a played day:
	#    the "sore" stop event, and the week strip with its "!" marker.
	_reset_health(game, health)
	health.strain["shins"] = 36.0
	health.strain["achilles"] = 38.0
	hub._show("overview")
	hub._refresh_week_ui()
	await _frames(6)
	await _shot("19_health_today_card")
	hub._today_card.open_area("shins")
	await _frames(4)
	await _shot("19b_health_soreness_row_open")
	health.strain["calves"] = 72.0   # (62 was enough on the old coach week; the indoor-specific Wednesday is lighter on the calves)
	hub._on_advance(false)
	await _frames(6)
	print("health tour: pending event after the sore day: ", game.pending_event().get("kind", "none"))
	await _shot("19c_health_sore_stop_event")
	if not game.pending_event().is_empty():
		hub._on_event_answer(game.pending_event().id, "easy")
	await _frames(6)
	await _shot("19d_health_strip_markers")
	hub._open_day(cal.weekday(game.date))
	await _frames(6)
	await _shot("19e_health_editor_sore_today")
	hub._close_day()

	# 2. A niggle (shin splints): the diagnosis panel, the Today card, the day editor with limits and the
	#    "train through it" warning.
	_reset_health(game, health)
	await _new_problem(game, hub, health, data, "shin_splints")
	await _shot("20_health_diagnosis_niggle")
	hub._on_event_answer(game.pending_event().id, "ok")
	await _frames(6)
	await _shot("20b_health_today_injured")
	hub._open_day(cal.weekday(game.date))
	await _frames(6)
	await _shot("20c_health_editor_limits")
	var through := _find_button(hub, "Train through it…")
	if through:
		through.pressed.emit()
		await _frames(6)
		await _shot("20d_health_train_through_warning")
	hub._close_day()

	# 3. A locked injury (shin stress reaction): diagnosis, Today card, day editor without an override.
	_reset_health(game, health)
	await _new_problem(game, hub, health, data, "tibial_stress_reaction")
	await _shot("21_health_diagnosis_locked")
	hub._on_event_answer(game.pending_event().id, "ok")
	await _frames(6)
	await _shot("21b_health_today_locked")
	hub._open_day(cal.weekday(game.date))
	await _frames(6)
	await _shot("21c_health_editor_locked")
	hub._close_day()

	# 4. The Training tab: load vs your normal and plan risk, for the coach plan and for a hard plan.
	_reset_health(game, health)
	hub._show("training")   # a new career runs the coach's season plan (M2 step 6b): notice + this week's plan
	await _frames(6)
	await _scroll_to_label(hub, "BODY STRAIN")
	await _shot("22a_health_training_season_plan")
	# The rest of the tour plans its own repeating weeks: press the switch button (it asks once more).
	var switch := _find_button(hub, "Use one repeating week instead")
	print("tour: switch button found: ", switch != null)
	switch.pressed.emit()
	await _frames(3)
	await _shot("22a2_health_training_switch_confirm")
	_find_button(hub, "Tap again to confirm").pressed.emit()
	await _frames(3)
	print("tour: repeat mode after the button: ", game.season.mode == "repeat")
	hub = main.get_node("ScreenHost").get_child(-1)
	hub._show("training")
	await _frames(6)
	await _scroll_to_label(hub, "BODY STRAIN")
	await _shot("22_health_training_coach_plan")
	game.season.repeat_week = load("res://scripts/core/week_plan.gd").make(HARD.duplicate(true))
	hub._show("training")
	await _frames(6)
	await _scroll_to_label(hub, "BODY STRAIN")
	await _shot("22b_health_training_hard_plan")
	game.season.repeat_week = load("res://scripts/core/week_plan.gd").make(load("res://scripts/core/training.gd").coach_plan())

	# 5. The Report tab: an injury and sore days in the log, and the proneness hint (two earlier injuries).
	for i in 2:
		health.history.append({"id": "calf_tightness", "first": "calf_tightness", "tier": "niggle", "area": "calves",
				"cause": "overuse", "started": game.add_days(game.date, -40 - i * 30), "days": [7], "phase": 1, "left": 0,
				"through_days": 0, "warning": 0, "escalated": false, "healed": game.add_days(game.date, -30 - i * 30),
				"healed_no": health.day_no - 30})
	health.strain["shins"] = 36.0
	await _new_problem(game, hub, health, data, "shin_splints")
	hub._on_event_answer(game.pending_event().id, "ok")
	_quiet_day(game)
	_quiet_day(game)
	hub._refresh_week_ui()
	hub._show("report")
	await _frames(6)
	await _shot("23_health_report")

	# 6. Racing injured: the next race with shin splints that last. The day editor on race day (with the scratch
	#    button asking once more), then the race screen (slower, may get worse, scratch).
	_reset_health(game, health)
	await _new_problem(game, hub, health, data, "shin_splints")
	hub._on_event_answer(game.pending_event().id, "ok")
	health.injuries[0].days = [90]
	health.injuries[0].left = 90
	var race: Dictionary = game.next_race()
	var guard := 0
	while not race.is_empty() and guard < 400 and not (cal.monday_of(race.date) == game.week_monday()
			and cal.date_key(game.date) <= cal.date_key(race.date)):
		guard += 1
		_quiet_day(game)
	hub._refresh_week_ui()
	hub._show("overview")
	hub._open_day(cal.weekday(race.date))
	await _frames(6)
	await _shot("24_health_race_day_injured")
	var scratch := _find_button(hub, "Scratch from this race")
	if scratch:
		scratch.pressed.emit()
		await _frames(4)
		await _shot("24b_health_scratch_confirm")
	hub._close_day()
	var reached: bool = game.race_day != null
	while not reached and guard < 500:
		guard += 1
		reached = game.advance_day() == game.RACE
		while not reached and not game.pending_event().is_empty():
			var e: Dictionary = game.pending_event()
			game.answer_event(e.id, "keep" if e.get("kind", "") == "sore" else "ok")
	print("health tour: reached the race day injured: ", reached)
	if reached:
		router.go("race")
		await _frames(6)
		await _shot("25_health_race_screen_injured")
		_find_button(main, "Scratch from this race").pressed.emit()
		await _frames(4)
		await _shot("25b_health_race_scratch_confirm")
		_find_button(main, "Yes, scratch").pressed.emit()
		await _frames(8)
		hub = main.get_node("ScreenHost").get_child(-1)
		print("health tour: scratched: entry gone ", not race.key in game.entries, ", no race waiting ", game.race_day == null)
		await _shot("25c_health_after_scratch")

	# 7. Ctrl+S saves: the Save button says "Saved ✓".
	var key := InputEventKey.new()
	key.keycode = KEY_S
	key.ctrl_pressed = true
	key.pressed = true
	hub._unhandled_key_input(key)
	await _frames(3)
	await _shot("26_health_ctrl_s_saved")

	# 8. The "sore" warning on the night before a race: a race day can't be made easier, so the choices are
	#    race as planned / scratch from the race (M2 step 5).
	_reset_health(game, health)
	var upcoming: Dictionary = game.next_race()
	if not upcoming.is_empty():
		var g2 := 0
		while cal.days_between(game.date, upcoming.date) > 1 and g2 < 400:
			g2 += 1
			_quiet_day(game)
		hub = main.get_node("ScreenHost").get_child(-1)
		health.strain["calves"] = 80.0
		hub._refresh_week_ui()
		hub._on_advance(false)
		await _frames(6)
		print("health tour: sore warning the night before a race names the race: ", game.pending_event().get("meet", "none") == upcoming.key)
		await _shot("27_health_sore_before_race")
	load("res://scripts/core/health_system.gd").model_enabled = false


## Back to a healthy body: no strain, no injuries, no leftover warnings.
func _reset_health(game, health) -> void:
	for area_id in health.strain:
		health.strain[area_id] = 0.0
	health.injuries.clear()
	health.levels.clear()
	health.warned.clear()
	health.last_level.clear()
	health.overrides.clear()
	health._apply_restrictions(game.current_week())


## Starts an injury (the same steps the model takes) and shows its diagnosis panel in the hub.
func _new_problem(game, hub: Control, health, data, injury_id: String) -> void:
	var news := []
	health._start(data.get_injury(injury_id), game.date, news)
	health._post_diagnosis(news[0])
	health._apply_restrictions(game.current_week())
	hub._refresh_week_ui()
	hub._show_pending_event()
	await _frames(6)


## One day with Next day; a race is run in quick mode, stop events are answered.
func _quiet_day(game) -> void:
	if game.advance_day() == game.RACE:
		var rd = game.race_day
		while not rd.is_done():
			var race = rd.start_round(false, "pack")
			race.run()
			rd.finish_round()
		game.finish_race()
	while not game.pending_event().is_empty():
		var e: Dictionary = game.pending_event()
		game.answer_event(e.id, "keep" if e.get("kind", "") == "sore" else "ok")


## Scrolls the hub's content so the label with this text is in view (a bit below the top edge).
func _scroll_to_label(hub: Control, text: String) -> void:
	var label := _find_label(hub, text)
	if label:
		hub._scroll.ensure_control_visible(label)
		await _frames(2)
		hub._scroll.scroll_vertical += 150
	await _frames(4)


func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text and (node as Label).is_visible_in_tree():
		return node
	for c in node.get_children():
		var found := _find_label(c, text)
		if found:
			return found
	return null


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as Button).is_visible_in_tree():
		return node
	for c in node.get_children():
		var found := _find_button(c, text)
		if found:
			return found
	return null


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name)
