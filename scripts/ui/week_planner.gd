class_name WeekPlanner
extends VBoxContainer
## The Sunday-evening week planner (GDD 4.10 decision 1, look in GDD 5 "The look (V1)"; session L1a): the This week tab and the one
## place where the week is shown and changed. It opens every week (Play week ends on Sunday night and the hub shows it).
##   PC: three columns, 268 | rest | 290. LAST WEEK on the left (sessions done by the one "done", the race, what changed and why as
##       cause chips, the coach's one line: this column is the week report), the WEEK in the middle (a column per day with its
##       sessions in the intensity colour, races, tests, the coach's note marked; then the cards that wait for an answer and four
##       facts), BODY and MIND on the right (bars with % and the warning tick, Form, the moods as words with what they do) and Play
##       week. With the hub's side panel open (the day editor or the help) only the middle shows.
##   Phone: one column: last week (chips as pills), a body strip, the week as rows (a note opens under its day), the other cards,
##       the mind, the facts. Play week is sticky above the bottom bar (the hub puts `play_block` there).
## A tap on a day opens the day editor (the hub's), where "Ask the coach" is. The cards: the coach's notes (Make it easy / Keep
## mine, the Veto with its reasons), the moments that wait for Sunday, his meet suggestions, an unsettled meet-and-tests clash. The
## player decides: nothing here changes the week unless a button says so. Texts: data/planner.json; the look: Palette / ThemeBuilder.
## Session L1b: every day shows its free-time slot (HabitsUI.chip: PC at the bottom of the day column, phone an icon on the right of
## the row), faint unless something landed on it (an invitation, a late night before a race or a hard session). A tap opens the
## slot's picker (PC: first among the cards; phone: under its day); an invitation is a card with its price (PC: among the cards;
## phone: under its day).

signal day_pressed(d: int)
signal play_pressed(week: bool)
signal changed                       # a card was answered: the hub refreshes the page
signal report_pressed                # "Last week in full"
signal card_pressed(id: String)      # a race strap: open its "what this race did" card (session L2a)
signal moment_answered(e: Dictionary)   # a waiting moment was answered: the hub shows what it changed (MomentEventPanel.result)

const PC_LEFT := 268.0
const PC_RIGHT := 290.0

var callouts_anchor: Control         # the cards (Play week's "Show me" scrolls here)
var selected := -1                   # the day open in the hub's day editor (a light border), -1 = none

## The day whose slot picker is open (-1 = none) and the week it belongs to (kept while the planner redraws; session L1b).
static var open_slot := -1
static var open_slot_week := 0


## The slot picker that is open this week, or -1.
static func slot_open() -> int:
	if open_slot >= 0 and Game.athlete != null and open_slot_week == Calendar.date_key(Game.week_monday()):
		return open_slot
	return -1


## A tap on a slot chip: opens its picker, or closes it when it is open.
func _toggle_slot(d: int) -> void:
	open_slot = -1 if slot_open() == d else d
	open_slot_week = Calendar.date_key(Game.week_monday())
	changed.emit()


func _close_slot() -> void:
	open_slot = -1
	changed.emit()


## The slot's chip of day `d` (null without the habit system).
func _slot_chip(w: WeekSim, d: int, icon_only: bool) -> Control:
	var hs := HabitsUI.system()
	if hs == null:
		return null
	return HabitsUI.chip(hs.slot_info(w, d), icon_only, _toggle_slot)


## The open slot's picker for day `d`.
func _slot_picker(w: WeekSim, d: int) -> Control:
	return HabitsUI.picker(w, d, func(): changed.emit(), _close_slot)


## This week's invitations still to come as cards (waiting or planned), oldest first.
static func _invites(w: WeekSim) -> Array:
	var ms := PeopleUI.system()
	if ms == null:
		return []
	var today := StoryletSystem.day_no(Game.date)
	return ms.invitations(w.monday).filter(func(m): return str(m.answer) == "" and int(m.slot_day) >= today)


static func ui() -> Dictionary:
	return Data.planner.ui


func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	if Layout.compact:
		_build_phone()
	else:
		_build_pc()


# --- What waits for an answer -------------------------------------------------------------------------------------------

## The choices still open this week: the coach's notes for days not played yet, the moments waiting for the planner (his meet
## suggestions among them), an unsettled meet-and-tests clash. [{kind: "note" | "moment" | "clash", ...}]
## Session L1b (user 2026-10-24): an invitation is NOT one of them: it sits in its evening with its price and "If you leave it, you
## stay home", but it neither counts in "N choices waiting" nor makes Play week ask (a careful week stays two clicks).
static func open_choices() -> Array:
	var out := []
	if Game.athlete == null:
		return out
	var w := Game.current_week()
	for p in _notes(w, true):
		out.append({"kind": "note", "p": p})
	var ms := PeopleUI.system()
	if ms != null:
		for m in ms.waiting():
			if not m.has("invite"):
				out.append({"kind": "moment", "m": m})
	var clash := _clash()
	if not clash.is_empty():
		out.append({"kind": "clash", "card": clash})
	return out


## "1 choice waiting" / "3 choices waiting" / "".
static func choices_text(n: int) -> String:
	if n <= 0:
		return ""
	return str(ui().choices_one) if n == 1 else str(ui().choices_many).format({"n": n})


## The coach's notes of this week (only the open ones for days still to come with `open_only`).
static func _notes(w: WeekSim, open_only: bool) -> Array:
	var cp := Game.get_system("proposals") as CoachProposals
	if cp == null or not CoachProposals.enabled:
		return []
	var list := cp.open_notes(w.monday) if open_only else cp.notes_of(w.monday)
	# (an open note on a day the player has changed since is left out: their change wins, and "Make it easy" would not apply)
	return list.filter(func(p):
		var d := int(p.days[0].d)
		if str(p.status) == "asked" and w.changed_by(d).values().has("player"):
			return false
		return not open_only or d >= w.day)


