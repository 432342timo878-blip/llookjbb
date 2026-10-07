extends Node
## The running career: the player's athlete, today's date, the training plan, race entries and rivals.
## Time moves a day at a time (GDD 4.5): advance_day() plays today, advance_week() plays on to Sunday night
## or until something needs the player. Every day runs the same loop, with slots that systems hook into
## (GDD 4.7, see GameSystem): day start → training or race → health → day end, and after Sunday: week end.
## The current week (WeekSim) lives between days and is saved with the game.

## Career start: the Finnish training year begins in autumn. 2 Nov 2026 is a Monday.
const START_DATE := {"year": 2026, "month": 11, "day": 2}
## What advance_day(), advance_week() and finish_race() report back:
const DAY_DONE := "day"     # a day was played; the week goes on
const WEEK_DONE := "week"   # Sunday night was played: last_report is ready
const RACE := "race"        # today is a race day: open the race screen (race_day is set)
const STOP := "stop"        # a stop event waits for the player's answer (see pending_event)
## How many days of day log (and of answered events) are kept.
const LOG_DAYS := 28

var athlete: Athlete
var date := START_DATE.duplicate()   # today: the next day to be played
## The training plan over time (GDD 4.8): the coach's season plan in phases (new careers) or one week plan that
## repeats every week (season.repeat_week = {days, intensity}, see WeekPlan). Ask for a week: season.week_for(monday).
var season := SeasonPlan.new()
var entries: Array = []          # meet keys (see Calendar) the athlete has entered
var rivals: Array = []           # fictional runners of the athlete's age and gender (see Rivals)
var last_report: Dictionary = {} # result of the most recent week, for the weekly report
var race_day: RaceDay            # set while a race is waiting to be run
var open_report := false         # a week just ended: the career hub should show its report
var systems: Array = []          # GameSystem instances hooked into the day loop
## Things that need attention (GDD 4.7), oldest first:
## {id, date, source, title, text, choices: [{id, label, detail}], stop, answer ("" = not answered yet)}
var events: Array = []
## What was actually done each day, oldest first:
## {date, day_type, sessions, intensity, race (meet key or ""), load, fatigue, events (ids)}
var day_log: Array = []
## Autosave after every played day. Dev tools that play thousands of days switch it off.
var autosave := true

var _week: WeekSim
var _playing_week := false   # the current day is being played by advance_week (it goes on after a race)
var _next_event := 1


## `mode` is how the training plan works (SeasonPlan.PHASES: the coach's season plan, with the main
## championships of the season entered as targets; SeasonPlan.REPEAT: one repeating week, the M1 behaviour).
## Dev tools that play days ask for REPEAT so no meets are entered and no stop events come.
## `variant`: the coach's plan to start on ("" = the coach's ★ pick, SeasonPlan.coach_pick).
func start_career(new_athlete: Athlete, mode := SeasonPlan.PHASES, variant := "") -> void:
	athlete = new_athlete
	date = START_DATE.duplicate()
	entries = []
	if mode == SeasonPlan.PHASES:
		season = SeasonPlan.phased(athlete, date, variant if variant != "" else SeasonPlan.coach_pick(athlete, date))
		for key in season.targets(season.first_season):
			enter(key)
	else:
		season = SeasonPlan.repeating(WeekPlan.coach())
	last_report = {}
	race_day = null
	events = []
	day_log = []
	_next_event = 1
	_week = null
	systems = _make_systems()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	rivals = Rivals.generate(athlete, rng)
	if autosave:
		SaveGame.save(SaveGame.AUTOSAVE)


func _make_systems() -> Array:
	var list: Array = [HealthSystem.new(), FormSystem.new()]
	if OS.is_debug_build():
		list.append(DevEvents.new())
	return list


func get_system(id: String) -> GameSystem:
	for s in systems:
		if s.id == id:
			return s
	return null


# --- Save / load -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var system_states := {}
	for s in systems:
		system_states[s.id] = s.to_dict()
	return {"athlete": athlete.to_dict(), "date": date, "season": season.to_dict(), "entries": entries,
			"rivals": rivals, "week": _week.to_dict() if _week else {}, "last_report": last_report,
			"events": events, "next_event": _next_event, "day_log": day_log, "systems": system_states}


