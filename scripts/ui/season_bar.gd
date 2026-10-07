class_name SeasonBar
extends Control
## The season as one bar, Nov–Oct (GDD 4.8 UI, PC): the phases in their colours (a dark dot = your changes),
## a thin strip under it with the lighter weeks (blue) and taper weeks (orange), ◆ on the target meets with their
## names above the bar, the months under it, and a white line for today. Tapping a phase emits `phase_pressed`.
## Everything is drawn once per refresh (no per-frame work).

signal phase_pressed(phase_id: String)

const TARGET_ROW := 22.0
const BAR := 46.0
const KIND_ROW := 8.0
const MONTH_ROW := 20.0

var year := 0
var _phases: Array = []    # phase_dates() + edited
var _kinds: Array = []     # per week of the season: "normal" / "lighter" / "taper"
var _targets: Array = []   # meets
var _weeks := 52
var _press := Vector2.ZERO


func _init(season_year: int) -> void:
	year = season_year
	custom_minimum_size.y = TARGET_ROW + BAR + KIND_ROW + MONTH_ROW + 4.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	refresh()


func refresh() -> void:
	var s := Game.season
	_weeks = SeasonPlan.season_weeks(year)
	_phases = s.phase_dates(year)
	for p in _phases:
		p.edited = s.is_edited(year, p.id)
	_kinds = []
	var origin := SeasonPlan.season_start(year)
	for w in _weeks:
		_kinds.append(s.week_for(Game.add_days(origin, w * 7)).kind)
	_targets = []
	for key in s.targets(year):
		var m := Calendar.get_meet(key)
		if not m.is_empty():
			_targets.append(m)
	queue_redraw()


func _x_of_day(days: float) -> float:
	return days / (_weeks * 7.0) * size.x


func _draw() -> void:
	var font := get_theme_default_font()
	var fs := 14
	var origin := SeasonPlan.season_start(year)
	var top := TARGET_ROW
	# Phases, then today's line, then the names on top (so the line never hides a letter).
	for p in _phases:
		var x0 := _x_of_day(p.start * 7.0)
		var x1 := _x_of_day((p.start + p.weeks) * 7.0)
		draw_rect(Rect2(x0, top, x1 - x0, BAR), Color(str(SeasonPlan.phase_type(p.id).get("color", "#888888"))))
		draw_line(Vector2(x1, top), Vector2(x1, top + BAR), Palette.BG, 2.0)
	var today := float(Calendar.days_between(origin, Game.date))
	if today >= 0.0 and today <= _weeks * 7.0:
		var tx := _x_of_day(today + 0.5)
		draw_line(Vector2(tx, top - 2.0), Vector2(tx, top + BAR + KIND_ROW), Palette.TEXT, 3.0)
		draw_line(Vector2(tx, top - 2.0), Vector2(tx, top + BAR + KIND_ROW), Palette.BG, 1.0)
	for p in _phases:
		var x0 := _x_of_day(p.start * 7.0)
		var x1 := _x_of_day((p.start + p.weeks) * 7.0)
		var title: String = SeasonPlan.phase_type(p.id).get("name", p.id)
		var room := x1 - x0 - 10.0
		if p.edited:
			room -= 14.0
		for candidate in [title, title.split(" ")[0], ""]:
			if candidate != "" and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room:
				draw_string(font, Vector2(x0 + 6.0, top + BAR / 2.0 + fs * 0.35), candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.BG)
				break
		if p.edited and x1 - x0 > 16.0:
			draw_circle(Vector2(x1 - 9.0, top + 9.0), 4.5, Palette.BG)   # "your changes" dot
	# Lighter and taper weeks.
	for w in _kinds.size():
		var kind: String = _kinds[w]
		if kind == "normal":
			continue
		var c := Palette.DAY_EASY if kind == "lighter" else Palette.ACCENT
		draw_rect(Rect2(_x_of_day(w * 7.0) + 1.0, top + BAR + 2.0, _x_of_day(7.0) - 2.0, KIND_ROW - 3.0), c)
	# Months.
	var month_y := top + BAR + KIND_ROW + MONTH_ROW - 5.0
	for i in 12:
		var m := 11 + i
		var first := {"year": year + (1 if m > 12 else 0), "month": (m - 1) % 12 + 1, "day": 1}
		var x := _x_of_day(float(Calendar.days_between(origin, first)))
		if x < 0.0 or x > size.x - 20.0:
			continue
		draw_line(Vector2(x, top + BAR + KIND_ROW), Vector2(x, top + BAR + KIND_ROW + 4.0), Palette.TEXT_FAINT, 1.0)
		draw_string(font, Vector2(x + 2.0, month_y), Calendar.MONTHS_SHORT[int(first.month) - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.TEXT_MUTED)
	# Targets: ◆ on the top edge of the bar, the name above it (kept inside the bar's width).
	for m in _targets:
		var x := _x_of_day(float(Calendar.days_between(origin, m.date)) + 0.5)
		var d := 7.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, top - d), Vector2(x + d, top), Vector2(x, top + d), Vector2(x - d, top)]), Palette.TEXT)
		draw_polyline(PackedVector2Array([Vector2(x, top - d), Vector2(x + d, top), Vector2(x, top + d), Vector2(x - d, top), Vector2(x, top - d)]), Palette.BG, 1.5)
		var label: String = m.name
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var lx := clampf(x - w / 2.0, 0.0, maxf(0.0, size.x - w))
		draw_string(font, Vector2(lx, top - 9.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.TEXT)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_press = event.position
		return
	if event.position.distance_to(_press) > 10.0:   # a scroll drag, not a tap
		return
	var day: float = event.position.x / maxf(1.0, size.x) * _weeks * 7.0
	for p in _phases:
		if day >= p.start * 7.0 and day < (p.start + p.weeks) * 7.0:
			phase_pressed.emit(p.id)
			accept_event()
			return