## The meet-and-tests clash of this week as a card ({} when there is none, it was settled or the school's decisions are off).
static func _clash() -> Dictionary:
	var ss := SchoolSystem.sys()
	if ss == null or not SchoolSystem.decisions_enabled or SchoolSystem.neutral:
		return {}
	for e in Game.events:   # (its Monday stop is already waiting: the stop panel asks it)
		if str(e.get("kind", "")) == "school_week" and e.answer == "":
			return {}
	return ss.meet_test_card(Game.date)


# --- Play week -----------------------------------------------------------------------------------------------------------

## The Play week block: Next day (small, secondary) and Play week (the biggest button on the screen; it says how many choices
## wait). `on_play(week: bool)`.
static func play_block(on_play: Callable) -> Control:
	var row := UIKit.hbox(8)
	var next := UIKit.button(str(ui().next_day), false, 0.0)
	next.custom_minimum_size = Vector2(96 if not Layout.compact else 104, 52)
	next.pressed.connect(func(): on_play.call(false))
	row.add_child(next)
	var play := Button.new()
	play.theme_type_variation = "PrimaryButton"
	play.custom_minimum_size = Vector2(0, 52)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(func(): on_play.call(true))
	var inner := UIKit.hbox(10)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(Icons.rect("play", 18.0, Color.WHITE))
	var texts := UIKit.vbox(0)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UIKit.label(str(ui().play_week), "CardHeading")
	title.add_theme_font_override("font", ThemeBuilder.FONT_BOLD)
	title.add_theme_font_size_override("font_size", 19 if Layout.compact else 17)
	title.add_theme_color_override("font_color", Color.WHITE)
	texts.add_child(title)
	var n := open_choices().size()
	if n > 0:
		var sub := UIKit.label(choices_text(n), "WhyLabel")
		sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		texts.add_child(sub)
		play.custom_minimum_size.y = 56
	inner.add_child(texts)
	play.add_child(inner)
	row.add_child(play)
	return row


# --- PC --------------------------------------------------------------------------------------------------------------------

func _build_pc() -> void:
	var w := Game.current_week()
	var row := UIKit.hbox(12)
	add_child(row)
	var side := Layout.side_open
	if not side:
		var left := _panel(_last_week_box())
		left.custom_minimum_size.x = _left_width()
		left.size_flags_vertical = Control.SIZE_FILL
		row.add_child(left)
	var mid := UIKit.vbox(12)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_panel(_week_box(w)))
	var cards := _cards(w, false)
	callouts_anchor = cards
	if cards.get_child_count() > 0:
		mid.add_child(cards)
	mid.add_child(_tiles(w))
	row.add_child(mid)
	if side:
		mid.add_child(play_block(func(week: bool): play_pressed.emit(week)))
		return
	var right := UIKit.vbox(12)
	right.custom_minimum_size.x = _right_width()
	right.add_child(_panel(_body_box(w)))
	var mind := _mind_box()
	if mind != null:
		right.add_child(_panel(mind))
	right.add_child(play_block(func(week: bool): play_pressed.emit(week)))
	row.add_child(right)


## The side columns give up width on a narrower wide window (a phone sideways, ~1206 logical px), so the days keep room for a whole
## word ("Strength") beside their icons: 268 | 290 at 1280.
func _left_width() -> float:
	return clampf(PC_LEFT - maxf(0.0, 1280.0 - Layout.logical_width) * 0.65, 200.0, PC_LEFT)


func _right_width() -> float:
	return clampf(PC_RIGHT - maxf(0.0, 1280.0 - Layout.logical_width) * 0.5, 230.0, PC_RIGHT)


static func _panel(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.panel_box(12))
	p.add_child(content)
	return p


## A section label with a muted note on the right ("LAST WEEK ........ 8–14 Feb").
static func _head(title: String, note := "") -> Control:
	var row := UIKit.hbox(8)
	var l := UIKit.label(title, "SectionLabel")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	if note != "":
		var n := UIKit.label(note, "WhyLabel")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(n)
	return row


## "8–14 Feb" / "28 Feb – 6 Mar".
static func range_text(monday: Dictionary) -> String:
	var sunday := Game.add_days(monday, 6)
	var m1 := str(Calendar.MONTHS_SHORT[int(monday.month) - 1])
	var m2 := str(Calendar.MONTHS_SHORT[int(sunday.month) - 1])
	if m1 == m2:
		return "%d–%d %s" % [int(monday.day), int(sunday.day), m2]
	return "%d %s – %d %s" % [int(monday.day), m1, int(sunday.day), m2]


# --- Last week -------------------------------------------------------------------------------------------------------------

func _last_week_box() -> Control:
	var u := ui()
	var box := UIKit.vbox(10)
	var r: Dictionary = Game.last_report
	if r.is_empty():
		box.add_child(_head(str(u.last_week)))
		box.add_child(UIKit.wrapped(str(u.first_week), "BodyLabel"))
		var line := _coach_line()
		if line != null:
			box.add_child(line)
		return box
	box.add_child(_head(str(u.last_week), range_text(r.monday)))
	box.add_child(_done_row(r))
	for strap in race_straps(r, func(id: String): card_pressed.emit(id)):
		box.add_child(strap)
	var rows := week_rows(r)
	if not rows.is_empty():   # (session L2b: every row opens its numbers on a tap; 5 + "+N more")
		box.add_child(UIKit.label(str(u.what_changed), "SectionLabel"))
		box.add_child(CausesUI.chip_list(rows, shown_rows(rows, 5), true))
	var line := _coach_line()
	if line != null:
		box.add_child(line)
	var full := UIKit.button(str(u.report_button), false, 0.0)
	full.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full.pressed.connect(func(): report_pressed.emit())
	box.add_child(full)
	return box


