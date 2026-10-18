class_name Cast
extends RefCounted
## The people around the athlete (GDD 4.9.5, session P1): the family, the friends, the close training partners, the school's
## staff and the rivals who become people, and the yearly calendar of Finnish teenage life the moments read (vappu, juhannus,
## Christmas, the school year, the confirmation camp). Static helpers only; StoryletSystem keeps the people (its `people`,
## saved with the career) and calls these to make them. Every number and word is in data/cast.json. Everyone is fictional.
## The dice come from the athlete's name and birth date, so the same career always gets the same people, and the global dice
## (rivals, races) are never touched.


static func cfg() -> Dictionary:
	return Data.cast


static func _rng(a: Athlete, what: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var b := a.birth_date
	rng.seed = ("cast|%s|%s|%d-%d-%d" % [what, a.full_name(), int(b.get("year", 0)), int(b.get("month", 0)), int(b.get("day", 0))]).hash()
	return rng


## The family's attitude for a creation answer of the family question ("" = an older save: the default).
static func attitude_for(family_answer: String) -> String:
	for id in cfg().attitudes:
		if family_answer in cfg().attitudes[id].from:
			return str(id)
	return str(cfg().family.default)


static func attitude_word(attitude: String) -> String:
	return str(cfg().attitudes.get(attitude, {}).get("word", ""))


## The family and the friends of a new career: [person, ...] (the person format of StoryletSystem.people plus gender,
## birth_year, word, trait, call). `info` = {origin, old_sport, family} (the creation answers).
static func make(a: Athlete, info: Dictionary) -> Array:
	var c := cfg()
	var rng := _rng(a, "people")
	var used := {a.full_name(): true}
	var out := []
	var by := int(a.birth_date.get("year", 2012))
	var attitude := attitude_for(str(info.get("family", "")))
	# Parents: two at home in most careers (a mum and a dad), else one.
	var fam: Dictionary = c.family
	var genders := ["female", "male"] if rng.randf() < float(fam.two_parents) else (["female"] if rng.randf() < 0.5 else ["male"])
	var athlete_parent := rng.randi_range(0, genders.size() - 1) if bool(c.attitudes.get(attitude, {}).get("athlete_parent", false)) else -1
	for i in genders.size():
		var g: String = genders[i]
		var first := _unique_first(rng, c.parent_names[g], a.last_name, used)
		var p := _person("fam.p%d" % (i + 1), "family", str(fam.role[g]), first, a.last_name, g,
				by - rng.randi_range(int(fam.parent_age[0]) - 14, int(fam.parent_age[1]) - 14), str(fam.word[g]))
		p.call = str(fam.call[g])
		if i == athlete_parent:
			p.athlete_parent = true
			p.word = str(fam.athlete_word)
		out.append(p)
	# An older sibling who runs (the answer "An older sibling runs").
	if str(info.get("family", "")) == str(fam.sibling.from):
		var g := "male" if rng.randf() < 0.5 else "female"
		var first := _unique_first(rng, Data.names[g], a.last_name, used)
		var sib := _person("fam.sib", "family", "sibling", first, a.last_name, g,
				by - rng.randi_range(int(fam.sibling.age_gap[0]), int(fam.sibling.age_gap[1])), str(fam.sibling.word))
		sib.event = _weighted(rng, fam.sibling.events)
		out.append(sib)
	# Friends from school: the best friend (not an athlete) and 1-2 more; with a sport before athletics one is from the old team.
	var fr: Dictionary = c.friends
	var best_g := a.gender if rng.randf() < 0.7 else ("female" if a.gender == "male" else "male")
	var best := _person("fr.best", "friends", "best_friend", "", "", best_g, by, str(fr.best_word))
	_name(best, rng, used)
	best.trait = _weighted(rng, fr.best_traits)
	out.append(best)
	var n := rng.randi_range(int(fr.others[0]), int(fr.others[1]))
	var old_sport := str(info.get("old_sport", ""))
	for i in n:
		var g := a.gender if rng.randf() < 0.6 else ("female" if a.gender == "male" else "male")
		var f := _person("fr.f%d" % (i + 1), "friends", "friend", "", "", g, by, str(fr.word))
		_name(f, rng, used)
		f.trait = "old_team" if i == 0 and old_sport != "" and rng.randf() < float(fr.old_team_share) else _weighted(rng, fr.traits)
		out.append(f)
	return out


## The staff of a school stage: `kind` "comprehensive" (grades 8-9) or "secondary"; `key` names the school (ids sch.<key>.<role>).
static func make_school(a: Athlete, key: String, kind: String, origin: String) -> Array:
	var c: Dictionary = cfg().school
	var rng := _rng(a, "school|" + key)
	var used := {a.full_name(): true}
	var out := []
	for s in c.get(kind, c.comprehensive):
		var g := "female" if rng.randf() < 0.6 else "male"
		var first := _unique_first(rng, cfg().parent_names[g], "", used)
		var last: String = Data.names.surnames[rng.randi_range(0, Data.names.surnames.size() - 1)]
		var word := str(s.word)
		if str(s.role) == "pe_teacher" and kind == "comprehensive" and origin == "pe_teacher":
			word = str(c.spotted_word)
		var p := _person("sch.%s.%s" % [key, s.role], "school", str(s.role), first, last, g,
				int(Game.date.get("year", 2026)) - rng.randi_range(int(c.age[0]), int(c.age[1])), word)
		if word == str(c.spotted_word):
			p.spotted = true
		out.append(p)
	return out


## The close training partners among a coach's training group (C1's teammates): the person ids, one of each role in the order
## of `prefer` first (different people: the racer, the joker, the veteran...), then the rest of the group in order.
static func pick_partners(coach_id: String, group: Array) -> Array:
	var cp: Dictionary = cfg().partners
	var out := []
	for role in cp.prefer:
		for t in group:
			var pid := "%s.%s" % [coach_id, t.id]
			if str(t.role) == str(role) and not pid in out:
				out.append(pid)
				break
	for t in group:
		var pid := "%s.%s" % [coach_id, t.id]
		if not pid in out:
			out.append(pid)
	return out.slice(0, int(cp.count))


## The starting relationship of a role (data/cast.json relation_start; else moments.json relation.start).
static func relation_start(role: String) -> float:
	return float(cfg().relation_start.get(role, Data.moments.relation.start))


## A relationship 0-100 in a word ("Close", "Good", "Fine", "Cool", "Strained").
static func relation_word(v: float) -> String:
	for w in cfg().relation_words:
		if v < float(w[0]):
			return str(w[1])
	return str(cfg().relation_words.back()[1])


static func _person(pid: String, thread: String, role: String, first: String, last: String, gender: String, birth_year: int, word: String) -> Dictionary:
	return {"id": pid, "thread": thread, "role": role, "first_name": first, "last_name": last, "gender": gender,
			"birth_year": birth_year, "word": word, "relation": relation_start(role), "active": true, "memory": {}}


static func _name(p: Dictionary, rng: RandomNumberGenerator, used: Dictionary) -> void:
	for _try in 30:
		var first := str(Data.names[p.gender][rng.randi_range(0, Data.names[p.gender].size() - 1)])
		var last := str(Data.names.surnames[rng.randi_range(0, Data.names.surnames.size() - 1)])
		if not used.has(first) and not used.has(first + " " + last):
			p.first_name = first
			p.last_name = last
			used[first] = true
			used[first + " " + last] = true
			return
	p.first_name = str(Data.names[p.gender][0])
	p.last_name = str(Data.names.surnames[0])


static func _unique_first(rng: RandomNumberGenerator, names: Array, last: String, used: Dictionary) -> String:
	var first := ""
	for _try in 30:
		first = str(names[rng.randi_range(0, names.size() - 1)])
		if not used.has(first):
			break
	used[first] = true
	used[first + " " + last] = true
	return first


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var x := rng.randf() * total
	for k in weights:
		x -= float(weights[k])
		if x < 0.0:
			return str(k)
	return str(weights.keys().back())


# --- The yearly calendar (data/cast.json life) -----------------------------------------------------------------

## The date of `event` in calendar year `year` ({} when it has none that year). `flags` = the moments' flags (the camp).
static func occurrence(event: String, year: int, flags := {}) -> Dictionary:
	var e: Dictionary = cfg().life.get(event, {})
	match str(e.get("kind", "")):
		"fixed":
			return {"year": year, "month": int(e.month), "day": int(e.day)}
		"juhannus":
			var d := {"year": year, "month": 6, "day": 19}
			while Calendar.weekday(d) != 4:
				d = Game.add_days(d, 1)
			return d
		"easter":
			return SchoolCalendar.easter(year)
		"school_start":
			return SchoolCalendar.year_for(_town(), year).start
		"school_end":
			return SchoolCalendar.year_for(_town(), year - 1).end
		"birthday":
			var b := Game.athlete.birth_date if Game.athlete != null else {}
			if b.is_empty():
				return {}
			return {"year": year, "month": int(b.month), "day": mini(int(b.day), 28) if int(b.month) == 2 else int(b.day)}
		"meet":
			var m := Calendar.get_meet("%s@%d" % [str(e.id), year])
			if m.is_empty():
				return {}
			return m.date if m.date is Dictionary else Calendar.parse_date(str(m.date))
		"rippileiri":
			if Game.athlete == null or year != int(Game.athlete.birth_date.get("year", 0)) + int(e.turns):
				return {}
			for flag in e.camps:
				if flags.has(flag):
					return nth_monday(year, int(e.camps[flag].month), int(e.camps[flag].nth))
	return {}


## Days from `date` to the next `event` (0 = today); a big number when there is none within a year.
static func days_to(event: String, date: Dictionary, flags := {}) -> int:
	for y in [int(date.year), int(date.year) + 1]:
		var d := occurrence(event, y, flags)
		if not d.is_empty():
			var n := Calendar.days_between(date, d)
			if n >= 0:
				return n
	return 100000


## Days since the last `event` up to `date` (0 = today); a big number when there is none within a year.
static func days_after(event: String, date: Dictionary, flags := {}) -> int:
	for y in [int(date.year), int(date.year) - 1]:
		var d := occurrence(event, y, flags)
		if not d.is_empty():
			var n := Calendar.days_between(d, date)
			if n >= 0:
				return n
	return 100000


static func nth_monday(year: int, month: int, nth: int) -> Dictionary:
	var d := {"year": year, "month": month, "day": 1}
	while Calendar.weekday(d) != 0:
		d = Game.add_days(d, 1)
	return Game.add_days(d, (nth - 1) * 7)


static func _town() -> String:
	var ss := SchoolSystem.sys()
	if ss != null:
		return ss.town()
	return Game.athlete.hometown if Game.athlete != null else ""
