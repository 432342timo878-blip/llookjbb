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
var _side_scroll: ScrollContainer
var _sheet: Control             # phone: the dimmed layer + bottom sheet around the editor (null on PC)
var _sheet_scroll: ScrollContainer
var _today_card: TodayCard      # on Overview only
var _overview_columns := 0      # columns the wide Overview was built with (0 = not built yet)
var _phase_open := ""           # Training tab: the season phase open in the PhaseEditor ("" = the season view)
var _strip_caption: Label       # above the week strip: the season plan's phase and week (empty in repeat mode)
# Help (GDD 5 "Help"): the header "?" opens the help of what the hub shows. PC: in the side slot, over the day editor
# (Close goes back to the day); phone: a HelpOverlay sheet. `_help_stack` is what is open ([] = closed), kept across
# layout switches.
var _help_button: HelpButton
var _help: HelpPanel            # PC: the help in the side slot (null on a phone)
var _help_overlay: HelpOverlay  # phone: the hub's help sheet (null on PC)
var _help_stack := []
var _help_follows_view := false # opened with the header "?": shows the help of the tab you switch to
var _built_side_open := false   # the page was built with the side panel open (Layout.stacked() layout)


func _exit_tree() -> void:
	Layout.side_open = false   # (only the hub has a side panel)


func _ready() -> void:
	Router.layout_changed.connect(func(_c): _build_shell(); _show(_view); _show_pending_event())
	_build_shell()
	# Coming back from a race that ended the week: show how the week went.
	_show("report" if Game.open_report and not Game.last_report.is_empty() else "overview")
	Game.open_report = false
	_show_pending_event()


## Ctrl+S saves (desktop only), like the Save button. F1 opens / closes the help. Escape closes the help, then the
## day editor.
## Debug builds only: T arms a test stop event for the end of the next played day (see DevEvents);
## H prints the hidden health numbers (strain, injuries, risk) to the Output panel (HealthSystem.debug_text).
## (Not F7/F8: when the game runs from the editor, they pause/stop the game.)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_S and (event as InputEventKey).is_command_or_control_pressed():
		if OS.has_feature("pc"):
			_save()
			get_viewport().set_input_as_handled()
	elif key == KEY_F1:
		if _event_overlay == null or not _event_overlay.visible:
			_toggle_help()
	elif key == KEY_ESCAPE and not _help_stack.is_empty():
		_close_help()
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
	_strip_caption = UIKit.label("", "CaptionLabel")
	_strip_caption.clip_text = true
	_strip_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_strip_caption)
	_strip = WeekStrip.new()
	_strip.selected = _selected_day
	_strip.day_pressed.connect(_on_day_pressed)
	column.add_child(_strip)
	_editor = DayEditor.new()
	_editor.changed.connect(_on_day_changed)
	_editor.close_requested.connect(_close_day)
	_editor.help_requested.connect(func(): _open_help("day_editor", false))
	_editor.rebuilt.connect(_fit_sheet)
	_help = null
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
		b.pressed.connect(func():
			_phase_open = ""   # a tab button opens the tab at its top level (the season view, not a phase)
			_show(v[0]))
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
	_apply_help()   # (also sets the editor's visibility)
	_raise_overlays()   # the stop event and the help stay on top of the rebuilt page
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
	var short := Layout.compact or Layout.logical_width < 1280.0   # (a short, wide window: phone sideways)
	var menu := UIKit.button("Menu" if short else "Main menu", false, 110 if short else 140)
	menu.pressed.connect(Router.go.bind("main_menu"))
	_help_button = HelpButton.new(_help_entry())
	_help_button.pressed.connect(_toggle_help)

	if Layout.compact:
		# Name + ? + Save + Menu on top, then the info line, then today's date with the time buttons.
		var box := UIKit.vbox(6)
		var top := UIKit.hbox(8)
		_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_label.clip_text = true
		top.add_child(_name_label)
		top.add_child(_help_button)
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
	_name_label.clip_text = true   # a long name ends in "…" rather than pushing the buttons off the window
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(_name_label)
	titles.add_child(_info_label)
	row.add_child(titles)
	_date_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_date_label.custom_minimum_size.y = 44
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_date_label)
	for b in [next_day, play_week, save, menu, _help_button]:
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
	# The season plan's caption over the week strip (GDD 4.8 UI): "General base · week 3 of 10 · lighter week".
	var caption := SeasonUI.week_caption()
	_strip_caption.text = caption.to_upper()
	_strip_caption.visible = caption != ""


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
	if _help != null and not _help_stack.is_empty():
		_close_help()   # PC: tapping a day brings the day editor back over the help
	_apply_editor_visibility()
	_raise_overlays()


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


