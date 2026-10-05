@tool
extends Control
## Decorative top-down drawing of an athletics stadium: stands with crowd,
## 400m track, and the field event areas in the infield.
## Geometry is in metres (real track dimensions) and scaled to fit the control.

@export var lanes := 8
@export var crowd_seed := 2026

const STRAIGHT := 84.39   # length of each straight
const R_IN := 36.5        # radius of the inner kerb
const LANE := 1.22        # lane width
const APRON := 4.0        # run-off area outside the last lane
const CONCOURSE := 3.0
const STAND_DEPTH := 20.0
const SEAT_PITCH := 0.9   # spacing between seats in the crowd

const CROWD_COLORS := [
	Color("#e8eaf0"), Color("#d0d4de"), Color("#2f5fb3"), Color("#1f3f80"),
	Color("#ff5a36"), Color("#f2c14e"), Color("#4a5163"), Color("#6b7285"),
	Color("#8b2f3c"), Color("#3a8f6a"),
]

var _k := 1.0             # pixels per metre
var _center := Vector2.ZERO


func _draw() -> void:
	var r_out := R_IN + LANE * lanes
	var r_stand_in := r_out + APRON + CONCOURSE
	var r_stand_out := r_stand_in + STAND_DEPTH
	var extent := Vector2(STRAIGHT + 2.0 * (r_stand_out + 6.0), 2.0 * (r_stand_out + 6.0))
	_k = minf(size.x / extent.x, size.y / extent.y)
	_center = size / 2.0

	_draw_floodlights(r_stand_out, false)
	_fill_stadium(r_stand_out, Palette.STAND)
	_draw_crowd(r_stand_in + 0.8, r_stand_out - 0.6)
	_draw_main_stand_roof(r_stand_in, r_stand_out)
	_fill_stadium(r_stand_in, Palette.CONCOURSE)
	_fill_stadium(r_out + APRON, Palette.TRACK_APRON)
	_fill_stadium(r_out, Palette.TRACK)
	_draw_infield()
	_draw_lane_lines(r_out)
	_draw_finish_area(r_out)
	_draw_field_events()
	_draw_scoreboard(r_stand_in, r_stand_out)
	_draw_floodlights(r_stand_out, true)


# --- Stadium shell -----------------------------------------------------------

func _draw_crowd(r_from: float, r_to: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = crowd_seed
	var dot := maxf(SEAT_PITCH * 0.7 * _k, 1.0)
	var r := r_from
	while r < r_to:
		var length := _stadium_length(r)
		var s := 0.0
		while s < length:
			var p := _px(_stadium_point(r, s))
			var color: Color
			if rng.randf() < 0.18:
				color = Palette.STAND.lightened(0.08)   # empty seat
			else:
				color = CROWD_COLORS[rng.randi() % CROWD_COLORS.size()].darkened(0.2 + rng.randf() * 0.35)
			draw_rect(Rect2(p - Vector2.ONE * dot / 2.0, Vector2.ONE * dot), color)
			s += SEAT_PITCH
		r += SEAT_PITCH * 1.15


func _draw_main_stand_roof(r_stand_in: float, r_stand_out: float) -> void:
	# Covered main stand along the home straight (bottom of the drawing).
	var front := r_stand_in + STAND_DEPTH * 0.45
	var rect := Rect2(-STRAIGHT / 2.0 + 2.0, front, STRAIGHT - 4.0, r_stand_out - front - 1.0)
	draw_rect(_px_rect(rect), Color(Palette.ROOF, 0.94))
	var edge_l := _px(Vector2(rect.position.x, front))
	var edge_r := _px(Vector2(rect.end.x, front))
	draw_line(edge_l, edge_r, Palette.ROOF.lightened(0.35), maxf(0.6 * _k, 1.0))
	# Roof girders.
	var x := rect.position.x + 6.0
	while x < rect.end.x:
		draw_line(_px(Vector2(x, front)), _px(Vector2(x, rect.end.y)), Palette.ROOF.lightened(0.12), 1.0)
		x += 8.0


func _draw_scoreboard(r_stand_in: float, r_stand_out: float) -> void:
	# Video board on top of the far-end stand (left).
	var x := -STRAIGHT / 2.0 - r_stand_in - STAND_DEPTH * 0.5
	var rect := Rect2(x - 1.5, -12.0, 3.0, 24.0)
	draw_rect(_px_rect(rect.grow(0.6)), Color("#0b0d12"))
	draw_rect(_px_rect(rect), Color("#141b2a"))
	draw_rect(_px_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 3.0)), Palette.ACCENT)


