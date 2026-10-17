class_name Matriculation
extends RefCounted
## The matriculation examination (ylioppilastutkinto; GDD 4.9.3, session S3b), static: the sessions of a lukio path, their exam
## days (data/school.json `matriculation`: the verified sessions, `rules.matriculation` for later years, estimated), the
## registration deadlines and results days, the exams the athlete can take, the board's rules as ✓ / ✗ lines, the counsellor's
## suggestion and the grade of a score. The state (the plan, what was sat, the results) lives in SchoolSystem.lukio.matric.
## Rules and numbers: data/lukio.json `matric` (real rules from the board's page; the score model and its thresholds estimated).
## A session key is "s2030" (the spring exams of 2030) or "a2030" (the autumn exams of 2030).

static var _days_cache := {}


static func cfg() -> Dictionary:
	return Data.lukio.matric


# --- Sessions ---------------------------------------------------------------------------------------------------------------

## "spring" / "autumn" and the calendar year of a key.
static func season_of(key: String) -> String:
	return "spring" if key.begins_with("s") else "autumn"


static func year_of(key: String) -> int:
	return int(key.substr(1))


static func key_for(season: String, year: int) -> String:
	return ("s" if season == "spring" else "a") + str(year)


## The session after `key` (spring -> the autumn of the same year -> the next spring).
static func next_key(key: String) -> String:
	if season_of(key) == "spring":
		return key_for("autumn", year_of(key))
	return key_for("spring", year_of(key) + 1)


## The three sessions of a lukio that starts in school year `start_year` and lasts `years`: the spring of its second-last
## school year, the autumn and the spring of its last one (the board allows at most three sessions in a row for the
## required exams, also in a four-year lukio).
static func sessions_for(start_year: int, years: int) -> Array:
	var last := start_year + years - 1   # the last school year (it ends in the spring of last + 1)
	return [key_for("spring", last), key_for("autumn", last), key_for("spring", last + 1)]


## The session in which the exams of a calendar year's spring / autumn are, as "spring 2030".
static func session_name(key: String) -> String:
	return str(Data.lukio.ui.session_names[season_of(key)]).format({"year": year_of(key)})


## The exam days of a session: [{date, day}] (day = the board's group id such as "foreign_long"). The verified sessions
## from school.json, every other by the rules (estimated).
static func days(key: String) -> Array:
	if _days_cache.has(key):
		return _days_cache[key]
	var out := []
	var m: Dictionary = Data.school.verified.matriculation
	var vk := ("spring_%d" if season_of(key) == "spring" else "autumn_%d") % year_of(key)
	if m.has(vk):
		for d in m[vk].days:
			for ex in d.exams:
				out.append({"date": Calendar.parse_date(str(d.date)), "day": str(ex)})
	else:
		var r: Dictionary = Data.school.rules.matriculation
		var start := _start_of(key)
		var offs: Array = r.spring_offsets.exams if season_of(key) == "spring" else r.autumn_offsets.exams
		for o in offs:
			out.append({"date": Game.add_days(start, int(o[0])), "day": str(o[1])})
	_days_cache[key] = out
	return out


## True when the session's dates come from the board's published list.
static func verified(key: String) -> bool:
	var vk := ("spring_%d" if season_of(key) == "spring" else "autumn_%d") % year_of(key)
	return Data.school.verified.matriculation.has(vk)


## The first exam day by the rule: the first Tuesday on or after 10 March / the first Monday on or after 12 September.
static func _start_of(key: String) -> Dictionary:
	var spring := season_of(key) == "spring"
	var d := {"year": year_of(key), "month": 3 if spring else 9, "day": 10 if spring else 12}
	var want := 1 if spring else 0   # (Calendar.weekday: 0 = Monday)
	while Calendar.weekday(d) != want:
		d = Game.add_days(d, 1)
	return d


static func first_day(key: String) -> Dictionary:
	var list := days(key)
	var best: Dictionary = list[0].date
	for x in list:
		if Calendar.date_key(x.date) < Calendar.date_key(best):
			best = x.date
	return best


static func last_day(key: String) -> Dictionary:
	var best: Dictionary = first_day(key)
	for x in days(key):
		if Calendar.date_key(x.date) > Calendar.date_key(best):
			best = x.date
	return best


## The dates an exam is written on in a session (Finnish: its two parts' days).
static func exam_dates(key: String, exam_id: String) -> Array:
	var out := []
	var want: Array = exam(exam_id).get("days", [])
	for w in want:
		for x in days(key):
			if str(x.day) == str(w):
				out.append(x.date)
				break
	return out


## The binding registration deadline of a session (data matric.registration).
static func deadline(key: String) -> Dictionary:
	var r: Dictionary = cfg().registration[season_of(key)]
	return {"year": year_of(key) + int(r.year_offset), "month": int(r.month), "day": int(r.day)}