## The side panel (PC) shows the help when it is open, else the day editor; the phone sheet only the day editor
## (the phone's help is a HelpOverlay on top).
func _apply_editor_visibility() -> void:
	var open := _selected_day >= 0
	var help_here := _help != null and not _help_stack.is_empty()
	_editor.visible = not help_here
	if _help:
		_help.visible = help_here
	if _side:
		_side.custom_minimum_size.x = _side_width()   # the window may have been resized since the page was built
		_side.visible = open or help_here
	if _sheet:
		_sheet.visible = open
	if _view == "overview" and _overview_columns != 0 and not Layout.compact \
			and _overview_columns != _wanted_overview_columns():
		_relayout_overview()
	# The Training pages were built for the other width (side panel opened or closed): build them again.
	if _view == "training" and not Layout.compact and _content.get_child_count() > 0 \
			and _side_is_open() != _built_side_open:
		_rebuild_view()


## PC: the side panel shows the day editor or the help.
func _side_is_open() -> bool:
	return _selected_day >= 0 or (_help != null and not _help_stack.is_empty())


## Columns of the wide Overview: 4 need about 1150 logical px, which the side panel takes away.
func _wanted_overview_columns() -> int:
	var side_open := _selected_day >= 0 or (_help != null and not _help_stack.is_empty())
	var width := Layout.logical_width - 96.0 - (_side_width() + 16.0 if side_open else 0.0)
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


## PC: the editor (or the help, which covers it) in a panel to the right of the tabs and content.
func _build_side_panel() -> void:
	_help = HelpPanel.new()
	_help.visible = false
	_help.close_requested.connect(_close_help)
	_help.navigated.connect(func(): _help_stack = _help.stack.duplicate())
	var scroll := _scrolling_editor()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_scroll = scroll
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
	var holder := UIKit.vbox(0)
	holder.add_child(_editor)
	if _help:
		holder.add_child(_help)
	pad.add_child(holder)
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
	if HealthEventPanel.handles(e):   # injury diagnosis and the "sore" warning have their own panels (with a "?")
		box = HealthEventPanel.build(e, width, func(choice: String): _on_event_answer(e.id, choice),
				func(): HelpOverlay.open(self, HealthEventPanel.HELP))
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
	_raise_overlays()
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
	# PC with the side panel open: pages with wide rows (Training) build their stacked, phone-like layout.
	Layout.side_open = not Layout.compact and _side_is_open()
	_built_side_open = Layout.side_open
	_scroll.scroll_vertical = 0
	for child in _content.get_children():
		child.queue_free()
	match view:
		"overview": _build_profile(Game.athlete)
		"training": _build_training()
		"calendar": _build_calendar()
		"rankings": _build_rankings()
		"report": _content.add_child(ReportView.new())
	# The header "?" belongs to what is shown now; help opened with it follows to the new tab / page.
	var help_id := _help_entry()
	_help_button.entry_id = help_id
	if _help_follows_view and not _help_stack.is_empty() and _help_stack[0] != help_id:
		_help_stack = [help_id]
		_apply_help()


# --- Help (GDD 5 "Help") ------------------------------------------------------------------------

## The help entry of what the hub shows: the tab, and in the Training tab which of its three pages.
func _help_entry() -> String:
	if _view == "training":
		if Game.season.mode != SeasonPlan.PHASES:
			return "training_repeat"
		return "phase_editor" if _phase_open != "" else "training_season"
	return _view


## The header "?" and F1: opens the help of what is shown, or closes it when that is already open.
func _toggle_help() -> void:
	if not _help_stack.is_empty() and _help_stack[0] == _help_entry():
		_close_help()
	else:
		_open_help(_help_entry(), true)


func _open_help(id: String, follows_view: bool) -> void:
	_help_follows_view = follows_view
	_help_stack = [id]
	_apply_help()
	if _side_scroll:
		_side_scroll.scroll_vertical = 0


func _close_help() -> void:
	_help_stack = []
	_apply_help()


## Shows `_help_stack` where it belongs in this layout: PC = the side slot (over the day editor), phone = a sheet.
func _apply_help() -> void:
	var open := not _help_stack.is_empty()
	if _help != null:   # PC
		if is_instance_valid(_help_overlay):   # (it was opened on a phone before the window was widened)
			_help_overlay.remove()
		_help_overlay = null
		if open and _help.stack != _help_stack:
			_help.show_stack(_help_stack)
	elif open:
		if not is_instance_valid(_help_overlay) or _help_overlay.is_queued_for_deletion():
			_help_overlay = HelpOverlay.new()
			_help_overlay.closed.connect(func():
				_help_stack = []
				_help_overlay = null)
			_help_overlay.panel.navigated.connect(func(): _help_stack = _help_overlay.panel.stack.duplicate())
			_help_overlay.panel.show_stack(_help_stack)
			add_child(_help_overlay)
		elif _help_overlay.panel.stack != _help_stack:
			_help_overlay.panel.show_stack(_help_stack)
	elif is_instance_valid(_help_overlay):
		_help_overlay.remove()
		_help_overlay = null
	_apply_editor_visibility()
	_raise_overlays()


