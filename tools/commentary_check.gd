extends SceneTree
## Dev tool (GDD 4.3.1 step R4): plays watched races through the commentary and checks / prints how the lines are used.
## Run: godot --headless --path . -s res://tools/commentary_check.gd [-- races [samples]]
## Plays `races` (default 50) watched races of five kinds (small meet with a stadium announcer; national final;
## senior TV final; indoor heat; international youth meet in the MTV style; a chasing heat), the four coaches in turn, with
## cards answered sensibly (every 4th race badly) and now and then an action-bar command, and checks:
##   - no line (variant) twice in a race; the same id never repeats within a race
##   - at least gap_s race seconds between exchanges, except for the important ones
##   - every event type the engine posts has lines in the data (and the commentary's own); which events were silent, gated,
##     capped, dropped by the rate rules or had no variant that fits (printed per tier)
##   - the coach speaks only about what he can see (Race.coach_sees_at), the verdicts come, the story builds
##   - the commentary does not change the race (the same race with and without it: same results and events), and the same
##     seed gives the same broadcast
## Prints how often each line was used (never-used variants listed) and, with `samples`, N full broadcasts to read.
## Read stderr too: a SCRIPT ERROR aborts a check function but "ALL CHECKS PASSED" may still print.

var _fails := 0
var _checks := 0

const ENGINE_EVENTS := ["start", "break_leader", "pace", "pack", "move", "cover", "let_go", "dropped", "boxed", "escape",
		"gap_opens", "contact", "stumble", "fall", "brought_down", "dnf", "dq", "spiked", "lead_change", "kick", "kick_dying",
		"ease", "close_finish", "photo_finish", "finish"]
const SYNTH_EVENTS := ["move_away", "move_caught", "move_fading", "move_held", "player_finish"]
## Event types that may legitimately have no variant that fits (a quiet pack says nothing).
const QUIET_OK := ["pack", "gap_opens", "spiked", "let_go", "ease", "stumble", "contact", "cover", "dnf", "dq"]

# name, level, indoor, mix, field ability, sd, player ability, gender, extra
const KINDS := [
	["small meet", "local", false, "local", 7.0, 1.4, 7.5],
	["national final", "national", false, "final", 9.0, 0.5, 9.2],
	["senior TV final", "elite", false, "final", 15.0, 0.4, 15.0],
	["indoor heat", "national", true, "heat", 8.0, 0.8, 8.2],
	["international youth meet (MTV style)", "international", false, "district", 8.0, 1.0, 8.5],
	["chasing heat", "elite", false, "chase", 14.0, 0.8, 14.2],
]


func _initialize() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", what)


