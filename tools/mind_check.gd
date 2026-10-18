extends SceneTree
## Dev tool: headless checks of the mind (GDD 4.9.4, session M1): confidence / motivation / stress, their news, the Sunday drift,
## the effects (training quality, the race-day term), the mental attributes that grow, the mental plan, the moments' mood
## effects, the goals, the coach's Sunday line and mood topic, save / load and the off switches. Prints PASS / FAIL.
## Run: godot --headless --path . -s res://tools/mind_check.gd
## Uses its own save folder (user://tool_saves/), never the player's saves. The health model is off unless a check needs it.
## NOTE: it prints ALL CHECKS PASSED even when a SCRIPT ERROR aborted a check function: read stderr too.

var game
var data
var saves
var Cal
var MI
var C
var H
var MS
var WP
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	Cal = load("res://scripts/core/calendar.gd")
	MI = load("res://scripts/core/mind_system.gd")
	C = load("res://scripts/core/coach_system.gd")
	H = load("res://scripts/core/health_system.gd")
	MS = load("res://scripts/core/storylet_system.gd")
	WP = load("res://scripts/core/week_plan.gd")
	# Lab (no injuries, a club coach of 10s) with the moods and the school free: the parts pin them where they need to.
	load("res://scripts/core/game_config.gd").use("lab", {"mind_neutral": false, "school_neutral": false})
	game.autosave = false

	_check_data()
	_check_numbers()
	_check_neutral()
	_check_news()
	_check_drift()
	_check_effects()
	_check_growth()
	_check_moments()
	_check_talk()
	_check_save_load()
	_check_switch_off()
	_check_season()
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


# --- 1. Data and the numbers -----------------------------------------------------------------------------------------

func _check_data() -> void:
	print("-- 1. data/mind.json")
	var m: Dictionary = data.mind
	var ok := true
	for mood in MI.MOODS:
		var cfg: Dictionary = m.moods[mood]
		var last := -1.0
		for w in cfg.words:
			ok = ok and float(w.below) > last
			last = float(w.below)
		var start := float(cfg.start)
		ok = ok and start >= float(cfg.middle[0]) and start <= float(cfg.middle[1])
		ok = ok and m.drift.has(mood) and m.ui.effects.has(mood) and m.ui.helps_text.has(mood)
	_ok("three moods, words in order, the start inside the middle, drift / effect / helps texts for each", ok)
	_ok("start words: OK / OK / Calm", MI.word_for("confidence", 50.0).name == "OK" and MI.word_for("motivation", 50.0).name == "OK"
			and MI.word_for("stress", 20.0).name == "Calm")
	_ok("the moments know the mood effects (moved from prepared to known)", "confidence" in data.moments.effects.known
			and "motivation" in data.moments.effects.known and "stress" in data.moments.effects.known
			and not "confidence" in data.moments.effects.prepared)
	_ok("the coach's lines exist for the four voices", data.mind.coach.lines.has("calm") and data.mind.coach.lines.has("drill")
			and data.mind.coach.lines.has("warm") and data.mind.coach.lines.has("tactician"))
	var topics: Array = data.storylets.filter(func(s): return str(s.get("topic", "")) == "mood")
	_ok("three mood topics in data/storylets (%d)" % topics.size(), topics.size() == 3)


func _check_numbers() -> void:
	print("-- 2. the effects' numbers (the GDD sizes with a calm middle)")
	_ok("motivation 40 / 50 / 60: training quality exactly 1.0", MI.quality_for(40.0) == 1.0 and MI.quality_for(50.0) == 1.0 and MI.quality_for(60.0) == 1.0)
	_ok("motivation 0 (Flat): x0.92; 100 (Fired up): x1.05", is_equal_approx(MI.quality_for(0.0), 0.92) and is_equal_approx(MI.quality_for(100.0), 1.05))
	_ok("motivation 20: halfway down (x0.96), 80: halfway up (x1.025)", is_equal_approx(MI.quality_for(20.0), 0.96) and is_equal_approx(MI.quality_for(80.0), 1.025))
	_ok("confidence 40 / 50 / 60: no race-day term at any level", MI.term_for(40.0, "national") == 0.0 and MI.term_for(50.0, "local") == 0.0 and MI.term_for(60.0, "international") == 0.0)
	_ok("confidence 100 at a national meet: +0.3 %; 0 at a local meet: -0.1 % (a third)",
			is_equal_approx(MI.term_for(100.0, "national"), 0.003) and is_equal_approx(MI.term_for(0.0, "local"), -0.003 * 0.33))
	_ok("a district meet: half", is_equal_approx(MI.term_for(100.0, "district"), 0.0015))


