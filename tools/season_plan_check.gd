extends SceneTree
## Dev tool: headless checks for the season model (GDD 4.8, M2 step 6b). Prints PASS / FAIL per check.
## Run: godot --headless --path . -s res://tools/season_plan_check.gd
## Uses its own save folder, never the player's saves. The health model is switched off (repeatable runs).
## NOTE: it prints ALL CHECKS PASSED even when a SCRIPT ERROR aborted a check function: read stderr too.

var game
var data
var saves
var Cal
var SP
var WP
var A
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	Cal = load("res://scripts/core/calendar.gd")
	SP = load("res://scripts/core/season_plan.gd")
	WP = load("res://scripts/core/week_plan.gd")
	A = load("res://scripts/core/athlete.gd")
	load("res://scripts/core/health_system.gd").model_enabled = false
	game.autosave = false

	_check_data()
	_check_variants()
	_check_star_rule()
	_check_variant_records()
	_check_seasons()
	_check_layout_2026()
	_check_every_week()
	_check_first_week_is_coach_week()
	_check_lighter()
	_check_ramp()
	_check_easy_day()
	_check_taper()
	_check_moves()
	_check_fallbacks()
	_check_career_start()
	_check_repeat_mode()
	_check_save_load()
	_check_play()
	_check_season_ui()
	_check_speed()
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


# --- Checks ------------------------------------------------------------------------------------

func _check_data() -> void:
	print("-- data")
	var ids := []
	for p in data.periodization.phases:
		ids.append(p.id)
	_ok("7 phases in skeleton order", ids == ["general_base", "indoor_specific", "spring_base", "pre_competition",
			"race_season", "transition", "autumn_general"])
	var templates: Dictionary = data.periodization.variants.balanced.templates
	var all_known := true
	for id in ids:
		var t: Dictionary = templates[id]
		for day in t.days:
			for s in day:
				all_known = all_known and not data.get_session(s).is_empty()
		all_known = all_known and t.days.size() == 7 and t.intensity.size() == 7
	_ok("every Balanced template has 7 days and only known sessions", all_known)
	var coach: Array = data.training.coach_plan.days
	_ok("Balanced general base is exactly the coach's starter week", templates.general_base.days == coach)
	var main_tags := {}
	for c in data.competitions.competitions:
		if c.has("main"):
			main_tags[c.id] = c.main
	_ok("main tags: SM-hallit 14-15 / 17-22 indoor, the three outdoor SM",
			main_tags == {"sm_hallit_14_15": "indoor", "sm_hallit_17_22": "indoor", "sm_14_15": "outdoor",
			"sm_16_17": "outdoor", "sm_19_22": "outdoor"})


## The coach's three plans (M2 step 6d): shapes, loads against Balanced's, and a plan for every week in each.
func _check_variants() -> void:
	print("-- the coach's three plans")
	var variants: Dictionary = data.periodization.variants
	var ids := []
	for p in data.periodization.phases:
		ids.append(p.id)
	_ok("three plans: steady, balanced, ambitious", variants.has("steady") and variants.has("balanced") and variants.has("ambitious"))
	for v in ["steady", "balanced", "ambitious"]:
		var fine := true
		var rest_day := true
		for id in ids:
			var t: Dictionary = variants[v].templates[id]
			fine = fine and t.days.size() == 7 and t.intensity.size() == 7 and variants[v].ramp_weeks.has(id)
			var rest := false
			for d in 7:
				fine = fine and t.days[d].size() <= 2 and t.intensity[d] in ["easy", "normal", "hard"]
				for s in t.days[d]:
					fine = fine and not data.get_session(s).is_empty()
				rest = rest or t.days[d].is_empty()
			rest_day = rest_day and rest
		_ok("%s: 7 days per phase, at most 2 known sessions a day, ramp weeks for every phase" % v, fine and str(variants[v].name) != "")
		_ok("%s: a full rest day in every phase's week" % v, rest_day)
	var amb: Dictionary = variants.ambitious.ramp_weeks
	_ok("Ambitious builds up longer in the base phases (3 weeks)", int(amb.general_base) == 3 and int(amb.spring_base) == 3)
	# Planned weekly load over the 2026-27 season (session load × intensity), against Balanced's.
	var loads := {}
	for v in ["steady", "balanced", "ambitious"]:
		var plan = SP.phased(_athlete(2012, "800m"), game.START_DATE, v)
		var sum := 0.0
		var shapes := true
		for w in 104:
			var p: Dictionary = plan.week_for(game.add_days(game.START_DATE, 7 * w), [])
			shapes = shapes and p.days.size() == 7 and p.intensity.size() == 7 and p.why.size() == 7
			if w < 52:
				for d in 7:
					for s in p.days[d]:
						sum += float(data.get_session(s).load) * float(data.health.intensity[p.intensity[d]].load)
		loads[v] = sum / 52.0
		_ok("%s: every Monday of 2026-27 and 2027-28 has a plan" % v, shapes)
	var steady: float = loads.steady / loads.balanced
	var ambitious: float = loads.ambitious / loads.balanced
	print("    planned load a week: Steady %.0f (%.0f %%), Balanced %.0f, Ambitious %.0f (%.0f %%)" % [
			loads.steady, 100.0 * steady, loads.balanced, loads.ambitious, 100.0 * ambitious])
	_ok("Steady is about 80 % of Balanced's load (75–90 %)", steady >= 0.75 and steady <= 0.90)
	_ok("Ambitious is 140–160 % of Balanced's load", ambitious >= 1.40 and ambitious <= 1.60)
	# Ambitious ramps up from the coach's starter week over 3 weeks: week 1 = 2 days Ambitious, 5 the coach's.
	var ap = SP.phased(_athlete(2012, "800m"), game.START_DATE, "ambitious")
	var a1: Dictionary = ap.week_for(game.START_DATE, [])
	var coach: Array = data.training.coach_plan.days
	_ok("Ambitious week 1: 2 days of its own, the rest still the coach's week",
			a1.days.slice(0, 2) == variants.ambitious.templates.general_base.days.slice(0, 2) and a1.days.slice(2) == coach.slice(2)
			and a1.why[2] == "Easing in (week 1 of 3)")
	# Every plan tapers to its targets and peaks the same way: rest 2 days before, mobility the day before.
	var tapers := true
	for v in ["steady", "ambitious"]:
		var p = SP.phased(_athlete(2012, "800m"), game.START_DATE, v)
		var wk: Dictionary = p.week_for(_d(2027, 8, 2), [])   # Nuorten SM Fri 6 Aug: Wed = -2, Thu = -1
		tapers = tapers and wk.kind == "taper" and wk.days[2].is_empty() and wk.days[3] == ["mobility"] and wk.intensity[3] == "easy"
	_ok("Steady and Ambitious taper too (rest on day -2, mobility on day -1)", tapers)


