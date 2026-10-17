extends SceneTree
## Dev tool: headless checks of the school model (GDD 4.9.3, session S1): the calendar against data/school.json (2026-27 for the
## towns that published their dates, the winter break by region, later years by the rules and marked estimated), the stages,
## grade drift per study effort over a year by creation answer (GDD 4.9.7), the life load (exactly neutral at Normal / Normal in
## a normal school week, bit for bit through the game), tests and exam weeks raising stress, report cards, the moods' and the
## health model's hooks, save / load, an older save and the off / neutral switches. Prints PASS / FAIL.
## Run: godot --headless --path . -s res://tools/school_check.gd [-- athletes per answer and effort, default 10]
## Uses its own save folder (user://tool_saves/), never the player's saves. ~1-2 minutes.
## NOTE: it prints ALL CHECKS PASSED even when a SCRIPT ERROR aborted a check function: read stderr too.

var game
var data
var saves
var Cal
var SCal
var SC
var MI
var C
var H
var WP
var _fails := 0
var _n := 10


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	Cal = load("res://scripts/core/calendar.gd")
	SCal = load("res://scripts/core/school_calendar.gd")
	SC = load("res://scripts/core/school_system.gd")
	MI = load("res://scripts/core/mind_system.gd")
	C = load("res://scripts/core/coach_system.gd")
	H = load("res://scripts/core/health_system.gd")
	WP = load("res://scripts/core/week_plan.gd")
	H.model_enabled = false
	C.neutral_club = true
	game.autosave = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		_n = args[0].to_int()

	_check_data()
	_check_calendar()
	_check_later_years()
	_check_stages()
	_check_life_load_numbers()
	_check_neutral_bit_for_bit()
	_check_grade_drift()
	_check_tests_and_cards()
	_check_stress()
	_check_hooks()
	_check_save_load()
	_check_switches()
	_check_decisions()
	_check_application()
	_check_lukio()
	_check_matric()
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


# --- 1. Data ------------------------------------------------------------------------------------------------------------

func _check_data() -> void:
	print("-- 1. data/school_life.json")
	var s: Dictionary = data.school_life
	var list: Array = s.subjects.list
	var academic := list.filter(func(x): return str(x.kind) == "academic")
	_ok("17 subjects, 12 academic (the application average)", list.size() == 17 and academic.size() == 12)
	var ok := true
	for q in data.background_questions:
		if str(q.id) == "school":
			for ans in q.answers:
				ok = ok and s.answers.has(str(ans.get("school_answer", "")))
	_ok("every 'How do you do at school?' answer has a school_answer with start / natural levels", ok)
	var starts := []
	for id in ["top", "hard_work", "fine", "struggling", "dont_care"]:
		starts.append(float(s.answers[id].start))
	_ok("the starting averages are the GDD's 9.0 / 8.5 / 7.5 / 6.8 / 6.3", starts == [9.0, 8.5, 7.5, 6.8, 6.3])
	_ok("Normal / Normal adds nothing (effort, free time and the normal shift are 0)", float(s.life_load.effort.normal) == 0.0
			and float(s.life_load.free_time.normal) == 0.0 and float(s.grades.effort_shift.normal) == 0.0)
	_ok("yläkoulu has no exam weeks (user 2026-10-17: only single tests)", s.stages.list[0].exam_weeks.is_empty()
			and s.stages.list[1].exam_weeks.is_empty())


# --- 2. The calendar of 2026-27 -------------------------------------------------------------------------------------------

func _d(s: String) -> Dictionary:
	return Cal.parse_date(s)


## Every weekday of a range has the kind and the break.
func _range_is(town: String, from: String, to: String, kind: String, brk: String) -> bool:
	var d := _d(from)
	while Cal.date_key(d) <= Cal.date_key(_d(to)):
		if Cal.weekday(d) < 5:
			var info: Dictionary = SCal.day(town, d)
			if str(info.kind) != kind or str(info["break"]) != brk:
				print("    %s %s: %s / %s (wanted %s / %s)" % [town, Cal.format_day(d), info.kind, info["break"], kind, brk])
				return false
		d = game.add_days(d, 1)
	return true


func _check_calendar() -> void:
	print("-- 2. the 2026-27 calendar against data/school.json")
	var ok := true
	var towns := 0
	for m in data.school.verified.municipal:
		var t := str(m.town)
		towns += 1
		ok = ok and _range_is(t, str(m.autumn[0]), str(m.autumn[1]), "holiday", "autumn")
		ok = ok and _range_is(t, str(m.christmas[0]), str(m.christmas[1]), "holiday", "christmas")
		ok = ok and _range_is(t, str(m.winter[0]), str(m.winter[1]), "holiday", "winter")
		var start := _d(str(m.start))
		ok = ok and str(SCal.day(t, start).kind) == "school"
		var before: Dictionary = game.add_days(start, -1)
		while Cal.weekday(before) >= 5:
			before = game.add_days(before, -1)
		ok = ok and str(SCal.day(t, before).kind) == "summer"
		ok = ok and not bool(SCal.day(t, start).estimated)
		ok = ok and str(SCal.day(t, _d("2027-06-04")).kind) == "school" and str(SCal.day(t, _d("2027-06-07")).kind) == "summer"
	_ok("%d towns: autumn, Christmas and winter breaks, the first school day, the end (Fri 4 Jun school, Mon 7 Jun summer)" % towns, ok and towns == 20)
	_ok("Kotka's autumn break is week 43 (19-23 Oct 2026), Helsinki's week 42", _range_is("Kotka", "2026-10-19", "2026-10-23", "holiday", "autumn")
			and str(SCal.day("Kotka", _d("2026-10-12")).kind) == "school" and _range_is("Helsinki", "2026-10-12", "2026-10-16", "holiday", "autumn"))
	_ok("Easter 2027: Good Friday 26 Mar to Easter Monday 29 Mar; Thu 25 Mar and Tue 30 Mar school",
			_range_is("Tampere", "2027-03-26", "2027-03-29", "holiday", "easter") and SCal.is_school_day("Tampere", _d("2027-03-25"))
			and SCal.is_school_day("Tampere", _d("2027-03-30")))
	_ok("public holidays: 1 May (Sat), Ascension Thu 6 + Fri 7 May 2027", _range_is("Tampere", "2027-05-06", "2027-05-07", "holiday", "public")
			and str(SCal.day("Tampere", _d("2027-05-01")).kind) == "weekend")
	_ok("Mikkeli: back on Mon 4 Jan, 6 Jan (Epiphany) still free", SCal.is_school_day("Mikkeli", _d("2027-01-04"))
			and str(SCal.day("Mikkeli", _d("2027-01-06")).kind) == "holiday")
	_ok("Tampere's Christmas report card day is Fri 18 Dec 2026", Cal.date_key(SCal.year_for("Tampere", 2026).christmas_card) == 20261218)
	# The winter break by region for towns that did not publish (data/towns.json winter_groups): one town of each group.
	var groups_ok := true
	var shown := []
	for g in ["south", "middle", "north"]:
		var town := ""
		for t in data.towns.towns:
			if SCal._municipal(str(t.name)).is_empty() and str(t.maakunta) in data.towns.winter_groups[g].maakunta:
				town = str(t.name)
				break
		var week := int(data.towns.winter_groups[g].iso_week)
		var mon: Dictionary = SCal.iso_monday(2027, week)
		var f := "%04d-%02d-%02d" % [mon.year, mon.month, mon.day]
		var fri: Dictionary = game.add_days(mon, 4)
		var t2 := "%04d-%02d-%02d" % [fri.year, fri.month, fri.day]
		groups_ok = groups_ok and town != "" and _range_is(town, f, t2, "holiday", "winter") and bool(SCal.day(town, mon).estimated)
		shown.append("%s %s week %d (%s)" % [g, town, week, f])
	_ok("winter break by region for the other towns, marked estimated: %s" % ", ".join(shown), groups_ok)
	_ok("Kerava (not in the agency's table): Uusimaa = south, week 8 (22-26 Feb 2027)", _range_is("Kerava", "2027-02-22", "2027-02-26", "holiday", "winter"))
	_ok("ISO weeks: 12 Oct 2026 = 42, 4 Jan 2027 = 1, 22 Feb 2027 = 8", SCal.iso_week(_d("2026-10-12")) == 42 and SCal.iso_week(_d("2027-01-04")) == 1
			and SCal.iso_week(_d("2027-02-22")) == 8)
	var school_days: int = SCal.school_days("Helsinki", _d("2026-08-12"), _d("2027-06-05")).size()
	print("    Helsinki 2026-27: %d school days (the agency: 189 working days incl. a Saturday)" % school_days)
	_ok("Helsinki 2026-27 has 185-190 Mon-Fri school days (%d)" % school_days, school_days >= 185 and school_days <= 190)


func _check_later_years() -> void:
	print("-- 3. later years by the rules (estimated)")
	var y: Dictionary = SCal.year_for("Helsinki", 2027)
	_ok("2027-28 is estimated: start Wed 18 Aug 2027 (ISO week 33), end Sat 3 Jun 2028", bool(y.estimated)
			and Cal.date_key(y.start) == 20270818 and Cal.date_key(y.end) == 20280603)
	_ok("autumn break 2027: Helsinki week 42 (18-22 Oct), Kotka keeps week 43 (25-29 Oct)",
			_range_is("Helsinki", "2027-10-18", "2027-10-22", "holiday", "autumn") and _range_is("Kotka", "2027-10-25", "2027-10-29", "holiday", "autumn"))
	_ok("Christmas 2027-28: 22 Dec - 6 Jan (Tue 21 Dec school, Fri 7 Jan school)", _range_is("Helsinki", "2027-12-22", "2028-01-06", "holiday", "christmas")
			and SCal.is_school_day("Helsinki", _d("2027-12-21")) and SCal.is_school_day("Helsinki", _d("2028-01-07")))
	_ok("winter 2028: Helsinki week 8 (21-25 Feb), Oulu week 10 (6-10 Mar)", _range_is("Helsinki", "2028-02-21", "2028-02-25", "holiday", "winter")
			and _range_is("Oulu", "2028-03-06", "2028-03-10", "holiday", "winter"))
	var easters := []
	for yr in [2027, 2028, 2029, 2030]:
		easters.append(Cal.date_key(SCal.easter(yr)))
	_ok("Easter Sundays 2027-2030: 28 Mar, 16 Apr, 1 Apr, 21 Apr", easters == [20270328, 20280416, 20290401, 20300421])
	_ok("Easter 2028 Fri 14 - Mon 17 Apr", _range_is("Helsinki", "2028-04-14", "2028-04-17", "holiday", "easter"))


# --- 4. Stages ----------------------------------------------------------------------------------------------------------

func _check_stages() -> void:
	print("-- 4. stages (born 2012)")
	var ss = _fresh()
	_ok("2 Nov 2026 grade 8, 1 Jul 2027 still grade 8 (its summer), 1 Sep 2027 grade 9, 1 Sep 2028 the default path (a lukio, S3a)",
			str(ss.stage_of(_d("2026-11-02")).id) == "grade_8" and str(ss.stage_of(_d("2027-07-01")).id) == "grade_8"
			and str(ss.stage_of(_d("2027-09-01")).id) == "grade_9" and str(ss.stage_of(_d("2028-09-01")).id) == "lukio")


# --- 5. Life load numbers ---------------------------------------------------------------------------------------------------