## "7/7 ●●●●●●● sessions done" (WeekSim.session_count, the one "done" of the game).
static func _done_row(r: Dictionary) -> Control:
	var c: Dictionary = r.get("count", {})
	var row := UIKit.hbox(8)
	if c.is_empty():   # (a report from before session L1a: the sessions trained)
		row.add_child(UIKit.label(str(int(r.get("sessions", 0))), "BigNumber"))
		var t := UIKit.label(str(ui().sessions_done), "WhyLabel")
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
		return row
	var planned := int(c.planned)
	var done := int(c.done)
	row.add_child(UIKit.label("%d/%d" % [done, planned], "BigNumber"))
	var dots := UIKit.hbox(3)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in mini(planned, 14):
		dots.add_child(UIKit.dot(Palette.GOOD if i < done else Palette.BAR_TRACK, 8))
	row.add_child(dots)
	var t := UIKit.label(str(ui().sessions_done if planned > 0 else ui().no_sessions), "WhyLabel")
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	row.add_child(t)
	return row


## A broadcast strap per race of the week: the flag, the time, a PB tag in LEAD, the meet and the place. Session L2a: a strap is a
## button that opens the race's "what this race did" card (kept in Game.race_cards); a race scratched that week has its own strap
## ("Scratched", the meet, why). `on_card(id)` opens a card (session L2b: static, so "Last week in full" shows them too).
static func race_straps(r: Dictionary, on_card: Callable) -> Array:
	var out := []
	for x in r.get("races", []):
		var key := str(x.get("meet_key", ""))
		var res := _result_of(key)
		if res.is_empty():
			continue
		var meet := Calendar.get_meet(key)
		var card_id := "%d_%s" % [Calendar.date_key(meet.date), key] if not meet.is_empty() else ""
		var top := UIKit.hbox(8)
		var ok := str(res.get("status", "")) == ""
		top.add_child(UIKit.label(Calendar.format_time(float(res.time)) if ok else str(res.status).to_upper(), "BigNumber"))
		if ok and bool(res.get("pb", false)):
			top.add_child(_tag("PB"))
		var place := Race._ordinal(int(res.place)) if ok and res.has("place") else ""
		var line := str(ui().race_line).format({"meet": str(meet.get("name", x.get("name", ""))), "place": place}).trim_suffix(" · ")
		out.append(_strap(top, line, Palette.LEAD, card_id, on_card))
	var lo := Calendar.date_key(r.monday)
	var hi := Calendar.date_key(Game.add_days(r.monday, 6))
	for c in Game.race_cards:
		var k := Calendar.date_key(c.date)
		if str(c.get("kind", "")) != "scratch" or k < lo or k > hi:
			continue
		var top := UIKit.hbox(8)
		top.add_child(UIKit.label(str(Data.recap.strap_scratched), "ItemLabel"))
		var line := str(Data.recap.strap_scratched_line).format({"meet": str(c.meet_name), "why": str(c.why).trim_suffix(".")})
		out.append(_strap(top, line, Palette.TEXT_MUTED, str(c.id), on_card))
	return out


## One strap: a raised row (48 px or more) with the flag, the top line, the line under it, and when it opens a card a chevron and a
## transparent button over the whole strap (the panel sizes itself to the text; the button fills it).
static func _strap(top: Control, line_text: String, flag: Color, card_id: String, on_card: Callable) -> Control:
	var has_card := card_id != "" and not Game.card(card_id).is_empty()
	var p := PanelContainer.new()
	var style := ThemeBuilder.raised_box(10)
	style.set_content_margin_all(0)   # (the margin is inside, so the button over the strap covers all of it)
	p.add_theme_stylebox_override("panel", style)
	p.custom_minimum_size.y = 48
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 7)
	p.add_child(pad)
	var row := UIKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Icons.rect("flag", 16.0, flag))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var line := UIKit.label(line_text, "WhyLabel")
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(line)
	row.add_child(col)
	pad.add_child(row)
	if has_card:
		var chev := Icons.rect("chevron-right", 16.0, Palette.TEXT_MUTED)
		chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chev)
		var b := Button.new()
		b.name = "OpenCard"
		b.flat = true
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1, 1, 1, 0.05)
		hover.set_corner_radius_all(Palette.RADIUS_RAISED)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): on_card.call(card_id))
		p.add_child(b)
	return p


## The LEAD tag (results only): "PB".
static func _tag(text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.strap_box(Palette.LEAD))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UIKit.label(text, "ChipNumber")
	l.add_theme_color_override("font_color", Palette.LEAD_TEXT)
	p.add_child(l)
	return p


static func _result_of(meet_key: String) -> Dictionary:
	for i in range(Game.athlete.results.size() - 1, -1, -1):
		if str(Game.athlete.results[i].meet_key) == meet_key:
			return Game.athlete.results[i]
	return {}


## What changed last week and why, in the order of importance (session L2b: WeekCauses.rows, every row with its recorded cause and
## its numbers on a tap): the rows the planner lists = the main ones and the smaller moves, but no attribute that reads under 0.1
## (L2b decision 2: those are in "Last week in full") and no mood that held steady.
static func week_rows(r: Dictionary) -> Array:
	return WeekCauses.rows(r).filter(func(x): return bool(x.main) or (str(x.kind) != "attr" and str(x.value) != str(Data.causes.mood.steady)))


## How many rows show before "+N more": the main ones (at most `most`), and at least two so a quiet week still says something.
static func shown_rows(rows: Array, most: int) -> int:
	var mains := rows.filter(func(x): return bool(x.main)).size()
	return mini(rows.size(), clampi(mains, 2, most))


static func _attr_icon(id: String, category: String) -> String:
	match id:
		"aerobic_capacity", "lactate_threshold":
			return "trending-up"
		"race_tactics":
			return "crosshair"
		"composure":
			return "shield"
		"strength", "power":
			return "dumbbell"
		"speed", "acceleration", "starts":
			return "zap"
	match category:
		"technical":
			return "person-standing"
		"mental":
			return "brain"
	return "activity"


