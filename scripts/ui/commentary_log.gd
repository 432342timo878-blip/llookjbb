class_name CommentaryLog
extends Control
## The full commentary log of a watched race (GDD 4.3.1, step R4), opened by tapping the phone's ticker: a dimmed layer
## (tap it to close) with the log in a bottom sheet, newest line on top, and a Close button (at least 44 px). The race waits
## while it is open (the race screen checks is_instance_valid), like the help. Esc closes it.

signal closed

var _scroll: ScrollContainer


## Opens the log of `lines` (as said, oldest first) over `host`.
static func open(host: Control, lines: Array) -> CommentaryLog:
	for c in host.get_children():
		if c is CommentaryLog and not c.is_queued_for_deletion():
			return c
	var o := CommentaryLog.new(lines)
	host.add_child(o)
	return o


func _init(lines: Array) -> void:
	name = "CommentaryLog"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(dim)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.SURFACE, 0.98)
	style.border_color = Palette.BORDER
	box.add_child(_content(lines))
	add_child(box)
	if Layout.compact:
		box.anchor_left = 0.0
		box.anchor_right = 1.0
		box.anchor_top = 0.28
		box.anchor_bottom = 1.0
		style.border_width_top = 1
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
	else:
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.anchor_top = 0.0
		box.anchor_bottom = 1.0
		box.offset_left = -476.0
		box.offset_right = -16.0
		box.offset_top = 16.0
		box.offset_bottom = -16.0
		style.set_border_width_all(1)
		style.set_corner_radius_all(Palette.RADIUS * 2)
	box.add_theme_stylebox_override("panel", style)


func _content(lines: Array) -> Control:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var column := UIKit.vbox(8)
	margin.add_child(column)
	var head := UIKit.hbox(8)
	var title := UIKit.label("COMMENTARY LOG", "CaptionLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var close_button := UIKit.button("Close", false, 100)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	column.add_child(head)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := UIKit.vbox(8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if lines.is_empty():
		rows.add_child(UIKit.wrapped("Nothing has been said yet."))
	for i in range(lines.size() - 1, -1, -1):
		rows.add_child(CommentaryBox.make_row(lines[i]))
	_scroll.add_child(rows)
	column.add_child(_scroll)
	return margin


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
