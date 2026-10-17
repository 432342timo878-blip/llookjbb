class_name MindSystem
extends GameSystem
## The mind (GDD 4.9.4; session M1). GameSystem id "mind". Three moods, each a hidden value 0-100 shown as a word
## (data/mind.json `moods`): confidence (Low / Shaky / OK / Confident / Flying), motivation (Flat / Low / OK / Keen / Fired
## up) and stress (Calm / Busy / Stressed / Overwhelmed).
## How they move (user 2026-10-17: "news + Sunday drift"): NEWS moves a mood at once (a race's result on its evening, an
## injury's diagnosis, a goal met / missed / set, a new training phase, a moment's answer: `news`); every SUNDAY NIGHT each
## mood drifts part of the way towards the target its situation sets (`drift`: the coach's fit, style, trust and Motivating,
## monotony, a layoff, stress, an injury, the mental plan). pulls(mood) lists that situation for the UI. The Sunday before a week
## with a big meet brings nerves (stress news).
## What they do (user: the GDD sizes with a calm middle): motivation = the quality of training (training_quality(): every
## session's training effect x 0.92 at Flat 0 ... x1.05 at Fired up 100, exactly 1.0 across the middle word; WeekSim.quality,
## set by Game.current_week()); confidence = a race-day term at its ends (race_term(meet): up to +-0.3 % of race time, by meet
## level; RaceDay._player_entrant); stress pulls motivation down. Nothing here ever changes WHAT is done (the player decides).
## Mental attributes that grow: consistency from every race, composure from big meets and from the weekly mental plan
## (`plan` of up to 3 kinds + the cue word shown on the race cards). Ambition (hidden) scales how goals move motivation.
## Off switches for the tools: `model_enabled` (off = no moods, no effects, no growth) and `neutral` (the moods stay at their
## start values in the middle, so every effect is exactly neutral; the attribute growth still works).
## No dice: same days = same moods; a loaded game goes on exactly as without saving.

static var model_enabled := true
static var neutral := false

const MOODS := ["confidence", "motivation", "stress"]

var values := {}          # mood -> 0-100
var snap := {}            # mood -> value after last Sunday's drift
var before := {}          # mood -> value after the Sunday before that (the arrow compares with it)
var causes := {}          # mood -> [{date, delta, text}], newest last (data keep_causes)
var same_weeks := 0       # weeks in a row on the same training template (monotony)
var template_key := ""    # that template ("" = none seen yet)
var last_race := {}       # {level, indoor} of the last race (consistency grows more from a different one)
var plan := []            # the weekly mental plan: up to max_sessions kind ids
var cue := ""             # the cue word for self-talk ("" = the default)
var started := false      # false until the first played day (state saved from then on)


func _init() -> void:
	id = "mind"
	_reset()


func _reset() -> void:
	for m in MOODS:
		var v := float(Data.mind.moods[m].start)
		values[m] = v
		snap[m] = v
		before[m] = v
		causes[m] = []


static func cfg() -> Dictionary:
	return Data.mind


## The career's mind system, or null when the model is off.
static func sys() -> MindSystem:
	if not model_enabled:
		return null
	return Game.get_system("mind") as MindSystem


# --- Reading the moods ---------------------------------------------------------------------------------------------

func value(mood: String) -> float:
	return float(values.get(mood, cfg().moods[mood].start))


## The word of a mood now: {id, name, color (Color)}.
func word(mood: String) -> Dictionary:
	return word_for(mood, value(mood))


static func word_for(mood: String, v: float) -> Dictionary:
	var words: Array = Data.mind.moods[mood].words
	for w in words:
		if v < float(w.below):
			return {"id": str(w.id), "name": str(w.name), "color": Color(str(w.color))}
	var last: Dictionary = words.back()
	return {"id": str(last.id), "name": str(last.name), "color": Color(str(last.color))}


## +1 / 0 / -1: has the mood risen or fallen since a week ago (by at least data arrow_min)?
func arrow(mood: String) -> int:
	var d := value(mood) - float(before.get(mood, value(mood)))
	if d >= float(cfg().arrow_min):
		return 1
	if d <= -float(cfg().arrow_min):
		return -1
	return 0


## "low" / "middle" / "high": where the mood sits against its middle word.
func side(mood: String) -> String:
	var mid: Array = cfg().moods[mood].middle
	var v := value(mood)
	if v < float(mid[0]):
		return "low"
	if v > float(mid[1]):
		return "high"
	return "middle"


