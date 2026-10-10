class_name RaceDay
extends RefCounted
## The player's 800 m at one meet: picks the field from the rival pool and runs it in the meet's format
## (GDD 4.3.1 decision 28; numbers in data/races.json "rounds"):
##   single   - one race (the field fits in one);
##   sections - a straight final in seeded timed sections, as Finnish championships run the 800 m (SUL
##              Mestaruuskilpailusäännöt 2026, 5.7–5.13): the best runners together, the slowest section first, places
##              and medals by time across all sections;
##   heats    - heats (and semi-finals when the table says so) and a final, through on place (Q) and on time (q), from
##              the World Athletics table (WAS Regulations 2025 Appendix 5). The heats are made by zigzag seeding and run
##              in an order drawn by lot (WA TR20.3), so the later heats know the times to beat.
## A meet's format is `format` in data/competitions.json, else rounds.default_format. In heats and later sections the
## runners chase a target time when their leaders can reach it (a faster race shape, decision 33).

## Dev tools: run every meet in this format ("sections" / "heats"; "" = the meet's own).
static var format_override := ""

var meet: Dictionary
var athlete: Athlete
var format := "single"
var rounds: Array[String] = []    # per round: "race" (single), "sections", "heat", "semi", "final"
var round_index := 0
var qualified := true
var fatigue := 0.0                # the player's fatigue going into the current round
var heats: Array = []             # the current round's groups (heats / sections; one group in a final), in running order
var player_heat := 0              # the player's group in `heats`
var final_entrants: Array = []    # a single race / the final: who runs
var heat_results: Array = []      # after a round of groups: every group's results, in running order
var heat_marks := {}              # after heats / semis: runner name → "Q" (through on place) / "q" (through on time)
var overall: Array = []           # after sections: everyone by time across the sections (result rows + "section")
var player_results: Array = []    # [{round, place, field, time, status}] (status "dnf" / "dq": no time, time 0)
var all_results: Array = []       # every race run here (for rival PBs)
var incidents: Array = []         # the player's falls and spike wounds today: [{kind: fall / spiked, round}] (health model)
var current: Race
var slowdown := 0.0               # share slower because of a niggle or illness (HealthSystem.race_slowdown)
var form := 0.0                   # share faster (+) or slower (-) from race-day form (FormSystem.race_form)

var _rng := RandomNumberGenerator.new()
var _gender := "male"
var _indoor := false
var _cfg: Dictionary              # data/races.json "rounds"
var _plan: Array = []             # heats: the table's rounds before the final, [groups, place, time] each
var _group_res: Array = []        # the current round: each group's results once run (null until then)
var _seed := {}                   # runner name → seeding time (season best, else PB; 9999 = no mark)


func _init(m: Dictionary, a: Athlete, pool: Array) -> void:
	meet = m
	athlete = a
	_gender = a.gender
	_indoor = meet.get("indoor", false)
	_cfg = Data.races.rounds
	fatigue = a.fatigue
	_rng.randomize()
	var standard_ability := 0.0
	if meet.has("standard"):
		var limits: Dictionary = Data.competitions.standards[meet.standard].get(a.main_event, {})
		var cls := Calendar.age_class(a, meet.date.year)
		if limits.has(cls):
			standard_ability = RacePerformance.ability_for_time(float(limits[cls]), a.gender)
	var entrants := []
	for r in Rivals.pick_field(pool, meet.level, _rng, standard_ability):
		entrants.append(_rival_entrant(r))
	entrants.append(_player_entrant())
	for e in entrants:
		_seed[e.name] = _seed_time(e)

	format = format_override if format_override != "" else str(meet.get("format", _cfg.default_format))
	var n := entrants.size()
	if format == "heats":
		var row := _heat_row(n)
		if row.is_empty():
			format = "single"
		else:
			for rd in row.rounds:
				_plan.append(rd)
				rounds.append("heat" if rounds.is_empty() else "semi")
			rounds.append("final")
			_make_groups(entrants, int(row.rounds[0][0]))
	elif format == "sections" and n > _section_max():
		rounds = ["sections"]
		_make_sections(entrants)
	else:
		format = "single"
	if format == "single":
		rounds = ["race"]
		final_entrants = entrants


