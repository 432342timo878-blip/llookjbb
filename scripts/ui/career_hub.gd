extends Control
## Career home screen: athlete header with today's date, Next day (plays one day) and Play week (plays to
## Sunday night or until something needs the player), the week strip (Mon–Sun of this week; tap a day to
## open the day editor), and tabs (Overview / Training / Calendar / Rankings / Report). Wide layout on PC
## (tabs on top, the day editor as a side panel); on a phone the content is stacked, the tabs sit in a bar
## at the bottom, within thumb reach, and the day editor is a bottom sheet. Stop events show as a
## full-screen dimmed decision panel.

## id, tab text, short tab text (phone)
const VIEWS := [["overview", "Overview", "Overview"], ["training", "Training", "Training"],
		["calendar", "Calendar", "Calendar"], ["rankings", "Rankings", "Rankings"], ["report", "Report", "Report"]]
const SIDE_PANEL_WIDTH := 480.0       # the day editor's side panel on PC (a bit less on a short, wide window)
const TAB_BAR_WIDTH := 690.0          # what the five tabs need next to the side panel
const MONTH_NAMES := ["January", "February", "March", "April", "May", "June", "July", "August",
		"September", "October", "November", "December"]

var _view := "overview"
var _tabs := {}   # view id -> tab Button
var _margin: MarginContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _name_label: Label
var _save_button: Button
var _info_label: Label
var _date_label: Label
var _event_overlay: ColorRect   # full-screen dimmed layer for stop events
var _strip: WeekStrip
var _editor: DayEditor          # the day editor; lives in the side panel (PC) or the bottom sheet (phone)
var _selected_day := -1         # the day open in the editor, -1 = none
var _side: PanelContainer       # PC: the side panel around the editor (null on a phone)
var _sheet: Control             # phone: the dimmed layer + bottom sheet around the editor (null on PC)
var _sheet_scroll: ScrollContainer
var _today_card: TodayCard      # on Overview only
var _overview_columns := 0      # columns the wide Overview was built with (0 = not built yet)


func _ready() -> void:
	Router.layout_changed.connect(func(_c): _build_shell(); _show(_view); _show_pending_event())
	_build_shell()
	# Coming back from a race that ended the week: show how the week went.
	_show("report" if Game.open_report and not Game.last_report.is_empty() else "overview")
	Game.open_report = false
	_show_pending_event()


## Ctrl+S saves (desktop only), like the Save button. Escape closes the day editor.
## Debug builds only: T arms a test stop event for the end of the next played day (see DevEvents);
## H prints the hidden health numbers (strain, injuries, risk) to the Output panel (HealthSystem.debug_text).
## (Not F keys: when the game runs from the editor, F7/F8 pause/stop the game.)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_S and (event as InputEventKey).is_command_or_control_pressed():
		if OS.has_feature("pc"):
			_save()
			get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and _selected_day >= 0:
		_close_day()
	elif key == KEY_T:
		var dev := Game.get_system("dev") as DevEvents
		if dev:
			dev.armed = true
			_date_label.text = "Test event ready ✓"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(_date_label):
					_refresh_header())
	elif key == KEY_H and OS.is_debug_build():
		var health := Game.get_system("health") as HealthSystem
		if health:
			print(health.debug_text())