func _check_life_load_numbers() -> void:
	print("-- 5. the life load's parts")
	var ss = _fresh()
	ss._schedules[2026] = {}   # (no tests in this part)
	var mon := _d("2026-11-09")
	var sat := _d("2026-11-14")
	_ok("a normal school day at Normal / Normal: 0 (also with the coach's Monday 'easy run + drills')",
			ss.life_load(mon, []) == 0.0 and ss.life_load(mon, ["easy_run", "drills"]) == 0.0 and not SC.is_double(["easy_run", "drills"])
			and not SC.is_double(["strength", "speed_strides"]))
	_ok("two separate practices on a school day: +1.5; on a Saturday: 0", SC.is_double(["easy_run", "tempo_run"])
			and ss.life_load(mon, ["easy_run", "tempo_run"]) == 1.5 and ss.life_load(sat, ["easy_run", "tempo_run"]) == 0.0)
	_ok("a weekday of the Christmas break: -1 (relief); a weekend: 0", ss.life_load(_d("2026-12-22"), []) == -1.0 and ss.life_load(sat, []) == 0.0)
	_ok("summer weekday: -1", ss.life_load(_d("2027-07-06"), []) == -1.0)
	ss.set_effort("heavy")
	ss.set_free_time("lots")
	_ok("Heavy effort + Lots of free time on a school day: +1.75; on a holiday still -1", ss.life_load(mon, []) == 1.75 and ss.life_load(_d("2026-12-22"), []) == -1.0)
	ss.set_effort("light")
	ss.set_free_time("little")
	_ok("Light + Little: -1.0", ss.life_load(mon, []) == -1.0)
	_ok("grade 9 scales the positive parts x1.1 (a double day 1.65)", is_equal_approx(ss.life_load(_d("2027-11-08"), ["easy_run", "tempo_run"]) + 1.0, 1.65))
	_ok("effects at 0: keep +0, colds x1, injuries x1", SC.keep_shift(0.0) == 0.0 and SC.illness_mult(0.0) == 1.0 and SC.injury_mult(0.0) == 1.0)
	_ok("an exam day (2 points): keep +0.01, colds x1.15, injuries x1.15; a holiday (-1): colds x0.925, injuries x1",
			is_equal_approx(SC.keep_shift(2.0), 0.01) and is_equal_approx(SC.illness_mult(2.0), 1.15) and is_equal_approx(SC.injury_mult(2.0), 1.15)
			and is_equal_approx(SC.illness_mult(-1.0), 0.925) and SC.injury_mult(-1.0) == 1.0)


# --- 6. Neutral = identical, through the game ---------------------------------------------------------------------------------

## A career playing `weeks` weeks of the coach's repeating week with the health model ON (fixed health dice) and the moods FREE.
## `school` = "off" / "free". With "free" and no tests the school weeks of Nov - mid Dec 2026 are normal school weeks at Normal /
## Normal. Returns the state as text.
func _career_state(school: String, weeks: int) -> String:
	SC.model_enabled = school != "off"
	H.model_enabled = true
	game.start_career(_athlete(), "repeat")
	game.get_system("health").rng.seed = 777
	if school != "off":
		game.get_system("school")._ensure_started()
		game.get_system("school")._schedules[2026] = {}
	_play_weeks(weeks)
	var mind = game.get_system("mind")
	var out := _json({"athlete": game.athlete.to_dict(), "health": game.get_system("health").to_dict(), "moods": mind.values,
			"fatigue": game.day_log.map(func(e): return e.fatigue)})
	SC.model_enabled = true
	H.model_enabled = false
	return out


func _check_neutral_bit_for_bit() -> void:
	print("-- 6. neutral = identical (Normal / Normal in normal school weeks, health on, moods free)")
	var off := _career_state("off", 6)
	var free := _career_state("free", 6)
	var ss = game.get_system("school")
	var all_zero := true
	for i in 42:
		all_zero = all_zero and ss.life_load(game.add_days(_d("2026-11-02"), i), []) == 0.0
	_ok("2 Nov - 13 Dec 2026 are normal school weeks in Tampere (every day's life load 0)", all_zero)
	if off != free:
		print("    off:  %s\n    free: %s" % [off.left(400), free.left(400)])
	_ok("6 weeks with the school ON at Normal / Normal = the school OFF, bit for bit (athlete, health, moods, every day's fatigue)", off == free)
	# The 7th week looks ahead to the Christmas break on Sunday night, and the 8th is the break: the free school differs (relief).
	var off8 := _career_state("off", 8)
	var f_off: float = game.athlete.fatigue
	var s_off: float = game.get_system("mind").value("stress")
	var free8 := _career_state("free", 8)
	var f_free: float = game.athlete.fatigue
	var s_free: float = game.get_system("mind").value("stress")
	print("    after the Christmas break's first week: fatigue %.3f (off) vs %.3f (school), stress %.1f vs %.1f" % [f_off, f_free, s_off, s_free])
	_ok("the Christmas break is lighter: less fatigue and less stress than without school", off8 != free8 and f_free < f_off and s_free < s_off)


# --- 7. Grade drift over a year (GDD 4.9.7) -----------------------------------------------------------------------------------

## The school of an athlete with the school answer `ans_index` (0-4) and a name of its own, set up as the career's school.
func _school_for(ans_index: int, i: int):
	var a = _athlete(ans_index)
	a.first_name = "Pupil%d" % i
	game.athlete = a
	var ss = SC.new()
	ss._ensure_started()
	return ss


## Plays a year of school days (2 Nov 2026 - 1 Nov 2027) on the school alone. Returns the change of the average.
func _school_year(ss, effort: String, focus := []) -> float:
	ss.set_effort(effort)
	ss.set_focus(focus)
	var before: float = ss.average()
	var d := _d("2026-11-02")
	for k in 365:
		ss.on_day_end({"date": d, "record": {}})
		d = game.add_days(d, 1)
	return ss.average() - before


func _check_grade_drift() -> void:
	print("-- 7. grade drift over a year by school answer and effort (%d athletes each; GDD 4.9.7: Normal +-0.3, Heavy +0.5, Light -0.5)" % _n)
	game.start_career(_athlete(), "repeat")
	var keep_athlete = game.athlete
	var names := ["top", "hard_work", "fine", "struggling", "dont_care"]
	var ok_normal := true
	var ok_heavy := true
	var ok_light := true
	var ok_start := true
	for ai in 5:
		var line := "    %-10s" % names[ai]
		var means := {}
		for effort in ["normal", "light", "heavy"]:
			var sum := 0.0
			var start_sum := 0.0
			var lo := 99.0
			var hi := -99.0
			for i in _n:
				var ss = _school_for(ai, i)
				start_sum += ss.average(true)
				var dv: float = _school_year(ss, effort)
				sum += dv
				lo = minf(lo, dv)
				hi = maxf(hi, dv)
			var mean := sum / _n
			means[effort] = mean
			line += " | %s %+.2f (%+.2f..%+.2f)" % [effort, mean, lo, hi]
			if effort == "normal":
				ok_normal = ok_normal and absf(mean) <= 0.3
				ok_start = ok_start and absf(start_sum / _n - float(data.school_life.answers[names[ai]].start)) < 0.05
			elif effort == "heavy":
				var up: float = mean - means.normal
				ok_heavy = ok_heavy and up >= (0.3 if names[ai] == "top" else 0.4) and up <= 0.6
			else:
				var down: float = mean - means.normal
				ok_light = ok_light and down <= -0.4 and down >= -0.6
		print(line)
	_ok("the starting academic average = the answer's level (within 0.05)", ok_start)
	_ok("Normal effort holds the average within +-0.3 a year for every answer ('hard work' slides, 'couldn't care less' rises a little)", ok_normal)
	_ok("Heavy effort: about +0.5 a year over Normal (+0.4..+0.6; 'Top of the class' at least +0.3: grades stop at 10)", ok_heavy)
	_ok("Light effort: about -0.5 a year under Normal (-0.6..-0.4)", ok_light)
	# Focus subjects rise more than the rest.
	var ss = _school_for(2, 0)
	var maths_before: float = ss.level("maths")
	var hist_before: float = ss.level("history")
	_school_year(ss, "normal", ["maths"])
	var dm: float = ss.level("maths") - maths_before
	var dh: float = ss.level("history") - hist_before
	print("    focus on maths for a year (Doing fine, Normal): maths %+.2f, history %+.2f" % [dm, dh])
	_ok("a focus subject rises (~+0.5 a year), the other academic subjects slip a little", dm > 0.35 and dh < 0.0 and dh > -0.15)
	game.athlete = keep_athlete


# --- 8. Tests and report cards --------------------------------------------------------------------------------------------------

func _check_tests_and_cards() -> void:
	print("-- 8. tests and report cards")
	game.start_career(_athlete(), "repeat")
	var ss = game.get_system("school")
	ss._ensure_started()
	var sched: Dictionary = ss._schedule(2026)
	var total := 0
	var per_week := {}
	for key in sched:
		total += sched[key].size()
		var d: Dictionary = Cal.parse_date("%d-%02d-%02d" % [int(key) / 10000, (int(key) / 100) % 100, int(key) % 100])
		var mk: int = Cal.date_key(Cal.monday_of(d))
		per_week[mk] = int(per_week.get(mk, 0)) + sched[key].size()
		if not SCal.is_school_day("Tampere", d):
			total = -9999
	var busy := 0
	var most := 0
	for mk in per_week:
		if int(per_week[mk]) > int(data.school_life.tests.normal_per_week):
			busy += 1
		most = maxi(most, int(per_week[mk]))
	print("    2026-27 in Tampere: %d tests in %d weeks with tests, %d busy weeks (3+ tests), at most %d in a week" % [total, per_week.size(), busy, most])
	_ok("48 tests a year (12 academic subjects x 2 a term), all on school days", total == 48)
	_ok("tests cluster: a few busy test weeks (2-10)", busy >= 2 and busy <= 10)
	_ok("the same career gets the same test days (no dice state)", ss._schedule(2026) == sched and ss.tests_on(_d("2026-11-02")) == sched.get(20261102, []))
	_ok("test scores look Finnish: 8, 8+, 8½, 9-", SC.score_text(8.0) == "8" and SC.score_text(8.25) == "8+" and SC.score_text(8.5) == "8½"
			and SC.score_text(8.75) == "9-")
	# A year through the game: the cards.
	_play_weeks(53)
	var cards: Array = ss.report_cards()
	var kinds := cards.map(func(c): return str(c.kind))
	var dates := cards.map(func(c): return Cal.date_key(c.date))
	print("    cards: %s on %s; averages %s" % [kinds, dates, cards.map(func(c): return "%.2f / %.2f" % [c.average, c.academic_average])])
	var whole := true
	for c in cards:
		for sid in c.grades:
			whole = whole and c.grades[sid] is int and int(c.grades[sid]) >= 4 and int(c.grades[sid]) <= 10
	_ok("a year: the Christmas card on Fri 18 Dec 2026 and the spring card on Sat 5 Jun 2027, whole grades 4-10",
			kinds == ["christmas", "spring"] and dates == [20261218, 20270605] and whole and cards[0].grades.size() == 17)
	_ok("the card's academic average is near the level (within 0.5)", absf(float(cards[1].academic_average) - ss.average(true)) < 0.5)
	_ok("the day log shows the kind of day and the tests", game.day_log.any(func(e): return e.has("school")))
	# Grade 9's June card is the final certificate.
	var a2 = _athlete()
	a2.birth_date = {"year": 2011, "month": 5, "day": 1}
	game.start_career(a2, "repeat")
	_play_weeks(32)
	var last: Dictionary = game.get_system("school").latest_report()
	_ok("a grade-9 career (born 2011): June 2027 card = the final certificate", str(last.get("kind", "")) == "final" and str(last.get("stage", "")) == "grade_9")


# --- 9. Stress: tests, exam weeks, holidays ----------------------------------------------------------------------------------------