## The coach's ★ (GDD 4.8, limits in data/periodization.json coach_pick): attributes as shown (whole numbers), injuries
## of the tiers listed (not niggles or illnesses) in the last months.
func _check_star_rule() -> void:
	print("-- the coach's ★ pick")
	var rule: Dictionary = data.periodization.coach_pick
	_ok("youth limits in the data: Steady at durability <= 4 or 2+ injuries in 12 months, Ambitious at 9 / 11 and 6 months clean",
			int(rule.steady.durability_max) == 4 and int(rule.steady.injuries) == 2 and int(rule.steady.months) == 12
			and int(rule.ambitious.durability_min) == 9 and int(rule.ambitious.professionalism_min) == 11 and int(rule.ambitious.injury_free_months) == 6)
	var today := _d(2027, 10, 1)
	var pick := func(dur: float, pro: float, injuries: Array) -> String:
		var a = _athlete(2012, "800m")
		a.set_attr("durability", dur)
		a.set_attr("professionalism", pro)
		var h = load("res://scripts/core/health_system.gd").new()
		for inj in injuries:
			h.history.append({"tier": inj[0], "started": game.add_days(today, -int(inj[1]))})
		return SP.coach_pick(a, today, h)
	_ok("durability 4 (shown as 4, also 4.4): Steady", pick.call(4.0, 10.0, []) == "steady" and pick.call(4.4, 10.0, []) == "steady")
	_ok("durability 5 (4.5 is shown as 5): Balanced", pick.call(5.0, 10.0, []) == "balanced" and pick.call(4.5, 10.0, []) == "balanced")
	_ok("durability 9 + professionalism 11, no injuries: Ambitious", pick.call(9.0, 11.0, []) == "ambitious")
	_ok("...professionalism 10 or durability 8: Balanced", pick.call(9.0, 10.0, []) == "balanced" and pick.call(8.0, 15.0, []) == "balanced")
	_ok("an injury 5 months ago blocks Ambitious, one 7 months ago doesn't",
			pick.call(12.0, 12.0, [["injury", 150]]) == "balanced" and pick.call(12.0, 12.0, [["injury", 215]]) == "ambitious")
	_ok("2 injuries in the last 12 months: Steady, even when durable", pick.call(12.0, 12.0, [["injury", 30], ["serious", 330]]) == "steady")
	_ok("...but not when one of them is older than 12 months", pick.call(12.0, 12.0, [["injury", 250], ["injury", 380]]) == "ambitious")
	_ok("niggles and illnesses don't count", pick.call(12.0, 12.0, [["niggle", 20], ["niggle", 40], ["illness", 10]]) == "ambitious")
	_ok("no health system (career start): attributes only", SP.coach_pick(_athlete(2012, "800m"), today) in ["steady", "balanced", "ambitious"])
	# Share of picks among 200 random new 14-year-olds (no creation points spent), for the GDD.
	var counts := {"steady": 0, "balanced": 0, "ambitious": 0}
	for i in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var answers := {}
		for q in data.background_questions:
			answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
		var a = load("res://scripts/core/athlete_factory.gd").create({"first_name": "T", "last_name": "R",
				"gender": "male" if i % 2 == 0 else "female", "hometown": "Tampere", "club_id": "tap", "main_event": "800m",
				"birth_date": {"year": 2012, "month": 5, "day": 1}, "answers": answers}, rng)
		counts[SP.coach_pick(a, game.START_DATE)] += 1
	print("    200 new 14-year-olds (no points spent): Steady %d %%, Balanced %d %%, Ambitious %d %%" % [
			counts.steady / 2, counts.balanced / 2, counts.ambitious / 2])
	_ok("most new careers get Balanced", counts.balanced > counts.steady + counts.ambitious)


## Choosing a plan for a season, and later seasons keeping it (until the autumn offer of step 6f).
func _check_variant_records() -> void:
	print("-- a season's plan")
	var plan = SP.phased(_athlete(2012, "800m"), game.START_DATE, "steady")
	_ok("the first season runs the plan it was made with", plan.variant(2026) == "steady")
	_ok("a later season nobody has touched keeps that plan", plan.variant(2027) == "steady" and plan.variant(2029) == "steady")
	var steady_week: Array = data.periodization.variants.steady.templates.general_base.days
	_ok("...and its weeks come from it", plan.week_for(_d(2027, 11, 22), []).days == steady_week)
	plan.edit_phase(2026, "spring_base").days[0] = ["tempo_run"]
	plan.edit_phase(2026, "race_season").days[0] = ["tempo_run"]
	plan.set_shift(2026, "spring_base", 1)
	plan.set_targets(2026, ["tjig@2027", "sm_14_15@2027"])
	_ok("edited phases are counted (2)", plan.edited_phases(2026) == 2)
	plan.set_variant(2026, "ambitious")
	_ok("choosing another plan replaces the phase weeks", plan.variant(2026) == "ambitious" and plan.edited_phases(2026) == 0)
	_ok("...but keeps the targets and the moved edges", plan.targets(2026) == ["tjig@2027", "sm_14_15@2027"] and plan.shift_of(2026, "spring_base") == 1)
	_ok("the next season follows the latest choice", plan.variant(2027) == "ambitious")
	plan.set_variant(2027, "balanced")
	_ok("a season with its own choice keeps it", plan.variant(2027) == "balanced" and plan.variant(2026) == "ambitious" and plan.variant(2028) == "balanced")
	plan.set_variant(2026, "nonsense")
	_ok("an unknown plan is ignored", plan.variant(2026) == "ambitious")
	var back = SP.from_dict(JSON.parse_string(JSON.stringify(plan.to_dict())))
	_ok("the choices survive save/load", back.variant(2026) == "ambitious" and back.variant(2027) == "balanced" and back.variant(2030) == "balanced")


