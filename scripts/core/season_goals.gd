class_name SeasonGoals
extends GameSystem
## The coach's season goals (GDD 4.9.2 "Season goals with times", session C5; GDD 4.10 decision 3 and "L3b2's questions", session
## L3b2), GameSystem id "goals". The goals are agreed with the coach on a CARD on the Sunday planner, never a stop: the first week of
## a career (once its plan is chosen) and from the autumn plan choice until the season starts. The card is a MENU: the TIME goal
## always, then any two more (two milestones, or a milestone and a habit) from FAMILIES: a standard of your age class, a place at a
## meet that has one (your targets, any national / international meet you entered, the district championships), three races under a
## time, a habit. Each family is a short list of levels from easy to hard with the level HE would pick (★). He estimates what you can
## run at the season's peak by playing the season plan forward on a copy of the career (CoachVerdict.simulate), seen through his
## judging ability (a poor judge sets goals that are too easy or too hard); his picks follow his demands and `lean` (what you told
## him). Left open, the card sets his picks on the date it names. The player decides; nothing is set without a button or that date.
## STAKES (only what the game really does; data/goals.json stakes): met = trust up (more above his ★), confidence and motivation up;
## a met Stretch, Dream or far-away goal moves next season's ★ up a step; a met milestone makes him put you up for a bigger meet
## (CoachSuggests.put_up, a suggestion card). Missed = confidence a little down, never trust. Two REVIEWS (the week after the indoor
## target, the juhannus week) are a section of that Sunday's planner: on track / adjust / drop. The season's end is a planner
## section too (C5's review stop is gone; K1's chapter will show the same record). Every effect is logged (`news`) for the week
## report's causes (WeekCauses.goal_rows). Numbers and texts: data/goals.json. Static `enabled` is OFF unless the app shell switches
## it on (GameConfig `goals`), so the tools that play seasons are unchanged (tools/goals_check.gd tests it on). Own state is saved
## only once a goal was ever offered (older careers save as before).

static var enabled := false

const LOG_KEEP := 40

var seasons := {}   # season year -> {offered, set, reviewed, est ({real, seen, peak}), goals: [goal], reviews: {id: review}, end: {...}}
var offers := {}    # season year -> the card waiting on the planner: {year, est, time (a family), menu ([family]), pick, until (date key)}
var lean := 0       # -2..2: what the player told him (and what a met Stretch / Dream goal did); consumed by the next offer
var counts := {}    # season year -> {planned, done, through, races}: the habit goals' counters
var news := []      # (session L3b2) what the goals did, oldest first: {date, year, gid, what, goal, effects [{kind, delta | meet}]}
var _legacy := false   # (not saved) a save before version 7 had a goals offer waiting: after_load() makes the new card
var _proj := {}        # (not saved) project() by date key while one menu is built


func _init() -> void:
	id = "goals"


static func cfg() -> Dictionary:
	return Data.goals


static func sys() -> SeasonGoals:
	return Game.get_system("goals") as SeasonGoals


# --- Dates and windows ---------------------------------------------------------------------------------------------

## The days a season's goals count: its first Monday to the day before the next season's.
static func window_of(year: int) -> Dictionary:
	return {"from": SeasonPlan.season_start(year), "to": Game.add_days(SeasonPlan.season_start(year + 1), -1)}


static func in_window(date: Dictionary, year: int) -> bool:
	var w := window_of(year)
	var k := Calendar.date_key(date)
	return k >= Calendar.date_key(w.from) and k <= Calendar.date_key(w.to)


## "31 Oct 2027"
static func fmt_date(d: Dictionary) -> String:
	return "%d %s %d" % [int(d.day), Calendar.MONTHS_SHORT[int(d.month) - 1], int(d.year)]


static func season_label(year: int) -> String:
	return SeasonSystem.season_label(year)


func _rec(year: int) -> Dictionary:
	if not seasons.has(year):
		seasons[year] = {"offered": false, "set": false, "reviewed": false, "est": {}, "goals": []}
	return seasons[year]


func goals_of(year: int) -> Array:
	return seasons[year].goals if seasons.has(year) else []


func has_goals(year: int) -> bool:
	return seasons.has(year) and bool(seasons[year].set)


func current_year() -> int:
	return SeasonPlan.year_of(Game.date)


func goal(year: int, gid: String) -> Dictionary:
	for g in goals_of(year):
		if str(g.id) == gid:
			return g
	return {}


func open_goals(year: int) -> Array:
	return goals_of(year).filter(func(g): return str(g.status) == "open")


# --- The day loop ----------------------------------------------------------------------------------------------------

## The new week is set up (Sunday evening, when the planner opens on it): the goals card of a season whose plan is chosen (or that
## has started), and a review when this is one of the season's two review weeks.
func on_week_start(w: WeekSim) -> void:
	if not enabled or Game.athlete == null or Game.season.mode != SeasonPlan.PHASES:
		return
	_maybe_card()
	_maybe_review(w.monday)


## The player chose the plan of season `year` (SeasonSystem: the offer or the Season tab): its goals card can come now.
func plan_chosen(_year: int) -> void:
	if enabled and Game.athlete != null and Game.season.mode == SeasonPlan.PHASES:
		_maybe_card()


## Evening: a card left open until its date takes his picks; the habit counters, a race just run, a place goal whose meet has passed,
## the end of the season.
func on_day_end(ctx: Dictionary) -> void:
	if not enabled or Game.athlete == null:
		return
	_default_cards(ctx.date)
	_pass_end(ctx.date)
	var year := SeasonPlan.year_of(ctx.date)
	if not has_goals(year):
		return
	_count_day(ctx, year)
	var rec: Dictionary = ctx.get("record", {})
	if not rec.is_empty() and str(rec.race) != "":
		_check_reached(year, ctx.date)
	_check_places(year, ctx.date)
	_close_if_over(ctx, year)


## (Saves before version 7 and tools: the old offer stop) "set" / "set:1,0,2" sets the goals; anything else leaves the card as it is.
func on_answer(event: Dictionary, choice: String) -> void:
	if str(event.get("kind", "")) != "goals" or not choice.begins_with("set"):
		return
	var picks := []
	if choice.begins_with("set:"):
		for s in choice.trim_prefix("set:").split(","):
			picks.append(int(s))
	apply(int(event.year), picks)


# --- The card ----------------------------------------------------------------------------------------------------------

## Is the plan offer of season `year` still waiting for an answer? (Its plan decides his estimate, so the goals wait for it.)
static func _plan_offer_waiting(year: int) -> bool:
	for e in Game.events:
		if str(e.get("source", "")) == "season" and str(e.get("kind", "")) == "offer" and int(e.get("year", 0)) == year and e.answer == "":
			return true
	return false


func _maybe_card() -> void:
	var cur := current_year()
	var ss := Game.get_system("season") as SeasonSystem
	for year in [cur, cur + 1]:
		if year < Game.season.first_season or bool(seasons.get(year, {}).get("offered", false)) or offers.has(year):
			continue
		var started := Calendar.date_key(Game.date) >= Calendar.date_key(SeasonPlan.season_start(year))
		if not (started or (ss != null and ss.decided.has(year))) or _plan_offer_waiting(year):
			continue
		offer(year)
		return


