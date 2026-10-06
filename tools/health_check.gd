extends SceneTree
## Dev tool: headless checks for the health model (GDD 4.6, HealthSystem). Prints PASS / FAIL per check.
## Run: godot --headless --path . -s res://tools/health_check.gd
## Uses its own save folder, never the player's saves.

const HARD := [["intervals_800", "strength"], ["tempo_run", "drills"], ["long_run"], ["intervals_800", "hill_sprints"],
		["tempo_run"], ["long_run", "speed_strides"], ["fartlek"]]

var game
var data
var saves
var Cal
var H
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Loaded at runtime: autoload names (Data, Game) only exist once the tree is running.
	game = root.get_node("Game")
	data = root.get_node("Data")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	Cal = load("res://scripts/core/calendar.gd")
	H = load("res://scripts/core/health_system.gd")
	game.autosave = false

	_check_data()
	_check_determinism()
	_check_stop_events()
	_check_restrictions()
	_check_override()
	_check_locked_race()
	_check_illness_and_racing()
	_check_midinjury_save()
	_check_old_saves()
	_check_model_off()
	_check_detraining()
	_check_ui_data()
	_check_rivals()
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


# --- Checks ------------------------------------------------------------------------------------

## Every injury's phases use known restrictions, escalations point at real injuries, every session's
## strain uses known areas and its "instead" sessions exist.
func _check_data() -> void:
	print("-- data")
	var areas := {}
	for a in H.areas():
		areas[a.id] = true
	var bad := []
	for inj in data.injuries:
		if inj.area != "" and not areas.has(inj.area):
			bad.append(inj.id + ": area")
		for ph in inj.phases:
			if not data.health.restrictions.has(ph.restriction):
				bad.append(inj.id + ": " + ph.restriction)
		if inj.has("escalates_to") and data.get_injury(inj.escalates_to).is_empty():
			bad.append(inj.id + ": escalates_to")
	var sessions: Array = data.training.sessions + [data.competitions.race_session]
	for s in sessions:
		for area in s.get("strain", {}):
			if not areas.has(area):
				bad.append(s.get("id", "race") + ": strain " + area)
		for alt in s.get("instead", []):
			if data.get_session(alt).is_empty():
				bad.append(s.id + ": instead " + alt)
		for injury_id in s.get("acute", {}):
			if data.get_injury(injury_id).is_empty():
				bad.append(s.get("id", "race") + ": acute " + injury_id)
	if not bad.is_empty():
		print("    ", bad)
	_ok("catalogue, sessions and restrictions fit together", bad.is_empty())
	_ok("Normal intensity leaves strain unchanged", float(data.health.intensity.normal.strain) == 1.0)
	_ok("cross-training sessions exist", ["aqua_jog", "stationary_bike", "swimming", "gym_core"].all(
			func(id): return not data.get_session(id).is_empty()))


## Same athlete, same health seed, same choices: exactly the same body, injuries and athlete.
func _check_determinism() -> void:
	print("-- determinism")
	var runs := []
	for i in 2:
		_new_career(11, 77)
		game.training_plan = HARD.duplicate(true)
		_play_days(150)
		runs.append(_json(game.get_system("health").to_dict()) + _json(game.athlete.to_dict()))
	_ok("same seed → bit-for-bit the same 150 days", runs[0] == runs[1])
	_new_career(11, 78)
	game.training_plan = HARD.duplicate(true)
	_play_days(150)
	_ok("another seed → a different story", _json(game.get_system("health").to_dict()) + _json(game.athlete.to_dict()) != runs[0])


## Play week stops on the first "sore" warning and on a new injury (diagnosis); answers work.
func _check_stop_events() -> void:
	print("-- stop events")
	_new_career(12, 5)
	game.training_plan = HARD.duplicate(true)
	var seen := {}
	var sore_stop_midweek := false
	var guard := 0
	while (not seen.has("sore") or not seen.has("diagnosis")) and guard < 60:
		guard += 1
		var r: String = game.advance_week()
		if r == game.STOP:
			var e: Dictionary = game.pending_event()
			var kind: String = e.get("kind", "")
			seen[kind] = e
			if kind == "sore":
				sore_stop_midweek = sore_stop_midweek or Cal.weekday(game.date) != 0
				var week = game.current_week()
				var d: int = week.day
				var can: bool = week.can_change(d)
				game.answer_event(e.id, "easy")
				if can and not seen.has("sore_answered"):
					seen.sore_answered = week.intensity(d) == "easy" and week.changed_by(d).get("intensity", "") == "player"
			else:
				game.answer_event(e.id, "ok")
	_ok("Play week stops on a 'sore' warning", seen.has("sore"))
	_ok("… with keep going / take it easy / rest day", seen.has("sore") and seen.sore.choices.size() == 3)
	_ok("… mid-week (not only on Sunday nights)", sore_stop_midweek)
	_ok("'Take it easy today' makes today Easy (by you)", seen.get("sore_answered", false))
	_ok("Play week stops on a new injury (diagnosis)", seen.has("diagnosis"))
	_ok("the diagnosis says the expected time", seen.has("diagnosis") and seen.diagnosis.text.contains("Expected time"))


