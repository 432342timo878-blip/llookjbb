class_name HabitsUI
extends RefCounted
## The free-time slots where the player sees and changes them (GDD 4.10 decision 6, session L1b; look: GDD 5 "The look (V1)"):
##   - the planner's slot chip (PC: the bottom of a day column; phone: an icon on the right of a day row), highlighted only when
##     something landed on it (an invitation: PEOPLE; a late night before a race or a hard session: WARN),
##   - the slot picker (a callout: the four activities as 44 px buttons, back to the habit; an invitation's Go / Stay home on top),
##   - the invitation card with its visible price (sleep, the next day's session, the friendship),
##   - the day editor's FREE TIME box, the evening line of the day's blocks,
##   - the Season tab's YOUR HABITS (a row per slot, what the week adds up to, back to the default),
##   - the School page's line.
## Changes go through HabitSystem (set_habit / set_slot) and StoryletSystem.answer (an invitation is only planned until its evening).
## The player decides: nothing here changes a slot unless a button says so. Texts: data/habits.json `ui`.

## The hub sets this (a weak reference to itself) so the School page's "Change my habits" can open the Season tab. A WeakRef, not a
## Callable: a static lambda bound to the hub would outlive it when the game quits and crash on the way out.
static var hub_ref: WeakRef = null


## Opens the Season tab in the hub, if there is one.
static func open_season() -> void:
	var hub = hub_ref.get_ref() if hub_ref != null else null
	if hub != null and hub.has_method("_show"):
		hub._show("season")


static func ui() -> Dictionary:
	return Data.habits.ui


static func system() -> HabitSystem:
	if Game.athlete == null:
		return null
	return HabitSystem.sys()


static func moments() -> StoryletSystem:
	return Game.get_system("moments") as StoryletSystem


## "Sat" / "Fri eve" for a slot; "Saturday" / "Friday evening" with `long`.
static func slot_label(i: int, long := false) -> String:
	return HabitSystem.slot_name(i) if long else HabitSystem.slot_short(i)


# --- The planner's chip --------------------------------------------------------------------------------------------------------

