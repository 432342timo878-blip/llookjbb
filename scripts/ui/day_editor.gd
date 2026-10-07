class_name DayEditor
extends VBoxContainer
## The day editor (GDD 4.5 "Hub UI"): one day of the current week. The hub shows it as a side panel on PC and
## as a bottom sheet on a phone. It builds one of three views:
##   - a day that can still be changed: sessions (swap, remove, add up to 2), Rest day, intensity,
##     the day's load, who changed it, and Back to plan. With the health model: soreness today, the injury
##     limits of the day (banned sessions greyed out with the reason, intensity capped, "Train through it"
##     with a warning where it's allowed);
##   - a played day: read-only, what was actually done (from the day log, with soreness and injuries);
##   - a race day: read-only, with the meet, a warning when racing injured and a Scratch button.
## Everything is a 44 px control and nothing needs hovering (descriptions are shown as text).
## All changes go through the WeekSim day-change functions; `changed` tells the hub to redraw the strip.

signal changed          # a day change was made
signal close_requested
signal help_requested   # the "?" next to Close: the hub opens the day editor's help
signal rebuilt         # the content was redrawn (the phone sheet re-fits its height)

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
	var help := HelpButton.new("day_editor")
	help.pressed.connect(func(): help_requested.emit())
	row.add_child(help)
	var close := UIKit.button("Close", false, 90)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func(): close_requested.emit())
	row.add_child(close)
	return row


# --- A day that can be changed -----------------------------------------------------------------------

func _build_editable(w: WeekSim, info: Dictionary) -> void:
	var month := DayInfo.month_of(w)
	var ids: Array = info.sessions

	var health := _health_box(info)
	if health != null:
		add_child(health)

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
	var plan_load := DayInfo.planned_load(w.plan[day], w.plan_intensity[day], month)
	if info.changed and roundi(plan_load) != roundi(info.load):
		load_text += "  (plan %d)" % roundi(plan_load)
	summary.add_child(UIKit.fact_row("Load for the day", UIKit.label(load_text)))
	# The season plan's reason for the day (GDD 4.8 UI): "Easy: race tomorrow", "Taper: … in 3 days", "Lighter week".
	# Easing back in after a layoff gives its reason in both modes, with "Stop easing back in…".
	var season_plan := Game.season.mode == SeasonPlan.PHASES
	var plan_why: Array = Game.season.week_for(w.monday).get("why", [])
	if not plan_why.is_empty() and plan_why[day] != "":
		summary.add_child(UIKit.fact_row("Season plan" if season_plan else "Plan", _wrapped_value(plan_why[day])))
	if Game.season.return_day(Game.add_days(w.monday, day)) >= 0 and day >= w.day:
		summary.add_child(SeasonUI.return_stop_control(func():
			HealthUI.refresh()
			_after_change()))
	if info.changed:
		var plan_text := _names_or_rest(w.plan[day])
		if not w.plan[day].is_empty() and w.plan_intensity[day] != WeekSim.NORMAL:
			plan_text += " · " + DayInfo.intensity_name(w.plan_intensity[day])
		summary.add_child(UIKit.fact_row("Weekly plan", _wrapped_value(plan_text)))
		summary.add_child(UIKit.wrapped(DayInfo.changed_text(info), ""))
		# The coach's Veto button goes here, next to "Back to plan", once coaching exists (GDD 4.7:
		# changes remember who made them, and a coach change shows Accept / Veto).
		if info.by.values().all(func(who): return who == "injury"):
			summary.add_child(UIKit.wrapped("Your injury sets these limits. They go away when you've recovered.", "MutedLabel"))
		else:
			var back := UIKit.button("Back to plan", false, 160)
			back.pressed.connect(func():
				if Game.current_week().reset_day(day):
					HealthUI.refresh()   # the injury limits (if any) go back into the day
					_after_change())
			summary.add_child(back)
	else:
		summary.add_child(UIKit.wrapped("This is your season plan's day. Changes here apply to this day only." if season_plan
				else "This is the weekly plan. Changes here apply to this day only.", "MutedLabel"))
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
	var h := HealthUI.system()
	if h != null and HealthUI.is_overridden(day) and h.ban_reason(id, day) != "":
		var against := UIKit.wrapped("Against your injury limits (%s): more strain, and it may get worse." % h.ban_reason(id, day), "")
		against.add_theme_color_override("font_color", Palette.SORE_3)
		col.add_child(against)
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


## Every session; those that aren't possible this month, or that an injury bans, are greyed out with the reason
## in the name ("(only Dec–Mar)", "(not with Shin splints)"). When you train through the limits, banned
## sessions can be picked and are marked "(against limits)".
func _picker(month: int, with_placeholder: bool) -> OptionButton:
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(0, 44)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.fit_to_longest_item = false   # a long name must never widen the panel
	pick.clip_text = true
	if with_placeholder:
		pick.add_item("Choose a session…")
		pick.set_item_metadata(0, "")
	var h := HealthUI.system()
	var through := HealthUI.is_overridden(day)
	for s in Data.training.sessions:
		var eff := Training.effectiveness(Game.athlete, s, month)
		var banned := h.ban_reason(s.id, day) if h != null else ""
		var text: String = s.name
		var disabled := eff == 0.0
		if eff == 0.0:
			text += " (%s)" % DayInfo.unavailable_text(s)
		elif banned != "" and through:
			text += " (against limits)"
		elif banned != "":
			text += " (not with %s)" % banned.get_slice(": ", 0)
			disabled = true
		elif eff < 1.0:
			text += " (no track)"
		pick.add_item(text)
		var i := pick.item_count - 1
		pick.set_item_metadata(i, s.id)
		pick.set_item_disabled(i, disabled)
	return pick


