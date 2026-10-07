class_name HelpOverlay
extends Control
## A HelpPanel over a whole screen (GDD 5 "Help"): a dimmed layer (tap it to close) with the help in a bottom sheet on
## a phone (fitted to its content, at most 72 % of the screen, like the day editor's sheet) or in a panel over the
## right side on PC. Used where there is no side slot: the race screen, the new-career wizard, the health stop panels,
## and the career hub on a phone. It rebuilds itself on Router.layout_changed and keeps the open entry. Esc closes it.

signal closed   # the player closed it (Close, the dim layer, Esc)

const PC_WIDTH := 460.0

var panel: HelpPanel
var _frame: Control
var _scroll: ScrollContainer


## Opens the help `id` over `host` (a screen); an overlay already open there shows the new entry instead.
static func open(host: Control, id: String) -> HelpOverlay:
	for c in host.get_children():
		if c is HelpOverlay and not c.is_queued_for_deletion():
			(c as HelpOverlay).panel.show_entry(id)
			host.move_child(c, -1)
			return c
	var o := HelpOverlay.new()
	o.panel.show_entry(id)
	host.add_child(o)
	return o


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = HelpPanel.new()
	panel.close_requested.connect(close)
	panel.rebuilt.connect(_fit)


func _ready() -> void:
	Router.layout_changed.connect(func(_c):
		if not is_queued_for_deletion():
			_build_frame())
	_build_frame()


## The player closed it.
func close() -> void:
	closed.emit()
	remove()


## Closes it without the `closed` signal (the host moves the help somewhere else).
func remove() -> void:
	if panel.get_parent():
		panel.get_parent().remove_child(panel)
	panel.queue_free()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_F1]:
		close()
		get_viewport().set_input_as_handled()


func _build_frame() -> void:
	if panel.get_parent():
		panel.get_parent().remove_child(panel)
	if _frame:
		_frame.queue_free()
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close())
	_frame.add_child(dim)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.SURFACE, 0.98)
	style.border_color = Palette.BORDER
	_frame.add_child(box)
	var margin := MarginContainer.new()
	box.add_child(margin)
	var column := UIKit.vbox(8)
	margin.add_child(column)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 12)   # room for the scroll bar
	pad.add_child(panel)
	_scroll.add_child(pad)

	if Layout.compact:
		# Bottom sheet: full width, rounded top, a handle; height fitted in _fit.
		box.anchor_left = 0.0
		box.anchor_right = 1.0
		box.anchor_top = 1.0
		box.anchor_bottom = 1.0
		box.grow_vertical = Control.GROW_DIRECTION_BEGIN
		style.border_width_top = 1
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		for side in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + side, 16)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 14)
		var handle := UIKit.dot(Palette.BORDER, 44, 5)
		handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(handle)
	else:
		# PC: a panel over the right side of the screen, full height.
		var width := minf(PC_WIDTH, Layout.logical_width - 32.0)
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.anchor_top = 0.0
		box.anchor_bottom = 1.0
		box.offset_left = -width - 16.0
		box.offset_right = -16.0
		box.offset_top = 16.0
		box.offset_bottom = -16.0
		style.set_border_width_all(1)
		style.set_corner_radius_all(Palette.RADIUS * 2)
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 16)
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", style)
	column.add_child(_scroll)
	_fit()


## Phone: the sheet's height follows its content, at most 72 % of the screen (longer help scrolls).
func _fit() -> void:
	if not Layout.compact or _scroll == null or not is_inside_tree():
		return
	var scroll := _scroll
	await get_tree().process_frame   # the texts need to be laid out before their height is known
	await get_tree().process_frame
	if scroll != _scroll or not is_instance_valid(scroll):
		return
	scroll.custom_minimum_size.y = minf(panel.get_combined_minimum_size().y, size.y * 0.72)