## The slot of day `d` as a 44 px chip: the activity's icon and name (an invitation: its chip text), faint unless something landed
## on it. `icon_only` = the phone row's icon on the right. A press calls `on_press(d)`.
static func chip(info: Dictionary, icon_only: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(44, 44)
	var color := Palette.TEXT_MUTED
	var icon := HabitSystem.activity_icon(str(info.activity))
	var text := HabitSystem.activity_name(str(info.activity))
	var bg := Color.TRANSPARENT
	var inv: Dictionary = info.invite
	if not inv.is_empty() and not bool(info.played):
		color = Palette.PEOPLE
		bg = Palette.PEOPLE_BG
		icon = "party-popper"
		text = str(inv.invite.get("chip", text))
	elif str(info.clash) != "":
		color = Palette.WARN
		bg = Color(Palette.WARN, 0.10)
		icon = "triangle-alert"
	elif bool(info.changed):
		color = Palette.TEXT
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(Palette.RADIUS_RAISED)
	if bg != Color.TRANSPARENT:
		box.border_color = color
		box.set_border_width_all(1)
	box.set_content_margin_all(4)
	for state in ["normal", "pressed"]:
		b.add_theme_stylebox_override(state, box)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color(Palette.SURFACE_2, 1.0) if bg == Color.TRANSPARENT else bg.lightened(0.1)
	b.add_theme_stylebox_override("hover", hover)
	var row := UIKit.hbox(4)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if HabitSystem.slot_kind(int(info.i)) == "evening" and not icon_only and inv.is_empty() and str(info.clash) == "":
		row.add_child(Icons.rect("moon", 11.0, Palette.TEXT_FAINT))   # (the evening / day marker of the mock-up: small, faint)
	elif not icon_only and inv.is_empty() and str(info.clash) == "":
		row.add_child(Icons.rect("sun", 11.0, Palette.TEXT_FAINT))
	row.add_child(Icons.rect(icon, 16.0 if icon_only else 13.0, color))
	if not icon_only:
		var l := UIKit.label(text, "WhyLabel")
		l.add_theme_color_override("font_color", color)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.set_meta("fit_words", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
	b.add_child(row)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not icon_only else Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var d := int(info.i)
	b.pressed.connect(func(): on_press.call(d))
	b.set_meta("slot_day", d)   # (the tools find a slot's chip by it)
	return b


# --- The slot picker -----------------------------------------------------------------------------------------------------------

## The picker of day `d`'s slot this week: what it is and does, an invitation on it (Go / Stay home with the price), the four
## activities, back to the habit, Close. `on_change` after a change; `on_close` for Close.
static func picker(w: WeekSim, d: int, on_change: Callable, on_close: Callable) -> CalloutCard:
	var hs := system()
	var u := ui()
	var info := hs.slot_info(w, d)
	var act := str(info.activity)
	var edge := Palette.PEOPLE if not info.invite.is_empty() else (Palette.WARN if str(info.clash) != "" else Palette.ACCENT)
	var title := str(u.picker_title).format({"slot": slot_label(d, true), "activity": HabitSystem.activity_name(act)})
	var card := CalloutCard.new(edge, HabitSystem.activity_icon(act), title, _state_line(info), [])
	card.set_meta("slot_picker", d)
	if not info.invite.is_empty():
		card.add_row(_invite_part(info.invite, on_change))
	if bool(info.played):
		card.add_row(UIKit.wrapped(str(u.picker_played), "WhyLabel"))
	elif info.invite.is_empty() or not HabitSystem.going(info.invite):   # (going out: the evening is the invitation's)
		card.add_row(_activity_buttons(hs, d, info, on_change))
	var close := UIKit.button(str(u.picker_close), false, 0.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END if not Layout.compact else Control.SIZE_EXPAND_FILL
	close.pressed.connect(func(): on_close.call())
	card.add_row(close)
	return card


## "This week only · A late night before Saturday's race." (whose choice it is, then the clash or the late night, else what the
## activity does).
static func _state_line(info: Dictionary) -> String:
	var u := ui()
	var how := str(u.changed_word) if bool(info.changed) else str(u.habit_word)
	var parts := [how.substr(0, 1).to_upper() + how.substr(1)]
	var day := _day_name(info.next.date)
	if str(info.clash) == "race":
		parts.append(str(u.clash_race).format({"day": day}))
	elif str(info.clash) == "hard":
		parts.append(str(u.clash_hard).format({"day": day}))
	elif bool(info.late) and info.invite.is_empty() and bool(info.next.school):
		parts.append(str(u.late_school).format({"day": day}))
	elif not bool(info.played) and info.invite.is_empty():
		parts.append(str(Data.habits.activities.get(str(info.activity), {}).get("does", "")))
	return " · ".join(parts.filter(func(x): return str(x) != ""))


## The four activities (the current one shown pressed) and "Back to my habit (Study)" when this week's slot was changed.
static func _activity_buttons(hs: HabitSystem, d: int, info: Dictionary, on_change: Callable) -> Control:
	var col := UIKit.vbox(6)
	var grid := GridContainer.new()
	grid.columns = 2   # (2 x 2: the picker is a half-width card on PC and the day editor a narrow side panel)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var current := hs.week_slot(d)
	var group := ButtonGroup.new()
	for act in HabitSystem.ACTIVITIES:
		var b := _activity_toggle(str(act), group, current == act)
		b.pressed.connect(func():
			hs.set_slot(d, str(act))
			on_change.call())
		grid.add_child(b)
	col.add_child(grid)
	if bool(info.changed):
		var back := UIKit.button(str(ui().picker_habit).format({"activity": HabitSystem.activity_name(hs.habit(d))}), false, 0.0)
		back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back.pressed.connect(func():
			hs.reset_slot(d)
			on_change.call())
		col.add_child(back)
	return col


## A 44 px toggle with an activity's icon and name.
static func _activity_toggle(act: String, group: ButtonGroup, on: bool) -> Button:
	var b := UIKit.toggle("", group)
	b.button_pressed = on
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 44)
	var row := UIKit.hbox(6)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Icons.rect(HabitSystem.activity_icon(act), 16.0, Palette.TEXT if on else Palette.TEXT_MUTED))
	var l := UIKit.label(HabitSystem.activity_name(act), "ItemLabel")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	b.add_child(row)
	b.set_meta("activity", act)
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, 96.0)
	return b


