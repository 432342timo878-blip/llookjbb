class_name StoryletSystem
extends GameSystem
## Moments and message threads (GDD 4.9.5 / 4.9.2; session C2, headless). GameSystem id "moments".
## The people around the athlete write in threads (coach, family, friends, group, school; data/moments.json `threads`). A
## moment is a storylet (data/storylets/*.json, format in data/storylets/README.md) that fits the day: its conditions
## hold, it is off cooldown, its sender is free. The player answers with one of its 2-4 replies; the reply's effects
## change trust (CoachSystem.add_trust), the sender's relationship, remembered flags and counters, and can queue a chain
## follow-up. A moment left unanswered passes as "you didn't answer" when it runs out of time (a real, small outcome).
## The scheduler keeps the rate (data/moments.json `rate`): a target of 3-5 moments a week, at most one a day, and with
## the setting "Play week stops for: Important only" (the default) only important moments stop Play week, each needing a
## stop token (one a week), so about one people stop a week; with "Every moment" every moment stops.
## Standing orders: the same reply to a recurring choice (storylets sharing a `standing` group) twice in a row offers a
## rule; with a rule the moment is answered by it and only the result line shows.
## Its own dice (seed and state saved), so a loaded game goes on exactly as without saving, and nothing here touches
## training, health or the global dice: with the moments on, the training balance is the same to the digit.
## The UI (session C3): the People tab shows the threads and lets the player answer (thread / unread / mark_read / pending /
## answer), the Today card shows the newest unread moment, the hub shows a stop moment as a message.
## Session C3 also adds two things the coach says that are NOT moments of the 3-5 a week (they sit outside the rate):
## the Sunday-evening WEEK TALK (always a stop: the talk with 0-2 topics, user 2026-10-11) and a MESSAGE on the evening
## after a race (not a stop). Both come from CoachTalk (data/coach_talk.json); the topics are storylets with a `topic` field
## (data/storylets/week_talk.json). A talk's first topic is part of its stop moment (its replies are the talk's replies, a talk
## without a topic has the single reply "Thanks, coach"), a second topic is a normal moment that waits in the thread.

## Off switch for the tools (like HealthSystem.model_enabled): no moments at all.
static var enabled := true
## The Sunday talk and the post-race message. OFF unless the app shell switches them on (main.gd): the talk always stops Play
## week, so every tool that plays weeks with `while advance_day() != WEEK_DONE` would never get past Sunday evening. The tools
## that test the talk (storylet_check, the UI checks) switch it on themselves.
static var talks_enabled := false
## Tools: use the test moments (storylet files with "test": true). A normal career uses them only when the Dev menu's
## Test moments switch is on for it (test_content, debug builds only).
static var include_test := false

const NONE := "_none"   # the answer of a moment that passed unanswered
const ACK := "talk_ack"  # the storylet of a week talk without a topic (data/storylets/week_talk.json)

var rng := RandomNumberGenerator.new()
var stop_setting := ""       # "important" / "all"; "" = the default of data/moments.json
var test_content := false    # this career uses the test moments (Dev menu, debug builds)
var started_day := -1        # day number of the first day the moments ran (-1 = not yet)
var seen := {}               # storylet id -> {count, first, last (day numbers), reply (last answer, "" = waiting), variant}
var flags := {}              # name -> {day (last set), count}
var counters := {}           # name -> int
var people := {}             # person id -> {id, thread, role, first_name, last_name, active, relation (0-100; the coach: trust)}
var threads := {}            # thread id -> [{id, date, day, from (person id / "you" / "system"), text, moment, read}]
var moments := []            # posted moments, oldest first: the unanswered ones and the last keep_moments_days days
var queue := []              # chain follow-ups: [{id (storylet), due, until (day numbers), after (moment id)}]
var week := {}               # {monday, target, count, stops, roll_day, go, evening, fired_day}
var stop_tokens := 0.0
var last_from := {}          # person id -> day number of their last moment
var standing := {}           # group -> {reply, label, rule, since}: the player's rules
var standing_history := {}   # group -> the last answers to that recurring choice, newest last
var standing_declined := {}  # group -> true: "Not now" was answered; again_after identical answers needed
## Not saved, for the tools: every moment posted since the system was made [{day, storylet, variant, stop, auto, from}] and
## the chain follow-ups dropped because their conditions never held.
var fired := []
var dropped_chains := 0

var _next := 1
var _by_id := {}
var _content_key := ""
var _content: Array = []


func _init() -> void:
	id = "moments"
	rng.randomize()


## The day number of a date (days since 1 Jan 1970): cooldowns, expiry and chains count in these.
static func day_no(d: Dictionary) -> int:
	return floori(Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12}) / 86400.0)


# --- Content and settings -----------------------------------------------------------------------------------

## The storylets this career can get: the real ones, and the test ones for the tools or with the Dev menu's switch.
func content() -> Array:
	var test := include_test or (test_content and OS.is_debug_build())
	var key := "%s|%d" % [test, Data.storylets.size()]
	if key != _content_key:
		_content_key = key
		_content = Data.storylets.filter(func(s): return test or not bool(s.get("test", false)))
		_by_id = {}
		for s in Data.storylets:
			_by_id[s.id] = s
	return _content


func storylet(storylet_id: String) -> Dictionary:
	content()
	return _by_id.get(storylet_id, {})


func active() -> bool:
	return enabled and not content().is_empty()


## "important" / "all" (data/moments.json settings.stops).
func stop_mode() -> String:
	return stop_setting if stop_setting != "" else str(Data.moments.settings.default)


