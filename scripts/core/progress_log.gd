class_name ProgressLog
extends RefCounted
## The monthly record of the athlete (playtest fix 7, 2026-10-10): at the start of the career and at the end of every month
## a snapshot of all attributes, the 800 m ability, the personal best and the season best. Kept in Game.progress and saved
## with the career (older saves get their first record when they are loaded). The Progress page shows it; step 7 (the
## multi-year check) and the future Statistics tab read it. Nothing here touches the game: it only reads the athlete.
##
## A record: {year, month, day (the date it was taken), kind ("start" / "month" / "first" for an older save),
## attrs {id: value}, ability, pb, sb, age}. Race results are not stored here: they are in Athlete.results.


## A snapshot of `a` on `date`.
static func snapshot(a: Athlete, date: Dictionary, kind: String) -> Dictionary:
	var attrs := {}
	for id in a.attributes:
		attrs[id] = snappedf(float(a.attributes[id]), 0.001)
	return {"year": int(date.year), "month": int(date.month), "day": int(date.day), "kind": kind, "attrs": attrs,
			"ability": snappedf(RacePerformance.ability(a), 0.001), "pb": float(a.personal_bests.get(a.main_event, 0.0)),
			"sb": Rankings.player_season_best(a, int(date.year)), "age": a.age_on(date)}


## Puts a record in the list: a month's record replaces an earlier one of the same month (a reloaded day), other kinds are added.
static func add(list: Array, rec: Dictionary) -> void:
	for i in list.size():
		if list[i].kind == rec.kind and rec.kind == "month" and int(list[i].year) == int(rec.year) and int(list[i].month) == int(rec.month):
			list[i] = rec
			return
	list.append(rec)


## After loading a save: numbers back to ints where they must be.
static func fixed(list: Array) -> Array:
	for rec in list:
		for k in ["year", "month", "day", "age"]:
			rec[k] = int(rec[k])
	return list


## The races of one month: {count, best (seconds, 0 = none)}; races without a time don't count.
static func month_races(a: Athlete, year: int, month: int) -> Dictionary:
	var count := 0
	var best := 0.0
	for r in a.results:
		var d := Game.int_date(r.date)
		if d.year != year or d.month != month or r.event != a.main_event:
			continue
		count += 1
		if r.get("status", "") == "" and float(r.time) > 0.0 and (best == 0.0 or float(r.time) < best):
			best = float(r.time)
	return {"count": count, "best": best}


## What the Progress page shows, newest first: the live state ("Now") then every record. Each row:
## {title, rec (the record), prev (the record before it, or {}), races {count, best}, now (bool)}.
static func rows(a: Athlete, list: Array, today: Dictionary) -> Array:
	var out := []
	var recs := list.duplicate()
	recs.sort_custom(func(x, y): return _key(x) < _key(y))
	var live := snapshot(a, today, "now")
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	out.append({"title": "Now · %s" % Calendar.format_day(today), "rec": live, "prev": recs[-1] if not recs.is_empty() else {},
			"races": month_races(a, int(today.year), int(today.month)), "now": true})
	for i in range(recs.size() - 1, -1, -1):
		var rec: Dictionary = recs[i]
		var title: String
		match str(rec.kind):
			"start": title = "Start · %s" % Calendar.format_day(rec)
			"first": title = "First record · %s" % Calendar.format_day(rec)
			_: title = "End of %s %d" % [months[int(rec.month) - 1], int(rec.year)]
		out.append({"title": title, "rec": rec, "prev": recs[i - 1] if i > 0 else {},
				"races": month_races(a, int(rec.year), int(rec.month)) if str(rec.kind) == "month" else {"count": 0, "best": 0.0},
				"now": false})
	return out


static func _key(rec: Dictionary) -> int:
	return int(rec.year) * 10000 + int(rec.month) * 100 + int(rec.day)


## The biggest changes of attributes between two records: [[id, change]] by size, only changes of at least 0.05.
static func changes(from_rec: Dictionary, to_rec: Dictionary, limit := 99) -> Array:
	var out := []
	if from_rec.is_empty():
		return out
	for id in to_rec.attrs:
		var d := float(to_rec.attrs[id]) - float(from_rec.attrs.get(id, to_rec.attrs[id]))
		if absf(d) >= 0.05:
			out.append([id, d])
	out.sort_custom(func(x, y): return absf(x[1]) > absf(y[1]))
	return out.slice(0, limit)
