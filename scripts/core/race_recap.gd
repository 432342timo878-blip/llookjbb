class_name RaceRecap
extends RefCounted
## "What this race did" (GDD 4.10 decision 1 and "L2's questions", session L2a): what one race day changed, recorded for the card
## the race ends on (RaceRecapView) and kept with the career (Game.race_cards, the last `keep`; a tap on the planner's race strap
## opens it again). Also the scratch card (Game.scratch_race).
## RECORDING ONLY: `before` reads the game on race morning (Game.end_race_day, before the race day's load and the evening), `build`
## reads it again after the evening's hooks and before Sunday's week end (Game._end_day). Nothing here draws a die or changes a
## number, so every fingerprint stays the same.
## A card is a plain Dictionary saved as JSON (texts made when it is recorded; data/race_recap.json):
##   race:    {kind "race", id, date, meet, meet_name, sub, status, place, field, time, mark, delta, delta_text, line, rounds,
##             splits {you [4], other [4], other_time, label}, form {...}, changes [change], nothing_else, coach {name, line},
##             messages [{from, text}], goal {...}, next {...}}
##   scratch: {kind "scratch", id, date, meet, meet_name, sub, cause, why, means [lines], coach {name, line}, next {...}}
## A change: {kind (injury / mood / attr / body / tired / trust / later), id, title, value, tone (good / bad / warn / plain), cause,
## detail (the exact numbers, shown on a tap)}. Only what really moved is listed (a value that rounds to 0 is left out).


static func cfg() -> Dictionary:
	return Data.recap


# --- Race morning ------------------------------------------------------------------------------------------------------

## The state on race morning (before the race day's load, the health day and the evening's news).
static func before(rd: RaceDay) -> Dictionary:
	var a := Game.athlete
	var b := {"attrs": a.attributes.duplicate(), "fatigue": a.fatigue}
	var h := _health()
	if h != null:
		b.strain = h.strain.duplicate()
	var mind := MindSystem.sys()
	if mind != null:
		b.moods = mind.values.duplicate()
		b.last_race = mind.last_race.duplicate()
		var mc := {}   # (shallow copies of the lists: the same entries, so new_entries can tell an old entry from an equal new one)
		for mood in mind.causes:
			mc[mood] = mind.causes[mood].duplicate()
		b.mood_causes = mc
	var cs := Game.get_system("coach") as CoachSystem
	if cs != null and CoachSystem.model_enabled and not cs.head().is_empty():
		b.trust = cs.trust()
		b.trust_causes = cs.relation().get("causes", []).duplicate()
	var gs := _goals()
	if gs != null:
		var year := gs.current_year()
		b.goal_year = year
		b.best = SeasonGoals.best_in(year)
		var status := {}
		for g in gs.goals_of(year):
			status[str(g.id)] = str(g.status)
		b.goal_status = status
	var ms := _moments()
	if ms != null:
		var sizes := {}
		for t in ms.threads:
			sizes[t] = ms.threads[t].size()
		b.threads = sizes
	b.form = _form(rd)
	return b


## Form on the day: the race's own form term (RaceDay.form, made on race morning) and its two factors, with the cause the game
## knows for each (the plan's taper or easy day before it, a tiring week; few or many fast sessions). {} with the form model off.
static func _form(rd: RaceDay) -> Dictionary:
	var f := Game.get_system("form") as FormSystem
	if f == null or not FormSystem.enabled:
		return {}
	var c: Dictionary = cfg()
	var fatigue := Game.athlete.fatigue
	var w: Dictionary = FormSystem.word_for(rd.form, fatigue)
	var fwhy := ""
	var plan := Game.season.week_for(Game.week_monday())
	var d := Calendar.weekday(Game.date)
	var whys: Array = plan.get("why", [])
	if str(plan.get("kind", "")) == "taper" and str(plan.get("target", "")) == str(rd.meet.get("key", "")):
		fwhy = str(c.fresh_why.taper)
	elif d > 0 and d - 1 < whys.size() and str(whys[d - 1]).contains(str(Data.periodization.easy_day_before_race.why)):
		fwhy = str(c.fresh_why.easy_before)
	elif fatigue >= 45.0:
		fwhy = str(c.fresh_why.tired)
	var sharp_term := FormSystem.sharp_term(f.sharpness)
	var swhy := ""
	if sharp_term < 0.0:
		swhy = str(c.sharp_why.low)
	elif sharp_term > 0.0:
		swhy = str(c.sharp_why.high)
	return {"word": str(w.name), "id": str(w.id), "color": str(w.color), "share": rd.form, "fresh": clampi(100 - roundi(fatigue), 0, 100),
			"sharp": roundi(f.sharpness), "fatigue": roundi(fatigue), "fresh_term": FormSystem.fresh_term(fatigue), "sharp_term": sharp_term,
			"mind": rd.mind, "slowdown": rd.slowdown, "fwhy": fwhy, "swhy": swhy, "helps": str(w.get("helps", ""))}


