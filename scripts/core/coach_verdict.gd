class_name CoachVerdict
extends RefCounted
## The coach's verdict on a change of the training (GDD 4.9.2 "Ask the coach", session C4; headless, reading only).
## THE TRUTH: the game plays the change and what it replaces on copies (the athlete, the body, Form; no dice) from today over
## the rest of this week and data/coaching.json verdict.window_weeks more, and compares: the 800 m ability at the end (the
## training through Training._apply_progression), the expected overuse injuries (the health model's daily hazard at average
## proneness, as HealthSystem.plan_risk) and race-day Form at the races in the window. Everything is put in WEEKS OF TRAINING
## (train, risk, form, race) and gives one of Good idea / Fine / Pointless / Risky (classify).
## THE COACH: sees each part through his attributes (perceive: noise by endurance / speed & strength knowledge, load
## management, periodization; his demands weigh the parts), so a weak coach can be wrong both ways and a demanding one
## dislikes Easy days even when they are right. His dice come from the coach, the date and the change: the same question on
## the same day gets the same answer. CoachTalk-style text in his voice and detail (say).
## A change: {kind ("day" / "race" / "week" / "phase" / "proposal"), start (the state to play from, see now_start), base and
## cand (lists of week specs, see _week_of), days ([{d, date, base: {sessions, intensity}, cand: {...}}]: what changed, for the
## texts), compare (a key of coach_talk.json verdict.compare), sig (a text that names the change for the dice)}.

const GOOD := "good"
const FINE := "fine"
const POINTLESS := "pointless"
const RISKY := "risky"
const ORDER := [GOOD, FINE, POINTLESS, RISKY]


static func cfg() -> Dictionary:
	return Data.coaching.verdict


# --- The state to play from, and the changes ----------------------------------------------------------

## Today's state: the body (null with the health model off), the athlete, sharpness and the week in progress.
static func now_start() -> Dictionary:
	var h := Game.get_system("health") as HealthSystem
	var f := Game.get_system("form") as FormSystem
	return {"health": h if HealthSystem.model_enabled else null, "athlete": Game.athlete,
			"sharpness": f.sharpness if f else float(Data.form.sharpness.neutral), "week": Game.current_week()}


## {sessions, intensity} of day `d` of the week in progress as it stands.
static func day_now(w: WeekSim, d: int) -> Dictionary:
	return {"sessions": w.session_ids(d).duplicate(), "intensity": w.intensity(d)}


## A change of days of the week in progress: `base` and `cand` = {day index: {sessions, intensity}} (the days not named are
## played as they stand in both). `scratch` = day indices whose race is left out of the candidate.
static func day_change(base: Dictionary, cand: Dictionary, compare := "day_changed", scratch := [], kind := "day") -> Dictionary:
	var w := Game.current_week()
	var days := []
	var sig := []
	var keys := cand.keys()
	keys.sort()
	for d in keys:
		days.append({"d": int(d), "date": Game.add_days(w.monday, int(d)), "base": base.get(d, day_now(w, int(d))), "cand": cand[d]})
		sig.append("%d:%s:%s" % [int(d), ",".join(cand[d].sessions), cand[d].intensity])
	var start := now_start()
	var nxt := Game.add_days(w.monday, 7)
	var base_weeks := [{"current": true, "set": base, "scratch": []}]
	var cand_weeks := [{"current": true, "set": cand, "scratch": scratch}]
	for i in int(cfg().window_weeks):
		var monday := Game.add_days(nxt, 7 * i)
		var spec := {"plan": Game.season.week_for(monday), "monday": monday}
		base_weeks.append(spec)
		cand_weeks.append(spec)
	return {"kind": kind, "start": start, "base": base_weeks, "cand": cand_weeks, "days": days, "compare": compare,
			"sig": "%s|%s|%s" % [kind, "/".join(sig), ",".join(scratch.map(func(x): return str(x)))]}


## Ask the coach about day `d` of this week (the day editor): the day as it stands against the plan's day; an unchanged day
## against a rest day (is it worth doing?), an unchanged rest day against an easy run (is resting right?).
static func for_day(d: int) -> Dictionary:
	var w := Game.current_week()
	var cur := day_now(w, d)
	var plan := {"sessions": w.plan[d].duplicate(), "intensity": str(w.plan_intensity[d])}
	if cur.sessions != plan.sessions or cur.intensity != plan.intensity:
		return day_change({d: plan}, {d: cur}, "day_changed")
	if cur.sessions.is_empty():
		return day_change({d: {"sessions": [str(Data.coaching.proposals.easy_session)], "intensity": WeekSim.NORMAL}}, {d: cur}, "day_rest")
	return day_change({d: {"sessions": [], "intensity": cur.intensity}}, {d: cur}, "day_plan")