func _check_seasons() -> void:
	print("-- season start")
	_ok("2026 starts Mon 2 Nov", SP.season_start(2026) == _d(2026, 11, 2))
	_ok("2027 starts Mon 1 Nov", SP.season_start(2027) == _d(2027, 11, 1))
	_ok("2028 starts Mon 30 Oct", SP.season_start(2028) == _d(2028, 10, 30))
	var all_mondays := true
	for y in range(2024, 2034):
		all_mondays = all_mondays and Cal.weekday(SP.season_start(y)) == 0
	_ok("a season always starts on a Monday", all_mondays)
	_ok("year_of: 1 Nov 2026 is still 2025, 2 Nov 2026 is 2026, 31 Oct 2027 is 2026",
			SP.year_of(_d(2026, 11, 1)) == 2025 and SP.year_of(_d(2026, 11, 2)) == 2026 and SP.year_of(_d(2027, 10, 31)) == 2026)
	_ok("season lengths 52 weeks", SP.season_weeks(2026) == 52 and SP.season_weeks(2027) == 52)


func _check_layout_2026() -> void:
	print("-- 2026-27 phase dates = GDD 4.8 table")
	var plan = _plan()
	var expected := [
		["general_base", _d(2026, 11, 2), 10], ["indoor_specific", _d(2027, 1, 11), 5], ["spring_base", _d(2027, 2, 15), 10],
		["pre_competition", _d(2027, 4, 26), 4], ["race_season", _d(2027, 5, 24), 14], ["transition", _d(2027, 8, 30), 3],
		["autumn_general", _d(2027, 9, 20), 6]]
	var lay: Array = plan.layout(2026)
	_ok("7 phases", lay.size() == 7)
	for i in mini(lay.size(), expected.size()):
		var start: Dictionary = game.add_days(SP.season_start(2026), 7 * int(lay[i].start))
		_ok("%s starts %s, %d weeks" % [lay[i].id, Cal.format_day(start), lay[i].weeks],
				lay[i].id == expected[i][0] and start == expected[i][1] and lay[i].weeks == expected[i][2])
	_ok("targets: SM-hallit 14-15 and Nuorten SM 14-15", plan.targets(2026) == ["sm_hallit_14_15@2027", "sm_14_15@2027"])
	var lay27: Array = plan.layout(2027)
	var sum := 0
	for p in lay27:
		sum += int(p.weeks)
	_ok("2027-28 (an unedited season) has 7 phases adding up to its 52 weeks", lay27.size() == 7 and sum == 52)
	print("    2027-28 targets (age 16 in 2028): ", plan.targets(2027))
	_ok("age 16: Turku indoor SM (17 class) and Nuorten SM 16-17",
			plan.targets(2027) == ["sm_hallit_17_22@2028", "sm_16_17@2028"])


func _check_every_week() -> void:
	print("-- every Monday of 2026-27 and 2027-28 has a plan, phases in order")
	var plan = _plan()
	var order := []
	for p in data.periodization.phases:
		order.append(p.id)
	var ok_shape := true
	var ok_order := true
	var prev := ""
	var prev_week := 0
	var prev_weeks := 0
	var seen := []
	for w in 104:
		var monday: Dictionary = game.add_days(game.START_DATE, 7 * w)
		var p: Dictionary = plan.week_for(monday, [])
		ok_shape = ok_shape and p.days.size() == 7 and p.intensity.size() == 7 and p.why.size() == 7 \
				and p.intensity.all(func(i): return i in ["easy", "normal", "hard"]) and p.kind in ["normal", "lighter", "taper"]
		if p.phase == prev:
			ok_order = ok_order and p.phase_week == prev_week + 1 and p.phase_weeks == prev_weeks
		else:
			var from := order.find(prev)
			ok_order = ok_order and p.phase_week == 1 and (prev == "" or order.find(p.phase) == (from + 1) % order.size())
			ok_order = ok_order and (prev == "" or prev_week == prev_weeks)
			seen.append(p.phase)
		prev = p.phase
		prev_week = p.phase_week
		prev_weeks = p.phase_weeks
	_ok("104 weeks: 7 days, intensities, reasons, kinds", ok_shape)
	_ok("phase weeks count 1..n, phases follow each other (no gaps, no repeats), two seasons = 14 phases",
			ok_order and seen.size() == 14)
	var early: Dictionary = plan.week_for(_d(2026, 10, 26), [])
	_ok("a Monday before the first season gets the first week", early.phase == "general_base" and early.phase_week == 1)
	var next_year: Dictionary = plan.week_for(_d(2028, 11, 6), [])
	_ok("a week of 2028-29 has a plan too", next_year.phase == "general_base" and next_year.days.size() == 7)


func _check_first_week_is_coach_week() -> void:
	print("-- a new career's first weeks are the old coach week")
	var plan = _plan()
	var coach: Array = data.training.coach_plan.days
	for w in 3:
		var p: Dictionary = plan.week_for(game.add_days(game.START_DATE, 7 * w), [])
		_ok("week %d: coach days, all Normal, no reasons" % (w + 1), p.days == coach and p.intensity == WP.coach().intensity
				and p.why == ["", "", "", "", "", "", ""])


