class_name CoachProposals
extends GameSystem
## The coach changes days himself (GDD 4.9.2 "Proposals and the veto", session C4). GameSystem id "proposals", after the
## moments in Game.systems. Every morning he looks at today, every evening from tomorrow, as far ahead as his load management
## lets him (data/coaching.json proposals.look_ahead), but only when something catches his eye: soreness, fatigue, a race
## close, a request from the Sunday talk (each signal through his noise, so a poor load manager also sees what isn't there).
## Then he tries his candidate changes (Easy, the hard session swapped for an easy run, a rest day, mobility before a race;
## heavier ones only when you asked for more) with CoachVerdict and proposes the one HE thinks is best when he thinks it is a
## Good idea. A race day with soreness or an injury can get his "scratch?" advice.
## The standing order "Let the coach adjust my days" (setting(), saved per career): Ask me first (the default, user
## 2026-10-11: a message with OK / Veto that stops Play week), Always, tell me (he changes the day by = "coach" and tells you;
## Veto in the day editor), Never (he changes nothing but says what he would have changed; trusting on through a real warning
## costs a little trust). Scratching is never done by itself: always asked (Never: a message).
## The player decides: he only changes unplayed non-race days that nobody else changed; a Veto puts the plan back (reset_day).
## A veto with a reason is free; from the third silent one within four weeks each costs a little trust (user 2026-10-11).
## Static off switch `enabled` (like StoryletSystem.talks_enabled): OFF unless the app shell (main.gd) switches it on, so the
## balance tools play exactly as before; tools/verdict_check.gd and training_balance part 2e test it on.

static var enabled := false

const NONE := "_none"   # a proposal moment left without one of its replies (tools answer "ok"): nothing changes

var mode := ""         # "ask" / "always" / "never"; "" = the default of data/coaching.json proposals.default_mode
var rng := RandomNumberGenerator.new()
var list: Array = []    # proposals, oldest first (the last proposals.keep): see _propose
var requests: Array = []   # from the Sunday talk: [{kind ("lighter_week" / "more_load"), day (day number)}]
var week := {}         # {monday (day number), count}
var last_day := -1     # day number of the last proposal
var silent: Array = [] # day numbers of silent vetoes
var _next := 1
## Not saved, for the tools: every proposal made since the system was made.
var fired: Array = []


func _init() -> void:
	id = "proposals"
	GameConfig.randomize_dice(rng, "proposals")


static func cfg() -> Dictionary:
	return Data.coaching.proposals


static func texts() -> Dictionary:
	return Data.coach_talk.proposal


## "ask" / "always" / "never".
func setting() -> String:
	return mode if mode != "" else str(cfg().default_mode)


func set_setting(m: String) -> void:
	if m in cfg().modes:
		mode = m


# --- The day loop -----------------------------------------------------------------------------------------------

## Morning: he looks at today and the days after it.
func on_day_start(ctx: Dictionary) -> void:
	if not enabled or Game.athlete == null:
		return
	_look(ctx, int(ctx.day))


## Evening: did you train on through his warning ("Never")? Then he looks from tomorrow.
func on_day_end(ctx: Dictionary) -> void:
	if not enabled or Game.athlete == null:
		return
	_check_ignored(ctx)
	if int(ctx.day) < 6:
		_look(ctx, int(ctx.day) + 1)


func _week_check(today: int, weekday: int) -> void:
	var monday := today - weekday
	if int(week.get("monday", -1)) != monday:
		week = {"monday": monday, "count": 0}