## Header, week strip, tab bar, scrolling content, day editor. Rebuilt when the window switches between
## wide and phone layout (an open day stays open).
func _build_shell() -> void:
	if _margin:
		_margin.queue_free()
	if _sheet:
		_sheet.queue_free()
	_side = null
	_sheet = null
	_sheet_scroll = null
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	Layout.page_margin(_margin)
	add_child(_margin)
	var column := UIKit.vbox(10 if Layout.compact else 16)
	_margin.add_child(column)

	column.add_child(_build_header())
	_strip = WeekStrip.new()
	_strip.selected = _selected_day
	_strip.day_pressed.connect(_on_day_pressed)
	column.add_child(_strip)
	_editor = DayEditor.new()
	_editor.changed.connect(_on_day_changed)
	_editor.close_requested.connect(_close_day)
	_editor.rebuilt.connect(_fit_sheet)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content = UIKit.vbox(14)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_tabs.clear()
	var group := ButtonGroup.new()
	var bar := UIKit.hbox(4)
	for v in VIEWS:
		var b := Button.new()
		b.text = v[2] if Layout.compact else v[1]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "BottomTabButton" if Layout.compact else "TabButton"
		b.custom_minimum_size = Vector2(0 if Layout.compact else 130, 48 if Layout.compact else 44)
		if Layout.compact:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show.bind(v[0]))
		bar.add_child(b)
		_tabs[v[0]] = b
	if Layout.compact:
		column.add_child(_scroll)
		column.add_child(HSeparator.new())
		column.add_child(bar)
		_build_sheet()
	else:
		var left := UIKit.vbox(16)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(bar)
		left.add_child(HSeparator.new())
		left.add_child(_scroll)
		var body := UIKit.hbox(16)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(left)
		_build_side_panel()
		body.add_child(_side)
		column.add_child(body)
	if _selected_day >= 0:
		_editor.show_day(_selected_day)
	_apply_editor_visibility()
	if _event_overlay:
		move_child(_event_overlay, -1)   # stays on top of the rebuilt page
	_refresh_header()


func _build_header() -> Control:
	_name_label = UIKit.label("", "TitleLabel")
	_info_label = UIKit.wrapped("")
	_date_label = UIKit.label("", "SubheadingLabel")
	var next_day := UIKit.button("Day" if Layout.compact else "Next day", true, 140)
	next_day.pressed.connect(_on_advance.bind(false))
	var play_week := UIKit.button("Week" if Layout.compact else "Play week", false, 140)
	play_week.pressed.connect(_on_advance.bind(true))
	var save := UIKit.button("Save", false, 110)
	_save_button = save
	save.pressed.connect(_save)
	var menu := UIKit.button("Menu" if Layout.compact else "Main menu", false, 140)
	menu.pressed.connect(Router.go.bind("main_menu"))

	if Layout.compact:
		# Name + Save + Menu on top, then the info line, then today's date with the time buttons.
		var box := UIKit.vbox(6)
		var top := UIKit.hbox(8)
		_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_label.clip_text = true
		top.add_child(_name_label)
		save.custom_minimum_size.x = 76
		menu.custom_minimum_size.x = 76
		top.add_child(save)
		top.add_child(menu)
		box.add_child(top)
		box.add_child(_info_label)
		var actions := UIKit.hbox(8)
		_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_date_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		actions.add_child(_date_label)
		next_day.custom_minimum_size.x = 100
		play_week.custom_minimum_size.x = 100
		actions.add_child(next_day)
		actions.add_child(play_week)
		box.add_child(actions)
		return box

	var row := UIKit.hbox(16)
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_name_label)
	titles.add_child(_info_label)
	row.add_child(titles)
	_date_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_date_label.custom_minimum_size.y = 44
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_date_label)
	for b in [next_day, play_week, save, menu]:
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(b)
	return row


## The Save button and Ctrl+S: a new snapshot save, and "Saved ✓" on the button for a moment.
func _save() -> void:
	SaveGame.save_snapshot()
	if not is_instance_valid(_save_button):
		return
	_save_button.text = "Saved ✓"
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(_save_button):
			_save_button.text = "Save")


## Next day (`week` = false) or Play week. A race day opens the race screen; a finished week shows its report.
func _on_advance(week: bool) -> void:
	var result := Game.advance_week() if week else Game.advance_day()
	if result == Game.RACE:
		Router.go("race")
		return
	_refresh_week_ui()
	if Game.open_report:
		Game.open_report = false
		_show("report")
	else:
		_show(_view)
	_show_pending_event()


func _refresh_header() -> void:
	var a := Game.athlete
	var club := Data.get_club(a.club_id)
	_name_label.text = a.full_name()
	_info_label.text = "%s · %d years · %s · %s" % [
		Data.get_event(a.main_event).name, a.age_on(Game.date), club.get("name", ""), a.hometown]
	_date_label.text = Calendar.format_day(Game.date)