## "Heat 2 of 3", "Semi-final 1 of 2", "Section 2 of 3", "Final", or "Race" for a single race.
func round_name() -> String:
	match rounds[round_index]:
		"heat": return "Heat %d of %d" % [player_heat + 1, heats.size()]
		"semi": return "Semi-final %d of %d" % [player_heat + 1, heats.size()]
		"sections": return "Section %d of %d" % [player_heat + 1, heats.size()]
		"final": return "Final"
	return "Race"


func is_done() -> bool:
	return round_index >= rounds.size() or not qualified


func is_big_meet() -> bool:
	return meet.level in ["national", "international"]


## A round of several groups (heats, semis, sections), the player running in one of them.
func is_group_round() -> bool:
	return round_index < rounds.size() and rounds[round_index] in ["heat", "semi", "sections"]


## Who runs in the player's next race.
func current_entrants() -> Array:
	return heats[player_heat] if is_group_round() else final_entrants


## The player's next race. `interactive` = detailed mode with decision pauses. In a round of groups the groups
## before the player's are run first, so the player knows the times to beat.
func start_round(interactive: bool, plan: String) -> Race:
	if is_group_round():
		_run_groups_until(player_heat)
	var entrants := current_entrants()
	current = Race.new()
	current.interactive = interactive
	current.setup(entrants, _gender, is_big_meet(), fatigue, _rng, _indoor, shape_mix())
	current.auto_places = _auto_places()
	current.coach_id = Coaches.id_of(athlete)   # (his wording on the cards; R4)
	current.set_player_plan(plan)
	return current


## Heats / semis: the automatic qualifying places of the current round (runners safely in one ease off near the
## line); 0 otherwise.
func _auto_places() -> int:
	if round_index < rounds.size() and rounds[round_index] in ["heat", "semi"]:
		return int(_plan[round_index][1])
	return 0


func _time_spots() -> int:
	if round_index < rounds.size() and rounds[round_index] in ["heat", "semi"]:
		return int(_plan[round_index][2])
	return 0


## Which race-shape mix (data/races.json shapes.mix) fits the player's race now: local and district meets by level,
## championships by round (heats run to qualify, finals more tactically); "chase" when a target time from the races
## already run is within the reach of this race's leaders (decision 33).
func shape_mix() -> String:
	return _mix_for(player_heat)


func _mix_for(g: int) -> String:
	var level: String = meet.get("level", "")
	var base := "final"
	if level in ["local", "district"]:
		base = level
	elif round_index < rounds.size() and rounds[round_index] in ["heat", "semi"]:
		base = "heat"
	if is_group_round() and _chases(g):
		return "chase"
	return base


## Does group g chase a time? Heats: a time spot is known from the earlier heats and someone in this heat who is
## not among its favourites for a Q place could make it. Sections: the medal or top-8 time so far is close to what
## this section's leaders run (a section far faster or slower than it has nothing to chase).
func _chases(g: int) -> bool:
	var c: Dictionary = _cfg.chase
	var group: Array = heats[g]
	if rounds[round_index] == "sections":
		var leaders := group.map(func(e): return _paper_time(e))
		leaders.sort()
		var mid: float = leaders[mini(1, leaders.size() - 1)]
		for target in [_kth_time_so_far(g, 3), _kth_time_so_far(g, 8)]:
			if target > 0.0 and absf(mid / target - 1.0) <= float(c.window):
				return true
		return false
	var cutoff := _cutoff_so_far(g)
	if cutoff <= 0.0:
		return false
	var times := group.map(func(e): return _paper_time(e))
	times.sort()
	var outside := times.slice(_auto_places())   # those not expected to take a Q place
	return not outside.is_empty() and float(outside[0]) <= cutoff * (1.0 + float(c.reach))


## A runner's even time on paper (their ability before the day's form).
func _paper_time(e: Dictionary) -> float:
	return RacePerformance.time_for(float(e.ability), _gender)