## One look from day `first` of this week.
func _look(ctx: Dictionary, first: int) -> void:
	var w: WeekSim = ctx.get("week")
	if w == null:
		return
	var today := StoryletSystem.day_no(ctx.date)
	_week_check(today, int(ctx.day))
	requests = requests.filter(func(r): return today - int(r.day) <= int(cfg().request_days))
	if last_day == today or int(week.count) >= int(cfg().max_per_week):
		return
	if setting() == "ask" and not Game.pending_event().is_empty():
		return   # (another stop already waits: he doesn't pile a second one on top)
	var cs := Game.get_system("coach") as CoachSystem
	if cs == null or cs.head().is_empty():
		return
	var coach := CoachVerdict.head_view()
	var lm := float(coach.attributes.get("load_management", 10))
	var last_d := mini(6, first + look_ahead(lm) - 1)
	if first > last_d:
		return
	if not requests.is_empty() and int(ctx.day) == first:   # (a request waits for a morning)
		_fulfil_request(ctx, w, first, coach, today)
		return
	if _scratch_advice(ctx, w, first, last_d, coach, lm, today):
		return
	var race_soon := _race_within(w, first, last_d + int(cfg().trigger.race_days))
	if not _caught_eye(lm, race_soon):
		return
	var best := {}
	for d in range(first, last_d + 1):
		if not _free_day(w, d):
			continue
		var cur := CoachVerdict.day_now(w, d)
		var soon := _race_within(w, d + 1, d + int(cfg().trigger.race_days))
		for cand in candidates(w, d, "lighter", soon):
			var j := CoachVerdict.judge(CoachVerdict.day_change({d: cur}, {d: cand}, "day_changed", [], "proposal"), coach)
			if j.verdict == CoachVerdict.GOOD and float(j.seen.total) >= float(cfg().propose_min_w) \
					and (best.is_empty() or float(j.seen.total) > float(best.j.seen.total)):
				best = {"d": d, "cur": cur, "cand": cand, "j": j}
	if not best.is_empty():
		_propose("lighter", w, [{"d": best.d, "from": best.cur, "to": best.cand}], best.j, ctx, today)


## How many days ahead a coach with this load management looks (data proposals.look_ahead).
static func look_ahead(lm: float) -> int:
	var n := 1
	for row in cfg().look_ahead:
		if lm >= float(row[0]):
			n = int(row[1])
	return n


## Does something catch his eye? The most loaded area against trigger.sore_strain, fatigue against trigger.fatigue, a race
## close; plus his noise (a poor load manager sees things that aren't there, and misses some that are).
func _caught_eye(lm: float, race_soon: bool) -> bool:
	var tr: Dictionary = cfg().trigger
	var level := Game.athlete.fatigue / float(tr.fatigue)
	var h := Game.get_system("health") as HealthSystem
	if h != null and HealthSystem.model_enabled and h.started:
		var most := 0.0
		for area in HealthSystem.areas():
			most = maxf(most, float(h.strain.get(area.id, 0.0)))
		level = maxf(level, most / float(tr.sore_strain))
	if race_soon:
		level = maxf(level, float(tr.level))
	level += rng.randfn(0.0, float(tr.noise_per_point) * maxf(0.0, 20.0 - lm))
	return level >= float(tr.level)


## A race on a day from..to of this week (to may run past Sunday: then the next entered race decides).
func _race_within(w: WeekSim, from: int, to: int) -> bool:
	for d in range(from, mini(to, 6) + 1):
		if w.is_race_day(d):
			return true
	if to > 6:
		var next := Game.next_race()
		if not next.is_empty() and Calendar.days_between(w.monday, next.date) <= to:
			return true
	return false


## A day he may change: not played, not a race day, nobody (you, an injury, he himself) changed it, not proposed before, and
## not the day a "sore" warning already asked you about.
func _free_day(w: WeekSim, d: int) -> bool:
	if not w.can_change(d) or w.changes.has(d):
		return false
	var date := Game.add_days(w.monday, d)
	return not proposed_on(date) and not _sore_asked(date)


## The "sore" warning (HealthSystem) of the evening before asked about this day.
static func _sore_asked(date: Dictionary) -> bool:
	var before := Calendar.date_key(Game.add_days(date, -1))
	for e in Game.events:
		if str(e.get("kind", "")) == "sore" and Calendar.date_key(e.date) == before:
			return true
	return false


## A proposal (or a scratch advice) was already made for this date.
func proposed_on(date: Dictionary) -> bool:
	var key := Calendar.date_key(date)
	for p in list:
		for x in p.days:
			if Calendar.date_key(x.date) == key:
				return true
	return false


