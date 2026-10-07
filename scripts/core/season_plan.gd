class_name SeasonPlan
extends RefCounted
## The player's training plan over time (GDD 4.8). Two modes:
## - "repeat": one week plan that repeats every week (the M1 behaviour, `repeat_week`).
## - "phases": the training year as phases tied to the target meets (data/periodization.json). Per season
##   (Nov–Oct) a record keeps the targets, the player's moves of the phase edges and the edited phase weeks;
##   a season without a record is the coach's unedited plan, so every week of every season has a plan.
## `week_for` is the one place the game asks "what is the plan for this week?". It is a pure function of this
## plan, the entries and the date (no dice), so the strip, the day editor, the health model and the saved
## game all see the same week.

const REPEAT := "repeat"
const PHASES := "phases"
const WHY_JOINER := " · "

var mode := REPEAT
var repeat_week: Dictionary = WeekPlan.empty()   # a week plan, see WeekPlan (Game.start_career puts the coach's in)
## Phases mode: who the plan is for (the main championships and the targets depend on the age class and event),
## and the first season of the career (its first phase ramps up from the coach's starter week).
var birth_year := 0
var event := ""
var first_season := 0
## season year (int, the year it starts in) -> record:
## {"variant": id, "targets": null (the coach's) or [meet keys], "shifts": {phase id: weeks},
##  "phases": {phase id: {"week": a week plan, "lighter": bool, "ramp_weeks": int}}} (only what was changed)
var seasons := {}

var _derived := {}   # season year -> {"targets": [...], "layout": [...]}; worked out on demand, never saved


# --- Making one --------------------------------------------------------------------------------

## A repeat-mode season with the given weekly plan (a week plan or the old plain Array of days).
static func repeating(plan: Variant) -> SeasonPlan:
	var s := SeasonPlan.new()
	s.repeat_week = WeekPlan.copy_of(plan)
	return s


## A phases-mode season for this athlete, starting on the coach's plan of the season `start` is in.
static func phased(athlete: Athlete, start: Dictionary, variant := "") -> SeasonPlan:
	var s := SeasonPlan.new()
	s.mode = PHASES
	s.repeat_week = WeekPlan.coach()
	s.birth_year = int(athlete.birth_date.year)
	s.event = athlete.main_event
	s.first_season = year_of(start)
	s.seasons[s.first_season] = _new_record(variant)
	return s


## The coach's ★ plan (GDD 4.8), from what the player can see: durability and professionalism as shown (whole
## numbers) and the injuries of the last months (`health` = the HealthSystem, or null: none). Limits in the data.
static func coach_pick(athlete: Athlete, today: Dictionary, health: HealthSystem = null) -> String:
	var rule: Dictionary = Data.periodization.coach_pick
	var durability := roundi(athlete.get_attr("durability"))
	if durability <= int(rule.steady.durability_max) \
			or _injuries_within(health, today, int(rule.steady.months)) >= int(rule.steady.injuries):
		return "steady"
	if durability >= int(rule.ambitious.durability_min) \
			and roundi(athlete.get_attr("professionalism")) >= int(rule.ambitious.professionalism_min) \
			and _injuries_within(health, today, int(rule.ambitious.injury_free_months)) == 0:
		return "ambitious"
	return "balanced"


## Injuries of the tiers the coach counts that started in the last `months` months (a month = 365 / 12 days).
static func _injuries_within(health: HealthSystem, today: Dictionary, months: int) -> int:
	if health == null:
		return 0
	var tiers: Array = Data.periodization.coach_pick.tiers
	var count := 0
	for inj in health.history + health.injuries:
		if inj.tier in tiers and Calendar.days_between(inj.started, today) < months * 365.0 / 12.0:
			count += 1
	return count


## The coach's plan a season runs on ("steady" / "balanced" / "ambitious"). A season nobody has touched keeps
## the plan of the season before it (until the autumn offer, step 6f, makes a record for it).
func variant(year: int) -> String:
	return str(_record(year).variant)


## Puts a season on another of the coach's plans. The player's phase weeks of that season are dropped (the new
## plan replaces them, GDD 4.8); targets and moved edges stay.
func set_variant(year: int, id: String) -> void:
	if id.begins_with("_") or not Data.periodization.variants.has(id):
		return
	var rec := _record_for_edit(year)
	rec.variant = id
	rec.phases = {}


