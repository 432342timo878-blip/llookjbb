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
var training_town := ""         # where they live and train after moving to a school (S3a); "" = the club's town / hometown, as before
var main_event := ""            # event id, e.g. "800m"
var coach_id := ""              # the head coach: a coach record of CoachSystem (GDD 4.9.1); "" = not made yet (older saves)
var temperament := ""           # from the creation answer "Before an important race..." (data/coaching.json temperaments); "" = not known
var family := ""                # the creation answer about the family (background_questions.json `family`: the budget, a parent coach; C6); "" = not known
## Two creation answers the people around the athlete are made from (session P1, Cast): who got them into athletics (`origin`:
## pe_teacher, friends, ...) and the sport before (`old_sport`). NOT saved: StoryletSystem.ensure_cast copies them into the
## cast when the career starts (so an athlete's save data stays as it was).
var origin := ""
var old_sport := ""

var height_cm := 0.0
var weight_kg := 0.0
var maturation := "average"     # "early" | "average" | "late"
var school_level := "medium"    # "high" | "medium" | "low"
var school_answer := ""         # the creation answer about school (background_questions.json `school_answer`: the starting grades, S1); "" = not known (older saves: from school_level)
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
	var out := {
		"first_name": first_name, "last_name": last_name, "gender": gender,
		"birth_date": birth_date, "hometown": hometown, "club_id": club_id,
		"main_event": main_event, "coach_id": coach_id, "temperament": temperament, "family": family, "height_cm": height_cm, "weight_kg": weight_kg,
		"maturation": maturation, "school_level": school_level, "school_answer": school_answer, "training_base": training_base,
		"experience": experience, "weeks_trained": weeks_trained, "attributes": attributes, "personal_bests": personal_bests,
		"fatigue": fatigue, "recent_change": recent_change, "results": results,
	}
	if training_town != "":   # (S3a: only a career that has moved has the key)
		out["training_town"] = training_town
	return out


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
