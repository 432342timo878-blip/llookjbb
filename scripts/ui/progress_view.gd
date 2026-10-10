class_name ProgressView
extends VBoxContainer
## The Progress page (playtest fix 7, 2026-10-10): the monthly record of the attributes and best times (ProgressLog), newest
## first, with a "since the start" summary on top. Tap a record to see every attribute and how it changed since the record
## before. A page of the career hub (opened from the Overview tab). Wide: two columns of attributes; phone: one.

signal back_pressed

var _rows: Array = []
var _open := 0                       # the row (index in _rows) that is open: 0 = Now


func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_rows = ProgressLog.rows(Game.athlete, Game.progress, Game.date)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var top := UIKit.hbox(12)
	var back := UIKit.button("◀ Overview", false, 140)
	back.custom_minimum_size.y = 44
	back.pressed.connect(func(): back_pressed.emit())
	top.add_child(back)
	var title := UIKit.label("Progress", "HeadingLabel")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	add_child(top)
	add_child(UIKit.wrapped("A record of your abilities and times, taken when your career started and at the end of every month. "
			+ "Tap a record to see how each attribute changed since the one before."))
	add_child(_summary())
	for i in _rows.size():
		add_child(_record(i))


## "Since the start": the ability, the personal best and the biggest attribute changes.
func _summary() -> Control:
	var now: Dictionary = _rows[0].rec
	var first: Dictionary = _rows[-1].rec
	var box := UIKit.vbox(6)
	if _rows.size() < 2:
		box.add_child(UIKit.label("SINCE THE START", "CaptionLabel"))
		box.add_child(UIKit.wrapped("The first monthly record comes at the end of this month."))
		return UIKit.panel(box, 16)
	box.add_child(UIKit.label("SINCE %s" % str(_rows[-1].title).to_upper(), "CaptionLabel"))
	var gain := float(now.ability) - float(first.ability)
	var best := "No race time yet."
	if float(first.pb) > 0.0 and float(now.pb) > 0.0:
		best = "Personal best: %s → %s." % [_time(float(first.pb)), _time(float(now.pb))]
	elif float(now.pb) > 0.0:
		best = "Personal best: %s." % _time(float(now.pb))
	box.add_child(UIKit.wrapped("800 m ability %.1f → %.1f (%s). %s" % [float(first.ability), float(now.ability), _signed(gain), best], ""))
	var parts := []
	for c in ProgressLog.changes(first, now, 5):
		parts.append("%s %s" % [UIKit.attr_name(c[0]), _signed(c[1])])
	if not parts.is_empty():
		box.add_child(UIKit.wrapped("Biggest changes: " + ", ".join(parts) + "."))
	return UIKit.panel(box, 16)


## One record: a tappable header with a one-line summary and, when open, all attributes with their change.
func _record(i: int) -> Control:
	var row: Dictionary = _rows[i]
	var rec: Dictionary = row.rec
	var open := i == _open
	var box := UIKit.vbox(6)
	var head := UIKit.hbox(8)
	head.custom_minimum_size.y = 44
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var title := UIKit.label(row.title, "SubheadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.clip_text = true
	head.add_child(title)
	var arrow := UIKit.label("▾" if open else "▸", "MutedLabel")
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(arrow)
	var press := {"at": Vector2.ZERO}
	head.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press.at = event.position
			elif event.position.distance_to(press.at) < 10.0:   # a tap, not a scroll drag
				_open = -1 if _open == i else i
				_build())
	box.add_child(head)
	var prev: Dictionary = row.prev
	var line := "800 m ability %.1f" % float(rec.ability)
	if not prev.is_empty():
		line += " (%s)" % _signed(float(rec.ability) - float(prev.ability))
	line += " · PB %s" % _time(float(rec.pb))
	var races: Dictionary = row.races
	if int(races.get("count", 0)) > 0:
		line += " · %d race%s this month, best %s" % [int(races.count), "" if int(races.count) == 1 else "s", _time(float(races.best))]
	box.add_child(UIKit.wrapped(line))
	if open:
		box.add_child(_attributes(rec, prev))
	return UIKit.panel(box, 16)


## Every attribute: value and the change since the record before (a dash when it hardly moved), by category.
func _attributes(rec: Dictionary, prev: Dictionary) -> Control:
	var out := UIKit.vbox(10)
	if prev.is_empty():
		out.add_child(UIKit.wrapped("No earlier record to compare with."))
	for category in ["physical", "technical", "mental"]:
		out.add_child(UIKit.label(category.to_upper(), "CaptionLabel"))
		var grid := GridContainer.new()
		grid.columns = 3 if Layout.compact else 6
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 4)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for attr in Data.attributes_in(category):
			var value := float(rec.attrs.get(attr.id, 0.0))
			var name_label := UIKit.label(attr.name)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.clip_text = true
			name_label.custom_minimum_size = Vector2(110, 30)
			grid.add_child(name_label)
			var v := UIKit.label("%.1f" % value)
			v.add_theme_color_override("font_color", UIKit.attr_color(value))
			v.custom_minimum_size.x = 36
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(v)
			var change := UIKit.label("")
			change.custom_minimum_size.x = 48
			change.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if not prev.is_empty():
				var d := value - float(prev.attrs.get(attr.id, value))
				if absf(d) >= 0.05:
					change.text = _signed(d)
					change.add_theme_color_override("font_color", Palette.ATTR_EXCELLENT if d > 0.0 else Palette.ATTR_POOR)
				else:
					change.text = "–"
					change.add_theme_color_override("font_color", Palette.TEXT_FAINT)
			grid.add_child(change)
		out.add_child(grid)
	return out


static func _signed(v: float) -> String:
	return ("+%.1f" % v) if v >= 0.05 else (("−%.1f" % absf(v)) if v <= -0.05 else "±0")


static func _time(seconds: float) -> String:
	return Calendar.format_time(seconds) if seconds > 0.0 else "–"
