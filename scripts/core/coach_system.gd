class_name CoachSystem
extends GameSystem
## The coaches (GDD 4.9.1-4.9.2; session C1, headless). Keeps the career's coach records (the format is in the note at
## the top of data/coaching.json), the athlete's relation with each (weeks together, trust) and the coach's effects on
## the game. Athlete.coach_id names the head coach's record; his `voice` is the personality of data/coaches.json whose
## words he uses at races (Coaches.id_of).
## Every effect is measured against 10 ((attribute - 10) x per_point, numbers in data/coaching.json `effects`), so a
## coach of 10s changes nothing. Built: the training effect by attribute group (WeekSim.coach_effect ->
## Training._apply_progression) and the race-advice accuracy (Race.coach_accuracy, replacing races.json
## controls.coach.accuracy). Prepared for later sessions: youth_factor, factor() for load management, periodization,
## mental coaching and motivating; trust and fit (nothing reads them yet).
## Each career starts with a club coach (make_club_coach): one of the four people of coaches.json (the one the
## athlete's name picks, as before C1) with his own overall level (user 2026-10-11: club coaches really differ,
## averages about 7-13) and strong and weak spots, from his own dice (same career = same coach).

## Off switch for the tools (like HealthSystem.model_enabled): every effect neutral, trust stands still.
static var model_enabled := true
## Tools that measure the balance: new club coaches get 10 in every attribute (everything else about them unchanged).
static var neutral_club := false

var coaches := {}      # id -> coach record
var relations := {}    # coach id -> {weeks (together), trust (0-100), since (date), causes: [{date, delta, cause}]}
var _next_id := 1


func _init() -> void:
	id = "coach"


# --- The head coach ------------------------------------------------------------------------------

## Makes the athlete's club coach when their coach_id names no record (a new career, or a save from before C1).
func ensure_head(a: Athlete, date: Dictionary) -> void:
	if coaches.has(a.coach_id):
		return
	var c := make_club_coach(a, date)
	c.id = "coach_%d" % _next_id
	_next_id += 1
	coaches[c.id] = c
	set_head(a, c.id, date)
	# A save from before C1: he has coached the athlete since the career began; trust as if it had drifted all along.
	var weeks := floori(Calendar.days_between(Game.START_DATE, date) / 7.0)
	if weeks > 0:
		var t: Dictionary = Data.coaching.trust
		var rel: Dictionary = relations[c.id]
		var target := float(t.target[fit_of(a.temperament, c)])
		rel.weeks = weeks
		rel.since = Game.START_DATE.duplicate()
		rel.trust = target + (float(rel.trust) - target) * pow(1.0 - float(t.rate), weeks)


## The athlete works with coach `coach_id` from `date` on (a relation starts New).
func set_head(a: Athlete, coach_id: String, date: Dictionary) -> void:
	a.coach_id = coach_id
	if not relations.has(coach_id):
		relations[coach_id] = {"weeks": 0, "trust": float(Data.coaching.trust.start), "since": date.duplicate(), "causes": []}


## The head coach's record, or {}.
func head() -> Dictionary:
	if Game.athlete == null:
		return {}
	return coaches.get(Game.athlete.coach_id, {})


func relation() -> Dictionary:
	if Game.athlete == null:
		return {}
	return relations.get(Game.athlete.coach_id, {})


## The head coach's attribute (1-20); 10 when the model is off or there is no coach. A coach in another town loses some of
## what he must see (session C6: data/market.json distance; a club coach in the club's own town loses nothing).
func attr(attr_id: String) -> float:
	var neutral := float(Data.coaching.neutral)
	if not model_enabled:
		return neutral
	var c := head()
	if c.is_empty():
		return neutral
	var v := float(c.attributes.get(attr_id, neutral))
	var pen := float(Data.market.distance[distance_of(c, Game.athlete)].penalty.get(attr_id, 0.0))
	return maxf(1.0, v - pen) if pen != 0.0 else v


## How far coach `c` is from athlete `a` (session C6): "same" (the club's town, or a parent), "region" (the same maakunta)
## or "far" (anywhere else, an unknown town, or a remote coach).
static func distance_of(c: Dictionary, a: Athlete) -> String:
	if c.is_empty() or a == null:
		return "same"
	var kind := str(c.get("kind", ""))
	if kind == "parent":
		return "same"
	if kind == "remote":
		return "far"
	var town := str(c.get("facts", {}).get("town", ""))
	var home := home_town(a)
	if town == home:
		return "same"
	var t1 := Data.get_town(town)
	var t2 := Data.get_town(home)
	if not t1.is_empty() and not t2.is_empty() and str(t1.maakunta) == str(t2.maakunta):
		return "region"
	return "far"


