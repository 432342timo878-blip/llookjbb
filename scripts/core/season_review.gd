class_name SeasonReview
extends RefCounted
## The season review chapter's snapshot (GDD 4.10 decision 10, session K1b). CareerSystem calls `build(year)` on the last night of a
## season (31 October): the season in numbers, the goals met and missed with what they opened, the season list, the best race, the
## coach's verdict, what changed in your life, and the next season. Everything is recorded or counted from what the game kept: the
## results, the goals, the season-list log, the monthly record, the milestones. The snapshot is saved with the career (CareerSystem
## `reviews`), so a season can be read again from Career -> Seasons. Texts: data/season_review.json.

static func cfg() -> Dictionary:
	return Data.season_review


## The dates of a training season (1 Nov of `year` to 31 Oct): {from, to}.
static func span(year: int) -> Dictionary:
	return {"from": SeasonPlan.season_start(year), "to": Game.add_days(SeasonPlan.season_start(year + 1), -1)}


## A snapshot of the training season `year` ("2026–27") as it stands on `today`.
static func build(year: int, cs: CareerSystem, today: Dictionary) -> Dictionary:
	var a := Game.athlete
	var sp := span(year)
	var lo := Calendar.date_key(sp.from)
	var hi := Calendar.date_key(sp.to)
	# --- the races of the season (a meet day = one race; its last round is the result)
	var races := 0
	var pbs := 0
	var wins := 0
	var medals := 0
	var scoring := 0
	var best := 0.0
	var best_before := 0.0
	var cur_id := ""
	var final_r := {}
	var days := []
	for r in a.results:
		if str(r.get("event", "")) != a.main_event:
			continue
		var k := Calendar.date_key(Game.int_date(r.date))
		var ok: bool = str(r.get("status", "")) == "" and float(r.time) > 0.0
		if k < lo:
			if ok and (best_before <= 0.0 or float(r.time) < best_before):
				best_before = float(r.time)
			continue
		if k > hi:
			continue
		if ok and (best <= 0.0 or float(r.time) < best):
			best = float(r.time)
		if bool(r.get("pb", false)):
			pbs += 1
		var id := "%d|%s" % [k, str(r.meet_key)]
		if id != cur_id:
			cur_id = id
			days.append({"date": Game.int_date(r.date), "key": str(r.meet_key), "last": r})
		days[-1].last = r
	for d in days:
		races += 1
		var fr: Dictionary = d.last
		var meet := Calendar.get_meet(str(d.key))
		var place := int(fr.get("place", 0))
		var field := int(fr.get("field", 0))
		var final: bool = not (str(fr.get("round", "Race")).begins_with("Heat") or str(fr.get("round", "Race")).begins_with("Semi"))
		if str(fr.get("status", "")) != "" or not final or place <= 0:
			continue
		if place == 1 and field >= 4:
			wins += 1
		elif place <= 3 and field >= 4:
			medals += 1
		if str(meet.get("level", "local")) in Data.career.milestones.national_levels and place <= 8 and place <= ceili(field / 2.0) and field >= 6:
			scoring += 1
	# --- the numbers
	var start_rec := _record_at(sp.from)
	var end_rec := ProgressLog.snapshot(a, sp.to, "end")
	var attrs := []
	for c in ProgressLog.changes(start_rec, end_rec, 5):
		var attr_name := str(c[0])
		for def in Data.attributes:
			if str(def.id) == str(c[0]):
				attr_name = str(def.name)
		attrs.append({"id": str(c[0]), "name": attr_name, "change": float(c[1])})
	var injured := 0
	var hs := Game.get_system("health") as HealthSystem
	if hs != null:
		for inj in hs.history:
			if str(inj.get("tier", "")) != "illness" and inj.has("healed") and Calendar.date_key(Game.int_date(inj.started)) >= lo \
					and Calendar.date_key(Game.int_date(inj.started)) <= hi:
				injured += Calendar.days_between(Game.int_date(inj.started), Game.int_date(inj.healed))
	var sessions := {}
	var sg := Game.get_system("goals") as SeasonGoals
	if sg != null and sg.counts.has(year):
		sessions = {"done": int(sg.counts[year].get("done", 0)), "planned": int(sg.counts[year].get("planned", 0))}
	var step0 := CareerSystem.step_of(cs.score(sp.from))
	var step1 := CareerSystem.step_of(cs.score(sp.to))
	var steps: Array = Data.reputation.steps
	var numbers := {"races": races, "pbs": pbs, "wins": wins, "medals": medals, "scoring": scoring, "best": best, "best_before": best_before,
			"ability0": float(start_rec.get("ability", 0.0)), "ability1": float(end_rec.ability), "name0": str(steps[step0].name),
			"name1": str(steps[step1].name), "sessions": sessions, "injured": injured}
	# --- the goals
	var goals := []
	var met := 0
	if sg != null:
		for g in sg.goals_of(year):
			var item := {"text": SeasonGoals.goal_text(g, year), "status": str(g.status), "opened": SeasonGoals.opened_text(g) if str(g.status) == "met" else "",
					"detail": str(g.get("detail", ""))}
			for h in g.get("history", []):
				if str(h.what) == "adjusted" and str(h.was) != "":
					item.was = str(h.was)
			goals.append(item)
			if str(g.status) == "met":
				met += 1
	# --- the season list
	var rank_rows := []
	for r in cs.rank_log:
		var in_season: bool = (int(r.year) == year and int(r.month) >= 11) or (int(r.year) == year + 1 and int(r.month) <= 10)
		if in_season:
			rank_rows.append({"label": "%s %d" % [str(Calendar.MONTHS_SHORT[int(r.month) - 1]), int(r.year)], "rank": int(r.rank), "of": int(r.of), "time": float(r.time)})
	# --- the best race: the one that earned the name the most points
	var best_race := {}
	var top := -1.0
	for e in cs.rep_events:
		if str(e.kind) != "race":
			continue
		var k := Calendar.date_key(e.date)
		if k >= lo and k <= hi and float(e.points) >= top:
			top = float(e.points)
			best_race = {"meet": str(e.meet), "key": str(e.key), "date": e.date.duplicate(), "points": float(e.points),
					"card": "%d_%s" % [k, str(e.key)], "text": ""}
	if not best_race.is_empty():
		for d in days:
			if str(d.key) == str(best_race.key) and Calendar.date_key(d.date) == Calendar.date_key(best_race.date):
				best_race.text = Race.result_text(d.last, " in ")
	# --- the verdict
	var yg := NextBig.yearly_gain(a.age_on(sp.to))
	var gain := best_before - best if best_before > 0.0 and best > 0.0 else 0.0
	var oc: Dictionary = cfg().outcome
	var outcome := "steady"
	if (not goals.is_empty() and float(met) / goals.size() >= float(oc.strong_goals)) or gain >= yg:
		outcome = "strong"
	elif races == 0 or (not goals.is_empty() and met == 0 and gain < yg * float(oc.tough_gain_share)):
		outcome = "tough"
	var voice := Coaches.id_of(a)
	var lines: Dictionary = cfg().verdict[outcome]
	var verdict := CoachSystem.words(str(lines.get(voice, lines.calm)))
	# --- what changed in your life
	var life := []
	for m in cs.milestones:
		var k := Calendar.date_key(m.date)
		if k >= lo and k <= hi and str(m.kind) in ["school", "coach", "moved", "injury", "comeback"]:
			life.append({"icon": str(m.icon), "title": str(m.title), "text": str(m.text), "date": m.date.duplicate()})
	var school_avg := 0.0
	var ss := SchoolSystem.sys()
	if ss != null and SchoolSystem.model_enabled:
		for rep in ss.reports:
			var k := Calendar.date_key(Game.int_date(rep.date))
			if k >= lo and k <= hi:
				school_avg = float(rep.get("average", 0.0))
	# --- on to the next season
	var next := {"year": year + 1, "label": SeasonSystem.season_label(year + 1), "targets": SeasonSystem.targets_text(year + 1)}
	return {"year": year, "label": SeasonSystem.season_label(year), "date": today.duplicate(), "seen": false,
			"until": Calendar.date_key(Game.add_days(sp.to, 28)), "numbers": numbers, "attrs": attrs, "goals": goals, "met": met,
			"rank": rank_rows, "best_race": best_race, "outcome": outcome, "verdict": verdict, "voice": voice, "life": life,
			"school_avg": school_avg, "next": next, "age": a.age_on(sp.to)}


## The monthly record (ProgressLog) at or before a date, else the earliest one.
static func _record_at(date: Dictionary) -> Dictionary:
	var key := Calendar.date_key(date)
	var pick := {}
	for rec in Game.progress:
		var k := int(rec.year) * 10000 + int(rec.month) * 100 + int(rec.day)
		if k <= key and (pick.is_empty() or k >= int(pick.year) * 10000 + int(pick.month) * 100 + int(pick.day)):
			pick = rec
	if pick.is_empty() and not Game.progress.is_empty():
		pick = Game.progress[0]
	return pick
