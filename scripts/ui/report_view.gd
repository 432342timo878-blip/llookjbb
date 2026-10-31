class_name ReportView
extends VBoxContainer
## "Last week in full" (a page of the This week tab; GDD 4.10 decision 2, session L2b restyled it to V1, GDD 5): last week's
## sessions done, its races (a strap opens the race's card), the plan, load and tiredness, then every change with its recorded
## cause, a row each, the exact numbers on a tap (WeekCauses / CausesUI): attributes, the body, the moods, people, school tests,
## the free-time slots' effects, invitations, the week's notes; the days one by one (folded); this week so far (folded).
## PC: two columns; a phone or beside the hub's side panel: one. Built when shown; reading only.

signal card_pressed(id: String)


func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func t() -> Dictionary:
	return Data.causes.report


func _ready() -> void:
	var r: Dictionary = Game.last_report
	var note := HealthUI.proneness_note()   # after repeated injuries
	if note != null:
		add_child(note)
	if not r.is_empty():
		_add_last_week(r)
	var monday := Game.week_monday()
	var rows := _days_of(monday)
	if not rows.is_empty() or r.is_empty():
		var box := UIKit.vbox(8)
		box.add_child(WeekPlanner._head(str(t().this_week), WeekPlanner.range_text(monday)))
		if rows.is_empty():
			box.add_child(UIKit.wrapped(str(t().none_this_week), "WhyLabel"))
		else:
			box.add_child(_days_box(rows, true))
		add_child(WeekPlanner._panel(box))


# --- Last week ---------------------------------------------------------------------------------------------------------------

func _add_last_week(r: Dictionary) -> void:
	var head := UIKit.vbox(8)
	head.add_child(WeekPlanner._head(str(t().title), WeekPlanner.range_text(r.monday)))
	head.add_child(WeekPlanner._done_row(r))
	for strap in WeekPlanner.race_straps(r, func(id: String): card_pressed.emit(id)):
		head.add_child(strap)
	head.add_child(_facts(r))
	if not r.has("parts"):
		head.add_child(UIKit.wrapped(str(t().old_report), "WhyLabel"))
	else:
		head.add_child(UIKit.wrapped(str(t().tap_hint), "WhyLabel"))
	add_child(WeekPlanner._panel(head))

	var attrs := WeekCauses.attr_rows(r)
	attrs.sort_custom(func(x, y): return float(x.size) > float(y.size))
	var body := WeekCauses.injury_rows(r) + WeekCauses.body_rows(r)
	var left := [CausesUI.section(str(t().attributes), attrs, str(t().no_attrs)), CausesUI.section(str(t().body), body)]
	var right := [CausesUI.section(str(t().moods), WeekCauses.mood_rows(r)),
			CausesUI.section(str(Data.causes.mental.title).to_upper(), WeekCauses.mental_rows(r)),   # (session L3b1)
			CausesUI.section(str(t().people), WeekCauses.people_rows(r)),
			CausesUI.section(str(t().school), WeekCauses.test_rows(r)), _free_time(r),
			CausesUI.section(str(t().invites), WeekCauses.invite_rows(r)), _notes(r)]
	left = left.filter(func(x): return x != null)
	right = right.filter(func(x): return x != null)
	if Layout.stacked():
		for s in left + right:
			add_child(WeekPlanner._panel(s))
	else:
		var cols := UIKit.hbox(12)
		for list in [left, right]:
			var col := UIKit.vbox(12)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for s in list:
				col.add_child(WeekPlanner._panel(s))
			cols.add_child(col)
		add_child(cols)
	var days := _days_of(r.monday)
	if not days.is_empty():
		add_child(WeekPlanner._panel(_days_box(days, false)))