## Runs the groups before group `upto` that have not been run yet (the player's is run by the race screen).
func _run_groups_until(upto: int) -> void:
	for g in upto:
		if _group_res[g] == null:
			_run_group(g)


func _run_group(g: int) -> void:
	var other := Race.new()
	other.setup(heats[g], _gender, is_big_meet(), 0.0, _rng, _indoor, _mix_for(g))
	other.auto_places = _auto_places()
	other.run()
	_group_res[g] = other.results()
	all_results.append(_group_res[g])


## Call when the player's current race is over.
func finish_round() -> void:
	var res := current.results()
	var name := round_name()
	if current.player != null:
		for k in current.player.falls:
			incidents.append({"kind": "fall", "round": name})
		if current.player.spiked:
			incidents.append({"kind": "spiked", "round": name})
	all_results.append(res)
	if not is_group_round():
		_add_player_result(name, res, res.size())
		round_index += 1
		return
	_group_res[player_heat] = res
	for g in range(player_heat + 1, heats.size()):
		_run_group(g)
	heat_results = _group_res.duplicate()
	if rounds[round_index] == "sections":
		_make_overall()
		_add_player_result(name, overall, overall.size())
		round_index += 1
		return
	_add_player_result(name, res, res.size())
	var through := _qualifiers(heat_results)
	qualified = through.any(func(e): return e.get("is_player", false))
	fatigue = minf(fatigue + 8.0, 100.0)   # the round took something out of you
	round_index += 1
	if round_index < rounds.size() and rounds[round_index] == "semi":
		_make_groups(through, int(_plan[round_index][0]))
	else:
		final_entrants = through
		heats = []


func _add_player_result(name: String, res: Array, field: int) -> void:
	for i in res.size():
		if res[i].is_player:
			player_results.append({"round": name, "place": i + 1, "field": field, "time": res[i].time,
					"status": res[i].status})


## Sections: every finisher by time across the sections, then the disqualified, then those who did not finish.
func _make_overall() -> void:
	var fin := []
	var dq := []
	var dnf := []
	for g in heat_results.size():
		for row in heat_results[g]:
			var r: Dictionary = row.duplicate()
			r.section = g + 1
			match str(r.get("status", "")):
				"dq": dq.append(r)
				"dnf": dnf.append(r)
				_: fin.append(r)
	fin.sort_custom(func(x, y): return x.time < y.time)
	overall = fin + dq + dnf


## Heats / semis: the top `place` of each group plus the fastest of the rest (`time` of them; only runners with a
## time). Fills heat_marks: "Q" for the places, "q" for the times (the marks of a real result list).
func _qualifiers(results_of_groups: Array) -> Array:
	var auto := _auto_places()
	var spots := _time_spots()
	var marks: Dictionary = _cfg.marks
	var by_name := {}
	for h in heats:
		for e in h:
			by_name[e.name] = e
	heat_marks = {}
	var q := []
	var rest := []
	for res in results_of_groups:
		for i in res.size():
			if res[i].get("status", "") != "":
				continue   # did not finish / disqualified (always listed last)
			if i < auto:
				q.append(by_name[res[i].name])
				heat_marks[res[i].name] = marks.place
			else:
				rest.append(res[i])
	rest.sort_custom(func(x, y): return x.time < y.time)
	for k in mini(spots, rest.size()):
		q.append(by_name[rest[k].name])
		heat_marks[rest[k].name] = marks.time
	# The next round is seeded on the original list, improved by today's times (WA TR20.3.2b for the 800 m).
	for res in results_of_groups:
		for row in res:
			if row.get("status", "") == "" and float(row.time) < float(_seed.get(row.name, 9999.0)):
				_seed[row.name] = float(row.time)
	return q


# --- Making the groups -----------------------------------------------------------------------------------