## Race or scratch on race day `d` of this week: the race (candidate) against scratching and running easy (base).
static func for_race(d: int) -> Dictionary:
	var c := race_change(d)
	# (swap the sides: the question is "is racing a good idea?")
	return {"kind": "race", "start": c.start, "base": c.cand, "cand": c.base, "days": c.days, "compare": "race",
			"sig": "race|%d" % d, "meet": c.meet}


## The scratch proposal of race day `d`: the race (base) against scratching it and running easy that day (candidate).
static func race_change(d: int) -> Dictionary:
	var w := Game.current_week()
	var easy := {"sessions": [str(Data.coaching.proposals.easy_session)], "intensity": "easy"}
	var c := day_change({}, {d: easy}, "race", [d], "scratch")
	c.base[0]["set"] = {}
	c.days[0].base = {"sessions": [], "intensity": WeekSim.NORMAL, "race": true}
	c.meet = w.races.get(d, {})
	return c


## Is racing meet `m` (not entered yet) a good idea? (session C5, "Coach suggests".) The weeks from now to a week after the meet
## played with the meet entered (candidate) and as they are (base), from today's state. Parts as for any change: the race replaces a
## training day (train), its load and strain (risk), the race value of its level (race). `weeks` = how many weeks ahead it is.
static func meet_change(meet: Dictionary) -> Dictionary:
	var key := str(meet.key)
	var start := now_start()
	var w := Game.current_week()
	var n := clampi(roundi(Calendar.days_between(w.monday, Calendar.monday_of(meet.date)) / 7.0), 0, int(Data.advice.suggest.max_weeks))
	var base_weeks := [{"current": true, "set": {}, "scratch": []}]
	var cand_weeks := [{"current": true, "set": {}, "scratch": [], "enter": [key]}]
	for i in range(1, n + 1 + int(Data.advice.suggest.after_weeks)):
		var monday := Game.add_days(w.monday, 7 * i)
		var plan := Game.season.week_for(monday)
		base_weeks.append({"plan": plan, "monday": monday})
		cand_weeks.append({"plan": plan, "monday": monday, "enter": [key]})
	return {"kind": "meet", "start": start, "base": base_weeks, "cand": cand_weeks, "days": [], "compare": "meet", "meet": meet,
			"sig": "meet|%s" % key}


## Is making meet `m` a target (the season plan built round it, and the meet entered) a good idea? The same weeks played with the
## target added to a copy of the season plan (candidate) and with the plan as it is (base); the target weight and race value count
## for the meet in both, so the taper, the Form and the race itself show in the parts.
static func target_change(meet: Dictionary) -> Dictionary:
	var key := str(meet.key)
	var start := now_start()
	var w := Game.current_week()
	var year := SeasonPlan.year_of(meet.date)
	var n := clampi(roundi(Calendar.days_between(w.monday, Calendar.monday_of(meet.date)) / 7.0), 0, int(Data.advice.suggest.max_weeks))
	var copy := Game.season.copy()
	copy.add_target(year, key)
	var base_weeks := [{"current": true, "set": {}, "scratch": []}]
	var cand_weeks := [{"current": true, "set": {}, "scratch": [], "enter": [key]}]
	for i in range(1, n + 1 + int(Data.advice.suggest.after_weeks)):
		var monday := Game.add_days(w.monday, 7 * i)
		base_weeks.append({"plan": Game.season.week_for(monday), "monday": monday})
		cand_weeks.append({"plan": copy.week_for(monday), "monday": monday, "enter": [key]})
	return {"kind": "target", "start": start, "base": base_weeks, "cand": cand_weeks, "days": [], "compare": "target", "meet": meet,
			"target": key, "sig": "target|%s" % key}