## The coach's one line (his avatar, his name, the line); null without a line.
static func _coach_line() -> Control:
	var ms := PeopleUI.system()
	var cs := Game.get_system("coach") as CoachSystem
	if ms == null or cs == null or cs.head().is_empty():
		return null
	var text := ms.line_for(Game.week_monday())
	if text == "":
		return null
	var name := str(cs.head().get("name", ""))
	var row := UIKit.hbox(10)
	row.add_child(_avatar(name.left(1), Palette.COACH, 32.0))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(str(ui().coach_role).format({"name": name}), "WhyLabel"))
	col.add_child(UIKit.wrapped(text, "BodyLabel"))
	row.add_child(col)
	return row


## A round avatar with an initial.
static func _avatar(initial: String, color: Color, size: float) -> Control:
	var p := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(size / 2.0))
	p.add_theme_stylebox_override("panel", box)
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var l := UIKit.label(initial.to_upper(), "ItemLabel")
	l.add_theme_color_override("font_color", Color.WHITE)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# --- The week ---------------------------------------------------------------------------------------------------------------

## "NEXT WEEK" before the week starts (Sunday evening / Monday morning), "THIS WEEK" once a day of it was played.
static func week_title(w: WeekSim) -> String:
	return str(ui().next_week if w.day == 0 else ui().this_week)


## "15–21 Feb · Indoor specific, week 3 of 5" (the season plan's phase) or "15–21 Feb · your repeating week".
static func week_caption(w: WeekSim) -> String:
	var range := range_text(w.monday)
	var plan := Game.season.week_for(w.monday)
	if Game.season.mode == SeasonPlan.PHASES and str(plan.get("phase", "")) != "":
		var pt := SeasonPlan.phase_type(str(plan.phase))
		return str(ui().phase_caption).format({"range": range, "phase": str(pt.get("name", plan.phase)),
				"week": int(plan.get("phase_week", 1)), "weeks": int(plan.get("phase_weeks", 1))})
	return str(ui().repeat_caption).format({"range": range})


func _week_box(w: WeekSim) -> Control:
	var box := UIKit.vbox(10)
	box.add_child(_head(week_title(w), week_caption(w)))
	var days := UIKit.hbox(5)
	var open := {}
	for p in _notes(w, true):
		open[int(p.days[0].d)] = true
	for d in 7:
		days.add_child(_day_column(w, d, open.has(d)))
	box.add_child(days)
	return box


## A day as a column: MON 15, the intensity line, the sessions with their icons (or the race), a test chip, who changed it. The
## whole column is one button (the day editor). Today has an ACCENT border, a day with an open note a WARN border and "!", a played
## day is dimmed with a tick.
func _day_column(w: WeekSim, d: int, note: bool) -> Control:
	var info := DayInfo.of(w, d)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.DAY
	style.set_corner_radius_all(Palette.RADIUS_RAISED)
	style.set_border_width_all(1)
	style.border_color = Palette.BORDER
	if d == selected:
		style.border_color = Palette.TEXT
		style.set_border_width_all(2)
	elif note:
		style.border_color = Palette.WARN
	elif bool(info.today):
		style.border_color = Palette.ACCENT
	style.set_content_margin_all(5)
	style.content_margin_top = 7
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 200)
	var col := UIKit.vbox(5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UIKit.hbox(4)
	var day_name := UIKit.label(str(Training.DAY_NAMES[d]).to_upper(), "ItemLabel")
	day_name.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	day_name.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(day_name)
	head.add_child(UIKit.label(str(int(info.date.day)), "BigNumber"))
	head.add_child(UIKit.spacer())
	if note:
		head.add_child(UIKit.badge("!", Palette.WARN, 16.0))
	elif bool(info.played):
		head.add_child(Icons.rect("check", 14.0, Palette.GOOD))
	col.add_child(head)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 3)
	line.color = _day_color(info)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	for c in _day_items(info, false):
		col.add_child(c)
	if bool(info.played):
		panel.modulate = Color(1, 1, 1, 0.6)
	# (session L1b: the day's top part is one button (the day editor), the slot chip under it is its own button)
	var outer := UIKit.vbox(4)
	var top := MarginContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_child(col)
	var tap := Button.new()
	tap.theme_type_variation = "CardOverlay"
	tap.focus_mode = Control.FOCUS_ALL
	tap.pressed.connect(func(): day_pressed.emit(d))
	top.add_child(tap)
	outer.add_child(top)
	var chip := _slot_chip(w, d, false)
	if chip != null:
		outer.add_child(chip)
	panel.add_child(outer)
	return panel


## The day's line colour: the race in LEAD, a day without sessions in DAY_REST, else its intensity.
static func _day_color(info: Dictionary) -> Color:
	if not info.race.is_empty():
		return Palette.LEAD
	if info.sessions.is_empty():
		return Palette.DAY_REST
	return Palette.intensity(str(info.intensity))


## What a day shows: the race or the sessions (icon + short name), then a test chip and who changed it. `rows` = the phone's row
## (one line of sessions, no icons).
static func _day_items(info: Dictionary, rows: bool) -> Array:
	var u := ui()
	var out := []
	if not info.race.is_empty():
		out.append(_icon_line("flag", Palette.LEAD, str(info.race.get("name", u.race_word))))
	elif info.sessions.is_empty():
		out.append(_icon_line("moon", Palette.TEXT_MUTED, str(u.rest_word)))
	else:
		for sid in info.sessions:
			out.append(_icon_line(Icons.session(str(sid)), Palette.intensity(str(info.intensity)), Icons.session_short(str(sid))))
	for t in _test_chips(info):
		out.append(t)
	var who := _changed_text(info)
	if who != "":
		var l := UIKit.label(who, "WhyLabel")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.set_meta("fit_words", true)
		out.append(l)
	return out


