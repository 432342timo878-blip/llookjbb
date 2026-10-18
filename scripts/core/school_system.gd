class_name SchoolSystem
extends GameSystem
## School (GDD 4.9.3, session S1; headless: the School page and the decisions come in S2). GameSystem id "school".
## - The stage by date: grade 8 in 2026-27 for a 2012-born athlete, grade 9 next, then a placeholder until S3
##   (data/school_life.json `stages`). The calendar of the athlete's hometown is SchoolCalendar (data/school.json).
## - 17 real subjects graded 4-10, each with a hidden natural level (the creation answer + an aptitude roll); on every school
##   day each grade drifts towards natural + the study effort + the focus subjects. Single tests through the term, report cards
##   at Christmas and in June (stored in `reports`).
## - Two weekly life settings: study effort (light / normal / heavy) and free time (little / normal / lots).
## - LIFE LOAD per day (life_load): 0 on a normal school day at Normal / Normal; holidays lighter; the settings, double days on
##   school days (two separate practices), busy test weeks and exam weeks heavier. It slows fatigue recovery (WeekSim), makes
##   colds and injuries a little more likely (HealthSystem) and pulls stress (MindSystem.pulls, with the causes); free time also
##   pulls motivation. At 0 nothing is computed differently: today's game to the last digit.
## Dice: every roll comes from a seed made of the career (name + birth date) and what is rolled (the aptitudes; a school year's
## test days; one test), so nothing depends on when it is asked and the global dice are untouched; no dice state to save.
## Switches for the tools: `model_enabled` (off = no school at all; sys() is null) and `neutral` (the life load is always 0 and
## nothing pulls the moods: the body and the mind are today's game; grades still drift and tests are still written).
## The player decides: the settings change the quality and the load of the days, never what is trained.

static var model_enabled := true
static var neutral := false
## The decisions and the report card stop (session S2): OFF unless main.gd switches it on, so every tool that plays days without the
## real game shell never meets a school stop (like CoachProposals.enabled).
static var decisions_enabled := false

const EFFORTS := ["light", "normal", "heavy"]
const FREE_TIMES := ["little", "normal", "lots"]

var started := false
var effort := "normal"
var free_time := "normal"
var focus: Array = []           # 0-2 subject ids
var subjects := {}              # subject id -> {"level": float, "natural": float}
var term_tests := {}            # subject id -> [scores] written this term (the next report card uses them)
var tests_log: Array = []       # the latest tests, oldest first: [{date, subject, score}]
var reports: Array = []         # report cards, oldest first: [{date, kind, stage, year, grades {id: int}, average, academic_average}]
var week_choices := {}          # the Monday's date key (as text) -> the id of the answer to that week's meet-and-tests decision (S2)
var paths: Array = []           # the schools after grade 9 (S3a): [{kind (urheilulukio / lukio / vocational / grade_10), school (id or ""), town, start_year, years}]
var applications := {}          # the application year (as text) -> {wishes [ids], locked, test {...}, results [...], decided} (S3a)
## Lukio (session S3b; {} until a lukio starts): {start_year, school, sports, maths (long / short), b3 (none / german / french /
## spanish), music_art, years, chosen, shifted, units [courses: see Lukio], matric {plan {exam: session}, locked [sessions],
## registered {session: [exams]}, sat {"session|exam": {parts [scores], absent}}, results [{session, exam, grade, points, absent}],
## cert}, asked {stop keys}, done (the lukio courses are over)}.
var lukio := {}

var _schedules := {}            # school year -> {date key -> [subject ids]} (made from the career's seed; not saved)
var _lukio_exams := {}          # lukio period -> {date key -> [course ids]} (Lukio.exam_schedule; not saved, cleared on a change)
var _matric_log: Array = []     # today's matriculation exams for the day log ({exam, absent}; not saved)
var _exam_days := {}            # school year -> {date key: true} (from the stage's exam_weeks; not saved)
var _stage_cache := {}          # school year -> the stage after grade 9 (from the paths; not saved)

const KEEP_TESTS := 60


func _init() -> void:
	id = "school"


static func cfg() -> Dictionary:
	return Data.school_life


## The career's school system, or null when the model is off.
static func sys() -> SchoolSystem:
	if not model_enabled:
		return null
	return Game.get_system("school") as SchoolSystem


# --- The stage and the calendar ----------------------------------------------------------------------------------------

## The town the athlete lives and goes to school in: the one they moved to for a school (S3a), else their hometown.
func _town() -> String:
	var a := Game.athlete
	if a == null:
		return ""
	return a.training_town if a.training_town != "" else a.hometown


func town() -> String:
	return _town()


## The stage on a date: {id, grade, name, kind, subjects, scale, exam_weeks, final?, applies?} (data stages.list for grades 8-9,
## from the athlete's path after that: stages.secondary).
func stage_of(d: Dictionary) -> Dictionary:
	var list: Array = cfg().stages.list
	if Game.athlete == null:
		return list[0]
	var year := SchoolCalendar.year_of(d)
	var grade := year - int(Game.athlete.birth_date.year) - int(cfg().stages.grade_offset)
	if year >= first_secondary_year():
		return _secondary_stage(year)
	var pick: Dictionary = list[0]
	for s in list:
		if grade >= int(s.grade):
			pick = s
	return pick


## The school year the athlete would be in grade 10 (born 2012: 2028): the first of the path.
func first_secondary_year() -> int:
	return int(Game.athlete.birth_date.year) + int(cfg().stages.grade_offset) + 10


## The stage of a school year after grade 9: its path's kind, the last year of a path `final`, `school` and `year_index`.
func _secondary_stage(year: int) -> Dictionary:
	if _stage_cache.has(year):
		return _stage_cache[year]
	var sec: Dictionary = cfg().stages.secondary
	var seg := segment_for(year)
	var s: Dictionary
	if seg.is_empty():
		s = (sec.graduated as Dictionary).duplicate(true)
	else:
		s = (sec[str(seg.kind)] as Dictionary).duplicate(true)
		s.final = year == int(seg.start_year) + int(seg.years) - 1
		s.school = str(seg.get("school", ""))
		s.year_index = year - int(seg.start_year)
	s.grade = year - int(Game.athlete.birth_date.year) - int(cfg().stages.grade_offset)
	_stage_cache[year] = s
	return s


## The path segment that holds a school year ({} = school is over). A year no stored segment covers gets the default: three
## years of the general lukio (what a tool that never decides, or a player who made no list, gets), after grade 9 and after a
## 10th-grade year.
func segment_for(year: int) -> Dictionary:
	var first := first_secondary_year()
	var end_all := first
	for sgm in paths:
		if year >= int(sgm.start_year) and year < int(sgm.start_year) + int(sgm.years):
			return sgm
		end_all = maxi(end_all, int(sgm.start_year) + int(sgm.years))
	if year < first:
		return {}
	if paths.is_empty() or str(paths.back().kind) == "grade_10":
		var years := int(cfg().stages.secondary.lukio.years)
		if year >= end_all and year < end_all + years:
			return {"kind": "lukio", "school": "", "town": _town(), "start_year": end_all, "years": years, "default": true}
	return {}


## The segment of the school year the game date is in ({} = none).
func current_path() -> Dictionary:
	return segment_for(SchoolCalendar.year_of(Game.date))


## The id of the school the athlete goes to now ("" = a general school or none).
func current_school_id() -> String:
	return str(current_path().get("school", ""))


## True on a morning-practice day of a sports lukio (a school day): the second session of that day is not a double day.
func morning_day(d: Dictionary) -> bool:
	var stage := stage_of(d)
	if not bool(stage.get("morning", false)):
		return false
	var m: Dictionary = Data.application.morning
	var days: Array = m.schools.get(str(stage.get("school", "")), m.default)
	return Calendar.weekday(d) in days.map(func(x): return int(x))


## What kind of day a date is: SchoolCalendar.day + {exam (a day of an exam week), tests (subject ids tested that day)}.
func day_info(d: Dictionary) -> Dictionary:
	var info := SchoolCalendar.day(_town(), d)
	info.exam = info.kind == "school" and is_exam_day(d)
	info.tests = tests_on(d)
	var m := matric_on(d)   # S3b: the matriculation exams registered for this day (only when there are any: the old fields stay as they were)
	if not m.is_empty():
		info.matric = m
	return info


func is_exam_day(d: Dictionary) -> bool:
	return _exam_set(SchoolCalendar.year_of(d)).has(Calendar.date_key(d))


## The days of the stage's exam weeks in a school year (rule {before: christmas | winter | end, weeks: n} = the Mon-Fri school
## week n weeks before that break's first free day; for "end" the week holding the last school day counts as week 1).
func _exam_set(year: int) -> Dictionary:
	if _exam_days.has(year):
		return _exam_days[year]
	var out := {}
	var y := SchoolCalendar.year_for(_town(), year)
	var stage := stage_of({"year": year, "month": 9, "day": 1})
	for rule in stage.get("exam_weeks", []):
		if bool(rule.get("periods", false)):   # a lukio: the last school days of each of its periods (S3a)
			_add_period_exams(out, y, rule)
			continue
		var anchor: Dictionary
		match str(rule.get("before", "")):
			"christmas":
				anchor = _break_from(y, "christmas")
			"winter":
				anchor = _break_from(y, "winter")
			"end":
				anchor = Game.add_days(y.end, 1)
			_:
				continue
		var monday := Game.add_days(Calendar.monday_of(Game.add_days(anchor, -1)), -7 * (int(rule.get("weeks", 1)) - 1))
		for i in 5:
			var d := Game.add_days(monday, i)
			if SchoolCalendar.is_school_day(_town(), d):
				out[Calendar.date_key(d)] = true
	_exam_days[year] = out
	return out


## The exam weeks of a lukio's periods (data/school.json rules.lukio_periods: the start of each period as days from the first
## school day; an exam week = the last `exam_week_school_days` school days of a period). The last period's ends `last_shift_days` days
## before the year's end (Helsingin kielilukio 2026-27: 3 June, a Thursday, for the end on Saturday 5 June).
func _add_period_exams(out: Dictionary, y: Dictionary, rule: Dictionary) -> void:
	var lp: Dictionary = Data.school.rules.lukio_periods
	var offs: Array = lp.start_offsets_days
	var n_days := int(lp.exam_week_school_days)
	for i in offs.size():
		var end_day: Dictionary
		if i + 1 < offs.size():
			end_day = Game.add_days(y.start, int(offs[i + 1]) - 1)
		else:
			end_day = Game.add_days(y.start, int(lp.end_offset_days) + int(rule.get("last_shift_days", 0)))
		var d := end_day
		var got := 0
		while got < n_days and Calendar.date_key(d) >= int(y.start_key):
			if SchoolCalendar.is_school_day(_town(), d):
				out[Calendar.date_key(d)] = true
				got += 1
			d = Game.add_days(d, -1)


static func _break_from(y: Dictionary, break_id: String) -> Dictionary:
	for b in y.breaks:
		if str(b.id) == break_id:
			return b.from
	return y.end


# --- Life load -----------------------------------------------------------------------------------------------------------

## The day's life load in points (0 = a normal school day at Normal / Normal = today's game). `session_ids` = the day's
## sessions (two separate practices on a school day = a double day). Always 0 with the model off or neutral.
func life_load(d: Dictionary, session_ids: Array) -> float:
	var total := 0.0
	for p in load_parts(d, session_ids):
		total += float(p.value)
	return total