# --- The evening -------------------------------------------------------------------------------------------------------

## The card of race day `rd` ({} for a race with no result of the player's). `b` = before(rd).
static func build(rd: RaceDay, b: Dictionary) -> Dictionary:
	if rd.player_results.is_empty():
		return {}
	var c: Dictionary = cfg()
	var m: Dictionary = rd.meet
	var pr: Dictionary = rd.player_results.back()
	var card := {"kind": "race", "id": "%d_%s" % [Calendar.date_key(m.date), str(m.key)], "date": Game.int_date(m.date),
			"meet": str(m.key), "meet_name": str(m.name), "sub": _sub(m, rd.story), "status": str(pr.get("status", "")),
			"place": int(pr.place), "field": int(pr.field), "time": float(pr.time), "mark": str(pr.get("mark", "")),
			"round": str(pr.round)}
	_result(card, rd, pr)
	card.splits = _splits(rd)
	card.form = b.get("form", {})
	card.changes = _changes(rd, b)
	card.nothing_else = card.changes.filter(func(x): return not str(x.kind) in ["later", "tired", "body"]).is_empty()
	card.coach = {"name": _coach_name(rd.story), "line": str(rd.story.get("line", ""))}
	card.messages = _messages(b)
	card.goal = _goal(b)
	card.next = next_race(m.date)
	return card


## "800 m P15 · Lappeenranta · Sat 13 Feb 2027 · section 4 of 5".
static func _sub(m: Dictionary, story: Dictionary) -> String:
	var c: Dictionary = cfg()
	var a := Game.athlete
	var text := str(c.meet_line).format({"cls": Calendar.age_class(a, int(m.date.year)), "place": Calendar.place(a, m),
			"date": Calendar.format_meet_date(m)})
	var round := str(story.get("round_label", ""))
	if round != "" and round != "Race":
		text += str(c.round_tail).format({"round": round.to_lower()})
	return text


## The delta against the PB / SB going in, the line under the strap (a section's place, the rounds of a meet with heats, "out").
static func _result(card: Dictionary, rd: RaceDay, pr: Dictionary) -> void:
	var c: Dictionary = cfg()
	var row := {}
	for r in rd.last_rows:
		if r.get("is_player", false):
			row = r
	var pb := float(row.get("pb_before", 0.0))
	var sb := float(row.get("sb_before", 0.0))
	var time := float(pr.time)
	card.delta = 0.0
	card.delta_text = ""
	if str(pr.get("status", "")) == "" and time > 0.0:
		var mark := str(pr.get("mark", ""))
		var ref := 0.0
		var name := ""
		if mark == "PB" and pb > 0.0:
			ref = pb
		elif mark == "SB" and sb > 0.0:
			ref = sb
		elif sb > 0.0:
			ref = sb
			name = "SB"
		elif pb > 0.0:
			ref = pb
			name = "PB"
		if ref > 0.0:
			card.delta = snappedf(time - ref, 0.01)
			var num := signed(card.delta, 2)
			card.delta_text = str(c.delta_pb).format({"delta": num}) if name == "" else str(c.delta_vs).format({"delta": num, "ref": str(c.refs[name])})
	var lines := []
	var kind := str(rd.story.get("kind", "race"))
	if kind == "sections":
		var at := 0
		for i in rd.last_rows.size():
			if rd.last_rows[i].get("is_player", false):
				at = i + 1
		if at > 0:
			lines.append(str(c.section_line).format({"place": Race._ordinal(at), "n": int(rd.story.get("group", 1))}))
	var rounds := []
	if rd.player_results.size() > 1:
		for x in rd.player_results:
			var t := Race.result_text(x)
			if str(x.get("mark", "")) != "" and str(x.get("status", "")) == "":
				t += " " + str(x.mark)
			rounds.append(str(c.rounds_line).format({"round": str(x.round), "result": t}))
	card.rounds = rounds
	if not rd.qualified:
		var nxt := "final"
		if rd.round_index < rd.rounds.size():
			nxt = "semi-final" if rd.rounds[rd.round_index] == "semi" else "final"
		lines.append(str(c.out_line).format({"next": nxt}))
	card.line = " · ".join(lines)