## Makes the goals card of season `year` (on the planner until it is answered or its date comes). Also what "Ask for goals" on the
## Career tab does. Returns the card ({} when there is nothing to offer).
func offer(year: int) -> Dictionary:
	var r := _rec(year)
	r.offered = true
	var pack := build(year, true)
	if pack.time.options.is_empty():
		return {}
	pack.until = Calendar.date_key(_until(year))
	offers[year] = pack
	r.est = pack.est
	return pack


## The day a card left open takes his picks: the evening before its season, or for a season already started the Sunday at least
## six days ahead (a card made on a Monday: this week's; later in the week: next week's).
static func _until(year: int) -> Dictionary:
	var eve := Game.add_days(SeasonPlan.season_start(year), -1)
	var sunday := Game.add_days(Calendar.monday_of(Game.add_days(Game.date, 6)), 6)
	return eve if Calendar.date_key(eve) > Calendar.date_key(sunday) else sunday


## The card waiting on the planner (the earliest season's), or {}.
func card() -> Dictionary:
	var years := offers.keys()
	years.sort()
	return offers[years[0]] if not years.is_empty() else {}


## Does the card count as a choice waiting this week? Only in the week its date falls in (Play week then asks once).
static func card_due(pack: Dictionary) -> bool:
	if pack.is_empty():
		return false
	return int(pack.until) <= Calendar.date_key(Game.add_days(Game.week_monday(), 6))


func _default_cards(date: Dictionary) -> void:
	for y in offers.keys():
		if Calendar.date_key(date) >= int(offers[y].until):
			apply(int(y), {}, true)


# --- The menu ----------------------------------------------------------------------------------------------------------

## The card of a season: {year, est, time (family), menu ([family]), pick {time, chosen {family key: option index}}}. A family:
## {key, kind ("time" / "milestone" / "process"), sub, name, pick (his ★), options (easy to hard)}. `consume` uses up `lean`.
## What is already reached this season is left out (a card made mid-season, the reviews).
func build(year: int, consume := true) -> Dictionary:
	_proj = {}
	var coach := CoachVerdict.head_view()
	var est := estimate(year, coach)
	var demands := str(coach.get("demands", "balanced"))
	var level_pick := clampi(int(cfg().pick.get(demands, 1)) + lean, 0, cfg().levels.size() - 1)
	var want := float(cfg().levels[level_pick].offset)
	var time := _time_family(year, est, level_pick)
	var menu := _menu(year, est)
	for fam in [time] + menu:   # (each family's ★: the option nearest the level he wants; what is already reached was left out)
		fam.pick = _nearest(fam.options, want)
	var chosen := _his_extras(menu, year, want)
	if consume:
		lean = 0
	_proj = {}
	return {"year": year, "est": est, "time": time, "menu": menu, "pick": {"time": int(time.pick), "chosen": chosen}}


## What the coach thinks you will run at the season's peak: {real (the time the game expects), seen (as he sees it), peak (date), sd}.
## The truth: the season plan played forward on a copy of the career up to the peak (the last target of the summer), the race-day
## Form of the race nearest the peak, and a best-of-a-few-races gain. His view: that time moved by his error (his judging ability).
func estimate(year: int, coach := {}) -> Dictionary:
	if coach.is_empty():
		coach = CoachVerdict.head_view()
	var e: Dictionary = cfg().estimate
	var peak := peak_date(year)
	var typical := float(project(peak).typical)
	var t_real := typical * (1.0 - float(e.best_of))
	var n: Dictionary = e.noise
	var judging := float(coach.attributes.get("judging_ability", 10))
	var sd := float(n.floor) + float(n.per_point) * maxf(0.0, 20.0 - judging)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("goals|%s|%d" % [str(coach.get("id", "coach")), year]).hash()
	var factor := 1.0 + rng.randfn(0.0, sd)   # (his error: the same in everything he projects this season)
	return {"real": t_real, "seen": t_real * factor, "factor": factor, "peak": peak, "sd": sd}


## What a race of the athlete would typically run on `date`, if the season plan is followed: the plan played forward on a copy of
## the career (CoachVerdict.simulate; the health model off, no dice), the ability at the end and the race-day Form of the race
## nearest the date (within 21 days; none = 0). {typical (seconds), ability, form}. Kept by date while one menu is built.
func project(date: Dictionary) -> Dictionary:
	var key := Calendar.date_key(date)
	if _proj.has(key):
		return _proj[key]
	var e: Dictionary = cfg().estimate
	var start := CoachVerdict.now_start()
	start.health = null
	var specs := [{"current": true, "set": {}, "scratch": []}]
	var w := Game.current_week()
	var m := Game.add_days(w.monday, 7)
	while Calendar.date_key(m) <= Calendar.date_key(date) and specs.size() <= int(e.window_weeks_max):
		specs.append({"plan": Game.season.week_for(m), "monday": m})
		m = Game.add_days(m, 7)
	var sim := CoachVerdict.simulate(start, specs)
	var ability := RacePerformance.ability(sim.athlete)
	var form := 0.0
	var nearest := 9999
	for r in sim.races:
		var d := absi(Calendar.days_between(r.date, date))
		if d <= 21 and d < nearest:
			nearest = d
			form = float(r.form)
	var typical := RacePerformance.time_for(ability, Game.athlete.gender) * (1.0 - clampf(form, 0.0, float(e.form_cap)))
	var out := {"typical": typical, "ability": ability, "form": form}
	_proj[key] = out
	return out


## The peak of season `year`: its last summer target (June or later), else the data's default date.
static func peak_date(year: int) -> Dictionary:
	var best := {}
	for key in Game.season.targets(year):
		var m := Calendar.get_meet(str(key))
		if m.is_empty() or int(m.date.month) < 6:
			continue
		if best.is_empty() or Calendar.date_key(m.date) > Calendar.date_key(best):
			best = m.date
	if not best.is_empty():
		return best
	var p: Dictionary = cfg().estimate.peak
	return {"year": year + 1, "month": int(p.month), "day": int(p.day)}


## A time snapped to the data's grid (0.5 s).
static func snap(t: float) -> float:
	var s := float(cfg().estimate.snap)
	return roundf(t / s) * s


## The level (index into levels) a required time is called by, from its ratio to the estimate (+ = slower = easier); -1 = far away.
static func level_of_ratio(ratio: float) -> int:
	if ratio < float(cfg().far.below):
		return -1
	var levels: Array = cfg().levels
	for i in levels.size():
		if ratio >= float(levels[i].from):
			return i
	return levels.size() - 1


static func chance_of(level: int) -> String:
	return str(cfg().far.chance) if level < 0 else str(cfg().levels[level].chance)


static func level_name(level: int) -> String:
	return "Far away" if level < 0 else str(cfg().levels[level].name)


## Four times at the levels' offsets from `base` (each at least min_step faster than the one before).
static func _times(base: float, extra := 0.0) -> Array:
	var out := []
	var prev := 1.0e9
	var step := float(cfg().estimate.min_step)
	for lv in cfg().levels:
		var t := snap(base * (1.0 + float(lv.offset) + extra))
		if t > prev - step:
			t = prev - step
		prev = t
		out.append(t)
	return out