## Seeding time: the season best of the meet's season (calendar year), else the PB; 9999 = no mark (seeded last).
func _seed_time(e: Dictionary) -> float:
	var year := Rankings.season_of(meet.date)
	if e.get("is_player", false):
		var sb := Rankings.player_season_best(athlete, year)
		var pb: float = athlete.personal_bests.get(athlete.main_event, 0.0)
		return sb if sb > 0.0 else (pb if pb > 0.0 else 9999.0)
	var rival: Dictionary = e.get("rival", {})
	if int(rival.get("sb_season", -1)) == year and float(rival.get("sb", 0.0)) > 0.0:
		return float(rival.sb)
	return float(rival.pb) if float(rival.get("pb", 0.0)) > 0.0 else 9999.0


## The entrants fastest seed first (runners without a mark last, in a drawn order).
func _seeded(entrants: Array) -> Array:
	var keyed := []
	for e in entrants:
		keyed.append([float(_seed.get(e.name, 9999.0)), _rng.randf(), e])
	keyed.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	return keyed.map(func(k): return k[2])


func _section_max() -> int:
	return int(_cfg.sections.max.indoor if _indoor else _cfg.sections.max.outdoor)


## Sections: the best seeds together, as many sections as needed (at most `max` runners each) of as even a size as possible,
## the slowest at least `min` runners where that can be; run slowest first.
func _make_sections(entrants: Array) -> void:
	var order := _seeded(entrants)
	var cap := _section_max()
	var low := int(_cfg.sections.min)
	var k := ceili(order.size() / float(cap))
	var sizes := []
	# As even as possible (13 runners, up to 12 a section: 7 + 6, not 9 + 4, user playtest 2026-10-10; real Nuorten SM races
	# had 6–11 runners each); the stronger sections get the extra runner. The weakest keeps at least `min` where it can.
	for s in k:
		sizes.append(order.size() / k + (1 if s < order.size() % k else 0))
	for j in range(k - 2, -1, -1):
		while sizes[k - 1] < low and sizes[j] > low:
			sizes[j] -= 1
			sizes[k - 1] += 1
	var groups := []
	var i := 0
	for s in k:
		groups.append(order.slice(i, i + int(sizes[s])))
		i += int(sizes[s])
	groups.reverse()   # the slowest section runs first, the fastest last
	_set_groups(groups)


## Heats / semis: zigzag seeding into `count` groups (WA TR20.3.3), then the running order drawn by lot (TR20.3.4).
func _make_groups(entrants: Array, count: int) -> void:
	var order := _seeded(entrants)
	var groups := []
	for g in count:
		groups.append([])
	for i in order.size():
		var lap := i / count
		var g := i % count if lap % 2 == 0 else count - 1 - i % count
		groups[g].append(order[i])
	for k in range(groups.size() - 1, 0, -1):
		var j := _rng.randi_range(0, k)
		var tmp = groups[k]
		groups[k] = groups[j]
		groups[j] = tmp
	_set_groups(groups)


func _set_groups(groups: Array) -> void:
	heats = groups
	_group_res = []
	_group_res.resize(groups.size())
	player_heat = 0
	for g in groups.size():
		if groups[g].any(func(e): return e.get("is_player", false)):
			player_heat = g


## The World Athletics table row for n runners: {entries: [from, to], rounds: [[groups, place, time], ...]}; {} when
## the field fits in a final. A bigger field than the table uses its last row.
func _heat_row(n: int) -> Dictionary:
	var rows: Array = _cfg.heats.indoor if _indoor else _cfg.heats.outdoor
	if n < int(rows[0].entries[0]):
		return {}
	for row in rows:
		if n <= int(row.entries[1]):
			return row
	return rows.back()


# --- Times to beat (shown to the player, and the chasing) -------------------------------------------------

## The k-th fastest time among the groups run before group g in this round (0 when fewer finished).
func _kth_time_so_far(g: int, k: int) -> float:
	var times := []
	for j in g:
		if _group_res[j] == null:
			continue
		for row in _group_res[j]:
			if row.get("status", "") == "":
				times.append(float(row.time))
	times.sort()
	return float(times[k - 1]) if times.size() >= k else 0.0