# --- Invitations -----------------------------------------------------------------------------------------------------------------

## An invitation as a planner card: "Sat: Saturday evening with Eino?", its price, its replies (the accepting ones first in ACCENT).
## A planned one shows what you chose and "Change my mind".
static func invite_card(m: Dictionary, on_change: Callable) -> CalloutCard:
	var d := Calendar.weekday(StoryletSystem._date_of(int(m.slot_day)))
	var title := str(ui().invite_title).format({"slot": slot_label(d), "title": str(m.invite.title)})
	var card := CalloutCard.new(Palette.PEOPLE, "party-popper", title, "", [])
	card.set_meta("invite", str(m.id))
	card.add_row(_invite_part(m, on_change))
	return card


## The price lines and the replies (or, planned: what you chose + Change my mind).
static func _invite_part(m: Dictionary, on_change: Callable) -> Control:
	var u := ui()
	var col := UIKit.vbox(6)
	var price := UIKit.wrapped(" ".join(price_lines(m)), "WhyLabel")
	price.add_theme_font_size_override("font_size", 16 if Layout.compact else 13)
	col.add_child(price)
	var ms := moments()
	var planned := str(m.get("planned", ""))
	var d := Calendar.weekday(StoryletSystem._date_of(int(m.slot_day)))
	if str(m.answer) != "":
		return col
	if planned != "":
		var hs := system()
		var go: bool = planned in m.invite.go
		var act := str(m.invite.activity) if go else hs.week_slot(d)
		var line := str(u.invite_going if go else u.invite_staying).format({"slot": slot_label(d, true),
				"activity": HabitSystem.activity_name(act).to_lower()})
		col.add_child(UIKit.wrapped(line, "BodyLabel"))
		var again := UIKit.button(str(u.invite_change), false, 0.0)
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
		again.pressed.connect(func():
			ms.unplan(str(m.id))
			on_change.call())
		col.add_child(again)
		return col
	price.text += " " + str(u.invite_leave)   # (open: what leaving it means; Play week doesn't ask about it)
	var replies := UIKit.vbox(6)
	var order: Array = m.replies.filter(func(r): return r.id in m.invite.go) + m.replies.filter(func(r): return not r.id in m.invite.go)
	for r in order:
		var b := UIKit.button(str(r.label), r.id in m.invite.go and r == order[0], 0.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if not (r.id in m.invite.go and r == order[0]) else HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("reply", str(r.id))
		b.pressed.connect(func():
			ms.answer(str(m.id), str(r.id))
			on_change.call())
		replies.add_child(b)
	col.add_child(replies)
	return col


## What going costs and what staying home costs, honest about what the game simulates: the late night and the day after it (a
## race, a session, a rest day, school), the grades, and the friendship if you stay home.
static func price_lines(m: Dictionary) -> Array:
	var u := ui()
	var ms := moments()
	var hs := system()
	var out := []
	if ms == null or hs == null:
		return out
	var s := ms.storylet(str(m.storylet))
	var go_rep := {}
	var stay_rep := {}
	for r in s.get("replies", []):
		if str(r.id) in m.invite.go:
			if go_rep.is_empty():
				go_rep = r
		elif stay_rep.is_empty() or float(r.get("effects", {}).get("relation", 0.0)) < float(stay_rep.get("effects", {}).get("relation", 0.0)):
			stay_rep = r
	var date := StoryletSystem._date_of(int(m.slot_day))
	var w := Game.current_week()
	var sleep := float(go_rep.get("effects", {}).get("sleep", 0.0))
	if sleep < 0.0 and Calendar.date_key(Calendar.monday_of(date)) == Calendar.date_key(w.monday):
		var nx := hs._next_day(w, Calendar.weekday(date))
		var sl := str(u.price_sleep_2 if sleep <= -2.0 else u.price_sleep_1)
		var day := _day_name(nx.date)
		if not nx.race.is_empty():
			out.append(str(u.price_race).format({"sleep": sl, "day": day}))
		elif bool(nx.school):
			out.append(str(u.price_school).format({"sleep": sl}))
		elif (nx.sessions as Array).is_empty():
			out.append(str(u.price_rest).format({"sleep": sl, "day": day}))
		else:
			out.append(str(u.price_session).format({"sleep": sl, "day": day, "session": Icons.session_short(str(nx.sessions[0])).to_lower()}))
	if float(go_rep.get("effects", {}).get("grades", 0.0)) > 0.0:
		out.append(str(u.price_grades))
	var rel := float(stay_rep.get("effects", {}).get("relation", 0.0))
	var p: Dictionary = ms.people.get(str(m.from), {})
	if rel < 0.0 and not p.is_empty():
		var change := ms._change_line(str(Data.moments.changes.relation).format({"who": StoryletSystem.short_name(p)}), rel)
		out.append(str(u.price_stay).format({"change": change}))
	if out.is_empty():
		out.append(str(u.price_none))
	return out


static func _day_name(date: Dictionary) -> String:
	return str(Data.moments.day_names[Calendar.weekday(date)])


# --- The day editor and the day's blocks -----------------------------------------------------------------------------------------

## The evening line of the day's blocks: "Friends (your habit)" / "Study (this week only)" / "A party on Friday? (an invitation)".
static func evening_text(date: Dictionary) -> String:
	var hs := system()
	if hs == null:
		return ""
	var u := ui()
	var d := Calendar.weekday(date)
	var inv := HabitSystem.invitation_on(date)
	var played := StoryletSystem.day_no(date) < StoryletSystem.day_no(Game.date)
	var how := str(u.habit_word)
	if not played and Calendar.date_key(Calendar.monday_of(date)) == Calendar.date_key(Game.week_monday()) and hs.changed(d):
		how = str(u.changed_word)
	if not inv.is_empty() and HabitSystem.going(inv):
		return str(u.evening_invite).format({"title": str(inv.invite.title), "how": str(u.chip_more)})
	return str(u.evening_line).format({"activity": HabitSystem.activity_name(hs.activity_on(date)), "how": how})


## The day editor's FREE TIME box for day `d` of this week: the slot's picker without its Close (null without the habit system).
static func editor_box(w: WeekSim, d: int, on_change: Callable) -> Control:
	var hs := system()
	if hs == null:
		return null
	var u := ui()
	var info := hs.slot_info(w, d)
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label("%s · %s" % [str(u.editor_head), slot_label(d, true).to_upper()], "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(u.picker_title).format({"slot": slot_label(d, true), "activity": HabitSystem.activity_name(str(info.activity))})
			+ " · " + _state_line(info), "MutedLabel"))
	if not info.invite.is_empty():
		box.add_child(UIKit.label(str(info.invite.invite.title), "SubheadingLabel"))
		box.add_child(_invite_part(info.invite, on_change))
	if bool(info.played):
		box.add_child(UIKit.wrapped(str(u.picker_played), "MutedLabel"))
	elif info.invite.is_empty() or not HabitSystem.going(info.invite):   # (going out: the evening is the invitation's)
		box.add_child(_activity_buttons(hs, d, info, on_change))
	return UIKit.panel(box, 14)


