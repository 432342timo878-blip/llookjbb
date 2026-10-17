extends SceneTree
## Check of the coach market (GDD 4.9.1 / 4.9.2, session C6; CoachMarket, data/market.json):
## 1. the data (every voice and the neutral `real` words for every message, tiers, budgets for every family answer);
## 2. the pool by town: a 14-year-old in a small municipality / small town sees 1-3 coaches of the town (remote ones come on
##    top), a centre town more; the same career = the same coaches; the global dice untouched;
## 3. scouting: ranges hold the true value, narrow by results / asking around / a visit (played through the day) and nest,
##    and are exact after 8 weeks together;
## 4. real coaches only when allowed (kind, age, the centre town, min_level, world level = approach only), held-back coaches
##    never (only the ids of data/coaching.json real), no real coach tied to a minor (neutral words, fictional group);
## 5. the family budget limits paid coaches (club fees always fit, estimates for missing fees);
## 6. changing coach end to end (ask, start, goodbye, Sunday night, new relation and group, messages) and save / load;
## 7. the ending chain (6 + 4 + 4 weeks Strained: two warnings, the end, the athlete picks) and its reset;
## 8. an offer after a personal best that clears a coach's bar; the TF-juniorit standard opens the national coaches;
## 9. distance (penalties, race reading at skipped meets), the parent coach (fit, stress pull);
## 10. the market off / untouched changes nothing (the same weeks bit for bit).
## Run: godot --headless --path . -s res://tools/market_check.gd
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var game
var data
var F
var M
var C
var H
var MS
var SL
var CAL
var saves
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	M = load("res://scripts/core/coach_market.gd")
	C = load("res://scripts/core/coach_system.gd")
	H = load("res://scripts/core/health_system.gd")
	MS = load("res://scripts/core/mind_system.gd")
	SL = load("res://scripts/core/storylet_system.gd")
	CAL = load("res://scripts/core/calendar.gd")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	H.model_enabled = false
	MS.neutral = true
	_data_checks()
	_pool_checks()
	_scouting()
	_real_coaches()
	_budget()
	_change_coach()
	_ending()
	_offers()
	_distance_parent()
	_neutral()
	M.enabled = false
	H.model_enabled = true
	MS.neutral = false
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


## A career: a 14-year-old (born 2012; `born` earlier = older) of club `club_id`, family answer index `family`.
func _career(club_id: String, seed: int, born := 2012, family := 4, gender := "male"):
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	answers["family"] = family
	var club: Dictionary = data.get_club(club_id)
	var a = F.create({"first_name": "Testi%d" % seed, "last_name": "Juoksija", "gender": gender, "hometown": str(club.city),
			"club_id": club_id, "main_event": "800m", "birth_date": {"year": born, "month": 3, "day": 14}, "answers": answers}, rng)
	game.start_career(a, "repeat")
	return a


func _mk():
	return game.get_system("market")


## A club of a town of the given size class (data/towns.json), else "".
func _club_of_size(size: String) -> String:
	for c in data.clubs:
		var t: Dictionary = data.get_town(str(c.city))
		if not t.is_empty() and data.town_size(str(c.city)) == size and t.get("centre") == null:
			return str(c.id)
	return ""


func _play_days(days: int, pick := "") -> void:
	for i in days:
		var r: String = game.advance_day()
		if r == game.RACE:
			var rd = game.race_day
			while not rd.is_done():
				var race = rd.start_round(false, "pack")
				race.run()
				rd.finish_round()
			game.finish_race()
		_answer_all(pick)


func _answer_all(pick := "") -> void:
	while not game.pending_event().is_empty():
		var e: Dictionary = game.pending_event()
		var id := pick if pick != "" else (str(e.choices[0].id) if not e.choices.is_empty() else "ok")
		game.answer_event(e.id, id)


## Plays to the end of this week (Sunday night): until the date is in the next week.
func _play_week(pick := "") -> void:
	var monday = CAL.date_key(game.week_monday())
	var guard := 0
	while CAL.date_key(game.week_monday()) == monday and guard < 30:
		guard += 1
		var r: String = game.advance_day()
		if r == game.RACE:
			var rd = game.race_day
			while not rd.is_done():
				var race = rd.start_round(false, "pack")
				race.run()
				rd.finish_round()
			game.finish_race()
		_answer_all(pick)


# --- 1. Data ------------------------------------------------------------------------------------------------------------------