## The stop-event layer above the page, and any help above that.
func _raise_overlays() -> void:
	if _event_overlay:
		move_child(_event_overlay, -1)
	for c in get_children():
		if c is HelpOverlay:
			move_child(c, -1)


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

	# The long explanations (week strip markers, attributes, saving) are in the help (data/help.json, "overview").
	_content.add_child(UIKit.wrapped("Plan your week under Training, tap a day in the week strip to change it, then press "
			+ "Next day or Play week. The ? at the top explains what you see on each screen.", "MutedLabel"))


# --- Training plan ----------------------------------------------------------------------

## The Training tab: the switch Season plan / One repeating week (GDD 4.8 UI), then the season (SeasonView, or the
## PhaseEditor of the phase that was tapped) or the repeating week's editor.
func _build_training() -> void:
	if Game.season.mode != SeasonPlan.PHASES:
		_phase_open = ""
	if _phase_open == "":   # the phase editor is a page of its own, with "◀ Season plan" instead
		_content.add_child(_mode_switch())
	if Game.season.mode != SeasonPlan.PHASES:
		_build_training_repeat()
		return
	if _phase_open != "":
		var editor := PhaseEditor.new(SeasonUI.current_year(), _phase_open)
		editor.back_pressed.connect(func():
			_phase_open = ""
			_show("training"))
		editor.plan_changed.connect(_after_plan_change)
		editor.rebuild.connect(func():
			_after_plan_change()
			_rebuild_view())
		_content.add_child(editor)
		return
	var view := SeasonView.new()
	view.phase_opened.connect(func(id: String):
		_phase_open = id
		_show("training"))
	view.plan_changed.connect(func():
		_after_plan_change()
		_rebuild_view())
	_content.add_child(view)


## Season plan / One repeating week. Both ways keep the other side: the season's changes stay while the repeating
## week is used, and the repeating week starts as this phase's week.
func _mode_switch() -> Control:
	var phases := Game.season.mode == SeasonPlan.PHASES
	var box := UIKit.vbox(6)
	var row := UIKit.hbox(6)
	var group := ButtonGroup.new()
	var season := UIKit.toggle("Season plan", group)
	var repeat := UIKit.toggle("Repeating week" if Layout.compact else "One repeating week", group)
	for b in [season, repeat]:
		b.custom_minimum_size.x = 0 if Layout.compact else 220
		if Layout.compact:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	season.button_pressed = phases
	repeat.button_pressed = not phases
	season.pressed.connect(func():
		if Game.season.mode != SeasonPlan.PHASES:
			Game.use_season_plan()
			_after_plan_change()
			_show("training"))
	repeat.pressed.connect(func():
		if Game.season.mode == SeasonPlan.PHASES:
			Game.season.switch_to_repeat(Game.week_monday())   # this phase's week repeats from now on
			_phase_open = ""
			_after_plan_change()
			_show("training"))
	box.add_child(row)
	box.add_child(UIKit.wrapped(
			"Or plan one week yourself that repeats every week (it starts as this phase's week; your season plan is kept)."
			if phases else
			"Or follow your coach's season plan: a year in phases, built up to your target meets (your earlier changes to it are kept)."))
	return box


## After the plan changed: the injury limits go into this week again, and the strip, its caption and the open day
## follow the plan.
func _after_plan_change() -> void:
	HealthUI.refresh()
	_refresh_week_ui()


## Rebuilds the current tab and keeps the scroll position (for edits inside a long page).
func _rebuild_view() -> void:
	var at := _scroll.scroll_vertical
	_show(_view)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = at


