extends SceneTree
## Dev tool: the multi-season check of the season plan (GDD 4.8 "Balance and verification" → "Multi-season check",
## M2 step 6f). N athletes (default 50) play three seasons, 2 Nov 2026 to 28 Oct 2029 (ages 14–17), through the game
## loop with the health and form models on. The coach's offers are answered "balanced", easing back in is accepted,
## "sore" warnings are answered "keep going" (neutral), races are finished without being run (as in
## training_balance.gd part 4), and each season the coach-recommended meets are entered. Checks:
##   1. the seasons' calendar: the season starts, every day of the three seasons in exactly one season, 29 Feb 2028;
##   2. the coach's offers: at career start and 3 weeks before each new season, answered;
##   3. the rollover: a record per season on Balanced, the coach's targets for the new age class (or a fallback),
##      entered; the new season's first phase starts on its first Monday; every Monday has a plan with a phase;
##   4. easing back in: offered only after 14+ days without running, and the block's days follow their rules;
##   5. save/load on the evening before a new season: the next 28 days play out bit for bit as without saving;
##   6. injuries and progress per season don't drift (printed per season, loose limits checked).
## Run (headless is fine; ~1.5 s per athlete-season):
##   godot --headless --path . -s res://tools/season_check.gd [-- n]
## Prints ALL CHECKS PASSED at the end; read stderr too (a SCRIPT ERROR can abort a check part-way).

const YEARS := [2026, 2027, 2028]
const SAVE_ATHLETES := 3     # athletes whose season boundaries are also checked through a save file
const SAVE_DAYS := 28

