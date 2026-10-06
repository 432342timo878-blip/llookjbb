class_name UIKit
## Small helpers for building screens in code, so all screens look consistent.


static func label(text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	return l


static func wrapped(text: String, variation := "MutedLabel") -> Label:
	var l := label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, primary := false, min_width := 140.0) -> Button:
	var b := Button.new()
	b.text = text
	# 44 px is a comfortable touch target; on a phone the width comes from the layout instead.
	b.custom_minimum_size = Vector2(minf(min_width, 100.0) if Layout.compact else min_width, 44)
	if primary:
		b.theme_type_variation = "PrimaryButton"
	return b


static func toggle(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.theme_type_variation = "ToggleButton"
	b.custom_minimum_size = Vector2(0, 44)
	return b


static func panel(content: Control, padding := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, mini(padding, 14) if Layout.compact else padding)
	m.add_child(content)
	p.add_child(m)
	return p


static func vbox(separation := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


## A row on wide screens and a column on a phone (BoxContainer.vertical follows the layout).
static func flex(separation := 16) -> BoxContainer:
	var b := BoxContainer.new()
	b.vertical = Layout.compact
	b.add_theme_constant_override("separation", separation)
	return b


## Makes the control's children fill the width on a phone (buttons side by side get equal shares).
static func fill(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Colour for a 1–20 attribute value, Football Manager style.
static func attr_color(value: float) -> Color:
	var v := roundi(value)
	if v >= 16:
		return Palette.ATTR_EXCELLENT
	if v >= 11:
		return Palette.ATTR_GOOD
	if v >= 6:
		return Palette.ATTR_AVERAGE
	return Palette.ATTR_POOR


## One "Name ........ ↑ 12" row as used in attribute panels. `trend`: -1, 0 or +1 (arrow).
## With a `description`, tapping (or clicking) the row shows it underneath, so it works without hovering.
static func attr_row(attr_name: String, value: float, trend := 0, description := "") -> Control:
	var row := hbox(8)
	row.custom_minimum_size.y = 34
	var name_label := label(attr_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	row.add_child(trend_arrow(trend))
	row.add_child(attr_value_label(value))
	return tap_to_explain(row, description)


## Wraps `row` so that a tap/click on it shows or hides `description` underneath (no hover needed).
## Returns `row` itself when there is nothing to explain.
static func tap_to_explain(row: Control, description: String) -> Control:
	if description == "":
		return row
	var box := vbox(2)
	box.add_child(row)
	var text := wrapped(description, "MutedLabel")
	text.visible = false
	box.add_child(text)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var press := {"at": Vector2.ZERO}
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press.at = event.position
			elif event.position.distance_to(press.at) < 10.0:   # a tap, not a scroll drag
				text.visible = not text.visible)
	return box


static func trend_arrow(trend: int) -> Label:
	var l := label("↑" if trend > 0 else ("↓" if trend < 0 else ""))
	l.add_theme_color_override("font_color", Palette.ATTR_EXCELLENT if trend > 0 else Palette.ATTR_POOR)
	l.custom_minimum_size = Vector2(14, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func attr_value_label(value: float) -> Label:
	var l := label(str(roundi(value)), "AttrValueLabel")
	l.add_theme_color_override("font_color", attr_color(value))
	l.custom_minimum_size = Vector2(28, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## A "Key ........ value" row (key muted on the left, the value control on the right).
static func fact_row(key: String, value: Control) -> HBoxContainer:
	var row := hbox()
	var k := label(key, "MutedLabel")
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.custom_minimum_size.x = 140
	row.add_child(k)
	row.add_child(value)
	return row


## "Tired (52)" in the colour of that fatigue state.
static func fatigue_label(fatigue: float) -> Label:
	var state := Training.fatigue_state(fatigue)
	var l := label("%s (%d)" % [state[0], roundi(fatigue)])
	l.add_theme_color_override("font_color", state[1])
	return l


static func attr_name(id: String) -> String:
	for attr in Data.attributes:
		if attr.id == id:
			return attr.name
	return id


## A small round or rounded-rectangle colour mark (fatigue dot, session marker).
static func dot(color: Color, width := 10.0, height := -1.0) -> Panel:
	var p := Panel.new()
	var h := width if height < 0.0 else height
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(minf(width, h) / 2.0))
	p.add_theme_stylebox_override("panel", box)
	p.custom_minimum_size = Vector2(width, h)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func format_date(d: Dictionary) -> String:
	return "%d.%d.%d" % [d.day, d.month, d.year]