func _build_training_repeat() -> void:
	var a := Game.athlete
	var month: int = Game.add_days(Game.week_monday(), 3).month
	var plan: Dictionary = Game.season.repeat_week   # {days, intensity}: edited in place (see WeekPlan)
	_content.add_child(UIKit.label("Weekly plan", "HeadingLabel"))
	_content.add_child(UIKit.wrapped(
			("Your plan repeats every week until you change it. Up to %d sessions a day; an empty day is a rest day. "
			% Training.MAX_SESSIONS_PER_DAY)
			+ "Easy, Normal or Hard sets how hard you do the day's sessions. "
			+ "To change just one day of this week, tap it in the week strip above."))
	var level_notes := []
	for level in Training.INTENSITIES:
		if level != WeekSim.NORMAL:
			var m := Training.intensity(level)
			level_notes.append("%s: tiring ×%s, training effect ×%s" % [m.name, String.num(float(m.load), 2),
					String.num(float(m.effect), 2)])
	_content.add_child(UIKit.wrapped(" · ".join(level_notes) + ". Normal is the sessions as planned."))

	var summary := UIKit.vbox(8)
	var refresh_summary := func(): _fill_plan_summary(summary, a)
	# After every edit of the weekly plan: the injury limits go into this week again, the week strip and the
	# open day follow the plan, and the summary (with load vs normal and risk) is worked out again.
	var on_plan_edited := func():
		_after_plan_change()
		refresh_summary.call()

	var days := UIKit.vbox(14 if Layout.stacked() else 8)
	for day in 7:
		if day > 0 and Layout.stacked():
			days.add_child(HSeparator.new())
		var date := Game.add_days(Game.week_monday(), day)
		days.add_child(PlanUI.day_row(plan, day, a, month, on_plan_edited, "%s %d.%d." % [Training.DAY_NAMES[day], date.day, date.month]))
	_content.add_child(UIKit.panel(days, 16))

	var buttons := UIKit.hbox(8)
	var coach := UIKit.button("Coach's plan", false, 160)
	coach.pressed.connect(func():
		Game.season.repeat_week = WeekPlan.coach()   # every day Normal
		_after_plan_change()
		_show("training"))
	var clear := UIKit.button("Clear week", false, 160)
	clear.pressed.connect(func():
		Game.season.repeat_week = WeekPlan.empty()
		_after_plan_change()
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


## The repeating week's summary (this week's plan, with load vs normal and risk).
func _fill_plan_summary(box: VBoxContainer, a: Athlete) -> void:
	var plan := Game.season.week_for(Game.week_monday())
	PlanUI.fill_summary(box, a, plan, Game.week_monday(), HealthUI.plan_section(plan, Game.current_week()))


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
	# More (qualifying times, targets, estimated dates) in the help (data/help.json, "calendar").
	_content.add_child(UIKit.wrapped(
			"Enter the meets you want to race; a race replaces that day's training. ★ = your coach recommends it."
			+ (" %s = one of your target meets." % SeasonUI.TARGET_MARK if Game.season.mode == SeasonPlan.PHASES else "")))

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

	# Enter / Entered ✓, and in season-plan mode the Target toggle (GDD 4.8): marking a target enters the meet
	# when allowed; withdrawing takes the target off too. Both buttons follow each other.
	var season := Game.season
	var year := SeasonPlan.year_of(m.date)
	var targetable: bool = season.mode == SeasonPlan.PHASES and year >= season.first_season and season.can_target(m) \
			and Calendar.date_key(m.date) >= Calendar.date_key(Game.date)
	if not check.ok and not targetable:
		return row
	var buttons: BoxContainer = UIKit.hbox(8) if Layout.compact else UIKit.vbox(6)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# (Lambdas capture the variables' values when they are made, so the buttons exist before the closures.)
	var b: Button = UIKit.button("", false, 150) if check.ok else null
	var t: Button = UIKit.button("", false, 150) if targetable else null
	var note := UIKit.wrapped("", "MutedLabel")
	note.visible = false
	var refresh := func():
		var entered: bool = m.key in Game.entries
		if b:
			b.text = "Entered ✓" if entered else "Enter"
			b.theme_type_variation = "PrimaryButton" if entered else ""
		if t:
			var is_target: bool = m.key in season.targets(year)
			t.text = "Target %s" % SeasonUI.TARGET_MARK if is_target else "Make target"
			t.theme_type_variation = "PrimaryButton" if is_target else ""
	var after := func():
		Game.current_week()   # this week's race days follow the entries
		HealthUI.refresh()    # a race day that was withdrawn is a training day again: injury limits apply to it
		_refresh_week_ui()
		refresh.call()
	if b:
		b.pressed.connect(func():
			if m.key in Game.entries:
				Game.withdraw(m.key)
			else:
				Game.enter(m.key)
			after.call())
		buttons.add_child(b)
	if t:
		t.pressed.connect(func():
			note.visible = false
			if m.key in season.targets(year):
				season.remove_target(year, m.key)
			elif season.add_target(year, m.key):
				if Calendar.can_enter(a, m, Game.date).ok:
					Game.enter(m.key)
			else:
				note.text = "You have %d targets this season, the most. Remove one first (Training tab)." % int(Data.periodization.season.max_targets)
				note.visible = true
			after.call())
		buttons.add_child(t)
	if Layout.compact:
		for x in buttons.get_children():
			x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(note)
	refresh.call()
	row.add_child(buttons)
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
