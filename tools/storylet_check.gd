extends SceneTree
## Check of the moments engine (GDD 4.9.5, session C2; StoryletSystem, data/moments.json, data/storylets/*.json):
## 1. the data: every storylet's thread, sender, slot, conditions, 2-4 replies, effects, chains, standing rules and
##    placeholders are known;
## 2. the rules one by one in a test career: off switch, no content = nothing, conditions, posting and answering
##    (effects: trust through CoachSystem.add_trust, relationship, flags, counters, chains), "you didn't answer" after the
##    moment's time, the two "Play week stops for" settings, standing orders (offer after two identical answers, the rule
##    answers, "Not now", removing a rule), never the same text twice in a row, the global dice untouched;
## 3. many seasons through the game loop (health on, races run, stop events answered, some messages answered and the
##    rest left to pass): the rate (moments and people stops per week), no repeat inside a cooldown, nothing stuck, every
##    storylet fires, the rate by age;
## 4. save / load bit for bit with moments waiting and chains queued; a save without the moments state loads;
## 5. neutral: a year of the coach week with the test moments on (every moment a stop, answered at random) gives the
##    same attributes and fatigue as with the moments off, and training_balance's coach-row fingerprint.
## 6. the coach's talk, the race message and the day's why (session C3);
## 7. the people (session P1, data/cast.json, data/storylets/family / friends / group / school_people / rivals): the cast made
##    from every family answer, the yearly calendar, the effects (a late night, grades, the attitude, memory, a whole thread),
##    rivals becoming people, many seasons with the people on (rate, stops, repeats, nothing stuck, coverage per storylet, per
##    age and per person), save / load bit for bit, people off = no cast and no people's moments, neutral = the fingerprint.
## Run: godot --headless --path . -s res://tools/storylet_check.gd [-- quick] [-- [careers for part 3, default 8] [seasons, default 2]
##      [careers for part 7, default 6 (one per family answer, ~4 min); 12 for the full coverage count, ~8 min]]
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var game
var data
var F
var MS
var C
var H
var SS
var saves
var _fails := 0
var _rng := RandomNumberGenerator.new()

const CONDITIONS := ["age", "month", "weekday", "day_type", "weeks_in_career", "phase", "race_today", "race_tomorrow",
		"race_in_days", "raced_days_ago", "pb_days_ago", "injured", "ill", "sore", "today_tags", "tomorrow_tags",
		"tomorrow_rest", "flags", "flag_days", "counters", "seen", "not_seen", "answered", "trust", "relation", "chance",
		"fatigue", "race_outcome", "mood",
		# session P1:
		"family", "has", "turns", "days_to", "days_after", "school_day", "break", "stage", "test_today", "test_tomorrow",
		"tests_week", "cards", "card_days_ago", "card_avg", "card_change", "app", "app_result", "origin", "old_sport",
		"memory", "memory_days", "trait", "rival_race", "rival_streak", "rival_wins"]
const PLACEHOLDERS := ["name", "full_name", "from", "coach", "coach_first", "teammate", "club", "meet", "race_days", "pb",
		"weekday", "tomorrow",
		# session P1:
		"mum", "dad", "parent", "sibling", "best", "friend", "partner", "rival", "class_teacher", "pe_teacher", "counsellor",
		"town", "test_subject", "avg", "old_sport", "family_word",
		# session F1: the coach's pronouns (CoachSystem.words; {He} and {v:a|b} are not lower-case names and pass the pattern)
		"he", "him", "his", "himself"]
## Session P1: the senders of the cast (StoryletSystem.people_for) and their sub-selectors.
const SENDERS := {"coach": [], "teammate": ["roles"], "partner": ["roles"], "family": [], "parent": ["mum", "dad", "athlete"],
		"sibling": [], "best_friend": [], "friend": [], "friends": [], "school": ["class_teacher", "pe_teacher", "counsellor"],
		"rival": []}