## After days were played or an event was answered: header, week strip and the open day.
## If a new week has begun, the day editor closes (its day belonged to the old week).
func _refresh_week_ui() -> void:
	_refresh_header()
	if _selected_day >= 0 and _strip.monday != Game.week_monday():
		_selected_day = -1
		_strip.selected = -1
		_apply_editor_visibility()
	_strip.refresh()
	if _selected_day >= 0:
		_editor.refresh()


# --- Week strip and day editor -----------------------------------------------------------------

func _on_day_pressed(day: int) -> void:
	if day == _selected_day:
		_close_day()
	else:
		_open_day(day)


func _open_day(day: int) -> void:
	_selected_day = day
	_editor.show_day(day)
	_strip.selected = day
	_strip.refresh()
	_apply_editor_visibility()
	if _event_overlay:
		move_child(_event_overlay, -1)


func _close_day() -> void:
	_selected_day = -1
	_strip.selected = -1
	_strip.refresh()
	_apply_editor_visibility()


## A day change was made in the editor: the strip and the Today card show it too.
func _on_day_changed() -> void:
	_strip.refresh()
	if is_instance_valid(_today_card):
		_today_card.refresh()


func _apply_editor_visibility() -> void:
	var open := _selected_day >= 0
	if _side:
		_side.custom_minimum_size.x = _side_width()   # the window may have been resized since the page was built
		_side.visible = open
	if _sheet:
		_sheet.visible = open
	if _view == "overview" and _overview_columns != 0 and not Layout.compact \
			and _overview_columns != _wanted_overview_columns():
		_relayout_overview()


## Columns of the wide Overview: 4 need about 1150 logical px, which the side panel takes away.
func _wanted_overview_columns() -> int:
	var width := Layout.logical_width - 96.0 - (_side_width() + 16.0 if _selected_day >= 0 else 0.0)
	return 4 if width >= 1150.0 else 2


## Width of the side panel: 480, or less when the window is too narrow to keep the tabs beside it.
func _side_width() -> float:
	return clampf(Layout.logical_width - 96.0 - 16.0 - TAB_BAR_WIDTH, 380.0, SIDE_PANEL_WIDTH)


## Rebuilds the Overview for a new width and keeps its scroll position.
func _relayout_overview() -> void:
	var at := _scroll.scroll_vertical
	_show("overview")
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = at


## PC: the editor in a panel to the right of the tabs and content.
func _build_side_panel() -> void:
	var scroll := _scrolling_editor()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side = UIKit.panel(scroll, 16)
	_side.custom_minimum_size.x = _side_width()
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.visible = false


## The editor in a vertical scroll area, with a little room on the right for the scroll bar.
func _scrolling_editor() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_child(_editor)
	scroll.add_child(pad)
	return scroll


## Phone: a dimmed layer over the whole screen (tap it to close) with the editor in a sheet at the bottom.
func _build_sheet() -> void:
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.visible = false
	add_child(_sheet)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_day())
	_sheet.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.SURFACE, 0.98)
	style.border_color = Palette.BORDER
	style.border_width_top = 1
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	panel.add_theme_stylebox_override("panel", style)
	_sheet.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box := UIKit.vbox(8)
	margin.add_child(box)
	var handle := UIKit.dot(Palette.BORDER, 44, 5)
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(handle)
	_sheet_scroll = _scrolling_editor()
	box.add_child(_sheet_scroll)


## Sizes the bottom sheet to its content (at most 72 % of the screen; longer content scrolls).
func _fit_sheet() -> void:
	if _sheet_scroll == null:
		return
	var scroll := _sheet_scroll
	await get_tree().process_frame   # the texts need to be laid out before their height is known
	await get_tree().process_frame
	if scroll != _sheet_scroll or not is_instance_valid(scroll):
		return
	scroll.custom_minimum_size.y = minf(_editor.get_combined_minimum_size().y, size.y * 0.72)


# --- Stop events ------------------------------------------------------------------------------

