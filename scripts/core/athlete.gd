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
var coach_id := ""              # the coach by the track (data/coaches.json); "" = the club coach, one per athlete (Coaches.id_of)

var height_cm := 0.0
var weight_kg := 0.0
var maturation := "average"     # "early" | "average" | "late"
var school_level := "medium"    # "high" | "medium" | "low"
var training_base := "outdoor_track"   # where they train; ids from background_questions.json
var experience := -1            # years of organised training behind the creation answers (AthleteFactory); -1 = not known (older saves)
var weeks_trained := 0          # weeks of progression since the career started (novice gains fade with it, Training.novice_bonus)

var attributes := {}            # attribute id -> float, visible and hidden
var personal_bests := {}        # event id -> mark (seconds or metres)
var results := []               # [{date, meet, meet_key, event, round, place, field, time, pb}]

var fatigue := 0.0              # 0 (fresh) – 100 (exhausted)
var recent_change := {}         # attribute id -> recent trend (decaying sum of weekly changes), for the arrows


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
		"main_event": main_event, "coach_id": coach_id, "height_cm": height_cm, "weight_kg": weight_kg,
		"maturation": maturation, "school_level": school_level, "training_base": training_base,
		"experience": experience, "weeks_trained": weeks_trained, "attributes": attributes, "personal_bests": personal_bests,
		"fatigue": fatigue, "recent_change": recent_change, "results": results,
	}


## -1, 0 or +1: which way the attribute has been moving lately (shown as an arrow).
func trend(id: String) -> int:
	var c: float = recent_change.get(id, 0.0)
	if c >= 0.04:
		return 1
	if c <= -0.04:
		return -1
	return 0


static func from_dict(d: Dictionary) -> Athlete:
	var a := Athlete.new()
	for key in d:
		a.set(key, d[key])
	if not a.birth_date.is_empty():
		a.birth_date = Game.int_date(a.birth_date)
	a.experience = int(a.experience)       # (JSON makes numbers floats)
	a.weeks_trained = int(a.weeks_trained)
	return a