func _data_checks() -> void:
	print("== 1. Data (data/market.json)")
	var mk: Dictionary = data.market
	var voices: Array = data.coaches.coaches.keys()
	var missing := []
	var p: Dictionary = mk.lines.pitch
	for reason in p.open:
		for v in voices + ([] if reason == "strained" else ["real"]):
			if not p.open[reason].has(v):
				missing.append("pitch.open.%s.%s" % [reason, v])
		if not p.see.has(reason):
			missing.append("pitch.see." + reason)
	for part in ["plan_intro", "promise", "close"]:
		for v in voices + ["real"]:
			if not p[part].has(v):
				missing.append("pitch.%s.%s" % [part, v])
	for at in data.coaching.attributes:
		if not p.plan.has(at.id):
			missing.append("pitch.plan." + at.id)
	for key in ["yes", "not_yet", "no_time", "full", "farewell", "welcome", "warn1", "warn2", "end"]:
		for v in voices + ["real"]:
			if not mk.lines[key].has(v):
				missing.append("%s.%s" % [key, v])
	for key in ["offer_answer", "farewell_answer", "warn_answer"]:
		for r in mk.lines[key]:
			for v in voices + ["real"]:
				if not mk.lines[key][r].has(v):
					missing.append("%s.%s.%s" % [key, r, v])
	_ok("every message has a line for each of the %d voices and the neutral 'real' words (missing: %s)" % [voices.size(), missing], missing.is_empty())
	var per_voice := []
	for v in voices:
		for f in [data.coaching.personalities, data.advice.race.lean, data.advice.race.kick.lean_m, data.advice.race.shouts.lean,
				data.advice.race.shouts.flip, data.advice.race.shouts.accuracy_bonus, data.advice.race.texts.line, data.advice.suggest.intro,
				data.advice.suggest.answered, data.coach_talk.voices, data.coach_talk.verdict.voice, data.coach_talk.proposal.intro,
				data.coach_talk.proposal.answered, data.goals.process.by_voice, data.goals.offer.intro, data.goals.met.text,
				data.goals.review.text, data.mind.coach.lines]:
			if not f.has(v):
				per_voice.append(v)
	_ok("the 8 voices have their texts and leanings in every file (missing: %s)" % [per_voice], per_voice.is_empty() and voices.size() == 8)
	var fams := []
	for q in data.background_questions:
		if q.id == "family":
			for ans in q.answers:
				fams.append(str(ans.get("family", "")))
	_ok("the stop panel has a caption for the market's messages", str(data.moments.ui.get("stop_head_market", "")) != "")
	_ok("a budget for every family answer %s" % [fams], fams.size() == 6 and fams.all(func(f): return mk.budget.by_family.has(f)))
	_ok("the tighter budgets (user): athletics parent 65, top parent 80, sibling 40, sporty 55, not sporty 35, against 15",
			int(mk.budget.by_family.athletics_parent) == 65 and int(mk.budget.by_family.top_parent) == 80 and int(mk.budget.by_family.against) == 15)


# --- 2. The pool -------------------------------------------------------------------------------------------------------------

func _pool_checks() -> void:
	print("== 2. The pool by town (14-year-olds, 20 careers per town)")
	M.enabled = false
	for size in ["village", "small", "town", "city"]:
		var club := _club_of_size(size)
		if club == "":
			continue
		var town_counts := []
		var all_counts := []
		for i in 20:
			_career(club, 100 + i)
			var lists: Dictionary = _mk().listing()
			town_counts.append(lists.get("club", []).size())
			all_counts.append(_total(lists))
		var lo: int = town_counts.min()
		var hi: int = town_counts.max()
		print("    %-8s (%s, %s): coaches of the club %d-%d, all visible %d-%d" % [size, club, data.get_club(club).city, lo, hi, all_counts.min(), all_counts.max()])
		if size in ["village", "small"]:
			_ok("a 14-year-old in a %s sees 1-3 coaches of the town (remote coaches come on top)" % size, lo >= 1 and hi <= 3)
	for club in ["tap", "hkv"]:
		var counts := []
		for i in 20:
			_career(club, 300 + i)
			counts.append(_mk().listing().get("club", []).size())
		print("    centre   (%s, %s): coaches of the club %d-%d" % [club, data.get_club(club).city, counts.min(), counts.max()])
		_ok("a centre town (%s) has more coaches in the club (at least 4, up to 8)" % data.get_club(club).city, counts.min() >= 4 and counts.max() <= 8)
	# The same career = the same coaches; the global dice untouched.
	var names1 := _names_of(_career("tap", 777))
	var names2 := _names_of(_career("tap", 777))
	_ok("the same career gets the same coaches (%d coaches)" % names1.size(), names1 == names2 and names1.size() > 10)
	_career("tap", 778)
	seed(4242)
	var before := randi()
	seed(4242)
	_mk().ensure_pool()
	_ok("making the pool does not touch the global dice", randi() == before)
	var real_ids := []
	for c in _mk().coaches():
		if bool(c.get("real", false)):
			real_ids.append(str(c.id))
	var data_ids: Array = data.coaching.real.map(func(r): return str(r.id))
	real_ids.sort()
	data_ids.sort()
	_ok("the real coaches in the pool are exactly data/coaching.json real (the held-back coaches are never there)", real_ids == data_ids)


func _total(lists: Dictionary) -> int:
	var n := 0
	for k in lists:
		n += lists[k].size()
	return n


