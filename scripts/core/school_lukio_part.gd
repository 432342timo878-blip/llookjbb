class_name SchoolLukioPart
extends RefCounted
## The courses, periods, choices, stops, exams of the period and results of the lukio (session S3b; split out of school_system.gd in the fix session 2026-10-18). Static functions over a SchoolSystem: the state (lukio) stays in the system, SchoolSystem forwards to these.

# --- Lukio: courses and periods (session S3b) ---------------------------------------------------------------------------------
# A lukio starts on the first day of its stage (1 August of its first year): the subjects move to the lukio's (lukio grades run
# lower, new subjects such as philosophy start from their relatives), the counsellor's choices (maths, an extra language,
# 3 or 4 years) and the plan of courses are made. With decisions_enabled (the real game) the choices are stops on the first
# school day, and every period starts with a stop for its courses and ends with a stop for its results (user 2026-10-17);
# every tool gets the counsellor's defaults and never a stop. Grades 8-9 and a TUVA year never run any of this.

## True on a date in a lukio stage once its lukio has started.
static func lukio_active(me: SchoolSystem, d: Dictionary) -> bool:
	if me.lukio.is_empty() or Game.athlete == null:
		return false
	var st := me.stage_of(d)
	if str(st.get("kind", "")) != "lukio":
		return false
	return int(SchoolCalendar.year_of(d)) - int(st.get("year_index", 0)) == int(me.lukio.start_year)


## The lukio segment of a date's stage ({} when the stage is not a lukio).
static func _lukio_seg(me: SchoolSystem, d: Dictionary) -> Dictionary:
	if str(me.stage_of(d).get("kind", "")) != "lukio":
		return {}
	return me.segment_for(SchoolCalendar.year_of(d))


## The course exams written on a date: [course ids].
static func lukio_exams_on(me: SchoolSystem, d: Dictionary) -> Array:
	var per := Lukio.period_at(me, me.lukio, d)
	if per.is_empty():
		return []
	return _exams_of(me, int(per.p)).get(Calendar.date_key(d), [])


static func _exams_of(me: SchoolSystem, p: int) -> Dictionary:
	if not me._lukio_exams.has(p):
		me._lukio_exams[p] = Lukio.exam_schedule(me, me.lukio, p)
	return me._lukio_exams[p]


static func _lukio_changed(me: SchoolSystem) -> void:
	me._lukio_exams = {}


static func _lukio_day_start(me: SchoolSystem, d: Dictionary) -> void:
	var seg := _lukio_seg(me, d)
	if not seg.is_empty() and (me.lukio.is_empty() or int(me.lukio.start_year) != int(seg.start_year)):
		_start_lukio(me, seg, d)
	if lukio_active(me, d):
		var per := Lukio.period_at(me, me.lukio, d)
		if not per.is_empty() and SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
			var first := _first_school_day(me, per.start, per.end)
			if Calendar.date_key(d) >= Calendar.date_key(first) and bool(me.lukio.chosen) and not me.lukio.asked.has("c%d" % int(per.p)) \
					and (per.exam.is_empty() or Calendar.date_key(d) < Calendar.date_key(per.exam[0])):
				_post_courses(me, int(per.p))
			if not bool(me.lukio.chosen) and not me.lukio.asked.has("choice") and Calendar.date_key(d) >= Calendar.date_key(first):
				me.lukio.asked["choice"] = true
				_post_choice(me, "maths")
	if not me.lukio.is_empty():
		me._matric_day_start(d)


static func _first_school_day(me: SchoolSystem, from: Dictionary, to: Dictionary) -> Dictionary:
	var d := from
	while Calendar.date_key(d) <= Calendar.date_key(to):
		if SchoolCalendar.is_school_day(me._town(), d):
			return d
		d = Game.add_days(d, 1)
	return from