func set_stop_mode(mode: String) -> void:
	if Data.moments.settings.stops.has(mode):
		stop_setting = mode


# --- The day loop -------------------------------------------------------------------------------------------------

## Morning: moments that ran out of time pass unanswered, the week's rate is set up, a morning moment may come.
func on_day_start(ctx: Dictionary) -> void:
	if not enabled:
		return
	var today := day_no(ctx.date)
	if content().is_empty():
		if started_day >= 0:
			_expire(today)   # (the test moments were switched off: those still waiting pass as before)
		return
	if started_day < 0:
		started_day = today
	_sync_people()
	_expire(today)
	_week_check(today, int(ctx.day))
	_slot("morning", ctx, today)


## Evening (after the day's training or race): an evening moment may come.
func on_day_end(ctx: Dictionary) -> void:
	if not active() or started_day < 0:
		return
	var today := day_no(ctx.date)
	_sync_people()
	_week_check(today, int(ctx.day))
	_slot("evening", ctx, today)
	if talks_enabled:
		if not ctx.get("race_note", {}).is_empty():
			_post_race_note(ctx, today)
		if int(ctx.day) == 6 and ctx.get("week") != null:
			_post_week_talk(ctx, today)
	_prune(today)


## A stop moment answered in the event panel. A choice that is not one of its replies (tools answer "ok") = no answer.
func on_answer(event: Dictionary, choice: String) -> void:
	var m := moment(str(event.get("moment", "")))
	if m.is_empty() or m.answer != "":
		return
	var ids: Array = m.replies.map(func(r): return r.id)
	_resolve(m, choice if choice in ids else NONE)


# --- The scheduler ------------------------------------------------------------------------------------------------

## A new week (Monday, or the first day the moments run in it): the week's target and a stop token.
func _week_check(today: int, weekday: int) -> void:
	var monday := today - weekday
	if int(week.get("monday", -1)) == monday:
		return
	var r: Dictionary = Data.moments.rate
	var target := rng.randi_range(int(r.per_week[0]), int(r.per_week[1]))
	if weekday > 0:   # (the moments start mid-week: that week gets its share)
		target = roundi(target * (7 - weekday) / 7.0)
	week = {"monday": monday, "target": target, "count": 0, "stops": 0, "roll_day": -1, "go": false, "evening": false,
			"fired_day": -1}
	stop_tokens = minf(stop_tokens + float(r.stops_per_week), float(r.stop_tokens_max))


func _slot(slot: String, ctx: Dictionary, today: int) -> void:
	var r: Dictionary = Data.moments.rate
	if today < started_day + int(r.start_after_days):
		return
	if _fire_due_chain(slot, ctx, today):
		return
	if int(week.fired_day) == today or int(week.count) >= int(r.max_per_week):
		return
	if int(week.roll_day) != today:   # once a day: does today get a moment? (moments still to come / days left)
		week.roll_day = today
		var remaining := int(week.target) - int(week.count)
		var days_left := 7 - int(ctx.day)
		week.go = remaining > 0 and rng.randf() < float(remaining) / days_left
		week.evening = false
	if not week.go:
		return
	for _try in 4:   # (a moment answered by a standing rule leaves the slot free: pick again)
		var pick := _pick(ctx, today, ["morning", "any", "evening"] if slot == "morning" else ["evening", "any"])
		if pick.is_empty():
			return
		if slot == "morning" and _slot_of(pick.s) == "evening":
			week.evening = true   # (the evening picks again, from what fits then)
			return
		if not _post(pick.s, pick.from, ctx, today).auto:
			return


static func _slot_of(s: Dictionary) -> String:
	return str(s.get("slot", "evening"))


## A weighted pick among the storylets that fit now: {s, from (person)} or {}.
func _pick(ctx: Dictionary, today: int, slots: Array) -> Dictionary:
	var cands := []
	var total := 0.0
	for s in content():
		if bool(s.get("chain_only", false)) or str(s.get("topic", "")) != "" or not _slot_of(s) in slots:
			continue
		if not _stop_allowed(s):
			continue
		if not _eligible(s, ctx, today):
			continue
		var senders := _senders(s, ctx, today)
		if senders.is_empty():
			continue
		var w := float(s.get("weight", 1.0))
		cands.append({"s": s, "senders": senders, "w": w})
		total += w
	if cands.is_empty():
		return {}
	var x := rng.randf() * total
	var chosen: Dictionary = cands.back()
	for c in cands:
		x -= c.w
		if x < 0.0:
			chosen = c
			break
	var senders: Array = chosen.senders
	return {"s": chosen.s, "from": senders[rng.randi_range(0, senders.size() - 1)]}


## With "Important only" an important moment needs a stop token, and none comes while another stop event waits.
func _stop_allowed(s: Dictionary) -> bool:
	if not bool(s.get("important", false)) or stop_mode() != "important":
		return true
	return stop_tokens >= 1.0 and Game.pending_event().is_empty()


## Conditions that don't depend on who writes: once, cooldown, not already waiting, `when`, enough replies and a text.
func _eligible(s: Dictionary, ctx: Dictionary, today: int) -> bool:
	var sn: Dictionary = seen.get(s.id, {})
	if not sn.is_empty():
		if bool(s.get("once", false)):
			return false
		if today - int(sn.last) < int(s.get("cooldown_days", 14)):
			return false
		if str(sn.reply) == "":
			return false   # (its last moment still waits for an answer)
	if not check_when(s.get("when", {}), ctx, {}):
		return false
	return true


