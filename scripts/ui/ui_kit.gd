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
	b.custom_minimum_size = Vector2(min_width, 44)
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


static func panel(content: Control, padding := 20) -> PanelContainer:
	var p := PanelContainer.new()
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, padding)
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
static func attr_row(attr_name: String, value: float, trend := 0) -> HBoxContainer:
	var row := hbox(8)
	var name_label := label(attr_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(trend_arrow(trend))
	row.add_child(attr_value_label(value))
	return row


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


static func format_date(d: Dictionary) -> String:
	return "%d.%d.%d" % [d.day, d.month, d.year]
