class_name ProtoHud
extends Control
## R6a prototype: the race information drawn over any of the three viewpoints (TV-style graphics, V1 palette): the position
## board with gaps in seconds, the clock, the reserve meter with its fuzz, the plan line, the effort bar, the track map, alerts
## and split flashes. Everything is read from the recording by the viewer, which fills `s` every frame; nothing here decides.

const NUM_FONT := "res://assets/fonts/BarlowCondensed-Bold.ttf"

## The viewer fills these every frame.
var rec: RaceRecording
var s := {
	"view": "", "clock": 0.0, "dist": 0.0, "rows": [], "reserve": 1.0, "felt": 1.0, "fuzz": 0.1, "effort": 0.0,
	"plan": 0.0, "alert": "", "alert_age": 99.0, "split": "", "split_age": 99.0, "dots": [], "slow": false, "title": "",
}
var visible_hud := true
var bottom_margin := 96.0   # the control bar below (the viewer sets it)
var _num: Font
var _txt: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_num = load(NUM_FONT)
	_txt = get_theme_default_font()


func _u() -> float:
	return clampf(minf(size.x / 1280.0, size.y / 720.0), 0.8 if size.x < 700.0 else 0.62, 1.4)


func _text(p: Vector2, text: String, fs: int, col: Color, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(font if font else _txt, p, text, align, w, fs, col)


func _panel(r: Rect2, accent := Color(0, 0, 0, 0)) -> void:
	draw_rect(r, Color(0.055, 0.067, 0.09, 0.82))
	if accent.a > 0.0:
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), accent)


func _draw() -> void:
	if rec == null or not visible_hud:
		return
	var u := _u()
	var compact := size.x < 700.0
	_draw_board(u, compact)
	_draw_clock(u)
	_draw_map(u, compact)
	_draw_meter(u, compact)
	_draw_plan(u, compact)
	_draw_effort(u)
	_draw_alerts(u)


func _draw_board(u: float, compact: bool) -> void:
	var rows: Array = s.rows
	var rh := 21.0 * u
	var w := (170.0 if compact else 215.0) * u
	var top := 12.0
	var r := Rect2(12, top, w, rh * (rows.size() + 1) + 10)
	_panel(r, Palette.LEAD)
	_text(Vector2(24, top + rh - 4), "800 M  ·  FINAL" if not rec.indoor else "800 M  ·  INDOOR", int(12 * u), Palette.LEAD, _txt)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := top + rh * (i + 1) + 6.0
		if row.is_player:
			draw_rect(Rect2(14, y - 1, w - 4, rh), Color(Palette.ACCENT, 0.35))
		_text(Vector2(22, y + rh - 6), str(row.pos), int(15 * u), Palette.LEAD if i == 0 else Palette.TEXT, _num)
		draw_rect(Rect2(40, y + 3, 5, rh - 8), row.color)
		_text(Vector2(52, y + rh - 6), str(row.name), int(14 * u), Palette.TEXT if row.is_player else Palette.TEXT_MUTED, _txt)
		_text(Vector2(12 + w - 8 - 70 * u, y + rh - 6), str(row.gap), int(14 * u), Palette.TEXT_MUTED, _num, HORIZONTAL_ALIGNMENT_RIGHT, 70 * u)