func _intensity_box(info: Dictionary) -> Control:
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label("INTENSITY", "CaptionLabel"))
	var group := ButtonGroup.new()
	var row := UIKit.hbox(8)
	var cap := _intensity_cap()
	for level in Training.INTENSITIES:
		var b := UIKit.toggle(Training.intensity(level).name, group)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = level == info.intensity
		b.disabled = cap != "" and Training.INTENSITIES.find(level) > Training.INTENSITIES.find(cap)
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
	if cap != "":
		box.add_child(UIKit.wrapped("Your injury limits this day to %s at most." % Training.intensity(cap).name, ""))
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

	if not info.sore_areas.is_empty() or not info.health.is_empty():
		var body := UIKit.vbox(4)
		body.add_child(UIKit.label("HEALTH THAT DAY", "CaptionLabel"))
		for x in info.sore_areas:
			var line := UIKit.wrapped("%s: %s" % [x.name, HealthUI.level_word(int(x.level)).to_lower()], "")
			line.add_theme_color_override("font_color", HealthUI.level_color(int(x.level)))
			body.add_child(line)
		for id in info.health:
			var data := Data.get_injury(str(id))
			var line := UIKit.wrapped("%s (%s)" % [data.get("name", id), HealthUI.TIER_NAMES.get(data.get("tier", ""), "").to_lower()], "")
			line.add_theme_color_override("font_color", HealthUI.tier_color(data.get("tier", "")))
			body.add_child(line)
		add_child(UIKit.panel(body, 14))

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
			+ "You can't change a race day, but you can scratch from the race."))
	# The coach's Veto (GDD 4.7) would sit next to this scratch button once coaching exists.
	box.add_child(HealthUI.scratch_control(meet, _after_change))
	var warning := HealthUI.race_card(HealthUI.race_outlook(day), info.today)
	if warning != null:
		add_child(warning)
	add_child(UIKit.panel(box, 14))
	if info.today:
		var form := FormUI.race_card()   # how you will race today (a later race day: it depends on the days in between)
		if form != null:
			add_child(form)


# --- Health ------------------------------------------------------------------------------------------

## Soreness today and the injury limits of this day, with "Train through it" where that is allowed. Null when
## there is nothing to say (healthy, or the health model is off).
func _health_box(info: Dictionary) -> Control:
	var h := HealthUI.system()
	if h == null:
		return null
	var rule := h.rule_at(day - Game.current_week().day + 1)
	var parts := []
	if info.today and not info.sore_areas.is_empty():
		var sore := UIKit.vbox(4)
		sore.add_child(UIKit.label("SORE TODAY", "CaptionLabel"))
		var worst := 0
		for x in info.sore_areas:
			worst = maxi(worst, int(x.level))
			var line := UIKit.wrapped("%s: %s" % [x.name, HealthUI.level_word(int(x.level)).to_lower()], "")
			line.add_theme_color_override("font_color", HealthUI.level_color(int(x.level)))
			sore.add_child(line)
		sore.add_child(UIKit.wrapped(str(Data.health.ui.soreness_hints[worst])))
		parts.append(UIKit.alert_panel(sore, HealthUI.level_color(worst)))
	if rule.active:
		var through := HealthUI.is_overridden(day)
		var limits := UIKit.vbox(6)
		limits.add_child(UIKit.label("INJURY LIMITS" if not through else "TRAINING THROUGH THE LIMITS", "CaptionLabel"))
		for reason in rule.reasons:
			limits.add_child(UIKit.wrapped(reason, ""))
		var color := Palette.SORE_1
		if through:
			color = Palette.SORE_3
			limits.add_child(UIKit.wrapped("You chose to ignore these limits today. That means more strain, and it may get worse.", ""))
			var back := UIKit.button("Follow the limits again", true, 200)
			back.pressed.connect(func():
				if h.cancel_override(day):
					_after_change())
			limits.add_child(back)
		elif rule.locked:
			color = Palette.SORE_3
			limits.add_child(UIKit.wrapped("Locked: this can't be trained through, and you can't race. "
					+ "Sessions that aren't allowed were swapped for ones that are.", ""))
		else:
			limits.add_child(UIKit.wrapped("Sessions that aren't allowed were swapped for ones that are.", ""))
			var over := HealthUI.through_control(day, _after_change)
			if over != null:
				limits.add_child(over)
		parts.append(UIKit.alert_panel(limits, color))
	if parts.is_empty():
		return null
	var box := UIKit.vbox(8)
	for p in parts:
		box.add_child(p)
	return box


## The most intense setting the injury allows on this day ("" = no limit, or you train through it).
func _intensity_cap() -> String:
	var h := HealthUI.system()
	if h == null or HealthUI.is_overridden(day):
		return ""
	return str(h.rule_at(day - Game.current_week().day + 1).intensity)


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
