class_name SchoolMatricPart
extends RefCounted
## The matriculation exams (session S3b; split out of school_system.gd in the fix session 2026-10-18). Static functions over a SchoolSystem: the state (lukio.matric) stays in the system, SchoolSystem forwards to these.

# --- The matriculation exams (session S3b) -----------------------------------------------------------------------------------

## The three sessions for the required exams: from the first session the athlete registered for, else the lukio's last three.
static func matric_main_sessions(me: SchoolSystem) -> Array:
	if me.lukio.is_empty():
		return []
	var locked: Array = me.lukio.matric.locked
	if locked.is_empty():
		return Matriculation.sessions_for(int(me.lukio.start_year), int(me.lukio.years))
	var first := str(locked[0])
	for k in locked:
		if Lukio._session_rank(str(k)) < Lukio._session_rank(first):
			first = str(k)
	return [first, Matriculation.next_key(first), Matriculation.next_key(Matriculation.next_key(first))]


## Every session the plan can use: the main three and, for retakes and better grades, the next three after them.
static func matric_sessions(me: SchoolSystem) -> Array:
	var out := matric_main_sessions(me)
	if out.is_empty():
		return out
	var k := str(out.back())
	for i in int(Data.lukio.matric.retakes):
		k = Matriculation.next_key(k)
		out.append(k)
	return out


## Sessions the plan can still change: not locked, before the deadline.
static func matric_open(me: SchoolSystem, key: String) -> bool:
	return not key in me.lukio.matric.locked and Calendar.date_key(Game.date) <= Calendar.date_key(Matriculation.deadline(key))


## Whether an exam may go into a session: open; a new exam only in the main three; a retake of a failed exam in the next three
## after the failure; a passed one any time; one realia subject a day.
static func matric_allowed(me: SchoolSystem, exam_id: String, key: String) -> bool:
	if me.lukio.is_empty() or not matric_open(me, key) or not exam_id in Matriculation.available(me.lukio):
		return false
	var main := matric_main_sessions(me)
	var tried := false
	for r in me.lukio.matric.results:
		if str(r.exam) == exam_id:
			tried = true
	if not tried and not key in main:
		return false
	if not key in matric_sessions(me):
		return false
	var days: Array = Matriculation.exam(exam_id).get("days", [])
	for ex in me.lukio.matric.plan:
		if str(ex) != exam_id and str(me.lukio.matric.plan[ex]) == key:
			var od: Array = Matriculation.exam(str(ex)).get("days", [])
			if not days.is_empty() and not od.is_empty() and str(days[0]) == str(od[0]):
				return false
	return true


## Puts an exam into a session ("" = out of the plan). False when the rules don't allow it.
static func set_matric(me: SchoolSystem, exam_id: String, key: String) -> bool:
	var plan: Dictionary = me.lukio.matric.plan
	if plan.has(exam_id) and not matric_open(me, str(plan[exam_id])):
		return false
	if key == "":
		plan.erase(exam_id)
		return true
	if not matric_allowed(me, exam_id, key):
		return false
	plan[exam_id] = key
	return true


## The counsellor's plan again for every exam that is not fixed yet.
static func matric_fill_suggestion(me: SchoolSystem) -> void:
	var plan: Dictionary = me.lukio.matric.plan
	for ex in plan.keys():
		if matric_open(me, str(plan[ex])):
			plan.erase(ex)
	var sug := Matriculation.suggest(me, me.lukio)
	var main := matric_main_sessions(me)
	for ex in sug:
		if plan.has(ex) or _passed(me, str(ex)):
			continue
		var k := str(sug[ex])
		if not matric_open(me, k):   # (the suggested session is past: the next open main one)
			k = ""
			for m in main:
				if matric_open(me, str(m)):
					k = str(m)
					break
		if k != "" and matric_allowed(me, str(ex), k):
			plan[ex] = k


static func _passed(me: SchoolSystem, exam_id: String) -> bool:
	for r in me.lukio.matric.results:
		if str(r.exam) == exam_id and Matriculation.passed(str(r.grade)):
			return true
	return false


## The best result of each exam: {exam id: grade}.
static func matric_best(me: SchoolSystem) -> Dictionary:
	var out := {}
	for r in me.lukio.matric.results:
		var ex := str(r.exam)
		if not out.has(ex) or Matriculation.points(str(r.grade)) > Matriculation.points(str(out[ex])):
			out[ex] = str(r.grade)
	return out