## His candidate changes of day `d` ("lighter": Easy, the hard session swapped for an easy run, a rest day, mobility when a
## race is close; "heavier": a step up in intensity, an easy run added to a day with one easy session).
static func candidates(w: WeekSim, d: int, dir: String, race_soon := false) -> Array:
	var cur := CoachVerdict.day_now(w, d)
	var out := []
	var month := int(Game.add_days(w.monday, 3).month)
	var easy := str(cfg().easy_session)
	var light := str(cfg().light_session)
	var ids: Array = cur.sessions
	if ids.is_empty():
		return out
	var hard := _hardest(ids)
	if dir == "lighter":
		if cur.intensity != "easy":
			out.append({"sessions": ids.duplicate(), "intensity": "easy"})
		if hard != "" and not easy in ids and Training.is_available(Data.get_session(easy), month):
			var swapped := ids.duplicate()
			swapped[swapped.find(hard)] = easy
			out.append({"sessions": swapped, "intensity": cur.intensity})
		out.append({"sessions": [], "intensity": cur.intensity})
		if race_soon and ids != [light]:
			out.append({"sessions": [light], "intensity": WeekSim.NORMAL})
	else:
		if cur.intensity == "easy":
			out.append({"sessions": ids.duplicate(), "intensity": WeekSim.NORMAL})
		elif cur.intensity == WeekSim.NORMAL and hard != "":
			out.append({"sessions": ids.duplicate(), "intensity": "hard"})
		if ids.size() == 1 and hard == "" and ids[0] != easy and Training.is_available(Data.get_session(easy), month):
			out.append({"sessions": [ids[0], easy], "intensity": cur.intensity})
	return out


## The day's hardest session with a "hard" or "speed" tag (by its strain), or "".
static func _hardest(ids: Array) -> String:
	var best := ""
	var most := -1.0
	for id in ids:
		var s := Data.get_session(id)
		var tags: Array = s.get("tags", [])
		if not ("hard" in tags or "speed" in tags):
			continue
		var total := 0.0
		for area in s.get("strain", {}):
			total += float(s.strain[area])
		if total > most:
			most = total
			best = str(id)
	return best


# --- Requests from the Sunday talk ----------------------------------------------------------------------------

## A reply of the week talk asked for a lighter week or for more (storylet effect "proposal"): he looks at it the next morning.
func request(kind: String) -> void:
	if not enabled or not kind in texts().request_names:
		return
	requests.append({"kind": kind, "day": StoryletSystem.day_no(Game.date)})


## The oldest request: lighter = the two heaviest days left made Easy (or one), more = the best step up he sees. He goes along
## unless he thinks it Pointless or Risky; then he says why in a message.
func _fulfil_request(ctx: Dictionary, w: WeekSim, first: int, coach: Dictionary, today: int) -> void:
	var req: Dictionary = requests.pop_front()
	var kind := str(req.kind)
	var free := []
	for d in range(first, 7):
		if _free_day(w, d) and not w.session_ids(d).is_empty():
			free.append(d)
	if free.is_empty():
		return
	var options := []   # [{set: {d: {sessions, intensity}}, from: {d: ...}}]
	if kind == "lighter_week":
		var by_load := free.duplicate()
		by_load.sort_custom(func(x, y): return _day_load(w, x) > _day_load(w, y))
		var heavy := by_load.filter(func(d): return w.intensity(d) != "easy")
		if heavy.size() >= 2:
			options.append([heavy[0], heavy[1]])
		if not heavy.is_empty():
			options.append([heavy[0]])
	var best := {}
	var fallback := {}
	if kind == "lighter_week":
		for days in options:
			var base := {}
			var cand := {}
			for d in days:
				base[d] = CoachVerdict.day_now(w, d)
				cand[d] = {"sessions": base[d].sessions.duplicate(), "intensity": "easy"}
			var j := CoachVerdict.judge(CoachVerdict.day_change(base, cand, "day_changed", [], "request"), coach)
			fallback = {"base": base, "cand": cand, "j": j} if fallback.is_empty() else fallback
			if j.verdict in [CoachVerdict.GOOD, CoachVerdict.FINE] and (best.is_empty() or float(j.seen.total) > float(best.j.seen.total)):
				best = {"base": base, "cand": cand, "j": j}
	else:
		for d in free:
			var cur := CoachVerdict.day_now(w, d)
			for cand in candidates(w, d, "heavier"):
				var j := CoachVerdict.judge(CoachVerdict.day_change({d: cur}, {d: cand}, "day_changed", [], "request"), coach)
				if fallback.is_empty() or float(j.seen.total) > float(fallback.j.seen.total):
					fallback = {"base": {d: cur}, "cand": {d: cand}, "j": j}
				if j.verdict in [CoachVerdict.GOOD, CoachVerdict.FINE] and (best.is_empty() or float(j.seen.total) > float(best.j.seen.total)):
					best = {"base": {d: cur}, "cand": {d: cand}, "j": j}
	var what := str(texts().request_names[kind]).format({})
	if best.is_empty():
		var ms := Game.get_system("moments") as StoryletSystem
		if ms != null and not fallback.is_empty():
			ms.coach_says(str(texts().request_no).format({"what": what}) + " " + _reason(fallback.j))
		return
	var days := []
	var keys: Array = best.cand.keys()
	keys.sort()
	for d in keys:
		days.append({"d": d, "from": best.base[d], "to": best.cand[d]})
	_propose("lighter" if kind == "lighter_week" else "heavier", w, days, best.j, ctx, today,
			{"request": kind, "prefix": str(texts().request_yes).format({"what": what})})


