class_name CoachMarket
extends GameSystem
## The coach market (GDD 4.9.1 "Who you can get, and when", "Shown and scouted"; 4.9.2 "A coach can end it"; session C6).
## Every number and text is in data/market.json (its note explains them).
##
## THE POOL: the coaches around a career are made once, from their own dice (the athlete's name and birth date: the same
## career always gets the same coaches; the global dice are never touched): the other coaches of the athlete's club (by the
## size of its town), the clubs of the same town, coaches of the region (the same maakunta), national coaches in the centre
## towns, remote coaches, a parent (only with the family answer "A parent competed in athletics") and the real coaches of
## data/coaching.json `real`. They are CoachSystem records (fictional ids mk_1, mk_2 ...; real ones keep their ids) with a
## `market` part {section, tier, group_size, group_level}.
## WHO YOU CAN GET: visible(c) (age, the TF-juniorit standard, the centre town, world level) and status(c) (your coach, his
## place this season, the time he wants, your budget, an offer). The player asks (ask), then starts on the next Monday
## (start: the old coach's goodbye, the group; the change itself on Sunday night). SCOUTING: range(c, attr) = the shown
## range, narrowed by look_results / ask_around / a visit (plan_visit: that day's sessions change) and by weeks together.
## OFFERS after a breakthrough; THE ENDING CHAIN (6 + 4 + 4 weeks of Strained trust, two warnings, then the athlete picks).
## Switch for the tools: `enabled` (default OFF; only main.gd switches it on, like the coach's proposals): off = no offers,
## no ending chain, no stops, no pending switch, and the pool is made only when something asks for it.

static var enabled := false

const SECTIONS := ["club", "parent", "town", "region", "academy", "national", "remote", "elite"]

var made := false            # the pool has been made
var scout := {}              # coach id -> {width: {attr: points}, asked, visited, results}
var spots := {}              # coach id -> {year, n}: his places this season (fictional coaches; drawn every season)
var pending := {}            # {coach, date (the Monday), why ("player" / "offer" / "ended")}: the next head coach
var visit := {}              # {coach, date, far, done}: the planned visit to a session
var offers := {}             # coach id -> {until (day number), why ("pb" / "seen")}
var declined := {}           # coach id -> season year: "Not now" to an offer
var answers := {}            # coach id -> {day, status}: the last answer to "Ask to be coached"
var ended := {}              # coach id -> day number: he ended the coaching
var history := []            # [{coach, from, to (date or {})}]: the athlete's coaches
var chain := {}              # the ending chain: {weeks (Strained in a row), stage 0-3, at (weeks at the last warning)}
var seen_pb := 0.0           # the 800 m best the market has already reacted to
var seen_tf := false         # the TF-juniorit standard is reached: the camp coaches have seen the athlete
var last_offer_day := -9999
var offers_by_season := {}   # season year -> offers made
var _next := 1


func _init() -> void:
	id = "market"


func cfg() -> Dictionary:
	return Data.market


static func sys() -> CoachMarket:
	return Game.get_system("market") as CoachMarket


func _cs() -> CoachSystem:
	return Game.get_system("coach") as CoachSystem


static func today_no() -> int:
	return StoryletSystem.day_no(Game.date)


## The training season (Nov-Oct) a date belongs to, by its first year.
static func season_of(d: Dictionary) -> int:
	return int(d.year) if int(d.month) >= 11 else int(d.year) - 1


# --- The pool -------------------------------------------------------------------------------------------------------------

## Makes the coaches around the career once (their own dice). Safe to call any time.
func ensure_pool() -> void:
	if made or Game.athlete == null:
		return
	var cs := _cs()
	if cs == null:
		return
	made = true
	var a := Game.athlete
	var p: Dictionary = cfg().pool
	var rng := RandomNumberGenerator.new()
	var b := a.birth_date
	rng.seed = ("market|%s|%d-%d-%d" % [a.full_name(), int(b.get("year", 0)), int(b.get("month", 0)), int(b.get("day", 0))]).hash()
	var home := CoachSystem.home_town(a)
	var size := Data.town_size(home)
	var town := Data.get_town(home)
	var centre := town.get("centre") != null
	# Your own club: the head coach is one of them.
	var n := _roll(rng, p.own_club.get(size, [1, 1])) + (_roll(rng, p.centre_extra) if centre else 0)
	var head := cs.head()
	if str(head.get("kind", "")) == "club" and str(head.get("facts", {}).get("club_id", "")) == a.club_id:
		n -= 1
		head.market = {"section": "club", "tier": "club", "group_size": head.get("group", []).size(), "group_level": -1.0}
	for i in maxi(n, 0):
		_add(_make(rng, "club", "club", home, a.club_id))
	# The other clubs of the town.
	for club in Data.clubs:
		if str(club.city) == home and str(club.id) != a.club_id:
			for i in _roll(rng, p.other_club.get(size, [1, 1])):
				_add(_make(rng, "club", "town", home, str(club.id)))
	# The region (the same maakunta), weighted by population.
	var region := {}
	for t in Data.towns.towns:
		if str(t.maakunta) == str(town.get("maakunta", "")):
			region[str(t.name)] = float(t.population)
	if region.is_empty():
		region[home] = 1.0
	for i in _roll(rng, p.region):
		var t := CoachSystem._weighted(rng, region)
		_add(_make(rng, "regional", "region", t, _club_in(rng, t)))
	# National coaches in the centre towns.
	for i in _roll(rng, p.national):
		var t := str(p.national_towns[rng.randi_range(0, p.national_towns.size() - 1)])
		_add(_make(rng, "national", "national", t, _club_in(rng, t)))
	# Remote coaches (always far: towns outside the region).
	var far := (p.remote_towns as Array).filter(func(x): return not region.has(str(x)))
	if far.is_empty():
		far = p.remote_towns
	for i in _roll(rng, p.remote):
		var t := str(far[rng.randi_range(0, far.size() - 1)])
		_add(_make(rng, "remote", "remote", t, _club_in(rng, t)))
	# A parent who competed in athletics.
	if a.family == str(cfg().parent.family):
		_add(_make_parent(rng, a, home))
	# The real coaches (copies of the data records; facts only from their sources).
	for r in Data.coaching.real:
		if not cs.coaches.has(str(r.id)):
			var c: Dictionary = r.duplicate(true)
			c.market = {"section": "", "tier": "real", "group_size": 0, "group_level": -1.0}
			cs.coaches[str(c.id)] = c
	seen_pb = float(a.personal_bests.get("800m", 0.0))
	if history.is_empty() and not head.is_empty():
		history.append({"coach": str(head.id), "from": cs.relation().get("since", Game.START_DATE).duplicate(), "to": {}})