## Who can write it: the people its `from` names who are free (person gap) and meet the `relation` condition.
func _senders(s: Dictionary, ctx: Dictionary, today: int) -> Array:
	var gap := int(Data.moments.rate.person_gap_days)
	var out := []
	for p in people_for(str(s.get("from", "coach"))):
		if last_from.has(p.id) and today - int(last_from[p.id]) < gap:
			continue
		var when: Dictionary = s.get("when", {})
		if when.has("relation") and not _in_range(relation_of(p), when.relation):
			continue
		if _valid_replies(s, ctx, p).size() < 2 or _valid_variants(s, ctx, p).is_empty():
			continue
		out.append(p)
	return out


## The people a `from` selector names: "coach", "teammate", "teammate:<role>" (family, friends, school: P1).
func people_for(selector: String) -> Array:
	var parts := selector.split(":")
	var out := []
	for p in people.values():
		if not bool(p.active):
			continue
		match parts[0]:
			"coach":
				if p.role == "coach":
					out.append(p)
			"teammate":
				if p.thread == "group" and (parts.size() < 2 or p.role == parts[1]):
					out.append(p)
	out.sort_custom(func(x, y): return str(x.id) < str(y.id))   # (dictionary order is not guaranteed after loading)
	return out


## The chain follow-ups due today, oldest first. True when one was posted. One whose conditions never held within
## chain_wait_days is dropped; an important one with no stop token waits, and on its last day comes without stopping.
func _fire_due_chain(slot: String, ctx: Dictionary, today: int) -> bool:
	var r: Dictionary = Data.moments.rate
	for q in queue.duplicate():
		if int(q.due) > today:
			continue
		var s := storylet(str(q.id))
		if s.is_empty() or today > int(q.until):
			queue.erase(q)
			dropped_chains += 1
			continue
		var sl := _slot_of(s)
		if sl != "any" and sl != slot:
			continue
		if int(week.fired_day) == today or int(week.count) >= int(r.max_per_week):
			return false
		if not _eligible(s, ctx, today):
			continue
		var senders := _senders(s, ctx, today)
		if senders.is_empty():
			continue
		var nonstop := false
		if not _stop_allowed(s):
			if today < int(q.until):
				continue
			nonstop = true
		queue.erase(q)
		_post(s, senders[rng.randi_range(0, senders.size() - 1)], ctx, today, nonstop)
		return true
	return false


# --- Posting and answering ----------------------------------------------------------------------------------

## Posts storylet `s` from person `p`: a message in the thread and a moment waiting for an answer (a stop event when
## the setting says so). With a standing order for its group it is answered by the rule at once.
## `opts` (session C3): prefix (a text that goes before the storylet's own: the week talk), talk (this is the week talk:
## a stop whatever the setting, titled "Week talk"), counted (false = outside the week's rate and stop count: talks and
## topics).
func _post(s: Dictionary, p: Dictionary, ctx: Dictionary, today: int, nonstop := false, opts := {}) -> Dictionary:
	var variants := _valid_variants(s, ctx, p)
	var last_variant := int(seen.get(s.id, {}).get("variant", -1))
	if variants.size() > 1:
		variants.erase(last_variant)   # never the same text twice in a row
	var vi: int = variants[rng.randi_range(0, variants.size() - 1)]
	var fill := _fill(ctx, p)
	var replies := []
	for rep in _valid_replies(s, ctx, p):
		replies.append({"id": str(rep.id), "label": str(rep.label).format(fill), "hint": str(rep.get("hint", "")).format(fill)})
	var body := _variant_text(s.text[vi]).format(fill)
	var prefix := str(opts.get("prefix", ""))
	var text := body if prefix == "" else (prefix if body == "" else prefix + "\n\n" + body)
	var talk := bool(opts.get("talk", false))
	var counted := bool(opts.get("counted", true))
	var m := {"id": "m%d" % _next, "kind": "moment", "storylet": str(s.id), "date": ctx.date.duplicate(), "day": today,
			"thread": str(s.thread), "from": str(p.id), "text": text, "variant": vi,
			"replies": replies, "fill": fill, "expires": today + int(s.get("expires_days", Data.moments.expires_days)),
			"stop": false, "event": "", "answer": "", "answered_day": -1, "auto": false, "talk": talk}
	_next += 1
	var sn: Dictionary = seen.get(s.id, {"count": 0, "first": today})
	sn.count = int(sn.count) + 1
	sn.last = today
	sn.variant = vi
	sn.reply = ""
	seen[s.id] = sn
	last_from[p.id] = today
	moments.append(m)
	_message(m.thread, p.id, m.text, m.id, ctx.date)
	var group := str(s.get("standing", ""))
	if group != "" and standing.has(group) and replies.any(func(rep): return rep.id == standing[group].reply):
		# Answered by the player's rule: only the result line shows; it uses neither the day's slot nor the week's rate.
		m.auto = true
		fired.append({"day": today, "storylet": s.id, "variant": vi, "stop": false, "auto": true, "from": p.id})
		_resolve(m, str(standing[group].reply))
		return m
	if counted:
		week.fired_day = today
		week.count = int(week.count) + 1
	var important := bool(s.get("important", false)) and not nonstop
	if talk or stop_mode() == "all" or important:
		if not talk and stop_mode() == "important":
			stop_tokens -= 1.0
		if counted:
			week.stops = int(week.stops) + 1
		_post_event(m, p)
	fired.append({"day": today, "storylet": s.id, "variant": vi, "stop": m.stop, "auto": false, "from": p.id, "talk": talk})
	return m