## The lukio begins: the subjects, the counsellor's choices and plan, the matriculation plan. A lukio that starts in the middle
## of a year (a save or a tool) has its earlier periods done, graded by the levels.
static func _start_lukio(me: SchoolSystem, seg: Dictionary, d: Dictionary) -> void:
	var lv: Dictionary = Data.lukio.levels
	var pick_long := me.level("maths") >= float(Data.lukio.plan.long_maths_from)
	me.lukio = {"start_year": int(seg.start_year), "school": str(seg.get("school", "")), "sports": str(seg.kind) == "urheilulukio",
			"maths": "long" if pick_long else "short", "b3": "none", "years": int(seg.years),
			"music_art": "music" if me.level("music") >= me.level("art") else "art", "chosen": not (SchoolSystem.decisions_enabled and not SchoolSystem.neutral),
			"shifted": false, "maths_shifted": false, "units": [], "asked": {}, "done": false,
			"matric": {"plan": {}, "locked": [], "registered": {}, "sat": {}, "results": [], "cert": false}}
	# The subjects: lukio grades run lower; the new subjects start from their relatives (with a roll of their own).
	var rng := RandomNumberGenerator.new()
	rng.seed = me._seed("lukio_subjects|%d" % int(seg.start_year))
	for s in Lukio.cfg().subjects.list:
		var sid := str(s.id)
		if str(s.kind) == "pass" or sid == "b3":
			continue
		_lukio_subject(me, sid, s, rng)
	me.lukio.shifted = true
	if me.lukio.maths == "long":
		_shift_subject(me, "maths", float(lv.long_maths_shift))
		me.lukio.maths_shifted = true
	_lukio_seed_matric(me)
	_replan(me, 0)
	me._stage_cache = {}
	# Started after its first school day: the periods before today are done (graded by the levels, no exams).
	var per := Lukio.period_at(me, me.lukio, d)
	if not per.is_empty():
		var upto := int(per.p) - 1
		if not per.exam.is_empty() and Calendar.date_key(d) > Calendar.date_key(per.exam.back()):
			upto = int(per.p)
		for p in range(0, upto + 1):
			_finish_period(me, p, false)
		if int(per.p) > 0:
			me.lukio.asked["choice"] = true
			me.lukio.chosen = true


static func _lukio_subject(me: SchoolSystem, sid: String, s: Dictionary, rng: RandomNumberGenerator) -> void:
	var lv: Dictionary = Data.lukio.levels
	var shift := float(lv.lukio_shift) + float(s.get("shift", 0.0))
	if me.subjects.has(sid):
		_shift_subject(me, sid, shift)
		return
	var from: Array = s.get("from", [])
	var lvl := 0.0
	var nat := 0.0
	for f in from:
		lvl += me.level(str(f))
		nat += float(me.subjects.get(str(f), {}).get("natural", me.level(str(f))))
	var n := maxi(1, from.size())
	var roll := rng.randfn(0.0, float(lv.new_subject_sd))
	var lo := float(SchoolSystem.cfg().grades.min)
	var hi := float(SchoolSystem.cfg().grades.max)
	me.subjects[sid] = {"natural": clampf(nat / n + shift + roll, lo, hi), "level": clampf(lvl / n + shift + roll, lo, hi)}


## A moment's `grades` effect (session P1): every academic subject's level moves by `points` x data/cast.json
## grades.grades_per_point; the natural level stays, so the drift takes it back over the weeks (studying for a test helps
## that test). Nothing with the model off or neutral. Returns the change per subject.
static func nudge_grades(me: SchoolSystem, points: float) -> float:
	if not SchoolSystem.model_enabled or SchoolSystem.neutral:
		return 0.0
	me._ensure_started()
	var shift := points * float(Data.cast.grades.grades_per_point)
	var lo := float(SchoolSystem.cfg().grades.min)
	var hi := float(SchoolSystem.cfg().grades.max)
	for s in me.subject_list():
		var sid := str(s.id)
		if me.is_academic(sid) and me.subjects.has(sid):
			me.subjects[sid].level = clampf(float(me.subjects[sid].level) + shift, lo, hi)
	return shift


