class_name HealthSystem
extends GameSystem
## Injuries and illness (GDD 4.6). After every played day (on_health) the body takes the day's training:
## each session adds hidden strain to six body areas, which fades day by day, and strain shows to the player
## as soreness. Then the day's dice are rolled: bad-luck injuries per session, overuse injuries per area (near
## zero until an area is a bit sore, then rising steeply) and illness. An injury or illness has phases
## (data/injuries.json); each phase restricts training, applied as this week's day changes "by" injury
## (banned sessions are swapped for allowed ones, e.g. aqua jogging). Niggles, colds and minor limits can be
## overridden by the player (override_day); training or racing through them can make them worse. Serious
## injuries and fever are locked, and they withdraw the athlete from races.
## Stop events: a new injury or illness (the diagnosis) and the first time an area turns sore.
## The UI reads the model through the functions under "For the UI"; all numbers are in data/health.json.
## It has its own random numbers (saved), so a loaded game goes on exactly as it would have.

## The whole health model can be switched off (dev tools: the M1 balance must stay the same without it).
static var model_enabled := true

const SORE := 2      # soreness level "Sore" (0 None, 1 A bit sore, 2 Sore, 3 Painful)
const PAINFUL := 3
const RISK_NAMES := {"low": "Low", "moderate": "Moderate", "high": "High"}

var rng := RandomNumberGenerator.new()
var started := false
var day_no := 0              # days played since the health model started (internal clock)
var strain := {}             # area id -> hidden strain
var impacts: Array = []      # impact (raw strain added) of each of the last ~28 days, oldest first
var capacity_now := 1.0      # how much load the body is adapted to (1.0 = a new career, see capacity())
## Active injuries and illness: {id, first (id when it began), tier, area, cause, started (date), days (per
## phase), phase, left (days left in the phase, from the next day to be played), through_days, warning (the
## area's highest soreness level in the week before it began: 0 none … 3 painful), escalated}
var injuries: Array = []
var history: Array = []      # healed ones: the same entries plus "healed" (date) and "healed_no"; whole career
var warned := {}             # area id -> day_no of its last "sore" warning
var last_level := {}         # area id -> [day_no it was last a bit sore, sore, painful] (or worse)
var levels := {}             # area id -> soreness level after the last played day
var overrides: Array = []    # date keys of days the player trains through the limits
var days_without_training := 0
var detrain_days := 0        # days this week beyond the detraining limit
var days_without_running := 0
var run_detrain_days := 0    # days this week beyond the running-detraining limit (cross-training doesn't count)
var last_race_no := -1000    # day_no of the last race
var counters := {"days_injured": 0, "days_ill": 0, "days_out": 0}


func _init() -> void:
	id = "health"
	rng.randomize()


static func areas() -> Array:
	return Data.health.areas.list


func _ensure_started() -> void:
	if started:
		return
	started = true
	for area in areas():
		strain[area.id] = 0.0
	capacity_now = 1.0
	impacts = []
	var spike: Dictionary = Data.health.strain.spike
	for i in int(spike.chronic_days):
		impacts.append(float(spike.start_daily_impact))


# --- Day loop ------------------------------------------------------------------------------------

func on_day_start(ctx: Dictionary) -> void:
	if not model_enabled:
		return
	_ensure_started()
	var week: WeekSim = ctx.week
	var today := Calendar.date_key(ctx.date)
	overrides = overrides.filter(func(k): return int(k) >= today)
	if week.is_race_day(week.day):
		var rule := rule_at(1)
		if rule.locked:
			var meet: Dictionary = week.races[week.day]
			Game.withdraw(meet.key)
			Game.current_week()   # the day is a training day now
			Game.post_event(id, "Withdrawn: %s" % meet.name,
					"You can't race like this (%s), so your entry was withdrawn." % rule.reasons[0])
	_apply_restrictions(week)


## A new week: the injury limits go into its days right away (the week strip shows them before Monday).
func on_week_start(week: WeekSim) -> void:
	if model_enabled and started:
		_apply_restrictions(week)


## Puts the limits into the current week again, e.g. after the player changed the weekly plan.
func refresh() -> void:
	if model_enabled and started:
		_apply_restrictions(Game.current_week())


func on_health(ctx: Dictionary) -> void:
	if not model_enabled:
		return
	_ensure_started()
	var a := Game.athlete
	var date: Dictionary = ctx.date
	var rec: Dictionary = ctx.record
	var is_race: bool = rec.race != ""
	var sessions := _done_sessions(rec)
	day_no += 1
	_count_day(rec)
	_body_day(a, sessions, rec.intensity, is_race, date, float(rec.fatigue))
	if is_race:
		last_race_no = day_no
	var news := []   # injuries and illnesses that started (or got worse) today
	_progress(a, sessions, is_race, date, news)
	_roll_acute(a, sessions, is_race, date, news)
	_roll_overuse(a, date, news)
	_roll_illness(a, news)
	for inj in news:
		_post_diagnosis(inj)
	_update_soreness(news.is_empty(), date)
	_apply_restrictions(ctx.week)
	var sore := {}
	for area in areas():
		if int(levels[area.id]) > 0:
			sore[area.id] = levels[area.id]
	ctx.log_extra = {"soreness": sore, "health": injuries.map(func(i): return i.id)}


