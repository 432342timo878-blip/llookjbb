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
	_ok("2 Nov 2026 grade 8, 1 Jul 2027 still grade 8 (its summer), 1 Sep 2027 grade 9, 1 Sep 2028 the placeholder",
			str(ss.stage_of(_d("2026-11-02")).id) == "grade_8" and str(ss.stage_of(_d("2027-07-01")).id) == "grade_8"
			and str(ss.stage_of(_d("2027-09-01")).id) == "grade_9" and str(ss.stage_of(_d("2028-09-01")).id) == "secondary")


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