static func _shift_subject(me: SchoolSystem, sid: String, shift: float) -> void:
	if not me.subjects.has(sid):
		return
	var lo := float(SchoolSystem.cfg().grades.min)
	var hi := float(SchoolSystem.cfg().grades.max)
	me.subjects[sid].natural = clampf(float(me.subjects[sid].natural) + shift, lo, hi)
	me.subjects[sid].level = clampf(float(me.subjects[sid].level) + shift, lo, hi)


static func _lukio_seed_matric(me: SchoolSystem) -> void:
	var plan := Matriculation.suggest(me, me.lukio)
	me.lukio.matric.plan = {}
	for ex in plan:
		if ex in Matriculation.available(me.lukio):
			me.lukio.matric.plan[ex] = plan[ex]


## The counsellor puts the courses from period `from_p` on into the plan again (after a choice or a change).
static func _replan(me: SchoolSystem, from_p: int) -> void:
	Lukio.ensure_units(me, me.lukio)
	Lukio.fill_optional(me, me.lukio, from_p)
	Lukio.spread(me, me.lukio, from_p)
	_lukio_changed(me)


## The period whose courses can be changed now: the current one before its first exam (-1 = none).
static func editable_period(me: SchoolSystem) -> int:
	if not lukio_active(me, Game.date):
		return -1
	var per := Lukio.period_at(me, me.lukio, Game.date)
	if per.is_empty():
		return -1
	if not per.exam.is_empty() and Calendar.date_key(Game.date) >= Calendar.date_key(per.exam[0]):
		return -1
	return int(per.p)


# --- The player's changes to a period's courses (the courses stop) ---
static func course_later(me: SchoolSystem, uid: String) -> bool:
	var p := editable_period(me)
	var u := Lukio.unit(me.lukio, uid)
	if p < 0 or u.is_empty() or int(u.p) != p or str(u.st) != "plan" or p + 1 >= Lukio.period_count(me.lukio):
		return false
	u.p = p + 1
	_after_edit(me, p)
	return true


static func course_add(me: SchoolSystem, uid: String) -> bool:
	var p := editable_period(me)
	var u := Lukio.unit(me.lukio, uid)
	if p < 0 or u.is_empty() or str(u.k) != "opt" or str(u.st) == "done" or (str(u.st) == "plan" and int(u.p) <= p):
		return false
	u.st = "plan"
	u.p = p
	u.by = "player"
	_after_edit(me, p)
	return true


## Drops an optional course of the period (back to the pool, never added again by the counsellor) or, in a sports lukio, leaves
## out a compulsory one by the rule.
static func course_drop(me: SchoolSystem, uid: String) -> bool:
	var p := editable_period(me)
	var u := Lukio.unit(me.lukio, uid)
	if p < 0 or u.is_empty() or int(u.p) != p or str(u.st) != "plan":
		return false
	if str(u.k) == "opt":
		u.st = "pool"
		u.by = "player_out"
	elif Lukio.can_drop_comp(me.lukio, u):
		u.st = "drop"
		u.by = "player"
	else:
		return false
	u.p = -1
	_after_edit(me, p)
	return true


static func course_put_back(me: SchoolSystem, uid: String) -> bool:
	var p := editable_period(me)
	var u := Lukio.unit(me.lukio, uid)
	if p < 0 or u.is_empty() or str(u.st) != "drop":
		return false
	u.st = "plan"
	u.p = p
	u.by = "player"
	_after_edit(me, p)
	return true


static func _after_edit(me: SchoolSystem, p: int) -> void:
	Lukio.fill_optional(me, me.lukio, p + 1)
	Lukio.spread(me, me.lukio, p + 1)
	_lukio_changed(me)