func _post_event(m: Dictionary, p: Dictionary) -> void:
	var choices := []
	for rep in m.replies:
		choices.append({"id": rep.id, "label": rep.label, "detail": rep.hint})
	var title := thread_name(m.thread)   # (a rule offer has no sender)
	if not p.is_empty():
		var pattern := str(Data.coach_talk.talk.title) if bool(m.get("talk", false)) else str(Data.moments.event_title)
		title = pattern.format({"from": person_name(p), "thread": title})
	var e := Game.post_event(id, title, m.text, choices, true)
	e.kind = "moment"
	e.moment = m.id
	m.stop = true
	m.event = e.id


## The player's answer from a thread (the UI, C3) or the tools: a stop moment goes through its event.
func answer(moment_id: String, reply_id: String) -> void:
	var m := moment(moment_id)
	if m.is_empty() or m.answer != "":
		return
	if m.event != "":
		for e in Game.events:
			if e.id == m.event and e.answer == "":
				Game.answer_event(e.id, reply_id)
				return
	var ids: Array = m.replies.map(func(r): return r.id)
	_resolve(m, reply_id if reply_id in ids else NONE)


func _resolve(m: Dictionary, reply_id: String) -> void:
	var today := day_no(Game.date)
	m.answer = reply_id
	m.answered_day = today
	if reply_id != NONE:   # (the player read it, in the stop panel or in the thread: nothing "new" about it any more)
		for x in threads.get(str(m.thread), []):
			if str(x.moment) == str(m.id):
				x.read = true
	if m.event != "":   # (answered in the thread: the event panel needn't ask any more)
		for e in Game.events:
			if e.id == m.event and e.answer == "":
				e.answer = reply_id
	if m.kind == "rule":
		_resolve_rule(m, reply_id, today)
		return
	var s := storylet(str(m.storylet))
	var p: Dictionary = people.get(m.from, {})
	var fill: Dictionary = m.fill
	var cause := "moment:" + str(m.storylet)
	var next = null
	m.changes = []
	if reply_id == NONE:
		var na: Dictionary = s.get("no_answer", Data.moments.no_answer)
		_apply(na.get("effects", {}), p, cause)
		m.changes = _changes_of(na.get("effects", {}), p, false)
		_message(m.thread, "system", str(na.get("result", Data.moments.no_answer.result)).format(fill), m.id, Game.date)
		next = na.get("next", null)
	else:
		var rep := _reply(s, reply_id)
		var label := ""
		for r in m.replies:
			if r.id == reply_id:
				label = r.label
		if m.auto:
			_message(m.thread, "system", str(Data.moments.standing.applied).format({"label": label}), m.id, Game.date)
		else:
			_message(m.thread, "you", label, m.id, Game.date)
		_apply(rep.get("effects", {}), p, cause)
		m.changes = _changes_of(rep.get("effects", {}), p, bool(rep.get("remember", false)))
		var result := str(rep.get("result", "")).format(fill)
		if result != "":
			# (a reply with "result_from": "sender" is the sender's own answer, a bubble from them; else a line of the game)
			var speaker := str(p.id) if str(rep.get("result_from", "")) == "sender" and not p.is_empty() else "system"
			_message(m.thread, speaker, result, m.id, Game.date)
			threads[m.thread].back().read = true   # (it answers the player's own reply: nothing "new" about it)
		next = rep.get("next", null)
	if seen.has(m.storylet):
		seen[m.storylet].reply = reply_id
	if next is Dictionary:
		_queue_next(next, m.id, today)
	var group := str(s.get("standing", ""))
	if group != "" and not m.auto:
		_note_standing(group, s, reply_id, m, today)


func _reply(s: Dictionary, reply_id: String) -> Dictionary:
	for r in s.get("replies", []):
		if str(r.id) == reply_id:
			return r
	return {}


func _queue_next(next: Dictionary, after: String, today: int) -> void:
	var days = next.get("days", 1)
	var d := rng.randi_range(int(days[0]), int(days[1])) if days is Array else int(days)
	queue.append({"id": str(next.id), "due": today + d, "until": today + d + int(Data.moments.chain_wait_days), "after": after})


## Effects of a reply (data/moments.json effects): trust, the sender's relationship, flags, counters. The prepared ones
## (moods, sleep, school, budget, coach proposals) change nothing until their systems exist.
func _apply(effects: Dictionary, p: Dictionary, cause: String) -> void:
	var today := day_no(Game.date)
	for key in effects:
		var v = effects[key]
		match key:
			"trust":
				_add_trust(float(v), cause)
			"relation":
				if p.get("role", "") == "coach":
					_add_trust(float(v), cause)
				elif not p.is_empty():
					var rel: Dictionary = Data.moments.relation
					p.relation = clampf(float(p.relation) + float(v), float(rel.min), float(rel.max))
			"flag":
				for name in (v if v is Array else [v]):
					var f: Dictionary = flags.get(name, {"count": 0})
					f.day = today
					f.count = int(f.count) + 1
					flags[name] = f
			"unflag":
				for name in (v if v is Array else [v]):
					flags.erase(name)
			"count":
				for name in v:
					counters[name] = int(counters.get(name, 0)) + int(v[name])
			_:
				if not key in Data.moments.effects.prepared:
					push_warning("Moment effect '%s' is unknown (%s)" % [key, cause])


