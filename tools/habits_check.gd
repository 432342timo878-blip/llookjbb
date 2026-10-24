extends SceneTree
## Dev tool (session L1b): the free-time slots and the standing habits (GDD 4.10 decision 6; HabitSystem, data/habits.json) and the
## invitations (storylets with an `invite` part, StoryletSystem): the data, the default habit = the old Normal / Normal (no effect at
## all), what each activity does, this week's changes, played days ("last night" on Monday), save / load and a version-4 save, the
## report card's choice, the invitations (they land in a slot of the week, are answered on the planner, happen on their evening;
## unanswered = you didn't go; a rule answers them; the clash marks), and a season with the people on: every invitation lands in a
## slot still to come, at most one a week, and every one is settled on its evening. Prints PASS / FAIL.
## Run: godot --headless --path . -s res://tools/habits_check.gd [-- weeks for the season part, default 26]   (~1 minute)
## Own save folder (user://tool_saves/). NOTE: it prints ALL CHECKS PASSED even when a SCRIPT ERROR aborted a part: read stderr too.

var game
var data
var Cal
var MS
var HS
var SC
var F
var saves
var HUI
var WPL
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	Cal = load("res://scripts/core/calendar.gd")
	MS = load("res://scripts/core/storylet_system.gd")
	HS = load("res://scripts/core/habit_system.gd")
	SC = load("res://scripts/core/school_system.gd")
	F = load("res://scripts/core/athlete_factory.gd")
	HUI = load("res://scripts/ui/habits_ui.gd")
	WPL = load("res://scripts/ui/week_planner.gd")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	var GC = load("res://scripts/core/game_config.gd")
	# Lab with the school and the moods free (the slots' effects follow the school's switches); the parts switch the people on.
	GC.use("lab", {"school_neutral": false, "mind_neutral": false})
	GC.fixed_seed = 4343
	game.autosave = false
	var weeks := 26
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			weeks = arg.to_int()
	_data()
	_neutral()
	_effects()
	_week_changes()
	_played_history()
	_save_load()
	_card()
	_invites()
	_season(weeks)
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


