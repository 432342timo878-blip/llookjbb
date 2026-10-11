class_name CoachTalk
extends RefCounted
## What the head coach says (GDD 4.9.2, session C3): the Sunday-evening week talk, the message after a race and the "why"
## line of the day editor. The texts are in data/coach_talk.json (read the note there); this class only picks and fills them.
## His communication attribute sets how much he says (level(): short / normal / full), his personality (Coaches.id_of, the
## voice of coaches.json) how he says it. Reading only: it never changes the game, and the dice it needs come from the
## caller (StoryletSystem's own), so a talk never touches training, health or the global dice.


static func cfg() -> Dictionary:
	return Data.coach_talk


## "short" / "normal" / "full" from the head coach's communication (normal when the coach model is off).
static func level() -> String:
	var cs := Game.get_system("coach") as CoachSystem
	var c := cs.attr("communication") if cs else float(Data.coaching.neutral)
	var d: Dictionary = cfg().detail
	if c <= float(d.short_max):
		return "short"
	if c >= float(d.full_min):
		return "full"
	return "normal"


## The voice record of the head coach (cfg voices.<calm / drill / warm / tactician>).
static func voice() -> Dictionary:
	var voices: Dictionary = cfg().voices
	return voices.get(Coaches.id_of(Game.athlete), voices.calm)


static func _pick(list, rng: RandomNumberGenerator) -> String:
	if list is Array:
		return str(list[rng.randi_range(0, list.size() - 1)]) if not list.is_empty() else ""
	return str(list)


# --- The Sunday-evening week talk ----------------------------------------------------------------------------

## The talk for the week that was just played (`ctx` = the day-end context of Sunday: `week`, `date`, `day`), as paragraphs
## separated by blank lines. `fill` = the placeholders of StoryletSystem._fill (name, coach_first ...).
static func week_talk(ctx: Dictionary, fill: Dictionary, rng: RandomNumberGenerator) -> String:
	var t: Dictionary = cfg().talk
	var v := voice()
	var lvl := level()
	var f := fill.duplicate()
	var w: WeekSim = ctx.week
	var last := _last_week(w)
	var plan := _next_week()
	var paras := []

	paras.append(_pick(v.open_short if lvl == "short" else v.open, rng).format(f))

	# Last week: the facts, then his comment on the one thing that mattered most.
	var review := []
	var facts: Dictionary = t.facts
	var fs: Dictionary = {"done": last.done, "planned": last.planned}
	if last.done == 0 and last.planned > 0:
		review.append(str(facts.sessions_none))
	elif last.planned == 0:
		if last.done > 0:
			review.append(str(facts.sessions_free).format(fs))
	elif last.done > last.planned:
		review.append(str(facts.sessions_extra).format(fs))
	elif last.done == last.planned:
		review.append(str(facts.sessions_all).format(fs))
	elif last.done * 4 < last.planned * 3:
		review.append(str(facts.sessions_few).format(fs))
	else:
		review.append(str(facts.sessions_most).format(fs))
	if lvl != "short" and last.planned + last.done > 0:
		review.append(str(facts.feel[last.feel]))
	if not last.injuries.is_empty():
		review.append(str(facts.injury).format({"injury": str(last.injuries[0]).to_lower()}))
	elif lvl != "short" and not last.sore.is_empty():
		review.append(str(facts.sore).format({"areas": ", ".join(last.sore)}))
	for r in last.races:
		review.append(str(facts.race).format({"meet": r.meet, "result": r.result}))
		if lvl == "short":
			break
	var sit := _situation(last)
	if sit != "":
		review.append(str(v.comment[sit]).format(f))
	paras.append(" ".join(review))

	# This week: the phase, why, the key sessions, the race.
	var preview := []
	var key: Dictionary = t.preview
	var phase_id := str(plan.get("phase", ""))
	if phase_id != "":
		var pt := SeasonPlan.phase_type(phase_id)
		preview.append(str(key.phase).format({"phase": str(pt.get("name", phase_id)).to_lower(),
				"week": plan.get("phase_week", 1), "weeks": plan.get("phase_weeks", 1)}))
		if lvl == "full":
			preview.append(str(cfg().phase_why.get(phase_id, "")))
	else:
		preview.append(str(key.phase_repeat))
	var kind := str(plan.get("kind", ""))
	if lvl != "short" and key.kinds.has(kind):
		var target := Calendar.get_meet(str(plan.get("target", "")))
		preview.append(str(key.kinds[kind]).format({"meet": str(target.get("name", "your race"))}))
	var keys := _key_sessions(plan)
	var shown := 0
	for k in keys:
		if shown >= (2 if lvl == "full" else 1):
			break
		var sw: Dictionary = cfg().session_why.get(k.id, {})
		var line := str(key.key_why if lvl == "full" else key.key)
		preview.append(line.format({"weekday": k.weekday, "session": k.session, "why": str(sw.get("why", ""))}))
		shown += 1
	if keys.is_empty() and lvl != "short":
		preview.append(str(key.no_key))
	var race := _race_ahead(plan)
	if not race.is_empty() and lvl != "short":
		preview.append(str(key.race).format({"meet": race.meet, "weekday": race.weekday}) if race.in_week
				else str(key.race_far).format({"meet": race.meet, "days": race.days}))
	paras.append(" ".join(preview))

	# One thing to focus on, and a closing word.
	if lvl != "short":
		var focus := _focus(last, plan, race)
		if focus != "":
			paras.append(_pick(v.focus_intro, rng) + " " + focus)
		paras.append(_pick(v.close, rng).format(f))
	return "\n\n".join(paras)