func _names_of(_a) -> Array:
	var out := []
	for c in _mk().coaches():
		out.append("%s|%s|%s" % [c.id, c.name, c.facts.town])
	out.sort()
	return out


# --- 3. Scouting --------------------------------------------------------------------------------------------------------------

func _scouting() -> void:
	print("== 3. Scouting")
	M.enabled = true
	_career("tap", 900, 2010)
	var mk = _mk()
	var c := {}
	for x in mk.coaches():
		if str(x.get("market", {}).get("tier", "")) == "regional" and str(x.facts.town) == "Tampere":
			c = x
			break
	if c.is_empty():
		for x in mk.coaches():
			if str(x.get("market", {}).get("tier", "")) == "regional":
				c = x
				break
	var w0 := {}
	var r0 := {}
	var inside := true
	for at in data.coaching.attributes:
		w0[at.id] = mk.width(c, at.id)
		r0[at.id] = mk.range_of(c, at.id)
		inside = inside and int(r0[at.id][0]) <= int(c.attributes[at.id]) and int(c.attributes[at.id]) <= int(r0[at.id][1])
	_ok("an unknown regional coach: ranges %d points wide, the true value inside every range" % int(w0.technique),
			inside and int(w0.technique) == int(data.market.scouting.width.regional))
	var off_middle := 0
	for at in data.coaching.attributes:
		if int(c.attributes[at.id]) * 2 != int(r0[at.id][0]) + int(r0[at.id][1]):
			off_middle += 1
	_ok("the true value is not always the middle of the range (%d of 11 off the middle)" % off_middle, off_middle >= 3)
	mk.look_results(c)
	_ok("looking at results narrows endurance knowledge by 2 and leaves motivating", is_equal_approx(mk.width(c, "endurance_knowledge"), w0.endurance_knowledge - 2.0)
			and is_equal_approx(mk.width(c, "motivating"), w0.motivating))
	mk.ask_around(c)
	_ok("asking around narrows motivating by 3, reveals style and demands, and a teammate writes it in the group thread",
			is_equal_approx(mk.width(c, "motivating"), w0.motivating - 3.0) and mk.knows(c, "style") and mk.knows(c, "demands")
			and game.get_system("moments").thread("group").size() > 0)
	var days: Array = mk.visit_days()
	_ok("a visit can be planned on %d days" % days.size(), days.size() >= 5)
	mk.plan_visit(c, days[0].date)
	var wk = game.current_week()
	var d: int = CAL.weekday(days[0].date)
	var monday_same: bool = CAL.date_key(CAL.monday_of(days[0].date)) == CAL.date_key(wk.monday)
	var far: bool = C.distance_of(c, game.athlete) != "same"
	var expect: Array = [] if far else Array(data.market.scouting.visit.near)
	_ok("the visit day changes: %s" % ("a rest day (travel)" if far else "an easy run with the group"), not monday_same or wk.session_ids(d) == expect)
	var tech_before: float = mk.width(c, "technique")
	var guard := 0
	while not mk.done(c, "visited") and guard < 9:
		_play_days(1)
		guard += 1
	_ok("after the visit day technique is 3 narrower and a line is in the 'Other coaches' thread",
			mk.done(c, "visited") and is_equal_approx(mk.width(c, "technique"), tech_before - 3.0)
			and game.get_system("moments").thread("coaches").size() > 0)
	var nested := true
	for at in data.coaching.attributes:
		var r: Array = mk.range_of(c, at.id)
		nested = nested and int(r[0]) >= int(r0[at.id][0]) and int(r[1]) <= int(r0[at.id][1])
	_ok("every narrower range lies inside the first one", nested)
	# Working together: exact after 8 weeks.
	mk.switch_to(str(c.id), "player")
	var cs = game.get_system("coach")
	cs.relations[str(c.id)].weeks = 4
	var half: float = mk.width(c, "judging_ability")
	cs.relations[str(c.id)].weeks = 8
	var exact := true
	for at in data.coaching.attributes:
		var r: Array = mk.range_of(c, at.id)
		exact = exact and int(r[0]) == int(r[1]) and int(r[0]) == int(c.attributes[at.id])
	_ok("4 weeks together halve a range (%.1f), 8 weeks make every skill exact" % half, exact and half < float(data.market.scouting.width.regional))


# --- 4. Real coaches --------------------------------------------------------------------------------------------------------

func _vis(id: String) -> bool:
	return _mk().visible(_mk().coach(id))


