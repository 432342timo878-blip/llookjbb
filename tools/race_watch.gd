extends SceneTree
## Dev tool: watched with sensible choices vs quick mode (GDD 4.3.1 "Balance and verification": at most ~1 place
## better on average) and how the new cards behave (R3).
## Run: godot --headless --path . -s res://tools/race_watch.gd [-- races_per_config [config 0-4 [tactics 1-20]]]
## Every race is played three ways from the same field, lanes and seed (the same starting dice):
##   quick    - non-interactive: the athlete answers every card (race tactics), no action bar
##   sensible - watched: every card answered with Race.sensible_choice (a player who always does the sensible thing)
##   coach    - watched: every card answered with the coach's shout when he can see it, else the sensible answer
## Prints per config and mode: the player's average place and time, how many cards a race shows (and which), the
## share of race time the screen would hold at 1x (slow motion, Race.moment_since), the answers given, the coach's
## shouts (how many, how many were the sensible answer); and the sensible-vs-quick gap.

const CONFIGS := [
	# name, gender, indoor, field ability, field sd, player ability, mix
	["youth final, player a little stronger", "male", false, 9.0, 0.5, 9.4, "final"],
	["district meet, wide field, player in the top half", "male", false, 7.0, 1.6, 8.0, "district"],
	["girls even field", "female", false, 7.0, 0.8, 7.0, "district"],
	["senior final", "male", false, 15.0, 0.4, 15.0, "final"],
	["indoor heat", "male", true, 8.0, 0.8, 8.2, "heat"],
	# R5 (decision 21): tight finals, where a second is 1-2 places (8th value: the field's consistency mean, default 9)
	["tight final (sd 0.3)", "male", false, 9.0, 0.3, 9.0, "final"],
	["tight final, consistent field (sd 0.3, consistency 15)", "male", false, 9.0, 0.3, 9.0, "final", 15.0],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := 100
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var tactics := 10.0
	if args.size() > 2:
		tactics = float(args[2])
	var configs := CONFIGS
	if args.size() > 1 and int(args[1]) >= 0:
		configs = [CONFIGS[int(args[1])]]
	print("player race tactics %d, %d races per config and mode" % [int(tactics), n])
	for cfg in configs:
		print("== %s" % cfg[0])
		var quick := {}
		var sensible := {}
		var poor := {}
		for mode in ["quick", "sensible", "coach", "poor"]:
			var res := _play(cfg, n, mode, tactics)
			if mode == "quick":
				quick = res
			if mode == "sensible":
				sensible = res
			if mode == "poor":
				poor = res
			print("   %-9s place %.2f  time %.2f s%s  cards/race %.2f  1x share %2d %%  | %s" % [mode, res.place, res.time,
					(" (DNF/DQ %d)" % res.lost) if res.lost > 0 else "", res.cards, roundi(res.slow * 100.0), _counts(res.by_card)])
			if mode != "quick":
				print("             answers: %s" % _counts(res.answers))
			if mode == "coach":
				print("             coach: shouts %.2f per race, right %d %%, silent cards %d %%" % [res.shouts,
						roundi(res.right * 100.0), roundi(res.silent * 100.0)])
		print("   felt reserve at the cards (share of the reserve, mean): %s" % _means(sensible.share))
		print("   sensible vs quick: %+.2f places better on average (target: at most about 1); sensible vs poor: %+.2f places, %+.2f s (%+.2f %%)" % [
				quick.place - sensible.place, poor.place - sensible.place, poor.time - sensible.time,
				100.0 * (poor.time - sensible.time) / sensible.time])
	quit()


func _play(cfg: Array, n: int, mode: String, tactics: float) -> Dictionary:
	var RaceScript = load("res://scripts/core/race.gd")
	var sm: Dictionary = root.get_node("Data").races.controls.slow_motion
	var place := 0.0
	var time := 0.0
	var cards := 0
	var by_card := {}
	var answers := {}
	var slow_time := 0.0
	var race_time := 0.0
	var shouts := 0
	var right := 0
	var silent := 0
	var asked := 0
	var share_log := {}
	var timed := 0
	var lost := 0
	for i in n:
		var frng := RandomNumberGenerator.new()
		frng.seed = 1000 + i
		var entrants := []
		var cons: float = cfg[7] if cfg.size() > 7 else 9.0
		for k in 8:
			var ab: float = cfg[3] + frng.randfn(0, cfg[4])
			entrants.append({"name": "Rival R%d" % k, "club": "", "ability": ab, "speed": ab + frng.randfn(0, 2),
					"anaerobic": frng.randfn(0, 2), "tactics": clampf(frng.randfn(8.0, 3.0), 1.0, 20.0),
					"consistency": clampf(frng.randfn(cons, 3.0), 1.0, 20.0), "composure": 10.0,
					"competitiveness": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0)})
		entrants[7] = {"name": "You Player", "club": "", "ability": cfg[5], "speed": cfg[5], "anaerobic": 0.0, "tactics": tactics,
				"consistency": 10.0, "composure": 10.0, "determination": 10.0, "is_player": true}
		var rng := RandomNumberGenerator.new()
		rng.seed = 5000 + i
		var race = RaceScript.new()
		race.interactive = mode != "quick"
		race.setup(entrants, cfg[1], false, 15.0, rng, cfg[2], cfg[6])
		race.set_player_plan("pack")
		var seen := 0
		var slow_left := 0.0
		while not race.finished and race.time < 400.0:
			if not race.pending.is_empty():
				var d: Dictionary = race.pending
				var pick: String = race.sensible_choice(d.id)
				asked += 1
				if d.has("coach"):
					shouts += 1
					if d.coach.option == pick:
						right += 1
				else:
					silent += 1
				if mode == "coach" and d.has("coach"):
					pick = d.coach.option
				if mode == "poor":   # anything but the sensible answer
					var others: Array = d.options.filter(func(o): return o.id != pick)
					pick = others[rng.randi_range(0, others.size() - 1)].id
				var shares: Array = share_log.get(d.id, [])
				shares.append(race._felt(race.player) / race.player.dprime)
				share_log[d.id] = shares
				var key := "%s:%s" % [d.id, pick]
				answers[key] = int(answers.get(key, 0)) + 1
				race.choose(pick)
				continue
			race.step()
			if race.moment_since(seen):
				slow_left = float(sm.seconds)
			seen = race.events.size()
			if slow_left > 0.0:
				slow_time += 0.1
				slow_left -= 0.1
			race_time += 0.1
		place += race.results().map(func(x): return x.is_player).find(true) + 1
		if race.player.status == "":
			time += race.player.t
			timed += 1
		else:
			lost += 1
		cards += race.cards_shown
		for c in race.card_log:
			by_card[c.id] = int(by_card.get(c.id, 0)) + 1
	return {"place": place / n, "time": time / maxf(timed, 1), "lost": lost, "cards": float(cards) / n, "by_card": by_card, "answers": answers,
			"slow": slow_time / maxf(race_time, 1.0), "shouts": float(shouts) / n,
			"right": float(right) / maxf(shouts, 1), "silent": float(silent) / maxf(asked, 1), "share": share_log}


func _means(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	return ", ".join(keys.map(func(k):
		var a: Array = d[k]
		var sum := 0.0
		for x in a:
			sum += x
		return "%s %.2f" % [k, sum / a.size()]))


func _counts(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	return ", ".join(keys.map(func(k): return "%s %s" % [k, d[k]]))