func _add(c: Dictionary) -> void:
	_cs().coaches[str(c.id)] = c


static func _roll(rng: RandomNumberGenerator, r: Array) -> int:
	return rng.randi_range(int(r[0]), int(r[1]))


## A club of a town (its id), or "" when the town has none in data/clubs.json.
static func _club_in(rng: RandomNumberGenerator, town: String) -> String:
	var list := Data.clubs.filter(func(c): return str(c.city) == town)
	if list.is_empty():
		return ""
	return str(list[rng.randi_range(0, list.size() - 1)].id)


## A fictional coach of a tier (data/market.json tiers; "club" uses the club-coach generator of data/coaching.json with
## the town's shift).
func _make(rng: RandomNumberGenerator, tier: String, section: String, town: String, club_id: String) -> Dictionary:
	var t: Dictionary = cfg().tiers[tier]
	var club_cfg: Dictionary = Data.coaching.club
	var average := 0.0
	if tier == "club":
		average = clampf(rng.randfn(float(club_cfg.average_mean) + CoachSystem.town_shift(town), float(club_cfg.average_sd)),
				float(club_cfg.average_min), float(club_cfg.average_max))
	else:
		var av: Array = t.average
		average = clampf(rng.randfn(float(av[0]), float(av[1])), float(av[2]), float(av[3]))
	var voice := CoachSystem._weighted(rng, cfg().pool.voices)
	var gender := "male" if rng.randf() < float(cfg().pool.male_share) else "female"
	var c := _build(rng, average, voice, gender, {}, t.get("age", club_cfg.age))
	c.id = "mk_%d" % _next
	_next += 1
	c.kind = str(t.kind)
	c.facts.club_id = club_id
	c.facts.town = town
	c.facts.reputation = str(t.reputation)
	if tier == "club":
		var club := Data.get_club(club_id)
		c.facts.town = str(club.get("city", town))
		c.facts.cost_month = rng.randi_range(roundi(float(club_cfg.cost_month[0]) / 5.0), roundi(float(club_cfg.cost_month[1]) / 5.0)) * 5
		c.facts.open = true
		c.facts.spots = 0
		c.facts.min_level = 0
	else:
		c.facts.cost_month = rng.randi_range(roundi(float(t.cost[0]) / 5.0), roundi(float(t.cost[1]) / 5.0)) * 5
		c.facts.open = false
		c.facts.spots = _roll(rng, t.spots)
		c.facts.min_level = _roll(rng, t.min_level)
	var gl := -1.0
	if int(c.facts.min_level) > 0:
		gl = float(c.facts.min_level) + rng.randf_range(0.5, 2.0)
	else:
		gl = CoachSystem.athlete_level(Game.athlete) + rng.randfn(0.0, 1.0)
	c.market = {"section": section, "tier": tier, "group_size": _roll(rng, t.group), "group_level": snappedf(gl, 0.1)}
	return c


func _make_parent(rng: RandomNumberGenerator, a: Athlete, home: String) -> Dictionary:
	var pc: Dictionary = cfg().parent
	var av: Array = pc.average
	var average := clampf(rng.randfn(float(av[0]), float(av[1])), float(av[2]), float(av[3]))
	var voice := CoachSystem._weighted(rng, pc.voices)
	var gender := "male" if rng.randf() < 0.5 else "female"
	var c := _build(rng, average, voice, gender, pc.lean, pc.age)
	c.id = "mk_%d" % _next
	_next += 1
	c.name = "%s %s" % [c.name.split(" ")[0], a.last_name]
	c.kind = "parent"
	c.facts.club_id = a.club_id
	c.facts.town = home
	c.facts.reputation = "local"
	c.facts.qualification = str(pc.qualification)
	c.facts.cost_month = 0
	c.facts.open = true
	c.facts.spots = 1
	c.facts.min_level = 0
	c.market = {"section": "parent", "tier": "parent", "group_size": 3, "group_level": snappedf(CoachSystem.athlete_level(a), 0.1)}
	return c


