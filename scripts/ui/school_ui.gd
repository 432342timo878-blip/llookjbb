class_name SchoolUI
extends RefCounted
## School where the player sees it (GDD 4.9.3 / 4.9.7, session S2): the two life settings (the Training tab and the School page),
## the day as blocks in the day editor, the week strip's marks, the Calendar's bands and the Report tab's school lines. Reading
## the SchoolSystem and changing only its settings. With the school model off (SchoolSystem.model_enabled) every piece shows
## nothing. Every control is at least 44 px and nothing needs hovering. Texts: data/school_life.json `ui` (and `texts`).


static func system() -> SchoolSystem:
	if Game.athlete == null:
		return null
	return SchoolSystem.sys()


static func ui() -> Dictionary:
	return Data.school_life.ui


## The colour of a grade or a standing (green from 9, light green from 8, amber from 6.5, red below).
static func grade_color(v: float) -> Color:
	for c in ui().grade_colors:
		if v >= float(c.min):
			return Color(str(c.color))
	return Palette.ATTR_POOR


## "Autumn break" / "Summer holiday" ... for a break id of the calendar ("" when there is none).
static func break_name(break_id: String) -> String:
	return str(Data.school_life.texts.breaks.get(break_id, ""))


# --- The two settings ---------------------------------------------------------------------------------------------------------

## The panel with Study effort and Free time (three 44 px toggles each, what the chosen one does) and what the two weigh
## together. `on_open` (valid) adds an "Open the School page" button (the Training tab). Null with the school model off.
static func settings_panel(on_open := Callable()) -> Control:
	var ss := system()
	if ss == null:
		return null
	var u := ui()
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label(str(u.settings_head), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(u.settings_text), "MutedLabel"))
	var load_label := UIKit.wrapped("", "")
	var refresh := func(): load_label.text = str(u.settings_load).format({"word": SchoolSystem.life_word(ss.settings_load())})
	box.add_child(_setting(ss, "effort", str(u.effort_label), refresh))
	box.add_child(_setting(ss, "free_time", str(u.free_label), refresh))
	refresh.call()
	box.add_child(load_label)
	if on_open.is_valid():
		var open := UIKit.button(str(u.open_page), false, 200)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
		open.pressed.connect(func(): on_open.call())
		box.add_child(open)
	return UIKit.panel(box, 16)


## One setting: its name, the three toggles (a row on PC, a column on a phone) and the text of the chosen one.
static func _setting(ss: SchoolSystem, kind: String, title: String, on_change: Callable) -> Control:
	var col := UIKit.vbox(6)
	col.add_child(UIKit.label(title, "SubheadingLabel"))
	var options: Array = Data.school_life.settings[kind]
	var current: String = ss.effort if kind == "effort" else ss.free_time
	var text := UIKit.wrapped("")
	for o in options:
		if str(o.id) == current:
			text.text = str(o.text)
	var group := ButtonGroup.new()
	var row := UIKit.flex(8)
	for o in options:
		var b := UIKit.toggle(str(o.name), group)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = str(o.id) == current
		b.pressed.connect(func():
			if kind == "effort":
				ss.set_effort(str(o.id))
			else:
				ss.set_free_time(str(o.id))
			text.text = str(o.text)
			on_change.call())
		row.add_child(b)
	col.add_child(row)
	col.add_child(text)
	return col


# --- The week strip --------------------------------------------------------------------------------------------------------------