static func _icon_line(icon: String, color: Color, text: String) -> Control:
	var row := UIKit.hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := Icons.rect(icon, 13.0, color)
	i.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(i)
	var l := UIKit.label(text, "ItemLabel")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.set_meta("fit_words", true)   # (tools/layout_check: a narrow day column is fine while every word fits)
	row.add_child(l)
	return row


## The day's tests as violet chips (school, lukio exams, the matriculation). `wrap` = the PC's narrow day column (the phone's row
## puts them in a flow, one line each).
static func _test_chips(info: Dictionary, wrap := true) -> Array:
	var out := []
	var school: Dictionary = info.get("school", {})
	var ss := SchoolSystem.sys()
	if school.is_empty() or ss == null:
		return out
	var names := []
	for sid in school.get("tests", []):
		names.append(ss.subject_name(str(sid)))
	if bool(school.get("exam", false)) and names.is_empty():
		names.append(str(ui().exam_chip))
	for n in names:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", ThemeBuilder.raised_box(4 if wrap else 5, Palette.SCHOOL_TEST_BG))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UIKit.label(str(ui().test_chip).format({"subject": n}), "ItemLabel")
		l.add_theme_color_override("font_color", Palette.SCHOOL_TEST)
		if wrap:   # (the PC's narrow day column: a size smaller, so "Geography" fits whole)
			l.add_theme_font_size_override("font_size", 12)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.set_meta("fit_words", true)
		p.add_child(l)
		out.append(p)
	return out


## "Changed by you" / "Changed by Heikki" / "Injury limits" (who changed the day), or "".
static func _changed_text(info: Dictionary) -> String:
	if bool(info.played) or info.by.is_empty():
		return ""
	var u := ui()
	if bool(info.limited):
		return str(u.changed_injury)
	if bool(info.coach):
		return str(u.changed_coach).format({"coach": DayInfo.who_name("coach")})
	return str(u.changed_you)


# --- The cards that wait for an answer ---------------------------------------------------------------------------------------

## Every card of this week: the coach's notes (answered ones stay as a line of what happened), the moments that wait, the clash.
## PC: a grid of two (one beside the side panel); `skip_notes` (the phone shows a note under its day).
func _cards(w: WeekSim, skip_notes: bool) -> Container:
	var grid := GridContainer.new()
	grid.columns = 1 if (Layout.compact or Layout.side_open) else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	if not skip_notes:   # (PC, session L1b: the open slot picker first; the phone shows it under its day)
		var open := slot_open()
		if open >= 0 and HabitsUI.system() != null:
			grid.add_child(_slot_picker(w, open))
	if not skip_notes:   # (the notes of days still to come, answered or not; a played day's note is history)
		for p in _notes(w, false):
			if int(p.days[0].d) >= w.day:
				grid.add_child(note_card(p))
	var clash := _clash()
	if not clash.is_empty():
		grid.add_child(_clash_card(clash))
	var ms := PeopleUI.system()
	if ms != null:
		if not skip_notes:   # (session L1b: the invitations of the week, waiting or planned; the phone shows them under their day)
			for m in _invites(w):
				if slot_open() != Calendar.weekday(StoryletSystem._date_of(int(m.slot_day))):   # (the open picker has it)
					grid.add_child(HabitsUI.invite_card(m, func(): changed.emit()))
		for m in ms.waiting():
			if not m.has("invite"):
				grid.add_child(_moment_card(m))
	for c in grid.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


## The coach's note on a day: title, his reason, Make it easy / Keep mine. Keep mine shows the veto reasons (a reason costs nothing,
## many silent vetoes cost trust: CoachProposals' rule). An answered note shows what happened instead of its buttons.
func note_card(p: Dictionary) -> CalloutCard:
	var cp := Game.get_system("proposals") as CoachProposals
	var t := cp.note_text(p)
	var nt: Dictionary = Data.coach_talk.proposal.note
	if str(p.status) != "asked":
		var card := CalloutCard.new(Palette.WARN, "message-circle", t.title, "", [])
		var x: Dictionary = p.days[0]
		var what := str(nt.passed)
		match str(p.status):
			"accepted", "applied":
				what = str(nt.accepted).format({"day": str(Data.moments.day_names[int(x.d)]),
						"to": CoachProposals._short_day(x.to).to_lower()})
			"vetoed":
				what = str(nt.kept)
		card.show_answer(what)
		return card
	var b := cp.note_buttons(p)
	var card := CalloutCard.new(Palette.WARN, "message-circle", t.title, t.text,
			[{"label": b[0], "primary": true, "id": "accept"}, {"label": b[1], "id": "keep"}])
	card.chosen.connect(func(id: String):
		if id == "accept":
			cp.answer_note(str(p.id), "accept")
			HealthUI.refresh()
			changed.emit()
			return
		card.button_row().visible = false
		card.add_row(UIKit.wrapped(str(nt.keep_why), "WhyLabel"))
		var reasons := UIKit.flex(8)
		var list: Array = CoachProposals.veto_reasons(str(p.kind)).slice(0, 2) + [{"id": "none", "label": str(nt.none)}]
		for r in list:
			var rb := UIKit.button(str(r.label), false, 0.0)
			rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rb.pressed.connect(func():
				cp.answer_note(str(p.id), "veto_" + str(r.id))
				HealthUI.refresh()
				changed.emit())
			reasons.add_child(rb)
		card.add_row(reasons))
	return card


