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
var plan_mental: Array          # (session L3b1) the weekly template's mental session per day: 7 × kind or ""
var monday: Dictionary
var races: Dictionary           # day index -> meet
var day := 0                    # the next day to play (0 = Monday; 7 = the whole week is played)
var day_started := false        # the game has run its day-start step for `day` (it may stop there)
## day index -> {"sessions": {"value": [ids], "by": who}, "intensity": {"value": id, "by": who}}
var changes := {}
## What was actually done, one record per played day: {day, sessions, intensity, race, load, fatigue}
var played := []
## The coach's training effect for this week (CoachSystem.training_effect; {} = none). Set by Game.current_week()
## every time it hands out the week, not saved.
var coach_effect := {}
## Motivation's training quality (MindSystem.training_quality, session M1): every training session's training effect x this
## (races not). Exactly 1.0 across the middle word, so the M1 balance is unchanged. Set by Game.current_week(), not saved.
var quality := 1.0
## The school (SchoolSystem, session S1) or null: each played day's life load slows the fatigue recovery (0 on a normal school
## day at Normal / Normal: nothing changes). Set by Game.current_week(), not saved; weeks made by tools and previews have none.
var school = null

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
## Session L2b (recording only; nothing reads these to decide anything): the stimulus by where it came from, attribute id ->
## {session id or "race:<meet key>": amount} (the amounts add up to `_stimulus`); what tired legs took away and what motivation
## added to it ({"tired": {attr: amount}, "motivation": {attr: amount}, "tired_days": [day]}); attribute changes made during
## the week outside the Sunday progression (attribute id -> {part key: delta}, e.g. a race evening's consistency); the
## attributes when the week started (the report's before / after).
var _sources := {}
var _mods := {"tired": {}, "motivation": {}, "tired_days": []}
var _extra := {}
var _attr_start := {}


## `week_plan` is a week plan (see WeekPlan); the old plain Array of days works too (every day Normal).
func _init(athlete: Athlete, week_plan: Variant, week_monday: Dictionary, week_races := {}) -> void:
	a = athlete
	var p := WeekPlan.of(week_plan)
	plan = p.days
	plan_intensity = p.intensity
	plan_mental = WeekPlan.mental(p)
	monday = week_monday
	races = week_races
	_month = Game.add_days(monday, 3).month   # the month most of the week is in
	_fatigue_start = a.fatigue
	_fatigue_peak = a.fatigue
	_attr_start = a.attributes.duplicate()


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
	plan_mental = WeekPlan.mental(p)
	for d in range(day, 7):
		var c: Dictionary = changes.get(d, {})
		if c.has("sessions") and c.sessions.value == plan[d]:
			c.erase("sessions")
		if c.has("intensity") and c.intensity.value == plan_intensity[d]:
			c.erase("intensity")
		if c.has("mental") and str(c.mental.value) == str(plan_mental[d]):
			c.erase("mental")
		if c.is_empty():
			changes.erase(d)


## Plays today (`day`) as a training day: its sessions and intensity, with any day changes.
## Returns the day's record (see `played`).
func play_day() -> Dictionary:
	return _play_day(_sessions_of(session_ids(day)), {}, intensity(day))