## Optional courses that can be added to the period: the next one of each subject that is not done or already in it.
static func add_candidates(me: SchoolSystem, p: int) -> Array:
	var out := []
	var seen := {}
	var list := (me.lukio.units as Array).duplicate()
	list.sort_custom(func(a, b): return int(a.n) < int(b.n))
	for u in list:
		var sid := str(u.s)
		if seen.has(sid) or str(u.k) != "opt" or str(u.st) == "done" or str(u.st) == "drop":
			continue
		if str(u.st) == "plan" and int(u.p) <= p:
			continue
		seen[sid] = true
		out.append(u)
	return out


# --- The choices ---
static func can_change_years(me: SchoolSystem) -> bool:
	if not lukio_active(me, Game.date):
		return false
	return SchoolCalendar.year_of(Game.date) - int(me.lukio.start_year) < 2


## 3 or 4 years (user: every lukio; until the third year starts): the path's length changes and the rest of the plan is
## spread again.
static func set_lukio_years(me: SchoolSystem, n: int) -> bool:
	var allowed := (Data.lukio.rules.years_allowed as Array).map(func(x): return int(x))
	if not can_change_years(me) or not n in allowed or n == int(me.lukio.years):
		return false
	_set_years(me, n)
	_replan(me, _replan_from(me))
	return true


## The first period the counsellor may plan again: the current one while its courses can change, else the next (in the summer
## between two school years: the next year's first).
static func _replan_from(me: SchoolSystem) -> int:
	var per := Lukio.period_at(me, me.lukio, Game.date)
	if per.is_empty():
		var yi := SchoolCalendar.year_of(Game.date) - int(me.lukio.start_year)
		if Game.date.month >= 6 and Game.date.month < 8:
			yi += 1
		return clampi(yi * Lukio.per_year(), 0, Lukio.period_count(me.lukio) - 1)
	return int(per.p) + (0 if editable_period(me) >= 0 else 1)


static func _set_years(me: SchoolSystem, n: int) -> void:
	var found := false
	for sgm in me.paths:
		if int(sgm.start_year) == int(me.lukio.start_year) and str(sgm.kind) in ["lukio", "urheilulukio"]:
			sgm.years = n
			found = true
	if not found:   # the default path (no list was made): stored now, with its new length
		var seg := me.segment_for(int(me.lukio.start_year))
		me.paths.append({"kind": str(seg.get("kind", "lukio")), "school": str(seg.get("school", "")), "town": str(seg.get("town", me._town())),
				"start_year": int(me.lukio.start_year), "years": n, "arrived": true, "default": true})
	me.lukio.years = n
	me._stage_cache = {}
	me._exam_days = {}
	me._schedules = {}
	Lukio.clear_cache()
	# The exam plan follows the sessions of the new length (an exam already registered or written keeps its session): the
	# counsellor's suggestion for every exam that is not fixed yet.
	me.matric_fill_suggestion()


static func can_short_maths(me: SchoolSystem) -> bool:
	if me.lukio.is_empty() or str(me.lukio.maths) != "long" or not lukio_active(me, Game.date):
		return false
	for k in me.lukio.matric.locked:
		if "maths" in me.lukio.matric.registered.get(str(k), []):
			return false
	return true


## Long maths -> short (real schools allow it; the long courses done count towards the short syllabus).
static func to_short_maths(me: SchoolSystem) -> bool:
	if not can_short_maths(me):
		return false
	var done := []
	for u in me.lukio.units:
		if str(u.s) == "maths" and str(u.st) == "done" and int(u.n) > 1:
			done.append(u)
	done.sort_custom(func(a, b): return int(a.n) < int(b.n))
	me.lukio.units = (me.lukio.units as Array).filter(func(u): return not (str(u.s) == "maths" and int(u.n) > 1))
	me.lukio.maths = "short"
	if bool(me.lukio.maths_shifted):
		_shift_subject(me, "maths", -float(Data.lukio.levels.long_maths_shift))
		me.lukio.maths_shifted = false
	var max_n := Lukio.comp_count("maths", me.lukio) + Lukio.opt_count("maths", me.lukio)
	for i in done.size():
		var n := 2 + i
		if n > max_n:
			break
		me.lukio.units.append({"id": Lukio._unit_id("maths", n, me.lukio), "s": "maths", "n": n, "k": "comp" if n <= Lukio.comp_count("maths", me.lukio) else "opt",
				"p": int(done[i].p), "st": "done", "g": int(done[i].g), "x": float(done[i].x), "by": "", "r": false})
	_replan(me, _replan_from(me))
	return true


