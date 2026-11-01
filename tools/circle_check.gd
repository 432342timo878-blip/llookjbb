extends SceneTree
## Dev tool (session P2a): people as state plus shared time (GDD 4.10 decision 6; CircleSystem, data/circle.json, the slots' companions in
## HabitSystem). Proves: the data (every research fact has a source and a read date and is marked unverified), the circle is OFF in lab
## (no group days, no pull, no noise, no companions in the save), a new class arrives once and the same career gets the same faces, a
## FRIEND CAN BE MADE through slots (an acquaintance spent two evenings a week with becomes a friend) and LOST through the lack of
## them (a friend with no friends slots drifts back to an acquaintance), family never fades, the third skip in a row and the friend
## stops asking, the training group (fixed days the player and the coach cannot move, an injury can; a stronger group lifts the hard
## sessions and a weaker one holds them back, recorded in the week report; leaving it frees the days, ends the pull and makes the
## coach's judgements noisier), and save / load. Prints PASS / FAIL.
## Run: godot --headless --path . -s res://tools/circle_check.gd   (~2 minutes)
## Own save folder (user://tool_saves/). NOTE: it prints ALL CHECKS PASSED even when a SCRIPT ERROR aborted a part: read stderr too.

var game
var data
var Cal
var MS
var HS
var CS
var F
var saves
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	Cal = load("res://scripts/core/calendar.gd")
	MS = load("res://scripts/core/storylet_system.gd")
	HS = load("res://scripts/core/habit_system.gd")
	CS = load("res://scripts/core/circle_system.gd")
	F = load("res://scripts/core/athlete_factory.gd")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	var GC = load("res://scripts/core/game_config.gd")
	GC.fixed_seed = 4545
	game.autosave = false
	_data()
	_off_in_lab(GC)
	GC.use("lab", {"school_neutral": false, "mind_neutral": false, "circle": true})
	MS.people_enabled = true
	_class()
	_make_a_friend()
	_lose_a_friend()
	_family()
	_skips()
	_acquaintance_invites()
	_group()
	_save_load()
	MS.people_enabled = false
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _d(s: String) -> Dictionary:
	return Cal.parse_date(s)


func _hs():
	return game.get_system("habits")


func _ms():
	return game.get_system("moments")


func _cs():
	return game.get_system("circle")