## Works for every save version: version 1 is always on a Monday with no week in progress, so the
## newer parts simply start empty. Versions 1 and 2 have a plain `training_plan` (Mon..Sun session ids):
## it becomes the repeating week with every day Normal. Version 3 has the `season`.
func from_dict(d: Dictionary) -> void:
	athlete = Athlete.from_dict(d.athlete)
	date = int_date(d.date)
	if d.has("season"):
		season = SeasonPlan.from_dict(d.season)
	else:
		season = SeasonPlan.repeating(d.training_plan)
	entries = d.entries
	rivals = d.get("rivals", [])
	if rivals.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		rivals = Rivals.generate(athlete, rng)
	race_day = null
	open_report = false
	_playing_week = false
	var week: Dictionary = d.get("week", {})
	_week = null if week.is_empty() else WeekSim.from_dict(athlete, season.week_for(int_date(week.monday)), week)
	last_report = d.get("last_report", {})
	if not last_report.is_empty():
		last_report.monday = int_date(last_report.monday)
		last_report.sessions = int(last_report.sessions)
	events = d.get("events", [])
	for e in events:
		e.date = int_date(e.date)
	day_log = d.get("day_log", [])
	for entry in day_log:
		entry.date = int_date(entry.date)
	_next_event = int(d.get("next_event", 1))
	systems = _make_systems()
	var states: Dictionary = d.get("systems", {})
	for s in systems:
		s.from_dict(states.get(s.id, {}))


## JSON turns every number into a float; dates must be ints again.
static func int_date(d: Dictionary) -> Dictionary:
	return {"year": int(d.year), "month": int(d.month), "day": int(d.day)}


# --- Entries ---------------------------------------------------------------------------------

func enter(meet_key: String) -> void:
	if not meet_key in entries:
		entries.append(meet_key)


func withdraw(meet_key: String) -> void:
	entries.erase(meet_key)
	season.on_withdraw(meet_key)   # a target the player no longer races is no target


## The player scratches from an entered race (doesn't start): the entry is withdrawn and that day becomes
## a training day again. Works before the day (the race is still only in the week) and on race day itself,
## when the race screen is waiting (`race_day`); then the day is still to be played, as a training day.
func scratch_race(meet_key: String) -> void:
	var meet := Calendar.get_meet(meet_key)
	withdraw(meet_key)
	if race_day != null and race_day.meet.key == meet_key:
		race_day = null
		_playing_week = false
	if not meet.is_empty() and Calendar.date_key(meet.date) == Calendar.date_key(date):
		post_event("player", "Scratched: %s" % meet.get("name", meet_key), "You decided not to start.")
	current_week()   # the week's races follow the entries: the day is a training day now
	var health := get_system("health") as HealthSystem
	if health:
		health.refresh()   # injury limits for the day that was a race day


## The next entered meet from today on, or {}.
func next_race() -> Dictionary:
	for m in Calendar.meets_between(date, add_days(date, 400)):
		if m.key in entries:
			return m
	return {}


# --- The current week ----------------------------------------------------------------------------

## The Monday of the current week.
func week_monday() -> Dictionary:
	return Calendar.monday_of(date)


## The week being played (made when first needed), kept in step with the season plan and race entries.
## Day changes for this week go through it: Game.current_week().set_intensity(day, "easy") etc.
func current_week() -> WeekSim:
	var created := _week == null
	if created:
		_week = WeekSim.new(athlete, season.week_for(week_monday()), week_monday())
		_week.day = Calendar.weekday(date)   # 0 unless an old save was made mid-week
	_week.set_plan(season.week_for(_week.monday))
	_week.races = Calendar.races_in_week(entries, _week.monday)
	if created:
		for s in systems:
			s.on_week_start(_week)
	return _week


# --- Playing days --------------------------------------------------------------------------------

## Plays today. Returns DAY_DONE, WEEK_DONE (Sunday played), RACE (open the race screen) or STOP.
func advance_day() -> String:
	_playing_week = false
	return _play_day()


## Plays on until Sunday night, a race day or a stop event. Same return values as advance_day().
func advance_week() -> String:
	_playing_week = true
	return _play_on()