## What an answer changed, in words for the result card (data/moments.json `changes`): ["Trust in Heikki ▲ a little", ...].
## Only what really changes: the coach's trust (his `trust` and `relation` effects), another person's relationship, and a
## "remember" note when the reply says so. Prepared effects (moods, sleep, grades, budget) are listed once they exist.
func _changes_of(effects: Dictionary, p: Dictionary, remember: bool) -> Array:
	var cfg: Dictionary = Data.moments.changes
	var out := []
	if p.is_empty():
		return out
	var who := str(p.first_name)
	var trust := float(effects.get("trust", 0.0))
	var rel := 0.0
	if p.get("role", "") == "coach":
		trust += float(effects.get("relation", 0.0))
	else:
		rel = float(effects.get("relation", 0.0))
	if trust != 0.0:
		out.append(_change_line(str(cfg.trust).format({"who": who}), trust))
	if rel != 0.0:
		out.append(_change_line(str(cfg.relation).format({"who": who}), rel))
	if remember:
		out.append(str(cfg.remember).format({"who": who}))
	return out


func _change_line(label: String, delta: float) -> String:
	var cfg: Dictionary = Data.moments.changes
	var limits: Array = cfg.size_limits
	var size := 0 if absf(delta) <= float(limits[0]) else (1 if absf(delta) <= float(limits[1]) else 2)
	return "%s %s %s" % [label, cfg.up if delta > 0.0 else cfg.down, cfg.sizes[size]]


func _add_trust(delta: float, cause: String) -> void:
	var cs := Game.get_system("coach") as CoachSystem
	if cs:
		cs.add_trust(delta, cause)


## A moment nobody answered in time passes as "you didn't answer" (a stop moment can't: Play week waits for it).
func _expire(today: int) -> void:
	for m in moments.duplicate():
		if m.answer == "" and not m.stop and today > int(m.expires):
			_resolve(m, NONE)


func _prune(today: int) -> void:
	var keep := int(Data.moments.keep_moments_days)
	moments = moments.filter(func(m): return m.answer == "" or today - int(m.answered_day) <= keep)
	var most := int(Data.moments.keep_messages)
	for t in threads:
		var list: Array = threads[t]
		if list.size() > most:
			threads[t] = list.slice(list.size() - most)


# --- The Sunday talk and the message after a race (session C3) -------------------------------------------------

## Sunday evening: the coach's week talk. A stop whatever the setting (user 2026-10-11: it always stops Play week). The text is
## CoachTalk.week_talk; its first topic (0-2 topics are drawn, data/coach_talk.json talk.topics_chance) is part of the same
## moment, a second topic is a normal moment that waits in the thread. Outside the 3-5 moments a week.
func _post_week_talk(ctx: Dictionary, today: int) -> void:
	var coach := people_for("coach")
	if coach.is_empty():
		return
	var p: Dictionary = coach[0]
	var chances: Array = Data.coach_talk.talk.topics_chance
	var x := rng.randf()
	var n := 0
	for c in chances:
		x -= float(c)
		if x < 0.0:
			break
		n += 1
	var topics := _pick_topics("week", ctx, today, p, mini(n, 2))
	var s: Dictionary = topics[0] if not topics.is_empty() else storylet(ACK)
	if s.is_empty():
		return
	var text := CoachTalk.week_talk(ctx, _fill(ctx, p), rng)
	_post(s, p, ctx, today, false, {"prefix": text, "talk": true, "counted": false})
	if topics.size() > 1:
		_post(topics[1], p, ctx, today, true, {"counted": false})


## The evening after a race: a message from the coach (not a stop): the result, his Race-story line, a closing word; with a
## chance one follow-up topic that fits how it went (a normal moment, answered in the thread).
func _post_race_note(ctx: Dictionary, today: int) -> void:
	var coach := people_for("coach")
	if coach.is_empty():
		return
	var p: Dictionary = coach[0]
	var note: Dictionary = ctx.race_note
	if CoachTalk.race_outcome(note) == "":
		return
	_message("coach", p.id, CoachTalk.race_message(note, _fill(ctx, p), rng), "", ctx.date)
	if rng.randf() < float(Data.coach_talk.talk.race_topic_chance):
		var topics := _pick_topics("race", ctx, today, p, 1)
		if not topics.is_empty():
			_post(topics[0], p, ctx, today, true, {"counted": false})


## Up to `n` topic storylets (field `topic` = kind) that fit now, drawn by weight.
func _pick_topics(kind: String, ctx: Dictionary, today: int, p: Dictionary, n: int) -> Array:
	var pool := []
	for s in content():
		if str(s.get("topic", "")) != kind or not _eligible(s, ctx, today):
			continue
		if _valid_replies(s, ctx, p).size() < 2 or _valid_variants(s, ctx, p).is_empty():
			continue
		pool.append(s)
	var out := []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for s in pool:
			total += float(s.get("weight", 1.0))
		var x := rng.randf() * total
		var chosen: Dictionary = pool.back()
		for s in pool:
			x -= float(s.get("weight", 1.0))
			if x < 0.0:
				chosen = s
				break
		out.append(chosen)
		pool.erase(chosen)
	return out


# --- Standing orders ----------------------------------------------------------------------------------------------