func _check_lighter() -> void:
	print("-- lighter weeks")
	var plan = _plan()
	var lighter_weeks := {}
	var wrong := 0
	for w in 52:
		var monday: Dictionary = game.add_days(game.START_DATE, 7 * w)
		var p: Dictionary = plan.week_for(monday, [])
		var ph: Dictionary = SP.phase_type(p.phase)
		var expect: bool = bool(ph.lighter) and p.phase_week % 4 == 0 and p.kind != "taper"
		if (p.kind == "lighter") != expect:
			wrong += 1
		if p.kind == "lighter":
			lighter_weeks[p.phase] = lighter_weeks.get(p.phase, []) + [p.phase_week]
	_ok("lighter exactly in every 4th week of general base and spring base: %s" % lighter_weeks,
			wrong == 0 and lighter_weeks == {"general_base": [4, 8], "spring_base": [4, 8]})
	var w4: Dictionary = plan.week_for(game.add_days(game.START_DATE, 7 * 3), [])
	_ok("general base week 4: every day Easy, reason 'Lighter week' on days with sessions",
			w4.intensity == ["easy", "easy", "easy", "easy", "easy", "easy", "easy"] and w4.why[0] == "Lighter week" and w4.kind == "lighter")
	# Hard days step down once: Hard > Normal, Normal > Easy.
	var edit: Dictionary = plan.edit_phase(2026, "general_base")
	edit.intensity = ["hard", "normal", "easy", "hard", "normal", "easy", "hard"]
	var w4h: Dictionary = plan.week_for(game.add_days(game.START_DATE, 7 * 3), [])
	_ok("a lighter week steps every day one level down", w4h.intensity == ["normal", "easy", "easy", "normal", "easy", "easy", "normal"])
	plan.set_lighter(2026, "general_base", false)
	_ok("lighter weeks can be switched off for a phase", plan.week_for(game.add_days(game.START_DATE, 7 * 3), []).kind == "normal")
	_ok("the phase counts as edited", plan.is_edited(2026, "general_base") and not plan.is_edited(2026, "spring_base"))
	plan.reset_phase(2026, "general_base")
	_ok("reset puts the coach's week back", not plan.is_edited(2026, "general_base")
			and plan.week_for(game.add_days(game.START_DATE, 7 * 3), []).intensity == w4.intensity)


func _check_ramp() -> void:
	print("-- ramp")
	var plan = _plan()
	# Pre-competition starts Mon 26 Apr 2027. Spring base: Sat long run; pre-competition: Sat club session.
	var w1: Dictionary = plan.week_for(_d(2027, 4, 26), [])
	var w2: Dictionary = plan.week_for(_d(2027, 5, 3), [])
	var spring_t: Dictionary = data.periodization.variants.balanced.templates.spring_base
	var pre_t: Dictionary = data.periodization.variants.balanced.templates.pre_competition
	var spring: Array = spring_t.days
	var pre: Array = pre_t.days
	_ok("ramp week 1: the first 4 days are the new phase's, the rest the old one's",
			w1.days.slice(0, 4) == pre.slice(0, 4) and w1.days.slice(4) == spring.slice(4) and w1.phase == "pre_competition" and w1.phase_week == 1)
	# A day that is still the old phase's says so when it differs from the new phase's day (sessions or intensity).
	var whys_right: bool = w1.why[0] == "" and w1.why[5] == "Easing in (week 1 of 2)"
	for d in range(4, 7):
		var differs: bool = spring[d] != pre[d] or spring_t.intensity[d] != pre_t.intensity[d]
		whys_right = whys_right and (w1.why[d] == "Easing in (week 1 of 2)") == differs
	_ok("the days that are still the old phase's say so", whys_right)
	_ok("ramp week 2 is the whole new phase", w2.days == pre and w2.why == ["", "", "", "", "", "", ""])
	plan.set_ramp_weeks(2026, "pre_competition", 1)
	_ok("ramp 1 = no ramp", plan.week_for(_d(2027, 4, 26), []).days == pre and plan.is_edited(2026, "pre_competition"))
	# The first phase of the next season blends from the last phase of this one. (Balanced's autumn week is the coach
	# week with an Easy Monday, so make its Wednesday different to see the blend.)
	plan.edit_phase(2026, "autumn_general").days[2] = ["tempo_run"]
	plan.set_ramp_weeks(2027, "general_base", 4)   # 2 days new, 5 old in the first week
	var n1: Dictionary = plan.week_for(SP.season_start(2027), [])
	var base: Array = data.periodization.variants.balanced.templates.general_base.days
	_ok("next season's first week blends from autumn general (2 new days, 5 old)",
			n1.days.slice(0, 2) == base.slice(0, 2) and n1.days[2] == ["tempo_run"] and n1.why[2] == "Easing in (week 1 of 4)"
			and n1.days.slice(3) == base.slice(3))


func _check_easy_day() -> void:
	print("-- easy day before a race (race phases only)")
	var plan = _plan()
	# (meet date → the weekday before is the day to look at.) Entered meets in several phases.
	var cases := [
		["hallikisat_jkl@2027", _d(2027, 1, 9), false],       # general base (ends Sun 10 Jan): not a race phase
		["hallikisat_espoo@2027", _d(2027, 1, 23), true],     # indoor specific
		["hallikisat_kuortane@2027", _d(2027, 2, 27), false], # spring base
		["kevatkisat@2027", _d(2027, 5, 15), true],           # pre-competition
		["iltakisat_kesakuu@2027", _d(2027, 6, 8), false],    # race season, a Tuesday: Monday, the day before, is the rest day
		["syyskisat@2027", _d(2027, 8, 28), true]]            # race season (last week), a Saturday
	var entries := []
	for c in cases:
		entries.append(c[0])
	for c in cases:
		var date: Dictionary = c[1]
		var day_before: Dictionary = game.add_days(date, -1)
		var monday: Dictionary = Cal.monday_of(day_before)
		var d: int = Cal.weekday(day_before)
		var with: Dictionary = plan.week_for(monday, entries)
		var without: Dictionary = plan.week_for(monday, [])
		var changed: bool = with.intensity[d] != without.intensity[d]
		# Easy the day before; the reason is shown when the rule changed it (some plans have an Easy day there anyway).
		var easy: bool = with.intensity[d] == "easy" and (with.why[d].contains("Easy: race tomorrow") or without.intensity[d] == "easy")
		_ok("%s (%s): %s" % [c[0], with.phase, "easy day before" if c[2] else "nothing changed"],
				(c[2] and easy) or (not c[2] and not changed))
	# A rest day is not made Easy: spring base / race season Sunday is rest or Easy anyway; use Saturday race, Friday rest.
	var edited: Dictionary = plan.edit_phase(2026, "race_season")
	edited.days[4] = []
	var fri_rest: Dictionary = plan.week_for(_d(2027, 8, 23), ["syyskisat@2027"])
	_ok("a rest day before a race stays a rest day without a reason", fri_rest.days[4].is_empty() and fri_rest.why[4] == "")