## The race day is done: apply its load and training effect. `summary` is a line for the report;
## `incidents` = the player's falls and spike wounds (RaceDay.incidents), which the health model reads from
## the day's record. Returns the day's record.
func race_done(summary: String, incidents := []) -> Dictionary:
	var meet: Dictionary = races[day]
	var race: Dictionary = Data.competitions.race_session.duplicate()
	race.name = meet.name
	var d := day
	_raced.append({"day": d, "meet_key": meet.get("key", ""), "name": meet.name})
	var record := _play_day([race], meet, NORMAL)
	if not incidents.is_empty():
		record.incidents = incidents.duplicate(true)
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

	var parts := {}
	var changes_done := Training._apply_progression(a, _stimulus, monday, coach_effect, parts)
	for id in _extra:   # (session L2b: the week's other changes, e.g. a race evening's consistency)
		for key in _extra[id]:
			add_part(parts, str(id), str(key), float(_extra[id][key]))
	# Session L1a: the week's sessions done by the one definition (session_count) for the planner's "7/7 sessions done", day by day.
	var counted := {"planned": 0, "done": 0, "extra": 0, "days": []}
	for r in played:
		if str(r.get("race", "")) != "":
			continue
		var n := session_count(int(r.day), r)
		counted.planned += int(n.planned)
		counted.done += int(n.done)
		counted.extra += int(n.extra)
		counted.days.append({"day": int(r.day), "planned": int(n.planned), "done": int(n.done)})
	return {
		"monday": monday, "sessions": _sessions, "load": _load,
		"fatigue_start": _fatigue_start, "fatigue_end": a.fatigue, "fatigue_peak": _fatigue_peak,
		"fatigue_avg": fatigue_avg, "changes": changes_done, "notes": _notes, "races": _raced, "count": counted,
		# Session L2b (recording only): where each change came from (Game._end_week adds the Sunday hooks' parts and `attrs`).
		"parts": parts, "sources": _sources.duplicate(true), "stimulus": _stimulus.duplicate(), "mods": _mods.duplicate(true),
		"attr_start": _attr_start.duplicate(),
	}


## The training stimulus collected so far this week (attribute id -> amount). Read-only.
func stimulus_so_far() -> Dictionary:
	return _stimulus


## Session L2b: an attribute change made during the week outside the Sunday progression (recording only; the change itself is
## made by the caller). `key` names its cause (e.g. "race_growth:<meet key>").
func note_change(attr: String, key: String, delta: float) -> void:
	if delta == 0.0:
		return
	var parts: Dictionary = _extra.get(attr, {})
	parts[key] = float(parts.get(key, 0.0)) + delta
	_extra[attr] = parts


## Adds `delta` to part `key` of attribute `attr` in a report's `parts` (recording only).
static func add_part(parts: Dictionary, attr: String, key: String, delta: float) -> void:
	if delta == 0.0:
		return
	var p: Dictionary = parts.get(attr, {})
	p[key] = float(p.get(key, 0.0)) + delta
	parts[attr] = p


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


## Day `d`'s mental session (session L3b1): the day change if there is one, otherwise the weekly plan's ("" = none).
func mental(d: int) -> String:
	var c: Dictionary = changes.get(d, {})
	if c.has("mental"):
		return str(c.mental.value)
	return str(plan_mental[d]) if d < plan_mental.size() else ""


## The mental session kinds of the week so far and still planned, each with its first day: {kind: day} (played days from
## their records, the rest from the plan with this week's changes).
func mental_week() -> Dictionary:
	var out := {}
	for r in played:
		var k := str(r.get("mental", ""))
		if k != "" and not out.has(k):
			out[k] = int(r.day)
	for d in range(day, 7):
		var k := mental(d)
		if k != "" and not out.has(k):
			out[k] = d
	return out


## Sets day `d`'s mental session ("" = none; a kind from data/mind.json mental). Not on a played or race day.
func set_mental(d: int, kind: String, by := "player") -> bool:
	if not can_change(d) or not by in CHANGED_BY or (kind != "" and not WeekPlan.is_mental(kind)):
		return false
	_set_change(d, "mental", kind, by, kind == str(plan_mental[d]))
	return true


## Who changed what on day `d`: {"sessions": who, "intensity": who, "mental": who}, only for the parts that were changed.
func changed_by(d: int) -> Dictionary:
	var who := {}
	for part in changes.get(d, {}):
		who[part] = changes[d][part].by
	return who


