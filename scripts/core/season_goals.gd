class_name SeasonGoals
extends GameSystem
## The coach's season goals (GDD 4.9.2 "Season goals with times", session C5), GameSystem id "goals". With the plan offer of a season
## (or as soon as the season has started without one) the coach offers three goals: a TIME, a MILESTONE (a real standard of
## data/standards.json or a place at one of your target meets) and a HABIT (a process goal), each with up to four levels to pick from.
## He estimates what you can run in the season's peak by playing the season plan forward on a copy of the career (CoachVerdict.simulate),
## sees that through his judging ability (a poor judge sets goals that are too easy or too hard) and marks the level HE would choose by
## his demands and by what you told him after last season's missed goals (`lean`). The player picks; nothing is set without them.
## A goal is met the moment it is reached (a message, trust up); what is still open when the season ends is settled together in ONE
## review talk, and a missed goal never costs trust: its replies only tell him how to set the next goals. Numbers and texts:
## data/goals.json. Static `enabled` is OFF unless the app shell (main.gd) switches it on, so the tools that play seasons are unchanged
## (tools/goals_check.gd tests it on). Own state: seasons {year: {offered, set, goals, reviewed, est}}, the pending offers, `lean`, the
## counters of the habit goals; nothing is saved while no goal was ever offered (older careers save as before).

static var enabled := false

var seasons := {}   # season year -> {offered, set, reviewed, est ({real, seen, peak}), goals: [goal]}
var offers := {}    # season year -> {year, est, goals: [{kind, pick, options: [...]}]} while the offer waits for the answer
var lean := 0       # -2..2: what the player told him after a missed / met goal; consumed by the next offer
var counts := {}    # season year -> {planned, done, through, races}: the habit goals' counters
var _next := 1


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


# --- The day loop ----------------------------------------------------------------------------------------------------

## Morning: the offer of this season's (or, once its plan is chosen, next season's) goals.
func on_day_start(ctx: Dictionary) -> void:
	if not enabled or Game.athlete == null or Game.season.mode != SeasonPlan.PHASES:
		return
	var cur := SeasonPlan.year_of(ctx.date)
	var ss := Game.get_system("season") as SeasonSystem
	for year in [cur, cur + 1]:
		if year < Game.season.first_season or bool(seasons.get(year, {}).get("offered", false)):
			continue
		var started := Calendar.date_key(ctx.date) >= Calendar.date_key(SeasonPlan.season_start(year))
		if started or (ss != null and ss.decided.has(year)):
			offer(year)
			return


## Evening: the habit counters, a race just run, a place goal whose meet has passed, the end of the season.
func on_day_end(ctx: Dictionary) -> void:
	if not enabled or Game.athlete == null:
		return
	var year := SeasonPlan.year_of(ctx.date)
	if not has_goals(year):
		return
	_count_day(ctx, year)
	var rec: Dictionary = ctx.get("record", {})
	if not rec.is_empty() and str(rec.race) != "":
		_check_reached(year, ctx.date)
	_check_places(year, ctx.date)
	_close_if_over(ctx, year)


## The player's answer to the offer event: "set" (his picks) or "set:1,0,2" (a level index per goal); anything else = decide later.
func on_answer(event: Dictionary, choice: String) -> void:
	if str(event.get("kind", "")) != "goals":
		return
	var year := int(event.year)
	if not choice.begins_with("set") or not offers.has(year):
		offers.erase(year)   # (later: you can ask on the Overview page)
		_rec(year).offered = true
		return
	var picks := []
	if choice.begins_with("set:"):
		for s in choice.trim_prefix("set:").split(","):
			picks.append(int(s))
	apply(year, picks)


# --- The offer -----------------------------------------------------------------------------------------------------