## The common part of a fictional coach: name, voice, attributes around `average` (the voice's lean + `lean` + his own
## spread, centred), style, demands, qualification, focus, age.
func _build(rng: RandomNumberGenerator, average: float, voice: String, gender: String, lean: Dictionary, age_range: Array) -> Dictionary:
	var club_cfg: Dictionary = Data.coaching.club
	var p: Dictionary = Data.coaching.personalities.get(voice, {})
	var focus := CoachSystem._weighted(rng, CoachSystem._weights(club_cfg.event_focus))
	var lean_f: Dictionary = club_cfg.event_focus[focus].lean
	var lean_p: Dictionary = p.get("lean", {})
	var raw := {}
	var sum := 0.0
	for at in Data.coaching.attributes:
		var v := float(lean_p.get(at.id, 0)) + float(lean_f.get(at.id, 0)) + float(lean.get(at.id, 0)) + rng.randfn(0.0, float(club_cfg.spread_sd))
		raw[at.id] = v
		sum += v
	var mean_raw := sum / raw.size()
	var attrs := {}
	for at_id in raw:
		attrs[at_id] = clampi(roundi(average + raw[at_id] - mean_raw), int(club_cfg.min), int(club_cfg.max))
	var qual_level := average + rng.randfn(0.0, float(club_cfg.qualification_noise))
	var qualification := ""
	for q in club_cfg.qualifications:
		if qual_level >= float(q.from_average):
			qualification = str(q.id)
	var first := str(Data.names[gender][rng.randi_range(0, Data.names[gender].size() - 1)])
	var last := str(Data.names.surnames[rng.randi_range(0, Data.names.surnames.size() - 1)])
	return {"id": "", "name": "%s %s" % [first, last], "gender": gender, "voice": voice, "kind": "", "real": false,
			"source": "", "attributes": attrs, "personality": voice,
			"style": int(CoachSystem._weighted(rng, p.get("style", {"0": 1}))),
			"demands": CoachSystem._weighted(rng, p.get("demands", {"balanced": 1})),
			"facts": {"birth_year": int(Game.date.year) - rng.randi_range(int(age_range[0]), int(age_range[1])), "club_id": "",
					"town": "", "qualification": qualification, "reputation": "local", "event_focus": focus, "cost_month": 0,
					"open": false, "spots": 0, "min_level": 0},
			"group": []}


## Every coach of the market (made first), the head coach included.
func coaches() -> Array:
	ensure_pool()
	var out := []
	var cs := _cs()
	for c in cs.coaches.values():
		if c.has("market") or str(c.id) == Game.athlete.coach_id:
			out.append(c)
	return out


func coach(coach_id: String) -> Dictionary:
	ensure_pool()
	return _cs().coaches.get(coach_id, {})


# --- Who you can get ----------------------------------------------------------------------------------------------------

## Where a coach is listed: club / parent / town / region / academy / national / remote / elite.
func section(c: Dictionary) -> String:
	var a := Game.athlete
	var m: Dictionary = c.get("market", {})
	if str(m.get("section", "")) != "":
		return str(m.section)
	var kind := str(c.get("kind", ""))
	var rep := str(c.facts.get("reputation", "local"))
	if kind == "academy":
		return "academy"
	if kind == "club" and str(c.facts.get("club_id", "")) == a.club_id:
		return "club"
	if kind == "club":
		match CoachSystem.distance_of(c, a):
			"same": return "town"
			"region": return "region"
		return "national"
	if rep == "international" and int(c.facts.get("spots", 0)) <= 0:
		return "elite"
	if kind == "remote":
		return "remote"
	if kind == "parent":
		return "parent"
	return "national"


## The athlete's age today.
static func age() -> int:
	return Game.athlete.age_on(Game.date)


## The 800 m ability the athlete's best time shows (0 = no time yet).
static func shown_ability() -> float:
	var pb := float(Game.athlete.personal_bests.get("800m", 0.0))
	return RacePerformance.ability_for_time(pb, Game.athlete.gender) if pb > 0.0 else 0.0


## The time the coach asks for (seconds; 0 = none), from his min_level on the 800 m ability scale.
static func required_time(c: Dictionary) -> float:
	var ml := float(c.get("facts", {}).get("min_level", 0))
	if ml <= 0.0 or Game.athlete == null:
		return 0.0
	return snappedf(RacePerformance.time_for(ml, Game.athlete.gender), 0.1)


## Does the athlete see this coach in Find a coach now?
func visible(c: Dictionary) -> bool:
	var a := Game.athlete
	if str(c.id) == a.coach_id or str(pending.get("coach", "")) == str(c.id) or offers.has(str(c.id)):
		return true
	var ages: Dictionary = cfg().ages
	var sec := section(c)
	var opened: Array = cfg().seen.opens if seen_tf else []
	var real := bool(c.get("real", false))
	match sec:
		"club", "parent":
			return age() >= int(ages.club)
		"town":
			return age() >= int(ages.town)
		"region":
			return age() >= int(ages.region) or "region" in opened
		"academy":
			return age() >= int(ages.academy) and _centre_of_town() == _centre_of_coach(c)
		"national":
			return age() >= int(ages.real_personal if real else ages.national) or "national" in opened
		"remote":
			if str(c.facts.get("reputation", "")) == "international":
				return age() >= int(ages.elite) and shown_ability() >= float(c.facts.min_level) - 2.0
			return age() >= int(ages.remote)
		"elite":
			return age() >= int(ages.elite) and shown_ability() >= float(c.facts.min_level) - 1.0
	return false


func _centre_of_town() -> String:
	var c = Data.get_town(CoachSystem.home_town(Game.athlete)).get("centre")
	return str(c) if c != null else "-"


func _centre_of_coach(c: Dictionary) -> String:
	for x in Data.urheilulukiot.centres.list:
		if str(x.get("coach_id", "")) == str(c.id):
			return str(x.id)
	return "?"


## His places this season: real coaches their data `spots`; fictional ones drawn again every season.
func spots_now(c: Dictionary) -> int:
	if bool(c.get("real", false)) or not c.has("market") or str(c.market.get("tier", "")) in ["club", "parent", "real"]:
		return int(c.facts.get("spots", 0))
	var year := season_of(Game.date)
	var s: Dictionary = spots.get(str(c.id), {})
	if int(s.get("year", -1)) != year:
		var rng := RandomNumberGenerator.new()
		rng.seed = ("spots|%s|%d" % [str(c.id), year]).hash()
		s = {"year": year, "n": _roll(rng, cfg().tiers[str(c.market.tier)].spots)}
		spots[str(c.id)] = s
	return int(s.n)