## While injured, banned sessions are swapped as day changes "by" injury; when it heals, the days go back.
func _check_restrictions() -> void:
	print("-- restrictions")
	_new_career(13, 9)
	game.training_plan = HARD.duplicate(true)
	var health = game.get_system("health")
	health._start(data.get_injury("tibial_stress_reaction"), game.date, [])
	health._apply_restrictions(game.current_week())
	var w = game.current_week()
	var ok_swap := true
	var by_injury := true
	for d in range(w.day, 7):
		for sid in w.session_ids(d):
			if health.ban_reason(sid, d) != "":
				ok_swap = false
		var planned_banned := false
		for sid in w.plan[d]:
			if health.ban_reason(sid, d) != "":
				planned_banned = true
		if planned_banned and w.changed_by(d).get("sessions", "") != "injury":
			by_injury = false
	_ok("no banned session left this week", ok_swap)
	_ok("changed days say 'by injury'", by_injury)
	_ok("no running: Monday's intervals became aqua jogging", w.session_ids(0) == ["aqua_jog", "strength"])
	_ok("ban reason in plain words", health.ban_reason("long_run", 0) == "Shin stress reaction: no running: cross-training instead")
	_ok("locked: can't be trained through", not health.can_override(0) and health.day_locked(0))
	_play_days(7)
	w = game.current_week()
	_ok("next week is restricted too", w.session_ids(0) == ["aqua_jog", "strength"] and w.changed_by(0).sessions == "injury")
	health.injuries.clear()
	health._apply_restrictions(w)
	_ok("healed: back to the weekly plan", w.changes.is_empty())
	_ok("the day log keeps soreness and injuries", game.day_log[-1].has("soreness") and "tibial_stress_reaction" in game.day_log[-1].health)


## A niggle can be trained through (the day goes back to the plan by the player) and that can make it worse.
func _check_override() -> void:
	print("-- training through a niggle")
	_new_career(14, 3)
	game.training_plan = HARD.duplicate(true)
	var health = game.get_system("health")
	health._start(data.get_injury("shin_splints"), game.date, [])
	health._apply_restrictions(game.current_week())
	var w = game.current_week()
	_ok("niggle: Monday restricted", w.session_ids(0) != w.plan[0])
	_ok("niggle: can be trained through", health.can_override(0))
	_ok("override: Monday back to the plan, by you", health.override_day(0) and w.session_ids(0) == w.plan[0]
			and not w.changed_by(0).values().has("injury"))
	var left: int = health.injuries[0].left
	game.advance_day()
	_ok("Monday stays as you chose (not restricted again at day start)", game.day_log[-1].sessions == w.plan[0])
	var inj: Dictionary = health.injuries[0] if not health.injuries.is_empty() else {}
	_ok("trained through: counted, and the niggle lasts longer (or got worse)", inj.is_empty() or inj.id != "shin_splints"
			or (inj.through_days == 1 and inj.left == left - 1 + int(data.health.escalation.extend_days)))
	# Escalation: keep training through until it turns into a stress reaction (or heals).
	var guard := 0
	while not health.injuries.is_empty() and health.injuries[0].id == "shin_splints" and guard < 60:
		var week = game.current_week()
		if health.can_override(week.day):
			health.override_day(week.day)
		_advance()
		guard += 1
	_ok("training through shin splints turned them into a stress reaction",
			not health.injuries.is_empty() and health.injuries[0].id == "tibial_stress_reaction" and health.injuries[0].escalated)