## The recent news that moved a mood, newest first: [{date, delta, text}].
func recent(mood: String) -> Array:
	var list: Array = causes.get(mood, []).duplicate()
	list.reverse()
	return list


# --- Effects ---------------------------------------------------------------------------------------------------------

## Motivation's training quality: every session's training effect is multiplied by it. Exactly 1.0 across the middle word
## and with the model off.
func training_quality() -> float:
	if not model_enabled:
		return 1.0
	return quality_for(value("motivation"))


static func quality_for(v: float) -> float:
	var mid: Array = Data.mind.moods.motivation.middle
	var e: Dictionary = Data.mind.effects.motivation
	var lo := float(mid[0])
	var hi := float(mid[1])
	if v < lo:
		return lerpf(float(e.at_0), 1.0, clampf(v / lo, 0.0, 1.0))
	if v > hi:
		return lerpf(1.0, float(e.at_100), clampf((v - hi) / (100.0 - hi), 0.0, 1.0))
	return 1.0


## Confidence's race-day term for a meet (a share of race time, + = faster). Exactly 0 across the middle word.
func race_term(meet: Dictionary) -> float:
	if not model_enabled:
		return 0.0
	return term_for(value("confidence"), str(meet.get("level", "local")))


static func term_for(v: float, level: String) -> float:
	var mid: Array = Data.mind.moods.confidence.middle
	var e: Dictionary = Data.mind.effects.confidence
	var lo := float(mid[0])
	var hi := float(mid[1])
	var t := 0.0
	if v < lo:
		t = lerpf(float(e.at_0), 0.0, clampf(v / lo, 0.0, 1.0))
	elif v > hi:
		t = lerpf(0.0, float(e.at_100), clampf((v - hi) / (100.0 - hi), 0.0, 1.0))
	else:
		return 0.0
	return t * float(e.level_scale.get(level, 1.0))


## The cue word shown on the race cards ("" = no self-talk in the mental plan).
func cue_word() -> String:
	if not model_enabled or not "self_talk" in plan:
		return ""
	return cue if cue != "" else str(cfg().mental_plan.default_cue)


# --- News -----------------------------------------------------------------------------------------------------------

## Moves a mood at once, with the cause shown when the row is tapped. Does nothing with the model off or neutral.
func add(mood: String, delta: float, text: String) -> void:
	if not model_enabled or neutral or delta == 0.0 or not mood in MOODS:
		return
	values[mood] = clampf(value(mood) + delta, 0.0, 100.0)
	var list: Array = causes[mood]
	list.append({"date": Game.date.duplicate(), "delta": delta, "text": text})
	while list.size() > int(cfg().keep_causes):
		list.pop_front()


## A reply's mood effect in a moment (StoryletSystem._apply): `points` x moment_point; from the coach also x his lift
## (Motivating) and the trust factor.
func from_moment(mood: String, points: float, p: Dictionary) -> void:
	var n: Dictionary = cfg().news
	var d := points * float(n.moment_point)
	var who := str(p.get("first_name", ""))
	if str(p.get("role", "")) == "coach":
		d *= coach_lift()
	add(mood, d, str(cfg().causes.moment).format({"who": who}) if who != "" else str(cfg().causes.week))


## How strongly the coach's words land: his Motivating x the trust factor (1.0 for a coach of 10 with Good trust).
func coach_lift() -> float:
	var cs := _coach()
	if cs == null:
		return 1.0
	var lift := cs.effect("motivating", "lift_per_point")
	return lift * float(cfg().news.trust_factor.get(cs.trust_level(), 1.0))


## A season goal was met (SeasonGoals._met).
func goal_met() -> void:
	var g: Dictionary = cfg().news.goal
	add("confidence", float(g.met_confidence), str(cfg().causes.goal_met))
	add("motivation", float(g.met_motivation), str(cfg().causes.goal_met))


## A season goal was missed (the season's review, or a place goal right after its meet).
func goal_missed() -> void:
	add("confidence", float(cfg().news.goal.missed_confidence), str(cfg().causes.goal_missed))