## The parts of the day's life load: [{id, value, n?}] (ids: holiday, effort_heavy / effort_light, free_lots / free_little,
## double_day, busy_test (n = the week's tests), exam). Empty when there is nothing (always with the model off or neutral).
func load_parts(d: Dictionary, session_ids: Array) -> Array:
	var out := []
	if not model_enabled or neutral or Game.athlete == null:
		return out
	var ll: Dictionary = cfg().life_load
	# A late night from a moment the evening before (session P1: a reply's `sleep`, StoryletSystem.late_night), any day.
	var ms := Game.get_system("moments") as StoryletSystem
	var late := ms.late_night(d) if ms != null else 0.0
	if late > 0.0:
		out.append({"id": "late_night", "value": late})
	var info := SchoolCalendar.day(_town(), d)
	if info.kind in ["holiday", "summer"]:
		if float(ll.holiday_weekday) != 0.0:
			out.append({"id": "holiday", "value": float(ll.holiday_weekday)})
		return out
	if info.kind != "school":
		return out
	var scale := float(stage_of(d).get("scale", 1.0))
	var e := float(ll.effort.get(effort, 0.0))
	if e != 0.0:
		out.append({"id": "effort_" + effort, "value": e * (scale if e > 0.0 else 1.0)})
	var f := float(ll.free_time.get(free_time, 0.0))
	if f != 0.0:
		out.append({"id": "free_" + free_time, "value": f * (scale if f > 0.0 else 1.0)})
	if is_double_on(d, session_ids):
		out.append({"id": "double_day", "value": float(ll.double_day) * scale})
	var chosen := choice_of(Calendar.monday_of(d))   # the week's meet-and-tests answer (S2): "bus" = studying late all week
	if chosen != "":
		var dl := float(option_of(chosen).get("load", 0.0))
		if dl != 0.0:
			out.append({"id": "decision_" + chosen, "value": dl * scale})
	var in_lukio := lukio_active(d)
	var today := tests_on(d).size()
	if today > 0 and not (in_lukio and is_exam_day(d)):   # (a lukio's course exams are its exam week: the exam part covers them, S3b)
		var n := tests_in_week(Calendar.monday_of(d))
		if n > int(cfg().tests.normal_per_week):
			out.append({"id": "busy_test", "value": today * float(ll.busy_test) * scale, "n": n})
	if is_exam_day(d):
		out.append({"id": "exam", "value": float(ll.exam_day) * scale})
	if in_lukio:   # S3b: the period's classroom courses against the usual five, and a matriculation exam day
		out.append_array(_lukio_load_parts(d, scale))
	return out


## Two separate practices: at least two sessions that are not add-ons (drills, strides... ride along in the same practice).
static func is_double(session_ids: Array) -> bool:
	return _main_sessions(session_ids) >= 2


static func _main_sessions(session_ids: Array) -> int:
	var add_ons: Array = Data.school_life.life_load.add_ons
	var main := 0
	for sid in session_ids:
		if not str(sid) in add_ons:
			main += 1
	return main


## A double day on a given date: on a morning-practice day of a sports lukio one of the practices is the school's own and
## does not count (S3a: "second sessions without the extra life load").
func is_double_on(d: Dictionary, session_ids: Array) -> bool:
	var main := _main_sessions(session_ids)
	if main >= 2 and morning_day(d):
		main -= 1
	return main >= 2


## Fatigue: the share of fatigue carried to tomorrow goes up by this (WeekSim._play_day; 0.0 at a load of 0).
static func keep_shift(load: float) -> float:
	return load * float(Data.school_life.effects.keep_per_point)


## Colds: the day's chance x this (exactly 1.0 at a load of 0).
static func illness_mult(load: float) -> float:
	if load == 0.0:
		return 1.0
	var e: Dictionary = Data.school_life.effects
	return maxf(float(e.illness_min), 1.0 + float(e.illness_per_point) * load)


## Injuries (overuse and bad luck): x this for a heavier day (exactly 1.0 at a load of 0 or below).
static func injury_mult(load: float) -> float:
	if load <= 0.0:
		return 1.0
	return 1.0 + float(Data.school_life.effects.injury_per_point) * load


# --- The moods (read by MindSystem) ---------------------------------------------------------------------------------------

## The week starting `monday` as stress pulls: [{text, delta}] per cause (the life load summed over the 7 days / 7 x
## stress_per_point). The days' sessions come from the plan of that week (the week in progress: with its day changes).
func stress_pulls(monday: Dictionary) -> Array:
	var out := []
	if not model_enabled or neutral or Game.athlete == null:
		return out
	var sums := {}
	var counts := {}
	var order := []
	for i in 7:
		var d := Game.add_days(monday, i)
		for p in load_parts(d, _sessions_of_day(monday, i)):
			if not sums.has(p.id):
				order.append(p.id)
				sums[p.id] = 0.0
			sums[p.id] = float(sums[p.id]) + float(p.value)
			counts[p.id] = int(p.get("n", 0))
	var texts: Dictionary = cfg().texts.pulls
	var per := float(cfg().effects.stress_per_point)
	for pid in order:
		var delta := float(sums[pid]) / 7.0 * per
		if delta != 0.0:
			out.append({"text": str(texts.get(pid, pid)).format({"n": counts[pid]}), "delta": delta})
	return out


## Free time's pull on motivation: [{text, delta}].
func motivation_pulls() -> Array:
	if not model_enabled or neutral:
		return []
	var e: Dictionary = cfg().effects
	var texts: Dictionary = cfg().texts.pulls
	match free_time:
		"lots":
			return [{"text": str(texts.motivation_lots), "delta": float(e.motivation_lots)}]
		"little":
			return [{"text": str(texts.motivation_little), "delta": -float(e.motivation_little)}]
	return []


## Stress news for the Sunday before the week starting `monday`: [{delta, text}] (a busy test week, an exam week ahead).
func week_news(monday: Dictionary) -> Array:
	var out := []
	if not model_enabled or neutral or Game.athlete == null:
		return out
	var e: Dictionary = cfg().effects
	var news: Dictionary = cfg().texts.news
	var n := tests_in_week(monday)
	if n > int(cfg().tests.normal_per_week) and float(e.busy_week_news) != 0.0:
		out.append({"delta": float(e.busy_week_news), "text": str(news.busy_week).format({"n": n})})
	for i in 5:
		if is_exam_day(Game.add_days(monday, i)):
			out.append({"delta": float(e.exam_week_news), "text": str(news.exam_week)})
			break
	for i in 5:   # a matriculation exam in the week (S3b)
		if not matric_on(Game.add_days(monday, i)).is_empty():
			out.append({"delta": float(Data.lukio.matric.stress_news), "text": str(Data.lukio.ui.news_matric_week)})
			break
	return out


func _sessions_of_day(monday: Dictionary, i: int) -> Array:
	if Game.season == null:
		return []
	var w = Game._week
	if w != null and Calendar.date_key(w.monday) == Calendar.date_key(monday):
		if w.is_race_day(i):
			return []
		return w.session_ids(i)
	var races := Calendar.races_in_week(Game.entries, monday)
	if races.has(i):
		return []
	return WeekPlan.of(Game.season.week_for(monday)).days[i]


# --- Grades -----------------------------------------------------------------------------------------------------------------

## The athlete's school answer id (the creation answer; older saves from school_level).
static func answer_of(a: Athlete) -> String:
	var answers: Dictionary = Data.school_life.answers
	if a.school_answer != "" and answers.has(a.school_answer):
		return a.school_answer
	return str(answers.from_level.get(a.school_level, "fine"))


func _seed(what: String) -> int:
	var a := Game.athlete
	var b: Dictionary = a.birth_date
	return ("school|%s|%s|%d-%d-%d" % [what, a.full_name(), int(b.get("year", 0)), int(b.get("month", 0)), int(b.get("day", 0))]).hash()


## The subjects' starting levels and natural levels (once a career, from its own seed).
func _ensure_started() -> void:
	if started or Game.athlete == null:
		return
	started = true
	var a := Game.athlete
	var c := cfg()
	var ans: Dictionary = c.answers[answer_of(a)]
	var apt: Dictionary = c.aptitude
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed("aptitude")
	var list: Array = c.subjects.list
	var offsets := []
	var sums := {}
	var counts := {}
	for s in list:
		var o := clampf(rng.randfn(0.0, float(apt.sd)), -float(apt.max), float(apt.max))
		offsets.append(o)
		sums[s.kind] = float(sums.get(s.kind, 0.0)) + o
		counts[s.kind] = int(counts.get(s.kind, 0)) + 1
	var lo := float(c.grades.min)
	var hi := float(c.grades.max)
	subjects = {}
	for i in list.size():
		var sid := str(list[i].id)
		# (Re-centred per kind: the academic subjects average the answer's level exactly, and so do the practical ones before PE's bonus.)
		var o: float = offsets[i] - float(sums[list[i].kind]) / int(counts[list[i].kind])
		if sid == "pe":
			o += float(apt.pe_bonus) + (float(apt.sports_class) if a.training_base == "sports_class" else 0.0)
		subjects[sid] = {"natural": clampf(float(ans.natural) + o, lo, hi), "level": clampf(float(ans.start) + o, lo, hi)}


## The subjects on the report card now: the grade 8-9 subjects, or in a lukio its graded subjects (S3b; passed-only courses
## such as study counselling are not on the list).
func subject_list() -> Array:
	if lukio_active(Game.date):
		var out := []
		for s in Lukio.subject_defs(lukio):
			if str(s.kind) != "pass":
				out.append({"id": str(s.id), "name": Lukio.subject_name(str(s.id), lukio), "kind": str(s.kind)})
		return out
	return cfg().subjects.list


func is_academic(sid: String) -> bool:
	if lukio_active(Game.date):
		return Lukio.kind_of(sid) == "academic" and not Lukio.subject_def(sid).is_empty()
	for s in cfg().subjects.list:
		if str(s.id) == sid:
			return str(s.kind) == "academic"
	return false


## A subject's level now (a float 4-10; the report card shows whole grades).
func level(sid: String) -> float:
	return float(subjects.get(sid, {}).get("level", 0.0))


## Where a subject's grade drifts at the current settings.
func target(sid: String) -> float:
	var g: Dictionary = cfg().grades
	var t := float(subjects[sid].natural) + float(g.effort_shift.get(effort, 0.0))
	if sid in focus:
		t += float(g.focus_shift)
	elif is_academic(sid):
		t -= float(g.focus_others) * focus.size()
	return clampf(t, float(g.min), float(g.max))


## The average of the levels: every subject, or only the academic ones (the application average, S3).
func average(academic_only := false) -> float:
	var total := 0.0
	var n := 0
	for s in subject_list():
		if academic_only and str(s.kind) != "academic":
			continue
		total += level(str(s.id))
		n += 1
	return total / maxf(1.0, n)


## One school day of grade drift.
func _drift() -> void:
	var k := 1.0 - pow(0.5, 1.0 / float(cfg().grades.half_life_days))
	for sid in subjects:
		var lv := level(sid)
		subjects[sid].level = lv + (target(sid) - lv) * k


# --- Tests -------------------------------------------------------------------------------------------------------------------

## The subjects tested on a date ([] on most days).
func tests_on(d: Dictionary) -> Array:
	if Game.athlete == null or not bool(stage_of(d).get("subjects", false)):
		return []
	if lukio_active(d):   # a lukio: the exams of the period's courses in its exam week (S3b)
		var out := []
		for uid in lukio_exams_on(d):
			out.append(str(Lukio.unit(lukio, uid).get("s", "")))
		return out
	return _schedule(SchoolCalendar.year_of(d)).get(Calendar.date_key(d), [])


## Tests in the Mon-Sun week starting `monday`.
func tests_in_week(monday: Dictionary) -> int:
	var n := 0
	for i in 7:
		n += tests_on(Game.add_days(monday, i)).size()
	return n


## A school year's test days: {date key -> [subject ids]}. Each academic subject has per_term tests a term at even points of
## the term's school days plus a roll; with an exam week in the term its last test is written in that week.
func _schedule(year: int) -> Dictionary:
	if _schedules.has(year):
		return _schedules[year]
	var out := {}
	var t: Dictionary = cfg().tests
	var y := SchoolCalendar.year_for(_town(), year)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed("tests|%d" % year)
	var exam := _exam_set(year)
	for term in ["autumn", "spring"]:
		var days := SchoolCalendar.school_days(_town(), y.terms[term][0], y.terms[term][1])
		var exam_days := days.filter(func(d): return exam.has(Calendar.date_key(d)))
		var normal := days.filter(func(d): return not exam.has(Calendar.date_key(d)))
		var skip := int(t.skip_days)
		if normal.size() <= skip:
			continue
		var per := int(t.per_term)
		for s in subject_list():
			if str(s.kind) != "academic":
				continue
			for i in per:
				var d: Dictionary
				if i == per - 1 and not exam_days.is_empty():
					d = exam_days[rng.randi_range(0, exam_days.size() - 1)]
				else:
					var pos := skip + (normal.size() - skip) * (i + 0.5) / per + rng.randfn(0.0, float(t.jitter_sd))
					d = normal[clampi(roundi(pos), skip, normal.size() - 1)]
				var key := Calendar.date_key(d)
				if not out.has(key):
					out[key] = []
				out[key].append(str(s.id))
	_schedules[year] = out
	return out