func _real_coaches() -> void:
	print("== 4. Real coaches")
	_career("hkv", 1000)   # Helsinki, 14
	var any_real := false
	for c in _mk().coaches():
		if bool(c.get("real", false)) and _mk().visible(c):
			any_real = true
	_ok("a 14-year-old in Helsinki sees no real coach", not any_real)
	_career("ahkera", 1001)   # Lahti, 14, a member of Lahden Ahkera
	_ok("a 14-year-old of Lahden Ahkera sees the club's real coach (Mikko Rajaniemi, open) in the club list",
			_vis("real_mikko_rajaniemi") and _mk().section(_mk().coach("real_mikko_rajaniemi")) == "club"
			and _mk().can_take(_mk().coach("real_mikko_rajaniemi")))
	_career("hkv", 1002, 2010)   # Helsinki, 16
	_ok("at 16 in Helsinki: the capital-region centre's manager (academy), not the Turku one", _vis("real_diari_sharifi") and not _vis("real_janica_rauma"))
	_ok("at 16: the national real personal coaches are listed (Suhonen, Viskari), not the remote international one or the world level",
			_vis("real_ari_suhonen") and _vis("real_jarmo_viskari") and not _vis("real_thomas_dreissigacker") and not _vis("real_patrick_sang"))
	var a = game.athlete
	a.personal_bests["800m"] = 130.0
	var st: String = _mk().status(_mk().coach("real_ari_suhonen")).id
	_ok("Suhonen (no published fee: about 90 a month, estimated) is over a 35-euro budget: '%s'" % st, st == "budget")
	a.family = "top_parent"
	_ok("with an 80-euro budget Viskari (60) wants a time first: '%s'" % _mk().status(_mk().coach("real_jarmo_viskari")).text,
			_mk().status(_mk().coach("real_jarmo_viskari")).id == "not_yet")
	a.personal_bests["800m"] = 124.0
	_ok("with 2:04.00 (Viskari asks %s) he could coach you" % CAL.format_time(M.required_time(_mk().coach("real_jarmo_viskari"))),
			_mk().can_take(_mk().coach("real_jarmo_viskari")))
	_career("hkv", 1003, 2007)   # 19
	game.athlete.personal_bests["800m"] = 106.0
	var meadows: Dictionary = _mk().coach("real_jenny_meadows")
	_ok("a 19-year-old at 1:46 sees the world-level coaches, who only approach athletes themselves ('%s')" % _mk().status(meadows).text,
			_mk().visible(meadows) and _mk().status(meadows).id in ["approach", "budget"] and not _mk().can_take(meadows))
	# Neutral words and a fictional group.
	_career("ahkera", 1004)
	var mk = _mk()
	var raj: Dictionary = mk.coach("real_mikko_rajaniemi")
	var words_ok := true
	for key in ["yes", "full", "farewell", "welcome", "warn1", "warn2", "end"]:
		words_ok = words_ok and mk.line(raj, key) == str(data.market.lines[key].real).format({"name": game.athlete.first_name,
				"coach": raj.name, "coach_first": "Mikko", "new": "{new}", "old": "{old}", "time": "{time}"})
	_ok("a real coach always uses the neutral 'real' words", words_ok)
	mk.ask(raj)
	mk.start(raj)
	_play_week()
	var g: Array = mk.coach("real_mikko_rajaniemi").group
	var senior: Array = raj.get("athletes_coached", [])
	var fictional := g.size() >= 3 and g.all(func(t): return not senior.any(func(s): return str(s).begins_with("%s %s" % [t.first_name, t.last_name])))
	_ok("a real coach's training group is fictional teammates (%d), none of the senior athletes of the sources" % g.size(), fictional and game.athlete.coach_id == "real_mikko_rajaniemi")


# --- 5. Budget ---------------------------------------------------------------------------------------------------------------

func _budget() -> void:
	print("== 5. The family budget")
	_career("tap", 1100, 2010, 5)   # 'They think sport is a waste of time': 15 a month
	var mk = _mk()
	var paid := 0
	var over := 0
	var club_ok := true
	for c in mk.coaches():
		var co: Dictionary = mk.cost_of(c)
		if str(co.kind) == "paid" or str(co.kind) == "estimate":
			paid += 1
			if int(co.cost) > 15 and mk.status(c).id == "budget":
				over += 1
		if str(c.kind) == "club":
			club_ok = club_ok and mk.fits_budget(c)
	_ok("budget %d: every paid coach (%d) is over it; club fees always fit" % [mk.budget(), paid], mk.budget() == 15 and over == paid and club_ok)
	game.athlete.family = ""
	_ok("an older save (family not known): %d a month" % mk.budget(), mk.budget() == int(data.market.budget.unknown))


# --- 6. Changing coach ------------------------------------------------------------------------------------------------------