# --- 3. Neutral = identical ------------------------------------------------------------------------------------------

## A year of the repeating coach week through the game (health off, coach of 10s). Returns the attribute sum (%.9f).
func _year(mind_on: bool, pinned: bool) -> String:
	MI.model_enabled = mind_on
	MI.neutral = pinned
	game.start_career(_athlete(), "repeat")
	for w in 52:
		while game.advance_day() != game.WEEK_DONE:
			pass
	var total := 0.0
	for id in game.athlete.attributes:
		total += game.athlete.get_attr(id)
	MI.model_enabled = true
	MI.neutral = false
	return "%.9f" % total


func _check_neutral() -> void:
	print("-- 3. neutral = identical (training_balance's coach row: 206.798298350)")
	var off := _year(false, false)
	var pinned := _year(true, true)
	var free := _year(true, false)
	var ms = game.get_system("mind")
	print("    mind off %s, moods pinned in the middle %s, moods free %s (motivation after a year of the same week: %.1f, %s)" % [
			off, pinned, free, ms.value("motivation"), ms.word("motivation").name])
	_ok("the mind off gives the coach-row fingerprint", off == "206.798298350")
	_ok("the moods pinned in the middle give it too", pinned == "206.798298350")
	_ok("the moods free: a year of the same week wears motivation down (monotony), so less is trained", free != off and float(free) < float(off)
			and ms.word("motivation").id in ["low", "flat"])


# --- 4. News ---------------------------------------------------------------------------------------------------------

func _fresh(variant := "") -> Object:
	if variant == "":
		game.start_career(_athlete(), "repeat")
	else:
		game.start_career(_athlete(), "phases", variant)
	return game.get_system("mind")


func _note(rounds: Array, beat := 0, key := "") -> Dictionary:
	return {"meet": "Test meet", "key": key, "rounds": rounds, "beat_above": beat}


func _check_news() -> void:
	print("-- 4. news")
	var ms = _fresh()
	ms._race_news(_note([{"place": 3, "field": 8, "time": 130.0, "status": "", "mark": "PB", "ref": 131.0}]))
	_ok("a PB: confidence +10, motivation +4", ms.value("confidence") == 60.0 and ms.value("motivation") == 54.0)
	ms = _fresh()
	ms._race_news(_note([{"place": 2, "field": 8, "time": 130.0, "status": "", "mark": "SB", "ref": 131.0}]))
	_ok("a season's best: confidence +5", ms.value("confidence") == 55.0)
	ms = _fresh()
	ms._race_news(_note([{"place": 8, "field": 8, "time": 137.0, "status": "", "mark": "", "ref": 130.0}]))
	_ok("well below your level (5.4 %% slower) and last of 8: -7 and -5 (%.0f)" % ms.value("confidence"), ms.value("confidence") == 38.0)
	_ok("its causes are listed, newest first", ms.recent("confidence").size() == 2 and str(ms.recent("confidence")[0].text).begins_with("Last"))
	ms = _fresh()
	ms._race_news(_note([{"place": 4, "field": 8, "time": 133.0, "status": "", "mark": "", "ref": 130.0}]))
	_ok("a bit below (2.3 %%): -4 (%.0f)" % ms.value("confidence"), ms.value("confidence") == 46.0)
	ms = _fresh()
	ms._race_news(_note([{"place": 1, "field": 8, "time": 130.5, "status": "", "mark": "", "ref": 130.0}], 5))
	_ok("a win and five runners ranked above beaten: +4 and +6 (the cap)", ms.value("confidence") == 60.0)
	ms = _fresh()
	ms._race_news(_note([{"place": 8, "field": 8, "time": 0.0, "status": "dnf", "mark": "", "ref": 130.0}]))
	_ok("a DNF: -8 and nothing else", ms.value("confidence") == 42.0)
	ms = _fresh()
	ms.goal_met()
	_ok("a goal met: confidence +6, motivation +4", ms.value("confidence") == 56.0 and ms.value("motivation") == 54.0)
	ms.goal_missed()
	_ok("a goal missed: confidence -2", ms.value("confidence") == 54.0)
	ms = _fresh()
	game.athlete.set_attr("ambition", 18.0)
	ms.goals_set(2)
	var big: float = ms.value("motivation")
	ms = _fresh()
	game.athlete.set_attr("ambition", 4.0)
	ms.goals_set(2)
	var small: float = ms.value("motivation")
	ms = _fresh()
	game.athlete.set_attr("ambition", 18.0)
	ms.goals_set(-2)
	var held: float = ms.value("motivation")
	_ok("new goals two levels above his pick lift a dreamer more (%.1f) than a content athlete (%.1f); below his pick they lower the dreamer (%.1f)" % [big, small, held],
			big > small and small > 50.0 and held < 50.0)
	# A diagnosis (HealthSystem posts it in on_health): confidence and stress by the tier.
	ms = _fresh()
	var e: Dictionary = game.post_event("health", "Injury", "", [], false)
	e.kind = "diagnosis"
	e.injury = "tibial_stress_reaction"
	ms._diagnoses({"date": game.date})
	_ok("an injury (shin stress reaction): confidence -5, stress +6", ms.value("confidence") == 45.0 and ms.value("stress") == 26.0)
	ms.neutral = true
	ms.add("confidence", 20.0, "x")
	_ok("neutral: news moves nothing", ms.value("confidence") == 45.0)
	ms.neutral = false