func _run() -> void:
	var n := 50
	var samples := 3
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	if args.size() > 1:
		samples = int(args[1])
	var data = root.get_node("Data")
	var RaceS = load("res://scripts/core/race.gd")
	var CommS = load("res://scripts/core/race_commentary.gd")
	var StoryS = load("res://scripts/core/race_story.gd")
	var CoachesS = load("res://scripts/core/coaches.gd")
	_static_checks(data, CoachesS)

	var usage := {}
	var tier_stats := {}
	var per_tier_lines := {}
	var voices := {}
	var tier_voice := {}
	var verdict_total := 0
	var verdict_by := {}
	var verdict_scores := {}
	var coach_lines_by := {}
	var story_moments := []
	var story_cases := {}
	var shown_samples := {}
	var gap_fails := 0
	var dup_fails := 0
	var invisible_coach := 0
	var races_with_banner := 0
	for i in n:
		var kind: Array = KINDS[i % KINDS.size()]
		var coach_id: String = data.coaches.pool[i % data.coaches.pool.size()]
		var poor := i % 4 == 3
		var res := _play(i, kind, coach_id, poor, true, RaceS, CommS, data)
		var comm = res.comm
		var race = res.race
		per_tier_lines[comm.tier] = per_tier_lines.get(comm.tier, []) + [comm.lines.size()]
		# no line twice in a race
		var ids := {}
		for l in comm.lines:
			usage[l.id] = int(usage.get(l.id, 0)) + 1
			voices[l.voice] = int(voices.get(l.voice, 0)) + 1
			var tvk: String = comm.tier + ":" + str(l.voice)
			tier_voice[tvk] = int(tier_voice.get(tvk, 0)) + 1
			if ids.has(l.id):
				dup_fails += 1
				print("DUPLICATE id in one race: ", l.id)
			ids[l.id] = true
			if l.voice == "coach":
				coach_lines_by[coach_id] = int(coach_lines_by.get(coach_id, 0)) + 1
				if l.has("d") and not str(l.key).begins_with("coach.finish") and not race.coach_sees_at(float(l.d)):
					invisible_coach += 1
					print("COACH SPOKE ABOUT SOMETHING HE CANNOT SEE: ", l.text, " at ", l.d, " m")
		# spacing of the cast channel (commentator, expert, announcer, fan): exchanges at least gap_s apart unless important
		var cast_t := []
		for l in comm.lines:
			if l.voice in ["tv", "announcer", "fan"]:
				var imp: bool = data.race_commentary.events.get(l.key, {}).get("important", false)
				cast_t.append([float(l.t), imp])
		for k in range(1, cast_t.size()):
			if cast_t[k][0] - cast_t[k - 1][0] < float(data.race_commentary.rules.gap_s) - 0.05 and not cast_t[k][1]:
				gap_fails += 1
		for l in comm.lines:
			if l.has("banner"):
				races_with_banner += 1
				break
		for k in comm.stats:
			var t: String = comm.tier
			var key: String = t + ":" + k
			if not tier_stats.has(key):
				tier_stats[key] = {"seen": 0, "said": 0, "gated": 0, "maxed": 0, "no_match": 0, "exhausted": 0, "silent": 0, "late": 0, "dropped": 0}
			for f in comm.stats[k]:
				tier_stats[key][f] += comm.stats[k][f]
		verdict_total += comm.verdicts.size()
		for v in comm.verdicts:
			verdict_by[v.outcome] = int(verdict_by.get(v.outcome, 0)) + 1
			var vk := "%s.%s" % [v.card, v.answer]
			verdict_scores[vk] = verdict_scores.get(vk, []) + [v.score]
		var story = StoryS.build(race, {"commentary": comm, "coach_id": coach_id})
		story_moments.append(story.moments.size())
		story_cases[story.case] = int(story_cases.get(story.case, 0)) + 1
		_ok(story.splits.size() == 4 and story.coach != "", "story has 4 split rows and a coach line (race %d)" % i)
		if race.player.status == "":
			_ok(story.splits[3].you != "–", "player's finish time in the story (race %d)" % i)
			_ok(story.splits[0].you != "–", "player's 200 m split in the story (race %d)" % i)
		if i < samples * KINDS.size() and not shown_samples.has(kind[0]) and i >= 0:
			shown_samples[kind[0]] = true
			_print_sample(i, kind, comm, story)
	print("")
	print("== Lines per race by tier (min / mean / max)")
	for t in per_tier_lines:
		var a: Array = per_tier_lines[t]
		a.sort()
		var sum := 0
		for x in a:
			sum += x
		print("  %-9s %d / %.1f / %d  (%d races)" % [t, a[0], float(sum) / a.size(), a[-1], a.size()])
	print("== Lines by voice: ", voices)
	for t in per_tier_lines:
		var races: int = per_tier_lines[t].size()
		var parts := []
		for v in ["announcer", "tv", "expert", "coach", "you", "fan"]:
			if tier_voice.has(t + ":" + v):
				parts.append("%s %.1f" % [v, float(tier_voice[t + ":" + v]) / races])
		print("   %-9s per race: %s" % [t, ", ".join(parts)])
	print("== Coach lines by coach: ", coach_lines_by)
	print("== Verdicts: %d (%s), races with a banner: %d" % [verdict_total, verdict_by, races_with_banner])
	print("== Verdict scores by card.answer (mean over n; good at +1.5, bad at -1.5):")
	var vkeys := verdict_scores.keys()
	vkeys.sort()
	for k in vkeys:
		var arr: Array = verdict_scores[k]
		var s := 0.0
		for x in arr:
			s += x
		print("     %-18s n=%2d  mean %+.2f" % [k, arr.size(), s / arr.size()])
	print("== Story: moments per race min %d max %d, coach cases %s" % [story_moments.min(), story_moments.max(), story_cases])
	_ok(dup_fails == 0, "no line twice in a race")
	_ok(gap_fails == 0, "exchanges at least gap_s apart unless important (%d too close)" % gap_fails)
	print("")
	print("== Events by tier (seen / said / gated / capped / no variant fits / used up / silent / dropped by rate rules)")
	var types := ENGINE_EVENTS + SYNTH_EVENTS
	for t in ["announcer", "stream", "tv"]:
		for e in types:
			var s: Dictionary = tier_stats.get(t + ":" + e, {})
			if s.is_empty():
				print("  %-9s %-14s never happened" % [t, e])
				continue
			var note := ""
			if t != "announcer" and int(s.no_match) > 0 and not (e in QUIET_OK):
				note = "   <-- no variant fits %d times" % int(s.no_match)
				_ok(false, "%s: %s had %d events with no variant that fits" % [t, e, int(s.no_match)])
			if t != "announcer" and int(s.silent) > 0 and not (e in ["finish_dummy"]):
				if not (e in ["close_finish", "photo_finish", "finish", "start"]) or int(s.silent) > int(s.seen):
					note += "   <-- silent %d" % int(s.silent)
			if int(s.exhausted) > 0:
				note += "   (all lines that fit were used up %d times)" % int(s.exhausted)
			print("  %-9s %-14s %4d / %4d / %4d / %4d / %4d / %4d / %4d / %4d (+%d after the winner)%s" % [t, e, s.seen, s.said, s.gated, s.maxed, s.no_match, s.exhausted, s.silent, s.dropped, s.late, note])
	print("")
	_usage_report(usage, data)

	# The race itself must not change, and the same seed must give the same broadcast.
	var a = _play(7, KINDS[1], "calm", false, true, RaceS, CommS, data, 12345)
	var b = _play(7, KINDS[1], "calm", false, false, RaceS, CommS, data, 0)
	_ok(JSON.stringify(a.race.results()) == JSON.stringify(b.race.results()), "the race has the same results with and without the commentary")
	_ok(JSON.stringify(a.race.events) == JSON.stringify(b.race.events), "the race has the same events with and without the commentary")
	CommS.reset_memory()
	var c1 = _play(7, KINDS[1], "calm", false, true, RaceS, CommS, data, 12345)
	CommS.reset_memory()
	var c2 = _play(7, KINDS[1], "calm", false, true, RaceS, CommS, data, 12345)
	_ok(JSON.stringify(c1.comm.lines.map(func(l): return [l.t, l.text])) == JSON.stringify(c2.comm.lines.map(func(l): return [l.t, l.text])),
			"the same seed gives the same broadcast")
	# The coach's spot
	var rr = RaceS.new()
	rr.setup(_entrants(0, KINDS[1], RaceS), "male", false, 10.0, _rng(1), false, "final")
	_ok(rr.coach_sees_at(200.0) and rr.coach_sees_at(600.0) and rr.coach_sees_at(150.0), "outdoors the coach sees the 200 m start and its surroundings")
	_ok(not rr.coach_sees_at(0.0) and not rr.coach_sees_at(400.0) and not rr.coach_sees_at(800.0), "outdoors the coach does not see the finish straight")
	var ri = RaceS.new()
	ri.setup(_entrants(0, KINDS[3], RaceS), "male", false, 10.0, _rng(1), true, "heat")
	_ok(ri.coach_sees_at(0.0) and ri.coach_sees_at(333.0), "indoors the coach sees the whole track")
	for cid in data.coaches.pool:
		_ok(CoachesS.get_coach(cid).has("shouts") and CoachesS.get_coach(cid).lines.has("split_ok"), "coach %s has shouts and lines" % cid)

	_ok(invisible_coach == 0, "the coach speaks only about what he can see")
	print("")
	print("commentary_check: %d checks, %d failed -> %s" % [_checks, _fails, "ALL CHECKS PASSED" if _fails == 0 else "SOME CHECKS FAILED"])
	quit()