func _change_coach() -> void:
	print("== 6. Changing coach end to end, save / load")
	M.enabled = true
	_career("tap", 1200, 2010)
	var mk = _mk()
	var cs = game.get_system("coach")
	var old_id: String = game.athlete.coach_id
	var c := {}
	for x in mk.listing().get("club", []):
		if str(x.id) != old_id:
			c = x
			break
	_ok("another coach of the club (%s) could coach you" % c.get("name", "?"), not c.is_empty() and mk.can_take(c))
	_ok("before asking you can't start", not mk.may_start(c))
	var ans: Dictionary = mk.ask(c)
	_ok("asked: '%s'" % ans.text, ans.ok and mk.may_start(c))
	mk.start(c)
	var ms = game.get_system("moments")
	var farewell: Array = ms.moments.filter(func(m): return str(m.get("ref", "")).begins_with("farewell:"))
	_ok("the old coach's goodbye waits in the coach thread with replies, and the group writes", farewell.size() == 1 and farewell[0].replies.size() == 3
			and ms.thread("group").size() > 0)
	_ok("the change waits for Monday %s" % CAL.format_day(mk.pending.date), mk.pending.coach == str(c.id) and game.athlete.coach_id == old_id)
	ms.answer(str(farewell[0].id), "thanks")
	_ok("thanking the old coach: the relationship ▲ on the result card", farewell[0].get("changes", []).size() == 1)
	_play_week()
	_ok("on Monday the new coach is the head coach", game.athlete.coach_id == str(c.id))
	_ok("a new relation: trust New, fit not known yet, a training group", cs.trust_level() == "new" and cs.relation().weeks == 0
			and cs.head().group.size() >= 3)
	_ok("history: two coaches, the first one closed", mk.history.size() == 2 and not (mk.history[0].to as Dictionary).is_empty())
	var texts: Array = ms.thread("coach").map(func(x): return str(x.text))
	_ok("the coach thread says who is the coach now and the new coach welcomes you",
			texts.any(func(t): return t.begins_with(str(c.name))) and ms.people_for("coach")[0].id == str(c.id))
	_ok("the old coach is listed again as a coach you could ask", mk.visible(cs.coaches[old_id]))
	_play_days(3)
	saves.save("market_check")
	var head_before: String = game.athlete.coach_id
	var hist_before: int = mk.history.size()
	var attrs_before: Dictionary = cs.head().attributes.duplicate()
	saves.load_slot("market_check")
	var mk2 = _mk()
	_ok("save / load keeps the coach, the history and the scouting", game.athlete.coach_id == head_before and mk2.history.size() == hist_before
			and game.get_system("coach").head().attributes == attrs_before and mk2.made)
	# Cancel: a pending change can be called off.
	var other := {}
	for x in mk2.listing().get("club", []):
		if str(x.id) != game.athlete.coach_id:
			other = x
	mk2.ask(other)
	mk2.start(other)
	mk2.cancel_pending()
	_play_week()
	_ok("a cancelled change does not happen", game.athlete.coach_id == head_before)


# --- 7. The ending chain -----------------------------------------------------------------------------------------------------

func _ending() -> void:
	print("== 7. A coach ends it (6 + 4 + 4 weeks Strained)")
	M.enabled = true
	_career("tap", 1300, 2010)
	var cs = game.get_system("coach")
	var mk = _mk()
	var log := []
	var head0: String = game.athlete.coach_id
	cs.relation().weeks = 20
	for w in 16:
		cs.relation().trust = 10.0
		var stops := _week_stops("hear")
		for s in stops:
			log.append("%d:%s" % [w + 1, s])
		if game.athlete.coach_id != head0:
			break
	print("    stops: %s" % [log])
	_ok("warning 1 after 6 Strained weeks, warning 2 after 10, the end after 14", log == ["6:warn:1", "10:warn:2", "14:end"])
	_ok("after the end a new head coach (an own-club coach) and the old one marked as ended",
			game.athlete.coach_id != head0 and mk.ended.has(head0) and mk.status(cs.coaches[head0]).id == "ended")
	# A reset: Strained for 5 weeks, then trust back.
	_career("tap", 1301, 2010)
	cs = game.get_system("coach")
	cs.relation().weeks = 20
	var log2 := []
	for w in 13:
		cs.relation().trust = 10.0 if w < 5 or w >= 7 else 60.0
		for s in _week_stops("hear"):
			log2.append("%d:%s" % [w + 1, s])
	print("    with trust back in weeks 6-7: %s" % [log2])
	_ok("trust back above Strained resets the chain (the first warning comes 6 weeks after it falls again: week 13)", log2 == ["13:warn:1"])
	# Answering 'Let's sort it out' brings trust back.
	_career("tap", 1302, 2010)
	cs = game.get_system("coach")
	cs.relation().weeks = 20
	for w in 6:
		cs.relation().trust = 27.0
		_week_stops("fix")
	_ok("'Let's sort it out' adds trust: no longer Strained (%.1f)" % cs.trust(), cs.trust_level() != "strained")