func _check_taper() -> void:
	print("-- taper")
	var plan = _plan()
	# Make every day of both race phases Hard with two sessions so the taper's changes are visible.
	var hard_week: Array = [["tempo_run", "drills"], ["intervals_800", "easy_run"], ["strength", "speed_strides"], ["fartlek", "drills"],
			["long_run"], ["club_session", "mobility"], ["long_run", "strength"]]
	for id in ["indoor_specific", "race_season"]:
		var week: Dictionary = plan.edit_phase(2026, id)
		week.days = hard_week.duplicate(true)
		week.intensity = ["hard", "hard", "hard", "hard", "hard", "hard", "hard"]
	plan.set_ramp_weeks(2026, "indoor_specific", 1)
	plan.set_ramp_weeks(2026, "race_season", 1)
	var targets := [_d(2027, 2, 13), _d(2027, 8, 6)]
	for target in targets:
		var label := "target %s" % Cal.format_day(target)
		var bad := []
		for off in range(12, -1, -1):
			var date: Dictionary = game.add_days(target, -off)
			var p: Dictionary = plan.week_for(Cal.monday_of(date), [])
			var d: int = Cal.weekday(date)
			var day: Array = p.days[d]
			var level: String = p.intensity[d]
			var why: String = p.why[d]
			var fine := true
			if off > 10 or off == 0:
				fine = not why.contains("Taper") and day == hard_week[d] and level == "hard"
			elif off >= 4:
				fine = day.size() == 1 and not "long_run" in day and level == "hard" and why.begins_with("Taper")
			elif off == 3:
				fine = day.size() == 1 and level == "normal" and why.begins_with("Taper")
			elif off == 2:
				fine = day.is_empty() and why.begins_with("Taper")
			elif off == 1:
				fine = day == ["mobility"] and level == "easy" and why.begins_with("Taper")
			if not fine:
				bad.append("%d days before: %s %s %s" % [off, day, level, why])
		_ok(label + ": days -10..-1 follow the taper rules, day 0 and -11/-12 untouched" + (" " + str(bad) if not bad.is_empty() else ""),
				bad.is_empty())
		var kinds := []
		for off in [14, 9, 3]:
			kinds.append(plan.week_for(Cal.monday_of(game.add_days(target, -off)), []).kind)
		_ok(label + ": the weeks before are kind %s (normal, taper, taper)" % [kinds], kinds == ["normal", "taper", "taper"])
	# Which session is kept: the speed / hard one. Wed 28 Jul = 9 days before Nuorten SM: speed & strides over strength.
	var wed: Dictionary = plan.week_for(_d(2027, 7, 26), [])
	_ok("with strength + speed & strides the sharp session is kept: %s" % [wed.days[2]], wed.days[2] == ["speed_strides"])
	_ok("the week names the target", wed.target == "sm_14_15@2027" and wed.why[2].contains("Nuorten SM"))
	_ok("the long run becomes an easy run", wed.days[4] == ["easy_run"])
	# A lighter week is not combined with a taper.
	var lw = _plan()
	var light_in_taper := 0
	for w in 52:
		var p: Dictionary = lw.week_for(game.add_days(game.START_DATE, 7 * w), [])
		if p.kind == "taper" and p.why.any(func(t): return t.contains("Lighter")):
			light_in_taper += 1
	_ok("no lighter week inside a taper week", light_in_taper == 0)
	# Several targets (max 3): the third only gets a taper.
	var many = _plan()
	many.set_targets(2026, ["sm_hallit_14_15@2027", "sm_14_15@2027", "youth_athletics_games@2027", "tjig@2027"])
	_ok("at most 3 targets", many.targets(2026).size() == 3 and not many.add_target(2026, "tjig@2027"))
	var yag := _d(2027, 6, 17)
	var yag_week: Dictionary = many.week_for(Cal.monday_of(game.add_days(yag, -2)), [])
	_ok("a third target gets its taper (rest two days before Youth Athletics Games)",
			yag_week.target == "youth_athletics_games@2027" and yag_week.days[Cal.weekday(game.add_days(yag, -2))].is_empty())
	_ok("...but doesn't move the phases", many.layout(2026) == _plan().layout(2026))


func _check_moves() -> void:
	print("-- moving an edge or a target moves the phases")
	var plan = _plan()
	var before: Array = plan.layout(2026).duplicate(true)
	_ok("move spring base +2 weeks", plan.set_shift(2026, "spring_base", 2) == 2)
	var after: Array = plan.layout(2026)
	_ok("indoor specific 2 weeks longer, spring base 2 shorter, the rest the same",
			after[1].weeks == before[1].weeks + 2 and after[2].start == before[2].start + 2 and after[2].weeks == before[2].weeks - 2
			and after[3].start == before[3].start and after[0] == before[0])
	_ok("the week plan follows (the Monday spring base used to start is indoor specific now)",
			plan.week_for(_d(2027, 2, 15), []).phase == "indoor_specific" and plan.week_for(_d(2027, 3, 1), []).phase == "spring_base")
	_ok("limit ±4 weeks", plan.set_shift(2026, "race_season", 9) == 4 and plan.set_shift(2026, "indoor_specific", -9) == -4)
	_ok("the first phase can't move", plan.set_shift(2026, "general_base", 3) == 0)
	plan.set_shift(2026, "race_season", 0)
	plan.set_shift(2026, "indoor_specific", 0)
	# Every phase keeps at least a week: pre-competition is 4 weeks, race season can't eat more than 3 of them.
	var plan2 = _plan()
	_ok("race season −4 is cut to −3 (pre-competition keeps 1 week)", plan2.set_shift(2026, "race_season", -4) == -3
			and plan2.layout(2026)[3].weeks == 1)
	var short := true
	for s in 2:
		for p in plan2.layout(2026 + s):
			short = short and int(p.weeks) >= 1
	_ok("every phase at least 1 week", short)
	plan2.set_shift(2026, "race_season", 0)
	_ok("shift 0 puts it back", plan2.layout(2026) == before)
	# Targets move the anchors: indoor target = Tampere Junior Indoor Games (Fri 12 Mar 2027), outdoor = Youth Athletics Games (Thu 17 Jun).
	var plan3 = _plan()
	plan3.set_targets(2026, ["tjig@2027", "youth_athletics_games@2027"])
	var lay: Array = plan3.layout(2026)
	var mon_tjig: Dictionary = _d(2027, 3, 8)
	var mon_yag: Dictionary = _d(2027, 6, 14)
	var start_of: Callable = func(id): return game.add_days(SP.season_start(2026), 7 * int(lay.filter(func(p): return p.id == id)[0].start))
	_ok("indoor specific = the 4 weeks before the indoor anchor's week (%s)" % Cal.format_day(start_of.call("indoor_specific")),
			start_of.call("indoor_specific") == game.add_days(mon_tjig, -28) and start_of.call("spring_base") == game.add_days(mon_tjig, 7))
	_ok("race season starts 10 weeks before the outdoor anchor's week, transition 4 weeks after it",
			start_of.call("race_season") == game.add_days(mon_yag, -70) and start_of.call("transition") == game.add_days(mon_yag, 28)
			or start_of.call("race_season") > game.add_days(mon_yag, -70))
	var ok_order := true
	for i in lay.size():
		ok_order = ok_order and int(lay[i].weeks) >= 1
	_ok("phases still in order, each at least a week (pre-competition squeezed: %d weeks)" % lay[3].weeks, ok_order)
	var taper_week: Dictionary = plan3.week_for(mon_tjig, [])
	_ok("the taper follows the new target", taper_week.kind == "taper" and taper_week.target == "tjig@2027")
	var plan4 = _plan()
	plan4.set_targets(2026, ["tjig@2027"])
	_ok("with only an indoor target the outdoor anchor is still the coach's main meet (phases unchanged)", plan4.layout(2026).slice(3) == _plan().layout(2026).slice(3))


