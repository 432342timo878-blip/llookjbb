class_name CauseChip
extends PanelContainer
## A change as a chip (GDD 5 "How text is cut down" 2, session L1a): an icon, a name, a value ("+0.3", "44 → 62 %", "▲") and one cause
## line of at most ~6 words ("hard Tuesday + race Saturday"). Raised (SURFACE_2, radius 6). Two shapes: a ROW (PC: the cause under the
## name) and a PILL (the phone's last-week chips: icon, name and value on one line, no cause). The value's colour is the meaning
## (GOOD better, BAD / WARN worse or near a line).

var icon := ""
var icon_color := Palette.TEXT_MUTED
var title := ""
var value := ""
var value_color := Palette.TEXT
var cause := ""
var pill := false


func _init(chip_icon := "", chip_title := "", chip_value := "", color := Palette.TEXT, chip_cause := "", as_pill := false) -> void:
	icon = chip_icon
	title = chip_title
	value = chip_value
	value_color = color
	icon_color = color if color != Palette.TEXT else Palette.TEXT_MUTED
	cause = chip_cause
	pill = as_pill
	add_theme_stylebox_override("panel", ThemeBuilder.raised_box(8 if as_pill else 10))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var col := UIKit.vbox(2)
	var row := UIKit.hbox(6)
	if icon != "":
		row.add_child(Icons.rect(icon, 16.0, icon_color))
	var name_label := UIKit.label(title, "ItemLabel")
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not pill:
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	if value != "":
		var v := UIKit.label(value, "ChipNumber")
		v.add_theme_color_override("font_color", value_color)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(v)
	col.add_child(row)
	if cause != "" and not pill:
		var c := UIKit.label(cause, "WhyLabel")
		c.clip_text = true
		c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(c)
	add_child(col)
