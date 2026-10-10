class_name AthleteFactory
## Creates the player's 14-year-old athlete from the character creation choices (GDD 4.1.1).
## The points pool (GDD 4.1.1 "Built (points pool)"): every background answer has an `experience` value (years of
## organised training behind it); the pool = pool.base + the experience (6-16), and experience costs trainability
## (a trained body starts stronger but has fewer easy gains left). Rules in data/background_questions.json "pool".

## Typical starting levels for a 14-year-old (1–20 scale): [min, max]. Physical 3.75–6.75 (was 4–7 before the points
## pool) so an average story with the coach's spread starts in the middle of the rival pool (tools/start_spread.gd).
const BASE_RANGES := {
	"physical": [3.75, 6.75],
	"technical": [3.0, 6.0],
	"mental": [5.0, 9.0],
}
const HIDDEN_RANGES := {
	"potential": [13.0, 18.0],
	"trainability": [8.0, 15.0],
	"recovery_rate": [8.0, 15.0],
	"injury_proneness": [5.0, 13.0],
	"maturation_timing": [10.0, 10.0],
	"ambition": [8.0, 15.0],
}
const MATURATION_TIMING := {"early": 5.0, "average": 10.0, "late": 15.0}


## `choices`: first_name, last_name, gender, hometown, club_id, main_event, birth_date,
## and `answers`: question id -> answer index. The athlete before the pool is spent (see spend()).
static func create(choices: Dictionary, rng: RandomNumberGenerator) -> Athlete:
	var a := Athlete.new()
	for key in ["first_name", "last_name", "gender", "hometown", "club_id", "main_event", "birth_date"]:
		a.set(key, choices[key])

	for category in BASE_RANGES:
		var r: Array = BASE_RANGES[category]
		for attr in Data.attributes_in(category):
			a.set_attr(attr.id, rng.randf_range(r[0], r[1]))
	for id in HIDDEN_RANGES:
		var r: Array = HIDDEN_RANGES[id]
		a.set_attr(id, rng.randf_range(r[0], r[1]))

	for answer in _answers(choices.answers):
		_apply_answer(a, answer)
	a.set_attr("maturation_timing", MATURATION_TIMING[a.maturation])
	# Years of training show in the body and cost trainability (no answers at all, e.g. a test athlete: no shift).
	if not choices.answers.is_empty():
		var p: Dictionary = Data.background_pool
		var extra := experience(choices.answers) - float(p.get("neutral_experience", 5))
		var shift := experience_shift(choices.answers)
		for attr in Data.attributes_in("physical"):
			a.set_attr(attr.id, a.get_attr(attr.id) + shift)
		a.set_attr("trainability", a.get_attr("trainability") - extra * float(p.get("trainability_per_experience", 0.0)))

	_roll_body(a, rng)
	return a


## The chosen answers, in question order.
static func _answers(answers: Dictionary) -> Array:
	var out := []
	for question in Data.background_questions:
		var index: int = answers.get(question.id, -1)
		if index >= 0 and index < question.answers.size():
			out.append(question.answers[index])
	return out


static func _apply_answer(a: Athlete, answer: Dictionary) -> void:
	for id in answer.get("effects", {}):
		a.set_attr(id, a.get_attr(id) + float(answer.effects[id]))
	if answer.has("maturation"):
		a.maturation = answer.maturation
	if answer.has("school"):
		a.school_level = answer.school
	if answer.has("training_base"):
		a.training_base = answer.training_base


# --- The points pool ------------------------------------------------------------------------------

## Years of organised training behind the answers (sum of their `experience`).
static func experience(answers: Dictionary) -> int:
	var total := 0
	for answer in _answers(answers):
		total += int(answer.get("experience", 0))
	return total


## Points to spend in the Attributes step.
static func pool_for(answers: Dictionary) -> int:
	return int(Data.background_pool.get("base", 12)) + experience(answers)


## Where the pool comes from, for the UI: [[label, points], ...], the base first, then every answer that adds points.
static func pool_parts(answers: Dictionary) -> Array:
	var parts := [["Everyone", int(Data.background_pool.get("base", 12))]]
	for answer in _answers(answers):
		if int(answer.get("experience", 0)) > 0:
			parts.append([answer.text, int(answer.experience)])
	return parts


## The most points one attribute can take.
static func cap() -> int:
	return int(Data.background_pool.get("max_per_attribute", 3))


