class_name RaceRecapView
extends VBoxContainer
## "What this race did" (GDD 4.10 decision 1 + "L2's questions", session L2a; the look: GDD 5 "The look (V1)", mock-ups
## docs/v1/race_card_pc.png / race_card_phone.png): the card a race ends on, made from a RaceRecap card (Game.race_cards).
##   PC: two columns. Left: the result strap (the place box in LEAD, the time, the PB / SB tag and the delta), the line under it, the
##       200 m splits against the winner, FORM ON THE DAY, the messages of the evening. Right: WHAT THIS RACE DID (5 + "+N more", a tap
##       on a row shows its exact numbers), the goal it moved, the coach's line, Continue + Full results, the next race.
##   Phone: one column, nothing behind a tap but the numbers: the strap (with the Form word) → what changed (4 + "+N more") → the
##       coach → the goal and the next race → the splits and Form → the messages. The race screen keeps Continue sticky at the bottom
##       (`buttons()`).
## `page` = opened again from the planner (the hub's page with its own Back): no Continue / Full results.
## Also the scratch card (`scratch_box`). Texts: data/race_recap.json. Nothing here changes the game.

signal continue_pressed
signal results_pressed

var card := {}
var page := false
var with_buttons := true   # PC: Continue / Full results in the right column (the phone's race screen puts them in a sticky block)


func _init(c: Dictionary, as_page := false) -> void:
	card = c
	page = as_page
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	if Layout.compact:
		_build_phone()
	else:
		_build_pc()


static func cfg() -> Dictionary:
	return Data.recap


# --- PC ------------------------------------------------------------------------------------------------------------------

func _build_pc() -> void:
	var row := UIKit.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var left := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.75
	left.add_child(_panel(_strap_box(false)))
	var form := _form_box()
	if form != null:
		left.add_child(_panel(form))
	var msgs := _messages_box()
	if msgs != null:
		left.add_child(_panel(msgs))
	row.add_child(left)
	var right := UIKit.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UIKit.vbox(10)
	box.add_child(head(str(cfg().title)))
	box.add_child(_changes_box(5))
	var goal := _goal_box()
	if goal != null:
		box.add_child(goal)
	var coach := _coach_row()
	if coach != null:
		box.add_child(coach)
	var bottom := UIKit.hbox(10)
	if with_buttons and not page:
		for b in buttons_row():
			bottom.add_child(b)
	var nxt := _next_box(true)
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(nxt)
	box.add_child(bottom)
	right.add_child(_panel(box))
	row.add_child(right)


# --- Phone ---------------------------------------------------------------------------------------------------------------

func _build_phone() -> void:
	add_child(_panel(_strap_box(true)))
	var box := UIKit.vbox(10)
	box.add_child(head(str(cfg().title)))
	box.add_child(_changes_box(4))
	add_child(_panel(box))
	var coach := _coach_row()
	if coach != null:
		add_child(_panel(coach))
	var facts := UIKit.vbox(10)
	var goal := _goal_box()
	if goal != null:
		facts.add_child(goal)
	facts.add_child(_next_box(false))
	add_child(_panel(facts))
	var chart := _splits_box(true)
	if chart != null:
		add_child(_panel(chart))
	var form := _form_box()
	if form != null:
		add_child(_panel(form))
	var msgs := _messages_box()
	if msgs != null:
		add_child(_panel(msgs))


# --- Parts ---------------------------------------------------------------------------------------------------------------

static func _panel(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.panel_box(12))
	p.add_child(content)
	return p


## A broadcast section head: a 4 px LEAD mark and the title in condensed caps.
static func head(text: String) -> Control:
	var row := UIKit.hbox(8)
	var mark := ColorRect.new()
	mark.color = Palette.LEAD
	mark.custom_minimum_size = Vector2(4, 18)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var l := UIKit.label(text.to_upper(), "ChipNumber")
	l.add_theme_font_size_override("font_size", 19 if Layout.compact else 17)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


