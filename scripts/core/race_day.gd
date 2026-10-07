class_name RaceDay
extends RefCounted
## The player's 800 m at one meet: picks the field from the rival pool, runs heats + final when the
## field is big (championships), and collects the results.

var meet: Dictionary
var athlete: Athlete
var rounds: Array[String] = []    # "heat" and/or "final"
var round_index := 0
var qualified := true
var fatigue := 0.0                # the player's fatigue going into the current round
var heats: Array = []             # Array of entrant arrays
var player_heat := 0
var final_entrants: Array = []
var player_results: Array = []    # [{round, place, field, time}]
var all_results: Array = []       # every race run here (for rival PBs)
var current: Race
var slowdown := 0.0               # share slower because of a niggle or illness (HealthSystem.race_slowdown)
var form := 0.0                   # share faster (+) or slower (-) from race-day form (FormSystem.race_form)

var _rng := RandomNumberGenerator.new()
var _gender := "male"
var _max_final := 8          # outdoor: 8 lanes; indoor: 6
var _heat_size := 8


func _init(m: Dictionary, a: Athlete, pool: Array) -> void:
	meet = m
	athlete = a
	_gender = a.gender
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

	var cfg: Dictionary = Data.races.heats
	_max_final = 6 if meet.get("indoor", false) else int(cfg.max_final)
	_heat_size = 6 if meet.get("indoor", false) else int(cfg.heat_size)
	if entrants.size() > _max_final + 4:
		rounds = ["heat", "final"]
		var n_heats := ceili(entrants.size() / float(_heat_size))
		entrants.sort_custom(func(x, y): return x.ability > y.ability)
		for h in n_heats:
			heats.append([])
		for i in entrants.size():
			# Snake seeding so every heat gets a fair mix.
			var lap := i / n_heats
			var h := i % n_heats if lap % 2 == 0 else n_heats - 1 - i % n_heats
			heats[h].append(entrants[i])
			if entrants[i].get("is_player", false):
				player_heat = h
	else:
		rounds = ["final"]
		final_entrants = entrants


func round_name() -> String:
	if rounds[round_index] == "heat":
		return "Heat %d of %d" % [player_heat + 1, heats.size()]
	return "Final" if rounds.size() > 1 else "Race"


func is_done() -> bool:
	return round_index >= rounds.size() or not qualified


func is_big_meet() -> bool:
	return meet.level in ["national", "international"]


## Who runs in the player's next race.
func current_entrants() -> Array:
	return heats[player_heat] if rounds[round_index] == "heat" else final_entrants


## The player's next race. `interactive` = detailed mode with decision pauses.
func start_round(interactive: bool, plan: String) -> Race:
	var entrants := current_entrants()
	current = Race.new()
	current.interactive = interactive
	current.setup(entrants, _gender, is_big_meet(), fatigue, _rng, meet.get("indoor", false), shape_mix())
	current.set_player_plan(plan)
	return current


## Which race-shape mix (data/races.json shapes.mix) fits this meet and round: local and district meets by
## level, championships by round (heats are run more honestly, finals more tactically).
func shape_mix() -> String:
	var level: String = meet.get("level", "")
	if level in ["local", "district"]:
		return level
	return "heat" if rounds[round_index] == "heat" else "final"


## Call when the player's current race is over.
func finish_round() -> void:
	var res := current.results()
	all_results.append(res)
	var place := 0
	for i in res.size():
		if res[i].is_player:
			place = i + 1
			player_results.append({"round": round_name(), "place": place, "field": res.size(), "time": res[i].time})
	if rounds[round_index] == "heat":
		var heat_results := []
		for h in heats.size():
			if h == player_heat:
				heat_results.append(res)
			else:
				var other := Race.new()
				other.setup(heats[h], _gender, is_big_meet(), 0.0, _rng, meet.get("indoor", false), shape_mix())
				other.run()
				heat_results.append(other.results())
				all_results.append(heat_results[h])
		final_entrants = _qualifiers(heat_results)
		qualified = final_entrants.any(func(e): return e.get("is_player", false))
		fatigue = minf(fatigue + 8.0, 100.0)   # the heat took something out of you
	round_index += 1


## Top N of each heat plus the fastest of the rest, up to the final size.
func _qualifiers(heat_results: Array) -> Array:
	var cfg: Dictionary = Data.races.heats
	var by_name := {}
	for h in heats:
		for e in h:
			by_name[e.name] = e
	var q := []
	var rest := []
	for res in heat_results:
		for i in res.size():
			if i < int(cfg.auto_per_heat):
				q.append(by_name[res[i].name])
			else:
				rest.append(res[i])
	rest.sort_custom(func(x, y): return x.time < y.time)
	for r in rest:
		if q.size() >= _max_final:
			break
		q.append(by_name[r.name])
	return q


## A line for the weekly report.
func summary() -> String:
	if player_results.is_empty():
		return ""
	var parts := []
	for r in player_results:
		var where: String = "" if r.round == "Race" else r.round.to_lower() + " "
		parts.append("%s%s in %s" % [where, Race._ordinal(r.place), Calendar.format_time(r.time)])
	var text := "%s, 800 m: %s." % [meet.name, ", ".join(parts)]
	if rounds.size() > 1 and not qualified:
		text += " Didn't make the final."
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
