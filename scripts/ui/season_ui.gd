class_name SeasonUI
extends RefCounted
## Shared words and numbers of the season-plan UI (GDD 4.8 "UI", M2 step 6e): the week strip caption, phase
## dates and states, the plan cards' weekly load, and the lead-in for a future phase (cached).

const TARGET_MARK := "◆"   # target meets (★ stays "the coach suggests", user decision 2026-10-07)

static var _lead_in_key := ""
static var _lead_in := {}


## The caption above the week strip for this week, or "" in repeat mode:
## "General base · week 3 of 10 · lighter week", "Taper: Nuorten SM 14-15 in 9 days".
static func week_caption() -> String:
	if Game.season.mode != SeasonPlan.PHASES:
		return ""
	var plan := Game.season.week_for(Game.week_monday())
	if plan.kind == "taper" and plan.target != "":
		var meet := Calendar.get_meet(plan.target)
		var days := Calendar.days_between(Game.date, meet.date)
		if days > 0:
			return "Taper: %s in %d day%s" % [meet.name, days, "" if days == 1 else "s"]
		if days == 0:
			return "Race day: %s" % meet.name
	return week_text(plan)


## "General base · week 3 of 10 · lighter week" for a week_for() result (or a saved report's `plan`).
static func week_text(plan: Dictionary) -> String:
	var text := "%s · week %d of %d" % [SeasonPlan.phase_type(plan.phase).get("name", plan.phase),
			int(plan.phase_week), int(plan.phase_weeks)]
	match str(plan.kind):
		"lighter": text += " · lighter week"
		"taper": text += " · taper" + (" for " + Calendar.get_meet(plan.target).get("name", "") if plan.get("target", "") != "" else "")
	return text


## The season shown in the Training tab (the one this week belongs to).
static func current_year() -> int:
	return Game.season.plan_year(Game.week_monday())


## "2 Nov – 10 Jan" (the year only when the two differ from the season's own).
static func range_text(first: Dictionary, last: Dictionary) -> String:
	return "%d %s – %d %s" % [first.day, Calendar.MONTHS_SHORT[int(first.month) - 1], last.day,
			Calendar.MONTHS_SHORT[int(last.month) - 1]]


## "past" / "now" / "future" for a phase of phase_dates().
static func phase_state(p: Dictionary) -> String:
	var today := Calendar.date_key(Game.date)
	if Calendar.date_key(p.last) < today:
		return "past"
	return "now" if Calendar.date_key(p.first) <= today else "future"


## The week of a phase today is in (1-based), or 0.
static func phase_week_now(p: Dictionary) -> int:
	if phase_state(p) != "now":
		return 0
	return Calendar.days_between(p.first, Calendar.monday_of(Game.date)) / 7 + 1


## Average planned weekly load of one of the coach's plans over a season: each phase's week (session load ×
## intensity) weighted by its weeks in the season's current layout. No ramp, lighter weeks or taper.
static func variant_load(a: Athlete, variant_id: String, year: int) -> float:
	var templates: Dictionary = Data.periodization.variants[variant_id].templates
	var total := 0.0
	var weeks := 0
	for p in Game.season.layout(year):
		var plan: Dictionary = templates[p.id]
		var week_load := 0.0
		for d in 7:
			var mult := float(Training.intensity(plan.intensity[d]).load)
			for sid in plan.days[d]:
				week_load += Training.session_load(a, Data.get_session(sid)) * mult
		total += week_load * int(p.weeks)
		weeks += int(p.weeks)
	return total / maxf(1.0, weeks)


## The lead-in to a future phase that starts on `first` (HealthSystem.projected), cached until the season plan,
## the entries or the date change (edits of the phase itself don't change what comes before it).
static func lead_in(year: int, phase_id: String, first: Dictionary) -> Dictionary:
	var h := HealthUI.system()
	if h == null:
		return {}
	var plan := Game.season.to_dict()
	var records: Dictionary = plan.seasons.duplicate()
	var key_year := str(year)
	if records.has(key_year):
		var rec: Dictionary = records[key_year].duplicate(true)
		rec.phases.erase(phase_id)
		records[key_year] = rec
	plan.seasons = records
	var key := JSON.stringify([plan, Game.entries, Game.date, first, h.day_no])
	if key != _lead_in_key:
		_lead_in = h.projected(first)
		_lead_in_key = key
	return _lead_in
