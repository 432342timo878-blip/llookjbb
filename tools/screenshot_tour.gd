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
	# The help's "read" marks in their own file, empty at the start: the "?" buttons show their "new" dot.
	var help = load("res://scripts/ui/help.gd")
	help.SEEN_PATH = "user://tour_help_seen.cfg"
	help.reset_seen()
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
	# The help (GDD 5 "Help"): the wizard's "?" opens it over the page.
	load("res://scripts/ui/help_overlay.gd").open(wizard, "new_career")
	await _frames(6)
	await _shot("1b_help_new_career")
	_close_help_overlays(main)
	await _frames(3)
	for i in range(4):
		if i == 1:
			for q in wizard.get_node("/root/Data").background_questions:
				wizard._choices.answers[q.id] = q.answers.size() - 1
		wizard._on_next()
		await _frames(5)
		await _shot("%d_%s" % [i + 2, wizard.STEPS[i + 1].to_lower().replace(" ", "_")])
	wizard._on_next()
	await _frames(6)
	# A new career opens with the coach's offer of the three plans (M2 step 6f), its help, then "Decide later".
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	await _shot("5b_coach_offer")
	await _scroll_event_to_end(hub)
	await _shot("5b2_coach_offer_buttons")
	load("res://scripts/ui/help_overlay.gd").open(hub, "season_offer")
	await _frames(6)
	await _shot("5c_help_coach_offer")
	_close_help_overlays(main)
	hub._on_event_answer(main.get_node("/root/Game").pending_event().id, "later")
	await _frames(5)
	await _shot("6_career_hub")
	# The header "?": Overview's help (PC: the side slot; phone: a sheet), then its "See also: Race form" topic.
	hub._toggle_help()
	await _frames(6)
	await _shot("6b_help_overview")
	var see := _find_button_prefix(main, "See also: Race form")
	if see:
		see.pressed.emit()
		await _frames(6)
		await _shot("6c_help_topic_form")
	hub._close_help()
	await _frames(3)
	await _shot("6d_hub_help_read")   # the "?" without its dot now
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
	hub._toggle_help()
	await _frames(6)
	await _shot("8b2_help_calendar")
	hub._close_help()
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
	hub._editor.help_requested.emit()   # the day editor's own "?": the help covers the editor
	await _frames(6)
	await _shot("8c2b_help_day_editor")
	hub._close_help()
	await _frames(3)
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
	screen._open_help(screen._help_id())
	await _frames(6)
	await _shot("9b_help_race_before")
	_close_help_overlays(main)
	await _frames(2)
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
				screen._open_help("race_running")   # the "?" on the decision card
				await _frames(6)
				await _shot("10b_help_race_decision")
				_close_help_overlays(main)
				await _frames(2)
			screen._decision.visible = false
			race.choose(race.pending.options[0].id)
		if not shots.mid and race.player.d > 560.0:
			shots.mid = true
			await _shot("11_race_mid")   # the action bar, the Feeling word under the clock
			# (the race is held still for these two shots, so no card gets in the way)
			screen._running = false
			# Kick now needs a second tap: after the first, the button asks for it.
			var kick: Button = screen._bar._buttons.kick
			kick.pressed.emit()
			await _frames(3)
			await _shot("11b_race_tap_again")
			screen._bar._armed_at = -1000.0
			# Something happens right next to the player at 4x: the race drops to 1x for a moment.
			screen._speed = 4.0
			race.events.append({"type": "fall", "t": race.time, "who": "A Rival", "i": 1, "player": false,
					"d": roundi(race.player.d) + 6, "pos": 3, "gap": 4.0})
			screen._running = true
			screen._process(0.05)
			screen._running = false
			screen._refresh_running()
			await _frames(3)
			await _shot("11c_race_slowed")
			screen._running = true
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
	await _form_tour(game, hub)

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
	await _season_tour(main)
	hub = main.get_node("ScreenHost").get_child(-1)
	await _health_tour(main, hub)
	saves.delete(slot)
	quit()


# --- The season plan UI (M2 step 6e): plan cards, the season, targets, the phase editor, strip caption, -----------
# --- the day editor's reason, the Report's phase line, the Calendar's Target button, the mode switch. -------------
# Seeded: an edited phase, a lighter week and a taper week (the date is moved there), a future phase with the
# lead-in (health model on). Everything is put back afterwards by loading a snapshot.