## How many phases of a season the player has changed (for the "This replaces your changes to N phases" warning).
func edited_phases(year: int) -> int:
	return layout(year).filter(func(p): return is_edited(year, p.id)).size()


## The player turns off the season plan: this week's phase plan becomes the repeating week.
func switch_to_repeat(monday: Dictionary) -> void:
	if mode == PHASES:
		repeat_week = phase_base(monday)
	mode = REPEAT


# --- Seasons and weeks -------------------------------------------------------------------------

## The Monday a season starts on: the Monday nearest to 1 November (2 Nov 2026, 1 Nov 2027, 30 Oct 2028).
static func season_start(year: int) -> Dictionary:
	var cfg: Dictionary = Data.periodization.season
	var first := {"year": year, "month": int(cfg.start_month), "day": int(cfg.start_day)}
	var wd := Calendar.weekday(first)
	return Game.add_days(first, -wd if wd <= 3 else 7 - wd)


## The season (named after the year it starts in) a date belongs to.
static func year_of(date: Dictionary) -> int:
	var y := int(date.year)
	return y if Calendar.date_key(date) >= Calendar.date_key(season_start(y)) else y - 1


static func season_weeks(year: int) -> int:
	return roundi(Calendar.days_between(season_start(year), season_start(year + 1)) / 7.0)


## Whole weeks from the season's first Monday to `monday`.
static func week_no(year: int, monday: Dictionary) -> int:
	return roundi(Calendar.days_between(season_start(year), monday) / 7.0)


static func phase_type(id: String) -> Dictionary:
	for p in Data.periodization.phases:
		if p.id == id:
			return p
	return {}


## The week plan for the week starting on `monday`. Repeat mode: the repeating plan itself (edits go straight
## into it). Phases mode: a new week plan {days, intensity, why (per day, "" or a reason), phase, phase_week
## (1-based), phase_weeks, kind (normal / lighter / taper), target (the meet a taper counts down to, or "")},
## built in this order: the phase's week, ramp, lighter week, easy day before a race, taper.
func week_for(monday: Dictionary, entries: Variant = null) -> Dictionary:
	if mode != PHASES:
		return repeat_week
	var cfg: Dictionary = Data.periodization
	var ents: Array = entries if entries != null else Game.entries
	var year := maxi(year_of(monday), first_season)
	var w := maxi(0, week_no(year, monday))
	var lay := layout(year)
	var idx := lay.size() - 1
	for i in lay.size():
		if w < int(lay[i].start) + int(lay[i].weeks):
			idx = i
			break
	var ph: Dictionary = lay[idx]
	var k := w - int(ph.start)
	var type := phase_type(ph.id)

	# 1. The phase's week.
	var base := WeekPlan.copy_of(_phase_week(year, ph.id))
	var days: Array = base.days
	var level: Array = base.intensity
	var why := ["", "", "", "", "", "", ""]

	# 2. Ramp: the first days of the first ramp weeks are still the previous phase's.
	var ramp := _ramp_weeks(year, ph.id)
	if ramp > 1 and k < ramp:
		var prev := WeekPlan.copy_of(_previous_week(year, idx))
		for d in range(roundi((k + 1) * 7.0 / ramp), 7):
			if days[d] != prev.days[d] or level[d] != prev.intensity[d]:
				days[d] = prev.days[d]
				level[d] = prev.intensity[d]
				_add_why(why, d, str(cfg.ramp.why).format({"week": k + 1, "weeks": ramp}))

	# 3. Lighter week (not in a taper week).
	var kind := "normal"
	var taper := _taper_days(year, monday)
	if _lighter(year, ph.id) and taper.is_empty() and (k + 1) % int(cfg.lighter.every) == 0:
		for d in 7:
			var lower := clampi(Training.INTENSITIES.find(level[d]) - int(cfg.lighter.step_down), 0, Training.INTENSITIES.size() - 1)
			if Training.INTENSITIES[lower] != level[d]:
				level[d] = Training.INTENSITIES[lower]
				_add_why(why, d, str(cfg.lighter.why))
		kind = "lighter"

	# 4. Easy day before an entered race (race phases only).
	var races := Calendar.races_in_week(ents, monday)
	if type.get("race_phase", false):
		var easy: Dictionary = cfg.easy_day_before_race
		for d in 6:
			if races.has(d + 1) and not races.has(d) and not days[d].is_empty() and level[d] != easy.intensity:
				level[d] = easy.intensity
				_add_why(why, d, str(easy.why))

	# 5. Taper.
	var target := ""
	if not taper.is_empty():
		kind = "taper"
		for d in taper:
			if not races.has(d):
				_apply_taper(days, level, why, d, taper[d], cfg.taper)
		target = str(taper[taper.keys()[0]].meet.key)

	return {"days": days, "intensity": level, "why": why, "phase": ph.id, "phase_week": k + 1,
			"phase_weeks": int(ph.weeks), "kind": kind, "target": target}