## Shows the oldest unanswered stop event as a dimmed full-screen panel (hidden when there is none).
## Its choices are 44 px buttons; an event without choices just has OK.
func _show_pending_event() -> void:
	var e := Game.pending_event()
	if e.is_empty():
		if _event_overlay:
			_event_overlay.visible = false
		return
	if _event_overlay == null:
		_event_overlay = ColorRect.new()
		_event_overlay.color = Color(0.03, 0.035, 0.05, 0.72)
		_event_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_event_overlay)
	for child in _event_overlay.get_children():
		child.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_event_overlay.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var card := PanelContainer.new()
	center.add_child(card)

	# Logical window width (the screen may not be laid out yet), minus screen margin and panel padding.
	var width := minf(480.0, Layout.logical_width - 32.0 - 36.0 - 12.0)
	var box: Control
	if HealthEventPanel.handles(e):   # injury diagnosis and the "sore" warning have their own panels
		box = HealthEventPanel.build(e, width, func(choice: String): _on_event_answer(e.id, choice))
	else:
		box = UIKit.vbox(10)
		box.custom_minimum_size.x = width
		box.add_child(UIKit.label(Calendar.format_day(e.date).to_upper(), "CaptionLabel"))
		box.add_child(UIKit.wrapped(e.title, "HeadingLabel"))
		box.add_child(UIKit.wrapped(e.text, ""))
		var choices: Array = e.choices
		if choices.is_empty():
			choices = [{"id": "ok", "label": "OK", "detail": ""}]
		for c in choices:
			var b := UIKit.button(c.label, false, 200)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(_on_event_answer.bind(e.id, c.id))
			box.add_child(b)
			if c.get("detail", "") != "":
				box.add_child(UIKit.wrapped(c.detail))
	# A long panel (phone) scrolls instead of running off the screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(box)
	card.add_child(scroll)
	_event_overlay.visible = true
	move_child(_event_overlay, -1)
	_fit_event_card(scroll, box)


## Sizes the scrolling event panel to its content, at most the screen height minus the margins.
func _fit_event_card(scroll: ScrollContainer, box: Control) -> void:
	await get_tree().process_frame   # the texts need to be laid out before their height is known
	await get_tree().process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(box):
		return
	scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, size.y - 32.0 - 36.0)


func _on_event_answer(event_id: String, choice: String) -> void:
	Game.answer_event(event_id, choice)
	_refresh_week_ui()
	_show(_view)
	_show_pending_event()


func _show(view: String) -> void:
	_view = view
	_tabs[view].button_pressed = true
	_scroll.scroll_vertical = 0
	for child in _content.get_children():
		child.queue_free()
	match view:
		"overview": _build_profile(Game.athlete)
		"training": _build_training()
		"calendar": _build_calendar()
		"rankings": _build_rankings()
		"report": _content.add_child(ReportView.new())


# --- Overview ---------------------------------------------------------------------------

