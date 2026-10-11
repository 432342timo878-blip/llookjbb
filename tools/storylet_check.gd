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
## Run: godot --headless --path . -s res://tools/storylet_check.gd [-- [careers for part 3, default 8] [seasons, default 2]]
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
		"tomorrow_rest", "flags", "flag_days", "counters", "seen", "not_seen", "answered", "trust", "relation", "chance"]
const PLACEHOLDERS := ["name", "full_name", "from", "coach", "coach_first", "teammate", "club", "meet", "race_days", "pb",
		"weekday", "tomorrow"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	MS = load("res://scripts/core/storylet_system.gd")
	C = load("res://scripts/core/coach_system.gd")
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
	_data_checks()
	MS.include_test = true
	_rules()
	_seasons(careers, seasons)
	_save_load()
	_neutral()
	MS.include_test = false
	MS.enabled = true
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
		if not from[0] in ["coach", "teammate"] or (from.size() > 1 and not roles.has(from[1])):
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
		if replies.size() < 2 or replies.size() > 4:
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
		if bool(s.get("chain_only", false)) and not nexts.has(s.id):
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
	_ok("no real moments yet and the test ones not asked for: nothing happens (normal careers today)",
			_ms().fired.is_empty() and game.events.is_empty() and _ms().to_dict().is_empty())
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

	# The two settings.
	var m5 := _force("test_coach_injury")
	_ok("Important only: an important moment is a stop event (title '%s')" % game.pending_event().get("title", ""),
			m5.stop and game.pending_event().get("moment", "") == m5.id)
	game.answer_event(game.pending_event().id, "ok")
	_ok("a stop answered 'ok' (tools) = no answer", ms.moment(m5.id).answer == MS.NONE and game.pending_event().is_empty())
	ms.set_stop_mode("all")
	var m6 := _force("test_group_weekend")
	_ok("Every moment: a small moment stops too", m6.stop and game.pending_event().get("moment", "") == m6.id)
	ms.answer(m6.id, "yes")
	_ok("answered from the thread, its event is answered too", game.pending_event().is_empty() and ms.moment(m6.id).answer == "yes")
	ms.set_stop_mode("important")
	ms.set_stop_mode("nonsense")
	_ok("an unknown setting is ignored", ms.stop_mode() == "important")

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
		var every := c % 4 == 3   # every fourth career on "Every moment"
		game.start_career(_athlete(100 + c))
		var ms = _ms()
		ms.rng.seed = 31 + c
		game.get_system("health").rng.seed = 61 + c
		if every:
			ms.set_stop_mode("all")
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
			if f.stop:
				stops_week[wk] = int(stops_week.get(wk, 0)) + 1
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
	print("    %.0f s; Important only: %d weeks, moments a week mean %.2f (sd %.2f, %s), people stops a week %.2f (most in a week: %d)" % [
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
	_ok("Important only: at most ~1 people stop a week on average (%.2f)" % stops, stops <= 1.05)
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