## The test's score: level + a roll - stress, kept inside 4..10, rounded to round_to.
func _write_test(sid: String, d: Dictionary) -> float:
	var t: Dictionary = cfg().tests
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed("test|%s|%d" % [sid, Calendar.date_key(d)])
	var score := level(sid) + rng.randfn(0.0, float(t.noise_sd))
	if not neutral:   # the answer to this week's meet-and-tests decision (S2): less study time, lower tests
		score -= float(option_of(choice_of(Calendar.monday_of(d))).get("test_penalty", 0.0))
	var mind := MindSystem.sys()
	if mind != null and not neutral:
		var st := mind.value("stress")
		if st > float(t.stress_from):
			score -= (st - float(t.stress_from)) / (100.0 - float(t.stress_from)) * float(t.stress_penalty)
	var step := float(t.round_to)
	return clampf(roundf(score / step) * step, float(cfg().grades.min), float(cfg().grades.max))


## How a score is written on a test in Finland: 8, 8+, 8½, 9-.
static func score_text(score: float) -> String:
	var whole := floori(score + 0.001)
	var rest := score - whole
	if rest < 0.125:
		return str(whole)
	if rest < 0.375:
		return "%d+" % whole
	if rest < 0.625:
		return "%d½" % whole
	return "%d-" % (whole + 1)


# --- Report cards ----------------------------------------------------------------------------------------------------------

## The report card: academic subjects from the term's tests and the level, practical subjects from the level; whole grades.
func _report(d: Dictionary, kind: String) -> Dictionary:
	var grades := {}
	var total := 0.0
	var academic := 0.0
	var n_ac := 0
	for s in subject_list():
		var sid := str(s.id)
		var g := card_grade(sid)
		grades[sid] = g
		total += g
		if str(s.kind) == "academic":
			academic += g
			n_ac += 1
	var stage := stage_of(d)
	return {"date": d.duplicate(), "kind": kind, "stage": str(stage.id), "year": SchoolCalendar.year_of(d), "grades": grades,
			"average": total / maxf(1.0, subject_list().size()), "academic_average": academic / maxf(1.0, n_ac)}


func report_cards() -> Array:
	return reports


func latest_report() -> Dictionary:
	return {} if reports.is_empty() else reports.back()


# --- The settings ----------------------------------------------------------------------------------------------------------

func set_effort(value: String) -> bool:
	if not value in EFFORTS:
		return false
	effort = value
	return true


func set_free_time(value: String) -> bool:
	if not value in FREE_TIMES:
		return false
	free_time = value
	return true


## The focus subjects (at most grades.focus_max; unknown ids dropped).
func set_focus(ids: Array) -> void:
	focus = []
	for sid in ids:
		if subjects.has(str(sid)) and not str(sid) in focus and focus.size() < int(cfg().grades.focus_max):
			focus.append(str(sid))


# --- The day loop ------------------------------------------------------------------------------------------------------------

func on_day_start(ctx: Dictionary) -> void:
	if not model_enabled:
		return
	_ensure_started()
	_application_day(ctx.date)
	_lukio_day_start(ctx.date)   # S3b: lukio starts, the period's courses, the matriculation exams (nothing before a lukio)
	if decisions_enabled and not neutral:
		_ask_meet_test(ctx.date)


func on_day_end(ctx: Dictionary) -> void:
	if not model_enabled or Game.athlete == null:
		return
	_ensure_started()
	var d: Dictionary = ctx.date
	var info := SchoolCalendar.day(_town(), d)
	var stage := stage_of(d)
	if bool(stage.get("applies", false)):   # the last day of the window: the list is closed (S3a)
		var ay := SchoolCalendar.year_of(d) + 1
		if Calendar.date_key(d) == Calendar.date_key(SchoolApplication.dates(ay).close):
			_lock_list(ay)
	var written := []
	var in_lukio := lukio_active(d)
	if info.kind == "school" and bool(stage.get("subjects", false)):
		_drift()
		if in_lukio:   # the exams of the period's courses (S3b)
			written = _write_lukio_exams(d)
		else:
			for sid in tests_on(d):
				var score := _write_test(sid, d)
				if not term_tests.has(sid):
					term_tests[sid] = []
				term_tests[sid].append(score)
				tests_log.append({"date": d.duplicate(), "subject": sid, "score": score})
				written.append(sid)
		while tests_log.size() > KEEP_TESTS:
			tests_log.pop_front()
	if in_lukio:
		_lukio_day_end(d)
	_matric_day_end(d)
	if bool(stage.get("subjects", false)):
		var y := SchoolCalendar.year_for(_town(), SchoolCalendar.year_of(d))
		var key := Calendar.date_key(d)
		var kind := ""
		if key == Calendar.date_key(y.christmas_card) and not in_lukio:   # (a lukio has no Christmas card: its periods have results, S3b)
			kind = "christmas"
		elif key == int(y.end_key):
			kind = "final" if bool(stage.get("final", false)) else ("" if in_lukio else "spring")
		if kind != "":
			reports.append(_report(d, kind))
			term_tests = {}
			if decisions_enabled:
				_post_card(reports.size() - 1)
			if in_lukio and kind == "final":   # the lukio's courses are over: the matriculation certificate, when the exams are passed (S3b)
				lukio.done = true
				_check_certificate()
	# The day log (the Report tab, S2): the kind of day, the life load and the tests (not when neutral: the log stays as it was).
	if not neutral:
		var extra: Dictionary = ctx.get("log_extra", {})
		extra["school"] = info.kind if info["break"] == "" or info.kind == "weekend" else str(info["break"])
		var rec: Dictionary = ctx.get("record", {})
		var life := life_load(d, rec.get("sessions", []))
		if life != 0.0:
			extra["life"] = life
		if not written.is_empty():
			extra["tests"] = written
		if not _matric_log.is_empty():   # S3b: the matriculation exams of the day ({exam, absent})
			extra["matric"] = _matric_log.duplicate(true)
		ctx.log_extra = extra


# --- Decisions and the report card (session S2; only with decisions_enabled, i.e. in the real game) ---------------------------

## One option of the meet-and-tests decision ({} for "" or an unknown id).
static func option_of(option_id: String) -> Dictionary:
	if option_id == "":
		return {}
	for o in Data.school_life.decisions.meet_test.options:
		if str(o.id) == option_id:
			return o
	return {}


## The answer given for the week starting `monday` ("" = none was asked).
func choice_of(monday: Dictionary) -> String:
	return str(week_choices.get(str(Calendar.date_key(monday)), ""))


## A race you entered in today's week that clashes with tests (data decisions.meet_test: a busy test week with at least
## min_left_busy tests left up to the race day, or a test on the race day or the day before it): {meet, day, left, list}
## (list = "Maths on Tue" lines) or {}. Nothing when this week was already answered.
func meet_test_clash(today: Dictionary) -> Dictionary:
	var c: Dictionary = cfg().decisions.meet_test
	var monday := Calendar.monday_of(today)
	if choice_of(monday) != "":
		return {}
	var di := Calendar.days_between(monday, today)
	var races := Calendar.races_in_week(Game.entries, monday)
	var days := races.keys()
	days.sort()
	for rd in days:
		if int(rd) < di:
			continue
		var list := []
		var left := 0
		for i in range(di, int(rd) + 1):
			for sid in tests_on(Game.add_days(monday, i)):
				left += 1
				list.append("%s on %s" % [subject_name(str(sid)), Training.DAY_NAMES[i]])
		var on_day: bool = bool(c.test_on_race_day) and not tests_on(Game.add_days(monday, int(rd))).is_empty()
		var before: bool = bool(c.test_day_before) and int(rd) - 1 >= di and not tests_on(Game.add_days(monday, int(rd) - 1)).is_empty()
		var busy: bool = tests_in_week(monday) > int(cfg().tests.normal_per_week) and left >= int(c.min_left_busy)
		var matric := false   # a matriculation exam still to write up to the race day always asks (S3b)
		for i in range(di, int(rd) + 1):
			for ex in matric_on(Game.add_days(monday, i)):
				matric = true
				left += 1
				list.append("%s on %s" % [Matriculation.exam_name(str(ex), lukio), Training.DAY_NAMES[i]])
		if on_day or before or busy or matric:
			return {"meet": races[rd], "day": int(rd), "left": left, "list": list}
	return {}


func _ask_meet_test(today: Dictionary) -> void:
	if not bool(stage_of(today).get("subjects", false)):
		return
	for e in Game.events:   # (one at a time)
		if str(e.source) == id and str(e.get("kind", "")) == "school_week" and e.answer == "":
			return
	var clash := meet_test_clash(today)
	if clash.is_empty():
		return
	var c: Dictionary = cfg().decisions.meet_test
	var meet: Dictionary = clash.meet
	var when := str(c.when_today) if int(clash.day) == Calendar.days_between(Calendar.monday_of(today), today) \
			else str(c.when_day).format({"day": Training.DAY_NAMES[int(clash.day)]})
	var tests_text := "1 test" if int(clash.left) == 1 else "%d tests" % int(clash.left)
	var text := str(c.text).format({"tests": tests_text, "list": ", ".join(clash.list), "meet": str(meet.name), "when": when})
	var choices := []
	for o in c.options:
		choices.append({"id": str(o.id), "label": str(o.label), "detail": str(o.detail)})
	var e := Game.post_event(id, str(c.title), text, choices, true)
	e.kind = "school_week"
	e.monday = Calendar.date_key(Calendar.monday_of(today))
	e.meet = str(meet.key)


## The report card day: a stop with the card, then the choice for the next term (the final certificate: just Continue).
func _post_card(index: int) -> void:
	var r: Dictionary = reports[index]
	var c: Dictionary = cfg().card
	var kind := str(r.kind)
	var ch: Dictionary = c.choices
	var choices := []
	if kind == "final":
		choices.append({"id": "done", "label": str(ch.done.label), "detail": str(ch.done.detail)})
	else:
		choices.append({"id": "keep", "label": str(ch.keep.label), "detail": str(ch.keep.detail).format({"effort": setting_name("effort", effort).to_lower()})})
		if effort != "heavy":
			choices.append({"id": "harder", "label": str(ch.harder.label), "detail": str(ch.harder.detail)})
		if effort != "light":
			choices.append({"id": "ease", "label": str(ch.ease.label), "detail": str(ch.ease.detail)})
	var e := Game.post_event(id, str(c.title[kind]), str(c.intro[kind]), choices, true)
	e.kind = "school_card"
	e.index = index


func on_answer(event: Dictionary, choice: String) -> void:
	match str(event.get("kind", "")):
		"school_week":
			_answer_week(event, choice)
		"school_card":
			_answer_card(choice)
		"school_apply":
			if choice == "suggest":
				set_wishes(int(event.year), SchoolApplication.suggest(self, int(event.year)))
		"school_test":
			_answer_test(event, choice)
		"school_result":
			_answer_result(event, choice)
		"lukio_choice", "lukio_courses", "lukio_results", "matric_plan", "matric_exam", "matric_results", "matric_cert":
			_answer_lukio(event, choice)   # S3b


func _answer_test(e: Dictionary, choice: String) -> void:
	var year := int(e.year)
	var i := int(e.step)
	var steps: Array = Data.application.test.steps
	var step: Dictionary = steps[i]
	var opt := choice
	var known := false
	for o in step.options:
		if str(o.id) == choice:
			known = true
	if not known:   # (a tool's "ok": the step's own sensible answer)
		opt = str(step.auto)
	_apply_step(year, str(step.id), opt)
	if i + 1 < steps.size():
		_post_test_step(year, i + 1)
	else:
		_finish_test(year)


func _answer_result(e: Dictionary, choice: String) -> void:
	var year := int(e.year)
	var place := str(e.get("wish", ""))
	match choice:
		"decline":
			var c: Dictionary = Data.application.results
			var e2 := Game.post_event(id, str(c.title), str(c.none), _fallback_choices(), true)
			e2.kind = "school_result"
			e2.year = year
			e2.wish = ""
		"general", "vocational", "grade_10":
			_decide(year, choice)
		_:
			_decide(year, place if place != "" else "general")


func _answer_week(e: Dictionary, choice: String) -> void:
	var c: Dictionary = cfg().decisions.meet_test
	var o := option_of(choice)
	if o.is_empty():   # (a tool's "ok", or an old answer: the default = race and risk it)
		o = option_of(str(c.default))
	week_choices[str(int(e.monday))] = str(o.id)
	var keys := week_choices.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	while keys.size() > 12:
		week_choices.erase(keys.pop_front())
	var meet_name := str(Calendar.get_meet(str(e.meet)).get("name", ""))
	if bool(o.scratch):
		Game.scratch_race(str(e.meet))
	var ms := MindSystem.sys()
	if ms != null and c.news.has(str(o.id)):
		ms.add("stress", float(o.stress), str(c.news[str(o.id)]))
	Game.post_event(id, str(c.title), str(o.note).format({"meet": meet_name}))   # (the line that shows in the day's events)