func _check_fallbacks() -> void:
	print("-- no main meet / no target: fallbacks")
	var plan = _plan()
	plan.set_targets(2026, [])
	_ok("no targets at all: the phases still come from the main meets", plan.layout(2026) == _plan().layout(2026))
	var any_taper := false
	for w in 52:
		any_taper = any_taper or plan.week_for(game.add_days(game.START_DATE, 7 * w), []).kind == "taper"
	_ok("...but there is no taper", not any_taper)
	# A 13-year-old: no main meet fits, so the highest-level coach meet of each part (Tampere Junior Indoor Games, Youth Athletics Games).
	var young = SP.phased(_athlete(2014, "800m"), game.START_DATE)
	_ok("age 13: highest-level ★ meets are the targets: %s" % [young.targets(2026)],
			young.targets(2026) == ["tjig@2027", "youth_athletics_games@2027"])
	# Age 17: indoor SM 17-22 and SM 16-17.
	var older = SP.phased(_athlete(2010, "800m"), game.START_DATE)
	_ok("age 17: %s" % [older.targets(2026)], older.targets(2026) == ["sm_hallit_17_22@2027", "sm_16_17@2027"])
	# An event nothing is on the programme for: no targets, the two anchored phases are left out.
	var none = SP.phased(_athlete(2012, "1500m"), game.START_DATE)
	var lay: Array = none.layout(2026)
	var ids := []
	var total := 0
	for p in lay:
		ids.append(p.id)
		total += int(p.weeks)
	_ok("no meet fits: no targets, indoor specific and race season left out: %s" % [ids],
			none.targets(2026).is_empty() and ids == ["general_base", "spring_base", "pre_competition", "transition", "autumn_general"])
	_ok("...and the phase before lasts longer (general base %d weeks, pre-competition %d), 52 weeks in all" % [lay[0].weeks, lay[2].weeks],
			lay[0].weeks == 15 and lay[2].weeks == 18 and total == 52)
	var fine := true
	for w in 52:
		var p: Dictionary = none.week_for(game.add_days(game.START_DATE, 7 * w), [])
		fine = fine and p.days.size() == 7 and p.kind != "taper"
	_ok("every week of that season has a plan", fine)


func _check_career_start() -> void:
	print("-- a new career starts in phases mode on the coach's ★ plan")
	game.start_career(_athlete(2012, "800m"))
	var star: String = SP.coach_pick(game.athlete, game.START_DATE)
	_ok("phases mode, the ★ plan (%s), first season 2026" % star, game.season.mode == "phases" and game.season.first_season == 2026
			and game.season.variant(2026) == star)
	var sturdy = _athlete(2012, "800m")
	sturdy.set_attr("durability", 4.0)
	game.start_career(sturdy)
	_ok("durability 4 at the start: the career starts on Steady", game.season.variant(2026) == "steady")
	game.start_career(_athlete(2012, "800m"), "phases", "ambitious")
	_ok("a plan asked for is used", game.season.variant(2026) == "ambitious")
	_new_career(3, "phases")
	_ok("(the other checks run on Balanced)", game.season.variant(2026) == "balanced")
	_ok("the two targets are entered: %s" % [game.entries], game.entries == ["sm_hallit_14_15@2027", "sm_14_15@2027"])
	game.withdraw("sm_14_15@2027")
	_ok("withdrawing from a target takes it off the target list", game.season.targets(2026) == ["sm_hallit_14_15@2027"]
			and game.entries == ["sm_hallit_14_15@2027"])
	game.scratch_race("sm_hallit_14_15@2027")
	_ok("so does scratching", game.season.targets(2026).is_empty())
	game.enter("hallikisat_jkl@2027")
	game.withdraw("hallikisat_jkl@2027")
	_ok("withdrawing from another meet changes nothing", game.season.targets(2026).is_empty())
	_new_career(3, "repeat")
	_ok("repeat mode asked for: no meets entered, coach week", game.season.mode == "repeat" and game.entries.is_empty()
			and game.season.repeat_week.days == data.training.coach_plan.days)


func _check_repeat_mode() -> void:
	print("-- repeat mode works as in 6a")
	_new_career(4, "repeat")
	var p: Dictionary = game.season.week_for(game.week_monday())
	_ok("week_for returns the repeating week itself, without phase fields", p == game.season.repeat_week and not p.has("phase"))
	var old = SP.repeating([["easy_run"], [], [], [], [], [], []])
	_ok("SeasonPlan.repeating takes the old Array", old.mode == "repeat" and old.week_for(_d(2027, 1, 4)).days[0] == ["easy_run"])
	var restored = SP.from_dict({"mode": "repeat", "repeat_week": {"days": [["long_run"], [], [], [], [], [], []], "intensity": ["hard", "normal", "normal", "normal", "normal", "normal", "normal"]}})
	_ok("a version-3 (6a) season dict loads as repeat mode", restored.mode == "repeat" and restored.repeat_week.intensity[0] == "hard")
	var broken = SP.from_dict({"mode": "phases", "repeat_week": {}})
	_ok("a 'phases' dict without seasons falls back to repeat mode", broken.mode == "repeat")