## Posts the offer of season `year` (a stop event; the panel is GoalsEventPanel). Also what "Ask for goals" on the Overview does.
func offer(year: int) -> Dictionary:
	var pack := build(year)
	var r := _rec(year)
	r.offered = true
	if pack.goals.is_empty():
		return {}
	offers[year] = pack
	r.est = pack.est
	var voice := Coaches.id_of(Game.athlete)
	var ui: Dictionary = cfg().ui
	var title := str(ui.offer_title).format({"season": season_label(year)})
	var text := str(cfg().offer.intro.get(voice, cfg().offer.intro.calm))
	var choices := [{"id": "set", "label": str(ui.offer_set), "detail": ""}, {"id": "later", "label": str(ui.offer_later), "detail": str(ui.offer_later_hint)}]
	var e := Game.post_event(id, title, text, choices, true)
	e.kind = "goals"
	e.year = year
	return e


## The offer for a season: {year, est, goals: [{kind, pick, options}]}. `lean` is consumed.
func build(year: int) -> Dictionary:
	var coach := CoachVerdict.head_view()
	var est := estimate(year, coach)
	var demands := str(coach.get("demands", "balanced"))
	var base := int(cfg().pick.get(demands, 1))
	var level_pick := clampi(base + lean, 0, cfg().levels.size() - 1)
	var goals := []
	var time_goal := _time_options(year, est, level_pick)
	goals.append(time_goal)
	var milestone := _milestone_options(year, est, level_pick)
	if not milestone.options.is_empty():
		goals.append(milestone)
	goals.append(_process_options(year, level_pick))
	lean = 0
	return {"year": year, "est": est, "goals": goals}


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
## nearest the date (within 21 days; none = 0). {typical (seconds), ability, form}.
func project(date: Dictionary) -> Dictionary:
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
	return {"typical": typical, "ability": ability, "form": form}


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


## The TIME goal: four times from the estimate.
func _time_options(year: int, est: Dictionary, pick: int) -> Dictionary:
	var levels: Array = cfg().levels
	var options := []
	var prev := 1.0e9
	var step := float(cfg().estimate.min_step)
	for i in levels.size():
		var t := snap(float(est.seen) * (1.0 + float(levels[i].offset)))
		if t > prev - step:
			t = prev - step   # (each level is at least min_step faster than the one before)
		prev = t
		options.append({"level": i, "sub": "time", "time": t, "ratio": float(levels[i].offset),
				"label": str(cfg().labels.time).format({"time": Calendar.format_time(t)}), "chance": chance_of(i), "level_name": level_name(i)})
	return {"kind": "time", "pick": pick, "options": options}


## The MILESTONE goal: real things sorted by the time they need (standards of your age class, a top-8 / medal place at a target
## meet), the four around his pick; {} options when there is nothing within reach.
func _milestone_options(year: int, est: Dictionary, pick: int) -> Dictionary:
	var a := Game.athlete
	var m: Dictionary = cfg().milestone
	var seen := float(est.seen)
	var items := []
	for s in Standards.ladder(a, year + 1):
		var item: Dictionary = s.duplicate()
		item.sub = "standard"
		item.label = str(cfg().labels.standard).format({"short": s.short, "time": Calendar.format_time(float(s.time))})
		items.append(item)
	for p in _place_items(year, float(est.factor)):
		items.append(p)
	# How hard each is, as the ratio of the time it needs to his estimate (+ = slower = easier). A place at a meet is one race on
	# that day (its ratio is set against his projection for that date, in _place_items); a standard is reached by the season's best.
	for it in items:
		if not it.has("ratio"):
			it.ratio = float(it.time) / seen - 1.0
	items.sort_custom(func(x, y): return float(x.ratio) > float(y.ratio))   # easiest first
	var reach: Dictionary = m.reach
	var chosen := items.filter(func(it): return float(it.ratio) >= -float(reach.ahead) and float(it.ratio) <= float(reach.behind))
	# Something within reach is an offer; with nothing, the nearest faster things are offered as "far away" (two at most).
	if chosen.size() < 2:
		for it in items:
			if float(it.ratio) < -float(reach.ahead) and chosen.size() < 2:
				chosen.append(it)
	if chosen.is_empty():
		return {"kind": "milestone", "pick": 0, "options": []}
	var want := float(cfg().levels[pick].offset)
	var anchor := 0
	for i in chosen.size():
		if absf(float(chosen[i].ratio) - want) < absf(float(chosen[anchor].ratio) - want):
			anchor = i
	var first := clampi(anchor - 1, 0, maxi(chosen.size() - 4, 0))
	var options := []
	for i in range(first, mini(first + 4, chosen.size())):
		var it: Dictionary = chosen[i]
		var lv := level_of_ratio(float(it.ratio))
		it.level = lv
		it.chance = chance_of(lv)
		it.level_name = level_name(lv)
		options.append(it)
	return {"kind": "milestone", "pick": anchor - first, "options": options}