## New goals were set (SeasonGoals.apply). `steps` = the levels chosen above (+) or below (-) the coach's picks, summed:
## big goals lift an ambitious athlete more, being held back hurts more (ambition / 10).
func goals_set(steps: int) -> void:
	var g: Dictionary = cfg().news.goal
	var amb := Game.athlete.get_attr("ambition") / 10.0 if Game.athlete else 1.0
	add("motivation", float(g.set_motivation) + steps * float(g.ambition_step) * amb, str(cfg().causes.goals_set))


# --- The day loop ---------------------------------------------------------------------------------------------------

func on_day_end(ctx: Dictionary) -> void:
	if not model_enabled:
		return
	started = true
	_diagnoses(ctx)
	var note: Dictionary = ctx.get("race_note", {})
	if not note.is_empty():
		_race_news(note)
		_race_growth(note)
	# The day log says when you dragged yourself through the training (motivation Low or Flat).
	var rec: Dictionary = ctx.get("record", {})
	if rec.get("race", "") == "" and not rec.get("sessions", []).is_empty() and value("motivation") < float(cfg().effects.dragged_below):
		var extra: Dictionary = ctx.get("log_extra", {})
		extra["dragged"] = true
		ctx.log_extra = extra


## Today's diagnoses (HealthSystem posts them in on_health): confidence and stress by the problem's tier.
func _diagnoses(ctx: Dictionary) -> void:
	var today := Calendar.date_key(ctx.date)
	for e in Game.events:
		if str(e.get("kind", "")) != "diagnosis" or Calendar.date_key(e.date) != today:
			continue
		var inj := Data.get_injury(str(e.get("injury", "")))
		var by: Dictionary = cfg().news.injury.get(str(inj.get("tier", "")), {})
		var text := str(cfg().causes.injury).format({"injury": str(inj.get("name", ""))})
		add("confidence", float(by.get("confidence", 0.0)), text)
		add("stress", float(by.get("stress", 0.0)), text)


## The evening of a race day: the result's news (Game._make_race_note adds the rounds and the runners beaten).
func _race_news(note: Dictionary) -> void:
	var r: Dictionary = cfg().news.race
	var c: Dictionary = cfg().causes
	var fill := {"meet": str(note.get("meet", ""))}
	var rounds: Array = note.get("rounds", [])
	if rounds.is_empty():
		return
	var last: Dictionary = rounds.back()
	var status := str(last.get("status", ""))
	if status == "dnf":
		add("confidence", float(r.dnf), str(c.dnf).format(fill))
		return
	if status == "dq":
		add("confidence", float(r.dq), str(c.dq).format(fill))
		return
	var best := 0.0
	var ref := 0.0
	var mark := ""
	for x in rounds:
		if str(x.get("status", "")) == "" and float(x.time) > 0.0 and (best == 0.0 or float(x.time) < best):
			best = float(x.time)
			mark = str(x.get("mark", ""))
		if ref == 0.0:
			ref = float(x.get("ref", 0.0))
	if mark == "PB":
		add("confidence", float(r.pb), str(c.pb).format(fill))
		add("motivation", float(r.motivation_pb), str(c.pb).format(fill))
	elif mark == "SB":
		add("confidence", float(r.sb), str(c.sb).format(fill))
	elif ref > 0.0 and best > 0.0:
		var slower := (best / ref - 1.0) * 100.0
		if slower > float(r.well_below_pct):
			add("confidence", float(r.well_below), str(c.well_below).format(fill))
		elif slower > float(r.below_pct):
			add("confidence", float(r.below), str(c.below).format(fill))
	if int(last.place) == 1 and int(last.field) > 1:
		add("confidence", float(r.win), str(c.win).format(fill))
	elif int(last.place) == int(last.field) and int(last.field) >= int(r.last_min_field):
		add("confidence", float(r.last), str(c.last).format(fill))
	var beaten := int(note.get("beat_above", 0))
	if beaten > 0:
		add("confidence", minf(beaten * float(r.beat_above), float(r.beat_above_max)), str(c.beat_above).format(fill))


## Racing grows consistency (more from a race unlike the last one) and big meets grow composure.
func _race_growth(note: Dictionary) -> void:
	var a := Game.athlete
	var meet := Calendar.get_meet(str(note.get("key", "")))
	if a == null or meet.is_empty():
		return
	var g: Dictionary = cfg().growth
	var level := str(meet.get("level", "local"))
	var indoor := bool(meet.get("indoor", false))
	var varied := last_race.is_empty() or str(last_race.level) != level or bool(last_race.indoor) != indoor
	_grow(a, "consistency", float(g.consistency.per_race) * (float(g.consistency.varied) if varied else 1.0))
	if level in cfg().big_levels:
		var conf := 1.0 + (value("confidence") - 50.0) / 50.0 * float(g.composure.confidence_share)
		_grow(a, "composure", float(g.composure.per_big_race) * _mental_coaching() * conf)
	last_race = {"level": level, "indoor": indoor}


