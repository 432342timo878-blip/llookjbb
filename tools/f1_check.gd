extends SceneTree
## Dev check (session F1, 2026-10-18): the 11 confirmed bugs of season playtest 2 (docs/PLAYTESTS.md's table), one part each.
## Every part failed before the fix and passes after it.
##   1. The coach's pronouns come from the coach's gender: no bare he / his / him in a player-visible data text (the developer
##      `_note`s, sources and the one friend "Joonas" aside), CoachSystem.words fills {he} {his} {v:a|b}, and with a woman as head
##      coach the help, the standing orders, a coach moment's hints and every hub tab say she / her (no placeholder left).
##   2. The race card's confidence line is "Confidence: Confident. You race ...", not "CONFIDENCE CONFIDENT: you race ...".
##   3. No confirmation-camp message comes after "I don't want to go" (rippi_none). (Session L3a: fr_rippi_together is gone.)
##   4. No message states a late night the game never played. (Session L3a: fam_screen is gone: late nights come from the slots.)
##   5. Adding mobility & stretching moves no strain, so no coach (even a load manager of 1) sees a risk in it.
##   6. A LIGHTER change that gives more training has its own reason (work_light), never "you're fresh enough for it".
##   7. A day the player asked the coach about gets no proposal of his.
##   8. Scratching from a race gets the coach's reaction in his thread (not when it was his own advice).
##   9. No coach closing line promises a mechanism ("tell me ... on Wednesday") or names the UI ("in the day view").
##  10. The habit goal's counter and the Sunday talk count "done" the same way (a day the coach lightened is not missed).
##  11. The Dev jump to a date answers the stop events with their defaults, runs the races and reaches the date.
##  + the player's own autosave (a copy) still loads and plays on.
## Run: godot --headless --path . -s res://tools/f1_check.gd      (~1 min; own save folder user://tool_saves/)
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var _fails := 0
var game
var data
var CS
var CV


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()
	# (a SCRIPT ERROR ends _run without quit(): the watchdog ends the run instead of hanging)
	create_timer(240.0).timeout.connect(func():
		print("  FAIL  the check did not finish (a SCRIPT ERROR? read stderr)")
		quit(1))


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _run() -> void:
	var SG = load("res://scripts/core/save_game.gd")
	SG.DIR = "user://tool_saves/"
	load("res://scripts/core/game_config.gd").fixed_seed = 7
	load("res://scripts/core/game_config.gd").use("real", {"health": true})
	await _frames(10)
	var main := current_scene
	var router = main.get_node("/root/Router")
	game = main.get_node("/root/Game")
	data = main.get_node("/root/Data")
	CS = load("res://scripts/core/coach_system.gd")
	CV = load("res://scripts/core/coach_verdict.gd")
	game.autosave = false
	router.go("new_career")
	await _frames(5)
	var wizard: Control = main.get_node("ScreenHost").get_child(-1)
	wizard._choices.first_name = "Aino"
	wizard._choices.last_name = "Virtanen"
	wizard._choices.gender = "female"
	wizard._choices.hometown = "Sastamala"
	wizard._choices.club_id = ""
	for q in data.background_questions:
		wizard._choices.answers[q.id] = 0
	for step in 4:
		wizard._on_next()
		await _frames(3)
	wizard._on_next()
	await _frames(5)
	var hub: Control = main.get_node("ScreenHost").get_child(-1)
	_answer_all()
	var cs = game.get_system("coach")
	var head: Dictionary = cs.head()
	head.gender = "female"   # (Marja's case: a woman as head coach)

	print("1. The coach's pronouns")
	_pronoun_data()
	if not _has_static(CS, "words"):
		_ok("CoachSystem.words exists (it fills the coach's pronouns)", false)
	else:
		_words()
	_help_pronouns()
	var ms = game.get_system("moments")
	# (session L3a: the coach's question topics are gone; a moment of his with the same hints, posted the way his moments are)
	var m: Dictionary = ms.post_custom("f1_check", "", "A test.", [{"id": "a", "label": "A", "hint": "{He} {v:keeps|keep} the plan"},
			{"id": "b", "label": "B", "hint": "{He} will remember"}], false)
	var hints := ", ".join(m.replies.map(func(r): return str(r.hint)))
	ms.moments.erase(m)
	_ok("a coach moment's hints say she ('%s')" % hints, hints.contains("She keeps the plan") and hints.contains("She will remember") and not hints.contains("{"))
	await _hub_pronouns(hub)

	print("2. The confidence line")
	var MUI = load("res://scripts/ui/mind_ui.gd")
	var line: String = MUI.race_text("Confident", 1.0) if _has_static(MUI, "race_text") else \
			str(data.mind.ui.race_line).format({"word": "CONFIDENT", "effect": str(data.mind.ui.race_faster)})   # (the old code's way)
	_ok("'%s'" % line, line == "Confidence: Confident. You race a little faster at a meet like this." and not line.to_lower().contains("confidence confident"))
	await _rest(ms, SG)