## The day of the stop that asks to check a session's exams (some days before the deadline).
static func stop_date(key: String) -> Dictionary:
	return Game.add_days(deadline(key), -int(cfg().registration.stop_days_before))


## The day the results reach the students (verified for spring 2027, else the session's first day + results_days).
static func results_date(key: String) -> Dictionary:
	var m: Dictionary = Data.school.verified.matriculation
	var vk := ("spring_%d" if season_of(key) == "spring" else "autumn_%d") % year_of(key)
	if m.has(vk) and m[vk].has("results_to_students"):
		return Calendar.parse_date(str(m[vk].results_to_students))
	return Game.add_days(first_day(key), int(cfg().results.results_days))


# --- Exams ------------------------------------------------------------------------------------------------------------------

static func exam(exam_id: String) -> Dictionary:
	for e in cfg().exams:
		if str(e.id) == exam_id:
			return e
	return {}


## Whether an exam is of the long syllabus (maths: by the athlete's syllabus).
static func is_long(exam_id: String, L: Dictionary) -> bool:
	var e := exam(exam_id)
	if e.has("long_if"):
		return str(L.get("maths", "short")) == str(e.long_if)
	return bool(e.get("long", false))


## The exam's name for the player ("Maths (long syllabus)", "German (short syllabus)").
static func exam_name(exam_id: String, L: Dictionary) -> String:
	var e := exam(exam_id)
	return str(e.get("name", exam_id)).format({"syllabus": str(Data.lukio.ui.syllabus.get(str(L.get("maths", "short")), "")),
			"language": Lukio.language_name(str(L.get("b3", "none")))})


## The exams the athlete can take (b3 only with a new language).
static func available(L: Dictionary) -> Array:
	var out := []
	for e in cfg().exams:
		if str(e.id) == "b3" and str(L.get("b3", "none")) == "none":
			continue
		out.append(str(e.id))
	return out


## The board's rules for a set of exams: [{ok, text}] and `ok` for all of them. `plan` = {exam id: session key}.
static func check(exams: Array, L: Dictionary, plan := {}) -> Dictionary:
	var u: Dictionary = Data.lukio.ui
	var c := cfg()
	var lines := []
	var has_finnish := "finnish" in exams
	lines.append({"ok": has_finnish, "text": str(u.rule_finnish)})
	lines.append({"ok": exams.size() >= int(c.min_exams), "text": str(u.rule_count).format({"n": int(c.min_exams), "have": exams.size()})})
	var groups := {}
	for x in exams:
		var g := str(exam(str(x)).get("group", ""))
		if g != "mother_tongue":
			groups[g] = true
	lines.append({"ok": groups.size() >= int(c.min_groups), "text": str(u.rule_groups).format({"n": int(c.min_groups), "have": groups.size()})})
	var long := false
	for x in exams:
		if is_long(str(x), L):
			long = true
	lines.append({"ok": long, "text": str(u.rule_long)})
	# One subject per realia day in a session.
	var per := {}
	for x in plan:
		var day: Array = exam(str(x)).get("days", [])
		if str(exam(str(x)).get("group", "")) != "realia" or day.is_empty():
			continue
		var k := "%s|%s" % [str(plan[x]), str(day[0])]
		per[k] = int(per.get(k, 0)) + 1
	for k in per:
		if int(per[k]) > 1:
			lines.append({"ok": false, "text": str(u.rule_days).format({"session": session_name(str(k).split("|")[0])})})
	var ok := true
	for l in lines:
		ok = ok and bool(l.ok)
	return {"ok": ok, "lines": lines}


## The counsellor's suggestion: Finnish, English (long), maths, Swedish and the realia subject you are best at; English in the
## first session, Swedish and the realia subject in the autumn, Finnish and maths in the last spring.
static func suggest(ss: SchoolSystem, L: Dictionary) -> Dictionary:
	var keys: Array = sessions_for(int(L.start_year), int(L.years))
	var best := ""
	var best_level := -1.0
	for e in cfg().exams:
		if str(e.group) != "realia":
			continue
		var lv := ss.level(str(e.subject))
		if lv > best_level:
			best_level = lv
			best = str(e.id)
	return {"english": keys[0], "swedish": keys[1], best: keys[1], "finnish": keys[2], "maths": keys[2]}


# --- Grades -----------------------------------------------------------------------------------------------------------------

## The grade of a score: the first threshold it reaches (L, E, M, C, B, A), else I.
static func grade_for(score: float) -> String:
	var th: Array = cfg().score.thresholds
	var grades: Array = cfg().grades
	for i in th.size():
		if score >= float(th[i]):
			return str(grades[i].id)
	return "I"


static func points(grade_id: String) -> int:
	for g in cfg().grades:
		if str(g.id) == grade_id:
			return int(g.points)
	return 0


static func grade_name(grade_id: String) -> String:
	for g in cfg().grades:
		if str(g.id) == grade_id:
			return str(g.name)
	return grade_id


static func passed(grade_id: String) -> bool:
	return grade_id != "" and grade_id != "I"