## Sunday night: extra detraining after long breaks (from all training, and running-specific fitness after
## weeks without running), and the rivals' injuries.
func on_week_end(ctx: Dictionary) -> void:
	if not model_enabled:
		return
	if detrain_days > 0:
		var stimulus: Dictionary = ctx.week.stimulus_so_far()
		var loss := float(Data.health.detraining.per_day) * detrain_days
		var a := Game.athlete
		for attr in Data.attributes_in("physical"):
			if float(stimulus.get(attr.id, 0.0)) <= Training.MIN_DOSE:
				var before := a.get_attr(attr.id)
				a.set_attr(attr.id, before - loss)
				a.recent_change[attr.id] = a.recent_change.get(attr.id, 0.0) + a.get_attr(attr.id) - before
		detrain_days = 0
	if run_detrain_days > 0:
		var a := Game.athlete
		var per_day: Dictionary = Data.health.running_detraining.per_day
		for attr_id in per_day:
			var before := a.get_attr(attr_id)
			a.set_attr(attr_id, before - float(per_day[attr_id]) * run_detrain_days)
			a.recent_change[attr_id] = a.recent_change.get(attr_id, 0.0) + a.get_attr(attr_id) - before
		run_detrain_days = 0
	var cfg: Dictionary = Data.health.rivals
	for r in Game.rivals:
		if Rivals.is_out(r):
			r.out_weeks = int(r.out_weeks) - 1
		elif rng.randf() < float(cfg.weekly_chance):
			r.out_weeks = rng.randi_range(int(cfg.weeks[0]), int(cfg.weeks[1]))


## The "sore" warning: keep going / take it easy today / rest day (today = the day not played yet). When that
## day is a race day (the event has the meet's key) the choices are race as planned / scratch from the race.
func on_answer(event: Dictionary, choice: String) -> void:
	if event.get("kind", "") != "sore":
		return
	if choice == "scratch" and event.has("meet"):
		Game.scratch_race(str(event.meet))
		return
	var week := Game.current_week()
	match choice:
		"easy": week.set_intensity(week.day, "easy", "player")
		"rest": week.make_rest_day(week.day, "player")


# --- The body ------------------------------------------------------------------------------------

func _done_sessions(rec: Dictionary) -> Array:
	if rec.race != "":
		return [Data.competitions.race_session]
	var list := []
	for sid in rec.sessions:
		list.append(Data.get_session(sid))
	return list


func _count_day(rec: Dictionary) -> void:
	var trained: bool = not rec.sessions.is_empty() or rec.race != ""
	days_without_training = 0 if trained else days_without_training + 1
	if days_without_training > int(Data.health.detraining.after_days):
		detrain_days += 1
	var ran: bool = rec.race != ""
	for sid in rec.sessions:
		ran = ran or "run" in Data.get_session(sid).get("tags", [])
	days_without_running = 0 if ran else days_without_running + 1
	if days_without_running > int(Data.health.running_detraining.after_days):
		run_detrain_days += 1
	var rule := rule_at(1)   # today's limits (injuries move on after this)
	for inj in injuries:
		if inj.tier == "illness":
			counters.days_ill += 1
			break
	for inj in injuries:
		if inj.tier != "illness":
			counters.days_injured += 1
			break
	if rule.bans.has("run") or rule.has_allow_only:
		counters.days_out += 1


## One day of training on the body: strain added per area (with every multiplier), then the daily fade.
func _body_day(a: Athlete, sessions: Array, level: String, is_race: bool, date: Dictionary, fatigue: float) -> void:
	var cfg: Dictionary = Data.health.strain
	var month := int(date.month)
	var level_mult := 1.0 if is_race else float(Training.intensity(level).get("strain", 1.0))
	var input := {}
	var impact := 0.0
	for s in sessions:
		var st: Dictionary = s.get("strain", {})
		var off_track := not is_race and Training.effectiveness(a, s, month) < 1.0
		for area_id in st:
			var v := float(st[area_id]) * level_mult
			impact += v
			if off_track and area_id in cfg.hard_surface_areas:
				v *= float(cfg.hard_surface)
			input[area_id] = input.get(area_id, 0.0) + v
	impacts.append(impact)
	while impacts.size() > int(cfg.spike.chronic_days):
		impacts.pop_front()
	_adapt()
	var common := _fatigue_mult(fatigue) * _durability_mult(a) * spike_mult() / capacity()
	var fade := (a.get_attr("recovery_rate") - 10.0) * float(cfg.fade_per_recovery_point) \
			+ (a.get_attr("professionalism") - 10.0) * float(cfg.fade_per_professionalism_point)
	if sessions.is_empty():
		fade += float(cfg.rest_day_extra_fade)
	var growth := growth_closeness(a, date)
	for area in areas():
		var keep := clampf(float(area.keep) - fade, 0.3, 0.98)
		var added := float(input.get(area.id, 0.0))
		if added > 0.0:
			added *= common * (1.0 + float(cfg.growth.areas.get(area.id, 0.0)) * growth) * _history_mult(area.id)
		strain[area.id] = float(strain.get(area.id, 0.0)) * keep + added


func _fatigue_mult(fatigue: float) -> float:
	var cfg: Dictionary = Data.health.strain
	var from := float(cfg.fatigue_from)
	return 1.0 + float(cfg.fatigue_extra) * maxf(0.0, fatigue - from) / (100.0 - from)


func _durability_mult(a: Athlete) -> float:
	var cfg: Dictionary = Data.health.strain
	return lerpf(float(cfg.durability_at_1), float(cfg.durability_at_20), (a.get_attr("durability") - 1.0) / 19.0)


## Acute vs chronic load: this week's impact against the weekly average of the last 4 weeks.
func load_ratio() -> float:
	var spike: Dictionary = Data.health.strain.spike
	var acute := 0.0
	for i in range(maxi(0, impacts.size() - int(spike.acute_days)), impacts.size()):
		acute += float(impacts[i])
	var chronic := _chronic_daily() * float(spike.acute_days)
	return acute / maxf(chronic, float(spike.min_chronic) * float(spike.acute_days))