## Call after the race screen is done with `race_day`: completes the race day. If the race came up
## during Play week, the week goes on. Same return values as advance_day().
func finish_race() -> String:
	_record(race_day)
	_week.race_done(race_day.summary())
	race_day = null
	var result := _end_day()
	if result == DAY_DONE and _playing_week:
		return _play_on()
	_playing_week = false
	return result


func _play_on() -> String:
	var result := DAY_DONE
	while result == DAY_DONE:
		result = _play_day()
	if result != RACE:
		_playing_week = false
	return result


func _play_day() -> String:
	if race_day != null:
		return RACE
	if not pending_event().is_empty():
		return STOP
	var week := current_week()
	if not week.day_started:
		week.day_started = true
		_hook("on_day_start", _day_context())
		if not pending_event().is_empty():
			return STOP   # the day isn't played yet; the next press carries on from here
	week = current_week()   # a system may have changed the entries (e.g. withdrawn an injured athlete)
	if week.is_race_day(week.day):
		race_day = RaceDay.new(week.races[week.day], athlete, rivals)
		return RACE
	week.play_day()
	return _end_day()


## After today's training or race: health, day end, the day log, (Sunday) week end; then tomorrow.
func _end_day() -> String:
	var ctx := _day_context()
	ctx.record = _week.played[-1]
	_hook("on_health", ctx)
	_hook("on_day_end", ctx)
	var rec: Dictionary = ctx.record
	var entry := {"date": date.duplicate(), "day_type": ctx.day_type, "sessions": rec.sessions,
			"intensity": rec.intensity, "race": rec.race, "load": rec.load, "fatigue": rec.fatigue, "events": []}
	# Systems can add their own fields to the day log (health: soreness and active injuries).
	var extra: Dictionary = ctx.get("log_extra", {})
	for key in extra:
		entry[key] = extra[key]
	day_log.append(entry)
	var result := DAY_DONE
	if _week.is_over():
		_end_week(ctx)
		result = WEEK_DONE
	for e in events:
		if Calendar.date_key(e.date) == Calendar.date_key(date):
			entry.events.append(e.id)
	date = add_days(date, 1)
	_prune()
	if autosave:
		SaveGame.save(SaveGame.AUTOSAVE)
	return STOP if not pending_event().is_empty() else result


## Sunday night: attribute progression and the weekly report, week-end hooks, rivals' training week.
func _end_week(ctx: Dictionary) -> void:
	last_report = _week.end_week()
	ctx.report = last_report
	_hook("on_week_end", ctx)
	Rivals.train_week(rivals, athlete.gender, _week.monday)
	_week = null
	open_report = true


func _day_context() -> Dictionary:
	return {"date": date.duplicate(), "day": Calendar.weekday(date), "day_type": Calendar.day_type(date),
			"week": _week}


func _hook(method: String, ctx: Dictionary) -> void:
	for s in systems:
		s.call(method, ctx)


## Keeps the last LOG_DAYS days of day log and events (unanswered stop events are always kept).
func _prune() -> void:
	var oldest := Calendar.date_key(add_days(date, -LOG_DAYS))
	day_log = day_log.filter(func(e): return Calendar.date_key(e.date) >= oldest)
	events = events.filter(func(e): return Calendar.date_key(e.date) >= oldest or (e.stop and e.answer == ""))


# --- Events --------------------------------------------------------------------------------------

## Adds an event from `source` (a system id: "health", later "coach" / "school"). `choices` are
## [{id, label, detail}]; with none the player just acknowledges it ("ok"). A `stop` event pauses
## Play week until it is answered. Returns the event.
func post_event(source: String, title: String, text: String, choices := [], stop := false) -> Dictionary:
	var e := {"id": "e%d" % _next_event, "date": date.duplicate(), "source": source, "title": title,
			"text": text, "choices": choices, "stop": stop, "answer": ""}
	_next_event += 1
	events.append(e)
	return e


## The oldest stop event still waiting for an answer, or {}.
func pending_event() -> Dictionary:
	for e in events:
		if e.stop and e.answer == "":
			return e
	return {}


## The player's answer; the system that posted the event handles it.
func answer_event(event_id: String, choice: String) -> void:
	for e in events:
		if e.id == event_id and e.answer == "":
			e.answer = choice
			var s := get_system(e.source)
			if s:
				s.on_answer(e, choice)
			return


# --- Results -------------------------------------------------------------------------------------

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