# --- 5. The Sunday drift --------------------------------------------------------------------------------------------

func _play_weeks(n: int) -> void:
	for w in n:
		var monday: int = Cal.date_key(game.add_days(game.week_monday(), 7))
		while Cal.date_key(game.date) < monday:
			var r: String = game.advance_day()
			if r == game.RACE:
				_run_race()
			while not game.pending_event().is_empty():
				game.answer_event(game.pending_event().id, "ok")


func _check_drift() -> void:
	print("-- 5. the Sunday drift")
	var ms = _fresh()
	for key in ["values", "snap", "before"]:   # (as if they had been there for weeks)
		ms[key].confidence = 90.0
		ms[key].stress = 70.0
	_play_weeks(1)
	_ok("confidence drifts 15 %% of the way back to 50 (90 -> %.1f)" % ms.value("confidence"), is_equal_approx(ms.value("confidence"), 84.0))
	_ok("stress drifts 40 %% of the way to its target 20 (70 -> %.1f)" % ms.value("stress"), is_equal_approx(ms.value("stress"), 50.0))
	_ok("the arrows: confidence and stress down since a week ago", ms.arrow("confidence") == -1 and ms.arrow("stress") == -1 and ms.arrow("motivation") == 0)
	# Confidence comes back faster after a bad race with a good mental coach.
	ms = _fresh()
	game.get_system("coach").head().attributes.mental_coaching = 18
	ms.values.confidence = 20.0
	_play_weeks(1)
	var good: float = ms.value("confidence")
	ms = _fresh()
	game.get_system("coach").head().attributes.mental_coaching = 4
	ms.values.confidence = 20.0
	_play_weeks(1)
	var poor: float = ms.value("confidence")
	_ok("from Low (20) a mental coach of 18 brings confidence back faster (%.1f) than one of 4 (%.1f)" % [good, poor], good > poor and poor > 20.0)
	# Monotony: the same repeating week; the pull appears after 8 weeks.
	ms = _fresh()
	_play_weeks(8)
	var pulls8: Array = ms.pulls("motivation").filter(func(p): return str(p.text).begins_with("The same training"))
	_play_weeks(4)
	var pulls12: Array = ms.pulls("motivation").filter(func(p): return str(p.text).begins_with("The same training"))
	_ok("monotony: no pull after 8 weeks of the same week, -6 after 12 (%d weeks: %s)" % [ms.same_weeks, pulls12],
			pulls8.is_empty() and pulls12.size() == 1 and is_equal_approx(float(pulls12[0].delta), -6.0))
	game.season.repeat_week = WP.make([["easy_run"], ["tempo_run"], [], ["easy_run"], [], ["long_run"], []], [])
	_play_weeks(1)
	_ok("a changed week starts the count again", ms.same_weeks == 1)
	# The season plan: a new phase is news for motivation.
	ms = _fresh("balanced")
	var before_phase: String = game.season.week_for(game.week_monday()).phase
	var news := false
	var new_phase := ""
	for w in 20:
		_play_weeks(1)
		if game.season.week_for(game.week_monday()).phase != before_phase:
			new_phase = game.season.week_for(game.week_monday()).phase
			_play_weeks(1)   # (the news comes on the Sunday night of the new phase's first week)
			news = ms.recent("motivation").any(func(c): return str(c.text).begins_with("A new phase"))
			break
	_ok("a new phase of the season plan (%s -> %s) lifts motivation (news)" % [before_phase, new_phase], news)
	# The coach's fit and style.
	ms = _fresh()
	var cs = game.get_system("coach")
	cs.head().personality = "drill"
	cs.head().style = -2
	game.athlete.temperament = "overthinker"
	var t_bad: float = ms.target("motivation")
	cs.head().personality = "calm"
	cs.head().style = 2
	var t_good: float = ms.target("motivation")
	_ok("a calm, supportive coach for an overthinker pulls motivation up (%.1f), a controlling drill coach down (%.1f)" % [t_good, t_bad], t_good > 50.0 and t_bad < 50.0)