func _rng(seed_: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	return r


## A field of 8 around the kind's ability; rivals carry the dictionaries the facts come from.
func _entrants(i: int, kind: Array, RaceS) -> Array:
	var frng := _rng(1000 + i)
	var types := ["front", "pack", "kicker", "surger"]
	var entrants := []
	var clubs := ["Tampereen Pyrintö", "Helsingin Kisa-Veikot", "Lahden Ahkera", "Oulun Pohjan Pojat", "Turun Urheiluliitto"]
	for k in 8:
		var ab: float = kind[4] + frng.randfn(0, kind[5])
		var first: String = ["Aino", "Eetu", "Veeti", "Siiri", "Oona", "Leevi", "Niko", "Iida"][k]
		var last: String = ["Korhonen", "Savolainen", "Heikkinen", "Laine", "Virtanen", "Mäkinen", "Nieminen", "Salo"][k]
		var pb := 0.0
		if k % 3 != 2:
			pb = 120.0 + frng.randf() * 40.0
		var rival := {"first_name": first, "last_name": last, "pb": pb, "sb": pb + 1.0 if pb > 0.0 else 0.0,
				"sb_season": 2027 if pb > 0.0 and k % 2 == 0 else 2026, "met": 2 if k % 3 == 0 else 0, "personality": types[k % 4]}
		entrants.append({"name": "%s %s" % [first, last], "club": clubs[k % clubs.size()], "ability": ab,
				"speed": ab + frng.randfn(0, 2), "anaerobic": frng.randfn(0, 2),
				"tactics": clampf(frng.randfn(8.0, 3.0), 1.0, 20.0), "consistency": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0),
				"composure": 10.0, "competitiveness": clampf(frng.randfn(9.0, 3.0), 1.0, 20.0), "rival": rival,
				"personality": types[k % 4]})
	entrants[7] = {"name": "Jaakko Testaaja", "club": "Hämeenlinnan Hurjat", "ability": kind[6], "speed": kind[6], "anaerobic": 0.0, "tactics": 10.0,
			"consistency": 10.0, "composure": 10.0, "determination": 10.0, "is_player": true}
	return entrants