func _words() -> void:
	_ok("CoachSystem.words: she", CS.words("{He} {v:changes|change} {his} plan {himself}; ask {him}.", {"gender": "female"}) == "She changes her plan herself; ask her.")
	_ok("CoachSystem.words: they (a real coach whose sources state none)", CS.words("{He} {v:changes|change} {his} plan.", {"gender": "unknown"}) == "They change their plan.")
	_ok("CoachSystem.words: he", CS.words("{he} {v:says|say} {his}", {"gender": "male"}) == "he says his")
	_ok("CoachSystem.words leaves other placeholders alone", CS.words("{meet} {He}", {"gender": "female"}) == "{meet} She")


func _rest(ms, SG) -> void:
	print("3. The rippi question")
	_rippi(ms)

	print("4. The phone at night")
	_phone(ms)

	print("5. Mobility & stretching and the coach's noise")
	_mobility()

	print("6. The reason of a lighter change")
	_lighter()

	print("7. Ask the coach, then no proposal on that day")
	_asked()

	print("8. The coach's reaction to a scratch")
	_scratch(ms)

	print("9. Closing lines without promises or UI names")
	_closing_lines()

	print("10. One 'done'")
	_one_done()

	print("11. The Dev jump")
	var DT = load("res://scripts/core/dev_tools.gd")
	var target: Dictionary = game.add_days(game.date, 70)
	var res: Dictionary = DT.jump(target, true) if _argc(DT, "jump") >= 2 else DT.jump(target)
	_ok("a jump of 70 days reaches its date (%d days, %d stops answered, %d races run)" % [res.days, res.get("stops", 0), res.get("races", 0)],
			load("res://scripts/core/calendar.gd").date_key(game.date) == load("res://scripts/core/calendar.gd").date_key(target) and int(res.get("stops", 0)) > 0)
	_ok("no stop event waits after it", game.pending_event().is_empty())
	_answer_all()

	print("The player's own autosave (a copy)")
	await _user_save(SG)

	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


# --- 1 ------------------------------------------------------------------------------------------------------

const PRONOUN := "(?<!\\{)\\b(he|his|him|himself|He|His|Him|Himself)\\b(?!\\})"   # (a {placeholder} is not bare)
const ALLOWED := {"friends.json": ["His parents are away"]}   # (Joonas, a friend of the cast, is a boy)


func _pronoun_data() -> void:
	var rx := RegEx.create_from_string(PRONOUN)
	var found := []
	for f in _json_files("res://data"):
		_walk(JSON.parse_string(FileAccess.get_file_as_string(f)), f.get_file(), "", rx, found)
	for x in found.slice(0, 8):
		print("        bare pronoun: " + x)
	_ok("no bare he / his / him in a player-visible data text (%d found)" % found.size(), found.is_empty())


func _walk(v, file: String, path: String, rx: RegEx, found: Array) -> void:
	if v is Dictionary:
		for k in v:
			if str(k).begins_with("_") or str(k) in ["sources", "basis", "facts", "athletes_coached", "pronouns"]:
				continue
			_walk(v[k], file, path + "." + str(k), rx, found)
	elif v is Array:
		for i in v.size():
			_walk(v[i], file, path + "[%d]" % i, rx, found)
	elif v is String and rx.search(v) != null:
		for allowed in ALLOWED.get(file, []):
			if v.contains(allowed):
				return
		found.append("%s %s: %s" % [file, path, v.substr(0, 90)])