## The 200 m splits of the player's last race against its winner (or the runner-up when the player won): seconds per 200 m.
static func _splits(rd: RaceDay) -> Dictionary:
	var seg: Dictionary = rd.story.get("segments", {})
	if seg.is_empty():
		return {}
	var c: Dictionary = cfg()
	var who := str(seg.get("other_is", "winner"))
	var group := str(rd.story.get("group_name", ""))
	var label := str(c.splits_who[who]) if group == "" else str(c.splits_who_group[who]).format({"group": group})
	return {"you": seg.you, "other": seg.other, "other_time": float(seg.get("other_time", 0.0)), "label": label}


## What the race day changed, the most important first: an injury, the moods, the attributes that grew tonight, the most strained
## body area, tiredness, trust, and the race's training that counts on Sunday.
static func _changes(rd: RaceDay, b: Dictionary) -> Array:
	var c: Dictionary = cfg()
	var a := Game.athlete
	var out := []
	var h := _health()
	# An injury or illness found today.
	if h != null:
		var today := Calendar.date_key(Game.date)
		for e in Game.events:
			if str(e.get("kind", "")) != "diagnosis" or Calendar.date_key(e.date) != today:
				continue
			var inj := Data.get_injury(str(e.get("injury", "")))
			if inj.is_empty():
				continue
			var info := {}
			for x in h.active():
				if str(x.get("id", "")) == str(inj.get("id", "")):
					info = x
			out.append({"kind": "injury", "id": str(inj.id), "title": str(inj.get("name", "")), "value": "", "tone": "bad",
					"cause": str(c.injury_cause).format({"tier": _uc(str(info.get("tier", inj.get("tier", "")))),
						"range": str(info.get("range", ""))}).trim_suffix(" · "),
					"detail": str(inj.get("description", ""))})
	# The moods: every one that tonight's news moved.
	var mind := MindSystem.sys()
	if mind != null and b.has("moods"):
		for mood in MindSystem.MOODS:
			var v0 := float(b.moods.get(mood, mind.value(mood)))
			var v1 := mind.value(mood)
			if absf(v1 - v0) < 0.5:
				continue
			var w0 := MindSystem.word_for(mood, v0)
			var w1 := mind.word(mood)
			var up := v1 > v0
			var good := up if mood != "stress" else not up
			var news := []
			var list := []
			for x in new_entries(b.get("mood_causes", {}).get(mood, []), mind.causes.get(mood, [])):
				news.append(str(x.text))
				list.append("%s %s" % [signed(float(x.delta), 0), str(x.text)])
			var eff: Dictionary = Data.mind.ui.effects[mood]
			var side := mind.side(mood)
			var does := str(eff.get(side, eff.get("low", "")))
			if mood == "stress":
				does = str(eff.low) if side == "middle" else str(eff.high)
			var value := str(w1.name) + (" ▲" if up else " ▼")
			if str(w0.id) != str(w1.id):
				value = "%s → %s" % [str(w0.name), str(w1.name)]
			out.append({"kind": "mood", "id": mood, "title": str(Data.mind.moods[mood].name), "value": value,
					"tone": "good" if good else "bad", "cause": news[0] if not news.is_empty() else "",
					"detail": str(c.mood_detail).format({"name": str(Data.mind.moods[mood].name), "before": roundi(v0), "after": roundi(v1),
						"word_before": str(w0.name), "word_after": str(w1.name), "list": "; ".join(list), "does": does})})
	# Attributes that changed tonight (consistency from every race, composure from a big meet: MindSystem's race growth).
	var before_attrs: Dictionary = b.get("attrs", {})
	var ids := before_attrs.keys()
	ids.sort()
	for id in ids:
		var v0 := float(before_attrs[id])
		var v1 := a.get_attr(str(id))
		var d := v1 - v0
		if absf(d) < 0.005:
			continue
		var def := Data.get_attribute(str(id))
		if def.get("hidden", false):
			continue
		var cause := str(c.attr_causes.get(str(id), c.attr_causes.other))
		if str(id) == "consistency" and _varied(rd, b):
			cause = str(c.attr_causes.consistency_varied)
		out.append({"kind": "attr", "id": str(id), "title": str(def.get("name", id)), "value": signed(d, 2 if absf(d) < 0.1 else 1),
				"tone": "good" if d > 0.0 else "bad", "cause": cause,
				"detail": str(c.attr_detail).format({"name": str(def.get("name", id)), "before": "%.2f" % v0, "after": "%.2f" % v1, "cause": cause})})
	# The body: the area the race strained most (the others in its detail), then tiredness.
	if h != null and b.has("strain"):
		var line := float(Data.health.soreness.levels[HealthSystem.SORE - 1])
		var rises := []
		for area in HealthSystem.areas():
			var s0 := float(b.strain.get(area.id, 0.0))
			var s1 := float(h.strain.get(area.id, 0.0))
			if roundi(s1) - roundi(s0) >= 1:
				rises.append({"id": str(area.id), "name": str(area.name), "s0": s0, "s1": s1, "helps": str(area.get("helps", ""))})
		rises.sort_custom(func(x, y): return float(x.s1) - float(x.s0) > float(y.s1) - float(y.s0))
		if not rises.is_empty():
			var top: Dictionary = rises[0]
			var also := []
			for x in rises.slice(1, 4):
				also.append("%s +%d %%" % [str(x.name).to_lower(), roundi(float(x.s1) - float(x.s0))])
			var fill := {"before": roundi(float(top.s0)), "after": roundi(float(top.s1)), "line": roundi(line), "also": ", ".join(also), "helps": top.helps}
			var tone := "bad" if float(top.s1) >= line else ("warn" if float(top.s1) >= line - 15.0 else "plain")
			out.append({"kind": "body", "id": top.id, "title": top.name, "value": "+%d %%" % (roundi(float(top.s1)) - roundi(float(top.s0))),
					"tone": tone, "cause": str(c.body_cause).format({"now": roundi(float(top.s1))}),
					"detail": str(c.body_detail if not also.is_empty() else c.body_detail_alone).format(fill)})
	var f0 := float(b.get("fatigue", a.fatigue))
	if roundi(a.fatigue) != roundi(f0):
		var tline := float(Data.planner.body.tired_warning)
		var df := roundi(a.fatigue) - roundi(f0)
		out.append({"kind": "tired", "id": "fatigue", "title": str(c.tired_title), "value": "%+d %%" % df,
				"tone": "bad" if a.fatigue >= tline else ("warn" if a.fatigue >= tline - 15.0 else "plain"),
				"cause": str(c.tired_cause).format({"now": roundi(a.fatigue), "word": str(Training.fatigue_state(a.fatigue)[0])}),
				"detail": str(c.tired_detail).format({"before": roundi(f0), "after": roundi(a.fatigue), "line": roundi(tline)})})
	# Trust in the coach, when something tonight moved it.
	var cs := Game.get_system("coach") as CoachSystem
	if cs != null and b.has("trust") and absf(cs.trust() - float(b.trust)) >= 0.5:
		var t1 := cs.trust()
		var name := str(cs.head().get("name", ""))
		var list := []
		for x in new_entries(b.get("trust_causes", []), cs.relation().get("causes", [])):
			list.append("%s %s" % [signed(float(x.delta), 0), str(x.cause)])
		out.append({"kind": "trust", "id": "trust", "title": str(c.trust_title).format({"name": name.get_slice(" ", 0)}),
				"value": "▲" if t1 > float(b.trust) else "▼", "tone": "good" if t1 > float(b.trust) else "bad",
				"cause": list[0].substr(list[0].find(" ") + 1) if not list.is_empty() else "",
				"detail": str(c.trust_detail).format({"before": roundi(float(b.trust)), "after": roundi(t1), "list": "; ".join(list)})})
	# The race's training, which counts with the week's sessions on Sunday night (Training._apply_progression).
	var effects: Dictionary = Data.competitions.race_session.get("effects", {})
	var names := []
	var keys := effects.keys()
	keys.sort_custom(func(x, y): return float(effects[x]) > float(effects[y]))
	for k in keys:
		names.append(str(Data.get_attribute(str(k)).get("name", k)).to_lower())
	if not names.is_empty():
		var short := _uc(str(names[0]))
		if names.size() == 2:
			short += ", " + str(names[1])
		elif names.size() > 2:
			short = str(c.later_more).format({"first": short + ", " + str(names[1]), "n": names.size() - 2})
		out.append({"kind": "later", "id": "race_training", "title": str(c.later_title), "value": str(c.later_value), "tone": "plain",
				"cause": str(c.later_cause).format({"list": short}), "detail": str(c.later_detail).format({"list": ", ".join(names)})})
	return out