func _answer_card(choice: String) -> void:
	var next := ""
	match choice:
		"harder":
			next = "heavy"
		"ease":
			next = "light"
	if next != "" and next != effort and set_effort(next):
		Game.post_event(id, str(cfg().ui.row_title), str(cfg().card.changed).format({"effort": setting_name("effort", next).to_lower()}))


# --- Reading the school for the UI (session S2) ------------------------------------------------------------------------------

func subject_name(sid: String) -> String:
	for s in subject_list():
		if str(s.id) == sid:
			return str(s.name)
	return any_subject_name(sid)


## A subject's name whatever the stage (a grade 9 subject, or a lukio one such as philosophy or the new language).
func any_subject_name(sid: String) -> String:
	for s in cfg().subjects.list:
		if str(s.id) == sid:
			return str(s.name)
	if not Lukio.subject_def(sid).is_empty():
		return Lukio.subject_name(sid, lukio)
	return sid


## The name of a setting value ("Heavy"): kind = "effort" / "free_time".
static func setting_name(kind: String, value: String) -> String:
	for s in Data.school_life.settings[kind]:
		if str(s.id) == value:
			return str(s.name)
	return value


## Where a subject stands now: the level rounded to the nearest quarter grade (written 8, 8+, 8½, 9-).
func standing(sid: String) -> float:
	return roundf(level(sid) * 4.0) / 4.0


func standing_text(sid: String) -> String:
	return score_text(standing(sid))


## The latest tests of a subject, newest first: [{date, subject, score}].
func tests_of(sid: String, n := 4) -> Array:
	var out := []
	for i in range(tests_log.size() - 1, -1, -1):
		if str(tests_log[i].subject) == sid:
			out.append(tests_log[i])
			if out.size() >= n:
				break
	return out


## The average of this term's tests in a subject (-1 when there is none yet).
func term_average(sid: String) -> float:
	var t: Array = term_tests.get(sid, [])
	if t.is_empty():
		return -1.0
	var total := 0.0
	for x in t:
		total += float(x)
	return total / t.size()


## The grade on the latest report card (0 = no card yet).
func last_grade(sid: String) -> int:
	if reports.is_empty():
		return 0
	return int(reports.back().grades.get(sid, 0))


## What the report card would give in a subject now (the same rule as the card).
func card_grade(sid: String) -> int:
	if lukio_active(Game.date):   # a lukio: the average of the subject's courses (S3b), its level until one is done
		var g := Lukio.subject_grade(lukio, sid)
		if g > 0:
			return g
		return clampi(floori(level(sid) + 0.5), int(cfg().grades.min), int(cfg().grades.max))
	var v := level(sid)
	var tests: Array = term_tests.get(sid, [])
	if is_academic(sid) and not tests.is_empty():
		var w := float(cfg().report_cards.tests_weight)
		var m := 0.0
		for x in tests:
			m += float(x)
		v = w * m / tests.size() + (1.0 - w) * v
	return clampi(floori(v + 0.5), int(cfg().grades.min), int(cfg().grades.max))


## The Mon-Sun week starting `monday` as the School page tells it: {school_days, break (the break's id when the week has a day
## off in a break or the summer), tests [{day, subject}], busy, choice (the answer of the meet-and-tests decision or "")}.
func week_summary(monday: Dictionary) -> Dictionary:
	var school_days := 0
	var break_id := ""
	var tests := []
	for i in 7:
		var d := Game.add_days(monday, i)
		var info := SchoolCalendar.day(_town(), d)
		if info.kind == "school":
			school_days += 1
		elif info.kind in ["holiday", "summer"]:
			break_id = str(info["break"])
		for sid in tests_on(d):
			tests.append({"day": i, "subject": str(sid)})
	return {"school_days": school_days, "break": break_id, "tests": tests,
			"busy": tests.size() > int(cfg().tests.normal_per_week), "choice": choice_of(monday)}


## The life load of a school day with the two settings and nothing else (what the settings alone weigh).
func settings_load() -> float:
	var ll: Dictionary = cfg().life_load
	var scale := float(stage_of(Game.date).get("scale", 1.0))
	var e := float(ll.effort.get(effort, 0.0))
	var f := float(ll.free_time.get(free_time, 0.0))
	return e * (scale if e > 0.0 else 1.0) + f * (scale if f > 0.0 else 1.0)


## "lighter than usual" / "normal" / "a little heavier" / "heavy" / "very heavy".
static func life_word(load: float) -> String:
	for w in Data.school_life.ui.life_words:
		if load <= float(w.max):
			return str(w.word)
	return str(Data.school_life.ui.life_words.back().word)


## The breaks between two dates (inclusive), except the single public holidays: [{id, from, to}] by start. The summer is the
## stretch between two school years.
func breaks_between(from: Dictionary, to: Dictionary) -> Array:
	var out := []
	var lo := Calendar.date_key(from)
	var hi := Calendar.date_key(to)
	for yr in range(SchoolCalendar.year_of(from) - 1, SchoolCalendar.year_of(to) + 1):
		var y := SchoolCalendar.year_for(_town(), yr)
		var list := []
		for b in y.breaks:
			if str(b.id) != "public":
				list.append({"id": str(b.id), "from": b.from, "to": b.to})
		list.append({"id": "summer", "from": Game.add_days(y.end, 1),
				"to": Game.add_days(SchoolCalendar.year_for(_town(), yr + 1).start, -1)})
		for b in list:
			if Calendar.date_key(b.to) >= lo and Calendar.date_key(b.from) <= hi:
				out.append(b)
	out.sort_custom(func(a, b): return Calendar.date_key(a.from) < Calendar.date_key(b.from))
	return out


## The busy test weeks between two dates: [{monday, n}].
func busy_weeks(from: Dictionary, to: Dictionary) -> Array:
	var out := []
	var m := Calendar.monday_of(from)
	while Calendar.date_key(m) <= Calendar.date_key(to):
		var n := tests_in_week(m)
		if n > int(cfg().tests.normal_per_week):
			out.append({"monday": m, "n": n})
		m = Game.add_days(m, 7)
	return out


# --- The joint application and the path after grade 9 (session S3a) ----------------------------------------------------------------
# The state changes (the list is locked, the test is taken, the results decide the path) happen on their dates in every
# career, with sensible defaults; only with decisions_enabled (the real game) does the player get a stop for each of them.

## The application made in the spring of `year` ({} before it is touched).
func application(year: int) -> Dictionary:
	return applications.get(str(year), {})


func _app(year: int) -> Dictionary:
	var k := str(year)
	if not applications.has(k):
		applications[k] = {"wishes": [], "locked": false, "test": {}, "results": [], "decided": false}
	return applications[k]


## The application year the athlete is making now (the spring after this school year), 0 when the stage does not apply.
func app_year_now() -> int:
	if Game.athlete == null or not bool(stage_of(Game.date).get("applies", false)):
		return 0
	return SchoolCalendar.year_of(Game.date) + 1


## "before" (the window has not opened), "open", "locked" (closed, no results yet) or "done" (the path is decided).
func app_state(year: int) -> String:
	var A := application(year)
	if bool(A.get("decided", false)):
		return "done"
	var dt := SchoolApplication.dates(year)
	var k := Calendar.date_key(Game.date)
	if k < Calendar.date_key(dt.open):
		return "before"
	if k <= Calendar.date_key(dt.close) and not bool(A.get("locked", false)):
		return "open"
	return "locked"


func can_edit_wishes(year: int) -> bool:
	return app_state(year) == "open"


func wishes_of(year: int) -> Array:
	return application(year).get("wishes", [])


func add_wish(year: int, wish_id: String) -> bool:
	if not can_edit_wishes(year) or wish_id in wishes_of(year) or wishes_of(year).size() >= int(Data.application.window.max_wishes):
		return false
	if SchoolApplication.option(wish_id, _town()).is_empty():
		return false
	_app(year).wishes.append(wish_id)
	return true


func remove_wish(year: int, wish_id: String) -> void:
	if can_edit_wishes(year):
		_app(year).wishes.erase(wish_id)


## Moves a wish one place up (-1) or down (+1) in the list.
func move_wish(year: int, wish_id: String, step: int) -> void:
	if not can_edit_wishes(year):
		return
	var list: Array = _app(year).wishes
	var i := list.find(wish_id)
	var j := i + step
	if i < 0 or j < 0 or j >= list.size():
		return
	list[i] = list[j]
	list[j] = wish_id


func set_wishes(year: int, list: Array) -> void:
	if not can_edit_wishes(year):
		return
	var out := []
	for w in list:
		if not SchoolApplication.option(str(w), _town()).is_empty() and not str(w) in out and out.size() < int(Data.application.window.max_wishes):
			out.append(str(w))
	_app(year).wishes = out


## The application days: the window opens, the reminder, the test day, the results, and moving day.
func _application_day(d: Dictionary) -> void:
	var key := Calendar.date_key(d)
	_arrival_day(d, key)
	var stage := stage_of(d)
	if not bool(stage.get("applies", false)):
		return
	var year := SchoolCalendar.year_of(d) + 1
	var dt := SchoolApplication.dates(year)
	if key == Calendar.date_key(dt.open):
		_open_window(year)
	elif key == Calendar.date_key(dt.remind):
		if not bool(_app(year).locked) and wishes_of(year).is_empty() and decisions_enabled and not neutral:
			_post_apply(year, "remind")
	elif key == Calendar.date_key(dt.test):
		_test_day(year)
	elif key == Calendar.date_key(dt.results):
		_results(year)


func _open_window(year: int) -> void:
	_app(year)
	if decisions_enabled and not neutral:
		_post_apply(year, "open")


func _post_apply(year: int, which: String) -> void:
	var c: Dictionary = Data.application.apply
	var dt := SchoolApplication.dates(year)
	var fill := {"from": Calendar.format_day(dt.open), "to": Calendar.format_day(dt.close), "max": int(Data.application.window.max_wishes), "town": _town()}
	var second := bool(paths.size() > 0 and str(paths.back().kind) == "grade_10")
	var title := str(c.open_title if which == "open" else c.remind_title)
	var text := str(c.remind_text if which == "remind" else (c.open_text_10 if second else c.open_text)).format(fill)
	var choices := []
	for id in ["build", "suggest", "later"]:
		choices.append({"id": id, "label": str(c.choices[id].label), "detail": str(c.choices[id].detail)})
	var e := Game.post_event(id, title, text, choices, true)
	e.kind = "school_apply"
	e.year = year


## The list is closed on the last day: an empty list becomes the general lukio of the town you train in.
func _lock_list(year: int) -> void:
	var A := _app(year)
	if bool(A.locked):
		return
	A.locked = true
	var c: Dictionary = Data.application.apply
	var empty: bool = A.wishes.is_empty()
	if empty:
		A.wishes = ["general"]
	if decisions_enabled and not neutral:
		var names := []
		for w in A.wishes:
			names.append(str(SchoolApplication.option(str(w), _town()).get("name", w)))
		Game.post_event(id, str(Data.application.ui.head).capitalize(), str(c.locked_default if empty else c.locked).format({"list": ", ".join(names)}))


func _test_day(year: int) -> void:
	var A := _app(year)
	_lock_list(year)
	if not (A.test as Dictionary).is_empty():
		return
	var a := Game.athlete
	var sp := SchoolApplication.sport_points(a, year)
	var invited := []
	for w in A.wishes:
		var o := SchoolApplication.option(str(w), _town())
		if str(o.get("kind", "")) == "sports" and float(sp.total) >= SchoolApplication.invite_min(o):
			invited.append(str(w))
	var t: Dictionary = Data.application.test
	if invited.is_empty():
		A.test = {"done": true, "invited": [], "base": 0.0, "steps": {}}
		if decisions_enabled and not neutral and _has_sports_wish(A.wishes):
			Game.post_event(id, str(t.title), str(t.done_none))
		return
	A.test = {"done": false, "invited": invited, "phys": SchoolApplication.physical_points(a), "interview": SchoolApplication.interview_points(a),
			"steps": {}, "base": 0.0}
	if decisions_enabled and not neutral:
		_post_test_step(year, 0)
	else:
		for step in t.steps:
			_apply_step(year, str(step.id), str(step.auto))
		_finish_test(year)


func _has_sports_wish(wishes: Array) -> bool:
	for w in wishes:
		if str(w).begins_with("sports:"):
			return true
	return false


