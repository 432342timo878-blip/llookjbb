class_name NextBig
extends RefCounted
## "The next big thing" and the long path (GDD 4.10 decision 10, session K1a). Reading only: the target race that comes next with a
## countdown and what you need for it, and the coach's 2-3-year view built from what the game really has (the application to the upper
## secondary school, the real limits of your ages, the school years). Texts: data/career.json (`ui.next_big`, `path`).


static func ui() -> Dictionary:
	return Data.career.ui.next_big


## The next target race from today on: {meet, days, need (a short phrase for the strap), lines (the full list)}, or {} when the career has
## no target (the repeating week) and no race entered. A target is a meet of the season plan; with none left the next entered meet.
static func target() -> Dictionary:
	var a := Game.athlete
	if a == null:
		return {}
	var today := Game.date
	var best := {}
	if Game.season.mode == SeasonPlan.PHASES:
		var y := SeasonPlan.year_of(today)
		for year in [y, y + 1]:
			for key in Game.season.targets(year):
				var m := Calendar.get_meet(str(key))
				if m.is_empty() or Calendar.date_key(m.date) < Calendar.date_key(today):
					continue
				if best.is_empty() or Calendar.date_key(m.date) < Calendar.date_key(best.date):
					best = m
	var is_target := not best.is_empty()
	if best.is_empty():
		best = Game.next_race()
	if best.is_empty():
		return {}
	var days := Calendar.days_between(today, best.date)
	var u := ui()
	var lines := []
	var need := ""
	var gap := _standard(a, best)
	if not gap.is_empty():
		if gap.have:
			lines.append(str(u.lines.std).format({"class": gap.cls, "limit": gap.limit_text, "have": str(u.lines.std_have).format({"pb": gap.pb_text})}))
			need = str(u.need_have)
		elif float(gap.pb) > 0.0:
			lines.append(str(u.lines.std).format({"class": gap.cls, "limit": gap.limit_text,
					"have": str(u.lines.std_gap).format({"pb": gap.pb_text, "gap": "%.1f" % float(gap.gap)})}))
			need = str(u.need_std).format({"limit": gap.limit_text})
		else:
			lines.append(str(u.lines.std).format({"class": gap.cls, "limit": gap.limit_text, "have": str(u.lines.std_nobest)}))
			need = str(u.need_std).format({"limit": gap.limit_text})
	for g in _goals_at(str(best.key)):
		lines.append(str(u.lines.goal).format({"goal": SeasonGoals.goal_text(g, SeasonPlan.year_of(best.date))}))
	var sb := Rankings.player_season_best(a, Rankings.season_of(today))
	if sb > 0.0:
		lines.append(str(u.lines.season_best).format({"sb": Calendar.format_time(sb)}))
	if need == "":
		var pb := float(a.personal_bests.get(a.main_event, 0.0))
		need = str(u.need_pb).format({"pb": Calendar.format_time(pb)}) if pb > 0.0 else str(u.need_none)
	return {"meet": best, "key": str(best.key), "days": days, "target": is_target, "need": need, "lines": lines,
			"when": Calendar.format_meet_date(best), "days_text": days_text(days)}


static func days_text(days: int) -> String:
	var u := ui()
	if days <= 0:
		return str(u.days_today)
	if days == 1:
		return str(u.days_one)
	return str(u.days_many).format({"n": days})


## The meet's entry standard for the athlete: {cls, limit, limit_text, pb, pb_text, gap (seconds above the limit), have} or {}.
static func _standard(a: Athlete, m: Dictionary) -> Dictionary:
	if not m.has("standard"):
		return {}
	var limits: Dictionary = Data.competitions.standards[m.standard].get(a.main_event, {})
	var cls := Calendar.age_class(a, m.date.year)
	if not limits.has(cls):
		return {}
	var limit := float(limits[cls])
	var pb := float(a.personal_bests.get(a.main_event, 0.0))
	return {"cls": cls, "limit": limit, "limit_text": Calendar.format_time(limit), "pb": pb,
			"pb_text": Calendar.format_time(pb) if pb > 0.0 else "", "gap": pb - limit, "have": pb > 0.0 and pb <= limit}