## Consistency grows more from a race unlike the last one (MindSystem._race_growth): the last race as it was on race morning.
static func _varied(rd: RaceDay, b: Dictionary) -> bool:
	var last: Dictionary = b.get("last_race", {})
	return last.is_empty() or str(last.get("level", "")) != str(rd.meet.get("level", "local")) or bool(last.get("indoor", false)) != bool(rd.meet.get("indoor", false))


static func _coach_name(story: Dictionary) -> String:
	var cs := Game.get_system("coach") as CoachSystem
	if cs != null and not cs.head().is_empty():
		return str(cs.head().get("name", ""))
	return str(story.get("coach_name", ""))


## The messages people (not the coach: his line is the card's) sent on the race evening: [{from, text}], at most three.
static func _messages(b: Dictionary) -> Array:
	var ms := _moments()
	if ms == null or not b.has("threads"):
		return []
	var out := []
	for t in ms.threads:
		if str(t) == "coach":
			continue
		var list: Array = ms.threads[t]
		for i in range(int(b.threads.get(t, 0)), list.size()):
			var x: Dictionary = list[i]
			if str(x.from) in ["you", "system"]:
				continue
			var p: Dictionary = ms.people.get(str(x.from), {})
			out.append({"from": StoryletSystem.person_name(p) if not p.is_empty() else str(t).capitalize(), "text": str(x.text)})
	return out.slice(0, 3)


