class_name Palette
## Colour and size tokens for the whole UI. Change colours here, not in screens.
## V1 (GDD 5 "The look (V1)", session L1a): "Stadium Night": the values of the style guide's table; the names that existed kept,
## the new tokens added. Dark only for now: a light mode later swaps these values without touching the screens.

const BG := Color("#0e1117")          # screen background
const TOP_BAR := Color("#12161d")     # the header bar and the phone's bottom tab bar
const SURFACE := Color("#161a22")     # panels (opaque on data screens)
const SURFACE_PANEL := Color(0.086, 0.102, 0.133, 0.94)   # panels over a photo (a hint of it shows through): big moments only
const SURFACE_2 := Color("#1e232d")   # raised things inside a panel: chips, facts, rows, buttons
const SURFACE_3 := Color("#272d39")   # hover
const DAY := Color("#181c25")         # a planner day column
const BORDER := Color("#262c39")      # panel and day borders
const DIVIDER := Color("#232936")     # the header's divider line (GDD 5 calls it LINE; that name is the stadium's lines below)
const TEXT := Color("#e9ecf2")
const TEXT_MUTED := Color("#8d95a7")
const TEXT_FAINT := Color("#5c6476")  # captions, slot markers and dividers only, never information
const ACCENT := Color("#ff5a36")      # athletics-track orange: the one action colour
const ACCENT_HOVER := Color("#ff7656")
const ACCENT_PRESSED := Color("#e04a29")
const LEAD := Color("#ffc83d")        # race and results only: the position box, PB / SB tags, the race card's section marks
const LEAD_TEXT := Color("#0a0e19")   # text on LEAD
const GOOD := Color("#3ddc84")        # bands and deltas: better / fine
const WARN := Color("#e9b949")        # near a line
const BAD := Color("#ef5b4f")         # at or over a line, worse
const PEOPLE := Color("#5fd0c4")      # invitations and slots something landed on
const PEOPLE_BG := Color(0.373, 0.816, 0.769, 0.10)
const BAR_TRACK := Color("#2a303c")   # the empty part of a bar
const COACH := Color("#3f8f6a")       # the coach's avatar
const TRACK := Color("#c2452d")       # track surface in drawings
const INFIELD := Color("#1f3a2e")     # grass in drawings

const RADIUS := 8
const RADIUS_RAISED := 6
const FONT_SIZE := 16

# Stadium drawing (waits for R6)
const TRACK_APRON := Color("#a63d28")
const GRASS_LIGHT := Color("#2e5a43")
const GRASS_DARK := Color("#29513d")
const STAND := Color("#262b37")
const CONCOURSE := Color("#1d212b")
const ROOF := Color("#323947")
const SAND := Color("#cdb27e")
const MAT := Color("#2f6db5")
const LINE := Color(1, 1, 1, 0.55)
const FLOODLIGHT := Color("#fff4d6")

# Day intensity: the day's top line, its session icons, the phone row's left edge
const DAY_EASY := Color("#5fb0e8")
const DAY_NORMAL := Color("#a0a8b9")
const DAY_HARD := Color("#ef6a5b")
const DAY_REST := Color("#3a4152")

# Health (soreness levels, injury tiers, plan risk): on V1's three bands
const SORE_1 := WARN                  # a bit sore
const SORE_2 := Color("#f0883e")      # sore (between the two)
const SORE_3 := BAD                   # painful
const TIER_NIGGLE := WARN
const TIER_INJURY := Color("#f0883e")
const TIER_SERIOUS := BAD
const TIER_ILLNESS := DAY_EASY
const RISK_LOW := GOOD
const RISK_MODERATE := WARN
const RISK_HIGH := BAD

# School (test chips, calendar bands, session S2)
const SCHOOL_OFF := Color(0.13, 0.25, 0.31, 0.94)    # a holiday or break day (a cool teal tint)
const SCHOOL_TEST := Color("#c7a4ef")                # a test (violet)
const SCHOOL_TEST_BG := Color(0.710, 0.545, 0.878, 0.14)
const SCHOOL_BAND := Color("#5fb3c4")                # a break on the Calendar (teal)

# Attribute value colours (1-5 / 6-10 / 11-15 / 16-20)
const ATTR_POOR := Color("#d9665b")
const ATTR_AVERAGE := Color("#e0b252")
const ATTR_GOOD := Color("#9ccc65")
const ATTR_EXCELLENT := Color("#3ddc84")


## The band colour of a value against a warning line (GDD 5 "Bars"): below line − 15 GOOD, up to the line WARN, at or over BAD.
static func band(value: float, warning: float) -> Color:
	if value >= warning:
		return BAD
	if value >= warning - 15.0:
		return WARN
	return GOOD


## A session's intensity colour ("easy" / "normal" / "hard"; a day without sessions is rest).
static func intensity(level: String, rest := false) -> Color:
	if rest:
		return DAY_REST
	match level:
		"easy": return DAY_EASY
		"hard": return DAY_HARD
	return DAY_NORMAL
