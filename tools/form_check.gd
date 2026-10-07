extends SceneTree
## Dev tool: headless checks and calibration for race-day form (GDD 4.8 "Form", M2 step 6c). Prints PASS / FAIL.
## Run: godot --headless --path . -s res://tools/form_check.gd
## Part 1 plays a year of the old repeating coach week with a race on every Saturday there is a meet and prints the `neutral`
## that would make its average form exactly 0 (the value in data/form.json must be within 0.1 % of that).
## Uses its own save folder, never the player's saves. The health model is off (repeatable runs).
## NOTE: it prints ALL CHECKS PASSED even when a SCRIPT ERROR aborted a check function: read stderr too.

var game
var data
var saves
var Cal
var FS
var A
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	Cal = load("res://scripts/core/calendar.gd")
	FS = load("res://scripts/core/form_system.gd")
	A = load("res://scripts/core/athlete.gd")
	load("res://scripts/core/health_system.gd").model_enabled = false
	game.autosave = false

	_check_data()
	_check_numbers()
	_check_calibration()
	_check_season_words()
	_check_tired()
	_check_race_effect()
	_check_save_load()
	_check_switch_off()
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


# --- Checks ------------------------------------------------------------------------------------

func _check_data() -> void:
	print("-- data")
	var f: Dictionary = data.form
	var mins := []
	for w in f.words:
		mins.append(float(w.min))
	var ordered := true
	for i in range(1, mins.size()):
		ordered = ordered and mins[i] < mins[i - 1]
	_ok("words are ordered from best to worst by their limit", ordered)
	_ok("tired word exists", f.tired.name == "Tired")
	var sharp := {}
	for s in data.training.sessions:
		if s.has("sharp"):
			sharp[s.id] = float(s.sharp)
	_ok("sharp values: intervals 20 (GDD first guess 12, see 4.8 Built 6c), club 7, speed 4, fartlek 4, tempo 3, hill 3, start 2", sharp == {"intervals_800": 20.0,
			"club_session": 7.0, "speed_strides": 4.0, "fartlek": 4.0, "tempo_run": 3.0, "hill_sprints": 3.0, "start_practice": 2.0})
	_ok("race sharp is 15", float(data.competitions.race_session.sharp) == 15.0)
	_ok("decay 0.93", float(f.sharpness.decay) == 0.93)


func _check_numbers() -> void:
	print("-- the formula")
	var n := float(data.form.sharpness.neutral)
	_ok("sharpness 0, tired legs: the lowest sharpness term (-0.75 %)", is_equal_approx(FS.sharp_term(0.0), -0.0075))
	_ok("sharpness = neutral: 0", is_equal_approx(FS.sharp_term(n), 0.0))
	_ok("sharpness 1.5 x neutral: +0.75 % (the cap)", is_equal_approx(FS.sharp_term(1.5 * n), 0.0075))
	_ok("halfway to the cap: +0.375 %", is_equal_approx(FS.sharp_term(1.25 * n), 0.00375))
	_ok("sharpness beyond the cap point is capped", is_equal_approx(FS.sharp_term(100.0), 0.0075))
	_ok("fatigue <= 8: +0.75 % freshness", is_equal_approx(FS.fresh_term(5.0), 0.0075) and is_equal_approx(FS.fresh_term(8.0), 0.0075))
	_ok("fatigue 20 and above: no freshness", FS.fresh_term(20.0) == 0.0 and FS.fresh_term(60.0) == 0.0)
	_ok("total is capped at +1.5 % / -1.0 %", FS.form_for(100.0, 0.0) <= 0.015 + 1e-12 and FS.form_for(0.0, 30.0) >= -0.010 - 1e-12)
	_ok("words", FS.word_for(0.012, 10.0).name == "Peaking" and FS.word_for(0.006, 10.0).name == "Sharp"
			and FS.word_for(0.0, 10.0).name == "OK" and FS.word_for(-0.005, 10.0).name == "Rusty")
	_ok("Tired wins over everything above fatigue 25", FS.word_for(0.015, 26.0).name == "Tired" and FS.word_for(0.015, 25.0).name == "Peaking")


## A year of the repeating coach week with a race on every Saturday there is a meet. Prints the neutral sharpness that
## would make the average form 0, and checks the value in the data is that.
func _check_calibration() -> void:
	print("-- calibration (repeating coach week, a race at every Saturday meet)")
	_new_career("repeat")
	var meets: Array = []
	var a = game.athlete
	for m in Cal.meets_between(_d(2026, 12, 1), _d(2027, 8, 31)):
		if Cal.weekday(m.date) == 5 and Cal.can_enter(a, m, game.date).ok:
			meets.append(m.key)
	game.entries = meets.duplicate()
	var pairs := _play_collect(_d(2027, 8, 31))
	var races := pairs.size()
	var mean := _mean_form(pairs)
	var solved := _solve_neutral(pairs)
	print("    %d races; mean form with neutral %.2f = %+.3f %%; neutral that gives exactly 0: %.2f" % [
			races, float(data.form.sharpness.neutral), mean * 100.0, solved])
	_ok("at least 8 races measured", races >= 8)
	_ok("the repeating coach week averages about 0 % form over its races (within 0.1 %)", absf(mean) < 0.001)
	var s_avg := 0.0
	var f_avg := 0.0
	for p in pairs:
		s_avg += p[0] / races
		f_avg += p[1] / races
	print("    average sharpness %.1f, average fatigue %.1f at the start line" % [s_avg, f_avg])