## A week plan for the coming weeks (the Training tab: this week's plan, the phase editor: the phase's week): the rest of this
## week as it stands, then `cand` against `base` for window_weeks + 1 weeks. `start` = a lead-in (HealthSystem.projected, for a
## future phase) or {} = today. `ref_equal` = the plans are the same (then base is the lighter week: is the plan worth it?).
static func week_change(cand: Dictionary, base: Dictionary, compare: String, start := {}, first_monday := {}) -> Dictionary:
	var s := now_start()
	var weeks := int(cfg().window_weeks) + 1
	var base_weeks := []
	var cand_weeks := []
	var monday: Dictionary = first_monday
	if start.is_empty():
		base_weeks.append({"current": true, "set": {}, "scratch": []})
		cand_weeks.append({"current": true, "set": {}, "scratch": []})
		if monday.is_empty():
			monday = Game.add_days(Game.current_week().monday, 7)
	else:
		s.health = start.health if HealthSystem.model_enabled else null
		s.athlete = start.athlete
		s.week = null
		monday = start.monday
	for i in weeks:
		var m := Game.add_days(monday, 7 * i)
		base_weeks.append({"plan": base, "monday": m})
		cand_weeks.append({"plan": cand, "monday": m})
	return {"kind": "week", "start": s, "base": base_weeks, "cand": cand_weeks, "days": [], "compare": compare,
			"sig": "week|%s|%s|%s" % [compare, JSON.stringify(cand), Calendar.date_key(monday)]}


## Ask the coach about the weekly plan (the Training tab): the plan from next week on as it is now against the coach's (repeat
## mode: WeekPlan.coach(); season mode: the same season with this phase put back to the coach's); a plan that is the coach's
## own is asked about against the same week one step easier (is the work worth it?).
static func for_week() -> Dictionary:
	var next := Game.add_days(Game.current_week().monday, 7)
	var cand: Dictionary
	var base := {}
	if Game.season.mode == SeasonPlan.PHASES:
		var plan := Game.season.week_for(next)
		cand = WeekPlan.make(plan.days, plan.intensity)
		var year := Game.season.plan_year(next)
		var phase := str(plan.get("phase", ""))
		if phase != "" and Game.season.is_edited(year, phase):
			var coach := Game.season.copy()
			coach.reset_phase(year, phase)
			var theirs := coach.week_for(next)
			base = WeekPlan.make(theirs.days, theirs.intensity)
	else:
		cand = WeekPlan.copy_of(Game.season.repeat_week)
		if not WeekPlan.equals(cand, WeekPlan.coach()):
			base = WeekPlan.coach()
	if base.is_empty() or WeekPlan.equals(base, cand):
		return week_change(cand, lighter_of(cand), "week_plan")
	return week_change(cand, base, "week_changed")


## Ask the coach about a phase's week (the phase editor): as you changed it against the coach's template, or (unchanged) against
## one step easier. `start` = the lead-in to a future phase (SeasonUI.lead_in: {health, athlete, monday}; {} = from today) and
## `first` = its first Monday ({} = the phase runs now: from next Monday).
static func for_phase(year: int, phase_id: String, start := {}, first := {}) -> Dictionary:
	var tmpl := Game.season.template_for(year, phase_id)
	var week: Dictionary = Game.season.edit_phase(year, phase_id) if Game.season.is_edited(year, phase_id) else tmpl
	var cand := WeekPlan.make(week.days, week.intensity)
	if WeekPlan.equals(cand, tmpl):
		return week_change(cand, lighter_of(cand), "phase_plan", start, first)
	return week_change(cand, WeekPlan.make(tmpl.days, tmpl.intensity), "phase_changed", start, first)


## The same week one step easier every day (Hard -> Normal -> Easy); an all-Easy week becomes a week of rest.
static func lighter_of(plan: Dictionary) -> Dictionary:
	var p := WeekPlan.of(plan)
	var level := []
	var changed := false
	for d in 7:
		var i := Training.INTENSITIES.find(str(p.intensity[d]))
		var down := str(Training.INTENSITIES[maxi(0, i - 1)])
		changed = changed or (down != p.intensity[d] and not p.days[d].is_empty())
		level.append(down)
	if not changed:
		return WeekPlan.empty()
	return WeekPlan.make(p.days.duplicate(true), level)


# --- The truth -------------------------------------------------------------------------------------------------

