extends Control
## Runners as dots on the track. Outdoors it sits over the stadium drawing (track_drawing.gd, same size and
## scale) so the busy stadium isn't redrawn every frame. Indoors the 200 m hall track is drawn by a second
## instance of this script with `track_only` (drawn once, not every frame); the instance with the dots draws
## only the dots (`indoor_floor_below`).

const TD := preload("res://scripts/ui/track_drawing.gd")
const INDOOR_MARGIN := 7.0       # metres of hall floor around the indoor track

var race: Race
## Indoors: draw only the (static) hall track, no runners. Never redrawn after the first time.
var track_only := false
## Indoors: the hall track is a separate view underneath, so this one draws just the runners.
var indoor_floor_below := false
## Draw the coach's spot (the race screen of a watched race).
var show_coach := false
## How far the clock is into the next engine step (0–1): dots are drawn that far from where they were before
## the last step towards where they are now, so they move smoothly even at 1x (10 engine steps a second).
var blend := 1.0

var _k := 1.0
var _center := Vector2.ZERO


func _draw() -> void:
	if race == null:
		return
	if race.indoor:
		var r_out := race.r_in + Race.LANE_W * race.lanes
		var extent := Vector2(race.straight + 2.0 * (r_out + INDOOR_MARGIN), 2.0 * (r_out + INDOOR_MARGIN))
		_k = minf(size.x / extent.x, size.y / extent.y)
		_center = size / 2.0
		if not indoor_floor_below:
			_draw_indoor_track(r_out)
	else:
		# Same scale as TrackDrawing._draw().
		var r_out: float = TD.R_IN + TD.LANE * 8
		var r_stand_out: float = r_out + TD.APRON + TD.CONCOURSE + TD.STAND_DEPTH
		var extent := Vector2(TD.STRAIGHT + 2.0 * (r_stand_out + 6.0), 2.0 * (r_stand_out + 6.0))
		_k = minf(size.x / extent.x, size.y / extent.y)
		_center = size / 2.0
	if not track_only:
		_draw_runners()
		if show_coach:
			_draw_coach()