## A year of the coach's repeating week (health off, moods free): the stress word after each Sunday night (= the week ahead) with
## what that week is. Returns {weeks: [{word, value, kind}]}.
func _stress_year(effort: String, free_time: String) -> Array:
	game.start_career(_athlete(), "repeat")
	var ss = game.get_system("school")
	ss.set_effort(effort)
	ss.set_free_time(free_time)
	var out := []
	for w in 52:
		_play_weeks(1)
		var monday: Dictionary = game.date
		var kind := "school"
		var holiday := 0
		var exam := false
		for i in 5:
			var info: Dictionary = ss.day_info(game.add_days(monday, i))
			if str(info.kind) in ["holiday", "summer"]:
				holiday += 1
			exam = exam or bool(info.exam)
		if holiday >= 3:
			kind = "holiday"
		elif exam:
			kind = "exam"
		elif ss.tests_in_week(monday) > int(data.school_life.tests.normal_per_week):
			kind = "busy"
		var mind = game.get_system("mind")
		out.append({"word": str(mind.word("stress").id), "value": mind.value("stress"), "kind": kind})
	return out


func _stress_summary(name: String, weeks: Array) -> Dictionary:
	var by := {}
	for w in weeks:
		var k: String = w.kind
		if not by.has(k):
			by[k] = {"n": 0, "sum": 0.0, "words": {}}
		by[k].n += 1
		by[k].sum += float(w.value)
		by[k].words[w.word] = int(by[k].words.get(w.word, 0)) + 1
	var parts := []
	for k in by:
		parts.append("%s %d wk avg %.1f %s" % [k, by[k].n, by[k].sum / by[k].n, by[k].words])
	print("    %-26s %s" % [name, " | ".join(parts)])
	return by


func _check_stress() -> void:
	print("-- 9. stress through a year (moods free, health off; the word after each Sunday = the week ahead)")
	var normal := _stress_summary("Normal / Normal:", _stress_year("normal", "normal"))
	var heavy := _stress_summary("Heavy / Lots:", _stress_year("heavy", "lots"))
	var light := _stress_summary("Light / Little:", _stress_year("light", "little"))
	_ok("holiday weeks are calmer than school weeks (Normal / Normal)", normal.has("holiday") and normal.has("school")
			and normal.holiday.sum / normal.holiday.n < normal.school.sum / normal.school.n)
	_ok("busy test weeks are more stressful than other school weeks (Normal / Normal)", normal.has("busy")
			and normal.busy.sum / normal.busy.n > normal.school.sum / normal.school.n)
	_ok("Heavy / Lots is more stressful than Normal / Normal, Light / Little calmer",
			heavy.school.sum / heavy.school.n > normal.school.sum / normal.school.n and light.school.sum / light.school.n < normal.school.sum / normal.school.n)
	# Exam weeks (none in yläkoulu by the user's choice; S3's lukio has them): the machinery, with three exam weeks forced into the data.
	var stage: Dictionary = data.school_life.stages.list[0]
	var keep: Array = stage.exam_weeks
	stage.exam_weeks = [{"before": "christmas", "weeks": 2}, {"before": "winter", "weeks": 1}, {"before": "end", "weeks": 2}]
	var ss = _fresh()
	var exam_days := []
	for key in ss._exam_set(2026):
		exam_days.append(int(key))
	exam_days.sort()
	print("    forced exam days 2026-27 (Tampere): %s" % [exam_days])
	_ok("exam weeks by rule: 7-11 Dec (2 weeks before Christmas), 22-26 Feb (before the winter break), 24-28 May (2 weeks before the end)",
			exam_days == [20261207, 20261208, 20261209, 20261210, 20261211, 20270222, 20270223, 20270224, 20270225, 20270226,
			20270524, 20270525, 20270526, 20270527, 20270528])
	var parts: Array = ss.load_parts(_d("2026-12-08"), [])
	_ok("an exam day at Normal / Normal: an exam part of 2 (plus its tests: %s)" % [parts],
			parts.any(func(p): return str(p.id) == "exam" and float(p.value) == 2.0))
	var exam_n := _stress_summary("exams, Normal / Normal:", _stress_year("normal", "normal"))
	var exam_h_weeks := _stress_year("heavy", "lots")
	var exam_h := _stress_summary("exams, Heavy / Lots:", exam_h_weeks)
	var stressed := 0
	var stressed_exam := 0
	for w in exam_h_weeks:
		if str(w.word) in ["stressed", "overwhelmed"]:
			stressed += 1
			if str(w.kind) == "exam":
				stressed_exam += 1
	_ok("exam weeks raise stress to Busy or more at Normal / Normal (avg %.1f vs %.1f in other school weeks)" % [
			exam_n.exam.sum / exam_n.exam.n, exam_n.school.sum / exam_n.school.n],
			exam_n.has("exam") and exam_n.exam.sum / exam_n.exam.n >= 35.0 and exam_n.exam.sum / exam_n.exam.n > exam_n.school.sum / exam_n.school.n + 10.0)
	_ok("Stressed or worse mostly in exam weeks (Heavy / Lots: %d of %d Stressed weeks are exam weeks)" % [stressed_exam, stressed],
			stressed > 0 and stressed_exam * 2 > stressed)
	stage.exam_weeks = keep


# --- 10. The moods' and the health model's hooks -----------------------------------------------------------------------------------

func _check_hooks() -> void:
	print("-- 10. hooks: the mind's rows and the health model")
	var ss = _fresh()
	ss._schedules[2026] = {}
	var mind = game.get_system("mind")
	_ok("Normal / Normal in a normal week: no school lines under stress or motivation",
			not mind.pulls("stress").any(func(p): return str(p.text).contains("study") or str(p.text).contains("free time"))
			and ss.stress_pulls(_d("2026-11-09")).is_empty() and ss.motivation_pulls().is_empty())
	ss.set_effort("heavy")
	ss.set_free_time("lots")
	var lines: Array = ss.stress_pulls(_d("2026-11-09"))
	print("    Heavy / Lots, a normal week: %s" % [lines])
	_ok("Heavy / Lots: stress pulls 'Heavy study effort' +8.6 and 'late nights' +6.4; motivation +4", lines.size() == 2
			and is_equal_approx(float(lines[0].delta), 5.0 / 7.0 * 12.0) and is_equal_approx(float(lines[1].delta), 5.0 * 0.75 / 7.0 * 12.0)
			and float(ss.motivation_pulls()[0].delta) == 4.0)
	var xmas: Array = ss.stress_pulls(_d("2026-12-21"))
	_ok("the Christmas break week pulls stress down ('School holiday')", xmas.size() == 1 and float(xmas[0].delta) < 0.0)
	# The health model reads the day's life load: a heavy school day makes a cold more likely (the multiplier it uses).
	H.model_enabled = true
	game.start_career(_athlete(), "repeat")
	var school = game.get_system("school")
	school._ensure_started()
	school._schedules[2026] = {}
	school.set_effort("heavy")
	var health = game.get_system("health")
	for i in 5:   # Monday to Friday: the last day played is a school day
		game.advance_day()
	_ok("the health model took today's multipliers from the life load (Heavy: colds x1.075, injuries x1.075)",
			is_equal_approx(health._ill_mult, 1.075) and is_equal_approx(health._inj_mult, 1.075))
	H.model_enabled = false


# --- 11. Save / load -----------------------------------------------------------------------------------------------------------

func _check_save_load() -> void:
	print("-- 11. save / load")
	H.model_enabled = true
	game.start_career(_athlete(), "repeat")
	var ss = game.get_system("school")
	ss._ensure_started()
	ss.set_effort("heavy")
	ss.set_free_time("little")
	ss.set_focus(["maths", "english"])
	_play_weeks(5)   # to early December: tests written this term
	var snap := _json(game.to_dict())
	_play_weeks(10)
	var a_end := _json(game.athlete.to_dict())
	var s_end := _json(game.get_system("school").to_dict())
	game.from_dict(_parse(snap))
	_play_weeks(10)
	var a_again := _json(game.athlete.to_dict())
	var s_again := _json(game.get_system("school").to_dict())
	if s_again != s_end:
		print("    without saving: %s\n    after the load: %s" % [s_end.left(500), s_again.left(500)])
	_ok("a loaded game goes on exactly as without saving (athlete and school: grades, tests, the Christmas card)", a_again == a_end and s_again == s_end)
	var ss2 = game.get_system("school")
	_ok("the settings and the focus are saved", ss2.effort == "heavy" and ss2.free_time == "little" and ss2.focus == ["maths", "english"])
	_ok("the Christmas card is in the save", ss2.reports.size() == 1 and str(ss2.reports[0].kind) == "christmas")
	# An older save: no school state, no school_answer (only school_level).
	var st: Dictionary = game.to_dict()
	st.systems.erase("school")
	st.athlete.erase("school_answer")
	st.athlete.school_level = "high"
	game.from_dict(st)
	var ss3 = game.get_system("school")
	_ok("an older save loads: no school state until the next day", not ss3.started and ss3.to_dict().is_empty())
	game.advance_day()
	_ok("... then the school starts from school_level 'high' = 'Good grades through hard work' (8.5)", ss3.started
			and SC.answer_of(game.athlete) == "hard_work" and absf(ss3.average(true) - 8.5) < 0.1)
	H.model_enabled = false


# --- 12. Switches ---------------------------------------------------------------------------------------------------------------

func _check_switches() -> void:
	print("-- 12. the off and neutral switches")
	SC.model_enabled = false
	game.start_career(_athlete(), "repeat")
	_play_weeks(2)
	var ss = game.get_system("school")
	_ok("off: SchoolSystem.sys() is null, no week has a school, nothing is saved", SC.sys() == null and game.current_week().school == null
			and ss.to_dict().is_empty() and ss.life_load(_d("2026-12-22"), []) == 0.0)
	SC.model_enabled = true
	SC.neutral = true
	game.start_career(_athlete(), "repeat")
	var ss2 = game.get_system("school")
	ss2.set_effort("heavy")
	ss2.set_free_time("lots")
	_play_weeks(3)
	_ok("neutral: no life load even at Heavy / Lots or on a holiday, no pulls, no news", ss2.life_load(_d("2026-11-10"), ["easy_run", "tempo_run"]) == 0.0
			and ss2.life_load(_d("2026-12-22"), []) == 0.0 and ss2.stress_pulls(_d("2026-12-21")).is_empty() and ss2.motivation_pulls().is_empty()
			and ss2.week_news(_d("2026-11-30")).is_empty())
	_ok("neutral: the grades still drift (Heavy) and the day log has no school fields", ss2.started and ss2.average(true) > 9.0
			and not game.day_log.any(func(e): return e.has("school")))
	SC.neutral = false


# --- 13. Decisions, the report card, the coach's view (session S2) ---------------------------------------------------------------

## A test meet on the Saturday of `monday`'s week (a copy of a local meet, put into the meets cache; removed again by _drop_test_meet).
func _add_test_meet(monday: Dictionary) -> Dictionary:
	Cal.get_meet("none")   # (fills the cache)
	var meet: Dictionary = {}
	for m in Cal._meets_cache:
		if str(m.id) == "kevatkisat":
			meet = m.duplicate(true)
			break
	meet.id = "s2_test_meet"
	meet.date = game.add_days(monday, 5)
	meet.key = "s2_test_meet@%d" % int(meet.date.year)
	Cal._meets_cache.append(meet)
	Cal._meets_cache.sort_custom(func(x, y): return Cal.date_key(x.date) < Cal.date_key(y.date))
	return meet


func _drop_test_meet() -> void:
	Cal._meets_cache = []
	Cal._index_of = []