## The TIME goal: four times from the estimate (those already run this season left out).
func _time_family(year: int, est: Dictionary, pick: int) -> Dictionary:
	var options := []
	var times := _times(float(est.seen))
	var best := best_in(year)
	for i in times.size():
		var t := float(times[i])
		if best > 0.0 and best <= t + 0.0001:
			continue
		options.append({"level": i, "sub": "time", "time": t, "ratio": float(cfg().levels[i].offset),
				"label": str(cfg().labels.time).format({"time": Calendar.format_time(t)}), "chance": chance_of(i), "level_name": level_name(i)})
	return _family("time", "time", "time", str(cfg().families.time), options, pick)


func _family(key: String, kind: String, sub: String, name: String, options: Array, pick: int) -> Dictionary:
	return {"key": key, "kind": kind, "sub": sub, "name": name, "pick": clampi(pick, 0, maxi(options.size() - 1, 0)), "options": options}


## The milestone and habit families of the menu, in menu order (standards, places by date, three races, the habits).
func _menu(year: int, est: Dictionary) -> Array:
	var out := []
	var std := _standard_family(year, est)
	if not std.options.is_empty():
		out.append(std)
	for fam in _place_families(year, est):
		out.append(fam)
	var three := _three_family(year, est)
	if not three.options.is_empty():
		out.append(three)
	for measure in cfg().process.kinds:
		var p := _process_family(year, str(measure))
		if not p.options.is_empty():
			out.append(p)
	return out.slice(0, int(cfg().menu.families_max))


static func _nearest(options: Array, want: float) -> int:
	var best := 0
	for i in options.size():
		if absf(float(options[i].ratio) - want) < absf(float(options[best].ratio) - want):
			best = i
	return best


## His two extras: C5's milestone (the option nearest the level he wants across the milestone families) and his habit (by his voice).
func _his_extras(menu: Array, year: int, want: float) -> Dictionary:
	var chosen := {}
	var best_key := ""
	var best_d := INF
	# (three races under a time sit exactly on his levels, so they would always be nearest: his milestone is a real one, a standard
	# or a place at a meet you are already in, as in C5; then three races; a place at a meet you are not in only when nothing else
	# is on the menu: his pick, taken by a card left open, never enters you in a meet by itself)
	var entered := func(f): return str(f.sub) != "place" or str(f.options[0].meet) in Game.entries
	var real := menu.filter(func(f): return str(f.kind) == "milestone" and str(f.sub) != "three" and entered.call(f))
	var three := menu.filter(func(f): return str(f.sub) == "three")
	var pool: Array = real if not real.is_empty() else (three if not three.is_empty() else menu)
	var best_level := 0
	for fam in pool:
		if str(fam.kind) != "milestone":
			continue
		var o: Dictionary = fam.options[int(fam.pick)]
		var d := absf(float(o.ratio) - want)
		if d < best_d:
			best_d = d
			best_key = str(fam.key)
			best_level = int(o.level) if int(o.level) >= 0 else cfg().levels.size()   # (far away = beyond Dream)
	# (a real milestone more than one level from the one he wants, e.g. a Dream when he wants Realistic: three races at his level)
	if pool == real and not three.is_empty() and absi(best_level - level_of_ratio(want)) > 1:
		best_key = str(three[0].key)
	for fam in menu:
		if str(fam.key) == best_key:
			chosen[best_key] = int(fam.pick)
	var measure := _his_habit(year)
	for fam in menu:
		if str(fam.key) == "habit:" + measure:
			chosen[str(fam.key)] = int(fam.pick)
	return chosen


## The habit his voice picks (C5), or the fallback when it does not fit the athlete's age.
func _his_habit(year: int) -> String:
	var p: Dictionary = cfg().process
	var measure := str(p.by_voice.get(Coaches.id_of(Game.athlete), p.fallback))
	if not p.kinds.has(measure):
		measure = str(p.fallback)
	var kind: Dictionary = p.kinds[measure]
	if kind.has("max_age") and Standards.age_in(Game.athlete, year + 1) > int(kind.max_age):
		measure = str(p.fallback)
	return measure


## The items of a family within reach: ratio between −reach.ahead (harder) and +reach.behind (easier), plus the next harder one (so a
## list can end in a stretch); with nothing within reach and `far_ok`, the two nearest harder ones (C5: "far away" only then).
static func _reach(items: Array, far_ok: bool) -> Array:
	var reach: Dictionary = cfg().milestone.reach
	items.sort_custom(func(x, y): return float(x.ratio) > float(y.ratio))   # easiest first
	var within := items.filter(func(it): return float(it.ratio) >= -float(reach.ahead) and float(it.ratio) <= float(reach.behind))
	var harder := items.filter(func(it): return float(it.ratio) < -float(reach.ahead))
	if within.is_empty():
		return harder.slice(0, 2) if far_ok else []
	if not harder.is_empty() and within.size() < 4:
		within.append(harder[0])
	return within.slice(maxi(within.size() - 4, 0))


static func _with_level(items: Array) -> Array:
	for it in items:
		var lv := level_of_ratio(float(it.ratio))
		it.level = lv
		it.chance = chance_of(lv)
		it.level_name = level_name(lv)
	return items


## The standards of the athlete's age class (C5): reached by the season's best.
func _standard_family(year: int, est: Dictionary) -> Dictionary:
	var items := []
	var best := best_in(year)
	for s in Standards.ladder(Game.athlete, year + 1):
		if best > 0.0 and best <= float(s.time) + 0.0001:
			continue
		var item: Dictionary = s.duplicate()
		item.sub = "standard"
		item.label = str(cfg().labels.standard).format({"short": s.short, "time": Calendar.format_time(float(s.time))})
		item.ratio = float(s.time) / float(est.seen) - 1.0
		items.append(item)
	return _family("standard", "milestone", "standard", str(cfg().families.standard), _with_level(_reach(items, true)), 0)


## The meets with a place goal this season, in date order: the targets and any national / international meet you entered, and the
## district championships (competitions.json champs "district"), each still ahead and open to you.
func _place_meets(year: int) -> Array:
	var a := Game.athlete
	var levels: Array = cfg().milestone.place_levels
	var w := window_of(year)
	var from: Dictionary = w.from if Calendar.date_key(w.from) > Calendar.date_key(Game.date) else Game.date
	var keys := []
	for m in Calendar.meets_between(from, w.to):
		var key := str(m.key)
		var big: bool = str(m.level) in levels and (key in Game.season.targets(year) or key in Game.entries)
		var district := str(m.get("champs", "")) == "district"
		if (big or district) and not key in keys and Calendar.can_enter(a, m, Game.date).ok:
			keys.append(key)
	return keys


## A place family per meet: top 12 / top 8 / a medal (a district championship: top 3 / the win), the time each needs set against his
## projection for that day.
func _place_families(year: int, est: Dictionary) -> Array:
	var out := []
	var a := Game.athlete
	var pm: Dictionary = cfg().milestone
	var pool: Array = Game.rivals.filter(func(r): return not Rivals.is_out(r))
	if pool.size() < int(pm.place.min_pool):
		return out
	for key in _place_meets(year):
		var meet := Calendar.get_meet(key)
		var abil := []
		var to := Calendar.monday_of(meet.date)
		var from := Calendar.monday_of(Game.date)
		for r in pool:
			abil.append(Rivals.expected_ability(r, a.gender, from, to, int(a.birth_date.year)))
		abil.sort()
		abil.reverse()
		var mine := float(project(meet.date).typical) * float(est.factor)   # (as he sees you on that day)
		var kinds := [["top3", int(pm.district.top3), "place"], ["win", int(pm.district.win), "place_win"]] \
				if str(meet.get("champs", "")) == "district" else \
				[["field", int(pm.place.field), "place"], ["final", int(pm.place.final), "place"], ["medal", int(pm.place.medal), "place_medal"]]
		var items := []
		for kind in kinds:
			var k := int(kind[1])
			var need_abil := place_need(meet, k, abil)
			if need_abil < 0.0:
				continue
			var need := RacePerformance.time_for(need_abil, a.gender)
			items.append({"id": "%s:%s" % [kind[0], key], "kind": "place", "sub": "place", "meet": key, "place": k, "time": need,
					"ratio": need / mine - 1.0, "label": str(cfg().labels[kind[2]]).format({"n": k, "meet": str(meet.name)}), "estimated": false})
		var options := _with_level(_reach(items, false))
		if not options.is_empty():
			out.append(_family("place:" + key, "milestone", "place", str(cfg().families.place).format({"meet": str(meet.name)}), options, 0))
	return out


