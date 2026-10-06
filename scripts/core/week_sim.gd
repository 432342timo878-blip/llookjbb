class_name WeekSim
extends RefCounted
## One Mon–Sun week, played a day at a time (GDD 4.5). Each day is either play_day() (training) or
## race_done() (after the race screen); after Sunday, end_week() applies the week's attribute progression
## and returns the weekly report. Fatigue changes every day, attributes only on Sunday night.
## Day changes override the weekly plan for one day of this week only: its sessions and/or its intensity,
## each remembering who made it (player / coach / injury). Played days and race days can't be changed.
## to_dict/from_dict save a week in progress; the plan and the race days come from the game, not the save.

const CHANGED_BY := ["player", "coach", "injury"]
const NORMAL := "normal"

var a: Athlete
var plan: Array                 # the weekly template's days: Mon..Sun, each an Array of session ids
var plan_intensity: Array       # the weekly template's intensity per day: 7 × "easy" / "normal" / "hard"
var monday: Dictionary
var races: Dictionary           # day index -> meet
var day := 0                    # the next day to play (0 = Monday; 7 = the whole week is played)
var day_started := false        # the game has run its day-start step for `day` (it may stop there)
## day index -> {"sessions": {"value": [ids], "by": who}, "intensity": {"value": id, "by": who}}
var changes := {}
## What was actually done, one record per played day: {day, sessions, intensity, race, load, fatigue}
var played := []

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


## `week_plan` is a week plan (see WeekPlan); the old plain Array of days works too (every day Normal).
func _init(athlete: Athlete, week_plan: Variant, week_monday: Dictionary, week_races := {}) -> void:
	a = athlete
	var p := WeekPlan.of(week_plan)
	plan = p.days
	plan_intensity = p.intensity
	monday = week_monday
	races = week_races
	_month = Game.add_days(monday, 3).month   # the month most of the week is in
	_fatigue_start = a.fatigue
	_fatigue_peak = a.fatigue


# --- Playing ---------------------------------------------------------------------------------

func is_over() -> bool:
	return day >= 7


func is_race_day(d: int) -> bool:
	return races.has(d)


## Plays training days until a race day (returns its meet; the day is not played yet) or the end ({}).
func run_until_race() -> Dictionary:
	while day < 7:
		if races.has(day):
			return races[day]
		play_day()
	return {}


## Follows a (changed) weekly plan: the game calls this every time it hands out the week. A day change that has
## become the same as the plan is dropped, like a change made equal to it.
func set_plan(week_plan: Variant) -> void:
	var p := WeekPlan.of(week_plan)
	plan = p.days
	plan_intensity = p.intensity
	for d in range(day, 7):
		var c: Dictionary = changes.get(d, {})
		if c.has("sessions") and c.sessions.value == plan[d]:
			c.erase("sessions")
		if c.has("intensity") and c.intensity.value == plan_intensity[d]:
			c.erase("intensity")
		if c.is_empty():
			changes.erase(d)


## Plays today (`day`) as a training day: its sessions and intensity, with any day changes.
## Returns the day's record (see `played`).
func play_day() -> Dictionary:
	return _play_day(_sessions_of(session_ids(day)), {}, intensity(day))


## The race day is done: apply its load and training effect. `summary` is a line for the report.
## Returns the day's record.
func race_done(summary: String) -> Dictionary:
	var meet: Dictionary = races[day]
	var race: Dictionary = Data.competitions.race_session.duplicate()
	race.name = meet.name
	var d := day
	_raced.append({"day": d, "meet_key": meet.get("key", ""), "name": meet.name})
	var record := _play_day([race], meet, NORMAL)
	if summary != "":
		_notes.append("%s: %s" % [Training.DAY_NAMES[d], summary])
	return record


## Plays the rest of the week (race days without a result, e.g. for previews) and returns the report.
func finish() -> Dictionary:
	while day < 7:
		if races.has(day):
			race_done("")
		else:
			play_day()
	return end_week()


## Sunday night: applies the week's attribute progression and returns the weekly report.
func end_week() -> Dictionary:
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

	var changes_done := Training._apply_progression(a, _stimulus)
	return {
		"monday": monday, "sessions": _sessions, "load": _load,
		"fatigue_start": _fatigue_start, "fatigue_end": a.fatigue, "fatigue_peak": _fatigue_peak,
		"fatigue_avg": fatigue_avg, "changes": changes_done, "notes": _notes, "races": _raced,
	}


## The training stimulus collected so far this week (attribute id -> amount). Read-only.
func stimulus_so_far() -> Dictionary:
	return _stimulus


# --- Day changes (this week only) --------------------------------------------------------------

## The session ids planned for day `d`: the day change if there is one, otherwise the weekly plan.
func session_ids(d: int) -> Array:
	var c: Dictionary = changes.get(d, {})
	if c.has("sessions"):
		return c.sessions.value
	return plan[d]


## The intensity id for day `d` ("easy" / "normal" / "hard"): the day change, otherwise the weekly plan's.
func intensity(d: int) -> String:
	var c: Dictionary = changes.get(d, {})
	return c.intensity.value if c.has("intensity") else plan_intensity[d]


## Who changed what on day `d`: {"sessions": who, "intensity": who}, only for the parts that were changed.
func changed_by(d: int) -> Dictionary:
	var who := {}
	for part in changes.get(d, {}):
		who[part] = changes[d][part].by
	return who


## Only days not yet played can be changed, and not race days (races are fixed).
func can_change(d: int) -> bool:
	return d >= day and d < 7 and not races.has(d)