## What the week strip shows for a day (from DayInfo.school): {off (shade the cell), caption (PC: the break's name), tests (count),
## test_text (PC: "Maths test" / "3 tests"), exam}. Empty when there is no school model.
static func strip_of(info: Dictionary) -> Dictionary:
	var sch: Dictionary = info.get("school", {})
	if sch.is_empty():
		return {}
	var n := (sch.tests as Array).size()
	var u: Dictionary = ui().strip
	var text := ""
	if n == 1:
		text = str(u.test_one).format({"subject": system().subject_name(str(sch.tests[0]))})
	elif n > 1:
		text = str(u.test_many).format({"n": n})
	var out := {"off": str(sch["break"]) != "", "caption": "" if str(sch["break"]) == "summer" else break_name(str(sch["break"])), "tests": n, "test_text": text, "exam": bool(sch.get("exam", false))}
	var m: Array = sch.get("matric", [])
	if not m.is_empty():   # a matriculation exam day (S3b): "YO" and the exam's name
		out.matric = true
		out.test_text = str(Data.lukio.ui.strip.matric_text).format({"exam": Matriculation.exam_name(str(m[0]), system().lukio)})
	return out


# --- The day editor: the day as blocks ---------------------------------------------------------------------------------------

## The day in four read-only blocks (morning / school / training / evening) and the day's life load in words. Null without school.
static func day_panel(info: Dictionary) -> Control:
	var ss := system()
	if ss == null or info.get("school", {}).is_empty():
		return null
	var u: Dictionary = ui().blocks
	var sch: Dictionary = info.school
	var kind := str(sch.kind)
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label(str(u.head), "CaptionLabel"))
	var on_school := kind == "school"
	box.add_child(_block(str(u.morning), str(u.morning_school if on_school else u.morning_free)))
	var school_text := ""
	match kind:
		"school":
			school_text = str(u.school_exam) if bool(sch.get("exam", false)) else str(u.school_day)
			var tests := _test_names(ss, sch.tests)
			if tests != "":
				school_text += " " + str(u.school_tests).format({"tests": tests})
			for ex in sch.get("matric", []):   # a matriculation exam (S3b)
				school_text += " " + str(Data.lukio.ui.blocks.matric).format({"exam": Matriculation.exam_name(str(ex), ss.lukio)})
		"holiday", "summer":
			school_text = str(u.school_off).format({"break": break_name(str(sch["break"]))})
		_:
			school_text = str(u.school_weekend)
	box.add_child(_block(str(u.school), school_text))
	var training := ""
	if not info.race.is_empty():
		training = str(u.training_race).format({"meet": str(info.race.name)})
	elif info.sessions.is_empty():
		training = str(u.training_rest)
	else:
		training = " + ".join(DayInfo.session_names(info.sessions))
		if info.intensity != WeekSim.NORMAL:
			training += " · " + DayInfo.intensity_name(info.intensity)
	box.add_child(_block(str(u.training), training))
	var evening := str(u.evening_free)
	if on_school:
		evening = str(u.evening_school).format({"effort": SchoolSystem.setting_name("effort", ss.effort).to_lower(),
				"free": SchoolSystem.setting_name("free_time", ss.free_time).to_lower()})
	box.add_child(_block(str(u.evening), evening))
	var life := _life_lines(ss, info)
	if life != null:
		box.add_child(life)
	return UIKit.panel(box, 14)


static func _block(title: String, text: String) -> Control:
	var row := UIKit.hbox(10)
	var t := UIKit.label(title, "MutedLabel")
	t.custom_minimum_size.x = 76
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(t)
	var body := UIKit.wrapped(text, "")
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	return row


## "Maths, English" for a list of subject ids.
static func _test_names(ss: SchoolSystem, ids: Array) -> String:
	var names := []
	for sid in ids:
		names.append(ss.subject_name(str(sid)))
	return ", ".join(names)