## The ability the k-th place at `meet` needs: the k-th best rival of the field the game draws there, without dice. A championship
## with real entry numbers (or a national one with a standard) takes its best entrants (C5's rule: the k-th best of the pool); any
## other meet draws its field from a part of the pool (races.json fields: pool_range, size; Rivals.pick_field), so on average the
## k-th best of n drawn from those candidates stands at rank k (candidates + 1) / (n + 1) among them. `pool` = abilities, best first;
## -1 when the field is smaller than k.
static func place_need(meet: Dictionary, k: int, pool: Array) -> float:
	var entries := RaceDay.entry_range(meet, Game.athlete)
	if entries.size() == 2 or (str(meet.level) == "national" and meet.has("standard")):
		return float(pool[k - 1]) if k <= pool.size() else -1.0
	var f: Dictionary = Data.races.fields.get(str(meet.level), Data.races.fields.local)
	var m := pool.size()
	var lo := int(float(f.pool_range[0]) * m)   # (pick_field slices the pool sorted weakest first)
	var hi := int(float(f.pool_range[1]) * m)
	var cand := hi - lo
	var n := mini(roundi((float(f.size[0]) + float(f.size[1])) / 2.0), cand)
	if k > n or cand <= 0:
		return -1.0
	var rank := clampi(roundi(k * (cand + 1.0) / (n + 1.0)), 1, cand)
	return float(pool[(m - hi) + rank - 1])


## Three races under a time: the time levels set against his estimate of your TYPICAL race at the peak (without the best-of gain)
## plus the data's slack; a level already reached three times this season is left out.
func _three_family(year: int, est: Dictionary) -> Dictionary:
	var t3: Dictionary = cfg().three
	var n := int(t3.n)
	var typical := float(est.seen) / (1.0 - float(cfg().estimate.best_of))
	var times := _times(typical, float(t3.slack))
	var options := []
	for i in times.size():
		var t := float(times[i])
		if three_count(year, t) >= n:
			continue
		options.append({"level": i, "sub": "three", "time": t, "n": n, "ratio": float(cfg().levels[i].offset),
				"label": str(cfg().labels.three).format({"time": Calendar.format_time(t), "n": n}), "chance": chance_of(i), "level_name": level_name(i)})
	return _family("three", "milestone", "three", str(cfg().families.three), options, 0)


## A habit family (days trained through a warning / races run, counted honestly: L3a), its levels without the ones already settled.
func _process_family(year: int, measure: String) -> Dictionary:
	var kind: Dictionary = cfg().process.kinds[measure]
	if kind.has("max_age") and Standards.age_in(Game.athlete, year + 1) > int(kind.max_age):
		return _family("habit:" + measure, "process", measure, "", [], 0)
	var c: Dictionary = counts.get(year, {"planned": 0, "done": 0, "through": 0, "races": 0})
	var options := []
	for i in kind.levels.size():
		var n := int(kind.levels[i])
		if (measure == "races" and int(c.races) >= n) or (measure == "limits" and int(c.through) > n):
			continue   # (already reached / already over the limit)
		options.append({"level": i, "sub": measure, "n": n, "ratio": float(cfg().levels[i].offset), "label": process_label(measure, n),
				"chance": chance_of(i), "level_name": level_name(i)})
	return _family("habit:" + measure, "process", measure, str(cfg().families[measure]), options, 0)


static func process_label(measure: String, n: int) -> String:
	var kind: Dictionary = cfg().process.kinds[measure]
	if n == 0 and kind.has("label_zero"):
		return str(kind.label_zero)
	if n == 1 and kind.has("label_one"):
		return str(kind.label_one)
	return str(kind.label).format({"n": n})


## The family of a menu (or the card's time family) by key, or {}.
static func family_in(pack: Dictionary, key: String) -> Dictionary:
	if key == "time":
		return pack.time
	for fam in pack.menu:
		if str(fam.key) == key:
			return fam
	return {}


## The family key of a goal (goals set before L3b2 have none: from what they ask).
static func family_of(g: Dictionary) -> String:
	if g.has("family"):
		return str(g.family)
	match str(g.get("sub", "")):
		"time":
			return "time"
		"standard":
			return "standard"
		"place":
			return "place:" + str(g.get("meet", ""))
		"three":
			return "three"
	return "habit:" + str(g.get("sub", ""))


## Is a choice of extras allowed? (at most menu.extras, at most max_process habits, at most max_milestone milestones)
static func allowed(pack: Dictionary, chosen: Dictionary) -> bool:
	var m: Dictionary = cfg().menu
	var habits := 0
	var miles := 0
	for key in chosen:
		var fam := family_in(pack, str(key))
		if fam.is_empty() or int(chosen[key]) < 0 or int(chosen[key]) >= fam.options.size():
			return false
		if str(fam.kind) == "process":
			habits += 1
		else:
			miles += 1
	return chosen.size() <= int(m.extras) and habits <= int(m.max_process) and miles <= int(m.max_milestone)


## The selection as {time, chosen}: `sel` a Dictionary from the card, an Array of level indices (the old offer: time, then his two
## extras in order) or empty (his picks). A selection the menu does not allow falls back to his picks.
static func _selection(pack: Dictionary, sel) -> Dictionary:
	var pick: Dictionary = pack.pick
	if sel is Dictionary and not sel.is_empty():
		var chosen: Dictionary = sel.get("chosen", pick.chosen)
		if allowed(pack, chosen):
			return {"time": clampi(int(sel.get("time", pick.time)), 0, pack.time.options.size() - 1), "chosen": chosen}
		return pick
	if sel is Array and not sel.is_empty():
		var chosen := {}
		var keys: Array = pick.chosen.keys()
		for i in keys.size():
			var fam := family_in(pack, str(keys[i]))
			chosen[keys[i]] = clampi(int(sel[i + 1]) if i + 1 < sel.size() else int(pick.chosen[keys[i]]), 0, fam.options.size() - 1)
		return {"time": clampi(int(sel[0]), 0, pack.time.options.size() - 1), "chosen": chosen}
	return pick


## A goal from a family's option.
static func _goal_from(fam: Dictionary, idx: int) -> Dictionary:
	var g: Dictionary = fam.options[idx].duplicate(true)
	g.kind = str(fam.kind)
	g.family = str(fam.key)
	g.index = idx
	g.pick = int(fam.pick)
	g.higher = idx > int(fam.pick)   # (a family runs from easy to hard: a later option is above his ★)
	g.status = "open"
	g.met_on = {}
	g.detail = ""
	return g