static func _day_load(w: WeekSim, d: int) -> float:
	var total := 0.0
	for id in w.session_ids(d):
		total += Training.session_load(Game.athlete, Data.get_session(id))
	return total * float(Training.intensity(w.intensity(d)).load)


# --- Scratch advice -------------------------------------------------------------------------------------------

## A race day within his look-ahead while something is sore or an injury is active: when racing looks Risky to him (scratching
## a Good idea), his "scratch?" advice. Never scratched by itself: in Ask me first and Always it asks, in Never it is a message.
func _scratch_advice(ctx: Dictionary, w: WeekSim, first: int, last_d: int, coach: Dictionary, lm: float, today: int) -> bool:
	var h := Game.get_system("health") as HealthSystem
	if h == null or not HealthSystem.model_enabled or not h.started:
		return false
	var worry := not h.injuries.filter(func(i): return str(i.tier) != "illness").is_empty()
	for area in HealthSystem.areas():
		worry = worry or h.soreness_level(area.id) >= HealthSystem.SORE
	if not worry:
		return false
	for d in range(first, last_d + 1):
		if not w.is_race_day(d) or d < w.day:
			continue
		var date := Game.add_days(w.monday, d)
		if proposed_on(date) or _sore_asked(date):
			continue
		var j := CoachVerdict.judge(CoachVerdict.race_change(d), coach)
		if j.verdict != CoachVerdict.GOOD:
			continue
		var easy := {"sessions": [str(cfg().easy_session)], "intensity": "easy"}
		_propose("scratch", w, [{"d": d, "from": {"sessions": [], "intensity": WeekSim.NORMAL, "race": true}, "to": easy}], j, ctx,
				today, {"meet": str(w.races[d].key), "meet_name": str(w.races[d].name)})
		return true
	return false


# --- Making a proposal ------------------------------------------------------------------------------------------

## A proposal: {id, day (posted), date, monday, kind (lighter / heavier / scratch), days [{d, date, from, to, vetoed}], meet,
## meet_name, request, verdict (his), reason, truth, truth_reason, warning (the truth says the day as it was is Risky), mode,
## status ("asked" / "accepted" / "applied" / "vetoed" / "noticed" / "none"), moment, veto (the reason id), checked}.
func _propose(kind: String, w: WeekSim, days: Array, j: Dictionary, ctx: Dictionary, today: int, extra := {}) -> Dictionary:
	var th: Dictionary = CoachVerdict.cfg().thresholds
	var t: Dictionary = j.truth
	var p := {"id": "p%d" % _next, "day": today, "date": ctx.date.duplicate(), "monday": w.monday.duplicate(), "kind": kind,
			"days": [], "meet": str(extra.get("meet", "")), "meet_name": str(extra.get("meet_name", "")),
			"request": str(extra.get("request", "")), "verdict": str(j.verdict), "reason": str(j.reason),
			"truth": str(t.verdict), "truth_reason": str(t.reason),
			"warning": float(t.risk_w) >= float(th.risky) and t.verdict == CoachVerdict.GOOD, "mode": setting(), "status": "",
			"moment": "", "veto": "", "checked": false, "said": _reason(j)}
	for x in days:
		p.days.append({"d": int(x.d), "date": Game.add_days(w.monday, int(x.d)), "from": x.from, "to": x.to, "vetoed": false})
	_next += 1
	list.append(p)
	while list.size() > int(cfg().keep):
		list.pop_front()
	week["count"] = int(week.get("count", 0)) + 1
	last_day = today
	fired.append(p)
	var ms := Game.get_system("moments") as StoryletSystem
	var prefix := str(extra.get("prefix", ""))
	match setting():
		"ask":
			p.status = "asked"
			if ms != null:
				var m := ms.post_proposal(p.id, _text(p, "ask_end", prefix), _replies(p), true)
				p.moment = str(m.get("id", ""))
		"always":
			if kind == "scratch":   # (a race is never scratched by itself: always asked)
				p.status = "asked"
				if ms != null:
					var m2 := ms.post_proposal(p.id, _text(p, "ask_end", prefix), _replies(p), true)
					p.moment = str(m2.get("id", ""))
			else:
				_apply(p)
				p.status = "applied"
				if ms != null:
					ms.coach_says(_text(p, "applied_end", prefix))
		_:
			p.status = "noticed"
			if ms != null:
				ms.coach_says(_text(p, "noticed_end", prefix))
	return p