# --- The stops of the lukio ---
static func _post_choice(me: SchoolSystem, step: String) -> void:
	var c: Dictionary = Data.lukio.stops
	var choices := []
	var text := ""
	var pick := ""
	match step:
		"maths":
			text = str(c.maths_text)
			for k in ["long", "short"]:
				choices.append({"id": k, "label": str(c.maths_options[k].label), "detail": str(c.maths_options[k].detail)})
			pick = str(c.maths_options[str(me.lukio.maths)].label)
		"language":
			text = str(c.language_text)
			for l in Data.lukio.subjects.languages:
				choices.append({"id": str(l.id), "label": str(l.name), "detail": str(l.text)})
			pick = Lukio.language_name("none")
		"years":
			text = str(c.years_text)
			for k in ["3", "4"]:
				choices.append({"id": k, "label": str(c.years_options[k].label), "detail": str(c.years_options[k].detail)})
			pick = str(c.years_options[str(int(me.lukio.years))].label)
	text += "\n\n" + str(c.counsellor_pick).format({"pick": pick})
	var e := Game.post_event(me.id, str(c.choices_title), text, choices, true)
	e.kind = "lukio_choice"
	e.step = step


## The start of a period: a stop to look at the courses (the standing order "Lukio courses: ask me every period"), or, with
## "let the counsellor plan them", only a message: the counsellor's plan stays as it is and can still be changed on the School page.
static func _post_courses(me: SchoolSystem, p: int) -> void:
	me.lukio.asked["c%d" % p] = true
	var per := Lukio.period_info(me, me.lukio, p)
	var c: Dictionary = Data.lukio.stops
	var fill := {"n": int(per.i) + 1, "year": int(per.year_index) + 1, "from": Calendar.format_day(per.start), "to": Calendar.format_day(per.end)}
	if me.courses_mode == "counsellor":
		var text := str(c.courses_auto).format(fill)
		Game.post_event(me.id, str(c.courses_title).format(fill), text)
		_school_message(text)
		return
	var e := Game.post_event(me.id, str(c.courses_title).format(fill), str(c.courses_text).format(fill),
			[{"id": "done", "label": str(c.courses_done.label), "detail": ""}], true)
	e.kind = "lukio_courses"
	e.period = p


static func _answer_lukio(me: SchoolSystem, e: Dictionary, choice: String) -> void:
	match str(e.kind):
		"lukio_choice":
			_answer_choice(me, str(e.step), choice)
		"matric_exam":
			var key := "%s|%s" % [str(e.session), str(e.exam)]
			var sat: Dictionary = me.lukio.matric.sat
			if not sat.has(key):
				sat[key] = {"parts": [], "absent": false}
			if choice == "skip":
				sat[key].absent = true
			elif str(e.get("meet", "")) != "":   # sitting the exam: the race of the same day is withdrawn
				Game.scratch_race(str(e.meet), "school")
		_:
			pass   # (courses: the changes were made in the panel; results, plan, certificate: read and continue)