## The week's plan (a line that wraps: it can be long), then load and tiredness as raised facts.
func _facts(r: Dictionary) -> Control:
	var box := UIKit.vbox(6)
	if r.get("plan") is Dictionary and not r.plan.is_empty():
		box.add_child(UIKit.wrapped("%s: %s" % [str(t().plan), SeasonUI.week_text(r.plan)], "WhyLabel"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.add_child(_fact("", str(t().load_plain).format({"load": roundi(float(r.load))})))
	flow.add_child(_fact("", str(t().fatigue).format({"before": roundi(float(r.fatigue_start)), "after": roundi(float(r.fatigue_end))})))
	box.add_child(flow)
	return box


static func _fact(head: String, text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.raised_box(8))
	var row := UIKit.hbox(6)
	if head != "":
		row.add_child(UIKit.label(head, "WhyLabel"))
	var l := UIKit.label(text, "ItemLabel")
	row.add_child(l)
	p.add_child(row)
	return p


## FREE TIME: the slots' effects as rows, then the week's nine slots in one line.
func _free_time(r: Dictionary) -> Control:
	var rows := WeekCauses.slot_rows(r)
	var slots: Array = r.get("slots", [])
	if rows.is_empty() and slots.is_empty():
		return null
	var box := UIKit.vbox(2)
	box.add_child(UIKit.label(str(t().free_time), "SectionLabel"))
	for x in rows:
		box.add_child(CausesUI.line_row(x))
	if not slots.is_empty():
		var parts := []
		for i in slots.size():
			parts.append("%s %s" % [HabitSystem.slot_short(i), HabitSystem.activity_name(str(slots[i])).to_lower()])
		box.add_child(UIKit.wrapped(" · ".join(parts), "WhyLabel"))
	return box


## NOTES: the week's own notes (off-track sessions, a tired week, a week off).
func _notes(r: Dictionary) -> Control:
	var notes: Array = r.get("notes", [])
	if notes.is_empty():
		return null
	var box := UIKit.vbox(4)
	box.add_child(UIKit.label(str(t().notes), "SectionLabel"))
	for n in notes:
		box.add_child(UIKit.wrapped(str(n), "BodyLabel"))
	return box


# --- Days ------------------------------------------------------------------------------------------------------------------------

## The played days of the week starting `monday` from the day log, in order.
static func _days_of(monday: Dictionary) -> Array:
	var lo := Calendar.date_key(monday)
	var hi := Calendar.date_key(Game.add_days(monday, 6))
	var rows := []
	for e in Game.day_log:
		var key := Calendar.date_key(e.date)
		if key >= lo and key <= hi:
			rows.append(e)
	return rows


## "Day by day (n)": a 44 px fold (closed unless `open`) with a row per day.
func _days_box(rows: Array, open: bool) -> Control:
	var title := str(t().day_by_day).format({"n": rows.size()})
	var box := UIKit.vbox(6)
	var head := UIKit.button(("▾  " if open else "▸  ") + title, false, 0.0)
	head.theme_type_variation = "FlatButton"
	head.custom_minimum_size.y = 44
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(head)
	var list := UIKit.vbox(0)
	for e in rows:
		list.add_child(_day_row(e))
	list.visible = open
	box.add_child(list)
	head.pressed.connect(func():
		list.visible = not list.visible
		head.text = ("▾  " if list.visible else "▸  ") + title)
	return box


## One played day (V1): the date, what was done with its icons in the intensity colour, tiredness and load; under it its school,
## health and events lines.
func _day_row(e: Dictionary) -> Control:
	var box := UIKit.vbox(2)
	var head := UIKit.hbox(8)
	var day := UIKit.label(DayInfo.short_day(e.date), "ItemLabel")
	day.custom_minimum_size.x = 92
	head.add_child(day)
	var what := UIKit.hbox(6)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var color := Palette.intensity(str(e.intensity))
	if e.race != "":
		what.add_child(Icons.rect("flag", 16.0, Palette.LEAD))
		var result := DayInfo.race_result_text(e.race)
		what.add_child(UIKit.wrapped(str(Calendar.get_meet(e.race).get("name", e.race)) + (" · " + result if result != "" else ""), "BodyLabel"))
	elif e.sessions.is_empty():
		what.add_child(Icons.rect("moon", 16.0, Palette.DAY_REST))
		what.add_child(UIKit.label(str(Data.planner.ui.rest_word), "BodyLabel"))
	else:
		for sid in e.sessions:
			what.add_child(Icons.rect(Icons.session(str(sid)), 16.0, color))
		var names := " + ".join(e.sessions.map(func(s): return Icons.session_short(str(s))))
		if e.intensity != WeekSim.NORMAL:
			names += " · " + DayInfo.intensity_name(e.intensity)
		what.add_child(UIKit.wrapped(names, "BodyLabel"))
	for c in what.get_children():
		if c is Label:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(what)
	var nums := UIKit.label(str(t().day_nums).format({"f": roundi(float(e.fatigue)), "load": roundi(float(e.load))}), "ChipNumber")
	nums.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	head.add_child(nums)
	box.add_child(head)
	var lines := []
	if e.get("dragged", false):
		lines.append(str(t().dragged))
	lines.append_array(SchoolUI.report_lines(e))
	for line in _health_lines(e):
		lines.append(line)
	for ev in DayInfo.events_of(e):
		var text: String = "• " + ev.title
		if ev.answer != "":
			for c in ev.choices:
				if c.id == ev.answer:
					text += " → " + c.label
		lines.append(text)
	for line in lines:
		var l := UIKit.wrapped(str(line), "WhyLabel")
		box.add_child(l)
	var wrap := UIKit.vbox(0)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 6)
	pad.add_child(box)
	wrap.add_child(pad)
	var div := ColorRect.new()
	div.color = Palette.DIVIDER
	div.custom_minimum_size.y = 1
	wrap.add_child(div)
	return wrap


## The health side of a played day (its day log entry): injuries and illnesses that were active after the day, sore areas.
static func _health_lines(e: Dictionary) -> Array:
	var lines := []
	if HealthUI.system() == null:
		return lines
	for id in e.get("health", []):
		var data := Data.get_injury(str(id))
		if not data.is_empty():
			lines.append("%s (%s)" % [data.name, str(HealthUI.TIER_NAMES[data.tier]).to_lower()])
	var levels: Dictionary = e.get("soreness", {})
	var parts := []
	for area in HealthSystem.areas():   # in the body areas' order
		var level := int(levels.get(area.id, 0))
		if level > 0:
			parts.append("%s %s" % [area.name.to_lower(), HealthUI.level_word(level).to_lower()])
	if not parts.is_empty():
		lines.append(str(t().sore).format({"list": ", ".join(parts)}))
	return lines
