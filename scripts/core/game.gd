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
## The monthly record of the attributes and best times (ProgressLog, playtest fix 7): a record at the start of the career
## and at the end of every month, saved with the career.
var progress: Array = []
## Autosave after every played day. Dev tools that play thousands of days switch it off.
var autosave := true
## A throw-away test career made by the Dev menu (DevTools, debug builds): nothing of it is ever saved (SaveGame.save does
## nothing) and the health model is off. A new or loaded career ends it.
var dev_test := false

## Session L2a: the "what this race did" cards (RaceRecap), oldest first, the last data/race_recap.json `keep` (race and scratch
## cards; saved with the career; older saves have none).
var race_cards: Array = []
## Session L2a: the scratch card the hub shows once, where the player scratched (not saved).
var scratch_card := {}

var _week: WeekSim
var _playing_week := false   # the current day is being played by advance_week (it goes on after a race)
var _race_note := {}         # the race just finished, for the coach's evening message (cleared when the day ends)
var _card_before := {}       # RaceRecap.before of the race day being ended (cleared when its card is made)
var _card_race: RaceDay      # that race day
var _race_end := ""          # what the race day's end returned (end_race_day), for resume_after_race
var _next_event := 1


## `mode` is how the training plan works (SeasonPlan.PHASES: the coach's season plan, with the main
## championships of the season entered as targets; SeasonPlan.REPEAT: one repeating week, the M1 behaviour).
## Dev tools that play days ask for REPEAT so no meets are entered and no stop events come.
## `variant`: the coach's plan to start on ("" = the coach's ★ pick, SeasonPlan.coach_pick).
func start_career(new_athlete: Athlete, mode := SeasonPlan.PHASES, variant := "") -> void:
	_leave_test()
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
	race_cards = []
	scratch_card = {}
	events = []
	day_log = []
	progress = [ProgressLog.snapshot(athlete, date, "start")]
	_next_event = 1
	_week = null
	systems = _make_systems()
	(get_system("coach") as CoachSystem).ensure_head(athlete, date)   # the career's club coach (GDD 4.9.1)
	(get_system("moments") as StoryletSystem).ensure_cast(athlete)   # the people around them (session P1; only with the people on)
	var rng := RandomNumberGenerator.new()
	GameConfig.randomize_dice(rng, "rivals")
	rivals = Rivals.generate(athlete, rng)
	# A career on the coach's ★ plan starts with the coach's offer of the three plans (GDD 4.8; tools that name a
	# plan don't get it).
	if mode == SeasonPlan.PHASES and variant == "" and SeasonSystem.offers_enabled:
		(get_system("season") as SeasonSystem).offer(season.first_season)
	if autosave:
		SaveGame.save(SaveGame.AUTOSAVE)


## A test career of the Dev menu ends when a real career starts or loads: saving works again, the health model is back on.
func _leave_test() -> void:
	if dev_test:
		dev_test = false
		GameConfig.set_option("health", true)


func _make_systems() -> Array:
	# (Moments after Health and Coach: an evening moment sees the day's injury news and the coach's record. The coach's
	# proposals last: he looks at the day after the body, Form and the moments have had their say.)
	# (The season goals (C5) after the moments: their messages and talks are moments; the coach's meet and target suggestions after them.)
	# (The coach market (C6) last: a change of coach happens on Sunday night after the old coach's week is counted.)
	# (The mind (M1) after the coach and before the moments: the day's diagnoses and race are news for the moods before an evening
	# moment or the Sunday talk reads them.)
	# (School (S1) before the mind: the day's tests and the life load are in the day log before the mind reads the day.)
	# (The habits (L1b, the free-time slots) beside the school: no dice; each evening they remember the slot for the next day.)
	var list: Array = [HealthSystem.new(), FormSystem.new(), SeasonSystem.new(), CoachSystem.new(), SchoolSystem.new(), HabitSystem.new(),
			MindSystem.new(), StoryletSystem.new(), SeasonGoals.new(), CoachProposals.new(), CoachSuggests.new(), CoachMarket.new()]
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
			"events": events, "next_event": _next_event, "day_log": day_log, "systems": system_states,
			"progress": progress, "stats_year": "calendar",   # season bests by calendar year (decision 30; older saves are converted on load)
			"race_cards": race_cards}


