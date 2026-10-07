class_name SeasonSystem
extends GameSystem
## The club coach's season events (GDD 4.8, M2 step 6f), GameSystem id "season":
##   - the offer "Your coach has three plans for the season": a stop event when a career starts on the coach's ★
##     plan (Game.start_career), and each autumn, `offer.weeks_before` weeks before the next season starts, for that
##     season (season mode only). The answer is a plan id or "later"; any other answer counts as "later".
##   - the season rollover, on the evening before a new season's first Monday: a season the player didn't choose
##     a plan for gets the coach's ★ of that day; its target meets are entered where allowed.
##   - easing back in (the return block): after `return_block.min_days` days in a row without running, on the
##     evening before the first day with an allowed run in the plan, "Easing back in" (accept / decline), once per
##     layoff. Accepting puts the block into Game.season (SeasonPlan.start_return).
## All rules, numbers and texts are in data/periodization.json ("offer", "return_block").

## Dev tools that play many seasons can switch the offers off (no stop events; the rollover still happens).
static var offers_enabled := true

var decided := {}            # season year -> true: the player chose a plan for it (offer or Training tab)
var offered := {}            # season year -> true: the autumn offer for it was posted
var rolled := {}             # season year -> true: its start was handled (plan, entries)
var layoff_offered := false  # easing back in was offered for the current stretch without running


func _init() -> void:
	id = "season"


# --- The day loop ----------------------------------------------------------------------------------------

## The autumn offer for next season, before the day is played.
func on_day_start(ctx: Dictionary) -> void:
	if not offers_enabled or Game.season.mode != SeasonPlan.PHASES:
		return
	var next := SeasonPlan.year_of(ctx.date) + 1
	if offered.has(next) or decided.has(next):
		return
	var from := Game.add_days(SeasonPlan.season_start(next), -7 * int(Data.periodization.offer.weeks_before))
	if Calendar.date_key(ctx.date) >= Calendar.date_key(from):
		offered[next] = true
		offer(next)


## Evening: the season rollover (tomorrow a new season starts) and the return block's offer.
func on_day_end(ctx: Dictionary) -> void:
	var tomorrow := Game.add_days(ctx.date, 1)
	var year := SeasonPlan.year_of(tomorrow)
	if Calendar.date_key(tomorrow) == Calendar.date_key(SeasonPlan.season_start(year)):
		roll_over(year)
	_check_layoff(tomorrow)


func on_answer(event: Dictionary, choice: String) -> void:
	match str(event.get("kind", "")):
		"offer":
			if is_plan(choice):
				choose(int(event.year), choice)
		"return":
			if choice == "accept":
				Game.season.start_return(Game.int_date(event.start), int(event.days_out))
				Game.current_week()   # this week (or the next) takes the block
				var h := Game.get_system("health") as HealthSystem
				if h:
					h.refresh()


static func is_plan(id: String) -> bool:
	return not id.begins_with("_") and Data.periodization.variants.has(id)


# --- The coach's three plans -------------------------------------------------------------------------------

## Posts the offer for season `year` (a stop event). On a new career's first day it is about the season it starts.
func offer(year: int) -> Dictionary:
	var cfg: Dictionary = Data.periodization.offer
	var a := Game.athlete
	var first := year == SeasonPlan.year_of(Game.date)
	var pick := SeasonPlan.coach_pick(a, Game.date, Game.get_system("health") as HealthSystem)
	var fill := {"season": season_label(year), "targets": targets_text(year),
			"age_class": Calendar.age_class(a, year + 1), "date": Calendar.format_day(SeasonPlan.season_start(year))}
	var title := str(cfg.title_first if first else cfg.title_next).format(fill)
	var text := str(cfg.text_first if first else cfg.text_next).format(fill)
	var choices := []
	for v in plan_order(pick):
		choices.append({"id": v, "label": str(cfg.use).format({"plan": Data.periodization.variants[v].name}), "detail": ""})
	choices.append({"id": "later", "label": str(cfg.later), "detail": ""})
	var e := Game.post_event(id, title, text, choices, true)
	e.kind = "offer"
	e.year = year
	e.pick = pick
	e.first = first
	return e