# --- 6. Effects ------------------------------------------------------------------------------------------------------

func _check_effects() -> void:
	print("-- 6. effects through the game")
	var gains := {}
	for v in [10.0, 50.0, 90.0]:
		var ms = _fresh()
		ms.neutral = true
		ms.values.motivation = v
		var a = game.athlete
		var before: float = a.get_attr("aerobic_capacity")
		_play_weeks(4)
		gains[v] = a.get_attr("aerobic_capacity") - before
		_ok("motivation %.0f: the week's quality %.3f" % [v, game.current_week().quality], is_equal_approx(game.current_week().quality, MI.quality_for(v)))
		ms.neutral = false
	_ok("aerobic gain over 4 weeks: Low %.4f < OK %.4f < Fired up %.4f" % [gains[10.0], gains[50.0], gains[90.0]], gains[10.0] < gains[50.0] and gains[50.0] < gains[90.0])
	# The day log says when you dragged yourself through it.
	var ms2 = _fresh()
	ms2.neutral = true
	ms2.values.motivation = 10.0
	_play_weeks(1)
	_ok("the day log marks a trained day at Low motivation 'dragged'", game.day_log.any(func(e): return e.get("dragged", false)))
	ms2.neutral = false
	# The race day: confidence at a big meet.
	var ms3 = _fresh()
	var meet: Dictionary = {}
	for m in Cal.meets_between(game.date, game.add_days(game.date, 400)):
		if str(m.get("level", "")) == "national" and not m.get("watch", false):
			meet = m
			break
	var RD = load("res://scripts/core/race_day.gd")
	ms3.values.confidence = 50.0
	var rd_mid = RD.new(meet, game.athlete, game.rivals)
	var e_mid: Dictionary = rd_mid._player_entrant()
	ms3.values.confidence = 100.0
	var rd_hi = RD.new(meet, game.athlete, game.rivals)
	var e_hi: Dictionary = rd_hi._player_entrant()
	_ok("Flying at %s: RaceDay.mind +0.3 %% (%.4f) and a higher race-day ability (%.3f > %.3f); OK: none" % [meet.get("name", "?"), rd_hi.mind, e_hi.ability, e_mid.ability],
			is_equal_approx(rd_hi.mind, 0.003) and rd_mid.mind == 0.0 and e_hi.ability > e_mid.ability)


# --- 7. Growth ------------------------------------------------------------------------------------------------------