## A new career that plays to the Monday of the clash week with the test meet entered, plays that Monday morning, answers the
## decision with `answer` (when it is there) and returns what happened.
func _decision_run(answer: String, meet: Dictionary, monday: Dictionary) -> Dictionary:
	var ss = _fresh()
	game.entries = [str(meet.key)]
	while Cal.date_key(game.date) < Cal.date_key(monday):
		game.advance_day()
		while not game.pending_event().is_empty():
			game.answer_event(game.pending_event().id, "ok")
	game.advance_day()
	var e: Dictionary = game.pending_event()
	var out := {"event": e.duplicate(true), "ss": ss}
	if str(e.get("kind", "")) == "school_week":
		game.answer_event(e.id, answer)
	out.choice = ss.choice_of(monday)
	out.entries = game.entries.duplicate()
	return out


func _check_decisions() -> void:
	print("-- 13. the decisions, the report card and the coach's view (S2)")
	SC.decisions_enabled = true
	var ss = _fresh()
	var weeks: Array = ss.busy_weeks(_d("2026-11-02"), _d("2027-06-05"))
	_ok("2026-27 has busy test weeks (the decision's trigger)", not weeks.is_empty())
	if weeks.is_empty():
		SC.decisions_enabled = false
		return
	var monday: Dictionary = weeks[0].monday
	var meet := _add_test_meet(monday)
	var race := _decision_run("race", meet, monday)
	var e: Dictionary = race.event
	print("    the week of %s: %s" % [Cal.format_day(monday), str(e.get("text", "(no event)")).left(160)])
	var ids: Array = (e.get("choices", []) as Array).map(func(c): return str(c.id))
	_ok("a race in a busy test week: Monday morning a stop 'school_week' with the three answers", str(e.get("kind", "")) == "school_week"
			and bool(e.get("stop", false)) and ids == ["race", "study", "bus"])
	_ok("... 'race': the week is marked, the race stays entered", race.choice == "race" and meet.key in race.entries)
	var ss1 = race.ss
	_ok("... and the same week is never asked twice", ss1.meet_test_clash(monday).is_empty())
	# Tests that week come out lower by the option's penalty (the rolls are the same, only the penalty differs).
	var d: Dictionary = game.add_days(monday, 2)
	var key := str(Cal.date_key(monday))
	var with_race: float = ss1._write_test("maths", d)
	ss1.week_choices[key] = "bus"
	var with_bus: float = ss1._write_test("maths", d)
	ss1.week_choices.erase(key)
	var without: float = ss1._write_test("maths", d)
	print("    a maths test that week: %.2f without an answer, %.2f race and risk, %.2f study on the bus" % [without, with_race, with_bus])
	_ok("race and risk costs about half a grade on a test, the bus about a tenth (scores are rounded to quarters)",
			without - with_race >= 0.25 - 0.001 and without - with_race <= 0.75 + 0.001 and without - with_bus >= -0.001 and without - with_bus <= 0.25 + 0.001)
	var study := _decision_run("study", meet, monday)
	_ok("'study and scratch': the race is withdrawn", study.choice == "study" and not meet.key in study.entries)
	var bus := _decision_run("bus", meet, monday)
	var parts: Array = bus.ss.load_parts(game.add_days(monday, 1), [])
	_ok("'race and study on the bus': the school days of that week weigh more (a decision part in the life load)", bus.choice == "bus"
			and parts.any(func(p): return str(p.id) == "decision_bus" and float(p.value) > 0.0) and meet.key in bus.entries)
	_ok("... and the part has a text for the stress row", data.school_life.texts.pulls.has("decision_bus"))
	var unknown := _decision_run("ok", meet, monday)
	_ok("an answer that is no option (a tool's 'ok') = the default 'race and risk it'", unknown.choice == "race")
	# The choices are saved.
	var saved: Dictionary = bus.ss.to_dict()
	var back = SC.new()
	back.from_dict(_parse(_json(saved)))
	_ok("the week's answer is saved and loaded", back.week_choices == bus.ss.week_choices and saved.has("choices"))
	_ok("a career never asked saves no 'choices' key (older states stay as they were)", not _fresh().to_dict().has("choices"))
	# Off: the switches.
	SC.decisions_enabled = false
	var quiet := _decision_run("race", meet, monday)
	_ok("decisions off (every tool that plays days): no stop, no answer", str(quiet.event.get("kind", "")) != "school_week" and quiet.choice == "")
	SC.decisions_enabled = true
	SC.neutral = true
	var neutral := _decision_run("race", meet, monday)
	_ok("neutral: no stop and no answer either", str(neutral.event.get("kind", "")) != "school_week" and neutral.choice == "")
	SC.neutral = false
	_drop_test_meet()

	# The report card day: a stop with the card, then the choice for the next term.
	var ss2 = _fresh()
	var card: Dictionary = {}
	while Cal.date_key(game.date) <= 20261218 and card.is_empty():
		game.advance_day()
		var p: Dictionary = game.pending_event()
		if str(p.get("kind", "")) == "school_card":
			card = p
		elif not p.is_empty():
			game.answer_event(p.id, "ok")
	var card_ids: Array = (card.get("choices", []) as Array).map(func(c): return str(c.id))
	_ok("Fri 18 Dec 2026: the Christmas report card is a stop with keep / harder / ease", not card.is_empty() and card_ids == ["keep", "harder", "ease"]
			and Cal.date_key(game.date) in [20261218, 20261219])
	var panel = load("res://scripts/ui/school_event_panel.gd")
	_ok("the card panel handles it, and the report is the one just made", not card.is_empty() and panel.handles(card) and ss2.reports.size() == 1 and int(card.index) == 0)
	if not card.is_empty():
		game.answer_event(card.id, "harder")
		_ok("'Study harder' sets the study effort to Heavy", ss2.effort == "heavy")
		_ok("... and it says so in the day's events", game.events.any(func(x): return str(x.source) == "school" and str(x.text).contains("heavy")))
	var ss3 = _fresh()
	var card2: Dictionary = {}
	while Cal.date_key(game.date) <= 20261219 and card2.is_empty():
		game.advance_day()
		var p: Dictionary = game.pending_event()
		if str(p.get("kind", "")) == "school_card":
			card2 = p
		elif not p.is_empty():
			game.answer_event(p.id, "ok")
	if not card2.is_empty():
		game.answer_event(card2.id, "ok")
		_ok("an unknown answer = keep going (the effort stays Normal)", ss3.effort == "normal")
	# The final certificate: Continue only.
	var a2 = _athlete()
	a2.birth_date = {"year": 2011, "month": 5, "day": 1}
	game.start_career(a2, "repeat")
	var fin: Dictionary = {}
	while Cal.date_key(game.date) <= 20270606 and fin.is_empty():
		game.advance_day()
		var p: Dictionary = game.pending_event()
		if str(p.get("kind", "")) == "school_card" and str(game.get_system("school").reports.back().kind) == "final":
			fin = p
		elif not p.is_empty():
			game.answer_event(p.id, "ok")
	_ok("a grade-9 career's June card is the final certificate with Continue only", not fin.is_empty()
			and (fin.choices as Array).map(func(c): return str(c.id)) == ["done"])
	SC.decisions_enabled = false

	# The coach's view: his simulation plays the school days' life load. At Normal / Normal in a normal week = without the school.
	var CV = load("res://scripts/core/coach_verdict.gd")
	var ss4 = _fresh()
	ss4._schedules[2026] = {}   # (a school week without tests)
	var mon: Dictionary = _d("2026-11-09")
	var spec := [{"plan": WP.of(game.season.week_for(mon)), "monday": mon}]
	var start: Dictionary = CV.now_start()
	var with_school: Dictionary = CV.simulate(start, spec)
	SC.model_enabled = false
	var without_school: Dictionary = CV.simulate(start, spec)
	SC.model_enabled = true
	_ok("the coach's simulation at Normal / Normal in a normal school week = without the school, to the last digit",
			with_school.athlete.fatigue == without_school.athlete.fatigue and with_school.exp == without_school.exp)
	ss4.set_effort("heavy")
	ss4.set_free_time("lots")
	var heavy: Dictionary = CV.simulate(start, spec)
	print("    his week's end fatigue: %.3f normal, %.3f at Heavy / Lots" % [with_school.athlete.fatigue, heavy.athlete.fatigue])
	_ok("... at Heavy / Lots he sees a more tiring week", heavy.athlete.fatigue > with_school.athlete.fatigue)


# --- 14. The joint application, the paths, the test day and moving (session S3a) ----------------------------------------------------

## Plays days up to `until` (a "YYYY-MM-DD"), answering every stop: `policy` maps an event's kind to an answer id ("FIRST" = the
## first choice, anything missing = "ok"). Returns the kinds (else the source) of the stops met, in order.
func _play_to(until: String, policy := {}) -> Array:
	var seen := []
	var stop: int = Cal.date_key(_d(until))
	while Cal.date_key(game.date) < stop:
		game.advance_day()
		while not game.pending_event().is_empty():
			var e: Dictionary = game.pending_event()
			var kind := str(e.get("kind", ""))
			seen.append(kind if kind != "" else str(e.source))
			var choice := str(policy.get(kind, "ok"))
			if choice == "FIRST" and not e.choices.is_empty():
				choice = str(e.choices[0].id)
			game.answer_event(e.id, choice)
	return seen


## A 14-year-old career with an 800 m result of `time` seconds in the 2027 season (so the application has sport points).
func _app_career(time: float, school_index := 0) -> Dictionary:
	game.start_career(_athlete(school_index), "repeat")
	if time > 0.0:
		game.athlete.results.append({"date": _d("2027-07-10"), "meet": "Test", "meet_key": "t", "event": "800m", "round": "final", "place": 1,
				"field": 8, "time": time, "pb": true})
	return {"ss": game.get_system("school")}


func _count(list: Array, what: String) -> int:
	return list.filter(func(x): return str(x) == what).size()