## The day's school life load in words and its causes (none on a weekend). For a played day the day log's value.
static func _life_lines(ss: SchoolSystem, info: Dictionary) -> Control:
	var u: Dictionary = ui().blocks
	var kind := str(info.school.kind)
	if kind == "weekend" and (info.played or ss.load_parts(info.date, info.sessions).is_empty()):
		return null   # (a weekend shows only a late night of the evening before, session P1)
	var col := UIKit.vbox(2)
	col.add_child(UIKit.label(str(u.life_head), "CaptionLabel"))
	var load := 0.0
	var parts := []
	if info.played:
		load = float(DayInfo.log_entry(info.date).get("life", 0.0))
	else:
		parts = ss.load_parts(info.date, info.sessions)
		for p in parts:
			load += float(p.value)
	col.add_child(UIKit.wrapped(str(u.life_line).format({"word": _cap(SchoolSystem.life_word(load))}), ""))
	var texts: Dictionary = Data.school_life.texts.pulls
	var arrows: Dictionary = Data.mind.ui
	for p in parts:
		var mark := str(arrows.arrow_up if float(p.value) > 0.0 else arrows.arrow_down)
		col.add_child(UIKit.wrapped("%s %s" % [mark, str(texts.get(str(p.id), str(p.id))).format({"n": int(p.get("n", 0))})], "MutedLabel"))
	return col


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


# --- The Report tab -----------------------------------------------------------------------------------------------------------------

## The school lines of a played day (from its day log entry): the break it was in, the tests with their scores, the life load.
static func report_lines(e: Dictionary) -> Array:
	var out := []
	var ss := system()
	if ss == null:
		return out
	var r: Dictionary = ui().report
	var kind := str(e.get("school", ""))
	if kind != "" and not kind in ["school", "weekend", "summer"] and break_name(kind) != "":
		out.append(break_name(kind))
	var tests: Array = e.get("tests", [])
	if not tests.is_empty():
		var list := []
		for sid in tests:
			var score := -1.0
			for t in ss.tests_log:
				if Calendar.date_key(t.date) == Calendar.date_key(e.date) and str(t.subject) == str(sid):
					score = float(t.score)
			list.append("%s %s" % [ss.subject_name(str(sid)), SchoolSystem.score_text(score) if score >= 0.0 else "?"])
		out.append(str(r.tests).format({"list": ", ".join(list)}))
	for m in e.get("matric", []):   # the day's matriculation exams (S3b)
		var lr: Dictionary = Data.lukio.ui.report
		out.append(str(lr.matric_skip if bool(m.get("absent", false)) else lr.matric).format({"exam": Matriculation.exam_name(str(m.exam), ss.lukio)}))
	if e.has("life"):
		out.append(str(r.life).format({"word": SchoolSystem.life_word(float(e.life))}))
	return out


# --- The Calendar ------------------------------------------------------------------------------------------------------------------

## The school bands between two dates for the Calendar: [{date (where the band starts), control}] (breaks, busy test weeks and the
## Pajulahti camp weeks of the verified year), to be sorted in among the meets.
static func bands(from: Dictionary, to: Dictionary) -> Array:
	var ss := system()
	if ss == null:
		return []
	var out := []
	var lo := Calendar.date_key(from)
	var c: Dictionary = ui().calendar
	for b in ss.breaks_between(from, to):
		var start: Dictionary = b.from
		var text := "%s - %s" % [DayInfo.short_day(b.from), DayInfo.short_day(b.to)]
		out.append({"date": start, "control": _band(break_name(str(b.id)), text, Palette.SCHOOL_BAND)})
	for w in ss.busy_weeks(from, to):
		if Calendar.date_key(Game.add_days(w.monday, 6)) < lo:
			continue
		if ss.lukio_active(w.monday) or ss.lukio_active(Game.add_days(w.monday, 4)):   # (a lukio's exam weeks have their own band, S3b)
			continue
		out.append({"date": w.monday, "control": _band(str(c.busy_week).format({"n": int(w.n)}),
				"%s - %s" % [DayInfo.short_day(w.monday), DayInfo.short_day(Game.add_days(w.monday, 4))], Palette.SCHOOL_TEST)})
	# The joint application (S3a): the window, the test day and the results of the spring after a grade-9 / 10th-grade school year.
	var hi := Calendar.date_key(to)
	var ac: Dictionary = Data.application.ui.calendar
	for yr in range(SchoolCalendar.year_of(from), SchoolCalendar.year_of(to) + 1):
		if not bool(ss.stage_of({"year": yr + 1, "month": 1, "day": 1}).get("applies", false)):
			continue
		var dt := SchoolApplication.dates(yr + 1)
		for spec in [["window", dt.open, dt.close], ["test", dt.test, dt.test], ["results", dt.results, dt.results]]:
			var a: Dictionary = spec[1]
			var b: Dictionary = spec[2]
			if Calendar.date_key(b) < lo or Calendar.date_key(a) > hi:
				continue
			var range_text := DayInfo.short_day(a) if Calendar.date_key(a) == Calendar.date_key(b) else "%s - %s" % [DayInfo.short_day(a), DayInfo.short_day(b)]
			out.append({"date": a, "control": _band(str(ac[str(spec[0])]), range_text, Palette.SCHOOL_TEST)})
	out.append_array(_lukio_bands(ss, from, to))
	for camp in Data.school.verified.camps.list:
		var s := Calendar.parse_date(str(camp.start))
		if Calendar.date_key(Calendar.parse_date(str(camp["end"]))) < lo or Calendar.date_key(s) > Calendar.date_key(to):
			continue
		out.append({"date": s, "control": _band(str(c.camp), "%s - %s" % [DayInfo.short_day(s), DayInfo.short_day(Calendar.parse_date(str(camp["end"])))],
				Palette.SCHOOL_BAND, str(c.camp_note))})
	return out