# --- The Season tab: YOUR HABITS -------------------------------------------------------------------------------------------------

## The standing habits: a row per slot (PC: the four activities as toggles; phone: a chip that opens them under the row), what the
## week adds up to, Back to the default. `on_change` after a change (the hub redraws the planner's week). Null without the system.
static func section(on_change := Callable()) -> Control:
	var hs := system()
	if hs == null:
		return null
	var u := ui()
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label(str(u.section_head), "SectionLabel"))
	box.add_child(UIKit.wrapped(str(u.section_text), "WhyLabel"))
	var summary := UIKit.wrapped(hs.summary(), "BodyLabel")
	var rows := UIKit.vbox(6)
	var back := UIKit.button(str(u.back_to_default), false, 0.0)
	var cb := {}   # (lambdas capture locals by value: they reach each other through this dictionary)
	cb.fill = func():
		for c in rows.get_children():
			rows.remove_child(c)
			c.queue_free()
		for i in 7:
			rows.add_child(_habit_row(hs, i, func(): cb.refresh.call()))
	cb.refresh = func():
		summary.text = hs.summary()
		back.disabled = hs.is_default()
		cb.fill.call()
		if on_change.is_valid():
			on_change.call()
	cb.fill.call()
	box.add_child(rows)
	box.add_child(summary)
	back.disabled = hs.is_default()
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func():
		hs.reset_habits()
		cb.refresh.call())
	box.add_child(back)
	box.set_meta("habits_section", true)
	return UIKit.panel(box, 16)


