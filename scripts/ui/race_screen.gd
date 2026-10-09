extends Control
## Race day: the field and your race plan → the race (quick result, or watched with decisions) → results.
## Works on Game.race_day; when it's all done, Game.finish_race() completes the race day.

const PLANS := [
	["front", "Lead", "Go to the front and set the pace. No traffic, but no shelter either. Suits strong runners."],
	["pack", "Sit in the pack", "Run behind others near the front and save energy. The safe, flexible choice."],
	["back", "Wait at the back", "Save the most for a late kick. Suits fast finishers; you may get boxed in."],
]
const SPEEDS := [1.0, 2.0, 4.0]   # 1x = real time (GDD 4.3.1 sketch)
## The Feeling word's colours (Race.feeling index): comfortable, working, hurting, empty.
const FEELING_COLORS := [Palette.RISK_LOW, Palette.TEXT, Palette.SORE_2, Palette.SORE_3]

var _rd: RaceDay
var _race: Race
var _plan := "pack"
var _speed := 4.0
var _acc := 0.0
var _running := false
var _finish_wait := 0.0

var _stage := "pre"   # pre / running / result: what a layout change should rebuild
var _margin: MarginContainer
var _title: Label
var _subtitle: Label
var _header_right: HBoxContainer
var _body: Control
# Running-phase widgets
var _runners_view: Control
var _clock: Label
var _info: Label
var _standings: VBoxContainer
var _stand_rows := []   # [name label, gap label] per position, reused every frame
var _commentary: VBoxContainer
var _comment_head: Label       # "COMMENTARY": hidden with the commentary while a card is open (PC)
var _feeling: Label            # "Feeling: Working" under the clock (GDD 4.3.1)
var _slow_note: Label          # "Slowed to 1x" while the race holds at 1x near something happening; "Paused" when paused
var _bar: RaceActionBar        # Push / Hold / Ease / Move out / Kick now
var _events_seen := 0          # how many of the race's events the slow-motion check has looked at
var _slow_left := 0.0          # race seconds more at 1x (a move, box, contact or fall near you, at 2x / 4x)
var _slow_reason := ""         # what it was ("Savolainen kicks"), shown in the note
var _paused := false           # the pause button / Space (GDD 4.3.1 decision 27): the race waits, the bar still works
var _pause_button: Button
var _pause_icon: Control       # the two bars (or the triangle when paused), drawn so no font is needed
var _track_area: Control       # the track: a decision card never covers it (decision 26)
var _side_scroll: ScrollContainer   # PC: the right column (card + clock + positions + commentary)
var _compact_run := false      # the layout the running stage was built for (a resize waits until the race is over)
var _decision: Control         # the decision card: PC = a panel at the top of the right column, phone = a bottom sheet
var _card_holder: Control      # where the card's content goes (the panel itself, or the sheet's scroll area)
var _card_box: Control         # the content last put there (the sheet is fitted to its height)
var _help_button: HelpButton   # "?" in the header: the help of this stage (GDD 5 "Help")
var _help: HelpOverlay         # open help; the race waits while it is open


func _ready() -> void:
	_rd = Game.race_day
	if _rd == null:
		Router.go.call_deferred("career_hub")
		return
	Router.layout_changed.connect(_on_layout_changed)
	_build_shell()
	_show_pre()


## Title, speed buttons and the empty body that the stages fill. Rebuilt when the layout switches.
func _build_shell() -> void:
	if _margin:
		_margin.queue_free()
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	Layout.page_margin(_margin)
	add_child(_margin)
	var column := UIKit.vbox(10 if Layout.compact else 16)
	_margin.add_child(column)

	var header := UIKit.hbox(16)
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = UIKit.wrapped("", "TitleLabel")
	_subtitle = UIKit.wrapped("")
	titles.add_child(_title)
	titles.add_child(_subtitle)
	header.add_child(titles)
	_header_right = UIKit.hbox(8)
	if Layout.compact:
		_header_right.visible = false   # shown (under the title) when there are speed buttons
	else:
		_header_right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		header.add_child(_header_right)
	_help_button = HelpButton.new(_help_id())
	_help_button.pressed.connect(func(): _open_help(_help_id()))
	header.add_child(_help_button)
	column.add_child(header)
	if Layout.compact:
		column.add_child(_header_right)

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)