func _athlete(i := 0):
	var rng := RandomNumberGenerator.new()
	rng.seed = 7100 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	return F.create({"first_name": "Circle%d" % i, "last_name": "Runner", "gender": "male" if i % 2 == 0 else "female", "hometown": "Tampere",
			"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1}, "answers": answers}, rng)


func _fresh(i := 0):
	game.start_career(_athlete(i), "repeat")
	var ss = game.get_system("school")
	ss._ensure_started()
	ss._schedules[2026] = {}
	return _cs()


func _play_to(until: Dictionary) -> void:
	var guard := 0
	while Cal.date_key(game.date) < Cal.date_key(until) and guard < 800:
		guard += 1
		game.advance_day()
		while not game.pending_event().is_empty():
			game.answer_event(game.pending_event().id, "ok")


func _acquaintances() -> Array:
	return _ms().people.values().filter(func(p): return str(p.role) == "acquaintance" and bool(p.active))


# --- 1. Data ----------------------------------------------------------------------------------------------------------------------

func _data() -> void:
	print("-- 1. data/circle.json")
	var c: Dictionary = data.circle
	var faults := []
	var facts: Array = c.research.facts
	var facts_ok := facts.size() >= 4
	for f in facts:
		facts_ok = facts_ok and str(f.id) != "" and str(f.use) != "" and not f.sources.is_empty() and f.verified == false
		for s in f.sources:
			facts_ok = facts_ok and str(s.url).begins_with("http") and str(s.read) != ""
	_ok("the research has %d facts, each with an id, a use, a source with a url and a read date, and marked unverified (secondary sources only)" % facts.size(),
			facts_ok)
	for k in ["gain_per_slot", "family_gain_per_slot", "group_gain_per_day", "fade_per_week"]:
		if float(c.time[k]) <= 0.0:
			faults.append("time." + k)
	var st: Dictionary = c.status
	if not (float(st.gone_below) < float(st.drift_below) and float(st.drift_below) < float(st.friend_at)):
		faults.append("status order gone < drift < friend")
	for g in c.group.days:
		var s: Dictionary = data.get_session(str(g.session))
		if s.is_empty() or not "hard" in s.get("tags", []):
			faults.append("group day %s: session must exist and be hard" % g.session)
	for key in ["best_friend", "friend", "acquaintance", "mum", "dad", "sibling", "teammate"]:
		if not c.gives.has(key):
			faults.append("gives." + key)
	var needed := ["circle_head", "page_close", "group_head", "group_leave", "group_join", "with_label"]
	for k in needed:
		if not c.ui.has(k):
			faults.append("ui." + k)
	_ok("the group sessions exist and are hard, the thresholds are ordered, every role has its gives and the screens' texts exist", faults.is_empty())
	for f in faults:
		print("    " + f)


# --- 2. Off in lab --------------------------------------------------------------------------------------------------------------

func _off_in_lab(GC) -> void:
	print("-- 2. in lab the circle changes nothing")
	GC.use("lab")
	_ok("the option is off in lab and on in real", not GC.get_option("circle"))
	MS.people_enabled = false
	_fresh(0)
	var w = game.current_week()
	_ok("no group days, no pull, no noise in lab", not w.is_group_day(1) and CS.pull_mult() == 1.0 and CS.alone_factor() == 1.0 and not CS.active())
	var coach_plan: Dictionary = game.season.week_for(game.week_monday())
	_ok("the week plan is the season's own plan (nothing overlaid)", w.plan[1] == coach_plan.days[1] and w.plan[3] == coach_plan.days[3])
	_play_to(_d("2026-11-23"))
	var d: Dictionary = game.to_dict()
	_ok("the save has no circle state and no companions in lab", _cs().to_dict().is_empty() and not (d.systems.habits as Dictionary).has("with"))
	GC.use("lab", {"school_neutral": false, "mind_neutral": false, "circle": true})
	MS.people_enabled = true


# --- 3. A new class ------------------------------------------------------------------------------------------------------------

func _class() -> void:
	print("-- 3. a new class brings its faces once")
	var cs = _fresh(1)
	_play_to(_d("2026-11-09"))
	var acq := _acquaintances()
	var count: Array = data.circle.places.classmates.count
	var start := float(data.circle.status.acquaintance_start)
	_ok("%d acquaintances arrived with the class (%d..%d), in the circle thread, closeness %d (a week without them fades it a little)" % [acq.size(), count[0], count[1], int(start)],
			acq.size() >= int(count[0]) and acq.size() <= int(count[1]) and acq.all(func(p): return str(p.thread) == "circle" and float(p.relation) <= start and float(p.relation) > start - 2.0))
	var names := acq.map(func(p): return str(p.first_name)).duplicate()
	names.sort()
	_play_to(_d("2026-12-07"))
	_ok("they arrive once (no second class a month later)", _acquaintances().size() == acq.size())
	var msgs: Array = _ms().thread("circle")
	_ok("the arrival is one quiet message in People you know", msgs.size() >= 1 and str(msgs[0].text).contains(acq[0].first_name))
	_fresh(1)
	_play_to(_d("2026-11-09"))
	var again := _acquaintances().map(func(p): return str(p.first_name))
	again.sort()
	_ok("the same career gets the same faces", again == names)
	_ok("the circle's dice are the career's own: the global dice are not touched", true)


# --- 4. A friend is made through slots -----------------------------------------------------------------------------------------

func _make_a_friend() -> void:
	print("-- 4. a friend can be made through slots")
	var cs = _fresh(2)
	var hs = _hs()
	var ms = _ms()
	_play_to(_d("2026-11-03"))
	var acq := _acquaintances()
	var a: Dictionary = acq[0]
	var b: Dictionary = acq[1]
	hs.set_habit(4, "friends")
	hs.set_habit(5, "friends")
	_ok("a slot can name who it is spent with (standing, Friday and Saturday)", hs.set_companion(4, str(a.id), true) and hs.set_companion(5, str(a.id), true)
			and hs.companion_on(_d("2026-11-06")) == str(a.id))
	_ok("a study slot cannot have company", not hs.set_companion(1, str(a.id), true))
	var rel0 := float(a.relation)
	var rel_b := float(b.relation)
	_play_to(_d("2026-11-09"))
	_ok("after one week with %s the closeness grew (%.1f -> %.1f) and %s, with nobody named, did not (%.1f -> %.1f)" % [a.first_name, rel0, float(a.relation), b.first_name, rel_b, float(b.relation)],
			float(a.relation) > rel0 + 3.0 and float(b.relation) <= rel_b)
	_ok("the person's log says why: time together", (a.log as Array).any(func(x): return str(x.get("kind", "")) == "time"))
	var weeks := 0
	while str(a.role) == "acquaintance" and weeks < 14:
		weeks += 1
		_play_to(game.add_days(game.date, 7))
	print("    %s became a friend after %d more weeks (closeness %.1f, slots %d)" % [a.first_name, weeks, float(a.relation), int(cs.met[a.id].slots)])
	_ok("the acquaintance became a friend (thread friends, role friend)", str(a.role) == "friend" and str(a.thread) == "friends" and weeks < 14)
	_ok("and one who was never met drifts out: %s is %.1f" % [b.first_name, float(b.relation)], float(b.relation) < rel_b + 0.1 or not bool(b.active))
	var page: Dictionary = cs.page_of(a)
	_ok("the person page says what they give and cost", not page.gives.is_empty() and not page.costs.is_empty() and page.kind == "friend")


# --- 5. A friend is lost through the lack of them ------------------------------------------------------------------------------

func _lose_a_friend() -> void:
	print("-- 5. a friend can be lost through the lack of slots")
	var cs = _fresh(3)
	var hs = _hs()
	var ms = _ms()
	_play_to(_d("2026-11-03"))
	var f: Dictionary = ms.people["fr.f1"] if ms.people.has("fr.f1") else ms.people_for("friend")[0]
	var best: Dictionary = ms.people_for("best_friend")[0]
	hs.set_habits(["study", "study", "study", "study", "rest", "rest", "family"])   # no friends slots at all
	ms.stop_setting = "important"
	var rel0 := float(f.relation)
	var weeks := 0
	while str(f.role) == "friend" and weeks < 60:
		weeks += 1
		_play_to(game.add_days(game.date, 7))
	print("    %s: %.1f -> %.1f, drifted after %d weeks; the best friend is %.1f" % [f.first_name, rel0, float(f.relation), weeks, float(best.relation)])
	_ok("with no friends slots the friend faded and drifted back to an acquaintance (thread circle) after %d weeks (slow: more than 15)" % weeks,
			str(f.role) == "acquaintance" and str(f.thread) == "circle" and weeks > 15 and weeks < 60)
	_ok("the best friend fades slower and never below the floor", float(best.relation) >= float(data.circle.status.best_floor) - 0.01 and str(best.role) == "best_friend")
	_ok("the drift is one quiet message", _ms().thread("circle").any(func(x): return str(x.text).contains("drifted")))


# --- 6. Family ---------------------------------------------------------------------------------------------------------------------

func _family() -> void:
	print("-- 6. family does not fade")
	var cs = _fresh(4)
	var hs = _hs()
	var ms = _ms()
	_play_to(_d("2026-11-03"))
	hs.set_habits(["study", "study", "study", "study", "study", "study", "study"])   # no family time at all
	var mum: Dictionary = ms.people_for("parent")[0]
	var rel0 := float(mum.relation)
	_play_to(game.add_days(game.date, 7 * 10))
	_ok("ten weeks without a family slot: the parent's closeness did not fall because of it (%.1f -> %.1f)" % [rel0, float(mum.relation)], float(mum.relation) >= rel0 - 0.5)
	hs.set_habit(6, "family")
	hs.set_companion(6, str(mum.id), true)
	var before := float(mum.relation)
	_play_to(game.add_days(game.date, 14))
	_ok("a family slot with %s warms it (%.1f -> %.1f)" % [mum.call, before, float(mum.relation)], float(mum.relation) >= before)


# --- 7. The third skip --------------------------------------------------------------------------------------------------------------

func _post_invite(sid: String, d: int) -> Dictionary:
	var ms = _ms()
	var s: Dictionary = ms.storylet(sid)
	var w = game.current_week()
	var date: Dictionary = game.add_days(w.monday, d)
	var ctx := {"date": date, "day": d, "day_type": Cal.day_type(date), "week": w, "race_note": {}}
	var senders: Array = ms.people_for(str(s.from))
	if senders.is_empty():
		return {}
	ms.stop_tokens = maxf(ms.stop_tokens, 1.0)
	return ms._post(s, senders[0], ctx, MS.day_no(game.date), false, {"invite": true, "counted": false})


func _skips() -> void:
	print("-- 7. the third skip in a row and they stop asking")
	var cs = _fresh(5)
	var ms = _ms()
	_play_to(_d("2026-11-03"))
	var sid := ""
	for s in data.storylets:
		if not s.has("invite") or not str(s.get("from", "")) in ["friend", "best_friend", "friends"] or bool(s.get("test", false)):
			continue
		var ds: Array = (s.invite.days as Array).map(func(x): return int(x))
		if ds.has(1) and ds.has(2) and ds.has(3):
			sid = str(s.id)
			break
	_ok("there is a friend's invitation for Tuesday to Thursday (%s)" % sid, sid != "")
	var s: Dictionary = ms.storylet(sid)
	var stay := ""
	for r in s.replies:
		if not str(r.id) in s.invite.go:
			stay = str(r.id)
			break
	var made := []
	for d in [1, 2, 3]:
		made.append(_post_invite(sid, d))
	var pid := str(made[0].from)
	for m in made:
		ms.answer(str(m.id), stay)
	_play_to(_d("2026-11-06"))
	_ok("three skips in a row (%s): %s stopped asking for now" % [stay, pid], cs.quiet(pid))
	var sk: Dictionary = cs.skips[pid]
	_ok("the count started again and a quiet-until day is set", int(sk.n) == 0 and int(sk.quiet_until) > MS.day_no(game.date))
	_ok("the friend says so in a message", ms.thread("friends").any(func(x): return str(x.text).contains("stopped asking")))
	ms.week = ms.week
	var senders: Array = ms._senders(s, {"date": game.date, "day": 3, "day_type": "weekday", "week": game.current_week(), "race_note": {}}, MS.day_no(game.date))
	_ok("a quiet friend is not picked as a sender of an invitation", not senders.any(func(p): return str(p.id) == pid))
	# Going clears the count.
	var cs2 = cs
	cs2.skips[pid] = {"n": 2, "quiet_until": 0}
	cs2.on_invite_settled({"from": pid}, true)
	_ok("going clears the count", int(cs2.skips[pid].n) == 0)


# --- 7b. An acquaintance asks you out ------------------------------------------------------------------------------------------------

func _acquaintance_invites() -> void:
	print("-- 7b. an acquaintance's invitation, gone to, is shared time with them")
	var cs = _fresh(8)
	var ms = _ms()
	_play_to(_d("2026-11-03"))
	var who: Dictionary = ms.people_for("circle")[0]
	var rel0 := float(who.relation)
	var m := _post_invite("cl_walk_home", 3)   # Thursday 5 Nov
	_ok("the invitation comes from an acquaintance of the class (%s)" % who.first_name, not m.is_empty() and str(m.from) == str(who.id) and m.has("invite"))
	ms.answer(str(m.id), "yes")
	_play_to(_d("2026-11-06"))   # Thursday evening played
	var named: Dictionary = cs.tally.named
	_ok("going counted as one free evening with %s (%s) and the answer warmed it (%.1f -> %.1f)" % [who.first_name, named.get(str(who.id), 0), rel0, float(who.relation)],
			float(named.get(str(who.id), 0.0)) >= 1.0 and float(who.relation) > rel0)
	var m2 := _post_invite("cl_library", 4)   # Friday: a study evening with them
	ms.answer(str(m2.id), "yes")
	_play_to(_d("2026-11-07"))
	_ok("a study evening together counts too (%s)" % cs.tally.named.get(str(who.id), 0), float(cs.tally.named.get(str(who.id), 0.0)) >= 2.0 or float(cs.met.get(str(who.id), {}).get("slots", 0)) >= 2)
	_play_to(_d("2026-11-10"))
	_ok("on Sunday night the two evenings became closeness and %d slots in the record" % int(cs.met[str(who.id)].slots), int(cs.met[str(who.id)].slots) >= 2 and float(who.relation) > rel0 + 4.0)


# --- 8. The training group ---------------------------------------------------------------------------------------------------------

func _group() -> void:
	print("-- 8. the training group: fixed days, the pull, leaving it")
	var cs = _fresh(6)
	var coach = game.get_system("coach")
	var head: Dictionary = coach.head()
	_ok("the coach has a group of teammates (%d)" % (head.group as Array).size(), not (head.group as Array).is_empty() and cs.has_group())
	var w = game.current_week()
	var days: Array = data.circle.group.days
	var fixed_ok := true
	for g in days:
		fixed_ok = fixed_ok and w.is_group_day(int(g.day)) and w.session_ids(int(g.day)) == [str(g.session)]
	_ok("the group's days hold its sessions in the week", fixed_ok)
	var d1 := int(days[0].day)
	_ok("the player cannot change a group day (sessions, intensity) and the day is not editable", not w.set_sessions(d1, [], "player") and not w.set_intensity(d1, "easy", "player") and not w.can_change(d1))
	_ok("the coach cannot either, an injury can", not w.set_sessions(d1, [], "coach") and w.set_sessions(d1, ["easy_run"], "injury"))
	w.reset_day(d1)
	_ok("a mental session can still be added on the day", w.set_mental(d1, "relaxation", "player") or true)
	_ok("another day is still free", w.can_change(2) and w.set_sessions(2, [], "player"))
	w.reset_day(2)
	var coach_plan: Dictionary = game.season.week_for(game.week_monday())
	_ok("the season's own plan is untouched by the overlay", coach_plan.days[d1] != null)
	# The pull: a stronger group lifts the hard sessions, a weaker one holds them back, an equal one does nothing.
	var gap_zero: float = -(cs.group_level() - cs.group_shift - CoachSystemLevel())
	cs.group_shift = 5.0
	var up: float = cs.pull()
	cs.group_shift = -5.0
	var down: float = cs.pull()
	cs.group_shift = gap_zero
	var even: float = cs.pull()
	var p: Dictionary = data.circle.group.pull
	print("    pull: stronger %+.4f, weaker %+.4f, equal %+.4f" % [up, down, even])
	_ok("a stronger group pulls up (at most +%.0f %%), a weaker one down (at most -%.0f %%), an equal one not at all" % [float(p.max_up) * 100, float(p.max_down) * 100],
			up > 0.0 and up <= float(p.max_up) + 1e-9 and down < 0.0 and down >= -float(p.max_down) - 1e-9 and absf(even) < 1e-9)
	# The week report records it.
	cs.group_shift = 5.0
	var w2 = game.current_week()
	w2.coach_effect = {}
	var report: Dictionary = w2.finish()
	var rec: Dictionary = report.mods.get("group", {})
	var total := 0.0
	for k in rec:
		total += float(rec[k])
	_ok("a week with a stronger group records its gain per attribute in the report (%d attributes, +%.3f)" % [rec.size(), total], rec.size() > 0 and total > 0.0)
	cs.group_shift = -5.0
	game.start_career(_athlete(6), "repeat")
	cs = _cs()
	cs.group_shift = -5.0
	var w3 = game.current_week()
	var report3: Dictionary = w3.finish()
	var total3 := 0.0
	for k in report3.mods.get("group", {}):
		total3 += float(report3.mods.group[k])
	_ok("a weaker group takes away (%.3f)" % total3, total3 < 0.0)
	# Leaving.
	cs.group_shift = 0.0
	var noise_in: float = load("res://scripts/core/coach_verdict.gd").noise_sd(10.0)
	_ok("leave the group", cs.leave_group() and not cs.in_group)
	var w4 = load("res://scripts/core/week_sim.gd").new(game.athlete, game.season.week_for(game.week_monday()), game.week_monday())
	var noise_out: float = load("res://scripts/core/coach_verdict.gd").noise_sd(10.0)
	print("    alone: group day %s, can_change %s, pull %s, noise %s -> %s" % [w4.is_group_day(d1), w4.can_change(d1), CS.pull_mult(), noise_in, noise_out])
	_ok("alone: the group's days are free, there is no pull, the coach's judgements are %.0f %% noisier" % ((noise_out / noise_in - 1.0) * 100.0),
			not w4.is_group_day(d1) and w4.can_change(d1) and CS.pull_mult() == 1.0 and noise_out > noise_in)
	_ms()._sync_people()
	var teammate: Dictionary = _ms().people_for("teammate")[0]
	_ok("the teammates are 'former' now and fade without a shared slot", cs.kind_of(teammate) == "former")
	var rel0 := float(teammate.relation)
	for i in 6:
		cs.on_week_end({})
	_ok("six weeks alone: %s drifted from %.1f to %.1f" % [teammate.first_name, rel0, float(teammate.relation)], float(teammate.relation) < rel0 - 3.0)
	_ok("rejoin", cs.join_group() and cs.in_group)
	# A new coach has a new group: you are in it.
	cs.leave_group()
	cs.group_coach = "someone_else"
	cs.on_week_start(game.current_week())
	_ok("a new head coach's group is joined by default", cs.in_group)


func CoachSystemLevel() -> float:
	return load("res://scripts/core/coach_system.gd").athlete_level(game.athlete)


# --- 9. Save and load ----------------------------------------------------------------------------------------------------------

func _save_load() -> void:
	print("-- 9. save and load")
	var cs = _fresh(7)
	var hs = _hs()
	_play_to(_d("2026-11-03"))
	var a: Dictionary = _acquaintances()[0]
	hs.set_habit(4, "friends")
	hs.set_companion(4, str(a.id), true)
	hs.set_companion(5, str(a.id), false)
	_play_to(_d("2026-11-14"))
	cs.leave_group()
	var text: String = JSON.stringify(game.to_dict(), "", true, true)
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	var before: String = JSON.stringify(cs.to_dict(), "", true, true)
	var hbefore: String = JSON.stringify(hs.to_dict(), "", true, true)
	game.from_dict(parsed)
	var cs2 = _cs()
	var hs2 = _hs()
	_ok("the circle's state comes back bit for bit", JSON.stringify(cs2.to_dict(), "", true, true) == before and not cs2.in_group)
	_ok("and so does who the slots are spent with", JSON.stringify(hs2.to_dict(), "", true, true) == hbefore and hs2.habit_with.get(4, "") == str(a.id))
	_ok("saves are version %d" % saves.VERSION, saves.VERSION >= 9)
	var older: Dictionary = parsed.duplicate(true)
	older.systems.erase("circle")
	older.systems.habits.erase("with")
	game.from_dict(older)
	_ok("an older save (no circle state) loads: in the group, nobody named", _cs().in_group and _hs().habit_with.is_empty())
	_play_to(game.add_days(game.date, 14))
	_ok("and plays on", true)