## The same reply `repeat` times in a row (after "Not now": again_after more) offers a rule, when the reply has one.
func _note_standing(group: String, s: Dictionary, reply_id: String, m: Dictionary, today: int) -> void:
	var cfg: Dictionary = Data.moments.standing
	var hist: Array = standing_history.get(group, [])
	hist.append(reply_id)
	while hist.size() > 6:
		hist.pop_front()
	standing_history[group] = hist
	if standing.has(group) or reply_id == NONE:
		return
	var rule := str(_reply(s, reply_id).get("rule", ""))
	if rule == "":
		return
	var streak := 0
	for i in range(hist.size() - 1, -1, -1):
		if hist[i] != reply_id:
			break
		streak += 1
	var need := int(cfg.again_after) if standing_declined.has(group) else int(cfg.repeat)
	if streak < need:
		return
	for other in moments:
		if other.kind == "rule" and other.group == group and other.answer == "":
			return   # (an offer already waits)
	var label := ""
	for r in m.replies:
		if r.id == reply_id:
			label = r.label
	var text := str(cfg.offer_text).format({"reply": label, "times": streak, "rule": rule})
	var offer := {"id": "m%d" % _next, "kind": "rule", "storylet": str(s.id), "group": group, "reply": reply_id,
			"label": label, "rule": rule, "date": Game.date.duplicate(), "day": today, "thread": m.thread, "from": "system",
			"text": text, "variant": 0, "fill": m.fill, "expires": today + int(Data.moments.expires_days),
			"replies": [{"id": "yes", "label": str(cfg.yes), "hint": str(cfg.yes_hint)},
					{"id": "no", "label": str(cfg.no), "hint": str(cfg.no_hint)}],
			"stop": false, "event": "", "answer": "", "answered_day": -1, "auto": false}
	_next += 1
	moments.append(offer)
	_message(m.thread, "system", text, offer.id, Game.date)
	if stop_mode() == "all":
		_post_event(offer, {})


func _resolve_rule(m: Dictionary, reply_id: String, today: int) -> void:
	var cfg: Dictionary = Data.moments.standing
	var group := str(m.group)
	match reply_id:
		"yes":
			standing[group] = {"reply": m.reply, "label": m.label, "rule": m.rule, "since": today}
			standing_declined.erase(group)
			_message(m.thread, "you", str(cfg.yes), m.id, Game.date)
			_message(m.thread, "system", str(cfg.made).format({"rule": m.rule}), m.id, Game.date)
		"no":
			standing_declined[group] = true
			standing_history[group] = []
			_message(m.thread, "you", str(cfg.no), m.id, Game.date)
		# (not answered: offered again after the next identical answer)


## The player's rules: [{group, reply, label, rule, since}].
func standing_orders() -> Array:
	var out := []
	for g in standing:
		var o: Dictionary = standing[g].duplicate()
		o.group = g
		out.append(o)
	return out


func clear_rule(group: String) -> void:
	standing.erase(group)
	standing_history[group] = []


# --- Conditions ------------------------------------------------------------------------------------------------------

## True when every condition of `when` holds today (README in data/storylets). `p` = the sender, or {} when it doesn't
## matter (the `relation` condition is then checked per sender).
func check_when(when: Dictionary, ctx: Dictionary, p: Dictionary) -> bool:
	if when.is_empty():
		return true
	var a := Game.athlete
	var date: Dictionary = ctx.date
	for key in when:
		var v = when[key]
		var ok := true
		match key:
			"age": ok = _in_range(a.age_on(date), v)
			"month": ok = int(date.month) in v.map(func(x): return int(x))
			"weekday": ok = int(ctx.day) in v.map(func(x): return int(x))
			"day_type": ok = str(ctx.day_type) == str(v)
			"weeks_in_career": ok = _in_range(floori(Calendar.days_between(Game.START_DATE, date) / 7.0), v)
			"phase": ok = str(_phase(date)) in v
			"race_today": ok = _race_on(date) == bool(v)
			"race_tomorrow": ok = _race_on(Game.add_days(date, 1)) == bool(v)
			"race_in_days": ok = _in_range(_next_race_days(date), v)
			"raced_days_ago": ok = _in_range(_days_since_result(date, false), v)
			"pb_days_ago": ok = _in_range(_days_since_result(date, true), v)
			"injured": ok = _health_tier(false) == bool(v)
			"ill": ok = _health_tier(true) == bool(v)
			"sore": ok = _sore() == bool(v)
			"today_tags": ok = _has_tag(_sessions_on(ctx, 0), v)
			"tomorrow_tags": ok = _has_tag(_sessions_on(ctx, 1), v)
			"tomorrow_rest": ok = (_sessions_on(ctx, 1).is_empty() and not _race_on(Game.add_days(date, 1))) == bool(v)
			"flags":
				for f in v:
					var name := str(f)
					ok = ok and (not flags.has(name.substr(1)) if name.begins_with("!") else flags.has(name))
			"flag_days":
				for name in v:
					ok = ok and flags.has(name) and _in_range(day_no(date) - int(flags[name].day), v[name])
			"counters":
				for name in v:
					ok = ok and _in_range(int(counters.get(name, 0)), v[name])
			"seen":
				for sid in v:
					ok = ok and seen.has(sid)
			"not_seen":
				for sid in v:
					ok = ok and not seen.has(sid)
			"answered":
				for sid in v:
					var want: Array = v[sid] if v[sid] is Array else [v[sid]]
					ok = ok and seen.has(sid) and str(seen[sid].reply) in want
			"trust":
				var cs := Game.get_system("coach") as CoachSystem
				ok = cs != null and cs.trust_level() in v
			"relation":
				ok = p.is_empty() or _in_range(relation_of(p), v)
			"fatigue": ok = _in_range(Game.athlete.fatigue, v)
			"race_outcome": ok = CoachTalk.race_outcome(ctx.get("race_note", {})) in v
			"chance":
				ok = rng.randf() < float(v)
			_:
				push_warning("Unknown moment condition '%s'" % key)
				ok = false
		if not ok:
			return false
	return true