func _json_files(dir: String) -> Array:
	var out := []
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_json_files(dir + "/" + d))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(dir + "/" + f)
	return out


## Every help entry as the help panel shows it, with the woman as head coach.
func _help_pronouns() -> void:
	var rx := RegEx.create_from_string(PRONOUN)
	var bad := []
	var shes := 0
	var ids: Array = data.help.screens.keys() + data.help.topics.keys()
	for id in ids:
		var panel = load("res://scripts/ui/help_panel.gd").new()
		root.add_child(panel)
		panel.show_entry(str(id))
		for t in _texts(panel):
			if rx.search(t) != null or t.contains("{he") or t.contains("{He") or t.contains("{his") or t.contains("{v:"):
				bad.append("%s: %s" % [id, t.substr(0, 80)])
			if t.contains("she ") or t.contains("She ") or t.contains(" her "):
				shes += 1
		panel.queue_free()
	for x in bad.slice(0, 5):
		print("        " + x)
	_ok("the help says she / her for a woman coach (%d lines with she / her, %d with he or a placeholder)" % [shes, bad.size()], bad.is_empty() and shes >= 20)
	var heading := ""
	for sct in data.help.topics.ask_coach.sections:
		heading = load("res://scripts/ui/ui_kit.gd").label(str(sct.heading)).text
		break
	_ok("the help's 'What he answers' is now '%s'" % heading, heading == "What she answers")


## Every hub tab after a few days: no placeholder left, and the standing orders' coach setting says she.
func _hub_pronouns(hub: Control) -> void:
	for i in 3:
		_answer_all()
		var r: String = game.advance_day()
		if r == game.RACE:
			_run_race()
	_answer_all()
	hub._refresh_week_ui()
	var leftovers := []
	var training := ""
	# (session L1a: the tabs This week / Season / Calendar / People / Career / Rankings and the report page)
	for v in ["week", "season", "calendar", "rankings", "report", "people", "career"]:
		hub._show(v)
		await _frames(4)
		for t in _texts(hub):
			if t.contains("{he") or t.contains("{He") or t.contains("{his") or t.contains("{His") or t.contains("{him") or t.contains("{v:"):
				leftovers.append("%s: %s" % [v, t.substr(0, 80)])
			if v == "season":
				training += t + "\n"
	for x in leftovers.slice(0, 5):
		print("        " + x)
	_ok("no pronoun placeholder is left in any hub tab (%d)" % leftovers.size(), leftovers.is_empty())
	_ok("the Season tab's standing orders say 'she writes a note on a day she would change'",
			training.contains("she writes a note on a day she would change"))


# --- 3, 4 -------------------------------------------------------------------------------------------------

## Session L3a: fr_rippi_together is gone (the sort); the camp's own messages (packing, the camp week) never come after "I don't
## want to go" and do come with a camp chosen.
func _rippi(ms) -> void:
	var CA = load("res://scripts/core/cast.gd")
	var birth := int(game.athlete.birth_date.year)
	var start: Dictionary = CA.occurrence("rippileiri", birth + 15, {"rippi_july": {}})
	var flags_before: Dictionary = ms.flags.duplicate(true)
	var bad := []
	for pair in [["fam_rippi_leaving", -1], ["fr_rippi_camp", 2]]:
		var s: Dictionary = ms.storylet(str(pair[0]))
		var d: Dictionary = game.add_days(start, int(pair[1]))
		var ctx := {"date": d, "day": 0, "day_type": "weekday"}
		ms.flags = {"rippi_none": {"day": 0, "count": 1}}
		if s.is_empty() or ms.check_when(s.when, ctx, {}):
			bad.append("%s after 'none'" % pair[0])
		ms.flags = {"rippi_july": {"day": 0, "count": 1}}
		if s.is_empty() or not ms.check_when(s.when, ctx, {}):
			bad.append("%s missing after 'July'" % pair[0])
	ms.flags = flags_before
	_ok("after 'I don't want to go' no camp message comes; after 'The July camp' they do (%s)" % ", ".join(bad), bad.is_empty())
	_ok("the friends' camp question is gone (L3a)", ms.storylet("fr_rippi_together").is_empty())