## Plays a week, answering market stops with `reply`; returns the refs of the market stops.
func _week_stops(reply: String) -> Array:
	var out := []
	var ms = game.get_system("moments")
	var monday = CAL.date_key(game.week_monday())
	var guard := 0
	while guard < 30:
		guard += 1
		if CAL.date_key(game.week_monday()) == monday:
			var r: String = game.advance_day()
			if r == game.RACE:
				var rd = game.race_day
				while not rd.is_done():
					var race = rd.start_round(false, "pack")
					race.run()
					rd.finish_round()
				game.finish_race()
		while not game.pending_event().is_empty():
			var e: Dictionary = game.pending_event()
			var m: Dictionary = ms.moment(str(e.get("moment", "")))
			if str(m.get("kind", "")) == "market":
				out.append(str(m.ref))
				game.answer_event(e.id, reply if str(m.ref).begins_with("warn") else str(e.choices[0].id))
			else:
				game.answer_event(e.id, str(e.choices[0].id) if not e.choices.is_empty() else "ok")
		if CAL.date_key(game.week_monday()) != monday:
			return out
	return out


# --- 8. Coaches offer themselves -----------------------------------------------------------------------------------------------

func _offers() -> void:
	print("== 8. Coaches offer themselves (whenever they see a reason; the switch; detailed messages)")
	M.enabled = true
	var o: Dictionary = data.market.offers
	var cpp: float = float(o.chance_per_point)
	var cmax: float = float(o.chance_max)
	_career("tap", 1400, 2010, 1)   # 16, 'A parent was a top athlete in another sport': 80 a month
	var mk = _mk()
	mk.ensure_pool()
	var a = game.athlete
	a.personal_bests["800m"] = 150.0
	mk.seen_pb = 150.0
	a.personal_bests["800m"] = 123.0
	mk.on_day_end({})
	_ok("a best of 2:03 is remembered by the coaches whose bar it cleared (%d)" % mk.crossed.size(), mk.crossed.size() > 0)
	o.chance_per_point = 100.0
	o.chance_max = 1.0
	var att: Dictionary = o.attention.duplicate()
	for k in o.attention:
		o.attention[k] = 1.0
	mk._weekly_offers()
	var offered: Array = mk.offers.keys()
	_ok("that Sunday one coach writes (%s), never two at once" % [offered.map(func(i): return mk.coach(i).name)], offered.size() == 1)
	if offered.size() == 1:
		var c: Dictionary = mk.coach(offered[0])
		var msgs: Array = game.get_system("moments").thread("coaches")
		var text: String = str(msgs.back().text) if not msgs.is_empty() else ""
		print("    --- the message ---\n" + text.indent("    | ") + "\n    -------------------")
		_ok("the message has the facts (cost, the place kept, the estimate is the coach's own) and the coach has a place for you",
				text.contains(str(data.market.lines.pitch.facts_head)) and text.contains(str(data.market.lines.pitch.estimate_note))
				and mk.status(c).id == "offer" and mk.may_start(c))
		_ok("his estimate for next summer is faster than the best (%s)" % CAL.format_time(float(mk.offers[offered[0]].promise)),
				float(mk.offers[offered[0]].promise) > 0.0 and float(mk.offers[offered[0]].promise) < 123.0)
		_ok("an offer is never accepted by itself: the head coach stays", game.athlete.coach_id != offered[0] and mk.pending.is_empty())
		# The same coach does not write again soon (his offer ran out, no new reason).
		mk.offers[offered[0]].until = SL.day_no(game.date) - 1
		mk.crossed.erase(offered[0])
		mk._weekly_offers()
		_ok("the same coach does not write again within %d days without a new reason" % int(o.again_days), not mk.offer_open(offered[0]))
		# "Not now".
		mk.offers.clear()
		mk.on_reply("offer:" + str(offered[0]), "no")
		_ok("'Not now' keeps that coach quiet for %d days" % int(o.declined_days), not mk.may_offer(c))
	# The switch.
	_career("tap", 1402, 2010, 1)
	mk = _mk()
	mk.ensure_pool()
	game.athlete.personal_bests["800m"] = 150.0
	mk.seen_pb = 150.0
	game.athlete.personal_bests["800m"] = 123.0
	mk.on_day_end({})
	mk.open_offers = false
	mk._weekly_offers()
	_ok("'Open to offers: No' = no coach writes", mk.offers.is_empty())
	mk.open_offers = true
	# A slump and progress, as the coaches see them.
	_career("tap", 1403, 2009, 1)   # 17
	mk = _mk()
	a = game.athlete
	_results(a, [[-400, 140.0, false], [-300, 131.0, true], [-60, 134.5, false], [-30, 135.0, false], [-10, 134.0, false]])
	a.personal_bests["800m"] = 131.0
	_ok("slower races than the best and no best for 300 days = a slump", mk.is_slumping())
	_results(a, [[-400, 140.0, false], [-300, 131.0, true], [-60, 131.5, false], [-30, 132.0, false], [-10, 131.2, false]])
	_ok("races close to the best = no slump", not mk.is_slumping())
	_ok("the best 9 s faster than a year ago = progress (%.1f s)" % mk.progress_s(), mk.progress_s() >= float(o.progress_s))
	_results(a, [[-400, 140.0, false], [-300, 131.0, true], [-60, 134.5, false], [-30, 135.0, false], [-10, 134.0, false]])
	# A good and a poor judge looking at the same slump.
	var base := {}
	for c in mk.coaches():
		if str(c.get("market", {}).get("tier", "")) == "regional":
			base = c
			break
	var good: Dictionary = base.duplicate(true)
	good.id = "judge_good"
	good.attributes.judging_ability = 18
	var poor: Dictionary = base.duplicate(true)
	poor.id = "judge_poor"
	poor.attributes.judging_ability = 4
	var seen_good := 0
	var seen_poor := 0
	var prom_good := []
	var prom_poor := []
	for i in 400:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + i
		if mk.reasons_of(good, rng).has("slump"):
			seen_good += 1
		rng.seed = 9000 + i
		if mk.reasons_of(poor, rng).has("slump"):
			seen_poor += 1
		rng.seed = 7000 + i
		prom_good.append(mk.promise_of(good, rng))
		rng.seed = 7000 + i
		prom_poor.append(mk.promise_of(poor, rng))
	print("    the slump noticed: judging 18 %d of 400, judging 4 %d of 400; estimates' spread %.2f s vs %.2f s" % [seen_good, seen_poor, _sd(prom_good), _sd(prom_poor)])
	_ok("a good judge notices the slump more often than a poor one", seen_good > seen_poor)
	_ok("a poor judge's estimates scatter more widely", _sd(prom_poor) > _sd(prom_good))
	# Short and detailed messages.
	var short: Dictionary = base.duplicate(true)
	short.attributes.communication = 5
	var full: Dictionary = base.duplicate(true)
	full.attributes.communication = 16
	var reasons := {"slump": 2.0, "talent": 1.5}
	var t_short: String = mk.offer_text(short, reasons, 128.0)
	var t_full: String = mk.offer_text(full, reasons, 128.0)
	var intro: String = str(data.market.lines.pitch.plan_intro.get(str(full.voice), ""))
	_ok("a coach of few words writes a short offer, a good communicator explains the plan (%d vs %d characters)" % [t_short.length(), t_full.length()],
			t_full.length() > t_short.length() + 60 and t_full.contains(intro) and not t_short.contains(intro))
	# A real coach never writes about trouble with your coach.
	mk.chain = {"weeks": 10, "stage": 0, "at": 0}
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var real_c: Dictionary = mk.coach("real_jarmo_viskari")
	_ok("a fictional coach may mention trouble with your coach, a real coach never", mk.reasons_of(base, rng2).has("strained")
			and not mk.reasons_of(real_c, rng2).has("strained"))
	mk.chain = {}
	# How many offers a year (the data's chance), week by week without playing, in Tampere (a centre: many coaches).
	o.chance_per_point = cpp
	o.chance_max = cmax
	o.attention = att
	var rows := {"talented and slumping": [17.0, [[-400, 140.0, false], [-300, 131.0, true], [-60, 134.5, false], [-30, 135.0, false], [-10, 134.0, false]]],
			"ordinary, steady": [-1.0, [[-400, 131.5, false], [-300, 131.0, true], [-60, 131.8, false], [-30, 132.2, false], [-10, 131.5, false]]]}
	var counts := {}
	for row in rows:
		counts[row] = []
		for career_seed in [1404, 1405, 1406, 1407]:
			_career("tap", career_seed, 2009, 1)
			mk = _mk()
			mk.ensure_pool()
			a = game.athlete
			var n := 0
			var start: Dictionary = game.date.duplicate()
			for w in 52:
				game.date = game.add_days(start, 7 * w)
				_results(a, rows[row][1])
				a.personal_bests["800m"] = 131.0
				# (ordinary: a talent just above what the best shows)
				a.attributes["potential"] = float(rows[row][0]) if float(rows[row][0]) > 0.0 else M.shown_ability() + 1.0
				var had: Dictionary = mk.offers.duplicate()
				mk._weekly_offers()
				for k in mk.offers:
					if not had.has(k):
						n += 1
			game.date = start
			counts[row].append(n)
		print("    offers in a year, %s 17-year-old in Tampere: %s" % [row, counts[row]])
	_ok("coaches write now and then: a talented slumping athlete gets more offers than an ordinary one, neither every week",
			_sum(counts["talented and slumping"]) > _sum(counts["ordinary, steady"]) and counts["talented and slumping"].all(func(x): return x <= 12))
	# The TF-juniorit standard at 14 opens the regional and national coaches.
	_career("tap", 1401, 2012)
	mk = _mk()
	mk.ensure_pool()
	var shown_before := _total(mk.listing())
	var tf: float = load("res://scripts/core/standards.gd").time("tf_juniorit", game.athlete, int(game.date.year))
	game.athlete.personal_bests["800m"] = tf - 0.5
	mk.on_day_end({})
	_ok("at 14, the TF-juniorit standard (%s) opens the regional and national coaches (%d -> %d listed)" % [CAL.format_time(tf), shown_before, _total(mk.listing())],
			mk.seen_tf and mk.listing().has("national") and _total(mk.listing()) > shown_before)