## Works for every save version: version 1 is always on a Monday with no week in progress, so the
## newer parts simply start empty. Versions 1 and 2 have a plain `training_plan` (Mon..Sun session ids):
## it becomes the repeating week with every day Normal. Version 3 has the `season`.
func from_dict(d: Dictionary) -> void:
	_leave_test()
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
		GameConfig.randomize_dice(rng, "rivals")
		rivals = Rivals.generate(athlete, rng)
	Rivals.ensure_personalities(rivals)   # saves from before step R1
	if not d.has("stats_year"):
		# Saves from before GDD 4.3.1 decision 30 counted season bests over the training year (Nov–Oct). The current
		# one becomes this calendar year's (its date is not stored); older ones are dropped.
		var old_season := int(date.year) if int(date.month) >= 11 else int(date.year) - 1
		for r in rivals:
			r.sb_season = int(date.year) if int(r.get("sb_season", -1)) == old_season else -1
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
	race_cards = d.get("race_cards", [])   # (session L2a; older saves: none)
	for c in race_cards:
		RaceRecap.fixed(c)
	scratch_card = {}
	progress = ProgressLog.fixed(d.get("progress", []))
	if progress.is_empty():   # a save from before the monthly record: it starts now (the earlier months are not known)
		progress = [ProgressLog.snapshot(athlete, date, "first")]
	systems = _make_systems()
	var states: Dictionary = d.get("systems", {})
	for s in systems:
		s.from_dict(states.get(s.id, {}))
	# Saves from before version 5 (session L1b) have the school's two settings instead of the habits: they become the nearest habits.
	if not states.has("habits"):
		var school_state: Dictionary = states.get("school", {})
		(get_system("habits") as HabitSystem).from_old(str(school_state.get("effort", "normal")), str(school_state.get("free_time", "normal")))
	# Saves from before version 4 (session C1) have no coach records: the athlete gets their club coach now (the same
	# person and voice they had at races).
	(get_system("coach") as CoachSystem).ensure_head(athlete, date)


## JSON turns every number into a float; dates must be ints again.
static func int_date(d: Dictionary) -> Dictionary:
	return {"year": int(d.year), "month": int(d.month), "day": int(d.day)}


# --- Entries ---------------------------------------------------------------------------------

func enter(meet_key: String) -> void:
	if not meet_key in entries:
		entries.append(meet_key)


## The Training tab's switch back to the season plan (GDD 4.8). The season keeps the player's earlier changes; a
## career that never had a season plan (an older save) gets the coach's ★ plan, and its coming targets are
## entered where allowed, as for a new career.
func use_season_plan() -> void:
	var fresh := season.switch_to_phases(athlete, week_monday(), SeasonPlan.coach_pick(athlete, date, get_system("health") as HealthSystem))
	if fresh:
		for key in season.targets(season.first_season):
			var m := Calendar.get_meet(key)
			if not m.is_empty() and Calendar.can_enter(athlete, m, date).ok:
				enter(key)
	# Back in a later season than the plan was made for (it was off at the rollover): that season starts now.
	var ss := get_system("season") as SeasonSystem
	if ss:
		ss.roll_over(season.plan_year(week_monday()))
	current_week()
	var health := get_system("health") as HealthSystem
	if health:
		health.refresh()


func withdraw(meet_key: String) -> void:
	entries.erase(meet_key)
	season.on_withdraw(meet_key)   # a target the player no longer races is no target