func _draw_floodlights(r_stand_out: float, heads: bool) -> void:
	var offset := Vector2(STRAIGHT / 2.0 + r_stand_out * 0.72, r_stand_out * 0.72)
	for sign in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p := _px(offset * sign)
		if heads:
			draw_rect(Rect2(p - Vector2(4, 4) * _k, Vector2(8, 8) * _k), Color("#3a404e"))
			draw_rect(Rect2(p - Vector2(3, 3) * _k, Vector2(6, 6) * _k), Palette.FLOODLIGHT)
		else:
			# Soft glow under the lights.
			for i in range(5):
				draw_circle(p, (16.0 - i * 3.0) * _k, Color(Palette.FLOODLIGHT, 0.03))


# --- Track ---------------------------------------------------------------------

func _draw_infield() -> void:
	_fill_stadium(R_IN, Palette.GRASS_DARK)
	# Mowing stripes across the rectangular part of the infield.
	var stripe := 6.0
	var x := -STRAIGHT / 2.0
	var i := 0
	while x < STRAIGHT / 2.0:
		if i % 2 == 0:
			var w := minf(stripe, STRAIGHT / 2.0 - x)
			draw_rect(_px_rect(Rect2(x, -R_IN, w, R_IN * 2.0)), Palette.GRASS_LIGHT)
		x += stripe
		i += 1


func _draw_lane_lines(r_out: float) -> void:
	var w := maxf(0.08 * _k, 1.0)
	for i in range(lanes + 1):
		_stroke_stadium(R_IN + LANE * i, Palette.LINE, w)
	# Raised inner kerb.
	_stroke_stadium(R_IN - 0.1, Color.WHITE, maxf(0.25 * _k, 1.5))


func _draw_finish_area(r_out: float) -> void:
	var finish_x := STRAIGHT / 2.0
	var w := maxf(0.12 * _k, 1.5)
	draw_line(_px(Vector2(finish_x, R_IN)), _px(Vector2(finish_x, r_out)), Color.WHITE, w)
	# Start line of the 100m / 110mH at the far end of the home straight.
	var start_x := -STRAIGHT / 2.0 + 0.5
	draw_line(_px(Vector2(start_x, R_IN)), _px(Vector2(start_x, r_out)), Palette.LINE, w)

	# Lane numbers just before the finish line.
	var font := get_theme_default_font()
	var font_size := int(LANE * 0.75 * _k)
	if font_size < 7:
		return
	for lane in range(lanes):
		var center := _px(Vector2(finish_x - 3.0, R_IN + LANE * (lane + 0.5)))
		var label := str(lane + 1)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x / 2.0, text_size.y * 0.3), label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.8))

	# Hurdle marks for the 110m hurdles: 13.72m to first, then every 9.14m.
	for h in range(10):
		var hx := start_x + 13.72 + 9.14 * h
		for lane in range(lanes):
			var y := R_IN + LANE * lane
			draw_line(_px(Vector2(hx, y + 0.15)), _px(Vector2(hx, y + 0.35)), Color(1, 1, 1, 0.45), 1.0)


# --- Field events --------------------------------------------------------------

func _draw_field_events() -> void:
	# Standard layout: the two "D" areas at the ends of the infield hold the jumps and
	# throws circles, and all throws land along the long axis of the grass.
	var line_w := maxf(0.1 * _k, 1.0)
	var left_d := Vector2(-STRAIGHT / 2.0, 0.0)
	var right_d := Vector2(STRAIGHT / 2.0, 0.0)

	# Left D: synthetic high jump fan, with the javelin runway crossing it along the axis.
	_fill_d(left_d, -1.0, R_IN - 1.0, Palette.TRACK.darkened(0.06))
	var hj_bar := left_d + Vector2(-10.0, -15.0)
	draw_rect(_px_rect(Rect2(hj_bar.x - 3.0, hj_bar.y - 3.0, 6.0, 3.0)), Palette.MAT)
	draw_line(_px(hj_bar + Vector2(-2.0, 0.2)), _px(hj_bar + Vector2(2.0, 0.2)), Color.WHITE, line_w)

	# Javelin: 4m-wide runway ending in an 8m-radius arc at the edge of the grass.
	var jav_arc_center := left_d + Vector2(-8.0, 0.0)
	draw_rect(_px_rect(Rect2(left_d.x - 33.0, -2.0, 33.0, 4.0)), Palette.TRACK.lightened(0.05))
	var arc_half := asin(2.0 / 8.0)
	draw_arc(_px(jav_arc_center), 8.0 * _k, -arc_half, arc_half, 12, Color.WHITE, maxf(0.15 * _k, 1.5), true)
	_draw_throwing_sector(jav_arc_center, 0.0, 28.96, 84.0)

	# Right D: discus/hammer cage throwing along the axis into the infield.
	_fill_d(right_d, 1.0, R_IN - 1.0, Palette.GRASS_DARK.darkened(0.12))
	var cage := right_d + Vector2(10.0, 0.0)
	draw_rect(_px_rect(Rect2(cage.x - 3.0, cage.y - 3.0, 6.0, 6.0)), Color("#3a404e"))
	draw_circle(_px(cage), 1.25 * _k, Color("#9aa1b2"))
	draw_arc(_px(cage), 3.6 * _k, PI + deg_to_rad(40.0), PI * 3.0 - deg_to_rad(40.0), 32,
			Color(1, 1, 1, 0.7), maxf(0.3 * _k, 1.5), true)
	_draw_throwing_sector(cage, PI, 34.92, 80.0)

	# Shot put circle in the right D, its sector landing on the D apron.
	var shot := right_d + Vector2(22.0, -20.0)
	draw_rect(_px_rect(Rect2(shot.x - 2.0, shot.y - 2.0, 4.0, 4.0)), Color("#3a404e"))
	_draw_throwing_sector(shot, deg_to_rad(110.0), 34.92, 20.0)
	draw_circle(_px(shot), 1.07 * _k, Color("#9aa1b2"))

	# Long & triple jump runway along the back straight, sand pit at the end.
	var runway_y := -R_IN + 3.5
	draw_rect(_px_rect(Rect2(-36.0, runway_y - 0.61, 64.0, 1.22)), Palette.TRACK)
	draw_rect(_px_rect(Rect2(28.0, runway_y - 1.5, 9.0, 3.0)), Palette.SAND)
	draw_line(_px(Vector2(25.0, runway_y - 0.61)), _px(Vector2(25.0, runway_y + 0.61)), Color.WHITE, line_w)

	# Pole vault runway along the home straight, landing mat at the end.
	var pv_y := R_IN - 3.5
	draw_rect(_px_rect(Rect2(-30.0, pv_y - 0.61, 45.0, 1.22)), Palette.TRACK)
	draw_rect(_px_rect(Rect2(15.0, pv_y - 3.0, 6.0, 6.0)), Palette.MAT)


