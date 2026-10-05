class_name WeekSim
extends RefCounted
## One week, played day by day so it can stop on race day: run_until_race() → (race happens) →
## race_done() → run_until_race() ... → finish() returns the weekly report.

var a: Athlete
var plan: Array
var monday: Dictionary
var races: Dictionary           # day index -> meet
var day := 0

var _month := 1
var _stimulus := {}
var _notes := []
var _raced := []
var _fatigue_start := 0.0
var _fatigue_peak := 0.0
var _fatigue_sum := 0.0
var _sessions := 0
var _load := 0.0
var _off_track := []


func _init(athlete: Athlete, week_plan: Array, week_monday: Dictionary, week_races := {}) -> void:
	a = athlete
	plan = week_plan
	monday = week_monday
	races = week_races
	_month = Game.add_days(monday, 3).month   # the month most of the week is in
	_fatigue_start = a.fatigue
	_fatigue_peak = a.fatigue


## Plays training days until a race day (returns its meet; the day is not played yet) or the end ({}).
func run_until_race() -> Dictionary:
	while day < 7:
		if races.has(day):
			return races[day]
		_play_day(_planned_sessions(day), false)
		day += 1
	return {}


## The race day is done: apply its load and training effect. `summary` is a line for the report.
func race_done(summary: String) -> void:
	var race: Dictionary = Data.competitions.race_session.duplicate()
	race.name = races[day].name
	_raced.append({"meet": races[day], "day": day})
	_play_day([race], true)
	if summary != "":
		_notes.append("%s: %s" % [Training.DAY_NAMES[day], summary])
	day += 1


## Plays the rest of the week (race days without a result, e.g. for previews) and returns the report.
func finish() -> Dictionary:
	while day < 7:
		if races.has(day):
			race_done("")
		else:
			_play_day(_planned_sessions(day), false)
			day += 1

	var fatigue_avg := _fatigue_sum / 7.0
	var season: Dictionary = Data.training.season
	if not _off_track.is_empty():
		_notes.append("No indoor track in winter: %s done on roads and snow instead (%d%% effect)." % [
				", ".join(_off_track), roundi(float(season.off_track_effect) * 100)])
	if fatigue_avg >= 65.0:
		_notes.append("You were exhausted this week. Training that tired does little good and risks injury.")
	elif fatigue_avg >= 45.0:
		_notes.append("Your legs felt heavy this week. A lighter week would help you absorb the training.")
	if _sessions == 0:
		_notes.append("A full week off. Good for recovery, but fitness slowly fades.")

	var changes := Training._apply_progression(a, _stimulus)
	return {
		"monday": monday, "sessions": _sessions, "load": _load,
		"fatigue_start": _fatigue_start, "fatigue_end": a.fatigue, "fatigue_peak": _fatigue_peak,
		"fatigue_avg": fatigue_avg, "changes": changes, "notes": _notes, "races": _raced,
	}


func _planned_sessions(d: int) -> Array:
	var sessions := []
	for id in plan[d]:
		var s := Data.get_session(id)
		if not s.is_empty():
			sessions.append(s)
	return sessions


func _play_day(sessions: Array, is_race: bool) -> void:
	var day_load := 0.0
	var keep := Training.daily_keep(a)
	var extra_recovery := 0.0
	var trained := false
	for s in sessions:
		var eff := 1.0 if is_race else Training.effectiveness(a, s, _month)
		if eff == 0.0:
			_notes.append("%s: %s isn't possible this time of year, so it was skipped." % [Training.DAY_NAMES[day], s.name])
			continue
		if eff < 1.0 and not s.name in _off_track:
			_off_track.append(s.name)
		# Training while very tired does less good.
		var fresh := 1.0
		if a.fatigue > Training.FATIGUE_LIMIT:
			fresh = lerpf(1.0, Training.FATIGUED_MIN_EFFECT,
					(a.fatigue - Training.FATIGUE_LIMIT) / (100.0 - Training.FATIGUE_LIMIT))
		for attr in s.effects:
			_stimulus[attr] = _stimulus.get(attr, 0.0) + float(s.effects[attr]) * eff * fresh
		day_load += Training.session_load(a, s)
		extra_recovery += float(s.get("recovery", 0))
		_sessions += 1
		trained = true
	if not trained:
		keep -= Training.REST_DAY_EXTRA
	_load += day_load
	a.fatigue = clampf(a.fatigue * keep + day_load - extra_recovery, 0.0, 100.0)
	_fatigue_peak = maxf(_fatigue_peak, a.fatigue)
	_fatigue_sum += a.fatigue
