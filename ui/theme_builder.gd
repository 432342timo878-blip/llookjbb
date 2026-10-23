class_name ThemeBuilder
## Builds the global dark theme in code, so every look-related value lives in one place.

const FONT_REGULAR := preload("res://assets/fonts/Inter-Regular.ttf")
const FONT_SEMIBOLD := preload("res://assets/fonts/Inter-SemiBold.ttf")
const FONT_BOLD := preload("res://assets/fonts/Inter-Bold.ttf")
# V1 (GDD 5 "Type"): Barlow Condensed for numbers only (OFL, assets/fonts/BarlowCondensed-LICENSE.txt).
const NUM_SEMIBOLD := preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const NUM_BOLD := preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
const NUM_EXTRABOLD := preload("res://assets/fonts/BarlowCondensed-ExtraBold.ttf")

static var _number_fonts := {}
static var _section_font: FontVariation


## A Barlow Condensed face with tabular figures (OpenType `tnum`), so digits line up in columns (GDD 5: L1 checks the font has
## it: tools/v1_check.gd measures "1" and "8").
static func number_font(base: Font) -> FontVariation:
	if not _number_fonts.has(base):
		var f := FontVariation.new()
		f.base_font = base
		f.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
		_number_fonts[base] = f
	return _number_fonts[base]


## Inter Bold with +1 px between letters: the section labels ("LAST WEEK").
static func section_font() -> FontVariation:
	if _section_font == null:
		_section_font = FontVariation.new()
		_section_font.base_font = FONT_BOLD
		_section_font.spacing_glyph = 1
	return _section_font


## `compact` = phone portrait: slightly larger body text, smaller title.
static func build(compact := false) -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT_REGULAR
	theme.default_font_size = Palette.FONT_SIZE + (1 if compact else 0)

	theme.set_color("font_color", "Label", Palette.TEXT)

	# Label variations: use via `label.theme_type_variation = "TitleLabel"` etc.
	_label_variation(theme, "TitleLabel", FONT_BOLD, 32 if compact else 44, Palette.TEXT)
	_label_variation(theme, "HeadingLabel", FONT_SEMIBOLD, 22, Palette.TEXT)
	_label_variation(theme, "SubheadingLabel", FONT_SEMIBOLD, 17, Palette.TEXT)
	_label_variation(theme, "MutedLabel", FONT_REGULAR, 16 if compact else 15, Palette.TEXT_MUTED)
	_label_variation(theme, "CaptionLabel", FONT_SEMIBOLD, 13, Palette.TEXT_FAINT)
	_label_variation(theme, "AttrValueLabel", FONT_BOLD, 17 if compact else 16, Palette.TEXT)
	# V1's scale (GDD 5 "Type", PC / compact) for the new screens (the planner first); the old variations above keep their sizes
	# until the restyle session.
	_label_variation(theme, "DisplayNumber", number_font(NUM_EXTRABOLD), 48 if compact else 64, Palette.TEXT)
	_label_variation(theme, "BigNumber", number_font(NUM_BOLD), 26 if compact else 22, Palette.TEXT)
	_label_variation(theme, "ChipNumber", number_font(NUM_BOLD), 18 if compact else 16, Palette.TEXT)
	_label_variation(theme, "NameLabel", FONT_BOLD, 22 if compact else 20, Palette.TEXT)
	_label_variation(theme, "CardHeading", FONT_SEMIBOLD, 18 if compact else 15, Palette.TEXT)
	_label_variation(theme, "BodyLabel", FONT_REGULAR, 17 if compact else 14, Palette.TEXT)
	_label_variation(theme, "ItemLabel", FONT_SEMIBOLD, 16 if compact else 13, Palette.TEXT)
	_label_variation(theme, "WhyLabel", FONT_REGULAR, 14 if compact else 12, Palette.TEXT_MUTED)
	_label_variation(theme, "SectionLabel", section_font(), 13 if compact else 12, Palette.TEXT_MUTED)

	theme.set_stylebox("panel", "PanelContainer", _box(Palette.SURFACE_PANEL, Palette.BORDER))
	theme.set_stylebox("panel", "Panel", _box(Palette.SURFACE_PANEL, Palette.BORDER))

	_button(theme, "Button", Palette.SURFACE_2, Palette.SURFACE_3, Palette.BG, Palette.TEXT, Palette.BORDER)
	theme.set_type_variation("PrimaryButton", "Button")
	_button(theme, "PrimaryButton", Palette.ACCENT, Palette.ACCENT_HOVER, Palette.ACCENT_PRESSED, Color.WHITE)
	theme.set_font("font", "PrimaryButton", FONT_BOLD)
	# V1: a flat button that is only its content (a planner day, a chip, a slot): the hover tint and the focus ring.
	theme.set_type_variation("FlatButton", "Button")
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color.TRANSPARENT
	flat.set_corner_radius_all(Palette.RADIUS_RAISED)
	var flat_hover := flat.duplicate() as StyleBoxFlat
	flat_hover.bg_color = Color(1, 1, 1, 0.04)
	for state in ["normal", "pressed", "disabled"]:
		theme.set_stylebox(state, "FlatButton", flat)
	for state in ["hover", "hover_pressed"]:
		theme.set_stylebox(state, "FlatButton", flat_hover)
	theme.set_stylebox("focus", "FlatButton", _focus_box())

	# Selectable option (gender, answers, events): highlighted border when chosen.
	theme.set_type_variation("ToggleButton", "Button")
	_button(theme, "ToggleButton", Palette.SURFACE_2, Palette.SURFACE_3, Palette.SURFACE_3, Palette.TEXT)
	var selected := _box(Palette.SURFACE_3, Palette.ACCENT)
	selected.set_border_width_all(2)
	theme.set_stylebox("pressed", "ToggleButton", selected)
	theme.set_stylebox("hover_pressed", "ToggleButton", selected)
	theme.set_constant("h_separation", "ToggleButton", 10)

	_tab_buttons(theme)
	_card_overlay(theme)

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
	theme.set_constant("v_separation", "PopupMenu", 14 if compact else 8)   # bigger touch targets in dropdowns
	var line := StyleBoxLine.new()
	line.color = Palette.BORDER
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 8)

	theme.set_stylebox("panel", "TooltipPanel", _box(Palette.SURFACE_3, Palette.BORDER))
	theme.set_color("font_color", "TooltipLabel", Palette.TEXT)
	return theme


