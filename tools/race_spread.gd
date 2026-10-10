extends SceneTree
## Dev tool: how much does ONE athlete's 800 m time vary from race to race? (playtest fix 1, 2026-10-10)
## Run: godot --headless --path . -s res://tools/race_spread.gd [-- races [save_file [config]]]
## The athlete comes from a COPY of a save file (default: the first autosave found in the scratchpad argument) or, with
## no file, a fixed athlete of ability 7. Every race has the same athlete, an 8-runner field, and a new dice seed.
## Rows: quick = the real quick mode (Race.interactive = false); sensible = a watched race always answered with
## Race.sensible_choice; mixed = a watched race answered like quick mode but counting the wrong answers; and the
## effect of the form / sickness multipliers worked out from the data. Prints mean, sd, min, max, the 5th and 95th
## percentile and the biggest gap between two races in a row, in seconds, plus the table (even-effort) time.
## config: 0 district meet (field ability 7 +- 1.6), 1 youth final (field 9 +- 0.5), 2 indoor heat.

const CONFIGS := [
	["district meet", false, 7.0, 1.6, "district"],
	["youth final", false, 9.0, 0.5, "final"],
	["indoor heat", true, 8.0, 0.8, "heat"],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 100
	var Perf = load("res://scripts/core/race_performance.gd")
	var AthleteScript = load("res://scripts/core/athlete.gd")
	var a = null
	if args.size() > 1 and FileAccess.file_exists(args[1]):
		var txt := FileAccess.get_file_as_string(args[1])
		var d: Dictionary = JSON.parse_string(txt)
		a = AthleteScript.from_dict(d.game.athlete)
	var cfg: Array = CONFIGS[int(args[2])] if args.size() > 2 else CONFIGS[0]
	var entrant: Dictionary
	var gender := "male"
	if a != null:
		entrant = Perf.player_profile(a)
		gender = a.gender
	else:
		entrant = {"ability": 7.0, "speed": 7.0, "anaerobic": 0.0, "tactics": 8.0, "consistency": 8.0, "composure": 8.0,
				"competitiveness": 8.0, "determination": 8.0}
	if args.size() > 3:   # a consistency to try instead of the athlete's own
		entrant.consistency = float(args[3])
	entrant.name = "You Player"
	entrant.club = ""
	entrant.is_player = true
	var table: float = Perf.time_for(entrant.ability, gender)
	print("%s; athlete ability %.2f (table time %.2f s), tactics %.1f, consistency %.1f, %d races per row" % [
			cfg[0], entrant.ability, table, entrant.tactics, entrant.consistency, n])
	var quick := []
	var sensible := []
	var mixed := []
	var wrong_times := {}   # number of wrong answers -> [times]
	for i in n:
		quick.append(_play(cfg, entrant, gender, i, "quick").time)
		sensible.append(_play(cfg, entrant, gender, i, "sensible").time)
		var m := _play(cfg, entrant, gender, i, "mixed")
		mixed.append(m.time)
		if not wrong_times.has(m.wrong):
			wrong_times[m.wrong] = []
		wrong_times[m.wrong].append(m.time)
	_report("quick (real quick mode)", quick, table)
	_report("watched, sensible answers", sensible, table)
	_report("watched, answered like quick mode", mixed, table)
	for k in wrong_times.keys():
		var arr: Array = wrong_times[k]
		var s := 0.0
		for t in arr:
			s += t
		print("    mixed with %d wrong answers: %d races, mean %.2f s" % [k, arr.size(), s / arr.size()])
	print("form: at most +-1.5 %% of the time = +-%.1f s; a niggle's race_slowdown: see data/health.json" % [table * 0.015])
	quit()


func _report(label: String, times: Array, table: float) -> void:
	var s := times.duplicate()
	s.sort()
	var mean := 0.0
	for t in times:
		mean += t
	mean /= times.size()
	var v := 0.0
	var worst_jump := 0.0
	var big := 0
	for i in times.size():
		v += pow(times[i] - mean, 2)
		if i > 0:
			worst_jump = maxf(worst_jump, absf(times[i] - times[i - 1]))
			if absf(times[i] - times[i - 1]) > 15.0:
				big += 1
	var sd := sqrt(v / times.size())
	print("  %-34s mean %.2f (table %+.2f)  sd %.2f  min %.2f  p5 %.2f  p95 %.2f  max %.2f  biggest jump %.2f  jumps over 15 s: %d %%" % [
			label, mean, mean - table, sd, s[0], s[int(s.size() * 0.05)], s[int(s.size() * 0.95)], s[-1], worst_jump,
			roundi(100.0 * big / maxi(times.size() - 1, 1))])


func _play(cfg: Array, entrant: Dictionary, gender: String, i: int, mode: String) -> Dictionary:
	var RaceScript = load("res://scripts/core/race.gd")
	var frng := RandomNumberGenerator.new()
	frng.seed = 1000 + i
	var entrants := []
	for k in 7:
		var ab: float = cfg[2] + frng.randfn(0, cfg[3])
		entrants.append({"name": "Rival R%d" % k, "club": "", "ability": ab, "speed": ab + frng.randfn(0, 2),
				"anaerobic": frng.randfn(0, 2), "tactics": clampf(frng.randfn(8.0, 3.0), 1.0, 20.0),
				"consistency": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0), "composure": 10.0,
				"competitiveness": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0)})
	entrants.append(entrant.duplicate())
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + i
	var arng := RandomNumberGenerator.new()
	arng.seed = 9000 + i
	var race = RaceScript.new()
	race.interactive = mode != "quick"
	race.setup(entrants, gender, false, 15.0, rng, cfg[1], cfg[4])
	race.set_player_plan("pack")
	var wrong := 0
	var auto: Dictionary = root.get_node("Data").races.controls.auto
	while not race.finished and race.time < 400.0:
		if not race.pending.is_empty():
			var d: Dictionary = race.pending
			var pick: String = race.sensible_choice(d.id)
			if mode == "mixed" and d.id != "break":
				if arng.randf() >= lerpf(float(auto.sensible_at_1), float(auto.sensible_at_20), race.player.skill):
					var opts: Array = root.get_node("Data").race_cards.cards[d.id].options
					var other: String = opts[arng.randi_range(0, opts.size() - 1)].id
					if other != pick:
						wrong += 1
					pick = other
			race.choose(pick)
			continue
		race.step()
	return {"time": race.player.t, "wrong": wrong}
