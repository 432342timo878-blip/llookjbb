extends SceneTree
## Dev tool: checks the meet formats (GDD 4.3.1 decisions 28 and 31-34, RaceDay): single races, timed sections and
## heats / semi-finals / final from the World Athletics table. Prints PASS / FAIL and a few measurements.
## Run: godot --headless --path . -s res://tools/race_rounds.gd [-- race_days_per_case]
## Uses its own save folder; the health model is off (repeatable fields).
## NOTE: it prints ALL CHECKS PASSED even when a SCRIPT ERROR aborted a check function: read stderr too.

var game
var data
var Cal
var RD
var _fails := 0
var _n := 20


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	data = root.get_node("Data")
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	load("res://scripts/core/health_system.gd").model_enabled = false
	Cal = load("res://scripts/core/calendar.gd")
	RD = load("res://scripts/core/race_day.gd")
	game.autosave = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_n = int(args[0])
	game.start_career(_athlete(), "repeat")
	# A season of the rivals' own training and races (their PBs and season bests: the seeding marks), to August.
	var rivals = load("res://scripts/core/rivals.gd")
	var monday: Dictionary = game.week_monday()
	for w in 40:
		rivals.train_week(game.rivals, game.athlete.gender, monday)
		monday = game.add_days(monday, 7)
	var marked: int = game.rivals.filter(func(r): return float(r.pb) > 0.0).size()
	print("rivals with a PB after 40 weeks: %d of %d" % [marked, game.rivals.size()])
	_check_table()
	_check_formats()
	_check_sections("sm_14_15@2027")
	_check_sections("sm_hallit_14_15@2027")
	# A strong athlete from here on, so the semi-finals and finals are reached too.
	for id in data.races.ability_weights:
		if not str(id).begins_with("_"):
			game.athlete.set_attr(id, 12.0)
	_check_heats("sm_14_15@2027")
	_check_heats("sm_hallit_14_15@2027")
	_check_semis()
	RD.format_override = ""
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(what: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1


func _athlete():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	var a = load("res://scripts/core/athlete_factory.gd").create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)
	return a


## The WA table: each round's groups x place + time spots = the next round's size, the last one = the final's size.
func _check_table() -> void:
	print("-- the World Athletics table (data/races.json rounds.heats)")
	var t: Dictionary = data.races.rounds.heats
	for where in ["outdoor", "indoor"]:
		var final_size := 8 if where == "outdoor" else 6
		var ok := true
		var prev_to := 0
		for row in t[where]:
			ok = ok and (prev_to == 0 or int(row.entries[0]) == prev_to + 1)
			prev_to = int(row.entries[1])
			var rounds: Array = row.rounds
			for k in rounds.size():
				var through: int = int(rounds[k][0]) * int(rounds[k][1]) + int(rounds[k][2])
				if k == rounds.size() - 1:
					ok = ok and through == final_size
				else:
					# a semi-final round: its groups hold the qualifiers (at most 8 each outdoors, 6 indoors)
					ok = ok and through <= int(rounds[k + 1][0]) * final_size and through > int(rounds[k + 1][0]) * int(rounds[k + 1][1])
			# the first round's heats hold the field (at most 9 a heat outdoors, two to a lane allowed; 6-7 indoors)
			var per: float = float(row.entries[1]) / float(rounds[0][0])
			ok = ok and per <= (9.0 if where == "outdoor" else 7.0)
		_ok("%s: rows follow each other and every round fills the next exactly (final %d)" % [where, final_size], ok)


func _days(key: String, count: int) -> Array:
	var meet: Dictionary = Cal.get_meet(key)
	var out := []
	for i in count:
		out.append(RD.new(meet, game.athlete, game.rivals))
	return out