## The goal the race moved: one settled today (met / missed), else the season's time goal with how far it is now (and how much
## closer the race brought it). {} without goals.
static func _goal(b: Dictionary) -> Dictionary:
	var gs := _goals()
	if gs == null or not b.has("goal_year"):
		return {}
	var c: Dictionary = cfg()
	var year := int(b.goal_year)
	var goals := gs.goals_of(year)
	for g in goals:
		var was := str(b.goal_status.get(str(g.id), ""))
		if was == "open" and str(g.status) in ["met", "missed"]:
			return {"text": str(c.goal_line).format({"goal": SeasonGoals.goal_text(g, year)}), "status": str(g.status),
					"note": str(c.goal_met if str(g.status) == "met" else c.goal_missed), "fill": 1.0 if str(g.status) == "met" else 0.0}
	for g in goals:
		if str(g.get("kind", "")) != "time" or str(g.status) != "open" or not g.has("time"):
			continue
		var best := SeasonGoals.best_in(year)
		var goal_time := float(g.time)
		var fill := 0.0
		var seen := float(gs.seasons.get(year, {}).get("est", {}).get("seen", 0.0))
		if best > 0.0 and seen > goal_time:
			fill = clampf((seen - best) / (seen - goal_time), 0.0, 1.0)
		var note := ""
		if best > 0.0:
			var gap := maxf(0.0, best - goal_time)
			var moved := float(b.get("best", 0.0)) - best if float(b.get("best", 0.0)) > 0.0 else 0.0
			note = str(c.goal_closer if moved >= 0.005 else c.goal_to_go).format({"gap": "%.2f" % gap, "moved": "%.2f" % moved})
		return {"text": str(c.goal_line).format({"goal": SeasonGoals.goal_text(g, year)}), "status": "open", "note": note, "fill": fill}
	return {}