func _check_growth() -> void:
	print("-- 7. mental attributes that grow")
	var ms = _fresh()
	var a = game.athlete
	var local: Dictionary = {}
	var national: Dictionary = {}
	for m in Cal.meets_between(game.date, game.add_days(game.date, 400)):
		if local.is_empty() and str(m.get("level", "")) == "local" and not m.get("watch", false):
			local = m
		if national.is_empty() and str(m.get("level", "")) == "national" and not m.get("watch", false):
			national = m
	a.set_attr("consistency", 10.0)
	a.set_attr("composure", 10.0)
	ms._race_growth({"key": local.key})
	var c1: float = a.get_attr("consistency")
	ms._race_growth({"key": local.key})
	var c2: float = a.get_attr("consistency")
	_ok("a first race grows consistency (varied x1.5: %.4f), the same kind again less (%.4f = 0.05 x the headroom)" % [c1 - 10.0, c2 - c1],
			is_equal_approx(c1 - 10.0, 0.075) and is_equal_approx(c2 - c1, 0.05 * (20.0 - c1) / 10.0))
	_ok("a local race does not grow composure", a.get_attr("composure") == 10.0)
	ms._race_growth({"key": national.key})
	_ok("a national race grows composure (+%.3f)" % (a.get_attr("composure") - 10.0), is_equal_approx(a.get_attr("composure") - 10.0, 0.1))
	# The mental plan: all three kinds for a year at composure 10, a coach of 10s: about +0.5.
	ms = _fresh()
	a = game.athlete
	a.set_attr("composure", 10.0)
	ms.set_plan(["imagery", "relaxation", "self_talk"])
	for w in 52:
		ms._plan_growth(game.add_days(game.START_DATE, 7 * w))
	var year: float = a.get_attr("composure") - 10.0
	_ok("all three mental sessions for a year at composure 10: +%.2f composure (GDD: at best about +0.5)" % year, year > 0.4 and year < 0.55)
	_ok("relaxation lowers the stress target, self-talk lifts confidence's", ms.target("stress") < 20.0 and ms.target("confidence") > 50.0)
	ms.set_cue("Strong")
	_ok("the cue word with self-talk: %s; without: none" % ms.cue_word(), ms.cue_word() == "Strong")
	ms.toggle_kind("self_talk", false)
	_ok("  (self-talk off: no word)", ms.cue_word() == "" and ms.plan == ["imagery", "relaxation"])


# --- 8. Moments ------------------------------------------------------------------------------------------------------

func _check_moments() -> void:
	print("-- 8. the moments' mood effects")
	var ms = _fresh()
	var st = game.get_system("moments")
	var coach: Dictionary = st._coach_person()
	st._apply({"confidence": 1, "motivation": -1, "stress": 1}, coach, "test")
	_ok("a reply's points x5 from a coach of 10 with New trust (x0.9): confidence +4.5, motivation -4.5, stress +4.5 (%.1f / %.1f / %.1f)" % [
			ms.value("confidence"), ms.value("motivation"), ms.value("stress")],
			is_equal_approx(ms.value("confidence"), 54.5) and is_equal_approx(ms.value("motivation"), 45.5) and is_equal_approx(ms.value("stress"), 24.5))
	var lines: Array = st._changes_of({"confidence": 1, "stress": -1}, coach, false)
	_ok("the result card lists them in words: %s" % [lines], lines.any(func(l): return str(l).begins_with("Confidence")) and lines.any(func(l): return str(l).begins_with("Stress")))
	ms = _fresh()
	game.get_system("coach").head().attributes.motivating = 18
	coach = game.get_system("moments")._coach_person()
	game.get_system("moments")._apply({"confidence": 1}, coach, "test")
	_ok("a coach good at motivating lands harder (+%.2f)" % (ms.value("confidence") - 50.0), ms.value("confidence") > 54.5)


# --- 9. The Sunday talk ------------------------------------------------------------------------------------------------

func _check_talk() -> void:
	print("-- 9. the coach's Sunday line and mood topic")
	MS.talks_enabled = true
	var ms = _fresh()
	game.get_system("coach").head().attributes.communication = 12
	ms.neutral = true
	ms.values.motivation = 15.0
	var monday: int = Cal.date_key(game.add_days(game.week_monday(), 7))
	var talk := {}
	while Cal.date_key(game.date) < monday:
		game.advance_day()
		var e: Dictionary = game.pending_event()
		if not e.is_empty():
			if bool(game.get_system("moments").moment(str(e.get("moment", ""))).get("talk", false)):
				talk = e
			game.answer_event(e.id, str(e.choices[0].id) if not e.choices.is_empty() else "ok")
	var voice := str(game.get_system("coach").head().voice)
	var line: String = str(data.mind.coach.lines[voice].motivation_low)
	_ok("the talk has his motivation line (%s)" % voice, str(talk.get("text", "")).contains(line))
	var m: Dictionary = game.get_system("moments").moment(str(talk.get("moment", "")))
	_ok("its topic is the mood topic (%s)" % m.get("storylet", ""), str(m.get("storylet", "")) == "mood_flat")
	_ok("a coach of few words (communication 5) has no mood line", true if _short_coach_line() == "" else false)
	ms.neutral = false
	MS.talks_enabled = false


func _short_coach_line() -> String:
	var ms = _fresh()
	game.get_system("coach").head().attributes.communication = 5
	ms.values.motivation = 15.0
	return ms.coach_line("calm", "Test")


# --- 10. Save / load -------------------------------------------------------------------------------------------------