func _post_test_step(year: int, i: int) -> void:
	var t: Dictionary = Data.application.test
	var step: Dictionary = t.steps[i]
	var choices := []
	for o in step.options:
		choices.append({"id": str(o.id), "label": str(o.label), "detail": str(o.detail)})
	var e := Game.post_event(id, str(step.title), (str(t.intro) + "\n\n" if i == 0 else "") + str(step.text), choices, true)
	e.kind = "school_test"
	e.year = year
	e.step = i


func _apply_step(year: int, step_id: String, option_id: String) -> void:
	var A := _app(year)
	A.test.steps[step_id] = {"option": option_id, "delta": SchoolApplication.step_delta(self, year, step_id, option_id)}


func _finish_test(year: int) -> void:
	var A := _app(year)
	var base: float = float(A.test.phys) + float(A.test.interview)
	for s in A.test.steps.values():
		base += float(s.delta)
	A.test.base = clampf(base, 0.0, float(Data.application.points.school.max))
	A.test.done = true
	if decisions_enabled and not neutral:
		var t: Dictionary = Data.application.test
		Game.post_event(id, str(t.done_title), str(t.done_text).format({"date": Calendar.format_day(SchoolApplication.dates(year).results)}))


## Results day: every wish in order against its limit; the first that accepts you is your place.
func _results(year: int) -> void:
	var A := _app(year)
	if bool(A.decided):
		return
	_lock_list(year)
	if (A.test as Dictionary).is_empty() or not bool(A.test.get("done", false)):
		A.test = {}
		_test_day_auto(year)
	var rows := SchoolApplication.evaluate(self, A.wishes, year)
	A.results = rows
	var place := ""
	for r in rows:
		if str(r.status) == "yes":
			place = str(r.wish)
			break
	if not (decisions_enabled and not neutral):
		_decide(year, place if place != "" else "general")
		return
	var c: Dictionary = Data.application.results
	var lines := [str(c.intro)]
	for r in rows:
		lines.append(SchoolApplication.result_line(r))
	var choices := []
	var fill := {"town": _town(), "date": Calendar.format_day(SchoolApplication.dates(year).accept_by)}
	if place != "":
		var o := SchoolApplication.option(place, _town())
		fill.name = str(o.name)
		fill.town = str(o.town)
		lines.append(str(c.accepted).format(fill))
		choices.append({"id": "accept", "label": str(c.accept_choice.label), "detail": str(c.accept_choice.detail).format(fill)})
		choices.append({"id": "decline", "label": str(c.decline_choice.label), "detail": str(c.decline_choice.detail)})
	else:
		lines.append(str(c.none))
		choices = _fallback_choices()
	var e := Game.post_event(id, str(c.title), "\n".join(lines), choices, true)
	e.kind = "school_result"
	e.year = year
	e.wish = place


func _fallback_choices() -> Array:
	var c: Dictionary = Data.application.results
	var out := []
	for k in ["general", "vocational", "grade_10"]:
		out.append({"id": k, "label": str(c.none_choices[k].label).format({"town": _town()}), "detail": str(c.none_choices[k].detail).format({"town": _town()})})
	return out


## The test of a career that reached results day without one (a save from before, a tool): every step with its auto answer.
func _test_day_auto(year: int) -> void:
	var A := _app(year)
	var a := Game.athlete
	var sp := SchoolApplication.sport_points(a, year)
	var invited := []
	for w in A.wishes:
		var o := SchoolApplication.option(str(w), _town())
		if str(o.get("kind", "")) == "sports" and float(sp.total) >= SchoolApplication.invite_min(o):
			invited.append(str(w))
	if invited.is_empty():
		A.test = {"done": true, "invited": [], "base": 0.0, "steps": {}}
		return
	A.test = {"done": false, "invited": invited, "phys": SchoolApplication.physical_points(a), "interview": SchoolApplication.interview_points(a), "steps": {}, "base": 0.0}
	for step in Data.application.test.steps:
		_apply_step(year, str(step.id), str(step.auto))
	var base: float = float(A.test.phys) + float(A.test.interview)
	for s in A.test.steps.values():
		base += float(s.delta)
	A.test.base = clampf(base, 0.0, float(Data.application.points.school.max))
	A.test.done = true


## Puts the athlete on the path of a wish ("general" / "vocational" / "grade_10" / "sports:<id>") from the next 1 August.
func _decide(year: int, wish_id: String) -> void:
	var A := _app(year)
	A.decided = true
	var kind := ""
	var school := ""
	var wtown := _town()
	var name := ""
	if wish_id == "grade_10":
		kind = "grade_10"
		name = str(Data.school_life.stages.secondary.grade_10.name)
	else:
		var o := SchoolApplication.option(wish_id, _town())
		if o.is_empty():
			o = SchoolApplication.option("general", _town())
		kind = SchoolApplication.path_kind(o)
		school = str(o.school.get("id", ""))
		wtown = str(o.town)
		name = str(o.name)
	paths.append({"kind": kind, "school": school, "town": wtown, "start_year": year, "years": int(Data.school_life.stages.secondary[kind].years)})
	_stage_cache = {}
	_exam_days = {}
	_schedules = {}
	var rows: Array = A.results
	var top := not rows.is_empty() and str(rows[0].status) == "yes"
	var any := false
	for r in rows:
		if str(r.status) == "yes":
			any = true
	var c: Dictionary = Data.application.results
	var ms := MindSystem.sys()
	if ms != null and not neutral and decisions_enabled:
		if any and wish_id != "general" and wish_id != "vocational":
			ms.add("confidence", float(c.news_delta.top if top else c.news_delta.yes), str(c.news_top if top else c.news_yes).format({"name": name}))
		elif not any:
			ms.add("confidence", float(c.news_delta.no), str(c.news_no))
	if decisions_enabled:
		Game.post_event(id, str(c.title), str(c.path_message_10 if kind == "grade_10" else c.path_message).format({"name": name, "town": wtown}))


## Moving day and the first day at a new school (1 August of a path's first year).
func _arrival_day(d: Dictionary, key: int) -> void:
	if d.month != 8 or d.day != 1:
		return
	for sgm in paths:
		if int(sgm.start_year) != int(d.year) or bool(sgm.get("arrived", false)):
			continue
		sgm.arrived = true
		var new_town := str(sgm.town)
		if new_town != "" and new_town != _town():
			_move_to(new_town, str(sgm.get("school", "")))
		if decisions_enabled and not neutral:
			_post_arrival(sgm)
		if str(sgm.kind) == "urheilulukio" and decisions_enabled and CoachMarket.enabled:
			var cm := CoachMarket.sys()
			var school := _school_row(str(sgm.school))
			if cm != null and not school.is_empty():
				cm.post_academy_offer(cm.add_academy_coach(school), school)


func _school_row(school_id: String) -> Dictionary:
	for s in Data.urheilulukiot.schools:
		if str(s.id) == school_id:
			return s
	return {}


func _post_arrival(sgm: Dictionary) -> void:
	var c: Dictionary = Data.application.arrival
	var row := _school_row(str(sgm.school))
	var name := str(row.get("name", Data.application.ui.kinds.get(str(sgm.kind), "")))
	var text := ""
	match str(sgm.kind):
		"urheilulukio":
			var days := []
			for i in Data.application.morning.schools.get(str(sgm.school), Data.application.morning.default):
				days.append(str(c.morning_names[int(i)]))
			var centre := ""
			var t := Data.get_town(str(sgm.town))
			if t.has("centre") and t.centre != null:
				for x in Data.urheilulukiot.centres.list:
					if str(x.id) == str(t.centre):
						centre = str(c.centre).format({"centre": str(x.name)})
			text = str(c.urheilulukio).format({"name": name, "days": ", ".join(days), "centre": centre})
		"lukio":
			text = str(c.lukio).format({"name": name})
		"vocational":
			text = str(c.vocational).format({"name": name})
		_:
			text = str(c.grade_10)
	Game.post_event(id, str(c.title), text)


## Moves the athlete to `town` for school: the town they live and train in changes (the club stays), the old coach is now far
## away, the coaches around the new town appear in the market, the old coach and the group say goodbye.
func _move_to(town_name: String, school_id: String) -> void:
	var a := Game.athlete
	var old := CoachSystem.home_town(a)
	var cs := Game.get_system("coach") as CoachSystem
	var head: Dictionary = cs.head() if cs != null else {}
	a.training_town = town_name
	var m: Dictionary = Data.application.moving
	if decisions_enabled and not neutral:
		var row := _school_row(school_id)
		var text := str(m.text_dorm if school_id in m.dorm else m.text_flat).format({"town": town_name, "school": str(row.get("name", "")), "old": old})
		Game.post_event(id, str(m.title).format({"town": town_name}), text)
		var ms := Game.get_system("moments") as StoryletSystem
		var cm := CoachMarket.sys()
		if ms != null and cm != null and not head.is_empty():
			ms.say("coach", str(head.id), cm.line(head, "farewell", {"new": town_name}))
			var mates := ms.people_for("teammate")
			if not mates.is_empty():
				var rng := RandomNumberGenerator.new()
				rng.seed = _seed("goodbye|" + town_name)
				ms.say("group", str(mates[rng.randi_range(0, mates.size() - 1)].id), str(m.group_goodbye).format({"town": town_name}))
	var market := CoachMarket.sys()
	if market != null and CoachMarket.enabled:
		market.refresh_for_move()


# --- Lukio: courses and periods (session S3b) ---------------------------------------------------------------------------------
# A lukio starts on the first day of its stage (1 August of its first year): the subjects move to the lukio's (lukio grades run
# lower, new subjects such as philosophy start from their relatives), the counsellor's choices (maths, an extra language,
# 3 or 4 years) and the plan of courses are made. With decisions_enabled (the real game) the choices are stops on the first
# school day, and every period starts with a stop for its courses and ends with a stop for its results (user 2026-10-17);
# every tool gets the counsellor's defaults and never a stop. Grades 8-9 and a 10th-grade year never run any of this.

## True on a date in a lukio stage once its lukio has started.
func lukio_active(d: Dictionary) -> bool:
	if lukio.is_empty() or Game.athlete == null:
		return false
	var st := stage_of(d)
	if str(st.get("kind", "")) != "lukio":
		return false
	return int(SchoolCalendar.year_of(d)) - int(st.get("year_index", 0)) == int(lukio.start_year)


## The lukio segment of a date's stage ({} when the stage is not a lukio).
func _lukio_seg(d: Dictionary) -> Dictionary:
	if str(stage_of(d).get("kind", "")) != "lukio":
		return {}
	return segment_for(SchoolCalendar.year_of(d))


## The course exams written on a date: [course ids].
func lukio_exams_on(d: Dictionary) -> Array:
	var per := Lukio.period_at(self, lukio, d)
	if per.is_empty():
		return []
	return _exams_of(int(per.p)).get(Calendar.date_key(d), [])


func _exams_of(p: int) -> Dictionary:
	if not _lukio_exams.has(p):
		_lukio_exams[p] = Lukio.exam_schedule(self, lukio, p)
	return _lukio_exams[p]


func _lukio_changed() -> void:
	_lukio_exams = {}


func _lukio_day_start(d: Dictionary) -> void:
	var seg := _lukio_seg(d)
	if not seg.is_empty() and (lukio.is_empty() or int(lukio.start_year) != int(seg.start_year)):
		_start_lukio(seg, d)
	if lukio_active(d):
		var per := Lukio.period_at(self, lukio, d)
		if not per.is_empty() and decisions_enabled and not neutral:
			var first := _first_school_day(per.start, per.end)
			if Calendar.date_key(d) >= Calendar.date_key(first) and bool(lukio.chosen) and not lukio.asked.has("c%d" % int(per.p)) \
					and (per.exam.is_empty() or Calendar.date_key(d) < Calendar.date_key(per.exam[0])):
				_post_courses(int(per.p))
			if not bool(lukio.chosen) and not lukio.asked.has("choice") and Calendar.date_key(d) >= Calendar.date_key(first):
				lukio.asked["choice"] = true
				_post_choice("maths")
	if not lukio.is_empty():
		_matric_day_start(d)


func _first_school_day(from: Dictionary, to: Dictionary) -> Dictionary:
	var d := from
	while Calendar.date_key(d) <= Calendar.date_key(to):
		if SchoolCalendar.is_school_day(_town(), d):
			return d
		d = Game.add_days(d, 1)
	return from