## Serious injury: locked limits and the athlete is withdrawn from a race that day.
func _check_locked_race() -> void:
	print("-- locked: withdrawn from a race")
	_new_career(15, 4)
	var meet := {}
	for m in Cal.meets_between(game.date, game.add_days(game.date, 120)):
		if Cal.coach_recommends(game.athlete, m, game.date):
			meet = m
			break
	game.enter(meet.key)
	while Cal.days_between(game.date, meet.date) > 1:
		_advance()
	var health = game.get_system("health")
	health.injuries.clear()
	health._start(data.get_injury("hamstring_tear"), game.date, [])
	_advance()   # the day before the race
	var r: String = game.advance_day()   # race day
	_ok("no race screen: withdrawn", r != game.RACE and not meet.key in game.entries)
	_ok("a 'Withdrawn' event", game.events.any(func(e): return e.title.begins_with("Withdrawn")))
	_ok("the race day was a (restricted) training day", game.day_log[-1].race == "" and game.day_log[-1].date == meet.date)
	_ok("can't race while locked", not health.can_race().ok)


## A cold: Easy training by injury, racing allowed but slower.
func _check_illness_and_racing() -> void:
	print("-- illness and racing injured")
	_new_career(16, 6)
	var health = game.get_system("health")
	health._start(data.get_injury("cold"), game.date, [])
	health._apply_restrictions(game.current_week())
	var w = game.current_week()
	_ok("cold: today Easy (by injury)", w.intensity(0) == "easy" and w.changed_by(0).intensity == "injury")
	_ok("cold: racing allowed", health.can_race().ok)
	_ok("cold: races slower", health.race_slowdown() > 0.0)
	var meet := {}
	for m in Cal.meets_between(game.date, game.add_days(game.date, 120)):
		if Cal.coach_recommends(game.athlete, m, game.date):
			meet = m
			break
	var rd = load("res://scripts/core/race_day.gd").new(meet, game.athlete, game.rivals)
	var player := {}
	for h in (rd.heats if not rd.heats.is_empty() else [rd.final_entrants]):
		for e in h:
			if e.get("is_player", false):
				player = e
	var RP = load("res://scripts/core/race_performance.gd")
	_ok("the race engine gets a slower athlete", rd.slowdown > 0.0 and player.ability < RP.ability(game.athlete))
	health.injuries.clear()
	_ok("healthy: no slowdown", health.race_slowdown() == 0.0)


## Save in the middle of an injury, load: the same state, and the next weeks play out exactly the same.
func _check_midinjury_save() -> void:
	print("-- save / load mid-injury")
	_new_career(17, 21)
	game.training_plan = HARD.duplicate(true)
	var health = game.get_system("health")
	var guard := 0
	while (health.injuries.is_empty() or health.injuries[0].tier == "illness") and guard < 300:
		_advance()
		guard += 1
	_ok("got injured (%s)" % (health.injuries[0].id if not health.injuries.is_empty() else "none"), not health.injuries.is_empty())
	saves.save("mid_injury")
	var before: String = _json(game.to_dict())
	_play_days(35)
	var a: String = _json(game.athlete.to_dict()) + _json(game.get_system("health").to_dict()) + _json(game.day_log)
	game.date = game.START_DATE.duplicate()   # scramble before loading
	_ok("load", saves.load_slot("mid_injury"))
	_ok("same state after loading", _json(game.to_dict()) == before)
	_play_days(35)
	var b: String = _json(game.athlete.to_dict()) + _json(game.get_system("health").to_dict()) + _json(game.day_log)
	_ok("the next 5 weeks play out bit for bit the same", a == b)
	if a != b:
		for i in mini(a.length(), b.length()):
			if a[i] != b[i]:
				print("    first difference:\n    A ", a.substr(maxi(0, i - 80), 160), "\n    B ", b.substr(maxi(0, i - 80), 160))
				break
	saves.delete("mid_injury")