func _on_layout_changed(_compact: bool) -> void:
	if _stage == "running":
		return   # the race goes on; the next stage uses the new layout
	_build_shell()
	if _stage == "result":
		_show_result(false)
	else:
		_show_pre()


## The decision card's home (GDD 4.3.1 decision 26): the race stays visible while a card is open, so the card is never
## a full-screen layer. PC: a panel at the top of the right column (made in _show_running, the race is paused while
## it is open). Phone: a bottom sheet over the screen below the track and the clock, made here.
func _make_decision() -> void:
	_drop_decision()
	if not _compact_run:
		_decision = PanelContainer.new()
		_decision.name = "DecisionCard"
		var style := UIKit.alert_style(Palette.ACCENT, 14)
		style.bg_color = Palette.SURFACE   # (darker than the answer buttons, so they read as buttons)
		_decision.add_theme_stylebox_override("panel", style)
		_decision.visible = false
		_card_holder = _decision
	else:
		var sheet := PanelContainer.new()
		sheet.name = "DecisionSheet"
		sheet.anchor_left = 0.0
		sheet.anchor_right = 1.0
		sheet.anchor_top = 1.0
		sheet.anchor_bottom = 1.0
		sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.SURFACE   # opaque: the positions behind it must not shine through the card's text
		style.border_color = Palette.ACCENT
		style.border_width_top = 2
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		sheet.add_theme_stylebox_override("panel", style)
		sheet.visible = false
		add_child(sheet)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 14)
		sheet.add_child(margin)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		margin.add_child(scroll)
		_decision = sheet
		_card_holder = scroll
	_decision.visibility_changed.connect(_on_decision_visibility)


## Removes the card (and the phone sheet, which is not part of the body).
func _drop_decision() -> void:
	if _decision != null and is_instance_valid(_decision):
		_decision.queue_free()
	_decision = null
	_card_holder = null
	_card_box = null


## While a card is open on PC the commentary makes room for it, and the column starts at the card.
func _on_decision_visibility() -> void:
	if _decision == null or not is_instance_valid(_decision):
		return
	var open := _decision.visible
	if not open:
		_decision.modulate.a = 1.0
	if _comment_head != null and is_instance_valid(_comment_head):
		_comment_head.visible = not (open and not _compact_run)
		_commentary.visible = _comment_head.visible
	if open and _side_scroll != null and is_instance_valid(_side_scroll):
		_side_scroll.scroll_vertical = 0


func _set_body(content: Control) -> void:
	for child in _body.get_children():
		child.queue_free()
	for child in _header_right.get_children():
		child.queue_free()
	_header_right.visible = false
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(content)
	_help_button.entry_id = _help_id()


# --- Help (GDD 5 "Help") ------------------------------------------------------------------------

## The help of this stage: before the race, the race itself (with its decisions), the result.
func _help_id() -> String:
	return {"pre": "race_before", "running": "race_running", "result": "race_result"}.get(_stage, "race_before")


func _open_help(id: String) -> void:
	_help = HelpOverlay.open(self, id)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_F1:
		_open_help(_help_id())
		get_viewport().set_input_as_handled()
	elif key == KEY_SPACE and _can_pause():
		_pause_button.button_pressed = not _pause_button.button_pressed   # (→ _on_pause_toggled)
		get_viewport().set_input_as_handled()


## Pause (button or Space): while the race runs, with no card or help open.
func _can_pause() -> bool:
	return _stage == "running" and _running and _pause_button != null and is_instance_valid(_pause_button) \
			and _race != null and not _race.finished and _race.pending.is_empty() \
			and not (is_instance_valid(_help) and not _help.is_queued_for_deletion())


func _on_pause_toggled(on: bool) -> void:
	_paused = on
	_pause_icon.queue_redraw()
	_update_slow_note()


## The pause button's picture: two bars ("pause") or a triangle when paused ("run on"). Drawn here because the font may
## not have the symbols on every device.
func _draw_pause_icon() -> void:
	var c := _pause_icon.size / 2.0
	var color := Palette.TEXT
	if _paused:
		_pause_icon.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -10), c + Vector2(-6, 10), c + Vector2(9, 0)]), color)
	else:
		_pause_icon.draw_rect(Rect2(c + Vector2(-8, -10), Vector2(5, 20)), color)
		_pause_icon.draw_rect(Rect2(c + Vector2(3, -10), Vector2(5, 20)), color)