## The next race entered after `after` (a date): {name, date, days} or {} with none entered.
static func next_race(after: Dictionary) -> Dictionary:
	var from := Game.add_days(after, 1)
	for m in Calendar.meets_between(from, Game.add_days(after, 400)):
		if m.key in Game.entries:
			return {"name": str(m.name), "date": Game.int_date(m.date), "days": Calendar.days_between(Game.date, m.date)}
	return {}


# --- A scratch -----------------------------------------------------------------------------------------------------------

## Why the race was scratched, read before the entry goes (Game.scratch_race): your call, with the injury or the sore area the
## game sees today, a busy test week, or his advice with the area that worried him.
static func scratch_why(cause: String) -> String:
	var c: Dictionary = cfg().scratch_why
	if cause == "school":
		return str(c.school)
	var h := _health()
	var top := {}
	if h != null:
		for area in HealthSystem.areas():
			var s := float(h.strain.get(area.id, 0.0))
			if top.is_empty() or s > float(top.s):
				top = {"name": str(area.name), "s": s, "level": h.soreness_level(str(area.id))}
	if cause == "coach":
		if top.is_empty():
			return str(c.player)
		return str(c.coach).format({"area": str(top.name).to_lower(), "pct": roundi(float(top.s))})
	if h != null:
		for x in h.active():
			if str(x.get("tier", "")) != "illness":
				return str(c.injury).format({"injury": str(x.get("name", "")).to_lower()})
		if not top.is_empty() and int(top.level) >= HealthSystem.SORE:
			return str(c.hurt).format({"area": str(top.name).to_lower(), "pct": roundi(float(top.s)),
					"word": HealthSystem.soreness_word(int(top.level)).to_lower()})
	return str(c.player)


## The area the coach worried about for his card line ("" when nothing is near the sore line).
static func sore_area_name() -> String:
	var h := _health()
	if h == null:
		return ""
	var top := ""
	var most := -1.0
	for area in HealthSystem.areas():
		var s := float(h.strain.get(area.id, 0.0))
		if s > most:
			most = s
			top = str(area.name).to_lower()
	return top if most >= float(Data.health.soreness.levels[HealthSystem.SORE - 1]) - 15.0 else ""


## The plan of every week from this one to the meet's (days + intensity), to see what the scratch gives back.
static func plan_until(meet: Dictionary) -> Array:
	var out := []
	if meet.is_empty():
		return out
	var monday := Game.week_monday()
	var last := Calendar.date_key(Calendar.monday_of(meet.date))
	while Calendar.date_key(monday) <= last:
		var p := Game.season.week_for(monday)
		out.append({"monday": monday, "days": p.days.duplicate(true), "intensity": p.intensity.duplicate()})
		monday = Game.add_days(monday, 7)
	return out


