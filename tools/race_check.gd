extends SceneTree
## Dev tool: checks of the race engine (GDD 4.3.1, step R2). Prints PASS / FAIL per check.
## Run: godot --headless --path . -s res://tools/race_check.gd [-- races_per_case]
## - every pre-race plan (front / pack / back) x answer policy (first / last / random answer, quick mode)
##   finishes (no stuck races) and every old decision card still comes up (per plan, watched);
## - rare incidents with their rates raised (falls, DNF, brought down, DQ): every path runs, races finish, results
##   list finishers, then DQ, then DNF;
## - over all those races every event type the commentary (R4) needs occurs, each with who / where / place / gap;
## - heats with automatic places: runners safely through ease off near the line (never in a final);
## - DNF and DQ runners are listed last, without a time.

const NEEDED := ["start", "break_leader", "pace", "pack", "move", "cover", "let_go", "dropped", "boxed", "escape",
		"gap_opens", "contact", "stumble", "fall", "brought_down", "dnf", "dq", "spiked", "lead_change", "kick",
		"kick_dying", "close_finish", "photo_finish", "finish"]
const CARDS := ["break", "bell", "move", "kick", "straight"]

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := 25
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var RaceScript = load("res://scripts/core/race.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var seen_events := {}
	var missing_fields := []
	var stuck := 0
	var races := 0
	print("-- plans x answers (%d races each)" % n)
	for plan in ["front", "pack", "back"]:
		var cards_of_plan := {}
		for policy in ["first", "last", "random", "quick"]:
			var cards := {}
			var places := 0.0
			for i in n:
				var race = RaceScript.new()
				race.interactive = policy != "quick"
				race.setup(_field(rng, 9.0, true), "male", i % 3 == 0, 15.0, rng, i % 5 == 0, ["local", "district", "final"][i % 3])
				race.set_player_plan(plan)
				while not race.finished and race.time < 400.0:
					race.run()
					if not race.pending.is_empty():
						var opts: Array = race.pending.options
						cards[race.pending.id] = true
						var pick: Dictionary = opts[0] if policy == "first" else (opts[-1] if policy == "last" \
								else opts[rng.randi_range(0, opts.size() - 1)])
						race.choose(pick.id)
				races += 1
				if not race.finished:
					stuck += 1
				places += race.results().map(func(x): return x.is_player).find(true) + 1
				for ev in race.events:
					seen_events[ev.type] = int(seen_events.get(ev.type, 0)) + 1
					if ev.has("who") and ev.has("i") and not (ev.has("d") and ev.has("pos") and ev.has("gap") and ev.has("player")):
						missing_fields.append(ev.type)
			var asked: Array = CARDS.filter(func(c): return cards.has(c))
			print("    %-5s %-6s average place %.1f, cards seen: %s" % [plan, policy, places / n, ", ".join(asked)])
			cards_of_plan.merge(cards)
		_ok("%s: every card comes up (watched)" % plan, CARDS.all(func(c): return cards_of_plan.has(c)))
	_ok("no stuck race in %d" % races, stuck == 0)

	# Rare incidents (a DNF is ~6 % of falls): the rates raised for a few races so every path runs.
	print("-- rare incidents (rates raised for this check)")
	var c: Dictionary = root.get_node("Data").races.engine.contact
	var b: Dictionary = root.get_node("Data").races.engine.box
	var saved := [c.fall, c.dnf, c.brought_down, b.push, b.push_dq]
	c.fall = 0.5
	c.dnf = 0.3
	c.brought_down = 0.8
	b.push = 5.0
	b.push_dq = 0.5
	var rare := {}
	var order_ok := true
	for i in 30:
		var race = RaceScript.new()
		race.setup(_field(rng, 9.0, true), "male", false, 15.0, rng, false, "final")
		while not race.finished and race.time < 400.0:
			race.run()
		races += 1
		if not race.finished:
			stuck += 1
		for ev in race.events:
			rare[ev.type] = int(rare.get(ev.type, 0)) + 1
			seen_events[ev.type] = int(seen_events.get(ev.type, 0)) + 1
		var res: Array = race.results()
		var ranks := {"": 0, "dq": 1, "dnf": 2}
		for k in range(1, res.size()):
			order_ok = order_ok and ranks[res[k].status] >= ranks[res[k - 1].status]
			order_ok = order_ok and (res[k].status == "") == (res[k].time > 0.0)
	c.fall = saved[0]
	c.dnf = saved[1]
	c.brought_down = saved[2]
	b.push = saved[3]
	b.push_dq = saved[4]
	print("    ", rare)
	_ok("falls, DNF, brought down and DQ all happen; the races still finish (%d stuck)" % stuck,
			["fall", "dnf", "brought_down", "dq"].all(func(t): return rare.has(t)) and stuck == 0)
	_ok("results: finishers, then DQ, then DNF, no time without a status", order_ok)

	print("-- heats: easing off when safely through")
	var eased := {"heat": 0, "final": 0}
	for round in ["heat", "final"]:
		for i in n:
			var race = RaceScript.new()
			race.setup(_field(rng, 9.0, false), "male", true, 15.0, rng, false, round)
			race.auto_places = 2 if round == "heat" else 0
			race.run()
			for ev in race.events:
				seen_events[ev.type] = int(seen_events.get(ev.type, 0)) + 1
				if ev.type == "ease":
					eased[round] += 1
					if ev.pos > 2:
						_ok("only runners in an automatic place ease (pos %d)" % ev.pos, false)
	print("    eased: ", eased)
	_ok("in heats runners safely through ease off", eased.heat > 0)
	_ok("never in a final", eased.final == 0)

	print("-- event list (%d races)" % races)
	print("    ", seen_events)
	var missing: Array = NEEDED.filter(func(t): return not seen_events.has(t))
	_ok("every event type occurs (missing: %s)" % str(missing), missing.is_empty())
	_ok("every runner event has who / where / place / gap (%d without)" % missing_fields.size(), missing_fields.is_empty())

	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


## 7 rivals around `ability` and (with_player) the player.
func _field(rng: RandomNumberGenerator, ability: float, with_player: bool) -> Array:
	var out := []
	for k in 8:
		var ab := ability + rng.randfn(0.0, 0.6)
		out.append({"name": "R%d" % k, "club": "", "ability": ab, "speed": ab + rng.randfn(0, 2), "anaerobic": rng.randfn(0, 2),
				"tactics": clampf(rng.randfn(8.0, 3.0), 1.0, 20.0), "consistency": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0),
				"composure": 10.0, "competitiveness": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0)})
	if with_player:
		out[7].name = "You"
		out[7].is_player = true
		out[7].erase("competitiveness")
		out[7].determination = 10.0
	return out


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1