func _build_profile(a: Athlete) -> void:
	_today_card = TodayCard.new()
	_today_card.pressed.connect(func(): _open_day(Calendar.weekday(Game.date)))
	_content.add_child(_today_card)

	var columns: Container   # wide: a grid of 4 (2 when the width is short, e.g. with the side panel open)
	if Layout.compact:
		columns = UIKit.flex(16)
	else:
		_overview_columns = _wanted_overview_columns()
		var grid := GridContainer.new()
		grid.columns = _overview_columns
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 16)
		columns = grid
	var attribute_panels := []
	for category in ["physical", "technical", "mental"]:
		var col := UIKit.vbox(2)
		col.add_child(UIKit.label(category.to_upper(), "CaptionLabel"))
		for attr in Data.attributes_in(category):
			col.add_child(UIKit.attr_row(attr.name, a.get_attr(attr.id), a.trend(attr.id), attr.description))
		attribute_panels.append(_column_panel(col))
	if not Layout.compact:
		for p in attribute_panels:
			columns.add_child(p)

	var body := UIKit.vbox(6)   # condition and next race are on the Today card
	body.add_child(UIKit.label("BODY", "CaptionLabel"))
	for f in [
		["Height", "%d cm" % a.height_cm],
		["Weight", "%d kg" % a.weight_kg],
		["Development", {"early": "Early", "average": "Average", "late": "Late"}[a.maturation]],
		["Born", UIKit.format_date(a.birth_date)],
	]:
		body.add_child(_fact_row(f[0], UIKit.label(f[1])))
	body.add_child(UIKit.label(" "))
	body.add_child(UIKit.label("PERSONAL BEST", "CaptionLabel"))
	var pb: float = a.personal_bests.get(a.main_event, 0.0)
	if pb == 0.0:
		body.add_child(UIKit.wrapped("No races yet. Enter some in the Calendar.", "MutedLabel"))
	else:
		body.add_child(_fact_row(Data.get_event(a.main_event).name, UIKit.label(Calendar.format_time(pb))))
		body.add_child(UIKit.label(" "))
		body.add_child(UIKit.label("RECENT RACES", "CaptionLabel"))
		for r in a.results.slice(-5):
			var where: String = "" if r.round == "Race" else " (%s)" % r.round.to_lower()
			var line := "%d.%d. %s%s: %s %s" % [int(r.date.day), int(r.date.month), r.meet, where,
					Race._ordinal(int(r.place)), Calendar.format_time(r.time)]
			body.add_child(UIKit.wrapped(line + (" PB" if r.pb else ""), "MutedLabel"))
	columns.add_child(_column_panel(body))
	if Layout.compact:   # the body and results first, then the attributes
		for p in attribute_panels:
			columns.add_child(p)
	_content.add_child(columns)

	var help := ("Arrows show attributes that have been rising or falling lately. Tap an attribute to see what it does. "
			+ "Plan your week under Training, change a single day by tapping it in the week strip, "
			+ "then press Next day or Play week. In the week strip, a round ! means you were sore that day "
			+ "(the colour says how sore) and a + means an injury or illness limited it.")
	if OS.has_feature("pc"):
		help += " Ctrl+S saves."
	_content.add_child(UIKit.wrapped(help, "MutedLabel"))


# --- Training plan ----------------------------------------------------------------------

func _build_training() -> void:
	var a := Game.athlete
	var month: int = Game.add_days(Game.week_monday(), 3).month
	_content.add_child(UIKit.label("Weekly plan", "HeadingLabel"))
	_content.add_child(UIKit.wrapped(
			("Your plan repeats every week until you change it. Up to %d sessions a day; an empty day is a rest day. "
			% Training.MAX_SESSIONS_PER_DAY)
			+ "To change just one day of this week, tap it in the week strip above."))

	var summary := UIKit.vbox(8)
	var refresh_summary := func(): _fill_plan_summary(summary, a, month)
	# After every edit of the weekly plan: the injury limits go into this week again, the week strip and the
	# open day follow the plan, and the summary (with load vs normal and risk) is worked out again.
	var on_plan_edited := func():
		HealthUI.refresh()
		_refresh_week_ui()
		refresh_summary.call()

	var days := UIKit.vbox(14 if Layout.compact else 8)
	for day in 7:
		if day > 0 and Layout.compact:
			days.add_child(HSeparator.new())
		days.add_child(_day_row(day, a, month, on_plan_edited))
	_content.add_child(UIKit.panel(days, 16))

	var buttons := UIKit.hbox(8)
	var coach := UIKit.button("Coach's plan", false, 160)
	coach.pressed.connect(func():
		Game.training_plan = Training.coach_plan()
		HealthUI.refresh()
		_refresh_week_ui()
		_show("training"))
	var clear := UIKit.button("Clear week", false, 160)
	clear.pressed.connect(func():
		Game.training_plan = Training.empty_plan()
		HealthUI.refresh()
		_refresh_week_ui()
		_show("training"))
	buttons.add_child(coach)
	buttons.add_child(clear)
	if Layout.compact:
		coach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(buttons)
	_content.add_child(UIKit.wrapped("Coach's plan puts back the starter week your club coach suggests."))

	_content.add_child(UIKit.panel(summary, 16))
	refresh_summary.call()
	_content.add_child(_session_library(a, month))