## The place goals: for each target meet of the season the athlete can still enter, the time the 8th / 3rd of the rival pool is
## expected to need there (the pool trained forward to the meet, no dice).
func _place_items(year: int, factor: float) -> Array:
	var out := []
	var a := Game.athlete
	var m: Dictionary = cfg().milestone.place
	var pool: Array = Game.rivals.filter(func(r): return not Rivals.is_out(r))
	if pool.size() < int(m.min_pool):
		return out
	for key in Game.season.targets(year):
		var meet := Calendar.get_meet(str(key))
		if meet.is_empty() or str(meet.level) not in ["national", "international"] or not Calendar.can_enter(a, meet, Game.date).ok:
			continue
		var abil := []
		var to := Calendar.monday_of(meet.date)
		var from := Calendar.monday_of(Game.date)
		for r in pool:
			abil.append(Rivals.expected_ability(r, a.gender, from, to, int(a.birth_date.year)))
		abil.sort()
		abil.reverse()
		var mine := float(project(meet.date).typical) * factor   # (as he sees you on that day)
		for kind in [["field", "place"], ["final", "place"], ["medal", "place_medal"]]:
			var k := int(m[kind[0]])
			if k > abil.size():
				continue
			var need := RacePerformance.time_for(float(abil[k - 1]), a.gender)
			var label := str(cfg().labels[kind[1]]).format({"n": k, "meet": str(meet.name)})
			out.append({"id": "%s:%s" % [kind[0], key], "kind": "place", "sub": "place", "meet": str(key), "place": k, "time": need,
					"ratio": need / mine - 1.0, "label": label, "estimated": false})
	return out


## The HABIT goal: sessions done / days trained through a warning / races, by his personality.
func _process_options(year: int, pick: int) -> Dictionary:
	var p: Dictionary = cfg().process
	var measure := str(p.by_voice.get(Coaches.id_of(Game.athlete), "sessions"))
	var kind: Dictionary = p.kinds[measure]
	if kind.has("max_age") and Standards.age_in(Game.athlete, year + 1) > int(kind.max_age):
		measure = "sessions"
		kind = p.kinds[measure]
	var options := []
	for i in kind.levels.size():
		options.append({"level": i, "sub": measure, "n": int(kind.levels[i]), "label": process_label(measure, int(kind.levels[i])),
				"chance": chance_of(i), "level_name": level_name(i)})
	return {"kind": "process", "pick": mini(pick, options.size() - 1), "options": options}


static func process_label(measure: String, n: int) -> String:
	var kind: Dictionary = cfg().process.kinds[measure]
	if n == 0 and kind.has("label_zero"):
		return str(kind.label_zero)
	return str(kind.label).format({"n": n})


## The levels chosen on the offer ([] or short = his pick): the goals of the season. Said in the coach thread.
func apply(year: int, picks: Array) -> void:
	if not offers.has(year):
		return
	var pack: Dictionary = offers[year]
	var r := _rec(year)
	r.goals = []
	var n := 0
	for i in pack.goals.size():
		var def: Dictionary = pack.goals[i]
		if def.options.is_empty():
			continue
		var idx := int(picks[i]) if i < picks.size() else int(def.pick)
		idx = clampi(idx, 0, def.options.size() - 1)
		var g: Dictionary = def.options[idx].duplicate(true)
		n += 1
		g.id = "g%d" % n
		g.kind = def.kind
		g.index = idx
		g.pick = int(def.pick)
		g.higher = idx > int(def.pick)   # (every goal's options run from easy to hard: a later one is above his pick)
		g.status = "open"
		g.met_on = {}
		g.detail = ""
		r.goals.append(g)
	r.set = true
	r.est = pack.est
	offers.erase(year)
	var mind := MindSystem.sys()   # (session M1: new goals lift motivation; levels above his pick lift an ambitious athlete more)
	if mind != null:
		var steps := 0
		for g in r.goals:
			steps += int(g.index) - int(g.pick)
		mind.goals_set(steps)
	_say_set(year)