## Plays a list of week specs from `start` on copies. A spec is {current: true, set: {d: {sessions, intensity}}, scratch: [d]}
## (the week in progress as it stands, with those days set and those races left out) or {plan, monday} (a new week of that
## plan with the entered races of that week). Returns {athlete (the copy at the end), exp (expected overuse injuries), races
## ([{key, meet, form (on race morning), date}]), days (played)}.
static func simulate(start: Dictionary, weeks: Array) -> Dictionary:
	var h: HealthSystem = null
	if start.get("health") != null:
		h = HealthSystem.new()
		h.from_dict(start.health.to_dict().duplicate(true))
		h._ensure_started()
		h.injuries = []
	var a := Athlete.from_dict(start.athlete.to_dict().duplicate(true))
	var school := SchoolSystem.sys()   # his view of the life load (session S2)
	var sharp := float(start.sharpness)
	var expected := 0.0
	var races := []
	var days := 0
	var form_cfg: Dictionary = Data.form.sharpness
	for spec in weeks:
		var w := _week_of(spec, a, start)
		if w == null:
			continue
		while not w.is_over():
			var date := Game.add_days(w.monday, w.day)
			var rec: Dictionary
			if w.is_race_day(w.day):
				var meet: Dictionary = w.races[w.day]
				races.append({"key": str(meet.get("key", "")), "meet": meet, "date": date,
						"form": FormSystem.form_for(sharp, a.fatigue) if FormSystem.enabled else 0.0})
				rec = w.race_done("")
			else:
				rec = w.play_day()
			days += 1
			if h != null:
				h._body_day(a, h._done_sessions(rec), rec.intensity, rec.race != "", date, float(rec.fatigue))
				h.day_no += 1
				var inj_mult := 1.0   # a heavier school day makes overuse injuries a little more likely (as in HealthSystem.on_health)
				if school != null:
					inj_mult = SchoolSystem.injury_mult(school.life_load(date, rec.sessions))
				for area in HealthSystem.areas():
					expected += h.hazard(a, area, false) * inj_mult
			var gain := 0.0
			if rec.race != "":
				gain = float(Data.competitions.race_session.get("sharp", 0.0))
			else:
				var effect := float(Training.intensity(rec.intensity).effect)
				for sid in rec.sessions:
					gain += float(Data.get_session(sid).get("sharp", 0.0)) * effect
			sharp = clampf(sharp * float(form_cfg.decay) + gain, 0.0, float(form_cfg.max))
		w.end_week()
	return {"athlete": a, "exp": expected, "races": races, "days": days, "health": h}


static func _week_of(spec: Dictionary, a: Athlete, start: Dictionary) -> WeekSim:
	if spec.get("current", false):
		var now: WeekSim = start.get("week")
		if now == null:
			return null
		var w := WeekSim.from_dict(a, WeekPlan.make(now.plan, now.plan_intensity), now.to_dict().duplicate(true))
		w.races = now.races.duplicate()
		w.coach_effect = now.coach_effect
		w.school = SchoolSystem.sys()   # he sees the school's life load (S2): busy test weeks, double days on school days
		for d in spec.get("scratch", []):
			w.races.erase(int(d))
		var setd: Dictionary = spec.get("set", {})
		for d in setd:
			var x: Dictionary = setd[d]
			if not w.can_change(int(d)):
				continue
			w.changes.erase(int(d))
			w.set_sessions(int(d), x.sessions, "coach")
			w.set_intensity(int(d), str(x.intensity), "coach")
		for key in spec.get("enter", []):   # (a meet entered in this candidate: C5, "Coach suggests")
			var m := Calendar.get_meet(str(key))
			var d2 := Calendar.days_between(w.monday, m.date) if not m.is_empty() else -1
			if d2 >= 0 and d2 < 7 and w.can_change(d2):
				w.races[d2] = m
		return w
	var monday: Dictionary = spec.monday
	var w2 := WeekSim.new(a, spec.plan, monday, Calendar.races_in_week(Game.entries + spec.get("enter", []), monday))
	var now2: WeekSim = start.get("week")
	if now2 != null:
		w2.coach_effect = now2.coach_effect
	w2.school = SchoolSystem.sys()
	return w2


