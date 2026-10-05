extends Node
## The running career: the player's athlete, the current date, the training plan, race entries and rivals.
## A week is played with WeekSim; on a race day it stops and the race screen runs `race_day`.

## Career start: the Finnish training year begins in autumn. 2 Nov 2026 is a Monday.
const START_DATE := {"year": 2026, "month": 11, "day": 2}

var athlete: Athlete
var date := START_DATE.duplicate()
var training_plan: Array = []    # Mon..Sun, each an Array of session ids; repeats every week
var entries: Array = []          # meet keys (see Calendar) the athlete has entered
var rivals: Array = []           # fictional runners of the athlete's age and gender (see Rivals)
var last_report: Dictionary = {} # result of the most recent week, for the weekly report
var race_day: RaceDay            # set while a race is waiting to be run
var open_report := false         # career hub opens on the weekly report (after a race day)

var _week: WeekSim


func start_career(new_athlete: Athlete) -> void:
	athlete = new_athlete
	date = START_DATE.duplicate()
	training_plan = Training.coach_plan()
	entries = []
	last_report = {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	rivals = Rivals.generate(athlete, rng)
	SaveGame.save(SaveGame.AUTOSAVE)


func to_dict() -> Dictionary:
	return {"athlete": athlete.to_dict(), "date": date, "training_plan": training_plan, "entries": entries,
			"rivals": rivals}


func from_dict(d: Dictionary) -> void:
	athlete = Athlete.from_dict(d.athlete)
	date = int_date(d.date)
	training_plan = d.training_plan
	entries = d.entries
	rivals = d.get("rivals", [])
	if rivals.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		rivals = Rivals.generate(athlete, rng)
	last_report = {}
	race_day = null
	_week = null


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


## Plays the current week. Returns true when it stopped for a race (then `race_day` is set and the
## race screen should open); false when the week is done (`last_report` is ready).
func advance_week() -> bool:
	_week = WeekSim.new(athlete, training_plan, date, Calendar.races_in_week(entries, date))
	return _continue_week()


## Call after the race screen is done with `race_day`. Same return value as advance_week().
func finish_race() -> bool:
	_record(race_day)
	_week.race_done(race_day.summary())
	race_day = null
	return _continue_week()


func _continue_week() -> bool:
	var meet := _week.run_until_race()
	if not meet.is_empty():
		race_day = RaceDay.new(meet, athlete, rivals)
		return true
	last_report = _week.finish()
	_week = null
	Rivals.train_week(rivals, athlete.gender, date)
	date = add_days(date, 7)
	SaveGame.save(SaveGame.AUTOSAVE)
	return false


## Stores the player's results and PBs, and the rivals' PBs.
func _record(rd: RaceDay) -> void:
	var event := athlete.main_event
	for r in rd.player_results:
		var pb: float = athlete.personal_bests.get(event, 0.0)
		var is_pb: bool = pb == 0.0 or r.time < pb
		if is_pb:
			athlete.personal_bests[event] = r.time
		athlete.results.append({"date": rd.meet.date, "meet": rd.meet.name, "meet_key": rd.meet.key,
				"event": event, "round": r.round, "place": r.place, "field": r.field, "time": r.time, "pb": is_pb})
	for res in rd.all_results:
		for row in res:
			var rival: Dictionary = row.get("rival", {})
			if not rival.is_empty():
				Rivals.record_time(rival, row.time, rd.meet.date)


static func add_days(d: Dictionary, days: int) -> Dictionary:
	var t := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12})
	var r := Time.get_datetime_dict_from_unix_time(t + days * 86400)
	return {"year": r.year, "month": r.month, "day": r.day}