## Adds `amount` x headroom to a mental attribute (and to its recent change, for the Overview's arrows).
func _grow(a: Athlete, attr_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var g: Dictionary = cfg().growth
	var v := a.get_attr(attr_id)
	var head := clampf((20.0 - v) / float(g.headroom_span), float(g.headroom_min), 1.0)
	a.set_attr(attr_id, v + amount * head)
	a.recent_change[attr_id] = a.recent_change.get(attr_id, 0.0) + (a.get_attr(attr_id) - v)


## The coach's mental coaching as a multiplier (1.0 at 10; data coaching.json effects.mental_coaching.composure_per_point).
func _mental_coaching() -> float:
	var cs := _coach()
	return cs.effect("mental_coaching", "composure_per_point") if cs else 1.0


func _coach() -> CoachSystem:
	return Game.get_system("coach") as CoachSystem


# --- Sunday night ---------------------------------------------------------------------------------------------------

func on_week_end(ctx: Dictionary) -> void:
	if not model_enabled:
		return
	started = true
	var monday: Dictionary = ctx.week.monday if ctx.get("week") != null else Game.week_monday()
	_track_template(monday)
	_plan_growth(monday)
	if not neutral:
		for m in MOODS:
			var t := target(m, ctx.get("week"))
			var rate := float(cfg().drift[m].rate)
			if m == "confidence" and value(m) < t:
				var cs := _coach()
				if cs:
					rate *= cs.effect("mental_coaching", "confidence_back_per_point")
			values[m] = clampf(value(m) + (t - value(m)) * clampf(rate, 0.0, 1.0), 0.0, 100.0)
	_big_meet_nerves(Game.add_days(monday, 7))
	before = snap.duplicate()
	snap = values.duplicate()


## Monotony: weeks in a row on the same template (the repeating week as it is, or the season phase). A new phase of a season
## plan is news for motivation.
func _track_template(monday: Dictionary) -> void:
	var key := template_of(monday)
	if key == template_key:
		same_weeks += 1
		return
	if template_key.begins_with("phase:") and key.begins_with("phase:"):
		add("motivation", float(cfg().news.new_phase_motivation), str(cfg().causes.new_phase))
	template_key = key
	same_weeks = 1


static func template_of(monday: Dictionary) -> String:
	var s: SeasonPlan = Game.season
	if s == null:
		return ""
	if s.mode == SeasonPlan.PHASES:
		var w: Dictionary = s.week_for(monday)
		return "phase:%d:%s" % [s.plan_year(monday), str(w.get("phase", ""))]
	return "repeat:" + JSON.stringify(s.repeat_week)


## The mental plan's week: composure from each session (imagery doubled with a target in the coming week).
func _plan_growth(monday: Dictionary) -> void:
	var a := Game.athlete
	if a == null or plan.is_empty():
		return
	var kinds: Dictionary = cfg().mental_plan.kinds
	var target_soon := _target_in_week(Game.add_days(monday, 7))
	var total := 0.0
	for k in plan:
		if not kinds.has(k):
			continue
		var amount := float(kinds[k].composure)
		if k == "imagery" and target_soon:
			amount *= float(kinds[k].target_week)
		total += amount
	_grow(a, "composure", total * _mental_coaching())


func _target_in_week(monday: Dictionary) -> bool:
	if Game.season == null or Game.season.mode != SeasonPlan.PHASES:
		return false
	var races := Calendar.races_in_week(Game.entries, monday)
	var targets: Array = Game.season.targets(Game.season.plan_year(monday))
	for d in races:
		if str(races[d].get("key", "")) in targets:
			return true
	return false


## Where the Sunday drift takes a mood: base + the pulls. `week` = the week just played (or the one in progress, for the UI).
func target(mood: String, week = null) -> float:
	var t := float(cfg().drift[mood].base)
	for p in pulls(mood, week):
		t += float(p.delta)
	return clampf(t, 0.0, 100.0)


## The situation pulling a mood: [{text, delta}] (delta in points of the target). Shown under the mood row.
func pulls(mood: String, week = null) -> Array:
	var out := []
	var d: Dictionary = cfg().drift[mood]
	var pt: Dictionary = cfg().pulls
	var cs := _coach()
	var first := ""
	if cs != null:
		first = str(cs.head().get("name", "")).split(" ")[0]
	var fill := {"coach": first, "weeks": same_weeks}
	var health := Game.get_system("health") as HealthSystem
	var injured := false
	if health != null and HealthSystem.model_enabled:
		for x in health.active():
			if str(x.tier) in ["injury", "serious"]:
				injured = true
	match mood:
		"confidence":
			if injured:
				out.append({"text": str(pt.injured), "delta": float(d.injured)})
			if "self_talk" in plan:
				out.append({"text": str(pt.self_talk), "delta": float(cfg().mental_plan.kinds.self_talk.confidence)})
		"motivation":
			if cs != null and CoachSystem.model_enabled and not cs.head().is_empty():
				var fit := cs.fit()
				if float(d.fit.get(fit, 0.0)) != 0.0:
					out.append({"text": str(pt["fit_" + fit]).format(fill), "delta": float(d.fit[fit])})
				var style := int(cs.head().get("style", 0))
				var temp := Game.athlete.temperament if Game.athlete else ""
				if style > 0 or (style < 0 and not temp in Data.coaching.fit.no_controlling_penalty):
					out.append({"text": str(pt.style_plus if style > 0 else pt.style_minus).format(fill),
							"delta": style * float(d.style_per_step)})
				var tl := cs.trust_level()
				if float(d.trust.get(tl, 0.0)) != 0.0:
					out.append({"text": str(pt["trust_" + tl]).format(fill), "delta": float(d.trust[tl])})
				var mot := (cs.attr("motivating") - float(Data.coaching.neutral)) * float(d.motivating_per_point)
				if mot != 0.0:
					out.append({"text": str(pt.motivating_plus if mot > 0.0 else pt.motivating_minus).format(fill), "delta": mot})
			var mono: Dictionary = d.monotony
			var over := same_weeks - int(mono.grace)
			if over > 0:
				out.append({"text": str(pt.monotony).format(fill), "delta": -minf(over * float(mono.per_week), float(mono.max))})
			if health != null and HealthSystem.model_enabled and health.days_without_running >= int(d.layoff.days):
				out.append({"text": str(pt.layoff), "delta": float(d.layoff.pull)})
			var st := value("stress")
			if st > float(d.stress.from):
				out.append({"text": str(pt.stress), "delta": (st - float(d.stress.from)) * float(d.stress.per_point)})
			var amb := Game.athlete.get_attr("ambition") if Game.athlete else 10.0
			var hb: Dictionary = d.held_back
			if amb > float(hb.ambition_above) and Game.season != null and Game.season.mode == SeasonPlan.PHASES \
					and Game.season.variant(Game.season.plan_year(Game.week_monday())) == "steady":
				out.append({"text": str(pt.held_back), "delta": (amb - float(hb.ambition_above)) * float(hb.per_point)})
		"stress":
			if injured:
				out.append({"text": str(pt.injured), "delta": float(d.injured)})
			if cs != null and CoachSystem.model_enabled and cs.trust_level() == "strained":
				out.append({"text": str(pt.strained).format(fill), "delta": float(d.strained)})
			if health != null and HealthSystem.model_enabled and week != null:
				var pct := health.load_vs_normal(week)
				if pct > int(d.load.from):
					out.append({"text": str(pt.load), "delta": minf((pct - float(d.load.from)) * float(d.load.per_point), float(d.load.max))})
			if "relaxation" in plan:
				out.append({"text": str(pt.relaxation), "delta": float(d.relaxation)})
	return out


## The first big meet (data big_levels) entered for the week starting `monday`, or {}.
func _big_meet_in(monday: Dictionary) -> Dictionary:
	var races := Calendar.races_in_week(Game.entries, monday)
	var days := races.keys()
	days.sort()
	for day in days:
		if str(races[day].get("level", "")) in cfg().big_levels:
			return races[day]
	return {}


## Sunday night before a week with a big meet: nerves (stress news), less with composure, halved with relaxation training.
func _big_meet_nerves(next_monday: Dictionary) -> void:
	var meet := _big_meet_in(next_monday)
	if meet.is_empty() or Game.athlete == null:
		return
	var b: Dictionary = cfg().news.big_meet
	var amount := float(b.stress) * maxf(0.0, 1.0 - (Game.athlete.get_attr("composure") - 10.0) * float(b.composure_per_point))
	if "relaxation" in plan:
		amount *= float(b.relaxation_share)
	add("stress", amount, str(cfg().causes.big_meet).format({"meet": str(meet.get("name", ""))}))


# --- The weekly mental plan ------------------------------------------------------------------------------------------

## Sets the plan: the kinds done this week, each at most once (unknown ids dropped; kept in the data's order).
func set_plan(kinds: Array) -> void:
	plan = []
	for k in cfg().mental_plan.kinds:
		if k in kinds and plan.size() < int(cfg().mental_plan.max_sessions):
			plan.append(str(k))


## Switches one kind on or off.
func toggle_kind(kind: String, on: bool) -> void:
	var kinds := plan.duplicate()
	if on and not kind in kinds:
		kinds.append(kind)
	elif not on:
		kinds.erase(kind)
	set_plan(kinds)


func set_cue(word_text: String) -> void:
	if word_text in cfg().mental_plan.cue_words:
		cue = word_text


# --- The coach's words -----------------------------------------------------------------------------------------------

## The mood the coach talks about on Sunday, with its side ("low" / "high"), or {}: the one furthest out of its middle, or
## the one that moved most this week (at least coach.moved_min).
func talk_mood() -> Dictionary:
	var best := {}
	var far := 0.0
	for m in MOODS:
		var mid: Array = cfg().moods[m].middle
		var v := value(m)
		var out := maxf(float(mid[0]) - v, v - float(mid[1]))
		if m == "stress" and v <= float(mid[1]):
			out = 0.0
		if out > far:
			far = out
			best = {"mood": m, "side": "low" if v < float(mid[0]) else "high"}
	if not best.is_empty():
		return best
	for m in ["confidence", "motivation"]:
		var moved := value(m) - float(snap.get(m, value(m)))
		if absf(moved) >= float(cfg().coach.moved_min) and absf(moved) > far:
			far = absf(moved)
			best = {"mood": m, "side": "high" if moved > 0.0 else "low"}
	return best


## His line for the Sunday talk ("" = nothing to say, or a coach of few words). `voice` = his personality.
func coach_line(voice: String, first_name: String) -> String:
	if not model_enabled or CoachTalk.level() == "short":
		return ""
	var tm := talk_mood()
	if tm.is_empty():
		return ""
	var lines: Dictionary = cfg().coach.lines.get(voice, cfg().coach.lines.calm)
	var key := "%s_%s" % [tm.mood, tm.side]
	if not lines.has(key):
		return ""
	return str(lines[key]).format({"first": first_name})


## A mood low enough for the Sunday talk's "how are you?" topic (the storylets with topic "mood").
func is_low(mood: String) -> bool:
	match mood:
		"confidence":
			return word("confidence").id == "low"
		"motivation":
			return word("motivation").id in ["flat", "low"]
		"stress":
			return word("stress").id in ["stressed", "overwhelmed"]
	return false


# --- Save / load ------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if not started and plan.is_empty() and cue == "":
		return {}
	return {"values": values, "snap": snap, "before": before, "causes": causes, "same_weeks": same_weeks,
			"template_key": template_key, "last_race": last_race, "plan": plan, "cue": cue, "started": started}


## An empty state (an older save, or a career that hasn't played a day) starts in the middle.
func from_dict(d: Dictionary) -> void:
	_reset()
	if d.is_empty():
		return
	for m in MOODS:
		values[m] = float(d.get("values", {}).get(m, values[m]))
		snap[m] = float(d.get("snap", {}).get(m, values[m]))
		before[m] = float(d.get("before", {}).get(m, values[m]))
		var list := []
		for c in d.get("causes", {}).get(m, []):
			list.append({"date": Game.int_date(c.date), "delta": float(c.delta), "text": str(c.text)})
		causes[m] = list
	same_weeks = int(d.get("same_weeks", 0))
	template_key = str(d.get("template_key", ""))
	last_race = d.get("last_race", {})
	plan = []
	for k in d.get("plan", []):
		plan.append(str(k))
	cue = str(d.get("cue", ""))
	started = bool(d.get("started", false))