func _athlete(i := 0):
	var rng := RandomNumberGenerator.new()
	rng.seed = 6100 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0 if i == 0 else rng.randi_range(0, q.answers.size() - 1)
	var gender := "male" if i % 2 == 0 else "female"
	return F.create({"first_name": "Slot%d" % i, "last_name": "Runner", "gender": gender, "hometown": "Tampere", "club_id": "tap",
			"main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1}, "answers": answers}, rng)


## A fresh career on its first Monday (2 Nov 2026), the coach's repeating week, no tests (so school days are plain).
func _fresh(i := 0):
	game.start_career(_athlete(i), "repeat")
	var ss = game.get_system("school")
	ss._ensure_started()
	ss._schedules[2026] = {}
	return _hs()


## Plays days up to (not including) `until`, answering every stop "ok" (planner cards are left open).
func _play_to(until: Dictionary) -> void:
	var guard := 0
	while Cal.date_key(game.date) < Cal.date_key(until) and guard < 400:
		guard += 1
		game.advance_day()
		while not game.pending_event().is_empty():
			game.answer_event(game.pending_event().id, "ok")


## A save's text read back with its decimals exact (SaveGame.load_slot does the same).
func _parse(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	return parsed


func _json(v: Variant) -> String:
	var text := JSON.stringify(v, "", true, true)
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	return JSON.stringify(parsed, "", true, true)


# --- 1. Data ---------------------------------------------------------------------------------------------------------------------

func _data() -> void:
	print("-- 1. data/habits.json and the invitations' storylets")
	var h: Dictionary = data.habits
	var acts: Array = HS.ACTIVITIES
	var faults := []
	if (h.slots as Array).size() != 7 or (h.slots as Array).filter(func(s): return s.kind == "evening").size() != 5:
		faults.append("slots: 7 with 5 evenings")
	for a in acts:
		var def: Dictionary = h.activities.get(a, {})
		if str(def.get("name", "")) == "" or str(def.get("does", "")) == "" or not ResourceLoader.exists("res://assets/icons/%s.svg" % def.get("icon", "?")):
			faults.append("activity %s: name / does / icon" % a)
	for k in h.from_old:
		if k == "_note":
			continue
		var list: Array = h.from_old[k]
		if list.size() != 7 or list.any(func(x): return not x in acts):
			faults.append("from_old %s" % k)
	if (h.from_old.keys() as Array).filter(func(k): return k != "_note").size() != 9:
		faults.append("from_old: 9 combinations")
	for f in faults:
		print("    " + f)
	_ok("7 slots (5 evenings + Saturday + Sunday), 4 activities with a name, what they do and an icon, 9 old combinations (%d faults)" % faults.size(), faults.is_empty())
	var c: Dictionary = HS.counts(h.default)
	_ok("the default habit = Mon-Thu study, Fri + Sat friends, Sun family = the neutral counts", h.default == ["study", "study", "study", "study", "friends", "friends", "family"]
			and int(c.study) == int(h.neutral.study) and int(c.friends) == int(h.neutral.friends) and int(c.family) == int(h.neutral.family)
			and h.from_old["normal|normal"] == h.default)
	var invites: Array = data.storylets.filter(func(s): return s.has("invite"))
	var bad := []
	for s in invites:
		var iv: Dictionary = s.invite
		var ids: Array = s.replies.map(func(r): return str(r.id))
		if (iv.get("days", []) as Array).is_empty() or (iv.days as Array).any(func(d): return int(d) < 0 or int(d) > 6):
			bad.append("%s: days" % s.id)
		if not str(iv.get("activity", "")) in acts:
			bad.append("%s: activity" % s.id)
		if (iv.get("go", []) as Array).is_empty() or (iv.go as Array).any(func(g): return not str(g) in ids) or ids.all(func(x): return x in iv.go):
			bad.append("%s: go replies (and one to stay home)" % s.id)
		if str(iv.get("title", "")) == "" or str(iv.get("chip", "")) == "":
			bad.append("%s: title / chip" % s.id)
		for t in s.text:
			if MS._variant_text(t).to_lower().contains("tonight"):
				bad.append("%s: 'tonight' in a text posted days before" % s.id)
	for b in bad:
		print("    " + b)
	_ok("%d invitations (the weekend party, the party before a race, the group work), each with slot days, an activity, Go replies + a stay-home reply, a title and a chip, no 'tonight' (%d faults)" % [invites.size(), bad.size()],
			invites.size() >= 3 and bad.is_empty() and ["fr_party_weekend", "fr_party_race", "sch_group_work"].all(func(x): return invites.any(func(s): return s.id == x)))


# --- 2. The default habit is the old Normal / Normal --------------------------------------------------------------------------

func _neutral() -> void:
	print("-- 2. the default habit adds nothing")
	var hs = _fresh()
	var ss = game.get_system("school")
	var zero := true
	for i in 42:
		var d: Dictionary = game.add_days(_d("2026-11-02"), i)
		zero = zero and hs.load_parts(d, 1.0).is_empty() and hs.grade_shift(d) == 0.0
	var mon := _d("2026-11-09")
	_ok("6 weeks of school (2 Nov - 13 Dec): no slot part on any day, no grade shift", zero)
	_ok("no motivation or stress pull, the old words Normal / Normal, the summary 'Grades hold · motivation steady · school days normal'",
			hs.motivation_pulls(mon).is_empty() and hs.stress_pulls(mon).is_empty() and ss.effort_word() == "normal" and ss.free_word() == "normal"
			and hs.summary() == "Grades hold · motivation steady · school days normal")
	SC.neutral = true
	hs.set_habits(["friends", "friends", "friends", "friends", "friends", "friends", "friends"])
	_ok("the school neutral (lab): every slot with friends still adds no load and no pull (the grade shift follows the study slots, as the old effort did)",
			hs.load_parts(mon, 1.0).is_empty() and hs.motivation_pulls(mon).is_empty() and hs.grade_shift(mon) == -1.0)
	SC.neutral = false


# --- 3. What each activity does -------------------------------------------------------------------------------------------------

func _effects() -> void:
	print("-- 3. what the slots do (data/habits.json effects)")
	var hs = _fresh()
	var mon := _d("2026-11-09")
	var shifts := []
	for n in [0, 2, 3, 4, 5, 6, 7]:
		shifts.append(HS.shift_for(n))
	_ok("the grade shift by study slots 0/2/3/4/5/6/7: -1, -1, -0.5, 0, +0.5, +1, +1 (capped like the old Light / Heavy) %s" % [shifts],
			shifts == [-1.0, -1.0, -0.5, 0.0, 0.5, 1.0, 1.0])
	hs.set_habits(["study", "study", "study", "study", "study", "study", "study"])
	var p: Array = hs.load_parts(mon, 1.0)
	_ok("study in every slot: a school day +1.5 'extra study' (3 over 4 x 0.5); x1.1 in grade 9", p.size() == 1 and p[0].id == "slot_study"
			and float(p[0].value) == 1.5 and is_equal_approx(float(hs.load_parts(mon, 1.1)[0].value), 1.65))
	hs.set_habits(["study", "rest", "study", "study", "friends", "friends", "friends"])
	var monday: Array = hs.load_parts(mon, 1.0)
	var wed: Array = hs.load_parts(_d("2026-11-11"), 1.0)
	var tue: Array = hs.load_parts(_d("2026-11-10"), 1.0)
	_ok("a school day after a friends evening (Sunday) +0.75, after a rest evening (Tuesday) -0.5, after a study evening nothing",
			monday.size() == 1 and monday[0].id == "slot_friends" and float(monday[0].value) == 0.75
			and wed.size() == 1 and wed[0].id == "slot_rest" and float(wed[0].value) == -0.5 and tue.is_empty())
	_ok("... friends on Friday and Saturday cost nothing (no school the next day)", hs.load_parts(_d("2026-11-14"), 1.0).is_empty()
			and hs.load_parts(_d("2026-11-15"), 1.0).is_empty())
	_ok("... three friends slots: motivation +2 (one over two); three study slots: grades -0.5", float(hs.motivation_pulls(mon)[0].delta) == 2.0
			and hs.grade_shift(mon) == -0.5)
	hs.set_habits(["study", "study", "study", "study", "family", "family", "family"])
	_ok("three family slots: stress -4 (two over one), motivation -4 (no friends), the summary says so",
			float(hs.stress_pulls(mon)[0].delta) == -4.0 and float(hs.motivation_pulls(mon)[0].delta) == -4.0
			and hs.summary().contains("stress ▼") and hs.summary().contains("motivation ▼"))
	# Through the game: a week with friends every school night is more tiring than the default week.
	var tired := []
	for habits in [data.habits.default, ["friends", "friends", "friends", "friends", "friends", "friends", "friends"]]:
		hs = _fresh()
		hs.set_habits(habits)
		_play_to(_d("2026-11-16"))
		tired.append(game.athlete.fatigue)
	print("    fatigue after the first week: default %.3f, friends every evening %.3f" % [tired[0], tired[1]])
	_ok("through the game: friends every evening (late nights before school) leaves you more tired than the default week", tired[1] > tired[0])


# --- 4. This week's changes ------------------------------------------------------------------------------------------------------

func _week_changes() -> void:
	print("-- 4. a slot changed for this week only (the planner, the day editor)")
	var hs = _fresh()
	_ok("Wednesday evening becomes friends this week: the habit stays study, next week's Wednesday is study",
			hs.set_slot(2, "friends") and hs.week_slot(2) == "friends" and hs.changed(2) and hs.habit(2) == "study"
			and hs.activity_on(_d("2026-11-04")) == "friends" and hs.activity_on(_d("2026-11-11")) == "study")
	_ok("... and Thursday (a school day after it) gets the late night", hs.load_parts(_d("2026-11-05"), 1.0).any(func(x): return x.id == "slot_friends"))
	_ok("setting the habit's own activity is no change; changing the habit to this week's choice drops the change",
			hs.set_slot(2, "study") and not hs.changed(2) and hs.set_slot(3, "rest") and hs.set_habit(3, "rest") and not hs.changed(3))
	hs.set_habit(3, "study")
	_play_to(_d("2026-11-04"))   # Monday and Tuesday played
	_ok("a played day's slot can't change; today's (Wednesday) still can", not hs.set_slot(0, "friends") and not hs.can_change(1)
			and hs.can_change(2) and hs.set_slot(4, "rest") and hs.reset_slot(4) and not hs.changed(4))
	hs.set_slot(5, "rest")
	_play_to(_d("2026-11-09"))
	game.current_week()   # (the planner opens on the new week)
	_ok("a new week starts with no changes (Saturday's rest was this week's only)", hs.week_slots.is_empty() and hs.week_slot(5) == "friends")


# --- 5. Played days ---------------------------------------------------------------------------------------------------------------

func _played_history() -> void:
	print("-- 5. played days and 'last night'")
	var hs = _fresh()
	hs.set_slot(6, "friends")   # Sunday 8 Nov with friends: Monday 9 Nov is a school day
	_play_to(_d("2026-11-09"))
	_ok("Sunday's slot is remembered after it is played (friends), though the habit is family", hs.activity_on(_d("2026-11-08")) == "friends"
			and hs.habit(6) == "family")
	var parts: Array = game.get_system("school").load_parts(_d("2026-11-09"), [])
	_ok("Monday (a school day) gets 'Out with friends last night'", parts.any(func(x): return x.id == "slot_friends"))
	_play_to(_d("2026-11-10"))
	var log_mon: Dictionary = {}
	for e in game.day_log:
		if Cal.date_key(e.date) == 20261109:
			log_mon = e
	_ok("... and Monday's day log has its life load (+0.75)", is_equal_approx(float(log_mon.get("life", 0.0)), 0.75))
	hs.set_habit(6, "rest")
	_ok("changing the habit later doesn't rewrite a played day", hs.activity_on(_d("2026-11-08")) == "friends")


# --- 6. Save / load ---------------------------------------------------------------------------------------------------------------

func _save_load() -> void:
	print("-- 6. save version 5, save / load, a version-4 save")
	_ok("save version 5", int(saves.VERSION) == 5)
	var hs = _fresh()
	hs.set_habits(["study", "rest", "study", "study", "friends", "family", "family"])
	hs.set_slot(3, "friends")
	_play_to(_d("2026-11-04"))
	var snap := _json(game.to_dict())
	_ok("the habits, this week's change and the played slots are in the save", game.to_dict().systems.has("habits")
			and game.to_dict().systems.habits.slots.has("3"))
	_play_to(_d("2026-11-25"))
	var end_a := _json(game.athlete.to_dict()) + _json(game.get_system("habits").to_dict()) + _json(game.get_system("school").to_dict())
	game.from_dict(_parse(snap))
	game.get_system("school")._schedules[2026] = {}   # (as _fresh: no tests; the schedule is not saved)
	_ok("loaded: the habits and Thursday's change are back", _hs().habits == ["study", "rest", "study", "study", "friends", "family", "family"]
			and _hs().week_slot(3) == "friends")
	_play_to(_d("2026-11-25"))
	var end_b := _json(game.athlete.to_dict()) + _json(game.get_system("habits").to_dict()) + _json(game.get_system("school").to_dict())
	_ok("a loaded game goes on exactly as without saving (athlete, habits, school)", end_a == end_b)
	for combo in [["heavy", "lots"], ["light", "little"], ["normal", "normal"]]:
		var old: Dictionary = game.to_dict()
		old.systems.erase("habits")
		old.systems.school.effort = combo[0]
		old.systems.school.free_time = combo[1]
		game.from_dict(_parse(_json(old)))
		_ok("a version-4 save at %s / %s gets the habits %s and reads back as %s / %s" % [combo[0], combo[1], _hs().habits, combo[0], combo[1]],
				_hs().habits == data.habits.from_old["%s|%s" % combo] and game.get_system("school").effort_word() == combo[0]
				and game.get_system("school").free_word() == combo[1])


# --- 7. The report card's choice ----------------------------------------------------------------------------------------------------

func _card() -> void:
	print("-- 7. the report card's choice edits the habits by one slot")
	var hs = _fresh()
	var ss = game.get_system("school")
	_ok("one more study evening = Sunday (family); one fewer = Thursday", hs.more_study() == {"i": 6, "from": "family"} and hs.less_study() == {"i": 3})
	ss._answer_card("harder")
	_ok("'One more study evening': Sunday is study, grades rise", hs.habit(6) == "study" and hs.grade_shift(game.date) == 0.5)
	ss._answer_card("ease")
	ss._answer_card("ease")
	_ok("'One fewer' twice: Thursday and Wednesday are rest", hs.habit(3) == "rest" and hs.habit(2) == "rest" and hs.grade_shift(game.date) == -0.5)
	ss._answer_card("keep")
	_ok("'Keep' changes nothing", hs.habits == ["study", "study", "rest", "rest", "friends", "friends", "study"])


# --- 8. Invitations --------------------------------------------------------------------------------------------------------------------

## Posts invitation storylet `sid` into day `d` of this week (skipping the Sunday draw), from its first possible sender.
func _post_invite(sid: String, d: int) -> Dictionary:
	var ms = _ms()
	ms._sync_people()
	var s: Dictionary = ms.storylet(sid)
	var w = game.current_week()
	var date: Dictionary = game.add_days(w.monday, d)
	var ctx := {"date": date, "day": d, "day_type": Cal.day_type(date), "week": w, "race_note": {}}
	var senders: Array = ms.people_for(str(s.from))
	if senders.is_empty():
		return {}
	ms.stop_tokens = maxf(ms.stop_tokens, 1.0)
	return ms._post(s, senders[0], ctx, MS.day_no(game.date), false, {"invite": true, "counted": false})


func _invites() -> void:
	print("-- 8. invitations land in a slot, are answered on the planner and happen on their evening")
	MS.people_enabled = true
	var keep_chance: float = data.habits.invites.chance
	data.habits.invites.chance = 0.0   # (no Sunday draw in this part: the invitations are posted by hand)
	var hs = _fresh(1)
	hs.set_habit(5, "rest")   # (so Go visibly changes Saturday)
	_play_to(_d("2026-11-03"))   # (the moments run from the first day)
	var ms = _ms()
	var m := _post_invite("fr_party_weekend", 5)
	var sat := _d("2026-11-07")
	_ok("posted for Saturday: it waits on the planner, the slot shows it, but it is no 'choice waiting' of Play week (user 2026-10-24)",
			not m.is_empty() and m.has("invite")
			and int(m.slot_day) == MS.day_no(sat) and ms.waiting().has(m) and not WPL.open_choices().any(func(c): return c.get("m", {}) == m)
			and bool(hs.slot_info(game.current_week(), 5).highlight) and hs.invitation_on(sat) == m)
	_ok("its text says the day, not 'tonight' (%s)" % m.text, str(m.text).contains("Saturday") or str(m.text).contains("bowling")
			or str(m.text).contains("Sauna"))
	var price: Array = HUI.price_lines(m)
	print("    price: %s" % [price])
	_ok("its price: the late night and the day after it, and what staying home costs the friendship", price.size() >= 2
			and str(price[0]).contains("late night") and str(price[-1]).begins_with("Stay home"))
	var friend: Dictionary = ms.people[str(m.from)]
	var rel_before := float(friend.relation)
	ms.answer(str(m.id), "go")
	_ok("Go only plans it: nothing happens yet, it asks nothing more, Saturday becomes friends", str(m.planned) == "go" and str(m.answer) == ""
			and not ms.waiting().has(m) and hs.activity_on(sat) == "friends" and float(friend.relation) == rel_before)
	ms.unplan(str(m.id))
	_ok("Change my mind: it waits again, Saturday is rest again", ms.waiting().has(m) and hs.activity_on(sat) == "rest")
	ms.answer(str(m.id), "go")
	ms.answer(str(m.id), "nonsense")
	_ok("an unknown reply leaves the plan as it is", str(m.planned) == "go")
	_play_to(_d("2026-11-08"))
	var sun_parts: Array = game.get_system("school").load_parts(_d("2026-11-08"), [])
	_ok("on Saturday evening it happened: answered Go, the friend closer, a late night for Sunday, Saturday remembered as friends",
			str(m.answer) == "go" and float(friend.relation) > rel_before and sun_parts.any(func(x): return x.id == "late_night")
			and hs.activity_on(sat) == "friends")
	# Unanswered = you didn't go; Stay home = the habit, the friend a bit hurt.
	_play_to(_d("2026-11-09"))
	var m2 := _post_invite("sch_group_work", 3)   # (Thursday 12 Nov)
	var m3 := _post_invite("fr_party_weekend", 4)
	var friend3: Dictionary = ms.people[str(m3.from)]
	var rel3 := float(friend3.relation)
	ms.answer(str(m3.id), "no")
	_ok("two in a week are possible by hand (the Sunday draw allows one): Thursday's group work open, Friday's party planned as Stay home",
			not m2.is_empty() and ms.waiting().has(m2) and str(m3.planned) == "no" and hs.activity_on(_d("2026-11-13")) == "friends")
	_play_to(_d("2026-11-14"))
	_ok("unanswered by Thursday evening: 'you didn't answer', the slot kept its habit (study)", str(m2.answer) == MS.NONE
			and hs.activity_on(_d("2026-11-12")) == "study")
	_ok("Stay home happened on Friday evening: the friend a bit hurt, no late night for Saturday", str(m3.answer) == "no"
			and float(friend3.relation) < rel3 and not game.get_system("school").load_parts(_d("2026-11-14"), []).any(func(x): return x.id == "late_night"))
	# A rule answers an invitation by itself (it still happens on its evening).
	ms.standing["weekend_party"] = {"reply": "no", "label": "x", "rule": "Say no to weekend evenings before a long or hard session", "since": 0}
	var m4 := _post_invite("fr_party_weekend", 5)
	_ok("with a rule it is planned at once (Stay home) and waits for nothing", bool(m4.auto) and str(m4.planned) == "no" and not ms.waiting().has(m4))
	ms.standing.erase("weekend_party")
	# The clash marks (a new week): a late night before a race or a hard session.
	_play_to(_d("2026-11-16"))
	_post_invite("fr_party_race", 4)
	var w = game.current_week()
	var keep_races: Dictionary = w.races
	w.races = {5: {"key": "test@2026", "name": "Test meet", "date": game.add_days(w.monday, 5)}}   # (after current_week(), which resets them)
	var info4: Dictionary = hs.slot_info(w, 4)
	_ok("an invitation with a late night on Friday before Saturday's race: the slot says 'race' (%s)" % info4.clash, str(info4.clash) == "race"
			and bool(info4.highlight))
	w.races = keep_races
	hs.set_slot(3, "friends")
	w.set_intensity(4, "hard")
	var info3: Dictionary = hs.slot_info(w, 3)
	_ok("friends on Thursday (a school night) before a hard Friday: a late night and the 'hard' clash", bool(info3.late) and str(info3.clash) == "hard")
	hs.reset_slot(3)
	_ok("the default Thursday (study) has no clash", str(hs.slot_info(w, 3).clash) == "")
	data.habits.invites.chance = keep_chance
	MS.people_enabled = false


# --- 9. A season with the people on ------------------------------------------------------------------------------------------------

func _season(weeks: int) -> void:
	print("-- 9. %d weeks with the people on: the Sunday draw" % weeks)
	MS.people_enabled = true
	var hs = _fresh(2)
	var ms = _ms()
	_play_to(game.add_days(game.date, 7 * weeks))
	var invs: Array = ms.fired.filter(func(f): return bool(f.get("invite", false)))
	var per_week := {}
	var faults := []
	for m in ms.moments:
		if not m.has("invite"):
			continue
		var wk: int = int(m.slot_day) - Cal.weekday(MS._date_of(int(m.slot_day)))
		per_week[wk] = int(per_week.get(wk, 0)) + 1
		if int(m.day) > int(m.slot_day):
			faults.append("%s posted after its slot" % m.storylet)
		if int(m.slot_day) - int(m.day) > 7:
			faults.append("%s posted more than a week ahead" % m.storylet)
		if int(m.slot_day) < MS.day_no(game.date) and str(m.answer) == "":
			faults.append("%s not settled after its evening" % m.storylet)
	var kinds := {}
	for f in invs:
		kinds[f.storylet] = int(kinds.get(f.storylet, 0)) + 1
	for f in faults:
		print("    " + f)
	print("    invitations: %d in %d weeks %s" % [invs.size(), weeks, kinds])
	_ok("invitations come (%d in %d weeks), at most one a week, never after or more than a week before their slot, each settled on its evening"
			% [invs.size(), weeks], invs.size() > 0 and per_week.values().all(func(n): return int(n) <= 1) and faults.is_empty())
	_ok("no old-style moment of the three invitations came (they are only posted into slots)",
			ms.fired.filter(func(f): return str(f.storylet) in ["fr_party_weekend", "fr_party_race", "sch_group_work"] and not bool(f.get("invite", false))).is_empty())
	MS.people_enabled = false