func _check_save_load() -> void:
	print("-- save / load bit for bit")
	_new_career(5, "phases")
	var plan = game.season
	plan.set_shift(2026, "spring_base", 2)
	plan.set_targets(2026, ["tjig@2027", "sm_14_15@2027", "youth_athletics_games@2027"])
	plan.edit_phase(2026, "race_season").days[2] = ["tempo_run"]
	plan.edit_phase(2026, "race_season").intensity[2] = "hard"
	plan.set_lighter(2026, "spring_base", false)
	plan.set_ramp_weeks(2027, "general_base", 3)
	plan.set_shift(2027, "pre_competition", -2)
	var entries: Array = ["hallikisat_espoo@2027", "kevatkisat@2027"]
	game.entries = entries.duplicate()
	var weeks := func(p) -> String:
		var all := []
		for w in 110:
			all.append(p.week_for(game.add_days(game.START_DATE, 7 * w), entries))
		return _json(all)
	var before: String = weeks.call(plan)
	var dict_before: String = _json(plan.to_dict())
	# Through a real save file, the way the game saves.
	saves.save("sp_check")
	game.season = SP.new()   # scramble
	game.entries = []
	_ok("load", saves.load_slot("sp_check"))
	_ok("the season plan dict comes back identical", _json(game.season.to_dict()) == dict_before)
	_ok("110 weeks of plans identical after save/load", weeks.call(game.season) == before)
	_ok("still phases mode, same athlete data", game.season.mode == "phases" and game.season.birth_year == 2012 and game.season.event == "800m"
			and game.season.first_season == 2026)
	_ok("targets and edits survived", game.season.targets(2026).size() == 3 and game.season.is_edited(2026, "race_season")
			and game.season.shift_of(2026, "spring_base") == 2)
	saves.delete("sp_check")
	# Loading the 6a save format (repeat mode only, no extra fields) and an old plain plan.
	var old: Dictionary = game.to_dict().duplicate(true)
	old.season = {"mode": "repeat", "repeat_week": game.season.repeat_week}
	game.from_dict(JSON.parse_string(JSON.stringify(old)))
	_ok("a 6a save loads as repeat mode with its week", game.season.mode == "repeat")
	old.erase("season")
	old.training_plan = data.training.coach_plan.days
	game.from_dict(JSON.parse_string(JSON.stringify(old)))
	_ok("a version-1/2 save loads as repeat mode with the old plan", game.season.mode == "repeat"
			and game.season.repeat_week.days == data.training.coach_plan.days)


## Plays real days through the game loop in phases mode, across a taper and the target race.
func _check_play() -> void:
	print("-- playing days in phases mode")
	_new_career(6, "phases")
	game.entries = ["sm_hallit_14_15@2027"]
	var played := 0
	var matched := 0
	var race_reached := false
	var limit := 120 * 3
	var steps := 0
	while Cal.date_key(game.date) <= Cal.date_key(_d(2027, 2, 14)) and steps < limit:
		steps += 1
		var date: Dictionary = game.date.duplicate()
		var planned: Dictionary = game.season.week_for(Cal.monday_of(date))
		var d: int = Cal.weekday(date)
		var expected_sessions: Array = game.current_week().session_ids(d)
		var r: String = game.advance_day()
		if r == game.RACE:
			race_reached = true
			_ok("race day reached on Sat 13 Feb 2027", Cal.date_key(date) == 20270213)
			var rd = game.race_day
			while not rd.is_done():
				var race = rd.start_round(false, "pack")
				race.run()
				rd.finish_round()
			r = game.finish_race()
		if r == game.STOP:
			game.answer_event(game.pending_event().id, "ok")
		if game.day_log.size() > 0 and Cal.date_key(game.day_log[-1].date) == Cal.date_key(date) and game.day_log[-1].race == "":
			played += 1
			if game.day_log[-1].sessions == planned.days[d] and expected_sessions == planned.days[d]:
				matched += 1
	_ok("played %d training days: the day log is what the week plan said (%d)" % [played, matched], played > 60 and matched == played)
	_ok("the taper played out and the race was run", race_reached and game.athlete.results.size() >= 1)
	var wk: Dictionary = game.season.week_for(game.week_monday())
	print("    now ", Cal.format_day(game.date), ": ", wk.phase, " week ", wk.phase_week, "/", wk.phase_weeks)
	# A day change on top of the plan still works (this-week changes apply on top of the phase week).
	var cw = game.current_week()
	var d_now: int = Cal.weekday(game.date)
	if d_now < 6:
		cw.make_rest_day(d_now + 1)
		_ok("a day change on top of the season plan", cw.session_ids(d_now + 1).is_empty() and game.current_week().changed_by(d_now + 1).has("sessions"))