## {cost (euros a month), kind: club / free / paid / estimate / academy}.
func cost_of(c: Dictionary) -> Dictionary:
	var kind := str(c.get("kind", ""))
	var cost := int(c.get("facts", {}).get("cost_month", 0))
	match kind:
		"parent":
			return {"cost": 0, "kind": "free"}
		"club":
			return {"cost": cost, "kind": "club"}
		"academy":
			return {"cost": cost, "kind": "academy" if cost > 0 else "free"}
	if cost <= 0 and bool(c.get("real", false)):
		return {"cost": int(cfg().fees.estimate.get(str(c.facts.get("reputation", "national")), 90)), "kind": "estimate"}
	return {"cost": cost, "kind": "paid"}


## The family's budget for coaching (euros a month, beyond the club fee).
func budget() -> int:
	var b: Dictionary = cfg().budget
	return int(b.by_family.get(Game.athlete.family, b.unknown))


func fits_budget(c: Dictionary) -> bool:
	var co := cost_of(c)
	return str(co.kind) in ["club", "free"] or int(co.cost) <= budget()


## {id, text}: head / pending / ended / offer / budget / approach / ok / no_time / not_yet / full.
func status(c: Dictionary) -> Dictionary:
	var ui: Dictionary = cfg().ui.status
	var cid := str(c.id)
	if cid == Game.athlete.coach_id:
		return {"id": "head", "text": str(ui.head)}
	if str(pending.get("coach", "")) == cid:
		return {"id": "pending", "text": str(ui.pending)}
	if ended.has(cid):
		return {"id": "ended", "text": str(ui.ended)}
	if not fits_budget(c):
		return {"id": "budget", "text": str(ui.budget).format({"cost": cost_of(c).cost})}
	if offer_open(cid):
		return {"id": "offer", "text": str(ui.offer).format({"date": Calendar.format_day(_date_of(int(offers[cid].until)))})}
	if section(c) == "elite":
		return {"id": "approach", "text": str(ui.approach)}
	if bool(c.facts.get("open", false)) and (str(c.kind) != "club" or str(c.facts.get("club_id", "")) == Game.athlete.club_id or age() >= int(cfg().ages.town)):
		return {"id": "ok", "text": str(ui.ok)}
	var req := required_time(c)
	if req > 0.0:
		var pb := float(Game.athlete.personal_bests.get("800m", 0.0))
		if pb <= 0.0:
			return {"id": "no_time", "text": str(ui.no_time)}
		if pb > req:
			return {"id": "not_yet", "text": str(ui.not_yet).format({"time": Calendar.format_time(req)})}
	if spots_now(c) <= 0:
		return {"id": "full", "text": str(ui.full)}
	return {"id": "ok", "text": str(ui.ok)}


## Could this coach take the athlete now (ask, then start)?
func can_take(c: Dictionary) -> bool:
	return str(status(c).id) in ["ok", "offer"]


func offer_open(cid: String) -> bool:
	return offers.has(cid) and int(offers[cid].until) >= today_no()


static func _date_of(day_no: int) -> Dictionary:
	return Game.add_days(Game.START_DATE, day_no - StoryletSystem.day_no(Game.START_DATE))


## The coaches the athlete sees now, by section (SECTIONS order), each list ordered by reputation and name.
func listing() -> Dictionary:
	var out := {}
	for c in coaches():
		if not visible(c):
			continue
		var sec := section(c)
		if not out.has(sec):
			out[sec] = []
		out[sec].append(c)
	var rank: Dictionary = cfg().reputation_rank
	for sec in out:
		out[sec].sort_custom(func(x, y):
			var rx := int(rank.get(str(x.facts.get("reputation", "local")), 0))
			var ry := int(rank.get(str(y.facts.get("reputation", "local")), 0))
			if rx != ry:
				return rx > ry
			return str(x.name) < str(y.name))
	return out


# --- Scouting ------------------------------------------------------------------------------------------------------------

## The width of the range before anything was learnt about the coach.
func start_width(c: Dictionary) -> float:
	var s: Dictionary = cfg().scouting
	if str(c.get("kind", "")) == "parent":
		return float(s.parent)
	if str(c.get("kind", "")) == "club" and str(c.get("facts", {}).get("club_id", "")) == Game.athlete.club_id:
		return float(s.head_start)   # (your own club's coaches: you have seen them at the track)
	if bool(c.get("real", false)):
		return float(s.evidence.get(str(c.get("evidence", "medium")), 6))
	return float(s.width.get(str(c.get("facts", {}).get("reputation", "local")), 8))


## The width of an attribute's range now: what was learnt, then the weeks together (exact after together_weeks).
func width(c: Dictionary, attr_id: String) -> float:
	var w := float(scout.get(str(c.id), {}).get("width", {}).get(attr_id, start_width(c)))
	var weeks := int(_cs().relations.get(str(c.id), {}).get("weeks", 0))
	if weeks > 0:
		w *= maxf(0.0, 1.0 - float(weeks) / float(cfg().scouting.together_weeks))
	return maxf(w, 0.0)


## [low, high] shown for an attribute (equal = known exactly). The true value sits at a fixed place inside the range (from
## the coach and the attribute), so a narrower range always lies inside the wider one.
func range_of(c: Dictionary, attr_id: String) -> Array:
	var v := int(c.attributes.get(attr_id, 10))
	var w := roundi(width(c, attr_id))
	if w <= 0:
		return [v, v]
	var off := float(posmod(("%s|%s" % [str(c.id), attr_id]).hash(), 1000)) / 999.0
	var lo := v - roundi(off * w)
	var hi := lo + w
	if lo < 1:
		hi += 1 - lo
		lo = 1
	if hi > 20:
		lo = maxi(1, lo - (hi - 20))
		hi = 20
	return [lo, hi]