## THE definition of a "done" session for the whole game (session F1, playtest 2: the habit goal said "352 of 352" while the
## Sunday talk said "8 of 11"): played day `d` with its record `rec` -> {planned, done, extra}. A day whose sessions the coach or
## an injury changed counts as the day they set (nothing missed); otherwise the plan's sessions count and each one not trained is
## missed (the player's own change, a rest day they chose). done <= planned; extra = sessions trained beyond the plan.
func session_count(d: int, rec: Dictionary) -> Dictionary:
	var trained: int = rec.sessions.size()
	var planned: int = plan[d].size()
	var by := str(changes.get(d, {}).get("sessions", {}).get("by", ""))
	if by == "coach" or by == "injury":
		planned = trained
	return {"planned": planned, "done": mini(trained, planned), "extra": maxi(0, trained - planned)}


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
		"sources": _sources, "mods": _mods, "extra": _extra, "attr_start": _attr_start,   # (session L2b; older saves: none)
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
	# (Session L2b: a save from before it has no record of the days already played; the report then says so.)
	w._sources = d.get("sources", {})
	var mods: Dictionary = d.get("mods", {})
	w._mods = {"tired": mods.get("tired", {}), "motivation": mods.get("motivation", {}),
			"tired_days": mods.get("tired_days", []).map(func(x): return int(x))}
	w._extra = d.get("extra", {})
	w._attr_start = d.get("attr_start", {})
	if not d.has("sources") and w.day > 0:
		w._mods["unrecorded"] = true
	return w


# --- The simulation of one day ----------------------------------------------------------------

func _sessions_of(ids: Array) -> Array:
	var sessions := []
	for id in ids:
		var s := Data.get_session(id)
		if not s.is_empty():
			sessions.append(s)
	return sessions


## Session L2b (recording only): `added` of attribute `attr` came from `source`; `plain` = the same without tired legs and
## motivation (`fresh`, `q`), so the report can say what each took away or added.
func _record_source(attr: String, source: String, added: float, plain: float, fresh: float, q: float) -> void:
	var src: Dictionary = _sources.get(attr, {})
	src[source] = float(src.get(source, 0.0)) + added
	_sources[attr] = src
	if fresh < 1.0:
		_mods.tired[attr] = float(_mods.tired.get(attr, 0.0)) + plain * q * (1.0 - fresh)
	if q != 1.0:
		_mods.motivation[attr] = float(_mods.motivation.get(attr, 0.0)) + plain * fresh * (q - 1.0)


## Plays day `day` and moves on to the next. `meet` is set on a race day (then `sessions` is the race).
func _play_day(sessions: Array, meet: Dictionary, level: String) -> Dictionary:
	var is_race := not meet.is_empty()
	var mult := Training.intensity(level)
	var load_mult := float(mult.load)
	var effect_mult := float(mult.effect)
	var q := 1.0 if is_race else quality
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
		var source := "race:" + str(meet.get("key", "")) if is_race else str(s.get("id", ""))
		for attr in s.effects:
			var added := float(s.effects[attr]) * eff * fresh * effect_mult * q
			_stimulus[attr] = _stimulus.get(attr, 0.0) + added
			_record_source(str(attr), source, added, float(s.effects[attr]) * eff * effect_mult, fresh, q)
		if fresh < 1.0 and not day in _mods.tired_days:
			_mods.tired_days.append(day)
		day_load += Training.session_load(a, s) * load_mult
		extra_recovery += float(s.get("recovery", 0))
		_sessions += 1
		trained = true
		if not is_race:
			done.append(s.id)
	if not trained:
		keep -= Training.REST_DAY_EXTRA
	if school != null:
		var life: float = school.life_load(Game.add_days(monday, day), done, mental(day))
		if life != 0.0:
			keep += SchoolSystem.keep_shift(life)
	_load += day_load
	a.fatigue = clampf(a.fatigue * keep + day_load - extra_recovery, 0.0, 100.0)
	_fatigue_peak = maxf(_fatigue_peak, a.fatigue)
	_fatigue_sum += a.fatigue
	var record := {"day": day, "sessions": done, "intensity": level, "race": meet.get("key", "") if is_race else "",
			"load": day_load, "fatigue": a.fatigue}
	var m := mental(day)   # (session L3b1: a mental session takes no training place and adds no load; MindSystem reads it on Sunday)
	if m != "":
		record.mental = m
	played.append(record)
	day += 1
	day_started = false
	return record