## Sets the athlete's 800 m results: [[days from today, time, pb], ...].
func _results(a, rows: Array) -> void:
	a.results = []
	for r in rows:
		var d: Dictionary = game.add_days(game.date, int(r[0]))
		a.results.append({"date": d, "meet": "x", "meet_key": "x", "event": "800m", "round": "Final", "place": 3, "field": 8,
				"time": float(r[1]), "pb": bool(r[2])})


func _sum(xs: Array) -> int:
	var s := 0
	for x in xs:
		s += int(x)
	return s


func _sd(xs: Array) -> float:
	var m := 0.0
	for x in xs:
		m += float(x)
	m /= maxf(1.0, xs.size())
	var v := 0.0
	for x in xs:
		v += (float(x) - m) * (float(x) - m)
	return sqrt(v / maxf(1.0, xs.size()))



# --- 9. Distance, the parent -------------------------------------------------------------------------------------------------

func _distance_parent() -> void:
	print("== 9. Distance and the parent coach")
	M.enabled = true
	_career("tap", 1500, 2010)
	var mk = _mk()
	var cs = game.get_system("coach")
	var far := {}
	var region := {}
	for c in mk.coaches():
		var d: String = C.distance_of(c, game.athlete)
		if d == "far" and far.is_empty() and str(c.kind) == "remote":
			far = c
		if d == "region" and region.is_empty():
			region = c
	mk.switch_to(str(far.id), "player")
	var pen: Dictionary = data.market.distance.far.penalty
	_ok("a remote coach: technique %d -> %d, load management -%d, endurance knowledge unchanged" % [int(far.attributes.technique), int(cs.attr("technique")), int(pen.load_management)],
			is_equal_approx(cs.attr("technique"), maxf(1.0, float(far.attributes.technique) - float(pen.technique)))
			and is_equal_approx(cs.attr("endurance_knowledge"), float(far.attributes.endurance_knowledge)))
	var local: float = cs.race_accuracy({"level": "local", "key": "x", "date": game.date})
	var national: float = cs.race_accuracy({"level": "national", "key": "x", "date": game.date})
	_ok("race advice is weaker at a meet the remote coach skips (%.3f) than at a national meet (%.3f)" % [local, national], local < national)
	if not region.is_empty():
		mk.switch_to(str(region.id), "player")
		_ok("a coach of the region: half the penalty (technique -%d)" % int(data.market.distance.region.penalty.technique),
				is_equal_approx(cs.attr("technique"), maxf(1.0, float(region.attributes.technique) - float(data.market.distance.region.penalty.technique))))
	# The parent.
	_career("tap", 1501, 2012, 0)   # 'A parent competed in athletics'
	mk = _mk()
	var parent := {}
	for c in mk.coaches():
		if str(c.kind) == "parent":
			parent = c
	_ok("a parent who competed in athletics is in the pool, at home, free, with the athlete's last name",
			not parent.is_empty() and mk.visible(parent) and mk.section(parent) == "parent" and mk.cost_of(parent).kind == "free"
			and str(parent.name).ends_with(game.athlete.last_name))
	_ok("the parent fits better (+%.1f)" % float(data.coaching.fit.kind_bonus.parent),
			C.fit_score(game.athlete.temperament, parent) == C.fit_score(game.athlete.temperament, _without_kind(parent)) + float(data.coaching.fit.kind_bonus.parent))
	mk.switch_to(str(parent.id), "player")
	MS.neutral = false
	var mind = game.get_system("mind")
	var pulls: Array = mind.pulls("stress")
	MS.neutral = true
	_ok("a parent as coach pulls stress up a little (family friction)", pulls.any(func(p): return is_equal_approx(float(p.delta), float(data.mind.drift.stress.parent_coach))))
	_career("tap", 1502, 2012, 3)
	_ok("no parent coach without that family answer", _mk().coaches().all(func(c): return str(c.kind) != "parent"))


func _without_kind(c: Dictionary) -> Dictionary:
	var d := c.duplicate(true)
	d.kind = "club"
	return d


# --- 10. Neutral -----------------------------------------------------------------------------------------------------------------

func _neutral() -> void:
	print("== 10. The market off or untouched changes nothing")
	C.neutral_club = true
	M.enabled = false
	_career("tap", 1600)
	_play_days(42)
	var off := _fingerprint()
	M.enabled = true
	_career("tap", 1600)
	_mk().ensure_pool()
	_play_days(42)
	var on := _fingerprint()
	C.neutral_club = false
	print("    off %s / on %s" % [off, on])
	_ok("six weeks with the market off and with it on (pool made, nothing chosen) are the same bit for bit", off == on)


func _fingerprint() -> String:
	var s := 0.0
	for k in game.athlete.attributes:
		s += float(game.athlete.attributes[k])
	return "%.9f / %.9f" % [s, game.athlete.fatigue]