func _check_application() -> void:
	print("-- 14. the joint application, the paths, the test day, moving (session S3a)")
	var SA = load("res://scripts/core/school_application.gd")
	var CM = load("res://scripts/core/coach_market.gd")
	var ap: Dictionary = data.application
	# Dates: the rule reproduces the real 2026 and 2027 windows.
	var d26: Dictionary = SA.dates(2026)
	var d27: Dictionary = SA.dates(2027)
	var d28: Dictionary = SA.dates(2028)
	_ok("the window rule gives the real 17 Feb - 17 Mar 2026 and 16 Feb - 16 Mar 2027", Cal.date_key(d26.open) == 20260217 and Cal.date_key(d26.close) == 20260317
			and Cal.date_key(d27.open) == 20270216 and Cal.date_key(d27.close) == 20270316)
	_ok("2028 (estimated): the window 15 Feb - 14 Mar, the test day Tue 9 May, results Mon 12 Jun (11 Jun is a Sunday), move 1 Aug",
			Cal.date_key(d28.open) == 20280215 and Cal.date_key(d28.close) == 20280314 and Cal.date_key(d28.test) == 20280509
			and Cal.date_key(d28.results) == 20280612 and Cal.date_key(d28.move) == 20280801)
	_ok("results come on 11 June or later, the place is held 14 days (the real rule: from 11 Jun 2026, accept by 25 Jun)",
			Cal.date_key(SA.dates(2026).results) == 20260611 and Cal.date_key(SA.dates(2026).accept_by) == 20260625)
	# The sport points: the anchors of the real standards, interpolated.
	var a = _athlete()
	game.start_career(a, "repeat")
	var sp := func(t: float) -> float:
		game.athlete.results = [{"date": _d("2027-07-10"), "event": "800m", "time": t, "round": "final", "place": 1, "field": 8, "pb": true}] if t > 0.0 else []
		return float(SA.sport_points(game.athlete, 2028).ladder)
	var anchors: Array = SA.anchors(game.athlete, 2028)
	print("    anchors for a boy applying in 2028 (seconds / points): %s" % ", ".join(anchors.map(func(x): return "%s %.2f / %.1f" % [x.id, x.time, x.points])))
	_ok("four anchors, slowest first: the SM limit 141 s = 1.5, TF-juniorit 126.03 = 3.5, Kalevan minimum 115.5 = 4.5, Kalevan limit 113.5 = 5.0",
			anchors.size() == 4 and absf(float(anchors[0].time) - 141.0) < 0.01 and absf(float(anchors[1].time) - 126.03) < 0.01
			and absf(float(anchors[2].time) - 115.5) < 0.01 and absf(float(anchors[3].time) - 113.5) < 0.01)
	_ok("sport points at the anchors and between: 141 s 1.5, 126.03 s 3.5, 120 s ~4.07, 113.5 s and faster 5.0, 170 s and no race 0",
			absf(sp.call(141.0) - 1.5) < 0.001 and absf(sp.call(126.03) - 3.5) < 0.001 and absf(sp.call(120.0) - (3.5 + 1.0 * 6.03 / 10.53)) < 0.01
			and absf(sp.call(113.5) - 5.0) < 0.001 and sp.call(100.0) == 5.0 and sp.call(170.0) == 0.0 and sp.call(0.0) == 0.0)
	var a_f = _athlete()
	a_f.gender = "female"
	game.athlete = a_f
	var an_f: Array = SA.anchors(a_f, 2028)
	_ok("a girl: 155 / 140.04 / 135 / 131", an_f.size() == 4 and absf(float(an_f[0].time) - 155.0) < 0.01 and absf(float(an_f[1].time) - 140.04) < 0.01
			and absf(float(an_f[2].time) - 135.0) < 0.01 and absf(float(an_f[3].time) - 131.0) < 0.01)
	game.athlete = a
	# Seasons: only the last three calendar years count; a DNF does not.
	game.athlete.results = [{"date": _d("2024-07-10"), "event": "800m", "time": 100.0}, {"date": _d("2027-07-10"), "event": "800m", "time": 0.0, "status": "dnf"},
			{"date": _d("2026-12-10"), "event": "800m", "time": 130.0}]
	_ok("the best of the last three seasons: 2024 is too old, a DNF is skipped (130 s)", absf(SA.best_time(game.athlete, 2028) - 130.0) < 0.001)
	# Options and cut-offs.
	var opts: Array = SA.options("Tampere")
	var sports := opts.filter(func(o): return str(o.kind) == "sports")
	_ok("16 sports lukiot (the Olympic Committee's 15 + Leppävaara's line) + the general lukio + the vocational school of the town; at most 7 wishes",
			sports.size() == data.urheilulukiot.schools.size() and sports.size() == 16 and opts.size() == 18 and int(ap.window.max_wishes) == 7)
	var ss0 = _fresh()
	var mk = SA.option("sports:makelanrinteen_lukio", "Tampere")
	var cut_mk: Dictionary = SA.cutoff(ss0, mk, 2028, false)
	var cut_kerttuli: Dictionary = SA.cutoff(ss0, SA.option("sports:kerttulin_lukio", "Tampere"), 2028, false)
	var cut_unknown: Dictionary = SA.cutoff(ss0, SA.option("sports:ounasvaaran_lukio", "Tampere"), 2028, false)
	_ok("cut-offs: Mäkelänrinne 16.09 (2025), Kerttuli the latest year 14.9 (2026), a school without a figure uses the estimate 14.8",
			absf(float(cut_mk.value) - 16.09) < 0.001 and int(cut_mk.year) == 2025 and absf(float(cut_kerttuli.value) - 14.9) < 0.001
			and bool(cut_unknown.estimated) and absf(float(cut_unknown.value) - 14.8) < 0.001)
	var n1: float = SA.cutoff(ss0, mk, 2028)["value"]
	var n2: float = SA.cutoff(ss0, mk, 2028)["value"]
	var n3: float = SA.cutoff(ss0, mk, 2029)["value"]
	_ok("the yearly wobble is the same every time it is asked and changes with the year", n1 == n2 and n1 != n3)
	_ok("the grade points: average 4 = 0, 7 = 5, 10 = 10", SA.grade_points(4.0) == 0.0 and absf(SA.grade_points(7.0) - 5.0) < 0.001 and SA.grade_points(10.0) == 10.0)
	_ok("an invitation needs the school's federation points: Lahti 2.1, Kuopio 1.8, Sotkamo 2.0, others 1.0",
			SA.invite_min(SA.option("sports:lahden_lyseo", "x")) == 2.1 and SA.invite_min(SA.option("sports:sotkamon_lukio", "x")) == 2.0
			and SA.invite_min(SA.option("sports:sammon_keskuslukio", "x")) == 1.0)
	_check_paths_and_stages(SA)
	_check_application_flow(SA, CM)
	_check_application_targets(SA)


## The stages from the path, the lukio's exam weeks against the real Helsinki calendar, the morning practice.
func _check_paths_and_stages(SA) -> void:
	print("   -- stages after grade 9")
	# An athlete born 2010 is in grade 10 in 2026-27: the lukio default path in Helsinki, compared with Helsingin kielilukio's real exam weeks.
	var a = _athlete()
	a.birth_date = {"year": 2010, "month": 5, "day": 1}
	a.hometown = "Helsinki"
	game.start_career(a, "repeat")
	var ss = game.get_system("school")
	ss._ensure_started()
	var real: Array = data.school.verified.lukio_example.periods
	var ok := true
	var shown := 0
	for p in real:
		var from: Dictionary = _d(str(p.exam_week[0]))
		var to: Dictionary = _d(str(p.exam_week[1]))
		var d: Dictionary = from
		var n := 0
		while Cal.date_key(d) <= Cal.date_key(to):
			if SCal.is_school_day("Helsinki", d):
				n += 1
				if not ss.is_exam_day(d):
					ok = false
					print("    %s is not an exam day (the school's period %d)" % [Cal.format_day(d), int(p.id)])
			d = game.add_days(d, 1)
		shown += n
	var total := 0
	var d2: Dictionary = _d("2026-08-12")
	while Cal.date_key(d2) <= Cal.date_key(_d("2027-06-05")):
		if ss.is_exam_day(d2):
			total += 1
		d2 = game.add_days(d2, 1)
	print("    Helsinki 2026-27 lukio: %d exam days from the rule, %d on the school's own dates" % [total, shown])
	_ok("the lukio's exam weeks from the periods rule cover every exam day of Helsingin kielilukio 2026-27 (5 weeks of 7 school days)", ok and total == shown and shown == 35)
	var exam_part := 0.0
	for p in ss.load_parts(_d("2026-09-28"), []):
		if str(p.id) == "exam":
			exam_part = float(p.value)
	_ok("a lukio stage has subjects and 3 years; an exam day carries the +2 exam load (x scale 1.0)", bool(ss.stage_of(_d("2026-09-28")).subjects)
			and int(ss.stage_of(_d("2026-09-28")).years) == 3 and exam_part == 2.0)
	# Paths: a sports lukio, a vocational school, a 10th grade; a 4th year does not exist yet.
	var b = _athlete()
	game.start_career(b, "repeat")
	var s2 = game.get_system("school")
	s2._ensure_started()
	s2.paths = [{"kind": "urheilulukio", "school": "sammon_keskuslukio", "town": "Tampere", "start_year": 2028, "years": 3}]
	s2._stage_cache = {}
	var st: Dictionary = s2.stage_of(_d("2029-09-01"))
	_ok("a sports lukio path: 2028-29 first year, 2030-31 the last (final), 2031-32 school is over",
			str(s2.stage_of(_d("2028-09-01")).id) == "urheilulukio" and int(st.year_index) == 1 and not bool(st.get("final", false))
			and bool(s2.stage_of(_d("2030-09-01")).get("final", false)) and str(s2.stage_of(_d("2031-09-01")).id) == "graduated")
	var tue := _d("2028-11-07")
	var mon := _d("2028-11-06")
	_ok("morning practice Tue / Wed / Fri at Sammo: a second session is not a double day then (Mon: it is)",
			s2.morning_day(tue) and s2.morning_day(_d("2028-11-08")) and s2.morning_day(_d("2028-11-10")) and not s2.morning_day(mon) and not s2.morning_day(_d("2028-11-09"))
			and not s2.is_double_on(tue, ["easy_run", "tempo_run"]) and s2.is_double_on(mon, ["easy_run", "tempo_run"]) and not s2.is_double_on(tue, ["easy_run", "drills"]))
	_ok("... and the life load follows: a double day on Tue 0, on Mon +1.5", s2.life_load(tue, ["easy_run", "tempo_run"]) == 0.0 and s2.life_load(mon, ["easy_run", "tempo_run"]) == 1.5)
	s2.paths = [{"kind": "lukio", "school": "", "town": "Tampere", "start_year": 2028, "years": 3}]
	s2._stage_cache = {}
	_ok("a general lukio has no morning practice", not s2.morning_day(tue) and s2.life_load(tue, ["easy_run", "tempo_run"]) == 1.5)
	s2.paths = [{"kind": "vocational", "school": "", "town": "Tampere", "start_year": 2028, "years": 3}]
	s2._stage_cache = {}
	s2._exam_days = {}
	s2._schedules = {}
	_ok("a vocational school: no subjects, no tests, no exam weeks", not bool(s2.stage_of(_d("2028-11-07")).subjects) and s2.tests_on(_d("2028-11-07")).is_empty()
			and not s2.is_exam_day(_d("2028-09-28")))
	s2.paths = [{"kind": "grade_10", "school": "", "town": "Tampere", "start_year": 2028, "years": 1}]
	s2._stage_cache = {}
	var after: Dictionary = s2.stage_of(_d("2029-09-01"))
	_ok("a 10th-grade year applies again (applies) and is followed by the default 3-year lukio", bool(s2.stage_of(_d("2028-11-07")).get("applies", false))
			and bool(s2.stage_of(_d("2028-11-07")).get("final", false)) and str(after.id) == "lukio" and str(s2.stage_of(_d("2031-09-01")).id) == "lukio"
			and str(s2.stage_of(_d("2032-09-01")).id) == "graduated")
	s2.paths = []
	s2._stage_cache = {}


