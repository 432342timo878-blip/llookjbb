class_name Training
## Weekly training simulation: a 7-day plan of sessions → fatigue (day by day) and attribute changes.
## Session data lives in data/training.json; the numbers below are model tuning, see GDD 4.2.

const DAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const MAX_SESSIONS_PER_DAY := 2
const TRAINED_CATEGORIES := ["physical", "technical", "mental"]

## Attribute gain per week at full stimulus, before trainability/headroom (≈ 3–4 points a year for a
## young athlete who trains an attribute well and is far below their ceiling).
const WEEKLY_RATE := 0.14
## Stimulus at which gains start to flatten out (diminishing returns within a week).
const SATURATION := 5.0
## Weekly stimulus below this does almost nothing (minimum effective dose).
const MIN_DOSE := 0.5
## Weekly loss for a physical attribute that wasn't trained at all.
const DETRAINING := 0.004
## Growth from puberty alone, per week, while the growth spurt lasts (puberty_share: late developers still have most of it
## to come, early ones are past it sooner).
const NATURAL_GROWTH := {"strength": 0.010, "power": 0.008, "speed": 0.006, "acceleration": 0.006, "aerobic_capacity": 0.004}
## Fatigue fades by a share each day (see daily_keep); a rest day clears this much more of it.
const REST_DAY_EXTRA := 0.10
## Above this fatigue, sessions lose effect (down to FATIGUED_MIN_EFFECT at 100).
const FATIGUE_LIMIT := 35.0
const FATIGUED_MIN_EFFECT := 0.1


## The club coach's starter days (Mon..Sun, each an Array of session ids); WeekPlan.coach() is the week plan.
static func coach_plan() -> Array:
	return Data.training.coach_plan.days.duplicate(true)


static func empty_plan() -> Array:
	var plan := []
	for i in 7:
		plan.append([])
	return plan


static func is_available(session: Dictionary, month: int) -> bool:
	return not session.has("months") or _in(month, session.months)


## How much of a session's effect the athlete gets this month (1.0, or less without a track in winter).
static func effectiveness(a: Athlete, session: Dictionary, month: int) -> float:
	if not is_available(session, month):
		return 0.0
	var season: Dictionary = Data.training.season
	if session.get("needs_track", false) and _in(month, season.track_closed_months) \
			and not a.training_base in season.track_access_bases:
		return float(season.off_track_effect)
	return 1.0


## Day intensity ids, lightest first (data/health.json).
const INTENSITIES := ["easy", "normal", "hard"]


## {name, load, effect, description} for a day intensity id; unknown ids count as Normal.
static func intensity(id: String) -> Dictionary:
	var all: Dictionary = Data.health.intensity
	return all.get(id, all.normal)


## Fatigue added by a session, after the athlete's durability.
static func session_load(a: Athlete, session: Dictionary) -> float:
	return float(session.load) * (0.9 - a.get_attr("durability") / 50.0)


## Share of fatigue still left the next day (0.6–0.8): better recovery rate and habits clear it faster.
static func daily_keep(a: Athlete) -> float:
	return 0.82 - a.get_attr("recovery_rate") / 20.0 * 0.15 - a.get_attr("professionalism") / 20.0 * 0.04


## Planned stimulus per attribute and total load, without fatigue effects. Used for the plan preview.
## `plan` is a week plan (see WeekPlan; the old plain Array of days works too): each day's intensity counts.
static func preview(a: Athlete, plan: Variant, month: int) -> Dictionary:
	var p := WeekPlan.of(plan)
	var stimulus := {}
	var load := 0.0
	for d in 7:
		var mult := intensity(p.intensity[d])
		var load_mult := float(mult.load)
		var effect_mult := float(mult.effect)
		for id in p.days[d]:
			var s := Data.get_session(id)
			var eff := effectiveness(a, s, month)
			if eff == 0.0:
				continue
			load += session_load(a, s) * load_mult
			for attr in s.effects:
				stimulus[attr] = stimulus.get(attr, 0.0) + float(s.effects[attr]) * eff * effect_mult
	return {"stimulus": stimulus, "load": load}


## Runs a whole week of the plan starting on `monday` (race days count as races without a result).
## Changes the athlete; returns the weekly report. The game itself plays WeekSim a day at a time (Game.advance_day).
static func simulate_week(a: Athlete, plan: Variant, monday: Dictionary, races := {}) -> Dictionary:
	return WeekSim.new(a, plan, monday, races).finish()

## Typical fatigue once the athlete has followed `plan` for a few weeks: {avg, peak}.
## Simulated on a copy, so the real athlete is untouched.
static func expected_fatigue(a: Athlete, plan: Variant, monday: Dictionary) -> Dictionary:
	var copy := Athlete.from_dict(a.to_dict().duplicate(true))
	var r := {}
	for w in 4:
		r = simulate_week(copy, plan, monday)
	return {"avg": r.fatigue_avg, "peak": r.fatigue_peak}