## The town the athlete trains in: the town they moved to for school (S3a), else their club's home town (else their hometown).
static func home_town(a: Athlete) -> String:
	if a == null:
		return ""
	if a.training_town != "":
		return a.training_town
	var club := Data.get_club(a.club_id)
	return str(club.get("city", a.hometown))


## He / him / his for a coach record (data/coaching.json pronouns; "unknown" = they / them / their, never a guess from a name).
static func pronoun(c: Dictionary, key: String) -> String:
	var p: Dictionary = Data.coaching.pronouns
	return str(p.get(str(c.get("gender", "unknown")), p.unknown).get(key, key))


# --- Effects (all exactly neutral at 10) ------------------------------------------------------

## The week's training effect: attribute id -> multiplier of its trained gain, for the attributes whose group
## knowledge is not 10 (empty = no change). Game.current_week() hands it to the WeekSim.
func training_effect() -> Dictionary:
	var out := {}
	if not model_enabled:
		return out
	var t: Dictionary = Data.coaching.effects.training
	for group in t.groups:
		var f := factor(group, float(t.per_point))
		if f != 1.0:
			for attr_id in t.groups[group]:
				out[attr_id] = f
	return out


## How often his shout on a race card is the sensible answer; -1 = the default (races.json controls.coach.accuracy,
## which is also exactly what a race reading of 10 gives). `meet` = the race's meet: a coach from another town who does not
## come to it follows it from afar (session C6: data/market.json distance.<d>.race_reading off his race reading).
func race_accuracy(meet := {}) -> float:
	if not model_enabled or head().is_empty():
		return -1.0
	var r: Dictionary = Data.coaching.effects.race_advice
	var base := float(Data.races.controls.coach.accuracy)
	var rr := attr(str(r.attribute))
	if not meet.is_empty() and not attends(meet):
		rr = maxf(1.0, rr - float(Data.market.distance[distance_of(head(), Game.athlete)].race_reading))
	# The race-reading tactician is the most accurate (data/advice.json race.shouts.accuracy_bonus, session C5).
	var bonus := float(Data.advice.race.shouts.accuracy_bonus.get(str(head().get("voice", "")), 0.0))
	if rr == float(Data.coaching.neutral) and bonus == 0.0:
		return base
	return clampf(base + (rr - float(Data.coaching.neutral)) * float(r.per_point) + bonus, float(r.min), float(r.max))


## Does the head coach come to this meet? Always when he trains in the athlete's town; from another town only to the levels
## of data/market.json distance.attends and to the season's targets.
func attends(meet: Dictionary) -> bool:
	if distance_of(head(), Game.athlete) == "same":
		return true
	if str(meet.get("level", "")) in Data.market.distance.attends:
		return true
	if Game.season != null and Game.season.mode == SeasonPlan.PHASES:
		return str(meet.get("key", "")) in Game.season.targets(Game.season.plan_year(meet.date))
	return false


## The race-advice accuracy for a race of athlete `a` (RaceDay): the career's coach for the career's athlete, else -1.
static func race_accuracy_for(a: Athlete, meet := {}) -> float:
	if a == null or a != Game.athlete:
		return -1.0
	var cs := Game.get_system("coach") as CoachSystem
	return cs.race_accuracy(meet) if cs else -1.0


## 1 + (attribute - 10) x per_point: the general form of every coach effect.
func factor(attr_id: String, per_point: float) -> float:
	return 1.0 + (attr(attr_id) - float(Data.coaching.neutral)) * per_point


## Prepared (C4 / balance): an effect named in data/coaching.json effects.<attribute>.<key>, e.g.
## effect("load_management", "spot_per_point"). 1.0 at 10.
func effect(attr_id: String, key: String) -> float:
	return factor(attr_id, float(Data.coaching.effects[attr_id][key]))


## Prepared (balance session): youth development only matters below effects.youth_development.below_age.
func youth_factor(key: String, age: float) -> float:
	if age >= float(Data.coaching.effects.youth_development.below_age):
		return 1.0
	return effect("youth_development", key)


# --- Fit and trust ------------------------------------------------------------------------------

## How the athlete's temperament and the coach go together: a score (data/coaching.json fit). 0 for an unknown
## temperament (older saves).
static func fit_score(temperament: String, c: Dictionary) -> float:
	if temperament == "" or c.is_empty():
		return 0.0
	var f: Dictionary = Data.coaching.fit
	var score := float(f.matrix.get(temperament, {}).get(str(c.personality), 0))
	var style := int(c.style)
	if style > 0 or not temperament in f.no_controlling_penalty:
		score += style * float(f.style_weight)
	score += float(f.get("kind_bonus", {}).get(str(c.get("kind", "")), 0.0))   # a parent as the coach (C6)
	return score


