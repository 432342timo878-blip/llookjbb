class_name CausesUI
extends RefCounted
## The rows of WeekCauses on screen (session L2b, GDD 5 "How text is cut down" 2-4): a change as a chip (icon, name, value, one
## cause line) that opens its exact numbers on a tap (no hover), a list of 5 + "+N more", the phone's pills with one detail
## under them, and the report's full-width rows. Reading only: nothing here changes the game.


static func color_of(tone: String) -> Color:
	return RaceRecapView.tone_color(tone)


## A tappable chip (PC, the planner's left column): 44 px or more; a tap shows / hides the detail lines under it.
## `use_short` = the planner's value ("+0.1") instead of the full one ("+0.08").
static func chip(row: Dictionary, use_short := false) -> Control:
	var value := str(row.get("short", row.value)) if use_short else str(row.value)
	var c := CauseChip.new(str(row.icon), str(row.title), value, color_of(str(row.tone)), str(row.cause))
	c.custom_minimum_size.y = 44
	c.set_meta("cause_row", str(row.kind) + ":" + str(row.id))
	return tappable(c, str(row.detail))


## A tap on `row` shows or hides `text` (lines) under it: WeekPlanner._tappable with the lines kept apart.
static func tappable(row: Control, text: String) -> Control:
	return WeekPlanner._tappable(row, text)


## The first `shown` rows as chips, the rest behind "+N more" (a flat 44 px button that opens them in place; "Show less" closes).
static func chip_list(rows: Array, shown: int, use_short := false) -> Control:
	var box := UIKit.vbox(6)
	var rest := UIKit.vbox(6)
	rest.visible = false
	for i in rows.size():
		var ch := chip(rows[i], use_short)
		if i < shown:
			box.add_child(ch)
		else:
			rest.add_child(ch)
	if rest.get_child_count() > 0:
		box.add_child(rest)
		box.add_child(_more_button(rest, rest.get_child_count()))
	return box


static func _more_button(rest: Control, n: int) -> Button:
	var more_text := str(Data.causes.more).format({"n": n})
	var more := UIKit.button(more_text, false, 0.0)
	more.theme_type_variation = "FlatButton"
	more.custom_minimum_size.y = 44
	more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	more.name = "MoreCauses"
	more.pressed.connect(func():
		rest.visible = not rest.visible
		more.text = str(Data.causes.less) if rest.visible else more_text)
	return more


## The phone's last week: pills (icon, name, value; 44 px tall) in a flow, the first `shown` and "+N more"; a tap on a pill shows
## its cause and numbers in one box under the flow (a second tap on it closes it).
static func pill_list(rows: Array, shown: int) -> Control:
	var box := UIKit.vbox(8)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	box.add_child(flow)
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", ThemeBuilder.raised_box(10))
	var text := UIKit.wrapped("", "WhyLabel")
	detail.add_child(text)
	detail.visible = false
	var state := {"open": ""}
	var extra := []
	for i in rows.size():
		var row: Dictionary = rows[i]
		var p := CauseChip.new(str(row.icon), str(row.title), str(row.get("short", row.value)), color_of(str(row.tone)), "", true)
		p.custom_minimum_size.y = 44
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.set_meta("cause_row", str(row.kind) + ":" + str(row.id))
		var key := str(row.kind) + ":" + str(row.id)
		var body := str(row.cause) + ("\n" if str(row.cause) != "" else "") + str(row.detail)
		var press := {"at": Vector2.ZERO}
		p.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					press.at = event.position
				elif event.position.distance_to(press.at) < 10.0:
					if state.open == key and detail.visible:
						detail.visible = false
					else:
						state.open = key
						text.text = body
						detail.visible = true)
		if i >= shown:
			p.visible = false
			extra.append(p)
		flow.add_child(p)
	if not extra.is_empty():
		var more_text := str(Data.causes.more).format({"n": extra.size()})
		var more := UIKit.button(more_text, false, 0.0)
		more.theme_type_variation = "FlatButton"
		more.custom_minimum_size.y = 44
		more.name = "MoreCauses"
		more.pressed.connect(func():
			var show: bool = not extra[0].visible
			for p in extra:
				p.visible = show
			more.text = str(Data.causes.less) if show else more_text)
		flow.add_child(more)
	box.add_child(detail)
	return box


## A full-width row (the report, the result card): an icon square, the name and its cause, the value in its colour, a divider;
## a tap shows the exact numbers under it.
static func line_row(x: Dictionary) -> Control:
	var row := UIKit.hbox(12)
	row.custom_minimum_size.y = 48
	var icon_box := PanelContainer.new()
	icon_box.add_theme_stylebox_override("panel", ThemeBuilder.raised_box(6))
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var color := color_of(str(x.get("tone", "plain")))
	icon_box.add_child(Icons.rect(str(x.icon), 16.0, color if color != Palette.TEXT else Palette.TEXT_MUTED))
	row.add_child(icon_box)
	var col := UIKit.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UIKit.wrapped(str(x.title), "ItemLabel"))
	if str(x.get("cause", "")) != "":
		col.add_child(UIKit.wrapped(str(x.cause), "WhyLabel"))
	row.add_child(col)
	var v := UIKit.label(str(x.get("value", "")), "ChipNumber")
	v.add_theme_color_override("font_color", color)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	row.set_meta("cause_row", str(x.get("kind", "")) + ":" + str(x.get("id", "")))
	var wrap := UIKit.vbox(0)
	wrap.add_child(tappable(row, str(x.get("detail", ""))))
	var line := ColorRect.new()
	line.color = Palette.DIVIDER
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(line)
	return wrap


## A section of the report: its caps label, the rows (or `empty` when there are none and it is not "").
static func section(title: String, list: Array, empty := "") -> Control:
	if list.is_empty() and empty == "":
		return null
	var box := UIKit.vbox(2)
	box.add_child(UIKit.label(title, "SectionLabel"))
	if list.is_empty():
		box.add_child(UIKit.wrapped(empty, "WhyLabel"))
	for x in list:
		box.add_child(line_row(x))
	return box