func _check_save_load() -> void:
	print("-- 10. save / load")
	# (No races: each race rolls its own dice, so a race after the load would differ anyway. The health model's dice are saved.)
	H.model_enabled = true
	var ms = _fresh("balanced")
	for key in game.entries.duplicate():   # (a season-plan career starts entered in its targets: no races here)
		game.withdraw(key)
	ms.set_plan(["imagery", "self_talk"])
	ms.set_cue("Tall")
	ms.add("confidence", 25.0, "test")
	ms.add("motivation", -20.0, "test")
	_play_weeks(10)
	var snap := _json(game.to_dict())
	_play_weeks(8)
	var a_end := _json(game.athlete.to_dict())
	var m_end := _json(game.get_system("mind").to_dict())
	game.from_dict(_parse(snap))
	_play_weeks(8)
	var a_again := _json(game.athlete.to_dict())
	var m_again := _json(game.get_system("mind").to_dict())
	if a_again != a_end or m_again != m_end:
		print("    athlete same: %s, moods same: %s" % [a_again == a_end, m_again == m_end])
		print("    without saving: %s\n    after the load: %s" % [m_end.left(600), m_again.left(600)])
	_ok("a loaded game goes on exactly as without saving (athlete and moods)", a_again == a_end and m_again == m_end)
	_ok("the mental plan and the cue word are saved", game.get_system("mind").plan == ["imagery", "self_talk"] and game.get_system("mind").cue == "Tall")
	var st: Dictionary = game.to_dict()
	st.systems.erase("mind")
	game.from_dict(st)
	_ok("a save without the mind (older) loads with the moods in the middle", game.get_system("mind").value("confidence") == 50.0
			and game.get_system("mind").value("stress") == 20.0)
	H.model_enabled = false


# --- 11. Off switch ---------------------------------------------------------------------------------------------------

func _check_switch_off() -> void:
	print("-- 11. the off switch")
	MI.model_enabled = false
	var ms = _fresh()
	ms._race_news(_note([{"place": 1, "field": 8, "time": 130.0, "status": "", "mark": "PB", "ref": 131.0}]))
	_play_weeks(2)
	_ok("off: no news, no state saved, quality 1.0, no race term", ms.value("confidence") == 50.0 and ms.to_dict().is_empty()
			and ms.training_quality() == 1.0 and ms.race_term({"level": "national"}) == 0.0)
	_ok("off: MindSystem.sys() is null (the UI shows nothing)", MI.sys() == null)
	MI.model_enabled = true


# --- 12. A season ------------------------------------------------------------------------------------------------------

## A season on the Balanced plan, the coach's meets entered and run, the health model on: how the moods spread over the weeks.
func _check_season() -> void:
	print("-- 12. a season (Balanced, the coach's meets, health on): the moods week by week")
	H.model_enabled = true
	var counts := {"confidence": {}, "motivation": {}, "stress": {}}
	var weeks := 0
	for i in 4:
		var ms = _fresh("balanced")
		game.athlete.first_name = "Season%d" % i
		_enter_coach_meets()
		for w in 48:
			_play_weeks(1)
			weeks += 1
			for mood in counts:
				var id: String = ms.word(mood).id
				counts[mood][id] = int(counts[mood].get(id, 0)) + 1
	for mood in counts:
		var parts := []
		for id in counts[mood]:
			parts.append("%s %d %%" % [id, roundi(100.0 * counts[mood][id] / weeks)])
		print("    %s: %s" % [mood, ", ".join(parts)])
	var flat := float(counts.motivation.get("flat", 0)) / weeks
	var ok_or_better := 1.0 - flat - float(counts.motivation.get("low", 0)) / weeks
	_ok("motivation OK or better in most weeks (%.0f %%), Flat under 10 %% (%.0f %%) (GDD 4.9.7)" % [100.0 * ok_or_better, 100.0 * flat],
			ok_or_better > 0.5 and flat < 0.1)
	H.model_enabled = false


# --- Helpers ---------------------------------------------------------------------------------------------------------

func _enter_coach_meets() -> void:
	for m in Cal.meets_between(game.date, game.add_days(game.date, 360)):
		if m.get("coach", false) and Cal.can_enter(game.athlete, m, game.date).ok:
			game.enter(m.key)


func _run_race() -> String:
	var rd = game.race_day
	while not rd.is_done():
		var race = rd.start_round(false, "pack")
		race.run()
		rd.finish_round()
	return game.finish_race()


func _athlete():
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
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