func _say_set(year: int) -> void:
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return
	var voice := Coaches.id_of(Game.athlete)
	var o: Dictionary = cfg().offer
	var lines := [str(o.set_message.get(voice, o.set_message.calm)).format({"season": season_label(year)})]
	for g in seasons[year].goals:
		lines.append(str(o.goal_line).format({"goal": goal_text(g, year)}))
	lines.append(str(o.set_end.get(voice, o.set_end.calm)))
	ms.coach_says("\n".join(lines))


# --- Goal texts -------------------------------------------------------------------------------------------------------

## "Run 2:12.00 or faster by 31 Oct 2027" / "Finish in the top 8 at Nuorten SM 14-15" / "Do 85 % of the sessions in your plan".
static func goal_text(g: Dictionary, year: int) -> String:
	var text := _uc_first(str(g.label))
	if str(g.sub) in ["time", "standard"]:
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


## The goal as it stands, one line for the Overview: what you have and what it needs.
func progress_text(g: Dictionary, year: int) -> String:
	var ui: Dictionary = cfg().ui
	match str(g.status):
		"met":
			return str(ui.met_on).format({"date": fmt_date(g.met_on)}) if not g.met_on.is_empty() else str(ui.status.met)
		"missed", "void":
			return str(g.detail) if str(g.detail) != "" else str(ui.status[g.status])
	match str(g.sub):
		"time", "standard":
			var best := best_in(year)
			if best > 0.0:
				return str(ui.time_progress).format({"best": Calendar.format_time(best), "goal": Calendar.format_time(float(g.time))})
			return str(ui.time_none).format({"goal": Calendar.format_time(float(g.time))})
		"place":
			var meet := Calendar.get_meet(str(g.meet))
			return str(ui.place_progress).format({"meet": str(meet.get("name", "")), "date": fmt_date(meet.date) if not meet.is_empty() else ""})
		_:
			return _count_note(g, year)


func _count_note(g: Dictionary, year: int) -> String:
	var c: Dictionary = counts.get(year, {"planned": 0, "done": 0, "through": 0, "races": 0})
	var kind: Dictionary = cfg().process.kinds[str(g.sub)]
	match str(g.sub):
		"sessions":
			var share := roundi(100.0 * float(c.done) / float(c.planned)) if int(c.planned) > 0 else 100
			return str(kind.count_note).format({"done": int(c.done), "planned": int(c.planned), "share": share})
		"limits":
			return str(kind.count_note).format({"done": int(c.through)})
	return str(kind.count_note).format({"done": int(c.races)})


## The player's best 800 m time inside the season's window (0.0 = none).
static func best_in(year: int) -> float:
	var a := Game.athlete
	var best := 0.0
	for r in a.results:
		if str(r.get("status", "")) != "" or float(r.time) <= 0.0 or str(r.event) != a.main_event:
			continue
		if in_window(Game.int_date(r.date), year) and (best == 0.0 or float(r.time) < best):
			best = float(r.time)
	return best


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


## After a race: a time or standard goal that is reached is met at once.
func _check_reached(year: int, date: Dictionary) -> void:
	var best := best_in(year)
	if best <= 0.0:
		return
	for g in goals_of(year):
		if str(g.status) == "open" and str(g.sub) in ["time", "standard"] and best <= float(g.time) + 0.0001:
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
		var mind := MindSystem.sys()
		if mind != null:
			mind.goal_missed()
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