## One watched race with (or without) the commentary. Returns {race, comm}.
func _play(i: int, kind: Array, coach_id: String, poor: bool, with_comm: bool, RaceS, CommS, data, seed_ := 0) -> Dictionary:
	var entrants := _entrants(i, kind, RaceS)
	var race = RaceS.new()
	race.interactive = true
	race.coach_id = coach_id
	var rng := _rng(5000 + i)
	race.setup(entrants, "male", kind[1] != "local", 15.0, rng, kind[2], kind[3])
	race.set_player_plan(["front", "pack", "back"][i % 3])
	if kind[3] in ["heat", "chase"]:
		race.auto_places = 2
	var ath = load("res://scripts/core/athlete.gd").new()
	ath.first_name = "Jaakko"
	ath.last_name = "Testaaja"
	ath.club_id = ""
	ath.main_event = "800m"
	ath.birth_date = {"year": 2012, "month": 3, "day": 4}
	ath.coach_id = coach_id
	ath.personal_bests = {"800m": 140.0} if i % 2 == 0 else {}
	var meet := {"id": "test_meet", "name": "Test Meet", "level": kind[1], "date": {"year": 2027, "month": 6, "day": 8},
			"description": "National championships for 14-15-year-olds: the highlight of the summer."}
	var targets := {}
	if kind[3] == "chase":
		targets = {"kind": "heats", "cutoff": 133.0, "medal": 0.0}
	elif i % 5 == 1:
		targets = {"kind": "sections", "medal": 131.0, "top8": 136.0}
	var comm = null
	if with_comm:
		comm = CommS.new(race, {"meet": meet, "athlete": ath, "targets": targets, "seed": seed_ if seed_ != 0 else 9000 + i,
				"today": {"year": 2027, "month": 6, "day": 1}, "entries": []})
	var cmd_rng := _rng(77 + i)
	var steps := 0
	while not race.finished and race.time < 400.0:
		if not race.pending.is_empty():
			var d: Dictionary = race.pending
			var pick: String = race.sensible_choice(d.id)
			if poor:
				var others: Array = d.options.filter(func(o): return o.id != pick)
				pick = others[cmd_rng.randi_range(0, others.size() - 1)].id
			race.choose(pick)
			continue
		if steps % 450 == 200:
			var cmd: String = ["push", "ease", "hold", "move_out"][cmd_rng.randi_range(0, 3)]
			race.command(cmd)
		race.step()
		steps += 1
		if comm != null:
			comm.update()
	if comm != null:
		for k in 30:   # (the finish: the screen keeps calling update while it waits)
			comm.update()
	return {"race": race, "comm": comm}


