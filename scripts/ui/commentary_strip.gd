class_name CommentaryStrip
extends PanelContainer
## The subtitle strip under the track on PC (GDD 4.3.1, step R4; the user's playtest 2026-10-10: "I can't follow the
## commentary on the right and the running"): the newest line in bigger text, wrapping to two rows, and the one before it
## small and dimmed under it, as wide as the track, so the eyes need not leave the race. The coach's lines are in the
## accent colour with "Coach: " in front. The full box with older lines stays in the right column (CommentaryBox).

const HEIGHT := 78.0

var _now: Label
var _before: Label


func _init() -> void:
	name = "CommentaryStrip"
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE_2
	style.border_color = Palette.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(Palette.RADIUS)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	var column := UIKit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_now = Label.new()
	_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_now.max_lines_visible = 2
	_now.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_now.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_now.add_theme_font_size_override("font_size", 18)
	_now.text = "The commentary appears here."
	_now.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	_before = Label.new()
	_before.clip_text = true
	_before.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_before.add_theme_font_size_override("font_size", 13)
	_before.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	column.add_child(_now)
	column.add_child(_before)
	add_child(column)


func show_line(line: Dictionary) -> void:
	_before.text = _now.text if _now.text != "The commentary appears here." else ""
	_before.add_theme_color_override("font_color", _now.get_theme_color("font_color"))
	_before.modulate.a = 0.55
	var voice := str(line.voice)
	var text := str(line.text)
	if voice == "coach":
		text = "Coach: " + text
	elif voice == "expert":
		text = "Expert: " + text
	_now.text = text
	_now.add_theme_color_override("font_color", Palette.ACCENT if voice == "coach" else Palette.TEXT)