## The exams of the plan and the passed ones together (what the rules are checked against).
static func matric_set(me: SchoolSystem) -> Array:
	var out := []
	for ex in me.lukio.matric.plan:
		out.append(str(ex))
	var best := matric_best(me)
	for ex in best:
		if Matriculation.passed(str(best[ex])) and not str(ex) in out:
			out.append(str(ex))
	return out


## The matriculation exams written on a date: [exam ids] (registered ones, or the plan's before the deadline; not skipped).
static func matric_on(me: SchoolSystem, d: Dictionary) -> Array:
	if me.lukio.is_empty():
		return []
	var out := []
	var key := Calendar.date_key(d)
	for k in _sessions_near(me, d):
		var list: Array = me.lukio.matric.registered.get(k, []) if k in me.lukio.matric.locked else _plan_in(me, k)
		for ex in list:
			if bool(me.lukio.matric.sat.get("%s|%s" % [k, str(ex)], {}).get("absent", false)):
				continue
			for dd in Matriculation.exam_dates(k, str(ex)):
				if Calendar.date_key(dd) == key:
					out.append(str(ex))
	return out


## The session whose exams could fall near a date (the spring one in March - April, the autumn one in September).
static func _sessions_near(me: SchoolSystem, d: Dictionary) -> Array:
	var m := int(d.month)
	if m == 3 or m == 4:
		return [Matriculation.key_for("spring", int(d.year))]
	if m == 9 or m == 10:
		return [Matriculation.key_for("autumn", int(d.year))]
	return []


static func _plan_in(me: SchoolSystem, key: String) -> Array:
	var out := []
	for ex in me.lukio.matric.plan:
		if str(me.lukio.matric.plan[ex]) == key:
			out.append(str(ex))
	return out


static func _matric_day_start(me: SchoolSystem, d: Dictionary) -> void:
	var key := Calendar.date_key(d)
	var stops := SchoolSystem.decisions_enabled and not SchoolSystem.neutral
	var main := matric_main_sessions(me)
	# The first plan: from the school year that holds the first deadline (user: one stop for the plan, then one per session).
	if stops and not main.is_empty() and me.lukio.matric.locked.is_empty() and not me.lukio.asked.has("plan"):
		var first_deadline := Matriculation.deadline(str(main[0]))
		var y := SchoolCalendar.year_for(me._town(), SchoolCalendar.year_of(first_deadline))
		if key >= Calendar.date_key(me._first_school_day(y.start, y.end)) and key <= Calendar.date_key(first_deadline) and bool(me.lukio.chosen):
			me.lukio.asked.plan = true
			_post_matric_plan(me, "")
	for k in matric_sessions(me):
		var sk := str(k)
		# The stop to check a session's exams before its deadline.
		if stops and matric_open(me, sk) and not me.lukio.asked.has("reg" + sk) and key >= Calendar.date_key(Matriculation.stop_date(sk)) \
				and me.lukio.asked.has("plan") and not _plan_in(me, sk).is_empty():
			me.lukio.asked["reg" + sk] = true
			_post_matric_plan(me, sk)
		# The exam days.
		if sk in me.lukio.matric.locked:
			for ex in me.lukio.matric.registered.get(sk, []):
				var dates := Matriculation.exam_dates(sk, str(ex))
				for i in dates.size():
					if Calendar.date_key(dates[i]) == key and stops:
						_post_matric_exam(me, sk, str(ex), i, dates.size())
			if key == Calendar.date_key(Matriculation.results_date(sk)) and not me.lukio.asked.has("res" + sk):
				me.lukio.asked["res" + sk] = true
				_matric_results(me, sk, stops)