## How much the experience behind the answers moved every physical attribute (+ or −).
static func experience_shift(answers: Dictionary) -> float:
	if answers.is_empty():
		return 0.0
	var p: Dictionary = Data.background_pool
	return (experience(answers) - float(p.get("neutral_experience", 5))) * float(p.get("physical_per_experience", 0.0))


## The visible attribute changes the answers' effects made (not the experience shift): attribute id -> total change
## (no zeros).
static func background_effects(answers: Dictionary) -> Dictionary:
	var out := {}
	for answer in _answers(answers):
		for id in answer.get("effects", {}):
			var attr := Data.get_attribute(id)
			if attr.is_empty() or attr.get("hidden", false):
				continue
			out[id] = float(out.get(id, 0.0)) + float(answer.effects[id])
	for id in out.keys():
		if is_zero_approx(out[id]):
			out.erase(id)
	return out


## The coach's spread of `pool` points: the attributes that count most for the 800 m first (races.json
## ability_weights), up to the cap each, never above the top of the scale. Returns attribute id -> points.
static func coach_spread(a: Athlete, pool: int) -> Dictionary:
	var weights: Dictionary = Data.races.ability_weights
	var ids := []
	for id in weights:
		if not str(id).begins_with("_"):
			ids.append(id)
	ids.sort_custom(func(x, y): return float(weights[x]) > float(weights[y]))
	var points := {}
	var left := pool
	for id in ids:
		var add := mini(mini(cap(), left), int(floor(Athlete.MAX_VALUE - a.get_attr(id))))
		if add > 0:
			points[id] = add
			left -= add
	return points


## How much an attribute counts for the 800 m time: [dots 0-3, text] (races.json ability_weights; texts in
## background_questions.json "estimate").
static func weight_tier(id: String) -> Array:
	var texts: Dictionary = Data.background_estimate
	var w := float(Data.races.ability_weights.get(id, 0.0))
	for t in texts.get("weight_tiers", []):
		if w >= float(t[0]):
			return [int(t[1]), str(t[2])]
	return [0, str(texts.get("weight_none", ""))]


## One sentence on what the experience behind the answers means for growth.
static func experience_note(answers: Dictionary) -> String:
	var years := experience(answers)
	for n in Data.background_estimate.get("experience_notes", []):
		if years <= int(n[0]):
			return str(n[1])
	return ""


## Adds the spent points to the athlete.
static func spend(a: Athlete, points: Dictionary) -> void:
	for id in points:
		a.set_attr(id, a.get_attr(id) + points[id])


## The coach's guess for the creation screens: {time (s), line, band, percentile} from the athlete's 800 m
## ability now and the rival pool at the start (Data.races.rivals).
static func estimate(a: Athlete) -> Dictionary:
	var ability := RacePerformance.ability(a)
	var seconds := RacePerformance.time_for(ability, a.gender)
	var cfg: Dictionary = Data.races.rivals
	var z := (ability - float(cfg.ability_mean)) / float(cfg.ability_sd)
	var pct := 100.0 * 0.5 * (1.0 + _erf(z / sqrt(2.0)))
	var texts: Dictionary = Data.background_estimate
	var band := ""
	for b in texts.get("bands", []):
		if pct < float(b[0]):
			band = str(b[1])
			if band.contains("%s"):
				band = band % str(texts.get("group", {}).get(a.gender, "athletes"))
			break
	return {"time": seconds, "percentile": pct,
			"line": str(texts.get("line", "%s")) % _rough_time(seconds), "band": band}


## A guess, so whole seconds: 158.4 -> "2:38".
static func _rough_time(seconds: float) -> String:
	var s := roundi(seconds)
	return "%d:%02d" % [s / 60, s % 60]


static func _erf(x: float) -> float:
	# Abramowitz–Stegun 7.1.26 (error below 1.5e-7)
	var t := 1.0 / (1.0 + 0.3275911 * absf(x))
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
	return y if x >= 0.0 else -y


## Height/weight of a 14-year-old, shifted by how early they matured.
static func _roll_body(a: Athlete, rng: RandomNumberGenerator) -> void:
	var height := 166.0 if a.gender == "male" else 162.0
	height += {"early": 8.0, "average": 0.0, "late": -8.0}[a.maturation]
	a.height_cm = roundf(rng.randfn(height, 4.0))
	# Lean, middle-distance build: BMI around 18.
	a.weight_kg = roundf(18.0 * pow(a.height_cm / 100.0, 2) + rng.randf_range(-2.0, 2.0))