## Tab bar buttons: flat, with a coloured line under (top bar) or over (bottom bar) the selected one.
static func _tab_buttons(theme: Theme) -> void:
	for type in ["TabButton", "BottomTabButton"]:
		var on_top: bool = type == "BottomTabButton"
		theme.set_type_variation(type, "Button")
		var flat := _tab_box(Color.TRANSPARENT, false, on_top)
		theme.set_stylebox("normal", type, flat)
		theme.set_stylebox("disabled", type, flat)
		theme.set_stylebox("hover", type, _tab_box(Palette.SURFACE_2, false, on_top))
		var selected := _tab_box(Color.TRANSPARENT, true, on_top)
		theme.set_stylebox("pressed", type, selected)
		theme.set_stylebox("hover_pressed", type, selected)
		theme.set_stylebox("focus", type, _focus_box())
		theme.set_font("font", type, FONT_SEMIBOLD)
		theme.set_color("font_color", type, Palette.TEXT_MUTED)
		theme.set_color("font_hover_color", type, Palette.TEXT)
		theme.set_color("font_focus_color", type, Palette.TEXT_MUTED)
		theme.set_color("font_pressed_color", type, Palette.TEXT)
		theme.set_color("font_hover_pressed_color", type, Palette.TEXT)
		theme.set_color("font_disabled_color", type, Palette.TEXT_FAINT)
		# V1: the phone's bottom bar has an icon over each name; the chosen tab's icon and name are ACCENT (GDD 5).
		for state in ["icon_normal_color", "icon_focus_color", "icon_disabled_color"]:
			theme.set_color(state, type, Palette.TEXT_MUTED)
		theme.set_color("icon_hover_color", type, Palette.TEXT)
		for state in ["icon_pressed_color", "icon_hover_pressed_color"]:
			theme.set_color(state, type, Palette.ACCENT if on_top else Palette.TEXT)
		if on_top:
			theme.set_color("font_pressed_color", type, Palette.ACCENT)
			theme.set_color("font_hover_pressed_color", type, Palette.ACCENT)
	# (the bottom bar: no line over the chosen tab, its colour says it)
	var plain := _tab_box(Color.TRANSPARENT, false, true)
	theme.set_stylebox("pressed", "BottomTabButton", plain)
	theme.set_stylebox("hover_pressed", "BottomTabButton", plain)