func _update_titles() -> void:
	var m := _rd.meet
	_title.text = m.name
	_subtitle.text = "%s · 800 m %s · %s · %s" % [_rd.round_name(), Calendar.age_class(Game.athlete, m.date.year),
			Calendar.place(Game.athlete, m), Calendar.format_meet_date(m)]


# --- Before the race ----------------------------------------------------------------------

func _show_pre() -> void:
	_stage = "pre"
	_drop_decision()
	_update_titles()
	var a := Game.athlete

	var field := UIKit.vbox(6)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(UIKit.label("THE FIELD", "CaptionLabel"))
	var entrants := _rd.current_entrants().duplicate()
	entrants.sort_custom(func(x, y): return _pb_of(x) < _pb_of(y))
	for e in entrants:
		var line := UIKit.hbox(8)
		line.custom_minimum_size.y = 30
		var n := UIKit.label(e.name)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.clip_text = true
		if e.get("is_player", false):
			n.add_theme_color_override("font_color", Palette.ACCENT)
		line.add_child(n)
		if not Layout.compact:
			var club := UIKit.label(e.club, "MutedLabel")
			club.custom_minimum_size.x = 220
			club.clip_text = true
			line.add_child(club)
		var pb := _pb_of(e)
		var pb_label := UIKit.label("PB " + (Calendar.format_time(pb) if pb < 9999.0 else "–"), "MutedLabel")
		pb_label.custom_minimum_size.x = 110
		pb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(pb_label)
		field.add_child(line)
	var field_panel := UIKit.panel(field, 16)
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var side := UIKit.vbox(10)
	side.add_child(UIKit.label("YOU", "CaptionLabel"))
	var state := Training.fatigue_state(a.fatigue)
	var cond := UIKit.label("Feeling %s (fatigue %d)" % [state[0].to_lower(), roundi(_rd.fatigue)])
	cond.add_theme_color_override("font_color", state[1])
	side.add_child(cond)
	var form := FormUI.race_card()   # race-day form: Peaking / Sharp / OK / Rusty / Tired (GDD 4.8)
	if form != null:
		side.add_child(form)
	# Racing with a niggle or a cold: slower, and it may get worse (GDD 4.6).
	var injured := HealthUI.race_card(HealthUI.race_outlook(Game.current_week().day), true)
	# Scratching (not starting) is possible in the first round; when injured it sits right under the warning.
	var scratch: Control = null
	if _rd.round_index == 0:
		scratch = HealthUI.scratch_control(_rd.meet, func(): Router.go("career_hub"))
	if injured != null:
		side.add_child(injured)
		if scratch != null:
			side.add_child(scratch)
	var standard := Calendar.standard_text(a, _rd.meet)
	if standard != "":
		side.add_child(UIKit.wrapped(standard))
	side.add_child(UIKit.label("RACE PLAN", "CaptionLabel"))
	var group := ButtonGroup.new()
	for p in PLANS:
		var card := ChoiceCard.new(p[1], p[2], group)
		card.selected = p[0] == _plan
		card.button.pressed.connect(func(): _plan = p[0])
		side.add_child(card)
	var buttons := UIKit.hbox(8)
	var quick := UIKit.button("Quick result", false, 160)
	quick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick.pressed.connect(_start.bind(false))
	var watch := UIKit.button("Watch & decide", true, 200)
	watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch.pressed.connect(_start.bind(true))
	buttons.add_child(quick)
	buttons.add_child(watch)
	side.add_child(buttons)
	if injured == null and scratch != null:   # (once you've run a heat, you finish the meet: no scratch in the final)
		side.add_child(scratch)
	var side_panel := UIKit.panel(side, 16)
	side_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if Layout.compact:
		# One scrolling column: your plan and the start buttons first, the field below.
		var scroll := _scroll_column()
		var column := scroll.get_child(0) as VBoxContainer
		column.add_child(side_panel)
		column.add_child(field_panel)
		_set_body(scroll)
		return
	side_panel.custom_minimum_size.x = 440
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(field_panel)
	var side_scroll := ScrollContainer.new()   # the plan, buttons and health warning can be taller than a short window
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.custom_minimum_size.x = 440.0 + 12.0
	side_scroll.add_child(side_panel)
	var row := UIKit.hbox(16)
	row.add_child(scroll)
	row.add_child(side_scroll)
	_set_body(row)