static func _matric_day_end(me: SchoolSystem, d: Dictionary) -> void:
	me._matric_log = []
	if me.lukio.is_empty():
		return
	var key := Calendar.date_key(d)
	for k in matric_sessions(me):
		var sk := str(k)
		# The deadline: the session's exams are registered for good.
		if key == Calendar.date_key(Matriculation.deadline(sk)) and not sk in me.lukio.matric.locked:
			var list := _plan_in(me, sk)
			if not list.is_empty():
				me.lukio.matric.locked.append(sk)
				me.lukio.matric.registered[sk] = list
				if SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
					var names := []
					for ex in list:
						names.append(Matriculation.exam_name(str(ex), me.lukio))
					Game.post_event(me.id, str(Data.lukio.stops.register_title).format({"session": Matriculation.session_name(sk)}),
							", ".join(names))
		if not sk in me.lukio.matric.locked:
			continue
		for ex in me.lukio.matric.registered.get(sk, []):
			var dates := Matriculation.exam_dates(sk, str(ex))
			for i in dates.size():
				if Calendar.date_key(dates[i]) != key:
					continue
				var sat_key := "%s|%s" % [sk, str(ex)]
				var sat: Dictionary = me.lukio.matric.sat
				if not sat.has(sat_key):
					sat[sat_key] = {"parts": [], "absent": false}
				var entry: Dictionary = sat[sat_key]
				me._matric_log.append({"exam": str(ex), "absent": bool(entry.absent)})
				if not bool(entry.absent):
					(entry.parts as Array).append(_matric_score(me, str(ex), i, d))


## A matriculation exam's score: the subject's level + its optional courses done + a roll - stress and the week's answer.
static func _matric_score(me: SchoolSystem, exam_id: String, part: int, d: Dictionary) -> float:
	var c: Dictionary = Data.lukio.matric.score
	var sid := str(Matriculation.exam(exam_id).get("subject", exam_id))
	var opt := 0
	for u in me.lukio.units:
		if str(u.s) == sid and str(u.k) == "opt" and str(u.st) == "done":
			opt += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = me._seed("matric|%s|%d|%d" % [exam_id, part, Calendar.date_key(d)])
	var t: Dictionary = SchoolSystem.cfg().tests
	return me.level(sid) + minf(float(c.bonus_max), opt * float(c.bonus_per_optional)) + rng.randfn(0.0, float(c.sd)) \
			- me._week_and_stress_penalty(d, float(t.stress_from), float(t.stress_penalty))


## Results day: every registered exam of the session graded; a failed one goes into the next session's plan (while retakes are
## left); the certificate when everything is passed.
static func _matric_results(me: SchoolSystem, key: String, stop: bool) -> void:
	var lines := []
	var any_bad := false
	var total := 0
	var n := 0
	for ex in me.lukio.matric.registered.get(key, []):
		var exs := str(ex)
		var entry: Dictionary = me.lukio.matric.sat.get("%s|%s" % [key, exs], {"parts": [], "absent": false})
		var need := Matriculation.exam_dates(key, exs).size()
		var absent := bool(entry.absent) or (entry.parts as Array).size() < need
		var grade := "I"
		if not absent:
			var s := 0.0
			for x in entry.parts:
				s += float(x)
			grade = Matriculation.grade_for(s / maxf(1.0, (entry.parts as Array).size()))
		me.lukio.matric.results.append({"session": key, "exam": exs, "grade": grade, "points": Matriculation.points(grade), "absent": absent})
		if str(me.lukio.matric.plan.get(exs, "")) == key:
			me.lukio.matric.plan.erase(exs)
		if not Matriculation.passed(grade):
			any_bad = true
			var fails := 0
			for r in me.lukio.matric.results:
				if str(r.exam) == exs and not Matriculation.passed(str(r.grade)):
					fails += 1
			if fails <= int(Data.lukio.matric.retakes) and not _passed(me, exs):   # the retake goes to the next session (the plan can change)
				me.lukio.matric.plan[exs] = Matriculation.next_key(key)
		total += Matriculation.points(grade)
		n += 1
		var c: Dictionary = Data.lukio.stops
		if absent:
			lines.append(str(c.matric_results_absent).format({"exam": Matriculation.exam_name(exs, me.lukio)}))
		else:
			lines.append(str(c.matric_results_line).format({"exam": Matriculation.exam_name(exs, me.lukio), "grade": grade, "name": Matriculation.grade_name(grade)}))
	var ms := MindSystem.sys()
	var st: Dictionary = Data.lukio.stops
	if ms != null and not SchoolSystem.neutral and SchoolSystem.decisions_enabled and n > 0:
		if any_bad:
			ms.add("confidence", float(st.news_delta.bad), str(st.news.matric_bad))
		elif float(total) / n >= 5.0:
			ms.add("confidence", float(st.news_delta.good), str(st.news.matric_good))
	if stop and n > 0:
		var text := str(st.matric_results_text).format({"session": Matriculation.session_name(key)}) + "\n" + "\n".join(lines)
		if any_bad:
			text += "\n\n" + str(st.matric_results_retake)
		var e := Game.post_event(me.id, str(st.matric_results_title), text, [{"id": "continue", "label": str(st["continue"].label), "detail": ""}], true)
		e.kind = "matric_results"
		e.session = key
	_check_certificate(me)


