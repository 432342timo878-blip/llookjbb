class_name HelpButton
extends Button
## The "?" ("How this works") button of a screen (GDD 5 "Help"): 44 × 44, accent-coloured, with a small accent dot
## while its help entry is new (not read yet, or changed since). The screen sets `entry_id` to the help of what it
## shows and opens the help itself when the button is pressed (HelpPanel / HelpOverlay).

const GROUP := "help_buttons"   # Help.mark_seen refreshes every button in it

var entry_id := "":
	set(value):
		entry_id = value
		refresh()

var _dot: Panel


func _init(id := "") -> void:
	text = "?"
	custom_minimum_size = Vector2(44, 44)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_color_override("font_color", Palette.ACCENT)
	add_theme_color_override("font_hover_color", Palette.ACCENT_HOVER)
	add_theme_color_override("font_pressed_color", Palette.ACCENT_PRESSED)
	_dot = UIKit.dot(Palette.ACCENT, 10)
	_dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_dot.position = Vector2(-13, 3)   # (relative to the top-right anchor)
	add_child(_dot)
	add_to_group(GROUP)
	entry_id = id


func _ready() -> void:
	# The theme's button look with an accent border, so the "?" stands out a little from the other buttons.
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := get_theme_stylebox(state)
		if box is StyleBoxFlat:
			var accent := (box as StyleBoxFlat).duplicate() as StyleBoxFlat
			accent.border_color = Color(Palette.ACCENT, 0.75)
			accent.set_border_width_all(maxi(1, accent.border_width_top))
			add_theme_stylebox_override(state, accent)
	refresh()


## Shows or hides the "new" dot.
func refresh() -> void:
	if _dot:
		_dot.visible = entry_id != "" and Help.is_new(entry_id)
