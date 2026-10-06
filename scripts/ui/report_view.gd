class_name ReportView
extends VBoxContainer
## The Report tab (GDD 4.5): this week day by day so far (from the day log), then last week's summary
## (the weekly report) with its days. Built when the tab is shown.


func _init() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	var monday := Game.week_monday()
	var note := HealthUI.proneness_note()   # after repeated injuries
	if note != null:
		add_child(note)
	add_child(UIKit.label("This week", "HeadingLabel"))
	add_child(UIKit.wrapped(_range(monday), "MutedLabel"))
	_add_days(monday, "No days played yet this week. Press Next day or Play week.")

	if not Game.last_report.is_empty():
		_add_last_week(Game.last_report)


## "Mon 2 Nov – Sun 8 Nov"
func _range(monday: Dictionary) -> String:
	return "%s – %s" % [DayInfo.short_day(monday), DayInfo.short_day(Game.add_days(monday, 6))]


## The played days of the week starting `monday`, one block each, in a panel.
func _add_days(monday: Dictionary, none_text: String) -> void:
	var lo := Calendar.date_key(monday)
	var hi := Calendar.date_key(Game.add_days(monday, 6))
	var rows := []
	for e in Game.day_log:
		var key := Calendar.date_key(e.date)
		if key >= lo and key <= hi:
			rows.append(e)
	if rows.is_empty():
		add_child(UIKit.wrapped(none_text, "MutedLabel"))
		return
	var box := UIKit.vbox(12)
	for i in rows.size():
		if i > 0:
			box.add_child(HSeparator.new())
		box.add_child(_day_row(rows[i]))
	add_child(UIKit.panel(box, 16))


## One played day: date and fatigue, what was done, intensity and load, then its events.
func _day_row(e: Dictionary) -> Control:
	var box := UIKit.vbox(3)
	var head := UIKit.hbox(8)
	var day := UIKit.label(DayInfo.short_day(e.date), "SubheadingLabel")
	day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(day)
	head.add_child(UIKit.fatigue_label(e.fatigue))
	box.add_child(head)

	var meta := []
	if e.race != "":
		var meet := Calendar.get_meet(e.race)
		var text: String = "Race: %s" % meet.get("name", e.race)
		var result := DayInfo.race_result_text(e.race)
		if result != "":
			text += " (%s)" % result
		box.add_child(UIKit.wrapped(text, ""))
	elif e.sessions.is_empty():
		box.add_child(UIKit.wrapped("Rest day", ""))
	else:
		box.add_child(UIKit.wrapped(" + ".join(DayInfo.session_names(e.sessions)), ""))
		if e.intensity != WeekSim.NORMAL:
			meta.append(DayInfo.intensity_name(e.intensity))
	meta.append("load %d" % roundi(e.load))
	box.add_child(UIKit.wrapped(" · ".join(meta), "MutedLabel"))
	for line in _health_lines(e):
		var l := UIKit.wrapped(line.text, "")
		l.add_theme_color_override("font_color", line.color)
		box.add_child(l)
	for ev in DayInfo.events_of(e):
		var line: String = "• " + ev.title
		if ev.answer != "":
			for c in ev.choices:
				if c.id == ev.answer:
					line += " → " + c.label
		box.add_child(UIKit.wrapped(line, "MutedLabel"))
	return box


## The health side of a played day (from its day log entry): injuries and illnesses that were active
## after the day, and sore areas. [{text, color}], empty on a healthy day or with the health model off.
func _health_lines(e: Dictionary) -> Array:
	var lines := []
	if HealthUI.system() == null:
		return lines
	for id in e.get("health", []):
		var data := Data.get_injury(str(id))
		if not data.is_empty():
			lines.append({"text": "%s (%s)" % [data.name, str(HealthUI.TIER_NAMES[data.tier]).to_lower()],
					"color": HealthUI.tier_color(data.tier)})
	var levels: Dictionary = e.get("soreness", {})
	var worst := 0
	var parts := []
	for area in HealthSystem.areas():   # in the body areas' order
		var level := int(levels.get(area.id, 0))
		if level > 0:
			worst = maxi(worst, level)
			parts.append("%s %s" % [area.name.to_lower(), HealthUI.level_word(level).to_lower()])
	if not parts.is_empty():
		lines.append({"text": "Sore: " + ", ".join(parts), "color": HealthUI.level_color(worst)})
	return lines