## A moment that waits for the planner: who and where, the text, the replies with their cost under each (44 px).
func _moment_card(m: Dictionary) -> CalloutCard:
	var ms := PeopleUI.system()
	var u := ui()
	var p: Dictionary = ms.people.get(str(m.from), {})
	var who := StoryletSystem.person_name(p) if not p.is_empty() else StoryletSystem.thread_name(str(m.thread))
	var title := str(u.moment_title).format({"name": who, "thread": StoryletSystem.thread_name(str(m.thread))})
	var edge := Palette.PEOPLE
	if str(m.thread) in ["coach", "coaches"]:
		edge = Palette.WARN
	if str(m.get("kind", "")) == "suggest":
		title = str(u.suggest_title).format({"coach": who})
	var card := CalloutCard.new(edge, _thread_icon(str(m.thread), str(m.get("kind", ""))), title, str(m.text), [])
	var replies := UIKit.vbox(6)
	for r in m.replies:
		var b := UIKit.button(str(r.label), false, 0.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			ms.answer(str(m.id), str(r.id))
			moment_answered.emit({"kind": "moment", "moment": str(m.id), "date": Game.date.duplicate(), "source": "moments"})
			changed.emit())
		replies.add_child(b)
		if str(r.get("hint", "")) != "":
			replies.add_child(UIKit.wrapped(str(r.hint), "WhyLabel"))
	card.add_row(replies)
	return card


static func _thread_icon(thread: String, kind: String) -> String:
	if kind == "suggest":
		return "flag"
	match thread:
		"family":
			return "house"
		"friends":
			return "user-round"
		"group":
			return "users"
		"school":
			return "school"
		"rivals":
			return "flag"
	return "message-circle"


## The meet-and-tests clash settled before the week (SchoolSystem.settle_week): its options with their details.
func _clash_card(c: Dictionary) -> CalloutCard:
	var card := CalloutCard.new(Palette.ACCENT, str(ui().clash_icon), str(c.title), str(c.text), [])
	var box := UIKit.vbox(6)
	for o in c.choices:
		var b := UIKit.button(str(o.label), false, 0.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			SchoolSystem.sys().settle_week(int(c.monday), str(c.meet), str(o.id))
			HealthUI.refresh()
			changed.emit())
		box.add_child(b)
		if str(o.get("detail", "")) != "":
			box.add_child(UIKit.wrapped(str(o.detail), "WhyLabel"))
	card.add_row(box)
	return card


# --- Four facts ----------------------------------------------------------------------------------------------------------------

## LOAD (vs a normal week), PLAN RISK, NEXT RACE (days, the meet), GOAL (this season's time goal and how far): raised tiles.
func _tiles(w: WeekSim) -> Control:
	var u := ui()
	var tiles := []
	var h := HealthUI.system()
	if h != null:
		var pct := h.load_vs_normal(w)
		var band := HealthUI.load_band(pct)
		tiles.append(_tile(str(u.load), HealthUI.load_text(pct), band.color, str(u.load_of)))
		var risk := h.plan_risk(Game.season.week_for(w.monday))
		tiles.append(_tile(str(u.risk), str(HealthSystem.RISK_NAMES[risk]), HealthUI.risk_color(risk), ""))
	var next := Game.next_race()
	if next.is_empty():
		tiles.append(_tile(str(u.next_race), "–", Palette.TEXT_MUTED, str(u.no_race)))
	else:
		var n := Calendar.days_between(Game.date, next.date)
		var when := str(u.today) if n <= 0 else (str(u.tomorrow) if n == 1 else str(u.days).format({"n": n}))
		tiles.append(_tile(str(u.next_race), when, Palette.TEXT, str(next.name)))
	var goal := _goal_tile()
	if goal != null:
		tiles.append(goal)
	var grid := GridContainer.new()
	grid.columns = 2 if Layout.compact else tiles.size()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for t in tiles:
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
	return grid


static func _tile(head: String, value: String, color: Color, sub: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.raised_box(10))
	var col := UIKit.vbox(2)
	col.add_child(UIKit.label(head, "SectionLabel"))
	var v := UIKit.label(value, "BigNumber")
	v.add_theme_color_override("font_color", color)
	col.add_child(v)
	if sub != "":
		var s := UIKit.label(sub, "WhyLabel")
		s.clip_text = true
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(s)
	p.add_child(col)
	return p


## This season's first goal as a tile (the time goal's time, how it stands), or null without goals.
static func _goal_tile() -> Control:
	if not GoalsUI.available():
		return null
	var gs := SeasonGoals.sys()
	var year := gs.current_year()
	if not gs.has_goals(year):
		return null
	var goals: Array = gs.goals_of(year)
	var g: Dictionary = goals[0]
	for x in goals:
		if str(x.get("kind", "")) == "time":
			g = x
	var value := Calendar.format_time(float(g.time)) if g.has("time") else str(Data.goals.ui.marks[str(g.status)])
	return _tile(str(ui().goal), value, Palette.TEXT, gs.progress_text(g, year))


# --- Body and mind ---------------------------------------------------------------------------------------------------------------

func _body_box(w: WeekSim) -> Control:
	var u := ui()
	var box := UIKit.vbox(12)
	box.add_child(_head(str(u.body), str(u.body_hint)))
	for inj in injury_blocks():
		box.add_child(inj)
	box.add_child(tired_bar(false))
	for b in area_bars(int(Data.planner.body.areas_pc), false):
		box.add_child(b)
	var form := form_box(false)
	if form != null:
		box.add_child(form)
	return box


## An injury or illness now: what it is, what is allowed, when you are back (HealthUI's block; tap for more). [] when healthy.
static func injury_blocks() -> Array:
	var h := HealthUI.system()
	if h == null:
		return []
	return h.active().map(func(x): return HealthUI.injury_block(x))


## Tiredness as a bar (fatigue 0-100 against the line where "Exhausted" starts), with its word and last week's sessions as the why.
static func tired_bar(compact_head: bool) -> Control:
	var u := ui()
	var f := Game.athlete.fatigue
	var line := float(Data.planner.body.tired_warning)
	var why := "%s · %s" % [str(Training.fatigue_state(f)[0]), str(u.warning_at).format({"n": roundi(line)})]
	var bar := StatBar.new(str(u.tiredness), f, line, why)
	bar.compact_head = compact_head
	bar.set_meta("cause_row", "tired:now")
	return _tappable(bar, WeekCauses.tired_now())