## One day of the plan. Wide: day, two pickers and the load on one row. Phone: a header line
## (day + load) with the two pickers stacked under it.
func _day_row(day: int, a: Athlete, month: int, on_change: Callable) -> Control:
	var date := Game.add_days(Game.week_monday(), day)
	var day_label := UIKit.label("%s %d.%d." % [Training.DAY_NAMES[day], date.day, date.month],
			"SubheadingLabel" if Layout.compact else "")
	var load_label := UIKit.label("", "MutedLabel")
	var row: BoxContainer
	var slot_parent: Control
	if Layout.compact:
		row = UIKit.vbox(6)
		var head := UIKit.hbox(8)
		day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(day_label)
		head.add_child(load_label)
		row.add_child(head)
		slot_parent = row
	else:
		row = UIKit.hbox(10)
		day_label.custom_minimum_size.x = 100
		row.add_child(day_label)
		slot_parent = row
	var slots := []
	for slot in Training.MAX_SESSIONS_PER_DAY:
		var pick := _session_picker(a, month)
		var current: Array = Game.training_plan[day]
		var id: String = current[slot] if slot < current.size() else ""
		for i in pick.item_count:
			if pick.get_item_metadata(i) == id:
				pick.select(i)
		slots.append(pick)
		slot_parent.add_child(pick)
	if not Layout.compact:
		load_label.custom_minimum_size.x = 80
		row.add_child(load_label)

	var update := func():
		var ids := []
		for p in slots:
			var sid: String = p.get_item_metadata(p.selected)
			if sid != "":
				ids.append(sid)
		Game.training_plan[day] = ids
		var load := 0.0
		for sid in ids:
			load += Training.session_load(a, Data.get_session(sid))
		load_label.text = "Rest day" if ids.is_empty() else "Load %d" % roundi(load)
	for p in slots:
		p.item_selected.connect(func(_i): update.call(); on_change.call())
	update.call()
	return row


func _session_picker(a: Athlete, month: int) -> OptionButton:
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(0 if Layout.compact else 200, 44)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.add_item("—")
	pick.set_item_metadata(0, "")
	for s in Data.training.sessions:
		var eff := Training.effectiveness(a, s, month)
		var text: String = s.name
		if eff > 0.0 and eff < 1.0:
			text += " (no track)"
		pick.add_item(text)
		var i := pick.item_count - 1
		pick.set_item_metadata(i, s.id)
		pick.set_item_tooltip(i, s.description)
		if eff == 0.0:
			pick.set_item_disabled(i, true)
			pick.set_item_tooltip(i, "Not possible this time of year")
	return pick


func _fill_plan_summary(box: VBoxContainer, a: Athlete, month: int) -> void:
	for child in box.get_children():
		child.queue_free()
	var p := Training.preview(a, Game.training_plan, month)
	var expected := Training.expected_fatigue(a, Game.training_plan, Game.week_monday())
	var verdict: String
	if expected.avg < 15.0:
		verdict = "Light: easy to recover from, but slower progress."
	elif expected.avg < 45.0:
		verdict = "Balanced: you should recover well between sessions."
	elif expected.avg < 65.0:
		verdict = "Hard: heavy legs, and training gives less when you're tired. Plan lighter weeks too."
	else:
		verdict = "Too much: you'll be exhausted, so most of the training is wasted."

	box.add_child(UIKit.label("THIS PLAN", "CaptionLabel"))
	box.add_child(_fact_row("Weekly load", UIKit.label(str(roundi(p.load)))))
	var fat := UIKit.hbox(6)
	fat.add_child(_fatigue_label(expected.avg))
	fat.add_child(UIKit.label("on average", "MutedLabel"))
	box.add_child(_fact_row("Expected fatigue", fat))
	box.add_child(UIKit.wrapped(verdict, ""))
	# Body strain of this plan: load vs your normal and injury risk (works for any plan passed in).
	var strain := HealthUI.plan_section(Game.training_plan, Game.current_week())
	if strain != null:
		box.add_child(strain)

	box.add_child(UIKit.label("TRAINING FOCUS", "CaptionLabel"))
	var focus: Array = p.stimulus.keys()
	focus.sort_custom(func(x, y): return p.stimulus[x] > p.stimulus[y])
	if focus.is_empty():
		box.add_child(UIKit.wrapped("Nothing planned: a full rest week."))
	for id in focus:
		var row := UIKit.hbox(10)
		var l := UIKit.label(_attr_name(id))
		l.custom_minimum_size.x = 150 if Layout.compact else 200
		row.add_child(l)
		var bar := ColorRect.new()
		bar.color = Palette.ACCENT
		bar.custom_minimum_size = Vector2(minf(p.stimulus[id], 6.0) * (30.0 if Layout.compact else 50.0), 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		box.add_child(row)


func _session_library(a: Athlete, month: int) -> PanelContainer:
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label("SESSIONS", "CaptionLabel"))
	for s in Data.training.sessions:
		var col := UIKit.vbox(2)
		var title := UIKit.hbox(8)
		title.add_child(UIKit.label(s.name, "SubheadingLabel"))
		title.add_child(UIKit.label("load %d" % s.load, "MutedLabel"))
		col.add_child(title)
		var trains := []
		for id in s.effects:
			trains.append(_attr_name(id).to_lower())
		var text: String = "%s Trains %s." % [s.description, ", ".join(trains)]
		var eff := Training.effectiveness(a, s, month)
		if eff == 0.0:
			text += " Not possible this time of year."
		elif eff < 1.0:
			text += " You have no indoor track this winter, so it's done on roads instead (less effective)."
		col.add_child(UIKit.wrapped(text))
		box.add_child(col)
	return UIKit.panel(box, 16)