## The result strap: the place box (LEAD, slanted), the time, the PB / SB tag and the delta; the line under it. On PC the splits chart
## follows in the same panel; on a phone the line carries the delta and the Form word instead.
func _strap_box(compact: bool) -> Control:
	var c: Dictionary = cfg()
	var box := UIKit.vbox(8)
	var row := UIKit.hbox(14)
	var ok := str(card.get("status", "")) == ""
	var place := PanelContainer.new()
	place.add_theme_stylebox_override("panel", ThemeBuilder.strap_box(Palette.LEAD))
	var inner := UIKit.hbox(4)
	var big := UIKit.label(str(int(card.get("place", 0))) if ok else str(card.status).to_upper(), "DisplayNumber")
	big.add_theme_color_override("font_color", Palette.LEAD_TEXT)
	inner.add_child(big)
	if ok and int(card.get("field", 0)) > 1:
		var of := UIKit.label(str(c.of_field).format({"field": int(card.field)}), "ChipNumber")
		of.add_theme_color_override("font_color", Palette.LEAD_TEXT)
		of.size_flags_vertical = Control.SIZE_SHRINK_END
		inner.add_child(of)
	place.add_child(inner)
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(place)
	if ok:
		var t := UIKit.label(Calendar.format_time(float(card.time)), "DisplayNumber")
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
	var tags: BoxContainer = UIKit.vbox(2) if not compact else UIKit.hbox(6)
	tags.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mark := str(card.get("mark", ""))
	if ok and mark != "":
		tags.add_child(WeekPlanner._tag(mark))
	if not compact and str(card.get("delta_text", "")) != "":
		tags.add_child(_delta_label())
	row.add_child(tags)
	box.add_child(row)
	var parts := []
	if str(card.get("line", "")) != "":
		parts.append(str(card.line))
	if compact:
		if str(card.get("delta_text", "")) != "":
			parts.append(str(card.delta_text))
		var form: Dictionary = card.get("form", {})
		if not form.is_empty():
			parts.append(str(c.form_short).format({"word": str(form.word)}))
	if not parts.is_empty():
		var l := UIKit.wrapped(" · ".join(parts), "WhyLabel")
		box.add_child(l)
	for r in card.get("rounds", []):
		box.add_child(UIKit.wrapped(str(r), "WhyLabel"))
	if not compact:
		var chart := _splits_box(false)
		if chart != null:
			box.add_child(chart)
	return box


func _delta_label() -> Label:
	var l := UIKit.label(str(card.delta_text), "ChipNumber")
	l.add_theme_color_override("font_color", Palette.GOOD if float(card.get("delta", 0.0)) < 0.0 else Palette.BAD)
	return l


## The splits chart with its line ("Your 200 m splits against the winner's (2:41.2)"), the legend and the axis note. Null without splits.
func _splits_box(with_head: bool) -> Control:
	var s: Dictionary = card.get("splits", {})
	var c: Dictionary = cfg()
	if s.is_empty():
		return null
	var box := UIKit.vbox(6)
	if with_head:
		box.add_child(head(str(c.splits_head)))
	var other_time := float(s.get("other_time", 0.0))
	var who := str(s.get("label", ""))
	box.add_child(UIKit.wrapped(str(c.splits_line).format({"who": who, "time": Calendar.format_time(other_time) if other_time > 0.0 else "–"}), "WhyLabel"))
	box.add_child(SplitsChart.new(s.get("you", []), s.get("other", []), 150.0 if Layout.compact else 170.0))
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 12)
	legend.add_child(_legend_item(Palette.ACCENT, str(c.splits_you)))
	legend.add_child(_legend_item(Color(Palette.DAY_NORMAL, 0.55), who.left(1).to_upper() + who.substr(1)))
	legend.add_child(UIKit.label(str(c.splits_axis), "WhyLabel"))
	box.add_child(legend)
	return box


static func _legend_item(color: Color, text: String) -> Control:
	var row := UIKit.hbox(5)
	row.add_child(UIKit.dot(color, 10))
	var l := UIKit.label(text, "WhyLabel")
	row.add_child(l)
	return row