## The scratch card. `plan_before` = plan_until(meet) before the entry went; `was_target` = it was a target race.
static func scratch(meet: Dictionary, cause: String, why: String, plan_before: Array, was_target: bool, line: String) -> Dictionary:
	var c: Dictionary = cfg()
	var means := []
	# The race day itself (when it is this week): what it is now.
	var w := Game.current_week()
	var key := Calendar.date_key(meet.date)
	if key >= Calendar.date_key(w.monday) and key <= Calendar.date_key(Game.add_days(w.monday, 6)):
		var d := Calendar.weekday(meet.date)
		var names := []
		for sid in w.session_ids(d):
			names.append(str(Data.get_session(sid).get("name", sid)))
		var day := str(Data.moments.day_names[d])
		means.append(str(c.scratch_day).format({"day": day, "sessions": ", ".join(names)}) if not names.is_empty()
				else str(c.scratch_day_rest).format({"day": day}))
	if was_target:
		means.append(str(c.scratch_target))
	# Days of the plan (from today, not the race day) that the race had made lighter and that go back now.
	var back := 0
	var today := Calendar.date_key(Game.date)
	for p in plan_before:
		var now := Game.season.week_for(p.monday)
		for d in 7:
			var dk := Calendar.date_key(Game.add_days(p.monday, d))
			if dk < today or dk == key:
				continue
			if now.days[d] != p.days[d] or str(now.intensity[d]) != str(p.intensity[d]):
				back += 1
	if back == 1:
		means.append(str(c.scratch_day_back))
	elif back > 1:
		means.append(str(c.scratch_days_back).format({"n": back}))
	var cs := Game.get_system("coach") as CoachSystem
	var name := str(cs.head().get("name", "")) if cs != null and CoachSystem.model_enabled else ""
	return {"kind": "scratch", "id": "%d_%s_x" % [key, str(meet.key)], "date": Game.int_date(meet.date), "meet": str(meet.key),
			"meet_name": str(meet.name), "sub": str(c.meet_line).format({"cls": Calendar.age_class(Game.athlete, int(meet.date.year)),
				"place": Calendar.place(Game.athlete, meet), "date": Calendar.format_meet_date(meet)}),
			"cause": cause, "why": why, "means": means, "coach": {"name": name, "line": line}, "next": next_race(Game.date)}


# --- Helpers -------------------------------------------------------------------------------------------------------------

## A card from a save: JSON made every number a float; the whole numbers become ints again (so a loaded card is the card saved).
static func fixed(c: Dictionary) -> Dictionary:
	c.date = Game.int_date(c.date)
	for k in ["place", "field"]:
		if c.has(k):
			c[k] = int(c[k])
	var f: Dictionary = c.get("form", {})
	for k in ["fresh", "sharp", "fatigue"]:
		if f.has(k):
			f[k] = int(f[k])
	var n: Dictionary = c.get("next", {})
	if not n.is_empty():
		n.date = Game.int_date(n.date)
		n.days = int(n.days)
	return c


## The entries of a cause list (newest last, the oldest dropped at its cap) added since `before` was copied: everything after the
## last entry `before` had (all of `after` when that one has been dropped or `before` was empty). `before` is a shallow copy, so
## the entries are the same objects: an equal news entry added tonight (the same meet twice on one date) is still new.
static func new_entries(before: Array, after: Array) -> Array:
	if before.is_empty():
		return after.duplicate()
	var last = before.back()
	for i in range(after.size() - 1, -1, -1):
		if is_same(after[i], last):
			return after.slice(i + 1)
	return after.duplicate()


static func _uc(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1)


## "+0.04" / "−6.51" (a real minus sign); a value that rounds to 0 has no sign ("0.0").
static func signed(v: float, decimals: int) -> String:
	var step := pow(10.0, -decimals)
	if absf(snappedf(v, step)) < step * 0.5:
		return ("%." + str(decimals) + "f") % 0.0
	var text := ("%+." + str(decimals) + "f") % v
	return text.replace("-", "−")


static func _health() -> HealthSystem:
	var h := Game.get_system("health") as HealthSystem
	return h if h != null and HealthSystem.model_enabled and h.started else null


static func _goals() -> SeasonGoals:
	var gs := SeasonGoals.sys()
	return gs if gs != null and SeasonGoals.enabled else null


static func _moments() -> StoryletSystem:
	var ms := Game.get_system("moments") as StoryletSystem
	return ms if ms != null and ms.active() else null