## Average daily impact over the last ~4 weeks.
func _chronic_daily() -> float:
	var total := 0.0
	for x in impacts:
		total += float(x)
	return total / maxf(1.0, impacts.size())


## How much load the body is used to (1.0 = the coach plan's level): strain added is divided by it.
func capacity() -> float:
	return capacity_now


## Capacity moves slowly towards what the last ~4 weeks of load would support.
func _adapt() -> void:
	var cfg: Dictionary = Data.health.strain
	var ad: Dictionary = cfg.adaptation
	var ratio := _chronic_daily() / float(cfg.spike.start_daily_impact)
	var target := clampf(pow(maxf(ratio, 0.0), float(ad.power)), float(ad.min), float(ad.max))
	var days := float(ad.days_up) if target > capacity_now else float(ad.days_down)
	capacity_now += (target - capacity_now) / days


func spike_mult() -> float:
	var spike: Dictionary = Data.health.strain.spike
	return clampf(1.0 + float(spike.per_ratio) * (load_ratio() - float(spike.free_ratio)), 1.0, float(spike.max))


## 0 (not near the growth spurt) – 1 (right in it).
func growth_closeness(a: Athlete, date: Dictionary) -> float:
	var g: Dictionary = Data.health.strain.growth
	var peak := float(g.peak_age[a.gender]) + float(g.maturation_shift.get(a.maturation, 0.0))
	var age := Calendar.days_between(a.birth_date, date) / 365.25
	return maxf(0.0, 1.0 - absf(age - peak) / float(g.half_width))


func _history_mult(area_id: String) -> float:
	var cfg: Dictionary = Data.health.strain.history
	var best := 0.0
	for h in history:
		if h.area == area_id:
			best = maxf(best, 1.0 - (day_no - int(h.healed_no)) / float(cfg.days))
	return 1.0 + float(cfg.extra) * best


func _proneness_mult(a: Athlete) -> float:
	var p: Array = Data.health.injury_risk.proneness
	return lerpf(float(p[0]), float(p[1]), (a.get_attr("injury_proneness") - 1.0) / 19.0)


## Daily overuse-injury chance of an area at its current strain.
func hazard(a: Athlete, area: Dictionary, with_proneness := true) -> float:
	var r: Dictionary = Data.health.injury_risk
	var s := float(strain.get(area.id, 0.0))
	if s <= float(r.zero_below):
		return 0.0
	var h := float(r.at_sore) * pow(2.0, (s - float(r.sore_strain)) / float(r.doubling))
	h *= minf(1.0, (s - float(r.zero_below)) / (float(r.full_from) - float(r.zero_below)))
	if with_proneness:
		h *= _proneness_mult(a)
	if a.gender == "female" and area.kind == "bone":
		h *= float(r.female_bone)
	return h


# --- Injuries ----------------------------------------------------------------------------------

## Today's step for every active injury: trained or raced through (may get worse), then one day closer to fit.
func _progress(a: Athlete, sessions: Array, is_race: bool, date: Dictionary, news: Array) -> void:
	var esc: Dictionary = Data.health.escalation
	for inj in injuries.duplicate():
		var data := Data.get_injury(inj.id)
		var rule := _phase_rule(inj, int(inj.phase))
		var through := false
		if not is_race:
			for s in sessions:
				if _ban_in(s, rule) != "":
					through = true
		if through:
			if inj.tier != "illness":   # a cold runs its course anyway
				inj.left = int(inj.left) + int(esc.extend_days)
			inj.through_days = int(inj.through_days) + 1
		var target := Data.get_injury(data.get("escalates_to", ""))
		var p := 0.0
		if not target.is_empty() and _eligible(target, a, date):
			var sore := float(Data.health.soreness.levels[SORE - 1])
			var load := clampf(pow(float(strain.get(inj.area, 0.0)) / sore, 2.0), float(esc.strain_min), float(esc.strain_max))
			if through:
				p += float(esc.trained_through) * load
			if is_race:
				p += float(esc.raced) * load
			if inj.area != "" and soreness_level(inj.area) >= PAINFUL:
				p += float(esc.painful)
		if p > 0.0 and rng.randf() < p:
			_escalate(inj, target, news)
			continue
		inj.left = int(inj.left) - 1
		while int(inj.left) <= 0:
			inj.phase = int(inj.phase) + 1
			if int(inj.phase) >= inj.days.size():
				_heal(inj, date)
				break
			inj.left = int(inj.left) + int(inj.days[inj.phase])
			Game.post_event(id, "%s: %s" % [data.name, _phase_name(inj, int(inj.phase))],
					"Next step of your recovery: %s." % _phase_rule(inj, int(inj.phase)).texts[0])


func _heal(inj: Dictionary, date: Dictionary) -> void:
	injuries.erase(inj)
	inj.healed = date.duplicate()
	inj.healed_no = day_no
	history.append(inj)
	var data := Data.get_injury(inj.id)
	var text := "You're fully fit again." if inj.tier == "illness" \
			else "You're back to full training. Build up gradually: the area is still a bit vulnerable for a few months."
	Game.post_event(id, "Recovered: %s" % data.name, text)


func _escalate(inj: Dictionary, target: Dictionary, news: Array) -> void:
	inj.id = target.id
	inj.tier = target.tier
	inj.days = _draw_days(target)
	inj.phase = 0
	inj.left = inj.days[0]
	inj.escalated = true
	news.append(inj)


func _draw_days(data: Dictionary) -> Array:
	var days := []
	for ph in data.phases:
		days.append(rng.randi_range(int(ph.days[0]), int(ph.days[1])))
	return days