static func _answer_choice(me: SchoolSystem, step: String, choice: String) -> void:
	match step:
		"maths":
			if choice in ["long", "short"] and choice != str(me.lukio.maths):
				var shift := float(Data.lukio.levels.long_maths_shift)
				me.lukio.maths = choice
				if choice == "long" and not bool(me.lukio.maths_shifted):
					_shift_subject(me, "maths", shift)
					me.lukio.maths_shifted = true
				elif choice == "short" and bool(me.lukio.maths_shifted):
					_shift_subject(me, "maths", -shift)
					me.lukio.maths_shifted = false
			_post_choice(me, "language")
		"language":
			var known := false
			for l in Data.lukio.subjects.languages:
				known = known or str(l.id) == choice
			if known and choice != "none":
				me.lukio.b3 = choice
				var rng := RandomNumberGenerator.new()
				rng.seed = me._seed("lukio_b3|%s" % choice)
				_lukio_subject(me, "b3", Lukio.subject_def("b3"), rng)
			_post_choice(me, "years")
		"years":
			if choice in ["3", "4"] and int(choice) != int(me.lukio.years):
				_set_years(me, int(choice))
			me.lukio.chosen = true
			_replan(me, _replan_from(me))
			var per := Lukio.period_at(me, me.lukio, Game.date)
			if not per.is_empty() and not me.lukio.asked.has("c%d" % int(per.p)):
				_post_courses(me, int(per.p))


# --- The exams of the period and its results ---
## Writes the course exams of the day: [subject ids written].
static func _write_lukio_exams(me: SchoolSystem, d: Dictionary) -> Array:
	var written := []
	for uid in lukio_exams_on(me, d):
		var u := Lukio.unit(me.lukio, uid)
		if u.is_empty() or str(u.st) != "plan":
			continue
		var sid := str(u.s)
		var t: Dictionary = SchoolSystem.cfg().tests
		var rng := RandomNumberGenerator.new()
		rng.seed = me._seed("course|%s|%d" % [uid, Calendar.date_key(d)])
		var score := me.level(sid) + rng.randfn(0.0, float(t.noise_sd)) - _week_and_stress_penalty(me, d, float(t.stress_from), float(t.stress_penalty))
		var step := float(t.round_to)
		score = clampf(roundf(score / step) * step, float(SchoolSystem.cfg().grades.min), float(SchoolSystem.cfg().grades.max))
		u.x = score
		me.tests_log.append({"date": d.duplicate(), "subject": sid, "score": score})
		written.append(sid)
	return written


## The meet-and-tests answer of the week and today's stress, as grade points off an exam (0 when neutral).
static func _week_and_stress_penalty(me: SchoolSystem, d: Dictionary, stress_from: float, stress_penalty: float) -> float:
	if SchoolSystem.neutral:
		return 0.0
	var off := float(SchoolSystem.option_of(me.choice_of(Calendar.monday_of(d))).get("test_penalty", 0.0))
	var mind := MindSystem.sys()
	if mind != null:
		var st := mind.value("stress")
		if st > stress_from:
			off += (st - stress_from) / (100.0 - stress_from) * stress_penalty
	return off


static func _lukio_day_end(me: SchoolSystem, d: Dictionary) -> void:
	var per := Lukio.period_at(me, me.lukio, d)
	if per.is_empty():
		return
	var last: Dictionary = per.exam.back() if not per.exam.is_empty() else per.end
	if Calendar.date_key(d) == Calendar.date_key(last):
		_finish_period(me, int(per.p), SchoolSystem.decisions_enabled and not SchoolSystem.neutral)