## The coach's plans with the ★ first (a tool that answers the first choice takes the ★).
static func plan_order(pick: String) -> Array:
	var ids := ["steady", "balanced", "ambitious"]
	ids.erase(pick)
	ids.push_front(pick)
	return ids


## The player chose plan `variant_id` for season `year` (the offer or the Training tab): the season runs on it and
## its target meets are entered where allowed.
func choose(year: int, variant_id: String) -> void:
	if not is_plan(variant_id):
		return
	if Game.season.variant(year) != variant_id or not Game.season.seasons.has(year):
		Game.season.set_variant(year, variant_id)
	decided[year] = true
	enter_targets(year)
	Game.current_week()
	var h := Game.get_system("health") as HealthSystem
	if h:
		h.refresh()


## A new season starts tomorrow: without the player's choice it runs on the coach's ★ of today; its targets are
## entered where allowed. Once per season, season mode only, never the career's first season.
func roll_over(year: int) -> void:
	var s := Game.season
	if s.mode != SeasonPlan.PHASES or year <= s.first_season or rolled.has(year):
		return
	rolled[year] = true
	if not decided.has(year):
		s.set_variant(year, SeasonPlan.coach_pick(Game.athlete, Game.date, Game.get_system("health") as HealthSystem))
	enter_targets(year)


func enter_targets(year: int) -> void:
	for key in Game.season.targets(year):
		var m := Calendar.get_meet(key)
		if not m.is_empty() and Calendar.can_enter(Game.athlete, m, Game.date).ok:
			Game.enter(key)


## The autumn window: from the offer day until next season starts, the Training tab shows next season's plans.
## Returns that season's year, or 0 outside the window (or in repeat mode).
static func next_season_open(today: Dictionary) -> int:
	if Game.season.mode != SeasonPlan.PHASES:
		return 0
	var next := SeasonPlan.year_of(today) + 1
	var from := Game.add_days(SeasonPlan.season_start(next), -7 * int(Data.periodization.offer.weeks_before))
	return next if Calendar.date_key(today) >= Calendar.date_key(from) else 0


## "2027–28"
static func season_label(year: int) -> String:
	return "%d–%s" % [year, str(year + 1).right(2)]


## "SM-hallit 14-15 (13 Feb) and Nuorten SM 14-15 (6 Aug)"
static func targets_text(year: int) -> String:
	var names := []
	for key in Game.season.targets(year):
		var m := Calendar.get_meet(key)
		if not m.is_empty():
			names.append("%s (%d %s)" % [m.name, int(m.date.day), Calendar.MONTHS_SHORT[int(m.date.month) - 1]])
	if names.is_empty():
		return str(Data.periodization.offer.no_targets)
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, -1)) + " and " + names[-1]


# --- Easing back in ------------------------------------------------------------------------------------------

func _check_layoff(tomorrow: Dictionary) -> void:
	var h := Game.get_system("health") as HealthSystem
	if h == null or not HealthSystem.model_enabled or not h.started:
		return
	if h.days_without_running == 0:
		layoff_offered = false
		return
	var cfg: Dictionary = Data.periodization.return_block
	if layoff_offered or h.days_without_running < int(cfg.min_days) or Game.season.return_ahead(tomorrow):
		return
	if not h.running_allowed(1) or not _runs_on(tomorrow):
		return
	layoff_offered = true
	_post_return(h, tomorrow)


## The plan has a run (or an entered race) on `date`.
func _runs_on(date: Dictionary) -> bool:
	var monday := Calendar.monday_of(date)
	var d := Calendar.weekday(date)
	if Calendar.races_in_week(Game.entries, monday).has(d):
		return true
	var tag := str(Data.periodization.return_block.run_tag)
	for sid in Game.season.week_for(monday).days[d]:
		if tag in Data.get_session(sid).get("tags", []):
			return true
	return false