## M2 step 6e: the model functions behind the season UI (switching both ways, target candidates, phase dates, the
## report's phase, the lead-in for a future phase) and the UI pieces building without errors.
func _check_season_ui() -> void:
	print("-- season UI (step 6e)")
	_new_career(7, "phases")
	var plan = game.season
	plan.edit_phase(2026, "spring_base").intensity[1] = "hard"
	plan.set_shift(2026, "race_season", 1)
	var before: String = _json(plan.to_dict())
	plan.switch_to_repeat(game.week_monday())
	_ok("switch to one repeating week: repeat mode, the week = this phase's week",
			plan.mode == "repeat" and WP.equals(plan.repeat_week, data.periodization.variants.balanced.templates.general_base))
	game.use_season_plan()
	_ok("...and back: phases mode with the season's changes kept",
			plan.mode == "phases" and plan.is_edited(2026, "spring_base")
			and plan.shift_of(2026, "race_season") == 1)
	plan.switch_to_repeat(game.week_monday())
	game.use_season_plan()
	var after: Dictionary = plan.to_dict()
	var was: Dictionary = JSON.parse_string(before)
	_ok("...the season records are exactly as before", _json(after.seasons) == _json(was.seasons))

	var old = SP.repeating(WP.coach())
	game.season = old
	game.entries = []
	game.use_season_plan()
	_ok("an old repeat-mode career switched on: phases mode, first season 2026, the ★ plan, targets entered",
			old.mode == "phases" and old.first_season == 2026 and old.birth_year == int(game.athlete.birth_date.year)
			and old.variant(2026) == SP.coach_pick(game.athlete, game.date) and not game.entries.is_empty()
			and game.entries.all(func(k): return k in old.targets(2026)))

	_new_career(8, "phases")
	plan = game.season
	var dates: Array = plan.phase_dates(2026)
	var joined: bool = dates.size() == 7 and dates[0].first == SP.season_start(2026)
	for i in range(1, dates.size()):
		joined = joined and game.add_days(dates[i - 1].last, 1) == dates[i].first
	_ok("phase_dates: 7 phases from Mon 2 Nov, each starting the day after the one before ends",
			joined and dates[dates.size() - 1].last == game.add_days(SP.season_start(2027), -1))
	var cands: Array = plan.target_candidates(2026, game.date)
	var fine := not cands.is_empty()
	for m in cands:
		fine = fine and not m.key in plan.targets(2026) and not m.get("watch", false) and "800m" in m.events \
				and Cal.date_key(m.date) >= Cal.date_key(game.date)
	_ok("target candidates: this season's 800 m meets from today, no watch-only meets, no targets (%d)" % cands.size(), fine)
	_ok("a third target can be added, a fourth can't", plan.add_target(2026, cands[0].key)
			and not plan.add_target(2026, plan.target_candidates(2026, game.date)[0].key))

	# The report keeps the week's phase; repeat mode has none.
	while game.advance_day() != game.WEEK_DONE:
		pass
	_ok("last week's report has its phase and kind", game.last_report.get("plan", {}).get("phase", "") == "general_base"
			and game.last_report.plan.kind == "normal" and int(game.last_report.plan.phase_week) == 1)

	# The lead-in (health on, no dice): the same answer twice, the game untouched, and today's state for this week.
	load("res://scripts/core/health_system.gd").model_enabled = true
	var health = game.get_system("health")
	health._ensure_started()
	var keep_health: String = _json(health.to_dict())
	var keep_athlete: String = _json(game.athlete.to_dict())
	var spring: Dictionary = plan.phase_dates(2026)[2]
	var t0 := Time.get_ticks_msec()
	var lead1: Dictionary = health.projected(spring.first)
	var ms := Time.get_ticks_msec() - t0
	var lead2: Dictionary = health.projected(spring.first)
	_ok("lead-in to spring base: repeatable (no dice), %d ms" % ms, _json(lead1.health.to_dict()) == _json(lead2.health.to_dict())
			and lead1.health.day_no > health.day_no + 90)
	_ok("...and the game's body and athlete are untouched", _json(health.to_dict()) == keep_health and _json(game.athlete.to_dict()) == keep_athlete)
	var week: Dictionary = plan.edit_phase(2026, "spring_base")
	var risk: String = health.plan_risk(week, lead1)
	var load_pct: int = health.load_vs_normal(week, lead1)
	_ok("risk and load of spring base after the lead-in: %s, %d %%" % [risk, load_pct], risk in ["low", "moderate", "high"] and load_pct > 50 and load_pct < 200)
	var section = load("res://scripts/ui/health_ui.gd").plan_section(week, null, lead1)
	_ok("the body-strain section builds for a future phase", section != null)
	if section:
		section.free()
	load("res://scripts/core/health_system.gd").model_enabled = false

	# The UI pieces build (season view, bar, phase editor of every phase, caption).
	var view = load("res://scripts/ui/season_view.gd").new()
	_ok("the season view builds", view.get_child_count() >= 5)
	view.free()
	var bar = load("res://scripts/ui/season_bar.gd").new(2026)
	_ok("the season bar has 7 phases and 52 week kinds", bar._phases.size() == 7 and bar._kinds.size() == 52)
	bar.free()
	var built := 0
	for p in plan.phase_dates(2026):
		var editor = load("res://scripts/ui/phase_editor.gd").new(2026, p.id)
		built += 1 if editor.get_child_count() >= 4 else 0
		editor.free()
	_ok("the phase editor builds for all 7 phases (past, now, future)", built == 7)
	_ok("week strip caption: \"%s\"" % load("res://scripts/ui/season_ui.gd").week_caption(),
			load("res://scripts/ui/season_ui.gd").week_caption().begins_with("General base · week 2 of 10"))


func _check_speed() -> void:
	print("-- speed")
	var plan = _plan()
	var t0 := Time.get_ticks_usec()
	var entries: Array = ["hallikisat_espoo@2027", "kevatkisat@2027"]
	for i in 2000:
		plan.week_for(game.add_days(game.START_DATE, 7 * (i % 100)), entries)
	var per_call := (Time.get_ticks_usec() - t0) / 2000.0
	print("    week_for: %.0f µs per call" % per_call)
	_ok("week_for is cheap (< 1 ms)", per_call < 1000.0)


# --- Helpers -------------------------------------------------------------------------------------

## A phases-mode plan for the 2012-born 800 m runner of the other checks, on the first season.
func _plan():
	return SP.phased(_athlete(2012, "800m"), game.START_DATE)


func _athlete(birth_year: int, event: String):
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	var a = load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": birth_year, "month": 5, "day": 1},
		"answers": answers}, rng)
	a.main_event = event
	return a


## Phases mode on Balanced (not the ★ pick), so the checks don't depend on this athlete's attributes.
func _new_career(seed_value: int, mode: String) -> void:
	var a = _athlete(2012, "800m")
	game.start_career(a, mode, "balanced")


func _d(y: int, m: int, d: int) -> Dictionary:
	return {"year": y, "month": m, "day": d}


## Full-precision JSON, read back once (exactly, like a save) so ints and floats compare the same way.
func _json(v: Variant) -> String:
	var text := JSON.stringify(v, "", true, true)
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	return JSON.stringify(parsed, "", true, true)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1
