class_name PbChart
extends Control
## The personal best over time (GDD 4.10 decision 10, session K1a): a step line through every personal best (lower is faster, so the line
## falls), a faint grid with its times, the first and the latest best written on the line, a dot for each. Drawn in _draw; nothing to
## tap (the Results list holds every race). `points` = CareerSystem.pb_series: [{date, time, meet}] oldest first.

var points: Array = []
var today: Dictionary = {}


func _init(series: Array, until: Dictionary, height := 170.0) -> void:
	points = series
	today = until
	custom_minimum_size = Vector2(0, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if points.size() < 2:
		return
	var num := ThemeBuilder.number_font(ThemeBuilder.NUM_BOLD)
	var text_font: Font = ThemeBuilder.FONT_REGULAR
	var small := 13 if Layout.compact else 12
	var t_min := 1.0e9
	var t_max := 0.0
	for p in points:
		t_min = minf(t_min, float(p.time))
		t_max = maxf(t_max, float(p.time))
	var step := 5.0 if t_max - t_min > 12.0 else 2.0
	var lo := floorf((t_min - 1.0) / step) * step
	var hi := ceilf((t_max + 1.0) / step) * step
	var left := 44.0
	var top := 14.0
	var bottom := size.y - 22.0
	var right := size.x - 8.0
	var h := bottom - top
	var d0 := StoryletSystem.day_no(points[0].date)
	var d1 := maxi(StoryletSystem.day_no(today), StoryletSystem.day_no(points[-1].date))
	var span := maxf(1.0, float(d1 - d0))
	# the grid with its times (the latest at the top is the slowest: higher on the page = slower)
	var s := lo
	while s <= hi + 0.01:
		var y := top + (s - lo) / (hi - lo) * h
		draw_line(Vector2(left, y), Vector2(right, y), Color(Palette.BORDER, 0.9), 1.0)
		draw_string(text_font, Vector2(0, y + 4), Calendar.format_time(s), HORIZONTAL_ALIGNMENT_LEFT, left - 4, small, Palette.TEXT_FAINT)
		s += step
	var prev := Vector2.ZERO
	for i in points.size():
		var p: Dictionary = points[i]
		var x := left + (float(StoryletSystem.day_no(p.date) - d0) / span) * (right - left)
		var y := top + (float(p.time) - lo) / (hi - lo) * h
		var at := Vector2(x, y)
		if i > 0:
			draw_line(prev, Vector2(x, prev.y), Palette.ACCENT, 2.0)
			draw_line(Vector2(x, prev.y), at, Palette.ACCENT, 2.0)
		draw_circle(at, 3.5, Palette.LEAD)
		prev = at
	# the line continues flat to today
	var x_end := left + (float(StoryletSystem.day_no(today) - d0) / span) * (right - left)
	if x_end > prev.x:
		draw_line(prev, Vector2(x_end, prev.y), Color(Palette.ACCENT, 0.5), 2.0)
	draw_string(num, Vector2(left + 4.0, minf(bottom - 4.0, top + (float(points[0].time) - lo) / (hi - lo) * h - 8.0)),
			Calendar.format_time(float(points[0].time)), HORIZONTAL_ALIGNMENT_LEFT, 90.0, small + 2, Palette.TEXT)
	draw_string(num, Vector2(right - 96.0, maxf(top + 12.0, prev.y - 10.0)), Calendar.format_time(float(points[-1].time)),
			HORIZONTAL_ALIGNMENT_RIGHT, 92.0, small + 2, Palette.LEAD)
	draw_string(text_font, Vector2(left, size.y - 4.0), Calendar.format_day(points[0].date), HORIZONTAL_ALIGNMENT_LEFT, 120.0, small, Palette.TEXT_MUTED)
	draw_string(text_font, Vector2(right - 120.0, size.y - 4.0), Calendar.format_day(today), HORIZONTAL_ALIGNMENT_RIGHT, 120.0, small, Palette.TEXT_MUTED)