const TOPICS := ["", "week", "race", "ack", "mood", "card", "app", "rival"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	MS = load("res://scripts/core/storylet_system.gd")
	C = load("res://scripts/core/coach_system.gd")
	# Lab (the moods in the middle, no life load) with the health model on and real club coaches; the parts switch the rest on.
	var GC = load("res://scripts/core/game_config.gd")
	GC.use("lab", {"health": true, "coach_neutral": false})
	# Fixed careers (fix session 2026-10-18): the dice a career draws from the clock (rivals, health, moments, proposals, each race)
	# come from this seed, so a run is the same every time and the check cannot fail by chance (it failed once in S3a).
	GC.fixed_seed = 4242
	H = load("res://scripts/core/health_system.gd")
	SS = load("res://scripts/core/season_system.gd")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	_rng.seed = 777
	var careers := 8
	var seasons := 2
	var nums := []
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			nums.append(arg.to_int())
	if nums.size() > 0:
		careers = nums[0]
	if nums.size() > 1:
		seasons = nums[1]
	# `quick` (run_all_checks -Quick): the data, the rules, save / load, neutral, the talk and the people's cheap parts; no long season runs.
	var quick := "quick" in OS.get_cmdline_user_args()
	_data_checks()
	MS.include_test = true
	_rules()
	if not quick:
		_seasons(careers, seasons)
	MS.talks_enabled = true   # (the coach's Sunday talk always stops Play week: only the parts below play with it)
	_save_load()
	_neutral()
	MS.include_test = false
	_talks()
	MS.talks_enabled = false
	MS.enabled = true
	_people(nums[2] if nums.size() > 2 else 6)
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


# --- 1. Data -------------------------------------------------------------------------------------------------

func _data_checks() -> void:
	print("== 1. Data (data/moments.json, data/storylets/*.json)")
	var mo: Dictionary = data.moments
	var all: Array = data.storylets
	_ok("%d storylets loaded (%d test)" % [all.size(), all.filter(func(s): return s.test).size()], all.size() >= 10)
	var ids := {}
	var problems := []
	var roles: Dictionary = data.coaching.club.group.roles
	var effects: Array = mo.effects.known + mo.effects.prepared
	var nexts := {}
	for s in all:
		var sid := str(s.get("id", ""))
		if sid == "" or ids.has(sid):
			problems.append("duplicate or missing id '%s'" % sid)
		ids[sid] = true
		if not mo.threads.has(str(s.get("thread", ""))):
			problems.append("%s: unknown thread" % sid)
		var from := str(s.get("from", "coach")).split(":")
		var subs: Array = SENDERS.get(from[0], [])
		var sub_ok: bool = from.size() < 2 or (roles.has(from[1]) if subs == ["roles"] else from[1] in subs)
		if not SENDERS.has(from[0]) or not sub_ok:
			problems.append("%s: unknown sender '%s'" % [sid, s.get("from")])
		if not str(s.get("slot", "evening")) in ["morning", "evening", "any"]:
			problems.append("%s: unknown slot" % sid)
		problems.append_array(_when_problems(sid, s.get("when", {})))
		var texts: Array = s.get("text", [])
		if texts.is_empty():
			problems.append("%s: no text" % sid)
		for t in texts:
			problems.append_array(_text_problems(sid, str(t.text) if t is Dictionary else str(t)))
			if t is Dictionary:
				problems.append_array(_when_problems(sid + " variant", t.get("when", {})))
		var replies: Array = s.get("replies", [])
		var topic := str(s.get("topic", ""))
		if not topic in TOPICS:   # (mood: session M1; card, app, rival: session P1)
			problems.append("%s: unknown topic '%s'" % [sid, topic])
		if topic == "ack":   # (a talk without a topic: the single reply "Thanks, coach")
			if replies.size() != 1:
				problems.append("%s: the talk's plain storylet has exactly 1 reply" % sid)
		elif replies.size() < 2 or replies.size() > 4:
			problems.append("%s: %d replies (2-4)" % [sid, replies.size()])
		var rids := {}
		var rules := 0
		for r in replies:
			if str(r.get("id", "")) == "" or rids.has(r.id) or str(r.get("label", "")) == "":
				problems.append("%s: a reply without a unique id or a label" % sid)
			rids[r.get("id", "")] = true
			for key in r.get("effects", {}):
				if not key in effects:
					problems.append("%s/%s: unknown effect '%s'" % [sid, r.id, key])
			for field in ["label", "hint", "result"]:
				problems.append_array(_text_problems(sid, str(r.get(field, ""))))
			problems.append_array(_when_problems(sid + " reply", r.get("when", {})))
			if r.has("next"):
				nexts[str(r.next.id)] = true
			if str(r.get("rule", "")) != "":
				rules += 1
		if s.has("standing") and rules == 0:
			problems.append("%s: a standing group but no reply with a rule" % sid)
		if s.has("no_answer"):
			for key in s.no_answer.get("effects", {}):
				if not key in effects:
					problems.append("%s/no_answer: unknown effect '%s'" % [sid, key])
	for n in nexts:
		if not ids.has(n):
			problems.append("a chain points to the unknown storylet '%s'" % n)
	for s in all:
		if bool(s.get("chain_only", false)) and not nexts.has(s.id) and str(s.get("topic", "")) == "":
			problems.append("%s: chain_only but no reply leads to it" % s.id)
	for p in problems:
		print("    " + p)
	# (Not the word "problems" in a PASS line: run_all_checks reads it as a failure.)
	_ok("every storylet is well formed: thread, sender, slot, conditions, 2-4 replies, effects, chains, rules, placeholders (%d faults)" % problems.size(),
			problems.is_empty())
	_ok("moments.json: rate, settings (default %s), no-answer text, standing texts" % mo.settings.default,
			mo.settings.stops.has(mo.settings.default) and str(mo.no_answer.result) != "" and mo.rate.per_week.size() == 2
			and mo.day_names.size() == 7)


func _when_problems(sid: String, when: Dictionary) -> Array:
	var out := []
	for key in when:
		if not key in CONDITIONS:
			out.append("%s: unknown condition '%s'" % [sid, key])
	return out


func _text_problems(sid: String, text: String) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("\\{([a-z_]*)\\}")
	for m in re.search_all(text):
		if not m.get_string(1) in PLACEHOLDERS:
			out.append("%s: unknown placeholder {%s}" % [sid, m.get_string(1)])
	return out


# --- Helpers -------------------------------------------------------------------------------------------------

func _athlete(i: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	var gender := "male" if i % 2 == 0 else "female"
	var first: String = data.names[gender][rng.randi_range(0, data.names[gender].size() - 1)]
	var last: String = data.names.surnames[rng.randi_range(0, data.names.surnames.size() - 1)]
	return F.create({
		"first_name": first, "last_name": last, "gender": gender, "hometown": "Tampere", "club_id": "tap",
		"main_event": "800m", "birth_date": {"year": 2012, "month": rng.randi_range(1, 12), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)


func _ms():
	return game.get_system("moments")


func _ctx() -> Dictionary:
	var cal = load("res://scripts/core/calendar.gd")
	return {"date": game.date.duplicate(), "day": cal.weekday(game.date), "day_type": cal.day_type(game.date),
			"week": game.current_week()}


func _today() -> int:
	return MS.day_no(game.date)


## Posts storylet `sid` now (from the first person who can send it), skipping the scheduler.
func _force(sid: String) -> Dictionary:
	var ms = _ms()
	ms._sync_people()
	var s: Dictionary = ms.storylet(sid)
	var senders: Array = ms.people_for(str(s.get("from", "coach")))
	if senders.is_empty() and str(s.from).begins_with("teammate"):
		senders = ms.people_for("teammate")   # (this group has no one of that role: anyone, for the test)
	if senders.is_empty():
		return {}
	return ms._post(s, senders[0], _ctx(), _today())


## Runs the race of the day (quick, the pack plan) and finishes the race day.
func _run_race() -> String:
	var rd = game.race_day
	while not rd.is_done():
		rd.start_round(false, "pack").run()
		rd.finish_round()
	return game.finish_race()


## Answers every waiting stop event: a moment with one of its replies (or "ok" = no answer, now and then), the rest as a
## sensible player would. Returns the number of moment stops answered.
func _answer_stops() -> int:
	var n := 0
	var guard := 0
	while not game.pending_event().is_empty() and guard < 50:
		guard += 1
		var e: Dictionary = game.pending_event()
		var answer := "ok"
		match str(e.get("kind", "")):
			"moment":
				n += 1
				answer = "ok" if _rng.randf() < 0.1 else str(e.choices[_rng.randi_range(0, e.choices.size() - 1)].id)
			"sore":
				answer = "keep"
			"offer":
				answer = str(e.choices[0].id)
			"return":
				answer = "accept"
		game.answer_event(e.id, answer)
	return n


## Answers about half of the moments waiting in the threads (the rest pass unanswered).
func _answer_some() -> void:
	var ms = _ms()
	for m in ms.pending():
		if m.stop or _rng.randf() < 0.5:
			continue
		ms.answer(m.id, str(m.replies[_rng.randi_range(0, m.replies.size() - 1)].id))


## Plays `days` days through the game loop (races run, stop events answered). False when it got stuck.
func _play(days: int, answer_some := true) -> bool:
	var cal = load("res://scripts/core/calendar.gd")
	var end_key: int = cal.date_key(game.add_days(game.date, days))
	var guard := 0
	while cal.date_key(game.date) < end_key:
		guard += 1
		if guard > days * 4 + 20:
			return false
		var r: String = game.advance_day()
		if r == game.RACE:
			_run_race()
		_answer_stops()
		if answer_some:
			_answer_some()
	return true


func _snapshot() -> String:
	# (Events: their id, title and answer; other systems' event fields are not normalised after loading.)
	return JSON.stringify({"athlete": game.athlete.to_dict(), "moments": _ms().to_dict(),
			"coach": game.get_system("coach").to_dict(), "date": game.date,
			"events": game.events.map(func(e): return [e.id, e.title, e.answer])})


# --- 2. The rules ----------------------------------------------------------------------------------------------

func _rules() -> void:
	print("\n== 2. The rules, one by one (a test career, health off)")
	H.model_enabled = false
	C.neutral_club = true
	SS.offers_enabled = false

	# Off switch and no content.
	MS.enabled = false
	game.start_career(_athlete(1), "repeat")
	_play(28)
	_ok("off switch: 4 weeks, no moment, no event, nothing to save", _ms().fired.is_empty() and game.events.is_empty() and _ms().to_dict().is_empty())
	MS.enabled = true
	MS.include_test = false
	game.start_career(_athlete(1), "repeat")
	_play(28)
	_ok("no scheduled moments yet (only the coach's talk topics exist) and the test ones not asked for: nothing happens",
			_ms().fired.is_empty() and game.events.is_empty() and _ms().threads.values().all(func(t): return t.is_empty()))
	MS.include_test = true

	# A quiet career for the rules (the scheduler's week target 0; chains still come).
	var rate: Dictionary = data.moments.rate
	var per_week: Array = rate.per_week.duplicate()
	rate.per_week = [0, 0]
	game.start_career(_athlete(2), "repeat")
	var ms = _ms()
	_play(3, false)
	_ok("people: the head coach and his training group are in the threads' cast (%d people)" % ms.people.size(),
			ms.people_for("coach").size() == 1 and ms.people_for("teammate").size() == game.get_system("coach").head().group.size())

	# Conditions.
	var ctx := _ctx()
	var a = game.athlete
	var age: int = a.age_on(game.date)
	_ok("conditions: age, month, weekday, day type",
			ms.check_when({"age": [age, age]}, ctx, {}) and not ms.check_when({"age": [age + 1, null]}, ctx, {})
			and ms.check_when({"month": [int(game.date.month)]}, ctx, {}) and not ms.check_when({"weekday": [(ctx.day + 1) % 7]}, ctx, {})
			and ms.check_when({"day_type": ctx.day_type}, ctx, {}))
	ms.flags["x"] = {"day": _today() - 5, "count": 1}
	ms.counters["c"] = 3
	_ok("conditions: flags / !flags, flag_days, counters",
			ms.check_when({"flags": ["x", "!y"]}, ctx, {}) and not ms.check_when({"flags": ["!x"]}, ctx, {})
			and ms.check_when({"flag_days": {"x": [5, 5]}}, ctx, {}) and not ms.check_when({"flag_days": {"x": [0, 4]}}, ctx, {})
			and ms.check_when({"counters": {"c": [3, null], "none": [0, 0]}}, ctx, {}) and not ms.check_when({"counters": {"c": [4, null]}}, ctx, {}))
	ms.flags.erase("x")
	ms.counters.erase("c")
	_ok("conditions: no race, no PB yet, healthy (health off), trust New",
			ms.check_when({"race_today": false, "race_tomorrow": false, "pb_days_ago": [100, null], "raced_days_ago": [100, null],
					"injured": false, "ill": false, "sore": false, "trust": ["new"]}, ctx, {}))
	_ok("an unknown condition never holds", not ms.check_when({"nonsense": true}, ctx, {}))
	var mate: Dictionary = ms.people_for("teammate")[0]
	mate.relation = 70.0
	_ok("conditions: relation with the sender", ms.check_when({"relation": [60, 80]}, ctx, mate) and not ms.check_when({"relation": [0, 60]}, ctx, mate))
	mate.relation = 50.0

	# Posting and answering: the coach check-in, reply "tired" (flag, counter, chain).
	var cs = game.get_system("coach")
	var m := _force("test_coach_checkin")
	_ok("a posted moment: in the coach thread, waiting, 3 replies with labels, no stop (not important)",
			not m.is_empty() and ms.thread("coach").back().moment == m.id and m.answer == "" and m.replies.size() == 3 and not m.stop
			and game.pending_event().is_empty())
	_ok("its text has no placeholder left (\"%s\")" % m.text, not "{" in m.text)
	ms.answer(m.id, "tired")
	_ok("the reply: flag told_tired with today's date, counter +1, chain follow-up queued in 2-3 days",
			ms.flags.has("told_tired") and int(ms.flags.told_tired.day) == _today() and int(ms.counters.get("tired_reports", 0)) == 1
			and ms.queue.size() == 1 and int(ms.queue[0].due) - _today() in [2, 3])
	_ok("the thread: the coach's message, your reply, the result line",
			ms.thread("coach").slice(-3).map(func(x): return x.from) == [m.from, "you", "system"])
	var follow_day: int = int(ms.queue[0].due)
	_play(follow_day - _today() + 1, false)
	var follow: Array = ms.moments.filter(func(x): return x.storylet == "test_coach_followup")
	_ok("the chain follow-up came on its day (%d)" % follow_day, follow.size() == 1 and int(follow[0].day) == follow_day)
	ms.answer(follow[0].id, "better")
	var cause: Dictionary = cs.relation().causes.back()
	_ok("its reply: trust +1 through CoachSystem.add_trust, the cause names the moment, the flag removed (%s %+.0f)" % [cause.cause, cause.delta],
			cause.cause == "moment:test_coach_followup" and float(cause.delta) == 1.0 and not ms.flags.has("told_tired"))

	# Relationship and "you didn't answer" (a moment can be answered on its day and the expires_days days after it).
	var m2 := _force("test_group_weekend")
	var sender: Dictionary = ms.people[m2.from]
	var rel0: float = sender.relation
	_play(3, false)
	_ok("unanswered on its day and the 2 days after: still waiting", ms.moment(m2.id).answer == "")
	_play(1, false)
	_ok("the next morning it passes as \"you didn't answer\" (relationship %d -> %d)" % [rel0, sender.relation],
			ms.moment(m2.id).answer == MS.NONE and sender.relation == rel0 - 1.0
			and ms.thread("group").any(func(x): return x.moment == m2.id and x.text == str(data.moments.no_answer.result)))
	var m3 := _force("test_coach_race_tomorrow")
	_play(2, false)
	var waited: bool = ms.moment(m3.id).answer == ""
	_play(1, false)
	_ok("a moment with its own time (expires_days 1) passes a day earlier", waited and ms.moment(m3.id).answer == MS.NONE)
	var m4 := _force("test_group_weekend")
	var rel4: float = ms.people[m4.from].relation
	ms.answer(m4.id, "yes")
	_ok("a reply with relation +2 raises the sender's relationship (%d -> %d)" % [rel4, ms.people[m4.from].relation],
			ms.people[m4.from].relation == rel4 + 2.0)
	var first4: String = ms.people[m4.from].first_name
	_ok("the result card says it in words (%s): ▲ somewhat; the unanswered moment: ▼ a little" % str(ms.moment(m4.id).changes),
			ms.moment(m4.id).changes == ["%s ▲ somewhat" % first4]
			and ms.moment(m2.id).changes == ["%s ▼ a little" % str(sender.first_name)])
	var coach_first: String = str(ms.people_for("coach")[0].first_name)
	_ok("the coach's trust in words: 'Trust in %s ▲ a little' (%s)" % [coach_first, str(ms.moment(follow[0].id).changes)],
			ms.moment(follow[0].id).changes == ["Trust in %s ▲ a little" % coach_first])
	_ok("the player's own lines and the game's lines are never 'new'; a reply's result from the sender is read at once",
			ms.thread("coach").filter(func(x): return x.from == "you" or x.from == "system").all(func(x): return x.read))

	# Session L1a ("L1's questions" 5): no people stops mid-week. An important moment waits for the Sunday planner: no stop event,
	# listed in waiting(), it expires on the coming Sunday and passes as "you didn't answer" on the Monday after it.
	var cal = load("res://scripts/core/calendar.gd")
	var m5 := _force("test_coach_injury")
	var sunday: int = _today() - cal.weekday(game.date) + 6
	_ok("an important moment waits for the planner: no stop event, in waiting(), it expires on the coming Sunday",
			not m5.stop and bool(m5.get("planner", false)) and game.pending_event().is_empty()
			and ms.waiting().any(func(x): return x.id == m5.id) and int(m5.expires) == sunday)
	ms.answer(m5.id, str(m5.replies[0].id))
	_ok("answered on the planner: answered, no longer waiting", ms.moment(m5.id).answer == str(m5.replies[0].id)
			and not ms.waiting().any(func(x): return x.id == m5.id))
	var m6 := _force("test_coach_injury")
	var guard := 0
	while _today() <= sunday + 1 and guard < 10:   # (Monday's morning resolves it)
		guard += 1
		game.advance_day()
		_answer_stops()
	_ok("on the Sunday it still waits; the Monday after, it passed unanswered (no stop on the way)",
			ms.moment(m6.id).answer == MS.NONE and game.pending_event().is_empty())
	ms.set_stop_mode("all")
	var m7 := _force("test_group_weekend")
	_ok("the cut setting 'Every moment' makes no moment stop", not m7.stop and game.pending_event().is_empty())
	ms.answer(m7.id, "yes")
	ms.set_stop_mode("important")

	# Standing orders.
	var p1 := _force("test_group_party")
	ms.answer(p1.id, "no")
	_ok("one 'no': no rule offered yet", not ms.moments.any(func(x): return x.kind == "rule"))
	var p2 := _force("test_group_party")
	ms.answer(p2.id, "no")
	var offers: Array = ms.moments.filter(func(x): return x.kind == "rule" and x.answer == "")
	_ok("the same answer twice in a row: a rule is offered (\"%s\")" % (offers[0].text if not offers.is_empty() else "?"), offers.size() == 1)
	ms.answer(offers[0].id, "no")
	var p3 := _force("test_group_party")
	ms.answer(p3.id, "no")
	_ok("'Not now': one more identical answer offers nothing", not ms.moments.any(func(x): return x.kind == "rule" and x.answer == ""))
	var p4 := _force("test_group_party")
	ms.answer(p4.id, "no")
	offers = ms.moments.filter(func(x): return x.kind == "rule" and x.answer == "")
	_ok("two more after 'Not now': offered again", offers.size() == 1)
	ms.answer(offers[0].id, "yes")
	_ok("'Make it a rule': saved as a standing order", ms.standing_orders().size() == 1 and ms.standing_orders()[0].reply == "no")
	var before_count: int = int(ms.week.get("count", 0))
	var p5 := _force("test_group_party")
	_ok("with the rule the moment answers itself: no waiting, the rule's line shows, not counted in the week's rate",
			p5.auto and p5.answer == "no" and int(ms.week.get("count", 0)) == before_count
			and ms.thread("group").any(func(x): return x.moment == p5.id and x.from == "system" and x.text.begins_with("Your rule")))
	ms.clear_rule("weekday_party")
	var p6 := _force("test_group_party")
	_ok("a removed rule: the moment asks again", not p6.auto and p6.answer == "")
	ms.answer(p6.id, "go")

	# Never the same text twice in a row (two variants, no conditions).
	var last := -1
	var repeats := 0
	for i in 30:
		var mv := _force("test_group_weekend")
		if mv.variant == last:
			repeats += 1
		last = mv.variant
		ms.answer(mv.id, "rest")
	_ok("30 times in a row: never the same text twice (%d repeats)" % repeats, repeats == 0)

	# The global dice (the rivals use them): posting, answering and the day's scheduler use the moments' own dice.
	seed(4242)
	var y1 := randi()
	seed(4242)
	var mg := _force("test_coach_checkin")
	ms.answer(mg.id, "tired")
	ms.on_day_end(_ctx())
	ms._pick(_ctx(), _today(), ["evening", "any"])
	var y2 := randi()
	_ok("posting, answering and picking moments do not touch the global dice", y1 == y2)
	rate.per_week = per_week
	H.model_enabled = true


# --- 3. Many seasons ------------------------------------------------------------------------------------------

func _seasons(careers: int, seasons: int) -> void:
	print("\n== 3. %d careers x %d seasons through the game loop (health on, races run, the coach's season plan)" % [careers, seasons])
	var t0 := Time.get_ticks_msec()
	C.neutral_club = false
	SS.offers_enabled = true
	var cal = load("res://scripts/core/calendar.gd")
	var week_counts := []     # moments asking for an answer per week (Important only)
	var week_stops := []      # people stops per week (Important only)
	var all_counts := []      # per week with Every moment
	var all_stops := []
	var by_age := {}          # age -> [moments, weeks]
	var fired_ids := {}
	var cooldown_bad := []
	var variant_bad := 0
	var per_day_bad := 0
	var stuck := []
	var dropped := 0
	var auto := 0
	var none := 0
	var answered := 0
	for c in careers:
		var every := false   # (session L1a: the setting "Every moment" is cut; no moment stops, the important ones wait for Sunday)
		game.start_career(_athlete(100 + c))
		var ms = _ms()
		ms.rng.seed = 31 + c
		game.get_system("health").rng.seed = 61 + c
		_answer_stops()
		var weeks := seasons * 52
		for w in weeks:
			if not _play(7):
				stuck.append("career %d week %d: the days did not move on" % [c, w])
				break
		ms = _ms()
		# Weekly counts from the record of every moment posted (not saved: one career = one record).
		var start_monday: int = MS.day_no(cal.monday_of(game.START_DATE))
		var per_week := {}
		var stops_week := {}
		var per_day := {}
		var last_by := {}
		var last_var := {}
		for f in ms.fired:
			fired_ids[f.storylet] = int(fired_ids.get(f.storylet, 0)) + 1
			if f.auto:
				auto += 1
			var s: Dictionary = ms.storylet(f.storylet)
			if last_by.has(f.storylet):
				var gap: int = int(f.day) - int(last_by[f.storylet])
				if bool(s.get("once", false)) or gap < int(s.get("cooldown_days", 14)):
					cooldown_bad.append("%s again after %d days" % [f.storylet, gap])
			last_by[f.storylet] = f.day
			var unconditional: int = s.text.filter(func(t): return not t is Dictionary).size()
			if unconditional == s.text.size() and s.text.size() > 1 and last_var.get(f.storylet, -1) == f.variant:
				variant_bad += 1
			last_var[f.storylet] = f.variant
			if f.auto:
				continue
			var wk := floori((int(f.day) - start_monday) / 7.0)
			per_week[wk] = int(per_week.get(wk, 0)) + 1
			if f.stop or bool(f.get("planner", false)):   # (session L1a: an important moment waits for the planner instead of stopping)
				stops_week[wk] = int(stops_week.get(wk, 0)) + 1
			if f.stop and not bool(f.get("talk", false)):
				stuck.append("career %d: %s stopped Play week (no people stops since L1a)" % [c, f.storylet])
			per_day[f.day] = int(per_day.get(f.day, 0)) + 1
		for d in per_day:
			if per_day[d] > int(data.moments.rate.max_per_day):
				per_day_bad += 1
		# The first week of a career is short (start_after_days) and the season offer comes first: count from week 1.
		for wk in range(1, weeks):
			(all_counts if every else week_counts).append(int(per_week.get(wk, 0)))
			(all_stops if every else week_stops).append(int(stops_week.get(wk, 0)))
			var age: int = game.athlete.age_on(game.add_days(game.START_DATE, 7 * wk))
			if not by_age.has(age):
				by_age[age] = [0, 0]
			by_age[age][0] += int(per_week.get(wk, 0))
			by_age[age][1] += 1
		# Nothing stuck at the end.
		var today: int = MS.day_no(game.date)
		for m in ms.pending():
			if not m.stop and today > int(m.expires) + 1:
				stuck.append("career %d: %s waits past its time" % [c, m.storylet])
		for q in ms.queue:
			if today > int(q.until) + 1:
				stuck.append("career %d: chain %s past its window" % [c, q.id])
		if not game.pending_event().is_empty():
			stuck.append("career %d: a stop event left waiting" % c)
		dropped += ms.dropped_chains
		for m in ms.moments:
			if m.kind == "moment" and not m.auto and m.answer != "":
				if m.answer == MS.NONE:
					none += 1
				else:
					answered += 1
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var mean := _mean(week_counts)
	var stops := _mean(week_stops)
	print("    %.0f s; %d weeks, moments a week mean %.2f (sd %.2f, %s), waiting for the planner a week %.2f (most in a week: %d)" % [
			secs, week_counts.size(), mean, _sd(week_counts), _dist(week_counts), stops, week_stops.max() if not week_stops.is_empty() else 0])
	if not all_counts.is_empty():
		print("    Every moment: %d weeks, moments a week %.2f, stops a week %.2f (every moment stops)" % [all_counts.size(), _mean(all_counts), _mean(all_stops)])
	var ages := by_age.keys()
	ages.sort()
	for age in ages:
		print("    age %d: %.2f moments a week over %d weeks" % [age, float(by_age[age][0]) / by_age[age][1], by_age[age][1]])
	print("    answered %d, passed unanswered %d (of the last 4 weeks' moments kept), answered by a rule %d, chains dropped %d" % [answered, none, auto, dropped])
	var ids: Array = fired_ids.keys()
	ids.sort()
	var parts := []
	for sid in ids:
		parts.append("%s %d" % [sid.trim_prefix("test_"), fired_ids[sid]])
	print("    fired: " + ", ".join(parts))
	_ok("rate: 3-5 moments a week on average (%.2f)" % mean, mean >= 3.0 and mean <= 5.0)
	_ok("never more than %d in a week (most %d) or %d in a day (%d days over)" % [data.moments.rate.max_per_week,
			week_counts.max() if not week_counts.is_empty() else 0, data.moments.rate.max_per_day, per_day_bad],
			(week_counts + all_counts).all(func(x): return x <= int(data.moments.rate.max_per_week)) and per_day_bad == 0)
	_ok("at most ~1 moment a week waits for the planner on average (%.2f), none stops Play week" % stops, stops <= 1.05)
	if not all_counts.is_empty():
		_ok("Every moment: every moment stops", _mean(all_counts) == _mean(all_stops))
	for b in cooldown_bad.slice(0, 5):
		print("    " + b)
	_ok("no moment again inside its cooldown, no 'once' moment twice (%d)" % cooldown_bad.size(), cooldown_bad.is_empty())
	_ok("never the same text twice in a row (%d)" % variant_bad, variant_bad == 0)
	for s in stuck.slice(0, 5):
		print("    " + s)
	_ok("nothing stuck: the days always moved on, no moment past its time, no chain past its window, no stop left (%d)" % stuck.size(), stuck.is_empty())
	var never: Array = data.storylets.filter(func(s): return s.test and not fired_ids.has(s.id)).map(func(s): return s.id)
	_ok("every test storylet fired at least once (never: %s)" % (", ".join(never) if not never.is_empty() else "none"), never.is_empty())
	_ok("both answers happen: answered and passed unanswered", answered > 0 and none > 0)


func _mean(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := 0.0
	for x in xs:
		s += x
	return s / xs.size()


func _sd(xs: Array) -> float:
	var m := _mean(xs)
	var s := 0.0
	for x in xs:
		s += (x - m) * (x - m)
	return sqrt(s / maxi(xs.size(), 1))


func _dist(xs: Array) -> String:
	var counts := {}
	for x in xs:
		counts[x] = int(counts.get(x, 0)) + 1
	var keys := counts.keys()
	keys.sort()
	var parts := []
	for k in keys:
		parts.append("%d: %d%%" % [k, roundi(100.0 * counts[k] / xs.size())])
	return ", ".join(parts)


# --- 4. Save / load ----------------------------------------------------------------------------------------------

## A deterministic answer policy (no dice), so the run after loading answers exactly as the run without saving.
func _play_fixed(days: int) -> void:
	var cal = load("res://scripts/core/calendar.gd")
	var end_key: int = cal.date_key(game.add_days(game.date, days))
	while cal.date_key(game.date) < end_key:
		var r: String = game.advance_day()
		if r == game.RACE:
			_run_race()
		while not game.pending_event().is_empty():
			var e: Dictionary = game.pending_event()
			var answer := "ok"
			match str(e.get("kind", "")):
				"moment": answer = str(e.choices[e.id.hash() % e.choices.size()].id)
				"sore": answer = "keep"
				"offer": answer = str(e.choices[0].id)
				"return": answer = "accept"
			game.answer_event(e.id, answer)
		var ms = _ms()
		for m in ms.pending():
			if not m.stop and m.id.hash() % 3 == 0:
				ms.answer(m.id, str(m.replies[0].id))


func _save_load() -> void:
	print("\n== 4. Save / load (test moments on, health on, a real club coach, Every moment for more stops)")
	C.neutral_club = false
	SS.offers_enabled = true
	game.start_career(_athlete(55))
	_ms().set_stop_mode("all")
	_play_fixed(40)
	var ms = _ms()
	# Something waiting at the save: a fresh moment and a queued chain.
	var m := _force("test_coach_checkin")
	if not m.is_empty() and m.answer == "":
		ms.answer(m.id, "tired")
	var waiting := _force("test_group_weekend")
	_answer_stops_fixed_none()
	saves.save("storylet_check")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.DIR + "storylet_check.json"))
	_ok("the save holds the moments state (%d moments, %d chains queued, %d messages)" % [ms.moments.size(), ms.queue.size(),
			ms.threads.values().reduce(func(acc, t): return acc + t.size(), 0)],
			parsed.game.systems.has("moments") and not parsed.game.systems.moments.moments.is_empty())
	var state_before: String = JSON.stringify(ms.to_dict())
	_play_fixed(45)
	var straight := _snapshot()
	saves.load_slot("storylet_check")
	_ok("after loading: the same moments state, to the dice", JSON.stringify(_ms().to_dict()) == state_before)
	_play_fixed(45)
	var after := _snapshot()
	_ok("45 more days after loading = the same 45 days without saving (athlete, moments, coach, events bit for bit)", after == straight)
	if after != straight:
		_diff(straight, after)
	# A save from before C2 (no moments state).
	var old: Dictionary = parsed.duplicate(true)
	old.game.systems.erase("moments")
	for e in old.game.events:
		e.erase("moment")
	var f := FileAccess.open(saves.DIR + "storylet_check_old.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(old, " ", true, true))
	f.close()
	_ok("a save without the moments state loads", saves.load_slot("storylet_check_old"))
	_ok("it starts with no moments (test content off: a normal career)", _ms().moments.is_empty() and not _ms().test_content)
	_play_fixed(7)
	_ok("and plays a week", true)
	saves.delete("storylet_check")
	saves.delete("storylet_check_old")
	if waiting.is_empty():
		pass


func _answer_stops_fixed_none() -> void:
	while not game.pending_event().is_empty():
		var e: Dictionary = game.pending_event()
		if str(e.get("kind", "")) == "moment":
			return   # (left waiting across the save on purpose)
		game.answer_event(e.id, "ok")


func _diff(a: String, b: String) -> void:
	var da: Dictionary = JSON.parse_string(a)
	var db: Dictionary = JSON.parse_string(b)
	for k in da:
		if JSON.stringify(da[k]) != JSON.stringify(db.get(k)):
			print("    differs: " + k)
			if da[k] is Dictionary:
				for k2 in da[k]:
					if JSON.stringify(da[k][k2]) != JSON.stringify(db[k].get(k2)):
						print("      " + k2)


# --- 5. Neutral --------------------------------------------------------------------------------------------------

## The training_balance M1 athlete.
func _m1_athlete():
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	return F.create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)


## A year of the repeating coach week (health off, a coach of 10s) with the moments off / on. Returns {attributes, fatigue,
## moments}.
func _year(on: bool) -> Dictionary:
	H.model_enabled = false
	C.neutral_club = true
	SS.offers_enabled = false
	MS.enabled = on
	game.start_career(_m1_athlete(), "repeat")
	if on:
		_ms().set_stop_mode("all")
	var stops := 0
	var cal = load("res://scripts/core/calendar.gd")
	var end_key: int = cal.date_key(game.add_days(game.START_DATE, 7 * 52))
	while cal.date_key(game.date) < end_key:
		game.advance_day()
		stops += _answer_stops()
		_answer_some()
	var total := 0.0
	for k in game.athlete.attributes:
		total += game.athlete.attributes[k]
	var out := {"attributes": game.athlete.attributes.duplicate(), "fatigue": game.athlete.fatigue, "sum": total,
			"moments": _ms().fired.size(), "stops": stops}
	MS.enabled = true
	H.model_enabled = true
	return out


func _neutral() -> void:
	print("\n== 5. Neutral: a year of the coach week, test moments off vs on (every moment a stop, answered at random)")
	var off := _year(false)
	var on := _year(true)
	print("    off: %d moments; on: %d moments, %d stops answered; attribute sum %.9f / %.9f" % [off.moments, on.moments, on.stops, off.sum, on.sum])
	_ok("the moments really came (%d)" % on.moments, on.moments > 100 and off.moments == 0)
	_ok("every attribute and the fatigue bit for bit the same with the moments on", JSON.stringify(off.attributes) == JSON.stringify(on.attributes) and off.fatigue == on.fatigue)
	_ok("training_balance's coach-row fingerprint (206.798298350): %.9f" % on.sum, "%.9f" % on.sum == "206.798298350")


# --- 6. The coach's talk, the race message, the day's why (session C3) ---------------------------------------------

## Plays weeks until a race day (stop events answered, the Sunday talks too). Returns game.RACE or "" when none came.
func _weeks_until_race(max_weeks: int) -> String:
	for i in max_weeks * 3:
		var r: String = game.advance_week()
		if r == game.RACE:
			return r
		if r == game.STOP:
			_answer_stops()
	return ""


func _talks() -> void:
	print("\n== 6. The Sunday talk, the message after a race, the coach's why (session C3)")
	H.model_enabled = false
	C.neutral_club = false
	SS.offers_enabled = false
	MS.enabled = true
	var CT = load("res://scripts/core/coach_talk.gd")
	var cal = load("res://scripts/core/calendar.gd")

	# Session L1a ("L1's questions" 6): the Sunday talk is no stop. Play week reaches Sunday night; the coach's one line is kept for
	# the coming week's planner, the whole talk is a message in his thread (read: the planner showed it), a topic whose reply changed
	# the week (the `proposal` effect) is never posted (his notes do that), the other topics are moments in his thread, not stops.
	game.start_career(_athlete(7))
	var ms = _ms()
	var r: String = game.advance_week()
	var line: String = ms.line_for(game.week_monday())
	_ok("Play week reaches Sunday night with no stop for the talk (%s)" % r, r == game.WEEK_DONE and game.pending_event().is_empty())
	var words: int = line.split(" ", false).size()
	_ok("the coach's line for the planner: %d words, at most ~30, no placeholder (\"%s\")" % [words, line],
			line != "" and words <= 30 and not "{" in line)
	var talk_msgs: Array = ms.thread("coach").filter(func(x): return x.moment == "" and x.from != "you" and x.from != "system")
	var full: String = str(talk_msgs.back().text) if not talk_msgs.is_empty() else ""
	var paragraphs: int = full.split("\n\n").size()
	_ok("the whole talk is in his thread, already read: open, review, preview (+ focus, close): %d paragraphs, no placeholder" % paragraphs,
			paragraphs >= 3 and not "{" in full and bool(talk_msgs.back().read))
	_ok("no talk moment and no topic that changes the week was posted",
			not ms.moments.any(func(x): return bool(x.get("talk", false)))
			and not ms.fired.any(func(f): return MS._changes_week(ms.storylet(f.storylet))))
	_ok("the line belongs to its week only (the next Monday's planner has none yet)", ms.line_for(game.add_days(game.week_monday(), 7)) == "")

	# Twelve weeks: a line every Sunday, never a talk stop, nothing stuck, the topics fit, the global dice untouched.
	var talks := 1
	var with_topic := 0
	var second_topics := 0
	var stuck := false
	var races_run := 0
	for w in 12:
		var rr: String = game.advance_week()
		var guard := 0
		while guard < 20 and rr != game.WEEK_DONE:
			guard += 1
			if rr == game.RACE:
				_run_race()
				races_run += 1
			elif rr == game.STOP:
				var ev: Dictionary = game.pending_event()
				if str(ev.get("kind", "")) == "moment" and bool(ms.moment(str(ev.moment)).get("talk", false)):
					stuck = true
				game.answer_event(ev.id, str(ev.choices[0].id) if not ev.choices.is_empty() else "ok")
			rr = game.advance_week() if game.pending_event().is_empty() else game.STOP
		if ms.line_for(game.week_monday()) != "":
			talks += 1
		else:
			stuck = true
	var bad_topics := []
	for f in ms.fired:
		var s: Dictionary = ms.storylet(f.storylet)
		var topic := str(s.get("topic", ""))
		if topic in ["week", "mood"]:
			with_topic += 1
		if topic == "week":
			second_topics += 1
		if not topic in ["", "week", "race", "mood"] or bool(f.get("stop", false)):
			bad_topics.append(f.storylet)
	_ok("13 Sundays, 13 lines, no talk stop (%d, %d races on the way), nothing stuck" % [talks, races_run], talks == 13 and not stuck)
	_ok("only the right kinds of moment were posted, none of them a stop (%s)" % ", ".join(bad_topics), bad_topics.is_empty())
	print("    topics posted to the thread %d (week topics %d) in 12 weeks" % [with_topic, second_topics])
	_ok("some Sundays post a topic to the thread", with_topic > 0)

	# The coach's detail and voice: communication short / normal / full, the four personalities.
	var lengths := {}
	var voices := ["calm", "drill", "warm", "tactician"]
	var texts := {}
	game.start_career(_athlete(8))
	ms = _ms()
	_play(6, false)   # Mon..Sat; today is Sunday morning
	var ctx := _ctx()
	var cs = game.get_system("coach")
	var coach: Dictionary = ms.people_for("coach")[0]
	var good := true
	seed(4242)
	var y1 := randi()
	seed(4242)
	for v in voices:
		cs.head().voice = v
		for comm in [5, 10, 16]:
			cs.head().attributes.communication = comm
			var text: String = CT.week_talk(ctx, ms._fill(ctx, coach), _rng)
			if text == "" or "{" in text:
				good = false
				print("    bad text: ", text)
			lengths[comm] = text.length() + int(lengths.get(comm, 0))
			texts[v + str(comm)] = text
	var y2 := randi()
	_ok("building talks does not touch the global dice (the rivals use them)", y1 == y2)
	_ok("the talk is filled in for all four voices and three detail levels (no placeholder, never empty)", good)
	_ok("more communication, more words: short %d < normal %d < full %d characters" % [lengths[5], lengths[10], lengths[16]],
			lengths[5] < lengths[10] and lengths[10] < lengths[16])
	_ok("the voices differ", texts["calm10"] != texts["drill10"] and texts["warm10"] != texts["tactician10"])
	_ok("short = open, review, preview only; normal and full add the focus and the closing word",
			texts["calm5"].split("\n\n").size() == 3 and texts["calm10"].split("\n\n").size() == 5 and texts["calm16"].split("\n\n").size() == 5)

	# The day's why.
	var why_ok := true
	for v in voices:
		cs.head().voice = v
		for comm in [5, 10, 16]:
			cs.head().attributes.communication = comm
			for sid in [["easy_run"], ["intervals_800", "drills"], ["strength"], []]:
				for lvl in ["easy", "normal", "hard"]:
					var w: String = CT.day_why(sid, lvl)
					if w == "" or "{" in w:
						why_ok = false
	_ok("the coach's why for every kind of day, voice and detail (rest days too): filled in, never empty", why_ok)
	cs.head().voice = "drill"
	cs.head().attributes.communication = 10
	_ok("the key session's reason in his words", CT.day_why(["intervals_800"], "hard").begins_with(str(data.coach_talk.session_why.intervals_800.why))
			and CT.day_why([], "normal") == str(data.coach_talk.voices.drill.day.rest))
	cs.head().attributes.communication = 4
	_ok("with little communication: the short form and 'Do it.'", CT.day_why(["intervals_800"], "hard") == "800 m intervals. Do it.")

	# The message after a race: every outcome, voice and detail.
	var race_ok := true
	for v in voices:
		cs.head().voice = v
		for comm in [5, 10, 16]:
			cs.head().attributes.communication = comm
			for note in [
					{"meet": "Kisat", "result": {"place": 1, "field": 8, "time": 130.5, "pb": true, "round": "Race"}, "story": {"case": "pb", "line": "A new best."}},
					{"meet": "Kisat", "result": {"place": 3, "field": 8, "time": 133.0, "pb": false, "round": "Race"}, "story": {}},
					{"meet": "Kisat", "result": {"place": 8, "field": 8, "time": 140.0, "pb": false, "round": "Race"}, "story": {"case": "below", "line": "Not your best."}},
					{"meet": "Kisat", "result": {"place": 0, "field": 8, "time": 0.0, "pb": false, "status": "dnf", "round": "Race"}, "story": {}}]:
				var text: String = CT.race_message(note, ms._fill(ctx, coach), _rng)
				if text == "" or "{" in text or not "Kisat" in text:
					race_ok = false
					print("    bad race text: ", text)
	_ok("the race message is filled in for every outcome, voice and detail, and names the meet", race_ok)
	_ok("outcomes: the case wins, else DNF = hurt, PB, the better half = good, else bad",
			CT.race_outcome({"result": {"place": 5, "field": 8, "pb": false}, "story": {"case": "won"}}) == "good"
			and CT.race_outcome({"result": {"place": 1, "field": 8, "status": "dq"}, "story": {"case": "won"}}) == "hurt"
			and CT.race_outcome({"result": {"place": 2, "field": 8, "pb": true}}) == "pb"
			and CT.race_outcome({"result": {"place": 4, "field": 8, "pb": false}}) == "good"
			and CT.race_outcome({"result": {"place": 5, "field": 8, "pb": false}}) == "bad"
			and CT.race_outcome({}) == "")

	# The evening after a real race: a message from the coach, not a stop.
	C.neutral_club = false
	game.start_career(_athlete(9))
	ms = _ms()
	for meet in cal.meets_between(game.date, game.add_days(game.date, 200)):
		if cal.coach_recommends(game.athlete, meet, game.date):
			game.enter(meet.key)
	if _weeks_until_race(40) == game.RACE:
		var meet_name: String = str(game.race_day.meet.name)
		var race_date: Dictionary = game.date.duplicate()
		_run_race()
		var note_msgs := []
		for x in ms.thread("coach"):
			if x.moment == "" and x.from != "you" and x.from != "system" and cal.date_key(x.date) == cal.date_key(race_date):
				note_msgs.append(x)
		_ok("the evening after the race: a message from the coach with the meet and the result (%s)" % (note_msgs[0].text.replace("\n", " ") if not note_msgs.is_empty() else "none"),
				not note_msgs.is_empty() and meet_name in note_msgs[0].text and not "{" in note_msgs[0].text)
		_ok("it is not a stop (Play week goes on; a Sunday race may bring the week talk too)",
				game.pending_event().is_empty() or bool(ms.moment(str(game.pending_event().get("moment", ""))).get("talk", false)))
	else:
		_ok("a race came within 40 weeks", false)

	# Switched off for the tools: no talk, Play week runs to Sunday night.
	MS.talks_enabled = false
	game.start_career(_athlete(10), "repeat")
	_ok("with the talks switched off (the tools): Play week reaches Sunday night without a stop", game.advance_week() == game.WEEK_DONE)
	MS.talks_enabled = true
	H.model_enabled = true


# --- 7. The people (session P1) ------------------------------------------------------------------------------------

const P1_FILES := ["family.json", "friends.json", "group.json", "school_people.json", "rivals.json"]


## A 14-year-old for part 7: `family` = the index of the family answer (-1 = from the seed); every third one was spotted by
## a PE teacher (the answer index 0 of "Who got you into athletics?").
func _p1_athlete(i: int, family := -1):
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	if family >= 0:
		answers["family"] = family
	if i % 3 == 0:
		answers["introduced_by"] = 0
	var gender := "male" if i % 2 == 0 else "female"
	var first: String = data.names[gender][rng.randi_range(0, data.names[gender].size() - 1)]
	var last: String = data.names.surnames[rng.randi_range(0, data.names.surnames.size() - 1)]
	return F.create({
		"first_name": first, "last_name": last, "gender": gender, "hometown": "Tampere", "club_id": "tap",
		"main_event": "800m", "birth_date": {"year": 2012, "month": rng.randi_range(1, 12), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)


func _p1_storylets() -> Array:
	return data.storylets.filter(func(s): return str(s.file) in P1_FILES)


func _people(careers: int) -> void:
	print("\n== 7. The people (session P1): the cast, the calendar, the effects, rivals, %d careers x 2 seasons, save / load, neutral" % careers)
	var MIND = load("res://scripts/core/mind_system.gd")
	var SCH = load("res://scripts/core/school_system.gd")
	var CA = load("res://scripts/core/cast.gd")
	var cal = load("res://scripts/core/calendar.gd")
	MS.include_test = false
	MS.talks_enabled = false
	MS.enabled = true
	_people_data(CA)
	MS.people_enabled = true
	_people_cast(CA)
	_people_calendar(CA)
	MIND.neutral = false
	SCH.neutral = false
	_people_effects()
	_people_rivals()
	if not "quick" in OS.get_cmdline_user_args():
		_people_seasons(careers, cal)
	_people_save_load()
	MIND.neutral = true
	SCH.neutral = true
	_people_neutral()
	MS.people_enabled = false
	_people_off()


## 7a. The data: cast.json and the P1 storylets' references.
func _people_data(CA) -> void:
	var cast: Dictionary = data.cast
	var p1 := _p1_storylets()
	var per_file := {}
	for s in p1:
		per_file[s.file] = int(per_file.get(s.file, 0)) + 1
	print("    P1 storylets: %d (%s)" % [p1.size(), ", ".join(per_file.keys().map(func(f): return "%s %d" % [f.trim_suffix(".json"), per_file[f]]))])
	_ok("about 100-150 P1 storylets (%d)" % p1.size(), p1.size() >= 100 and p1.size() <= 160)
	var faults := []
	for q in data.background_questions:
		if q.id == "family":
			for ans in q.answers:
				if not cast.attitudes.values().any(func(a): return str(ans.family) in a.from):
					faults.append("family answer %s has no attitude" % ans.family)
	var stage_ids := ["grade_8", "grade_9"]
	for s in p1:
		var whens := [s.get("when", {})]
		for t in s.text:
			if t is Dictionary:
				whens.append(t.get("when", {}))
		for r in s.replies:
			whens.append(r.get("when", {}))
			for key in ["attitude"]:
				if r.get("effects", {}).has(key) and not cast.attitudes.has(str(r.effects[key])):
					faults.append("%s: unknown attitude %s" % [s.id, r.effects[key]])
		for w in whens:
			for key in ["days_to", "days_after"]:
				for ev in w.get(key, {}):
					if not cast.life.has(ev):
						faults.append("%s: unknown life event %s" % [s.id, ev])
			for a in w.get("family", []):
				if not cast.attitudes.has(a):
					faults.append("%s: unknown attitude %s" % [s.id, a])
			for st in w.get("stage", []):
				if not st in stage_ids:
					faults.append("%s: unknown stage %s" % [s.id, st])
			for tr in w.get("trait", []):
				if not cast.friends.trait_words.has(tr):
					faults.append("%s: unknown trait %s" % [s.id, tr])
		if not str(s.thread) in ["family", "friends", "group", "school", "rivals"]:
			faults.append("%s: a P1 storylet in thread %s" % [s.id, s.thread])
	for f in faults:
		print("    " + f)
	_ok("cast.json: every family answer has an attitude; the P1 storylets name known events, attitudes, stages and traits (%d faults)" % faults.size(), faults.is_empty())


## 7b. The cast of a new career from every family answer.
func _people_cast(CA) -> void:
	var family_q: Dictionary = data.background_questions.filter(func(q): return q.id == "family")[0]
	var faults := []
	for fi in family_q.answers.size():
		var a = _p1_athlete(fi, fi)
		game.start_career(a, "repeat")
		var ms = _ms()
		ms._sync_people()
		var fam_id := str(family_q.answers[fi].family)
		var parents: Array = ms.people_for("parent")
		var sib: Array = ms.people_for("sibling")
		var friends: Array = ms.people_for("friends")
		var best: Array = ms.people_for("best_friend")
		var partners: Array = ms.people_for("partner")
		var staff: Array = ms.people_for("school")
		var line := "%s: %s, attitude %s; friends %s; partners %s; school %s" % [fam_id,
				", ".join((parents + sib).map(func(p): return "%s (%s)" % [ms.person_name(p), p.first_name])), ms.family.get("attitude", ""),
				", ".join(friends.map(func(p): return "%s %s" % [p.first_name, p.get("trait", "")])),
				", ".join(partners.map(func(p): return "%s %s" % [p.first_name, p.role])),
				", ".join(staff.map(func(p): return "%s %s" % [p.first_name, p.word]))]
		print("    " + line)
		if parents.size() < 1 or parents.size() > 2:
			faults.append("%s: %d parents" % [fam_id, parents.size()])
		if (sib.size() == 1) != (fam_id == "sibling"):
			faults.append("%s: sibling %d" % [fam_id, sib.size()])
		if str(ms.family.get("attitude", "")) != CA.attitude_for(fam_id):
			faults.append("%s: attitude %s" % [fam_id, ms.family.get("attitude", "")])
		if (fam_id == "athletics_parent") != parents.any(func(p): return bool(p.get("athlete_parent", false))):
			faults.append("%s: the parent who ran" % fam_id)
		if best.size() != 1 or friends.size() < 2 or friends.size() > 3:
			faults.append("%s: friends %d (best %d)" % [fam_id, friends.size(), best.size()])
		if (a.old_sport != "") != friends.any(func(p): return str(p.get("trait", "")) == "old_team"):
			faults.append("%s: the old team friend (sport '%s')" % [fam_id, a.old_sport])
		if partners.size() != mini(3, ms.people_for("teammate").size()):
			faults.append("%s: %d partners" % [fam_id, partners.size()])
		if staff.size() != 3:
			faults.append("%s: %d school staff" % [fam_id, staff.size()])
		if (a.origin == "pe_teacher") != staff.any(func(p): return bool(p.get("spotted", false))):
			faults.append("%s: the PE teacher who spotted you (origin %s)" % [fam_id, a.origin])
		var firsts := {}
		for p in parents + sib + friends:
			if firsts.has(p.first_name) or p.first_name == a.first_name:
				faults.append("%s: the first name %s twice" % [fam_id, p.first_name])
			firsts[p.first_name] = true
		if parents.any(func(p): return str(p.get("call", "")) == ""):
			faults.append("%s: a parent without Mum / Dad" % fam_id)
	for f in faults:
		print("    " + f)
	_ok("every family answer: 1-2 parents with Mum / Dad, a sibling only with 'An older sibling runs', the attitude, the parent who ran, a best friend + 1-2 friends (the old team with a sport before), 3 training partners, 3 school staff (the PE teacher who spotted you), unique names (%d faults)" % faults.size(), faults.is_empty())
	# The same career = the same people; the global dice untouched.
	game.start_career(_p1_athlete(3, 2), "repeat")
	var first_cast: String = JSON.stringify(_ms().people)
	seed(4711)
	var x1 := randi()
	seed(4711)
	game.start_career(_p1_athlete(3, 2), "repeat")
	var second_cast: String = JSON.stringify(_ms().people)
	_ok("the same career gets the same people", first_cast == second_cast)
	seed(4711)
	var plain := randi()
	seed(4711)
	CA.make(_p1_athlete(3, 2), {"origin": "", "old_sport": "football", "family": "sibling"})
	CA.make_school(_p1_athlete(3, 2), "comp", "comprehensive", "pe_teacher")
	_ok("making the cast does not touch the global dice", randi() == plain)
	if x1 == 0:
		pass


## 7c. The yearly calendar.
func _people_calendar(CA) -> void:
	var cal = load("res://scripts/core/calendar.gd")
	game.start_career(_p1_athlete(1, 2), "repeat")
	var d := func(y, m, dd): return {"year": y, "month": m, "day": dd}
	var ok := true
	var checks := [
		[CA.occurrence("juhannus", 2027), d.call(2027, 6, 25)], [CA.occurrence("juhannus", 2028), d.call(2028, 6, 23)],
		[CA.occurrence("easter", 2027), d.call(2027, 3, 28)], [CA.occurrence("school_end", 2027), d.call(2027, 6, 5)],
		[CA.occurrence("rippileiri", 2027, {"rippi_june": {}}), d.call(2027, 6, 14)],
		[CA.occurrence("rippileiri", 2027, {"rippi_july": {}}), d.call(2027, 7, 12)]]
	for c in checks:
		if cal.date_key(c[0]) != cal.date_key(c[1]):
			ok = false
			print("    calendar: %s != %s" % [c[0], c[1]])
	ok = ok and CA.occurrence("rippileiri", 2028, {"rippi_june": {}}).is_empty() and CA.occurrence("rippileiri", 2027, {}).is_empty()
	ok = ok and CA.days_to("vappu", d.call(2027, 4, 28)) == 2 and CA.days_after("christmas", d.call(2027, 1, 2)) == 9
	ok = ok and CA.days_to("christmas", d.call(2026, 12, 24)) == 0
	_ok("the calendar: juhannus = the Friday 19-25 June, Easter, the school's last day, the confirmation camp of the year you turn 15, days to / after", ok)


## 7d. The effects of a reply.
func _people_effects() -> void:
	game.start_career(_p1_athlete(2, 4), "repeat")
	_play(3, false)
	var ms = _ms()
	var ss = game.get_system("school")
	ms._sync_people()
	var friend: Dictionary = ms.people_for("best_friend")[0]
	var others: Array = ms.people_for("friend")
	var tomorrow: Dictionary = game.add_days(game.date, 1)
	var before: float = ss.life_load(tomorrow, [])
	ms._apply({"sleep": -2}, friend, "check")
	var parts: Array = ss.load_parts(tomorrow, [])
	var late: Array = parts.filter(func(p): return p.id == "late_night")
	_ok("a late night (sleep -2) = life load %.2f tomorrow (%.2f -> %.2f), shown as '%s'" % [late[0].value if not late.is_empty() else 0.0, before, ss.life_load(tomorrow, []), data.school_life.texts.pulls.late_night],
			not late.is_empty() and is_equal_approx(float(late[0].value), 2.0 * float(data.cast.sleep.life_load_per_point)) and ss.load_parts(game.date, []).filter(func(p): return p.id == "late_night").is_empty())
	var sid: String = str(ss.subject_list().filter(func(s): return ss.is_academic(str(s.id)))[0].id)
	var lv: float = ss.level(sid)
	ms._apply({"grades": 2}, friend, "check")
	_ok("grades +2 = every academic level +%.2f (%.3f -> %.3f)" % [2 * float(data.cast.grades.grades_per_point), lv, ss.level(sid)],
			is_equal_approx(ss.level(sid) - lv, 2 * float(data.cast.grades.grades_per_point)))
	ms._apply({"attitude": "coming_round"}, friend, "check")
	var att_ok: bool = ms.family.attitude == "coming_round"
	ms._apply({"attitude": "no_such"}, friend, "check")
	_ok("the family's attitude changes with a reply (an unknown one is ignored)", att_ok and ms.family.attitude == "coming_round")
	ms._apply({"memory": "promised"}, friend, "check")
	var ctx := _ctx()
	_ok("the sender remembers: memory / !memory hold for them only", ms._sender_ok({"memory": ["promised"]}, ctx, friend)
			and not ms._sender_ok({"memory": ["!promised"]}, ctx, friend)
			and (others.is_empty() or not ms._sender_ok({"memory": ["promised"]}, ctx, others[0])))
	var rel_before: float = others[0].relation if not others.is_empty() else 0.0
	var best_before: float = friend.relation
	ms._apply({"relation_thread": {"friends": 2}}, friend, "check")
	_ok("relation_thread moves everyone else in the thread", others.is_empty() or (others[0].relation == rel_before + 2.0 and friend.relation == best_before))
	var lines: Array = ms._changes_of({"sleep": -1, "grades": 2, "relation": 3, "relation_thread": {"friends": -1}, "attitude": "supportive"}, friend, true)
	print("    result card: " + " | ".join(lines))
	_ok("the result card says it in words: sleep, schoolwork, the person, the thread, the attitude, remembered",
			lines.size() == 6 and lines.all(func(l): return not "{" in str(l)))
	_ok("a parent is 'Mum' / 'Dad' in sentences", ms.people_for("parent").all(func(p): return ms.short_name(p) in ["Mum", "Dad"]))


## 7e. Rivals become people; their record against you.
func _people_rivals() -> void:
	game.start_career(_p1_athlete(5, 2), "repeat")
	var ms = _ms()
	var pool: Array = game.rivals
	for i in 5:
		pool[i].met = 2 + i   # (the last ones met most)
	ms._sync_people()
	var rv: Array = ms.people_for("rival")
	_ok("rivals met at least %d times become people, at most %d, the most met first (%s)" % [data.cast.rivals.met_min, data.cast.rivals.max,
			", ".join(rv.map(func(p): return p.first_name))], rv.size() == int(data.cast.rivals.max)
			and rv.all(func(p): return int(pool.filter(func(r): return str(r.id) == p.rival_id)[0].met) >= 4))
	var p: Dictionary = rv[0]
	var ctx := _ctx()
	ctx.race_note = {"vs": [{"id": p.rival_id, "beat": false}], "result": {"place": 5, "field": 8}}
	for k in 3:
		ms._post_rival_note(ctx, _today() + k)
	_ok("three losses in a row: their streak is 3, rival_race = lost", int(ms.rival_stats[p.rival_id].streak) == 3
			and ms._sender_ok({"rival_streak": [3, null], "rival_race": ["lost"]}, ctx, p))
	ctx.race_note = {"vs": [{"id": p.rival_id, "beat": true}], "result": {"place": 1, "field": 8}}
	ms._post_rival_note(ctx, _today() + 4)
	_ok("then a win: the streak resets, your wins 1, rival_race = beat", int(ms.rival_stats[p.rival_id].streak) == 0
			and int(ms.rival_stats[p.rival_id].wins) == 1 and ms._sender_ok({"rival_race": ["beat"]}, ctx, p))
	_ok("a rival's note is never a stop", game.pending_event().is_empty())


## 7f. Many seasons with the people on: the rate, the stops, repeats, coverage.
func _people_seasons(careers: int, cal) -> void:
	var t0 := Time.get_ticks_msec()
	C.neutral_club = false
	SS.offers_enabled = true
	var family_q: Dictionary = data.background_questions.filter(func(q): return q.id == "family")[0]
	var week_counts := []
	var week_stops := []
	var by_age := {}
	var by_thread := {}
	var fired_ids := {}
	var cooldown_bad := []
	var variant_bad := 0
	var per_day_bad := 0
	var stuck := []
	var rival_people := 0
	var rival_notes := 0
	var late_nights := 0
	var answered := 0
	var none := 0
	var auto := 0
	var invites := 0           # session L1b: invitations (outside the 3-5 a week and the one a day)
	var invite_week_max := 0
	var moods := {}   # mood -> word id -> weeks (Sunday night, answers at random)
	var quality_sum := 0.0   # the mind's training quality at each week's end (M1: ~1.0005 on average without the people)
	var quality_n := 0
	for c in careers:
		game.start_career(_p1_athlete(200 + c, c % family_q.answers.size()))
		for meet in cal.meets_between(game.date, game.add_days(game.date, 730)):
			if cal.coach_recommends(game.athlete, meet, game.date):
				game.enter(meet.key)
		var ms = _ms()
		ms.rng.seed = 131 + c
		game.get_system("health").rng.seed = 161 + c
		_answer_stops()
		var weeks := 104
		var start_monday: int = MS.day_no(cal.monday_of(game.START_DATE))
		for w in weeks:
			if not _play(7):
				stuck.append("career %d week %d: the days did not move on" % [c, w])
				break
			late_nights += ms.late_nights.size()
			var mind = game.get_system("mind")
			if mind != null:
				quality_sum += float(mind.training_quality())
				quality_n += 1
				for mood in ["confidence", "motivation", "stress"]:
					var wid: String = str(mind.word(mood).id)
					if not moods.has(mood):
						moods[mood] = {}
					moods[mood][wid] = int(moods[mood].get(wid, 0)) + 1
		ms = _ms()
		rival_people += ms.people.values().filter(func(p): return str(p.thread) == "rivals").size()
		var invite_weeks := {}
		var per_week := {}
		var stops_week := {}
		var per_day := {}
		var last_by := {}
		var last_var := {}
		for f in ms.fired:
			var s: Dictionary = ms.storylet(f.storylet)
			if not str(s.get("file", "")) in P1_FILES:
				continue
			fired_ids[f.storylet] = int(fired_ids.get(f.storylet, 0)) + 1
			if last_by.has(f.storylet):
				var gap: int = int(f.day) - int(last_by[f.storylet])
				if bool(s.get("once", false)) or gap < int(s.get("cooldown_days", 14)):
					cooldown_bad.append("%s again after %d days" % [f.storylet, gap])
			last_by[f.storylet] = f.day
			var unconditional: int = s.text.filter(func(t): return not t is Dictionary).size()
			if unconditional == s.text.size() and s.text.size() > 1 and last_var.get(f.storylet, -1) == f.variant:
				variant_bad += 1
			last_var[f.storylet] = f.variant
			if f.auto:
				auto += 1
				continue
			var p: Dictionary = ms.people.get(str(f.from), {})
			var th := str(p.get("thread", s.thread))
			by_thread[th] = int(by_thread.get(th, 0)) + 1
			if str(s.get("topic", "")) == "rival":
				rival_notes += 1
				continue   # (a rival's note sits outside the 3-5 a week, like the coach's race message)
			if bool(f.get("invite", false)):   # (session L1b: posted when the week opens, outside the day's slot: at most 1 a week)
				invites += 1
				var iwk := floori((int(f.day) - start_monday) / 7.0)
				invite_weeks[iwk] = int(invite_weeks.get(iwk, 0)) + 1
				continue
			var wk := floori((int(f.day) - start_monday) / 7.0)
			per_week[wk] = int(per_week.get(wk, 0)) + 1
			if f.stop or bool(f.get("planner", false)):   # (session L1a: an important moment waits for the planner instead of stopping)
				stops_week[wk] = int(stops_week.get(wk, 0)) + 1
			if f.stop and not bool(f.get("talk", false)):
				stuck.append("career %d: %s stopped Play week (no people stops since L1a)" % [c, f.storylet])
			per_day[f.day] = int(per_day.get(f.day, 0)) + 1
		for dd in per_day:
			if per_day[dd] > int(data.moments.rate.max_per_day):
				per_day_bad += 1
		for iw in invite_weeks:
			invite_week_max = maxi(invite_week_max, int(invite_weeks[iw]))
		for wk in range(1, weeks):
			week_counts.append(int(per_week.get(wk, 0)))
			week_stops.append(int(stops_week.get(wk, 0)))
			var age: int = game.athlete.age_on(game.add_days(game.START_DATE, 7 * wk))
			if not by_age.has(age):
				by_age[age] = [0, 0]
			by_age[age][0] += int(per_week.get(wk, 0))
			by_age[age][1] += 1
		var today: int = MS.day_no(game.date)
		for m in ms.pending():
			if not m.stop and today > int(m.expires) + 1:
				stuck.append("career %d: %s waits past its time" % [c, m.storylet])
		for q in ms.queue:
			if today > int(q.until) + 1:
				stuck.append("career %d: chain %s past its window" % [c, q.get("id", q.get("topic", ""))])
		if not game.pending_event().is_empty():
			stuck.append("career %d: a stop event left waiting" % c)
		for m in ms.moments:
			if m.kind == "moment" and not m.auto and m.answer != "":
				if m.answer == MS.NONE:
					none += 1
				else:
					answered += 1
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var mean := _mean(week_counts)
	var stops := _mean(week_stops)
	print("    %.0f s; %d weeks: moments a week mean %.2f (sd %.2f, %s), people stops a week %.2f (most in a week %d)" % [
			secs, week_counts.size(), mean, _sd(week_counts), _dist(week_counts), stops, week_stops.max() if not week_stops.is_empty() else 0])
	var ages := by_age.keys()
	ages.sort()
	for age in ages:
		print("    age %d: %.2f moments a week over %d weeks" % [age, float(by_age[age][0]) / by_age[age][1], by_age[age][1]])
	print("    by person: %s" % ", ".join(by_thread.keys().map(func(t): return "%s %d" % [t, by_thread[t]])))
	print("    rivals who became people %d, rival notes %d, late nights %d, answered %d, unanswered %d, by a rule %d" % [rival_people, rival_notes, late_nights, answered, none, auto])
	for mood in moods:
		var total := 0
		for wid in moods[mood]:
			total += int(moods[mood][wid])
		print("    %s (weeks, random answers): %s" % [mood, ", ".join(moods[mood].keys().map(func(w): return "%s %d%%" % [w, roundi(100.0 * moods[mood][w] / maxi(total, 1))]))])
	var p1 := _p1_storylets()
	var never: Array = p1.filter(func(s): return not fired_ids.has(s.id)).map(func(s): return s.id)
	var ids: Array = fired_ids.keys()
	ids.sort()
	print("    fired: " + ", ".join(ids.map(func(i): return "%s %d" % [i, fired_ids[i]])))
	print("    never fired (%d): %s" % [never.size(), ", ".join(never)])
	_ok("rate with the people: 3-5 moments a week on average (%.2f)" % mean, mean >= 3.0 and mean <= 5.0)
	_ok("never more than %d in a week (most %d) or %d in a day (%d days over)" % [data.moments.rate.max_per_week,
			week_counts.max() if not week_counts.is_empty() else 0, data.moments.rate.max_per_day, per_day_bad],
			week_counts.all(func(x): return x <= int(data.moments.rate.max_per_week)) and per_day_bad == 0)
	_ok("at most ~1 moment a week waits for the planner on average (%.2f), none stops Play week" % stops, stops <= 1.05)
	print("    invitations (session L1b, posted into a slot when the week opens; outside the counts above): %d, %.2f a week" % [
			invites, invites / float(maxi(1, week_counts.size()))])
	_ok("invitations come, and at most %d a week (most %d)" % [int(data.habits.invites.max_per_week), invite_week_max],
			invites > 0 and invite_week_max <= int(data.habits.invites.max_per_week))
	for b in cooldown_bad.slice(0, 5):
		print("    " + b)
	_ok("no moment again inside its cooldown, no 'once' moment twice (%d)" % cooldown_bad.size(), cooldown_bad.is_empty())
	_ok("never the same text twice in a row (%d)" % variant_bad, variant_bad == 0)
	for s in stuck.slice(0, 5):
		print("    " + s)
	_ok("nothing stuck (%d)" % stuck.size(), stuck.is_empty())
	var need := 0.85 if careers >= 12 else 0.75   # (the rare ones need many careers: run `-- 8 2 12` for the full count)
	_ok("coverage: at least %d %% of the P1 storylets came (%d of %d)" % [roundi(need * 100), p1.size() - never.size(), p1.size()],
			p1.size() - never.size() >= ceili(need * p1.size()))
	_ok("every person writes: family, friends, group, school, rivals (%s)" % ", ".join(by_thread.keys()),
			["family", "friends", "group", "school", "rivals"].all(func(t): return int(by_thread.get(t, 0)) > 0))
	_ok("both ages 14 and 15 have 3-5 a week", [14, 15].all(func(a): return by_age.has(a) and float(by_age[a][0]) / by_age[a][1] >= 3.0 and float(by_age[a][0]) / by_age[a][1] <= 5.0))
	_ok("the family's report card talk and the application talk came", fired_ids.keys().any(func(i): return str(i).begins_with("fam_card_"))
			and fired_ids.keys().any(func(i): return str(i).begins_with("fam_app_")))
	_ok("late nights happened (a reply's sleep) and moments were both answered and left", late_nights > 0 and answered > 0 and none > 0)
	var q := quality_sum / maxi(quality_n, 1)
	_ok("the moods stay calibrated: mean training quality %.4f (M1 without the people ~1.0005; within 1 %%)" % q, absf(q - 1.0) < 0.01)
	var mot: Dictionary = moods.get("motivation", {})
	var mot_total := 0
	for wid in mot:
		mot_total += int(mot[wid])
	var flat_share := float(mot.get("flat", 0)) / maxi(mot_total, 1)
	_ok("motivation Flat in under 10 %% of weeks (%.1f %%, GDD 4.9.7)" % (100.0 * flat_share), flat_share < 0.10)


## 7g. Save / load with the people on, bit for bit; a save from before the first day keeps the cast.
func _people_save_load() -> void:
	C.neutral_club = false
	SS.offers_enabled = true
	game.start_career(_p1_athlete(77, 0))
	saves.save("storylet_check_p1_day0")
	var cast0: String = JSON.stringify(_ms().people)
	saves.load_slot("storylet_check_p1_day0")
	_ok("a save made before the first day keeps the cast (%d people) and the attitude" % _ms().people.size(),
			JSON.stringify(_ms().people) == cast0 and str(_ms().family.get("attitude", "")) == "athletics" and not _ms().cast_info.is_empty())
	_play_fixed(40)
	saves.save("storylet_check_p1")
	var state_before: String = JSON.stringify(_ms().to_dict())
	_play_fixed(45)
	var straight := _snapshot() + JSON.stringify(game.get_system("school").to_dict())
	saves.load_slot("storylet_check_p1")
	_ok("after loading: the same moments state (people, memory, late nights, rivals)", JSON.stringify(_ms().to_dict()) == state_before)
	_play_fixed(45)
	var after := _snapshot() + JSON.stringify(game.get_system("school").to_dict())
	_ok("45 more days after loading = the same 45 days without saving (with the people, school and moods on)", after == straight)
	if after != straight:
		_diff(straight, after)
	saves.delete("storylet_check_p1")
	saves.delete("storylet_check_p1_day0")


## 7h. Neutral: a year of the coach week with the people on (every moment a stop, answered at random), the mind and school
## neutral = training_balance's coach-row fingerprint.
func _people_neutral() -> void:
	var on := _year(true)
	print("    people on: %d moments, %d stops answered; attribute sum %.9f" % [on.moments, on.stops, on.sum])
	_ok("the people's moments came in the neutral year (%d)" % on.moments, on.moments > 100)
	_ok("training_balance's coach-row fingerprint with the people on (206.798298350): %.9f" % on.sum, "%.9f" % on.sum == "206.798298350")


## 7i. The people switched off (the tools): no cast, none of the people's moments.
func _people_off() -> void:
	game.start_career(_p1_athlete(9, 2), "repeat")
	_play(60, true)
	var ms = _ms()
	var p1 := _p1_storylets().map(func(s): return s.id)
	_ok("people off: no cast, none of the people's moments in 60 days, nothing of P1 in the save",
			ms.people_for("family").is_empty() and ms.people_for("friends").is_empty()
			and not ms.fired.any(func(f): return f.storylet in p1) and not ms.to_dict().has("cast_info"))
