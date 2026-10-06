class_name TodayCard
extends PanelContainer
## The Today card at the top of Overview (GDD 4.5): today's sessions and intensity (or rest day / the race),
## how you feel, warning signs, and the next race. Tapping it opens today's day editor (`pressed`).

signal pressed

const FEEL := {"Fresh": "Your legs feel light.", "Normal": "You feel fine.",
		"Tired": "Your legs feel heavy.", "Exhausted": "You're running on empty."}

var _content: MarginContainer


func _init() -> void:
	_content = MarginContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, 14 if Layout.compact else 18)
	add_child(_content)
	var button := Button.new()   # laid over the whole card
	button.theme_type_variation = "CardOverlay"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): pressed.emit())
	add_child(button)
	refresh()


func refresh() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	var info := DayInfo.of(Game.current_week(), Calendar.weekday(Game.date))
	var columns := UIKit.flex(24 if not Layout.compact else 14)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_today(info))
	columns.add_child(_feel())
	columns.add_child(_next_race(info))
	_content.add_child(columns)


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
	_warning_signs(col)
	return col


## Body warning signs (soreness per area, GDD 4.6) come with the health UI (M2 step 4). Until the health
## model exists there is nothing to warn about.
func _warning_signs(col: VBoxContainer) -> void:
	col.add_child(UIKit.label("WARNING SIGNS", "CaptionLabel"))
	col.add_child(UIKit.wrapped("None.", "MutedLabel"))


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
