extends SceneTree
## Dev tool: what is each answer of each card worth? (R3 follow-up, "mistakes must cost"; R5)
## Run: godot --headless --path . -s res://tools/race_value.gd [-- races [card|card+card|all [config 0-6 [plan]]]]
## Every race is played with the sensible answer to every card (Race.sensible_choice); then again for each answer
## of one card, answered with that answer the first time the card comes up and sensibly otherwise. Everything
## before that moment is identical, so the difference is the value of that one decision. Prints per card and
## answer, over the races where the card came up: the mean difference in the player's finishing time (s, % of the
## time; only races where the player finished both times) and place (DNF / DQ = last) against the sensible answer
## (positive = worse), how often it was the sensible answer, and the DNF / DQ count. The move card is also split
## by the mover's edge over the player (day ability, kick); the box card by whether there was room to push through.

const CONFIGS := [
	# name, gender, indoor, field ability, field sd, player ability, mix, (field consistency mean, default 9)
	["youth final", "male", false, 9.0, 0.5, 9.4, "final"],
	["district meet", "male", false, 7.0, 1.6, 8.0, "district"],
	["girls even field", "female", false, 7.0, 0.8, 7.0, "district"],
	["senior final", "male", false, 15.0, 0.4, 15.0, "final"],
	["indoor heat", "male", true, 8.0, 0.8, 8.2, "heat"],
	["tight final (sd 0.3)", "male", false, 9.0, 0.3, 9.0, "final"],
	["tight final, consistent field (sd 0.3, consistency 15)", "male", false, 9.0, 0.3, 9.0, "final", 15.0],
]


var _plan := "pack"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := 100
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var cards: Array = root.get_node("Data").race_cards.cards.keys()
	if args.size() > 1 and args[1] != "all":
		cards = Array(args[1].split("+"))
	var cfg: Array = CONFIGS[int(args[2])] if args.size() > 2 else CONFIGS[0]
	if args.size() > 3:   # the pre-race plan (default pack; back gives many more box cards)
		_plan = args[3]
	print("%s, plan %s, %d races per card and answer" % [cfg[0], _plan, n])
	for id in cards:
		var options: Array = root.get_node("Data").race_cards.cards[id].options.map(func(o): return o.id)
		var base := {}
		for i in n:
			base[i] = _play(cfg, i, "", "")
		var came := base.keys().filter(func(i): return base[i].asked.has(id))
		if came.is_empty():
			print("  %-9s never came up in %d races" % [id, n])
			continue
		print("  %-9s came up in %d races" % [id, came.size()])
		var results := {}   # option -> {i: result}
		for opt in options:
			results[opt] = {}
			for i in came:
				results[opt][i] = _play(cfg, i, id, opt)
		# By how far there is to go when the card comes up (metres): far / middle / near; the move card also by the
		# mover's edge, the box card by room.
		var buckets := [["more than 400 m to go", func(i): return base[i].at[id] > 400.0],
				["250-400 m to go", func(i): return base[i].at[id] > 250.0 and base[i].at[id] <= 400.0],
				["under 250 m to go", func(i): return base[i].at[id] <= 250.0]]
		if id == "move":
			buckets += [["mover over 1 % stronger on the day", func(i): return base[i].info.move.edge > 0.01],
					["mover within 1 % on the day", func(i): return absf(base[i].info.move.edge) <= 0.01],
					["mover over 1 % weaker on the day", func(i): return base[i].info.move.edge < -0.01],
					["mover within 6 m", func(i): return base[i].info.move.near],
					["mover further away", func(i): return not base[i].info.move.near],
					["mover's kick better", func(i): return base[i].info.move.kick_better],
					["mover's kick worse", func(i): return not base[i].info.move.kick_better],
					["a surge (not a kick)", func(i): return not base[i].info.move.kicking],
					["a kick", func(i): return base[i].info.move.kicking]]
		if id == "box":
			buckets += [["room to push through", func(i): return base[i].info.box.room],
					["no room", func(i): return not base[i].info.box.room]]
		for bucket in buckets:
			var sub: Array = came.filter(bucket[1])
			if sub.size() < 8:
				continue
			print("    %s (%d races)" % [bucket[0], sub.size()])
			for opt in options:
				var dt := 0.0
				var nt := 0
				var dp := 0.0
				var same := 0
				var lost := 0
				for i in sub:
					var r: Dictionary = results[opt][i]
					if r.finished and base[i].finished:
						dt += r.time - base[i].time
						nt += 1
					elif not r.finished:
						lost += 1
					dp += r.place - base[i].place
					if base[i].asked[id] == opt:
						same += 1
				var m := float(sub.size())
				print("      %-9s time %+.2f s (%+.2f %%)  place %+.2f   (the sensible answer in %d %%)%s" % [opt,
						dt / maxf(nt, 1), 100.0 * dt / maxf(nt, 1) / 140.0, dp / m, roundi(100.0 * same / m),
						("  DNF/DQ %d" % lost) if lost > 0 else ""])
	quit()


## One race: `force_id`/`force_opt` answered the first time that card comes up, everything else sensibly.
func _play(cfg: Array, i: int, force_id: String, force_opt: String) -> Dictionary:
	var RaceScript = load("res://scripts/core/race.gd")
	var frng := RandomNumberGenerator.new()
	frng.seed = 1000 + i
	var cons: float = cfg[7] if cfg.size() > 7 else 9.0
	var entrants := []
	for k in 8:
		var ab: float = cfg[3] + frng.randfn(0, cfg[4])
		entrants.append({"name": "Rival R%d" % k, "club": "", "ability": ab, "speed": ab + frng.randfn(0, 2),
				"anaerobic": frng.randfn(0, 2), "tactics": clampf(frng.randfn(8.0, 3.0), 1.0, 20.0),
				"consistency": clampf(frng.randfn(cons, 3.0), 1.0, 20.0), "composure": 10.0,
				"competitiveness": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0)})
	entrants[7] = {"name": "You Player", "club": "", "ability": cfg[5], "speed": cfg[5], "anaerobic": 0.0, "tactics": 10.0,
			"consistency": 10.0, "composure": 10.0, "determination": 10.0, "is_player": true}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + i
	var race = RaceScript.new()
	race.interactive = true
	race.setup(entrants, cfg[1], false, 15.0, rng, cfg[2], cfg[6])
	race.set_player_plan(_plan)
	var asked := {}
	var at := {}
	var info := {}
	var forced := false
	while not race.finished and race.time < 400.0:
		if not race.pending.is_empty():
			var d: Dictionary = race.pending
			var pick: String = race.sensible_choice(d.id)
			if not asked.has(d.id):
				asked[d.id] = pick
				at[d.id] = 800.0 - race.player.d
				if d.id == "move":
					var m = race._card_mover
					var p = race.player
					info["move"] = {"edge": (m.even_v / p.even_v - 1.0) if m != null else 0.0,
							"near": m != null and absf(m.d - p.d) <= 6.0,
							"kick_better": m != null and m.kick_v > p.kick_v, "kicking": m != null and m.kicking}
				if d.id == "box":   # (box_room is new in R5: the older engine has no room rule)
					info["box"] = {"room": race.box_room(race.player) if race.has_method("box_room") else false}
				if d.id == force_id and not forced:
					forced = true
					pick = force_opt
			race.choose(pick)
			continue
		race.step()
	var res: Array = race.results()
	var place := res.map(func(x): return x.is_player).find(true) + 1
	return {"time": race.player.t, "finished": race.player.status == "", "place": float(place), "asked": asked, "at": at,
			"info": info}