## The most strained body areas as bars (strain against the line where "Sore" starts: the game's own sore warning).
static func area_bars(n: int, compact_head: bool) -> Array:
	var h := HealthUI.system()
	var out := []
	if h == null or not h.started:
		return out
	var line := float(Data.health.soreness.levels[HealthSystem.SORE - 1])
	var list := []
	for area in HealthSystem.areas():
		list.append({"id": str(area.id), "name": str(area.name), "strain": float(h.strain.get(area.id, 0.0))})
	list.sort_custom(func(x, y): return float(x.strain) > float(y.strain))
	for x in list.slice(0, n):
		var lvl := h.soreness_level(str(x.id))
		var word := HealthSystem.soreness_word(lvl)
		if lvl == 0 and float(x.strain) >= line - 15.0:
			word = str(Data.planner.ui.get("near_line", "Near the line"))
		var why := "%s · %s" % [word, str(ui().warning_at).format({"n": roundi(line)})]
		var bar := StatBar.new(str(x.name), float(x.strain), line, why)
		bar.compact_head = compact_head
		bar.set_meta("cause_row", "body:" + str(x.id))
		out.append(_tappable(bar, WeekCauses.area_now(str(x.id))))   # (session L2b: what raised it, day by day, as recorded)
	return out


## Race form as a word in its colour with its two factors (raised); tap = what it means. Null with the form model off.
static func form_box(compact: bool) -> Control:
	var i := FormUI.info()
	if i.is_empty():
		return null
	var u := ui()
	var f := Game.get_system("form") as FormSystem
	var fresh := clampi(100 - roundi(Game.athlete.fatigue), 0, 100)
	var line := str(u.form_line).format({"s": roundi(f.sharpness), "f": fresh}).replace(" %", " %")   # (a number keeps its %)
	if compact:
		var col := UIKit.vbox(2)
		col.add_child(UIKit.label(str(u.form_strip), "WhyLabel"))
		var word := UIKit.label(str(i.word), "BigNumber")
		word.add_theme_color_override("font_color", i.color)
		col.add_child(word)
		return _tappable(col, FormUI.explanation(i))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.raised_box(10))
	var row := UIKit.hbox(12)
	var word := UIKit.label(str(i.word), "BigNumber")
	word.add_theme_font_size_override("font_size", 26)
	word.add_theme_color_override("font_color", i.color)
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(word)
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(str(u.form_title), "ItemLabel"))
	var l := UIKit.wrapped(line, "WhyLabel")
	l.set_meta("fit_words", true)
	col.add_child(l)
	row.add_child(col)
	p.add_child(row)
	return _tappable(p, FormUI.explanation(i))


## A tap on `row` shows or hides `text` under it (no hover; UIKit.tap_to_explain with the V1 why style).
static func _tappable(row: Control, text: String) -> Control:
	if text.strip_edges() == "":
		return row
	var box := UIKit.vbox(4)
	box.add_child(row)
	var t := UIKit.wrapped(text, "WhyLabel")
	t.visible = false
	box.add_child(t)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var press := {"at": Vector2.ZERO}
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press.at = event.position
			elif event.position.distance_to(press.at) < 10.0:
				t.visible = not t.visible)
	return box


## The moods: name, the word in its colour with ▲ / ▼, what it does now · the news that moved it; tap = the whole story
## (MindUI.detail). Null with the mind model off.
static func _mind_box() -> Control:
	var mind := MindSystem.sys()
	if mind == null:
		return null
	var box := UIKit.vbox(10)
	box.add_child(_head(str(ui().mind)))
	for mood in MindSystem.MOODS:
		box.add_child(mood_row(mind, mood))
	return box


static func mood_row(mind: MindSystem, mood: String) -> Control:
	var w := mind.word(mood)
	var col := UIKit.vbox(1)
	col.add_child(UIKit.label(str(Data.mind.moods[mood].name), "ItemLabel"))
	var word_row := UIKit.hbox(6)
	var word := UIKit.label(str(w.name), "ItemLabel")
	word.add_theme_color_override("font_color", w.color)
	word_row.add_child(word)
	var arrow := mind.arrow(mood)
	if arrow != 0:
		var good := arrow > 0 if mood != "stress" else arrow < 0
		var a := UIKit.label("▲" if arrow > 0 else "▼", "ItemLabel")
		a.add_theme_color_override("font_color", Palette.GOOD if good else Palette.BAD)
		word_row.add_child(a)
	col.add_child(word_row)
	var eff: Dictionary = Data.mind.ui.effects[mood]
	var side := mind.side(mood)
	var does := str(eff.get(side, eff.get("low", "")))
	if mood == "stress":
		does = str(eff.low) if side == "middle" else str(eff.high)
	var recent := mind.recent(mood)
	var why := does if recent.is_empty() else "%s · %s %s" % [does, str(recent[0].text), "▲" if float(recent[0].delta) > 0.0 else "▼"]
	var l := UIKit.wrapped(why, "WhyLabel")
	col.add_child(l)
	col.custom_minimum_size.y = 44
	col.set_meta("cause_row", "mood:" + mood)
	# (Session L2b: the tap shows the word with its number and what it does, every recent news with ▲ / ▼, last Sunday's drift with
	# its pulls, what helps: WeekCauses.mood_now.)
	return _tappable(col, WeekCauses.mood_now(mood))


# --- Phone -------------------------------------------------------------------------------------------------------------------