# --- Last week ---------------------------------------------------------------------------------------

## One line about the week's injuries, illnesses and soreness from the day log ("" when it was a healthy week).
func _week_health(monday: Dictionary) -> String:
	if HealthUI.system() == null:
		return ""
	var lo := Calendar.date_key(monday)
	var hi := Calendar.date_key(Game.add_days(monday, 6))
	var names := []
	var sore_days := 0
	for e in Game.day_log:
		var key := Calendar.date_key(e.date)
		if key < lo or key > hi:
			continue
		for id in e.get("health", []):
			var n: String = Data.get_injury(str(id)).get("name", id)
			if not n in names:
				names.append(n)
		if not e.get("soreness", {}).is_empty():
			sore_days += 1
	var parts := []
	if not names.is_empty():
		parts.append(", ".join(names))
	if sore_days > 0:
		parts.append("sore on %d day%s" % [sore_days, "" if sore_days == 1 else "s"])
	return "; ".join(parts)


func _add_last_week(r: Dictionary) -> void:
	var a := Game.athlete
	var sunday := Game.add_days(r.monday, 6)
	add_child(UIKit.label("Last week", "HeadingLabel"))
	add_child(UIKit.wrapped("%d.%d. – %d.%d.%d" % [
			r.monday.day, r.monday.month, sunday.day, sunday.month, sunday.year], "MutedLabel"))

	var facts := UIKit.vbox(6)
	facts.add_child(UIKit.fact_row("Sessions", UIKit.label(str(r.sessions))))
	facts.add_child(UIKit.fact_row("Training load", UIKit.label(str(roundi(r.load)))))
	var fat := UIKit.hbox(6)
	fat.add_child(UIKit.fatigue_label(r.fatigue_start))
	fat.add_child(UIKit.label("→", "MutedLabel"))
	fat.add_child(UIKit.fatigue_label(r.fatigue_end))
	facts.add_child(UIKit.fact_row("Fatigue (Mon → Sun)", fat))
	var health := _week_health(r.monday)
	if health != "":
		facts.add_child(UIKit.wrapped("Health: " + health, ""))
	add_child(UIKit.panel(facts, 16))

	for note in r.notes:
		add_child(UIKit.wrapped("• " + note, ""))

	var up := []
	var down := []
	for id in r.changes:
		var c: Dictionary = r.changes[id]
		if roundi(c.after) != roundi(c.before):
			(up if c.after > c.before else down).append(id)
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label("ATTRIBUTES", "CaptionLabel"))
	if up.is_empty() and down.is_empty():
		box.add_child(UIKit.wrapped("No attribute has moved up a whole point this week. Progress builds up slowly, so keep going."))
	for id in up + down:
		var c: Dictionary = r.changes[id]
		var row := UIKit.hbox(8)
		var l := UIKit.label(UIKit.attr_name(id))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.attr_value_label(c.before))
		row.add_child(UIKit.label("→", "MutedLabel"))
		row.add_child(UIKit.trend_arrow(1 if c.after > c.before else -1))
		row.add_child(UIKit.attr_value_label(c.after))
		box.add_child(row)
	var improving := []
	for category in Training.TRAINED_CATEGORIES:
		for attr in Data.attributes_in(category):
			if a.trend(attr.id) > 0:
				improving.append(attr.name.to_lower())
	if not improving.is_empty():
		box.add_child(UIKit.wrapped("Improving lately: %s." % ", ".join(improving)))
	add_child(UIKit.panel(box, 16))

	add_child(UIKit.label("Last week, day by day", "SubheadingLabel"))
	_add_days(r.monday, "The day-by-day log of that week is no longer kept.")