func _start(data: Dictionary, date: Dictionary, news: Array) -> void:
	var days := _draw_days(data)
	var area: String = data.area
	var inj := {"id": data.id, "first": data.id, "tier": data.tier, "area": area, "cause": data.cause,
			"started": date.duplicate(), "days": days, "phase": 0, "left": days[0], "through_days": 0,
			"warning": _recent_warning(area), "escalated": false}
	injuries.append(inj)
	news.append(inj)


## The highest soreness level the area showed in the last 7 played days (0–3).
func _recent_warning(area_id: String) -> int:
	var days: Array = last_level.get(area_id, [])
	var level := 0
	for i in days.size():
		if day_no - int(days[i]) <= 7:
			level = i + 1
	return level


func _injured(area_id: String) -> bool:
	for inj in injuries:
		if inj.area == area_id:
			return true
	return false


func _eligible(data: Dictionary, a: Athlete, date: Dictionary) -> bool:
	var age := a.age_on(date)
	if age < int(data.get("min_age", 0)) or age > int(data.get("max_age", 99)):
		return false
	return not data.get("growth", false) or growth_closeness(a, date) > 0.0


## Bad luck in today's sessions: sprains and pulled muscles (more when tired), icy roads in winter.
func _roll_acute(a: Athlete, sessions: Array, is_race: bool, date: Dictionary, news: Array) -> void:
	var cfg: Dictionary = Data.health.acute
	var tired := 1.0 + float(cfg.fatigue_extra) * maxf(0.0, a.fatigue - 30.0) / 70.0
	var prone := _proneness_mult(a)
	var ice: Dictionary = cfg.winter_roads
	var month := int(date.month)
	for s in sessions:
		var risks: Dictionary = s.get("acute", {}).duplicate()
		var on_roads: bool = not is_race and "run" in s.get("tags", []) \
				and (not s.get("needs_track", false) or Training.effectiveness(a, s, month) < 1.0)
		if on_roads and Training._in(month, ice.months):
			risks[ice.injury] = float(risks.get(ice.injury, 0.0)) + float(ice.chance)
		for injury_id in risks:
			var data := Data.get_injury(injury_id)
			if data.is_empty() or _injured(data.area):
				continue
			if rng.randf() < float(risks[injury_id]) * tired * prone:
				_start(data, date, news)


## Overuse: each area may give way, more likely the more strained it is.
func _roll_overuse(a: Athlete, date: Dictionary, news: Array) -> void:
	for area in areas():
		if _injured(area.id):
			continue
		var h := hazard(a, area)
		if h > 0.0 and rng.randf() < h:
			var data := _pick_overuse(a, area.id, date)
			if not data.is_empty():
				_start(data, date, news)


## Which overuse injury: catalogue entries of the area whose min_strain is reached; the more overloaded
## the area, the more the worse ones (higher min_strain) weigh. If none is reached yet, the mildest ones.
func _pick_overuse(a: Athlete, area_id: String, date: Dictionary) -> Dictionary:
	var s := float(strain[area_id])
	var mildest := INF
	for data in Data.injuries:
		if data.cause == "overuse" and data.area == area_id and _eligible(data, a, date):
			mildest = minf(mildest, float(data.min_strain))
	s = maxf(s, mildest)
	var bias := float(Data.health.injury_risk.pick_bias)
	var candidates := []
	var weights := []
	var total := 0.0
	for data in Data.injuries:
		if data.cause != "overuse" or data.area != area_id or s < float(data.min_strain) or not _eligible(data, a, date):
			continue
		var w := float(data.weight) * (1.0 + (s - float(data.min_strain)) / bias)
		if a.gender == "female":
			w *= float(data.get("female", 1.0))
		if data.get("growth", false):
			w *= growth_closeness(a, date)
		candidates.append(data)
		weights.append(w)
		total += w
	if candidates.is_empty():
		return {}
	var x := rng.randf() * total
	for i in candidates.size():
		x -= weights[i]
		if x <= 0.0:
			return candidates[i]
	return candidates[-1]


## Colds and flu: more in winter, when tired, in the days after a race; less with good habits.
func _roll_illness(a: Athlete, news: Array) -> void:
	for inj in injuries:
		if inj.tier == "illness":
			return
	var cfg: Dictionary = Data.health.illness
	var month := int(Game.date.month)
	var p := float(cfg.daily) * float(cfg.month_weight[month - 1])
	var from := float(cfg.fatigue_from)
	p *= 1.0 + float(cfg.fatigue_extra) * maxf(0.0, a.fatigue - from) / (100.0 - from)
	if day_no - last_race_no <= int(cfg.after_race_days):
		p *= float(cfg.after_race)
	p *= lerpf(float(cfg.professionalism[0]), float(cfg.professionalism[1]), (a.get_attr("professionalism") - 1.0) / 19.0)
	if rng.randf() >= p:
		return
	var list := Data.injuries.filter(func(d): return d.cause == "illness")
	var total := 0.0
	for d in list:
		total += float(d.weight)
	var x := rng.randf() * total
	for d in list:
		x -= float(d.weight)
		if x <= 0.0:
			_start(d, Game.date, news)
			return
	_start(list[-1], Game.date, news)


func _post_diagnosis(inj: Dictionary) -> void:
	var data := Data.get_injury(inj.id)
	var title: String
	if inj.escalated:
		title = "It got worse: %s" % data.name
	elif inj.tier == "illness":
		title = "You're ill: %s" % data.name
	else:
		title = "Injury: %s" % data.name
	var text := "%s\n\nExpected time: %s. Allowed now: %s." % [data.description, _range_text(data),
			_phase_rule(inj, 0).texts[0]]
	if data.phases[0].get("locked", false):
		text += " This can't be trained through."
	elif inj.tier != "illness":
		text += " You could train through it, but it may get worse."
	var e := Game.post_event(id, title, text, [], true)
	e.kind = "diagnosis"
	e.injury = inj.id   # the UI finds the injury by this id