## Which format each kind of meet gets.
func _check_formats() -> void:
	print("-- formats")
	RD.format_override = ""
	var local_out: Array = _days("kevatkisat@2027", 10)
	_ok("outdoor local meet (5-8 runners): one race", local_out.all(func(rd): return rd.format == "single" and rd.rounds == ["race"]))
	var local_in: Array = _days("hallikisat_jkl@2027", 20)
	_ok("indoor local meet: one race up to 6, sections from 7 (decision 32)", local_in.all(func(rd):
			var n: int = rd.final_entrants.size() if rd.format == "single" else rd.heats.reduce(func(s, h): return s + h.size(), 0)
			return (rd.format == "single" and n <= 6) or (rd.format == "sections" and n > 6)))
	var sm: Array = _days("sm_14_15@2027", 5)
	_ok("Nuorten SM 14-15: sections, no heats (decision 28)", sm.all(func(rd): return rd.format == "sections"))
	var tjig: Array = _days("tjig@2027", 5)
	_ok("Tampere Junior Indoor Games: sections or one race (decision 31)", tjig.all(func(rd): return rd.format in ["sections", "single"]))
	_ok("Kalevan kisat is a heats meet in the data", str(Cal.get_meet("kalevan_kisat@2027").get("format", "")) == "heats")


## Sections: sizes, seeding, running order, the overall list and the player's place in it.
func _check_sections(key: String) -> void:
	RD.format_override = ""
	var meet: Dictionary = Cal.get_meet(key)
	var indoor: bool = meet.get("indoor", false)
	var cap := 6 if indoor else 12
	print("-- sections: %s (%d race days)" % [meet.name, _n])
	var sizes_ok := true
	var seeded_ok := true
	var overall_ok := true
	var place_ok := true
	var chase := 0
	var groups_seen := 0
	var medal_est := []
	var medal_real := []
	var sizes_seen := {}
	for i in _n:
		var rd = RD.new(meet, game.athlete, game.rivals)
		if rd.format != "sections":
			continue
		var n: int = rd.heats.reduce(func(s, h): return s + h.size(), 0)
		for h in rd.heats:
			sizes_ok = sizes_ok and h.size() <= cap and h.size() >= 4
		sizes_seen[str(rd.heats.map(func(h): return h.size()))] = true
		# The slowest section runs first: every seed in a section is at least as slow as every seed after it.
		for g in range(1, rd.heats.size()):
			var slow_after := 0.0
			for e in rd.heats[g]:
				slow_after = maxf(slow_after, float(rd._seed[e.name]))
			var fast_before := 1.0e9
			for e in rd.heats[g - 1]:
				fast_before = minf(fast_before, float(rd._seed[e.name]))
			seeded_ok = seeded_ok and slow_after <= fast_before
		var t: Dictionary = rd.targets()
		for g in rd.heats.size():
			if g != rd.player_heat and rd._mix_for(g) == "chase":
				chase += 1
			groups_seen += 1
		rd.start_round(false, "pack").run()
		rd.finish_round()
		overall_ok = overall_ok and rd.overall.size() == n and rd.is_done()
		var times: Array = rd.overall.filter(func(r): return r.get("status", "") == "").map(func(r): return float(r.time))
		for k in range(1, times.size()):
			overall_ok = overall_ok and times[k] >= times[k - 1]
		var mine: Dictionary = rd.player_results[0]
		var at := -1
		for k in rd.overall.size():
			if rd.overall[k].is_player:
				at = k + 1
		place_ok = place_ok and (mine.status != "" or int(mine.place) == at) and int(mine.field) == n
		if t.medal > 0.0 and times.size() >= 3:
			medal_est.append(float(t.medal))
			medal_real.append(float(times[2]))
	_ok("sections of at most %d, the last at least 4 (seen %s)" % [cap, str(sizes_seen.keys())], sizes_ok)
	_ok("the best seeds together, the slowest section runs first", seeded_ok)
	_ok("the overall list holds everyone, by time", overall_ok)
	_ok("the player's place is the place in the overall list (field = everyone)", place_ok)
	var err := 0.0
	for k in medal_est.size():
		err += medal_est[k] - medal_real[k]
	print("    sections chasing a time: %d of %d (the player's not counted); medal estimate - real 3rd: %+.2f s (%d days)" % [
			chase, groups_seen, err / maxf(medal_est.size(), 1), medal_est.size()])