## The season plan: base, the tapered target races and the first race after a base phase.
func _check_season_words() -> void:
	print("-- the season plan (phases mode, Balanced)")
	_new_career("phases")
	game.entries.append("hallikisat_jkl@2027")   # 9 Jan: the end of general base
	game.entries.append("kevatkisat@2027")        # 15 May: the third week of pre-competition, after spring base
	var out := {}
	_play_words(_d(2027, 8, 10), out, {20270424: "end_of_spring_base", 20270531: "end_of_pre_comp"})
	for key in ["hallikisat_jkl@2027", "sm_hallit_14_15@2027", "end_of_spring_base", "kevatkisat@2027", "end_of_pre_comp", "sm_14_15@2027"]:
		if out.has(key):
			var o: Dictionary = out[key]
			var when: String = key
			if key.contains("@"):
				when = Cal.format_day(Cal.get_meet(key).date)
			print("    %-24s %-18s: %-8s form %+.2f %% (sharpness %.0f, fatigue %.0f)" % [key.left(24), when,
					o.word, o.share * 100.0, o.sharpness, o.fatigue])
	_ok("all races and probes were reached", out.size() == 6)
	if out.size() == 6:
		_ok("a tapered target race reads Peaking (SM-hallit)", out["sm_hallit_14_15@2027"].word == "Peaking")
		# The race-season week is so heavy that even the taper leaves fatigue near 19 (a 6d tuning point), so the
		# August target reads Sharp rather than Peaking: it must at least be Sharp.
		_ok("the August target (tapered, but fatigue stays near 19) reads Sharp or better", out["sm_14_15@2027"].word in ["Sharp", "Peaking"])
		_ok("a race at the end of the spring base (Sat 24 Apr, no race-specific work yet) would read Rusty", out["end_of_spring_base"].word == "Rusty")
		_ok("Rusty is slower than Peaking", out["end_of_spring_base"].share < out["sm_hallit_14_15@2027"].share)


func _check_tired() -> void:
	print("-- tired")
	_new_career("repeat")
	game.athlete.fatigue = 40.0
	var fs = game.get_system("form")
	var info: Dictionary = fs.info(game.athlete.fatigue)
	_ok("fatigue over 25 reads Tired", info.word == "Tired")
	game.athlete.fatigue = 25.0
	_ok("fatigue 25 does not (yet)", fs.info(25.0).word != "Tired")
	_ok("the info has text and what helps", String(info.text) != "" and String(info.helps) != "")


## Form changes the race time like the slowdown does, and with the model off the player's ability is untouched.
func _check_race_effect() -> void:
	print("-- applied to the race")
	_new_career("repeat")
	var fs = game.get_system("form")
	var meet: Dictionary = Cal.get_meet("hallikisat_jkl@2027")
	var base_ability: float = load("res://scripts/core/race_performance.gd").player_profile(game.athlete).ability
	fs.sharpness = 60.0
	game.athlete.fatigue = 5.0
	var rd = load("res://scripts/core/race_day.gd").new(meet, game.athlete, game.rivals)
	var expected: float = fs.race_form(5.0)
	_ok("race-day form is stored on the RaceDay (%+.2f %%)" % (rd.form * 100.0), is_equal_approx(rd.form, expected) and rd.form > 0.01)
	var player: Dictionary = {}
	for e in rd.current_entrants():
		if e.get("is_player", false):
			player = e
	var RP = load("res://scripts/core/race_performance.gd")
	var t_base: float = RP.time_for(base_ability, game.athlete.gender)
	var t_now: float = RP.time_for(player.ability, game.athlete.gender)
	_ok("the player's race time is time x (1 - form)", absf(t_now / t_base - (1.0 - rd.form)) < 1e-6)
	FS.enabled = false
	rd = load("res://scripts/core/race_day.gd").new(meet, game.athlete, game.rivals)
	var again: Dictionary = {}
	for e in rd.current_entrants():
		if e.get("is_player", false):
			again = e
	_ok("with the form model off: form 0 and the ability is the plain one", rd.form == 0.0 and is_equal_approx(again.ability, base_ability))
	FS.enabled = true


