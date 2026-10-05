class_name AthleteFactory
## Creates the player's 14-year-old athlete from the character creation choices.

## Typical starting levels for a promising 14-year-old (1–20 scale): [min, max].
const BASE_RANGES := {
	"physical": [4.0, 7.0],
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

## Points the player can spend in the last creation step, and the cap per attribute.
const POINT_POOL := 12
const MAX_POINTS_PER_ATTRIBUTE := 3


## `choices`: first_name, last_name, gender, hometown, club_id, main_event, birth_date,
## and `answers`: question id -> answer index.
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

	for question in Data.background_questions:
		var index: int = choices.answers.get(question.id, -1)
		if index >= 0:
			_apply_answer(a, question.answers[index])
	a.set_attr("maturation_timing", MATURATION_TIMING[a.maturation])

	_roll_body(a, rng)
	return a


static func _apply_answer(a: Athlete, answer: Dictionary) -> void:
	for id in answer.get("effects", {}):
		a.set_attr(id, a.get_attr(id) + float(answer.effects[id]))
	if answer.has("maturation"):
		a.maturation = answer.maturation
	if answer.has("school"):
		a.school_level = answer.school
	if answer.has("training_base"):
		a.training_base = answer.training_base


## Height/weight of a 14-year-old, shifted by how early they matured.
static func _roll_body(a: Athlete, rng: RandomNumberGenerator) -> void:
	var height := 166.0 if a.gender == "male" else 162.0
	height += {"early": 8.0, "average": 0.0, "late": -8.0}[a.maturation]
	a.height_cm = roundf(rng.randfn(height, 4.0))
	# Lean, middle-distance build: BMI around 18.
	a.weight_kg = roundf(18.0 * pow(a.height_cm / 100.0, 2) + rng.randf_range(-2.0, 2.0))
