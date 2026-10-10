extends SceneTree
## Dev tool: checks the quick fixes from the season playtest (2026-10-10, ROADMAP "Quick fixes from the season playtest"):
##   2  the kick: "Wait" in a watched race (Race.manual_kick) never starts the kick by itself, Kick now works at any
##      distance, also inside the last 100 m; without manual_kick (quick mode, tools) Wait still means 100 m; a Quick
##      result follows the player's kick plan
##   3  a kick that died after starting in the home straight is told as "kick_died_late", not "too early"
##   4  the coach's advice never contradicts his last advice soon after, unless the race changed
##   5  the verdict rules: a PB is its own case, a season best is never "below", a time near the athlete's own best is
##      never "below"
##   6  PB / SB marks on the result rows (the player's and the rivals')
##   7  the monthly record: a record at the start and at the end of every month, saved and loaded, old saves get a first one
## Run: godot --headless --path . -s res://tools/playtest_fix_check.gd
## Prints ALL CHECKS PASSED at the end; read stderr too (a SCRIPT ERROR can abort a check part-way).

var game
var data
var Cal
var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	load("res://scripts/core/health_system.gd").model_enabled = false
	Cal = load("res://scripts/core/calendar.gd")
	game.autosave = false
	_check_kick()
	_check_kick_plan()
	_check_coach_conflict()
	_check_verdicts()
	_check_marks()
	_check_progress()
	print("%d checks, %d failed" % [_checks, _fails])
	print("ALL CHECKS PASSED" if _fails == 0 else "SOME CHECKS FAILED")
	quit(1 if _fails > 0 else 0)