## The form state saves and loads, and the days after a load go exactly as without saving.
func _check_save_load() -> void:
	print("-- save / load")
	_new_career("phases")
	var fs = game.get_system("form")
	_ok("a new career has an empty form state in its save", fs.to_dict().is_empty())
	_play_days(40)
	fs = game.get_system("form")
	_ok("after playing, the state is saved (sharpness %.3f)" % fs.sharpness, fs.to_dict().get("started", false))
	var snap := _json(game.to_dict())
	var first := _play_days(60)
	var s_after: float = game.get_system("form").sharpness
	game.from_dict(_parse(snap))
	var restored: float = game.get_system("form").sharpness
	var snap_state: Dictionary = _parse(snap).systems.form
	_ok("the loaded sharpness is the saved one, bit for bit", restored == float(snap_state.sharpness))
	var second := _play_days(60)
	_ok("60 days after a load: the same form numbers as without saving", first == second)
	_ok("... and the same sharpness at the end", game.get_system("form").sharpness == s_after)
	# An old save has no form state: it starts at the neutral sharpness.
	var old: Dictionary = _parse(snap)
	old.systems.erase("form")
	game.from_dict(old)
	fs = game.get_system("form")
	_ok("an old save (no form state) loads with the neutral start", fs.sharpness == float(data.form.sharpness.start) and fs.to_dict().is_empty())
	_play_days(3)
	_ok("... and plays on", game.get_system("form").to_dict().get("started", false))


func _check_switch_off() -> void:
	print("-- switched off")
	FS.enabled = false
	_new_career("repeat")
	_play_days(14)
	var fs = game.get_system("form")
	_ok("nothing changes while off (sharpness stays, state empty)", fs.sharpness == float(data.form.sharpness.start) and fs.to_dict().is_empty())
	_ok("race_form is 0 and the info is empty", fs.race_form(5.0) == 0.0 and fs.info(5.0).is_empty())
	FS.enabled = true


# --- Helpers -------------------------------------------------------------------------------------

## Plays days to `end` (inclusive date), running every race through the game, and returns
## [[sharpness, fatigue], ...] on each race morning.
func _play_collect(end: Dictionary) -> Array:
	var pairs := []
	var steps := 0
	while Cal.date_key(game.date) <= Cal.date_key(end) and steps < 2000:
		steps += 1
		var r: String = game.advance_day()
		if r == game.RACE:
			var fs = game.get_system("form")
			pairs.append([fs.sharpness, game.athlete.fatigue])
			r = _run_race()
		if r == game.STOP:
			game.answer_event(game.pending_event().id, "ok")
	return pairs


func _play_words(end: Dictionary, out: Dictionary, probes := {}) -> void:
	var steps := 0
	while Cal.date_key(game.date) <= Cal.date_key(end) and steps < 2000:
		steps += 1
		var pk: int = Cal.date_key(game.date)
		if probes.has(pk):
			var fs0 = game.get_system("form")
			var info0: Dictionary = fs0.info(game.athlete.fatigue)
			out[probes[pk]] = {"word": info0.word, "share": info0.share, "sharpness": fs0.sharpness,
					"fatigue": game.athlete.fatigue, "phase": game.season.week_for(game.week_monday()).phase}
		var r: String = game.advance_day()
		if r == game.RACE:
			var fs = game.get_system("form")
			var info: Dictionary = fs.info(game.athlete.fatigue)
			out[game.race_day.meet.key] = {"word": info.word, "share": info.share, "sharpness": fs.sharpness,
					"fatigue": game.athlete.fatigue}
			r = _run_race()
		if r == game.STOP:
			game.answer_event(game.pending_event().id, "ok")


## Plays n days; returns the sharpness and race form after each (to compare runs).
func _play_days(n: int) -> Array:
	var log := []
	for i in n:
		var r: String = game.advance_day()
		if r == game.RACE:
			log.append(game.race_day.form)
			r = _run_race()
		if r == game.STOP:
			game.answer_event(game.pending_event().id, "ok")
		log.append(game.get_system("form").sharpness)
	return log


func _run_race() -> String:
	var rd = game.race_day
	while not rd.is_done():
		var race = rd.start_round(false, "pack")
		race.run()
		rd.finish_round()
	return game.finish_race()


func _mean_form(pairs: Array) -> float:
	var sum := 0.0
	for p in pairs:
		sum += FS.form_for(p[0], p[1])
	return sum / maxf(1.0, pairs.size())


## The neutral sharpness that makes the mean form of `pairs` 0 (bisection; the data value is put back).
func _solve_neutral(pairs: Array) -> float:
	var cfg: Dictionary = data.form.sharpness
	var keep := float(cfg.neutral)
	var lo := 5.0
	var hi := 90.0
	for i in 60:
		var mid := (lo + hi) / 2.0
		cfg.neutral = mid
		if _mean_form(pairs) > 0.0:
			lo = mid
		else:
			hi = mid
	cfg.neutral = keep
	return (lo + hi) / 2.0


func _athlete():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	return load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)


func _new_career(mode: String) -> void:
	game.start_career(_athlete(), mode)


func _d(y: int, m: int, d: int) -> Dictionary:
	return {"year": y, "month": m, "day": d}


## Reads a JSON text exactly like a save is read (every decimal exact, see SaveGame.load_slot).
func _parse(text: String) -> Variant:
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	return parsed


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
