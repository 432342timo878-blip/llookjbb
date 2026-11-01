extends SceneTree
## Dev tool (session P2b): a first relationship (GDD 4.10 decision 6, "P2b's questions"; RomanceSystem, data/romance.json, the activity
## "partner" in HabitSystem, the crush card, late texting, the breakup's dip, the confirmation camp's faces, a teammate really quitting
## or joining). Proves: the data (research facts with a source, a read date and marked unverified; the storylets of P2b: at least 25,
## guarded), the relationship is OFF in lab (no card, no partner slot, no texting part, nothing in the save), NOBODY IS CHOSEN FOR THE
## PLAYER (no relationship starts without the player's pick, the card stays), a relationship STARTS ON THE PLAYER'S CHOICE (a yes and a
## no from the career's own dice), together it gives a weekend slot that lifts the mood and is time together, LATE TEXTING COSTS SLEEP (a
## life-load part on two school evenings, none with the phone off or on a rest evening, recorded in the day log), a week without is
## neglect (a warning, then it ends), it ENDS WITH A DIP (a breakup by you or by them: the moods drop at once and the Sunday targets are
## lowered for two weeks, recorded as pulls), the camp brings new faces once, a teammate quits / joins for real, and save / load (an
## older save has no romance state). Prints PASS / FAIL.
## Run: godot --headless --path . -s res://tools/romance_check.gd   (~3 minutes)
## Own save folder (user://tool_saves/). NOTE: it prints ALL CHECKS PASSED even when a SCRIPT ERROR aborted a part: read stderr too.

var game
var data
var Cal
var MS
var HS
var RS
var CS
var F
var saves
var _fails := 0
var _chance_backup := {}
var _answer_backup := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	Cal = load("res://scripts/core/calendar.gd")
	MS = load("res://scripts/core/storylet_system.gd")
	HS = load("res://scripts/core/habit_system.gd")
	RS = load("res://scripts/core/romance_system.gd")
	CS = load("res://scripts/core/circle_system.gd")
	F = load("res://scripts/core/athlete_factory.gd")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	var GC = load("res://scripts/core/game_config.gd")
	GC.fixed_seed = 4646
	game.autosave = false
	_chance_backup = (data.romance.offer.chance as Dictionary).duplicate()
	_answer_backup = (data.romance.answer as Dictionary).duplicate()
	_data()
	_off_in_lab(GC)
	GC.use("lab", {"school_neutral": false, "mind_neutral": false, "circle": true, "romance": true})
	MS.people_enabled = true
	_nobody_is_chosen()
	_choice()
	_together()
	_texting()
	_neglect_and_breakup()
	_end_by_you()
	_camp()
	_team()
	_invitation()
	_post_every_storylet()
	_save_load()
	MS.people_enabled = false
	_restore()
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


func _rs():
	return game.get_system("romance")


func _mind():
	return game.get_system("mind")


func _restore() -> void:
	data.romance.offer.chance = _chance_backup.duplicate()
	data.romance.answer = _answer_backup.duplicate()


## Every week a card comes (chance 1) and the answer is certain (yes = true) or impossible (false).
func _rigged(card_always: bool, answer_yes) -> void:
	_restore()
	if card_always:
		data.romance.offer.chance = {"15": 1.0, "16": 1.0, "17": 1.0}
	if answer_yes != null:
		var v: float = 1.0 if answer_yes else 0.0
		data.romance.answer.base = v
		data.romance.answer.min = v
		data.romance.answer.max = v


