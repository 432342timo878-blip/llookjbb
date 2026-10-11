extends SceneTree
## Check of the coach model (GDD 4.9.1-4.9.2, session C1; CoachSystem, data/coaching.json):
## 1. the data (11 attributes, voices, temperaments, fit, trust, real coaches have a source);
## 2. the club-coach generator over many athletes (averages ~7-13, strong and weak spots, the old voice kept, the same
##    career = the same coach, the global dice untouched, a neutral club coach differs only in his attributes) and the
##    spread of averages, qualifications, focus, style, groups and fit;
## 3. a coach of 10s changes nothing (a year through the game: model off = model on with 10s, bit for bit);
## 4. a coach of 16s changes only what his attributes say (each knowledge group alone, every other attribute alone, all
##    16s, a weak endurance coach), and the race-advice accuracy;
## 5. fit and trust (words, drift, add_trust);
## 6. save / load bit for bit with a real club coach; a version-3 save (made here by removing the coach) gets the same
##    club coach back; with "-- saves=<folder of COPIES of saves>" also those saves (load, coach, 7 days, save, reload).
## Run: godot --headless --path . -s res://tools/coach_check.gd [-- [athletes for part 2, default 500] [saves=<folder>]]
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var game
var data
var F
var C
var H
var SS
var saves
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	C = load("res://scripts/core/coach_system.gd")
	H = load("res://scripts/core/health_system.gd")
	SS = load("res://scripts/core/season_system.gd")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	var args := OS.get_cmdline_user_args()
	var n := 500
	var folder := ""
	for arg in args:
		if arg.is_valid_int():
			n = arg.to_int()
		elif arg.begins_with("saves="):
			folder = arg.trim_prefix("saves=").replace("\\", "/").trim_suffix("/") + "/"
	_data_checks()
	_generator(n)
	H.model_enabled = false
	_neutral_and_16s()
	_fit_and_trust()
	H.model_enabled = true
	_save_load()
	if folder != "":
		_old_saves(folder)
	C.neutral_club = false
	C.model_enabled = true
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


# --- 1. Data -------------------------------------------------------------------------------------

func _data_checks() -> void:
	print("== 1. Data (data/coaching.json, coaches.json, background_questions.json)")
	var cg: Dictionary = data.coaching
	var ids := []
	for at in cg.attributes:
		ids.append(at.id)
	_ok("11 coach attributes, each with a name and a description",
			ids.size() == 11 and cg.attributes.all(func(at): return str(at.get("name", "")) != "" and str(at.get("description", "")) != ""))
	var groups_ok := true
	for g in cg.effects.training.groups:
		groups_ok = groups_ok and g in ids
		for attr_id in cg.effects.training.groups[g]:
			groups_ok = groups_ok and not data.get_attribute(attr_id).is_empty()
	_ok("training groups name coach attributes and athlete attributes", groups_ok)
	_ok("race advice reads a coach attribute", str(cg.effects.race_advice.attribute) in ids)
	var voices_ok := true
	for v in data.coaches.pool:
		var lean: Dictionary = cg.personalities.get(v, {}).get("lean", {})
		voices_ok = voices_ok and cg.personalities.has(v) and str(data.coaches.coaches[v].get("gender", "")) in ["male", "female"]
		for k in lean:
			voices_ok = voices_ok and k in ids
	_ok("every voice in the pool has a personality entry (lean on real attributes) and a gender", voices_ok)
	var temps: Array = cg.temperaments.keys().filter(func(k): return k != "_note")
	var pressure: Dictionary = {}
	for q in data.background_questions:
		if q.id == "pressure":
			pressure = q
	_ok("every 'pressure' answer has a known temperament",
			not pressure.is_empty() and pressure.answers.all(func(ans): return str(ans.get("temperament", "")) in temps))
	var fit_ok := true
	for t in cg.fit.matrix:
		fit_ok = fit_ok and t in temps
		for p in cg.fit.matrix[t]:
			fit_ok = fit_ok and p in data.coaches.pool
	_ok("fit matrix uses known temperaments and voices", fit_ok)
	_ok("trust has a target for every fit and every word",
			["click", "fine", "friction"].all(func(k): return cg.trust.target.has(k))
			and ["new", "good", "strong", "strained"].all(func(k): return cg.trust.words.has(k)))
	_ok("every real coach has a source (%d real coaches)" % cg.real.size(),
			cg.real.all(func(c): return bool(c.get("real", true)) and str(c.get("source", "")) != ""))