## The lukio's bands (S3b): each period's exam week, each matriculation session with exams in the plan, and its registration deadline.
static func _lukio_bands(ss: SchoolSystem, from: Dictionary, to: Dictionary) -> Array:
	var out := []
	var L: Dictionary = ss.lukio
	if L.is_empty():
		return out
	var lo := Calendar.date_key(from)
	var hi := Calendar.date_key(to)
	var c: Dictionary = Data.lukio.ui.calendar
	for p in Lukio.period_count(L):
		var per := Lukio.period_info(ss, L, p)
		if per.exam.is_empty():
			continue
		var a: Dictionary = per.exam[0]
		var b: Dictionary = per.exam.back()
		if Calendar.date_key(b) < lo or Calendar.date_key(a) > hi:
			continue
		out.append({"date": a, "control": _band(str(c.exam_week).format({"n": int(per.i) + 1}), "%s - %s" % [DayInfo.short_day(a), DayInfo.short_day(b)], Palette.SCHOOL_TEST)})
	for k in ss.matric_sessions():
		var sk := str(k)
		var exams: Array = L.matric.registered.get(sk, []) if sk in L.matric.locked else ss._plan_in(sk)
		if exams.is_empty():
			continue
		var a := Matriculation.first_day(sk)
		var b := Matriculation.last_day(sk)
		var names := []
		for ex in exams:
			names.append(Matriculation.exam_name(str(ex), L))
		var title := str(c.matric).format({"session": Matriculation.session_name(sk)})
		if Calendar.date_key(b) >= lo and Calendar.date_key(a) <= hi:
			out.append({"date": a, "control": _band(title, "%s - %s" % [DayInfo.short_day(a), DayInfo.short_day(b)], Palette.SCHOOL_TEST, ", ".join(names))})
		var dl := Matriculation.deadline(sk)
		if not sk in L.matric.locked and Calendar.date_key(dl) >= lo and Calendar.date_key(dl) <= hi:
			out.append({"date": dl, "control": _band(str(c.register).format({"session": Matriculation.session_name(sk)}), DayInfo.short_day(dl), Palette.SCHOOL_TEST)})
	return out


static func _band(title: String, range_text: String, color: Color, note := "") -> Control:
	var col := UIKit.vbox(2)
	var head := UIKit.wrapped(title, "SubheadingLabel")
	col.add_child(head)
	col.add_child(UIKit.wrapped(range_text, "MutedLabel"))
	if note != "":
		col.add_child(UIKit.wrapped(note, "MutedLabel"))
	return UIKit.alert_panel(col, color, 10)