## The first time an area turns sore (at most once per area every few weeks): a stop event, unless today
## already brought a diagnosis.
func _update_soreness(may_warn: bool, date := {}) -> void:
	if date.is_empty():
		date = Game.date   # the day just played (dev tools that seed a state call it without)
	var newly := []
	for area in areas():
		var lvl := soreness_level(area.id)
		var seen: Array = last_level.get(area.id, [-1000, -1000, -1000])
		for i in lvl:
			seen[i] = day_no
		last_level[area.id] = seen
		var prev := int(levels.get(area.id, 0))
		levels[area.id] = lvl
		if lvl >= SORE and prev < SORE and not _injured(area.id) \
				and day_no - int(warned.get(area.id, -1000)) > int(Data.health.warning.repeat_days):
			newly.append(area)
	if newly.is_empty() or not may_warn:
		return
	var names := []
	for area in newly:
		warned[area.id] = day_no
		names.append(area.name.left(1).to_lower() + area.name.substr(1))   # "heels & Achilles"
	var list: String = names[-1] if names.size() == 1 else ", ".join(names.slice(0, -1)) + " and " + names[-1]
	var text := "After training your %s are sore. Soreness is the body's warning: training on through it " % list \
			+ "is how most running injuries start. "
	var meet := _entered_meet_on(Game.add_days(date, 1))
	var choices := [
		{"id": "keep", "label": "Keep going", "detail": "Train as planned and hope it settles."},
		{"id": "easy", "label": "Take it easy today", "detail": "Today's sessions at Easy intensity."},
		{"id": "rest", "label": "Rest day", "detail": "No training today."},
	]
	if not meet.is_empty():   # a race day can't be made easier: race or scratch
		text += "Today is a race day (%s). What do you do?" % meet.name
		choices = [
			{"id": "keep", "label": "Race as planned", "detail": "Start and see how it goes."},
			{"id": "scratch", "label": "Scratch from the race", "detail": "You won't start; the day becomes a training day you can still change."},
		]
	else:
		text += "What do you do today?"
	var e := Game.post_event(id, "Your %s feel sore" % list, text, choices, true)
	e.kind = "sore"
	if not meet.is_empty():
		e.meet = meet.key


## The entered meet on `date`, or {}.
func _entered_meet_on(date: Dictionary) -> Dictionary:
	for key in Game.entries:
		var meet := Calendar.get_meet(key)
		if not meet.is_empty() and Calendar.date_key(meet.date) == Calendar.date_key(date):
			return meet
	return {}


# --- Restrictions ------------------------------------------------------------------------------

## The phase an injury is in `k` days from now (k = 1: the next day to be played), or -1 when healed by then.
func _phase_at(inj: Dictionary, k: int) -> int:
	var p := int(inj.phase)
	var left := int(inj.left)
	while k > left:
		k -= left
		p += 1
		if p >= inj.days.size():
			return -1
		left = int(inj.days[p])
	return p


func _phase_name(inj: Dictionary, phase: int) -> String:
	var ph: Dictionary = Data.get_injury(inj.id).phases[phase]
	return Data.health.restrictions[ph.restriction].name


## What one injury phase allows: {bans: {tag: reason}, has_allow_only, allow_only, intensity, locked,
## reasons ("Shin splints: easy running only"), texts ("easy running only")}.
func _phase_rule(inj: Dictionary, phase: int) -> Dictionary:
	var rule := _empty_rule()
	_merge(rule, inj, phase)
	return rule


func _empty_rule() -> Dictionary:
	return {"active": false, "bans": {}, "has_allow_only": false, "allow_only": [], "intensity": "",
			"locked": false, "reasons": [], "texts": []}


func _merge(rule: Dictionary, inj: Dictionary, phase: int) -> void:
	var data := Data.get_injury(inj.id)
	var ph: Dictionary = data.phases[phase]
	var preset: Dictionary = Data.health.restrictions[ph.restriction]
	var reason := "%s: %s" % [data.name, preset.text]
	rule.active = true
	rule.reasons.append(reason)
	rule.texts.append(preset.text)
	for tag in preset.get("bans", []) + ph.get("bans", []):
		if not rule.bans.has(tag):
			rule.bans[tag] = reason
	if preset.has("allow_only"):
		if rule.has_allow_only:
			rule.allow_only = rule.allow_only.filter(func(x): return x in preset.allow_only)
		else:
			rule.allow_only = preset.allow_only.duplicate()
		rule.has_allow_only = true
		rule.allow_reason = reason
	var level: String = preset.get("intensity", "")
	if level != "" and (rule.intensity == "" or Training.INTENSITIES.find(level) < Training.INTENSITIES.find(rule.intensity)):
		rule.intensity = level
	if ph.get("locked", false):
		rule.locked = true


## Everything active `k` days from now, combined.
func rule_at(k: int) -> Dictionary:
	var rule := _empty_rule()
	for inj in injuries:
		var p := _phase_at(inj, k)
		if p >= 0:
			_merge(rule, inj, p)
	return rule


## Why `session` isn't allowed under `rule` ("" = allowed).
func _ban_in(s: Dictionary, rule: Dictionary) -> String:
	if not rule.active:
		return ""
	if rule.has_allow_only and not s.get("id", "") in rule.allow_only:
		return rule.allow_reason
	for tag in s.get("tags", []):
		if rule.bans.has(tag):
			return rule.bans[tag]
	return ""


