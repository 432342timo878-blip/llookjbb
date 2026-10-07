class_name Layout
## Responsive layout state. main.gd decides the mode from the window size and sets `compact`;
## screens read it when they build and rebuild on `Router.layout_changed`.
##   wide    = PC / tablet landscape / phone landscape (1280x720-based layouts)
##   compact = phone portrait (about 480 px wide, everything stacked, bottom tab bar)

const WIDE_BASE := Vector2(1280, 720)
const COMPACT_WIDTH := 480.0
## Windows that are at least this wide relative to their height use the wide layout.
const WIDE_MIN_ASPECT := 1.1

static var compact := false
## Logical width of the window (set by main.gd); wide screens use it to keep content from stretching too far.
static var logical_width := 1280.0
## PC: the career hub's side panel (day editor or help) is open, so its pages get only ~690 px (set by the hub).
static var side_open := false


## The page content is phone-narrow: a phone, or PC beside the hub's side panel. Pages with wide rows (the Training
## tab's day rows, phase editor, season view) stack them when this is true.
static func stacked() -> bool:
	return compact or side_open


## Mode for a window of this size in pixels.
static func is_compact_for(window_px: Vector2) -> bool:
	return window_px.x < window_px.y * WIDE_MIN_ASPECT


## UI scale (window pixels per logical pixel) for the given window and mode.
static func scale_for(window_px: Vector2, compact_mode: bool) -> float:
	if compact_mode:
		return clampf(window_px.x / COMPACT_WIDTH, 0.7, 3.0)
	return maxf(minf(window_px.x / WIDE_BASE.x, window_px.y / WIDE_BASE.y), 0.7)


## Outer margin of a full screen: roomy on PC, tight on a phone.
## `max_content` (wide layout only) centres the content in at most that many pixels.
static func page_margin(m: MarginContainer, max_content := 0.0) -> void:
	var side := 16 if compact else 48
	if not compact and max_content > 0.0:
		side = maxi(side, roundi((logical_width - max_content) / 2.0))
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_top", 14 if compact else 32)
	m.add_theme_constant_override("margin_bottom", 10 if compact else 24)