func _season_tour(main: Node) -> void:
	var game = main.get_node("/root/Game")
	var router = main.get_node("/root/Router")
	var cal = load("res://scripts/core/calendar.gd")
	var saves = load("res://scripts/core/save_game.gd")
	var SeasonView = load("res://scripts/ui/season_view.gd")
	var slot: String = saves.save_snapshot()
	load("res://scripts/core/health_system.gd").model_enabled = true
	game.get_system("health")._ensure_started()
	router.go("career_hub")
	await _frames(5)
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	var year: int = game.season.plan_year(game.week_monday())

	# 1. The Training tab in season mode (and its help); then the three plan cards.
	hub._show("training")
	await _frames(6)
	await _shot("28_season_plan_top")
	hub._toggle_help()
	await _frames(6)
	await _shot("28a_help_training_season")
	hub._close_help()
	SeasonView.cards_open = true
	hub._show("training")
	await _frames(6)
	await _scroll_to_label(hub, "COACH'S PLAN")
	await _shot("28b_season_plan_cards")
	# 2. An edited phase (spring base: Tuesday Hard, a second session on Thursday), then another plan is chosen:
	#    the warning "This replaces your changes to 1 phase".
	var week: Dictionary = game.season.edit_phase(year, "spring_base")
	week.intensity[1] = "hard"
	week.days[3] = ["fartlek", "strength"]
	SeasonView.pending_variant = "balanced"
	hub._show("training")
	await _frames(6)
	await _scroll_to_label(hub, "COACH'S PLAN")
	hub._scroll.scroll_vertical += 200
	await _frames(4)
	await _shot("28c_season_plan_confirm")
	SeasonView.pending_variant = ""
	SeasonView.cards_open = false
	hub._show("training")
	await _frames(6)
	await _scroll_to_label(hub, "THE SEASON")
	await _shot("28d_season_phases")
	await _scroll_to_label(hub, "TARGET MEETS (2 OF 3)")
	await _shot("28e_season_targets")

	# 3. The phase editor: a future phase with your changes (body strain after the lead-in), its rules and edges,
	#    then the phase running now, and a phase that is over.
	hub._phase_open = "spring_base"
	hub._show("training")
	await _frames(6)
	await _shot("29_phase_editor_top")
	hub._toggle_help()
	await _frames(6)
	await _shot("29a_help_phase_editor")
	hub._close_help()
	await _scroll_to_label(hub, "WEEKS OF THE PHASE")
	await _shot("29b_phase_editor_rules")
	await _scroll_to_label(hub, "BODY STRAIN")
	await _shot("29c_phase_editor_strain")
	var now_id: String = game.season.week_for(game.week_monday()).phase
	hub._phase_open = now_id
	hub._show("training")
	await _frames(6)
	await _shot("29d_phase_editor_now")
	await _scroll_to_label(hub, "WHEN IT RUNS")
	await _shot("29d2_phase_editor_now_edges")   # the start already passed: text only (it once wrapped letter by letter)
	hub._phase_open = "general_base"
	hub._show("training")
	await _frames(6)
	print("season tour: phase now ", now_id, ", general base over: ", now_id != "general_base")
	await _shot("29e_phase_editor_past")
	hub._phase_open = ""

	# 4. A lighter week: the strip caption, the day editor's reason; then the week is played: the Report's phase line.
	#    (Health model off again from here: no random cold in these shots.)
	load("res://scripts/core/health_system.gd").model_enabled = false
	var lighter := _find_week(game, "lighter")
	var taper := _find_week(game, "taper")
	print("season tour: lighter week ", lighter, ", taper week ", taper)
	if not lighter.is_empty():
		_jump(game, lighter)
		hub._refresh_week_ui()
		hub._show("overview")
		hub._open_day(_day_with_why(game))
		await _frames(6)
		await _scroll_editor_to(hub, "Season plan")
		await _shot("30_strip_lighter_week")
		hub._close_day()
		var monday: Dictionary = game.week_monday()
		while game.week_monday() == monday:
			_quiet_day(game)
		hub._refresh_week_ui()
		hub._show("report")
		await _frames(6)
		await _shot("30b_report_phase_line")
	# 5. A taper week: the caption counts down to the target, and the day editor shows the taper day's reason.
	if not taper.is_empty():
		_jump(game, taper)
		hub._refresh_week_ui()
		hub._show("overview")
		hub._open_day(_day_with_why(game))
		await _frames(6)
		await _scroll_editor_to(hub, "Season plan")
		await _shot("30c_strip_taper_week")
		hub._close_day()

	# 6. The Calendar: Make target / Target ◆ next to Enter.
	hub._show("calendar")
	await _frames(6)
	await _scroll_to_label(hub, "FEBRUARY 2027")
	await _shot("31_calendar_targets")

	# 7. The mode switch: one repeating week, and back to the season plan (the changes are still there).
	hub._show("training")
	await _frames(4)
	_find_button(hub, "Repeating week" if load("res://ui/layout.gd").compact else "One repeating week").pressed.emit()
	await _frames(6)
	await _shot("32_training_repeat_mode")
	_find_button(hub, "Season plan").pressed.emit()
	await _frames(6)
	print("season tour: back in phases mode ", game.season.mode == "phases", ", spring base still edited ",
			game.season.is_edited(year, "spring_base"))
	await _shot("32b_training_back_to_season")

	# 8. The coach's autumn offer for next season (M2 step 6f): with a changed phase of next season, Ambitious chosen
	#    shows the warning; "Decide later": the Training tab's Next season box.
	_jump(game, {"year": 2027, "month": 10, "day": 11})
	game.season.edit_phase(year + 1, "general_base").intensity[0] = "hard"
	game.get_system("season").offer(year + 1)
	hub._refresh_week_ui()
	hub._show("overview")
	hub._show_pending_event()
	await _frames(6)
	await _shot("33_coach_offer_next_season")
	var panel = _find_script(hub._event_overlay, load("res://scripts/ui/season_event_panel.gd"))
	if panel:
		panel._selected = "ambitious"
		panel._confirm = true
		panel._build()
		await _frames(6)
		await _scroll_event_to_end(hub)
		await _shot("33b_coach_offer_replace_warning")
	hub._on_event_answer(game.pending_event().id, "later")
	hub._show("training")
	await _frames(6)
	await _scroll_to_label(hub, "NEXT SEASON 2027–28")
	await _shot("33c_training_next_season")

	# 9. Easing back in (M2 step 6f): 33 days without running after a shin stress reaction; the coach's event on
	#    Wednesday evening (the body seeded as after a layoff: low capacity), its help; accepted: Thursday's day editor,
	#    the strip caption, the Training tab's box, the Report line and the next week's strip.
	_jump(game, {"year": 2027, "month": 3, "day": 1})
	game.date = {"year": 2027, "month": 3, "day": 3}
	game._week = null
	game.current_week()
	load("res://scripts/core/health_system.gd").model_enabled = true
	var health = game.get_system("health")
	health._ensure_started()
	_reset_health(game, health)
	health.days_without_running = 33
	health.capacity_now = 0.55
	for k in health.impacts.size():
		health.impacts[k] = 2.0
	health.history.append({"id": "tibial_stress_reaction", "first": "tibial_stress_reaction", "tier": "injury", "area": "shins",
			"cause": "overuse", "started": {"year": 2027, "month": 1, "day": 29}, "days": [28, 6], "phase": 2, "left": 0,
			"through_days": 0, "warning": 1, "escalated": false, "healed": {"year": 2027, "month": 3, "day": 2},
			"healed_no": health.day_no - 1})
	game.get_system("season")._post_return(health, game.add_days(game.date, 1))
	print("tour: easing back in risk ", game.pending_event().risk_full, " -> ", game.pending_event().risk_block)
	load("res://scripts/core/health_system.gd").model_enabled = false
	hub._refresh_week_ui()
	hub._show("overview")
	hub._show_pending_event()
	await _frames(6)
	await _shot("34_easing_back_in")
	await _scroll_event_to_end(hub)
	await _shot("34a_easing_back_in_buttons")
	load("res://scripts/ui/help_overlay.gd").open(hub, "return_block")
	await _frames(6)
	await _shot("34a2_help_easing_back_in")
	_close_help_overlays(main)
	hub._on_event_answer(game.pending_event().id, "accept")
	_quiet_day(game)   # Wednesday
	hub._refresh_week_ui()
	hub._open_day(cal.weekday(game.date))
	await _frames(6)
	await _scroll_editor_to(hub, "Season plan")
	await _shot("34b_easing_day_editor")
	hub._close_day()
	hub._show("training")
	await _frames(6)
	await _shot("34c_training_easing_box")
	while cal.weekday(game.date) != 0:
		_quiet_day(game)
	hub._refresh_week_ui()
	hub._show("report")
	await _frames(6)
	await _scroll_to_label(hub, "Last week")
	await _shot("34d_report_easing_line")
	hub._show("overview")
	await _frames(6)
	await _shot("34e_strip_easing_next_week")

	load("res://scripts/core/health_system.gd").model_enabled = false
	saves.load_slot(slot)
	saves.delete(slot)
	router.go("career_hub")
	await _frames(6)


