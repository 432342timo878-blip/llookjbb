extends SceneTree
## Dev tool: checks of the race engine (GDD 4.3.1, steps R2, R3 and R5). Prints PASS / FAIL per check.
## Run: godot --headless --path . -s res://tools/race_check.gd [-- races_per_case]
## - every pre-race plan (front / pack / back) x answer policy (first / last / random answer + random action bar
##   commands, quick mode) finishes (no stuck races), shows at most the data's maximum of cards, break / bell once each;
## - R5 boxes: the best way out (the room decides), easing out costs a few metres, the box card says if there is room;
## - rare incidents with their rates raised (falls, DNF, brought down, DQ): every path runs, races finish, results
##   list finishers, then DQ, then DNF;
## - over all those races every event type the commentary (R4) needs occurs, each with who / where / place / gap;
## - heats with automatic places: runners safely through ease off near the line (never in a final);
## - R3: every card comes up, and every answer of every card changes what the engine does (state right after the
##   answer, and the finished race differs between answers); no card is asked twice at once; the budget holds;
## - R3: the action bar's commands (push / hold / ease / move out / kick), the Feeling words, the coach's rule, the
##   slow-motion moments, quick mode answering the cards.

const NEEDED := ["start", "break_leader", "pace", "pack", "move", "cover", "let_go", "dropped", "boxed", "escape",
		"gap_opens", "contact", "stumble", "fall", "brought_down", "dnf", "dq", "spiked", "lead_change", "kick",
		"kick_dying", "close_finish", "photo_finish", "finish"]
const CARDS := ["break", "bell", "kick", "move", "box", "dropped", "slow", "straight", "fall"]