static func _tab_box(bg: Color, selected: bool, line_on_top: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	if selected:
		box.border_color = Palette.ACCENT
		if line_on_top:
			box.border_width_top = 3
		else:
			box.border_width_bottom = 3
	return box


## Invisible button laid over a ChoiceCard: only shows a hover tint and the focus ring.
static func _card_overlay(theme: Theme) -> void:
	theme.set_type_variation("CardOverlay", "Button")
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color.TRANSPARENT
	clear.set_corner_radius_all(Palette.RADIUS)
	var tint := StyleBoxFlat.new()
	tint.bg_color = Color(1, 1, 1, 0.04)
	tint.set_corner_radius_all(Palette.RADIUS)
	for state in ["normal", "pressed", "disabled", "hover_pressed"]:
		theme.set_stylebox(state, "CardOverlay", clear)
	theme.set_stylebox("hover", "CardOverlay", tint)
	theme.set_stylebox("focus", "CardOverlay", _focus_box())


## Panel look for a ChoiceCard (selected = accent border).
static func card_box(selected: bool) -> StyleBoxFlat:
	var box := _box(Palette.SURFACE_3 if selected else Palette.SURFACE_2, Palette.ACCENT if selected else Palette.BORDER)
	box.set_border_width_all(2 if selected else 1)
	return box


static func _label_variation(theme: Theme, name: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


## V1 buttons (GDD 5 "Panels and cards"): radius 6; the secondary (default) button has a BORDER line.
static func _button(theme: Theme, type: String, normal: Color, hover: Color, pressed: Color, text: Color, line := Color.TRANSPARENT) -> void:
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", Palette.SURFACE]]:
		var box := _box(pair[1], line)
		box.set_corner_radius_all(Palette.RADIUS_RAISED)
		theme.set_stylebox(pair[0], type, box)
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


# --- V1 style boxes (GDD 5 "Panels and cards": three levels, never more than two nested) -----------------------------------

## Panel: SURFACE, 1 px BORDER, radius 8, padding 12. A column or a block of the screen.
static func panel_box(padding := 12, bg := Palette.SURFACE, line := Palette.BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(Palette.RADIUS)
	if line.a > 0.0:
		box.border_color = line
		box.set_border_width_all(1)
	box.set_content_margin_all(padding)
	return box


## Raised: SURFACE_2, radius 6, no border. Chips, facts, rows inside a panel.
static func raised_box(padding := 10, bg := Palette.SURFACE_2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(Palette.RADIUS_RAISED)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding - 3
	box.content_margin_bottom = padding - 3
	return box


## Callout: a panel with a 3 px left edge in its meaning colour (WARN = the coach's note, PEOPLE = an invitation, ACCENT = needs
## you). The only cards with buttons.
static func callout_box(edge: Color, padding := 12) -> StyleBoxFlat:
	# (one border colour per StyleBoxFlat: a faint tint of the colour all round, and CalloutCard draws the 3 px left edge in full)
	var box := panel_box(padding, Palette.SURFACE, edge.lerp(Palette.BORDER, 0.65))
	box.border_width_left = 3
	box.content_margin_left = padding + 2
	return box


## Strap (race and results only, broadcast shapes): radius 0-2, skewed -8 degrees.
static func strap_box(bg := Palette.LEAD, skew := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(2)
	if skew:
		box.skew = Vector2(-0.14, 0.0)   # tan(8 degrees)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Palette.ACCENT
	box.set_border_width_all(2)
	box.set_corner_radius_all(Palette.RADIUS)
	return box