## How well the athlete knows the coach: a word (data scouting.known_words by the mean width).
func known_word(c: Dictionary) -> String:
	var sum := 0.0
	for at in Data.coaching.attributes:
		sum += width(c, str(at.id))
	var mean := sum / maxf(1.0, Data.coaching.attributes.size())
	for k in cfg().scouting.known_words:
		if mean <= float(k[0]):
			return str(k[1])
	return ""


## Is a character word (style / demands) known? The head and former coaches always; others once a step revealed it.
func knows(c: Dictionary, what: String) -> bool:
	if int(_cs().relations.get(str(c.id), {}).get("weeks", 0)) > 0 or str(c.id) == Game.athlete.coach_id:
		return true
	return what in scout.get(str(c.id), {}).get("revealed", [])


func done(c: Dictionary, step: String) -> bool:
	return bool(scout.get(str(c.id), {}).get(step, false))


## A scouting step: asked / visited / results (data scouting.<asked|visit|results>).
func _learn(c: Dictionary, step: String) -> void:
	var key := str({"asked": "asked", "visited": "visit", "results": "results"}[step])
	var s: Dictionary = cfg().scouting[key]
	var cid := str(c.id)
	if not scout.has(cid):
		scout[cid] = {"width": {}, "revealed": []}
	var rec: Dictionary = scout[cid]
	if bool(rec.get(step, false)):
		return
	rec[step] = true
	for at in Data.coaching.attributes:
		var w := float(rec.width.get(at.id, start_width(c)))
		rec.width[at.id] = maxf(0.0, w - float(s.attrs.get(at.id, s.other)))
	for r in s.get("reveals", []):
		if not r in rec.revealed:
			rec.revealed.append(r)


## Look at the results of the coach's athletes (free, at once). Returns the line shown.
func look_results(c: Dictionary) -> String:
	_learn(c, "results")
	var lines: Dictionary = cfg().lines.results
	if bool(c.get("real", false)):
		return str(lines.real).format({"athletes": ", ".join(c.get("athletes_coached", []))})
	var k := (float(c.attributes.endurance_knowledge) + float(c.attributes.speed_strength_knowledge) + float(c.attributes.periodization)) / 3.0
	return str(lines.fictional["strong" if k >= 12.5 else ("fair" if k >= 9.5 else "weak")])