## Scrolls the open day editor (side panel or bottom sheet) so the label with this text is in view.
func _scroll_editor_to(hub: Control, text: String) -> void:
	var label := _find_label(hub._editor, text)
	if label == null:
		print("tour: editor label not found: ", text)
		return
	var p := label.get_parent()
	while p and not p is ScrollContainer:
		p = p.get_parent()
	if p:
		(p as ScrollContainer).ensure_control_visible(label)
	await _frames(4)


## The first day of this week (from today) that the season plan gives a reason for (lighter week, taper…), else today.
func _day_with_why(game) -> int:
	var plan: Dictionary = game.season.week_for(game.week_monday())
	for d in range(load("res://scripts/core/calendar.gd").weekday(game.date), 7):
		if plan.why[d] != "":
			return d
	return load("res://scripts/core/calendar.gd").weekday(game.date)


## The Monday of the first coming week of this kind ("lighter" / "taper"), or {}.
func _find_week(game, kind: String) -> Dictionary:
	var monday: Dictionary = game.add_days(game.week_monday(), 7)
	for i in 60:
		if game.season.week_for(monday).kind == kind:
			return monday
		monday = game.add_days(monday, 7)
	return {}


## Moves the game to a week's Monday (a new week, nothing played).
func _jump(game, monday: Dictionary) -> void:
	game.date = monday.duplicate()
	game._week = null
	game.current_week()