## The lukio begins: the subjects, the counsellor's choices and plan, the matriculation plan. A lukio that starts in the middle
## of a year (a save or a tool) has its earlier periods done, graded by the levels.
func _start_lukio(seg: Dictionary, d: Dictionary) -> void:
	var lv: Dictionary = Data.lukio.levels
	var pick_long := level("maths") >= float(Data.lukio.plan.long_maths_from)
	lukio = {"start_year": int(seg.start_year), "school": str(seg.get("school", "")), "sports": str(seg.kind) == "urheilulukio",
			"maths": "long" if pick_long else "short", "b3": "none", "years": int(seg.years),
			"music_art": "music" if level("music") >= level("art") else "art", "chosen": not (decisions_enabled and not neutral),
			"shifted": false, "maths_shifted": false, "units": [], "asked": {}, "done": false,
			"matric": {"plan": {}, "locked": [], "registered": {}, "sat": {}, "results": [], "cert": false}}
	# The subjects: lukio grades run lower; the new subjects start from their relatives (with a roll of their own).
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed("lukio_subjects|%d" % int(seg.start_year))
	for s in Lukio.cfg().subjects.list:
		var sid := str(s.id)
		if str(s.kind) == "pass" or sid == "b3":
			continue
		_lukio_subject(sid, s, rng)
	lukio.shifted = true
	if lukio.maths == "long":
		_shift_subject("maths", float(lv.long_maths_shift))
		lukio.maths_shifted = true
	_lukio_seed_matric()
	_replan(0)
	_stage_cache = {}
	# Started after its first school day: the periods before today are done (graded by the levels, no exams).
	var per := Lukio.period_at(self, lukio, d)
	if not per.is_empty():
		var upto := int(per.p) - 1
		if not per.exam.is_empty() and Calendar.date_key(d) > Calendar.date_key(per.exam.back()):
			upto = int(per.p)
		for p in range(0, upto + 1):
			_finish_period(p, false)
		if int(per.p) > 0:
			lukio.asked["choice"] = true
			lukio.chosen = true


func _lukio_subject(sid: String, s: Dictionary, rng: RandomNumberGenerator) -> void:
	var lv: Dictionary = Data.lukio.levels
	var shift := float(lv.lukio_shift) + float(s.get("shift", 0.0))
	if subjects.has(sid):
		_shift_subject(sid, shift)
		return
	var from: Array = s.get("from", [])
	var lvl := 0.0
	var nat := 0.0
	for f in from:
		lvl += level(str(f))
		nat += float(subjects.get(str(f), {}).get("natural", level(str(f))))
	var n := maxi(1, from.size())
	var roll := rng.randfn(0.0, float(lv.new_subject_sd))
	var lo := float(cfg().grades.min)
	var hi := float(cfg().grades.max)
	subjects[sid] = {"natural": clampf(nat / n + shift + roll, lo, hi), "level": clampf(lvl / n + shift + roll, lo, hi)}


## A moment's `grades` effect (session P1): every academic subject's level moves by `points` x data/cast.json
## grades.grades_per_point; the natural level stays, so the drift takes it back over the weeks (studying for a test helps
## that test). Nothing with the model off or neutral. Returns the change per subject.
func nudge_grades(points: float) -> float:
	if not model_enabled or neutral:
		return 0.0
	_ensure_started()
	var shift := points * float(Data.cast.grades.grades_per_point)
	var lo := float(cfg().grades.min)
	var hi := float(cfg().grades.max)
	for s in subject_list():
		var sid := str(s.id)
		if is_academic(sid) and subjects.has(sid):
			subjects[sid].level = clampf(float(subjects[sid].level) + shift, lo, hi)
	return shift


func _shift_subject(sid: String, shift: float) -> void:
	if not subjects.has(sid):
		return
	var lo := float(cfg().grades.min)
	var hi := float(cfg().grades.max)
	subjects[sid].natural = clampf(float(subjects[sid].natural) + shift, lo, hi)
	subjects[sid].level = clampf(float(subjects[sid].level) + shift, lo, hi)


func _lukio_seed_matric() -> void:
	var plan := Matriculation.suggest(self, lukio)
	lukio.matric.plan = {}
	for ex in plan:
		if ex in Matriculation.available(lukio):
			lukio.matric.plan[ex] = plan[ex]


## The counsellor puts the courses from period `from_p` on into the plan again (after a choice or a change).
func _replan(from_p: int) -> void:
	Lukio.ensure_units(self, lukio)
	Lukio.fill_optional(self, lukio, from_p)
	Lukio.spread(self, lukio, from_p)
	_lukio_changed()


## The period whose courses can be changed now: the current one before its first exam (-1 = none).
func editable_period() -> int:
	if not lukio_active(Game.date):
		return -1
	var per := Lukio.period_at(self, lukio, Game.date)
	if per.is_empty():
		return -1
	if not per.exam.is_empty() and Calendar.date_key(Game.date) >= Calendar.date_key(per.exam[0]):
		return -1
	return int(per.p)


# --- The player's changes to a period's courses (the courses stop) ---

func course_later(uid: String) -> bool:
	var p := editable_period()
	var u := Lukio.unit(lukio, uid)
	if p < 0 or u.is_empty() or int(u.p) != p or str(u.st) != "plan" or p + 1 >= Lukio.period_count(lukio):
		return false
	u.p = p + 1
	_after_edit(p)
	return true


func course_add(uid: String) -> bool:
	var p := editable_period()
	var u := Lukio.unit(lukio, uid)
	if p < 0 or u.is_empty() or str(u.k) != "opt" or str(u.st) == "done" or (str(u.st) == "plan" and int(u.p) <= p):
		return false
	u.st = "plan"
	u.p = p
	u.by = "player"
	_after_edit(p)
	return true


## Drops an optional course of the period (back to the pool, never added again by the counsellor) or, in a sports lukio, leaves
## out a compulsory one by the rule.
func course_drop(uid: String) -> bool:
	var p := editable_period()
	var u := Lukio.unit(lukio, uid)
	if p < 0 or u.is_empty() or int(u.p) != p or str(u.st) != "plan":
		return false
	if str(u.k) == "opt":
		u.st = "pool"
		u.by = "player_out"
	elif Lukio.can_drop_comp(lukio, u):
		u.st = "drop"
		u.by = "player"
	else:
		return false
	u.p = -1
	_after_edit(p)
	return true


func course_put_back(uid: String) -> bool:
	var p := editable_period()
	var u := Lukio.unit(lukio, uid)
	if p < 0 or u.is_empty() or str(u.st) != "drop":
		return false
	u.st = "plan"
	u.p = p
	u.by = "player"
	_after_edit(p)
	return true


func _after_edit(p: int) -> void:
	Lukio.fill_optional(self, lukio, p + 1)
	Lukio.spread(self, lukio, p + 1)
	_lukio_changed()


## Optional courses that can be added to the period: the next one of each subject that is not done or already in it.
func add_candidates(p: int) -> Array:
	var out := []
	var seen := {}
	var list := (lukio.units as Array).duplicate()
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

func can_change_years() -> bool:
	if not lukio_active(Game.date):
		return false
	return SchoolCalendar.year_of(Game.date) - int(lukio.start_year) < 2


## 3 or 4 years (user: every lukio; until the third year starts): the path's length changes and the rest of the plan is
## spread again.
func set_lukio_years(n: int) -> bool:
	var allowed := (Data.lukio.rules.years_allowed as Array).map(func(x): return int(x))
	if not can_change_years() or not n in allowed or n == int(lukio.years):
		return false
	_set_years(n)
	_replan(_replan_from())
	return true


## The first period the counsellor may plan again: the current one while its courses can change, else the next (in the summer
## between two school years: the next year's first).
func _replan_from() -> int:
	var per := Lukio.period_at(self, lukio, Game.date)
	if per.is_empty():
		var yi := SchoolCalendar.year_of(Game.date) - int(lukio.start_year)
		if Game.date.month >= 6 and Game.date.month < 8:
			yi += 1
		return clampi(yi * Lukio.per_year(), 0, Lukio.period_count(lukio) - 1)
	return int(per.p) + (0 if editable_period() >= 0 else 1)


func _set_years(n: int) -> void:
	var found := false
	for sgm in paths:
		if int(sgm.start_year) == int(lukio.start_year) and str(sgm.kind) in ["lukio", "urheilulukio"]:
			sgm.years = n
			found = true
	if not found:   # the default path (no list was made): stored now, with its new length
		var seg := segment_for(int(lukio.start_year))
		paths.append({"kind": str(seg.get("kind", "lukio")), "school": str(seg.get("school", "")), "town": str(seg.get("town", _town())),
				"start_year": int(lukio.start_year), "years": n, "arrived": true, "default": true})
	lukio.years = n
	_stage_cache = {}
	_exam_days = {}
	_schedules = {}
	Lukio.clear_cache()
	# The exam plan follows the sessions of the new length (an exam already registered or written keeps its session): the
	# counsellor's suggestion for every exam that is not fixed yet.
	matric_fill_suggestion()


func can_short_maths() -> bool:
	if lukio.is_empty() or str(lukio.maths) != "long" or not lukio_active(Game.date):
		return false
	for k in lukio.matric.locked:
		if "maths" in lukio.matric.registered.get(str(k), []):
			return false
	return true


## Long maths -> short (real schools allow it; the long courses done count towards the short syllabus).
func to_short_maths() -> bool:
	if not can_short_maths():
		return false
	var done := []
	for u in lukio.units:
		if str(u.s) == "maths" and str(u.st) == "done" and int(u.n) > 1:
			done.append(u)
	done.sort_custom(func(a, b): return int(a.n) < int(b.n))
	lukio.units = (lukio.units as Array).filter(func(u): return not (str(u.s) == "maths" and int(u.n) > 1))
	lukio.maths = "short"
	if bool(lukio.maths_shifted):
		_shift_subject("maths", -float(Data.lukio.levels.long_maths_shift))
		lukio.maths_shifted = false
	var max_n := Lukio.comp_count("maths", lukio) + Lukio.opt_count("maths", lukio)
	for i in done.size():
		var n := 2 + i
		if n > max_n:
			break
		lukio.units.append({"id": Lukio._unit_id("maths", n, lukio), "s": "maths", "n": n, "k": "comp" if n <= Lukio.comp_count("maths", lukio) else "opt",
				"p": int(done[i].p), "st": "done", "g": int(done[i].g), "x": float(done[i].x), "by": "", "r": false})
	_replan(_replan_from())
	return true


# --- The stops of the lukio ---

func _post_choice(step: String) -> void:
	var c: Dictionary = Data.lukio.stops
	var choices := []
	var text := ""
	var pick := ""
	match step:
		"maths":
			text = str(c.maths_text)
			for k in ["long", "short"]:
				choices.append({"id": k, "label": str(c.maths_options[k].label), "detail": str(c.maths_options[k].detail)})
			pick = str(c.maths_options[str(lukio.maths)].label)
		"language":
			text = str(c.language_text)
			for l in Data.lukio.subjects.languages:
				choices.append({"id": str(l.id), "label": str(l.name), "detail": str(l.text)})
			pick = Lukio.language_name("none")
		"years":
			text = str(c.years_text)
			for k in ["3", "4"]:
				choices.append({"id": k, "label": str(c.years_options[k].label), "detail": str(c.years_options[k].detail)})
			pick = str(c.years_options[str(int(lukio.years))].label)
	text += "\n\n" + str(c.counsellor_pick).format({"pick": pick})
	var e := Game.post_event(id, str(c.choices_title), text, choices, true)
	e.kind = "lukio_choice"
	e.step = step


func _post_courses(p: int) -> void:
	lukio.asked["c%d" % p] = true
	var per := Lukio.period_info(self, lukio, p)
	var c: Dictionary = Data.lukio.stops
	var fill := {"n": int(per.i) + 1, "year": int(per.year_index) + 1, "from": Calendar.format_day(per.start), "to": Calendar.format_day(per.end)}
	var e := Game.post_event(id, str(c.courses_title).format(fill), str(c.courses_text).format(fill),
			[{"id": "done", "label": str(c.courses_done.label), "detail": ""}], true)
	e.kind = "lukio_courses"
	e.period = p


func _answer_lukio(e: Dictionary, choice: String) -> void:
	match str(e.kind):
		"lukio_choice":
			_answer_choice(str(e.step), choice)
		"matric_exam":
			var key := "%s|%s" % [str(e.session), str(e.exam)]
			var sat: Dictionary = lukio.matric.sat
			if not sat.has(key):
				sat[key] = {"parts": [], "absent": false}
			if choice == "skip":
				sat[key].absent = true
			elif str(e.get("meet", "")) != "":   # sitting the exam: the race of the same day is withdrawn
				Game.scratch_race(str(e.meet))
		_:
			pass   # (courses: the changes were made in the panel; results, plan, certificate: read and continue)