## Ask around (a teammate knows the coach): his best and worst side in a message in the group thread. Returns the text.
func ask_around(c: Dictionary) -> String:
	_learn(c, "asked")
	var l: Dictionary = cfg().lines.asked
	var best := ""
	var worst := ""
	for at in Data.coaching.attributes:
		var v := int(c.attributes[at.id])
		if best == "" or v > int(c.attributes[best]):
			best = str(at.id)
		if worst == "" or v < int(c.attributes[worst]):
			worst = str(at.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("asked|%s|%s" % [str(c.id), Game.athlete.full_name()]).hash()
	var fill := {"coach_first": str(c.name).split(" ")[0]}
	var text := "%s %s %s %s" % [str(l.intro[rng.randi_range(0, l.intro.size() - 1)]).format(fill), str(l.good[best]),
			str(l.bad[worst]), str(l.style.get(str(int(c.style)), ""))]
	var ms := Game.get_system("moments") as StoryletSystem
	if ms != null:
		ms._sync_people()
		var mates := ms.people_for("teammate")
		if not mates.is_empty():
			ms.say("group", str(mates[rng.randi_range(0, mates.size() - 1)].id), text)
	return text


## The days a visit can be planned on: the next `visit.days` days from tomorrow (today too before it is played), without
## race days. [{date, label}]
func visit_days() -> Array:
	var out := []
	var week := Game.current_week()
	for i in int(cfg().scouting.visit.days) + 1:
		var d := Game.add_days(Game.date, i)
		if i == 0 and week.day_started:
			continue
		if Calendar.date_key(Calendar.monday_of(d)) == Calendar.date_key(week.monday) and week.is_race_day(Calendar.weekday(d)):
			continue
		if not Calendar.races_in_week(Game.entries, Calendar.monday_of(d)).get(Calendar.weekday(d), {}).is_empty():
			continue
		out.append({"date": d, "label": Calendar.format_day(d)})
	return out


## Plans a visit to the coach's session on `date` (one visit at a time). The day changes: near = an easy run with his group,
## far = a rest day for the travel.
func plan_visit(c: Dictionary, date: Dictionary) -> void:
	cancel_visit()
	var far := CoachSystem.distance_of(c, Game.athlete) != "same"
	visit = {"coach": str(c.id), "date": date.duplicate(), "far": far, "done": false}
	_apply_visit(Game.current_week())


func cancel_visit() -> void:
	if visit.is_empty():
		return
	var week := Game.current_week()
	var d := _visit_day_in(week)
	if d >= 0 and week.can_change(d):
		week.reset_day(d)
	visit = {}


func _visit_day_in(week: WeekSim) -> int:
	if visit.is_empty() or Calendar.date_key(Calendar.monday_of(visit.date)) != Calendar.date_key(week.monday):
		return -1
	return Calendar.weekday(visit.date)


func _apply_visit(week: WeekSim) -> void:
	var d := _visit_day_in(week)
	if d < 0 or not week.can_change(d):
		return
	var v: Dictionary = cfg().scouting.visit
	if bool(visit.far):
		week.make_rest_day(d, "player")
	else:
		week.set_sessions(d, Array(v.near), "player")


func on_week_start(week: WeekSim) -> void:
	_apply_visit(week)


# --- Asking and changing coach -------------------------------------------------------------------------------------------

## "Would you coach me?": his answer as a message in the "coaches" thread. Returns {ok, status, text}.
func ask(c: Dictionary) -> Dictionary:
	var st := str(status(c).id)
	if st in ["head", "pending", "budget", "ended"]:
		return {"ok": false, "status": st, "text": ""}
	var key := str({"ok": "yes", "offer": "yes", "no_time": "no_time", "not_yet": "not_yet", "full": "full", "approach": "full"}.get(st, "full"))
	var text := line(c, key, {"time": Calendar.format_time(required_time(c))})
	answers[str(c.id)] = {"day": today_no(), "status": st}
	var ms := Game.get_system("moments") as StoryletSystem
	if ms != null:
		var pid := ms.market_person(c)
		ms.say("coaches", "you", str(cfg().ui.get("ask_line", "Would you coach me?")).format({"coach": c.name}))
		ms.say("coaches", pid, text, true)
	return {"ok": key == "yes", "status": st, "text": text}


## He said yes (or has an offer open): the athlete may start with him.
func may_start(c: Dictionary) -> bool:
	if not can_take(c):
		return false
	if offer_open(str(c.id)):
		return true
	var ans: Dictionary = answers.get(str(c.id), {})
	return not ans.is_empty() and str(ans.status) in ["ok", "offer"] and today_no() - int(ans.day) <= int(cfg().offers.valid_days)


## The athlete decides to change coach: from the next Monday. The old coach's goodbye (a moment in the coach thread) and the
## group's line come now; the change itself on Sunday night.
func start(c: Dictionary, why := "player") -> void:
	var monday := Game.add_days(Calendar.monday_of(Game.date), 7)
	pending = {"coach": str(c.id), "date": monday, "why": why}
	var cs := _cs()
	var old := cs.head()
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null or old.is_empty():
		return
	var l: Dictionary = cfg().lines
	var fill := {"new": str(c.name), "old": str(old.name), "name": Game.athlete.first_name, "coach_first": str(old.name).split(" ")[0]}
	if why != "ended":
		var replies := []
		for r in l.farewell_replies:
			replies.append({"id": r.id, "label": str(r.label).format(fill), "hint": str(r.hint).format(fill)})
		ms.post_custom("market", "farewell:" + str(old.id), line(old, "farewell", fill), replies, false,
				{"title": str(l.farewell_title).format({"coach": old.name})})
	ms._sync_people()
	var mates := ms.people_for("teammate")
	if not mates.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = ("goodbye|%s|%s" % [str(old.id), str(c.id)]).hash()
		ms.say("group", str(mates[rng.randi_range(0, mates.size() - 1)].id), str(l.group_goodbye[rng.randi_range(0, l.group_goodbye.size() - 1)]).format(fill))


func cancel_pending() -> void:
	pending = {}


## The change itself (Sunday night, or at once when a coach has ended it): a new relation (or the old one, back with a former
## coach), his training group, the threads' lines.
func switch_to(cid: String, why: String) -> void:
	var cs := _cs()
	var a := Game.athlete
	var c: Dictionary = cs.coaches.get(cid, {})
	if c.is_empty():
		return
	var start_day := Game.date.duplicate() if why == "ended" else Game.add_days(Game.date, 1)
	for h in history:
		if (h.to as Dictionary).is_empty():
			h.to = start_day.duplicate()
	if (c.get("group", []) as Array).is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = ("group|%s|%s" % [cid, a.full_name()]).hash()
		var m: Dictionary = c.get("market", {})
		var size: Array = cfg().tiers.get(str(m.get("tier", "")), {}).get("group", [])
		if str(m.get("tier", "")) == "parent":
			size = [2, 4]
		var gl := float(m.get("group_level", -1.0))
		c.group = CoachSystem._make_group(a, rng, size, gl if gl > 0.0 else -1.0)
	cs.set_head(a, cid, start_day)
	history.append({"coach": cid, "from": start_day.duplicate(), "to": {}})
	pending = {}
	offers.erase(cid)
	chain = {}
	if visit.get("coach", "") == cid:
		visit = {}
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return
	ms._sync_people()
	var l: Dictionary = cfg().lines
	var fill := {"new": str(c.name), "name": a.first_name}
	ms.say("coach", "system", str(l.switched).format(fill), true)
	ms.say("coach", cid, line(c, "welcome", fill))
	var mates := ms.people_for("teammate")
	if not mates.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = ("hello|%s|%s" % [cid, a.full_name()]).hash()
		ms.say("group", str(mates[rng.randi_range(0, mates.size() - 1)].id), str(l.group_hello[rng.randi_range(0, l.group_hello.size() - 1)]).format(fill))


## A line of data/market.json lines.<key> in the coach's voice (`real` for a real coach: neutral words only).
func line(c: Dictionary, key: String, fill := {}) -> String:
	var set: Dictionary = cfg().lines[key]
	var voice := "real" if bool(c.get("real", false)) else str(c.get("voice", "calm"))
	var f := fill.duplicate()
	f.merge({"name": Game.athlete.first_name, "coach": str(c.get("name", "")), "coach_first": str(c.get("name", "")).split(" ")[0]}, false)
	return str(set.get(voice, set.get("calm", ""))).format(f)


# --- The week: the change, offers, the ending chain ----------------------------------------------------------------------

func on_day_end(_ctx: Dictionary) -> void:
	if not enabled or Game.athlete == null:
		return
	if not visit.is_empty() and not bool(visit.done) and Calendar.date_key(visit.date) == Calendar.date_key(Game.date):
		_visit_done()
	var pb := float(Game.athlete.personal_bests.get("800m", 0.0))
	if pb > 0.0 and (seen_pb <= 0.0 or pb < seen_pb):
		var old := seen_pb
		seen_pb = pb
		ensure_pool()
		_check_offers(old, pb)


func _visit_done() -> void:
	visit.done = true
	var c := coach(str(visit.coach))
	if c.is_empty():
		return
	_learn(c, "visited")
	var v: Dictionary = cfg().lines.visit
	var best := ""
	var worst := ""
	for at_id in v.good:
		var x := int(c.attributes[at_id])
		if best == "" or x > int(c.attributes[best]):
			best = at_id
		if worst == "" or x < int(c.attributes[worst]):
			worst = at_id
	var good := str(v.good[best]) if int(c.attributes[best]) >= 12 else ""
	var bad := str(v.bad[worst]) if int(c.attributes[worst]) <= 8 else ""
	if good == "" and bad == "":
		good = str(v.neutral)
	var ms := Game.get_system("moments") as StoryletSystem
	if ms != null:
		ms.say("coaches", "system", str(v.line).format({"coach": c.name, "day": Calendar.format_day(Game.date), "good": good, "bad": bad}).strip_edges())


## A personal best: has it cleared a coach's bar for the first time (or reached the TF-juniorit standard)? One coach may
## write to the athlete (at most one every gap_days, max_per_season a season).
func _check_offers(old_pb: float, pb: float) -> void:
	var a := Game.athlete
	var why := "pb"
	var tf := Standards.time(str(cfg().seen.standard), a, int(Game.date.year))
	if not seen_tf and tf > 0.0 and pb <= tf:
		seen_tf = true
		why = "seen"
	var o: Dictionary = cfg().offers
	var year := season_of(Game.date)
	if today_no() - last_offer_day < int(o.gap_days) or int(offers_by_season.get(str(year), 0)) >= int(o.max_per_season):
		return
	var rank: Dictionary = cfg().reputation_rank
	var head_rank := int(rank.get(str(_cs().head().get("facts", {}).get("reputation", "local")), 0))
	var best := {}
	for c in coaches():
		var cid := str(c.id)
		if cid == a.coach_id or cid == str(pending.get("coach", "")) or ended.has(cid) or int(declined.get(cid, -1)) == year:
			continue
		if not section(c) in ["region", "national", "remote", "elite", "academy"] or not fits_budget(c):
			continue
		var req := required_time(c)
		if req <= 0.0 or pb > req:
			continue
		var crossed := old_pb <= 0.0 or old_pb > req
		if not crossed and why != "seen":
			continue
		if section(c) == "elite":
			if age() < int(cfg().ages.elite):
				continue
		elif not visible(c) or spots_now(c) <= 0:
			continue
		var r := int(rank.get(str(c.facts.get("reputation", "local")), 0))
		if r < head_rank:
			continue
		if best.is_empty() or r > int(rank.get(str(best.facts.get("reputation", "local")), 0)) \
				or (r == int(rank.get(str(best.facts.get("reputation", "local")), 0)) and CoachSystem.average(c) > CoachSystem.average(best)):
			best = c
	if best.is_empty():
		return
	last_offer_day = today_no()
	offers_by_season[str(year)] = int(offers_by_season.get(str(year), 0)) + 1
	offers[str(best.id)] = {"until": today_no() + int(o.valid_days), "why": why}
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return
	var pid := ms.market_person(best)
	var replies := []
	for r in cfg().lines.offer_replies:
		replies.append({"id": r.id, "label": r.label, "hint": r.hint})
	ms.post_custom("market", "offer:" + str(best.id), line(best, "offer_seen" if why == "seen" else "offer"), replies, false,
			{"from": pid, "thread": "coaches", "expires_days": int(o.valid_days),
			"title": str(cfg().lines.offer_title).format({"coach": best.name})})


func on_week_end(_ctx: Dictionary) -> void:
	if not enabled or Game.athlete == null:
		return
	var monday := Game.add_days(Game.date, 1)
	if not pending.is_empty() and Calendar.date_key(pending.date) == Calendar.date_key(monday):
		switch_to(str(pending.coach), str(pending.get("why", "player")))
		return
	_chain_week()


## The ending chain (user 2026-10-17: 6 + 4 + 4 weeks): Strained weeks in a row, two warnings, then he ends it.
func _chain_week() -> void:
	var cs := _cs()
	if cs == null or not CoachSystem.model_enabled or not pending.is_empty():
		return
	if cs.trust_level() != "strained":
		chain = {}
		return
	var e: Dictionary = cfg().ending
	var weeks := int(chain.get("weeks", 0)) + 1
	var stage := int(chain.get("stage", 0))
	var at := int(chain.get("at", 0))
	chain = {"weeks": weeks, "stage": stage, "at": at}
	if stage == 0 and weeks >= int(e.strained_weeks):
		_warn(1)
		chain.stage = 1
		chain.at = weeks
	elif stage == 1 and weeks >= at + int(e.second_after):
		_warn(2)
		chain.stage = 2
		chain.at = weeks
	elif stage == 2 and weeks >= at + int(e.end_after):
		_end()
		chain.stage = 3


func _warn(n: int) -> void:
	var ms := Game.get_system("moments") as StoryletSystem
	var head := _cs().head()
	if ms == null or head.is_empty():
		return
	var fill := {"coach_first": str(head.name).split(" ")[0]}
	var replies := []
	for r in cfg().lines.warn_replies:
		replies.append({"id": r.id, "label": str(r.label).format(fill), "hint": str(r.hint).format(fill)})
	ms.post_custom("market", "warn:%d" % n, line(head, "warn%d" % n), replies, true,
			{"title": str(cfg().lines.warn_title).format({"coach": head.name})})


## He ends it: a stop with the coaches who would take the athlete now (no answer = the first). A small club with nobody else
## finds a volunteer (a new club coach).
func _end() -> void:
	var ms := Game.get_system("moments") as StoryletSystem
	var head := _cs().head()
	if ms == null or head.is_empty():
		return
	ended[str(head.id)] = today_no()
	var replies := []
	for c in end_choices():
		var co := cost_of(c)
		var cost_text := str(cfg().ui.cost[str(co.kind)]).format({"cost": co.cost})
		replies.append({"id": "pick:" + str(c.id), "label": str(c.name),
				"hint": str(cfg().lines.end_reply_hint).format({"kind": str(cfg().ui.kinds.get(str(c.kind), c.kind)), "cost": cost_text})})
	ms.post_custom("market", "end", line(head, "end"), replies, true,
			{"title": str(cfg().lines.end_title).format({"coach": head.name})})


## Who would take the athlete now, best first: the own club's coaches, the parent, then the others by reputation.
func end_choices() -> Array:
	var out := []
	var lists := listing()
	for sec in SECTIONS:
		for c in lists.get(sec, []):
			if can_take(c) and str(c.id) != Game.athlete.coach_id:
				out.append(c)
	if out.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = ("volunteer|%s|%d" % [Game.athlete.full_name(), today_no()]).hash()
		var c := _make(rng, "club", "club", CoachSystem.home_town(Game.athlete), Game.athlete.club_id)
		_add(c)
		out.append(c)
	return out.slice(0, int(cfg().ending.max_choices))


## The answers to the market's moments (StoryletSystem custom kind "market"): offer:<id>, farewell:<id>, warn:<n>, end.
func on_reply(ref: String, reply_id: String) -> Dictionary:
	var parts := ref.split(":", false, 1)
	var l: Dictionary = cfg().lines
	match parts[0]:
		"offer":
			var c := coach(parts[1])
			if reply_id == "no":
				declined[parts[1]] = season_of(Game.date)
				offers.erase(parts[1])
			if c.is_empty() or reply_id == StoryletSystem.NONE:
				return {}
			if reply_id == "more":
				_learn(c, "results")
			return {"result": _answer_line(c, l.offer_answer, reply_id)}
		"farewell":
			var c := coach(parts[1])
			if c.is_empty() or reply_id == StoryletSystem.NONE:
				return {}
			var ms := Game.get_system("moments") as StoryletSystem
			var delta := float(l.farewell_relation.get(reply_id, 0.0))
			var changes := []
			if ms != null and delta != 0.0:
				ms.add_relation(parts[1], delta)
				changes.append(ms._change_line(str(Data.moments.changes.relation).format({"who": str(c.name).split(" ")[0]}), delta))
			return {"result": _answer_line(c, l.farewell_answer, reply_id), "changes": changes}
		"warn":
			var head := _cs().head()
			if reply_id == StoryletSystem.NONE or head.is_empty():
				return {}
			var delta := float(cfg().ending.replies.get(reply_id, 0.0))
			var changes := []
			if delta != 0.0:
				_cs().add_trust(delta, "market:warn")
				var ms := Game.get_system("moments") as StoryletSystem
				if ms != null:
					changes.append(ms._change_line(str(Data.moments.changes.trust).format({"who": str(head.name).split(" ")[0]}), delta))
			return {"result": _answer_line(head, l.warn_answer, reply_id), "changes": changes}
		"end":
			var pick := reply_id.trim_prefix("pick:")
			if not _cs().coaches.has(pick) or reply_id == pick:
				var choices := end_choices()
				pick = str(choices[0].id)
			switch_to(pick, "ended")
			return {}
	return {}


func _answer_line(c: Dictionary, set: Dictionary, reply_id: String) -> String:
	var by: Dictionary = set.get(reply_id, {})
	var voice := "real" if bool(c.get("real", false)) else str(c.get("voice", "calm"))
	return str(by.get(voice, by.get("calm", "")))


# --- Save ------------------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if not made and pending.is_empty() and history.is_empty():
		return {}
	return {"made": made, "scout": scout, "spots": spots, "pending": pending, "visit": visit, "offers": offers,
			"declined": declined, "answers": answers, "ended": ended, "history": history, "chain": chain,
			"seen_pb": seen_pb, "seen_tf": seen_tf, "last_offer_day": last_offer_day, "offers_by_season": offers_by_season,
			"next": _next}


func from_dict(d: Dictionary) -> void:
	made = bool(d.get("made", false))
	scout = d.get("scout", {})
	spots = d.get("spots", {})
	for s in spots.values():
		s.year = int(s.year)
		s.n = int(s.n)
	pending = d.get("pending", {})
	if not pending.is_empty():
		pending.date = Game.int_date(pending.date)
	visit = d.get("visit", {})
	if not visit.is_empty():
		visit.date = Game.int_date(visit.date)
	offers = d.get("offers", {})
	for o in offers.values():
		o.until = int(o.until)
	declined = d.get("declined", {})
	for k in declined:
		declined[k] = int(declined[k])
	answers = d.get("answers", {})
	for x in answers.values():
		x.day = int(x.day)
	ended = d.get("ended", {})
	for k in ended:
		ended[k] = int(ended[k])
	history = d.get("history", [])
	for h in history:
		h.from = Game.int_date(h.from)
		if not (h.to as Dictionary).is_empty():
			h.to = Game.int_date(h.to)
	chain = d.get("chain", {})
	for k in chain:
		chain[k] = int(chain[k])
	seen_pb = float(d.get("seen_pb", 0.0))
	seen_tf = bool(d.get("seen_tf", false))
	last_offer_day = int(d.get("last_offer_day", -9999))
	offers_by_season = d.get("offers_by_season", {})
	_next = int(d.get("next", 1))
