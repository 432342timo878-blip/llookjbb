class_name ThemeBuilder
## Builds the global dark theme in code, so every look-related value lives in one place.

const FONT_REGULAR := preload("res://assets/fonts/Inter-Regular.ttf")
const FONT_SEMIBOLD := preload("res://assets/fonts/Inter-SemiBold.ttf")
const FONT_BOLD := preload("res://assets/fonts/Inter-Bold.ttf")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT_REGULAR
	theme.default_font_size = Palette.FONT_SIZE

	theme.set_color("font_color", "Label", Palette.TEXT)

	# Label variations: use via `label.theme_type_variation = "TitleLabel"` etc.
	_label_variation(theme, "TitleLabel", FONT_BOLD, 44, Palette.TEXT)
	_label_variation(theme, "HeadingLabel", FONT_SEMIBOLD, 22, Palette.TEXT)
	_label_variation(theme, "SubheadingLabel", FONT_SEMIBOLD, 17, Palette.TEXT)
	_label_variation(theme, "MutedLabel", FONT_REGULAR, 15, Palette.TEXT_MUTED)
	_label_variation(theme, "CaptionLabel", FONT_SEMIBOLD, 12, Palette.TEXT_FAINT)
	_label_variation(theme, "AttrValueLabel", FONT_BOLD, 16, Palette.TEXT)

	theme.set_stylebox("panel", "PanelContainer", _box(Palette.SURFACE, Palette.BORDER))
	theme.set_stylebox("panel", "Panel", _box(Palette.SURFACE, Palette.BORDER))

	_button(theme, "Button", Palette.SURFACE_2, Palette.SURFACE_3, Palette.BG, Palette.TEXT)
	theme.set_type_variation("PrimaryButton", "Button")
	_button(theme, "PrimaryButton", Palette.ACCENT, Palette.ACCENT_HOVER, Palette.ACCENT_PRESSED, Color.WHITE)

	# Selectable option (gender, answers, events): highlighted border when chosen.
	theme.set_type_variation("ToggleButton", "Button")
	_button(theme, "ToggleButton", Palette.SURFACE_2, Palette.SURFACE_3, Palette.SURFACE_3, Palette.TEXT)
	var selected := _box(Palette.SURFACE_3, Palette.ACCENT)
	selected.set_border_width_all(2)
	theme.set_stylebox("pressed", "ToggleButton", selected)
	theme.set_stylebox("hover_pressed", "ToggleButton", selected)
	theme.set_constant("h_separation", "ToggleButton", 10)

	var field := _box(Palette.BG, Palette.BORDER)
	theme.set_stylebox("normal", "LineEdit", field)
	var field_focus := _box(Palette.BG, Palette.ACCENT)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_color("font_color", "LineEdit", Palette.TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Palette.TEXT_FAINT)

	_button(theme, "OptionButton", Palette.SURFACE_2, Palette.SURFACE_3, Palette.BG, Palette.TEXT)
	theme.set_stylebox("panel", "PopupMenu", _box(Palette.SURFACE_2, Palette.BORDER))
	theme.set_stylebox("hover", "PopupMenu", _box(Palette.SURFACE_3))
	theme.set_color("font_color", "PopupMenu", Palette.TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Palette.TEXT)
	theme.set_constant("v_separation", "PopupMenu", 8)

	theme.set_stylebox("panel", "TooltipPanel", _box(Palette.SURFACE_3, Palette.BORDER))
	theme.set_color("font_color", "TooltipLabel", Palette.TEXT)
	return theme


static func _label_variation(theme: Theme, name: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


static func _button(theme: Theme, type: String, normal: Color, hover: Color, pressed: Color, text: Color) -> void:
	theme.set_stylebox("normal", type, _box(normal))
	theme.set_stylebox("hover", type, _box(hover))
	theme.set_stylebox("pressed", type, _box(pressed))
	theme.set_stylebox("disabled", type, _box(Palette.SURFACE))
	theme.set_stylebox("focus", type, _focus_box())
	theme.set_font("font", type, FONT_SEMIBOLD)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, Palette.TEXT_FAINT)


static func _box(bg: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(Palette.RADIUS)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(1)
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Palette.ACCENT
	box.set_border_width_all(2)
	box.set_corner_radius_all(Palette.RADIUS)
	return box