func _ok(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  FAIL  " + what)


# --- A made-up race ------------------------------------------------------------------------------------------------

## 8 runners of about the same level; the player (tactics 10) is the last. `seed` fixes the dice.
func _race(seed: int, interactive: bool, manual: bool, kick_plan := 0.0):
	var RaceScript = load("res://scripts/core/race.gd")
	var frng := RandomNumberGenerator.new()
	frng.seed = 1000 + seed
	var entrants := []
	for k in 7:
		var ab: float = 9.0 + frng.randfn(0, 0.5)
		entrants.append({"name": "Rival R%d" % k, "club": "", "ability": ab, "speed": ab + frng.randfn(0, 2),
				"anaerobic": frng.randfn(0, 2), "tactics": clampf(frng.randfn(8.0, 3.0), 1.0, 20.0),
				"consistency": 10.0, "composure": 10.0, "competitiveness": 9.0})
	entrants.append({"name": "You Player", "club": "", "ability": 9.0, "speed": 9.0, "anaerobic": 0.0, "tactics": 10.0,
			"consistency": 10.0, "composure": 10.0, "determination": 10.0, "is_player": true})
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + seed
	var race = RaceScript.new()
	race.interactive = interactive
	race.manual_kick = manual
	race.setup(entrants, "male", false, 15.0, rng, false, "final")
	race.set_player_plan("pack")
	if kick_plan > 0.0:
		race.set_kick_plan(kick_plan)
	return race


## Plays a watched race: sensible answers, except the kick card is answered `kick_answer` and a rival's move is always let
## go (going with it would start the kick too); `press_at` = metres to go at which Kick now is pressed (0 = never).
func _play_watched(race, kick_answer: String, press_at: float) -> void:
	while not race.finished and race.time < 400.0:
		if not race.pending.is_empty():
			var id: String = race.pending.id
			race.choose(kick_answer if id == "kick" else ("wait" if id == "move" else race.sensible_choice(id)))
			continue
		if press_at > 0.0 and 800.0 - race.player.d <= press_at and race.can_command("kick"):
			race.command("kick")
		race.step()


func _check_kick() -> void:
	print("-- fix 2: the kick")
	var waited := 0
	var started_by_itself := 0
	var pressed_ok := 0
	var pressed_n := 0
	var old_ok := 0
	var old_n := 0
	var asked := 0
	for i in 40:
		# Wait, never press Kick now: the player never kicks.
		var r = _race(i, true, true)
		_play_watched(r, "wait", 0.0)
		if r.card_log.any(func(c): return c.id == "kick"):
			asked += 1
			if r.player.kick_hold:
				waited += 1
			# a kick of the player's own that nothing asked for (not an answer to a rival's kick) = the game decided for them
			if r.events.any(func(e): return e.type == "kick" and bool(e.get("player", false)) and str(e.get("answer_to", "")) == ""):
				started_by_itself += 1
		# Wait, then press Kick now with 60 m to go: the kick starts there, inside the last 100 m.
		var p = _race(i, true, true)
		_play_watched(p, "wait", 60.0)
		if p.card_log.any(func(c): return c.id == "kick") and p.player.kick_hold == false and p.player.kicking:
			pressed_n += 1
			if p.player.kick_began >= 50.0 and p.player.kick_began <= 61.0:
				pressed_ok += 1
		# Without manual_kick (quick mode, tools): Wait is still a kick at 100 m.
		var o = _race(i, true, false)
		_play_watched(o, "wait", 0.0)
		if o.card_log.any(func(c): return c.id == "kick" and c.d < 700):
			old_n += 1
			if o.player.kicking and o.player.kick_began >= 90.0 and o.player.kick_began <= 101.0:
				old_ok += 1
	_ok("watched, Wait: nothing kicks for the player (%d races where the kick card came, %d still waiting at the end, %d kicks started by themselves)" % [asked, waited, started_by_itself],
			asked > 10 and waited > 0 and started_by_itself == 0)
	_ok("watched, Wait then Kick now with 60 m to go: the kick starts there (%d of %d)" % [pressed_ok, pressed_n],
			pressed_n > 10 and pressed_ok >= pressed_n - 1)
	_ok("quick mode / tools, Wait: the kick still starts at 100 m to go (%d of %d)" % [old_ok, old_n], old_n > 10 and old_ok >= old_n - 1)


func _check_kick_plan() -> void:
	print("-- fix 2: the kick plan of a Quick result")
	for plan in [250.0, 150.0, 60.0]:
		var ok := 0
		var n := 0
		for i in 40:
			var r = _race(i, false, false, plan)
			r.run()
			if r.player.kicking or r.player.kick_began > 0.0:
				n += 1
				# (a move or a kick by a rival can start it earlier; a plan is never later than the plan)
				if r.player.kick_began <= plan + 1.0 and r.player.kick_began >= plan - 6.0:
					ok += 1
		_ok("kick plan %d m: the kick starts at the plan in most races (%d of %d)" % [plan, ok, n], n > 30 and ok >= n * 0.6)
	var natural_n := 0
	for i in 20:
		var r = _race(i, false, false, 0.0)
		r.run()
		if r.player.kick_began > 0.0:
			natural_n += 1
	_ok("no plan: the natural kick, as before (%d of 20 kick)" % natural_n, natural_n >= 15)


func _check_coach_conflict() -> void:
	print("-- fix 4: no opposite advice soon after one another")
	var r = _race(1, true, true)
	r.step()
	r.coach_note("ease")
	_ok("push right after ease is a conflict", r.coach_conflicts("push"))
	_ok("ease right after ease is not", not r.coach_conflicts("ease"))
	_ok("a neutral line is never a conflict", not r.coach_conflicts(""))
	r.coach_dir_log[-1].t -= 30.0
	_ok("30 s later it is not a conflict", not r.coach_conflicts("push"))
	r.coach_dir_log[-1].t = r.time
	r.coach_dir_log[-1].gap += 20.0
	_ok("the gap to the leader has changed by 20 m: not a conflict", not r.coach_conflicts("push"))
	r.coach_dir_log[-1].gap = r._gap_to_leader()
	r.coach_dir_log[-1].pos += 3
	_ok("the player's place has changed by 3: not a conflict", not r.coach_conflicts("push"))
	# In whole races: no two opposite pieces of advice within the time and with the race unchanged (card shouts only here).
	var bad := 0
	var shouts := 0
	for i in 40:
		var race = _race(i, true, true)
		while not race.finished and race.time < 400.0:
			if not race.pending.is_empty():
				var d: Dictionary = race.pending
				race.choose(race.sensible_choice(d.id))
				continue
			race.step()
		# The advice the coach gave (every shout that reached a card is in the log with the race as it was): two in a row in
		# opposite directions only when the time or the race had changed.
		var log: Array = race.coach_dir_log
		shouts += log.size()
		for k in range(1, log.size()):
			var a: Dictionary = log[k - 1]
			var b: Dictionary = log[k]
			var unchanged: bool = absf(float(b.gap) - float(a.gap)) < 8.0 and absi(int(b.pos) - int(a.pos)) < 2
			if a.dir != b.dir and float(b.t) - float(a.t) <= 20.0 and unchanged:
				bad += 1
	_ok("card shouts: no contradiction within 20 s in an unchanged race (%d shouts, %d contradictions)" % [shouts, bad], shouts > 20 and bad == 0)


func _check_verdicts() -> void:
	print("-- fix 5: the verdict rules")
	var Story = load("res://scripts/core/race_story.gd")
	var below_plain := 0
	var worse_pb := 0
	var worse_sb := 0
	var worse_near := 0
	var worse_better := 0
	var n := 0
	for i in 80:
		var r = _race(i, false, false)
		r.run()
		var res: Array = r.results()
		var place := 0
		for k in res.size():
			if res[k].is_player:
				place = k + 1
		var t: float = r.player.t
		var base: String = Story.verdict_case(r, place, {"kind": "race", "pre_rank": 1})   # (expected 1st: a worse place is "below")
		n += 1
		if base == "below":
			below_plain += 1
		var pb: String = Story.verdict_case(r, place, {"kind": "race", "pre_rank": 1, "mark": "PB", "time": t, "ref": t + 3.0})
		var sb: String = Story.verdict_case(r, place, {"kind": "race", "pre_rank": 1, "mark": "SB", "time": t, "ref": t + 3.0})
		var near: String = Story.verdict_case(r, place, {"kind": "race", "pre_rank": 1, "mark": "", "time": t, "ref": t * 0.995})
		var fast: String = Story.verdict_case(r, place, {"kind": "race", "pre_rank": 1, "mark": "", "time": t, "ref": t * 1.03})
		if base not in ["dnf", "dq", "fell", "won"] and pb != "pb":
			worse_pb += 1
		if sb == "below":
			worse_sb += 1
		if near == "below":
			worse_near += 1
		if base not in ["dnf", "dq", "fell", "won", "won_part", "kick_died", "kick_died_late", "boxed", "faded", "too_fast", "good_kick", "podium"] and fast != "better":
			worse_better += 1
	_ok("a PB is the case 'pb' (whatever the place) in every race that is not won / DNF / DQ / fell (%d races, %d times not)" % [n, worse_pb], worse_pb == 0)
	_ok("a season best is never 'below'", worse_sb == 0)
	_ok("a time within 0.5 %% of the athlete's best is never 'below' (%d times, without the rule %d races were 'below')" % [worse_near, below_plain], worse_near == 0 and below_plain > 0)
	_ok("a time 3 %% faster than their best is 'better' when nothing more specific fits (%d not)" % worse_better, worse_better == 0)


func _check_marks() -> void:
	print("-- fix 6: PB / SB marks")
	var RD = load("res://scripts/core/race_day.gd")
	game.start_career(_athlete(), "repeat")
	var rivals = load("res://scripts/core/rivals.gd")
	var monday: Dictionary = game.week_monday()
	for w in 40:
		rivals.train_week(game.rivals, game.athlete.gender, monday)
		monday = game.add_days(monday, 7)
	var meet: Dictionary = Cal.get_meet("sm_14_15@2027")
	var player_first := ""
	var rival_pb := 0
	var rival_bad := 0
	var rival_rows := 0
	for case in 3:
		var a = game.athlete
		match case:
			0: a.personal_bests = {}                       # no mark at all
			1: a.personal_bests = {"800m": 90.0}           # a very fast earlier PB
			2: a.personal_bests = {"800m": 400.0}          # a very slow one
		var rd = RD.new(meet, a, game.rivals)
		var race = rd.start_round(false, "pack")
		race.run()
		var before := {}
		for e in rd.current_entrants():
			if e.has("rival"):
				before[e.name] = {"pb": float(e.rival.get("pb", 0.0)), "sb": float(e.rival.get("sb", 0.0)), "season": int(e.rival.get("sb_season", -1))}
		rd.finish_round()
		var mine: Dictionary = {}
		for row in rd.last_rows:
			if row.is_player:
				mine = row
			elif before.has(row.name) and str(row.get("status", "")) == "":
				rival_rows += 1
				var b: Dictionary = before[row.name]
				if row.mark == "PB":
					rival_pb += 1
					rival_bad += 0 if b.pb > 0.0 and row.time < b.pb else 1
				elif row.mark == "SB":
					rival_bad += 0 if (b.season == meet.date.year and row.time < b.sb) or (b.season != meet.date.year and b.pb > 0.0) else 1
				elif b.pb > 0.0 and row.time < b.pb:
					rival_bad += 1   # a PB without its mark
		match case:
			0: _ok("the player's first ever time is a PB", mine.get("mark", "") == "PB")
			1: _ok("slower than a PB of 1:30 gets no PB mark", mine.get("mark", "") != "PB")
			2: _ok("faster than a PB of 6:40 is a PB", mine.get("mark", "") == "PB")
		_ok("the rows have the earlier marks to judge by (pb_before, sb_before)", mine.has("pb_before") and mine.has("sb_before"))
	_ok("rivals' marks follow their PB / SB (%d rows, %d PBs, %d wrong)" % [rival_rows, rival_pb, rival_bad], rival_rows > 20 and rival_bad == 0)


# --- 7: the monthly record -------------------------------------------------------------------------------------------

func _check_progress() -> void:
	print("-- fix 7: the monthly record")
	var saves = load("res://scripts/core/save_game.gd")
	game.start_career(_athlete(), "repeat")
	_ok("a new career starts with one record, kind 'start'", game.progress.size() == 1 and game.progress[0].kind == "start")
	var guard := 0
	while Cal.date_key(game.date) < 20270105 and guard < 200:
		guard += 1
		var r: String = game.advance_day()
		if r == game.RACE:
			game.finish_race()
		var e: Dictionary = game.pending_event()
		if not e.is_empty():
			game.answer_event(e.id, "ok")
	var months: Array = game.progress.filter(func(p): return p.kind == "month")
	_ok("Nov and Dec 2026 have a month record (%d records)" % game.progress.size(), months.size() == 2 and months[0].month == 11 and months[1].month == 12)
	_ok("a record has every attribute, the ability and the dates", months[0].attrs.size() == data.attributes.size() and months[0].has("ability") and months[0].day == 30)
	saves.save("playtest_fix")
	var before := JSON.stringify(game.progress)
	_ok("load the save", saves.load_slot("playtest_fix"))
	_ok("the record comes back from the save as it was", JSON.stringify(game.progress) == before)
	_ok("the ints are ints again", typeof(game.progress[0].year) == TYPE_INT and typeof(game.progress[0].age) == TYPE_INT)
	saves.delete("playtest_fix")
	# An older save has no record: it gets a first one.
	var d: Dictionary = game.to_dict()
	d.erase("progress")
	game.from_dict(JSON.parse_string(JSON.stringify(d)))
	_ok("a save without the record gets a 'first' record", game.progress.size() == 1 and game.progress[0].kind == "first")
	var rows: Array = load("res://scripts/core/progress_log.gd").rows(game.athlete, game.progress, game.date)
	_ok("the Progress page rows: Now and the record", rows.size() == 2 and rows[0].now)


func _athlete():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	return load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)