func _answer_choice(step: String, choice: String) -> void:
	match step:
		"maths":
			if choice in ["long", "short"] and choice != str(lukio.maths):
				var shift := float(Data.lukio.levels.long_maths_shift)
				lukio.maths = choice
				if choice == "long" and not bool(lukio.maths_shifted):
					_shift_subject("maths", shift)
					lukio.maths_shifted = true
				elif choice == "short" and bool(lukio.maths_shifted):
					_shift_subject("maths", -shift)
					lukio.maths_shifted = false
			_post_choice("language")
		"language":
			var known := false
			for l in Data.lukio.subjects.languages:
				known = known or str(l.id) == choice
			if known and choice != "none":
				lukio.b3 = choice
				var rng := RandomNumberGenerator.new()
				rng.seed = _seed("lukio_b3|%s" % choice)
				_lukio_subject("b3", Lukio.subject_def("b3"), rng)
			_post_choice("years")
		"years":
			if choice in ["3", "4"] and int(choice) != int(lukio.years):
				_set_years(int(choice))
			lukio.chosen = true
			_replan(_replan_from())
			var per := Lukio.period_at(self, lukio, Game.date)
			if not per.is_empty() and not lukio.asked.has("c%d" % int(per.p)):
				_post_courses(int(per.p))


# --- The exams of the period and its results ---

## Writes the course exams of the day: [subject ids written].
func _write_lukio_exams(d: Dictionary) -> Array:
	var written := []
	for uid in lukio_exams_on(d):
		var u := Lukio.unit(lukio, uid)
		if u.is_empty() or str(u.st) != "plan":
			continue
		var sid := str(u.s)
		var t: Dictionary = cfg().tests
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed("course|%s|%d" % [uid, Calendar.date_key(d)])
		var score := level(sid) + rng.randfn(0.0, float(t.noise_sd)) - _week_and_stress_penalty(d, float(t.stress_from), float(t.stress_penalty))
		var step := float(t.round_to)
		score = clampf(roundf(score / step) * step, float(cfg().grades.min), float(cfg().grades.max))
		u.x = score
		tests_log.append({"date": d.duplicate(), "subject": sid, "score": score})
		written.append(sid)
	return written


## The meet-and-tests answer of the week and today's stress, as grade points off an exam (0 when neutral).
func _week_and_stress_penalty(d: Dictionary, stress_from: float, stress_penalty: float) -> float:
	if neutral:
		return 0.0
	var off := float(option_of(choice_of(Calendar.monday_of(d))).get("test_penalty", 0.0))
	var mind := MindSystem.sys()
	if mind != null:
		var st := mind.value("stress")
		if st > stress_from:
			off += (st - stress_from) / (100.0 - stress_from) * stress_penalty
	return off


func _lukio_day_end(d: Dictionary) -> void:
	var per := Lukio.period_at(self, lukio, d)
	if per.is_empty():
		return
	var last: Dictionary = per.exam.back() if not per.exam.is_empty() else per.end
	if Calendar.date_key(d) == Calendar.date_key(last):
		_finish_period(int(per.p), decisions_enabled and not neutral)


## The end of a period: every course of it graded (a failed course goes to the next period's exam week once), its results kept
## as a report and, in the real game, shown in a stop.
func _finish_period(p: int, stop: bool) -> void:
	if lukio.asked.has("r%d" % p):
		return
	lukio.asked["r%d" % p] = true
	var w := float(Data.lukio.courses.exam_weight)
	var graded := []
	var retakes := []
	for u in Lukio.courses_in(lukio, p):
		if str(u.st) != "plan":
			continue
		var kind := Lukio.kind_of(str(u.s))
		var g := -1
		if str(u.k) != "coach" and kind != "pass":
			var lv := level(str(u.s))
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
		if g == 4 and kind == "academic" and bool(Data.lukio.courses.retake) and not u.has("retaken") and p + 1 < Lukio.period_count(lukio):
			u.st = "plan"
			u.p = p + 1
			u.r = true
			u.retaken = true
			u.x = -1.0
			retakes.append(u)
	_lukio_changed()
	reports.append(_period_report(p, graded))
	if stop:
		var per := Lukio.period_info(self, lukio, p)
		var c: Dictionary = Data.lukio.stops
		var fill := {"n": int(per.i) + 1}
		var e := Game.post_event(id, str(c.results_title).format(fill), str(c.results_text).format(fill),
				[{"id": "continue", "label": str(c.results_continue.label), "detail": ""}], true)
		e.kind = "lukio_results"
		e.period = p
		e.index = reports.size() - 1


func _period_report(p: int, graded: Array) -> Dictionary:
	var per := Lukio.period_info(self, lukio, p)
	var grades := {}
	var total := 0.0
	var n := 0
	var ac := 0.0
	var n_ac := 0
	for s in Lukio.subject_defs(lukio):
		var sid := str(s.id)
		if str(s.kind) == "pass":
			continue
		var g := Lukio.subject_grade(lukio, sid)
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
	return {"date": Game.date.duplicate(), "kind": "period", "label": label, "stage": str(stage_of(per.end).id), "year": int(per.year),
			"grades": grades, "average": total / maxf(1.0, n), "academic_average": ac / maxf(1.0, n_ac), "period": p, "courses": courses}


func _lukio_load_parts(d: Dictionary, scale: float) -> Array:
	var out := []
	var per := Lukio.period_at(self, lukio, d)
	if not per.is_empty() and not is_exam_day(d):
		var n := 0
		for u in Lukio.courses_in(lukio, int(per.p)):
			if Lukio.is_classroom(u) and not bool(u.r):
				n += 1
		var v := float(n - int(Data.lukio.plan.normal_courses)) * float(Data.lukio.plan.load_per_course)
		if v != 0.0:
			out.append({"id": "courses" if v > 0.0 else "courses_light", "value": v * (scale if v > 0.0 else 1.0), "n": n})
	if not matric_on(d).is_empty():
		out.append({"id": "matric", "value": float(Data.lukio.matric.life_load) * scale})
	return out


# --- The matriculation exams (session S3b) -----------------------------------------------------------------------------------

## The three sessions for the required exams: from the first session the athlete registered for, else the lukio's last three.
func matric_main_sessions() -> Array:
	if lukio.is_empty():
		return []
	var locked: Array = lukio.matric.locked
	if locked.is_empty():
		return Matriculation.sessions_for(int(lukio.start_year), int(lukio.years))
	var first := str(locked[0])
	for k in locked:
		if Lukio._session_rank(str(k)) < Lukio._session_rank(first):
			first = str(k)
	return [first, Matriculation.next_key(first), Matriculation.next_key(Matriculation.next_key(first))]


## Every session the plan can use: the main three and, for retakes and better grades, the next three after them.
func matric_sessions() -> Array:
	var out := matric_main_sessions()
	if out.is_empty():
		return out
	var k := str(out.back())
	for i in int(Data.lukio.matric.retakes):
		k = Matriculation.next_key(k)
		out.append(k)
	return out


## Sessions the plan can still change: not locked, before the deadline.
func matric_open(key: String) -> bool:
	return not key in lukio.matric.locked and Calendar.date_key(Game.date) <= Calendar.date_key(Matriculation.deadline(key))


## Whether an exam may go into a session: open; a new exam only in the main three; a retake of a failed exam in the next three
## after the failure; a passed one any time; one realia subject a day.
func matric_allowed(exam_id: String, key: String) -> bool:
	if lukio.is_empty() or not matric_open(key) or not exam_id in Matriculation.available(lukio):
		return false
	var main := matric_main_sessions()
	var tried := false
	for r in lukio.matric.results:
		if str(r.exam) == exam_id:
			tried = true
	if not tried and not key in main:
		return false
	if not key in matric_sessions():
		return false
	var days: Array = Matriculation.exam(exam_id).get("days", [])
	for ex in lukio.matric.plan:
		if str(ex) != exam_id and str(lukio.matric.plan[ex]) == key:
			var od: Array = Matriculation.exam(str(ex)).get("days", [])
			if not days.is_empty() and not od.is_empty() and str(days[0]) == str(od[0]):
				return false
	return true


## Puts an exam into a session ("" = out of the plan). False when the rules don't allow it.
func set_matric(exam_id: String, key: String) -> bool:
	var plan: Dictionary = lukio.matric.plan
	if plan.has(exam_id) and not matric_open(str(plan[exam_id])):
		return false
	if key == "":
		plan.erase(exam_id)
		return true
	if not matric_allowed(exam_id, key):
		return false
	plan[exam_id] = key
	return true


## The counsellor's plan again for every exam that is not fixed yet.
func matric_fill_suggestion() -> void:
	var plan: Dictionary = lukio.matric.plan
	for ex in plan.keys():
		if matric_open(str(plan[ex])):
			plan.erase(ex)
	var sug := Matriculation.suggest(self, lukio)
	var main := matric_main_sessions()
	for ex in sug:
		if plan.has(ex) or _passed(str(ex)):
			continue
		var k := str(sug[ex])
		if not matric_open(k):   # (the suggested session is past: the next open main one)
			k = ""
			for m in main:
				if matric_open(str(m)):
					k = str(m)
					break
		if k != "" and matric_allowed(str(ex), k):
			plan[ex] = k


func _passed(exam_id: String) -> bool:
	for r in lukio.matric.results:
		if str(r.exam) == exam_id and Matriculation.passed(str(r.grade)):
			return true
	return false


## The best result of each exam: {exam id: grade}.
func matric_best() -> Dictionary:
	var out := {}
	for r in lukio.matric.results:
		var ex := str(r.exam)
		if not out.has(ex) or Matriculation.points(str(r.grade)) > Matriculation.points(str(out[ex])):
			out[ex] = str(r.grade)
	return out


## The exams of the plan and the passed ones together (what the rules are checked against).
func matric_set() -> Array:
	var out := []
	for ex in lukio.matric.plan:
		out.append(str(ex))
	var best := matric_best()
	for ex in best:
		if Matriculation.passed(str(best[ex])) and not str(ex) in out:
			out.append(str(ex))
	return out


## The matriculation exams written on a date: [exam ids] (registered ones, or the plan's before the deadline; not skipped).
func matric_on(d: Dictionary) -> Array:
	if lukio.is_empty():
		return []
	var out := []
	var key := Calendar.date_key(d)
	for k in _sessions_near(d):
		var list: Array = lukio.matric.registered.get(k, []) if k in lukio.matric.locked else _plan_in(k)
		for ex in list:
			if bool(lukio.matric.sat.get("%s|%s" % [k, str(ex)], {}).get("absent", false)):
				continue
			for dd in Matriculation.exam_dates(k, str(ex)):
				if Calendar.date_key(dd) == key:
					out.append(str(ex))
	return out


## The session whose exams could fall near a date (the spring one in March - April, the autumn one in September).
func _sessions_near(d: Dictionary) -> Array:
	var m := int(d.month)
	if m == 3 or m == 4:
		return [Matriculation.key_for("spring", int(d.year))]
	if m == 9 or m == 10:
		return [Matriculation.key_for("autumn", int(d.year))]
	return []


func _plan_in(key: String) -> Array:
	var out := []
	for ex in lukio.matric.plan:
		if str(lukio.matric.plan[ex]) == key:
			out.append(str(ex))
	return out


func _matric_day_start(d: Dictionary) -> void:
	var key := Calendar.date_key(d)
	var stops := decisions_enabled and not neutral
	var main := matric_main_sessions()
	# The first plan: from the school year that holds the first deadline (user: one stop for the plan, then one per session).
	if stops and not main.is_empty() and lukio.matric.locked.is_empty() and not lukio.asked.has("plan"):
		var first_deadline := Matriculation.deadline(str(main[0]))
		var y := SchoolCalendar.year_for(_town(), SchoolCalendar.year_of(first_deadline))
		if key >= Calendar.date_key(_first_school_day(y.start, y.end)) and key <= Calendar.date_key(first_deadline) and bool(lukio.chosen):
			lukio.asked.plan = true
			_post_matric_plan("")
	for k in matric_sessions():
		var sk := str(k)
		# The stop to check a session's exams before its deadline.
		if stops and matric_open(sk) and not lukio.asked.has("reg" + sk) and key >= Calendar.date_key(Matriculation.stop_date(sk)) \
				and lukio.asked.has("plan") and not _plan_in(sk).is_empty():
			lukio.asked["reg" + sk] = true
			_post_matric_plan(sk)
		# The exam days.
		if sk in lukio.matric.locked:
			for ex in lukio.matric.registered.get(sk, []):
				var dates := Matriculation.exam_dates(sk, str(ex))
				for i in dates.size():
					if Calendar.date_key(dates[i]) == key and stops:
						_post_matric_exam(sk, str(ex), i, dates.size())
			if key == Calendar.date_key(Matriculation.results_date(sk)) and not lukio.asked.has("res" + sk):
				lukio.asked["res" + sk] = true
				_matric_results(sk, stops)