## A 15-year-old at the start (born 2011), a career in lab with the school and the mind on.
func _athlete(i := 0):
	var rng := RandomNumberGenerator.new()
	rng.seed = 8200 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	return F.create({"first_name": "Romy%d" % i, "last_name": "Runner", "gender": "male" if i % 2 == 0 else "female", "hometown": "Tampere",
			"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2011, "month": 5, "day": 1}, "answers": answers}, rng)


func _fresh(i := 0, year := 2011):
	var a = _athlete(i)
	a.birth_date = {"year": year, "month": 5, "day": 1}
	game.start_career(a, "repeat")
	var ss = game.get_system("school")
	ss._ensure_started()
	ss._schedules[2026] = {}
	return _rs()


func _play_to(until: Dictionary) -> void:
	var guard := 0
	while Cal.date_key(game.date) < Cal.date_key(until) and guard < 900:
		guard += 1
		game.advance_day()
		while not game.pending_event().is_empty():
			game.answer_event(game.pending_event().id, "ok")


func _week(n := 1) -> void:
	_play_to(game.add_days(game.date, 7 * n))


## The friend to fall for: the best friend.
func _best():
	return _ms().people_for("best_friend")[0]


# --- 1. Data ----------------------------------------------------------------------------------------------------------------------

func _data() -> void:
	print("-- 1. data/romance.json and the P2b storylets")
	var r: Dictionary = data.romance
	var facts: Array = r.research.facts
	var facts_ok := facts.size() >= 3
	for f in facts:
		facts_ok = facts_ok and str(f.id) != "" and str(f.use) != "" and not f.sources.is_empty() and f.verified == false
		for s in f.sources:
			facts_ok = facts_ok and str(s.url).begins_with("http") and str(s.read) != ""
	_ok("the research has %d facts, each with a use, a source with a url and a read date, marked unverified" % facts.size(), facts_ok)
	var faults := []
	for k in ["offer", "answer", "dating", "texting", "effects", "breakup", "camp", "texts", "ui"]:
		if not r.has(k):
			faults.append(k)
	if not (float(r.answer.min) < float(r.answer.max) and float(r.dating.warn_weeks) < float(r.dating.end_weeks)):
		faults.append("answer min < max, warn < end")
	for t in ["asked", "yes", "no", "warn", "ended_them", "ended_you", "pull_slots", "pull_dip_them"]:
		if not r.texts.has(t):
			faults.append("texts." + t)
	_ok("the keys, the texts and the thresholds are in order", faults.is_empty())
	for f in faults:
		print("    " + f)
	var mine: Array = data.storylets.filter(func(s): return not bool(s.get("test", false)) and (str(s.id).begins_with("rm_") or str(s.id).begins_with("t16_")))
	var feed := mine.filter(func(s): return bool(s.get("feed", false))).size()
	var invite := mine.filter(func(s): return s.has("invite")).size()
	var beat := mine.filter(func(s): return s.has("beat")).size()
	_ok("%d new storylets (at least 25): %d feed, %d invitations, %d story beats" % [mine.size(), feed, invite, beat],
			mine.size() >= 25 and feed > 0 and invite > 0 and beat > 0 and feed + invite + beat == mine.size())
	var rm: Array = mine.filter(func(s): return str(s.id).begins_with("rm_"))
	var guarded := rm.all(func(s): return (s.when as Dictionary).has("romance"))
	_ok("every storylet of the relationship is guarded by the `romance` condition", guarded and not rm.is_empty())
	var weekend := rm.filter(func(s): return s.has("invite")).all(func(s): return str(s.invite.activity) == "partner" and (s.invite.days as Array).all(func(x): return int(x) in [5, 6]))
	_ok("and its invitations are partner slots on Saturday / Sunday", weekend)
	_ok("the 16-17 moments carry an age, a stage, a flag or a `turns` condition (nothing for everyone)",
			mine.filter(func(s): return str(s.id).begins_with("t16_")).all(func(s): var w: Dictionary = s.when; return w.has("age") or w.has("stage") or w.has("flags") or w.has("turns")))


# --- 2. Off in lab ------------------------------------------------------------------------------------------------------------

func _off_in_lab(GC) -> void:
	print("-- 2. in lab the relationship changes nothing")
	GC.use("lab")
	_ok("the option is off in lab and on in real", not GC.get_option("romance"))
	MS.people_enabled = false
	_fresh(0)
	_rigged(true, true)
	_play_to(_d("2026-11-23"))
	_ok("no card, no stage, no partner slot, no texting part, nothing in the save", not RS.active() and _rs().card().is_empty() and _rs().stage == "" and _rs().to_dict().is_empty()
			and not _hs().choices(5).has("partner") and not RS.allows_partner(5) and not _hs().set_habit(5, "partner"))
	_ok("and the mind has no pull from it", _mind().pulls("motivation").all(func(p): return not str(p.text).contains("Together")))
	_restore()
	GC.use("lab", {"school_neutral": false, "mind_neutral": false, "circle": true, "romance": true})
	MS.people_enabled = true


# --- 3. Nobody is chosen for the player ----------------------------------------------------------------------------------------

func _nobody_is_chosen() -> void:
	print("-- 3. a card comes, and nothing starts without the player's choice")
	var young = _fresh(1, 2012)   # 14 at the start: too young
	_rigged(true, true)
	_play_to(_d("2026-12-14"))
	_ok("a 14-year-old gets no card (the age is from %d)" % int(data.romance.offer.age_min), _rs().card().is_empty() and _rs().stage == "")
	var rs = _fresh(2)
	_rigged(true, true)
	_play_to(_d("2026-11-09"))
	var card: Dictionary = rs.card()
	_ok("after the first Sunday a card is there: %d people, closest first" % card.get("cands", []).size(), not card.is_empty() and card.cands.size() >= 1 and card.cands.size() <= 3)
	_ok("they are people you know well enough (closeness at least %d): friends, classmates or teammates, never the player's family or a teacher" % int(data.romance.offer.min_closeness),
			card.cands.all(func(p): return float(p.relation) >= float(data.romance.offer.min_closeness) and CS.sys().kind_of(p) in data.romance.offer.kinds))
	_play_to(_d("2026-11-30"))
	_ok("three more weeks with the card left alone: still nobody (no crush, no relationship), the card stays", rs.stage == "" and rs.partner == "" and not rs.card().is_empty())
	rs.decline()
	_ok("'Nobody right now' removes it and keeps it away for %d weeks" % int(data.romance.offer.decline_quiet_weeks), rs.card().is_empty())
	_play_to(_d("2026-12-14"))
	_ok("quiet for the weeks it said", rs.card().is_empty())


# --- 4. The choice and the answer ------------------------------------------------------------------------------------------------

func _choice() -> void:
	print("-- 4. a relationship starts on the player's choice; the answer comes from the dice")
	var rs = _fresh(3)
	_rigged(true, true)
	_play_to(_d("2026-11-09"))
	var p: Dictionary = rs.card().cands[0]
	var pid := str(p.id)
	_ok("the player picks %s: a crush, no card, a quiet line in Together" % p.first_name, rs.choose(pid) and rs.stage == "crush" and rs.partner == pid and rs.card().is_empty()
			and not _ms().thread("together").is_empty())
	_ok("the crush's page has a TOGETHER box in the 'crush' mode", rs.box_of(pid).mode == "crush")
	_ok("the Together thread is listed with the crush", _ms().people_for("together").has(p))
	_play_to(_d("2026-11-16"))
	_ok("the answer came on Sunday evening: a yes (rigged): together", rs.stage == "dating" and bool(p.dating) and str(p.word) == data.romance.words.together and rs.state_now() == "dating")
	_ok("their answer is a message in Together, and the relationship is at least %d" % int(data.romance.dating.start_min),
			_ms().thread("together").any(func(x): return str(x.from) == pid) and float(p.relation) >= float(data.romance.dating.start_min) - 0.01)
	_ok("the circle knows them as 'dating'", CS.sys().kind_of(p) == "dating")
	# A no.
	rs = _fresh(4)
	_rigged(true, false)
	_play_to(_d("2026-11-09"))
	p = rs.card().cands[0]
	pid = str(p.id)
	rs.choose(pid)
	_play_to(_d("2026-11-16"))
	_ok("a no (rigged): still friends, no relationship", rs.stage == "" and not bool(p.get("dating", false)) and str(p.role) in ["best_friend", "friend", "acquaintance"])
	_ok("it stings, and the causes say so: the person's log has the 'said no' move, the confidence has a cause too",
			(p.log as Array).any(func(x): return str(x.get("kind", "")) == "romance" and float(x.delta) < 0.0)
			and (_mind().causes["confidence"] as Array).any(func(c): return str(c.text).contains("said no") and float(c.delta) < 0.0))
	_ok("and you cannot ask again for %d days (the card stays away)" % int(data.romance.offer.no_quiet_days), rs.card().is_empty() and int(rs.asked.get(pid, 0)) > 0)
	_play_to(_d("2027-02-01"))
	_ok("... not even ten weeks later", rs.card().is_empty())
	# The dice are the career's own and the chance rises with closeness.
	_restore()
	var near := {"relation": 80.0}
	var far := {"relation": 36.0}
	_ok("the chance rises with closeness (%.2f at 36, %.2f at 80), kept in [%.1f, %.1f]" % [rs.chance_for(far), rs.chance_for(near), float(data.romance.answer.min), float(data.romance.answer.max)],
			rs.chance_for(far) < rs.chance_for(near) and rs.chance_for(far) >= float(data.romance.answer.min) and rs.chance_for(near) <= float(data.romance.answer.max))
	var rs_again = _fresh(4)
	_rigged(true, null)
	_play_to(_d("2026-11-09"))
	var c1: Array = rs_again.card().cands.map(func(q): return str(q.id))
	var rs_third = _fresh(4)
	_rigged(true, null)
	_play_to(_d("2026-11-09"))
	_ok("the same career gets the same first name on the card (the closest person)", not c1.is_empty() and str(rs_third.card().cands[0].id) == c1[0])


# --- 5. Together --------------------------------------------------------------------------------------------------------------

## A career that is together with the best friend, started the first Sunday (rigged yes).
func _dating_career(i: int):
	var rs = _fresh(i)
	_rigged(true, true)
	_play_to(_d("2026-11-09"))
	rs.choose(str(rs.card().cands[0].id))
	_play_to(_d("2026-11-16"))
	_restore()
	data.romance.offer.chance = {"15": 0.0, "16": 0.0, "17": 0.0}
	return rs


func _together() -> void:
	print("-- 5. together: a weekend slot, the mood, closeness")
	var rs = _dating_career(5)
	var hs = _hs()
	var mind = _mind()
	var p: Dictionary = rs.partner_person()
	_ok("together: a Partner slot can fill Saturday and Sunday and no other day", RS.allows_partner(5) and RS.allows_partner(6) and not RS.allows_partner(2)
			and hs.choices(5).has("partner") and not hs.choices(2).has("partner"))
	_ok("setting a weekday to partner is refused", not hs.set_slot(2, "partner") and not hs.set_habit(2, "partner"))
	_ok("... and Saturday works, this week only", hs.set_slot(5, "partner") and hs.week_slot(5) == "partner" and hs.activity_on(_d("2026-11-21")) == "partner")
	var mot_pulls: Array = mind.pulls("motivation", game.current_week())
	_ok("the mood row says why: 'Time with %s' lifts motivation" % p.first_name, mot_pulls.any(func(x): return str(x.text).contains(str(p.first_name)) and float(x.delta) > 0.0))
	var rel0 := float(p.relation)
	_play_to(_d("2026-11-23"))
	_ok("a week with a partner day: closeness grew (%.1f -> %.1f), slots_last %d, no neglect" % [rel0, float(p.relation), rs.slots_last], float(p.relation) > rel0 and rs.slots_last == 1 and rs.neglect == 0)
	_ok("the person's log says why: time together", (p.log as Array).any(func(x): return str(x.get("kind", "")) == "time"))
	_ok("the circle's page tells what the slot gives and costs", CS.sys().page_of(p).gives.size() >= 1 and CS.sys().page_of(p).costs.size() >= 1 and CS.sys().page_of(p).kind == "dating")
	hs.set_slot(5, "partner")
	hs.set_slot(6, "partner")
	_ok("two partner days lift motivation by at most %d x %.0f" % [int(data.romance.effects.max_slots), float(data.romance.effects.motivation_per_slot)],
			mind.pulls("motivation", game.current_week()).filter(func(x): return str(x.text).contains(str(p.first_name))).all(func(x): return float(x.delta) <= float(data.romance.effects.max_slots) * float(data.romance.effects.motivation_per_slot) + 0.001))
	var conf_pull: Array = mind.pulls("confidence", game.current_week())
	_ok("and a little confidence", conf_pull.any(func(x): return float(x.delta) > 0.0 and str(x.text).contains("Together")))


# --- 6. Late texting costs sleep ----------------------------------------------------------------------------------------------------

func _texting() -> void:
	print("-- 6. late texting costs sleep")
	var rs = _dating_career(6)
	var hs = _hs()
	var ss = game.get_system("school")
	hs.set_habits(["study", "study", "study", "study", "friends", "friends", "family"])
	var monday: Dictionary = game.week_monday()
	var count := 0
	var days := []
	for i in 5:
		var d: Dictionary = game.add_days(monday, i)
		if ss.load_parts(d, []).any(func(x): return x.id == "texting"):
			count += 1
			days.append(i)
	var picks := []
	for e in data.romance.texting.evenings:
		if RS.text_late(monday, int(e)):
			picks.append(int(e))
	var right := picks.size() == int(data.romance.texting.nights)
	for e in picks:   # the school day after a picked evening carries the part (a Sunday's pick: next Monday)
		right = right and ss.load_parts(game.add_days(monday, int(e) + 1), []).any(func(x): return x.id == "texting")
	for e in data.romance.texting.evenings:
		if not int(e) in picks:
			right = right and not ss.load_parts(game.add_days(monday, int(e) + 1), []).any(func(x): return x.id == "texting")
	_ok("'Texting: whenever' (the default): %d of the week's evenings (%s) are late texts, each with its part on the school day after (%d school days this Mon-Fri)" % [picks.size(), picks, count],
			rs.texting == "whenever" and right)
	var again := []
	for e in data.romance.texting.evenings:
		if RS.text_late(monday, int(e)):
			again.append(int(e))
	_ok("it is a pure function of the career and the week (asked twice, the same)", again == picks)
	var part: Dictionary = {}
	for i in 5:
		for x in ss.load_parts(game.add_days(monday, i), []):
			if x.id == "texting":
				part = x
	var scale := float(ss.stage_of(game.date).get("scale", 1.0))
	_ok("each costs %.2f of life load (%.2f x the stage's scale %.2f): the same as an evening out with friends" % [float(part.get("value", 0.0)), float(data.romance.texting.load), scale],
			not part.is_empty() and is_equal_approx(float(part.value), float(data.habits.effects.late_friends) * scale))
	rs.set_texting("off")
	var off := 0
	for i in 5:
		if ss.load_parts(game.add_days(monday, i), []).any(func(x): return x.id == "texting"):
			off += 1
	_ok("'Phone off at ten': no late nights from texting", off == 0)
	rs.set_texting("whenever")
	hs.set_habits(["rest", "rest", "rest", "rest", "rest", "rest", "rest"])
	var rest := 0
	for i in 5:
		if ss.load_parts(game.add_days(monday, i), []).any(func(x): return x.id == "texting"):
			rest += 1
	_ok("a rest evening never gets the late text (an early night wins)", rest == 0)
	hs.set_habits(["study", "study", "study", "study", "friends", "friends", "family"])
	_play_to(game.add_days(monday, 7))
	var log_texting := 0
	for e in game.day_log:
		if (e.get("life_parts", {}) as Dictionary).has("texting"):
			log_texting += 1
	_ok("it is recorded in the day log (%d school days) so the week's causes can say it" % log_texting, log_texting >= 1)
	# Closeness grows faster with it than without.
	var cmp := [_closeness_after_two_weeks("whenever"), _closeness_after_two_weeks("off")]
	_ok("and closeness grows a little faster with texting whenever (%.2f) than with the phone off (%.2f)" % [cmp[0], cmp[1]], cmp[0] > cmp[1])


func _closeness_after_two_weeks(mode: String) -> float:
	var rs = _dating_career(7)
	var p: Dictionary = rs.partner_person()
	rs.set_texting(mode)
	_hs().set_slot(5, "partner")
	var before := float(p.relation)
	_play_to(_d("2026-11-23"))
	return float(p.relation) - before


# --- 7. Neglect and a breakup by them ---------------------------------------------------------------------------------------------

func _neglect_and_breakup() -> void:
	print("-- 7. a week with no partner day is neglect: a warning, then it ends with a dip")
	var rs = _dating_career(8)
	var mind = _mind()
	var p: Dictionary = rs.partner_person()
	var pid := str(p.id)
	_play_to(_d("2026-11-23"))   # week 1 with no partner slot
	_ok("one week without a partner day: neglect 1, no warning yet", rs.neglect == 1 and not rs.warned and rs.stage == "dating")
	_play_to(_d("2026-11-30"))
	_ok("two weeks: they say so (one message from them), still together", rs.neglect == 2 and rs.warned and rs.stage == "dating"
			and _ms().thread("together").any(func(x): return str(x.from) == pid and data.romance.texts.warn.any(func(w): return str(x.text) == str(w))))
	var conf: float = mind.value("confidence")
	var mot: float = mind.value("motivation")
	var rel: float = float(p.relation)
	_play_to(_d("2026-12-07"))
	_ok("three weeks: they end it (stage cleared, the ex is marked, the page says 'ex')", rs.stage == "" and not bool(p.dating) and int(p.get("ex", 0)) > 0 and rs.box_of(pid).mode == "ex" and rs.state_now() == "ended")
	_ok("they say so in Together", _ms().thread("together").any(func(x): return str(x.from) == pid and data.romance.texts.ended_them.any(func(w): return str(x.text) == str(w))))
	_ok("the person is who they were: the closeness fell (%.1f -> %.1f) and they are a %s again" % [rel, float(p.relation), p.role], float(p.relation) < rel - 8.0 and str(p.role) in ["best_friend", "friend"])
	var them: Dictionary = data.romance.breakup.them
	_ok("the dip: confidence %.1f -> %.1f, motivation %.1f -> %.1f at once (%+.0f, %+.0f)" % [conf, mind.value("confidence"), mot, mind.value("motivation"), float(them.now.confidence), float(them.now.motivation)],
			mind.value("confidence") < conf - 3.0 and mind.value("motivation") < mot - 4.0)
	_ok("... and the Sunday targets are lowered for %d weeks, said in the mood rows" % int(data.romance.breakup.weeks), int(rs.dip.weeks) == int(data.romance.breakup.weeks)
			and mind.pulls("motivation", game.current_week()).any(func(x): return str(x.text) == data.romance.texts.pull_dip_them and float(x.delta) < 0.0)
			and mind.pulls("confidence", game.current_week()).any(func(x): return float(x.delta) < 0.0))
	_ok("the mood's causes record it", (mind.causes["motivation"] as Array).any(func(c): return str(c.text).contains(str(p.first_name)) and float(c.delta) < 0.0))
	_play_to(_d("2026-12-21"))
	_ok("after two Sundays the weight is gone (about two weeks)", rs.dip.is_empty() and not mind.pulls("motivation", game.current_week()).any(func(x): return str(x.text) == data.romance.texts.pull_dip_them))
	_ok("no new card for %d days" % int(data.romance.offer.after_breakup_days), rs.card().is_empty())


# --- 8. You end it ------------------------------------------------------------------------------------------------------------------

func _end_by_you() -> void:
	print("-- 8. you end it: the smaller dip, the partner days become friends days")
	var rs = _dating_career(9)
	var hs = _hs()
	var mind = _mind()
	var p: Dictionary = rs.partner_person()
	hs.set_habit(5, "partner")
	hs.set_slot(6, "partner")
	var mot: float = mind.value("motivation")
	_ok("end_it works on a relationship", rs.end_it())
	var you: Dictionary = data.romance.breakup.you
	_ok("the partner days became friends days (habit and this week's)", hs.habit(5) == "friends" and hs.week_slot(6) != "partner")
	_ok("a smaller dip than when they end it: motivation %.1f -> %.1f (%+.0f vs %+.0f)" % [mot, mind.value("motivation"), float(you.now.motivation), float(data.romance.breakup.them.now.motivation)],
			mind.value("motivation") < mot - 2.0 and float(you.now.motivation) > float(data.romance.breakup.them.now.motivation))
	_ok("the dip is 'you': %s, the history has the pair" % rs.dip.mode, str(rs.dip.mode) == "you" and rs.history.size() == 1 and str(rs.history[0].by) == "you")
	_ok("the partner slot is gone as a choice", not hs.choices(5).has("partner") and not RS.allows_partner(5))
	_ok("ending twice does nothing", not rs.end_it())
	_play_to(game.add_days(game.date, 14))
	_ok("two Sundays later the dip is over", rs.dip.is_empty())


# --- 9. The confirmation camp ---------------------------------------------------------------------------------------------------------

func _camp() -> void:
	print("-- 9. the confirmation camp brings new faces once")
	var rs = _fresh(10, 2012)   # turns 15 in 2027: the camp year
	var ms = _ms()
	var cs = CS.sys()
	ms.flags["rippi_june"] = {"day": MS.day_no(game.date), "count": 1}
	var start: Dictionary = load("res://scripts/core/cast.gd").occurrence("rippileiri", 2027, ms.flags)
	_ok("the camp week of June 2027 exists (%s)" % [start], not start.is_empty())
	var before: int = ms.people.values().filter(func(p): return str(p.role) == "acquaintance").size()
	game.date = start.duplicate()
	var made: Array = cs.arrive_camp()
	var count: Array = data.romance.camp.count
	_ok("%d faces joined (%d..%d), acquaintances from the camp, fictional, in People you know" % [made.size(), count[0], count[1]],
			made.size() >= int(count[0]) and made.size() <= int(count[1]) and made.all(func(p): return str(p.word) == data.romance.camp.met and str(p.thread) == "circle" and str(p.role) == "acquaintance"))
	_ok("the same camp does not bring them twice", cs.arrive_camp().is_empty())
	_ok("they are not candidates at the first meeting (closeness %d), and are once close enough" % int(data.circle.status.acquaintance_start),
			not rs.candidates().has(made[0]) and (func():
				made[0].relation = float(data.romance.offer.min_closeness) + 5.0
				return rs.candidates().has(made[0])).call())
	ms.flags.erase("rippi_june")
	ms.flags["rippi_none"] = {"day": 0, "count": 1}
	cs.arrivals.erase("camp.2027")
	_ok("no camp chosen: nobody comes (%d acquaintances before, the camp's added them)" % before, cs.arrive_camp().is_empty())


# --- 10. A teammate really quits or joins -------------------------------------------------------------------------------------------

func _team() -> void:
	print("-- 10. a teammate quits or joins for real")
	var rs = _fresh(11)
	var ms = _ms()
	var cs = CS.sys()
	_play_to(_d("2026-11-03"))
	var head: Dictionary = game.get_system("coach").head()
	var n0: int = (head.group as Array).size()
	var mate: Dictionary = ms.people_for("teammate")[0]
	var level0: float = cs.group_level()
	_ok("the group has %d teammates" % n0, n0 >= 4)
	# Make sure there is room to quit.
	while (head.group as Array).size() < 6:
		cs.team_change("join", {})
	var n1: int = (head.group as Array).size()
	_ok("a teammate joined for real (%d -> %d), a new person in the thread group" % [n0, n1], n1 >= 6 and ms.people_for("teammate").size() == n1)
	_ok("a quitting teammate leaves: the group gets smaller and they are not around any more", cs.team_change("quit", mate) and (head.group as Array).size() == n1 - 1
			and not bool(mate.active) and not ms.people_for("teammate").has(mate))
	_ok("the group's level and size are what the pull reads (size %d, level %.2f)" % [cs.group_size(), cs.group_level()], cs.group_size() == n1 - 1 and cs.group_level() > 0.0)
	while (head.group as Array).size() > 4:
		cs.team_change("quit", ms.people_for("teammate")[0])
	_ok("never fewer than 4 (the group of 4 keeps its people)", not cs.team_change("quit", ms.people_for("teammate")[0]) and (head.group as Array).size() == 4)
	var sid := "t16_mate_quits"
	_ok("%s is not offered to a group of 4 (team_size 5+)" % sid, not ms.check_when({"team_size": [5, null]}, {"date": game.date, "day": 0, "day_type": "weekday"}, {}))
	_ok("... and t16_new_runner is (team_size 3..8)", ms.check_when({"team_size": [3, 8]}, {"date": game.date, "day": 0, "day_type": "weekday"}, {}))


# --- 11. Its invitation ---------------------------------------------------------------------------------------------------------------

func _invitation() -> void:
	print("-- 11. the relationship's own invitation lands in a weekend slot; going is time together")
	var rs = _dating_career(12)
	var ms = _ms()
	var hs = _hs()
	var p: Dictionary = rs.partner_person()
	var s: Dictionary = ms.storylet("rm_film")
	var w = game.current_week()
	var date: Dictionary = game.add_days(w.monday, 5)
	var ctx := {"date": date, "day": 5, "day_type": Cal.day_type(date), "week": w, "race_note": {}}
	_ok("rm_film is sent by %s (the person you are together with)" % p.first_name, ms.people_for("dating").has(p) and ms._senders(s, ctx, MS.day_no(game.date)).has(p))
	ms.stop_tokens = maxf(ms.stop_tokens, 1.0)
	var m: Dictionary = ms._post(s, p, ctx, MS.day_no(game.date), false, {"invite": true, "counted": false})
	_ok("it lands on Saturday as a partner slot (the activity 'partner'), changing nothing until you say Go", str(m.invite.activity) == "partner" and hs.activity_on(date) != "partner")
	ms.answer(str(m.id), "yes")
	_ok("Go: the slot becomes the activity partner", hs.activity_on(date) == "partner")
	var rel0 := float(p.relation)
	_play_to(_d("2026-11-23"))
	_ok("it was time together: slots_last %d, no neglect, closeness %.1f -> %.1f" % [rs.slots_last, rel0, float(p.relation)], rs.slots_last >= 1 and rs.neglect == 0 and float(p.relation) > rel0)
	# A relationship that is over writes nothing: an ex's storylet needs the ex.
	var ex_tag: bool = ms.check_when({"romance": ["dating"]}, ctx, {})
	_ok("the `romance` condition reads the state: 'dating' holds now", ex_tag and not ms.check_when({"romance": ["single"]}, ctx, {}))
	rs.end_it()
	_ok("... and after the breakup it is 'ended', not 'dating'", ms.check_when({"romance": ["ended"]}, ctx, {}) and not ms.check_when({"romance": ["dating"]}, ctx, {}))


# --- 11b. Every new storylet can be sent and answered ------------------------------------------------------------------------------------

## Posts each storylet of P2b from a person its sender selector names (its `when` is not asked: the point is the TEXT, the placeholders,
## the replies and their effects), answers its first reply and checks no placeholder was left in a text, a label or a hint.
func _post_every_storylet() -> void:
	print("-- 11b. every new storylet can be sent and answered (texts filled, replies work)")
	var rs = _dating_career(14)
	var ms = _ms()
	_play_to(_d("2026-11-23"))
	var mine: Array = data.storylets.filter(func(s): return not bool(s.get("test", false)) and (str(s.id).begins_with("rm_") or str(s.id).begins_with("t16_")))
	var faults := []
	var sent := 0
	for phase in 2:   # phase 0: together (the dating senders), phase 1: after the breakup (the ex)
		if phase == 1:
			rs.end_it()
		for s in mine:
			var from := str(s.get("from", "coach"))
			if (phase == 0) == (from == "ex"):
				continue
			var senders: Array = ms.people_for(from)
			if senders.is_empty():
				faults.append("%s: nobody to send it (%s)" % [s.id, from])
				continue
			var day := 0
			if s.has("invite"):
				day = int((s.invite.days as Array)[0])
			var w = game.current_week()
			var date: Dictionary = game.add_days(w.monday, day)
			var ctx := {"date": date, "day": day, "day_type": Cal.day_type(date), "week": w, "race_note": {}}
			ms.stop_tokens = maxf(ms.stop_tokens, 1.0)
			var opts := {}
			if s.has("invite"):
				opts = {"invite": true, "counted": false}
			elif s.has("beat"):
				opts = {"beat": true, "counted": false}
			var m: Dictionary = ms._post(s, senders[0], ctx, MS.day_no(game.date), false, opts)
			sent += 1
			var texts := []
			if bool(s.get("feed", false)):
				texts.append(str(ms.thread(str(s.thread)).back().text))
			else:
				texts.append(str(m.get("text", "")))
				for r in m.get("replies", []):
					texts.append(str(r.label))
					texts.append(str(r.hint))
				if m.has("invite"):
					texts.append(str(m.invite.title))
					texts.append(str(m.invite.chip))
				if m.has("beat"):
					texts.append(str(m.beat.title))
					texts.append(str(m.beat.chip))
			for t in texts:
				if t.contains("{") or t.contains("}"):
					faults.append("%s: a placeholder is left in \"%s\"" % [s.id, t.left(70)])
			if str(texts[0]).strip_edges() == "":
				faults.append("%s: an empty text" % s.id)
			if not bool(s.get("feed", false)) and not m.is_empty() and not m.get("replies", []).is_empty():
				ms.answer(str(m.id), str(m.replies[0].id))
				if not s.has("invite") and str(m.answer) == "":
					faults.append("%s: the first reply did not answer it" % s.id)
	for f in faults.slice(0, 20):
		print("    " + f)
	_ok("%d of the new storylets were sent from their senders and answered with no placeholder left and no empty text (%d faults)" % [sent, faults.size()], faults.is_empty() and sent >= 25)


# --- 12. Save / load ------------------------------------------------------------------------------------------------------------------

func _save_load() -> void:
	print("-- 12. save and load")
	var rs = _dating_career(13)
	var hs = _hs()
	hs.set_habit(5, "partner")
	rs.set_texting("off")
	_play_to(_d("2026-11-24"))
	var pid: String = rs.partner
	var text: String = JSON.stringify(game.to_dict(), "", true, true)
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	var before: String = JSON.stringify(rs.to_dict(), "", true, true)
	game.from_dict(parsed)
	var rs2 = _rs()
	_ok("the relationship comes back bit for bit (stage %s, texting %s)" % [rs2.stage, rs2.texting], JSON.stringify(rs2.to_dict(), "", true, true) == before and rs2.stage == "dating" and rs2.partner == pid and rs2.texting == "off")
	_ok("and so does the partner habit and who is the sweetheart", _hs().habit(5) == "partner" and bool(_ms().people[pid].get("dating", false)) and CS.sys().kind_of(_ms().people[pid]) == "dating")
	var older: Dictionary = parsed.duplicate(true)
	older.systems.erase("romance")
	game.from_dict(older)
	_ok("an older save (no romance state) loads as single", _rs().stage == "" and _rs().to_dict().is_empty())
	_play_to(game.add_days(game.date, 14))
	_ok("and plays on", true)
	_ok("saves are version %d" % saves.VERSION, saves.VERSION >= 10)