var game
var data
var saves
var Cal
var SP
var SS
var H
var RP
var F
var _fails := 0
var _checks := 0
var _fail_lines := {}        # check text -> times failed (each printed once)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	Cal = load("res://scripts/core/calendar.gd")
	SP = load("res://scripts/core/season_plan.gd")
	SS = load("res://scripts/core/season_system.gd")
	H = load("res://scripts/core/health_system.gd")
	RP = load("res://scripts/core/race_performance.gd")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	H.model_enabled = true
	SS.offers_enabled = true
	var n := 50
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		n = int(args[0])

	print("--- 1. the seasons' calendar")
	_check_calendar()

	print("--- 2–6. %d athletes × 3 seasons on Balanced (health and form on)" % n)
	var t0 := Time.get_ticks_msec()
	var totals := {"inj": {}, "serious": {}, "ill": {}, "gain": {}, "gain2": {}, "stops": {}, "blocks": {}}
	for key in totals:
		for y in YEARS:
			totals[key][y] = 0.0
	var extra := {"block_weeks": {}, "risk_pairs": {}, "return_days": 0, "targets": {}, "save_checks": 0}
	for i in n:
		_career(i, totals, extra)
	print("    %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))

	print("--- 6. per season (per athlete)")
	for y in YEARS:
		var se := sqrt(maxf(0.0, totals.gain2[y] / n - pow(totals.gain[y] / n, 2.0)) / n)
		print("    %d–%s: injuries %.2f (serious %.2f) · illnesses %.2f · 800 m ability %+.2f (se %.2f) · stops %.1f · easing back in accepted %.2f" % [
				y, str(y + 1).right(2), totals.inj[y] / n, totals.serious[y] / n, totals.ill[y] / n,
				totals.gain[y] / n, se, totals.stops[y] / n, totals.blocks[y] / n])
	print("    days with running banned: %.1f a year" % (extra.get("days_out", 0) / (3.0 * n)))
	for y in YEARS:
		_ok("season %d: injuries a year within 0.2–1.6 (%.2f)" % [y, totals.inj[y] / n], totals.inj[y] / n >= 0.2 and totals.inj[y] / n <= 1.6)
		_ok("season %d: the athletes still progress (%+.2f)" % [y, totals.gain[y] / n], totals.gain[y] / n > 0.2)
	_ok("injuries don't drift: the third season within ±0.6 of the first (%.2f vs %.2f)" % [totals.inj[2028] / n, totals.inj[2026] / n],
			absf(totals.inj[2028] - totals.inj[2026]) / n <= 0.6)
	print("    easing back in: %d blocks, by length %s; plan risk full plan → with the block %s; %d block days checked" % [
			extra.block_weeks.values().reduce(func(x, y): return x + y, 0), extra.block_weeks, extra.risk_pairs, extra.return_days])
	print("    the coach's targets per season: %s" % extra.targets)
	_ok("save/load at a season boundary was checked for %d athletes" % SAVE_ATHLETES, extra.save_checks == mini(n, SAVE_ATHLETES) * 2)

	for line in _fail_lines:
		print("  FAIL  %s (%d×)" % [line, _fail_lines[line]])
	print("%d checks, %d failed" % [_checks, _fails])
	print("ALL CHECKS PASSED" if _fails == 0 else "SOME CHECKS FAILED")
	quit()


# --- 1. Calendar -------------------------------------------------------------------------------------------------

func _check_calendar() -> void:
	var starts := {2026: 20261102, 2027: 20271101, 2028: 20281030, 2029: 20291029}
	for y in starts:
		_ok("season %d starts on %d" % [y, starts[y]], Cal.date_key(SP.season_start(y)) == starts[y])
		_ok("season %d starts on a Monday" % y, Cal.weekday(SP.season_start(y)) == 0)
	_ok("2027–28 has 52 weeks, 2028–29 has 52", SP.season_weeks(2027) == 52 and SP.season_weeks(2028) == 52)
	var day: Dictionary = SP.season_start(2026)
	var count := 0
	var leap := false
	var wrong := 0
	while Cal.date_key(day) < Cal.date_key(SP.season_start(2029)):
		var y: int = SP.year_of(day)
		if Cal.date_key(day) < Cal.date_key(SP.season_start(y)) or Cal.date_key(day) >= Cal.date_key(SP.season_start(y + 1)):
			wrong += 1
		leap = leap or Cal.date_key(day) == 20280229
		day = game.add_days(day, 1)
		count += 1
	_ok("every day of the three seasons is in exactly one season (%d days, %d wrong)" % [count, wrong], wrong == 0 and count == 1092)
	_ok("29 Feb 2028 is one of them (leap year)", leap)
	_ok("28 Feb 2028 + 1 day = 29 Feb, + 2 days = 1 Mar", Cal.date_key(game.add_days({"year": 2028, "month": 2, "day": 28}, 1)) == 20280229
			and Cal.date_key(game.add_days({"year": 2028, "month": 2, "day": 28}, 2)) == 20280301)


# --- One career -------------------------------------------------------------------------------------------------

func _career(i: int, totals: Dictionary, extra: Dictionary) -> void:
	game.start_career(_random_athlete(i))   # season plan on the coach's ★, with the coach's offer
	game.get_system("health").rng.seed = 7000 + i
	var st := {"offers": [], "returns": [], "stops": {}, "kept": {}, "risk_pairs": extra.risk_pairs, "return_days": 0, "entered": {}}
	_ok("a new career starts with the coach's offer", game.pending_event().get("kind", "") == "offer")
	_answer_events(st)
	_ok("Balanced after answering the offer", game.season.variant(2026) == "balanced")
	var ability := {2026: RP.ability(game.athlete)}
	var end_key: int = Cal.date_key(SP.season_start(2029))
	var compare_at := -1
	var snapshot := ""
	var leap_played := false
	var guard := 0
	while Cal.date_key(game.date) < end_key and guard < 1200:
		guard += 1
		var today: Dictionary = game.date.duplicate()
		var y: int = SP.year_of(today)
		if y > 2026 and Cal.date_key(today) == Cal.date_key(SP.season_start(y)) and not ability.has(y):
			ability[y] = RP.ability(game.athlete)
			_check_rollover(y, i, extra)
		# The Sunday before a new season (its evening is the rollover): through a save file and back.
		var tomorrow: Dictionary = game.add_days(today, 1)
		if i < SAVE_ATHLETES and compare_at < 0 and SP.year_of(tomorrow) > y and SP.year_of(tomorrow) <= 2028:
			snapshot = _save_and_play(st)
			compare_at = Cal.date_key(game.add_days(today, SAVE_DAYS))
		elif compare_at == Cal.date_key(today):
			_ok("save/load at the start of a season: %d days later everything is the same as without saving" % SAVE_DAYS, _state() == snapshot)
			extra.save_checks += 1
			compare_at = -1
		leap_played = leap_played or Cal.date_key(today) == 20280229
		_step(st)
	_ok("the career played to the end of the third season", Cal.date_key(game.date) == end_key)
	_ok("29 Feb 2028 was played", leap_played)
	ability[2029] = RP.ability(game.athlete)
	var offer_days: Array = st.offers.map(func(e): return Cal.date_key(e.date))
	_ok("the offers came at the start and 3 weeks before each new season (%s)" % [offer_days], offer_days == [20261102, 20271011, 20281009, 20291008])

	# Per season.
	var h = game.get_system("health")
	for y in YEARS:
		var gain: float = ability[y + 1] - ability[y]
		totals.gain[y] += gain
		totals.gain2[y] += gain * gain
		totals.stops[y] += st.stops.get(y, 0)
	for inj in h.history + h.injuries:
		var y: int = SP.year_of(inj.started)
		if not y in YEARS:
			continue
		if inj.tier == "illness":
			totals.ill[y] += 1
		else:
			totals.inj[y] += 1
			totals.serious[y] += 1 if inj.tier == "serious" else 0
	extra.days_out = int(extra.get("days_out", 0)) + int(h.counters.days_out)   # (the counter is for the whole career)
	for e in st.returns:
		_ok("easing back in was offered after at least 14 days without running", int(e.days_out) >= int(data.periodization.return_block.min_days))
		var y: int = SP.year_of(e.date)
		if y in YEARS:
			totals.blocks[y] += 1
		var w: int = e.kinds.size()
		extra.block_weeks[w] = int(extra.block_weeks.get(w, 0)) + 1
	extra.return_days += st.return_days

	# Every Monday of the three seasons has a plan with a phase (also in the final state of the plan).
	var monday: Dictionary = SP.season_start(2026)
	var missing := 0
	while Cal.date_key(monday) < end_key:
		var plan: Dictionary = game.season.week_for(monday)
		if plan.days.size() != 7 or plan.intensity.size() != 7 or str(plan.get("phase", "")) == "":
			missing += 1
		monday = game.add_days(monday, 7)
	_ok("every Monday of the three seasons has a week plan with a phase", missing == 0)


## Plays one day (the race finished without running it) and answers what comes up. On a new season's first day the
## coach-recommended meets of that season are entered first.
func _step(st: Dictionary) -> void:
	var y: int = SP.year_of(game.date)
	if Cal.date_key(game.date) == Cal.date_key(SP.season_start(y)) and not st.entered.has(y):
		st.entered[y] = true
		_enter_recommended(y)
	_check_return_day(st)
	var r: String = game.advance_day()
	if r == game.RACE:
		r = game.finish_race()
	_answer_events(st)


func _answer_events(st: Dictionary) -> void:
	var guard := 0
	while not game.pending_event().is_empty() and guard < 20:
		guard += 1
		var e: Dictionary = game.pending_event()
		var y: int = SP.year_of(e.date)
		st.stops[y] = int(st.stops.get(y, 0)) + 1
		var answer := "ok"
		match str(e.get("kind", "")):
			"offer":
				st.offers.append(e)
				answer = "balanced"
			"return":
				st.returns.append(e)
				print("    easing back in %s: %d days out (%s), %d weeks, risk %s → %s" % [Cal.format_day(e.date), int(e.days_out),
						e.cause if e.cause != "" else "own break", e.kinds.size(), e.risk_full, e.risk_block],
						" (much safer)" if e.risk_full == e.risk_block and e.much_safer else "")
				var pair := "%s → %s" % [e.risk_full, e.risk_block]
				st.risk_pairs[pair] = int(st.risk_pairs.get(pair, 0)) + 1
				answer = "accept"
			"sore":
				answer = "keep"
		game.answer_event(e.id, answer)


func _enter_recommended(year: int) -> void:
	var from: Dictionary = game.date
	for m in Cal.meets_between(from, game.add_days(SP.season_start(year + 1), -1)):
		if Cal.coach_recommends(game.athlete, m, from) and not m.key in game.entries:
			game.enter(m.key)


# --- 3. Rollover --------------------------------------------------------------------------------------------------

func _check_rollover(y: int, i: int, extra: Dictionary) -> void:
	var s = game.season
	_ok("season %d: a record was made at the rollover" % y, s.seasons.has(y))
	_ok("season %d: on Balanced (the offer's answer)" % y, s.variant(y) == "balanced")
	_ok("season %d: the season system handled the start" % y, game.get_system("season").rolled.has(y))
	var targets: Array = s.targets(y)
	_ok("season %d: the coach has targets" % y, not targets.is_empty())
	var names := []
	for key in targets:
		var m: Dictionary = Cal.get_meet(key)
		_ok("season %d: target %s is in that season" % [y, key], not m.is_empty() and SP.year_of(m.date) == y)
		_ok("season %d: target %s fits the athlete's age class" % [y, key], s.can_target(m))
		var can: bool = Cal.can_enter(game.athlete, m, game.date).ok
		_ok("season %d: target %s is entered" % [y, key], key in game.entries or not can)
		names.append(m.get("name", key))
	if i == 0:
		extra.targets[y] = "%s: %s" % [Cal.age_class(game.athlete, y + 1), ", ".join(names)]
	var first: Dictionary = s.phase_dates(y)[0]
	_ok("season %d: the first phase starts on the season's first Monday" % y, Cal.date_key(first.first) == Cal.date_key(SP.season_start(y)))
	_ok("season %d: this week is its first phase's" % y, s.week_for(game.week_monday()).phase == first.id)


# --- 4. Easing back in --------------------------------------------------------------------------------------------

## Today's day of a return block follows the block's rules (not on race days; rest days stay rest days).
func _check_return_day(st: Dictionary) -> void:
	var s = game.season
	var i: int = s.return_day(game.date)
	if i < 0:
		return
	var monday: Dictionary = game.week_monday()
	var d: int = Cal.weekday(game.date)
	if Cal.races_in_week(game.entries, monday).has(d):
		return
	var plan: Dictionary = s.week_for(monday)
	_ok("a block week's plan says kind 'return'", plan.kind == "return")
	var cfg: Dictionary = data.periodization.return_block
	var kind: String = s.return_block.kinds[i / 7]
	var rule: Dictionary = cfg.kinds[kind]
	var ids: Array = plan.days[d]
	st.return_days += 1
	if d < 6 and Cal.races_in_week(game.entries, monday).has(d + 1) and not ids.is_empty():
		_ok("in a return block the day before a race is Easy", plan.intensity[d] == "easy")
	if not rule.has("max_sessions"):
		return
	_ok("return '%s' days have at most %d session" % [kind, int(rule.max_sessions)], ids.size() <= int(rule.max_sessions))
	var levels := ["easy", "normal", "hard"]
	_ok("return '%s' days are at most %s" % [kind, rule.intensity_max], ids.is_empty() or levels.find(plan.intensity[d]) <= levels.find(rule.intensity_max))
	var key := "%s/%d" % [str(s.return_block.start), i / 7]
	for sid in ids:
		var tags: Array = data.get_session(sid).get("tags", [])
		if tags.any(func(t): return t in rule.swap_tags):
			st.kept[key] = int(st.kept.get(key, 0)) + 1
	_ok("return '%s' weeks keep at most %d hard session" % [kind, int(rule.keep_hard)], int(st.kept.get(key, 0)) <= int(rule.keep_hard))


# --- 5. Save / load -----------------------------------------------------------------------------------------------

## Saves (the evening before a new season was just played), plays SAVE_DAYS days and keeps the state, then loads the
## save again: the career goes on from the save, and the caller compares when it gets there.
func _save_and_play(st: Dictionary) -> String:
	saves.save("season_check")
	var dry := {"offers": [], "returns": [], "stops": {}, "kept": {}, "risk_pairs": {}, "return_days": 0, "entered": st.entered.duplicate()}
	for k in SAVE_DAYS:
		_step(dry)
	var state := _state()
	_ok("load the save made before the new season", saves.load_slot("season_check"))
	saves.delete("season_check")
	return state


## Everything a played day changes for the player (the rivals' random training isn't part of it).
func _state() -> String:
	var systems := {}
	for s in game.systems:
		systems[s.id] = s.to_dict()
	return _json([game.athlete.to_dict(), game.date, game.season.to_dict(), game.entries, game.day_log, game.last_report,
			systems, game.events.map(func(e): return [e.title, e.answer])])


# --- Helpers -------------------------------------------------------------------------------------------------------

func _random_athlete(i: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	return F.create({
		"first_name": "Test", "last_name": "Runner%d" % i, "gender": "male" if i % 2 == 0 else "female",
		"hometown": "Tampere", "club_id": "tap", "main_event": "800m",
		"birth_date": {"year": 2012, "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)


## Full-precision JSON, read back once (exactly, like a save) so ints and floats compare the same way.
func _json(v: Variant) -> String:
	var text := JSON.stringify(v, "", true, true)
	var parsed = JSON.parse_string(text)
	saves._exact_numbers(parsed, saves._number_tokens(text), {"i": 0})
	return JSON.stringify(parsed, "", true, true)


## Counts a check; a failure is printed once per text at the end (with how often it failed).
func _ok(what: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_fails += 1
		_fail_lines[what] = int(_fail_lines.get(what, 0)) + 1
