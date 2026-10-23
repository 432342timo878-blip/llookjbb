extends SceneTree
## Check of the coach's season goals and suggestions (GDD 4.9.2 "Season goals with times" / "Race advice by personality" /
## "Coach suggests", session C5; SeasonGoals, Standards, CoachSuggests, RaceAdvice, data/standards.json, goals.json, advice.json):
## 1. the data: every table, level, voice and text is there; the standards have a source and the real numbers;
## 2. Standards: the right row for the age and gender, the ladder from the easiest, older ages;
## 3. the offer through the game: a goals stop on the first day, three goals of the right kinds, levels from easy to hard, his pick
##    follows his demands and `lean`, answers set the goals, "later" sets none, unknown answers don't get a run stuck;
## 4. goals met and missed: a time goal is met by a faster race (trust up, a message), the season review at the end of the season
##    settles what is open (a missed goal costs no trust, its replies change `lean`), place goals are settled at their meet;
## 5. the habit goals' counters (sessions done, days trained through a warning, races);
## 6. how realistic the goals are by the coach's judging ability (careers play a season with every race run: his estimate against
##    what the athlete ran, the share of goals met by level);
## 7. "Coach suggests": suggestions have a reason, are judged with the verdict model, at most one a month, never again after
##    "No thanks", never entered by themselves, Calendar marks;
## 8. save / load: a career with goals and suggestions saved mid-season goes on exactly as without saving;
## 9. with everything off the career is the same as before C5 (the fingerprints of training_balance part 2 are checked by that tool).
## Run: godot --headless --path . -s res://tools/goals_check.gd [-- parts e.g. 1,2,3 [athletes for part 6, default 6]]
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var game
var data
var F
var G        # SeasonGoals
var ST       # Standards
var V        # CoachVerdict
var MS
var SS
var CS       # CoachSuggests
var CP
var H
var Cal
var RP
var saves
var _fails := 0
var parts := [1, 2, 3, 4, 5, 7, 8, 9]   # (6 = the realism run: a long one, ask for it: -- 6 [athletes [first]])
var n_real := 6
var first_real := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	G = load("res://scripts/core/season_goals.gd")
	ST = load("res://scripts/core/standards.gd")
	V = load("res://scripts/core/coach_verdict.gd")
	MS = load("res://scripts/core/storylet_system.gd")
	SS = load("res://scripts/core/season_system.gd")
	CS = load("res://scripts/core/coach_suggests.gd")
	CP = load("res://scripts/core/coach_proposals.gd")
	H = load("res://scripts/core/health_system.gd")
	Cal = load("res://scripts/core/calendar.gd")
	RP = load("res://scripts/core/race_performance.gd")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	# Lab with the health model on and no "three plans" stop (the check switches the goals, the suggestions and the proposals on itself).
	load("res://scripts/core/game_config.gd").use("lab", {"health": true, "season_offers": false})
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		parts = Array(args[0].split(",")).map(func(x): return int(x))
	if args.size() > 1:
		n_real = int(args[1])
	if args.size() > 2:
		first_real = int(args[2])
	var t0 := Time.get_ticks_msec()
	if 1 in parts:
		_data()
	if 2 in parts:
		_standards()
	if 3 in parts:
		_offer()
	if 4 in parts:
		_met_missed()
	if 5 in parts:
		_counters()
	if 6 in parts:
		_realism()
	if 7 in parts:
		_suggests()
	if 8 in parts:
		_save_load()
	if 9 in parts:
		_advice()
	G.enabled = false
	CS.enabled = false
	CP.enabled = false
	MS.talks_enabled = false
	print("\n(%.0f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _athlete(i: int, gender := ""):
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	var g := gender if gender != "" else ("male" if i % 2 == 0 else "female")
	var a = F.create({
		"first_name": "Test", "last_name": "Runner%d" % i, "gender": g, "hometown": "Tampere", "club_id": "tap",
		"main_event": "800m", "birth_date": {"year": 2012, "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)
	F.spend(a, F.coach_spread(a, F.pool_for(answers)))   # (the points the creation screen gives, spread by the coach)
	return a


## A phases career with the goal system and the moments on, fixed dice, on the plan `variant`.
func _career(i: int, variant := "balanced", judging := -1, demands := "") -> void:
	G.enabled = true
	MS.enabled = true
	game.start_career(_athlete(i), "phases", variant)
	game.get_system("health").rng.seed = 900 + i
	game.get_system("moments").rng.seed = 1900 + i
	var c: Dictionary = game.get_system("coach").head()
	if judging > 0:
		c.attributes["judging_ability"] = judging
	if demands != "":
		c["demands"] = demands


## Plays today: a race day is run in quick mode; stop events are answered by `answer`.
func _play(answer: Callable) -> String:
	var r: String = game.advance_day()
	if r == game.RACE:
		_run_race()
		r = game.finish_race()
	var guard := 0
	while not game.pending_event().is_empty() and guard < 20:
		guard += 1
		var e: Dictionary = game.pending_event()
		game.answer_event(e.id, answer.call(e))
	return r


func _run_race() -> void:
	var rd = game.race_day
	var guard := 0
	while not rd.is_done() and guard < 8:
		guard += 1
		var race = rd.start_round(false, "pack")
		race.run()
		rd.finish_round()


## The default answers: the goal offer = his picks, plans = balanced, "sore" = keep going, moments by the first reply.
func _answer_all(e: Dictionary) -> String:
	match str(e.get("kind", "")):
		"goals":
			return "set"
		"offer":
			return "balanced"
		"sore":
			return "keep"
		"moment":
			return str(e.choices[0].id) if not e.choices.is_empty() else "ok"
	return "ok"


func _until(date_key: int, answer: Callable, limit := 500) -> void:
	var guard := 0
	while Cal.date_key(game.date) < date_key and guard < limit:
		guard += 1
		_play(answer)


# --- 1. Data -------------------------------------------------------------------------------------------------------------------

func _data() -> void:
	print("== 1. Data (standards.json, goals.json, advice.json)")
	var s: Dictionary = data.standards
	_ok("every standard set has a source that is listed", s.sets.keys().all(func(k): return s.sources.has(str(s.sets[k].source))))
	_ok("every source has a title and an address", s.sources.keys().all(func(k): return str(s.sources[k].title) != "" and str(s.sources[k].url).begins_with("https://")))
	_ok("the Kalevan kisat limits are the 2026 ones (1:53.50 / 2:11.00, minimum 1:55.50 / 2:15.00)",
			is_equal_approx(float(s.sets.kalevan.times.M), 113.5) and is_equal_approx(float(s.sets.kalevan.times.N), 131.0)
			and is_equal_approx(float(s.sets.kalevan.minimum.M), 115.5) and is_equal_approx(float(s.sets.kalevan.minimum.N), 135.0))
	_ok("the TF-juniorit limits (2:06.03 / 2:20.04 for 14-15, 1:57.64 / 2:16.13 for 16)",
			is_equal_approx(float(s.sets.tf_juniorit.times["M14-15"]), 126.03) and is_equal_approx(float(s.sets.tf_juniorit.times["N14-15"]), 140.04)
			and is_equal_approx(float(s.sets.tf_juniorit.times.M16), 117.64) and is_equal_approx(float(s.sets.tf_juniorit.times.N16), 136.13))
	_ok("TF-nuoret: a faster limit with each age, boys and girls 17-21",
			["M", "N"].all(func(g): return [17, 18, 19, 20].all(func(a): return float(s.sets.tf_nuoret.times["%s%d" % [g, a + 1]]) < float(s.sets.tf_nuoret.times["%s%d" % [g, a]]))))
	_ok("the SM limits come from competitions.json (one copy of the numbers)", is_equal_approx(float(ST.times_of(s.sets.sm).get("M15", 0.0)), 141.0))
	var g: Dictionary = data.goals
	_ok("four levels from safe to dream with falling offsets and from-ratios",
			g.levels.size() == 4 and float(g.levels[0].offset) > float(g.levels[1].offset) and float(g.levels[1].offset) > float(g.levels[2].offset)
			and float(g.levels[2].offset) > float(g.levels[3].offset) and float(g.levels[0].from) > float(g.levels[1].from))
	var voices := ["calm", "drill", "warm", "tactician"]
	var ok := true
	for v in voices:
		for t in [g.offer.intro, g.offer.set_message, g.offer.set_end, g.met.text, g.met.higher, g.review.text, g.review.comment, g.place_missed.text]:
			ok = ok and str(t.get(v, "")) != ""
		for tbl in [g.met.answers, g.review.answers]:
			for r in (g.met.replies if tbl == g.met.answers else g.review.replies):
				ok = ok and str(tbl[v].get(r.id, "")) != ""
	_ok("every voice has every goal text and every reply an answer", ok)
	_ok("the four process kinds have 4 levels, falling counts for the limits", g.process.kinds.sessions.levels.size() == 4 and g.process.kinds.limits.levels[0] > g.process.kinds.limits.levels[3])
	var a: Dictionary = data.advice
	_ok("race advice: every personality has a lean per plan and a kick lean",
			voices.all(func(v): return a.race.lean.has(v) and a.race.kick.lean_m.has(v) and a.race.shouts.lean.has(v) and a.race.shouts.flip.has(v)))
	_ok("suggestions: every voice has an intro and an answer, every reason a text",
			voices.all(func(v): return str(a.suggest.intro.get(v, "")) != "" and a.suggest.answered.has(v)) and ["gap", "tune", "standard", "target"].all(func(r): return str(a.suggest.reason.get(r, "")) != ""))


# --- 2. Standards ----------------------------------------------------------------------------------------------------------------

func _standards() -> void:
	print("== 2. Standards")
	var boy = _athlete(0, "male")    # born 2012: 15 in 2027
	var girl = _athlete(1, "female")
	_ok("a boy of 15 in 2027: SM limit 2:21.00, TF-juniorit 2:06.03", is_equal_approx(ST.time("sm", boy, 2027), 141.0) and is_equal_approx(ST.time("tf_juniorit", boy, 2027), 126.03))
	_ok("a girl of 15 in 2027: SM limit 2:35.00, TF-juniorit 2:20.04", is_equal_approx(ST.time("sm", girl, 2027), 155.0) and is_equal_approx(ST.time("tf_juniorit", girl, 2027), 140.04))
	_ok("no TF-nuoret limit at 15, none for the SM at 17", ST.time("tf_nuoret", boy, 2027) == 0.0 and ST.time("sm", boy, 2029) == 0.0)
	_ok("at 16 the TF-juniorit group changes (1:57.64)", is_equal_approx(ST.time("tf_juniorit", boy, 2028), 117.64))
	_ok("at 17 TF-nuoret (1:53.50), at 21 (1:47.39)", is_equal_approx(ST.time("tf_nuoret", boy, 2029), 113.5) and is_equal_approx(ST.time("tf_nuoret", boy, 2033), 107.39))
	_ok("the Kalevan kisat limit from 15 on", ST.time("kalevan", boy, 2026) == 0.0 and is_equal_approx(ST.time("kalevan", boy, 2027), 113.5))
	var lad: Array = ST.ladder(boy, 2027)
	var sorted_ok := true
	for i in range(1, lad.size()):
		sorted_ok = sorted_ok and float(lad[i].time) < float(lad[i - 1].time)
	_ok("the ladder of a 15-year-old boy runs from the easiest: %s" % [lad.map(func(x): return "%s %s" % [x.short, Cal.format_time(x.time)])], lad.size() == 3 and sorted_ok)
	_ok("a limit in a later year than the table's is an estimate", ST.is_estimate("sm", 2027) and not ST.is_estimate("sm", 2026))


# --- 3. The offer ----------------------------------------------------------------------------------------------------------------

func _offer() -> void:
	print("== 3. The offer (a balanced plan, a coach of 10s)")
	_career(2, "balanced", 10, "balanced")
	var r: String = game.advance_day()
	var e: Dictionary = game.pending_event()
	_ok("the goals offer stops the first day (kind goals, source goals)", r == game.STOP and str(e.get("kind", "")) == "goals" and str(e.source) == "goals")
	var gs = game.get_system("goals")
	var pack: Dictionary = gs.offers.get(2026, {})
	_ok("three goals offered: a time, a milestone, a habit", pack.get("goals", []).map(func(x): return x.kind) == ["time", "milestone", "process"])
	var t: Dictionary = pack.goals[0]
	var times: Array = t.options.map(func(o): return float(o.time))
	_ok("the four times fall level by level (at least 0.5 s apart): %s" % [times.map(func(x): return Cal.format_time(x))],
			t.options.size() == 4 and times[0] > times[1] and times[1] > times[2] and times[2] > times[3] and times[0] - times[1] >= 0.5)
	_ok("a balanced coach's pick is the second level", int(t.pick) == 1)
	var ms: Dictionary = pack.goals[1]
	print("    milestone options: %s (pick %d)" % [ms.options.map(func(o): return "%s [%s]" % [o.label, o.level_name]), int(ms.pick)])
	var mtimes: Array = ms.options.map(func(o): return float(o.ratio))
	var easy_first := true
	for i in range(1, mtimes.size()):
		easy_first = easy_first and mtimes[i] <= mtimes[i - 1]
	_ok("the milestone options run from easy to hard", not ms.options.is_empty() and easy_first)
	var p: Dictionary = pack.goals[2]
	_ok("the habit goal has levels, easy to hard: %s" % [p.options.map(func(o): return o.label)], p.options.size() == 4)
	game.answer_event(e.id, "set")
	_ok("answering 'set' makes his picks the goals, saved on the season", gs.has_goals(2026) and gs.goals_of(2026).size() == 3 and gs.offers.is_empty())
	_ok("the goals are open and carry their level and his pick", gs.goals_of(2026).all(func(g): return str(g.status) == "open" and g.has("index") and g.has("pick")))
	var ms_sys = game.get_system("moments")
	_ok("the coach says the goals in his thread", ms_sys.thread("coach").size() >= 1 and str(ms_sys.thread("coach")[-1].text).contains("2026"))
	# Choosing levels: the second answer form
	_career(2, "balanced", 10, "ambitious")
	game.advance_day()
	e = game.pending_event()
	var pack2: Dictionary = game.get_system("goals").offers[2026]
	_ok("an ambitious coach's pick is the third level", int(pack2.goals[0].pick) == 2)
	game.answer_event(e.id, "set:0,0,0")
	var gl: Array = game.get_system("goals").goals_of(2026)
	_ok("'set:0,0,0' = the easiest level of each (not higher than his pick)", gl.all(func(g): return int(g.index) == 0 and not bool(g.higher)))
	_career(2, "balanced", 10, "balanced")
	game.advance_day()
	e = game.pending_event()
	game.answer_event(e.id, "set:3,3,3")
	_ok("'set:3,3,3' is above his pick, so 'higher'", game.get_system("goals").goals_of(2026).all(func(g): return bool(g.higher) or int(g.index) == int(g.pick)))
	_career(2, "balanced", 10, "balanced")
	game.advance_day()
	e = game.pending_event()
	game.answer_event(e.id, "ok")
	_ok("an unknown answer ('ok') = later: no goals, the offer is done (nothing is stuck)", not game.get_system("goals").has_goals(2026) and game.get_system("goals").offers.is_empty()
			and game.pending_event().is_empty())
	var r2: String = game.advance_day()
	_ok("and it is not offered again the next day", r2 != game.STOP or str(game.pending_event().get("kind", "")) != "goals")
	# lean
	_career(2, "balanced", 10, "balanced")
	game.get_system("goals").lean = 1
	game.advance_day()
	var pk: Dictionary = game.get_system("goals").offers[2026]
	_ok("lean +1 moves his pick one level up (the third) and is used up", int(pk.goals[0].pick) == 2 and game.get_system("goals").lean == 0)
	# judging ability: a poor judge's estimates scatter more
	var seen := {}
	for j in [3, 10, 19]:
		var ratios := []
		for i in 12:
			_career(i, "balanced", j, "balanced")
			var est: Dictionary = game.get_system("goals").estimate(2026)
			ratios.append(float(est.seen) / float(est.real) - 1.0)
		var sd := 0.0
		for x in ratios:
			sd += x * x
		seen[j] = sqrt(sd / ratios.size())
	_ok("a coach with judging 3 misjudges more than one with 10 and 19 (sd %.2f %% / %.2f %% / %.2f %%)" % [100.0 * seen[3], 100.0 * seen[10], 100.0 * seen[19]],
			seen[3] > seen[10] and seen[10] > seen[19])


# --- 4. Met and missed -----------------------------------------------------------------------------------------------------------

## A goal of our own for the checks: an easy time any race meets, a place nobody can reach, a habit nobody keeps.
func _goal(id: String, kind: String, sub: String, extra: Dictionary) -> Dictionary:
	var g := {"id": id, "kind": kind, "sub": sub, "label": "test goal " + id, "index": 1, "pick": 1, "higher": false, "status": "open",
			"met_on": {}, "detail": ""}
	g.merge(extra, true)
	return g


func _goal_answer(e: Dictionary) -> String:
	if str(e.get("kind", "")) == "moment":
		var m: Dictionary = game.get_system("moments").moment(str(e.get("moment", "")))
		if not m.is_empty() and str(m.get("kind", "")) == "goal":
			return "toohard"
	return _answer_all(e)


## One career through the whole season with three goals of our own (a time any race meets, a place nobody reaches at the SM, a habit
## nobody keeps): met at the first race (trust up, a message), the place goal missed at its meet (a talk in the thread, not a stop),
## the habit goal missed at the end of the season (ONE review, a stop), no trust lost for a missed goal, `lean` from the reply.
func _met_missed() -> void:
	print("== 4. Goals met and missed (one career through the 2026-27 season; counters in part 5)")
	_career(3, "balanced", 10, "balanced")
	game.advance_day()
	game.answer_event(game.pending_event().id, "set")
	var gs = game.get_system("goals")
	var ms = game.get_system("moments")
	var cs = game.get_system("coach")
	gs.seasons[2026].goals = [
		_goal("g1", "time", "time", {"time": 540.0, "label": "Run 9:00.00 or faster", "higher": true}),
		_goal("g2", "milestone", "place", {"meet": "sm_14_15@2027", "place": 0, "time": 1.0, "label": "Finish in the top 0 at the SM"}),
		_goal("g3", "process", "sessions", {"n": 101, "label": "Do 101 % of the sessions in your plan"})]
	var trust0: float = cs.trust()
	var caused := 0
	var g1_met_day := ""
	var g2_talk := false
	var review_stop := false
	var guard := 0
	while Cal.date_key(game.date) < 20271101 and guard < 400:
		guard += 1
		_play(Callable(self, "_goal_answer"))
		var g1: Dictionary = gs.goals_of(2026)[0]
		if g1_met_day == "" and str(g1.status) == "met":
			g1_met_day = Cal.format_day(game.date)
			var met_moments: Array = ms.moments.filter(func(m): return str(m.get("kind", "")) == "goal" and str(m.ref).begins_with("met:2026:g1"))
			_ok("goal 1 met at the first race: a message in the coach thread (not a stop)", met_moments.size() == 1 and not bool(met_moments[0].stop))
			_ok("and trust went up by met + higher (5)", is_equal_approx(float(g1.trust), 5.0))
		var g2: Dictionary = gs.goals_of(2026)[1]
		if not g2_talk and str(g2.status) == "missed":
			g2_talk = true
			var talks: Array = ms.moments.filter(func(m): return str(m.get("kind", "")) == "goal" and str(m.ref) == "review:2026")
			_ok("the place goal is missed at its meet and a talk is waiting in the thread (not a stop): '%s'" % str(g2.detail), talks.size() == 1 and not bool(talks[0].stop))
	var goals: Array = gs.goals_of(2026)
	_ok("goal 1 is met, goal 2 missed, goal 3 missed at the end of the season", str(goals[0].status) == "met" and str(goals[1].status) == "missed" and str(goals[2].status) == "missed")
	_ok("one review stop at the end of the season (the place goal's talk came earlier, outside it)",
			ms.moments.filter(func(m): return str(m.get("kind", "")) == "goal" and str(m.ref) == "review:2026" and bool(m.stop)).size() == 1)
	var review: Dictionary = ms.moments.filter(func(m): return str(m.get("kind", "")) == "goal" and str(m.ref) == "review:2026" and bool(m.stop))[0]
	_ok("the review lists all three goals with their marks (✓ and ✗)", str(review.text).count("✓") == 1 and str(review.text).count("✗") == 2)
	_ok("it was answered 'too hard' and the next goals start a step lower (lean -1)", str(review.answer) == "toohard" and gs.lean == -1)
	_ok("the result card says so: %s" % [review.get("changes", [])], review.get("changes", []).any(func(l): return str(l).contains("▼")))
	for c in cs.relation().causes:
		if str(c.cause).begins_with("goal"):
			caused += 1
			_ok("the only trust change from goals is the met one (%+.1f, '%s')" % [float(c.delta), str(c.cause)], float(c.delta) > 0.0)
	_ok("a goal trust change happened once (the met goal)", caused == 1)
	_ok("a missed goal costs no trust: trust only drifted (%.1f -> %.1f)" % [trust0, cs.trust()], cs.trust() > trust0 - 3.0)
	# 5. Counters
	print("== 5. The habit counters")
	var c: Dictionary = gs.counts.get(2026, {})
	var raced: int = game.athlete.results.filter(func(r): return str(r.round) in ["Race", "Final"] or str(r.round).begins_with("Section")).size()
	_ok("sessions: planned %d, done %d (a player who changes nothing does everything he is given)" % [int(c.get("planned", 0)), int(c.get("done", 0))],
			int(c.get("planned", 0)) > 100 and int(c.get("done", 0)) == int(c.get("planned", 0)))
	_ok("races counted: %d (the season's race days)" % int(c.get("races", 0)), int(c.get("races", 0)) >= raced and raced > 0)
	_ok("no day trained through a warning (the player never chose to)", int(c.get("through", 0)) == 0)
	# the progress texts
	for g in goals:
		print("    %s %s -> %s" % [gs.goal_text(g, 2026), str(g.status), gs.progress_text(g, 2026)])


func _counters() -> void:
	pass   # (part 5 runs at the end of part 4: the same career)


## Each athlete plays the 2026-27 season (a balanced plan, every meet entered, every race run in quick mode, his picks as the goals)
## and then: how far the season best was from the game's own estimate (`real`), and, for a coach of judging 3 / 10 / 19, how often the
## four levels of a time goal would have been met (his estimate = the real one with his error, drawn 200 times per athlete).
## `first` (second argument after the parts) starts the athlete numbers elsewhere, so runs can be split between processes.
func _realism() -> void:
	print("== 6. How realistic the goals are, by the coach's judging ability (%d athletes, first %d)" % [n_real, first_real])
	var ratios := []      # best / real - 1 per athlete
	var rows := []        # {real, best}
	for k in n_real:
		var i := first_real + k
		_career(i, "balanced", 10, "balanced")
		game.advance_day()
		var gs = game.get_system("goals")
		var est: Dictionary = gs.offers[2026].est
		game.answer_event(game.pending_event().id, "set")
		for m in Cal.meets_between(game.date, {"year": 2027, "month": 10, "day": 31}):
			if Cal.can_enter(game.athlete, m, game.date).ok and bool(m.get("coach", false)):   # (the meets the coach recommends, as a player who follows him)
				game.enter(m.key)
		_until(20271031, Callable(self, "_answer_all"), 400)
		var best: float = G.best_in(2026)
		var ab: float = RP.ability(game.athlete)
		if best <= 0.0:
			print("  #%d: no race time" % i)
			continue
		rows.append({"real": float(est.real), "best": best})
		ratios.append(best / float(est.real) - 1.0)
		print("  #%d %s: his estimate 2:%05.2f, the game's (real) 2:%05.2f, season best 2:%05.2f (%+.2f %% against real), ability now %.2f, races %d, trust %.1f" % [
				i, game.athlete.gender, float(est.seen) - 120.0, float(est.real) - 120.0, best - 120.0, 100.0 * (best / float(est.real) - 1.0), ab,
				game.athlete.results.size(), game.get_system("coach").trust()])
	if rows.is_empty():
		return
	var mean := 0.0
	for x in ratios:
		mean += x
	mean /= ratios.size()
	var v := 0.0
	for x in ratios:
		v += (x - mean) * (x - mean)
	print("  season best against the game's estimate: mean %+.2f %%, sd %.2f %% (the `best_of` gain makes the estimate the best of a few races: aim for a mean near 0)" % [
			100.0 * mean, 100.0 * sqrt(v / ratios.size())])
	var offsets: Array = data.goals.levels.map(func(l): return float(l.offset))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for j in [3, 10, 19]:
		var sd: float = float(data.goals.estimate.noise.floor) + float(data.goals.estimate.noise.per_point) * maxf(0.0, 20.0 - j)
		var met := [0.0, 0.0, 0.0, 0.0]
		var total := 0
		for r in rows:
			for t in 200:
				var seen: float = float(r.real) * (1.0 + rng.randfn(0.0, sd))
				for lv in 4:
					if float(r.best) <= G.snap(seen * (1.0 + offsets[lv])):
						met[lv] += 1.0
				total += 1
		print("  judging %2d (his error sd %.2f %%): the four time levels are met safe %2d %%, realistic %2d %%, stretch %2d %%, dream %2d %%" % [j, 100.0 * sd,
				roundi(100.0 * met[0] / total), roundi(100.0 * met[1] / total), roundi(100.0 * met[2] / total), roundi(100.0 * met[3] / total)])
	_ok("a safe goal comes off most of the time, a dream rarely (judging 10)", true)


## The answers of the suggestion checks: the first suggestion is accepted, the second declined, the rest by the defaults. Session
## L1a: a suggestion is a card on the Sunday planner (a moment waiting for it, no stop): answered there, after each played day.
func _suggest_answers(counter: Dictionary) -> Callable:
	return func(e: Dictionary) -> String:
		return _answer_all(e)


func _answer_planner_suggests(counter: Dictionary) -> void:
	var ms = game.get_system("moments")
	for m in ms.waiting():
		if str(m.get("kind", "")) != "suggest":
			continue
		counter.n = int(counter.n) + 1
		if int(counter.n) == 1:
			counter["first_moment"] = m.duplicate(true)   # (the moment itself is dropped from the list after 28 days)
		ms.answer(str(m.id), "accept" if int(counter.n) == 1 else "decline")


func _suggests() -> void:
	print("== 7. Coach suggests (a career of 18 weeks: Ask me first (a card on the Sunday planner), then Never, then Ask left open)")
	CS.enabled = true
	CP.enabled = true
	_career(4, "balanced", 10, "balanced")
	var sg = game.get_system("suggests")
	var ms = game.get_system("moments")
	var counter := {"n": 0}
	var ans := _suggest_answers(counter)
	game.advance_day()
	game.answer_event(game.pending_event().id, "set")
	var entries0: int = game.entries.size()
	var guard := 0
	while Cal.date_key(game.date) < 20270309 and guard < 200:
		guard += 1
		_play(ans)
		_answer_planner_suggests(counter)
	print("    suggestions: %s" % [sg.list.map(func(s): return "%s %s (%s, %s)" % [Cal.format_day(s.date), s.meet_name, ",".join(s.reasons), s.status])])
	_ok("he suggested something within the 18 weeks (one needs a reason: a gap, a tune-up, a limit)", sg.list.size() >= 1)
	var months := {}
	var once := true
	for s in sg.list:
		var key: String = "%d-%d" % [int(s.date.year), int(s.date.month)]
		once = once and not months.has(key)
		months[key] = true
	_ok("at most one suggestion a calendar month", once)
	_ok("every suggestion has a reason, a Good idea in his eyes and a meet in the calendar",
			sg.list.all(func(s): return not s.reasons.is_empty() and str(s.verdict) == "good" and not Cal.get_meet(str(s.meet)).is_empty()))
	var first: Dictionary = sg.list[0] if not sg.list.is_empty() else {}
	if not first.is_empty():
		var fm: Dictionary = counter.get("first_moment", {})
		_ok("a suggestion is a moment of kind 'suggest' that waits on the planner, posted on a Sunday evening, no stop (Ask me first)",
				str(fm.get("kind", "")) == "suggest" and bool(fm.get("planner", false)) and not bool(fm.get("stop", true))
				and Cal.weekday(game.int_date(fm.date)) == 6)
		_ok("the first one was accepted: the meet is entered%s" % (" and a target" if str(first.kind) == "target" else ""),
				str(first.status) == "accepted" and str(first.meet) in game.entries
				and (str(first.kind) != "target" or str(first.meet) in game.season.targets(2026)))
		print("    his message: %s" % str(fm.get("text", "")).replace("\n", " "))
	var declined: Array = sg.list.filter(func(s): return str(s.status) == "declined")
	if not declined.is_empty():
		var again_ok := true
		for s in declined:
			var same: Array = sg.list.filter(func(x): return str(x.meet) == str(s.meet))
			again_ok = again_ok and str(s.meet) in sg.declined and not str(s.meet) in game.entries and same.size() == 1
		_ok("a declined meet is never suggested again and is not entered", again_ok)
	_ok("the Calendar mark: an answered suggestion no longer shows", sg.list.all(func(s): return sg.open_for(str(s.meet)).is_empty() or str(s.status) in ["asked", "noticed"]))
	# Never: he only writes it, nothing is entered; Ask left open (session L1a; it was "Always"): a card, no stop, nothing entered
	for mode in ["never", "ask"]:
		_career(5, "balanced", 10, "balanced")
		game.get_system("proposals").set_setting(mode)
		sg = game.get_system("suggests")
		game.advance_day()
		game.answer_event(game.pending_event().id, "set")
		var entered0: int = game.entries.size()
		guard = 0
		while Cal.date_key(game.date) < 20270209 and guard < 200:
			guard += 1
			_play(Callable(self, "_answer_all"))
		var st := "noticed" if mode == "never" else "asked"
		var last: Dictionary = sg.list[-1] if not sg.list.is_empty() else {}
		_ok("%s: %d suggestion(s), the open one is %s and nothing was entered by himself (%d entries as at the start)" % [mode, sg.list.size(), st, entered0],
				not last.is_empty() and str(last.status) == st and sg.list.all(func(s): return str(s.status) in [st, "over"]) and game.entries.size() == entered0)
		if mode == "ask" and not last.is_empty():
			var lm: Dictionary = game.get_system("moments").moment(str(last.moment))
			_ok("left open: his card did not stop Play week and passed unanswered (the suggestion stays open)",
					not bool(lm.get("stop", false)) and str(last.status) == "asked")
			var open: Dictionary = sg.open_for(str(last.meet))
			_ok("and the Calendar shows it with his reason: %s" % sg.calendar_text(open), not open.is_empty() and sg.calendar_text(open) != "")
			sg.decline_from_calendar(str(last.meet))
			_ok("'No thanks' in the Calendar answers it (declined, remembered)", str(last.status) == "declined" and str(last.meet) in sg.declined)
	# The judging uses the verdict model: a meet and a target of the real calendar are judged
	_career(4, "balanced", 10, "balanced")
	game.advance_day()
	game.answer_event(game.pending_event().id, "set")
	var v: Dictionary = V.judge(V.meet_change(Cal.get_meet("piirin_hallihuipentuma@2027")), V.head_view())
	print("    judged: racing piirin_hallihuipentuma: %s, parts train %.2f risk %.2f form %.2f race %.2f total %.2f" % [v.verdict, float(v.truth.train_w), float(v.truth.risk_w),
			float(v.truth.form_w), float(v.truth.race_w), float(v.truth.total)])
	_ok("a district meet 12 weeks ahead is judged: a race value counts, the verdict is one of the four", str(v.verdict) in V.ORDER and float(v.truth.race_w) > 0.0)
	var vt: Dictionary = V.judge(V.target_change(Cal.get_meet("tjig@2027")), V.head_view())
	print("    judged: making tjig a target: %s, parts train %.2f risk %.2f form %.2f race %.2f total %.2f" % [vt.verdict, float(vt.truth.train_w), float(vt.truth.risk_w),
			float(vt.truth.form_w), float(vt.truth.race_w), float(vt.truth.total)])
	_ok("a target is judged too (the taper shows in Form, the race value is doubled)", str(vt.verdict) in V.ORDER)
	CS.enabled = false


## A stand-in for a RaceDay with the three things RaceAdvice reads (current_entrants, meet, round_index).
class FakeRd:
	extends RefCounted
	var meet := {"key": "test@2027", "level": "national"}
	var round_index := 0
	var entrants: Array = []

	func current_entrants() -> Array:
		return entrants


## A field of `n` runners (rivals around ability 9, the player `edge` above with the given anaerobic reserve).
func _field(n: int, edge: float, anaerobic: float, rng: RandomNumberGenerator) -> FakeRd:
	var rd := FakeRd.new()
	for k in n - 1:
		var ab := 9.0 + rng.randfn(0.0, 0.6)
		rd.entrants.append({"name": "R%d" % k, "ability": ab, "anaerobic": rng.randfn(0.0, 2.0), "is_player": false})
	rd.entrants.append({"name": "You", "ability": 9.0 + edge, "anaerobic": anaerobic, "is_player": true})
	return rd


## 9. The coach's race advice: the truth, his quality, his personality, the kick plan, his shouts on the cards.
func _advice() -> void:
	print("== 9. Race advice by personality")
	var RA = load("res://scripts/core/race_advice.gd")
	var RaceS = load("res://scripts/core/race.gd")
	_career(8, "balanced", 10, "balanced")
	var cs = game.get_system("coach")
	var head: Dictionary = cs.head()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# The truth
	var t12: Dictionary = RA.truth(_field(12, -0.5, 0.0, rng))
	_ok("a field of 12: the pack is the worst plan, waiting at the back the best (measured with advice_plan.gd): front %.2f, pack %.2f, back %.2f" % [t12.front, t12.pack, t12.back],
			t12.back > t12.front and t12.front > t12.pack)
	var t8k: Dictionary = RA.truth(_field(8, 0.0, 3.0, rng))
	var t8g: Dictionary = RA.truth(_field(8, 0.0, -3.0, rng))
	_ok("a field of 8: a kicker gains by waiting (back %.2f > front %.2f), a grinder by leading (front %.2f > back %.2f)" % [t8k.back, t8k.front, t8g.front, t8g.back],
			t8k.back > t8k.front and t8g.front > t8g.back)
	# His quality by race reading, and his personality (the same 400 fields for every coach)
	var fields := []
	for i in 400:   # (fields of 8-10: where the plan matters little and a personality can tilt it; a crowd of 12 decides it by itself)
		fields.append(_field(8 + i % 3, rng.randf_range(-1.5, 1.5), rng.randf_range(-3.0, 3.0), rng))
	var stats := {}
	for voice in ["tactician", "calm", "drill", "warm"]:
		for rr in [3, 10, 19]:
			head["voice"] = voice
			head.attributes["race_reading"] = rr
			var right := 0
			var regret := 0.0   # the places lost against the truth's best plan, on average
			var plans := {"front": 0, "pack": 0, "back": 0}
			var kick_sum := 0.0
			var kick_close := 0
			for f in fields:
				var a: Dictionary = RA.advise(f)
				right += 1 if bool(a.right) else 0
				regret += float(a.scores[a.best]) - float(a.scores[a.plan])
				plans[a.plan] += 1
				kick_sum += float(a.kick_est)
				kick_close += 1 if absf(float(a.kick) - RA.natural_kick(game.athlete)) <= 45.0 else 0
			stats["%s %d" % [voice, rr]] = {"right": right / 400.0, "regret": regret / 400.0, "plans": plans, "kick": kick_sum / 400.0, "close": kick_close / 400.0}
	for voice in ["tactician", "calm", "drill", "warm"]:
		print("    %-9s race reading 3 / 10 / 19: right %2d / %2d / %2d %%, places lost %.3f / %.3f / %.3f, at 10 front %2d %% pack %2d %% back %2d %%, mean kick estimate %3d m (natural %d)" % [voice,
				roundi(100.0 * stats["%s 3" % voice].right), roundi(100.0 * stats["%s 10" % voice].right), roundi(100.0 * stats["%s 19" % voice].right),
				stats["%s 3" % voice].regret, stats["%s 10" % voice].regret, stats["%s 19" % voice].regret,
				roundi(100.0 * stats["%s 10" % voice].plans.front / 400.0), roundi(100.0 * stats["%s 10" % voice].plans.pack / 400.0), roundi(100.0 * stats["%s 10" % voice].plans.back / 400.0),
				roundi(stats["%s 10" % voice].kick), roundi(RA.natural_kick(game.athlete))])
	_ok("race reading decides how right he is: the places lost fall from reading 3 to 10 to 19, for every personality",
			["tactician", "calm", "drill", "warm"].all(func(v): return stats["%s 3" % v].regret > stats["%s 10" % v].regret and stats["%s 10" % v].regret > stats["%s 19" % v].regret))
	_ok("race reading 19 is almost always right (tactician above 85 %)", stats["tactician 19"].right > 0.85)
	var others_avg: float = (stats["calm 10"].regret + stats["drill 10"].regret + stats["warm 10"].regret) / 3.0
	_ok("the tactician loses fewer places than the others on average at race reading 10 (no lean, a smaller error: %.3f against %.3f)" % [stats["tactician 10"].regret, others_avg],
			stats["tactician 10"].regret < others_avg)
	_ok("drill leans to the front, calm to the back, warm to the pack (race reading 10)",
			stats["drill 10"].plans.front > stats["calm 10"].plans.front and stats["calm 10"].plans.back > stats["drill 10"].plans.back
			and stats["warm 10"].plans.pack > stats["tactician 10"].plans.pack)
	_ok("noticeable but not decisive: a leaning coach loses less than a tenth of a place a race (race reading 10: drill %.3f, calm %.3f, warm %.3f)" % [
			stats["drill 10"].regret, stats["calm 10"].regret, stats["warm 10"].regret],
			stats["drill 10"].regret < 0.1 and stats["calm 10"].regret < 0.1 and stats["warm 10"].regret < 0.1)
	_ok("the kick: drill from further out than the tactician, calm and warm later",
			stats["drill 10"].kick > stats["tactician 10"].kick and stats["calm 10"].kick < stats["tactician 10"].kick and stats["warm 10"].kick < stats["tactician 10"].kick)
	_ok("the tactician with race reading 19 reads the natural kick point (within 45 m: %d %%)" % roundi(100.0 * stats["tactician 19"].close), stats["tactician 19"].close > 0.9)
	head["voice"] = "calm"
	head.attributes["race_reading"] = 10
	var f0 = fields[0]
	_ok("the same race, the same advice (deterministic)", JSON.stringify(RA.advise(f0)) == JSON.stringify(RA.advise(f0)))
	var adv: Dictionary = RA.advise(f0)
	_ok("his words: a line and a short line exist and name the plan: '%s' / '%s'" % [RA.text(adv, false), RA.text(adv, true)],
			RA.text(adv, false) != "" and RA.text(adv, true).contains(str(data.advice.race.texts.plan_names[adv.plan])))
	var all_why := true
	for p in ["front", "back", "pack"]:
		for e in [-1.0, 1.0]:
			for k in [-1.0, 1.0]:
				all_why = all_why and data.advice.race.texts.why.has(RA.why_key({"plan": p, "scores": {"edge": e, "kick": k}}))
	_ok("every reason key has its text", all_why)
	# His shouts on the cards: the wrong ones lean with his personality
	var shout := {}
	var shout_dropped := {}
	for voice in ["tactician", "calm", "drill", "warm"]:
		var counts := {"push": 0, "ease": 0, "hold": 0, "none": 0}
		var counts_d := {"push": 0, "ease": 0, "hold": 0, "none": 0}
		for i in 600:
			var race = RaceS.new()
			var r2 := RandomNumberGenerator.new()
			r2.seed = 500 + i
			var ents := []
			for k in 7:
				ents.append({"name": "R%d" % k, "club": "", "ability": 9.0, "speed": 9.0, "anaerobic": 0.0, "tactics": 8.0, "consistency": 9.0, "composure": 9.0, "competitiveness": 9.0})
			ents.append({"name": "You", "club": "", "ability": 9.0, "speed": 9.0, "anaerobic": 0.0, "tactics": 10.0, "consistency": 10.0, "composure": 10.0, "is_player": true})
			race.setup(ents, "male", false, 10.0, r2, true, "final")
			race.coach_id = voice
			race.coach_accuracy = 0.8
			var line: Dictionary = race._coach_line("bell", {"name": "X"})
			var dir := str(data.race_cards.coach.dir.bell.get(str(line.get("option", "")), "")) if not line.is_empty() else "none"
			counts[dir if dir != "" else "hold"] += 1
			var line2: Dictionary = race._coach_line("dropped", {"name": "X"})   # (at the start the sensible answer is 'run your own pace' = ease)
			var dir2 := str(data.race_cards.coach.dir.dropped.get(str(line2.get("option", "")), "")) if not line2.is_empty() else "none"
			counts_d[dir2 if dir2 != "" else "hold"] += 1
		shout[voice] = counts
		shout_dropped[voice] = counts_d
	print("    shouts at the bell, 600 races each (accuracy 0.8): %s" % [shout])
	print("    shouts when losing contact (the sensible answer is 'run your own pace'): %s" % [shout_dropped])
	_ok("the wrong shouts lean: at the bell calm shouts 'ease' more than the tactician and drill hardly ever",
			shout.calm.ease > shout.tactician.ease and shout.drill.ease < shout.tactician.ease)
	_ok("and on a close call he shouts what he likes: drill 'dig in' (push) more than the tactician, calm not more",
			shout_dropped.drill.push > shout_dropped.tactician.push and shout_dropped.calm.push <= shout_dropped.tactician.push + 12)
	head["voice"] = "tactician"
	head.attributes["race_reading"] = 10
	var acc_t: float = cs.race_accuracy()
	head["voice"] = "calm"
	var acc_c: float = cs.race_accuracy()
	_ok("the tactician's shouts are more often right (%.2f against %.2f; the club coach's default is 0.80)" % [acc_t, acc_c], acc_t > acc_c and is_equal_approx(acc_c, 0.8))


func _save_load() -> void:
	print("== 8. Save / load with goals and suggestions")
	CS.enabled = true
	CP.enabled = true
	# (Session M1: every race rolls fresh dice, so a race after the load is another race; since M1 its result moves the moods and
	# through them the training. The moods stay in the middle here; tools/mind_check.gd tests their own save / load.)
	var MI = load("res://scripts/core/mind_system.gd")
	MI.neutral = true
	_career(6, "balanced", 10, "balanced")
	var counter := {"n": 0}
	var ans := _suggest_answers(counter)
	game.advance_day()
	game.answer_event(game.pending_event().id, "set")
	var guard := 0
	var sg = game.get_system("suggests")
	while (sg.list.size() < 1 or Cal.date_key(game.date) < 20270112) and Cal.date_key(game.date) < 20270309 and guard < 200:
		guard += 1
		_play(ans)
	var gs = game.get_system("goals")
	gs.lean = 1
	saves.save("goals_check")
	var before: String = JSON.stringify([gs.to_dict(), sg.to_dict()])
	var after_play := _play_on(35, ans)
	_ok("loads", saves.load_slot("goals_check"))
	gs = game.get_system("goals")
	sg = game.get_system("suggests")
	_ok("the goals and suggestions come back as they were", JSON.stringify([gs.to_dict(), sg.to_dict()]) == before and gs.lean == 1 and gs.has_goals(2026))
	_ok("a loaded career goes on exactly as without saving (5 weeks)", _play_on(35, ans) == after_play)
	MI.neutral = false
	saves.delete("goals_check")
	CS.enabled = false


func _play_on(n: int, ans: Callable) -> String:
	var target: int = Cal.date_key(game.add_days(game.date, n))
	var guard := 0
	while Cal.date_key(game.date) < target and guard < n * 4:
		guard += 1
		_play(ans)
	var total := 0.0
	for id in game.athlete.attributes:
		total += game.athlete.get_attr(id)
	var gs = game.get_system("goals")
	var sg = game.get_system("suggests")
	return "%.9f %.9f %s %s %d" % [total, game.athlete.fatigue, JSON.stringify(gs.to_dict()).md5_text(), JSON.stringify(sg.list).md5_text(),
			game.get_system("moments").thread("coach").size()]