## FORM ON THE DAY: the word in its colour, freshness and sharpness with their causes, the terms; a tap shows the exact numbers.
func _form_box() -> Control:
	var f: Dictionary = card.get("form", {})
	if f.is_empty():
		return null
	var c: Dictionary = cfg()
	var box := UIKit.vbox(8)
	box.add_child(head(str(c.form_head)))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.raised_box(10))
	var row := UIKit.hbox(12)
	var word := UIKit.label(str(f.word), "BigNumber")
	word.add_theme_font_size_override("font_size", 26)
	word.add_theme_color_override("font_color", Color(str(f.get("color", "#9aa1b2"))))
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(word)
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fwhy: String = " (%s)" % str(f.fwhy) if str(f.get("fwhy", "")) != "" else ""
	var swhy: String = " (%s)" % str(f.swhy) if str(f.get("swhy", "")) != "" else ""
	col.add_child(UIKit.wrapped(str(c.form_line).format({"f": int(f.fresh), "fwhy": fwhy, "s": int(f.sharp), "swhy": swhy}), "WhyLabel"))
	var pct := func(v: float) -> String: return RaceRecap.signed(v * 100.0, 1) + " %"
	var mind := float(f.get("mind", 0.0))
	var terms: String = str(c.form_terms if absf(mind) >= 0.0005 else c.form_terms_plain).format({"form": pct.call(float(f.share)), "mind": pct.call(mind)})
	col.add_child(UIKit.wrapped(terms, "WhyLabel"))
	var slow := float(f.get("slowdown", 0.0))
	if slow > 0.0:
		col.add_child(UIKit.wrapped(str(c.form_slow).format({"pct": "%.1f %%" % (slow * 100.0)}), "WhyLabel"))
	row.add_child(col)
	p.add_child(row)
	var detail := str(c.form_detail).format({"f": int(f.fresh), "fatigue": int(f.fatigue), "fresh_term": pct.call(float(f.fresh_term)),
			"s": int(f.sharp), "sharp_term": pct.call(float(f.sharp_term)), "form": pct.call(float(f.share)), "mind": pct.call(mind),
			"helps": str(f.get("helps", ""))})
	box.add_child(WeekPlanner._tappable(p, detail))
	return box


## WHAT THIS RACE DID: the rows (the first `shown`, then "+N more" opens the rest), "Nothing else moved" when only the body and
## the race training are left.
func _changes_box(shown: int) -> Control:
	var c: Dictionary = cfg()
	var box := UIKit.vbox(0)
	var list: Array = card.get("changes", [])
	var rest := UIKit.vbox(0)
	rest.visible = false
	for i in list.size():
		var r := _change_row(list[i])
		if i < shown:
			box.add_child(r)
		else:
			rest.add_child(r)
	if rest.get_child_count() > 0:
		box.add_child(rest)
		var more := UIKit.button(str(c.more).format({"n": rest.get_child_count()}), false, 0.0)
		more.theme_type_variation = "FlatButton"
		more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		more.pressed.connect(func():
			rest.visible = true
			more.visible = false)
		box.add_child(more)
	if bool(card.get("nothing_else", false)):
		var l := UIKit.wrapped(str(c.nothing_else), "WhyLabel")
		box.add_child(l)
	return box


static func tone_color(tone: String) -> Color:
	match tone:
		"good": return Palette.GOOD
		"bad": return Palette.BAD
		"warn": return Palette.WARN
	return Palette.TEXT


static func _icon_of(x: Dictionary) -> String:
	match str(x.get("kind", "")):
		"mood": return str(Data.recap.mood_icons.get(str(x.id), "brain"))
		"attr": return WeekPlanner._attr_icon(str(x.id), str(Data.get_attribute(str(x.id)).get("category", "")))
		"body", "injury": return "triangle-alert" if str(x.get("tone", "")) in ["warn", "bad"] else "activity"
		"tired": return "gauge"
		"trust": return "message-circle"
		"later": return "calendar-days"
	return "activity"