## The coach by the track (GDD 4.3.1 step R4): a small diamond where he stands, outdoors at the 200 m start on the infield
## side of lane 1 (he sees the stretch round it, Race.coach_sees_at), indoors in the middle of the infield (he sees all).
func _draw_coach() -> void:
	var spot := Vector2.ZERO
	if not race.indoor:
		var radius := race.r_in - 3.0
		spot = _stadium_point(radius, _path_s(fmod(float(Data.races.controls.coach.spot_outdoor), race.lap), radius))
	var p := _px(spot)
	var s := maxf(0.9 * _k, 5.0)
	var diamond := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
	draw_colored_polygon(diamond, Palette.ACCENT)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color.WHITE, 1.5)
	var font := get_theme_default_font()
	var w := font.get_string_size("Coach", HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
	draw_string(font, p + Vector2(-w / 2.0, -s - 5.0), "Coach", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)


func _draw_runners() -> void:
	var dot := maxf(0.75 * _k, 4.0)
	var order := race.standings()
	# Back-to-front so the leaders are on top; the player last of all.
	for i in range(order.size() - 1, -1, -1):
		var r: Race.Runner = order[i]
		if r.is_player:
			continue
		var p := _px(_position(r))
		draw_circle(p, dot, Color("#d0d4de"))
		draw_circle(p, dot, Color("#12141a"), false, 1.0)
	if race.player:
		var p := _px(_position(race.player))
		draw_circle(p, dot * 1.25, Palette.ACCENT)
		draw_circle(p, dot * 1.25, Color.WHITE, false, 2.0)
		var font := get_theme_default_font()
		var w := font.get_string_size("You", HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
		draw_string(font, p + Vector2(-w / 2.0, -dot * 1.25 - 6.0), "You", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)


## A standard 200 m indoor track: 6 lanes, synthetic infield with the 60 m sprint straight in the middle.
func _draw_indoor_track(r_out: float) -> void:
	var hall := Rect2(_px(Vector2(-race.straight / 2.0 - r_out - INDOOR_MARGIN, -r_out - INDOOR_MARGIN)),
			Vector2(race.straight + 2.0 * (r_out + INDOOR_MARGIN), 2.0 * (r_out + INDOOR_MARGIN)) * _k)
	draw_rect(hall, Palette.CONCOURSE)
	_fill(r_out + 1.0, Palette.TRACK_APRON)
	_fill(r_out, Palette.TRACK)
	_fill(race.r_in, Palette.TRACK.darkened(0.12))
	var w := maxf(0.08 * _k, 1.0)
	for i in range(race.lanes + 1):
		_stroke(race.r_in + Race.LANE_W * i, Palette.LINE, w)
	_stroke(race.r_in - 0.05, Color.WHITE, maxf(0.2 * _k, 1.5))
	# 60 m sprint straight (8 lanes) across the infield.
	var sprint := Rect2(-36.0, -Race.LANE_W * 4.0, 72.0, Race.LANE_W * 8.0)
	draw_rect(Rect2(_px(sprint.position), sprint.size * _k), Palette.TRACK.lightened(0.04))
	for i in 9:
		var y := sprint.position.y + Race.LANE_W * i
		draw_line(_px(Vector2(sprint.position.x, y)), _px(Vector2(sprint.end.x, y)), Color(1, 1, 1, 0.35), 1.0)
	# Finish line at the end of the home straight.
	var fx := race.straight / 2.0
	draw_line(_px(Vector2(fx, race.r_in)), _px(Vector2(fx, r_out)), Color.WHITE, maxf(0.12 * _k, 1.5))


## Position in metres (track coordinates) of a runner.
func _position(r: Race.Runner) -> Vector2:
	var d := minf(lerpf(r.prev_d, r.d, blend), Race.DISTANCE + 2.0)
	if d < race.break_line:
		# In lanes: each lane starts further round (the stagger: the extra length of the bends run in lanes), so all
		# reach the break line level.
		var radius := race.r_in + (r.lane - 0.5) * Race.LANE_W
		return _stadium_point(radius, race.straight + race.break_bends * PI * (radius - race.r1) + d)
	var radius := race.r1 + lerpf(r.prev_lat, r.lat, blend) + 0.3
	return _stadium_point(radius, _path_s(fmod(d, race.lap), radius))


## Lane-1 lap distance (0 = finish line) → distance along a path of this radius, measured like
## _stadium_point (0 = left end of the home straight).
func _path_s(p: float, radius: float) -> float:
	var arc := PI * radius
	if p < race.bend:
		return race.straight + p / race.bend * arc
	p -= race.bend
	if p < race.straight:
		return race.straight + arc + p
	p -= race.straight
	if p < race.bend:
		return 2.0 * race.straight + arc + p / race.bend * arc
	p -= race.bend
	return p   # home straight, from its left end


## Point at distance `s` along a stadium-shaped path of radius `r`, starting at the left end of the
## bottom (home) straight and running anticlockwise on screen.
func _stadium_point(r: float, s: float) -> Vector2:
	var half := race.straight / 2.0
	var arc := PI * r
	s = fmod(s, 2.0 * race.straight + 2.0 * arc)
	if s < race.straight:
		return Vector2(-half + s, r)
	s -= race.straight
	if s < arc:
		return Vector2(half, 0.0) + Vector2.from_angle(PI / 2.0 - s / r) * r
	s -= arc
	if s < race.straight:
		return Vector2(half - s, -r)
	s -= race.straight
	return Vector2(-half, 0.0) + Vector2.from_angle(-PI / 2.0 - s / r) * r


func _fill(r: float, color: Color) -> void:
	var a := _px(Vector2(-race.straight / 2.0, 0.0))
	var b := _px(Vector2(race.straight / 2.0, 0.0))
	draw_circle(a, r * _k, color)
	draw_circle(b, r * _k, color)
	draw_rect(Rect2(a.x, a.y - r * _k, b.x - a.x, r * 2.0 * _k), color)


func _stroke(r: float, color: Color, width: float) -> void:
	var a := _px(Vector2(-race.straight / 2.0, 0.0))
	var b := _px(Vector2(race.straight / 2.0, 0.0))
	var rp := r * _k
	draw_arc(a, rp, PI / 2.0, PI * 1.5, 48, color, width, true)
	draw_arc(b, rp, -PI / 2.0, PI / 2.0, 48, color, width, true)
	draw_line(Vector2(a.x, a.y - rp), Vector2(b.x, b.y - rp), color, width, true)
	draw_line(Vector2(a.x, a.y + rp), Vector2(b.x, b.y + rp), color, width, true)


func _px(m: Vector2) -> Vector2:
	return _center + m * _k
