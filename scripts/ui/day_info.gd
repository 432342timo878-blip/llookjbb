class_name DayInfo
extends RefCounted
## What the UI needs to know about one day of the current week (week strip, day editor, Today card, Report).
## Pure reading: it never changes the game. Day changes go through Game.current_week() (see WeekSim).

const WHO := {"player": "you", "coach": "your coach", "injury": "an injury restriction"}


## Day `d` (0 = Mon) of week `w`:
## {day, date, played, today, editable, race (meet or {}), sessions (ids), intensity (id), load,
##  fatigue (after the day; -1 until it is played), changed, by ({"sessions": who, "intensity": who}), events,
##  and the health side (empty with the health model off): sore (highest soreness level 0–3 that day: for a played
##  day from the day log, for today now), sore_areas ([{id, name, level}]), health (injury ids active that day:
##  the day log for a played day, today's now), limited (the day was changed by an injury), tier (the worst
##  tier of the problems that touch the day, "" for none)}
static func of(w: WeekSim, d: int) -> Dictionary:
	var date := Game.add_days(w.monday, d)
	var played := d < w.day
	var info := {
		"day": d, "date": date, "played": played, "today": Calendar.date_key(date) == Calendar.date_key(Game.date),
		"editable": w.can_change(d), "race": {}, "sessions": [], "intensity": WeekSim.NORMAL, "load": 0.0,
		"fatigue": -1.0, "changed": w.changes.has(d), "by": w.changed_by(d), "events": [],
		"sore": 0, "sore_areas": [], "health": [], "limited": false, "tier": "",
	}
	info.limited = info.by.values().has("injury")
	_add_health(info, log_entry(date) if played else {})
	if played:
		var rec := _record(w, d)
		var entry := log_entry(date)
		if rec.is_empty() and not entry.is_empty():
			rec = entry
		if not rec.is_empty():
			info.sessions = rec.sessions
			info.intensity = rec.intensity
			info.load = float(rec.load)
			info.fatigue = float(rec.fatigue)
			if rec.race != "":
				info.race = Calendar.get_meet(rec.race)
		info.events = events_of(entry)
	elif w.is_race_day(d):
		info.race = w.races[d]
	else:
		info.sessions = w.session_ids(d)
		info.intensity = w.intensity(d)
		info.load = planned_load(info.sessions, info.intensity, month_of(w))
	return info


## The health fields of a day's info (see `of`). A played day reads its day log entry, today reads the body now.
static func _add_health(info: Dictionary, entry: Dictionary) -> void:
	var h := HealthUI.system()
	if h == null:
		return
	if info.played:
		var levels: Dictionary = entry.get("soreness", {})
		for id in levels:
			info.sore_areas.append({"id": id, "name": HealthUI.area_name(id), "level": int(levels[id])})
		info.health = entry.get("health", []).duplicate()
	elif info.today:
		for x in HealthUI.sore_areas():
			info.sore_areas.append({"id": x.id, "name": x.name, "level": int(x.level)})
		info.health = h.active().map(func(x): return x.id)
	for x in info.sore_areas:
		info.sore = maxi(info.sore, int(x.level))
	info.tier = HealthUI.worst_tier(info.health)
	if info.limited and info.tier == "":   # a coming day with limits: the problems that exist now
		info.tier = HealthUI.worst_tier(h.active().map(func(x): return x.id))


## The month most of the week is in (what the training model uses for the whole week).
static func month_of(w: WeekSim) -> int:
	return Game.add_days(w.monday, 3).month


static func _record(w: WeekSim, d: int) -> Dictionary:
	for r in w.played:
		if int(r.day) == d:
			return r
	return {}


## The day log entry of a date, or {}.
static func log_entry(date: Dictionary) -> Dictionary:
	var key := Calendar.date_key(date)
	for e in Game.day_log:
		if Calendar.date_key(e.date) == key:
			return e
	return {}


## The events a day log entry refers to (dictionaries from Game.events).
static func events_of(entry: Dictionary) -> Array:
	var list := []
	for id in entry.get("events", []):
		for e in Game.events:
			if e.id == id:
				list.append(e)
	return list


## Fatigue the day's sessions add: as the engine counts it (sessions that aren't possible are skipped).
static func planned_load(ids: Array, level: String, month: int) -> float:
	var mult := float(Training.intensity(level).load)
	var total := 0.0
	for id in ids:
		var s := Data.get_session(id)
		if not s.is_empty() and Training.effectiveness(Game.athlete, s, month) > 0.0:
			total += Training.session_load(Game.athlete, s) * mult
	return total


static func session_names(ids: Array) -> Array:
	var names := []
	for id in ids:
		names.append(Data.get_session(id).get("name", id))
	return names


static func intensity_name(level: String) -> String:
	return Training.intensity(level).name


static func intensity_color(level: String) -> Color:
	match level:
		"easy": return Palette.DAY_EASY
		"hard": return Palette.DAY_HARD
	return Palette.DAY_NORMAL


## "Mon 2 Nov" (no year).
static func short_day(date: Dictionary) -> String:
	return "%s %d %s" % [Training.DAY_NAMES[Calendar.weekday(date)], date.day, Calendar.MONTHS_SHORT[int(date.month) - 1]]


## "Changed by you", or one part per line when sessions and intensity were changed by different people.
static func changed_text(info: Dictionary) -> String:
	var by: Dictionary = info.by
	if by.is_empty():
		return ""
	var who_set := {}
	for part in by:
		who_set[by[part]] = true
	if who_set.size() == 1:
		return "Changed by %s" % WHO.get(by.values()[0], by.values()[0])
	var parts := []
	for part in by:
		parts.append("%s changed by %s" % [part.capitalize(), WHO.get(by[part], by[part])])
	return " · ".join(parts)


## Why a session can't be done this month ("only Dec–Mar"), or "" when it can.
static func unavailable_text(s: Dictionary) -> String:
	if Training.is_available(s, Game.add_days(Game.current_week().monday, 3).month):
		return ""
	var months: Array = s.get("months", [])
	var contiguous := not months.is_empty()
	for i in range(1, months.size()):
		if int(months[i]) != int(months[i - 1]) % 12 + 1:
			contiguous = false
	var names := []
	for m in months:
		names.append(Calendar.MONTHS_SHORT[int(m) - 1])
	if contiguous and names.size() > 1:
		return "only %s–%s" % [names[0], names[-1]]
	return "only " + ", ".join(names)


## "2nd, 2:31.40" for each round the athlete ran at a meet (joined with "; "), or "".
static func race_result_text(meet_key: String) -> String:
	var parts := []
	for r in Game.athlete.results:
		if r.meet_key == meet_key:
			var text: String = Race.result_text(r, ", ")
			if r.round != "Race":
				text = "%s: %s" % [r.round, text]
			parts.append(text + (" (PB)" if r.pb else ""))
	return "; ".join(parts)


## The next entered race after today (today's own race is shown separately), or {}.
static func next_race_after_today() -> Dictionary:
	for m in Calendar.meets_between(Game.add_days(Game.date, 1), Game.add_days(Game.date, 400)):
		if m.key in Game.entries:
			return m
	return {}


## "today" / "tomorrow" / "in 5 days"
static func days_away(date: Dictionary) -> String:
	var n := Calendar.days_between(Game.date, date)
	if n <= 0:
		return "today"
	return "tomorrow" if n == 1 else "in %d days" % n
