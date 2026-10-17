class_name SchoolCalendar
## The Finnish school calendar (GDD 4.9.3, session S1): every date of a school year in a town is a school day, a weekend or
## a holiday (a break, a public holiday or the summer). The real 2026-27 year comes from data/school.json `verified`
## (the town's own dates in `municipal` when it published them); later years and the other towns from `rules`, and such a
## year is marked `estimated`. Static and cached per town and school year; no dice.
## A school year Y runs from the first school day in August of Y to the first Saturday of June of Y + 1; 1 Aug - 31 Jul is
## its range (the summer at both ends counts as summer holiday).

static var _cache := {}   # "town|year" -> the year's dictionary (see year_for)


## The school year a date belongs to: the year of the August it follows (2027-03-01 -> 2026).
static func year_of(d: Dictionary) -> int:
	return int(d.year) if int(d.month) >= 8 else int(d.year) - 1


## What kind of day `d` is in `town`: {kind: "school" / "weekend" / "holiday" / "summer", break (the break's id or "":
## autumn / christmas / winter / easter / public / summer), year (the school year), estimated (the year comes from the rules)}.
static func day(town: String, d: Dictionary) -> Dictionary:
	var y := year_for(town, year_of(d))
	var key := Calendar.date_key(d)
	var weekend := Calendar.weekday(d) >= 5
	var info := {"kind": "school", "break": "", "year": int(y.year), "estimated": bool(y.estimated)}
	if key < int(y.start_key) or key > int(y.end_key):
		info.kind = "weekend" if weekend else "summer"
		info["break"] = "summer"
		return info
	var b: String = y.free.get(key, "")
	if weekend:
		info.kind = "weekend"
		info["break"] = b
	elif b != "":
		info.kind = "holiday"
		info["break"] = b
	return info


## True on a school day (a weekday of the term that is not a holiday).
static func is_school_day(town: String, d: Dictionary) -> bool:
	return day(town, d).kind == "school"


## The school year Y in `town`: {year, town, estimated, start, end (dates), start_key, end_key, free (date key -> break id for
## every free day inside the term, weekends of the breaks included), breaks [{id, from, to}], christmas_card (the last school
## day before the Christmas break), terms {autumn: [from, to], spring: [from, to]}}.
static func year_for(town: String, year: int) -> Dictionary:
	var ck := "%s|%d" % [town, year]
	if _cache.has(ck):
		return _cache[ck]
	var y := _build(town, year)
	_cache[ck] = y
	return y


static func _build(town: String, year: int) -> Dictionary:
	var sc: Dictionary = Data.school
	var rules: Dictionary = sc.rules
	var real_year := int(str(sc.verified.school_year).split("-")[0])
	var mun := _municipal(town)
	var real := year == real_year
	var estimated := not real or mun.is_empty()
	var start: Dictionary
	var christmas: Array
	var autumn: Array
	var winter: Array
	# School start: the town's own day in the real year, else the Wednesday of ISO week 33.
	if real and not mun.is_empty():
		start = Calendar.parse_date(str(mun.start))
	else:
		start = Game.add_days(iso_monday(year, 33), 2)
	var end := _first_saturday_of_june(year + 1)
	# Breaks: the town's published dates in the real year; later years keep the town's published week numbers
	# (school.json rules: towns in the municipal table keep their week), others by the rules.
	if real and not mun.is_empty():
		autumn = [Calendar.parse_date(str(mun.autumn[0])), Calendar.parse_date(str(mun.autumn[1]))]
		christmas = [Calendar.parse_date(str(mun.christmas[0])), Calendar.parse_date(str(mun.christmas[1]))]
		winter = [Calendar.parse_date(str(mun.winter[0])), Calendar.parse_date(str(mun.winter[1]))]
	else:
		var aw := int(rules.autumn_break.default_week)
		var ww := winter_week(town)
		if not mun.is_empty():
			aw = iso_week(Calendar.parse_date(str(mun.autumn[0])))
			ww = iso_week(Calendar.parse_date(str(mun.winter[0])))
		var am := iso_monday(year, aw)
		autumn = [am, Game.add_days(am, 4)]
		var wm := iso_monday(year + 1, ww)
		winter = [wm, Game.add_days(wm, 4)]
		var cf := str(rules.christmas_break.from).split("-")
		var ct := str(rules.christmas_break.to).split("-")
		christmas = [{"year": year, "month": int(cf[0]), "day": int(cf[1])}, {"year": year + 1, "month": int(ct[0]), "day": int(ct[1])}]
	var easter_sunday := easter(year + 1)
	var breaks := [
		{"id": "autumn", "from": autumn[0], "to": autumn[1]},
		{"id": "christmas", "from": christmas[0], "to": christmas[1]},
		{"id": "winter", "from": winter[0], "to": winter[1]},
		{"id": "easter", "from": Game.add_days(easter_sunday, -2), "to": Game.add_days(easter_sunday, 1)},
	]
	# Public holidays inside the term (school.json rules.other_holidays): 6 Dec, 6 Jan, 1 May, Ascension Thursday + Friday.
	var ascension := Game.add_days(easter_sunday, 39)
	for d in [{"year": year, "month": 12, "day": 6}, {"year": year + 1, "month": 1, "day": 6},
			{"year": year + 1, "month": 5, "day": 1}, ascension, Game.add_days(ascension, 1)]:
		breaks.append({"id": "public", "from": d, "to": d})
	var free := {}
	for b in breaks:
		var d: Dictionary = b.from
		while Calendar.date_key(d) <= Calendar.date_key(b.to):
			if not free.has(Calendar.date_key(d)) or str(b.id) != "public":
				free[Calendar.date_key(d)] = str(b.id)
			d = Game.add_days(d, 1)
	var y := {"year": year, "town": town, "estimated": estimated, "start": start, "end": end,
			"start_key": Calendar.date_key(start), "end_key": Calendar.date_key(end), "free": free, "breaks": breaks}
	# The last school day before the Christmas break (the Christmas report card) and the two terms.
	var card := Game.add_days(christmas[0], -1)
	while _free_or_weekend(y, card) and Calendar.date_key(card) > int(y.start_key):
		card = Game.add_days(card, -1)
	y.christmas_card = card
	y.terms = {"autumn": [start, card], "spring": [Game.add_days(christmas[1], 1), end]}
	return y


