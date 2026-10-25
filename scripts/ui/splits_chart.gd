class_name SplitsChart
extends Control
## The race card's 200 m splits as paired bars (GDD 5 "Charts", session L2a): per 200 m the other runner (the winner, or the runner-up
## when you won) in DAY_NORMAL and you in ACCENT, a faint grid with its seconds, your value on your bar, the parts under the bars.
## Lower is faster (the axis note under the chart says so). A part not run (a DNF) has no bar. Drawn in _draw; nothing to tap.

const PARTS := ["0–200", "200–400", "400–600", "600–800"]

var you: Array = []
var other: Array = []


func _init(you_splits: Array, other_splits: Array, height := 170.0) -> void:
	you = you_splits
	other = other_splits
	custom_minimum_size = Vector2(0, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var values := []
	for v in you + other:
		if float(v) > 0.0:
			values.append(float(v))
	if values.is_empty():
		return
	var num := ThemeBuilder.number_font(ThemeBuilder.NUM_BOLD)
	var text_font: Font = ThemeBuilder.FONT_REGULAR
	var small := 13 if Layout.compact else 12
	var lo := floorf((values.min() - 2.0) / 4.0) * 4.0
	var hi := ceilf((values.max() + 1.0) / 4.0) * 4.0
	if hi - lo < 8.0:
		hi = lo + 8.0
	var left := 28.0
	var top := 18.0
	var bottom := size.y - 22.0
	var right := size.x
	var h := bottom - top
	# The grid with its seconds (every 4 s).
	var s := lo
	while s <= hi + 0.01:
		var y := bottom - (s - lo) / (hi - lo) * h
		draw_line(Vector2(left, y), Vector2(right, y), Color(Palette.BORDER, 0.9), 1.0)
		draw_string(text_font, Vector2(0, y + 4), "%d" % roundi(s), HORIZONTAL_ALIGNMENT_LEFT, left - 4, small, Palette.TEXT_FAINT)
		s += 4.0
	var group := (right - left) / 4.0
	var bar := minf(30.0, group * 0.26)
	for i in 4:
		var cx := left + group * (i + 0.5)
		var pairs := [[other, Color(Palette.DAY_NORMAL, 0.55), cx - bar - 3.0, false], [you, Palette.ACCENT, cx + 3.0, true]]
		for p in pairs:
			var list: Array = p[0]
			var v := float(list[i]) if i < list.size() else 0.0
			if v <= 0.0:
				continue
			var y := bottom - (clampf(v, lo, hi) - lo) / (hi - lo) * h
			draw_rect(Rect2(float(p[2]), y, bar, bottom - y), p[1])
			if bool(p[3]):
				draw_string(num, Vector2(float(p[2]) - 8.0, y - 4.0), "%.1f" % v, HORIZONTAL_ALIGNMENT_CENTER, bar + 16.0, small + 2, Palette.TEXT)
		draw_string(text_font, Vector2(cx - group / 2.0, size.y - 4.0), PARTS[i], HORIZONTAL_ALIGNMENT_CENTER, group, small, Palette.TEXT_MUTED)