## [min, max] with null = open.
static func _in_range(x: float, r) -> bool:
	if not r is Array or r.size() < 2:
		return false
	return (r[0] == null or x >= float(r[0])) and (r[1] == null or x <= float(r[1]))


func _phase(date: Dictionary) -> String:
	if Game.season.mode != SeasonPlan.PHASES:
		return ""
	return str(Game.season.week_for(Calendar.monday_of(date)).get("phase", ""))


func _race_on(date: Dictionary) -> bool:
	return Calendar.races_in_week(Game.entries, Calendar.monday_of(date)).has(Calendar.weekday(date))


## Days to the next entered race from `date` (0 = that day); a big number when there is none.
func _next_race_days(date: Dictionary) -> int:
	var m := Game.next_race()
	return 100000 if m.is_empty() else Calendar.days_between(date, m.date)


## Days since the last race run (or the last PB); a big number when there is none.
func _days_since_result(date: Dictionary, pb_only: bool) -> int:
	for i in range(Game.athlete.results.size() - 1, -1, -1):
		var r: Dictionary = Game.athlete.results[i]
		if not pb_only or bool(r.get("pb", false)):
			return Calendar.days_between(Game.int_date(r.date), date)
	return 100000


## An active injury (illness = false) or an illness (true).
func _health_tier(illness: bool) -> bool:
	var h := Game.get_system("health") as HealthSystem
	if h == null or not HealthSystem.model_enabled:
		return false
	for inj in h.injuries:
		if (str(inj.tier) == "illness") == illness:
			return true
	return false


func _sore() -> bool:
	var h := Game.get_system("health") as HealthSystem
	if h == null or not HealthSystem.model_enabled:
		return false
	return h.levels.values().any(func(l): return int(l) >= 1)


## The session ids of today (offset 0) or tomorrow (1): this week's day with its changes, or next week's plan.
func _sessions_on(ctx: Dictionary, offset: int) -> Array:
	var d := int(ctx.day) + offset
	var w: WeekSim = ctx.get("week")
	if w != null and d < 7:
		return w.session_ids(d)
	var monday := Calendar.monday_of(Game.add_days(ctx.date, offset))
	return Game.season.week_for(monday).days[d % 7]


static func _has_tag(ids: Array, tags: Array) -> bool:
	for sid in ids:
		for t in Data.get_session(sid).get("tags", []):
			if t in tags:
				return true
	return false


func _valid_replies(s: Dictionary, ctx: Dictionary, p: Dictionary) -> Array:
	return s.get("replies", []).filter(func(r): return check_when(r.get("when", {}), ctx, p))


## Indices of the text variants whose own conditions hold.
func _valid_variants(s: Dictionary, ctx: Dictionary, p: Dictionary) -> Array:
	var out := []
	var texts: Array = s.get("text", [])
	for i in texts.size():
		if not texts[i] is Dictionary or check_when(texts[i].get("when", {}), ctx, p):
			out.append(i)
	return out


static func _variant_text(v) -> String:
	return str(v.text) if v is Dictionary else str(v)


## The placeholders of a moment's texts.
func _fill(ctx: Dictionary, p: Dictionary) -> Dictionary:
	var a := Game.athlete
	var names: Array = Data.moments.day_names
	var coach: Array = people_for("coach")
	var mates := people_for("teammate").filter(func(t): return t.id != p.get("id", ""))
	var next := Game.next_race()
	var pb := float(a.personal_bests.get(a.main_event, 0.0))
	return {
		"name": a.first_name, "full_name": a.full_name(), "from": str(p.get("first_name", "")),
		"coach": person_name(coach[0]) if not coach.is_empty() else "",
		"coach_first": str(coach[0].first_name) if not coach.is_empty() else "",
		"teammate": str(mates[rng.randi_range(0, mates.size() - 1)].first_name) if not mates.is_empty() else "",
		"club": str(Data.get_club(a.club_id).get("name", "")),
		"meet": str(next.get("name", "")), "race_days": str(_next_race_days(ctx.date)) if not next.is_empty() else "",
		"pb": Calendar.format_time(pb) if pb > 0.0 else "",
		"weekday": str(names[int(ctx.day)]), "tomorrow": str(names[(int(ctx.day) + 1) % 7]),
	}


# --- People and threads ----------------------------------------------------------------------------------------

## Keeps the people in step with the career: the head coach (C1's record) and his training group. Family, friends and
## school people come with P1 (their threads are there, empty). People who are no longer around stay, inactive, so old
## messages keep their names.
func _sync_people() -> void:
	var cs := Game.get_system("coach") as CoachSystem
	var head: Dictionary = cs.head() if cs else {}
	for p in people.values():
		p.active = false
	if head.is_empty():
		return
	var parts := str(head.name).split(" ", false, 1)
	_person(str(head.id), "coach", "coach", parts[0], parts[1] if parts.size() > 1 else "")
	for t in head.get("group", []):
		_person("%s.%s" % [head.id, t.id], "group", str(t.role), str(t.first_name), str(t.last_name))


func _person(pid: String, thread: String, role: String, first: String, last: String) -> void:
	if not people.has(pid):
		people[pid] = {"id": pid, "thread": thread, "role": role, "first_name": first, "last_name": last,
				"relation": float(Data.moments.relation.start)}
	people[pid].active = true


## 0-100; the head coach's is his trust.
func relation_of(p: Dictionary) -> float:
	if p.get("role", "") == "coach":
		var cs := Game.get_system("coach") as CoachSystem
		return cs.trust() if cs else float(Data.moments.relation.start)
	return float(p.get("relation", Data.moments.relation.start))


