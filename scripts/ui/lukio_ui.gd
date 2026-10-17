class_name LukioUI
extends RefCounted
## Lukio on the School page (GDD 4.9.3, session S3b), static panels: THIS PERIOD (its dates, exam week and courses), YOUR CHOICES
## (maths, the extra language, 3 or 4 years, with Move to short maths (two taps) and the years switch until year 3), the LUKIO CARD
## (each subject with its course grades and the subject grade, tap for the courses), the STUDY PLAN (every period's courses, the
## credits) and the matriculation plan (MatricPlanView). Reading SchoolSystem; changing only the choices and the exam plan.
## `open` remembers the opened rows while the page redraws. Every control is at least 44 px. Texts: data/lukio.json `ui`.

static var open := {}


static func ui() -> Dictionary:
	return Data.lukio.ui


## THIS PERIOD: the period of today (or the summer line).
static func period_panel(ss: SchoolSystem) -> Control:
	var u := ui()
	var L: Dictionary = ss.lukio
	var box := UIKit.vbox(4)
	box.add_child(UIKit.label(str(u.period_head), "CaptionLabel"))
	var per := Lukio.period_at(ss, L, Game.date)
	if per.is_empty():
		box.add_child(UIKit.wrapped(str(u.summer), ""))
		return UIKit.panel(box, 14)
	box.add_child(UIKit.wrapped(str(u.period_line).format({"year": int(per.year_index) + 1, "n": int(per.i) + 1,
			"from": Calendar.format_day(per.start), "to": Calendar.format_day(per.end)}), "SubheadingLabel"))
	if not per.exam.is_empty():
		box.add_child(UIKit.wrapped(str(u.period_exams).format({"from": Calendar.format_day(per.exam[0]), "to": Calendar.format_day(per.exam.back())}), "MutedLabel"))
	var n := Lukio.class_count(L, int(per.p))
	box.add_child(UIKit.wrapped(str(u.period_courses).format({"n": n, "load": str(u.period_load[Lukio.load_word(n)])}), ""))
	var sched := Lukio.exam_schedule(ss, L, int(per.p))
	var days := {}
	for k in sched:
		for uid in sched[k]:
			days[str(uid)] = int(k)
	var lines := []
	for c in Lukio.courses_in(L, int(per.p)):
		var t := Lukio.course_name(c, L)
		if str(c.st) == "done":
			t += ": " + (str(u.passed) if int(c.g) < 0 else str(int(c.g)))
		elif days.has(str(c.id)):
			var k := int(days[str(c.id)])
			t += " (%s)" % str(u.exam_day).format({"day": DayInfo.short_day({"year": k / 10000, "month": (k / 100) % 100, "day": k % 100})})
		lines.append(t)
	box.add_child(UIKit.wrapped("\n".join(lines), "MutedLabel"))
	return UIKit.panel(box, 14)


## YOUR CHOICES: maths, the language, the years, and the two changes allowed later.
static func choices_panel(ss: SchoolSystem, on_change: Callable) -> Control:
	var u := ui()
	var L: Dictionary = ss.lukio
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label(str(u.choices_head), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(u.choice_maths).format({"syllabus": str(u.syllabus[str(L.maths)])}), ""))
	box.add_child(UIKit.wrapped(str(u.choice_language).format({"language": Lukio.language_name(str(L.b3))}), ""))
	box.add_child(UIKit.wrapped(str(u.choice_years).format({"years": int(L.years)}), ""))
	if ss.can_short_maths():
		var b := UIKit.button(str(u.to_short), false, 200)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
		var armed := {"on": false}
		b.pressed.connect(func():
			if not armed.on:
				armed.on = true
				b.text = str(u.to_short_confirm)
				return
			ss.to_short_maths()
			on_change.call())
		box.add_child(b)
		box.add_child(UIKit.wrapped(str(u.to_short_note), "MutedLabel"))
	if ss.can_change_years():
		var other := 4 if int(L.years) == 3 else 3
		var y := UIKit.button(str(u.years_switch).format({"years": other}), false, 200)
		y.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
		y.pressed.connect(func():
			ss.set_lukio_years(other)
			on_change.call())
		box.add_child(y)
	elif ss.lukio_active(Game.date):
		box.add_child(UIKit.wrapped(str(u.years_locked), "MutedLabel"))
	return UIKit.panel(box, 14)


