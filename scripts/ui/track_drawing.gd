@tool
extends Control
## Decorative top-down drawing of a 400m track (infield, lanes, finish line).

@export var lanes := 8


func _draw() -> void:
	# A standard track is ~176m x 92m; fit that ratio inside this control.
	var ratio := 176.0 / 92.0
	var w := minf(size.x, size.y * ratio) * 0.92
	var h := w / ratio
	var origin := (size - Vector2(w, h)) / 2.0
	var lane_w := h * 0.035

	var outer_r := h / 2.0
	var inner_r := outer_r - lane_w * lanes
	var c_left := origin + Vector2(outer_r, outer_r)
	var c_right := origin + Vector2(w - outer_r, outer_r)

	_stadium(c_left, c_right, outer_r, Palette.TRACK)
	_stadium(c_left, c_right, inner_r, Palette.INFIELD)

	var line := Color(1, 1, 1, 0.35)
	for i in range(lanes + 1):
		_stadium_outline(c_left, c_right, inner_r + lane_w * i, line)

	# Finish line on the home straight.
	var x := c_right.x - outer_r * 0.15
	draw_line(Vector2(x, c_right.y + inner_r), Vector2(x, c_right.y + outer_r), Color.WHITE, 3.0)


func _stadium(a: Vector2, b: Vector2, r: float, color: Color) -> void:
	draw_circle(a, r, color)
	draw_circle(b, r, color)
	draw_rect(Rect2(a.x, a.y - r, b.x - a.x, r * 2.0), color)


func _stadium_outline(a: Vector2, b: Vector2, r: float, color: Color) -> void:
	draw_arc(a, r, PI / 2.0, PI * 1.5, 48, color, 1.0, true)
	draw_arc(b, r, -PI / 2.0, PI / 2.0, 48, color, 1.0, true)
	draw_line(Vector2(a.x, a.y - r), Vector2(b.x, b.y - r), color, 1.0, true)
	draw_line(Vector2(a.x, a.y + r), Vector2(b.x, b.y + r), color, 1.0, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