## The "Easing back in" stop event, with what the panel shows: the weeks, the plan risk with and without the
## block (from the body now), the entered races in the block and the injury that kept the athlete off running.
func _post_return(h: HealthSystem, start: Dictionary) -> void:
	var days_out := h.days_without_running
	var trial := Game.season.copy()
	trial.start_return(start, days_out)
	var kinds: Array = trial.return_block.kinds
	var monday := Calendar.monday_of(start)
	var full := []
	var eased := []
	for w in int(Data.health.plan_risk.weeks):
		var m := Game.add_days(monday, 7 * w)
		full.append(WeekPlan.copy_of(Game.season.week_for(m)))
		eased.append(WeekPlan.copy_of(trial.week_for(m)))
	for d in Calendar.weekday(start):   # the days before the first day back are the layoff's, in both
		full[0].days[d] = []
		eased[0].days[d] = []
	var from := {"monday": monday}
	var last := trial.return_last_day()
	var races := []
	for m in Calendar.meets_between(start, last):
		if m.key in Game.entries:
			races.append(m.key)
	var after := Game.add_days(last, 1)
	var plan_after := Game.season.week_for(Calendar.monday_of(after))
	var ui: Dictionary = Data.periodization.return_block.ui
	var cause := _layoff_cause(h, days_out)
	var text := str(ui.text).format({"days": days_out, "weeks": kinds.size(),
			"cause": str(ui.cause).format({"name": cause}) if cause != "" else ""})
	var e := Game.post_event(id, str(ui.title), text,
			[{"id": "accept", "label": str(ui.accept), "detail": str(ui.accept_detail)},
			{"id": "decline", "label": str(ui.decline), "detail": str(ui.decline_detail)}], true)
	e.kind = "return"
	e.start = start.duplicate()
	e.days_out = days_out
	e.kinds = kinds.duplicate()
	e.cause = cause
	var without := h.weeks_expected(full, from)
	var with_block := h.weeks_expected(eased, from)
	e.risk_full = HealthSystem.risk_word(without)
	e.risk_block = HealthSystem.risk_word(with_block)
	# The words are coarse: when both read the same, the panel says whether the block still makes it much safer.
	e.much_safer = with_block <= without * float(Data.periodization.return_block.much_safer)
	e.races = races
	e.phase_after = str(plan_after.get("phase", ""))


## The injury (not an illness) that most likely kept the athlete off running: one still active, or healed during
## the layoff; the worst tier first, then the latest to heal. (An injury that got worse keeps its first start date,
## so the start can't be used.) "" when there is none (the player's own break).
func _layoff_cause(h: HealthSystem, days_out: int) -> String:
	var tiers := ["niggle", "injury", "serious"]
	var best := {}
	for inj in h.history + h.injuries:
		if not inj.tier in tiers:
			continue
		if inj.has("healed") and Calendar.days_between(inj.healed, Game.date) > days_out:
			continue
		if best.is_empty() or tiers.find(inj.tier) > tiers.find(best.tier) \
				or (inj.tier == best.tier and not inj.has("healed")):
			best = inj
	return "" if best.is_empty() else str(Data.get_injury(best.id).name)


# --- Save / load ---------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if decided.is_empty() and offered.is_empty() and rolled.is_empty() and not layoff_offered:
		return {}
	return {"decided": decided.keys(), "offered": offered.keys(), "rolled": rolled.keys(), "layoff_offered": layoff_offered}


func from_dict(d: Dictionary) -> void:
	for key in ["decided", "offered", "rolled"]:
		var into: Dictionary = get(key)
		for y in d.get(key, []):
			into[int(y)] = true
	layoff_offered = bool(d.get("layoff_offered", false))