## The player scratches from an entered race (doesn't start): the entry is withdrawn and that day becomes
## a training day again. Works before the day (the race is still only in the week) and on race day itself,
## when the race screen is waiting (`race_day`); then the day is still to be played, as a training day.
## `cause` (session F1): "player" (the Calendar, the day editor, the sore warning), "school" (a busy test week) or "coach" (his
## own scratch advice); the head coach says a line in his thread unless it was his advice (CoachTalk.scratch_line).
func scratch_race(meet_key: String, cause := "player") -> void:
	var meet := Calendar.get_meet(meet_key)
	# (Session L2a, the scratch card: why and what the plan was, read before the entry goes.)
	var why := RaceRecap.scratch_why(cause)
	var plan_before := RaceRecap.plan_until(meet)
	var was_target := not meet.is_empty() and season.mode == SeasonPlan.PHASES and meet_key in season.targets(SeasonPlan.year_of(meet.date))
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
	var ms := get_system("moments") as StoryletSystem
	var line := ""
	if ms != null and ms.active():
		ms.coach_says(CoachTalk.scratch_line(meet, cause))
		line = CoachTalk.scratch_line(meet, cause, false)   # (the card shows the next race itself)
		if cause == "coach":   # (his own advice: nothing new in his thread, F1; his word on the card)
			line = CoachTalk.scratch_reply(meet, RaceRecap.sore_area_name())
	if not meet.is_empty():
		scratch_card = RaceRecap.scratch(meet, cause, why, plan_before, was_target, line)
		add_card(scratch_card)


## Keeps a card (RaceRecap) with the career: the last data/race_recap.json `keep` (a card with the same id replaces the old one).
func add_card(card: Dictionary) -> void:
	race_cards = race_cards.filter(func(c): return str(c.get("id", "")) != str(card.get("id", "")))
	race_cards.append(card)
	while race_cards.size() > int(Data.recap.get("keep", 40)):
		race_cards.pop_front()


## A kept card by its id ({} when it is gone).
func card(id: String) -> Dictionary:
	for c in race_cards:
		if str(c.get("id", "")) == id:
			return c
	return {}


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
	var coach := get_system("coach") as CoachSystem
	_week.coach_effect = coach.training_effect() if coach else {}
	var mind := get_system("mind") as MindSystem
	_week.quality = mind.training_quality() if mind else 1.0   # motivation (GDD 4.9.4): exactly 1.0 in the middle
	_week.school = SchoolSystem.sys()   # the life load (GDD 4.9.3, S1): 0 on a normal school day at Normal / Normal
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
	end_race_day()
	return resume_after_race()


## Session L2a: the first half of finish_race(): ends the race day (the result, the evening, the card in race_cards) and stops
## there, so the race screen can show "what this race did" before Play week goes on. Returns what the day's end returned
## (DAY_DONE / WEEK_DONE / STOP); then call resume_after_race().
func end_race_day() -> String:
	_card_before = RaceRecap.before(race_day)
	_card_race = race_day
	_record(race_day)
	_week.race_done(race_day.summary(), race_day.incidents)
	_race_note = _make_race_note(race_day)
	race_day = null
	_race_end = _end_day()
	return _race_end


## True when `race_day` is the race of today in the week being played (a tool may open the race screen on any meet: then the
## race screen keeps its old result view and no card is made).
func can_end_race_day() -> bool:
	if race_day == null or _week == null or not _week.is_race_day(_week.day):
		return false
	return str(_week.races[_week.day].get("key", "")) == str(race_day.meet.get("key", ""))