## Enters the meet of a place goal when the athlete is not in it yet (the card says so before it is set).
static func _enter_for(g: Dictionary) -> void:
	if str(g.get("sub", "")) != "place":
		return
	var m := Calendar.get_meet(str(g.meet))
	if not m.is_empty() and not str(g.meet) in Game.entries and Calendar.can_enter(Game.athlete, m, Game.date).ok:
		Game.enter(str(g.meet))
		Game.current_week()


## The card's goals are set: the time goal and the chosen extras ({time, chosen}; empty = his picks). Said in the coach thread.
## `defaulted`: the card was left open until its date.
func apply(year: int, sel = {}, defaulted := false) -> void:
	if not offers.has(year):
		return
	var pack: Dictionary = offers[year]
	var s := _selection(pack, sel)
	var r := _rec(year)
	r.goals = []
	var fams := [[pack.time, int(s.time)]]
	for fam in pack.menu:
		if s.chosen.has(fam.key):
			fams.append([fam, int(s.chosen[fam.key])])
	var steps := 0
	for pair in fams:
		var g := _goal_from(pair[0], int(pair[1]))
		g.id = "g%d" % (r.goals.size() + 1)
		r.goals.append(g)
		steps += int(g.index) - int(g.pick)
		_enter_for(g)
	r.set = true
	r.est = pack.est
	offers.erase(year)
	var effects := []
	var mind := MindSystem.sys()   # (session M1: new goals lift motivation; levels above his pick lift an ambitious athlete more)
	if mind != null and MindSystem.model_enabled:
		var was := mind.value("motivation")
		mind.goals_set(steps)
		effects.append({"kind": "motivation", "delta": mind.value("motivation") - was})
	_log(year, {}, "defaulted" if defaulted else "set", effects)
	_say_set(year, defaulted)
	HabitSystem.touch()


func _say_set(year: int, defaulted: bool) -> void:
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return
	var voice := Coaches.id_of(Game.athlete)
	var o: Dictionary = cfg().offer
	var lines := [str(cfg().card.defaulted) if defaulted else str(o.set_message.get(voice, o.set_message.calm)).format({"season": season_label(year)})]
	for g in seasons[year].goals:
		lines.append(str(o.goal_line).format({"goal": goal_text(g, year)}))
	lines.append(str(o.set_end.get(voice, o.set_end.calm)))
	ms.coach_says("\n".join(lines))


# --- Goal texts -------------------------------------------------------------------------------------------------------

## "Run 2:12.00 or faster by 31 Oct 2027" / "Finish in the top 8 at Nuorten SM 14-15" / "Race at least 5 times".
static func goal_text(g: Dictionary, year: int) -> String:
	var text := _uc_first(str(g.label))
	if str(g.sub) in ["time", "standard", "three"]:
		text += " " + str(cfg().ui.window).format({"date": fmt_date(window_of(year).to)})
	return text


static func _uc_first(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1) if s.length() > 0 else s


## "✗ Run 2:12.00 or faster by 31 Oct 2027 (your best was 2:20.00)": the part in brackets only when there is something to say.
static func missed_line(g: Dictionary, year: int) -> String:
	var rv: Dictionary = cfg().review
	if str(g.get("detail", "")) == "":
		return str(rv.line_missed_plain).format({"goal": goal_text(g, year)})
	return str(rv.line_missed).format({"goal": goal_text(g, year), "detail": str(g.detail)})


## Does meeting this goal move next season's ★ up? (a Stretch, Dream or far-away level)
static func lean_stake(g: Dictionary) -> bool:
	var lv := int(g.get("level", g.get("index", 0)))
	return lv >= 2 or lv < 0


## What a goal opens when met and what a miss costs, in one line (GDD 4.10 "L3b2's questions" 3): only what the game really does.
static func stakes_text(g: Dictionary) -> String:
	var s: Dictionary = cfg().stakes
	var t: Dictionary = cfg().trust
	var met := [str(s.trust).format({"n": "%.0f" % (float(t.met) + (float(t.higher) if bool(g.get("higher", false)) else 0.0))}), str(s.moods)]
	if lean_stake(g):
		met.append(str(s.lean))
	if str(g.get("kind", "")) == "milestone":
		met.append(str(s.meet))
	return CoachSystem.words("%s %s. %s %s." % [str(s.met_head), ", ".join(met), str(s.missed_head), str(s.missed)])


## The general line of the card: what met and missed mean.
static func stakes_general() -> String:
	var t: Dictionary = cfg().trust
	return CoachSystem.words(str(cfg().stakes.general).format({"met": "%.0f" % float(t.met), "higher": "%.0f" % float(t.higher)}))


## What a met goal opened ("Opened: trust +3, confidence +6, …"), from what was recorded when it was met.
static func opened_text(g: Dictionary) -> String:
	var parts := []
	for e in g.get("opened", []):
		var line := effect_text(e)
		if line != "":
			parts.append(_lc_first(line) if parts.size() > 0 else line)
	if parts.is_empty():
		return str(cfg().ui.opened_none)
	return str(cfg().ui.opened).format({"list": ", ".join(parts)})


## One recorded effect in words ("Trust +3", "Confidence +6", "He put you up for TJIG").
static func effect_text(e: Dictionary) -> String:
	var lg: Dictionary = cfg().log
	match str(e.kind):
		"trust", "confidence", "motivation":
			if absf(float(e.delta)) < 0.05:
				return ""
			return str(lg[str(e.kind)]).format({"delta": RaceRecap.signed(float(e.delta), 0 if absf(float(e.delta)) >= 1.0 else 1)})
		"lean":
			return CoachSystem.words(str(lg.lean))
		"meet":
			return CoachSystem.words(str(lg.meet).format({"meet": str(e.meet)}))
		"meet_none":
			return str(lg.meet_none)
	return ""


## The goal as it stands, one line: what you have and what it needs.
func progress_text(g: Dictionary, year: int) -> String:
	var ui: Dictionary = cfg().ui
	match str(g.status):
		"met":
			return str(ui.met_on).format({"date": fmt_date(g.met_on)}) if not g.met_on.is_empty() else str(ui.status.met)
		"missed", "void", "dropped":
			return str(g.detail) if str(g.detail) != "" else str(ui.status.get(str(g.status), ui.status_dropped))
	match str(g.sub):
		"time", "standard":
			var best := best_in(year)
			if best > 0.0:
				return str(ui.time_progress).format({"best": Calendar.format_time(best), "goal": Calendar.format_time(float(g.time))})
			return str(ui.time_none).format({"goal": Calendar.format_time(float(g.time))})
		"three":
			return str(ui.three_progress).format({"done": three_count(year, float(g.time)), "n": int(g.n), "time": Calendar.format_time(float(g.time))})
		"place":
			var meet := Calendar.get_meet(str(g.meet))
			return str(ui.place_progress).format({"meet": str(meet.get("name", "")), "date": fmt_date(meet.date) if not meet.is_empty() else ""})
		_:
			return _count_note(g, year)


func _count_note(g: Dictionary, year: int) -> String:
	var c: Dictionary = counts.get(year, {"planned": 0, "done": 0, "through": 0, "races": 0})
	var kind: Dictionary = cfg().process.kinds.get(str(g.sub), {})
	if kind.is_empty():
		return str(cfg().ui.retired)
	match str(g.sub):
		"limits":
			return str(kind.count_note).format({"done": int(c.through)})
	return str(kind.count_note).format({"done": int(c.races)})