## Phone: which habit row has its choices open (kept while the tab redraws).
static var open_row := -1


static func _habit_row(hs: HabitSystem, i: int, refresh: Callable) -> Control:
	var current := hs.habit(i)
	var name := UIKit.label(slot_label(i, true), "ItemLabel")
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not Layout.stacked():
		var row := UIKit.hbox(8)
		name.custom_minimum_size.x = 150
		row.add_child(name)
		var group := ButtonGroup.new()
		for act in HabitSystem.ACTIVITIES:
			var b := _activity_toggle(str(act), group, current == act)
			b.pressed.connect(func():
				hs.set_habit(i, str(act))
				refresh.call())
			row.add_child(b)
		row.set_meta("habit_row", i)
		return row
	var col := UIKit.vbox(6)
	var head := UIKit.hbox(8)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var chip_b := UIKit.button(HabitSystem.activity_name(current), false, 0.0)
	chip_b.icon = Icons.texture(HabitSystem.activity_icon(current))
	chip_b.expand_icon = false
	chip_b.add_theme_constant_override("icon_max_width", 16)
	chip_b.custom_minimum_size = Vector2(150, 44)
	chip_b.pressed.connect(func():
		open_row = -1 if open_row == i else i
		refresh.call())
	head.add_child(chip_b)
	col.add_child(head)
	if open_row == i:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		var group := ButtonGroup.new()
		for act in HabitSystem.ACTIVITIES:
			var b := _activity_toggle(str(act), group, current == act)
			b.pressed.connect(func():
				hs.set_habit(i, str(act))
				open_row = -1
				refresh.call())
			grid.add_child(b)
		col.add_child(grid)
	col.set_meta("habit_row", i)
	return col


# --- The School page ---------------------------------------------------------------------------------------------------------------

## "Your evenings: 4 study slots a week · Grades hold" and "Change my habits" (opens the Season tab). Null without the system.
static func school_line() -> Control:
	var hs := system()
	if hs == null:
		return null
	var u := ui()
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(Data.school_life.ui.settings_head), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(Data.habits.summary.school_line).format({"study": int(HabitSystem.counts(hs.habits).study),
			"grades": hs.grades_word()}), ""))
	box.add_child(UIKit.wrapped(hs.summary(), "MutedLabel"))
	if hub_ref != null and hub_ref.get_ref() != null:
		var b := UIKit.button(str(u.school_button), false, 200)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func(): HabitsUI.open_season())
		box.add_child(b)
	return UIKit.panel(box, 16)
