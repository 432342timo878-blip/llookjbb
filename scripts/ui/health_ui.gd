class_name HealthUI
extends RefCounted
## The shared pieces of the health UI (M2 step 4, GDD 4.6 "Warning signs & UI"): soreness rows, injury blocks,
## the body-strain section for a plan, race warnings, "train through it" and "scratch" controls.
## It only reads HealthSystem (soreness, active, rule_at, plan_risk, ...) and uses its two UI actions
## (override_day, refresh); it never touches the model's numbers. When the health model is switched off
## (HealthSystem.model_enabled, dev tools), system() is null and every piece shows nothing.

const TIER_NAMES := {"niggle": "NIGGLE", "injury": "INJURY", "serious": "SERIOUS INJURY", "illness": "ILLNESS"}
const TIER_RANK := {"niggle": 1, "illness": 2, "injury": 3, "serious": 4}
const RISK_TEXT := {
	"low": "Your body should cope with this plan.",
	"moderate": "Some strain would build up. Watch for sore areas and plan lighter days.",
	"high": "Likely to overload you right now: expect niggles unless you build up to it gradually.",
}


## The health system, or null when the health model is off.
static func system() -> HealthSystem:
	if not HealthSystem.model_enabled:
		return null
	return Game.get_system("health") as HealthSystem


## Call after the weekly plan was edited: puts the injury limits into this week again.
static func refresh() -> void:
	var h := system()
	if h:
		h.refresh()


# --- Words and colours ---------------------------------------------------------------------------

static func level_color(level: int) -> Color:
	return [Palette.TEXT_MUTED, Palette.SORE_1, Palette.SORE_2, Palette.SORE_3][clampi(level, 0, 3)]


static func tier_color(tier: String) -> Color:
	match tier:
		"niggle": return Palette.TIER_NIGGLE
		"injury": return Palette.TIER_INJURY
		"serious": return Palette.TIER_SERIOUS
	return Palette.TIER_ILLNESS


static func risk_color(risk: String) -> Color:
	match risk:
		"low": return Palette.RISK_LOW
		"moderate": return Palette.RISK_MODERATE
	return Palette.RISK_HIGH


static func area_name(id: String) -> String:
	for a in HealthSystem.areas():
		if a.id == id:
			return a.name
	return id


## The soreness word for a level, as the model words it ("A bit sore", "Sore", "Painful").
static func level_word(level: int) -> String:
	return HealthSystem.soreness_word(level)


## Areas that are at least a bit sore now: [{id, name, level, word}].
static func sore_areas() -> Array:
	var h := system()
	if h == null:
		return []
	return h.soreness().filter(func(x): return int(x.level) > 0)


## "about 12 days (around Sat 14 Nov)" for the expected return of an active injury (HealthSystem.active()).
static func return_text(x: Dictionary) -> String:
	var n := int(x.days_left)
	var span: String
	if n <= 1:
		span = "tomorrow"
	elif n < 14:
		span = "about %d days" % n
	else:
		span = "about %d weeks" % roundi(n / 7.0)
	if n <= 1:
		return span
	return "%s (around %s)" % [span, DayInfo.short_day(x.expected_return)]


## "1.5 %" / "2 %" for a share like 0.015.
static func percent_text(share: float) -> String:
	return ("%.1f" % (share * 100.0)).rstrip("0").rstrip(".") + " %"


## "105 %", or "over 300 %" when the number is huge (right after a layoff the body's "normal" is tiny).
static func load_text(percent: int) -> String:
	var cap := int(Data.health.ui.load_cap)
	return "over %d %%" % cap if percent > cap else "%d %%" % percent


## What a load vs normal means: {text, color}.
static func load_band(percent: int) -> Dictionary:
	var ui: Dictionary = Data.health.ui
	var free := roundi(float(Data.health.strain.spike.free_ratio) * 100.0)
	if percent < int(ui.load_low):
		return {"text": "A lighter week than your body is used to.", "color": Palette.TEXT_MUTED}
	if percent <= free:
		return {"text": "About what your body is used to.", "color": Palette.RISK_LOW}
	if percent <= int(ui.load_high):
		return {"text": "A step up: your body needs a few weeks to adapt to more load.", "color": Palette.RISK_MODERATE}
	return {"text": "A big jump. Sudden jumps in load are how most overuse injuries start: build up gradually instead.",
			"color": Palette.RISK_HIGH}


## The worst tier among injury ids ("" when there are none).
static func worst_tier(ids: Array) -> String:
	var best := ""
	for id in ids:
		var tier: String = Data.get_injury(str(id)).get("tier", "")
		if tier != "" and int(TIER_RANK.get(tier, 0)) > int(TIER_RANK.get(best, 0)):
			best = tier
	return best