var _fails := 0
var _RaceScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := 25
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	_RaceScript = load("res://scripts/core/race.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var seen_events := {}
	var missing_fields := []
	var stuck := 0
	var races := 0
	var cards_seen := {}
	var over_budget := 0
	var bad_always := 0
	print("-- plans x answers (%d races each)" % n)
	for plan in ["front", "pack", "back"]:
		for policy in ["first", "last", "random", "quick"]:
			var cards := {}
			var places := 0.0
			for i in n:
				var race = _RaceScript.new()
				race.interactive = policy != "quick"
				race.setup(_field(rng, 9.0, true), "male", i % 3 == 0, 15.0, rng, i % 5 == 0, ["local", "district", "final"][i % 3])
				race.set_player_plan(plan)
				while not race.finished and race.time < 400.0:
					if not race.pending.is_empty():
						var opts: Array = race.pending.options
						cards[race.pending.id] = true
						var pick: Dictionary = opts[0] if policy == "first" else (opts[-1] if policy == "last" \
								else opts[rng.randi_range(0, opts.size() - 1)])
						race.choose(pick.id)
						continue
					race.step()
					if policy == "random" and rng.randf() < 0.01:   # the action bar, pressed at random
						race.command(["push", "hold", "ease", "move_out", "kick"][rng.randi_range(0, 4)])
				races += 1
				if not race.finished:
					stuck += 1
				places += race.results().map(func(x): return x.is_player).find(true) + 1
				for ev in race.events:
					seen_events[ev.type] = int(seen_events.get(ev.type, 0)) + 1
					if ev.has("who") and ev.has("i") and not (ev.has("d") and ev.has("pos") and ev.has("gap") and ev.has("player")):
						missing_fields.append(ev.type)
				for c in race.card_log:
					cards_seen[c.id] = int(cards_seen.get(c.id, 0)) + 1
				if race.cards_shown > int(root.get_node("Data").races.controls.cards.max) or race.card_log.size() != race.cards_shown:
					over_budget += 1
				var counts := {}
				for c in race.card_log:
					counts[c.id] = int(counts.get(c.id, 0)) + 1
				if race.player.status == "" and (counts.get("break", 0) != 1 or counts.get("bell", 0) != 1):
					bad_always += 1
			var asked: Array = CARDS.filter(func(c): return cards.has(c))
			print("    %-5s %-6s average place %.1f, cards seen: %s" % [plan, policy, places / n, ", ".join(asked)])
	_ok("no stuck race in %d" % races, stuck == 0)
	_ok("never more than the data's maximum of cards in a race (%d races over)" % over_budget, over_budget == 0)
	_ok("break and bell are asked exactly once in every race (%d without)" % bad_always, bad_always == 0)
	print("    cards seen: ", cards_seen)
	_ok("every card comes up in the races above (missing: %s)" % str(CARDS.filter(func(c): return not cards_seen.has(c))),
			CARDS.all(func(c): return cards_seen.has(c)))

	# Rare incidents (a DNF is ~6 % of falls): the rates raised for a few races so every path runs.
	print("-- rare incidents (rates raised for this check)")
	var c: Dictionary = root.get_node("Data").races.engine.contact
	var b: Dictionary = root.get_node("Data").races.engine.box
	var saved := [c.fall, c.dnf, c.brought_down, b.push, b.push_dq]
	c.fall = 0.5
	c.dnf = 0.3
	c.brought_down = 0.8
	b.push = 5.0
	b.push_dq = [0.5, 0.5]   # [no room, room]
	var rare := {}
	var order_ok := true
	for i in 30:
		var race = _RaceScript.new()
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
			var race = _RaceScript.new()
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

	print("-- R5: boxed in (decision 22)")
	_boxes(rng)

	print("-- R3: every answer of every card does something")
	_effects(rng)
	print("-- R3: the action bar, Feeling, the coach, slow motion, quick mode")
	_controls(rng)

	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


# --- R5: boxed in ---------------------------------------------------------------------------------------

## The best way out depends on the distance left (wait early, ease mid-race, push late with room); easing and
## stepping out costs a few metres, not the race; the box card says whether there is room.
func _boxes(rng: RandomNumberGenerator) -> void:
	var data = root.get_node("Data")
	var best: Dictionary = data.races.engine.box.best
	var race = _RaceScript.new()
	race.setup(_field(rng, 9.0, true), "male", false, 15.0, rng, false, "final")
	var p = race.player
	var ways := {}
	var near: float = float(best.push_to_go) / 2.0
	for case in [[500.0, false], [near, false], [500.0, true], [300.0, true], [near, true]]:
		p.d = 800.0 - case[0]
		p.room = case[1]
		ways["%d m to go%s" % [roundi(case[0]), ", room" if case[1] else ""]] = race._box_best(p)
	print("    best way out: ", ways)
	_ok("the best way out (the room decides): no room wait, room ease and step out, push through near the line",
			ways.values() == ["wait", "wait", "ease", "ease", "push"])
	# Over many finals: what easing and stepping out costs against the runner who was ahead, for boxes that lasted.
	var lost := []
	var rooms := {true: 0, false: 0}
	var texts_ok := true
	var ph: Dictionary = data.race_cards.phrases
	for i in 40:
		var r = _RaceScript.new()
		r.interactive = true
		r.setup(_field(rng, 9.0, true), "male", false, 15.0, rng, false, "final")
		r.set_player_plan("back")
		while not r.finished and r.time < 400.0:
			if not r.pending.is_empty():
				var d: Dictionary = r.pending
				if d.id == "box":
					rooms[r.player.room] += 1
					var line: String = ph.room if r.player.room else String(ph.no_room).replace("{name}", "")
					texts_ok = texts_ok and String(d.text).contains(line)
				r.choose(r.sensible_choice(d.id))
				continue
			r.step()
		for ev in r.events:
			if ev.type == "escape" and ev.way == "ease" and float(ev.seconds) >= 1.0:
				lost.append(float(ev.lost))
	lost.sort()
	var med: float = lost[lost.size() / 2] if not lost.is_empty() else 0.0
	print("    easing out of boxes that lasted 1 s or more: %d, median %.1f m lost against the runner ahead (90th percentile %.1f m)" % [
			lost.size(), med, lost[int(lost.size() * 0.9)] if not lost.is_empty() else 0.0])
	_ok("easing and stepping out costs a few metres (median %.1f m, design 2-4 m: at most 4)" % med, lost.size() >= 10 and med > 0.3 and med <= 4.0)
	print("    box cards: with room %d, without %d" % [rooms[true], rooms[false]])
	_ok("the box card says whether there is room", texts_ok and rooms[true] + rooms[false] > 0)


# --- R3: the answers ---------------------------------------------------------------------------------

## For each card, races are played watched; whenever the card comes up it is answered with the next answer in turn
## (so every answer is tried) and the state right after the answer is checked. Cases tune the field or raise a
## rate so the rare cards come up often enough.
func _effects(rng: RandomNumberGenerator) -> void:
	var data: Dictionary = root.get_node("Data").races
	var cases := {
		"break": {"tries": 24}, "bell": {"tries": 24}, "kick": {"tries": 24}, "straight": {"tries": 60},
		"move": {"tries": 60}, "box": {"tries": 120, "box_after_s": 0.2},
		"dropped": {"tries": 60, "player_ability": 6.0}, "slow": {"tries": 80, "tactical": true},
		"fall": {"tries": 80, "fall": 0.5},
	}
	for id in cases:
		var cs: Dictionary = cases[id]
		var options: Array = root.get_node("Data").race_cards.cards[id].options.map(func(o): return o.id)
		var done := {}
		var differ := {}   # option -> finishing times of the player
		var saved_fall: float = data.engine.contact.fall
		var saved_after: float = data.controls.cards.box_after_s
		var saved_rate: Dictionary = data.engine.moves.rate_per_100.duplicate()
		var saved_mix: Dictionary = data.shapes.mix.final.duplicate()
		if cs.get("tactical", false):   # every final tactical (a front runner in the field moves a little back)
			data.shapes.mix.final = {"fast": 0, "honest": 0, "tactical": 100}
		if cs.has("fall"):
			data.engine.contact.fall = cs.fall
		if cs.has("box_after_s"):
			data.controls.cards.box_after_s = cs.box_after_s
		if id == "box" or id == "move":   # more moves, so boxes with a move going and moves near the player are common
			for k in data.engine.moves.rate_per_100:
				data.engine.moves.rate_per_100[k] = float(data.engine.moves.rate_per_100[k]) * 6.0
		var bad := 0
		var tries := int(cs.get("tries", 40))
		for t in tries:
			var race = _RaceScript.new()
			race.interactive = true
			var f := _field(rng, 9.0, true)
			f[7].ability = float(cs.get("player_ability", 9.0))
			f[7].speed = f[7].ability
			race.setup(f, "male", false, 15.0, rng, id == "bell" and t % 2 == 0, "final")
			race.set_player_plan(["front", "pack", "back"][t % 3])
			var answered := ""
			while not race.finished and race.time < 400.0:
				if not race.pending.is_empty():
					var d: Dictionary = race.pending
					var pick: String = d.options[rng.randi_range(0, d.options.size() - 1)].id
					if d.id == id and answered == "":
						# the least tried answer first
						var least: String = options[0]
						for o in options:
							if int(done.get(o, 0)) < int(done.get(least, 0)):
								least = o
						pick = least
						answered = pick
						var before := _snapshot(race)
						race.choose(pick)
						done[pick] = int(done.get(pick, 0)) + 1
						if not _effect_ok(race, id, pick, before):
							bad += 1
							print("    wrong state after %s / %s: %s" % [id, pick, str(_snapshot(race))])
					else:
						race.choose(pick)
					continue
				race.step()
			if not race.finished:
				bad += 1
			if answered != "" and race.player.status == "":
				if not differ.has(answered):
					differ[answered] = []
				differ[answered].append(race.player.t)
		data.shapes.mix.final = saved_mix
		data.engine.contact.fall = saved_fall
		data.controls.cards.box_after_s = saved_after
		for k in saved_rate:
			data.engine.moves.rate_per_100[k] = saved_rate[k]
		print("    %-8s answered: %s" % [id, str(done)])
		_ok("%s: every answer was tried and left the right state (%d wrong)" % [id, bad],
				options.all(func(o): return int(done.get(o, 0)) >= 2) and bad == 0)


## The runner state an answer can change.
func _snapshot(race) -> Dictionary:
	var p = race.player
	return {"want": p.want, "effort": race.effort, "pace_factor": p.pace_factor, "dig_boost": p.dig_boost,
			"kicking": p.kicking, "kick_at": p.kick_at, "kick_free": p.kick_free, "covering": p.covering != null,
			"surge_left": p.surge_left, "hold_left": p.hold_left, "box_way": p.box_way, "pending": race.pending.is_empty()}


func _effect_ok(race, id: String, opt: String, before: Dictionary) -> bool:
	var p = race.player
	var ctl: Dictionary = root.get_node("Data").races.controls
	if not race.pending.is_empty():
		return false
	match [id, opt]:
		["break", "lead"]:
			return p.want == "lead"
		["break", "shoulder"]:
			return p.want == "pack"
		["break", "back"]:
			return p.want == "back"
		["bell", _]:
			return race.effort == opt and is_equal_approx(p.pace_factor, float(ctl.effort[opt]))
		["fall", "chase"]:
			return is_equal_approx(p.dig_boost, float(ctl.chase.dig)) and race.effort == ctl.chase.effort and p.commit_left > 0.0
		["fall", "steady"]:
			return p.dig_boost == 0.0 and race.effort == ctl.steady.effort and p.kick_at <= float(ctl.steady.kick_at)
		["kick", "now"]:
			return p.kicking
		["kick", "wait"]:
			return is_equal_approx(p.kick_at, 100.0) and not p.kick_free
		["box", _]:
			return p.box_way == opt
		["move", "go"]:
			return (p.covering and p.commit_left > 0.0) or p.kicking
		["move", "wait"]:
			var m = race._card_mover
			return not p.kicking and (m == null or m.kicking or p.hold_left > 0.0)
		["move", "counter"]:
			return p.kicking or p.surge_left > 0.0
		["dropped", "dig"]:
			return is_equal_approx(p.dig_boost, float(ctl.dig_in)) and p.commit_left > 0.0
		["dropped", "own"]:
			return p.dig_boost == 0.0
		["slow", "lead"]:
			return p.want == "lead" and race.effort == ctl.take_lead.effort
		["slow", "stay"]:
			return p.want == before.want
		["straight", _]:
			return p.kicking
	return false


# --- R3: the action bar and the rest ------------------------------------------------------------------

func _controls(rng: RandomNumberGenerator) -> void:
	var ctl: Dictionary = root.get_node("Data").races.controls
	# The action bar's commands.
	var race = _RaceScript.new()
	race.setup(_field(rng, 9.0, true), "male", false, 15.0, rng, false, "final")
	race.set_player_plan("pack")
	var p = race.player
	_ok("before the break: push / hold / ease allowed, move out and kick not",
			race.can_command("push") and race.can_command("ease") and not race.can_command("move_out") and not race.can_command("kick"))
	_ok("an unknown command is refused", not race.command("sprint"))
	for cmd in ["push", "ease", "hold"]:
		race.command(cmd)
		_ok("%s sets the pace factor to the data number" % cmd, race.effort == cmd and is_equal_approx(p.pace_factor, float(ctl.effort[cmd])))
	while p.d < 300.0 and not race.finished:
		race.step()
	_ok("after the break: kick is allowed, move out too unless already 3 m or more from the rail (lat %.1f)" % p.lat,
			race.can_command("kick") and race.can_command("move_out") == (p.lat < float(ctl.move_out.max_lat) - 0.2))
	var left: float = 0.0
	race.command("move_out")
	left = p.out_left
	for i in 40:
		race.step()
	# Over several races: the player ends further from the rail (or stays where they are when already wide / boxed).
	var moved := 0
	var wider := 0
	var tried := 0
	for i in 12:
		var r = _RaceScript.new()
		var frng := RandomNumberGenerator.new()
		frng.seed = 60 + i
		r.setup(_field(frng, 9.0, true), "male", false, 15.0, frng, false, "district")
		r.set_player_plan("pack")
		while r.player.d < 320.0 and not r.finished:
			r.step()
		var lat_before: float = r.player.lat
		if not r.command("move_out"):
			continue   # already out wide
		tried += 1
		for k in 40:
			r.step()
		moved += 1 if r.player.lat > lat_before + 0.3 else 0
		wider += 1 if r.player.lat >= lat_before - 0.1 else 0
	_ok("move out takes the player further from the rail (%d of %d moved out 0.3 m or more, %d never closer to the rail)" % [moved, tried, wider],
			tried >= 4 and moved >= tried - 2 and wider >= tried - 1)
	for i in 60:
		race.step()
	_ok("move out lasts a few seconds and then ends (%.1f s → %.1f s)" % [left, p.out_left], p.out_left <= 0.0 and left > 0.0 or not race.can_command("move_out") and left == 0.0)
	race.command("kick")
	_ok("kick now starts the kick at once", p.kicking)
	_ok("kicking: push / hold / ease and a second kick are refused", not race.can_command("push") and not race.can_command("kick"))
	while not race.finished and race.time < 400.0:
		race.step()
	_ok("after the finish nothing can be commanded", not race.can_command("push") and not race.can_command("kick"))

	# Pushing and easing change the race.
	var times := {}
	for cmd in ["push", "ease"]:
		var sum := 0.0
		for i in 12:
			var r = _RaceScript.new()
			var frng := RandomNumberGenerator.new()
			frng.seed = 77 + i
			r.setup(_field(frng, 9.0, true), "male", false, 15.0, frng, false, "district")
			r.set_player_plan("pack")
			r.command(cmd)
			r.run()
			sum += r.player.t
		times[cmd] = sum / 12.0
	_ok("pushing and easing give different races (push %.1f s, ease %.1f s)" % [times.push, times.ease], absf(times.push - times.ease) > 0.05)

	# Mistakes cost: a kick started far too early dies before the line; pushing hard is paid for later.
	var base_t := 0.0
	var early_t := 0.0
	var n_pair := 24
	for i in n_pair:
		for mode in ["natural", "early"]:
			var r = _RaceScript.new()
			var frng := RandomNumberGenerator.new()
			frng.seed = 800 + i
			r.setup(_field(frng, 9.0, true), "male", false, 15.0, frng, false, "district")
			r.set_player_plan("pack")
			while not r.finished and r.time < 400.0:
				r.step()
				if mode == "early" and r.player.d >= 330.0 and not r.player.kicking:
					r.command("kick")
			if mode == "natural":
				base_t += r.player.t
			else:
				early_t += r.player.t
	print("    a kick from 470 m to go: %.2f s slower on average than the natural kick" % ((early_t - base_t) / n_pair))
	_ok("a kick started far too early costs time (%.2f s over %d races)" % [(early_t - base_t) / n_pair, n_pair], early_t - base_t > 0.5 * n_pair)

	# Feeling: the four words, from the felt reserve and fatigue.
	var words := {}
	var order_ok := true
	for i in 12:
		var r = _RaceScript.new()
		var frng := RandomNumberGenerator.new()
		frng.seed = 400 + i
		r.setup(_field(frng, 9.0, true), "male", false, 15.0, frng, false, "district")
		r.set_player_plan("pack")
		var first: Dictionary = r.feeling()
		order_ok = order_ok and first.index == 0
		var worst := 0
		while not r.finished and r.time < 400.0:
			r.step()
			var f: Dictionary = r.feeling()
			words[f.word] = true
			worst = maxi(worst, f.index)
		order_ok = order_ok and worst >= 2
	print("    Feeling words seen: ", words.keys())
	_ok("Feeling: starts Comfortable, ends Hurting or Empty, all four words come up", order_ok and words.size() == 4)
	var tired = _RaceScript.new()
	var trng := RandomNumberGenerator.new()
	trng.seed = 5
	tired.setup(_field(trng, 9.0, true), "male", false, 60.0, trng, false, "district")
	var fresh = _RaceScript.new()
	trng.seed = 5
	fresh.setup(_field(trng, 9.0, true), "male", false, 5.0, trng, false, "district")
	_ok("Feeling: fatigue makes it worse (same reserve, fatigue 60 vs 5: %.3f vs %.3f)" % [tired.feeling().share, fresh.feeling().share],
			tired.feeling().share < fresh.feeling().share)

	# The coach's rule.
	var indoor = _RaceScript.new()
	indoor.setup(_field(rng, 9.0, true), "male", false, 15.0, rng, true, "district")
	var ok_all := true
	for d in [0.0, 100.0, 250.0, 399.0, 650.0]:
		indoor.player.d = d
		ok_all = ok_all and indoor.coach_sees()
	_ok("coach: indoors he sees the whole track", ok_all)
	var out = _RaceScript.new()
	out.setup(_field(rng, 9.0, true), "male", false, 15.0, rng, false, "district")
	var spot: float = ctl.coach.spot_outdoor
	var view: float = ctl.coach.view_m
	var rule_ok := true
	for d in range(0, 800, 10):
		out.player.d = float(d)
		var dist := absf(fmod(float(d), 400.0) - spot)
		rule_ok = rule_ok and out.coach_sees() == (minf(dist, 400.0 - dist) <= view)
	_ok("coach: outdoors he sees the player within %d m of his spot (%d m round the lap), both laps" % [roundi(view), roundi(spot)], rule_ok)
	var with_coach := 0
	var asked := 0
	var right := 0
	var consistent := true
	for i in 30:
		var r = _RaceScript.new()
		r.interactive = true
		r.setup(_field(rng, 9.0, true), "male", false, 15.0, rng, i % 2 == 0, "final")
		while not r.finished and r.time < 400.0:
			if not r.pending.is_empty():
				var d: Dictionary = r.pending
				asked += 1
				consistent = consistent and d.has("coach") == r.card_log[-1].coach_sees   # (as of the moment the card was asked)
				if d.has("coach"):
					with_coach += 1
					consistent = consistent and d.options.any(func(o): return o.id == d.coach.option) and d.coach.text != ""
					if d.coach.option == r.sensible_choice(d.id):
						right += 1
				r.choose(d.options[0].id)
				continue
			r.step()
	print("    coach: %d of %d cards had a shout, %d right" % [with_coach, asked, right])
	_ok("coach: a shout exactly when he can see, naming one of the answers", consistent and with_coach > 0 and with_coach < asked)
	_ok("coach: right about as often as his accuracy (%d %% vs %d %%)" % [roundi(100.0 * right / maxf(with_coach, 1)), roundi(100.0 * float(ctl.coach.accuracy))],
			absf(float(right) / maxf(with_coach, 1) - float(ctl.coach.accuracy)) < 0.2)

	# Slow motion: which events count.
	var sm = _RaceScript.new()
	sm.setup(_field(rng, 9.0, true), "male", false, 15.0, rng, false, "district")
	sm.player.d = 300.0
	var near := {"type": "fall", "t": 1.0, "who": "x", "i": 1, "player": false, "d": 315}
	var far := {"type": "fall", "t": 1.0, "who": "x", "i": 1, "player": false, "d": 340}
	var box_rival := {"type": "boxed", "t": 1.0, "who": "x", "i": 1, "player": false, "d": 305, "way": "wait"}
	var box_mine := {"type": "boxed", "t": 1.0, "who": "You", "i": 7, "player": true, "d": 300, "way": "wait"}
	var pace := {"type": "pace", "t": 1.0, "who": "x", "i": 1, "player": false, "d": 305}
	sm.events = [near]
	_ok("slow motion: a fall within range counts", sm.moment_since(0))
	sm.events = [far]
	_ok("slow motion: a fall out of range does not", not sm.moment_since(0))
	sm.events = [box_rival, pace]
	_ok("slow motion: a rival's box and a pace call do not", not sm.moment_since(0))
	sm.events = [box_mine]
	_ok("slow motion: the player's own box does", sm.moment_since(0))
	sm.events = [box_mine, near]
	_ok("slow motion: only events after the index are looked at", not sm.moment_since(2) and sm.moment_since(1))
	var shares := []
	for i in 10:
		var r = _RaceScript.new()
		var frng := RandomNumberGenerator.new()
		frng.seed = 900 + i
		r.setup(_field(frng, 9.0, true), "male", false, 15.0, frng, false, "final")
		var seen := 0
		var slow := 0.0
		var left_s := 0.0
		while not r.finished and r.time < 400.0:
			r.step()
			if r.moment_since(seen):
				left_s = float(ctl.slow_motion.seconds)
			seen = r.events.size()
			if left_s > 0.0:
				slow += 0.1
				left_s -= 0.1
		shares.append(slow / r.time)
	var avg := 0.0
	for s in shares:
		avg += s
	avg /= shares.size()
	print("    slow motion holds the race at 1x for %d %% of its time on average" % roundi(avg * 100.0))
	_ok("slow motion is a moment, not the whole race (under 50 % of the time)", avg > 0.02 and avg < 0.5)

	# Quick mode answers the cards, without the player.
	var qcards := 0
	var qrace_ok := true
	for i in 20:
		var r = _RaceScript.new()
		r.setup(_field(rng, 9.0, true), "male", false, 15.0, rng, false, "final")
		r.run()
		qrace_ok = qrace_ok and r.finished and r.pending.is_empty()
		qcards += r.cards_shown
		qrace_ok = qrace_ok and r.card_log.all(func(x): return x.answer != "")
	_ok("quick mode: the athlete answers every card (%d cards in 20 races), nothing waits" % qcards, qrace_ok and qcards > 40)
	var same := true
	for i in 3:
		var logs := []
		for k in 2:
			var r = _RaceScript.new()
			var frng := RandomNumberGenerator.new()
			frng.seed = 31 + i
			r.interactive = false
			r.setup(_field(frng, 9.0, true), "male", false, 15.0, frng, false, "final")
			r.run()
			logs.append(JSON.stringify([r.card_log, r.events.size(), r.player.t]))
		same = same and logs[0] == logs[1]
	_ok("same seed → same race, same cards and answers", same)


## 7 rivals around `ability` and (with_player) the player.
func _field(rng: RandomNumberGenerator, ability: float, with_player: bool) -> Array:
	var out := []
	for k in 8:
		var ab := ability + rng.randfn(0.0, 0.6)
		out.append({"name": "Rival R%d" % k, "club": "", "ability": ab, "speed": ab + rng.randfn(0, 2), "anaerobic": rng.randfn(0, 2),
				"tactics": clampf(rng.randfn(8.0, 3.0), 1.0, 20.0), "consistency": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0),
				"composure": 10.0, "competitiveness": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0)})
	if with_player:
		out[7].name = "You Player"
		out[7].is_player = true
		out[7].erase("competitiveness")
		out[7].determination = 10.0
	return out


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1