static func person_name(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	return ("%s %s" % [p.first_name, p.last_name]).strip_edges()


static func thread_name(thread: String) -> String:
	return str(Data.moments.threads.get(thread, {}).get("name", thread))


func _message(thread: String, from: String, text: String, moment_id: String, date: Dictionary) -> void:
	if not threads.has(thread):
		threads[thread] = []
	threads[thread].append({"id": "x%d" % _next, "date": date.duplicate(), "day": day_no(date), "from": from, "text": text,
			"moment": moment_id, "read": from == "you" or from == "system"})   # (the player's own lines and the game's lines are never "new")
	_next += 1


## A thread's messages, oldest first (for the People tab, C3).
func thread(thread_id: String) -> Array:
	return threads.get(thread_id, [])


func unread(thread_id: String) -> int:
	return thread(thread_id).filter(func(x): return not bool(x.read)).size()


func mark_read(thread_id: String) -> void:
	for x in thread(thread_id):
		x.read = true


func moment(moment_id: String) -> Dictionary:
	for m in moments:
		if m.id == moment_id:
			return m
	return {}


# For the People tab, the Today card and the week strip (session C3) ----------------------------------------

## The thread ids in the order of data/moments.json (coach, family, friends, group, school).
static func thread_ids() -> Array:
	return Data.moments.threads.keys()


## Unread messages in all threads.
func unread_total() -> int:
	var n := 0
	for t in threads:
		n += unread(t)
	return n


## The last message of a thread, or {}.
func last_message(thread_id: String) -> Dictionary:
	var list := thread(thread_id)
	return list.back() if not list.is_empty() else {}


## What the Today card shows: the newest moment still waiting for an answer, else the newest unread message of a person.
## {kind "moment" | "message", thread, from (person id), text, date, moment (id or "")} or {}.
func newest_open() -> Dictionary:
	var open := pending()
	if not open.is_empty():
		var m: Dictionary = open.back()
		return {"kind": "moment", "thread": m.thread, "from": m.from, "text": m.text, "date": m.date, "moment": m.id}
	var best := {}
	for t in threads:
		for x in threads[t]:
			if bool(x.read) or x.from == "you" or x.from == "system":
				continue
			if best.is_empty() or int(x.day) >= int(best.day):
				best = {"kind": "message", "thread": t, "from": x.from, "text": x.text, "date": x.date, "moment": x.moment, "day": int(x.day)}
	return best


## Per day number: {count (messages from people that day), unread} for the days first..last (the week strip's people mark).
func marks_between(first_day: int, last_day: int) -> Dictionary:
	var out := {}
	for t in threads:
		for x in threads[t]:
			if x.from == "you" or x.from == "system" or int(x.day) < first_day or int(x.day) > last_day:
				continue
			var d: Dictionary = out.get(int(x.day), {"count": 0, "unread": 0})
			d.count += 1
			if not bool(x.read):
				d.unread += 1
			out[int(x.day)] = d
	return out


## Moments still waiting for an answer, oldest first.
func pending() -> Array:
	return moments.filter(func(m): return m.answer == "")


# --- Save / load ---------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if started_day < 0:
		var d := {}
		if test_content:
			d.test_content = true
		if stop_setting != "":
			d.stop_setting = stop_setting
		return d
	return {"rng_seed": str(rng.seed), "rng_state": str(rng.state), "stop_setting": stop_setting,
			"test_content": test_content, "started_day": started_day, "seen": seen, "flags": flags, "counters": counters,
			"people": people, "threads": threads, "moments": moments, "queue": queue, "week": week,
			"stop_tokens": stop_tokens, "last_from": last_from, "standing": standing, "standing_history": standing_history,
			"standing_declined": standing_declined.keys(), "next": _next}


## JSON makes every number a float: counts, days and dates back to ints.
func from_dict(d: Dictionary) -> void:
	stop_setting = str(d.get("stop_setting", ""))
	test_content = bool(d.get("test_content", false))
	if not d.has("started_day"):
		return
	rng.seed = str(d.rng_seed).to_int()
	rng.state = str(d.rng_state).to_int()
	started_day = int(d.started_day)
	seen = d.get("seen", {})
	for sn in seen.values():
		for k in ["count", "first", "last", "variant"]:
			sn[k] = int(sn[k])
	flags = d.get("flags", {})
	for f in flags.values():
		f.day = int(f.day)
		f.count = int(f.count)
	counters = d.get("counters", {})
	for k in counters:
		counters[k] = int(counters[k])
	people = d.get("people", {})
	for p in people.values():
		p.relation = float(p.relation)
	threads = d.get("threads", {})
	for t in threads.values():
		for x in t:
			x.date = Game.int_date(x.date)
			x.day = int(x.day)
	moments = d.get("moments", [])
	for m in moments:
		m.date = Game.int_date(m.date)
		for k in ["day", "variant", "expires", "answered_day"]:
			m[k] = int(m[k])
	queue = d.get("queue", [])
	for q in queue:
		for k in ["due", "until"]:
			q[k] = int(q[k])
	week = d.get("week", {})
	for k in week:
		if not week[k] is bool:
			week[k] = int(week[k])
	stop_tokens = float(d.get("stop_tokens", 0.0))
	last_from = d.get("last_from", {})
	for k in last_from:
		last_from[k] = int(last_from[k])
	standing = d.get("standing", {})
	for g in standing.values():
		g.since = int(g.since)
	standing_history = d.get("standing_history", {})
	standing_declined = {}
	for g in d.get("standing_declined", []):
		standing_declined[str(g)] = true
	_next = int(d.get("next", 1))