## "click" / "fine" / "friction".
static func fit_of(temperament: String, c: Dictionary) -> String:
	var f: Dictionary = Data.coaching.fit
	var s := fit_score(temperament, c)
	if s >= float(f.click):
		return "click"
	if s <= float(f.friction):
		return "friction"
	return "fine"


## The head coach's fit with the athlete.
func fit() -> String:
	return fit_of(Game.athlete.temperament if Game.athlete else "", head())


## The word shown (after data fit.reveal_weeks together).
func fit_word() -> String:
	var f: Dictionary = Data.coaching.fit
	if int(relation().get("weeks", 0)) < int(f.reveal_weeks):
		return str(f.words.unknown)
	return str(f.words[fit()])


func trust() -> float:
	return float(relation().get("trust", Data.coaching.trust.start))


## "new" / "good" / "strong" / "strained".
func trust_level() -> String:
	var t: Dictionary = Data.coaching.trust
	var rel := relation()
	if int(rel.get("weeks", 0)) < int(t.new_weeks):
		return "new"
	var v := trust()
	if v >= float(t.strong):
		return "strong"
	if v < float(t.strained):
		return "strained"
	return "good"


func trust_word() -> String:
	return str(Data.coaching.trust.words[trust_level()])


## Later sessions move trust with this (results vs his goals, moments, vetoes): `cause` is kept for the UI.
func add_trust(delta: float, cause: String) -> void:
	var rel := relation()
	if rel.is_empty() or not model_enabled:
		return
	rel.trust = clampf(float(rel.trust) + delta, 0.0, 100.0)
	rel.causes.append({"date": Game.date.duplicate(), "delta": delta, "cause": cause})
	while rel.causes.size() > int(Data.coaching.trust.keep_causes):
		rel.causes.pop_front()


## Sunday night: one more week together; trust drifts towards where the fit puts it.
func on_week_end(_ctx: Dictionary) -> void:
	if not model_enabled:
		return
	var rel := relation()
	if rel.is_empty():
		return
	var t: Dictionary = Data.coaching.trust
	rel.weeks = int(rel.weeks) + 1
	rel.trust = float(rel.trust) + (float(t.target[fit()]) - float(rel.trust)) * float(t.rate)


# --- The club coach -----------------------------------------------------------------------------

## A career's club coach (data/coaching.json club), without an id. His dice come from the athlete's name and birth
## date only, so the same career always gets the same coach; the global dice are never touched (rivals use them).
static func make_club_coach(a: Athlete, date: Dictionary) -> Dictionary:
	var cfg: Dictionary = Data.coaching.club
	var voice := Coaches.club_voice(a)
	var person: Dictionary = Data.coaches.coaches[voice]
	var p: Dictionary = Data.coaching.personalities.get(voice, {})
	var rng := RandomNumberGenerator.new()
	var b := a.birth_date
	rng.seed = ("club coach|%s|%d-%d-%d" % [a.full_name(), int(b.get("year", 0)), int(b.get("month", 0)), int(b.get("day", 0))]).hash()
	var average := clampf(rng.randfn(float(cfg.average_mean) + town_shift(home_town(a)), float(cfg.average_sd)), float(cfg.average_min), float(cfg.average_max))
	var focus := _weighted(rng, _weights(cfg.event_focus))
	var lean_f: Dictionary = cfg.event_focus[focus].lean
	var lean_p: Dictionary = p.get("lean", {})
	var raw := {}
	var sum := 0.0
	for at in Data.coaching.attributes:
		var v := float(lean_p.get(at.id, 0)) + float(lean_f.get(at.id, 0)) + rng.randfn(0.0, float(cfg.spread_sd))
		raw[at.id] = v
		sum += v
	var mean_raw := sum / raw.size()
	var attrs := {}
	for at_id in raw:
		attrs[at_id] = 10 if neutral_club else clampi(roundi(average + raw[at_id] - mean_raw), int(cfg.min), int(cfg.max))
	var style := int(_weighted(rng, p.get("style", {"0": 1})))
	var demands := _weighted(rng, p.get("demands", {"balanced": 1}))
	var age := rng.randi_range(int(cfg.age[0]), int(cfg.age[1]))
	var qual_level := average + rng.randfn(0.0, float(cfg.qualification_noise))
	var qualification := ""
	for q in cfg.qualifications:
		if qual_level >= float(q.from_average):
			qualification = str(q.id)
	var cost := rng.randi_range(roundi(float(cfg.cost_month[0]) / 5.0), roundi(float(cfg.cost_month[1]) / 5.0)) * 5
	var club := Data.get_club(a.club_id)
	return {
		"id": "", "name": str(person.name), "gender": str(person.get("gender", "male")), "voice": voice,
		"kind": str(cfg.kind), "real": false, "source": "", "attributes": attrs, "personality": voice,
		"style": style, "demands": demands,
		"facts": {"birth_year": int(date.year) - age, "club_id": a.club_id, "town": str(club.get("city", a.hometown)),
				"qualification": qualification, "reputation": str(cfg.reputation), "event_focus": focus,
				"cost_month": cost, "open": bool(cfg.open), "spots": 0, "min_level": 0},
		"group": _make_group(a, rng),
	}