## His message: the opening line of his voice, the day lines (or the scratch line), his reason, the end of the setting.
func _text(p: Dictionary, end_key: String, prefix := "") -> String:
	var t := texts()
	var voice := Coaches.id_of(Game.athlete)
	var parts := []
	if prefix != "":
		parts.append(prefix)
	else:
		parts.append(str(t.intro.get(voice, t.intro.calm)))
	if p.kind == "scratch":
		var x: Dictionary = p.days[0]
		var key := "scratch_noticed" if end_key == "noticed_end" else "scratch"
		parts.append(str(t[key]).format({"meet": p.meet_name, "when": _when(x.date)}))
	else:
		for x in p.days:
			parts.append(change_line(int(x.d), x.from, x.to))
	if str(p.said) != "":
		parts.append(str(p.said))
	parts.append(str(t[end_key]))
	return " ".join(parts)


## "Thursday: Easy run instead of 800 m intervals." / "Thursday: Fartlek at Easy instead of Normal." (the same sessions).
static func change_line(d: int, from: Dictionary, to: Dictionary) -> String:
	var t := texts()
	if from.sessions == to.sessions and not to.sessions.is_empty():
		return str(t.change_level).format({"day": _day_name(d), "sessions": CoachVerdict.day_text(to.sessions, WeekSim.NORMAL),
				"to": Training.intensity(str(to.intensity)).name, "from": Training.intensity(str(from.intensity)).name})
	return str(t.change_line).format({"day": _day_name(d), "to": CoachVerdict.day_text(to.sessions, str(to.intensity)),
			"from": CoachVerdict.day_text(from.sessions, str(from.intensity)).to_lower()})


## His reason without the opening word of his verdict (the proposal is his idea, not yours).
static func _reason(j: Dictionary) -> String:
	var v: Dictionary = Data.coach_talk.verdict
	var full := str(j.text)
	var voice: Dictionary = v.voice.get(Coaches.id_of(Game.athlete), v.voice.calm)
	var opener := str(voice.get(j.verdict, ""))
	if opener != "" and full.begins_with(opener):
		full = full.substr(opener.length()).strip_edges()
	return full


static func _when(date: Dictionary) -> String:
	var w: Dictionary = texts().scratch_when
	var n := Calendar.days_between(Game.date, date)
	if n <= 0:
		return str(w.today)
	if n == 1:
		return str(w.tomorrow)
	return str(w.later).format({"day": _day_name(Calendar.weekday(date))})


static func _day_name(d: int) -> String:
	return str(Data.moments.day_names[d])


## The replies of "Ask me first": OK (Scratch) and two vetoes with a reason and the silent one.
func _replies(p: Dictionary) -> Array:
	var r: Dictionary = texts().replies
	var out := []
	var scratch: bool = p.kind == "scratch"
	var accept: Dictionary = r.accept_scratch if scratch else r.accept
	out.append({"id": "accept", "label": str(accept.label), "hint": str(accept.hint)})
	var prefix := str(r.race_prefix if scratch else r.veto_prefix)
	var reasons: Array = veto_reasons(str(p.kind))
	for i in mini(2, reasons.size()):
		out.append({"id": "veto_" + str(reasons[i].id), "label": prefix + str(reasons[i].label), "hint": str(r.veto_hint)})
	out.append({"id": "veto_none", "label": str(r.none_race if scratch else r.none_label), "hint": str(r.none_hint)})
	return out


## The reasons a veto of this kind of proposal can give ([{id, label}]); "none" (no reason) is always there too.
static func veto_reasons(kind: String) -> Array:
	var all: Dictionary = texts().veto_reasons
	return all.get(kind, all.lighter)


# --- Accept, apply, veto ------------------------------------------------------------------------------------------

