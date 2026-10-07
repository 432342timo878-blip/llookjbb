class_name TodayCard
extends PanelContainer
## The Today card at the top of Overview (GDD 4.5, 4.6): today's sessions and intensity (or rest day / the race),
## how you feel, and the next race. Tapping that top part opens today's day editor (`pressed`).
## Under it the race form (a word, tap = what it means and what builds it, `FormUI`) and the health part: warning signs (soreness per body area, in words and colour, tap an area for why and
## what helps) next to the active injuries and illnesses (phase, what's allowed, expected return).

signal pressed

const FEEL := {"Fresh": "Your legs feel light.", "Normal": "You feel fine.",
		"Tired": "Your legs feel heavy.", "Exhausted": "You're running on empty."}

var _rows: VBoxContainer
var _open_areas := {}   # soreness rows that are open (area id -> bool), kept when the card redraws


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14 if Layout.compact else 18)
	add_child(margin)
	_rows = UIKit.vbox(12)
	margin.add_child(_rows)
	refresh()


func refresh() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var info := DayInfo.of(Game.current_week(), Calendar.weekday(Game.date))
	var columns := UIKit.flex(24 if not Layout.compact else 14)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_today(info))
	columns.add_child(_feel())
	columns.add_child(_next_race(info))
	# The top part is one big button (tap = today's editor); the health part below has its own taps.
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	top.add_child(columns)
	var button := Button.new()
	button.theme_type_variation = "CardOverlay"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): pressed.emit())
	top.add_child(button)
	_rows.add_child(top)
	var form := FormUI.today_row()
	if form != null:
		_rows.add_child(HSeparator.new())
		_rows.add_child(form)
	var health := HealthUI.warning_sections(_open_areas)
	if health != null:
		_rows.add_child(HSeparator.new())
		_rows.add_child(health)


## Opens the soreness row of an area (for screenshots and the layout check).
func open_area(area_id: String) -> void:
	_open_areas[area_id] = true
	refresh()


func _column() -> VBoxContainer:
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return col


func _today(info: Dictionary) -> Control:
	var col := _column()
	col.add_child(UIKit.label("TODAY · " + Calendar.format_day(Game.date).to_upper(), "CaptionLabel"))
	if not info.race.is_empty():
		col.add_child(UIKit.wrapped("Race day", "HeadingLabel"))
		col.add_child(UIKit.wrapped(info.race.name, ""))
		col.add_child(UIKit.wrapped(Calendar.place(Game.athlete, info.race), "MutedLabel"))
	elif info.sessions.is_empty():
		col.add_child(UIKit.wrapped("Rest day", "HeadingLabel"))
		col.add_child(UIKit.wrapped("No training planned. Your body recovers faster today.", "MutedLabel"))
	else:
		for session_name in DayInfo.session_names(info.sessions):
			col.add_child(UIKit.wrapped(session_name, "HeadingLabel"))
		var level_label := UIKit.label("%s intensity · load %d" % [DayInfo.intensity_name(info.intensity), roundi(info.load)])
		level_label.add_theme_color_override("font_color", DayInfo.intensity_color(info.intensity))
		col.add_child(level_label)
	if info.changed:
		col.add_child(UIKit.wrapped(DayInfo.changed_text(info), "MutedLabel"))
	var hint := UIKit.label("TAP TO SEE DETAILS" if not info.race.is_empty() else "TAP TO CHANGE TODAY", "CaptionLabel")
	hint.add_theme_color_override("font_color", Palette.ACCENT)
	col.add_child(hint)
	return col


func _feel() -> Control:
	var col := _column()
	col.add_child(UIKit.label("HOW YOU FEEL", "CaptionLabel"))
	var fatigue := Game.athlete.fatigue
	col.add_child(UIKit.fatigue_label(fatigue))
	col.add_child(UIKit.wrapped(FEEL.get(Training.fatigue_state(fatigue)[0], ""), "MutedLabel"))
	return col


func _next_race(info: Dictionary) -> Control:
	var col := _column()
	col.add_child(UIKit.label("NEXT RACE", "CaptionLabel"))
	var next := DayInfo.next_race_after_today() if not info.race.is_empty() else Game.next_race()
	if next.is_empty():
		col.add_child(UIKit.wrapped("No races entered. Pick some in the Calendar.", "MutedLabel"))
	else:
		col.add_child(UIKit.wrapped(next.name, ""))
		col.add_child(UIKit.wrapped("%s · %s" % [Calendar.format_meet_date(next), DayInfo.days_away(next.date)], "MutedLabel"))
		col.add_child(UIKit.wrapped(Calendar.place(Game.athlete, next), "MutedLabel"))
	return col