## The day's sessions under `rule`: banned ones swapped for their first allowed "instead" session, or dropped.
func _restricted_ids(ids: Array, rule: Dictionary, month: int) -> Array:
	var out := []
	for sid in ids:
		var s := Data.get_session(sid)
		if _ban_in(s, rule) == "":
			out.append(sid)
			continue
		for alt in s.get("instead", []):
			var alt_s := Data.get_session(alt)
			if not alt in out and not alt in ids and _ban_in(alt_s, rule) == "" and Training.is_available(alt_s, month):
				out.append(alt)
				break
	return out


## Writes the limits into this week's days from `week.day` on, as day changes "by" injury. A day the
## player chose to train through (override_day) is left alone unless the limits are locked; when the
## limits end, the injury's changes go back to the plan.
func _apply_restrictions(week: WeekSim) -> void:
	var month: int = Game.add_days(week.monday, 3).month
	for d in range(week.day, 7):
		if not week.can_change(d):
			continue
		var rule := rule_at(d - week.day + 1)
		var key := Calendar.date_key(Game.add_days(week.monday, d))
		if key in overrides:
			if not rule.locked:
				continue
			overrides.erase(key)
		var c: Dictionary = week.changes.get(d, {})
		var sessions_by_injury: bool = c.has("sessions") and c.sessions.by == "injury"
		var intensity_by_injury: bool = c.has("intensity") and c.intensity.by == "injury"
		var base: Array = week.plan[d] if sessions_by_injury or not c.has("sessions") else c.sessions.value
		var ids: Array = _restricted_ids(base, rule, month) if rule.active else base
		if ids != week.session_ids(d):
			week.set_sessions(d, ids, "injury")
		if rule.intensity != "":
			if Training.INTENSITIES.find(week.intensity(d)) > Training.INTENSITIES.find(rule.intensity):
				week.set_intensity(d, rule.intensity, "injury")
		elif intensity_by_injury:
			week.set_intensity(d, week.plan_intensity[d], "injury")   # back to the plan's own intensity


# --- For the UI (M2 step 4) ----------------------------------------------------------------------

## 0 None, 1 A bit sore, 2 Sore, 3 Painful.
func soreness_level(area_id: String) -> int:
	var s := float(strain.get(area_id, 0.0))
	var level := 0
	for t in Data.health.soreness.levels:
		if s >= float(t):
			level += 1
	return level


static func soreness_word(level: int) -> String:
	return Data.health.soreness.names[level]


## Every body area: [{id, name, level, word}], in the data order.
func soreness() -> Array:
	var list := []
	for area in areas():
		var lvl := soreness_level(area.id)
		list.append({"id": area.id, "name": area.name, "level": lvl, "word": soreness_word(lvl)})
	return list


## Why an area is sore (plain-language causes, most important first) and what helps: {causes, helps}.
func soreness_info(area_id: String) -> Dictionary:
	var a := Game.athlete
	var area := {}
	for x in areas():
		if x.id == area_id:
			area = x
	var causes := []
	var by_session := {}
	for e in Game.day_log.slice(-7):
		for sid in e.sessions:
			var s := Data.get_session(sid)
			by_session[s.name] = by_session.get(s.name, 0.0) + float(s.get("strain", {}).get(area_id, 0.0))
		if e.race != "":
			by_session["Racing"] = by_session.get("Racing", 0.0) \
					+ float(Data.competitions.race_session.strain.get(area_id, 0.0))
	var names := by_session.keys().filter(func(n): return by_session[n] > 0.0)
	names.sort_custom(func(x, y): return by_session[x] > by_session[y])
	if not names.is_empty():
		causes.append("Recent training: %s." % ", ".join(names.slice(0, 2)))
	if load_ratio() > float(Data.health.strain.spike.free_ratio):
		causes.append("A sudden jump in training load: more than your body is used to.")
	if a.fatigue >= 45.0:
		causes.append("Tired legs: strain builds faster when you're tired.")
	if float(Data.health.strain.growth.areas.get(area_id, 0.0)) > 0.0 and growth_closeness(a, Game.date) > 0.3:
		causes.append("You're growing fast right now, and growth plates are vulnerable.")
	if _history_mult(area_id) > 1.05:
		causes.append("An old injury here that is still a weak spot.")
	return {"causes": causes, "helps": area.get("helps", "")}


## Active injuries and illness for the Today card and the diagnosis panel:
## [{id, name, tier, area, area_name, description, phase_name, allowed, locked, days_left, range,
##   expected_return (date), escalated}]
func active() -> Array:
	var list := []
	for inj in injuries:
		var data := Data.get_injury(inj.id)
		var p := int(inj.phase)
		var days_left := int(inj.left)
		for i in range(p + 1, inj.days.size()):
			days_left += int(inj.days[i])
		var area_name := ""
		for x in areas():
			if x.id == inj.area:
				area_name = x.name
		list.append({"id": inj.id, "name": data.name, "tier": inj.tier, "area": inj.area, "area_name": area_name,
				"description": data.description, "phase_name": _phase_name(inj, p),
				"allowed": _phase_rule(inj, p).texts[0], "locked": data.phases[p].get("locked", false),
				"days_left": days_left, "range": _range_text(data),
				"expected_return": Game.add_days(Game.date, days_left), "escalated": inj.escalated})
	return list


## Why a session can't be done on day `d` of the current week ("" = allowed), e.g. "Shin splints: easy running only".
func ban_reason(session_id: String, d: int) -> String:
	var week := Game.current_week()
	return _ban_in(Data.get_session(session_id), rule_at(d - week.day + 1))


## The limits on day `d` of the current week are locked (serious injury, fever): no override, no racing.
func day_locked(d: int) -> bool:
	var week := Game.current_week()
	return rule_at(d - week.day + 1).locked