## Heats / semis: the slowest time now inside the time spots among the heats run before group g (0 = no time yet).
func _cutoff_so_far(g: int) -> float:
	var spots := _time_spots()
	if spots <= 0:
		return 0.0
	var auto := _auto_places()
	var rest := []
	for j in g:
		if _group_res[j] == null:
			continue
		var res: Array = _group_res[j]
		for i in res.size():
			if i >= auto and res[i].get("status", "") == "":
				rest.append(float(res[i].time))
	rest.sort()
	return float(rest[spots - 1]) if rest.size() >= spots else 0.0


## What the player needs, for the race screen (decision 34). Runs the groups before the player's first.
##   heats / semis: {kind: "heats", place, time, groups, group, cutoff (0 = no time yet)}
##   sections:      {kind: "sections", sections, section, medal, top8} (estimates: the 3rd / 8th best of the times
##                  already run and the season bests of those still to run, the player left out; 0 = not enough)
##   otherwise {}.
func targets() -> Dictionary:
	if not is_group_round():
		return {}
	_run_groups_until(player_heat)
	if rounds[round_index] == "sections":
		var times := []
		var others := 0
		for g in heats.size():
			if _group_res[g] != null:
				for row in _group_res[g]:
					others += 1
					if row.get("status", "") == "":
						times.append(float(row.time))
			else:
				for e in heats[g]:
					if e.get("is_player", false):
						continue
					others += 1
					if float(_seed.get(e.name, 9999.0)) < 9999.0:
						times.append(float(_seed[e.name]))
		times.sort()
		# Only an estimate when most of the field has a time to go by (early in a season many have none yet).
		var enough := times.size() >= float(_cfg.estimate_share) * others
		return {"kind": "sections", "sections": heats.size(), "section": player_heat + 1,
				"medal": float(times[2]) if enough and times.size() >= 3 else 0.0,
				"top8": float(times[7]) if enough and times.size() >= 8 else 0.0}
	return {"kind": "heats", "place": _auto_places(), "time": _time_spots(), "groups": heats.size(),
			"group": player_heat + 1, "cutoff": _cutoff_so_far(player_heat)}


## A line for the weekly report.
func summary() -> String:
	if player_results.is_empty():
		return ""
	var parts := []
	for r in player_results:
		if r.round.begins_with("Section"):
			parts.append("%s of %d (%s)" % [Race.result_text(r), int(r.field), r.round.to_lower()])
		else:
			var where: String = "" if r.round == "Race" else r.round.to_lower() + " "
			parts.append(where + Race.result_text(r))
	var text := "%s, 800 m: %s." % [meet.name, ", ".join(parts)]
	if rounds.size() > 1 and not qualified:
		text += " Didn't make the final."
	if incidents.any(func(x): return x.kind == "fall"):
		text += " You fell."
	elif incidents.any(func(x): return x.kind == "spiked"):
		text += " You were spiked."
	return text


func _rival_entrant(r: Dictionary) -> Dictionary:
	return {"name": Rivals.full_name(r), "club": Data.get_club(r.club_id).get("name", ""),
			"ability": r.ability, "speed": r.speed, "anaerobic": r.anaerobic, "tactics": r.tactics,
			"consistency": r.consistency, "composure": r.composure,
			"competitiveness": r.get("competitiveness", 10.0), "personality": r.get("personality", ""), "rival": r}


## Racing with a niggle or a cold (GDD 4.6): the athlete runs this share slower (0 when healthy).
## The health system also counts the race as running on the problem (it may get worse).
func _player_entrant() -> Dictionary:
	var e := RacePerformance.player_profile(athlete)
	var health := Game.get_system("health") as HealthSystem
	slowdown = health.race_slowdown() if health else 0.0
	var form_system := Game.get_system("form") as FormSystem
	form = form_system.race_form(athlete.fatigue) if form_system else 0.0
	if slowdown > 0.0 or form != 0.0:
		var time := RacePerformance.time_for(e.ability, athlete.gender) * (1.0 + slowdown - form)
		e.ability = RacePerformance.ability_for_time(time, athlete.gender)
	e.name = athlete.full_name()
	e.club = Data.get_club(athlete.club_id).get("name", "")
	e.is_player = true
	return e