## Session L3a: fam_screen is gone (late nights come from the evening slots); no message that asks nothing states a late night.
func _phone(ms) -> void:
	_ok("fam_screen is gone (late nights come from your evening slots since L1b)", ms.storylet("fam_screen").is_empty())
	var bad := []
	for s in data.storylets:
		if bool(s.get("feed", false)):
			for t in s.text:
				var text := str(t.text) if t is Dictionary else str(t)
				if text.contains("one o'clock") or text.contains("you stayed up") or text.contains("until one"):
					bad.append(str(s.id))
	_ok("no message that asks nothing states a late night of yours (%s)" % ", ".join(bad), bad.is_empty())


# --- 5, 6, 7 -----------------------------------------------------------------------------------------------

## A day of this week that can still be changed and has 1 session (or none).
func _free_day(max_sessions := 1) -> int:
	var w = game.current_week()
	for d in range(w.day, 7):
		if w.can_change(d) and not w.changes.has(d) and w.session_ids(d).size() <= max_sessions and not w.session_ids(d).is_empty():
			return d
	return -1


func _weak_coach() -> Dictionary:
	var attrs := {}
	for at in data.coaching.attributes:
		attrs[at.id] = 1
	return {"id": "f1_weak", "attributes": attrs, "demands": "balanced", "voice": "calm"}


func _mobility() -> void:
	var d := _free_day()
	if d < 0:
		_ok("a free day with one session this week", false)
		return
	var w = game.current_week()
	var cur: Dictionary = CV.day_now(w, d)
	var cand := {"sessions": cur.sessions + ["mobility"], "intensity": cur.intensity}
	var change: Dictionary = CV.day_change({d: cur}, {d: cand}, "day_changed")
	var t: Dictionary = CV.truth(change)
	var dm := float(data.coaching.verdict.demands.balanced.risk)
	var off := 0
	var weak := _weak_coach()
	for seed in 300:
		var seen: Dictionary = CV.perceive(t, weak, seed)
		if not is_equal_approx(float(seen.risk), float(t.risk_w) * dm):
			off += 1
	_ok("adding mobility moves no strain (%s)" % str(t.get("strain_moved", "?")), float(t.get("strain_moved", -1.0)) == 0.0)
	_ok("a coach with load management 1 sees no risk in it on any of 300 days (%d saw one)" % off, off == 0)
	# (his eye still works where the strain moves: a hill session added)
	var hill := {"sessions": cur.sessions + ["hill_sprints"], "intensity": cur.intensity}
	var t2: Dictionary = CV.truth(CV.day_change({d: cur}, {d: hill}, "day_changed"))
	var varied := 0
	for seed in 50:
		if not is_equal_approx(float(CV.perceive(t2, weak, seed).risk), float(t2.risk_w) * dm):
			varied += 1
	_ok("... while hill sprints added (strain %.2f) still go through his noise (%d of 50 days)" % [float(t2.get("strain_moved", -1.0)), varied], varied > 25)


func _lighter() -> void:
	var w = game.current_week()
	var d := -1
	for x in range(w.day, 7):
		if w.can_change(x) and not w.session_ids(x).is_empty() and str(w.intensity(x)) != "easy":
			d = x
			break
	if d < 0:
		_ok("a day above Easy this week", false)
		return
	if not _has_static(CV, "reason_for"):
		_ok("CoachVerdict.reason_for exists (a lighter change's 'work' has its own words)", false)
		return
	var cur: Dictionary = CV.day_now(w, d)
	var lighter: Dictionary = CV.day_change({d: cur}, {d: {"sessions": cur.sessions, "intensity": "easy"}}, "day_changed", [], "proposal")
	var heavier: Dictionary = CV.day_change({d: cur}, {d: {"sessions": cur.sessions, "intensity": "hard"}}, "day_changed", [], "proposal")
	_ok("'work' on a lighter change becomes 'work_light'", CV.reason_for("work", lighter) == "work_light")
	_ok("'work' on a heavier change stays 'work'", CV.reason_for("work", heavier) == "work")
	var said: String = CV.say({"reason": "work_light", "verdict": "good"}, CV.truth(lighter), lighter, CV.head_view())
	_ok("his words for it: '%s'" % said, said != "" and not said.contains("fresh enough") and not said.contains("can take it"))