## The application through the game loop: the tools' way (no stops, defaults), the real game's way (stops), moving, saving.
func _check_application_flow(SA, CM) -> void:
	print("   -- the application through the game loop")
	# A. The tools' way: nobody decides; the list becomes the general lukio of the town; no school stop appears.
	var ctx := _app_career(125.0)
	var ss = ctx.ss
	var seen := _play_to("2028-09-02")
	_ok("tools (no decisions): no school stop in the whole time up to the first lukio day", seen.filter(func(k): return str(k).begins_with("school")).is_empty())
	_ok("... the list was the general lukio of Tampere, a path was decided and the athlete stays (no move)", ss.paths.size() == 1 and str(ss.paths[0].kind) == "lukio"
			and str(ss.paths[0].school) == "" and bool(ss.application(2028).decided) and ss.application(2028).wishes == ["general"]
			and game.athlete.training_town == "" and str(ss.stage_of(game.date).id) == "lukio")
	_ok("... the test day found no sports wish: nothing to test", bool(ss.application(2028).test.done) and ss.application(2028).test.invited.is_empty())

	# B. The real game's way: the stops, the counsellor's list, the test steps, the results.
	SC.decisions_enabled = true
	var ctx2 := _app_career(125.0)
	var ss2 = ctx2.ss
	var policy := {"school_apply": "suggest", "school_test": "FIRST", "school_result": "accept"}
	var seen2 := _play_to("2028-08-02", policy)
	_ok("an arrival message on 1 August (a stop-free event) when the school is new", game.events.any(func(e): return str(e.source) == "school" and str(e.title) == str(data.application.arrival.title)))
	seen2.append_array(_play_to("2028-09-02", policy))
	var wishes: Array = ss2.application(2028).wishes
	print("    the counsellor's list for a top-of-the-class boy with 2:05.0 in Tampere: %s; stops: %s" % [", ".join(wishes), ", ".join(seen2.filter(func(k): return str(k).begins_with("school_") and str(k) != "school_card"))])
	_ok("the window opens with ONE stop (the list was filled, so no reminder)", _count(seen2, "school_apply") == 1)
	_ok("the counsellor's list: only sports lukiot of the own region (Pirkanmaa: Sammo) with athletics, then the general lukio last, at most 7",
			wishes.size() >= 1 and wishes.size() <= 7 and wishes.back() == "general" and wishes.all(func(w): return w == "general" or w == "sports:sammon_keskuslukio"))
	var test: Dictionary = ss2.application(2028).test
	_ok("an invited athlete gets the test day: three stops, the base counted from the physical test, the interview and the choices",
			_count(seen2, "school_test") == (3 if not test.invited.is_empty() else 0) and bool(test.done) and float(test.base) >= 0.0 and float(test.base) <= 5.0)
	_ok("results: one stop, a path decided that matches the first wish that said yes", _count(seen2, "school_result") == 1 and ss2.paths.size() == 1)
	var first_yes := "general"
	for r in ss2.application(2028).results:
		if str(r.status) == "yes":
			first_yes = str(r.wish)
			break
	var want_school := first_yes.trim_prefix("sports:") if first_yes.begins_with("sports:") else ""
	_ok("... %s -> %s" % [first_yes, ss2.paths[0].kind], str(ss2.paths[0].school) == want_school)
	_ok("the athlete's results lines name the wishes and why (the text of the stop is built from them)", ss2.application(2028).results.size() >= 1
			and SA.result_line(ss2.application(2028).results[0]).length() > 10)

	# C. Moving: a school in Kuortane. The club stays, the town changes, the old coach is far, the market has coaches of the new town.
	var CMs = CM
	CMs.enabled = true
	var ctx3 := _app_career(125.0)
	var ss3 = ctx3.ss
	_play_to("2028-06-14", {})
	var cm = game.get_system("market")
	cm.ensure_pool()
	var before: int = game.get_system("coach").coaches.size()
	ss3.paths.clear()
	ss3.applications["2028"].decided = false
	ss3._stage_cache = {}
	ss3._decide(2028, "sports:kuortaneen_urheilulukio")
	var head: Dictionary = game.get_system("coach").head()
	_ok("before the move the head coach is in the club's town (same)", C.distance_of(head, game.athlete) == "same" and game.athlete.training_town == "")
	_play_to("2028-08-03", {})
	_ok("1 August: the athlete lives in Kuortane (the club stays), the school follows the new town, the old coach is far away",
			game.athlete.training_town == "Kuortane" and game.athlete.club_id == "tap" and ss3.town() == "Kuortane" and C.home_town(game.athlete) == "Kuortane"
			and C.distance_of(head, game.athlete) == "far" and str(ss3.stage_of(game.date).id) == "urheilulukio")
	var coaches_after: int = game.get_system("coach").coaches.size()
	var academy: Dictionary = {}
	for c in game.get_system("coach").coaches.values():
		if str(c.get("market", {}).get("school", "")) == "kuortaneen_urheilulukio":
			academy = c
	_ok("the market got coaches of the new town (%d -> %d) and the school's academy coach: kind academy, offered, visible while at the school" % [before, coaches_after],
			coaches_after > before and not academy.is_empty() and str(academy.kind) == "academy" and cm.offer_open(str(academy.id)) and cm.visible(academy))
	ss3.paths = []
	ss3._stage_cache = {}
	cm.offers.erase(str(academy.id))
	_ok("... and invisible at another school (once the offer is gone)", not cm.visible(academy))
	_ok("a move leaves a message from the old coach (farewell) and the group", game.get_system("moments").threads.get("coach", []).any(func(m): return str(m.text).contains("Kuortane"))
			or game.get_system("moments").threads.has("group"))
	CMs.enabled = false

	# D. Save / load: paths, applications and the training town come back and the game goes on the same.
	var ctx4 := _app_career(125.0)
	var ss4 = ctx4.ss
	_play_to("2028-06-14", {"school_apply": "suggest", "school_test": "FIRST", "school_result": "accept"})
	var snap := _json(game.to_dict())
	_play_to("2028-09-05", {})
	var end1 := _json(game.get_system("school").to_dict()) + _json(game.athlete.to_dict())
	game.from_dict(_parse(snap))
	_play_to("2028-09-05", {})
	var end2 := _json(game.get_system("school").to_dict()) + _json(game.athlete.to_dict())
	_ok("a loaded game goes on exactly as without saving (paths, application, test, arrival)", end1 == end2)
	_ok("the saved school state carries paths and apps; an older state without them loads with none", snap.contains("\"paths\"") and snap.contains("\"apps\""))
	var old: Dictionary = game.to_dict()
	old.systems.school.erase("paths")
	old.systems.school.erase("apps")
	game.from_dict(old)
	_ok("... and then plays the default lukio", game.get_system("school").paths.is_empty() and str(game.get_system("school").stage_of(_d("2028-09-02")).id) == "lukio")
	SC.decisions_enabled = false


## The balance target (GDD 4.9.7): which cut-offs are reachable for which athlete. The points an athlete has at the end of
## grade 9 (the school answer x the effort of the year, the grades after a year of drift) plus the sport points of an 800 m result.
func _check_application_targets(SA) -> void:
	print("   -- who can reach which cut-off (GDD 4.9.7: 'Doing fine' or better with Normal effort, 'Struggling' needs a Heavy grade 9)")
	var names := ["top", "hard_work", "fine", "struggling", "dont_care"]
	var efforts := ["normal", "heavy"]
	var times := {"2:05 (TF-juniorit)": 125.0, "2:00": 120.0, "2:15": 135.0}
	_app_career(125.0)
	var rows := []
	var table := {}
	for ai in names.size():
		for effort in efforts:
			var ss = _school_for(ai, 0)
			ss.set_effort(effort)
			# grade 8 to the end of grade 9 (2 Nov 2026 - 3 Jun 2028 is long; the average after 1.5 years of drift)
			var d := _d("2026-11-02")
			for k in 580:
				ss.on_day_end({"date": d, "record": {}})
				d = game.add_days(d, 1)
			var avg: float = SA.average_now(ss)
			table["%s/%s" % [names[ai], effort]] = avg
	for key in table:
		rows.append("%s %.2f" % [key, table[key]])
	print("    academic + PE average at the end of grade 9: " + ", ".join(rows))
	# The points of each combination against a few cut-offs.
	var cuts := {"Espoo 12.8": 12.77, "Schildt 13.8": 13.81, "Kerttuli 14.9": 14.9, "Lahti 15.0": 15.0, "Mäkelänrinne 16.1": 16.09}
	var school_pts := 3.3
	print("    points = grades + sport + %.1f school points (a middling test day); 'x' = at or over the limit" % school_pts)
	for tk in times:
		var line := "    %s:" % tk
		var a2 = _athlete()
		game.athlete = a2
		game.athlete.results = [{"date": _d("2027-07-10"), "event": "800m", "time": float(times[tk])}]
		var sport := float(SA.sport_points(game.athlete, 2028).total)
		line += " sport %.1f" % sport
		print(line)
		for key in table:
			var total: float = SA.grade_points(float(table[key])) + sport + school_pts
			var marks := []
			for ck in cuts:
				marks.append(("x " if total >= float(cuts[ck]) else ". ") + ck.split(" ")[0])
			print("      %-18s avg %.2f -> %.1f points   %s" % [key, float(table[key]), total, "  ".join(marks)])
	# The target as checks: "Doing fine" with Normal effort and a TF-juniorit-level result reaches the lowest sports lukio limits;
	# "Struggling" with Normal effort does not, with a Heavy grade 9 it does.
	var fine_n: float = table["fine/normal"]
	var str_n: float = table["struggling/normal"]
	var str_h: float = table["struggling/heavy"]
	game.athlete.results = [{"date": _d("2027-07-10"), "event": "800m", "time": 126.03}]
	var sport_tf := float(SA.sport_points(game.athlete, 2028).total)
	var low_cut := 12.77   # the lowest published limit (Espoo's sports line)
	var p_fine: float = SA.grade_points(fine_n) + sport_tf + school_pts
	var p_str_n: float = SA.grade_points(str_n) + sport_tf + school_pts
	var p_str_h: float = SA.grade_points(str_h) + sport_tf + school_pts
	print("    TF-juniorit result + a middling test (3.3): Doing fine/Normal %.1f, Struggling/Normal %.1f, Struggling/Heavy %.1f; the lowest limit is %.2f" % [p_fine, p_str_n, p_str_h, low_cut])
	_ok("a 'Doing fine' athlete with Normal effort and a TF-juniorit result reaches the lowest limit (Espoo 12.77): %.1f" % p_fine, p_fine >= low_cut)
	_ok("a 'Struggling' athlete with Normal effort does not (%.1f), with a Heavy grade 9 it does (%.1f)" % [p_str_n, p_str_h], p_str_n < low_cut and p_str_h >= low_cut)


# --- 15. Lukio courses (session S3b) ----------------------------------------------------------------------------------------------

## A career whose athlete is born in `year` (2010: lukio year 1 in 2026-27, 2009: year 2), in Helsinki (the verified lukio calendar).
func _lukio_career(year: int, sports := false):
	var a = _athlete(1)
	a.birth_date = {"year": year, "month": 5, "day": 1}
	a.hometown = "Helsinki"
	game.start_career(a, "repeat")
	var ss = game.get_system("school")
	ss._ensure_started()
	if sports:
		ss.paths = [{"kind": "urheilulukio", "school": "makelanrinteen_lukio", "town": "Helsinki", "start_year": year + 16, "years": 3, "arrived": true}]
		ss._stage_cache = {}
	return ss


func _plan_counts(L: Dictionary) -> Dictionary:
	var out := {"plan": 0, "done": 0, "comp": 0, "opt": 0, "coach": 0, "drop": 0}
	for u in L.units:
		if str(u.st) in ["plan", "done"]:
			out[str(u.st)] += 1
			out[str(u.k)] += 1
		elif str(u.st) == "drop":
			out.drop += 1
	return out