## The second half: if the race came up during Play week, the week goes on. Same return values as advance_day().
func resume_after_race() -> String:
	var result := _race_end
	_race_end = ""
	if result == DAY_DONE and _playing_week:
		return _play_on()
	_playing_week = false
	return result if result != "" else DAY_DONE


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
	if not _card_before.is_empty():   # (session L2a: the race day's card, after the evening and before Sunday's week end)
		var made := RaceRecap.build(_card_race, _card_before)
		_card_before = {}
		_card_race = null
		if not made.is_empty():
			add_card(made)
	_race_note = {}
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
	var played := date
	date = add_days(date, 1)
	if int(date.month) != int(played.month):   # the month is over: its record (ProgressLog)
		ProgressLog.add(progress, ProgressLog.snapshot(athlete, played, "month"))
	_prune()
	if autosave:
		SaveGame.save(SaveGame.AUTOSAVE)
	return STOP if not pending_event().is_empty() else result


## Sunday night: attribute progression and the weekly report, week-end hooks, rivals' training week.
func _end_week(ctx: Dictionary) -> void:
	last_report = _week.end_week()
	# The week's phase and kind for the Report (GDD 4.8 UI); in repeat mode only a week of easing back in.
	var plan := season.week_for(_week.monday)
	if season.mode == SeasonPlan.PHASES:
		last_report.plan = {"phase": plan.phase, "phase_week": plan.phase_week, "phase_weeks": plan.phase_weeks,
				"kind": plan.kind, "target": plan.target}
	if plan.get("kind", "") == "return":
		if not last_report.has("plan"):
			last_report.plan = {"kind": "return"}
		last_report.plan.return_week = plan.return_week
		last_report.plan.return_weeks = plan.return_weeks
	ctx.report = last_report
	_hook("on_week_end", ctx)
	# Session L2b (recording only): every attribute that moved this week, from its value when the week started to now (after the
	# Sunday hooks: the long-break detraining, the mental plan); a save from before L2b has no start (then only Sunday's changes).
	var start: Dictionary = last_report.get("attr_start", {})
	last_report.erase("attr_start")
	var moved := {}
	if not start.is_empty():
		for id in athlete.attributes:
			var was := float(start.get(id, athlete.attributes[id]))
			if float(athlete.attributes[id]) != was:
				moved[id] = {"before": was, "after": float(athlete.attributes[id])}
	else:
		for id in last_report.get("changes", {}):
			moved[id] = {"before": float(last_report.changes[id].before), "after": athlete.get_attr(str(id))}
	last_report.attrs = moved
	var hs := get_system("habits") as HabitSystem   # (the week's free-time slots as they were played: the report's causes)
	if hs != null:
		last_report.slots = hs.week_activities(_week.monday)
	Rivals.train_week(rivals, athlete.gender, _week.monday, int(athlete.birth_date.year))
	_week = null
	open_report = true


func _day_context() -> Dictionary:
	return {"date": date.duplicate(), "day": Calendar.weekday(date), "day_type": Calendar.day_type(date),
			"week": _week, "race_note": _race_note}


## What the coach needs for his message on the evening after the player's race (StoryletSystem, session C3): the meet, the
## athlete's result entry of its last round and the Race-story line the race screen made ({} for a race with no result).
func _make_race_note(rd: RaceDay) -> Dictionary:
	if rd.player_results.is_empty():
		return {}
	var res := {}
	for i in range(athlete.results.size() - 1, -1, -1):
		if str(athlete.results[i].meet_key) == str(rd.meet.key):
			res = athlete.results[i]
			break
	if res.is_empty():
		return {}
	return {"meet": str(rd.meet.name), "key": str(rd.meet.key), "result": res, "story": rd.story.duplicate(),
			"rounds": rd.player_results.duplicate(true), "beat_above": _beaten_above(rd), "vs": _rivals_vs(rd)}


## The rivals who ran a round with the player (session P1, the Rivals thread): [{id, beat}], `beat` = the player finished ahead
## (or they did not finish and the player did). A rival met in several rounds counts by the last one.
static func _rivals_vs(rd: RaceDay) -> Array:
	var by_id := {}
	for res in rd.all_results:
		var mine := -1
		for i in res.size():
			if res[i].get("is_player", false):
				mine = i
		if mine < 0:
			continue
		var i_finished := str(res[mine].get("status", "")) == ""
		for i in res.size():
			var rival: Dictionary = res[i].get("rival", {})
			if i == mine or rival.is_empty():
				continue
			var they_finished := str(res[i].get("status", "")) == ""
			by_id[str(rival.id)] = i_finished and (i > mine or not they_finished)
	var out := []
	for rid in by_id:
		out.append({"id": rid, "beat": by_id[rid]})
	return out