# --- Soreness and injuries (Today card, sore panel) -------------------------------------------------

## A card with a head row that is always shown and a detail block that opens on a tap; the whole card is the
## button (at least 44 px high), so it works without hovering. `top_row` gets the ▸ marker; `body` (may be null)
## is always visible under it. `on_toggle(is_open)` lets the caller remember the state.
static func expandable(top_row: HBoxContainer, body: Control, detail: Control, color: Color,
		start_open := false, on_toggle := Callable()) -> Control:
	var inner := UIKit.vbox(5)
	var arrow := UIKit.label("▾" if start_open else "▸", "MutedLabel")
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(arrow)
	inner.add_child(top_row)
	if body != null:
		inner.add_child(body)
	detail.visible = start_open
	inner.add_child(detail)
	var card := UIKit.alert_panel(inner, color)
	card.custom_minimum_size.y = 44
	var button := Button.new()
	button.theme_type_variation = "CardOverlay"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func():
		detail.visible = not detail.visible
		arrow.text = "▾" if detail.visible else "▸"
		if on_toggle.is_valid():
			on_toggle.call(detail.visible))
	card.add_child(button)
	return card


## One row per body area that is at least a bit sore (word + colour); tap a row for why and what helps.
## "No soreness" when there is none. `open` (area id -> bool) remembers which rows are open.
static func soreness_list(open: Dictionary) -> Control:
	var h := system()
	var sore := sore_areas()
	if h == null or sore.is_empty():
		return UIKit.wrapped("No soreness. Your body feels fine.", "MutedLabel")
	var box := UIKit.vbox(6)
	for x in sore:
		box.add_child(soreness_row(h, x, open))
	box.add_child(UIKit.wrapped("Tap an area to see why it's sore and what helps. \"A bit sore\" is your early warning.", "MutedLabel"))
	return box


static func soreness_row(h: HealthSystem, x: Dictionary, open: Dictionary, start_open := false) -> Control:
	var level := int(x.level)
	var color := level_color(level)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.dot(color, 12))
	var name_label := UIKit.label(x.name, "SubheadingLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	head.add_child(name_label)
	var word := UIKit.label(x.word)
	word.add_theme_color_override("font_color", color)
	head.add_child(word)

	var detail := UIKit.vbox(4)
	detail.add_child(UIKit.wrapped(str(Data.health.ui.soreness_hints[level]), ""))
	var info := h.soreness_info(x.id)
	if not info.causes.is_empty():
		detail.add_child(UIKit.label("WHY", "CaptionLabel"))
		for cause in info.causes:
			detail.add_child(UIKit.wrapped("• " + cause, ""))
	if info.helps != "":
		detail.add_child(UIKit.label("WHAT HELPS", "CaptionLabel"))
		detail.add_child(UIKit.wrapped(info.helps, ""))
	return expandable(head, null, detail, color, bool(open.get(x.id, start_open)),
			func(is_open): open[x.id] = is_open)


## An active injury or illness (HealthSystem.active() entry): tier, name, phase, what's allowed, expected
## return and whether it can be trained through; tap for the plain explanation.
static func injury_block(x: Dictionary, start_open := false) -> Control:
	var color := tier_color(x.tier)
	var tag: String = TIER_NAMES[x.tier]
	if x.area_name != "":
		tag += " · " + str(x.area_name).to_upper()
	if x.escalated:
		tag += " · GOT WORSE"
	var top := UIKit.hbox(8)
	var tag_label := UIKit.label(tag, "CaptionLabel")
	tag_label.add_theme_color_override("font_color", color)
	tag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_label.clip_text = true
	top.add_child(tag_label)

	var body := UIKit.vbox(3)
	body.add_child(UIKit.wrapped(x.name, "SubheadingLabel"))
	body.add_child(UIKit.wrapped("Phase: %s" % x.phase_name, ""))
	body.add_child(UIKit.wrapped("Allowed now: %s" % capitalise(x.allowed), ""))
	body.add_child(UIKit.wrapped("Expected back: %s" % return_text(x), ""))
	body.add_child(through_line(x))

	var detail := UIKit.wrapped(x.description, "MutedLabel")
	return expandable(top, body, detail, color, start_open)


## "Locked: …" / "You can train through it, but …" for an active injury.
static func through_line(x: Dictionary) -> Label:
	var text: String
	var color: Color
	if x.locked:
		text = "Locked: this can't be trained through, and you can't race."
		color = Palette.SORE_3
	elif x.tier == "illness":
		text = "You can train through it, but it isn't a good idea. Racing ill makes you slower."
		color = Palette.SORE_1
	else:
		text = "You can train through it, but it may get worse."
		color = Palette.SORE_1
	var l := UIKit.wrapped(text, "")
	l.add_theme_color_override("font_color", color)
	return l


static func capitalise(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


## The "WARNING SIGNS" and "INJURY & ILLNESS" sections side by side (stacked on a phone), for the Today card.
## `open` remembers which soreness rows are open. Null when the health model is off.
static func warning_sections(open: Dictionary) -> Control:
	var h := system()
	if h == null:
		return null
	var columns := UIKit.flex(24 if not Layout.compact else 14)
	var left := UIKit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UIKit.label("WARNING SIGNS", "CaptionLabel"))
	left.add_child(soreness_list(open))

	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.label("INJURY & ILLNESS", "CaptionLabel"))
	var active := h.active()
	if active.is_empty():
		right.add_child(UIKit.wrapped("None. You're healthy.", "MutedLabel"))
	for x in active:
		right.add_child(injury_block(x))
	# On a phone the sections are stacked: an injury matters more than a row of sore areas, so it comes first.
	if Layout.compact and not active.is_empty():
		columns.add_child(right)
		columns.add_child(left)
	else:
		columns.add_child(left)
		columns.add_child(right)
	return columns