# --- Race form (M2 step 6c): the Today card row for each word, one explanation open ---------------------------

func _form_tour(game, hub: Control) -> void:
	var form = game.get_system("form")
	var keep_sharp: float = form.sharpness
	var keep_fatigue: float = game.athlete.fatigue
	for s in [["peaking", 62.0, 6.0], ["rusty", 18.0, 22.0], ["tired", 40.0, 38.0]]:
		form.sharpness = s[1]
		game.athlete.fatigue = s[2]
		hub._show("overview")
		hub._on_day_changed()
		await _frames(5)
		if s[0] == "rusty":
			var label := _find_label(hub, "RACE FORM")
			if label != null:
				for pressed in [true, false]:
					var ev := InputEventMouseButton.new()
					ev.button_index = MOUSE_BUTTON_LEFT
					ev.pressed = pressed
					label.get_parent().gui_input.emit(ev)
				await _frames(3)
		await _shot("14d_form_" + s[0])
	form.sharpness = keep_sharp
	game.athlete.fatigue = keep_fatigue
	hub._on_day_changed()


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
	load("res://scripts/ui/help_overlay.gd").open(hub, "health_event")   # the "?" on the diagnosis panel
	await _frames(6)
	await _shot("20a_help_health_event")
	_close_help_overlays(main)
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
	await _shot("22a0_training_season_plan_top")   # "Coach's plan: Balanced ★" (M2 step 6d)
	await _scroll_to_label(hub, "BODY STRAIN")
	await _shot("22a_health_training_season_plan")
	# The rest of the tour plans its own repeating weeks: press the switch button (it asks once more).
	var switch := _find_button(hub, "Repeating week" if load("res://ui/layout.gd").compact else "One repeating week")
	print("tour: switch button found: ", switch != null)
	switch.pressed.emit()
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


func _find_button_prefix(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix) and (node as Button).is_visible_in_tree():
		return node
	for c in node.get_children():
		var found := _find_button_prefix(c, prefix)
		if found:
			return found
	return null


## Closes every help sheet / panel over a screen (HelpOverlay).
func _close_help_overlays(node: Node) -> void:
	if node.get_script() == load("res://scripts/ui/help_overlay.gd") and not node.is_queued_for_deletion():
		node.close()
		return
	for c in node.get_children():
		_close_help_overlays(c)


## The first node under `node` with this script, or null.
func _find_script(node: Node, script):
	if node == null:
		return null
	if node.get_script() == script:
		return node
	for c in node.get_children():
		var found = _find_script(c, script)
		if found:
			return found
	return null


## Scrolls the stop-event card to its end (the buttons), when it scrolls.
func _scroll_event_to_end(hub: Control) -> void:
	await _frames(3)
	if hub._event_overlay == null:
		return
	var scroll = _find_class(hub._event_overlay, "ScrollContainer")
	if scroll:
		scroll.scroll_vertical = 100000
	await _frames(3)


func _find_class(node: Node, cls: String):
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var found = _find_class(c, cls)
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