## Fills the half-disc ("D") at one end of the infield. `side` is -1 for left, 1 for right.
func _fill_d(center: Vector2, side: float, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	var start := -PI / 2.0 if side > 0.0 else PI / 2.0
	for i in range(31):
		points.append(_px(center + Vector2.from_angle(start + PI * i / 30.0) * radius))
	draw_colored_polygon(points, color)


func _draw_throwing_sector(origin: Vector2, direction: float, angle_deg: float, length: float) -> void:
	var half := deg_to_rad(angle_deg / 2.0)
	var color := Color(1, 1, 1, 0.3)
	for side in [-half, half]:
		var end := origin + Vector2.from_angle(direction + side) * length
		draw_line(_px(origin), _px(end), color, 1.0, true)
	# Distance arcs every 10m.
	var d := 10.0
	while d <= length:
		draw_arc(_px(origin), d * _k, direction - half, direction + half, 16, Color(1, 1, 1, 0.14), 1.0, true)
		d += 10.0


# --- Geometry helpers ------------------------------------------------------------

func _px(m: Vector2) -> Vector2:
	return _center + m * _k


func _px_rect(r: Rect2) -> Rect2:
	return Rect2(_px(r.position), r.size * _k)


func _fill_stadium(r: float, color: Color) -> void:
	var a := _px(Vector2(-STRAIGHT / 2.0, 0.0))
	var b := _px(Vector2(STRAIGHT / 2.0, 0.0))
	draw_circle(a, r * _k, color)
	draw_circle(b, r * _k, color)
	draw_rect(Rect2(a.x, a.y - r * _k, b.x - a.x, r * 2.0 * _k), color)


func _stroke_stadium(r: float, color: Color, width: float) -> void:
	var a := _px(Vector2(-STRAIGHT / 2.0, 0.0))
	var b := _px(Vector2(STRAIGHT / 2.0, 0.0))
	var rp := r * _k
	draw_arc(a, rp, PI / 2.0, PI * 1.5, 64, color, width, true)
	draw_arc(b, rp, -PI / 2.0, PI / 2.0, 64, color, width, true)
	draw_line(Vector2(a.x, a.y - rp), Vector2(b.x, b.y - rp), color, width, true)
	draw_line(Vector2(a.x, a.y + rp), Vector2(b.x, b.y + rp), color, width, true)


func _stadium_length(r: float) -> float:
	return 2.0 * STRAIGHT + TAU * r


## Point at distance `s` along a stadium-shaped path of radius `r`,
## starting at the left end of the bottom straight and running anticlockwise on screen.
func _stadium_point(r: float, s: float) -> Vector2:
	var half := STRAIGHT / 2.0
	var arc := PI * r
	if s < STRAIGHT:
		return Vector2(-half + s, r)
	s -= STRAIGHT
	if s < arc:
		return Vector2(half, 0.0) + Vector2.from_angle(PI / 2.0 - s / r) * r
	s -= arc
	if s < STRAIGHT:
		return Vector2(half - s, -r)
	s -= STRAIGHT
	return Vector2(-half, 0.0) + Vector2.from_angle(-PI / 2.0 - s / r) * r


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