static func _free_or_weekend(y: Dictionary, d: Dictionary) -> bool:
	return Calendar.weekday(d) >= 5 or y.free.has(Calendar.date_key(d))


## The school days of a range (inclusive), in order, as dates.
static func school_days(town: String, from: Dictionary, to: Dictionary) -> Array:
	var out := []
	var d := from
	while Calendar.date_key(d) <= Calendar.date_key(to):
		if is_school_day(town, d):
			out.append(d)
		d = Game.add_days(d, 1)
	return out


## The town's 2026-27 entry of data/school.json `municipal`, or {}.
static func _municipal(town: String) -> Dictionary:
	for m in Data.school.verified.municipal:
		if str(m.town) == town:
			return m
	return {}


## The ISO week of the winter break for the town's region (data/towns.json winter_groups by maakunta; "middle" when the
## town or its region is not known).
static func winter_week(town: String) -> int:
	var groups: Dictionary = Data.towns.winter_groups
	var region := str(Data.get_town(town).get("maakunta", ""))
	for g in groups:
		if groups[g] is Dictionary and groups[g].has("maakunta") and region in groups[g].maakunta:
			return int(groups[g].iso_week)
	return int(groups.middle.iso_week)


## The winter-break group id of a town (south / middle / north).
static func winter_group(town: String) -> String:
	var groups: Dictionary = Data.towns.winter_groups
	var region := str(Data.get_town(town).get("maakunta", ""))
	for g in groups:
		if groups[g] is Dictionary and groups[g].has("maakunta") and region in groups[g].maakunta:
			return str(g)
	return "middle"


# --- Date helpers -----------------------------------------------------------------------------------------------------

## The Monday of ISO week `week` of `year` (week 1 holds 4 January).
static func iso_monday(year: int, week: int) -> Dictionary:
	return Game.add_days(Calendar.monday_of({"year": year, "month": 1, "day": 4}), (week - 1) * 7)


## The ISO week number of a date.
@warning_ignore("integer_division")
static func iso_week(d: Dictionary) -> int:
	var thursday := Game.add_days(Calendar.monday_of(d), 3)
	var first := iso_monday(int(thursday.year), 1)
	return Calendar.days_between(first, Calendar.monday_of(d)) / 7 + 1


static func _first_saturday_of_june(year: int) -> Dictionary:
	var d := {"year": year, "month": 6, "day": 1}
	while Calendar.weekday(d) != 5:
		d = Game.add_days(d, 1)
	return d


## Easter Sunday of a year (the Gregorian computus, "anonymous" algorithm).
@warning_ignore("integer_division")
static func easter(year: int) -> Dictionary:
	var a := year % 19
	var b := year / 100
	var c := year % 100
	var d := b / 4
	var e := b % 4
	var f := (b + 8) / 25
	var g := (b - f + 1) / 3
	var h := (19 * a + b - d - g + 15) % 30
	var i := c / 4
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var m := (a + 11 * h + 22 * l) / 451
	var month := (h + l - 7 * m + 114) / 31
	var day_of := ((h + l - 7 * m + 114) % 31) + 1
	return {"year": year, "month": month, "day": day_of}