## The truth of a change: {train_w, train_end_w, train_spd_w, risk_w, form_w, race_w, total, verdict, reason, races (bool),
## exp_base, exp_cand, ref_s (a week's gain in seconds), area (the most loaded area's name), meet (the race in the window)}.
static func truth(change: Dictionary) -> Dictionary:
	var c := cfg()
	var start: Dictionary = change.start
	var a0: Athlete = start.athlete
	var b := simulate(start, change.base)
	var k := simulate(start, change.cand)
	var gender := a0.gender
	var ab0 := RacePerformance.ability(a0)
	var abb := RacePerformance.ability(b.athlete)
	var weeks := maxf(float(b.days) / 7.0, 1.0 / 7.0)
	var ref := maxf((RacePerformance.time_for(ab0, gender) - RacePerformance.time_for(abb, gender)) / weeks, float(c.min_week_s))
	var slope := (RacePerformance.time_for(abb - 0.05, gender) - RacePerformance.time_for(abb + 0.05, gender)) / 0.1
	var endurance: Array = Data.coaching.effects.training.groups.endurance_knowledge
	var d_end := 0.0
	var d_all := 0.0
	var weights: Dictionary = Data.races.ability_weights
	for id in weights:
		if str(id).begins_with("_"):
			continue
		var dd: float = (k.athlete.get_attr(id) - b.athlete.get_attr(id)) * float(weights[id])
		d_all += dd
		if id in endurance:
			d_end += dd
	var t := {}
	t.train_end_w = d_end * slope / ref
	t.train_spd_w = (d_all - d_end) * slope / ref
	t.train_w = t.train_end_w + t.train_spd_w
	t.exp_base = b.exp
	t.exp_cand = k.exp
	t.risk_w = -(k.exp - b.exp) * float(c.injury_weeks)
	# Racing on an injury: its chance to get worse (health.json escalation.raced x the strain rule), counted against racing.
	var esc := _escalation_chance(start)
	if esc > 0.0:
		var raced_b: int = b.races.size()
		var raced_k: int = k.races.size()
		t.risk_w -= (raced_k - raced_b) * esc * float(c.escalation_weeks)
	var race_time := RacePerformance.time_for(abb, gender)
	var form_w := 0.0
	var race_w := 0.0
	var by_key := {}
	for r in k.races:
		by_key[r.key] = r
	var meet := ""
	var tk := str(change.get("target", ""))   # (a meet made a target in this change: it counts as one in both plans)
	for r in b.races:
		if meet == "":
			meet = str(r.meet.get("name", ""))
		var weight := _race_weight(r.meet, tk)
		if by_key.has(r.key):
			form_w += (float(by_key[r.key].form) - float(r.form)) * race_time * weight / ref
			by_key.erase(r.key)
		else:
			race_w -= _race_value(r.meet, tk)
	for key in by_key:   # (a race only in the candidate: the base scratched it)
		race_w += _race_value(by_key[key].meet, tk)
		if meet == "":
			meet = str(by_key[key].meet.get("name", ""))
	t.form_w = form_w
	t.race_w = race_w
	t.races = not b.races.is_empty() or not k.races.is_empty()
	t.ref_s = ref
	t.meet = meet
	t.area = _area_name(start)
	var r := classify(t.train_w, t.risk_w, t.form_w, t.race_w)
	t.total = r.total
	t.verdict = r.verdict
	t.reason = r.reason
	return t


static func _race_weight(meet: Dictionary, target_key := "") -> float:
	var w: Dictionary = cfg().race_weight
	return float(w.target) if is_target(meet) or (target_key != "" and str(meet.get("key", "")) == target_key) else float(w.other)


static func _race_value(meet: Dictionary, target_key := "") -> float:
	var v: Dictionary = cfg().race_value_w
	var x := float(v.get(str(meet.get("level", "local")), v.local))
	return x * float(v.target_mult) if is_target(meet) or str(meet.get("key", "")) == target_key and target_key != "" else x


## A target meet of the season plan.
static func is_target(meet: Dictionary) -> bool:
	if Game.season.mode != SeasonPlan.PHASES or meet.is_empty() or not meet.has("date"):
		return false
	return str(meet.get("key", "")) in Game.season.targets(SeasonPlan.year_of(meet.date))


## The chance an active injury gets worse from one race (health.json escalation.raced x (strain / sore)^2, clamped).
static func _escalation_chance(start: Dictionary) -> float:
	var h: HealthSystem = start.get("health")
	if h == null:
		return 0.0
	var esc: Dictionary = Data.health.escalation
	var best := 0.0
	for inj in h.injuries:
		if str(inj.tier) == "illness" or Data.get_injury(inj.id).get("escalates_to", "") == "":
			continue
		var ratio := float(h.strain.get(inj.area, 0.0)) / float(Data.health.soreness.levels[1])
		best = maxf(best, float(esc.raced) * clampf(ratio * ratio, float(esc.strain_min), float(esc.strain_max)))
	return best


