class_name Standards
extends RefCounted
## The real 800 m standards (data/standards.json, GDD 4.9.2 "Season goals with times", session C5): the SM limit for the 14-15-year-olds,
## SUL's Team Finland criteria for the juniors (14-16) and the youth (17-21) and the Kalevan kisat limit. Reading only: the data
## says which table, which source and for whom; this class finds the number for an athlete in a calendar year.
## The times are those of the season the table was published for (`valid`); later years use the same table and are marked
## estimated (the limits come out again each February).


static func cfg() -> Dictionary:
	return Data.standards


static func ids() -> Array:
	return cfg().sets.keys()


static func set_of(id: String) -> Dictionary:
	return cfg().sets.get(id, {})


## The athlete's age in the calendar year `year` (the age they turn that year, as the limits count it).
static func age_in(a: Athlete, year: int) -> int:
	return year - int(a.birth_date.year)


## The table of a set: key ("M15" / "M14-15" / "M") -> seconds. `times_from` points into another data file.
static func times_of(set: Dictionary) -> Dictionary:
	if set.has("times"):
		return set.times
	var path := str(set.get("times_from", "")).split(".")
	if path.is_empty():
		return {}
	var node = Data.get(path[0])
	for i in range(1, path.size()):
		if node is Dictionary and node.has(path[i]):
			node = node[path[i]]
		else:
			return {}
	return node if node is Dictionary else {}


## The key of the athlete's row in the set's table for the age they turn in `year` ("" = the set is not for them).
static func key_for(set: Dictionary, a: Athlete, year: int) -> String:
	var age := age_in(a, year)
	var ages: Array = set.ages
	if age < int(ages[0]) or age > int(ages[1]):
		return ""
	var letter := "M" if a.gender == "male" else "N"
	match str(set.get("lookup", "age")):
		"gender":
			return letter
		"group":
			for g in set.groups:
				if age >= int(set.groups[g][0]) and age <= int(set.groups[g][1]):
					return letter + str(g)
			return ""
	return "%s%d" % [letter, age]


## The limit of set `id` for the athlete in `year`, in seconds; 0.0 when the athlete is not in its age range or the table has no row.
static func time(id: String, a: Athlete, year: int) -> float:
	var set := set_of(id)
	if set.is_empty():
		return 0.0
	var key := key_for(set, a, year)
	return float(times_of(set).get(key, 0.0)) if key != "" else 0.0


## A limit later than the year the table was published for is an estimate.
static func is_estimate(id: String, year: int) -> bool:
	return year > int(set_of(id).get("valid", 0))


## Every standard the athlete can reach for in `year`, easiest (slowest) first:
## [{id, kind: "standard", set, name, short, time, estimated, source}].
static func ladder(a: Athlete, year: int) -> Array:
	var out := []
	for id in ids():
		var t := time(id, a, year)
		if t <= 0.0:
			continue
		var set := set_of(id)
		out.append({"id": "std:" + id, "kind": "standard", "set": id, "name": str(set.name), "short": str(set.short), "time": t,
				"estimated": is_estimate(id, year), "source": str(set.source)})
	out.sort_custom(func(x, y): return float(x.time) > float(y.time))
	return out


## The sources' titles and addresses, for the Credits and the help ("where do these numbers come from").
static func sources() -> Array:
	var out := []
	var s: Dictionary = cfg().sources
	for id in s:
		out.append({"id": id, "title": str(s[id].title), "url": str(s[id].url)})
	return out
