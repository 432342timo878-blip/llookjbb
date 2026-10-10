class_name RaceStory
extends RefCounted
## The Race story on the result screen (GDD 4.3.1, step R4): the player's splits at 200 / 400 / 600 m and the finish next
## to the winner's, the four to six key moments of the race, and the coach's one-line verdict in his own words
## (data/coaches.json `story`). Built from the finished race (its events, the runners' split marks) and, for a watched race,
## the commentary's own events and verdicts. Works for quick races too. Texts: data/race_commentary.json `events.<type>.story`
## and `story`.


## `ctx`: commentary (a RaceCommentary or null), coach_id ("" = the athlete's coach), athlete (or null), and for a meet with
## rounds (decisions 43, 47): kind (race / sections / heat / semi / final), overall_place (sections: the place by time across
## all sections, 0 = unknown), pre_rank (the player's rank by seeding before the race, 0 = no mark, see RaceDay.pre_race_rank).
## → {title, splits [{label, you, winner}], other_head, moments [{m, text}], coach_name, coach_title, coach, case, place}
static func build(race: Race, ctx := {}) -> Dictionary:
	var cfg: Dictionary = Data.race_commentary.story
	var p := race.player
	var res := race.results()
	var place := 0
	for i in res.size():
		if res[i].is_player:
			place = i + 1
	var kind: String = str(ctx.get("kind", "race"))
	var overall := int(ctx.get("overall_place", 0))
	var winner: Race.Runner = null
	var second: Race.Runner = null
	var fin := race.runners.filter(func(r): return r.done and r.status == "")
	fin.sort_custom(func(a, b): return a.t < b.t)
	if fin.size() > 0:
		winner = fin[0]
	if fin.size() > 1:
		second = fin[1]
	var other: Race.Runner = winner
	var other_head := "WINNER"
	if winner == p and second != null:
		other = second
		other_head = "2ND PLACE"
	var out := {"title": cfg.title, "other_head": other_head, "place": overall if overall > 0 else place, "splits": [], "moments": []}
	for m in Race.SPLIT_MARKS:
		out.splits.append({"label": cfg.marks[str(m)], "you": _mark_text(p, m), "winner": _mark_text(other, m)})
	out.splits.append({"label": cfg.marks["800"], "you": _finish_text(p), "winner": _finish_text(other)})
	out.moments = _moments(race, ctx.get("commentary", null), cfg)
	var case_id := verdict_case(race, place, {"kind": kind, "overall": overall, "pre_rank": int(ctx.get("pre_rank", -1))})
	var coach_id: String = str(ctx.get("coach_id", race.coach_id))
	if coach_id == "":
		coach_id = Coaches.id_of(ctx.get("athlete", null))
	var coach := Coaches.get_coach(coach_id)
	var list: Array = coach.story.get(case_id, [])
	out.case = case_id
	out.coach_name = coach.name
	out.coach_title = coach.title
	out.coach = str(list[randi() % list.size()]) if not list.is_empty() else ""
	return out


## "31.2 (4th)" for a split, "–" when the runner did not get there.
static func _mark_text(r: Race.Runner, m: int) -> String:
	if r == null or not r.marks.has(m):
		return Data.race_commentary.story.no_winner_split
	var text := RaceCommentary._t1(float(r.marks[m].t))
	return "%s (%s)" % [text, Race._ordinal(int(r.marks[m].pos))]


static func _finish_text(r: Race.Runner) -> String:
	if r == null or not r.done or r.status != "":
		return Data.race_commentary.story.no_winner_split
	return Calendar.format_time(snappedf(r.t, 0.01))