## The name of the most loaded body area today (lower case), for the texts.
static func _area_name(start: Dictionary) -> String:
	var h: HealthSystem = start.get("health")
	var best := ""
	var most := -1.0
	for area in HealthSystem.areas():
		var s := float(h.strain.get(area.id, 0.0)) if h != null else 0.0
		if s > most:
			most = s
			best = str(area.name).to_lower()
	return best if h != null else "legs"


## The category of a change from its parts (weeks of training): {verdict, reason, total}.
static func classify(train_w: float, risk_w: float, form_w: float, race_w := 0.0) -> Dictionary:
	var th: Dictionary = cfg().thresholds
	var total := train_w + risk_w + form_w + race_w
	var risky := float(th.risky)
	if risk_w <= -risky or form_w <= -risky:
		return {"verdict": RISKY, "reason": "risk" if risk_w <= form_w else "form", "total": total}
	if total >= float(th.good):
		var parts := {"rest": risk_w, "fresh": form_w, "work": train_w, "race": race_w}
		return {"verdict": GOOD, "reason": _largest(parts), "total": total}
	if total <= -float(th.pointless):
		var parts := {"lose_work": train_w, "form_loss": form_w, "bit_risky": risk_w, "lose_race": race_w}
		var worst := _smallest(parts)
		return {"verdict": POINTLESS, "reason": "lose_work" if worst == "lose_race" else worst, "total": total}
	var big := maxf(maxf(absf(train_w), absf(risk_w)), maxf(absf(form_w), absf(race_w)))
	if big < float(th.good) * 0.5:
		return {"verdict": FINE, "reason": "nothing" if big < float(th.good) * 0.2 else "fine", "total": total}
	return {"verdict": FINE, "reason": "tradeoff" if big >= float(th.good) else "fine", "total": total}


static func _largest(parts: Dictionary) -> String:
	var best := ""
	for k in parts:
		if best == "" or float(parts[k]) > float(parts[best]):
			best = k
	return best


static func _smallest(parts: Dictionary) -> String:
	var best := ""
	for k in parts:
		if best == "" or float(parts[k]) < float(parts[best]):
			best = k
	return best


# --- The coach's view ------------------------------------------------------------------------------------------

## The head coach as the verdict sees him: {id, attributes, demands, voice}; a coach of 10s (balanced) with the coach model
## off or no coach.
static func head_view() -> Dictionary:
	var cs := Game.get_system("coach") as CoachSystem
	var c: Dictionary = cs.head() if cs else {}
	if c.is_empty() or not CoachSystem.model_enabled:
		var attrs := {}
		for at in Data.coaching.attributes:
			attrs[at.id] = int(Data.coaching.neutral)
		return {"id": str(c.get("id", "coach")), "attributes": attrs, "demands": "balanced",
				"voice": str(c.get("voice", Coaches.id_of(Game.athlete) if Game.athlete else "calm"))}
	return {"id": str(c.id), "attributes": c.attributes, "demands": str(c.get("demands", "balanced")), "voice": str(c.voice)}


## The noise of a part as a coach with this attribute sees it (data verdict.noise).
static func noise_sd(attr: float) -> float:
	var n: Dictionary = cfg().noise
	return float(n.floor) + float(n.per_point) * maxf(0.0, 20.0 - attr)


## His dice for a change on a date.
static func seed_for(coach: Dictionary, change: Dictionary) -> int:
	return ("verdict|%s|%s|%s" % [coach.id, Calendar.date_key(Game.date), change.sig]).hash()


## How `coach` sees the truth `t`: {verdict, reason, total, train, risk, form, race} (his parts, after his demands).
static func perceive(t: Dictionary, coach: Dictionary, dice: int) -> Dictionary:
	var n: Dictionary = cfg().noise
	var rng := RandomNumberGenerator.new()
	rng.seed = dice
	var attrs: Dictionary = coach.attributes
	var rel := float(n.rel)
	var end := float(t.train_end_w) + rng.randfn(0.0, noise_sd(float(attrs.get("endurance_knowledge", 10)))
			* (absf(float(t.train_end_w)) * rel + float(n.train_abs)))
	var spd := float(t.train_spd_w) + rng.randfn(0.0, noise_sd(float(attrs.get("speed_strength_knowledge", 10)))
			* (absf(float(t.train_spd_w)) * rel + float(n.train_abs)))
	var risk := float(t.risk_w) + rng.randfn(0.0, noise_sd(float(attrs.get("load_management", 10)))
			* (absf(float(t.risk_w)) * rel + float(n.risk_abs)))
	var form_noise := rng.randfn(0.0, noise_sd(float(attrs.get("periodization", 10))) * (absf(float(t.form_w)) * rel + float(n.form_abs)))
	var form := float(t.form_w) + (form_noise if bool(t.races) else 0.0)
	var dm: Dictionary = cfg().demands.get(str(coach.get("demands", "balanced")), cfg().demands.balanced)
	var train := (end + spd) * float(dm.train)
	risk *= float(dm.risk)
	var r := classify(train, risk, form, float(t.race_w))
	r.train = train
	r.risk = risk
	r.form = form
	r.race = float(t.race_w)
	return r