## The player's best 800 m time inside the season's window (0.0 = none).
static func best_in(year: int) -> float:
	var best := 0.0
	for t in _times_in(year):
		if best == 0.0 or t < best:
			best = t
	return best


## How many races of the season were run in `time` or faster.
static func three_count(year: int, time: float) -> int:
	return _times_in(year).filter(func(t): return t <= time + 0.0001).size()


static func _times_in(year: int) -> Array:
	var a := Game.athlete
	var out := []
	for r in a.results:
		if str(r.get("status", "")) != "" or float(r.time) <= 0.0 or str(r.event) != a.main_event:
			continue
		if in_window(Game.int_date(r.date), year):
			out.append(float(r.time))
	return out


# --- Counting and settling --------------------------------------------------------------------------------------------

func _count_day(ctx: Dictionary, year: int) -> void:
	var c: Dictionary = counts.get(year, {"planned": 0, "done": 0, "through": 0, "races": 0})
	var rec: Dictionary = ctx.get("record", {})
	var w: WeekSim = ctx.get("week")
	if rec.is_empty() or w == null:
		return
	var d := int(ctx.day)
	if str(rec.race) != "":
		c.races = int(c.races) + 1
	else:
		var n := w.session_count(d, rec)   # (session F1: the same "done" as the Sunday talk)
		c.planned = int(c.planned) + int(n.planned)
		c.done = int(c.done) + int(n.done)
	var h := Game.get_system("health") as HealthSystem
	if h != null and Calendar.date_key(ctx.date) in h.overrides:
		c.through = int(c.through) + 1
	counts[year] = c


## After a race: a time, standard or three-races goal that is reached is met at once.
func _check_reached(year: int, date: Dictionary) -> void:
	var best := best_in(year)
	if best <= 0.0:
		return
	for g in goals_of(year):
		if str(g.status) != "open":
			continue
		if str(g.sub) in ["time", "standard"] and best <= float(g.time) + 0.0001:
			_met(year, g, date)
		elif str(g.sub) == "three" and three_count(year, float(g.time)) >= int(g.n):
			_met(year, g, date)


## A place goal is settled on the evening of its meet's race day: met with the place, or missed with a quiet talk (in the thread).
func _check_places(year: int, date: Dictionary) -> void:
	for g in goals_of(year):
		if str(g.status) != "open" or str(g.sub) != "place":
			continue
		var meet := Calendar.get_meet(str(g.meet))
		if meet.is_empty() or Calendar.date_key(date) < Calendar.date_key(meet.date):
			continue
		var res := place_result(str(g.meet))
		if not res.is_empty() and bool(res.reached) and int(res.place) <= int(g.place):
			_met(year, g, date)
			continue
		g.status = "missed"
		g.detail = str(cfg().review.detail.place_none) if res.is_empty() else str(cfg().review.detail.place).format({"result": str(res.text)})
		_missed_effects(year, g)
		_talk_missed(year, g)


## How the player did at a meet: {place, reached (a final result, not an eliminated heat), text} or {} when they did not race it.
static func place_result(meet_key: String) -> Dictionary:
	var last := {}
	for r in Game.athlete.results:
		if str(r.meet_key) == meet_key:
			last = r
	if last.is_empty():
		return {}
	var round := str(last.round)
	var final: bool = round in ["Race", "Final"] or round.begins_with("Section")
	var place := int(last.place) if str(last.get("status", "")) == "" else 9999
	return {"place": place, "reached": final, "text": Race.result_text(last, " ")}


## The evening before a new season: what is still open is settled, and the season's goals wait on the next planner as a section
## (session L3b2: never a stop).
func _close_if_over(ctx: Dictionary, year: int) -> void:
	var tomorrow := Game.add_days(ctx.date, 1)
	if SeasonPlan.year_of(tomorrow) == year or not has_goals(year) or bool(seasons[year].reviewed):
		return
	var r: Dictionary = seasons[year]
	r.reviewed = true
	var best := best_in(year)
	var c: Dictionary = counts.get(year, {"planned": 0, "done": 0, "through": 0, "races": 0})
	for g in r.goals:
		if str(g.status) != "open":
			continue
		var ok := false
		var detail := ""
		var rd: Dictionary = cfg().review.detail
		match str(g.sub):
			"time", "standard":
				ok = best > 0.0 and best <= float(g.time) + 0.0001
				detail = str(rd.time).format({"best": Calendar.format_time(best)}) if best > 0.0 else str(rd.time_none)
			"three":
				var n := three_count(year, float(g.time))
				ok = n >= int(g.n)
				detail = str(rd.three).format({"done": n, "n": int(g.n)})
			"limits":
				ok = int(c.through) <= int(g.n)
				detail = str(rd.process_limits).format({"done": int(c.through)})
			"races":
				ok = int(c.races) >= int(g.n)
				detail = str(rd.process_races).format({"done": int(c.races)})
			"place":
				ok = false
				detail = str(rd.place_none)
		if ok:
			_met(year, g, ctx.date)
		else:
			g.status = "missed"
			g.detail = detail
			_missed_effects(year, g)
	var all_missed: int = r.goals.filter(func(x): return str(x.status) == "missed").size()   # (with a place goal missed at its meet)
	r.end = {"until": Calendar.date_key(Game.add_days(tomorrow, 6)), "answer": "", "missed": all_missed}


## A missed goal: confidence a little down (M1), never trust; logged.
func _missed_effects(year: int, g: Dictionary) -> void:
	var effects := []
	var mind := MindSystem.sys()
	if mind != null and MindSystem.model_enabled:
		var was := mind.value("confidence")
		mind.goal_missed()
		effects.append({"kind": "confidence", "delta": mind.value("confidence") - was})
	_log(year, g, "missed", effects)


# --- Met: what it opens ----------------------------------------------------------------------------------------------------

## A goal is met: trust up (more above his ★), confidence and motivation up, a Stretch / Dream goal moves next season's ★ up, a
## milestone makes him put you up for a bigger meet; a message with replies (not a stop). What it opened is kept on the goal.
func _met(year: int, g: Dictionary, date: Dictionary) -> void:
	g.status = "met"
	g.met_on = date.duplicate()
	var effects := []
	var t: Dictionary = cfg().trust
	var delta := float(t.met) + (float(t.higher) if bool(g.higher) else 0.0)
	g.trust = delta
	var cs := Game.get_system("coach") as CoachSystem
	if cs != null and CoachSystem.model_enabled and not cs.head().is_empty():
		var was := cs.trust()
		cs.add_trust(delta, "goal met")
		effects.append({"kind": "trust", "delta": cs.trust() - was})
	var mind := MindSystem.sys()   # (session M1: confidence and motivation up)
	if mind != null and MindSystem.model_enabled:
		var c0 := mind.value("confidence")
		var m0 := mind.value("motivation")
		mind.goal_met()
		effects.append({"kind": "confidence", "delta": mind.value("confidence") - c0})
		effects.append({"kind": "motivation", "delta": mind.value("motivation") - m0})
	if lean_stake(g):
		lean = clampi(lean + int(cfg().stakes.lean_met), int(cfg().lean.min), int(cfg().lean.max))
		effects.append({"kind": "lean"})
		_refresh_cards()
	if str(g.get("kind", "")) == "milestone":
		var su := CoachSuggests.sys()
		if su != null and CoachSuggests.enabled:
			var s := su.put_up(goal_text(g, year))
			effects.append({"kind": "meet", "meet": str(s.meet_name)} if not s.is_empty() else {"kind": "meet_none"})
	g.opened = effects
	_log(year, g, "met", effects)
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return
	var voice := Coaches.id_of(Game.athlete)
	var m: Dictionary = cfg().met
	var text := str(m.text.get(voice, m.text.calm)).format({"goal": goal_text(g, year), "goal_lc": _lc_first(goal_text(g, year))})
	if bool(g.higher):
		text += str(m.higher.get(voice, m.higher.calm))
	ms.post_custom("goal", "met:%d:%s" % [year, str(g.id)], text, _replies(m.replies), false)


