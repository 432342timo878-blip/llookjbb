class_name Calendar
## Competition calendar: builds dated meets from data/competitions.json, and answers who can enter what.
## The data describes the first season; later seasons repeat it 52 weeks later (same weekday) as estimates.

const SEASONS_AHEAD := 2   # how many repeated seasons to generate after the first


## All meets between two dates (inclusive), sorted by date. Each meet is a Dictionary with the data fields plus
## "key" (unique per year, used for entries), "date" (date dict) and "estimated".
static func meets_between(from: Dictionary, to: Dictionary) -> Array:
	var result := []
	var lo := date_key(from)
	var hi := date_key(to)
	for m in _all_meets():
		var k := date_key(m.date)
		if k >= lo and k <= hi:
			result.append(m)
	return result


static func get_meet(key: String) -> Dictionary:
	for m in _all_meets():
		if m.key == key:
			return m
	return {}


## "M15" / "N14" etc. for the competition year.
static func age_class(a: Athlete, year: int) -> String:
	return "%s%d" % ["M" if a.gender == "male" else "N", year - int(a.birth_date.year)]


## {"ok": bool, "reason": String}. Whether the athlete can enter the meet in their main event.
static func can_enter(a: Athlete, meet: Dictionary, today: Dictionary) -> Dictionary:
	if meet.get("watch", false):
		return {"ok": false, "reason": "Senior event: you're following this one from home."}
	if date_key(meet.date) < date_key(today):
		return {"ok": false, "reason": "Already over."}
	var age: int = meet.date.year - int(a.birth_date.year)
	if age < int(meet.ages[0]) or age > int(meet.ages[1]):
		return {"ok": false, "reason": "Not for your age class (%s)." % age_class(a, meet.date.year)}
	if not a.main_event in meet.events:
		return {"ok": false, "reason": "Your event isn't on the programme (coming in a later version)."}
	return {"ok": true, "reason": ""}


## Text about the qualifying standard for this meet, or "" if there is none.
static func standard_text(a: Athlete, meet: Dictionary) -> String:
	if not meet.has("standard"):
		return ""
	var limits: Dictionary = Data.competitions.standards[meet.standard].get(a.main_event, {})
	var cls := age_class(a, meet.date.year)
	if not limits.has(cls):
		return ""
	var limit: float = limits[cls]
	var pb: float = a.personal_bests.get(a.main_event, 0.0)
	var text := "Qualifying time for %s: %s." % [cls, format_time(limit)]
	if pb > 0.0 and pb <= limit:
		return text + " You have it (PB %s)." % format_time(pb)
	return text + " Not reached yet, but you may enter one event without it."


static func coach_recommends(a: Athlete, meet: Dictionary, today: Dictionary) -> bool:
	return meet.get("coach", false) and can_enter(a, meet, today).ok


## Display name of the place: real town, your club's town, or your district.
static func place(a: Athlete, meet: Dictionary) -> String:
	var city: String = meet.get("city", "")
	match city:
		"@club": city = Data.get_club(a.club_id).get("city", a.hometown)
		"@district": city = "Your district"
	if meet.has("venue"):
		return "%s, %s" % [meet.venue, city]
	return city


## Entered meets that fall within the week starting `monday`: day index (0–6) -> meet.
static func races_in_week(entries: Array, monday: Dictionary) -> Dictionary:
	var races := {}
	for m in meets_between(monday, Game.add_days(monday, 6)):
		if m.key in entries:
			races[days_between(monday, m.date)] = m
	return races


# --- Dates ---------------------------------------------------------------------------------

static func parse_date(s: String) -> Dictionary:
	var p := s.split("-")
	return {"year": int(p[0]), "month": int(p[1]), "day": int(p[2])}


## Sortable integer, e.g. 20270213.
static func date_key(d: Dictionary) -> int:
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


static func days_between(a: Dictionary, b: Dictionary) -> int:
	var ta := Time.get_unix_time_from_datetime_dict({"year": a.year, "month": a.month, "day": a.day, "hour": 12})
	var tb := Time.get_unix_time_from_datetime_dict({"year": b.year, "month": b.month, "day": b.day, "hour": 12})
	return roundi((tb - ta) / 86400.0)


## "Sat 13.2." or "Fri 6.–8.8." for multi-day meets.
static func format_meet_date(meet: Dictionary) -> String:
	var d: Dictionary = meet.date
	var t := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12})
	var wd: int = Time.get_datetime_dict_from_unix_time(t).weekday   # 0 = Sunday
	var day_name: String = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][wd]
	var days: int = meet.get("days", 1)
	if days <= 1:
		return "%s %d.%d." % [day_name, d.day, d.month]
	var end := Game.add_days(d, days - 1)
	if end.month == d.month:
		return "%s %d.–%d.%d." % [day_name, d.day, end.day, d.month]
	return "%s %d.%d.–%d.%d." % [day_name, d.day, d.month, end.day, end.month]


## 141.0 -> "2:21.00"
static func format_time(seconds: float) -> String:
	var m := floori(seconds / 60.0)
	var s := seconds - m * 60
	if m == 0:
		return "%.2f" % s
	return "%d:%05.2f" % [m, s]


static func _all_meets() -> Array:
	var meets := []
	for season in SEASONS_AHEAD + 1:
		for c in Data.competitions.competitions:
			var m: Dictionary = c.duplicate(true)
			m.date = Game.add_days(parse_date(c.date), 364 * season)
			m.key = "%s@%d" % [c.id, m.date.year]
			if season > 0:
				m.estimated = true
				if m.level in ["national", "international", "elite"]:
					m.city = "TBA"
					m.erase("venue")
			meets.append(m)
	meets.sort_custom(func(x, y): return date_key(x.date) < date_key(y.date))
	return meets