## The whole verdict of the head coach (or `coach`) on a change: {verdict, word, reason, text, compare, truth, seen}.
static func judge(change: Dictionary, coach := {}) -> Dictionary:
	if coach.is_empty():
		coach = head_view()
	var t := truth(change)
	var seen := perceive(t, coach, seed_for(coach, change))
	return {"verdict": seen.verdict, "word": word(seen.verdict), "reason": seen.reason, "truth": t, "seen": seen,
			"text": say(seen, t, change, coach), "compare": compare_text(change)}


static func word(verdict: String) -> String:
	return str(Data.coach_talk.verdict.words.get(verdict, verdict))


# --- In his words --------------------------------------------------------------------------------------------

## His answer: the opening word of his voice and the reason, in his detail (CoachTalk.level).
static func say(seen: Dictionary, t: Dictionary, change: Dictionary, coach: Dictionary) -> String:
	var v: Dictionary = Data.coach_talk.verdict
	var voice: Dictionary = v.voice.get(str(coach.get("voice", "calm")), v.voice.calm)
	var fill := fill_for(t, change)
	var reason := str(seen.reason)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(coach, change) + 7
	var lvl := CoachTalk.level()
	var parts := [str(voice.get(seen.verdict, ""))]
	if lvl == "short":
		parts.append(str(v.short.get(reason, "")).format(fill))
	else:
		parts.append(_pick(v.reasons.get(reason, []), rng).format(fill))
		if lvl == "full":
			parts.append(str(v.detail.get(reason, "")).format(fill))
	return " ".join(parts.filter(func(x): return str(x) != "")).strip_edges()


## The placeholders of the verdict texts.
static func fill_for(t: Dictionary, change: Dictionary) -> Dictionary:
	var names: Array = Data.moments.day_names
	var day := ""
	if not change.get("days", []).is_empty():
		day = str(names[int(change.days[0].d)])
	var cs := Game.get_system("coach") as CoachSystem
	var head: Dictionary = cs.head() if cs else {}
	return {"area": str(t.get("area", "legs")), "meet": str(t.meet) if str(t.get("meet", "")) != "" else "the race",
			"day": day, "coach_first": str(head.get("name", "")).split(" ")[0], "name": Game.athlete.first_name if Game.athlete else ""}


## What was compared, in words (coach_talk.json verdict.compare).
static func compare_text(change: Dictionary) -> String:
	var cmp: Dictionary = Data.coach_talk.verdict.compare
	var pattern := str(cmp.get(str(change.compare), ""))
	var names: Array = Data.moments.day_names
	var f := {}
	if not change.get("days", []).is_empty():
		var x: Dictionary = change.days[0]
		f.day = str(names[int(x.d)])
		f.cand = day_text(x.cand.sessions, str(x.cand.intensity))
		f.base = day_text(x.base.sessions, str(x.base.intensity))
	if change.has("meet"):
		f.meet = str(change.meet.get("name", ""))
	return pattern.format(f)


## "Easy run", "800 m intervals at Easy", "a rest day".
static func day_text(ids: Array, level: String) -> String:
	var p: Dictionary = Data.coach_talk.proposal
	if ids.is_empty():
		return str(p.rest_day)
	var names := []
	for id in ids:
		names.append(str(Data.get_session(id).get("name", id)))
	var text := " + ".join(names)
	if level != WeekSim.NORMAL:
		text = str(p.at_level).format({"sessions": text, "level": Training.intensity(level).name})
	return text


static func _pick(list, rng: RandomNumberGenerator) -> String:
	if list is Array:
		return str(list[rng.randi_range(0, list.size() - 1)]) if not list.is_empty() else ""
	return str(list)