func _draw_clock(u: float) -> void:
	var cx := size.x / 2.0
	var w := 190.0 * u
	_panel(Rect2(cx - w / 2.0, 10, w, 62 * u))
	_text(Vector2(cx - w / 2.0, 10 + 40 * u), _fmt(float(s.clock)), int(40 * u), Palette.TEXT, _num, HORIZONTAL_ALIGNMENT_CENTER, w)
	var to_go := maxf(0.0, Race.DISTANCE - float(s.dist))
	_text(Vector2(cx - w / 2.0, 10 + 57 * u), "%d m to go" % roundi(to_go), int(12 * u), Palette.TEXT_MUTED, _txt, HORIZONTAL_ALIGNMENT_CENTER, w)
	if s.slow:
		_text(Vector2(cx - w / 2.0, 10 + 82 * u), "SLOW MOTION", int(12 * u), Palette.LEAD, _txt, HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_map(u: float, compact: bool) -> void:
	var mw := (120.0 if compact else 190.0) * u
	var r_out := rec.r_in + Race.LANE_W * rec.lanes
	var ext := Vector2(rec.straight + 2.0 * r_out, 2.0 * r_out)
	var k := mw / ext.x
	var mh := ext.y * k
	var box := Rect2(size.x - mw - 26, 12, mw + 14, mh + 14)
	_panel(box)
	var origin := box.position + Vector2(7, 7) + Vector2(ext.x / 2.0, ext.y / 2.0) * k
	var line := PackedVector2Array()
	var rm := rec.r_in + Race.LANE_W * rec.lanes / 2.0
	var total := 2.0 * rec.straight + 2.0 * PI * rm
	for i in 81:
		var p := rec.stadium_point(rm, total * i / 80.0)
		line.append(origin + p * k)
	draw_polyline(line, Color(1, 1, 1, 0.35), maxf(3.0 * u, 2.0), true)
	var fx := origin + Vector2(rec.straight / 2.0, rm) * k
	draw_line(fx - Vector2(0, 4), fx + Vector2(0, 4), Color.WHITE, 2.0)
	for dd in s.dots:
		var p: Vector2 = origin + dd.p * k
		if dd.is_player:
			draw_circle(p, 4.5 * u, Palette.ACCENT)
			draw_arc(p, 4.5 * u, 0, TAU, 16, Color.WHITE, 1.2)
		else:
			draw_circle(p, 3.0 * u, dd.color)


func _draw_meter(u: float, compact: bool) -> void:
	var w := (210.0 if compact else 280.0) * u
	var h := 54.0 * u
	var x := 12.0
	var y := size.y - bottom_margin - 8.0 - h
	_panel(Rect2(x, y, w, h), Palette.GOOD)
	_text(Vector2(x + 12, y + 18 * u), "RESERVE", int(12 * u), Palette.TEXT_MUTED, _txt)
	var bx := x + 12.0
	var bw := w - 24.0
	var by := y + 26.0 * u
	var bh := 14.0 * u
	draw_rect(Rect2(bx, by, bw, bh), Palette.BAR_TRACK)
	var felt := clampf(float(s.felt), 0.0, 1.0)
	var col: Color = Palette.GOOD if felt > 0.5 else (Palette.WARN if felt > 0.25 else Palette.BAD)
	draw_rect(Rect2(bx, by, bw * felt, bh), col)
	# the fuzz: what the runner cannot tell about their own reserve (wider with weak race tactics)
	var fz := float(s.fuzz)
	var a := clampf(felt - fz, 0.0, 1.0)
	var b := clampf(felt + fz, 0.0, 1.0)
	draw_rect(Rect2(bx + bw * a, by - 3, bw * (b - a), bh + 6), Color(1, 1, 1, 0.22))
	draw_line(Vector2(bx + bw * felt, by - 4), Vector2(bx + bw * felt, by + bh + 4), Color.WHITE, 2.0)
	var word := "Comfortable" if felt > 0.66 else ("Working" if felt > 0.4 else ("Hurting" if felt > 0.15 else "Empty"))
	_text(Vector2(x + w - 12 - 110 * u, y + 18 * u), word, int(13 * u), col, _txt, HORIZONTAL_ALIGNMENT_RIGHT, 110 * u)


func _draw_plan(u: float, compact: bool) -> void:
	var w := (210.0 if compact else 280.0) * u
	var h := 54.0 * u
	var x := 12.0 + w + 10.0
	var y := size.y - bottom_margin - 8.0 - h
	if x + w > size.x - 70.0:   # a narrow screen: above the meter
		x = 12.0
		y -= h + 8.0
	_panel(Rect2(x, y, w, h), Palette.LEAD)
	var d := float(s.plan)   # seconds ahead (+) / behind (-) of the coach's plan
	_text(Vector2(x + 12, y + 18 * u), "PLAN LINE", int(12 * u), Palette.TEXT_MUTED, _txt)
	var word := ("%.1f s ahead" % d) if d >= 0.05 else (("%.1f s behind" % -d) if d <= -0.05 else "on plan")
	_text(Vector2(x + w - 12 - 130 * u, y + 18 * u), word, int(13 * u), Palette.GOOD if absf(d) < 0.6 else Palette.WARN, _txt, HORIZONTAL_ALIGNMENT_RIGHT, 130 * u)
	var bx := x + 12.0
	var bw := w - 24.0
	var by := y + 34.0 * u
	draw_line(Vector2(bx, by), Vector2(bx + bw, by), Palette.BAR_TRACK, 4.0)
	draw_line(Vector2(bx + bw / 2.0, by - 8), Vector2(bx + bw / 2.0, by + 8), Palette.LEAD, 2.0)
	var px := bx + bw / 2.0 + clampf(d / 3.0, -1.0, 1.0) * bw / 2.0
	draw_circle(Vector2(px, by), 5.0 * u, Palette.ACCENT)


func _draw_effort(u: float) -> void:
	var w := 26.0 * u
	var top := 140.0 * u
	var h := maxf(100.0, size.y - top - bottom_margin - 130.0 * u)
	var x := size.x - w - 14.0
	_panel(Rect2(x - 6, top - 22, w + 12, h + 52))
	_text(Vector2(x - 6, top - 6), "EFFORT", int(10 * u), Palette.TEXT_MUTED, _txt, HORIZONTAL_ALIGNMENT_CENTER, w + 12)
	draw_rect(Rect2(x, top, w, h), Palette.BAR_TRACK)
	var e := clampf(float(s.effort), 0.0, 1.0)
	var col := Palette.GOOD.lerp(Palette.WARN, clampf(e * 2.0 - 0.6, 0.0, 1.0)).lerp(Palette.BAD, clampf(e * 2.0 - 1.2, 0.0, 1.0))
	draw_rect(Rect2(x, top + h * (1.0 - e), w, h * e), col)
	draw_line(Vector2(x - 3, top + h * 0.5), Vector2(x + w + 3, top + h * 0.5), Color(1, 1, 1, 0.5), 1.0)
	_text(Vector2(x - 6, top + h + 16 * u), "replay", int(10 * u), Palette.TEXT_FAINT, _txt, HORIZONTAL_ALIGNMENT_CENTER, w + 12)


func _draw_alerts(u: float) -> void:
	var cx := size.x / 2.0
	if str(s.alert) != "" and float(s.alert_age) < 3.2:
		var a := clampf(3.2 - float(s.alert_age), 0.0, 1.0)
		var w := 360.0 * u
		var r := Rect2(cx - w / 2.0, 110.0 * u, w, 34.0 * u)
		draw_rect(r, Color(Palette.ACCENT, 0.9 * a))
		_text(Vector2(r.position.x, r.position.y + 24 * u), str(s.alert), int(18 * u), Color(1, 1, 1, a), _num, HORIZONTAL_ALIGNMENT_CENTER, w)
	if str(s.split) != "" and float(s.split_age) < 4.0:
		var a2 := clampf(4.0 - float(s.split_age), 0.0, 1.0)
		var w2 := 300.0 * u
		var r2 := Rect2(cx - w2 / 2.0, 154.0 * u, w2, 40.0 * u)
		draw_rect(r2, Color(0.055, 0.067, 0.09, 0.9 * a2))
		draw_rect(Rect2(r2.position, Vector2(4, r2.size.y)), Color(Palette.LEAD, a2))
		_text(Vector2(r2.position.x + 12, r2.position.y + 28 * u), str(s.split), int(22 * u), Color(1, 1, 1, a2), _num)


static func _fmt(t: float) -> String:
	var m := int(t / 60.0)
	return "%d:%04.1f" % [m, t - m * 60.0]