# --- 2. The club-coach generator ------------------------------------------------------------------------

func _random_athlete(i: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	var gender := "male" if i % 2 == 0 else "female"
	var first: String = data.names[gender][rng.randi_range(0, data.names[gender].size() - 1)]
	var last: String = data.names.surnames[rng.randi_range(0, data.names.surnames.size() - 1)]
	return F.create({
		"first_name": first, "last_name": last, "gender": gender, "hometown": "Tampere", "club_id": "tap",
		"main_event": "800m", "birth_date": {"year": 2012, "month": rng.randi_range(1, 12), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)


func _generator(n: int) -> void:
	print("\n== 2. The club coach (%d athletes)" % n)
	var cfg: Dictionary = data.coaching.club
	var date: Dictionary = game.START_DATE
	var avgs := []
	var bad_range := 0
	var flat := 0
	var wrong_voice := 0
	var not_same := 0
	var neutral_diff := 0
	var group_bad := 0
	var counts := {"qualification": {}, "event_focus": {}, "style": {}, "demands": {}, "voice": {}, "fit": {}, "group size": {}}
	var by_temp := {}
	for i in n:
		var a = _random_athlete(i)
		C.neutral_club = false
		var c: Dictionary = C.make_club_coach(a, date)
		var again: Dictionary = C.make_club_coach(a, date)
		C.neutral_club = true
		var neutral: Dictionary = C.make_club_coach(a, date)
		C.neutral_club = false
		if JSON.stringify(c) != JSON.stringify(again):
			not_same += 1
		# The neutral club coach: 10s, everything else the same.
		var n_copy: Dictionary = neutral.duplicate(true)
		var c_copy: Dictionary = c.duplicate(true)
		n_copy.erase("attributes")
		c_copy.erase("attributes")
		if JSON.stringify(n_copy) != JSON.stringify(c_copy) or not neutral.attributes.values().all(func(v): return v == 10):
			neutral_diff += 1
		var vals: Array = c.attributes.values()
		if vals.size() != 11 or vals.any(func(v): return typeof(v) != TYPE_INT or v < int(cfg.min) or v > int(cfg.max)):
			bad_range += 1
		if vals.max() - vals.min() < 3:
			flat += 1
		# The voice is the one the athlete's name picked before C1.
		var pool: Array = data.coaches.pool
		if c.voice != str(pool[posmod((a.first_name + " " + a.last_name).hash(), pool.size())]) or c.name != data.coaches.coaches[c.voice].name:
			wrong_voice += 1
		var names := {a.full_name(): true}
		for t in c.group:
			var full: String = t.first_name + " " + t.last_name
			if names.has(full) or not data.coaching.club.group.roles.has(t.role) or abs(int(t.birth_year) - 2012) > 4:
				group_bad += 1
			names[full] = true
		if c.group.size() < int(cfg.group.size[0]) or c.group.size() > int(cfg.group.size[1]):
			group_bad += 1
		avgs.append(C.average(c))
		for key in ["qualification", "event_focus"]:
			_count(counts[key], str(c.facts[key]))
		_count(counts.style, str(c.style))
		_count(counts.demands, str(c.demands))
		_count(counts.voice, str(c.voice))
		_count(counts["group size"], str(c.group.size()))
		var fit: String = C.fit_of(a.temperament, c)
		_count(counts.fit, fit)
		if not by_temp.has(a.temperament):
			by_temp[a.temperament] = {}
		_count(by_temp[a.temperament], fit)
	var mean := 0.0
	for v in avgs:
		mean += v
	mean /= avgs.size()
	var sd := 0.0
	for v in avgs:
		sd += (v - mean) * (v - mean)
	sd = sqrt(sd / avgs.size())
	_ok("the same athlete always gets the same club coach (%d differ)" % not_same, not_same == 0)
	_ok("a neutral club coach (tools) = 10s, everything else the same person (%d differ)" % neutral_diff, neutral_diff == 0)
	_ok("11 whole-number attributes within %d-%d (%d outside)" % [cfg.min, cfg.max, bad_range], bad_range == 0)
	_ok("strong somewhere and weak somewhere: best - worst >= 3 (%d flat coaches)" % flat, flat * 50 <= n)
	_ok("the coach is the person (and voice) the athlete's name picked before C1 (%d wrong)" % wrong_voice, wrong_voice == 0)
	_ok("training groups: %d-%d teammates, unique names, known roles, about the athlete's age (%d bad)" % [cfg.group.size[0], cfg.group.size[1], group_bad], group_bad == 0)
	_ok("averages centre on 10 (mean %.2f, sd %.2f) and stay within about 7-13 (%.1f-%.1f)" % [mean, sd, avgs.min(), avgs.max()],
			absf(mean - 10.0) < 0.3 and sd > 0.8 and avgs.min() >= 6.5 and avgs.max() <= 13.5)
	print("    averages: " + _histogram(avgs))
	for key in counts:
		print("    %s: %s" % [key, _shares(counts[key], n)])
	for t in by_temp:
		var total := 0
		for k in by_temp[t]:
			total += by_temp[t][k]
		print("    fit for '%s': %s" % [t, _shares(by_temp[t], total)])
	# The global dice (rivals use them) are not touched.
	seed(4242)
	var x1 := randi()
	seed(4242)
	C.make_club_coach(_random_athlete(1), date)
	var x2 := randi()
	_ok("making a coach does not touch the global dice", x1 == x2)


func _count(d: Dictionary, key: String) -> void:
	d[key] = int(d.get(key, 0)) + 1


func _shares(d: Dictionary, total: int) -> String:
	var keys := d.keys()
	keys.sort()
	var parts := []
	for k in keys:
		parts.append("%s %d%%" % [k, roundi(100.0 * d[k] / maxi(total, 1))])
	return ", ".join(parts)


func _histogram(vals: Array) -> String:
	var bins := {}
	for v in vals:
		var b := floori(v)
		bins[b] = int(bins.get(b, 0)) + 1
	var keys := bins.keys()
	keys.sort()
	var parts := []
	for k in keys:
		parts.append("%d-%d: %d%%" % [k, k + 1, roundi(100.0 * bins[k] / vals.size())])
	return ", ".join(parts)


# --- 3-4. A coach of 10s / of 16s -------------------------------------------------------------------

## The training_balance M1 athlete.
func _m1_athlete():
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = 0
	return F.create({
		"first_name": "Test", "last_name": "Runner", "gender": "male", "hometown": "Tampere",
		"club_id": "tap", "main_event": "800m", "birth_date": {"year": 2012, "month": 5, "day": 1},
		"answers": answers}, rng)


## A year of the repeating coach week through the game (health off) with the head coach's attributes set to `attrs`
## (others 10; null = the coach model off). Returns {attributes, fatigue, accuracy}.
func _year(attrs) -> Dictionary:
	C.neutral_club = true
	C.model_enabled = attrs != null
	var a = _m1_athlete()
	game.start_career(a, "repeat")
	var cs = game.get_system("coach")
	if attrs != null:
		for k in attrs:
			cs.head().attributes[k] = attrs[k]
	for w in 52:
		while game.advance_day() != game.WEEK_DONE:
			pass
	var out := {"attributes": a.attributes.duplicate(), "fatigue": a.fatigue, "accuracy": cs.race_accuracy(),
			"race_day_accuracy": C.race_accuracy_for(a)}
	C.model_enabled = true
	return out


func _changed(base: Dictionary, other: Dictionary) -> Array:
	var out := []
	for k in base.attributes:
		if base.attributes[k] != other.attributes[k]:
			out.append(k)
	out.sort()
	return out


func _neutral_and_16s() -> void:
	print("\n== 3. A coach of 10s changes nothing (a year of the coach week through the game, health off)")
	var off := _year(null)
	var tens := _year({})
	_ok("model off = model on with a coach of 10s, every attribute and fatigue bit for bit",
			_changed(off, tens).is_empty() and off.fatigue == tens.fatigue)
	_ok("race advice: model off = default (-1), a race reading of 10 = races.json controls.coach.accuracy exactly (%.3f)" % tens.accuracy,
			off.accuracy == -1.0 and tens.accuracy == float(data.races.controls.coach.accuracy))
	var total := 0.0
	for k in tens.attributes:
		total += tens.attributes[k]
	print("    attribute sum %.9f (training_balance's coach row: 206.798298350)" % total)
	_ok("the year gives training_balance's coach-row fingerprint", "%.9f" % total == "206.798298350")

	print("\n== 4. A coach of 16s changes only what his attributes say")
	var groups: Dictionary = data.coaching.effects.training.groups
	for g in groups:
		var r := _year({g: 16})
		# (Only trained gains grow: an attribute of the group that the coach week doesn't train stays the same.)
		var expect: Array = groups[g].duplicate()
		expect.sort()
		var changed := _changed(tens, r)
		var up: bool = changed.all(func(k): return k in expect and r.attributes[k] > tens.attributes[k])
		_ok("%s 16: only his group grows more (%s), nothing else" % [g, _gains(tens, r, expect)],
				not changed.is_empty() and up and r.fatigue == tens.fatigue)
	var weak := _year({"endurance_knowledge": 4})
	var e_ids: Array = groups.endurance_knowledge.duplicate()
	e_ids.sort()
	_ok("endurance_knowledge 4: the endurance attributes grow less (%s)" % _gains(tens, weak, e_ids),
			not _changed(tens, weak).is_empty() and _changed(tens, weak).all(func(k): return k in e_ids and weak.attributes[k] < tens.attributes[k]))
	var others := {}
	for at in data.coaching.attributes:
		if not groups.has(at.id):
			others[at.id] = 16
	var r_others := _year(others)
	_ok("every other attribute at 16 (%s): no training change (prepared hooks only)" % ", ".join(others.keys()),
			_changed(tens, r_others).is_empty() and r_others.fatigue == tens.fatigue)
	var rr: Dictionary = data.coaching.effects.race_advice
	var expect_acc := clampf(float(data.races.controls.coach.accuracy) + 6.0 * float(rr.per_point), float(rr.min), float(rr.max))
	_ok("race reading 16: race advice right %.3f of the time (expected %.3f; a race of the career's athlete gets it: %.3f)" % [r_others.accuracy, expect_acc, r_others.race_day_accuracy],
			absf(r_others.accuracy - expect_acc) < 1e-12 and r_others.race_day_accuracy == r_others.accuracy)
	var all16 := {}
	for at in data.coaching.attributes:
		all16[at.id] = 16
	var r_all := _year(all16)
	var all_ids := []
	for g in groups:
		all_ids.append_array(groups[g])
	all_ids.sort()
	_ok("a coach of 16s everywhere: only the three groups' attributes change, all upwards",
			_changed(tens, r_all).all(func(k): return k in all_ids and r_all.attributes[k] > tens.attributes[k]))
	var sum10 := 0.0
	var sum16 := 0.0
	for k in tens.attributes:
		sum10 += tens.attributes[k]
		sum16 += r_all.attributes[k]
	print("    a year of the coach week: attribute sum %.2f with 10s, %.2f with 16s (+%.2f)" % [sum10, sum16, sum16 - sum10])


func _gains(base: Dictionary, r: Dictionary, ids: Array) -> String:
	var parts := []
	for k in ids:
		parts.append("%s %+.3f" % [k.substr(0, 10), r.attributes[k] - base.attributes[k]])
	return ", ".join(parts)


# --- 5. Fit and trust -----------------------------------------------------------------------------

func _fit_and_trust() -> void:
	print("\n== 5. Fit and trust")
	var f: Dictionary = data.coaching.fit
	var calm := {"personality": "calm", "style": 0}
	var drill := {"personality": "drill", "style": -2}
	_ok("'Overthink everything' clicks with a calm coach", C.fit_of("overthinker", calm) == "click")
	_ok("'Overthink everything' has friction with a very controlling hard driver", C.fit_of("overthinker", drill) == "friction")
	_ok("'Get fired up' clicks with a very controlling hard driver (no controlling penalty)", C.fit_of("fiery", drill) == "click")
	_ok("an unknown temperament (older saves) is Fine with everyone", C.fit_of("", drill) == "fine" and C.fit_of("", calm) == "fine")
	_ok("a very supportive style helps a little (score +%.2f)" % (C.fit_score("steady", {"personality": "tactician", "style": 2})),
			C.fit_score("steady", {"personality": "tactician", "style": 2}) == 2 * float(f.style_weight))
	C.neutral_club = true
	var a = _m1_athlete()
	game.start_career(a, "repeat")
	var cs = game.get_system("coach")
	var t: Dictionary = data.coaching.trust
	_ok("a new coach: trust New, fit '%s' at first" % f.words.unknown, cs.trust_level() == "new" and cs.fit_word() == str(f.words.unknown))
	cs.head().personality = "calm"
	cs.head().style = -2
	a.temperament = "fiery"   # friction
	var levels := []
	for w in 40:
		while game.advance_day() != game.WEEK_DONE:
			pass
		if w in [3, 7, 39]:
			levels.append("%d weeks: %s, fit %s, trust %.1f" % [w + 1, cs.trust_word(), cs.fit_word(), cs.trust()])
	print("    friction: " + " / ".join(levels))
	_ok("friction alone: trust drifts down towards %d but never to Strained (%.1f, %s)" % [t.target.friction, cs.trust(), cs.trust_word()],
			cs.trust() < float(t.start) and cs.trust() > float(t.strained) and cs.trust_level() == "good" and cs.fit_word() == str(f.words.friction))
	cs.add_trust(-40.0, "test")
	_ok("add_trust moves it (Strained below %d) and keeps the cause" % t.strained,
			cs.trust_level() == "strained" and cs.relation().causes.back().cause == "test")
	C.model_enabled = false
	var before: float = cs.trust()
	while game.advance_day() != game.WEEK_DONE:
		pass
	cs.add_trust(10.0, "off")
	_ok("model off: trust stands still", cs.trust() == before)
	C.model_enabled = true


# --- 6. Save / load ---------------------------------------------------------------------------------

func _snapshot() -> String:
	return JSON.stringify({"athlete": game.athlete.to_dict(), "coach": game.get_system("coach").to_dict(), "date": game.date})


func _play_days(days: int) -> void:
	for i in days:
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
			game.answer_event(e.id, e.choices[0].id if not e.choices.is_empty() else "ok")


func _save_load() -> void:
	print("\n== 6. Save / load (a real club coach, health on)")
	C.neutral_club = false
	SS.offers_enabled = false
	var a = _random_athlete(7)
	game.start_career(a, "repeat")
	_play_days(17)
	saves.save("coach_check")
	var file := FileAccess.get_file_as_string(saves.DIR + "coach_check.json")
	var parsed: Dictionary = JSON.parse_string(file)
	_ok("the save is version %d and holds the coach records" % saves.VERSION,
			int(parsed.version) == 4 and parsed.game.systems.has("coach") and not parsed.game.systems.coach.coaches.is_empty())
	var coach_before: String = JSON.stringify(game.get_system("coach").to_dict())
	_play_days(30)
	var straight := _snapshot()
	saves.load_slot("coach_check")
	_ok("after loading: the same coach records and relation", JSON.stringify(game.get_system("coach").to_dict()) == coach_before)
	_play_days(30)
	_ok("30 more days after loading = the same 30 days without saving (athlete, coach, date bit for bit)", _snapshot() == straight)

	# A version-3 save: the same career without coach records (and an athlete without coach_id / temperament).
	var old: Dictionary = parsed.duplicate(true)
	old.version = 3
	old.game.systems.erase("coach")
	old.game.athlete.erase("coach_id")
	old.game.athlete.erase("temperament")
	var f := FileAccess.open(saves.DIR + "coach_check_v3.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(old, " ", true, true))
	f.close()
	var coach_rec: Dictionary = parsed.game.systems.coach.coaches[parsed.game.athlete.coach_id]
	_ok("a version-3 save loads", saves.load_slot("coach_check_v3"))
	var cs = game.get_system("coach")
	var got: Dictionary = cs.head()
	# (The teammates' levels follow the athlete's level on the day the coach is made, so only they may differ.)
	_ok("it gets its club coach: the same person with the same attributes, facts and group (%s)" % got.get("name", "?"),
			_norm(got.attributes) == _norm(coach_rec.attributes) and got.name == coach_rec.name
			and _norm(got.facts) == _norm(coach_rec.facts) and _no_levels(got.group) == _no_levels(coach_rec.group))
	_ok("its temperament is unknown: fit Fine", game.athlete.temperament == "" and cs.fit() == "fine")
	_play_days(7)
	_ok("it plays a week", true)
	saves.delete("coach_check")
	saves.delete("coach_check_v3")
	SS.offers_enabled = true


## The same text for the same content, whether its numbers came from JSON (floats) or not.
func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)))


func _no_levels(group: Array) -> String:
	var out := []
	for t in group:
		var u: Dictionary = t.duplicate()
		u.erase("level")
		out.append(u)
	return _norm(out)


func _old_saves(folder: String) -> void:
	print("\n== 7. Older saves in %s (copies)" % folder)
	var own_dir: String = saves.DIR
	C.neutral_club = false
	for file in DirAccess.get_files_at(folder):
		if not file.ends_with(".json"):
			continue
		var slot := file.trim_suffix(".json")
		var text := FileAccess.get_file_as_string(folder + file)
		var version := int(JSON.parse_string(text).get("version", 1))
		saves.DIR = folder
		var loaded: bool = saves.load_slot(slot)
		saves.DIR = own_dir
		_ok("%s (version %d) loads" % [slot, version], loaded)
		if not loaded:
			continue
		var a = game.athlete
		var cs = game.get_system("coach")
		var c: Dictionary = cs.head()
		var pool: Array = data.coaches.pool
		var old_voice := str(pool[posmod((a.first_name + " " + a.last_name).hash(), pool.size())])
		print("    %s: coach %s (%s, average %.1f, %s, group of %d), trust %s" % [a.full_name(), c.get("name", "?"),
				c.get("voice", "?"), C.average(c) if not c.is_empty() else 0.0, c.get("facts", {}).get("qualification", "?"),
				c.get("group", []).size(), cs.trust_word()])
		_ok("%s: has a coach record, the same person as at races before (%s)" % [slot, old_voice],
				not c.is_empty() and (version >= 4 or c.voice == old_voice))
		_play_days(7)
		saves.save("coach_check_old")
		var coach_state: String = JSON.stringify(cs.to_dict())
		saves.load_slot("coach_check_old")
		_ok("%s: plays 7 days, saves and loads with the same coach" % slot,
				JSON.stringify(game.get_system("coach").to_dict()) == coach_state)
		saves.delete("coach_check_old")