## The phase's own week for the week starting on `monday`, before any rule (ramp, lighter, taper…): what
## "one repeating week" becomes when the player switches the season plan off.
func phase_base(monday: Dictionary) -> Dictionary:
	if mode != PHASES:
		return repeat_week
	var year := maxi(year_of(monday), first_season)
	var lay := layout(year)
	return WeekPlan.copy_of(_phase_week(year, str(lay[_phase_index(lay, maxi(0, week_no(year, monday)))].id)))


func _phase_index(lay: Array, w: int) -> int:
	for i in lay.size():
		if w < int(lay[i].start) + int(lay[i].weeks):
			return i
	return lay.size() - 1


## Previous phase's week for the ramp: the phase before, the last phase of the season before, or at the start
## of the career the coach's starter week.
func _previous_week(year: int, idx: int) -> Dictionary:
	if idx > 0:
		return _phase_week(year, str(layout(year)[idx - 1].id))
	if year > first_season:
		var before := layout(year - 1)
		return _phase_week(year - 1, str(before[before.size() - 1].id))
	return WeekPlan.coach()


## Adds a reason to a day; a day with several rules shows them all.
func _add_why(why: Array, d: int, text: String) -> void:
	why[d] = text if why[d] == "" else why[d] + WHY_JOINER + text


## day (0–6) -> {"off": days to the race, "meet": meet} for the days of this week inside a taper (the nearest
## coming target of the season counts).
func _taper_days(year: int, monday: Dictionary) -> Dictionary:
	var result := {}
	var length := int(Data.periodization.taper.days)
	var meets := []
	for key in targets(year):
		var m := Calendar.get_meet(key)
		if not m.is_empty():
			meets.append(m)
	if meets.is_empty():
		return result
	for m in meets:
		var ahead := Calendar.days_between(monday, m.date)   # days from Monday to the race
		if ahead < 1 or ahead > 6 + length:
			continue
		for d in 7:
			var off := ahead - d
			if off >= 1 and off <= length and (not result.has(d) or off < int(result[d].off)):
				result[d] = {"off": off, "meet": m}
	return result


## One taper day: the first band that holds the day's distance to the race.
func _apply_taper(days: Array, level: Array, why: Array, d: int, info: Dictionary, taper: Dictionary) -> void:
	for band in taper.bands:
		if info.off > int(band.from) or info.off < int(band.to):
			continue
		var before_days: Array = days[d].duplicate()
		var before_level: String = level[d]
		if band.get("rest", false):
			days[d] = []
		elif not days[d].is_empty():
			if band.has("sessions"):
				days[d] = band.sessions.map(func(id): return str(id))
			if band.has("replace"):
				days[d] = days[d].map(func(id): return str(band.replace.get(id, id)))
			if band.has("max_sessions") and days[d].size() > int(band.max_sessions):
				days[d] = [_best_session(days[d], taper.keep_tags)]
			if band.has("intensity") and not days[d].is_empty():
				level[d] = str(band.intensity)
		if days[d] != before_days or level[d] != before_level:
			_add_why(why, d, str(band.why).format({"meet": info.meet.name, "days": info.off}))
		return