# --- The plan: load vs normal and risk (Training tab) ------------------------------------------------

## "BODY STRAIN" for a weekly plan (any plan: the repeating weekly one now, a phase's plan with periodization):
## load vs your normal (a %, capped), the plan risk word Low / Moderate / High, each explained. With `week`
## (the current week, with its day changes) a third line shows how this week stands. Null when the model is off.
static func plan_section(plan: Array, week: WeekSim = null) -> Control:
	var h := system()
	if h == null:
		return null
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label("BODY STRAIN", "CaptionLabel"))
	var plan_week := WeekSim.new(Game.athlete, plan, Game.week_monday())   # nothing played, no day changes
	box.add_child(_load_row("Load vs your normal", h.load_vs_normal(plan_week), true))
	var risk := h.plan_risk(plan)
	var risk_label := UIKit.label(HealthSystem.RISK_NAMES[risk])
	risk_label.add_theme_color_override("font_color", risk_color(risk))
	var risk_box := UIKit.vbox(2)
	risk_box.add_child(UIKit.fact_row("Plan risk", risk_label))
	risk_box.add_child(UIKit.wrapped("%s It depends on how your body is right now: the same plan can be Low once you've built up to it." % RISK_TEXT[risk]))
	box.add_child(risk_box)
	if week != null and (week.day > 0 or not week.changes.is_empty()):
		box.add_child(_load_row("This week, with your changes", h.load_vs_normal(week), false))
	return box


static func _load_row(key: String, percent: int, explain: bool) -> Control:
	var band := load_band(percent)
	var col := UIKit.vbox(2)
	var value := UIKit.label(load_text(percent))
	value.add_theme_color_override("font_color", band.color)
	col.add_child(UIKit.fact_row(key, value))
	if explain:
		col.add_child(UIKit.wrapped("%s Your normal = the average week of your last four." % band.text))
	return col


# --- Racing and training through -----------------------------------------------------------------------

## How fit the athlete is to race on day `d` of the current week:
## {state: "fit" / "limited" / "locked", reasons, slowdown (share slower; only known for today, else -1)}.
static func race_outlook(d: int) -> Dictionary:
	var h := system()
	if h == null:
		return {"state": "fit", "reasons": [], "slowdown": 0.0}
	var k := maxi(1, d - Game.current_week().day + 1)
	var rule := h.rule_at(k)
	var state := "fit"
	if rule.active:
		state = "locked" if rule.locked else "limited"
	return {"state": state, "reasons": rule.reasons, "slowdown": h.race_slowdown() if k == 1 else -1.0}


## The warning for a race day: can't race (locked) / racing injured (slower, may get worse). Null when fit.
## `today`: the race is today (then the slowdown can be told); otherwise it depends on how the recovery goes.
static func race_card(o: Dictionary, today: bool) -> Control:
	if o.state == "fit":
		return null
	var box := UIKit.vbox(4)
	var color: Color
	if o.state == "locked":
		color = Palette.SORE_3
		box.add_child(UIKit.wrapped("You can't race like this" if today else "You're not fit to race on this day", "SubheadingLabel"))
		box.add_child(UIKit.wrapped("\n".join(o.reasons), ""))
		box.add_child(UIKit.wrapped(("You'll be withdrawn from the race when the day starts." if today
				else "If it's still so when the day comes, you'll be withdrawn from the race automatically."), ""))
	else:
		color = Palette.SORE_1
		box.add_child(UIKit.wrapped("Racing injured" if today else "You'd be racing injured", "SubheadingLabel"))
		box.add_child(UIKit.wrapped("\n".join(o.reasons), ""))
		var slower := ""
		if today and float(o.slowdown) > 0.0:
			slower = " (about %s on your time)" % percent_text(float(o.slowdown))
		box.add_child(UIKit.wrapped(("You can start, but you'll run slower%s and it may get worse. " % slower)
				+ "Or scratch from the race and let it heal.", ""))
	return UIKit.alert_panel(box, color)