func _asked() -> void:
	var cp = game.get_system("proposals")
	var w = game.current_week()
	var d := -1
	for x in range(w.day, 7):
		if cp._free_day(w, x):
			d = x
			break
	if d < 0:
		_ok("a free day for a proposal this week", false)
		return
	var ask = load("res://scripts/ui/coach_ask.gd").new("day", func(): return CV.for_day(d))
	root.add_child(ask)
	ask.press()
	ask.queue_free()
	var date: Dictionary = game.add_days(w.monday, d)
	if not cp.has_method("asked_about"):
		_ok("after Ask the coach about day %d he makes no proposal for it (old code: no memory of the question)" % d, cp._free_day(w, d) == false)
		return
	_ok("after Ask the coach about day %d it is remembered" % d, cp.asked_about(date))
	_ok("... and he makes no proposal for that day", not cp._free_day(w, d))
	var again = load("res://scripts/core/coach_proposals.gd").new()
	again.from_dict(cp.to_dict())
	_ok("... also after a save and a load", again.asked_about(date))


# --- 8 -----------------------------------------------------------------------------------------------------

func _scratch(ms) -> void:
	var Cal = load("res://scripts/core/calendar.gd")
	var keys := []
	for m in Cal.meets_between(game.add_days(game.date, 3), game.add_days(game.date, 200)):
		if not m.key in game.entries and Cal.can_enter(game.athlete, m, game.date).ok:
			keys.append(m)
		if keys.size() >= 2:
			break
	if keys.size() < 2:
		_ok("two meets to enter", false)
		return
	game.enter(keys[0].key)
	var before: int = ms.thread("coach").size()
	game.scratch_race(keys[0].key)
	var after: Array = ms.thread("coach")
	var last: Dictionary = after.back() if not after.is_empty() else {}
	_ok("scratching %s: the coach writes ('%s')" % [keys[0].name, str(last.get("text", ""))],
			after.size() == before + 1 and str(last.text).contains(str(keys[0].name)) and not str(last.from) in ["you", "system"])
	if _argc(game, "scratch_race") < 2:
		_ok("scratch_race knows who scratched (his own advice gets no second reaction)", false)
		return
	game.enter(keys[1].key)
	before = ms.thread("coach").size()
	game.scratch_race(keys[1].key, "coach")
	_ok("... but not when the scratch was his own advice (he has answered already)", ms.thread("coach").size() == before)


# --- 9 -----------------------------------------------------------------------------------------------------

const PROMISE := "(?i)\\btell me\\b|\\bask (me|for)\\b|day view|training tab|people tab|the overview|you see it|you can see it"


func _closing_lines() -> void:
	var rx := RegEx.create_from_string(PROMISE)
	var bad := []
	var ct: Dictionary = data.coach_talk
	var lines := []
	lines.append_array(ct.talk.focus.values().filter(func(x): return x is String))
	lines.append_array(ct.talk.focus.phase.values())
	for v in ct.voices.values():
		lines.append_array(v.comment.values())
		lines.append_array(v.close)
		lines.append_array(v.race.values())
		lines.append_array(v.day.values())
	for v in ct.proposal.answered.values():
		lines.append_array(v.values())
	for v in data.mind.coach.lines.values():
		lines.append_array(v.values())
	for k in ["week_talk.json", "mind_talk.json"]:
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://data/storylets/" + k))
		for s in j.storylets:
			for r in s.get("replies", []):
				lines.append(str(r.get("result", "")))
	for t in lines:
		if rx.search(str(t)) != null:
			bad.append(str(t))
	for x in bad.slice(0, 6):
		print("        " + x)
	_ok("no coach closing line or reply result promises a mechanism or names the UI (%d of %d lines)" % [bad.size(), lines.size()], bad.is_empty())


# --- 10 ----------------------------------------------------------------------------------------------------