## The session worth keeping on a taper day: the first one that has the first tag of `keep_tags`, else the
## second tag and so on; the first listed on a tie.
func _best_session(ids: Array, keep_tags: Array) -> String:
	var best := ""
	var best_rank := keep_tags.size() + 1
	for id in ids:
		var tags: Array = Data.get_session(id).get("tags", [])
		var rank := keep_tags.size()
		for i in keep_tags.size():
			if keep_tags[i] in tags:
				rank = i
				break
		if rank < best_rank:
			best = id
			best_rank = rank
	return best


# --- Phases of a season --------------------------------------------------------------------------

## The phases of a season in order: [{id, start (weeks from the season start), weeks}]. Phases without an
## anchor are left out; phases always start on a Monday and last at least min_phase_weeks.
func layout(year: int) -> Array:
	var cache := _cache(year)
	if cache.has("layout"):
		return cache.layout
	var raw := _raw_starts(year)
	var total := season_weeks(year)
	var least := int(Data.periodization.season.min_phase_weeks)
	var n := raw.size()
	for i in range(1, n):
		raw[i].start = maxi(raw[i].start, raw[i - 1].start + least)
	for i in range(n - 1, 0, -1):
		raw[i].start = mini(raw[i].start, total - (n - i) * least)
	for i in range(1, n):
		raw[i].start = maxi(raw[i].start, raw[i - 1].start + least)
	var result := []
	for i in n:
		var end: int = raw[i + 1].start if i + 1 < n else total
		result.append({"id": raw[i].id, "start": raw[i].start, "weeks": end - int(raw[i].start)})
	cache.layout = result
	return result


## Where each phase would start before the minimum length is enforced: [{id, start}].
func _raw_starts(year: int) -> Array:
	var anchors := {"season_start": {"week": 0, "real": true}, "indoor": _anchor_week(year, "indoor"),
			"outdoor": _anchor_week(year, "outdoor")}
	var out := []
	for p in Data.periodization.phases:
		var needs: String = p.get("omit_without", "")
		if needs != "" and not anchors[needs].real:
			continue
		var start := 0
		if not out.is_empty():
			start = int(anchors[p.start.ref].week) + int(p.start.weeks) + shift_of(year, p.id)
		out.append({"id": p.id, "start": start})
	return out


## Every phase still has its minimum length with the moves of the player.
func _feasible(year: int) -> bool:
	var raw := _raw_starts(year)
	var least := int(Data.periodization.season.min_phase_weeks)
	for i in range(1, raw.size()):
		if raw[i].start < raw[i - 1].start + least:
			return false
	return raw[raw.size() - 1].start <= season_weeks(year) - least


## {"week": the Monday's week of the anchor meet, "real": there is such a meet, "key": the meet}: the first
## target of the kind in the target list; with none (the player took it off), the coach's pick (the main
## championship, else the highest-level ★ meet); with no meet at all, a fallback date from the data (only used
## for the edges of the phases, the phase of that kind is left out).
func _anchor_week(year: int, kind: String) -> Dictionary:
	for list in [targets(year), _default_targets(year)]:
		for key in list:
			var m := Calendar.get_meet(key)
			if not m.is_empty() and bool(m.get("indoor", false)) == (kind == "indoor"):
				return {"week": week_no(year, Calendar.monday_of(m.date)), "real": true, "key": key}
	var fb: Dictionary = Data.periodization.anchor_fallback[kind]
	var d := {"year": year + 1, "month": int(fb.month), "day": int(fb.day)}
	return {"week": week_no(year, Calendar.monday_of(d)), "real": false, "key": ""}


## Moves the start of a phase by whole weeks (±shift_limit, the first phase can't move) as far as every phase
## keeps its minimum length. Returns the shift that was applied.
func set_shift(year: int, phase_id: String, weeks: int) -> int:
	var lay := layout(year)
	if lay.is_empty() or lay[0].id == phase_id or not lay.any(func(p): return p.id == phase_id):
		return 0
	var limit := int(Data.periodization.season.shift_limit)
	var w := clampi(weeks, -limit, limit)
	var rec := _record_for_edit(year)
	while w != 0:
		rec.shifts[phase_id] = w
		_invalidate(year)
		if _feasible(year):
			return w
		w -= signi(w)
	rec.shifts.erase(phase_id)
	_invalidate(year)
	return 0


func shift_of(year: int, phase_id: String) -> int:
	return int(_record(year).shifts.get(phase_id, 0))