## Heats (forced, as no youth meet runs them): the WA split, Q / q marks, the final's size, the targets, chasing.
func _check_heats(key: String) -> void:
	RD.format_override = "heats"
	var meet: Dictionary = Cal.get_meet(key)
	var indoor: bool = meet.get("indoor", false)
	var final_size := 6 if indoor else 8
	print("-- heats (forced): %s (%d race days)" % [meet.name, _n])
	var marks_ok := true
	var final_ok := true
	var first_ok := true
	var cutoff_ok := true
	var chase := 0
	var later := 0
	var splits := {}
	var played := 0
	for i in _n:
		var rd = RD.new(meet, game.athlete, game.rivals)
		if rd.format != "heats":
			continue
		var n: int = rd.heats.reduce(func(s, h): return s + h.size(), 0)
		splits["%d: %d heats, %d Q + %d q" % [n, rd.heats.size(), rd._auto_places(), rd._time_spots()]] = true
		for g in rd.heats.size():
			if g > 0:
				later += 1
		var t: Dictionary = rd.targets()
		first_ok = first_ok and (rd.player_heat > 0 or float(t.cutoff) == 0.0)
		for g in range(1, rd.heats.size()):
			if g < rd.player_heat and rd._mix_for(g) == "chase":
				chase += 1
		var guard := 0
		while not rd.is_done() and guard < 4:
			guard += 1
			var groups: int = rd.heats.size()
			var round_kind: String = rd.rounds[rd.round_index]
			rd.start_round(false, "pack").run()
			rd.finish_round()
			if round_kind in ["heat", "semi"]:
				var expect: int = groups * int(rd._plan[rd.round_index - 1][1]) + int(rd._plan[rd.round_index - 1][2])
				# (exactly the table's size: a Q place left empty by a DNF / DQ goes to the next fastest time; fewer only when
				# too few runners finished)
				var finishers := 0
				for res in rd.heat_results:
					finishers += res.filter(func(r): return str(r.get("status", "")) == "").size()
				marks_ok = marks_ok and rd.heat_marks.size() == mini(expect, finishers)
				# The cutoff the player was told is a real time from an earlier heat (or none).
			if not rd.qualified:
				break
		if rd.qualified and rd.round_index >= rd.rounds.size():
			played += 1
			final_ok = final_ok and rd.player_results.back().round == "Final" and int(rd.player_results.back().field) <= final_size
	_ok("Q + q = the next round's size (DNF / DQ can leave a place empty); splits seen: %s" % str(splits.keys()), marks_ok)
	_ok("finals of at most %d (%d race days reached the final)" % [final_size, played], final_ok)
	_ok("in the first heat no time spot is known yet", first_ok)
	print("    heats before the player's that chased a time spot: %d of %d later heats" % [chase, later])


## A big field: heats, semi-finals, final (WA outdoors from 25 runners, e.g. 41-48: 6 heats 3 + 6 → 3 semis 2 + 2 → 8).
func _check_semis() -> void:
	RD.format_override = "heats"
	print("-- semi-finals (forced heats, a field of 25 or more)")
	var meet: Dictionary = Cal.get_meet("sm_14_15@2027")
	var found := false
	for i in 40:
		var rd = RD.new(meet, game.athlete, game.rivals)
		if rd.rounds.size() < 3:
			continue
		found = true
		_ok("rounds heat, semi, final", rd.rounds == ["heat", "semi", "final"])
		rd.start_round(false, "pack").run()
		rd.finish_round()
		if not rd.qualified:
			_ok("out after the heats: done", rd.is_done())
			break
		var semi_n: int = rd.heats.reduce(func(s, h): return s + h.size(), 0)
		var row: Array = rd._plan[1]
		_ok("semi-finals: %d groups, %d runners (WA row: %d groups)" % [rd.heats.size(), semi_n, int(row[0])],
				rd.heats.size() == int(row[0]) and semi_n <= rd.heats.size() * 8)
		_ok("round name of the semi", rd.round_name().begins_with("Semi-final"))
		rd.start_round(false, "pack").run()
		rd.finish_round()
		if rd.qualified:
			_ok("final of at most 8", rd.final_entrants.size() <= 8 and rd.round_name() == "Final")
		break
	if not found:
		print("    (no field of 25+ in 40 tries)")
