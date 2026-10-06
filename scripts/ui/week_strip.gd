class_name WeekStrip
extends HBoxContainer
## The week strip (GDD 4.5 "Hub UI"): seven cells for Mon–Sun of the current week, under the header.
## Each cell shows the date, one marker per session (colour = intensity: blue Easy, grey Normal, red Hard),
## a RACE badge on race days, a dot when the day was changed, and for played days a fatigue dot (dimmed).
## Today has an accent border; `selected` (the day open in the day editor) a bright one.
## Tapping a cell emits `day_pressed`. On a phone the cells are ~62 px wide and show the day letter, the
## day of the month and the markers; on PC they also show the session names.

signal day_pressed(day: int)

var selected := -1   # the day open in the day editor, -1 = none
var monday := {}     # the Monday of the week shown (the hub closes the editor when it changes)


func _init() -> void:
	add_theme_constant_override("separation", 3 if Layout.compact else 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	refresh()


## Redraws all seven cells from the game state.
func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var w := Game.current_week()
	monday = w.monday
	for d in 7:
		add_child(_cell(DayInfo.of(w, d)))


func _cell(info: Dictionary) -> Control:
	var compact := Layout.compact
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(0, 78 if compact else 92)
	cell.add_theme_stylebox_override("panel", _cell_style(info))

	var col := UIKit.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if info.played:
		col.modulate = Color(1, 1, 1, 0.62)
	cell.add_child(col)

	# Top line: day (and date on PC), marks on the right.
	var top := UIKit.hbox(3)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_text: String = Training.DAY_NAMES[info.day]
	if compact:
		name_text = name_text.left(1)
	else:
		name_text += " %d.%d." % [info.date.day, info.date.month]
	var day_label := UIKit.label(name_text, "SubheadingLabel" if not compact else "CaptionLabel")
	day_label.clip_text = true
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_label.add_theme_color_override("font_color", Palette.ACCENT if info.today else Palette.TEXT_MUTED if compact else Palette.TEXT)
	top.add_child(day_label)
	if info.changed:
		top.add_child(UIKit.dot(Palette.ACCENT, 7))   # "changed" mark
	if info.played and info.fatigue >= 0.0:
		top.add_child(UIKit.dot(Training.fatigue_state(info.fatigue)[1], 10))
	col.add_child(top)

	if compact:
		var date_label := UIKit.label(str(info.date.day), "SubheadingLabel")
		date_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(date_label)

	# Sessions: markers on a phone, marker + name per session on PC.
	var sessions: Array = info.sessions
	var level: String = info.intensity
	if not info.race.is_empty():
		pass   # the race badge below says it
	elif sessions.is_empty():
		var rest := UIKit.label("Rest" if compact else "Rest day", "CaptionLabel")
		rest.clip_text = true
		col.add_child(rest)
	elif compact:
		var markers := UIKit.hbox(3)
		markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in sessions.size():
			markers.add_child(UIKit.dot(DayInfo.intensity_color(level), 14, 6))
		col.add_child(markers)
	else:
		for id in sessions:
			var line := UIKit.hbox(5)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(UIKit.dot(DayInfo.intensity_color(level), 8))
			var l := UIKit.label(str(Data.get_session(id).get("name", id)), "MutedLabel")
			l.add_theme_font_size_override("font_size", 13)
			l.clip_text = true
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(l)
			col.add_child(line)

	# Bottom: race badge, or (PC) the fatigue word of a played day.
	if not info.race.is_empty():
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.ACCENT
		style.set_corner_radius_all(4)
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		badge.add_theme_stylebox_override("panel", style)
		var badge_text := UIKit.label("RACE", "CaptionLabel")
		badge_text.add_theme_color_override("font_color", Color.WHITE)
		badge.add_child(badge_text)
		col.add_child(badge)
		if not compact:
			var meet := UIKit.label(str(info.race.name), "MutedLabel")
			meet.add_theme_font_size_override("font_size", 13)
			meet.clip_text = true
			col.add_child(meet)
	elif info.played and not compact and info.fatigue >= 0.0:
		var state := Training.fatigue_state(info.fatigue)
		var word := UIKit.label(state[0], "CaptionLabel")
		word.add_theme_color_override("font_color", state[1])
		col.add_child(word)

	var button := Button.new()
	button.theme_type_variation = "CardOverlay"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): day_pressed.emit(info.day))
	cell.add_child(button)
	return cell


func _cell_style(info: Dictionary) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var open: bool = info.day == selected
	box.bg_color = Palette.SURFACE_3 if open else (Palette.SURFACE_2 if info.today else Palette.SURFACE_PANEL)
	box.set_corner_radius_all(Palette.RADIUS)
	box.border_color = Palette.BORDER
	box.set_border_width_all(1)
	if info.today:
		box.border_color = Palette.ACCENT
		box.set_border_width_all(2)
	elif open:
		box.border_color = Palette.TEXT
		box.set_border_width_all(2)
	var side := 4 if Layout.compact else 8
	box.content_margin_left = side
	box.content_margin_right = side
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box