## The answer to an "Ask me first" proposal (StoryletSystem routes the moment's reply here): {result (his reply), changes
## (lines for the result card)}.
func on_reply(proposal_id: String, reply_id: String) -> Dictionary:
	var p := proposal(proposal_id)
	if p.is_empty() or p.status != "asked":
		return {}
	var answered: Dictionary = texts().answered.get(Coaches.id_of(Game.athlete), texts().answered.calm)
	if reply_id == "accept":
		_apply(p)
		p.status = "accepted"
		return {"result": str(answered.accept), "changes": _lines(p, true)}
	if reply_id == NONE or not reply_id.begins_with("veto_"):
		p.status = "none"
		return {"changes": _lines(p, false)}
	p.status = "vetoed"
	p.veto = reply_id.trim_prefix("veto_")
	for x in p.days:
		x.vetoed = true
	var changes := _lines(p, false)
	if p.veto == "none":
		changes += _silent_veto()
		return {"result": str(answered.silent), "changes": changes}
	return {"result": str(answered.veto), "changes": changes}


## Puts the proposal into the week (by = "coach"); a scratch proposal withdraws the entry first (Game.scratch_race).
func _apply(p: Dictionary) -> void:
	if p.kind == "scratch" and p.meet != "":
		Game.scratch_race(str(p.meet))
	var w := Game.current_week()
	if Calendar.date_key(w.monday) != Calendar.date_key(p.monday):
		return
	for x in p.days:
		var d := int(x.d)
		if not w.can_change(d):
			continue
		if w.changed_by(d).values().has("player"):
			continue   # (you changed the day meanwhile: yours stays)
		w.set_sessions(d, x.to.sessions, "coach")
		w.set_intensity(d, str(x.to.intensity), "coach")
	var h := Game.get_system("health") as HealthSystem
	if h != null:
		h.refresh()   # (the injury limits go back on top of his change)


## Takes the coach's parts out of day `d` (the plan comes back; your own changes stay), then the injury limits go back on (a
## part an injury limit set on top of his change is dropped too: refresh recomputes it from what is left).
static func _drop_coach(w: WeekSim, d: int) -> void:
	var c: Dictionary = w.changes.get(d, {})
	for part in c.keys():
		if str(c[part].by) in ["coach", "injury"]:
			c.erase(part)
	if c.is_empty():
		w.changes.erase(d)
	var h := Game.get_system("health") as HealthSystem
	if h != null:
		h.refresh()


## The result card's lines: what changed, or what stays.
func _lines(p: Dictionary, accepted: bool) -> Array:
	var l: Dictionary = texts().lines
	var out := []
	if p.kind == "scratch":
		out.append(str(l.scratched if accepted else l.raced).format({"meet": p.meet_name}))
		return out
	for x in p.days:
		var day := _day_name(int(x.d))
		if accepted:
			out.append(str(l.changed).format({"day": day, "to": CoachVerdict.day_text(x.to.sessions, str(x.to.intensity))}))
		else:
			out.append(str(l.stays).format({"day": day}))
	return out


## A silent veto: from the (silent_free + 1)th within the window each costs a little trust. Returns the result-card line.
func _silent_veto() -> Array:
	var v: Dictionary = cfg().veto
	var today := StoryletSystem.day_no(Game.date)
	silent.append(today)
	silent = silent.filter(func(x): return today - int(x) < int(v.silent_window_days))
	if silent.size() <= int(v.silent_free):
		return []
	var cs := Game.get_system("coach") as CoachSystem
	if cs == null:
		return []
	cs.add_trust(-float(v.silent_cost), "veto")
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return []
	var who := str(cs.head().get("name", "")).split(" ")[0]
	return [ms._change_line(str(Data.moments.changes.trust).format({"who": who}), -float(v.silent_cost))]


## The proposal the coach put into day `date` (Always, or an accepted one) that still stands, or {}.
func applied_for(date: Dictionary) -> Dictionary:
	var key := Calendar.date_key(date)
	for i in range(list.size() - 1, -1, -1):
		var p: Dictionary = list[i]
		if not p.status in ["accepted", "applied"] or p.kind == "scratch":
			continue
		for x in p.days:
			if Calendar.date_key(x.date) == key and not bool(x.vetoed):
				return p
	return {}


## The scratch advice for a meet, or {}.
func advice_for(meet_key: String) -> Dictionary:
	for i in range(list.size() - 1, -1, -1):
		if list[i].kind == "scratch" and str(list[i].meet) == meet_key:
			return list[i]
	return {}