# --- Calendar ---------------------------------------------------------------------------

func _build_calendar() -> void:
	var a := Game.athlete
	_content.add_child(UIKit.label("Season calendar", "HeadingLabel"))
	_content.add_child(UIKit.wrapped(
			"Enter the meets you want to race; a race replaces that day's training. Tap \"Entered\" again to withdraw. "
			+ "★ = your coach recommends it. "
			+ "\"Estimated\" dates are believable guesses for small meets whose real dates aren't published."))

	# The rest of this season and the whole next one.
	var meets := Calendar.meets_between(Game.date, {"year": Game.date.year + 1, "month": 10, "day": 31})
	var month := -1
	var box: VBoxContainer
	for m in meets:
		if m.date.month != month:
			month = m.date.month
			_content.add_child(UIKit.label("%s %d" % [MONTH_NAMES[month - 1].to_upper(), m.date.year], "CaptionLabel"))
			box = UIKit.vbox(18 if Layout.compact else 14)
			_content.add_child(UIKit.panel(box, 16))
		box.add_child(_meet_row(a, m))


## One meet. Wide: date | details | Enter button. Phone: date, details, then a full-width button.
func _meet_row(a: Athlete, m: Dictionary) -> Control:
	var row: BoxContainer = UIKit.vbox(6) if Layout.compact else UIKit.hbox(16)
	var date := UIKit.label(Calendar.format_meet_date(m), "CaptionLabel" if Layout.compact else "")
	if Layout.compact:
		date.text = date.text.to_upper()
	else:
		date.custom_minimum_size.x = 120
		date.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(date)

	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: String = m.name + ("  ★" if Calendar.coach_recommends(a, m, Game.date) else "")
	info.add_child(UIKit.wrapped(title, "SubheadingLabel" if not m.get("watch", false) else ""))
	var details := [Calendar.place(a, m), Data.competitions.levels.get(m.level, "")]
	if m.get("indoor", false):
		details.append("Indoor")
	if m.get("estimated", false):
		details.append("Estimated date")
	var fee := Calendar.fee_text(m)
	if fee != "" and not m.get("watch", false):
		details.append(fee)
	info.add_child(UIKit.wrapped(" · ".join(details), "MutedLabel"))
	if m.has("description"):
		info.add_child(UIKit.wrapped(m.description, "MutedLabel"))
	var check := Calendar.can_enter(a, m, Game.date)
	var standard := Calendar.standard_text(a, m)
	if check.ok and standard != "":
		info.add_child(UIKit.wrapped(standard, ""))
	if not check.ok:
		info.add_child(UIKit.wrapped(check.reason, "MutedLabel"))
	row.add_child(info)

	if check.ok:
		var b := UIKit.button("", false, 150)
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var refresh := func():
			var entered: bool = m.key in Game.entries
			b.text = "Entered ✓" if entered else "Enter"
			b.theme_type_variation = "PrimaryButton" if entered else ""
		b.pressed.connect(func():
			if m.key in Game.entries:
				Game.withdraw(m.key)
			else:
				Game.enter(m.key)
			Game.current_week()   # this week's race days follow the entries
			HealthUI.refresh()    # a race day that was withdrawn is a training day again: injury limits apply to it
			_refresh_week_ui()
			refresh.call())
		refresh.call()
		row.add_child(b)
	return row