# --- Targets ---------------------------------------------------------------------------------------

## The target meets of a season (keys), most important first: the first indoor and the first outdoor target
## are the anchors of the phases, others only get a taper. Without the player's own list: the coach's.
func targets(year: int) -> Array:
	var rec := _record(year)
	if rec.targets != null:
		return rec.targets.duplicate()
	return _default_targets(year).duplicate()


func set_targets(year: int, keys: Array) -> void:
	var list := []
	for key in keys:
		if not str(key) in list and not Calendar.get_meet(str(key)).is_empty() and list.size() < int(Data.periodization.season.max_targets):
			list.append(str(key))
	_record_for_edit(year).targets = list
	_invalidate(year)


func add_target(year: int, key: String) -> bool:
	var list := targets(year)
	if key in list or list.size() >= int(Data.periodization.season.max_targets) or Calendar.get_meet(key).is_empty():
		return false
	list.append(key)
	set_targets(year, list)
	return true


func remove_target(year: int, key: String) -> void:
	var list := targets(year)
	list.erase(key)
	set_targets(year, list)


## Withdrawing from or scratching a target takes it off the target list (GDD 4.8).
func on_withdraw(meet_key: String) -> void:
	if mode != PHASES:
		return
	var m := Calendar.get_meet(meet_key)
	if m.is_empty():
		return
	var year := year_of(m.date)
	if meet_key in targets(year):
		remove_target(year, meet_key)


## The coach's targets: for indoor and outdoor the season's main championship the athlete can enter, or, with
## none, the highest-level coach meet (★) of that season part; with none, no target of that kind.
func _default_targets(year: int) -> Array:
	var cache := _cache(year)
	if cache.has("targets"):
		return cache.targets
	var meets := Calendar.meets_between(season_start(year), Game.add_days(season_start(year + 1), -1))
	var result := []
	for kind in ["indoor", "outdoor"]:
		var key := _pick_main(meets, kind)
		if key != "":
			result.append(key)
	cache.targets = result
	return result


func _pick_main(meets: Array, kind: String) -> String:
	for m in meets:
		if m.get("main", "") == kind and _can_target(m):
			return m.key
	var order: Array = Data.competitions.levels.keys()
	var best := ""
	var best_rank := -1
	for m in meets:
		if bool(m.get("indoor", false)) != (kind == "indoor") or not m.get("coach", false) or not _can_target(m):
			continue
		var rank := order.find(m.level)
		if rank > best_rank:
			best = m.key
			best_rank = rank
	return best


## A meet the athlete could race in their main event (not a watch-only one).
func _can_target(meet: Dictionary) -> bool:
	if meet.get("watch", false) or not event in meet.events:
		return false
	var age := int(meet.date.year) - birth_year
	return age >= int(meet.ages[0]) and age <= int(meet.ages[1])


# --- Phase weeks and settings ------------------------------------------------------------------------

## The phase's week plan (the player's own or the variant's template). Not a copy.
func _phase_week(year: int, phase_id: String) -> Dictionary:
	var rec := _record(year)
	var stored: Dictionary = rec.phases.get(phase_id, {})
	if stored.has("week"):
		return stored.week
	return Data.periodization.variants[rec.variant].templates[phase_id]


## The phase's week to edit in place (a copy of the template is stored on the first call).
func edit_phase(year: int, phase_id: String) -> Dictionary:
	var state := _phase_state(year, phase_id)
	if not state.has("week"):
		state.week = WeekPlan.copy_of(_phase_week(year, phase_id))
	return state.week


## True when the player has changed the phase's week, its lighter weeks or its ramp from the coach's.
func is_edited(year: int, phase_id: String) -> bool:
	var stored: Dictionary = _record(year).phases.get(phase_id, {})
	if stored.has("week") and not WeekPlan.equals(stored.week, Data.periodization.variants[_record(year).variant].templates[phase_id]):
		return true
	return (stored.has("lighter") and bool(stored.lighter) != bool(phase_type(phase_id).get("lighter", false))) \
			or (stored.has("ramp_weeks") and int(stored.ramp_weeks) != _variant_ramp(year, phase_id))


## Back to the coach's week, lighter weeks and ramp for the phase.
func reset_phase(year: int, phase_id: String) -> void:
	_record_for_edit(year).phases.erase(phase_id)


