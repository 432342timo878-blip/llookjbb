class_name DayEditor
extends VBoxContainer
## The day editor (GDD 4.5 "Hub UI"): one day of the current week. The hub shows it as a side panel on PC and
## as a bottom sheet on a phone. It builds one of three views:
##   - a day that can still be changed: sessions (swap, remove, add up to 2), Rest day, intensity,
##     the day's load, who changed it, and Back to plan;
##   - a played day: read-only, what was actually done (from the day log);
##   - a race day: read-only, with the meet.
## Everything is a 44 px control and nothing needs hovering (descriptions are shown as text).
## All changes go through the WeekSim day-change functions; `changed` tells the hub to redraw the strip.

signal changed          # a day change was made
signal close_requested
signal rebuilt          # the content was redrawn (the phone sheet re-fits its height)

var day := 0
var _adding := false    # an empty "Choose a session" row is open


func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func show_day(d: int) -> void:
	day = d
	_adding = false
	refresh()


func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var w := Game.current_week()
	var info := DayInfo.of(w, day)
	add_child(_header(info))
	if info.played:
		_build_played(info)
	elif not info.race.is_empty():
		_build_race(info)
	else:
		_build_editable(w, info)
	rebuilt.emit()


func _after_change() -> void:
	_adding = false
	refresh()
	changed.emit()


func _header(info: Dictionary) -> Control:
	var row := UIKit.hbox(8)
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.wrapped(Calendar.format_day(info.date), "HeadingLabel"))
	var status: String
	if info.played:
		status = "PLAYED"
	elif info.today:
		status = "TODAY"
	else:
		status = DayInfo.days_away(info.date).to_upper()
	if not info.race.is_empty() and not info.played:
		status += " · RACE DAY"
	titles.add_child(UIKit.label(status, "CaptionLabel"))
	row.add_child(titles)
	var close := UIKit.button("Close", false, 90)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func(): close_requested.emit())
	row.add_child(close)
	return row


# --- A day that can be changed -----------------------------------------------------------------------

func _build_editable(w: WeekSim, info: Dictionary) -> void:
	var month := DayInfo.month_of(w)
	var ids: Array = info.sessions

	var sessions := UIKit.vbox(8)
	sessions.add_child(UIKit.label("SESSIONS", "CaptionLabel"))
	if ids.is_empty() and not _adding:
		sessions.add_child(UIKit.wrapped("Rest day: no training.", ""))
	for slot in ids.size():
		sessions.add_child(_slot(slot, ids[slot], month))
	if _adding:
		sessions.add_child(_new_slot(month))
	var buttons := UIKit.hbox(8)
	if ids.size() < Training.MAX_SESSIONS_PER_DAY and not _adding:
		var add := UIKit.button("Add session", false, 120)
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add.pressed.connect(func():
			_adding = true
			refresh())
		buttons.add_child(add)
	if not ids.is_empty():
		var rest := UIKit.button("Rest day", false, 120)
		rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rest.pressed.connect(func():
			if Game.current_week().make_rest_day(day):
				_after_change())
		buttons.add_child(rest)
	if buttons.get_child_count() > 0:
		sessions.add_child(buttons)
	add_child(UIKit.panel(sessions, 14))

	add_child(UIKit.panel(_intensity_box(info), 14))

	var summary := UIKit.vbox(6)
	var load_text := "%d" % roundi(info.load)
	var plan_load := DayInfo.planned_load(w.plan[day], WeekSim.NORMAL, month)
	if info.changed and roundi(plan_load) != roundi(info.load):
		load_text += "  (plan %d)" % roundi(plan_load)
	summary.add_child(UIKit.fact_row("Load for the day", UIKit.label(load_text)))
	if info.changed:
		summary.add_child(UIKit.fact_row("Weekly plan", _wrapped_value(_names_or_rest(w.plan[day]))))
		summary.add_child(UIKit.wrapped(DayInfo.changed_text(info), ""))
		# The coach's Veto button goes here, next to "Back to plan", once coaching exists (GDD 4.7:
		# changes remember who made them, and a coach change shows Accept / Veto).
		var back := UIKit.button("Back to plan", false, 160)
		back.pressed.connect(func():
			if Game.current_week().reset_day(day):
				_after_change())
		summary.add_child(back)
	else:
		summary.add_child(UIKit.wrapped("This is the weekly plan. Changes here apply to this day only.", "MutedLabel"))
	add_child(UIKit.panel(summary, 14))


## One session of the day: a picker to swap it, a Remove button, and what it is.
func _slot(slot: int, id: String, month: int) -> Control:
	var col := UIKit.vbox(4)
	var row := UIKit.hbox(8)
	var pick := _picker(month, false)
	for i in pick.item_count:
		if pick.get_item_metadata(i) == id:
			pick.select(i)
	pick.item_selected.connect(func(i: int):
		if Game.current_week().swap_session(day, slot, str(pick.get_item_metadata(i))):
			_after_change())
	row.add_child(pick)
	var remove := UIKit.button("Remove", false, 88)
	remove.pressed.connect(func():
		if Game.current_week().skip_session(day, slot):
			_after_change())
	row.add_child(remove)
	col.add_child(row)

	var s := Data.get_session(id)
	var eff := Training.effectiveness(Game.athlete, s, month)
	col.add_child(UIKit.wrapped(s.get("description", "")))
	if eff == 0.0:
		var warn := UIKit.wrapped("Not possible this time of year (%s): it will be skipped." % DayInfo.unavailable_text(s), "")
		warn.add_theme_color_override("font_color", Palette.ATTR_POOR)
		col.add_child(warn)
	elif eff < 1.0:
		col.add_child(UIKit.wrapped("No indoor track for you in winter: done on roads, less effective."))
	return col