## One change: an icon square, the name and its cause, the value in its colour; a tap shows the exact numbers.
func _change_row(x: Dictionary) -> Control:
	var row := UIKit.hbox(12)
	row.custom_minimum_size.y = 48
	var icon_box := PanelContainer.new()
	icon_box.add_theme_stylebox_override("panel", ThemeBuilder.raised_box(6))
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var color := tone_color(str(x.get("tone", "plain")))
	icon_box.add_child(Icons.rect(_icon_of(x), 16.0, color if color != Palette.TEXT else Palette.TEXT_MUTED))
	row.add_child(icon_box)
	var col := UIKit.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UIKit.label(str(x.title), "ItemLabel"))
	if str(x.get("cause", "")) != "":
		col.add_child(UIKit.wrapped(str(x.cause), "WhyLabel"))
	row.add_child(col)
	var v := UIKit.label(str(x.get("value", "")), "BigNumber")
	v.add_theme_color_override("font_color", color if str(x.kind) != "later" else Palette.TEXT_MUTED)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	var wrap := UIKit.vbox(0)
	var line := ColorRect.new()
	line.color = Palette.DIVIDER
	line.custom_minimum_size = Vector2(0, 1)
	wrap.add_child(WeekPlanner._tappable(row, str(x.get("detail", ""))))
	wrap.add_child(line)
	return wrap