func _one_done() -> void:
	var WS = load("res://scripts/core/week_sim.gd")
	var Ath = load("res://scripts/core/athlete.gd")
	var monday: Dictionary = game.add_days(game.current_week().monday, 7)
	var a = Ath.from_dict(game.athlete.to_dict().duplicate(true))
	var w = WS.new(a, game.season.week_for(monday), monday, {})
	var days := []
	for d in 7:
		if not w.plan[d].is_empty():
			days.append(d)
	if days.size() < 3:
		_ok("a week with 3+ training days", false)
		return
	w.make_rest_day(days[0], "coach")    # the coach lightened it: not a missed day
	w.make_rest_day(days[1], "player")   # the player's own rest day: missed
	while not w.is_over():
		w.play_day()
	var talk: Dictionary = load("res://scripts/core/coach_talk.gd")._last_week(w)
	var goals = game.get_system("goals")
	for rec in w.played:
		goals._count_day({"record": rec, "week": w, "day": int(rec.day), "date": game.add_days(monday, int(rec.day))}, 9999)
	var c: Dictionary = goals.counts.get(9999, {"planned": 0, "done": 0})
	goals.counts.erase(9999)
	var missed := int(w.plan[days[1]].size())
	_ok("the Sunday talk and the habit goal agree: talk %d of %d, goal %d of %d" % [talk.done, talk.planned, int(c.done), int(c.planned)],
			int(talk.done) == int(c.done) and int(talk.planned) == int(c.planned))
	_ok("... the coach's rest day is not missed, the player's own is (%d missed)" % (int(talk.planned) - int(talk.done)),
			int(talk.planned) - int(talk.done) == missed)


# --- The player's save --------------------------------------------------------------------------------------

func _user_save(SG) -> void:
	var src := "user://saves/autosave.json"
	if not FileAccess.file_exists(src):
		print("        (no autosave of the player on this computer: skipped)")
		return
	var text := FileAccess.get_file_as_string(src)
	var f := FileAccess.open(SG.DIR + "f1_player_copy.json", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var loaded: bool = SG.load_slot("f1_player_copy")
	_ok("a copy of the player's autosave loads (%s, %s)" % [game.athlete.full_name() if game.athlete else "-", game.date], loaded)
	if not loaded:
		return
	var start: Dictionary = game.date.duplicate()
	var guard := 0
	while load("res://scripts/core/calendar.gd").days_between(start, game.date) < 7 and guard < 40:
		guard += 1
		_answer_all()
		var r: String = game.advance_day()
		if r == game.RACE:
			_run_race()
	_ok("... and plays a week on (today %s)" % [game.date], load("res://scripts/core/calendar.gd").days_between(start, game.date) >= 7)
	SG.delete("f1_player_copy")


# --- Helpers -----------------------------------------------------------------------------------------------

func _answer_all() -> void:
	var n := 0
	while not game.pending_event().is_empty() and n < 30:
		var e: Dictionary = game.pending_event()
		var choices: Array = e.get("choices", [])
		game.answer_event(e.id, str(choices[0].id) if str(e.get("kind", "")) == "moment" and not choices.is_empty() else "ok")
		n += 1


## A script's static function by name (the check runs on the code from before the fixes too: a missing one is a FAIL, not a crash).
func _has_static(script, fname: String) -> bool:
	for m in script.get_script_method_list():
		if str(m.name) == fname:
			return true
	return false


## How many arguments an object's (or a script's) method takes; -1 = no such method.
func _argc(obj, fname: String) -> int:
	var list: Array = obj.get_script_method_list() if obj is Script else obj.get_method_list()
	for m in list:
		if str(m.name) == fname:
			return (m.args as Array).size()
	return -1


func _run_race() -> void:
	var rd = game.race_day
	while not rd.is_done():
		rd.start_round(false, "pack").run()
		rd.finish_round()
	game.finish_race()


func _texts(node: Node) -> Array:
	var out := []
	if (node is Label or node is Button) and (node as Control).is_visible_in_tree():
		out.append(str(node.text))
	elif node is Label or node is Button:
		out.append(str(node.text))
	for c in node.get_children():
		out.append_array(_texts(c))
	return out


func _frames(n: int) -> void:
	for i in n:
		await process_frame