func _check_lukio() -> void:
	print("-- 15. lukio courses (session S3b)")
	var LK = load("res://scripts/core/lukio.gd")
	var lk: Dictionary = data.lukio
	# Data: the decree's compulsory credits are the courses of the game.
	var short := {"maths": "short", "b3": "none", "music_art": "music", "sports": false, "years": 3}
	var long := short.duplicate()
	long.maths = "long"
	var sum_short := 0
	var sum_long := 0
	for s in lk.subjects.list:
		sum_short += LK.comp_count(str(s.id), short)
		sum_long += LK.comp_count(str(s.id), long)
	print("    compulsory courses: short maths %d (%d credits), long maths %d (%d credits)" % [sum_short, sum_short * 2, sum_long, sum_long * 2])
	_ok("the game's compulsory courses are the decree's 94 / 102 credits (810/2018 Annex 1)", sum_short * 2 == int(lk.decree.compulsory_total[0]) and sum_long * 2 == int(lk.decree.compulsory_total[1]))
	var dec: Dictionary = lk.decree.rows
	_ok("per subject as in the decree (Finnish 12 + 6, English 12 + 4, Swedish 10 + 4, physics 2 + 12, long maths 18 + 6 ...)",
			LK.comp_count("finnish", short) * 2 == int(dec.finnish.compulsory) and LK.opt_count("finnish", short) * 2 == int(dec.finnish.optional)
			and LK.comp_count("english", short) * 2 == int(dec.a_language.compulsory) and LK.opt_count("swedish", short) * 2 == int(dec.b1_language.optional)
			and LK.opt_count("physics", short) * 2 == int(dec.physics.optional) and (LK.comp_count("maths", long) - 1) * 2 == int(dec.maths_long.compulsory)
			and LK.opt_count("maths", long) * 2 == int(dec.maths_long.optional) and LK.comp_count("health_ed", short) * 2 == int(dec.health_ed.compulsory))

	# A. The tools' way: a lukio that starts in the middle of its first year (born 2010, Helsinki, from 2 Nov 2026).
	var ss = _lukio_career(2010)
	_play_to("2026-11-04")
	var L: Dictionary = ss.lukio
	var c := _plan_counts(L)
	print("    started: maths %s, %d years, %d courses (%d compulsory, %d optional), %d done" % [L.maths, int(L.years), c.plan + c.done, c.comp, c.opt, c.done])
	_ok("a lukio starts by itself in a lukio stage (tools: the counsellor's choices, no stop) with 75 courses, every compulsory one, at least 10 optional",
			not L.is_empty() and bool(L.chosen) and c.plan + c.done == 75 and c.comp == sum_short + (4 if str(L.maths) == "long" else 0) and c.opt >= 10)
	_ok("... started in period 2: period 1's courses are done with grades 4-10 (or passed), the subject list is the lukio's",
			L.units.filter(func(u): return int(u.p) == 0).all(func(u): return str(u.st) == "done" and (int(u.g) >= 4 or int(u.g) == -1))
			and ss.subject_list().any(func(s): return str(s.id) == "philosophy") and not ss.subject_list().any(func(s): return str(s.id) == "crafts"))
	var per_year := [0, 0, 0]
	var per_period := []
	for p in 15:
		var n: int = LK.courses_in(L, p).size()
		per_period.append(n)
		per_year[p / 5] += n
	print("    courses per period: %s (years %s)" % [str(per_period), str(per_year)])
	_ok("the plan: year 1 at least 30 courses (the 60 credits of Mäkelänrinne's rule), the last year lightest, no courses in the abi's last period",
			per_year[0] >= 30 and per_year[2] < per_year[1] and per_period[14] == 0)
	# The exam week: each academic course of a period has one exam in its exam week.
	var p2: Dictionary = LK.period_info(ss, L, 1)
	var sched: Dictionary = LK.exam_schedule(ss, L, 1)
	var n_exams := 0
	var in_week := true
	for k in sched:
		n_exams += (sched[k] as Array).size()
		in_week = in_week and p2.exam.any(func(d): return Cal.date_key(d) == int(k))
	var n_academic: int = LK.courses_in(L, 1).filter(func(u): return LK.kind_of(str(u.s)) == "academic").size()
	_ok("period 2's %d academic courses have one exam each, all in its exam week (%s - %s)" % [n_academic, Cal.format_day(p2.exam[0]), Cal.format_day(p2.exam.back())],
			n_exams == n_academic and in_week and n_academic > 0)
	_play_to("2026-12-03")
	var graded: Array = L.units.filter(func(u): return int(u.p) == 1 and str(u.st) == "done")
	_ok("after period 2's exam week every course of it is graded (a failed one goes to the next exam week once)",
			LK.courses_in(L, 1).all(func(u): return str(u.st) == "done" or bool(u.r)) and graded.size() > 0)
	_ok("... a period report was kept with the subject grades (the average of the courses)", str(ss.reports.back().kind) == "period"
			and int(ss.reports.back().grades.get("finnish", 0)) == LK.subject_grade(L, "finnish"))
	_ok("no Christmas report card in a lukio", not ss.reports.any(func(r): return str(r.kind) == "christmas"))
	# The life load: classroom courses above five weigh, fewer weigh less; the exam week keeps its own +2.
	var p3: Dictionary = LK.period_info(ss, L, 2)
	var day3: Dictionary = p3.start
	while not SCal.is_school_day("Helsinki", day3) or ss.is_exam_day(day3):
		day3 = game.add_days(day3, 1)
	var n3: int = LK.class_count(L, 2)
	var want := float(n3 - 5) * 0.25
	var got := 0.0
	for part in ss.load_parts(day3, []):
		if str(part.id).begins_with("courses"):
			got = float(part.value)
	_ok("a school day of period 3 (%d classroom courses) weighs %+.2f (= (n - 5) x 0.25)" % [n3, got], absf(got - want) < 0.0001)
	# Grades through the game: the course grades sit around the levels.
	var gsum := 0.0
	var lsum := 0.0
	var gn := 0
	for u in graded:
		if int(u.g) >= 4:
			gsum += int(u.g)
			lsum += ss.level(str(u.s))
			gn += 1
	print("    period 2 grades: mean %.2f against the levels' %.2f (%d courses)" % [gsum / maxf(1, gn), lsum / maxf(1, gn), gn])
	_ok("course grades follow the levels (mean within 0.6)", gn > 0 and absf(gsum / gn - lsum / gn) < 0.6)

	# B. Four years and long -> short maths.
	var ss4 = _lukio_career(2010)
	_play_to("2026-11-04")
	var before4 := _plan_counts(ss4.lukio)
	var class_before: int = LK.class_count(ss4.lukio, 3)
	_ok("3 -> 4 years is allowed in year 1", ss4.can_change_years() and ss4.set_lukio_years(4))
	var c4 := _plan_counts(ss4.lukio)
	_ok("4 years: the path is 4 years, the 2029-30 school year is the final one, still 75 courses, 20 periods",
			int(ss4.lukio.years) == 4 and bool(ss4.stage_of(_d("2029-09-01")).get("final", false)) and not bool(ss4.stage_of(_d("2028-09-01")).get("final", false))
			and c4.plan + c4.done == 75 and LK.period_count(ss4.lukio) == 20 and before4.done == c4.done)
	print("    period 4 classroom courses: 3 years %d, 4 years %d" % [class_before, LK.class_count(ss4.lukio, 3)])
	_ok("... with fewer classroom courses a period (lighter school days)", LK.class_count(ss4.lukio, 3) < class_before)
	ss4.lukio.maths = "long"   # (force the long syllabus to try the switch)
	ss4._replan(2)
	var long_units: int = ss4.lukio.units.filter(func(u): return str(u.s) == "maths" and str(u.st) in ["plan", "done"]).size()
	_ok("long maths -> short maths: allowed, the maths courses become the short syllabus's and the plan is 75 courses again",
			ss4.can_short_maths() and ss4.to_short_maths() and str(ss4.lukio.maths) == "short"
			and ss4.lukio.units.filter(func(u): return str(u.s) == "maths" and str(u.st) in ["plan", "done"]).size() < long_units
			and _plan_counts(ss4.lukio).plan + _plan_counts(ss4.lukio).done == 75 and not ss4.can_short_maths())

	# C. The period's courses: later / add / drop, and leaving out compulsory courses in a sports lukio.
	var ss5 = _lukio_career(2010, true)
	_play_to("2026-12-02")   # the first school day of period 3
	var p := int(ss5.editable_period())
	_ok("on a period's first day its courses can be changed (period 3: %d)" % p, p == 2)
	var L5: Dictionary = ss5.lukio
	_ok("a sports lukio has its 12 coaching courses", _plan_counts(L5).coach == 12)
	var cur: Array = LK.courses_in(L5, p)
	var a_comp: Dictionary = cur.filter(func(u): return str(u.k) == "comp")[0]
	_ok("Later: a course moves out of the period, the whole stays 75", ss5.course_later(str(a_comp.id)) and int(a_comp.p) > p
			and _plan_counts(L5).plan + _plan_counts(L5).done == 75)
	var cands: Array = ss5.add_candidates(p)
	var add: Dictionary = cands[0]
	_ok("Add: an optional course comes into the period (by the player), still 75 in all", ss5.course_add(str(add.id)) and int(add.p) == p and str(add.by) == "player"
			and _plan_counts(L5).plan + _plan_counts(L5).done == 75)
	_ok("Drop: the added optional course goes out and the counsellor does not add it back", ss5.course_drop(str(add.id)) and str(add.st) == "pool"
			and str(add.by) == "player_out")
	# Leaving out: not in an exam subject (Finnish), yes in history (not in the plan's exams), at most half of a subject.
	var fin: Dictionary = L5.units.filter(func(u): return str(u.s) == "finnish" and str(u.k) == "comp" and str(u.st) == "plan")[0]
	var subj := ""
	for s in ["history", "social_studies", "geography", "chemistry", "physics", "biology"]:
		if not L5.matric.plan.keys().any(func(ex): return str(data.lukio.matric.exams.filter(func(e): return str(e.id) == str(ex))[0].subject) == s):
			subj = s
			break
	var hist: Array = L5.units.filter(func(u): return str(u.s) == subj and str(u.k) == "comp" and str(u.st) == "plan")
	for u in hist:
		u.p = p
	_ok("leaving out a compulsory course: never in an exam subject (Finnish)", not LK.can_drop_comp(L5, fin))
	var dropped := 0
	for u in hist:
		if ss5.course_drop(str(u.id)):
			dropped += 1
	var comp_n: int = LK.comp_count(subj, L5)
	print("    %s: %d compulsory, %d left out" % [subj, comp_n, dropped])
	_ok("... in %s at most half of its compulsory courses (%d of %d), and 75 courses in all again" % [subj, dropped, comp_n],
			dropped == comp_n - ceili(comp_n / 2.0) and _plan_counts(L5).plan + _plan_counts(L5).done == 75)
	var back: Dictionary = L5.units.filter(func(u): return str(u.st) == "drop")[0]
	_ok("Put back: a left-out course comes back into the period", ss5.course_put_back(str(back.id)) and str(back.st) == "plan" and int(back.p) == p)
	var general = _lukio_career(2010)
	_play_to("2026-12-02")
	var g_fin: Dictionary = general.lukio.units.filter(func(u): return str(u.s) == "history" and str(u.k) == "comp" and str(u.st) == "plan")[0]
	_ok("a general lukio cannot leave out compulsory courses", not LK.can_drop_comp(general.lukio, g_fin))

	# D. The real game's way: the choices, a courses stop at each period's start and a results stop at its end.
	SC.decisions_enabled = true
	var ss6 = _lukio_career(2011)   # lukio from August 2027
	var seen := _play_to("2027-10-13", {"lukio_choice": "german"})
	var kinds := seen.filter(func(k): return str(k).begins_with("lukio"))
	print("    stops from the first lukio day to 13 Oct 2027: %s" % ", ".join(kinds))
	_ok("the first lukio day: three choice stops (maths, a language, the years), then period 1's courses", _count(seen, "lukio_choice") == 3
			and kinds.find("lukio_courses") > kinds.rfind("lukio_choice"))
	_ok("... period 1 ends with a results stop and period 2 starts with a courses stop (two separate stops, user)",
			_count(seen, "lukio_results") == 1 and _count(seen, "lukio_courses") == 2)
	_ok("an answer that is no option keeps the counsellor's pick (maths, 3 years); German was taken and its courses are in",
			str(ss6.lukio.maths) in ["long", "short"] and str(ss6.lukio.b3) == "german" and int(ss6.lukio.years) == 3 and ss6.lukio.units.any(func(u): return str(u.s) == "b3")
			and ss6.subject_list().any(func(s): return str(s.name) == "German"))
	SC.decisions_enabled = false

	# Speed: a lukio day against a grade 8 day (the long tools play thousands of days).
	_lukio_career(2012)
	var t0 := Time.get_ticks_usec()
	_play_to("2027-01-31")
	var ms8 := (Time.get_ticks_usec() - t0) / 1000.0 / 90.0
	_lukio_career(2010)
	t0 = Time.get_ticks_usec()
	_play_to("2027-01-31")
	var ms_l := (Time.get_ticks_usec() - t0) / 1000.0 / 90.0
	print("    time per played day (health off): grade 8 %.2f ms, lukio %.2f ms" % [ms8, ms_l])
	_ok("a lukio day costs at most a few ms more than a grade 8 day", ms_l < ms8 + 5.0)

	# E. Save / load in a lukio: the game goes on exactly as without saving.
	var ss7 = _lukio_career(2010)
	_play_to("2026-11-20")
	var snap := _json(game.to_dict())
	_play_to("2027-02-15")
	var end1 := _json(game.get_system("school").to_dict()) + _json(game.athlete.to_dict())
	game.from_dict(_parse(snap))
	_play_to("2027-02-15")
	var end2 := _json(game.get_system("school").to_dict()) + _json(game.athlete.to_dict())
	if end1 != end2:
		var i := 0
		while i < mini(end1.length(), end2.length()) and end1[i] == end2[i]:
			i += 1
		print("    first difference at %d:\n      %s\n      %s" % [i, end1.substr(maxi(0, i - 160), 240).replace("\n", " "), end2.substr(maxi(0, i - 160), 240).replace("\n", " ")])
	_ok("a loaded lukio goes on exactly as without saving (courses, exams, grades)", end1 == end2 and snap.contains("\"lukio\"") and not ss7.lukio.is_empty())