## The matriculation certificate: the passed exams meet the rules and the lukio courses are done.
static func _check_certificate(me: SchoolSystem) -> void:
	if me.lukio.is_empty() or bool(me.lukio.matric.cert) or not bool(me.lukio.get("done", false)):
		return
	var passed := []
	var best := matric_best(me)
	for ex in best:
		if Matriculation.passed(str(best[ex])):
			passed.append(str(ex))
	var chk := Matriculation.check(passed, me.lukio)
	var st: Dictionary = Data.lukio.stops
	if not bool(chk.ok):
		if SchoolSystem.decisions_enabled and not SchoolSystem.neutral and not me.lukio.asked.has("cert_wait"):
			me.lukio.asked.cert_wait = true
			Game.post_event(me.id, str(st.certificate_title), str(st.certificate_wait))
		return
	me.lukio.matric.cert = true
	if SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
		var lines := []
		var pts := 0
		for ex in passed:
			lines.append("%s: %s" % [Matriculation.exam_name(ex, me.lukio), str(best[ex])])
			pts += Matriculation.points(str(best[ex]))
		var text := str(st.certificate_text) + "\n" + "\n".join(lines) + "\n\n" + str(st.certificate_points).format({"points": pts, "n": passed.size()})
		var e := Game.post_event(me.id, str(st.certificate_title), text, [{"id": "continue", "label": str(st["continue"].label), "detail": ""}], true)
		e.kind = "matric_cert"
		var ms := MindSystem.sys()
		if ms != null:
			ms.add("confidence", float(st.news_delta.graduate), str(st.news.graduate))


static func _post_matric_plan(me: SchoolSystem, key: String) -> void:
	var st: Dictionary = Data.lukio.stops
	var title := ""
	var text := ""
	if key == "":
		var names := []
		for k in matric_main_sessions(me):
			names.append(Matriculation.session_name(str(k)))
		title = str(st.plan_title)
		text = str(st.plan_text).format({"sessions": ", ".join(names)})
	else:
		title = str(st.register_title).format({"session": Matriculation.session_name(key)})
		text = str(st.register_text).format({"session": Matriculation.session_name(key), "date": Calendar.format_day(Matriculation.deadline(key))})
	var e := Game.post_event(me.id, title, text, [{"id": "done", "label": str(st.plan_done.label), "detail": ""}], true)
	e.kind = "matric_plan"
	e.session = key


static func _post_matric_exam(me: SchoolSystem, key: String, exam_id: String, part: int, parts: int) -> void:
	var st: Dictionary = Data.lukio.stops
	var sat: Dictionary = me.lukio.matric.sat.get("%s|%s" % [key, exam_id], {})
	if bool(sat.get("absent", false)):
		return
	var part_text := ""
	if parts > 1:
		var names: Array = Matriculation.exam(exam_id).get("parts", [])
		part_text = str(st.exam_part).format({"part": str(names[part]) if part < names.size() else str(part + 1)})
	var meet := ""
	var race_text := ""
	var races := Calendar.races_in_week(Game.entries, Calendar.monday_of(Game.date))
	var di := Calendar.days_between(Calendar.monday_of(Game.date), Game.date)
	if races.has(di):
		meet = str(races[di].key)
		race_text = str(st.exam_race).format({"meet": str(races[di].name)})
	var choices := []
	for k in ["sit", "skip"]:
		choices.append({"id": k, "label": str(st.exam_options[k].label), "detail": str(st.exam_options[k].detail)})
	var e := Game.post_event(me.id, str(st.exam_title), str(st.exam_text).format({"exam": Matriculation.exam_name(exam_id, me.lukio), "part": part_text, "race": race_text}).strip_edges(),
			choices, true)
	e.kind = "matric_exam"
	e.session = key
	e.exam = exam_id
	e.part = part
	e.meet = meet
