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

var _schedules := {}            # school year -> {date key -> [subject ids]} (made from the career's seed; not saved)
var _exam_days := {}            # school year -> {date key: true} (from the stage's exam_weeks; not saved)

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

func _town() -> String:
	return Game.athlete.hometown if Game.athlete else ""


## The stage on a date: {id, grade, name, kind, subjects, scale, exam_weeks, final?} (data stages.list).
func stage_of(d: Dictionary) -> Dictionary:
	var list: Array = cfg().stages.list
	if Game.athlete == null:
		return list[0]
	var grade := SchoolCalendar.year_of(d) - int(Game.athlete.birth_date.year) - int(cfg().stages.grade_offset)
	var pick: Dictionary = list[0]
	for s in list:
		if grade >= int(s.grade):
			pick = s
	return pick


## What kind of day a date is: SchoolCalendar.day + {exam (a day of an exam week), tests (subject ids tested that day)}.
func day_info(d: Dictionary) -> Dictionary:
	var info := SchoolCalendar.day(_town(), d)
	info.exam = info.kind == "school" and is_exam_day(d)
	info.tests = tests_on(d)
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
	if is_double(session_ids):
		out.append({"id": "double_day", "value": float(ll.double_day) * scale})
	var chosen := choice_of(Calendar.monday_of(d))   # the week's meet-and-tests answer (S2): "bus" = studying late all week
	if chosen != "":
		var dl := float(option_of(chosen).get("load", 0.0))
		if dl != 0.0:
			out.append({"id": "decision_" + chosen, "value": dl * scale})
	var today := tests_on(d).size()
	if today > 0:
		var n := tests_in_week(Calendar.monday_of(d))
		if n > int(cfg().tests.normal_per_week):
			out.append({"id": "busy_test", "value": today * float(ll.busy_test) * scale, "n": n})
	if is_exam_day(d):
		out.append({"id": "exam", "value": float(ll.exam_day) * scale})
	return out


## Two separate practices: at least two sessions that are not add-ons (drills, strides... ride along in the same practice).
static func is_double(session_ids: Array) -> bool:
	var add_ons: Array = Data.school_life.life_load.add_ons
	var main := 0
	for sid in session_ids:
		if not str(sid) in add_ons:
			main += 1
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


func subject_list() -> Array:
	return cfg().subjects.list


func is_academic(sid: String) -> bool:
	for s in subject_list():
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
	if decisions_enabled and not neutral:
		_ask_meet_test(ctx.date)


func on_day_end(ctx: Dictionary) -> void:
	if not model_enabled or Game.athlete == null:
		return
	_ensure_started()
	var d: Dictionary = ctx.date
	var info := SchoolCalendar.day(_town(), d)
	var stage := stage_of(d)
	var written := []
	if info.kind == "school" and bool(stage.get("subjects", false)):
		_drift()
		for sid in tests_on(d):
			var score := _write_test(sid, d)
			if not term_tests.has(sid):
				term_tests[sid] = []
			term_tests[sid].append(score)
			tests_log.append({"date": d.duplicate(), "subject": sid, "score": score})
			written.append(sid)
		while tests_log.size() > KEEP_TESTS:
			tests_log.pop_front()
	if bool(stage.get("subjects", false)):
		var y := SchoolCalendar.year_for(_town(), SchoolCalendar.year_of(d))
		var key := Calendar.date_key(d)
		var kind := ""
		if key == Calendar.date_key(y.christmas_card):
			kind = "christmas"
		elif key == int(y.end_key):
			kind = "final" if bool(stage.get("final", false)) else "spring"
		if kind != "":
			reports.append(_report(d, kind))
			term_tests = {}
			if decisions_enabled:
				_post_card(reports.size() - 1)
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
		if on_day or before or busy:
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


# --- Save / load -------------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if not started:
		return {}
	var out := {"started": true, "effort": effort, "free_time": free_time, "focus": focus, "subjects": subjects,
			"term_tests": term_tests, "tests_log": tests_log, "reports": reports}
	if not week_choices.is_empty():   # (S2: only a career that was asked has the key, so older states stay exactly as they were)
		out["choices"] = week_choices
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
	_schedules = {}
	_exam_days = {}
	if d.is_empty():
		return
	for k in d.get("choices", {}):
		week_choices[str(k)] = str(d.choices[k])
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
		reports.append({"date": Game.int_date(r.date), "kind": str(r.kind), "stage": str(r.stage), "year": int(r.year),
				"grades": grades, "average": float(r.average), "academic_average": float(r.academic_average)})
