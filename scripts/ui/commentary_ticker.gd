class_name CommentaryTicker
extends PanelContainer
## The phone's commentary ticker (GDD 4.3.1, step R4): the newest line in two lines of text, under the track; the coach's
## in the accent colour with "Coach: " in front. Tapping it (the whole strip, at least 44 px) opens the full log
## (CommentaryLog); the race waits while the log is open.

signal tapped

var _label: Label


func _init() -> void:
	name = "CommentaryTicker"
	custom_minimum_size.y = 52.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE_2
	style.border_color = Palette.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(Palette.RADIUS)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.max_lines_visible = 2
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "Commentary · tap for the log"
	_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	add_child(_label)


func show_line(line: Dictionary) -> void:
	var voice := str(line.voice)
	var text := str(line.text)
	if voice == "coach":
		text = "Coach: " + text
	elif voice == "expert":
		text = "Expert: " + text
	_label.text = text
	_label.add_theme_color_override("font_color", Palette.ACCENT if voice == "coach" else Palette.TEXT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		tapped.emit()
		accept_event()