func _static_checks(data, CoachesS) -> void:
	var cfg: Dictionary = data.race_commentary
	for t in ENGINE_EVENTS + SYNTH_EVENTS:
		var spec: Dictionary = cfg.events.get(t, {})
		_ok(not spec.is_empty(), "events.%s exists in the data" % t)
		if spec.is_empty():
			continue
		_ok(spec.has("tv") and not spec.tv.is_empty(), "events.%s has commentator lines" % t)
	for t in cfg.events:
		_ok(t in ENGINE_EVENTS or t in SYNTH_EVENTS, "events.%s is a known event type" % t)
	for tier in cfg.tiers:
		_ok(cfg.crews.has(tier if tier != "tv" else "yle"), "crew for tier %s" % tier)
	_ok(CoachesS.id_of(null) == str(data.coaches.pool[0]), "a missing athlete has the default coach")


func _usage_report(usage: Dictionary, data) -> void:
	var cfg: Dictionary = data.race_commentary
	var all := []
	for t in cfg.events:
		for voice in ["tv", "expert", "announcer"]:
			for i in cfg.events[t].get(voice, []).size():
				all.append("%s.%s.%d" % [t, voice, i])
	for f in cfg.fillers:
		all.append("filler." + str(f.id))
	for key in cfg.you:
		for i in cfg.you[key].size():
			all.append("you.%s.%d" % [key, i])
	for key in cfg.fan:
		for i in cfg.fan[key].size():
			all.append("fan.%s.%d" % [key, i])
	var unused := all.filter(func(id): return not usage.has(id) and not usage.has(id + ".reply"))
	var counts := usage.values()
	counts.sort()
	print("== Line usage: %d lines said from %d distinct variants of %d in the broadcast data (%d never used)" % [
			_sum(counts), usage.size(), all.size(), unused.size()])
	var hot := []
	for id in usage:
		hot.append([usage[id], id])
	hot.sort_custom(func(a, b): return a[0] > b[0])
	print("   most used: ", ", ".join(hot.slice(0, 8).map(func(h): return "%s x%d" % [h[1], h[0]])))
	print("   never used (conditions that did not come up in these races, or events that are rare): ", ", ".join(unused.slice(0, 60)))


func _sum(a: Array) -> int:
	var s := 0
	for x in a:
		s += int(x)
	return s


func _print_sample(i: int, kind: Array, comm, story: Dictionary) -> void:
	print("")
	print("---- SAMPLE %d: %s · tier %s · style %s · coach %s · %s" % [i, kind[0], comm.tier, comm.style, comm.coach_id, comm.crew_text()])
	for l in comm.lines:
		print("  %6.1f  %-9s %s%s" % [float(l.t), l.voice.to_upper(), l.text, "   [BANNER: %s]" % l.banner if l.has("banner") else ""])
	print("  -- story: ", story.splits.map(func(s): return "%s %s | %s" % [s.label, s.you, s.winner]))
	for m in story.moments:
		print("     %4d m  %s" % [m.m, m.text])
	print("     %s: \"%s\"" % [story.coach_name, story.coach])
