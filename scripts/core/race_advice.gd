class_name RaceAdvice
extends RefCounted
## The coach's advice before a race (GDD 4.9.2 "Race advice by personality", session C5; numbers and texts in data/advice.json race).
## THE TRUTH: a score for each pre-race plan (Lead / Sit in the pack / Wait at the back) from the athlete against this field:
## a stronger runner gains by leading, a runner with a big finish (anaerobic reserve) gains by waiting and loses by leading,
## waiting in a big field risks being boxed in; the pack is the baseline. The scores were measured with tools/advice_plan.gd.
## HIS VIEW: the score plus his personality's lean plus his error (smaller with better race reading; the tactician is the most
## accurate and has no lean), the best view wins: race reading decides how often he is right, his personality tilts the answer
## when two plans are close (drill: go to the front, calm: wait, warm: the safe pack). The KICK PLAN: the athlete's natural kick point
## (races.json engine.player_kick) as he reads it (error by race reading, lean in metres by personality), snapped to the nearest
## kick-plan option. His dice come from the coach, the meet and the round, so the advice is the same every time the screen opens.
## Reading only: the advice is never applied by itself (the player presses "Use his plan").


static func cfg() -> Dictionary:
	return Data.advice.race


## The coach's race reading (1-20), 10 with the coach model off.
static func reading() -> float:
	var cs := Game.get_system("coach") as CoachSystem
	return cs.attr("race_reading") if cs != null else float(Data.coaching.neutral)


## The personality (voice id) of the athlete's coach.
static func voice() -> String:
	return Coaches.id_of(Game.athlete)


## The truth: {front, pack, back} scores (higher = better; pack = 0) and the inputs {edge, kick, size}.
static func truth(rd) -> Dictionary:
	var sc: Dictionary = cfg().score
	var entrants: Array = rd.current_entrants()
	var me := {}
	var others := []
	for e in entrants:
		if e.get("is_player", false):
			me = e
		else:
			others.append(float(e.ability))
	if me.is_empty() or others.is_empty():
		return {"front": 0.0, "pack": 0.0, "back": 0.0, "edge": 0.0, "kick": 0.0, "size": entrants.size()}
	others.sort()
	var mean := 0.0
	for x in others:
		mean += x
	mean /= others.size()
	var v := 0.0
	for x in others:
		v += (x - mean) * (x - mean)
	var spread := maxf(float(sc.spread_min), sqrt(v / others.size()))
	var edge := clampf((float(me.ability) - mean) / spread, -float(sc.edge_cap), float(sc.edge_cap))
	var kick := clampf(float(me.anaerobic) / float(sc.kick_ref), -1.0, 1.0)
	# In a big field the pack plan is the crowded one (measured: in a final of 12 it is the worst, waiting at the back the best and the
	# front in between; in a field of 8 the plan hardly matters), so the crowd term grows with the runners above size_from.
	var size_f := maxf(0.0, (entrants.size() - float(sc.size_from)) / float(sc.size_ref))
	return {
		"front": float(sc.strength) * edge - float(sc.lead_kick) * kick - float(sc.lead_cost) + float(sc.crowd_front) * size_f,
		"pack": float(sc.pack_safe) * maxf(0.0, 1.0 - size_f),   # (the safe, flexible choice: worth something in a small field only)
		"back": float(sc.back_kick) * kick + float(sc.crowd_back) * size_f,
		"edge": edge, "kick": kick, "size": entrants.size()}


## The athlete's natural kick point in metres to go (races.json engine.player_kick, from their anaerobic fitness).
static func natural_kick(a: Athlete) -> float:
	var pk: Dictionary = Data.races.engine.player_kick
	var an := float(RacePerformance.player_profile(a).anaerobic)
	return clampf(float(pk.base) + float(pk.per_anaerobic) * an, float(pk.min), float(pk.max))


## The kick-plan options without "natural": [300, 250, ...] metres to go.
static func kick_options() -> Array:
	var out := []
	for o in Data.races.controls.kick_plans.options:
		if float(o[0]) > 0.0:
			out.append(float(o[0]))
	return out


## His advice for the race of `rd` now: {plan ("front" / "pack" / "back"), kick (metres to go), scores (the truth), seen (his view),
## best (the truth's best plan), right (his plan is the truth's best), voice}.
static func advise(rd) -> Dictionary:
	var c := cfg()
	var t := truth(rd)
	var v := voice()
	var rr := reading()
	var rng := RandomNumberGenerator.new()
	var cs := Game.get_system("coach") as CoachSystem
	var coach_id := str(cs.head().get("id", "coach")) if cs != null else "coach"
	rng.seed = ("advice|%s|%s|%d" % [coach_id, str(rd.meet.get("key", "")), rd.round_index]).hash()
	var n: Dictionary = c.noise
	var sd := (float(n.floor) + float(n.per_point) * maxf(0.0, 20.0 - rr)) * (float(n.tactician_mult) if v == "tactician" else 1.0)
	var lean: Dictionary = c.lean.get(v, c.lean.calm)
	var seen := {}
	var best_seen := ""
	var best_true := ""
	for p in c.plans:
		seen[p] = float(t[p]) + float(lean.get(p, 0.0)) + rng.randfn(0.0, sd)
		if best_seen == "" or seen[p] > seen[best_seen]:
			best_seen = p
		if best_true == "" or float(t[p]) > float(t[best_true]):
			best_true = p
	# The kick: his reading of the natural point, snapped to the nearest option.
	var k: Dictionary = c.kick
	var est := natural_kick(Game.athlete) + rng.randfn(0.0, float(k.floor_m) + float(k.per_point_m) * maxf(0.0, 20.0 - rr)) \
			+ float(k.lean_m.get(v, 0.0))
	var kick := 0.0
	var gap := 1.0e9
	for o in kick_options():
		if absf(float(o) - est) < gap:
			gap = absf(float(o) - est)
			kick = float(o)
	return {"plan": best_seen, "kick": kick, "kick_est": est, "scores": t, "seen": seen, "best": best_true, "right": best_seen == best_true, "voice": v}


# --- In his words -------------------------------------------------------------------------------------------------------

## The line(s) for the pre-race card: the short one at local / district meets, the full one with a reason at bigger meets.
static func text(adv: Dictionary, short: bool) -> String:
	var t: Dictionary = cfg().texts
	var plan := str(t.plan_names[adv.plan])
	var kick := str(t.kick_natural) if float(adv.kick) <= 0.0 else str(t.kick_at).format({"m": roundi(float(adv.kick))})
	if short:
		return str(t.line_short).format({"plan": plan, "kick": kick})
	var kickline := str(t.kick_line.natural) if float(adv.kick) <= 0.0 else str(t.kick_line.at).format({"m": roundi(float(adv.kick))})
	var line: String = t.line.get(adv.voice, t.line.calm)
	return line.format({"plan": plan, "kickline": kickline, "why": str(t.why[why_key(adv)])}).strip_edges()


## Why the plan fits, from what the truth saw: a stronger runner leads, a grinder leads, a big field crowds the pack; a finisher waits.
static func why_key(adv: Dictionary) -> String:
	var th: Dictionary = cfg().texts.thresholds
	var sc: Dictionary = adv.scores
	match str(adv.plan):
		"front":
			if float(sc.edge) > float(th.strong):
				return "front_strong"
			return "front_grinder" if float(sc.kick) < -float(th.kicker) else "front_crowd"
		"back":
			return "back_finisher" if float(sc.kick) > float(th.kicker) else "back_crowd"
	return "pack"