## The case the coach talks about: the first that fits (dnf, dq, fell, won / won_part, kick_died, boxed, faded / too_fast,
## good_kick, podium, better, as_expected, below).
## `place` = the place in this race (a section or heat for those rounds). `opts` (decisions 43, 47): kind (race / sections /
## heat / semi / final), overall (sections: the overall place, 0 = unknown), pre_rank (the rank by seeding before the race
## among the same field, 0 = no mark, -1 = not given: then the day's ability is compared, for the tools). In sections the
## win and the podium go by the overall place; a heat or section place alone is never a podium ("won_part" = won the heat /
## section).
static func verdict_case(race: Race, place: int, opts := {}) -> String:
	var p := race.player
	var kind: String = str(opts.get("kind", "race"))
	var grouped := kind in ["heat", "semi", "sections"]
	var overall := int(opts.get("overall", 0))
	var medal_place := place
	if kind == "sections":
		medal_place = overall if overall > 0 else 99
	elif grouped:
		medal_place = 99
	if p.status == "dnf":
		return "dnf"
	if p.status == "dq":
		return "dq"
	if p.falls > 0:
		return "fell"
	if medal_place == 1:
		return "won"
	if grouped and place == 1:
		return "won_part"
	var kick_died := false
	var boxed_long := false
	for ev in race.events:
		if not bool(ev.get("player", false)):
			continue
		if ev.type == "kick_dying":
			kick_died = true
		elif ev.type == "escape" and (float(ev.get("seconds", 0.0)) >= 2.0 or float(ev.get("lost", 0.0)) >= 3.0):
			boxed_long = true
	if kick_died:
		return "kick_died"
	if boxed_long:
		return "boxed"
	var pos200: int = int(p.marks[200].pos) if p.marks.has(200) else place
	var pos600: int = int(p.marks[600].pos) if p.marks.has(600) else place
	if place - pos600 >= 2:
		return "too_fast" if pos200 <= 2 else "faded"
	if pos600 - place >= 2:
		return "good_kick"
	if medal_place <= 3:
		return "podium"
	# Where the pre-race picture (the seeding by season best / PB) put them against where they finished. Not the day's ability:
	# that includes the hidden race-day form, so a bad day would count as "as expected".
	var pre_rank := int(opts.get("pre_rank", -1))
	if pre_rank == 0:
		return "as_expected"   # (no mark yet: nothing to compare with)
	var compare := place if kind != "sections" or overall <= 0 else overall
	var diff := 0
	if pre_rank > 0:
		diff = pre_rank - compare
	else:
		var stronger := 0
		for r in race.runners:
			if r != p and r.ability > p.ability:
				stronger += 1
		diff = (stronger + 1) - place
	var band := int(Data.race_commentary.story.expected_band)
	if diff > band:
		return "better"
	if diff < -band:
		return "below"
	return "as_expected"


## Four to six key moments, in the order they happened: the events with a `story` line in the data, weighted (the player's
## own, the front of the race, late ones count more), at most `per_type` of one kind, plus the verdicts on the player's choices.
static func _moments(race: Race, commentary, cfg: Dictionary) -> Array:
	var specs: Dictionary = Data.race_commentary.events
	var cands := []
	var evs: Array = race.events.duplicate()
	if commentary != null:
		evs.append_array(commentary.synth_events)
	var pname := Race._surname(race.player.name)
	for ev in evs:
		var spec: Dictionary = specs.get(ev.type, {})
		if not spec.has("story"):
			continue
		if ev.type in ["finish", "close_finish", "photo_finish"] and not ev.get("synth", false) and commentary != null:
			continue   # (the commentary's own, made when the runners crossed; the engine's come at the end)
		var mine := bool(ev.get("player", false))
		var pos := int(ev.get("pos", 9))
		if not mine and pos > 4 and ev.type not in ["close_finish", "photo_finish"]:
			continue
		if ev.type == "escape" and float(ev.get("seconds", 0.0)) < float(Data.race_commentary.rules.box_story_s) and not mine:
			continue
		var d_at: Variant = ev.get("d", Race.DISTANCE if ev.type in ["finish", "close_finish", "photo_finish"] else 0)   # (the finish has no spot of its own)
		var weight := float(spec.get("story_weight", 3))
		if mine:
			weight += 3.0
		weight += float(d_at) / 400.0   # (later in the race counts a little more)
		var tpl: String = str(spec.story.player if mine else spec.story.other)
		var f := {"name": Race._surname(str(ev.get("who", ""))), "to_go": str(roundi(Race.DISTANCE - float(d_at))),
				"m": str(roundi(float(d_at))), "gap": str(roundi(float(ev.get("gap", 0)))),
				"seconds": "%.1f" % float(ev.get("seconds", 0.0)), "place": Race._ordinal(int(ev.get("place", 1))),
				"place_next": Race._ordinal(int(ev.get("place", 1)) + 1), "margin": "%.2f" % float(ev.get("margin", 0.0))}
		cands.append({"m": roundi(float(d_at)), "t": float(ev.get("t", 0.0)), "type": ev.type, "weight": weight,
				"text": tpl.format(f)})
	if commentary != null:
		for v in commentary.final_verdicts():   # (the 10 s lines are only "so far": the real verdict is in hindsight, decision 44)
			# (the verdict line alone reads oddly without its card: "You chose “Dig in”. It's costing a lot...")
			var label := ""
			for o in Data.race_cards.cards.get(str(v.card), {}).get("options", []):
				if o.id == v.answer:
					label = str(o.label)
			var text := str(v.text) if label == "" else "You chose “%s”. %s" % [label, v.text]
			cands.append({"m": int(v.m), "t": float(v.t), "type": "verdict", "weight": 6.0, "text": text})
	cands.sort_custom(func(a, b): return a.weight > b.weight)
	var picked := []
	var per_type := {}
	for c in cands:
		if picked.size() >= int(cfg.max_moments):
			break
		if int(per_type.get(c.type, 0)) >= int(cfg.per_type):
			continue
		per_type[c.type] = int(per_type.get(c.type, 0)) + 1
		picked.append(c)
	picked.sort_custom(func(a, b): return a.t < b.t)
	return picked.map(func(c): return {"m": c.m, "text": c.text})