## The mind's news (session M1): how many runners who went into a round with a faster season best (else personal best) than the
## player's finished behind them (each runner counted once over the meet's rounds).
static func _beaten_above(rd: RaceDay) -> int:
	var names := {}
	for res in rd.all_results:
		var mine := -1
		for i in res.size():
			if res[i].get("is_player", false):
				mine = i
		if mine < 0 or str(res[mine].get("status", "")) != "":
			continue
		var my_ref := float(res[mine].get("sb_before", 0.0))
		if my_ref <= 0.0:
			my_ref = float(res[mine].get("pb_before", 0.0))
		if my_ref <= 0.0:
			continue
		for i in range(mine + 1, res.size()):
			var ref := float(res[i].get("sb_before", 0.0))
			if ref <= 0.0:
				ref = float(res[i].get("pb_before", 0.0))
			if ref > 0.0 and ref < my_ref:
				names[str(res[i].name)] = true
	return names.size()


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
	# Session F1: a coach text's pronoun placeholders are filled with the head coach's (texts about another coach come filled).
	# (copies: the choices may be an array or dictionaries of the data files)
	choices = choices.duplicate()
	for i in choices.size():
		var c = choices[i]
		for key in ["label", "detail", "hint"]:
			if c is Dictionary and c.has(key) and str(c[key]).find("{") >= 0:
				c = c.duplicate()
				c[key] = CoachSystem.words(str(c[key]))
				choices[i] = c
	var e := {"id": "e%d" % _next_event, "date": date.duplicate(), "source": source, "title": CoachSystem.words(title),
			"text": CoachSystem.words(text), "choices": choices, "stop": stop, "answer": ""}
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

## Stores the player's results and PBs, and the rivals' PBs. A race without a time (status "dnf" / "dq") is
## kept in the results but never counts for a PB or the rankings. A rival hurt in a fall misses some weeks
## (out_weeks, GDD 4.3.1; part of the health model, so only when it is on).
func _record(rd: RaceDay) -> void:
	var event := athlete.main_event
	for r in rd.player_results:
		var status: String = r.get("status", "")
		var pb: float = athlete.personal_bests.get(event, 0.0)
		var is_pb: bool = status == "" and (pb == 0.0 or r.time < pb)
		if is_pb:
			athlete.personal_bests[event] = r.time
		var entry := {"date": rd.meet.date, "meet": rd.meet.name, "meet_key": rd.meet.key,
				"event": event, "round": r.round, "place": r.place, "field": r.field, "time": r.time, "pb": is_pb}
		if status != "":
			entry.status = status
		athlete.results.append(entry)
	for res in rd.all_results:
		var with_player: bool = res.any(func(row): return row.is_player)
		for row in res:
			var rival: Dictionary = row.get("rival", {})
			if not rival.is_empty():
				if row.get("status", "") == "":
					Rivals.record_time(rival, row.time, rd.meet.date)
				if int(row.get("out_weeks", 0)) > 0 and HealthSystem.model_enabled:
					rival.out_weeks = maxi(int(rival.get("out_weeks", 0)), int(row.out_weeks))
				if with_player:
					rival.met = int(rival.get("met", 0)) + 1   # raced the player (the tag shows from 2, step R4)


static func add_days(d: Dictionary, days: int) -> Dictionary:
	var t := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12})
	var r := Time.get_datetime_dict_from_unix_time(t + days * 86400)
	return {"year": r.year, "month": r.month, "day": r.day}