## Turns the week's stimulus into attribute changes (the week starting on `monday`). Returns attribute id ->
## {before, after}. Step 7 (GDD 4.2 "Multi-year check"): trained physical gains shrink with age (age_rate), a beginner
## responds more in their first years (novice_bonus, physical and technical), and puberty growth follows the growth
## spurt (puberty_share) instead of going on for life.
static func _apply_progression(a: Athlete, stimulus: Dictionary, monday: Dictionary) -> Dictionary:
	var trainability := 0.6 + a.get_attr("trainability") / 20.0 * 0.8
	var growth := puberty_share(a, monday)
	var novice := 1.0 + novice_bonus(a)
	var by_age := age_rate(a, monday)
	var changes := {}
	for category in TRAINED_CATEGORIES:
		for attr in Data.attributes_in(category):
			var id: String = attr.id
			var before := a.get_attr(id)
			var s: float = stimulus.get(id, 0.0)
			var gain := 0.0
			if s > MIN_DOSE:
				gain = WEEKLY_RATE * (1.0 - exp(-(s - MIN_DOSE) / SATURATION)) * trainability * _headroom(a, before)
				if category == "physical":
					gain *= by_age * novice
				elif category == "technical":
					gain *= novice
			elif category == "physical":
				gain -= DETRAINING
			gain += NATURAL_GROWTH.get(id, 0.0) * growth
			a.set_attr(id, before + gain)
			var delta := a.get_attr(id) - before
			a.recent_change[id] = a.recent_change.get(id, 0.0) * 0.75 + delta
			if delta != 0.0:
				changes[id] = {"before": before, "after": a.get_attr(id)}
	a.weeks_trained += 1
	return changes


## How much of a trained physical gain an athlete of this age still gets: 1.0 young, less from about 16 (boys) /
## 15 (girls), as real juniors' yearly improvement shrinks (data/training.json progression.age_rate, by age in years).
static func age_rate(a: Athlete, monday: Dictionary) -> float:
	var table: Array = Data.training.progression.age_rate.get(a.gender, [])
	var age := age_years(a, monday)
	if table.is_empty() or age <= float(table[0][0]):
		return 1.0 if table.is_empty() else float(table[0][1])
	for i in range(1, table.size()):
		if age <= float(table[i][0]):
			return lerpf(float(table[i - 1][1]), float(table[i][1]), (age - float(table[i - 1][0])) / (float(table[i][0]) - float(table[i - 1][0])))
	return float(table.back()[1])


## Puberty growth this week (share of NATURAL_GROWTH): full up to a year after the growth-spurt peak (the health model's
## peak age by gender and maturation, data/health.json strain.growth), then fading to nothing (progression.puberty).
static func puberty_share(a: Athlete, monday: Dictionary) -> float:
	var p: Dictionary = Data.training.progression.puberty
	var g: Dictionary = Data.health.strain.growth
	var after := age_years(a, monday) - (float(g.peak_age[a.gender]) + float(g.maturation_shift.get(a.maturation, 0.0)))
	var full := float(p.full_years_after_peak)
	var end := float(p.ends_years_after_peak)
	return clampf((end - after) / (end - full), 0.0, 1.0)


## A beginner's extra response to training (novice gains): `bonus` for an athlete with no training behind them, less with
## more experience (none from `below_experience` years), fading out over their first `fade_weeks` (progression.novice).
static func novice_bonus(a: Athlete) -> float:
	var n: Dictionary = Data.training.progression.novice
	if a.experience < 0:
		return 0.0
	var below := float(n.below_experience)
	var share := clampf((below - a.experience) / below, 0.0, 1.0)
	return float(n.bonus) * share * clampf(1.0 - a.weeks_trained / float(n.fade_weeks), 0.0, 1.0)


## Age in years (with the fraction) on `date`.
static func age_years(a: Athlete, date: Dictionary) -> float:
	return Calendar.days_between(a.birth_date, date) / 365.25


## 1.0 far below the athlete's (hidden) ceiling, shrinking towards it.
static func _headroom(a: Athlete, value: float) -> float:
	return clampf((a.get_attr("potential") - value) / 5.0, 0.05, 1.0)


## Word and colour for a fatigue level.
static func fatigue_state(fatigue: float) -> Array:
	if fatigue < 25.0:
		return ["Fresh", Palette.ATTR_EXCELLENT]
	if fatigue < 45.0:
		return ["Normal", Palette.ATTR_GOOD]
	if fatigue < 65.0:
		return ["Tired", Palette.ATTR_AVERAGE]
	return ["Exhausted", Palette.ATTR_POOR]


## JSON numbers load as floats, so compare month lists numerically.
static func _in(month: int, months: Array) -> bool:
	for m in months:
		if int(m) == month:
			return true
	return false
