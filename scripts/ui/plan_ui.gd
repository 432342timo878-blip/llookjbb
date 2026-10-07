class_name PlanUI
extends RefCounted
## The pieces of a weekly-plan editor, shared by the Training tab's repeating week and the season plan's phase
## editor (GDD 4.8): one row per day (two session pickers, the day's load, Easy / Normal / Hard) and the plan
## summary (weekly load, expected fatigue, body strain, training focus).


## One day of a week plan (`plan` = the week plan being edited in place). Wide: day, two pickers, the load and
## the Easy / Normal / Hard buttons on one row. Phone: a header line (day + load) with the two pickers stacked
## under it, then the three intensity buttons. `on_change` is called after every edit.
static func day_row(plan: Dictionary, day: int, a: Athlete, month: int, on_change: Callable, title: String) -> Control:
	var day_label := UIKit.label(title, "SubheadingLabel" if Layout.stacked() else "")
	var load_label := UIKit.label("", "MutedLabel")
	var row: BoxContainer
	if Layout.stacked():
		row = UIKit.vbox(6)
		var head := UIKit.hbox(8)
		day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(day_label)
		head.add_child(load_label)
		row.add_child(head)
	else:
		row = UIKit.hbox(10)
		day_label.custom_minimum_size.x = 100
		row.add_child(day_label)
	var slots := []
	for slot in Training.MAX_SESSIONS_PER_DAY:
		var pick := session_picker(a, month)
		var current: Array = plan.days[day]
		var id: String = current[slot] if slot < current.size() else ""
		for i in pick.item_count:
			if pick.get_item_metadata(i) == id:
				pick.select(i)
		slots.append(pick)
		row.add_child(pick)
	if not Layout.stacked():
		load_label.custom_minimum_size.x = 80
		row.add_child(load_label)

	# Easy / Normal / Hard for the day (44 px high; on a phone they share the width).
	var group := ButtonGroup.new()
	var level_buttons := {}
	var level_row := UIKit.hbox(6)
	for level in Training.INTENSITIES:
		var b := UIKit.toggle(Training.intensity(level).name, group)
		b.custom_minimum_size.x = 0 if Layout.stacked() else 72
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.stacked() else Control.SIZE_SHRINK_END
		b.button_pressed = level == plan.intensity[day]
		level_buttons[level] = b
		level_row.add_child(b)
	row.add_child(level_row)

	var update := func():
		var ids := []
		for p in slots:
			var sid: String = p.get_item_metadata(p.selected)
			if sid != "":
				ids.append(sid)
		plan.days[day] = ids
		var load := 0.0
		var mult := float(Training.intensity(plan.intensity[day]).load)
		for sid in ids:
			load += Training.session_load(a, Data.get_session(sid)) * mult
		load_label.text = "Rest day" if ids.is_empty() else "Load %d" % roundi(load)
		for b in level_buttons.values():
			b.disabled = ids.is_empty()   # intensity changes nothing on a rest day
	for p in slots:
		p.item_selected.connect(func(_i): update.call(); on_change.call())
	for level in level_buttons:
		level_buttons[level].pressed.connect(func():
			plan.intensity[day] = level
			update.call()
			on_change.call())
	update.call()
	return row


static func session_picker(a: Athlete, month: int) -> OptionButton:
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(0 if Layout.stacked() else 200, 44)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.add_item("—")
	pick.set_item_metadata(0, "")
	for s in Data.training.sessions:
		var eff := Training.effectiveness(a, s, month)
		var text: String = s.name
		if eff > 0.0 and eff < 1.0:
			text += " (no track)"
		pick.add_item(text)
		var i := pick.item_count - 1
		pick.set_item_metadata(i, s.id)
		pick.set_item_tooltip(i, s.description)
		if eff == 0.0:
			pick.set_item_disabled(i, true)
			pick.set_item_tooltip(i, "Not possible this time of year")
	return pick


## "THIS PLAN" for a week plan starting on `monday`: weekly load, expected fatigue with a verdict, `strain` (the
## body-strain section, or null), and the training focus bars. Clears `box` first.
static func fill_summary(box: VBoxContainer, a: Athlete, plan: Variant, monday: Dictionary, strain: Control) -> void:
	for child in box.get_children():
		child.queue_free()
	var month: int = Game.add_days(monday, 3).month
	var p := Training.preview(a, plan, month)
	var expected := Training.expected_fatigue(a, plan, monday)
	var verdict: String
	if expected.avg < 15.0:
		verdict = "Light: easy to recover from, but slower progress."
	elif expected.avg < 45.0:
		verdict = "Balanced: you should recover well between sessions."
	elif expected.avg < 65.0:
		verdict = "Hard: heavy legs, and training gives less when you're tired. Plan lighter weeks too."
	else:
		verdict = "Too much: you'll be exhausted, so most of the training is wasted."

	box.add_child(UIKit.label("THIS PLAN", "CaptionLabel"))
	box.add_child(UIKit.fact_row("Weekly load", UIKit.label(str(roundi(p.load)))))
	var fat := UIKit.hbox(6)
	fat.add_child(UIKit.fatigue_label(expected.avg))
	fat.add_child(UIKit.label("on average", "MutedLabel"))
	box.add_child(UIKit.fact_row("Expected fatigue", fat))
	box.add_child(UIKit.wrapped(verdict, ""))
	if strain != null:
		box.add_child(strain)

	box.add_child(UIKit.label("TRAINING FOCUS", "CaptionLabel"))
	var focus: Array = p.stimulus.keys()
	focus.sort_custom(func(x, y): return p.stimulus[x] > p.stimulus[y])
	if focus.is_empty():
		box.add_child(UIKit.wrapped("Nothing planned: a full rest week."))
	for id in focus:
		var row := UIKit.hbox(10)
		var l := UIKit.label(UIKit.attr_name(id))
		l.custom_minimum_size.x = 150 if Layout.stacked() else 200
		row.add_child(l)
		var bar := ColorRect.new()
		bar.color = Palette.ACCENT
		bar.custom_minimum_size = Vector2(minf(p.stimulus[id], 6.0) * (30.0 if Layout.stacked() else 50.0), 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		box.add_child(row)


## A week plan's days as text lines: "Mon: easy run, drills (Easy)" and, with `why`, the reasons under them.
static func days_list(plan: Dictionary, why: Array = []) -> VBoxContainer:
	var days := UIKit.vbox(6)
	for d in 7:
		var names := []
		for id in plan.days[d]:
			names.append(Data.get_session(id).name)
		var line := "%s: %s" % [Training.DAY_NAMES[d], ", ".join(names) if not names.is_empty() else "Rest day"]
		if not names.is_empty() and plan.intensity[d] != WeekPlan.NORMAL:
			line += " (%s)" % Training.intensity(plan.intensity[d]).name
		days.add_child(UIKit.wrapped(line, ""))
		if d < why.size() and why[d] != "":
			days.add_child(UIKit.wrapped(why[d], "CaptionLabel"))
	return days