func _matric_day_end(d: Dictionary) -> void:
	_matric_log = []
	if lukio.is_empty():
		return
	var key := Calendar.date_key(d)
	for k in matric_sessions():
		var sk := str(k)
		# The deadline: the session's exams are registered for good.
		if key == Calendar.date_key(Matriculation.deadline(sk)) and not sk in lukio.matric.locked:
			var list := _plan_in(sk)
			if not list.is_empty():
				lukio.matric.locked.append(sk)
				lukio.matric.registered[sk] = list
				if decisions_enabled and not neutral:
					var names := []
					for ex in list:
						names.append(Matriculation.exam_name(str(ex), lukio))
					Game.post_event(id, str(Data.lukio.stops.register_title).format({"session": Matriculation.session_name(sk)}),
							", ".join(names))
		if not sk in lukio.matric.locked:
			continue
		for ex in lukio.matric.registered.get(sk, []):
			var dates := Matriculation.exam_dates(sk, str(ex))
			for i in dates.size():
				if Calendar.date_key(dates[i]) != key:
					continue
				var sat_key := "%s|%s" % [sk, str(ex)]
				var sat: Dictionary = lukio.matric.sat
				if not sat.has(sat_key):
					sat[sat_key] = {"parts": [], "absent": false}
				var entry: Dictionary = sat[sat_key]
				_matric_log.append({"exam": str(ex), "absent": bool(entry.absent)})
				if not bool(entry.absent):
					(entry.parts as Array).append(_matric_score(str(ex), i, d))


## A matriculation exam's score: the subject's level + its optional courses done + a roll - stress and the week's answer.
func _matric_score(exam_id: String, part: int, d: Dictionary) -> float:
	var c: Dictionary = Data.lukio.matric.score
	var sid := str(Matriculation.exam(exam_id).get("subject", exam_id))
	var opt := 0
	for u in lukio.units:
		if str(u.s) == sid and str(u.k) == "opt" and str(u.st) == "done":
			opt += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed("matric|%s|%d|%d" % [exam_id, part, Calendar.date_key(d)])
	var t: Dictionary = cfg().tests
	return level(sid) + minf(float(c.bonus_max), opt * float(c.bonus_per_optional)) + rng.randfn(0.0, float(c.sd)) \
			- _week_and_stress_penalty(d, float(t.stress_from), float(t.stress_penalty))


## Results day: every registered exam of the session graded; a failed one goes into the next session's plan (while retakes are
## left); the certificate when everything is passed.
func _matric_results(key: String, stop: bool) -> void:
	var lines := []
	var any_bad := false
	var total := 0
	var n := 0
	for ex in lukio.matric.registered.get(key, []):
		var exs := str(ex)
		var entry: Dictionary = lukio.matric.sat.get("%s|%s" % [key, exs], {"parts": [], "absent": false})
		var need := Matriculation.exam_dates(key, exs).size()
		var absent := bool(entry.absent) or (entry.parts as Array).size() < need
		var grade := "I"
		if not absent:
			var s := 0.0
			for x in entry.parts:
				s += float(x)
			grade = Matriculation.grade_for(s / maxf(1.0, (entry.parts as Array).size()))
		lukio.matric.results.append({"session": key, "exam": exs, "grade": grade, "points": Matriculation.points(grade), "absent": absent})
		if str(lukio.matric.plan.get(exs, "")) == key:
			lukio.matric.plan.erase(exs)
		if not Matriculation.passed(grade):
			any_bad = true
			var fails := 0
			for r in lukio.matric.results:
				if str(r.exam) == exs and not Matriculation.passed(str(r.grade)):
					fails += 1
			if fails <= int(Data.lukio.matric.retakes) and not _passed(exs):   # the retake goes to the next session (the plan can change)
				lukio.matric.plan[exs] = Matriculation.next_key(key)
		total += Matriculation.points(grade)
		n += 1
		var c: Dictionary = Data.lukio.stops
		if absent:
			lines.append(str(c.matric_results_absent).format({"exam": Matriculation.exam_name(exs, lukio)}))
		else:
			lines.append(str(c.matric_results_line).format({"exam": Matriculation.exam_name(exs, lukio), "grade": grade, "name": Matriculation.grade_name(grade)}))
	var ms := MindSystem.sys()
	var st: Dictionary = Data.lukio.stops
	if ms != null and not neutral and decisions_enabled and n > 0:
		if any_bad:
			ms.add("confidence", float(st.news_delta.bad), str(st.news.matric_bad))
		elif float(total) / n >= 5.0:
			ms.add("confidence", float(st.news_delta.good), str(st.news.matric_good))
	if stop and n > 0:
		var text := str(st.matric_results_text).format({"session": Matriculation.session_name(key)}) + "\n" + "\n".join(lines)
		if any_bad:
			text += "\n\n" + str(st.matric_results_retake)
		var e := Game.post_event(id, str(st.matric_results_title), text, [{"id": "continue", "label": str(st["continue"].label), "detail": ""}], true)
		e.kind = "matric_results"
		e.session = key
	_check_certificate()


## The matriculation certificate: the passed exams meet the rules and the lukio courses are done.
func _check_certificate() -> void:
	if lukio.is_empty() or bool(lukio.matric.cert) or not bool(lukio.get("done", false)):
		return
	var passed := []
	var best := matric_best()
	for ex in best:
		if Matriculation.passed(str(best[ex])):
			passed.append(str(ex))
	var chk := Matriculation.check(passed, lukio)
	var st: Dictionary = Data.lukio.stops
	if not bool(chk.ok):
		if decisions_enabled and not neutral and not lukio.asked.has("cert_wait"):
			lukio.asked.cert_wait = true
			Game.post_event(id, str(st.certificate_title), str(st.certificate_wait))
		return
	lukio.matric.cert = true
	if decisions_enabled and not neutral:
		var lines := []
		var pts := 0
		for ex in passed:
			lines.append("%s: %s" % [Matriculation.exam_name(ex, lukio), str(best[ex])])
			pts += Matriculation.points(str(best[ex]))
		var text := str(st.certificate_text) + "\n" + "\n".join(lines) + "\n\n" + str(st.certificate_points).format({"points": pts, "n": passed.size()})
		var e := Game.post_event(id, str(st.certificate_title), text, [{"id": "continue", "label": str(st["continue"].label), "detail": ""}], true)
		e.kind = "matric_cert"
		var ms := MindSystem.sys()
		if ms != null:
			ms.add("confidence", float(st.news_delta.graduate), str(st.news.graduate))


func _post_matric_plan(key: String) -> void:
	var st: Dictionary = Data.lukio.stops
	var title := ""
	var text := ""
	if key == "":
		var names := []
		for k in matric_main_sessions():
			names.append(Matriculation.session_name(str(k)))
		title = str(st.plan_title)
		text = str(st.plan_text).format({"sessions": ", ".join(names)})
	else:
		title = str(st.register_title).format({"session": Matriculation.session_name(key)})
		text = str(st.register_text).format({"session": Matriculation.session_name(key), "date": Calendar.format_day(Matriculation.deadline(key))})
	var e := Game.post_event(id, title, text, [{"id": "done", "label": str(st.plan_done.label), "detail": ""}], true)
	e.kind = "matric_plan"
	e.session = key


func _post_matric_exam(key: String, exam_id: String, part: int, parts: int) -> void:
	var st: Dictionary = Data.lukio.stops
	var sat: Dictionary = lukio.matric.sat.get("%s|%s" % [key, exam_id], {})
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
	var e := Game.post_event(id, str(st.exam_title), str(st.exam_text).format({"exam": Matriculation.exam_name(exam_id, lukio), "part": part_text, "race": race_text}).strip_edges(),
			choices, true)
	e.kind = "matric_exam"
	e.session = key
	e.exam = exam_id
	e.part = part
	e.meet = meet


## Reads a saved lukio state (numbers as the right types).
static func _lukio_from(src: Dictionary) -> Dictionary:
	var L: Dictionary = src.duplicate(true)
	for k in ["start_year", "years"]:
		L[k] = int(L.get(k, 0))
	for u in L.get("units", []):
		u.n = int(u.n)
		u.p = int(u.p)
		u.g = int(u.g)
		u.x = float(u.x)
		u.r = bool(u.get("r", false))
	if not L.has("matric"):
		L.matric = {}
	for k in ["plan", "registered", "sat"]:
		if not L.matric.has(k):
			L.matric[k] = {}
	for k in ["locked", "results"]:
		if not L.matric.has(k):
			L.matric[k] = []
	if not L.matric.has("cert"):
		L.matric.cert = false
	for r in L.matric.results:
		r.points = int(r.points)
	if not L.has("asked"):
		L.asked = {}
	return L


# --- Save / load -------------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if not started:
		return {}
	var out := {"started": true, "effort": effort, "free_time": free_time, "focus": focus, "subjects": subjects,
			"term_tests": term_tests, "tests_log": tests_log, "reports": reports}
	if not week_choices.is_empty():   # (S2: only a career that was asked has the key, so older states stay exactly as they were)
		out["choices"] = week_choices
	if not paths.is_empty():   # (S3a: likewise)
		out["paths"] = paths
	if not applications.is_empty():
		out["apps"] = applications
	if not lukio.is_empty():   # (S3b: likewise, only once a lukio has started)
		out["lukio"] = lukio
	return out


## An empty state (an older save, or a career that hasn't played a day) starts from the creation answer on the next day.
func from_dict(d: Dictionary) -> void:
	started = false
	effort = "normal"
	free_time = "normal"
	focus = []
	subjects = {}
	term_tests = {}
	tests_log = []
	reports = []
	week_choices = {}
	paths = []
	applications = {}
	lukio = {}
	_schedules = {}
	_exam_days = {}
	_stage_cache = {}
	_lukio_exams = {}
	Lukio.clear_cache()
	if d.is_empty():
		return
	if d.has("lukio"):
		lukio = _lukio_from(d.lukio)
	for k in d.get("choices", {}):
		week_choices[str(k)] = str(d.choices[k])
	for p in d.get("paths", []):
		var seg := {"kind": str(p.kind), "school": str(p.school), "town": str(p.town), "start_year": int(p.start_year),
				"years": int(p.years), "arrived": bool(p.get("arrived", false))}
		if bool(p.get("default", false)):
			seg["default"] = true
		paths.append(seg)
	for k in d.get("apps", {}):
		var src: Dictionary = d.apps[k]
		var rows := []
		for r in src.get("results", []):
			rows.append(r)
		var test: Dictionary = src.get("test", {})
		applications[str(k)] = {"wishes": (src.get("wishes", []) as Array).map(func(x): return str(x)), "locked": bool(src.get("locked", false)),
				"test": test, "results": rows, "decided": bool(src.get("decided", false))}
	started = bool(d.get("started", false))
	effort = str(d.get("effort", "normal"))
	free_time = str(d.get("free_time", "normal"))
	for sid in d.get("focus", []):
		focus.append(str(sid))
	for sid in d.get("subjects", {}):
		var s: Dictionary = d.subjects[sid]
		subjects[str(sid)] = {"natural": float(s.natural), "level": float(s.level)}
	for sid in d.get("term_tests", {}):
		var list := []
		for x in d.term_tests[sid]:
			list.append(float(x))
		term_tests[str(sid)] = list
	for t in d.get("tests_log", []):
		tests_log.append({"date": Game.int_date(t.date), "subject": str(t.subject), "score": float(t.score)})
	for r in d.get("reports", []):
		var grades := {}
		for sid in r.grades:
			grades[str(sid)] = int(r.grades[sid])
		var rep := {"date": Game.int_date(r.date), "kind": str(r.kind), "stage": str(r.stage), "year": int(r.year),
				"grades": grades, "average": float(r.average), "academic_average": float(r.academic_average)}
		if r.has("period"):   # a lukio period's results (S3b)
			rep.label = str(r.get("label", ""))
			rep.period = int(r.period)
			rep.courses = (r.get("courses", []) as Array).map(func(c): return {"id": str(c.id), "s": str(c.s), "n": int(c.n), "g": int(c.g)})
		reports.append(rep)