## What the week that was just played looked like: {done, planned, feel, sore [area names], injuries [names],
## races [{meet, result, outcome}], fatigue (average)}.
static func _last_week(w: WeekSim) -> Dictionary:
	var done := 0
	var planned := 0
	var fatigue := 0.0
	var races := []
	for r in w.played:
		var d := int(r.day)
		fatigue += float(r.fatigue)
		if str(r.race) != "":
			races.append(str(r.race))
			continue
		done += r.sessions.size()
		var ch: Dictionary = w.changes.get(d, {})
		if ch.has("sessions") and str(ch.sessions.by) == "injury":
			planned += r.sessions.size()   # (the injury took the rest out: not a missed session)
		else:
			planned += w.plan[d].size()
	var avg := fatigue / maxi(w.played.size(), 1)
	var out := {"done": done, "planned": planned, "fatigue": avg, "feel": str(Training.fatigue_state(avg)[0]).to_lower(),
			"sore": _sore_names(), "injuries": [], "races": []}
	var h := Game.get_system("health") as HealthSystem
	if h != null and HealthSystem.model_enabled:
		for x in h.active():
			out.injuries.append(str(x.name))
	for key in races:
		var res := _result_of(key)
		if not res.is_empty():
			var meet := Calendar.get_meet(key)
			out.races.append({"meet": str(meet.get("name", res.get("meet", key))), "result": _result_text(res),
					"outcome": race_outcome({"result": res})})
	return out


## The names of the body areas that were sore at some point in the last days (lowercase).
static func _sore_names() -> Array:
	var ids := {}
	for e in Game.day_log.slice(-6):
		var levels: Dictionary = e.get("soreness", {})
		for id in levels:
			if int(levels[id]) >= 1:
				ids[id] = true
	var h := Game.get_system("health") as HealthSystem
	if h != null and HealthSystem.model_enabled:
		for x in h.soreness():
			if int(x.level) >= 1:
				ids[x.id] = true
	var out := []
	for a in HealthSystem.areas():
		if ids.has(a.id):
			out.append(str(a.name).to_lower())
	return out


## The athlete's last result at a meet (the race of the week), or {}.
static func _result_of(meet_key: String) -> Dictionary:
	for i in range(Game.athlete.results.size() - 1, -1, -1):
		if str(Game.athlete.results[i].meet_key) == meet_key:
			return Game.athlete.results[i]
	return {}


static func _result_text(res: Dictionary) -> String:
	var text := Race.result_text(res, ", ")
	if str(res.get("status", "")) == "":
		if bool(res.get("pb", false)):
			text += " (PB)"
	return text


## The comment key of the voice for last week: the one thing that mattered most ("" = nothing to say).
static func _situation(last: Dictionary) -> String:
	if not last.injuries.is_empty():
		return "injured"
	if last.feel == "exhausted":
		return "exhausted"
	if not last.races.is_empty():
		var o := str(last.races[0].outcome)
		if o != "":
			return "race_" + o
	if not last.sore.is_empty():
		return "sore"
	if last.feel == "tired":
		return "tired"
	if last.planned > 0 and last.done == 0:
		return "none"
	if last.planned > 0 and last.done * 4 < last.planned * 3:
		return "missed"
	if last.planned > 0 and last.done >= last.planned:
		return "kept"
	if last.feel == "fresh":
		return "fresh"
	return ""


## The plan of the coming week: Game.season.week_for(next Monday) with its races added as `races` (day -> meet).
static func _next_week() -> Dictionary:
	# (Sunday evening: today is still Sunday, so the coming week starts the next day)
	var monday := Calendar.monday_of(Game.add_days(Game.date, 1))
	var plan: Dictionary = Game.season.week_for(monday).duplicate()
	plan.monday = monday
	plan.races = Calendar.races_in_week(Game.entries, monday)
	return plan