## The row for a session that is being added: a picker that starts on "Choose a session".
func _new_slot(month: int) -> Control:
	var row := UIKit.hbox(8)
	var pick := _picker(month, true)
	pick.item_selected.connect(func(i: int):
		var id := str(pick.get_item_metadata(i))
		if id != "" and Game.current_week().add_session(day, id):
			_after_change())
	row.add_child(pick)
	var cancel := UIKit.button("Cancel", false, 92)
	cancel.pressed.connect(func():
		_adding = false
		refresh())
	row.add_child(cancel)
	return row


## Every session; those that aren't possible this month are greyed out with the reason in the name.
func _picker(month: int, with_placeholder: bool) -> OptionButton:
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(0, 44)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.fit_to_longest_item = false   # a long name must never widen the panel
	pick.clip_text = true
	if with_placeholder:
		pick.add_item("Choose a session…")
		pick.set_item_metadata(0, "")
	for s in Data.training.sessions:
		var eff := Training.effectiveness(Game.athlete, s, month)
		var text: String = s.name
		if eff == 0.0:
			text += " (%s)" % DayInfo.unavailable_text(s)
		elif eff < 1.0:
			text += " (no track)"
		pick.add_item(text)
		var i := pick.item_count - 1
		pick.set_item_metadata(i, s.id)
		pick.set_item_disabled(i, eff == 0.0)
	return pick


func _intensity_box(info: Dictionary) -> Control:
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label("INTENSITY", "CaptionLabel"))
	var group := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for level in Training.INTENSITIES:
		var b := UIKit.toggle(Training.intensity(level).name, group)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = level == info.intensity
		b.pressed.connect(func():
			if Game.current_week().set_intensity(day, level):
				_after_change())
		row.add_child(b)
	box.add_child(row)
	var current := Training.intensity(info.intensity)
	var text: String = current.description
	if info.intensity != WeekSim.NORMAL:
		text += " Tiring ×%s, training effect ×%s." % [_x(current.load), _x(current.effect)]
	box.add_child(UIKit.wrapped(text))
	if info.sessions.is_empty():
		box.add_child(UIKit.wrapped("Rest day: there are no sessions, so intensity changes nothing."))
	return box


# --- A day that was played ---------------------------------------------------------------------------

func _build_played(info: Dictionary) -> void:
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label("WHAT YOU DID", "CaptionLabel"))
	if not info.race.is_empty():
		box.add_child(UIKit.wrapped("Race: %s" % info.race.name, "SubheadingLabel"))
		var result := DayInfo.race_result_text(info.race.key)
		if result != "":
			box.add_child(UIKit.wrapped(result, ""))
	elif info.sessions.is_empty():
		box.add_child(UIKit.wrapped("Rest day", "SubheadingLabel"))
	else:
		for session_name in DayInfo.session_names(info.sessions):
			box.add_child(UIKit.wrapped(session_name, "SubheadingLabel"))
	if info.race.is_empty():
		var level_label := UIKit.label(DayInfo.intensity_name(info.intensity))
		level_label.add_theme_color_override("font_color", DayInfo.intensity_color(info.intensity))
		box.add_child(UIKit.fact_row("Intensity", level_label))
	box.add_child(UIKit.fact_row("Load", UIKit.label(str(roundi(info.load)))))
	if info.fatigue >= 0.0:
		box.add_child(UIKit.fact_row("Fatigue after", UIKit.fatigue_label(info.fatigue)))
	if info.changed:
		box.add_child(UIKit.wrapped(DayInfo.changed_text(info), "MutedLabel"))
	add_child(UIKit.panel(box, 14))

	if not info.events.is_empty():
		var events := UIKit.vbox(6)
		events.add_child(UIKit.label("EVENTS", "CaptionLabel"))
		for e in info.events:
			events.add_child(UIKit.wrapped(e.title, "SubheadingLabel"))
			events.add_child(UIKit.wrapped(e.text))
		add_child(UIKit.panel(events, 14))
	add_child(UIKit.wrapped("This day is over, so it can't be changed.", "MutedLabel"))


# --- A race day --------------------------------------------------------------------------------------

func _build_race(info: Dictionary) -> void:
	var meet: Dictionary = info.race
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label("RACE", "CaptionLabel"))
	box.add_child(UIKit.wrapped(meet.name, "HeadingLabel"))
	box.add_child(UIKit.wrapped("%s · %s" % [Calendar.format_meet_date(meet), Calendar.place(Game.athlete, meet)], "MutedLabel"))
	var level: String = Data.competitions.levels.get(meet.level, "")
	if level != "":
		box.add_child(UIKit.wrapped(level, "MutedLabel"))
	box.add_child(UIKit.wrapped("The race replaces the day's training, so there is nothing to plan here. "
			+ "You can't change a race day."))
	# Scratching the race (not starting) comes here with the health UI (M2 step 4, GDD 4.6).
	add_child(UIKit.panel(box, 14))


# --- Helpers -----------------------------------------------------------------------------------------

func _names_or_rest(ids: Array) -> String:
	return "Rest day" if ids.is_empty() else " + ".join(DayInfo.session_names(ids))


## A right-hand value that wraps instead of widening the row.
func _wrapped_value(text: String) -> Label:
	var l := UIKit.wrapped(text, "")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## 0.70 -> "0.7", 1.15 -> "1.15"
func _x(v: Variant) -> String:
	var t := "%.2f" % float(v)
	return t.rstrip("0").rstrip(".")