## LUKIO CARD: each subject with its courses done / in the plan and its grade; tap a subject for its courses.
static func card_panel(ss: SchoolSystem) -> Control:
	var u := ui()
	var L: Dictionary = ss.lukio
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label(str(u.card_head), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(u.card_text), "MutedLabel"))
	for s in Lukio.subject_defs(L):
		box.add_child(_subject_row(ss, L, str(s.id)))
	var cr := Lukio.credits(L)
	box.add_child(UIKit.wrapped(str(u.credits).format({"done": int(cr.done), "total": int(cr.total), "planned": int(cr.planned)}), ""))
	return UIKit.panel(box, 14)


static func _subject_row(ss: SchoolSystem, L: Dictionary, sid: String) -> Control:
	var u := ui()
	var row := UIKit.hbox(8)
	var name := UIKit.label(Lukio.subject_name(sid, L))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name.clip_text = true
	row.add_child(name)
	var cnt := Lukio.subject_counts(L, sid)
	var c := UIKit.label(str(u.card_courses).format({"done": int(cnt.done), "total": int(cnt.total)}), "MutedLabel")
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	var g := Lukio.subject_grade(L, sid)
	var pass_only := Lukio.kind_of(sid) == "pass"
	var v := UIKit.label(("-" if int(cnt.done) == 0 else str(u.passed)) if pass_only else (str(g) if g > 0 else "-"), "AttrValueLabel")
	v.custom_minimum_size.x = 40
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if g > 0:
		v.add_theme_color_override("font_color", SchoolUI.grade_color(float(g)))
	row.add_child(v)
	var lines := []
	for x in Lukio._units_of(L, sid):
		var cn := Lukio.course_name(x, L)
		match str(x.st):
			"done":
				lines.append(str(u.card_course_line).format({"course": cn, "grade": str(u.passed) if int(x.g) < 0 else str(int(x.g))}))
			"plan":
				lines.append(str(u.card_planned).format({"course": cn, "period": _period_name(ss, L, int(x.p))}))
			"drop":
				lines.append(str(u.card_dropped).format({"course": cn}))
	var key := "subj_" + sid
	return HealthUI.expandable(row, null, UIKit.wrapped("\n".join(lines), "MutedLabel"), SchoolUI.grade_color(float(g)) if g > 0 else Palette.SURFACE_PANEL,
			bool(open.get(key, false)), func(is_open): open[key] = is_open)


## "year 2, P3" for a period index.
static func _period_name(ss: SchoolSystem, L: Dictionary, p: int) -> String:
	if p < 0:
		return "?"
	return "%s %s" % [str(ui().plan_year).format({"year": p / Lukio.per_year() + 1}).to_lower(), str(ui().plan_period).format({"n": p % Lukio.per_year() + 1})]


## STUDY PLAN: each year, each period with its courses (the current one marked).
static func plan_panel(ss: SchoolSystem) -> Control:
	var u := ui()
	var L: Dictionary = ss.lukio
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label(str(u.plan_head), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(u.plan_text), "MutedLabel"))
	var now := Lukio.period_at(ss, L, Game.date)
	var cur := int(now.get("p", -1))
	for yi in int(L.years):
		var col := UIKit.vbox(2)
		for i in Lukio.per_year():
			var p := yi * Lukio.per_year() + i
			var names := []
			for c in Lukio.courses_in(L, p):
				names.append(Lukio.course_name(c, L))
			var text := "%s · %s: %s" % [str(u.plan_period).format({"n": i + 1}), str(u.plan_period_courses).format({"n": names.size()}), ", ".join(names) if not names.is_empty() else "-"]
			var l := UIKit.wrapped(("▸ " if p == cur else "") + text, "" if p == cur else "MutedLabel")
			col.add_child(l)
		var head := UIKit.hbox(8)
		var t := UIKit.label(str(u.plan_year).format({"year": yi + 1}), "SubheadingLabel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var key := "year_%d" % yi
		var start_open := bool(open.get(key, yi == maxi(0, cur / Lukio.per_year())))
		box.add_child(HealthUI.expandable(head, null, col, Palette.SURFACE_PANEL, start_open, func(is_open): open[key] = is_open))
	var cr := Lukio.credits(L)
	box.add_child(UIKit.wrapped(str(u.credits).format({"done": int(cr.done), "total": int(cr.total), "planned": int(cr.planned)}), ""))
	if int(cr.planned) < int(cr.total):
		box.add_child(UIKit.wrapped(str(u.credits_short).format({"n": int(cr.total) - int(cr.planned)}), "MutedLabel"))
	return UIKit.panel(box, 14)


## The matriculation exams (the plan editor).
static func matric_panel() -> Control:
	return UIKit.panel(MatricPlanView.new(), 14)
