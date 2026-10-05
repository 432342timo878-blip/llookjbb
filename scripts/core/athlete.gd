class_name Athlete
extends RefCounted
## One athlete: the player's or any other in the simulated world.
## Attribute values are floats on the 1–20 scale; the UI shows them rounded.

const MIN_VALUE := 1.0
const MAX_VALUE := 20.0

var first_name := ""
var last_name := ""
var gender := "male"            # "male" | "female"
var birth_date := {}            # {"year", "month", "day"}
var hometown := ""
var club_id := ""
var main_event := ""            # event id, e.g. "800m"

var height_cm := 0.0
var weight_kg := 0.0
var maturation := "average"     # "early" | "average" | "late"
var school_level := "medium"    # "high" | "medium" | "low"
var training_base := "outdoor_track"   # where they train; ids from background_questions.json

var attributes := {}            # attribute id -> float, visible and hidden
var personal_bests := {}        # event id -> mark (seconds or metres)


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


func get_attr(id: String) -> float:
	return attributes.get(id, MIN_VALUE)


func set_attr(id: String, value: float) -> void:
	attributes[id] = clampf(value, MIN_VALUE, MAX_VALUE)


## Age in whole years on the given date.
func age_on(date: Dictionary) -> int:
	var age: int = date.year - birth_date.year
	if date.month < birth_date.month or (date.month == birth_date.month and date.day < birth_date.day):
		age -= 1
	return age


func to_dict() -> Dictionary:
	return {
		"first_name": first_name, "last_name": last_name, "gender": gender,
		"birth_date": birth_date, "hometown": hometown, "club_id": club_id,
		"main_event": main_event, "height_cm": height_cm, "weight_kg": weight_kg,
		"maturation": maturation, "school_level": school_level, "training_base": training_base,
		"attributes": attributes, "personal_bests": personal_bests,
	}


static func from_dict(d: Dictionary) -> Athlete:
	var a := Athlete.new()
	for key in d:
		a.set(key, d[key])
	return a