## A vertically scrolling column (no sideways scrolling); returns the ScrollContainer, its child is the VBox.
func _scroll_column() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := UIKit.vbox(12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return scroll


func _pb_of(e: Dictionary) -> float:
	if e.get("is_player", false):
		var pb: float = Game.athlete.personal_bests.get(Game.athlete.main_event, 0.0)
		return pb if pb > 0.0 else 9999.0
	var rival: Dictionary = e.get("rival", {})
	var rpb := float(rival.get("pb", 0.0))
	return rpb if rpb > 0.0 else 9999.0


func _start(interactive: bool) -> void:
	_race = _rd.start_round(interactive, _plan)
	if not interactive:
		_race.run()
		_show_result()
		return
	_show_running()


# --- The race -------------------------------------------------------------------------------

func _show_running() -> void:
	_stage = "running"
	_compact_run = Layout.compact
	_paused = false
	_make_decision()
	var track_area := Control.new()
	_track_area = track_area
	track_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if Layout.compact:
		track_area.custom_minimum_size.y = 250
		track_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not _race.indoor:
		var stadium := Control.new()
		stadium.set_script(preload("res://scripts/ui/track_drawing.gd"))
		stadium.set_anchors_preset(Control.PRESET_FULL_RECT)
		track_area.add_child(stadium)
	else:
		# The hall track never changes: its own view, drawn once (the dots view redraws every frame).
		var floor_view := Control.new()
		floor_view.set_script(preload("res://scripts/ui/race_runners_view.gd"))
		floor_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		floor_view.set("race", _race)
		floor_view.set("track_only", true)
		track_area.add_child(floor_view)
	_runners_view = Control.new()
	_runners_view.set_script(preload("res://scripts/ui/race_runners_view.gd"))
	_runners_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_runners_view.set("race", _race)
	_runners_view.set("indoor_floor_below", true)
	track_area.add_child(_runners_view)

	_clock = UIKit.label("0.0", "TitleLabel")
	_info = UIKit.wrapped("")
	_feeling = UIKit.label("")
	_slow_note = UIKit.label("SLOWED TO 1x", "CaptionLabel")
	_slow_note.add_theme_color_override("font_color", Palette.ACCENT)
	_slow_note.visible = false
	_slow_note.clip_text = true   # a long reason never widens the panel
	_slow_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if Layout.compact else HORIZONTAL_ALIGNMENT_LEFT
	_slow_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_standings = UIKit.vbox(2)
	_stand_rows.clear()
	_commentary = UIKit.vbox(4)
	_events_seen = _race.events.size()
	_slow_left = 0.0
	# The action bar (not in quick mode, which never gets here) sits under the track and never scrolls away.
	_bar = RaceActionBar.new(_race)
	var side := UIKit.vbox(8)
	var status: VBoxContainer = null
	if Layout.compact:
		status = UIKit.vbox(2)
		var bar := UIKit.hbox(12)
		_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bar.add_child(_clock)
		bar.add_child(_info)
		status.add_child(bar)
		var mood := UIKit.hbox(12)
		mood.add_child(_feeling)
		mood.add_child(_slow_note)
		status.add_child(mood)
	else:
		side.custom_minimum_size.x = 330
		side.add_child(_clock)
		side.add_child(_feeling)
		side.add_child(_slow_note)
		side.add_child(_info)
	side.add_child(UIKit.label("POSITIONS", "CaptionLabel"))
	side.add_child(_standings)
	_comment_head = UIKit.label("COMMENTARY", "CaptionLabel")
	side.add_child(_comment_head)
	side.add_child(_commentary)
	var side_panel := UIKit.panel(side, 16)

	if Layout.compact:
		var column := UIKit.vbox(8)
		column.add_child(track_area)
		column.add_child(status)
		column.add_child(_bar)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(side_panel)
		column.add_child(scroll)
		_set_body(column)
	else:
		var left := UIKit.vbox(10)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(track_area)
		left.add_child(_bar)
		# The right column: a decision card (decision 26) on top of the clock, positions and commentary. It scrolls
		# when the card and the rest are taller than the window; the track on the left is never covered.
		var right := UIKit.vbox(10)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(_decision)
		right.add_child(side_panel)
		_side_scroll = ScrollContainer.new()
		_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_side_scroll.custom_minimum_size.x = 330.0 + 32.0 + 12.0
		_side_scroll.add_child(right)
		var row := UIKit.hbox(16)
		row.add_child(left)
		row.add_child(_side_scroll)
		_set_body(row)

	_header_right.visible = true
	var group := ButtonGroup.new()
	for s in SPEEDS:
		var b := UIKit.toggle("%dx" % s, group)
		b.custom_minimum_size.x = 64
		b.focus_mode = Control.FOCUS_NONE   # (Space pauses; it must not press a focused speed button)
		if Layout.compact:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = s == _speed
		b.pressed.connect(func(): _speed = s)
		_header_right.add_child(b)
	# Pause (decision 27): beside the speeds, 44 px, a toggle (lit = paused). Not in the speed group.
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.toggle_mode = true
	_pause_button.theme_type_variation = "ToggleButton"
	_pause_button.custom_minimum_size = Vector2(56 if Layout.compact else 64, 44)
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_icon = Control.new()
	_pause_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_icon.draw.connect(_draw_pause_icon)
	_pause_button.add_child(_pause_icon)
	_pause_button.toggled.connect(_on_pause_toggled)
	_header_right.add_child(_pause_button)

	_race.commentary.connect(_add_commentary)
	_race.decision_needed.connect(_show_decision)
	# Dev (debug builds, e.g. run from the editor): the engine's race events in the Output panel, until the
	# commentary turns them into words (step R4).
	_race.print_events = OS.is_debug_build()
	_running = true
	_acc = 0.0
	_finish_wait = 0.0


func _process(delta: float) -> void:
	if not _running or (is_instance_valid(_help) and not _help.is_queued_for_deletion()):
		return   # (the race waits while the help is open)
	if _race.finished:
		_finish_wait += delta
		if _finish_wait > 1.2:
			_running = false
			_show_result()
		return
	if not _race.pending.is_empty():
		return
	if _paused:
		_bar.refresh()   # (the bar works while paused: a command is given at once and acts when the race runs on)
		return
	# At 2x / 4x the race drops to 1x for a few race seconds when a move, box, contact or fall happens close to
	# the player (data controls.slow_motion), then goes back to the chosen speed.
	_acc += delta * (1.0 if _slow_left > 0.0 else _speed)
	while _acc >= Race.DT and _race.pending.is_empty() and not _race.finished:
		_race.step()
		_acc -= Race.DT
		var moment := _race.moment_event(_events_seen) if _speed > 1.0 else {}
		if not moment.is_empty():
			_slow_left = float(Data.races.controls.slow_motion.seconds)
			_slow_reason = _race.moment_text(moment)
			_acc = minf(_acc, Race.DT)
		_events_seen = _race.events.size()
		_slow_left = maxf(0.0, _slow_left - Race.DT)
	# Dots between the last two engine steps, so they glide instead of jumping 10 times a second at 1x.
	_runners_view.set("blend", 1.0 if _race.finished else clampf(_acc / Race.DT, 0.0, 1.0))
	_refresh_running()


func _refresh_running() -> void:
	_clock.text = Calendar.format_time(_race.time) if _race.time >= 60.0 else "%.1f" % _race.time
	var p := _race.player
	var order := _race.standings()
	_info.text = "You: %s of %d · %d m to go" % [Race._ordinal(order.find(p) + 1), order.size(),
			maxi(0, roundi(Race.DISTANCE - p.d))]
	var feeling := _race.feeling()
	_feeling.text = "Feeling: " + feeling.word
	_feeling.add_theme_color_override("font_color", FEELING_COLORS[feeling.index])
	_update_slow_note()
	_bar.refresh()
	# The rows are made once and only their text changes: rebuilding them every frame re-lays-out the whole
	# side panel (including the wrapped commentary) 60 times a second.
	if _stand_rows.size() != order.size():
		for child in _standings.get_children():
			child.queue_free()
		_stand_rows.clear()
		for i in order.size():
			var line := UIKit.hbox(6)
			var n := UIKit.label("")
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.clip_text = true
			line.add_child(n)
			var g := UIKit.label("", "MutedLabel")
			line.add_child(g)
			_standings.add_child(line)
			_stand_rows.append([n, g])
	var lead := order[0].d
	for i in order.size():
		var r: Race.Runner = order[i]
		var gap := "" if i == 0 else ("+%.1f m" % (lead - r.d) if not r.done else Calendar.format_time(r.t))
		if i == 0 and r.done:
			gap = Calendar.format_time(r.t)
		if r.status == "dnf":
			gap = "DNF"
		var n: Label = _stand_rows[i][0]
		n.text = "%d. %s" % [i + 1, r.name]
		if r.is_player:
			n.add_theme_color_override("font_color", Palette.ACCENT)
		else:
			n.remove_theme_color_override("font_color")
		(_stand_rows[i][1] as Label).text = gap
	_runners_view.queue_redraw()


## The note under the Feeling word: "PAUSED" while paused, else "SLOWED TO 1x · why" while the race holds at 1x.
func _update_slow_note() -> void:
	if _slow_note == null or not is_instance_valid(_slow_note):
		return
	if _paused and not _race.finished:
		_slow_note.visible = true
		_slow_note.text = "PAUSED" if Layout.compact else "PAUSED · SPACE TO RESUME"
		return
	_slow_note.visible = _slow_left > 0.0 and _speed > 1.0 and not _race.finished
	var head := "SLOWED TO 1x" if not Layout.compact else "SLOWED"   # (a phone has less room beside the Feeling word)
	_slow_note.text = head + " · " + _slow_reason.to_upper() if _slow_reason != "" else head


func _add_commentary(text: String) -> void:
	_commentary.add_child(UIKit.wrapped(text, ""))
	while _commentary.get_child_count() > (3 if Layout.compact else 5):
		var old := _commentary.get_child(0)
		_commentary.remove_child(old)
		old.queue_free()


## The decision card (decision 26): PC = the panel at the top of the right column, phone = a bottom sheet below the
## track and the clock. The race is paused while it is open and the track is never covered.
func _show_decision(d: Dictionary) -> void:
	_refresh_running()
	for child in _card_holder.get_children():
		_card_holder.remove_child(child)
		child.queue_free()
	var box := UIKit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIKit.hbox(8)
	var title := UIKit.wrapped(d.title, "HeadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var help := HelpButton.new("race_running")
	help.pressed.connect(func(): _open_help("race_running"))
	head.add_child(help)
	box.add_child(head)
	box.add_child(UIKit.wrapped(d.text, ""))
	if d.has("coach"):   # the coach by the track shouts (when he can see you, GDD 4.3.1)
		var shout := UIKit.vbox(2)
		var tag := UIKit.label(Data.race_cards.coach.label, "CaptionLabel")
		tag.add_theme_color_override("font_color", Palette.ACCENT)
		shout.add_child(tag)
		shout.add_child(UIKit.wrapped("“%s”" % d.coach.text, ""))
		box.add_child(UIKit.alert_panel(shout, Palette.ACCENT))
	for o in d.options:
		var b := UIKit.button(o.label, false, 200)
		b.pressed.connect(func():
			_decision.visible = false
			_race.choose(o.id))
		box.add_child(b)
		box.add_child(UIKit.wrapped(o.detail))
	_card_box = box
	_card_holder.add_child(box)   # the panel style already pads it
	if not _compact_run:
		_decision.visible = true
		return
	# Phone: the sheet starts below the clock and is as tall as the card needs (the rest scrolls). Its height is only
	# known once the texts are laid out, so it is shown (invisibly) for two frames first; the race waits anyway.
	_card_holder.custom_minimum_size.y = 0.0
	_decision.modulate.a = 0.0
	_decision.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if _card_box != box or not is_instance_valid(box) or _decision == null:
		return
	var top := _bar.get_global_rect().position.y - 4.0   # (the sheet covers the action bar, which a card dims anyway)
	var room := maxf(size.y - top - 40.0, 160.0)   # (40 = the sheet's own padding)
	_card_holder.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, room)
	_decision.modulate.a = 1.0


# --- Results ----------------------------------------------------------------------------------

var _result := {}   # what the result stage shows (kept so a layout change can redraw it)


func _show_result(fresh := true) -> void:
	_stage = "result"
	_drop_decision()
	if fresh:
		var res := _race.results()
		var old_pb: float = Game.athlete.personal_bests.get(Game.athlete.main_event, 0.0)
		_rd.finish_round()
		var mine: Dictionary = {}
		for r in res:
			if r.is_player:
				mine = r
		var place := res.find(mine) + 1
		var headline := "%s in %s" % [Race._ordinal(place), Calendar.format_time(mine.time)]
		var best_so_far := old_pb
		for r in _rd.player_results.slice(0, -1):
			if r.get("status", "") == "" and (best_so_far == 0.0 or r.time < best_so_far):
				best_so_far = r.time
		match mine.status:
			"dnf": headline = "Did not finish"
			"dq": headline = "Disqualified (obstruction)"
			_:
				if best_so_far == 0.0 or mine.time < best_so_far:
					headline += "  ·  Personal best!"
		# After the heats: every heat's result with the marks of a real result list (Q = through on place, q = on
		# time), the player's heat first. Otherwise just this race.
		var lists := []   # [{title, res, mine}]
		var marks := {}
		if _rd.rounds.size() > 1 and _rd.round_index == 1:
			marks = _rd.heat_marks.duplicate()
			for h in _rd.heat_results.size():
				var own: bool = h == _rd.player_heat
				lists.append({"title": "HEAT %d%s" % [h + 1, " · YOUR HEAT" if own else ""],
						"res": _rd.heat_results[h], "mine": own})
			lists.sort_custom(func(x, y): return x.mine and not y.mine)
		else:
			lists.append({"title": "", "res": res, "mine": true})
		_result = {"res": res, "headline": headline, "lists": lists, "marks": marks,
				"via": marks.get(mine.name, ""),
				"done": _rd.is_done(), "qualified": _rd.qualified, "heats": _rd.rounds.size() > 1}

	var col := UIKit.vbox(12)
	col.add_child(UIKit.wrapped(_result.headline, "HeadingLabel"))
	var marks_text: Dictionary = Data.races.heats.marks
	if not _result.marks.is_empty():
		col.add_child(UIKit.wrapped(marks_text.legend))

	var tables := UIKit.vbox(10)
	tables.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for list in _result.lists:
		if list.title != "":
			var head := UIKit.label(list.title, "CaptionLabel")
			if list.mine:
				head.add_theme_color_override("font_color", Palette.ACCENT)
			tables.add_child(head)
		var panel := UIKit.panel(_results_grid(list.res, _result.marks), 16)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tables.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(tables)
	col.add_child(scroll)

	var next := UIKit.button("", true, 220)
	if not _result.done:
		col.add_child(UIKit.wrapped(marks_text.via_place if _result.via == marks_text.place \
				else marks_text.via_time if _result.via == marks_text.time else "You're through to the final!", ""))
		next.text = "On to the final"
		next.pressed.connect(_show_pre)
	else:
		if _result.heats and not _result.qualified:
			col.add_child(UIKit.wrapped("Not enough to make the final this time.", ""))
		next.text = "Continue"
		next.pressed.connect(_leave)
	col.add_child(next)

	if Layout.compact:
		_set_body(col)
		return
	# Wide screens: keep the table a readable width, centred.
	col.custom_minimum_size.x = 820
	next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var wrap := UIKit.hbox(0)
	wrap.add_child(UIKit.spacer())
	wrap.add_child(col)
	wrap.add_child(UIKit.spacer())
	_set_body(wrap)


## One result table: place, name, (club,) time and the Q / q mark ("" when the runner did not go through).
func _results_grid(res: Array, marks: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4 if Layout.compact else 5
	grid.add_theme_constant_override("h_separation", 14 if Layout.compact else 24)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var headers := ["", "NAME", "TIME", ""] if Layout.compact else ["", "NAME", "CLUB", "TIME", ""]
	for h in headers:
		grid.add_child(UIKit.label(h, "CaptionLabel"))
	for i in res.size():
		var r: Dictionary = res[i]
		var no_time: bool = r.get("status", "") != ""
		var cells := ["–" if no_time else str(i + 1), r.name, Race.time_text(r), marks.get(r.name, "")]
		if not Layout.compact:
			cells.insert(2, r.club)
		for c in cells.size():
			var l := UIKit.label(cells[c], "MutedLabel" if (not Layout.compact and c == 2) else "")
			if c == 1:   # the name column takes the room
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.clip_text = true
			if r.is_player:
				l.add_theme_color_override("font_color", Palette.ACCENT)
			elif c == cells.size() - 1 and cells[c] != "":
				l.add_theme_color_override("font_color", Palette.RISK_LOW)
			grid.add_child(l)
	return grid


## Completes the race day. If the race came up during Play week, the week goes on (and may reach another race).
func _leave() -> void:
	if Game.finish_race() == Game.RACE:
		Router.go("race")
	else:
		Router.go("career_hub")   # the hub shows the weekly report or a stop event if there is one