## The player may train through the limits on day `d` (after a clear warning in the UI).
func can_override(d: int) -> bool:
	var week := Game.current_week()
	if not week.can_change(d):
		return false
	var rule := rule_at(d - week.day + 1)
	return rule.active and not rule.locked


## Train through the limits on day `d`: the day goes back to the plan (by the player) and stays that way.
## Training through can make the problem worse. False if it isn't allowed.
func override_day(d: int) -> bool:
	if not can_override(d):
		return false
	var week := Game.current_week()
	overrides.append(Calendar.date_key(Game.add_days(week.monday, d)))
	var c: Dictionary = week.changes.get(d, {})
	if c.has("sessions") and c.sessions.by == "injury":
		week.set_sessions(d, week.plan[d], "player")
	if c.has("intensity") and c.intensity.by == "injury":
		week.set_intensity(d, week.plan_intensity[d], "player")
	return true


## Take back "train through it" for day `d`: the limits go into the day again (banned sessions are swapped
## as before). False if the day wasn't trained through, or can't be changed any more.
func cancel_override(d: int) -> bool:
	var week := Game.current_week()
	var key := Calendar.date_key(Game.add_days(week.monday, d))
	if not week.can_change(d) or not key in overrides:
		return false
	overrides.erase(key)
	_apply_restrictions(week)
	return true


## Racing today: {ok, reason}. A niggle or a cold allows it (slower, may get worse); locked limits don't.
func can_race() -> Dictionary:
	var rule := rule_at(1)
	if rule.locked:
		return {"ok": false, "reason": rule.reasons[0]}
	return {"ok": true, "reason": rule.reasons[0] if rule.active else ""}


## How much slower the athlete races with today's problems (0.02 = 2 %), the worst one counts.
func race_slowdown() -> float:
	if not model_enabled:
		return 0.0
	var worst := 0.0
	for inj in injuries:
		if _phase_at(inj, 1) >= 0:
			worst = maxf(worst, float(Data.get_injury(inj.id).get("race_slowdown", 0.0)))
	return worst


## The week's load against the athlete's normal (the average week of the last 4), in percent:
## played days as done, the rest as planned now. 100 = as usual.
## `week_or_plan` is a WeekSim, or a week plan (see WeekPlan; the old plain Array works too): a plan is taken as
## this week with nothing played and no day changes.
## `from` = a lead-in (see `projected`): the plan as the week the lead-in ends on, against the normal of the
## weeks before it.
func load_vs_normal(week_or_plan: Variant, from := {}) -> int:
	if not from.is_empty():
		return from.health.load_vs_normal(WeekSim.new(from.athlete, week_or_plan, from.monday))
	if impacts.is_empty():
		return 100
	var week: WeekSim = week_or_plan if week_or_plan is WeekSim \
			else WeekSim.new(Game.athlete, week_or_plan, Game.week_monday())
	var total := 0.0
	for d in 7:
		if d < week.day:
			for r in week.played:
				if int(r.day) == d:
					total += _impact(_done_sessions(r), r.intensity, r.race != "")
		elif week.is_race_day(d):
			total += _impact([Data.competitions.race_session], WeekSim.NORMAL, true)
		else:
			var list := []
			for sid in week.session_ids(d):
				list.append(Data.get_session(sid))
			total += _impact(list, week.intensity(d), false)
	var normal := 0.0
	for x in impacts:
		normal += float(x)
	normal = normal / impacts.size() * 7.0
	return roundi(total / maxf(normal, 1.0) * 100.0)


func _impact(sessions: Array, level: String, is_race: bool) -> float:
	var mult := 1.0 if is_race else float(Training.intensity(level).get("strain", 1.0))
	var total := 0.0
	for s in sessions:
		for area_id in s.get("strain", {}):
			total += float(s.strain[area_id]) * mult
	return total


## The weekly plan's injury risk from the body's current state: "low" / "moderate" / "high" (RISK_NAMES).
## `plan` is a week plan (days and intensity, see WeekPlan; the old plain Array of days works too).
## Plays the plan for a few weeks on copies (no dice), counting expected overuse injuries at average
## injury proneness, so it never gives the hidden value away.
## `from` = a lead-in (see `projected`): the risk of switching into the plan when the lead-in ends.
func plan_risk(plan: Variant, from := {}) -> String:
	var cfg: Dictionary = Data.health.plan_risk
	var copy := HealthSystem.new()
	var base: HealthSystem = from.get("health", self)
	copy.from_dict(base.to_dict().duplicate(true))
	copy._ensure_started()
	copy.injuries = []
	var a := Athlete.from_dict((from.athlete if from.has("athlete") else Game.athlete).to_dict().duplicate(true))
	var monday: Dictionary = from.get("monday", Game.week_monday())
	var expected := 0.0
	for w in int(cfg.weeks):
		var week := WeekSim.new(a, plan, monday)
		while not week.is_over():
			var rec := week.play_day()
			copy._body_day(a, copy._done_sessions(rec), rec.intensity, false, Game.add_days(monday, int(rec.day)), float(rec.fatigue))
			copy.day_no += 1
			for area in areas():
				expected += copy.hazard(a, area, false)
		monday = Game.add_days(monday, 7)
	if expected >= float(cfg.high):
		return "high"
	return "moderate" if expected >= float(cfg.moderate) else "low"