## The coming week's hard sessions, in day order: [{id, weekday, session}].
static func _key_sessions(plan: Dictionary) -> Array:
	var out := []
	var names: Array = Data.moments.day_names
	for d in 7:
		if plan.races.has(d):
			continue
		var ids: Array = plan.days[d]
		var best := ""
		var best_load := 0.0
		for id in ids:
			var s := Data.get_session(id)
			var tags: Array = s.get("tags", [])
			if not ("hard" in tags or "speed" in tags or "long" in tags):
				continue
			var session_load := float(s.get("load", 0))
			if session_load > best_load:
				best_load = session_load
				best = str(id)
		if best != "" and str(plan.intensity[d]) != "easy":
			out.append({"id": best, "weekday": str(names[d]), "session": str(Data.get_session(best).name)})
	return out


## The race in the coming week (or the next one within a month): {meet, weekday, in_week, days}, or {}.
static func _race_ahead(plan: Dictionary) -> Dictionary:
	var names: Array = Data.moments.day_names
	if not plan.races.is_empty():
		var d: int = plan.races.keys().min()
		return {"meet": str(plan.races[d].name), "weekday": str(names[d]), "in_week": true, "days": 0}
	var next := Game.next_race()
	if next.is_empty():
		return {}
	var days := Calendar.days_between(Game.date, next.date)
	if days > 28:
		return {}
	return {"meet": str(next.name), "weekday": "", "in_week": false, "days": days}


## The one thing to focus on this week (a sentence), by what matters most.
static func _focus(last: Dictionary, plan: Dictionary, race: Dictionary) -> String:
	var f: Dictionary = cfg().talk.focus
	if not last.injuries.is_empty():
		return str(f.injured).format({"injury": str(last.injuries[0]).to_lower()})
	if not last.sore.is_empty():
		return str(f.sore).format({"area": str(last.sore[0])})
	if not race.is_empty() and race.in_week:
		return str(f.race_week).format({"meet": race.meet})
	var kind := str(plan.get("kind", ""))
	if kind == "taper":
		return str(f.taper)
	if last.feel in ["tired", "exhausted"]:
		return str(f.tired)
	if kind == "lighter":
		return str(f.lighter)
	var phase := str(plan.get("phase", ""))
	if f.phase.has(phase):
		return str(f.phase[phase])
	return str(f["default"])


# --- After a race -----------------------------------------------------------------------------------------------

## "pb" / "good" / "bad" / "hurt" for a race: `note` = {result (an athlete.results entry), story {case, line}}. "" = no race.
static func race_outcome(note: Dictionary) -> String:
	var res: Dictionary = note.get("result", {})
	if res.is_empty():
		return ""
	if str(res.get("status", "")) != "":
		return "hurt"
	var case_id := str(note.get("story", {}).get("case", ""))
	if case_id != "":
		var outcomes: Dictionary = cfg().race.outcomes
		for k in outcomes:
			if case_id in outcomes[k]:
				return str(k)
	if bool(res.get("pb", false)):
		return "pb"
	return "good" if int(res.get("place", 99)) * 2 <= int(res.get("field", 1)) else "bad"


## The coach's message on the evening after a race: the facts, the Race-story line in his own words, a closing word.
static func race_message(note: Dictionary, fill: Dictionary, rng: RandomNumberGenerator) -> String:
	var v := voice()
	var lvl := level()
	var outcome := race_outcome(note)
	var res: Dictionary = note.result
	var meet := str(note.get("meet", res.get("meet", "")))
	var paras := [str(cfg().race.facts).format({"meet": meet, "result": _result_text(res)})]
	var line := str(note.get("story", {}).get("line", ""))
	if line == "":
		line = str(v.comment["race_" + outcome]).format(fill)
	paras.append(line)
	if lvl != "short":
		paras.append(str(v.race[outcome]).format(fill))
	return "\n\n".join(paras)


# --- The coach's "why" in the day editor ----------------------------------------------------------------------

## His reason for a day (GDD 4.9.2 "Every session explains itself"): the key session's why, in his detail and voice.
## `ids` = the day's session ids, `level_id` = easy / normal / hard. Rest days get his rest line.
static func day_why(ids: Array, level_id: String) -> String:
	var d: Dictionary = voice().day
	if ids.is_empty():
		return str(d.rest)
	var lvl := level()
	var key := ""
	var best := -1.0
	for id in ids:
		var session_load := float(Data.get_session(id).get("load", 0))
		if session_load > best:
			best = session_load
			key = str(id)
	var sw: Dictionary = cfg().session_why.get(key, {})
	if sw.is_empty():
		return str(cfg().day.unknown)
	if lvl == "short":
		return "%s %s" % [sw.short, d.short_end]
	var parts := [str(sw.why)]
	if level_id == "easy":
		parts.append(str(d.easy))
	elif level_id == "hard":
		parts.append(str(d.hard))
	if lvl == "full":
		var plan := Game.season.week_for(Calendar.monday_of(Game.date))
		var phase := str(plan.get("phase", ""))
		if phase != "" and Game.season.mode == SeasonPlan.PHASES:
			parts.append(str(cfg().phase_why.get(phase, "")))
	return " ".join(parts)