func set_lighter(year: int, phase_id: String, on: bool) -> void:
	_phase_state(year, phase_id).lighter = on


func set_ramp_weeks(year: int, phase_id: String, weeks: int) -> void:
	_phase_state(year, phase_id).ramp_weeks = maxi(1, weeks)


func _lighter(year: int, phase_id: String) -> bool:
	var stored: Dictionary = _record(year).phases.get(phase_id, {})
	return bool(stored.get("lighter", phase_type(phase_id).get("lighter", false)))


func _ramp_weeks(year: int, phase_id: String) -> int:
	var stored: Dictionary = _record(year).phases.get(phase_id, {})
	return int(stored.get("ramp_weeks", _variant_ramp(year, phase_id)))


func _variant_ramp(year: int, phase_id: String) -> int:
	return int(Data.periodization.variants[_record(year).variant].ramp_weeks.get(phase_id, 1))


func _phase_state(year: int, phase_id: String) -> Dictionary:
	var rec := _record_for_edit(year)
	if not rec.phases.has(phase_id):
		rec.phases[phase_id] = {}
	return rec.phases[phase_id]


# --- Records ---------------------------------------------------------------------------------------

static func _new_record(variant := "") -> Dictionary:
	var id: String = variant if variant != "" else str(Data.periodization.season.default_variant)
	return {"variant": id, "targets": null, "shifts": {}, "phases": {}}


## The season's record, or a fresh coach's one (not stored) for a season nobody has touched, on the plan of the
## latest season before it.
func _record(year: int) -> Dictionary:
	return seasons[year] if seasons.has(year) else _new_record(_inherited_variant(year))


func _record_for_edit(year: int) -> Dictionary:
	if not seasons.has(year):
		seasons[year] = _new_record(_inherited_variant(year))
	return seasons[year]


func _inherited_variant(year: int) -> String:
	var best := -1
	for y in seasons:
		if y < year and y > best:
			best = y
	return str(seasons[best].variant) if best >= 0 else ""


func _cache(year: int) -> Dictionary:
	if not _derived.has(year):
		_derived[year] = {}
	return _derived[year]


func _invalidate(year: int) -> void:
	_derived.erase(year)


# --- Save / load -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var records := {}
	for year in seasons:
		records[str(year)] = seasons[year]
	return {"mode": mode, "repeat_week": repeat_week, "birth_year": birth_year, "event": event,
			"first_season": first_season, "seasons": records}


static func from_dict(d: Dictionary) -> SeasonPlan:
	var s := SeasonPlan.new()
	var week = d.get("repeat_week", {})
	s.repeat_week = WeekPlan.make(week.get("days", []), week.get("intensity", [])) if week is Dictionary and not week.is_empty() \
			else WeekPlan.coach()
	var saved = d.get("seasons", {})
	if saved is Dictionary:
		for key in saved:
			s.seasons[int(key)] = _clean_record(saved[key])
	s.birth_year = int(d.get("birth_year", 0))
	s.event = str(d.get("event", ""))
	s.first_season = int(d.get("first_season", 0))
	# Phases mode needs the seasons and who it is for; anything else (older saves too) is repeat mode.
	s.mode = PHASES if str(d.get("mode", REPEAT)) == PHASES and s.seasons.has(s.first_season) and s.birth_year > 0 else REPEAT
	return s


## A saved season record with numbers as ints again (JSON makes every number a float).
static func _clean_record(saved: Dictionary) -> Dictionary:
	var rec := _new_record(str(saved.get("variant", "")))
	var targets = saved.get("targets")
	if targets is Array:
		rec.targets = targets.map(func(key): return str(key))
	for id in saved.get("shifts", {}):
		rec.shifts[str(id)] = int(saved.shifts[id])
	for id in saved.get("phases", {}):
		var from: Dictionary = saved.phases[id]
		var state := {}
		if from.has("week"):
			state.week = WeekPlan.make(from.week.get("days", []), from.week.get("intensity", []))
		if from.has("lighter"):
			state.lighter = bool(from.lighter)
		if from.has("ramp_weeks"):
			state.ramp_weeks = int(from.ramp_weeks)
		rec.phases[str(id)] = state
	return rec