func _build_phone() -> void:
	var w := Game.current_week()
	add_child(_panel(_last_week_phone()))
	var body := UIKit.vbox(10)
	for inj in injury_blocks():
		body.add_child(inj)
	body.add_child(_body_strip())
	add_child(_panel(body))
	var week := UIKit.vbox(0)
	var caption := week_caption(w)
	var h := HealthUI.system()
	if h != null:
		caption = range_text(w.monday) + " · " + str(ui().load_caption).format({"load": HealthUI.load_text(h.load_vs_normal(w))})
	week.add_child(_head(week_title(w), caption))
	var notes := {}
	for p in _notes(w, false):
		if int(p.days[0].d) >= w.day:
			notes[int(p.days[0].d)] = p
	var invites := {}   # (session L1b: an invitation opens under its day, like a note)
	for m in _invites(w):
		invites[Calendar.weekday(StoryletSystem._date_of(int(m.slot_day)))] = m
	for d in 7:
		var open := notes.has(d) and str(notes[d].status) == "asked"
		week.add_child(_day_row(w, d, open))
		var under := []
		if notes.has(d):
			under.append(note_card(notes[d]))
		if slot_open() == d and HabitsUI.system() != null:
			under.append(_slot_picker(w, d))
		elif invites.has(d):
			under.append(HabitsUI.invite_card(invites[d], func(): changed.emit()))
		for card in under:
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_bottom", 8)
			pad.add_child(card)
			week.add_child(pad)
	add_child(_panel(week))
	var cards := _cards(w, true)
	callouts_anchor = cards
	if cards.get_child_count() > 0:
		add_child(cards)
	var mind := _mind_box()
	if mind != null:
		add_child(_panel(mind))
	add_child(_tiles(w))


## Last week on a phone: the head with "7/7 done · 2:57.31 PB", the chips as pills (4 + "+N more"), the coach's line.
func _last_week_phone() -> Control:
	var u := ui()
	var box := UIKit.vbox(10)
	var r: Dictionary = Game.last_report
	if r.is_empty():
		box.add_child(_head(str(u.last_week)))
		box.add_child(UIKit.wrapped(str(u.first_week), "BodyLabel"))
		var first_line := _coach_line()
		if first_line != null:
			box.add_child(first_line)
		return box
	var c: Dictionary = r.get("count", {})
	var note := str(u.done_short).format({"done": int(c.get("done", 0)), "planned": int(c.get("planned", 0))}) if not c.is_empty() else ""
	var head := _head(str(u.last_week), note)
	box.add_child(head)
	for strap in race_straps(r, func(id: String): card_pressed.emit(id)):   # (session L2a: the race straps open their cards, as on PC)
		box.add_child(strap)
	var rows := week_rows(r)
	if not rows.is_empty():   # (session L2b: a tap on a pill shows its cause and numbers under them; 4 + "+N more")
		box.add_child(CausesUI.pill_list(rows, shown_rows(rows, 4)))
	var line := _coach_line()
	if line != null:
		box.add_child(line)
	var full := UIKit.button(str(u.report_button), false, 0.0)
	full.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full.pressed.connect(func(): report_pressed.emit())
	box.add_child(full)
	return box


## Tiredness, the most strained area and Form side by side.
func _body_strip() -> Control:
	var row := UIKit.hbox(14)
	var parts: Array = [tired_bar(true)]
	parts.append_array(area_bars(int(Data.planner.body.areas_phone), true))
	var form := form_box(true)
	if form != null:
		parts.append(form)
	for p in parts:
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	return row


## A day as a phone row: the day and date as a big number, a 4 px edge in the intensity colour, the sessions in words with the
## intensity, a test chip; a note's mark on the right. The whole row is one button (the day editor).
func _day_row(w: WeekSim, d: int, note: bool) -> Control:
	var info := DayInfo.of(w, d)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.WARN, 0.08) if note else (Color(Palette.ACCENT, 0.06) if bool(info.today) else Color.TRANSPARENT)
	style.set_corner_radius_all(Palette.RADIUS_RAISED)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 4
	style.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = 52
	var row := UIKit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var date := UIKit.vbox(0)
	date.custom_minimum_size.x = 40
	var dn := UIKit.label(str(Training.DAY_NAMES[d]).to_upper(), "WhyLabel")
	date.add_child(dn)
	date.add_child(UIKit.label(str(int(info.date.day)), "BigNumber"))
	row.add_child(date)
	var edge := ColorRect.new()
	edge.custom_minimum_size = Vector2(4, 0)
	edge.color = _day_color(info)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(edge)
	var col := UIKit.vbox(3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var u := ui()
	var main := ""
	var sub := ""
	if not info.race.is_empty():
		main = str(info.race.get("name", u.race_word))
		sub = str(u.race_word)
	elif info.sessions.is_empty():
		main = str(u.rest_word)
	else:
		main = " + ".join(info.sessions.map(func(s): return Icons.session_short(str(s))))
		sub = DayInfo.intensity_name(str(info.intensity))
	var who := _changed_text(info)
	if who != "":
		sub = who if sub == "" else sub + " · " + who
	if bool(info.played):
		sub = str(u.played_word) if sub == "" else str(u.played_word) + " · " + sub
	col.add_child(UIKit.wrapped(main, "CardHeading"))
	if sub != "":
		col.add_child(UIKit.label(sub, "WhyLabel"))
	var chips := _test_chips(info, false)
	if not chips.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		for c in chips:
			flow.add_child(c)
		col.add_child(flow)
	row.add_child(col)
	if note:
		row.add_child(Icons.rect("message-circle", 18.0, Palette.WARN))
	elif bool(info.played):
		row.add_child(Icons.rect("check", 18.0, Palette.GOOD))
	if bool(info.played):
		panel.modulate = Color(1, 1, 1, 0.6)
	# (session L1b: the row is one button (the day editor) except the slot icon on its right, its own 44 px button)
	var outer := UIKit.hbox(4)
	var left := MarginContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(row)
	var tap := Button.new()
	tap.theme_type_variation = "CardOverlay"
	tap.pressed.connect(func(): day_pressed.emit(d))
	left.add_child(tap)
	outer.add_child(left)
	var chip := _slot_chip(w, d, true)
	if chip != null:
		outer.add_child(chip)
	panel.add_child(outer)
	return panel