## The goal the race moved: its line, how it stands, a bar (from where you stood when it was set to the goal).
func _goal_box() -> Control:
	var g: Dictionary = card.get("goal", {})
	if g.is_empty():
		return null
	var box := UIKit.vbox(6)
	var row := UIKit.hbox(8)
	var t := UIKit.wrapped(str(g.text), "ItemLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if str(g.get("note", "")) != "":
		var n := UIKit.label(str(g.note), "WhyLabel")
		if str(g.status) == "met":
			n.add_theme_color_override("font_color", Palette.GOOD)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(n)
	box.add_child(row)
	if str(g.status) != "missed":
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := clampf(float(g.get("fill", 0.0)), 0.0, 1.0)
		bar.draw.connect(func():
			var back := StyleBoxFlat.new()
			back.bg_color = Palette.BAR_TRACK
			back.set_corner_radius_all(4)
			bar.draw_style_box(back, Rect2(Vector2.ZERO, bar.size))
			if fill > 0.0:
				var f := StyleBoxFlat.new()
				f.bg_color = Palette.GOOD if str(g.status) == "met" else Palette.ACCENT
				f.set_corner_radius_all(4)
				bar.draw_style_box(f, Rect2(0, 0, maxf(bar.size.x * fill, 8.0), bar.size.y)))
		box.add_child(bar)
	return box


## The coach's one line: his avatar, "Heikki Laine, coach", the line. Null when he said nothing.
func _coach_row() -> Control:
	var co: Dictionary = card.get("coach", {})
	if str(co.get("line", "")) == "":
		return null
	return coach_row(co)


static func coach_row(co: Dictionary) -> Control:
	var name := str(co.get("name", ""))
	var row := UIKit.hbox(10)
	row.add_child(WeekPlanner._avatar(name.left(1) if name != "" else "C", Palette.COACH, 36.0))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if name != "":
		col.add_child(UIKit.label(str(Data.recap.coach_role).format({"name": name}), "WhyLabel"))
	col.add_child(UIKit.wrapped(str(co.line), "BodyLabel"))
	row.add_child(col)
	return row


## The messages of the evening (real ones only), as rows: a person icon, "Eino: …". Null without any.
func _messages_box() -> Control:
	var list: Array = card.get("messages", [])
	if list.is_empty():
		return null
	var box := UIKit.vbox(8)
	box.add_child(head(str(cfg().messages_head)))
	for m in list:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", ThemeBuilder.raised_box(10))
		var row := UIKit.hbox(8)
		row.add_child(Icons.rect("user-round", 16.0, Palette.PEOPLE))
		var l := UIKit.label("%s: %s" % [str(m.from), str(m.text)], "ItemLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		p.add_child(row)
		box.add_child(p)
	return box


## "Next race: Tampere Junior Indoor Games / Sat 13 Mar · 27 days" (right-aligned on PC) or "No race entered yet".
func _next_box(right: bool) -> Control:
	return next_box(card.get("next", {}), right)


static func next_box(n: Dictionary, right: bool) -> Control:
	var c: Dictionary = Data.recap
	var col := UIKit.vbox(0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if n.is_empty():
		var l := UIKit.label(str(c.next_none), "WhyLabel")
		if right:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(l)
		return col
	var a := UIKit.wrapped(str(c.next_race).format({"meet": str(n.name)}), "WhyLabel")
	var days := int(n.get("days", 0))
	var when := str(c.next_when_one if days == 1 else c.next_when).format({"date": Calendar.format_day(Game.int_date(n.date)), "days": days})
	var b := UIKit.label(when, "ItemLabel")
	if right:
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(a)
	col.add_child(b)
	return col


## CONTINUE (ACCENT, slanted) and FULL RESULTS (secondary), in the broadcast face; they emit continue_pressed / results_pressed.
func buttons_row() -> Array:
	var c: Dictionary = cfg()
	var go := broadcast_button(str(c["continue"]), true)
	go.pressed.connect(func(): continue_pressed.emit())
	var full := broadcast_button(str(c.full_results), false)
	full.pressed.connect(func(): results_pressed.emit())
	return [go, full]


## A race-and-results button: condensed caps, 48 px; the primary one ACCENT and slanted -8 degrees (GDD 5 broadcast shapes).
static func broadcast_button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 48)
	b.add_theme_font_override("font", ThemeBuilder.number_font(ThemeBuilder.NUM_EXTRABOLD if primary else ThemeBuilder.NUM_BOLD))
	b.add_theme_font_size_override("font_size", 22 if Layout.compact else 19)
	if primary:
		for state in ["normal", "hover", "pressed", "focus"]:
			var col := Palette.ACCENT
			if state == "hover":
				col = Palette.ACCENT_HOVER
			elif state == "pressed":
				col = Palette.ACCENT_PRESSED
			var box := ThemeBuilder.strap_box(col)
			box.content_margin_left = 22
			box.content_margin_right = 22
			if state == "focus":
				box.draw_center = false
				box.border_color = Color.WHITE
				box.set_border_width_all(2)
			b.add_theme_stylebox_override(state, box)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(key, Color.WHITE)
	else:
		for state in ["normal", "hover", "pressed"]:
			var box := ThemeBuilder.strap_box(Palette.SURFACE_3 if state == "hover" else Palette.SURFACE_2, false)
			box.border_color = Palette.BORDER
			box.set_border_width_all(1)
			box.content_margin_left = 18
			box.content_margin_right = 18
			b.add_theme_stylebox_override(state, box)
	return b


# --- The scratch card ------------------------------------------------------------------------------------------------------

## The scratch card (session L2a): SCRATCHED + the meet, why, the coach's line, what it means, the next race, OK (`on_ok`).
static func scratch_box(c: Dictionary, width: float, on_ok: Callable) -> Control:
	var t: Dictionary = Data.recap
	var box := UIKit.vbox(10)
	box.custom_minimum_size.x = width
	box.add_child(head(str(t.scratch_title)))
	box.add_child(UIKit.wrapped(str(c.meet_name), "CardHeading"))
	box.add_child(UIKit.wrapped(str(c.get("sub", "")), "WhyLabel"))
	box.add_child(UIKit.label(str(t.scratch_why_head), "SectionLabel"))
	box.add_child(UIKit.wrapped(str(c.why), "BodyLabel"))
	var co: Dictionary = c.get("coach", {})
	if str(co.get("line", "")) != "":
		box.add_child(coach_row(co))
	var means: Array = c.get("means", [])
	if not means.is_empty():
		box.add_child(UIKit.label(str(t.scratch_means_head), "SectionLabel"))
		for m in means:
			box.add_child(UIKit.wrapped(str(m), "BodyLabel"))
	box.add_child(next_box(c.get("next", {}), false))
	var ok := UIKit.button(str(t.ok), true, 0.0)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(on_ok)
	box.add_child(ok)
	return box