## The lead-in for a future phase (GDD 4.8 UI, "Future phases"): the body and the athlete as they would be on the
## Monday `until` if the season plan were followed from today. Plays the rest of this week (with its day changes
## and races) and every week up to `until` on copies, races as races, with no dice and no injuries; the weekly
## progression is applied too. Returns {"health", "athlete", "monday"} for plan_risk / load_vs_normal.
## About 6 ms per 4 weeks: the UI computes it only for the phase it shows and keeps it until the plan changes.
func projected(until: Dictionary) -> Dictionary:
	var copy := HealthSystem.new()
	copy.from_dict(to_dict().duplicate(true))
	copy._ensure_started()
	copy.injuries = []
	var a := Athlete.from_dict(Game.athlete.to_dict().duplicate(true))
	var now := Game.current_week()
	var week := WeekSim.from_dict(a, WeekPlan.make(now.plan, now.plan_intensity), now.to_dict().duplicate(true))
	week.races = now.races
	var monday: Dictionary = now.monday
	var guard := 0
	while Calendar.date_key(monday) < Calendar.date_key(until) and guard < 60:
		guard += 1
		while not week.is_over():
			var rec: Dictionary = week.race_done("") if week.is_race_day(week.day) else week.play_day()
			copy._body_day(a, copy._done_sessions(rec), rec.intensity, rec.race != "",
					Game.add_days(monday, int(rec.day)), float(rec.fatigue))
			copy.day_no += 1
		week.end_week()
		monday = Game.add_days(monday, 7)
		week = WeekSim.new(a, Game.season.week_for(monday), monday, Calendar.races_in_week(Game.entries, monday))
	return {"health": copy, "athlete": a, "monday": until}


## After repeated injuries the game may hint that the athlete picks up knocks easily (proneness stays hidden).
func proneness_hint() -> bool:
	var cfg: Dictionary = Data.health.proneness_hint
	var n := 0
	for inj in history + injuries:
		if inj.tier != "illness" and day_no - _started_no(inj) <= int(cfg.days):
			n += 1
	return n >= int(cfg.injuries)


func _started_no(inj: Dictionary) -> int:
	return day_no - Calendar.days_between(inj.started, Game.date)


## Dev only (H key in the hub, tools/health_season.gd): the hidden numbers in a few lines of text.
func debug_text() -> String:
	if not started:
		return "Health: not started yet (play a day)."
	var lines := ["== Health on %s (day %d)" % [Calendar.format_day(Game.date), day_no]]
	var parts := []
	for x in soreness():
		parts.append("%s %d (%s)" % [x.name, roundi(float(strain[x.id])), x.word])
	lines.append("Strain: " + ", ".join(parts))
	lines.append("Capacity ×%.2f, load ratio %.2f (spike ×%.2f), load vs normal this week %d%%, plan risk %s" % [
			capacity(), load_ratio(), spike_mult(), load_vs_normal(Game.current_week()),
			RISK_NAMES[plan_risk(Game.season.week_for(Game.week_monday()))]])
	for x in active():
		lines.append("Active: %s (%s): %s, %d days left (%s)%s" % [x.name, x.tier, x.allowed, x.days_left, x.range,
				", locked" if x.locked else ""])
	lines.append("History: %d injuries/illnesses, %d days injured, %d days with no running, %d days ill" % [
			history.size(), counters.days_injured, counters.days_out, counters.days_ill])
	return "\n".join(lines)


## "1–3 weeks" / "3–7 days": the whole time an injury takes, from its phases.
func _range_text(data: Dictionary) -> String:
	var lo := 0
	var hi := 0
	for ph in data.phases:
		lo += int(ph.days[0])
		hi += int(ph.days[1])
	if hi < 14:
		return "%d–%d days" % [lo, hi]
	return "%d–%d weeks" % [maxi(1, roundi(lo / 7.0)), roundi(hi / 7.0)]


# --- Save / load -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if not started:
		return {}
	return {"started": true, "rng_seed": str(rng.seed), "rng_state": str(rng.state), "day_no": day_no,
			"strain": strain, "impacts": impacts, "capacity": capacity_now, "injuries": injuries, "history": history, "warned": warned,
			"last_level": last_level, "levels": levels, "overrides": overrides,
			"days_without_training": days_without_training, "detrain_days": detrain_days,
			"days_without_running": days_without_running, "run_detrain_days": run_detrain_days,
			"last_race_no": last_race_no, "counters": counters}


## An empty state (a save from before the health model) starts fresh on the next played day.
func from_dict(d: Dictionary) -> void:
	if not d.get("started", false):
		return
	started = true
	rng.seed = str(d.rng_seed).to_int()
	rng.state = str(d.rng_state).to_int()
	day_no = int(d.day_no)
	strain = d.strain
	impacts = d.impacts
	capacity_now = float(d.capacity)
	injuries = d.injuries
	history = d.history
	for inj in injuries + history:
		inj.started = Game.int_date(inj.started)
		inj.phase = int(inj.phase)
		inj.left = int(inj.left)
		inj.through_days = int(inj.through_days)
		inj.warning = int(inj.warning)
		inj.days = inj.days.map(func(x): return int(x))
		if inj.has("healed"):
			inj.healed = Game.int_date(inj.healed)
			inj.healed_no = int(inj.healed_no)
	for key in d.warned:
		warned[key] = int(d.warned[key])
	for key in d.last_level:
		last_level[key] = d.last_level[key].map(func(x): return int(x))
	for key in d.levels:
		levels[key] = int(d.levels[key])
	overrides = d.overrides.map(func(x): return int(x))
	days_without_training = int(d.days_without_training)
	detrain_days = int(d.detrain_days)
	days_without_running = int(d.get("days_without_running", 0))   # saves from before this was added
	run_detrain_days = int(d.get("run_detrain_days", 0))
	last_race_no = int(d.last_race_no)
	for key in d.counters:
		counters[key] = int(d.counters[key])