## A "Scratch from this race" button that asks once more before it withdraws you (Game.scratch_race).
## `on_done` is called afterwards.
static func scratch_control(meet: Dictionary, on_done: Callable) -> Control:
	var box := UIKit.vbox(8)
	var ask := UIKit.vbox(8)
	ask.visible = false
	ask.add_child(UIKit.wrapped("Withdraw from %s? You won't start, and the day becomes a training day." % meet.name, ""))
	var row := _button_row()
	var yes := UIKit.button("Yes, scratch", true, 100)
	yes.pressed.connect(func():
		Game.scratch_race(meet.key)
		on_done.call())
	var no := UIKit.button("Keep my entry", false, 100)
	row.add_child(yes)
	row.add_child(no)
	ask.add_child(row)
	var start := UIKit.button("Scratch from this race", false, 200)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(func():
		start.visible = false
		ask.visible = true)
	no.pressed.connect(func():
		ask.visible = false
		start.visible = true)
	box.add_child(start)
	box.add_child(ask)
	return box


## A row of buttons that wraps onto a second line when the space is short (a narrow side panel);
## on a phone the buttons are stacked, each the full width.
static func _button_row() -> Container:
	if Layout.compact:
		return UIKit.vbox(8)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	return row


## What training through the limits means, one line per active problem (for the "Train through it" warning).
static func through_lines(h: HealthSystem) -> Array:
	var lines := []
	var extend := int(Data.health.escalation.extend_days)
	for x in h.active():
		if x.tier == "illness":
			lines.append("%s: training while you're ill isn't a good idea." % x.name)
			continue
		var line := "%s: every day you train through it puts more strain on the sore area and adds %d days to your recovery" % [x.name, extend]
		var worse := Data.get_injury(str(Data.get_injury(x.id).get("escalates_to", "")))
		if not worse.is_empty():
			line += ". It can turn into: %s" % worse.name
		lines.append(line + ".")
	return lines


## "Train through it…" for day `d` (the day goes back to the plan, by you): first a clear warning, then
## `on_done` after HealthSystem.override_day. Only offered where it's allowed (not locked); null otherwise.
static func through_control(d: int, on_done: Callable) -> Control:
	var h := system()
	if h == null or not h.can_override(d):
		return null
	var box := UIKit.vbox(8)
	var warn := UIKit.vbox(6)
	warn.visible = false
	var lines := UIKit.vbox(4)
	lines.add_child(UIKit.wrapped("Train through it?", "SubheadingLabel"))
	lines.add_child(UIKit.wrapped("You'd do the planned sessions even though your body says otherwise. "
			+ "You'll feel it, and it can get worse.", ""))
	for line in through_lines(h):
		lines.add_child(UIKit.wrapped("• " + line, ""))
	warn.add_child(UIKit.alert_panel(lines, Palette.SORE_3))
	var row := _button_row()
	var yes := UIKit.button("Train through it anyway", false, 100)
	yes.pressed.connect(func():
		if h.override_day(d):
			on_done.call())
	var no := UIKit.button("Keep the limits", true, 100)
	row.add_child(yes)
	row.add_child(no)
	warn.add_child(row)
	var start := UIKit.button("Train through it…", false, 200)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(func():
		start.visible = false
		warn.visible = true)
	no.pressed.connect(func():
		warn.visible = false
		start.visible = true)
	box.add_child(start)
	box.add_child(warn)
	return box


## Is the player training through the limits on day `d` of the current week?
static func is_overridden(d: int) -> bool:
	var h := system()
	if h == null:
		return false
	return Calendar.date_key(Game.add_days(Game.current_week().monday, d)) in h.overrides


## Why session `id` can't be done on day `d` ("" = fine, or the day is trained through).
static func ban_reason(id: String, d: int) -> String:
	var h := system()
	if h == null or is_overridden(d):
		return ""
	return h.ban_reason(id, d)


## The note after repeated injuries (proneness stays hidden): a Control, or null.
static func proneness_note() -> Control:
	var h := system()
	if h == null or not h.proneness_hint():
		return null
	var box := UIKit.vbox(4)
	box.add_child(UIKit.wrapped("You seem to pick up knocks easily", "SubheadingLabel"))
	box.add_child(UIKit.wrapped("A few injuries within a year: your body may need more recovery and a more gradual "
			+ "build-up than other runners. Watch the warning signs closely.", ""))
	return UIKit.alert_panel(box, Palette.SORE_1)