## A place goal missed right after its meet: a talk in the thread (not a stop), with the same replies as the season's end.
func _talk_missed(year: int, g: Dictionary) -> void:
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return
	var voice := Coaches.id_of(Game.athlete)
	var rv: Dictionary = cfg().review
	var text := str(cfg().place_missed.text.get(voice, cfg().place_missed.text.calm)).format(
			{"goal": goal_text(g, year), "goal_lc": _lc_first(goal_text(g, year)), "detail": str(g.detail)})
	text += " " + str(rv.comment.get(voice, rv.comment.calm))
	ms.post_custom("goal", "review:%d" % year, text, _replies(rv.replies), false)


static func _lc_first(s: String) -> String:
	return s.left(1).to_lower() + s.substr(1) if s.length() > 0 else s


static func _replies(list: Array) -> Array:
	return list.map(func(r): return {"id": str(r.id), "label": str(r.label), "hint": str(r.hint)})


## The answer to a goal moment (StoryletSystem routes it here): his reply and the lines of the result card.
func on_reply(ref: String, reply_id: String) -> Dictionary:
	var parts := ref.split(":")
	var table: Dictionary = cfg().met if parts[0] == "met" else cfg().review
	var voice := Coaches.id_of(Game.athlete)
	var reply := {}
	for r in table.replies:
		if str(r.id) == reply_id:
			reply = r
	if reply.is_empty():   # (it passed unanswered: nothing changes)
		return {"changes": _met_changes(parts)}
	var changes := _met_changes(parts)
	var d := int(reply.lean)
	if d != 0:
		lean = clampi(lean + d, int(cfg().lean.min), int(cfg().lean.max))
		changes.append(str(cfg().ui.lean_up if d > 0 else cfg().ui.lean_down))
		_refresh_cards()
	var answers: Dictionary = table.answers.get(voice, table.answers.calm)
	return {"result": str(answers.get(reply_id, "")), "changes": changes}


## The trust line of a met goal's result card.
func _met_changes(parts: Array) -> Array:
	if parts[0] != "met" or parts.size() < 3:
		return []
	for g in goals_of(int(parts[1])):
		if str(g.id) == parts[2] and float(g.get("trust", 0.0)) > 0.0:
			var ms := Game.get_system("moments") as StoryletSystem
			var cs := Game.get_system("coach") as CoachSystem
			if ms != null and cs != null:
				var who := str(cs.head().get("name", "")).split(" ")[0]
				return [ms._change_line(str(Data.moments.changes.trust).format({"who": who}), float(g.trust))]
	return []


# --- The two reviews ---------------------------------------------------------------------------------------------------------

## The review weeks of season `year`: [{id, monday}]: the week after the indoor anchor (the target, else the coach's pick) and the
## juhannus week (Midsummer Eve's).
static func review_weeks(year: int) -> Array:
	var out := []
	for rv in cfg().reviews.list:
		var monday := {}
		match str(rv.rule):
			"after_indoor":
				monday = Game.add_days(Game.season.anchor_monday(year, "indoor"), 7)
			"juhannus":
				monday = Calendar.monday_of(Cast.occurrence("juhannus", year + 1))
		if not monday.is_empty() and in_window(monday, year):
			out.append({"id": str(rv.id), "monday": monday})
	return out


## On the planner of a review week: the menu again, with his estimate as it is now (the season so far), for the open goals.
func _maybe_review(monday: Dictionary) -> void:
	var year := SeasonPlan.year_of(monday)
	if not has_goals(year) or open_goals(year).is_empty():
		return
	var r: Dictionary = seasons[year]
	var reviews: Dictionary = r.get("reviews", {})
	for rv in review_weeks(year):
		if reviews.has(rv.id) or Calendar.date_key(rv.monday) != Calendar.date_key(monday):
			continue
		var pack := build(year, false)
		reviews[rv.id] = {"id": str(rv.id), "monday": monday.duplicate(), "est": pack.est, "time": pack.time, "menu": pack.menu,
				"goals": open_goals(year).map(func(g): return str(g.id)), "answers": {}}
	r.reviews = reviews


## This week's review section: {year, review} or {} (only in its own week).
func review_card() -> Dictionary:
	var year := current_year()
	if not seasons.has(year):
		return {}
	var reviews: Dictionary = seasons[year].get("reviews", {})
	for rid in reviews:
		var rv: Dictionary = reviews[rid]
		if Calendar.date_key(rv.monday) == Calendar.date_key(Game.week_monday()):
			return {"year": year, "review": rv}
	return {}


## His view of an open goal now: the level its time would be called by against his estimate as it is now.
func view_now(rv: Dictionary, g: Dictionary) -> Dictionary:
	var fam := family_in(rv, family_of(g))
	if not fam.is_empty():
		for i in fam.options.size():
			var o: Dictionary = fam.options[i]
			if str(o.label) == str(g.label):
				return {"level": int(o.level), "level_name": str(o.level_name), "chance": str(o.chance), "star": i == int(fam.pick)}
	if g.has("time") and str(g.sub) in ["time", "standard"]:
		var lv := level_of_ratio(float(g.time) / float(rv.est.seen) - 1.0)
		return {"level": lv, "level_name": level_name(lv), "chance": chance_of(lv), "star": false}
	return {}


## The families an open goal can be adjusted to in this review: its own (if still on the menu) and, for a milestone, the other
## milestone families no goal of the season uses.
func adjust_families(year: int, rv: Dictionary, g: Dictionary) -> Array:
	var out := []
	var own := family_in(rv, family_of(g))
	if not own.is_empty() and not own.options.is_empty():
		out.append(own)
	if str(g.kind) != "milestone":
		return out
	var used := goals_of(year).filter(func(x): return str(x.status) in ["open", "met"]).map(func(x): return family_of(x))
	for fam in rv.menu:
		if str(fam.kind) == "milestone" and family_of(g) != str(fam.key) and not str(fam.key) in used:
			out.append(fam)
	return out