## Replaces the day's sessions (at most Training.MAX_SESSIONS_PER_DAY; [] = rest day). False if not allowed.
func set_sessions(d: int, ids: Array, by := "player") -> bool:
	if not can_change(d) or not by in CHANGED_BY or ids.size() > Training.MAX_SESSIONS_PER_DAY:
		return false
	for id in ids:
		if Data.get_session(id).is_empty():
			return false
	_set_change(d, "sessions", ids.duplicate(), by, ids == plan[d])
	return true


## Puts session `id` in place of the one in `slot` (0 or 1).
func swap_session(d: int, slot: int, id: String, by := "player") -> bool:
	var ids := session_ids(d).duplicate()
	if slot < 0 or slot >= ids.size():
		return false
	ids[slot] = id
	return set_sessions(d, ids, by)


## Leaves out the session in `slot`.
func skip_session(d: int, slot: int, by := "player") -> bool:
	var ids := session_ids(d).duplicate()
	if slot < 0 or slot >= ids.size():
		return false
	ids.remove_at(slot)
	return set_sessions(d, ids, by)


## Adds a session to the day (fails if the day already has the maximum).
func add_session(d: int, id: String, by := "player") -> bool:
	var ids := session_ids(d).duplicate()
	ids.append(id)
	return set_sessions(d, ids, by)


func make_rest_day(d: int, by := "player") -> bool:
	return set_sessions(d, [], by)


## Sets the day's intensity: an id from data/health.json ("easy" / "normal" / "hard").
func set_intensity(d: int, level: String, by := "player") -> bool:
	if not can_change(d) or not by in CHANGED_BY or not level in Data.health.intensity or level.begins_with("_"):
		return false
	_set_change(d, "intensity", level, by, level == plan_intensity[d])
	return true


## Back to the weekly plan for that day (removes all its changes).
func reset_day(d: int) -> bool:
	if not can_change(d):
		return false
	changes.erase(d)
	return true


## Records a change; a value that is the same as the plan isn't a change, so it is removed instead.
func _set_change(d: int, part: String, value: Variant, by: String, same_as_plan: bool) -> void:
	var c: Dictionary = changes.get(d, {})
	if same_as_plan:
		c.erase(part)
	else:
		c[part] = {"value": value, "by": by}
	if c.is_empty():
		changes.erase(d)
	else:
		changes[d] = c


# --- Save / load -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_changes := {}
	for d in changes:
		saved_changes[str(d)] = changes[d]   # JSON keys must be strings
	return {
		"monday": monday, "day": day, "day_started": day_started, "changes": saved_changes, "played": played,
		"stimulus": _stimulus, "notes": _notes, "raced": _raced, "fatigue_start": _fatigue_start,
		"fatigue_peak": _fatigue_peak, "fatigue_sum": _fatigue_sum, "sessions": _sessions, "load": _load,
		"off_track": _off_track,
	}


## A week in progress from a save. `week_plan` is the game's weekly plan; race days are set by the game.
static func from_dict(athlete: Athlete, week_plan: Variant, d: Dictionary) -> WeekSim:
	var w := WeekSim.new(athlete, week_plan, Game.int_date(d.monday))
	w.day = int(d.day)
	w.day_started = bool(d.get("day_started", false))
	for key in d.get("changes", {}):
		w.changes[int(key)] = d.changes[key]
	for r in d.get("played", []):
		r.day = int(r.day)
		w.played.append(r)
	for r in d.get("raced", []):
		r.day = int(r.day)
		w._raced.append(r)
	w._stimulus = d.get("stimulus", {})
	w._notes = d.get("notes", [])
	w._fatigue_start = float(d.fatigue_start)
	w._fatigue_peak = float(d.fatigue_peak)
	w._fatigue_sum = float(d.fatigue_sum)
	w._sessions = int(d.sessions)
	w._load = float(d.load)
	w._off_track = d.get("off_track", [])
	return w


# --- The simulation of one day ----------------------------------------------------------------

func _sessions_of(ids: Array) -> Array:
	var sessions := []
	for id in ids:
		var s := Data.get_session(id)
		if not s.is_empty():
			sessions.append(s)
	return sessions


## Plays day `day` and moves on to the next. `meet` is set on a race day (then `sessions` is the race).
func _play_day(sessions: Array, meet: Dictionary, level: String) -> Dictionary:
	var is_race := not meet.is_empty()
	var mult := Training.intensity(level)
	var load_mult := float(mult.load)
	var effect_mult := float(mult.effect)
	var day_load := 0.0
	var keep := Training.daily_keep(a)
	var extra_recovery := 0.0
	var trained := false
	var done := []
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
			_stimulus[attr] = _stimulus.get(attr, 0.0) + float(s.effects[attr]) * eff * fresh * effect_mult
		day_load += Training.session_load(a, s) * load_mult
		extra_recovery += float(s.get("recovery", 0))
		_sessions += 1
		trained = true
		if not is_race:
			done.append(s.id)
	if not trained:
		keep -= Training.REST_DAY_EXTRA
	_load += day_load
	a.fatigue = clampf(a.fatigue * keep + day_load - extra_recovery, 0.0, 100.0)
	_fatigue_peak = maxf(_fatigue_peak, a.fatigue)
	_fatigue_sum += a.fatigue
	var record := {"day": day, "sessions": done, "intensity": level, "race": meet.get("key", "") if is_race else "",
			"load": day_load, "fatigue": a.fatigue}
	played.append(record)
	day += 1
	day_started = false
	return record