## Saves from before the health model (version 1, and version 2 from M2 step 2) load; health starts empty.
func _check_old_saves() -> void:
	print("-- old saves")
	H.model_enabled = false
	_new_career(18, 1)
	_play_days(10)
	var g: Dictionary = game.to_dict()
	H.model_enabled = true
	var v1 := {"version": 1, "saved_at": "2026-10-01 12:00:00", "summary": "old",
			"game": {"athlete": g.athlete, "date": game.START_DATE, "training_plan": g.training_plan, "entries": g.entries,
					"rivals": g.rivals}}
	g.systems = {"health": {}}   # what step 1–2 saved: an empty health state
	var v2 := {"version": 2, "saved_at": "2026-10-05 12:00:00", "summary": "step 2", "game": g}
	for save in [["v1", v1], ["v2 (step 2)", v2]]:
		var f := FileAccess.open(saves.DIR + "old.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(save[1], " "))
		f.close()
		_ok("%s save loads" % save[0], saves.load_slot("old"))
		var health = game.get_system("health")
		_ok("%s: health starts empty" % save[0], not health.started and health.injuries.is_empty())
		_play_days(3)
		_ok("%s: plays on, the body is tracked from now" % save[0], health.started and health.day_no == 3)
	saves.delete("old")


## Health model off: no strain, no health events, nothing changes.
func _check_model_off() -> void:
	print("-- health model off")
	H.model_enabled = false
	_new_career(19, 2)
	game.training_plan = HARD.duplicate(true)
	_play_days(60)
	var health = game.get_system("health")
	_ok("nothing tracked", not health.started and health.strain.is_empty())
	_ok("no health events", not game.events.any(func(e): return e.source == "health"))
	_ok("no injury day changes", not game.current_week().changed_by(game.current_week().day).values().has("injury"))
	H.model_enabled = true


## More than ~10 days in a row without any training: extra detraining (only with the health model on).
func _check_detraining() -> void:
	print("-- detraining after a long break")
	var sums := []
	for on in [false, true]:
		H.model_enabled = on
		_new_career(20, 8)
		game.training_plan = [[], [], [], [], [], [], []]
		_play_days(21)
		var total := 0.0
		for attr in data.attributes_in("physical"):
			total += game.athlete.get_attr(attr.id)
		sums.append(total)
	H.model_enabled = true
	var expected: float = data.attributes_in("physical").size() * float(data.health.detraining.per_day) * (21 - int(data.health.detraining.after_days))
	_ok("3 weeks off: %.2f extra loss (expected %.2f)" % [sums[0] - sums[1], expected], is_equal_approx(sums[0] - sums[1], expected))


## What the health UI (step 4) will read.
func _check_ui_data() -> void:
	print("-- data for the health UI")
	_new_career(21, 10)
	var health = game.get_system("health")
	_play_days(28)
	var load_coach: int = health.load_vs_normal(game.current_week())
	_ok("coach plan: load vs your normal ≈ 100%% (%d%%)" % load_coach, load_coach >= 75 and load_coach <= 130)
	_ok("coach plan risk: Low (%s)" % health.plan_risk(game.training_plan), health.plan_risk(game.training_plan) == "low")
	_ok("hard plan risk now: not Low (%s)" % health.plan_risk(HARD), health.plan_risk(HARD) != "low")
	game.training_plan = HARD.duplicate(true)
	_ok("hard plan: load vs your normal > 150%% (%d%%)" % health.load_vs_normal(game.current_week()),
			health.load_vs_normal(game.current_week()) > 150)
	var list: Array = health.soreness()
	_ok("soreness for all 6 areas, in words", list.size() == 6 and list.all(func(x): return x.word in data.health.soreness.names))
	var info: Dictionary = health.soreness_info("shins")
	_ok("cause and what helps", info.helps != "" and info.causes is Array)
	health.injuries.clear()
	health._start(data.get_injury("ankle_sprain"), game.date, [])
	var act: Array = health.active()
	_ok("active injury: name, phase, what's allowed, expected return", act.size() == 1 and act[0].name == "Ankle sprain"
			and act[0].phase_name == "No impact" and act[0].allowed != "" and act[0].locked and act[0].days_left >= 11
			and act[0].range == "2–3 weeks")
	_ok("proneness stays hidden until repeated injuries", not health.proneness_hint())


## Rivals get injured now and then, and injured rivals don't race.
func _check_rivals() -> void:
	print("-- rival injuries")
	_new_career(22, 12)
	_play_days(26 * 7)
	var out: Array = game.rivals.filter(func(r): return int(r.get("out_weeks", 0)) > 0)
	_ok("some rivals are out injured (%d of %d)" % [out.size(), game.rivals.size()], out.size() > 0)
	var rng := RandomNumberGenerator.new()
	var field: Array = load("res://scripts/core/rivals.gd").pick_field(game.rivals, "national", rng, 1.0)
	_ok("injured rivals aren't in race fields", not field.any(func(r): return int(r.get("out_weeks", 0)) > 0))


# --- Helpers -------------------------------------------------------------------------------------

func _new_career(seed_value: int, health_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	var a = load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)
	game.start_career(a)
	game.get_system("health").rng.seed = health_seed


## One day with Next day; stop events are answered (keep going / OK), races skipped to their result.
func _advance() -> void:
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
		game.answer_event(e.id, "keep" if e.get("kind", "") == "sore" else "ok")


func _play_days(n: int) -> void:
	for i in n:
		_advance()


## Full-precision JSON, read back once (exactly, like a save) so ints and floats compare the same way.
func _json(v: Variant) -> String:
	var text := JSON.stringify(v, "", true, true)
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	return JSON.stringify(parsed, "", true, true)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1