## The player's answer for one goal in a review: "track" (nothing changes), "drop" (it can no longer be met; no cost), "adjust" to
## option `idx` of family `key` (the stakes follow the new level).
func answer_review(year: int, rid: String, gid: String, action: String, key := "", idx := -1) -> void:
	if not seasons.has(year) or not seasons[year].get("reviews", {}).has(rid):
		return
	var rv: Dictionary = seasons[year].reviews[rid]
	var g := goal(year, gid)
	if g.is_empty() or str(g.status) != "open":
		return
	match action:
		"track":
			rv.answers[gid] = "track"
		"drop":
			g.status = "dropped"
			g.detail = str(cfg().ui.dropped_on).format({"date": fmt_date(Game.date)})
			_history(g, "dropped", "")
			rv.answers[gid] = "drop"
			_log(year, g, "dropped", [])
		"adjust":
			var fam := {}
			for f in adjust_families(year, rv, g):
				if str(f.key) == key:
					fam = f
			if fam.is_empty() or idx < 0 or idx >= fam.options.size():
				return
			var was := goal_text(g, year)
			var ng := _goal_from(fam, idx)
			ng.id = gid
			ng.history = g.get("history", []).duplicate(true)
			_history(ng, "adjusted", was)
			var goals: Array = seasons[year].goals
			goals[goals.find(g)] = ng
			_enter_for(ng)
			rv.answers[gid] = "adjust"
			_log(year, ng, "adjusted", [{"kind": "was", "goal": was}])
	HabitSystem.touch()


static func _history(g: Dictionary, what: String, was: String) -> void:
	if not g.has("history"):
		g.history = []
	g.history.append({"date": Game.date.duplicate(), "what": what, "was": was})


# --- The season's end -------------------------------------------------------------------------------------------------------------

## The season's goals on the first planner of the next season: {year, end} or {} (until its week is over or it is answered).
func end_card() -> Dictionary:
	for y in seasons:
		var e: Dictionary = seasons[y].get("end", {})
		if not e.is_empty() and str(e.answer) == "" and Calendar.date_key(Game.date) <= int(e.until):
			return {"year": int(y), "end": e}
	return {}


## The replies of the season's end: C5's review replies when a goal was missed, else the met ones.
func end_replies(e: Dictionary) -> Array:
	return _replies((cfg().review if int(e.missed) > 0 else cfg().met).replies)


## The answer to the season's end: the reply moves next season's goals (lean) and he answers in his thread.
func answer_end(year: int, reply_id: String) -> void:
	var e: Dictionary = seasons.get(year, {}).get("end", {})
	if e.is_empty() or str(e.answer) != "":
		return
	var table: Dictionary = cfg().review if int(e.missed) > 0 else cfg().met
	for r in table.replies:
		if str(r.id) == reply_id:
			lean = clampi(lean + int(r.lean), int(cfg().lean.min), int(cfg().lean.max))
	e.answer = reply_id
	var ms := Game.get_system("moments") as StoryletSystem
	var answers: Dictionary = table.answers.get(Coaches.id_of(Game.athlete), table.answers.calm)
	if ms != null and str(answers.get(reply_id, "")) != "":
		ms.coach_says(str(answers[reply_id]))
	_refresh_cards()


## `lean` moved while a card waits (the season's end, a met goal, a reply): the card is made again with it, so his ★ moves at once
## (the date it names stays).
func _refresh_cards() -> void:
	for y in offers.keys():
		var until := int(offers[y].until)
		var pack := build(int(y), true)
		if pack.time.options.is_empty():
			continue
		pack.until = until
		offers[y] = pack


## A season's end left open past its week: "we try again" (nothing changes).
func _pass_end(date: Dictionary) -> void:
	for y in seasons:
		var e: Dictionary = seasons[y].get("end", {})
		if not e.is_empty() and str(e.answer) == "" and Calendar.date_key(date) >= int(e.until):
			e.answer = "left"


# --- The log (causes) ----------------------------------------------------------------------------------------------------------------

func _log(year: int, g: Dictionary, what: String, effects: Array) -> void:
	news.append({"date": Game.date.duplicate(), "year": year, "gid": str(g.get("id", "")), "what": what,
			"goal": goal_text(g, year) if not g.is_empty() else "", "label": _uc_first(str(g.get("label", ""))), "effects": effects})
	while news.size() > LOG_KEEP:
		news.pop_front()


# --- Save / load -----------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if seasons.is_empty() and offers.is_empty() and lean == 0 and counts.is_empty():
		return {}
	var s := {}
	for y in seasons:
		s[str(y)] = seasons[y]
	var o := {}
	for y in offers:
		o[str(y)] = offers[y]
	var c := {}
	for y in counts:
		c[str(y)] = counts[y]
	return {"seasons": s, "offers": o, "lean": lean, "counts": c, "news": news}


static func _ints(g: Dictionary) -> void:
	for k in ["index", "pick", "level", "n", "place"]:
		if g.has(k):
			g[k] = int(g[k])


static func _fix_family(fam: Dictionary) -> void:
	fam.pick = int(fam.pick)
	for op in fam.options:
		_ints(op)


func from_dict(d: Dictionary) -> void:
	seasons = {}
	for y in d.get("seasons", {}):
		var r: Dictionary = d.seasons[y]
		for g in r.goals:
			_ints(g)
			if not g.met_on.is_empty():
				g.met_on = Game.int_date(g.met_on)
			for h in g.get("history", []):
				h.date = Game.int_date(h.date)
			if str(g.get("sub", "")) == "sessions" and str(g.status) == "open":   # (session L3a: the habit goal is cut)
				g.status = "void"
				g.detail = str(cfg().ui.retired)
		if not r.est.is_empty() and r.est.has("peak"):
			r.est.peak = Game.int_date(r.est.peak)
		for rid in r.get("reviews", {}):
			var rv: Dictionary = r.reviews[rid]
			rv.monday = Game.int_date(rv.monday)
			rv.est.peak = Game.int_date(rv.est.peak)
			_fix_family(rv.time)
			for fam in rv.menu:
				_fix_family(fam)
		if r.has("end") and not r.end.is_empty():
			r.end.until = int(r.end.until)
			r.end.missed = int(r.end.missed)
		seasons[int(y)] = r
	offers = {}
	_legacy = false
	for y in d.get("offers", {}):
		var o: Dictionary = d.offers[y]
		if o.has("goals"):   # (an offer of a save before version 7: the new card with the new menu takes its place: after_load)
			_legacy = true
			if seasons.has(int(y)):
				seasons[int(y)].offered = false
			continue
		o.year = int(o.year)
		o.until = int(o.until)
		if o.est.has("peak"):
			o.est.peak = Game.int_date(o.est.peak)
		_fix_family(o.time)
		for fam in o.menu:
			_fix_family(fam)
		o.pick.time = int(o.pick.time)
		for k in o.pick.chosen:
			o.pick.chosen[k] = int(o.pick.chosen[k])
		offers[int(y)] = o
	lean = int(d.get("lean", 0))
	counts = {}
	for y in d.get("counts", {}):
		var c: Dictionary = d.counts[y]
		for k in c:
			c[k] = int(c[k])
		counts[int(y)] = c
	news = d.get("news", [])
	for e in news:
		e.date = Game.int_date(e.date)
		e.year = int(e.year)


## After the whole career is loaded (Game.from_dict): the goals offer of a save before version 7 was a stop event; it closes, and the
## new card with the new menu takes its place.
func after_load() -> void:
	for e in Game.events:
		if str(e.get("source", "")) == id and str(e.get("kind", "")) == "goals" and e.answer == "":
			e.answer = "card"
			_legacy = true
			if seasons.has(int(e.get("year", 0))):
				seasons[int(e.year)].offered = false
	if _legacy and enabled and Game.athlete != null and Game.season.mode == SeasonPlan.PHASES:
		_maybe_card()
	_legacy = false