## The end of a period: every course of it graded (a failed course goes to the next period's exam week once), its results kept
## as a report and, in the real game, shown in a stop.
static func _finish_period(me: SchoolSystem, p: int, stop: bool) -> void:
	if me.lukio.asked.has("r%d" % p):
		return
	me.lukio.asked["r%d" % p] = true
	var w := float(Data.lukio.courses.exam_weight)
	var graded := []
	var retakes := []
	for u in Lukio.courses_in(me.lukio, p):
		if str(u.st) != "plan":
			continue
		var kind := Lukio.kind_of(str(u.s))
		var g := -1
		if str(u.k) != "coach" and kind != "pass":
			var lv := me.level(str(u.s))
			if kind == "academic":
				var x := float(u.x) if float(u.x) >= 0.0 else lv
				g = clampi(floori(w * x + (1.0 - w) * lv + 0.5), 4, 10)
			else:
				g = clampi(floori(lv + 0.5), 4, 10)
		if bool(u.r):
			g = maxi(g, int(u.g))
			u.r = false
		u.g = g
		u.st = "done"
		graded.append(u)
		if g == 4 and kind == "academic" and bool(Data.lukio.courses.retake) and not u.has("retaken") and p + 1 < Lukio.period_count(me.lukio):
			u.st = "plan"
			u.p = p + 1
			u.r = true
			u.retaken = true
			u.x = -1.0
			retakes.append(u)
	_lukio_changed(me)
	me.reports.append(_period_report(me, p, graded))
	if stop:
		var per := Lukio.period_info(me, me.lukio, p)
		var c: Dictionary = Data.lukio.stops
		var fill := {"n": int(per.i) + 1}
		var failed := false
		for u in graded:
			failed = failed or int(u.g) == 4
		if not failed:
			# Fix session 2026-10-18: a period without a failed course is a message, not a stop.
			var rep: Dictionary = me.reports.back()
			var names := []
			for sub in Lukio.subject_defs(me.lukio):
				if rep.grades.has(str(sub.id)):
					names.append("%s %d" % [me.any_subject_name(str(sub.id)), int(rep.grades[str(sub.id)])])
			fill["grades"] = ", ".join(names)
			fill["avg"] = "%.2f" % float(rep.average)
			var text := str(c.results_message).format(fill)
			Game.post_event(me.id, str(c.results_title).format(fill), text)
			_school_message(text)
			return
		var e := Game.post_event(me.id, str(c.results_title).format(fill), str(c.results_text).format(fill),
				[{"id": "continue", "label": str(c.results_continue.label), "detail": ""}], true)
		e.kind = "lukio_results"
		e.period = p
		e.index = me.reports.size() - 1


## A message from the school in the School page's thread (nothing when the moments are not running).
static func _school_message(text: String) -> void:
	var ms := Game.get_system("moments") as StoryletSystem
	if ms != null:
		ms.say("school", "system", text)


static func _period_report(me: SchoolSystem, p: int, graded: Array) -> Dictionary:
	var per := Lukio.period_info(me, me.lukio, p)
	var grades := {}
	var total := 0.0
	var n := 0
	var ac := 0.0
	var n_ac := 0
	for s in Lukio.subject_defs(me.lukio):
		var sid := str(s.id)
		if str(s.kind) == "pass":
			continue
		var g := Lukio.subject_grade(me.lukio, sid)
		if g <= 0:
			continue
		grades[sid] = g
		total += g
		n += 1
		if str(s.kind) == "academic":
			ac += g
			n_ac += 1
	var courses := []
	for u in graded:
		courses.append({"id": str(u.id), "s": str(u.s), "n": int(u.n), "g": int(u.g)})
	var label := str(Data.lukio.stops.results_title).format({"n": int(per.i) + 1})
	return {"date": Game.date.duplicate(), "kind": "period", "label": label, "stage": str(me.stage_of(per.end).id), "year": int(per.year),
			"grades": grades, "average": total / maxf(1.0, n), "academic_average": ac / maxf(1.0, n_ac), "period": p, "courses": courses}


static func _lukio_load_parts(me: SchoolSystem, d: Dictionary, scale: float) -> Array:
	var out := []
	var per := Lukio.period_at(me, me.lukio, d)
	if not per.is_empty() and not me.is_exam_day(d):
		var n := 0
		for u in Lukio.courses_in(me.lukio, int(per.p)):
			if Lukio.is_classroom(u) and not bool(u.r):
				n += 1
		var v := float(n - int(Data.lukio.plan.normal_courses)) * float(Data.lukio.plan.load_per_course)
		if v != 0.0:
			out.append({"id": "courses" if v > 0.0 else "courses_light", "value": v * (scale if v > 0.0 else 1.0), "n": n})
	if not me.matric_on(d).is_empty():
		out.append({"id": "matric", "value": float(Data.lukio.matric.life_load) * scale})
	return out