## The Veto of the day editor: day `date` goes back to the plan (Back to plan, with the injury limits put back). `reason` = a
## veto reason id or "none" (silent). Returns the result lines (what stays, a trust line for a costly silent veto).
func veto(date: Dictionary, reason: String) -> Array:
	var p := applied_for(date)
	var w := Game.current_week()
	var d := Calendar.weekday(date)
	if p.is_empty() or Calendar.date_key(w.monday) != Calendar.date_key(Calendar.monday_of(date)) or not w.can_change(d):
		return []
	_drop_coach(w, d)
	for x in p.days:
		if Calendar.date_key(x.date) == Calendar.date_key(date):
			x.vetoed = true
	if p.days.all(func(x): return bool(x.vetoed)):
		p.status = "vetoed"
	p.veto = reason
	var out := [str(texts().lines.stays).format({"day": _day_name(d)})]
	var ms := Game.get_system("moments") as StoryletSystem
	var answered: Dictionary = texts().answered.get(Coaches.id_of(Game.athlete), texts().answered.calm)
	var label := str(texts().replies.none_label)
	for r in veto_reasons(str(p.kind)):
		if str(r.id) == reason:
			label = str(texts().replies.veto_prefix) + str(r.label)
	if reason == "none":
		out += _silent_veto()
	if ms != null:
		ms.player_says(label)
		ms.coach_says(str(answered.silent if reason == "none" else answered.veto), true)
	return out


## "Never": the day he warned about was trained as it was (or the race he'd have scratched was raced) and the warning was
## real: trust - ignored_warning_cost, and he says so.
func _check_ignored(ctx: Dictionary) -> void:
	var rec: Dictionary = ctx.get("record", {})
	if rec.is_empty():
		return
	var key := Calendar.date_key(ctx.date)
	for p in list:
		if p.status != "noticed" or bool(p.checked) or not bool(p.warning):
			continue
		for x in p.days:
			if Calendar.date_key(x.date) != key:
				continue
			p.checked = true
			var as_it_was: bool
			if p.kind == "scratch":
				as_it_was = str(rec.race) == str(p.meet)
			else:
				as_it_was = rec.race == "" and rec.sessions == x.from.sessions and str(rec.intensity) == str(x.from.intensity)
			if not as_it_was:
				continue
			var cs := Game.get_system("coach") as CoachSystem
			if cs != null:
				cs.add_trust(-float(cfg().ignored_warning_cost), "ignored warning")
			var ms := Game.get_system("moments") as StoryletSystem
			if ms != null:
				ms.coach_says(str(texts().ignored).format({"day": _day_name(int(x.d)), "area": _area_now()}))


static func _area_now() -> String:
	return str(CoachVerdict._area_name(CoachVerdict.now_start()))


func proposal(proposal_id: String) -> Dictionary:
	for p in list:
		if p.id == proposal_id:
			return p
	return {}


# --- Save / load ------------------------------------------------------------------------------------------------

## Nothing to save while he never proposed anything and the setting is the default (older careers save as before).
func to_dict() -> Dictionary:
	if list.is_empty() and requests.is_empty() and silent.is_empty() and _next == 1:
		return {"mode": mode} if mode != "" else {}
	return {"mode": mode, "rng_seed": str(rng.seed), "rng_state": str(rng.state), "list": list, "requests": requests,
			"week": week, "last_day": last_day, "silent": silent, "next": _next}


## JSON makes every number a float: days, dates and counts back to ints.
func from_dict(d: Dictionary) -> void:
	mode = str(d.get("mode", ""))
	if not d.has("next"):
		return
	rng.seed = str(d.rng_seed).to_int()
	rng.state = str(d.rng_state).to_int()
	list = d.get("list", [])
	for p in list:
		p.day = int(p.day)
		p.date = Game.int_date(p.date)
		p.monday = Game.int_date(p.monday)
		for x in p.days:
			x.d = int(x.d)
			x.date = Game.int_date(x.date)
	requests = d.get("requests", [])
	for r in requests:
		r.day = int(r.day)
	week = d.get("week", {})
	for k in week:
		week[k] = int(week[k])
	last_day = int(d.get("last_day", -1))
	silent = d.get("silent", []).map(func(x): return int(x))
	_next = int(d.get("next", 1))