## The open season goals that name this meet.
static func _goals_at(key: String) -> Array:
	var out := []
	var sg := SeasonGoals.sys()
	if sg == null or not SeasonGoals.enabled:
		return out
	for y in sg.seasons:
		for g in sg.seasons[y].get("goals", []):
			if str(g.get("status", "")) == "open" and str(g.get("meet", "")) == key:
				out.append(g)
	return out


# --- The long path --------------------------------------------------------------------------------------------------------------

## The coming years as a list of steps, in order: [{kind ("school" / "limit"), year, when (text), title, text, gap (seconds, limits only),
## reach (a phrase, limits only)}]. Only what the game has: the application, the real limits of the ages, the school years.
static func path() -> Array:
	var a := Game.athlete
	var out := []
	if a == null:
		return out
	var p: Dictionary = Data.career.path
	var today := Game.date
	var pb := float(a.personal_bests.get(a.main_event, 0.0))
	var ss := SchoolSystem.sys()
	if ss != null and SchoolSystem.model_enabled and not SchoolSystem.neutral:
		var first := ss.first_secondary_year()
		var apply_year := first - 1
		var d := SchoolApplication.dates(apply_year)
		if Calendar.date_key(d.close) >= Calendar.date_key(today):
			var text := str(p.application).format({"dates": "%s – %s" % [Calendar.format_day(d.open), Calendar.format_day(d.close)]})
			var sp := SchoolApplication.sport_points(a, apply_year)
			var next := _next_anchor(a, apply_year, float(sp.best))
			if float(sp.best) > 0.0 and next != "":
				text += " " + str(p.application_sport).format({"points": "%.1f" % float(sp.total), "max": "%.0f" % float(SchoolApplication.cfg().points.sport.max), "time": next})
			out.append({"kind": "school", "year": apply_year, "order": Calendar.date_key(d.open), "when": Calendar.format_day(d.open), "title": "Application", "text": text})
		if Calendar.date_key(today) < Calendar.date_key({"year": first, "month": 8, "day": 1}):
			out.append({"kind": "school", "year": first, "order": first * 10000 + 801, "when": "Autumn %d" % first, "title": "Upper secondary begins",
					"text": str(p.school_start).format({"path": "Your next school", "school_year": "autumn %d" % first})})
	var seen_keys := {}
	var y0 := int(today.year)
	for y in range(y0, y0 + int(p.seasons)):
		for sid in Standards.ids():
			var set := Standards.set_of(str(sid))
			var limit := Standards.time(str(sid), a, y)
			if limit <= 0.0:
				continue
			var key := "%s|%s" % [sid, Standards.key_for(set, a, y)]
			if seen_keys.has(key):
				continue
			seen_keys[key] = true
			var gap := pb - limit if pb > 0.0 else 0.0
			var age := Standards.age_in(a, y)
			var step := {"kind": "limit", "year": y, "order": y * 10000 + 1000 + int(limit), "when": "%d" % y, "title": str(set.name),
					"text": str(p.limit).format({"name": str(set.short), "time": Calendar.format_time(limit), "year": y, "age_text": "age %d" % age}),
					"gap": gap, "limit": limit}
			if pb > 0.0:
				step.reach = reach_word(gap, age)
				if gap > 0.0:
					step.text += " " + str(p.limit_gap).format({"gap": "%.1f" % gap})
			out.append(step)
	out.sort_custom(func(x, y): return int(x.order) < int(y.order))
	return out


## The anchor above the best time of the sport points ("2:20.00"), or "".
static func _next_anchor(a: Athlete, year: int, best: float) -> String:
	var next := 0.0
	for an in SchoolApplication.anchors(a, year):
		if float(an.time) < best:
			next = float(an.time)
			break
	return Calendar.format_time(next) if next > 0.0 else ""


## How soon a gap closes at the typical yearly gain of the age (data/market.json offers.yearly_gain): a rough pace, not a promise.
static func reach_word(gap: float, age: int) -> String:
	var r: Dictionary = Data.career.path.reach
	if gap <= 0.0:
		return str(r.have)
	var gain := yearly_gain(age)
	if gap <= gain:
		return str(r.within)
	if gap <= gain * 2.0:
		return str(r.two)
	return str(r.far)


static func yearly_gain(age: int) -> float:
	var table: Array = Data.market.offers.yearly_gain
	var out := float(table[0][1])
	for row in table:
		if age >= int(row[0]):
			out = float(row[1])
	return out