## The evening before a new season: what is still open is settled in one review.
func _close_if_over(ctx: Dictionary, year: int) -> void:
	var tomorrow := Game.add_days(ctx.date, 1)
	if SeasonPlan.year_of(tomorrow) == year or not has_goals(year) or bool(seasons[year].reviewed):
		return
	var r: Dictionary = seasons[year]
	r.reviewed = true
	var best := best_in(year)
	var c: Dictionary = counts.get(year, {"planned": 0, "done": 0, "through": 0, "races": 0})
	var missed := []
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
			"sessions":
				var share := 100.0 * float(c.done) / float(c.planned) if int(c.planned) > 0 else 100.0
				ok = share >= float(g.n)
				detail = str(rd.process_sessions).format({"done": int(c.done), "planned": int(c.planned)})
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
			missed.append(g)
	if not missed.is_empty():
		var mind := MindSystem.sys()   # (session M1: a missed goal costs a little confidence, never trust)
		if mind != null:
			for g in missed:
				mind.goal_missed()
		_review(year)


# --- The coach's words about them ----------------------------------------------------------------------------------------

## A goal is met: trust up (more for a level above his pick) and a message with replies (not a stop).
func _met(year: int, g: Dictionary, date: Dictionary) -> void:
	g.status = "met"
	g.met_on = date.duplicate()
	var t: Dictionary = cfg().trust
	var delta := float(t.met) + (float(t.higher) if bool(g.higher) else 0.0)
	g.trust = delta
	var cs := Game.get_system("coach") as CoachSystem
	if cs != null:
		cs.add_trust(delta, "goal met")
	var mind := MindSystem.sys()   # (session M1: confidence and motivation up)
	if mind != null:
		mind.goal_met()
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return
	var voice := Coaches.id_of(Game.athlete)
	var m: Dictionary = cfg().met
	var text := str(m.text.get(voice, m.text.calm)).format({"goal": goal_text(g, year), "goal_lc": _lc_first(goal_text(g, year))})
	if bool(g.higher):
		text += str(m.higher.get(voice, m.higher.calm))
	ms.post_custom("goal", "met:%d:%s" % [year, str(g.id)], text, _replies(m.replies), false)


## A place goal missed right after its meet: a talk in the thread (not a stop), with the same replies as the review.
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


## The season's review talk (a stop): every goal with ✓ / ✗, his comment, the replies that tell him how to set the next goals.
func _review(year: int) -> void:
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return
	var voice := Coaches.id_of(Game.athlete)
	var rv: Dictionary = cfg().review
	var lines := [str(rv.text.get(voice, rv.text.calm))]
	for g in seasons[year].goals:
		if str(g.status) == "met":
			lines.append(str(rv.line_met).format({"goal": goal_text(g, year)}))
		else:
			lines.append(missed_line(g, year))
	lines.append(str(rv.comment.get(voice, rv.comment.calm)))
	ms.post_custom("goal", "review:%d" % year, "\n".join(lines), _replies(rv.replies), true)


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
	return {"seasons": s, "offers": o, "lean": lean, "counts": c}


func from_dict(d: Dictionary) -> void:
	seasons = {}
	for y in d.get("seasons", {}):
		var r: Dictionary = d.seasons[y]
		for g in r.goals:
			g.index = int(g.index)
			g.pick = int(g.pick)
			if g.has("level"):
				g.level = int(g.level)
			if g.has("n"):
				g.n = int(g.n)
			if g.has("place"):
				g.place = int(g.place)
			if not g.met_on.is_empty():
				g.met_on = Game.int_date(g.met_on)
		if not r.est.is_empty() and r.est.has("peak"):
			r.est.peak = Game.int_date(r.est.peak)
		seasons[int(y)] = r
	offers = {}
	for y in d.get("offers", {}):
		var o: Dictionary = d.offers[y]
		o.year = int(o.year)
		if o.est.has("peak"):
			o.est.peak = Game.int_date(o.est.peak)
		for def in o.goals:
			def.pick = int(def.pick)
			for op in def.options:
				if op.has("level"):
					op.level = int(op.level)
				if op.has("n"):
					op.n = int(op.n)
				if op.has("place"):
					op.place = int(op.place)
		offers[int(y)] = o
	lean = int(d.get("lean", 0))
	counts = {}
	for y in d.get("counts", {}):
		var c: Dictionary = d.counts[y]
		for k in c:
			c[k] = int(c[k])
		counts[int(y)] = c