# --- 16. The matriculation exams (session S3b) -----------------------------------------------------------------------------------

func _check_matric() -> void:
	print("-- 16. the matriculation exams (session S3b)")
	var M = load("res://scripts/core/matriculation.gd")
	# Dates.
	_ok("spring 2027 from the board's list: Finnish reading 16 Mar, English (long) 22 Mar, maths 24 Mar, results 19 May",
			Cal.date_key(M.exam_dates("s2027", "finnish")[0]) == 20270316 and Cal.date_key(M.exam_dates("s2027", "finnish")[1]) == 20270319
			and Cal.date_key(M.exam_dates("s2027", "english")[0]) == 20270322 and Cal.date_key(M.exam_dates("s2027", "maths")[0]) == 20270324
			and Cal.date_key(M.results_date("s2027")) == 20270519 and M.verified("s2027"))
	_ok("later sessions by the rule (estimated): spring 2030 starts Tue 12 Mar, autumn 2030 Mon 16 Sep; deadlines 20 Nov 2029 / 20 May 2030",
			Cal.date_key(M.first_day("s2030")) == 20300312 and Cal.date_key(M.first_day("a2030")) == 20300916
			and Cal.date_key(M.deadline("s2030")) == 20291120 and Cal.date_key(M.deadline("a2030")) == 20300520 and not M.verified("s2030"))
	_ok("the three sessions of a lukio from 2028: spring 2030, autumn 2030, spring 2031 (4 years: spring 2031, autumn 2031, spring 2032)",
			M.sessions_for(2028, 3) == ["s2030", "a2030", "s2031"] and M.sessions_for(2028, 4) == ["s2031", "a2031", "s2032"])
	# The rules.
	var L := {"maths": "short", "b3": "none"}
	_ok("the board's rules: Finnish + English + maths + Swedish + history pass", bool(M.check(["finnish", "english", "maths", "swedish", "history"], L).ok))
	_ok("... without Finnish no; with four exams no", not bool(M.check(["english", "maths", "swedish", "history", "biology"], L).ok)
			and not bool(M.check(["finnish", "english", "maths", "swedish"], L).ok))
	_ok("... Finnish + four realia subjects: only one group, no", not bool(M.check(["finnish", "history", "biology", "chemistry", "geography"], L).ok))
	_ok("... no long-syllabus exam (short maths, Swedish, two realia) no; with long maths yes",
			not bool(M.check(["finnish", "maths", "swedish", "history", "chemistry"], L).ok) and bool(M.check(["finnish", "maths", "swedish", "history", "chemistry"], {"maths": "long"}).ok))
	_ok("... two realia subjects of the same day in one session no", not bool(M.check(["finnish", "english", "maths", "history", "biology"], L, {"history": "s2030", "biology": "s2030"}).ok))
	_calibrate_matric(M)

	# Through the game, the tools' way: born 2009 (lukio year 2 in 2026-27): the spring 2027 session is the first.
	var ss = _lukio_career(2009)
	_play_to("2026-11-22")
	var Lm: Dictionary = ss.lukio
	print("    the counsellor's plan: %s" % str(Lm.matric.plan))
	_ok("the counsellor's plan passes the rules and uses the three sessions spring 2027 / autumn 2027 / spring 2028",
			bool(M.check(ss.matric_set(), Lm, Lm.matric.plan).ok) and ss.matric_main_sessions() == ["s2027", "a2027", "s2028"])
	_ok("the spring 2027 session was registered at its deadline (20 Nov): English", "s2027" in Lm.matric.locked and Lm.matric.registered.s2027 == ["english"]
			and not ss.set_matric("history", "s2027"))
	var mon := _d("2027-03-22")
	var parts: Array = ss.load_parts(mon, [])
	_ok("the exam day weighs +3 (a matriculation exam) and is marked for the week strip", parts.any(func(x): return str(x.id) == "matric" and float(x.value) == 3.0)
			and ss.day_info(mon).get("matric", []) == ["english"])
	_play_to("2027-05-20")
	_ok("results on 19 May 2027: English got a grade L-I", Lm.matric.results.size() == 1 and str(Lm.matric.results[0].exam) == "english"
			and str(Lm.matric.results[0].grade) in ["L", "E", "M", "C", "B", "A", "I"])
	print("    English (long): %s; the level was %.2f" % [str(Lm.matric.results[0].grade), ss.level("english")])
	# The meet-and-tests decision sees a matriculation exam (a race in the week of the autumn session).
	_play_to("2027-09-12")
	var monday := _d("2027-09-13")
	var meet: Dictionary = _add_test_meet(monday)
	var old_entries: Array = game.entries.duplicate()
	game.entries = [str(meet.key)]
	var clash: Dictionary = ss.meet_test_clash(monday)
	game.entries = old_entries
	var reg_a: Array = Lm.matric.registered.get("a2027", [])
	_ok("a race in a week with a matriculation exam asks (the exam is in the list): %s" % ", ".join(clash.get("list", [])),
			reg_a.is_empty() or (not clash.is_empty() and ", ".join(clash.list).contains("on ")))
	_drop_test_meet()
	# To the end: the certificate after the last spring and the final card (or a retake).
	_play_to("2028-06-10")
	var best: Dictionary = ss.matric_best()
	print("    results: %s; certificate %s" % [str(Lm.matric.results.map(func(r): return "%s %s %s" % [r.session, r.exam, r.grade])), str(Lm.matric.cert)])
	var failed := best.values().any(func(g): return str(g) == "I")
	_ok("lukio done (the final card) and the certificate when every required exam passed (or a failed one is planned again)",
			bool(Lm.done) and (bool(Lm.matric.cert) or (failed and not Lm.matric.plan.is_empty())))

	# The real game's way: the plan stop, a stop per session, the exam days, the results; skipping = a failed exam and a retake.
	SC.decisions_enabled = true
	var ss2 = _lukio_career(2009)
	var seen := _play_to("2027-05-20", {"matric_exam": "skip"})
	var mk := seen.filter(func(k): return str(k).begins_with("matric"))
	print("    stops: %s" % ", ".join(mk))
	_ok("one plan stop, a registration stop for spring 2027 and for autumn 2027, one exam-day stop, one results stop", _count(seen, "matric_plan") == 3 and _count(seen, "matric_exam") == 1
			and _count(seen, "matric_results") == 1)
	var r0: Dictionary = ss2.lukio.matric.results[0]
	_ok("a skipped exam is a failed one (absent) and goes into the next session's plan as a retake", str(r0.grade) == "I" and bool(r0.absent)
			and str(ss2.lukio.matric.plan.get("english", "")) == "a2027")
	_ok("the retake is allowed after the main sessions too; a new exam only in the main three",
			ss2.matric_allowed("english", "a2027") and not ss2.matric_allowed("geography", "a2028"))
	SC.decisions_enabled = false


## The score thresholds against the board's shares: the game's lukio students (the five school answers equally, a level of
## natural + a typical bonus at Normal effort) and the grade each would get.
func _calibrate_matric(M) -> void:
	var lk: Dictionary = data.lukio
	var sc: Dictionary = lk.matric.score
	var scores := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var answers := ["top", "hard_work", "fine", "struggling", "dont_care"]
	var apt: Dictionary = data.school_life.aptitude
	for i in 4000:
		var nat := float(data.school_life.answers[answers[i % 5]].natural)
		var lv := nat + clampf(rng.randfn(0.0, float(apt.sd)), -float(apt.max), float(apt.max)) + float(lk.levels.lukio_shift)
		var bonus := minf(float(sc.bonus_max), rng.randi_range(1, 4) * float(sc.bonus_per_optional))
		scores.append(lv + bonus + rng.randfn(0.0, float(sc.sd)))
	scores.sort()
	scores.reverse()
	var counts := {}
	for s in scores:
		var g: String = M.grade_for(float(s))
		counts[g] = int(counts.get(g, 0)) + 1
	var line := []
	var cum := 0.0
	var fitted := []
	var ok := true
	for g in lk.matric.grades:
		var share := float(counts.get(str(g.id), 0)) / scores.size()
		line.append("%s %.1f %% (board %.0f %%)" % [str(g.id), share * 100.0, float(g.share) * 100.0])
		ok = ok and absf(share - float(g.share)) < 0.04
		cum += float(g.share)
		if str(g.id) != "I":
			fitted.append("%.2f" % float(scores[mini(scores.size() - 1, int(cum * scores.size()))]))
	print("    grade shares of the game's lukio students: " + ", ".join(line))
	print("    thresholds that would fit exactly: [%s]" % ", ".join(fitted))
	_ok("the score thresholds give about the board's shares (each within 4 points)", ok)


# --- Helpers ---------------------------------------------------------------------------------------------------------------------

## A new career on the coach's repeating week; returns its school (started).
func _fresh():
	game.start_career(_athlete(), "repeat")
	var ss = game.get_system("school")
	ss._ensure_started()
	return ss


## Plays n weeks by the date, answering every stop event "ok" (the health model's "sore" warnings: a stop on any day, even
## Sunday evening, would keep `while advance_day() != WEEK_DONE` going for ever).
func _play_weeks(n: int) -> void:
	for w in n:
		var monday: int = Cal.date_key(game.add_days(game.week_monday(), 7))
		while Cal.date_key(game.date) < monday:
			game.advance_day()
			while not game.pending_event().is_empty():
				game.answer_event(game.pending_event().id, "ok")


## The test athlete (training_balance's): every creation answer the first, unless `school_index` picks the school answer.
func _athlete(school_index := 0):
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = school_index if str(q.id) == "school" else 0
	return load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)


## Reads a JSON text exactly like a save is read (every decimal exact, see SaveGame.load_slot).
func _parse(text: String) -> Variant:
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	return parsed


func _json(v: Variant) -> String:
	var text := JSON.stringify(v, "", true, true)
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	return JSON.stringify(parsed, "", true, true)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1
