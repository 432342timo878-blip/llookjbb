class_name ChatMark
extends Control
## The small people mark of the week strip (GDD 4.9.5 "Where", session C3): a speech bubble, filled in the accent colour while
## a message of that day is still unread, an outline once everything was read. Drawn, not a font symbol.

var unread := true


func _init(has_unread := true) -> void:
	unread = has_unread
	custom_minimum_size = Vector2(17, 16)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var color := Palette.ACCENT if unread else Palette.TEXT_MUTED
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	if unread:
		box.bg_color = color
	else:
		box.draw_center = false
		box.border_color = color
		box.set_border_width_all(2)
	draw_style_box(box, Rect2(0, 0, 17, 12))
	draw_colored_polygon(PackedVector2Array([Vector2(3, 10), Vector2(3, 16), Vector2(9, 10)]), color)
