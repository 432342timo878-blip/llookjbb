extends Node
## The running career: the player's athlete, the current date, the training plan and race entries.

## Career start: the Finnish training year begins in autumn. 2 Nov 2026 is a Monday.
const START_DATE := {"year": 2026, "month": 11, "day": 2}

var athlete: Athlete
var date := START_DATE.duplicate()
var training_plan: Array = []    # Mon..Sun, each an Array of session ids; repeats every week
var entries: Array = []          # meet keys (see Calendar) the athlete has entered
var last_report: Dictionary = {} # result of the most recent week, for the weekly report


func start_career(new_athlete: Athlete) -> void:
	athlete = new_athlete
	date = START_DATE.duplicate()
	training_plan = Training.coach_plan()
	entries = []
	last_report = {}
	SaveGame.save(SaveGame.AUTOSAVE)


func to_dict() -> Dictionary:
	return {"athlete": athlete.to_dict(), "date": date, "training_plan": training_plan, "entries": entries}


func from_dict(d: Dictionary) -> void:
	athlete = Athlete.from_dict(d.athlete)
	date = int_date(d.date)
	training_plan = d.training_plan
	entries = d.entries
	last_report = {}


## JSON turns every number into a float; dates must be ints again.
static func int_date(d: Dictionary) -> Dictionary:
	return {"year": int(d.year), "month": int(d.month), "day": int(d.day)}


func enter(meet_key: String) -> void:
	if not meet_key in entries:
		entries.append(meet_key)


func withdraw(meet_key: String) -> void:
	entries.erase(meet_key)


## The next entered meet from today on, or {}.
func next_race() -> Dictionary:
	for m in Calendar.meets_between(date, add_days(date, 400)):
		if m.key in entries:
			return m
	return {}


## Plays the current week with the training plan and moves the date to next Monday.
func advance_week() -> Dictionary:
	var races := Calendar.races_in_week(entries, date)
	last_report = Training.simulate_week(athlete, training_plan, date, races)
	date = add_days(date, 7)
	SaveGame.save(SaveGame.AUTOSAVE)
	return last_report


static func add_days(d: Dictionary, days: int) -> Dictionary:
	var t := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12})
	var r := Time.get_datetime_dict_from_unix_time(t + days * 86400)
	return {"year": r.year, "month": r.month, "day": r.day}