## How a town moves its club coaches' average level (session C6, user: a moderate shift): data/coaching.json club.town_shift
## by the size class of the town (data/towns.json), plus `centre` in one of SUL's athletics-centre towns.
static func town_shift(town: String) -> float:
	var shift: Dictionary = Data.coaching.club.get("town_shift", {})
	var out := float(shift.get(Data.town_size(town), 0.0))
	if Data.get_town(town).get("centre") != null:
		out += float(shift.get("centre", 0.0))
	return out


## The athlete's level on the training group's scale: the mean of their physical and technical attributes.
static func athlete_level(a: Athlete) -> float:
	var level := 0.0
	var n := 0
	for category in ["physical", "technical"]:
		for at in Data.attributes_in(category):
			level += a.get_attr(at.id)
			n += 1
	return level / maxi(n, 1)


## The training group that comes with the coach: fictional teammates of about the athlete's age. `size` [min, max] and
## `level` (the group's centre on the attribute scale) default to the club group around the athlete's own level.
static func _make_group(a: Athlete, rng: RandomNumberGenerator, size := [], level := -1.0) -> Array:
	var g: Dictionary = Data.coaching.club.group
	if level < 0.0:
		level = athlete_level(a)
	if size.is_empty():
		size = g.size
	var role_weights := {}
	for r in g.roles:
		role_weights[r] = float(g.roles[r].weight)
	var used := {a.full_name(): true}
	var out := []
	for i in rng.randi_range(int(size[0]), int(size[1])):
		var role := _weighted(rng, role_weights)
		if float(g.roles[role].weight) <= 1.0:
			role_weights.erase(role)   # (the veteran, the newcomer and the leader: one each)
		var r: Dictionary = g.roles[role]
		var gender := "male" if rng.randf() < 0.5 else "female"
		var first := ""
		var last := ""
		for _try in 20:
			first = str(Data.names[gender][rng.randi_range(0, Data.names[gender].size() - 1)])
			last = str(Data.names.surnames[rng.randi_range(0, Data.names.surnames.size() - 1)])
			if not used.has(first + " " + last):
				break
		used[first + " " + last] = true
		out.append({"id": "t%d" % (i + 1), "first_name": first, "last_name": last, "gender": gender,
				"birth_year": int(a.birth_date.year) + rng.randi_range(int(g.birth_year_offset[0]), int(g.birth_year_offset[1])) + int(r.age),
				"event": _weighted(rng, _weights(g.events)),
				"level": snappedf(clampf(level + float(r.level) + rng.randfn(0.0, float(g.level_sd)), 1.0, 20.0), 0.1),
				"role": role})
	return out


## {key: weight} from a dict of numbers or of {weight: ...}.
static func _weights(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = float(d[k].weight) if d[k] is Dictionary else float(d[k])
	return out


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var x := rng.randf() * total
	for k in weights:
		x -= float(weights[k])
		if x < 0.0:
			return str(k)
	return str(weights.keys().back())


## The average of a coach's 11 attributes (his overall level).
static func average(c: Dictionary) -> float:
	var s := 0.0
	for k in c.attributes:
		s += float(c.attributes[k])
	return s / maxi(c.attributes.size(), 1)


# --- Save ------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"coaches": coaches, "relations": relations, "next_id": _next_id}


## JSON makes every number a float: whole numbers back to ints.
func from_dict(d: Dictionary) -> void:
	coaches = d.get("coaches", {})
	relations = d.get("relations", {})
	_next_id = int(d.get("next_id", 1))
	for c in coaches.values():
		for k in c.attributes:
			c.attributes[k] = int(c.attributes[k])
		c.style = int(c.style)
		for k in ["birth_year", "cost_month", "spots", "min_level"]:
			if c.facts.has(k):
				c.facts[k] = int(c.facts[k])
		for t in c.get("group", []):
			t.birth_year = int(t.birth_year)
	for rel in relations.values():
		rel.weeks = int(rel.weeks)
		rel.since = Game.int_date(rel.since)
		for cause in rel.get("causes", []):
			cause.date = Game.int_date(cause.date)