# --- Rankings ---------------------------------------------------------------------------

const RANKING_TOP := 25

func _build_rankings() -> void:
	var a := Game.athlete
	var season := Rankings.season_of(Game.date)
	var event_name: String = Data.get_event(a.main_event).name
	_content.add_child(UIKit.label("%s %s · season %s" % [
			Calendar.age_class(a, Game.date.year), event_name, Rankings.season_label(season)], "HeadingLabel"))
	_content.add_child(UIKit.wrapped(
			"Season bests (1 Nov – 31 Oct), indoor and outdoor together. Rivals race on their own too, so the list "
			+ "fills up as the season goes on."))

	var rows := Rankings.season_list(a, Game.rivals, season)
	var box := UIKit.vbox(6)
	var mine := 0
	for r in rows:
		if r.is_player:
			mine = r.rank
	if mine == 0:
		box.add_child(UIKit.wrapped("You have no %s time this season yet. Enter a race in the Calendar." % event_name))
	else:
		box.add_child(UIKit.wrapped("You're ranked %d of %d." % [mine, rows.size()]))
	box.add_child(UIKit.label(" "))
	box.add_child(_ranking_header())
	for r in rows:
		if r.rank <= RANKING_TOP or r.is_player:
			if r.rank == RANKING_TOP + 1 or (r.rank > RANKING_TOP + 1 and r.is_player):
				box.add_child(UIKit.label("…", "MutedLabel"))
			box.add_child(_ranking_row(r))
	if rows.is_empty():
		box.add_child(UIKit.wrapped("No results this season yet."))
	_content.add_child(UIKit.panel(box, 16))


## Column widths: rank, athlete (0 = takes the free space), club (hidden on a phone), season best.
func _ranking_columns() -> Array:
	if Layout.compact:
		return [["#", 36], ["ATHLETE", 0], ["SB", 80]]
	return [["#", 50], ["ATHLETE", 260], ["CLUB", 0], ["SB", 90]]


func _ranking_header() -> HBoxContainer:
	var row := UIKit.hbox(10)
	for c in _ranking_columns():
		var l := UIKit.label(c[0], "CaptionLabel")
		l.custom_minimum_size.x = c[1]
		if c[1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if c[0] == "SB":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
	return row


func _ranking_row(r: Dictionary) -> Control:
	var row := UIKit.hbox(10)
	row.custom_minimum_size.y = 30
	var texts := [str(r.rank), r.name, Calendar.format_time(r.time)] if Layout.compact \
			else [str(r.rank), r.name, r.club, Calendar.format_time(r.time)]
	var columns := _ranking_columns()
	for i in columns.size():
		var l := UIKit.label(texts[i], "" if r.is_player else "MutedLabel")
		l.custom_minimum_size.x = columns[i][1]
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if columns[i][1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
		if columns[i][0] == "SB":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if r.is_player:
			l.add_theme_color_override("font_color", Palette.ACCENT)
		row.add_child(l)
	if not r.is_player:
		return row
	# Highlight the player's own row.
	var tint := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.ACCENT, 0.12)
	style.set_corner_radius_all(Palette.RADIUS)
	style.expand_margin_left = 8     # the tint reaches past the text so columns stay aligned
	style.expand_margin_right = 8
	tint.add_theme_stylebox_override("panel", style)
	tint.add_child(row)
	return tint


# --- Helpers ------------------------------------------------------------------------------

func _fact_row(key: String, value: Control) -> HBoxContainer:
	return UIKit.fact_row(key, value)


func _fatigue_label(fatigue: float) -> Label:
	return UIKit.fatigue_label(fatigue)


func _attr_name(id: String) -> String:
	return UIKit.attr_name(id)


func _column_panel(content: Control) -> PanelContainer:
	var p := UIKit.panel(content, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return p
