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
## Session L3a (GDD 4.10 decision 6, the sort in docs/L3_SORT.md): every real storylet is one of three kinds. A FEED storylet
## (`feed`: no replies) is a message that asks nothing: it never stops, never waits, changes no mood or relationship, only the
## story state it carries (`effects`: flags, a sender's memory, the family's attitude); the day picks 2-4 a week. An INVITATION
## (`invite`, L1b) lands in a free-time slot on Sunday (up to 2 a week, data/habits.json invites). A STORY BEAT (`beat`) is a
## rare real choice posted on Sunday for the coming week (the stop token: at most 1 a week): a card on the planner whose price is
## the free-time slots a reply takes (`slots`) and the relationship; left open it takes its stated default when Monday is played.
## The old `important` (L1a: wait for the planner) stays for the test moments only.

## Off switch for the tools (like HealthSystem.model_enabled): no moments at all.
static var enabled := true
## The Sunday talk and the post-race message. OFF unless the app shell switches them on (main.gd): the talk always stops Play
## week, so every tool that plays weeks with `while advance_day() != WEEK_DONE` would never get past Sunday evening. The tools
## that test the talk (storylet_check, the UI checks) switch it on themselves.
static var talks_enabled := false
## Tools: use the test moments (storylet files with "test": true). A normal career uses them only when the Dev menu's
## Test moments switch is on for it (test_content, debug builds only).
static var include_test := false
## The people around the athlete and their moments (session P1, GDD 4.9.5): the family, friends, close training partners,
## school staff and rivals (Cast, data/cast.json) and every real storylet that is not one of the coach's talk topics. OFF
## unless the app shell switches it on (main.gd), like the talks: real moments stop Play week, so the tools that play days
## keep exactly today's behaviour. storylet_check part 7 and the UI checks switch it on themselves.
static var people_enabled := false

## The coach's talk topics (sessions C3 / M1): real content that runs without the people (people_enabled off).
const COACH_TOPICS := ["week", "race", "ack", "mood"]

const NONE := "_none"   # the answer of a moment that passed unanswered
const ACK := "talk_ack"  # the storylet of a week talk without a topic (data/storylets/week_talk.json)
## Moments made by other systems of the coach (session C5): the moment kind -> the id of the GameSystem whose on_reply(ref, reply)
## answers it (SeasonGoals: a goal met / missed; CoachSuggests: a meet or target he suggests).
const CUSTOM_SYSTEMS := {"goal": "goals", "suggest": "suggests", "market": "market"}

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
var _why := {}               # (session L2b) the answer being applied, for the relationship's log (not saved)
var standing_declined := {}  # group -> true: "Not now" was answered; again_after identical answers needed
# Session P1 (the cast; saved only once there is something):
var family := {}             # {attitude} (data/cast.json attitudes; a reply's `attitude` effect changes it)
var cast_info := {}          # the creation answers the cast was made from: {origin, old_sport, family}
var late_nights := {}        # day number (as text) -> points of life load that day from a late night the evening before
var rival_stats := {}        # rival id -> {beat, lost, streak (losses in a row), wins (wins in a row), races}
var planner_line := {}       # session L1a: the coach's one line for the planner: {monday (date key of the week it is for), text}
var drawn_week := -1         # session L3a: the Monday (day number) whose story beat and invitations were drawn
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
	GameConfig.randomize_dice(rng, "moments")


## The day number of a date (days since 1 Jan 1970): cooldowns, expiry and chains count in these.
static func day_no(d: Dictionary) -> int:
	return floori(Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12}) / 86400.0)


# --- Content and settings -----------------------------------------------------------------------------------

## The storylets this career can get: the real ones, and the test ones for the tools or with the Dev menu's switch. The people's
## moments (every real storylet that is not a coach talk topic, session P1) only with `people_enabled`.
func content() -> Array:
	var test := include_test or (test_content and OS.is_debug_build())
	var key := "%s|%s|%d" % [test, people_enabled, Data.storylets.size()]
	if key != _content_key:
		_content_key = key
		_content = Data.storylets.filter(func(s):
			if bool(s.get("test", false)):
				return test
			return people_enabled or str(s.get("topic", "")) in COACH_TOPICS)
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
	_resolve_invitations(today)   # (session L1b: tonight's invitation happens, or passes)
	_slot("evening", ctx, today)
	if talks_enabled:
		if not ctx.get("race_note", {}).is_empty():
			_post_race_note(ctx, today)
		if int(ctx.day) == 6 and ctx.get("week") != null:
			_post_week_talk(ctx, today)
	if people_enabled:
		_people_evening(ctx, today)
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
	if _fire_dated(slot, ctx, today):
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


## Session P1: a moment of a day of the year (`dated`: Christmas Eve, vappu, the birthday, the camp week...) comes whenever it
## fits, before the day's roll (like a chain follow-up), inside the day's and the week's limits. Only with the people on.
func _fire_dated(slot: String, ctx: Dictionary, today: int) -> bool:
	if not people_enabled:
		return false
	var r: Dictionary = Data.moments.rate
	if int(week.fired_day) == today or int(week.count) >= int(r.max_per_week):
		return false
	var pick := _pick(ctx, today, ["morning", "any"] if slot == "morning" else ["evening", "any"], true)
	if pick.is_empty():
		return false
	_post(pick.s, pick.from, ctx, today)
	return true


## A weighted pick among the storylets that fit now: {s, from (person)} or {}. `dated_only`: only the dated ones (P1).
func _pick(ctx: Dictionary, today: int, slots: Array, dated_only := false) -> Dictionary:
	var cands := []
	var total := 0.0
	for s in content():
		if bool(s.get("chain_only", false)) or str(s.get("topic", "")) != "" or not _slot_of(s) in slots:
			continue
		if s.has("invite") or s.has("beat"):   # (sessions L1b / L3a: posted for the coming week on Sunday, never picked by the day)
			continue
		if dated_only and not bool(s.get("dated", false)):
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


## An important moment needs a stop token (about one a week), and none comes while another stop event waits. (Session L1a: it
## waits for the planner instead of stopping; the setting "Every moment" is cut.)
func _stop_allowed(s: Dictionary) -> bool:
	if not bool(s.get("important", false)) and not s.has("beat"):
		return true
	return stop_tokens >= 1.0 and Game.pending_event().is_empty()


## Session L3a: a message that asks nothing (no replies, never a stop, never waiting).
static func is_feed(s: Dictionary) -> bool:
	return bool(s.get("feed", false))


## The effects a feed message may carry: story state only (data/moments.json effects.story), never a mood or a relationship.
static func story_effects(s: Dictionary) -> Dictionary:
	var out := {}
	var allowed: Array = Data.moments.effects.story
	var eff: Dictionary = s.get("effects", {})
	for k in eff:
		if str(k) in allowed:
			out[k] = eff[k]
	return out


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
		if not _sender_ok(s.get("when", {}), ctx, p):
			continue
		if (not is_feed(s) and _valid_replies(s, ctx, p).size() < 2) or _valid_variants(s, ctx, p).is_empty():
			continue
		out.append(p)
	return out


## The people a `from` selector names: "coach", "teammate", "teammate:<role>" (anyone in the coach's group); session P1:
## "partner" / "partner:<role>" (the close training partners), "family" (anyone), "parent" / "parent:mum" / "parent:dad" /
## "parent:athlete" (the one who ran), "sibling", "best_friend", "friend" (the other friends), "friends" (any friend),
## "school" / "school:<role>" (class_teacher, pe_teacher, counsellor), "rival".
func people_for(selector: String) -> Array:
	var parts := selector.split(":")
	var sub := parts[1] if parts.size() > 1 else ""
	var out := []
	for p in people.values():
		if not bool(p.active):
			continue
		var ok := false
		match parts[0]:
			"coach":
				ok = p.role == "coach"
			"teammate":
				ok = p.thread == "group" and (sub == "" or p.role == sub)
			"partner":
				ok = p.thread == "group" and bool(p.get("close", false)) and (sub == "" or p.role == sub)
			"family":
				ok = p.thread == "family"
			"parent":
				ok = p.role in ["mum", "dad"] and (sub == "" or p.role == sub or (sub == "athlete" and bool(p.get("athlete_parent", false))))
			"sibling", "best_friend", "friend":
				ok = p.role == parts[0]
			"friends":
				ok = p.thread == "friends"
			"school":
				ok = p.thread == "school" and (sub == "" or p.role == sub)
			"rival":
				ok = p.thread == "rivals"
		if ok:
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
		var topic := str(q.get("topic", ""))   # (session P1: "pick a fitting storylet of this topic", e.g. the family's card talk)
		var s := storylet(str(q.get("id", ""))) if topic == "" else {}
		if (topic == "" and s.is_empty()) or today > int(q.until):
			queue.erase(q)
			dropped_chains += 1
			continue
		var senders := []
		if topic != "":
			if int(week.fired_day) == today or int(week.count) >= int(r.max_per_week):
				return false
			var pick := _pick_queued_topic(topic, slot, ctx, today)
			if pick.is_empty():
				continue
			s = pick.s
			senders = pick.senders
		else:
			var sl := _slot_of(s)
			if sl != "any" and sl != slot:
				continue
			if int(week.fired_day) == today or int(week.count) >= int(r.max_per_week):
				return false
			if not _eligible(s, ctx, today):
				continue
			senders = _senders(s, ctx, today)
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
	if is_feed(s):
		return _post_feed(s, p, ctx, today, opts)
	var variants := _valid_variants(s, ctx, p)
	var last_variant := int(seen.get(s.id, {}).get("variant", -1))
	if variants.size() > 1:
		variants.erase(last_variant)   # never the same text twice in a row
	var vi: int = variants[rng.randi_range(0, variants.size() - 1)]
	var fill := _fill(ctx, p)
	var replies := []
	for rep in _valid_replies(s, ctx, p):
		replies.append({"id": str(rep.id), "label": CoachSystem.words(str(rep.label).format(fill)),
				"hint": CoachSystem.words(str(rep.get("hint", "")).format(fill))})
	var body := CoachSystem.words(_variant_text(s.text[vi]).format(fill))
	var prefix := str(opts.get("prefix", ""))
	var text := body if prefix == "" else (prefix if body == "" else prefix + "\n\n" + body)
	var talk := bool(opts.get("talk", false))
	var counted := bool(opts.get("counted", true))
	var invite := opts.has("invite")   # (session L1b: posted on Sunday for a slot of the coming week: ctx is that slot's day)
	var beat := opts.has("beat")       # (session L3a: a story beat, posted on Sunday for the coming week)
	var posted: Dictionary = Game.date.duplicate() if invite or beat else ctx.date.duplicate()
	var m := {"id": "m%d" % _next, "kind": "moment", "storylet": str(s.id), "date": posted, "day": today,
			"thread": str(s.thread), "from": str(p.id), "text": text, "variant": vi,
			"replies": replies, "fill": fill, "expires": today + int(s.get("expires_days", Data.moments.expires_days)),
			"stop": false, "event": "", "answer": "", "answered_day": -1, "auto": false, "talk": talk}
	_next += 1
	if invite:
		var iv: Dictionary = s.invite
		var go: Array = (iv.get("go", ["go"]) as Array).map(func(x): return str(x))
		m.invite = {"activity": str(iv.get("activity", "friends")), "go": go,
				"title": CoachSystem.words(str(iv.get("title", "")).format(fill)),
				"chip": CoachSystem.words(str(iv.get("chip", iv.get("title", ""))).format(fill))}
		m.slot_day = day_no(ctx.date)
		m.planned = ""
		m.expires = int(m.slot_day)
		m.planner = true
		HabitSystem.touch()
	if beat:
		var bt: Dictionary = s.beat
		m.beat = {"title": CoachSystem.words(str(bt.get("title", "")).format(fill)),
				"chip": CoachSystem.words(str(bt.get("chip", "")).format(fill)), "default": str(bt.get("default", ""))}
		m.week = day_no(Calendar.monday_of(Game.date))
		m.planner = true
		m.expires = today - 1   # (the Monday it was posted for: when that day is played, an open beat takes its default)
	var sn: Dictionary = seen.get(s.id, {"count": 0, "first": today})
	sn.count = int(sn.count) + 1
	sn.last = today
	sn.variant = vi
	sn.reply = ""
	seen[s.id] = sn
	last_from[p.id] = today
	moments.append(m)
	_message(m.thread, p.id, m.text, m.id, posted)
	var group := str(s.get("standing", ""))
	if invite:
		if group != "" and standing.has(group) and replies.any(func(rep): return rep.id == standing[group].reply):
			m.auto = true   # (the player's rule plans it; it still happens on its evening)
			m.planned = str(standing[group].reply)
		fired.append({"day": today, "storylet": s.id, "variant": vi, "stop": false, "auto": bool(m.auto), "from": p.id,
				"talk": false, "planner": true, "invite": true})
		return m
	if beat:   # (session L3a: it waits on the planner; it uses the week's stop token)
		stop_tokens -= 1.0
		fired.append({"day": today, "storylet": s.id, "variant": vi, "stop": false, "auto": false, "from": p.id,
				"talk": false, "planner": true, "beat": true})
		return m
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
	if talk:
		_post_event(m, p)
	elif important:   # (session L1a, "L1's questions" 5: no people stops mid-week; it waits for the Sunday planner instead)
		stop_tokens -= 1.0
		if counted:
			week.stops = int(week.stops) + 1
		_wait_for_planner(m)
	fired.append({"day": today, "storylet": s.id, "variant": vi, "stop": m.stop, "auto": false, "from": p.id, "talk": talk,
			"planner": bool(m.get("planner", false))})
	return m


## Session L3a: a feed storylet = a message from its sender that asks nothing: no moment waits, nothing stops; the story state it
## carries (`effects`, story keys only) is set; it counts in the week's 2-4 like a moment did. Returns {"auto": false, "feed": true}.
func _post_feed(s: Dictionary, p: Dictionary, ctx: Dictionary, today: int, opts := {}) -> Dictionary:
	var variants := _valid_variants(s, ctx, p)
	var last_variant := int(seen.get(s.id, {}).get("variant", -1))
	if variants.size() > 1:
		variants.erase(last_variant)   # never the same text twice in a row
	var vi: int = variants[rng.randi_range(0, variants.size() - 1)]
	var fill := _fill(ctx, p)
	var text := CoachSystem.words(_variant_text(s.text[vi]).format(fill))
	var sn: Dictionary = seen.get(s.id, {"count": 0, "first": today})
	sn.count = int(sn.count) + 1
	sn.last = today
	sn.variant = vi
	sn.reply = "feed"   # (nothing waits for an answer)
	seen[s.id] = sn
	last_from[p.id] = today
	if str(s.thread) == "coach":
		_start_threads()
	_message(str(s.thread), str(p.id), text, "", ctx.date)
	threads[str(s.thread)].back().feed = str(s.id)   # (which storylet: a message that asks nothing)
	_apply(story_effects(s), p, "feed:" + str(s.id))
	if bool(opts.get("counted", true)):
		week.fired_day = today
		week.count = int(week.count) + 1
	fired.append({"day": today, "storylet": s.id, "variant": vi, "stop": false, "auto": false, "from": p.id, "talk": false,
			"planner": false, "feed": true})
	return {"auto": false, "feed": true}


## Session L1a: a moment that would have stopped Play week waits for the Sunday planner: it shows there as a card with its replies
## (it counts in "N choices waiting") and, unanswered, passes as "you didn't answer" when the next week starts (it expires on the
## coming Sunday, so the Monday morning after it resolves it).
func _wait_for_planner(m: Dictionary) -> void:
	var d: Dictionary = m.date
	m.planner = true
	m.expires = day_no(d) - Calendar.weekday(d) + 6


## The moments waiting for the planner (session L1a), oldest first. Session L1b: an invitation waits until it is planned (Go /
## Stay home); a planned one still shows on its slot but asks nothing.
func waiting() -> Array:
	return moments.filter(func(m): return m.answer == "" and bool(m.get("planner", false)) and str(m.get("planned", "")) == "")


# --- Invitations (session L1b, GDD 4.10 decision 6 "Invitations land in the slots") -------------------------------------------

## The new week is set up (Sunday evening, when the planner opens on it): an invitation may land in one of its slots.
func on_week_start(w: WeekSim) -> void:
	if not people_enabled or not active() or started_day < 0:
		return
	if drawn_week == day_no(w.monday):
		return   # (session L3a: this week's beat and invitations were drawn already: a game loaded mid-week goes on as without saving)
	drawn_week = day_no(w.monday)
	_post_beat(w)
	_post_invitations(w)


# --- Story beats (session L3a, GDD 4.10 decision 6; the sort in docs/L3_SORT.md) ------------------------------------------------

## The new week is set up (Sunday evening): a story beat may come for it, with the week's stop token (at most one a week, ~5-7 a
## year by its storylets' conditions and cooldowns): a storylet with a `beat` part whose conditions hold on the week's first day
## to play. It waits on the planner as a card; its replies' `slots` take free-time slots of THIS week.
func _post_beat(w: WeekSim) -> void:
	if stop_tokens < 1.0 or not Game.pending_event().is_empty():
		return
	var monday_no := day_no(w.monday)
	if moments.any(func(m): return m.has("beat") and int(m.get("week", -1)) == monday_no):
		return
	var today := day_no(Game.date)
	var ctx := {"date": Game.date, "day": Calendar.weekday(Game.date), "day_type": Calendar.day_type(Game.date), "week": w,
			"race_note": {}}
	var cands := []
	var total := 0.0
	for s in content():
		if not s.has("beat") or bool(s.get("chain_only", false)):
			continue
		if not _eligible(s, ctx, today):
			continue
		var senders := _senders(s, ctx, today)
		if senders.is_empty():
			continue
		var wt := float(s.get("weight", 1.0))
		cands.append({"s": s, "senders": senders, "w": wt})
		total += wt
	if cands.is_empty():
		return
	var x := rng.randf() * total
	var chosen: Dictionary = cands.back()
	for c in cands:
		x -= c.w
		if x < 0.0:
			chosen = c
			break
	var senders: Array = chosen.senders
	_post(chosen.s, senders[rng.randi_range(0, senders.size() - 1)], ctx, today, false, {"beat": true, "counted": false})


## The weekdays a beat reply's `slots` take in the week starting `monday`: its `days` (weekday numbers), or "break" = the days of
## that week inside a school break; only days not played yet.
func slot_days(slots: Dictionary, monday: Dictionary) -> Array:
	var out := []
	var first := Calendar.weekday(Game.date) if Calendar.date_key(Calendar.monday_of(Game.date)) == Calendar.date_key(monday) else 0
	var days = slots.get("days", [])
	for i in 7:
		if i < first:
			continue
		if days is String and str(days) == "break":
			if str(_school_day(Game.add_days(monday, i)).get("break", "")) != "":
				out.append(i)
		elif days is Array and float(i) in days.map(func(x): return float(x)):
			out.append(i)
	return out


## Every weekday of this week that an open or answered beat takes or may take (an invitation never lands on one).
func beat_days(monday: Dictionary) -> Array:
	var out := []
	var key := day_no(monday)
	for m in moments:
		if not m.has("beat") or int(m.get("week", -1)) != key:
			continue
		if m.has("took"):
			out.append_array(m.took.days)
		elif m.answer == "":
			for r in storylet(str(m.storylet)).get("replies", []):
				if r.has("slots"):
					out.append_array(slot_days(r.slots, monday))
	return out


## The free-time slot a story beat or an away week (the confirmation camp) takes on date `d`: {activity, chip, title, moment}
## or {} (session L3a). HabitSystem reads it for the week being played.
func away_on(d: Dictionary) -> Dictionary:
	var monday := Calendar.monday_of(d)
	var key := day_no(monday)
	var wd := Calendar.weekday(d)
	for m in moments:
		if m.has("took") and int(m.get("week", -1)) == key and float(wd) in (m.took.days as Array).map(func(x): return float(x)):
			return {"activity": str(m.took.activity), "chip": str(m.beat.chip), "title": str(m.beat.title), "moment": str(m.id)}
	if people_enabled and not cast_info.is_empty():
		var camp: Dictionary = Data.cast.away.rippileiri
		var start := Cast.occurrence("rippileiri", int(d.year), flags)
		if not start.is_empty() and str(_camp_flag()) in camp.get("flags", []):
			var n := Calendar.days_between(start, d)
			if n >= 0 and n < int(camp.days):
				return {"activity": str(camp.activity), "chip": str(camp.chip), "title": str(camp.title), "moment": ""}
	return {}


func _camp_flag() -> String:
	for f in ["rippi_june", "rippi_july", "rippi_day", "rippi_none"]:
		if flags.has(f):
			return f
	return ""


## Up to data/habits.json invites.max_per_week a week (session L3a: 2), each with its chance (`chances`: the first, the second),
## no longer using the week's stop token (an invitation never makes Play week ask): a storylet with an `invite` part whose
## conditions hold for one of its slot days (`invite.days`, weekday numbers) still to come this week and not taken by a story
## beat; picked by weight among every fitting (storylet, day).
func _post_invitations(w: WeekSim) -> void:
	var cfg: Dictionary = Data.habits.invites
	var chances: Array = cfg.get("chances", [cfg.get("chance", 0.7)])
	for k in int(cfg.max_per_week):
		if rng.randf() >= float(chances[mini(k, chances.size() - 1)]):
			return
		if not _post_invitation(w):
			return


## One invitation into the coming week; false when none fits.
func _post_invitation(w: WeekSim) -> bool:
	var today := day_no(Game.date)
	var taken := beat_days(w.monday)
	var cands := []
	var total := 0.0
	for s in content():
		if not s.has("invite") or bool(s.get("chain_only", false)):
			continue
		for wd in s.invite.get("days", []):
			var d := int(wd)
			if d < w.day or d > 6 or d in taken:
				continue
			var date := Game.add_days(w.monday, d)
			if not invitation_on(date).is_empty() or not away_on(date).is_empty():
				continue
			var ctx := {"date": date, "day": d, "day_type": Calendar.day_type(date), "week": w, "race_note": {}}
			if not _eligible(s, ctx, today):
				continue
			var senders := _senders(s, ctx, today)
			if senders.is_empty():
				continue
			var wt := float(s.get("weight", 1.0))
			cands.append({"s": s, "ctx": ctx, "senders": senders, "w": wt})
			total += wt
	if cands.is_empty():
		return false
	var x := rng.randf() * total
	var chosen: Dictionary = cands.back()
	for c in cands:
		x -= c.w
		if x < 0.0:
			chosen = c
			break
	var senders: Array = chosen.senders
	_post(chosen.s, senders[rng.randi_range(0, senders.size() - 1)], chosen.ctx, today, false, {"invite": true, "counted": false})
	return true


## The date of a day number (the inverse of day_no).
static func _date_of(n: int) -> Dictionary:
	var t := Time.get_datetime_dict_from_unix_time(n * 86400 + 43200)
	return {"year": int(t.year), "month": int(t.month), "day": int(t.day)}


## The invitation in a date's slot (waiting, planned or answered on its evening), or {}.
func invitation_on(d: Dictionary) -> Dictionary:
	var n := day_no(d)
	for m in moments:
		if m.has("invite") and int(m.slot_day) == n:
			return m
	return {}


## "Change my mind": a planned invitation waits for an answer again (until its evening).
func unplan(moment_id: String) -> void:
	var m := moment(moment_id)
	if not m.is_empty() and m.has("invite") and m.answer == "":
		m.planned = ""
		HabitSystem.touch()


## The invitations of the week starting `monday` (oldest first).
func invitations(monday: Dictionary) -> Array:
	var lo := day_no(monday)
	return moments.filter(func(m): return m.has("invite") and int(m.slot_day) >= lo and int(m.slot_day) <= lo + 6)


## Tonight's invitation happens: its planned reply (Go or Stay home) is resolved with its effects (a `sleep` = a late night for
## tomorrow); unanswered it passes as "you didn't answer".
func _resolve_invitations(today: int) -> void:
	for m in moments.duplicate():
		if m.has("invite") and m.answer == "" and int(m.slot_day) == today:
			_resolve(m, str(m.planned) if str(m.get("planned", "")) != "" else NONE)


func _post_event(m: Dictionary, p: Dictionary) -> void:
	var choices := []
	for rep in m.replies:
		choices.append({"id": rep.id, "label": rep.label, "detail": rep.hint})
	var title := thread_name(m.thread)   # (a rule offer has no sender)
	if not p.is_empty():
		var pattern := str(Data.moments.event_title)
		if bool(m.get("talk", false)):
			pattern = str(Data.coach_talk.talk.title)
		elif str(m.kind) == "proposal":
			pattern = str(Data.coach_talk.proposal.title)
		elif str(m.kind) == "goal":
			pattern = str(Data.goals.ui.moment_title)
		elif str(m.kind) == "suggest":
			pattern = str(Data.advice.suggest.ui.moment_title)
		title = pattern.format({"from": person_name(p), "thread": title})
	if m.has("title"):   # (the coach market's own titles, session C6)
		title = str(m.title)
	var e := Game.post_event(id, title, m.text, choices, true)
	e.kind = "moment"
	e.moment = m.id
	m.stop = true
	m.event = e.id


## The player's answer from a thread (the UI, C3) or the tools: a stop moment goes through its event. Session L1b: an invitation
## is only PLANNED by an answer (Go / Stay home, changeable until its evening; an unknown reply leaves it open): it happens on the
## evening of its slot (_resolve_invitations).
func answer(moment_id: String, reply_id: String) -> void:
	var m := moment(moment_id)
	if m.is_empty() or m.answer != "":
		return
	if m.has("invite"):
		if m.replies.any(func(r): return r.id == reply_id):
			m.planned = reply_id
			HabitSystem.touch()   # (the slot may change: HabitSystem's cache)
			for x in threads.get(str(m.thread), []):
				if str(x.moment) == str(m.id):
					x.read = true
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
	if m.has("invite"):
		HabitSystem.touch()   # (session L1b: an invitation settled; HabitSystem's cache)
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
	if m.kind == "proposal":
		_resolve_proposal(m, reply_id)
		return
	if CUSTOM_SYSTEMS.has(str(m.kind)):
		_resolve_custom(m, reply_id)
		return
	var s := storylet(str(m.storylet))
	var p: Dictionary = people.get(m.from, {})
	var fill: Dictionary = m.fill
	var cause := "moment:" + str(m.storylet)
	var next = null
	m.changes = []
	var rel_before := _relations()   # (session L2b: whose relationship this answer moved, for the result card)
	if reply_id == NONE:
		var na: Dictionary = s.get("no_answer", Data.moments.no_answer)
		_why = {"from": str(m.from), "reply": "", "about": _about(m)}
		_apply(na.get("effects", {}), p, cause)
		_why = {}
		m.changes = _changes_of(na.get("effects", {}), p, false, false)
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
		elif bool(m.get("defaulted", false)):   # (session L3a: a story beat left open took its stated default)
			_message(m.thread, "system", str(Data.moments.beat.defaulted).format({"label": label}), m.id, Game.date)
		else:
			_message(m.thread, "you", label, m.id, Game.date)
		if m.has("beat") and rep.has("slots"):   # (session L3a: the reply takes free-time slots of the beat's week)
			var monday := _date_of(int(m.week))
			m.took = {"days": slot_days(rep.slots, monday), "activity": str(rep.slots.get("activity", "family"))}
			HabitSystem.touch()
		_why = {"from": str(m.from), "reply": label, "about": _about(m)}
		_apply(rep.get("effects", {}), p, cause)
		_why = {}
		m.changes = _changes_of(rep.get("effects", {}), p, bool(rep.get("remember", false)), false)
		var result := str(rep.get("result", "")).format(fill)
		if result != "":
			# (a reply with "result_from": "sender" is the sender's own answer, a bubble from them; else a line of the game)
			var speaker := str(p.id) if str(rep.get("result_from", "")) == "sender" and not p.is_empty() else "system"
			_message(m.thread, speaker, result, m.id, Game.date)
			threads[m.thread].back().read = true   # (it answers the player's own reply: nothing "new" about it)
		next = rep.get("next", null)
	var moved := _relations_moved(rel_before)
	if not moved.is_empty():
		m.rel = moved
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


## Effects of a reply (data/moments.json effects): trust, the sender's relationship, flags, counters, the coach's proposal and
## (session M1) the moods confidence / motivation / stress (MindSystem.from_moment). The prepared ones (sleep, school, budget)
## change nothing until their systems exist.
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
					var was := float(p.relation)
					p.relation = clampf(float(p.relation) + float(v), float(rel.min), float(rel.max))
					_note_relation(p, was, _why)
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
			"proposal":   # (session C4: the reply asked for a lighter week / more; the coach looks at it the next morning)
				var cp := Game.get_system("proposals") as CoachProposals
				if cp:
					cp.request(str(v))
			"confidence", "motivation", "stress":   # (session M1: points on the mood, scaled by the sender)
				var mind := MindSystem.sys()
				if mind:
					var pts := float(v)
					if people_enabled and str(p.get("role", "")) != "coach":
						pts *= float(Data.cast.mood_scale)   # (session P1: the people's moments weigh less than the coach's words)
					mind.from_moment(key, pts, p)
			"sleep":   # (session P1: negative = a late night: life load tomorrow, data/cast.json sleep)
				if float(v) < 0.0:
					var k := str(today + 1)
					late_nights[k] = float(late_nights.get(k, 0.0)) - float(v) * float(Data.cast.sleep.life_load_per_point)
			"grades":   # (session P1: every academic subject's level, SchoolSystem.nudge_grades)
				var ss := SchoolSystem.sys()
				if ss:
					ss.nudge_grades(float(v))
			"attitude":   # (session P1: the family's attitude, data/cast.json attitudes)
				if Data.cast.attitudes.has(str(v)):
					family.attitude = str(v)
			"memory":   # (session P1: the sender remembers it, with the day)
				if not p.is_empty():
					if not p.has("memory"):
						p.memory = {}
					for name in (v if v is Array else [v]):
						p.memory[str(name)] = today
			"forget":
				if not p.is_empty() and p.has("memory"):
					for name in (v if v is Array else [v]):
						p.memory.erase(str(name))
			"relation_thread":   # (session P1: {thread: points} for everyone else in that thread, e.g. the friends)
				for t in v:
					for q in people.values():
						if bool(q.active) and str(q.thread) == str(t) and q != p and q.get("role", "") != "coach":
							var was := float(q.relation)
							q.relation = clampf(float(q.relation) + float(v[t]), float(Data.moments.relation.min), float(Data.moments.relation.max))
							_note_relation(q, was, _why)
			_:
				if not key in Data.moments.effects.prepared:
					push_warning("Moment effect '%s' is unknown (%s)" % [key, cause])


## What an answer changed, in words for the result card (data/moments.json `changes`): ["Trust in Heikki ▲ a little", ...].
## Only what really changes: the coach's trust (his `trust` and `relation` effects), another person's relationship, the moods
## (session M1, with the mind model on), and a "remember" note when the reply says so. Prepared effects (sleep, grades, budget)
## are listed once they exist.
## `with_people` false (session L2b, the answer's own result card): the relationships are left out here; the moment keeps them
## as `rel` ({pid, before, after}) and the card shows each as a word (PeopleUI.relation_rows).
func _changes_of(effects: Dictionary, p: Dictionary, remember: bool, with_people := true) -> Array:
	var cfg: Dictionary = Data.moments.changes
	var out := []
	if p.is_empty():
		return out
	if MindSystem.sys() != null:
		for mood in MindSystem.MOODS:
			var mv := float(effects.get(mood, 0.0))
			if people_enabled and str(p.get("role", "")) != "coach":
				mv *= float(Data.cast.mood_scale)   # (session P1, as in _apply)
			if mv != 0.0:
				out.append(_change_line(str(cfg.moods[mood]), mv))
	var ss := SchoolSystem.sys()
	if ss != null and not SchoolSystem.neutral:   # (session P1: a late night and the grades)
		if float(effects.get("sleep", 0.0)) < 0.0:
			out.append(_change_line(str(cfg.sleep), float(effects.sleep)))
		if float(effects.get("grades", 0.0)) != 0.0:
			out.append(_change_line(str(cfg.grades), float(effects.grades)))
	var who := short_name(p)
	var trust := float(effects.get("trust", 0.0))
	var rel := 0.0
	if p.get("role", "") == "coach":
		trust += float(effects.get("relation", 0.0))
	else:
		rel = float(effects.get("relation", 0.0))
	if trust != 0.0:
		out.append(_change_line(str(cfg.trust).format({"who": who}), trust))
	if rel != 0.0 and with_people:
		out.append(_change_line(str(cfg.relation).format({"who": who}), rel))
	var others: Dictionary = effects.get("relation_thread", {}) if with_people else {}
	for t in others:
		if float(others[t]) != 0.0:
			out.append(_change_line(str(cfg.thread).format({"thread": thread_name(str(t))}), float(others[t])))
	if str(effects.get("attitude", "")) != "":
		out.append(str(cfg.attitude).format({"word": Cast.attitude_word(str(effects.attitude))}))
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
			if m.has("beat") and str(m.beat.get("default", "")) != "":   # (session L3a: its stated default, said on the card)
				m.defaulted = true
				_resolve(m, str(m.beat.default))
			else:
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
	# (session M1, user 2026-10-17: "a line + a topic when low": with a mood low, his "how are you?" topic comes first)
	var mood_topic := _pick_topics("mood", ctx, today, p, 1)
	if not mood_topic.is_empty():
		topics = mood_topic + topics.slice(0, 1)
	# Session L1a ("L1's questions" 6): no popup. His one line goes on the planner, the whole talk into his thread (read: the planner
	# showed it), a topic whose reply changed the week (a `proposal` effect: sore, tired, fresh) is his note on a day instead
	# (CoachProposals.plan_notes), the other topics are moments in his thread, answered there, never a stop.
	var fill := _fill(ctx, p)
	var text := CoachTalk.week_talk(ctx, fill, rng)
	var mind := MindSystem.sys()
	if mind:
		var line := mind.coach_line(str(Coaches.id_of(Game.athlete)), str(Game.athlete.first_name))
		if line != "":
			text += "\n\n" + line
	_start_threads()
	_message("coach", str(p.id), text, "", ctx.date)
	threads.coach.back().read = true
	planner_line = {"monday": Calendar.date_key(Game.add_days(ctx.date, 1)), "text": CoachTalk.planner_line(ctx, fill)}
	for t in topics:
		if not _changes_week(t):
			_post(t, p, ctx, today, true, {"counted": false})


## A week topic one of whose replies asks for a lighter or heavier week (the `proposal` effect: sore, tired, fresh): the coach's notes
## do that now. (A mood topic stays: its "lighter week" reply is a request his next Sunday notes answer, CoachProposals.plan_notes.)
static func _changes_week(s: Dictionary) -> bool:
	if str(s.get("topic", "")) != "week":
		return false
	for r in s.get("replies", []):
		if r.get("effects", {}).has("proposal"):
			return true
	return false


## The coach's one line for the planner of the week starting `monday` ("" when he said none: the first week).
func line_for(monday: Dictionary) -> String:
	if int(planner_line.get("monday", -1)) != Calendar.date_key(monday):
		return ""
	return str(planner_line.get("text", ""))


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


# --- The people's evening (session P1) ---------------------------------------------------------------------------

## The evening of a played day with the people on: the rivals' record after a race and maybe a message from one of them, the
## family's talk after a report card or the application's results (queued for the next evening, a moment of the week).
func _people_evening(ctx: Dictionary, today: int) -> void:
	var note: Dictionary = ctx.get("race_note", {})
	var warmth: Dictionary = Data.cast.warmth   # (session L3a: the family's good signs come from what happened, not from replies)
	if not note.is_empty():
		_post_rival_note(ctx, today)
		if CoachTalk.race_outcome(note) == "pb":
			_warmth(warmth.pb)
	var ss := SchoolSystem.sys()
	if ss != null:
		var wait := int(Data.moments.chain_wait_days)
		if not ss.reports.is_empty() and day_no(Game.int_date(ss.reports.back().date)) == today and str(ss.reports.back().kind) != "period":
			queue.append({"topic": "card", "due": today + 1, "until": today + 1 + wait, "after": ""})
			if float(ss.reports.back().get("academic_average", 0.0)) >= float(warmth.card_avg):
				_warmth(warmth.card)
		var year := ss.app_year_now()
		if year > 0 and Calendar.date_key(SchoolApplication.dates(year).results) == Calendar.date_key(ctx.date):
			queue.append({"topic": "app", "due": today + 1, "until": today + 1 + wait, "after": ""})
	for k in late_nights.keys():
		if int(k) < today:
			late_nights.erase(k)


## Session L3a: a good sign for a family that is against the sport (`cast.json warmth`: a PB, a good report card); enough of them
## and the family comes round (fam_against_softens, a feed message that changes the attitude).
func _warmth(points) -> void:
	if str(family.get("attitude", "")) in Data.cast.warmth.attitudes:
		counters["family_warmth"] = int(counters.get("family_warmth", 0)) + int(points)


## After a race: every rival who ran it gets the result in `rival_stats`; rivals met often enough become people; with a chance
## one of those who ran it writes (topic "rival": a nod, a jab, the rival who always beats you). Never a stop, outside the 3-5.
func _post_rival_note(ctx: Dictionary, today: int) -> void:
	var vs: Array = ctx.race_note.get("vs", [])
	for x in vs:
		var st: Dictionary = rival_stats.get(str(x.id), {"beat": 0, "lost": 0, "streak": 0, "wins": 0, "races": 0})
		st.races = int(st.races) + 1
		if bool(x.beat):
			st.beat = int(st.beat) + 1
			st.wins = int(st.wins) + 1
			st.streak = 0
		else:
			st.lost = int(st.lost) + 1
			st.streak = int(st.streak) + 1
			st.wins = 0
		rival_stats[str(x.id)] = st
	_sync_people()
	var ran := []
	for x in vs:
		var p: Dictionary = people.get("rv." + str(x.id), {})
		if not p.is_empty() and bool(p.active):
			ran.append(p)
	if ran.is_empty() or rng.randf() >= float(Data.cast.rivals.note_chance):
		return
	var p: Dictionary = ran[rng.randi_range(0, ran.size() - 1)]
	var pool := _pick_topics("rival", ctx, today, p, 1)
	if not pool.is_empty():
		_post(pool[0], p, ctx, today, true, {"counted": false})


## A queued topic (the family's card talk): {s, senders} for a storylet of that topic that fits now in this slot, or {}.
func _pick_queued_topic(topic: String, slot: String, ctx: Dictionary, today: int) -> Dictionary:
	var cands := []
	var total := 0.0
	for s in content():
		if str(s.get("topic", "")) != topic:
			continue
		var sl := _slot_of(s)
		if sl != "any" and sl != slot:
			continue
		if not _eligible(s, ctx, today):
			continue
		var senders := _senders(s, ctx, today)
		if senders.is_empty():
			continue
		cands.append({"s": s, "senders": senders})
		total += float(s.get("weight", 1.0))
	if cands.is_empty():
		return {}
	var x := rng.randf() * total
	for c in cands:
		x -= float(c.s.get("weight", 1.0))
		if x < 0.0:
			return c
	return cands.back()


# --- The coach's proposals (session C4) -------------------------------------------------------------------------

## The head coach as a person of the threads ({} without one). Works with the moments switched off too (tools).
func _coach_person() -> Dictionary:
	_sync_people()
	var coach := people_for("coach")
	return coach[0] if not coach.is_empty() else {}


## The threads are saved once the moments have started: a message of the coach starts them (they may be off in tools).
func _start_threads() -> void:
	if started_day < 0:
		started_day = day_no(Game.date)


## A proposal of CoachProposals ("Ask me first"): his message in the coach thread as a moment (kind "proposal") with the replies
## OK / Veto: <reason> / Veto, no reason; with `stop` it stops Play week (user 2026-10-11: always with "Ask me first"). Outside
## the 3-5 moments a week. The answer goes to CoachProposals.on_reply (_resolve_proposal). Returns the moment ({} without a coach).
func post_proposal(proposal_id: String, text: String, replies: Array, stop: bool) -> Dictionary:
	var p := _coach_person()
	if p.is_empty():
		return {}
	_start_threads()
	var today := day_no(Game.date)
	text = CoachSystem.words(text)
	var m := {"id": "m%d" % _next, "kind": "proposal", "proposal": proposal_id, "storylet": "", "date": Game.date.duplicate(),
			"day": today, "thread": "coach", "from": str(p.id), "text": text, "variant": 0, "replies": _words_in(replies, {}),
			"fill": {}, "expires": today + int(Data.moments.expires_days), "stop": false, "event": "", "answer": "",
			"answered_day": -1, "auto": false, "talk": false}
	_next += 1
	moments.append(m)
	_message("coach", str(p.id), text, m.id, Game.date)
	if stop:
		_post_event(m, p)
	return m


## A moment of the coach's own systems (session C5), like a proposal: his message in the coach thread with replies, outside the 3-5
## a week, a stop with `stop`. `kind` is "goal" or "suggest" (CUSTOM_SYSTEMS), `ref` names what it is about for that system.
## The answer goes to the system's on_reply(ref, reply_id) -> {result (his reply), changes (lines for the result card)}.
## Works with the moments switched off too (tools). Returns the moment ({} without a coach).
## `opts` (session C6): `from` = a person id other than the head coach (a coach of the market, registered with market_person)
## and `thread` (default "coach"); `title` = the stop panel's title; `expires_days`.
func post_custom(kind: String, ref: String, text: String, replies: Array, stop: bool, opts := {}) -> Dictionary:
	var p: Dictionary = people.get(str(opts.from), {}) if opts.has("from") else _coach_person()
	if p.is_empty():
		return {}
	_start_threads()
	var thread := str(opts.get("thread", "coach"))
	var today := day_no(Game.date)
	var about := _coach_record(str(p.id))
	text = CoachSystem.words(text, about)
	var m := {"id": "m%d" % _next, "kind": kind, "ref": ref, "storylet": "", "date": Game.date.duplicate(),
			"day": today, "thread": thread, "from": str(p.id), "text": text, "variant": 0, "replies": _words_in(replies, about),
			"fill": {}, "expires": today + int(opts.get("expires_days", Data.moments.expires_days)), "stop": false, "event": "",
			"answer": "", "answered_day": -1, "auto": false, "talk": false}
	if opts.has("title"):
		m.title = str(opts.title)
	_next += 1
	moments.append(m)
	_message(thread, str(p.id), text, m.id, Game.date)
	if stop:
		_post_event(m, p)
	elif bool(opts.get("planner", false)):   # (session L1a: a card on the Sunday planner, e.g. "Coach suggests")
		_wait_for_planner(m)
	return m


## The coach record a person id names (a market coach's person id is his record id), else {} (= the head coach in CoachSystem.words).
func _coach_record(pid: String) -> Dictionary:
	var sys = Game.get_system("coach")
	return sys.coaches.get(pid, {}) if sys != null else {}


## Replies (id, label, hint) with the coach's pronouns filled (session F1).
static func _words_in(replies: Array, about: Dictionary) -> Array:
	var out := replies.duplicate(true)
	for r in out:
		for key in ["label", "hint"]:
			if r.has(key):
				r[key] = CoachSystem.words(str(r[key]), about)
	return out


## A person of the coach market (session C6): a coach who is not (or not yet) the head coach, writing in the "coaches" thread.
## Returns the person id (the coach record's id).
func market_person(c: Dictionary) -> String:
	var parts := str(c.name).split(" ", false, 1)
	var pid := str(c.id)
	if not people.has(pid):
		people[pid] = {"id": pid, "thread": "coaches", "role": "market_coach", "first_name": parts[0],
				"last_name": parts[1] if parts.size() > 1 else "", "relation": float(Data.moments.relation.start), "active": false}
	return pid


## A message that asks nothing, from any person (`from` = a person id, "you" or "system") in any thread (session C6).
func say(thread: String, from: String, text: String, read := false) -> void:
	if text == "":
		return
	_start_threads()
	_message(thread, from, text, "", Game.date)
	if read:
		threads[thread].back().read = true


## The relationship with a person (not the head coach, whose relationship is his trust): `delta` points (session C6: the old
## coach after a goodbye).
func add_relation(pid: String, delta: float, why := {"kind": "farewell"}) -> void:
	if people.has(pid):
		var was := float(people[pid].get("relation", Data.moments.relation.start))
		people[pid].relation = clampf(was + delta, 0.0, 100.0)
		_note_relation(people[pid], was, why)


## Session L2b (recording only): a person's relationship moved from `was`; kept with its cause in their `log` (the last
## cast.json relation_log entries): {date, delta, before, after} + `why` ({from: the sender, reply: the label ("" = no answer)}
## or {kind: "farewell"}).
func _note_relation(q: Dictionary, was: float, why: Dictionary) -> void:
	var d := float(q.relation) - was
	if d == 0.0:
		return
	var entry := {"date": Game.date.duplicate(), "delta": d, "before": was, "after": float(q.relation)}
	entry.merge(why)
	var list: Array = q.get("log", [])
	list.append(entry)
	while list.size() > int(Data.cast.get("relation_log", 6)):
		list.pop_front()
	q.log = list


## The first words of a moment's message, for a relationship's log (session L2b: what the answer was about).
static func _about(m: Dictionary) -> String:
	var text := str(m.get("text", "")).replace("\n", " ").strip_edges()
	var n := int(Data.causes.people.about_chars)
	return text if text.length() <= n else text.left(n - 1).strip_edges() + "…"


## Everyone's relationship now (person id -> value; the coach's is his trust and is left out).
func _relations() -> Dictionary:
	var out := {}
	for pid in people:
		if str(people[pid].get("role", "")) != "coach":
			out[pid] = float(people[pid].get("relation", Data.moments.relation.start))
	return out


## Whose relationship moved since `before` (_relations): [{pid, before, after}].
func _relations_moved(before: Dictionary) -> Array:
	var out := []
	for pid in before:
		var now := float(people[pid].get("relation", before[pid]))
		if now != float(before[pid]):
			out.append({"pid": str(pid), "before": float(before[pid]), "after": now})
	return out


## The answer to a custom moment: the player's reply in the thread, then the system decides and its reply comes back.
func _resolve_custom(m: Dictionary, reply_id: String) -> void:
	var label := ""
	for r in m.replies:
		if r.id == reply_id:
			label = str(r.label)
	if reply_id != NONE and label != "":
		_message(m.thread, "you", label, m.id, Game.date)
	var sys := Game.get_system(str(CUSTOM_SYSTEMS[m.kind]))
	var res: Dictionary = sys.on_reply(str(m.ref), reply_id) if sys != null and sys.has_method("on_reply") else {}
	m.changes = res.get("changes", [])
	var result := str(res.get("result", ""))
	if reply_id == NONE:
		_message(m.thread, "system", str(Data.moments.no_answer.result), m.id, Game.date)
	elif result != "":
		_message(m.thread, str(m.from), result, m.id, Game.date)
		threads[m.thread].back().read = true


## A message of the coach in his thread that asks nothing (a change he made, what he would have changed, his reply to a veto).
## `read` = the player has just seen it (it answers something they did in the day editor).
func coach_says(text: String, read := false) -> void:
	var p := _coach_person()
	if p.is_empty() or text == "":
		return
	_start_threads()
	_message("coach", str(p.id), text, "", Game.date)
	if read:
		threads.coach.back().read = true


## The player's own line in the coach thread (a veto given in the day editor).
func player_says(text: String) -> void:
	if _coach_person().is_empty() or text == "":
		return
	_start_threads()
	_message("coach", "you", text, "", Game.date)


## The answer to a proposal moment: the player's reply in the thread, then CoachProposals decides and his reply comes back.
func _resolve_proposal(m: Dictionary, reply_id: String) -> void:
	var label := ""
	for r in m.replies:
		if r.id == reply_id:
			label = str(r.label)
	if reply_id != NONE and label != "":
		_message(m.thread, "you", label, m.id, Game.date)
	var cp := Game.get_system("proposals") as CoachProposals
	var res: Dictionary = cp.on_reply(str(m.proposal), reply_id if reply_id != NONE else CoachProposals.NONE) if cp else {}
	m.changes = res.get("changes", [])
	var result := str(res.get("result", ""))
	if reply_id == NONE:
		_message(m.thread, "system", str(Data.moments.no_answer.result), m.id, Game.date)
	elif result != "":
		_message(m.thread, str(m.from), result, m.id, Game.date)
		threads[m.thread].back().read = true


## Up to `n` topic storylets (field `topic` = kind) that fit now, drawn by weight.
func _pick_topics(kind: String, ctx: Dictionary, today: int, p: Dictionary, n: int) -> Array:
	var pool := []
	for s in content():
		if str(s.get("topic", "")) != kind or not _eligible(s, ctx, today):
			continue
		if not _sender_ok(s.get("when", {}), ctx, p):   # (session P1: a rival's race; the coach's topics ask nothing of him)
			continue
		if (not is_feed(s) and _valid_replies(s, ctx, p).size() < 2) or _valid_variants(s, ctx, p).is_empty():
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
			"mood":   # (session M1) {"motivation": ["flat", "low"], ...}: each mood's word is one of those
				var mind := MindSystem.sys()
				ok = mind != null
				for mood in v:
					ok = ok and mind.word(str(mood)).id in v[mood]
			"race_outcome": ok = CoachTalk.race_outcome(ctx.get("race_note", {})) in v
			"chance":
				ok = rng.randf() < float(v)
			# Session P1 (the cast and Finnish life):
			"family": ok = str(family.get("attitude", "")) in v
			"has":
				for sel in v:
					ok = ok and not people_for(str(sel)).is_empty()
			"days_to":
				for ev in v:
					ok = ok and _in_range(Cast.days_to(str(ev), date, flags), v[ev])
			"days_after":
				for ev in v:
					ok = ok and _in_range(Cast.days_after(str(ev), date, flags), v[ev])
			"school_day": ok = (_school_day(date).get("kind", "") == "school") == bool(v)
			"break": ok = str(_school_day(date).get("break", "")) in v
			"break_week":   # (session L3a) a day of this Mon-Sun week is inside one of these breaks
				var mon := Calendar.monday_of(date)
				ok = false
				for i in 7:
					if str(_school_day(Game.add_days(mon, i)).get("break", "")) in v:
						ok = true
						break
			"stage":
				var ss := SchoolSystem.sys()
				ok = ss != null and str(ss.stage_of(date).id) in v
			"test_today": ok = (_tests(date) > 0) == bool(v)
			"test_tomorrow": ok = (_tests(Game.add_days(date, 1)) > 0) == bool(v)
			"tests_week":
				var ss := SchoolSystem.sys()
				ok = ss != null and _in_range(ss.tests_in_week(Calendar.monday_of(date)), v)
			"card_days_ago", "card_change", "card_avg", "cards": ok = _card_check(key, v, date)
			"turns": ok = _in_range(int(date.year) - int(a.birth_date.get("year", 0)), v)   # (the age they turn this year)
			"app":
				var ss := SchoolSystem.sys()
				ok = ss != null and ss.app_year_now() > 0 and ss.app_state(ss.app_year_now()) in v
			"app_result": ok = _app_result() in v
			"origin": ok = str(cast_info.get("origin", "")) in v
			"old_sport": ok = (str(cast_info.get("old_sport", "")) != "") == bool(v)
			# Session L3a ("content never contradicts the player"):
			"next_level":   # the next entered race's level (local / district / national / international ...)
				var nm := Game.next_race()
				ok = not nm.is_empty() and str(nm.get("level", "")) in v
			"card_grade":   # {"pe": [10, 10]}: the grade on the latest report card
				var ss := SchoolSystem.sys()
				ok = ss != null and not ss.reports.is_empty()
				for sid in v:
					ok = ok and _in_range(ss.last_grade(str(sid)), v[sid])
			"evening":   # the activity of the day's free-time slot (["family"]): what the player planned for it
				var hs := HabitSystem.sys()
				ok = hs != null and hs.activity_on(date) in v
			"memory", "memory_days", "rival_race", "rival_streak", "rival_wins", "trait":
				ok = p.is_empty() or _sender_key(key, v, ctx, p)   # (who sends it: checked per sender, _sender_ok)
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


const SENDER_KEYS := ["relation", "memory", "memory_days", "rival_race", "rival_streak", "rival_wins", "trait"]


## The conditions about who sends it (the relationship, their memory, a rival's race against you, a friend's trait): true
## when `p` meets every one of them.
func _sender_ok(when: Dictionary, ctx: Dictionary, p: Dictionary) -> bool:
	for key in when:
		if key in SENDER_KEYS and not _sender_key(key, when[key], ctx, p):
			return false
	return true


func _sender_key(key: String, v, ctx: Dictionary, p: Dictionary) -> bool:
	var mem: Dictionary = p.get("memory", {})
	match key:
		"relation":
			return _in_range(relation_of(p), v)
		"memory":
			for f in v:
				var name := str(f)
				if (mem.has(name.substr(1)) if name.begins_with("!") else not mem.has(name)):
					return false
			return true
		"memory_days":
			for name in v:
				if not mem.has(name) or not _in_range(day_no(ctx.date) - int(mem[name]), v[name]):
					return false
			return true
		"trait":
			return str(p.get("trait", "")) in v
		"rival_race":   # "beat" (you finished ahead of them in the race that just ended) / "lost"
			return _rival_result(ctx, p) in v
		"rival_streak":
			return _in_range(int(rival_stats.get(str(p.get("rival_id", "")), {}).get("streak", 0)), v)
		"rival_wins":
			return _in_range(int(rival_stats.get(str(p.get("rival_id", "")), {}).get("wins", 0)), v)
	return true


## "beat" / "lost" for a rival person in the race that just ended (the evening's race note), "" when they weren't in it.
func _rival_result(ctx: Dictionary, p: Dictionary) -> String:
	var rid := str(p.get("rival_id", ""))
	for x in ctx.get("race_note", {}).get("vs", []):
		if str(x.id) == rid:
			return "beat" if bool(x.beat) else "lost"
	return ""


## The school calendar's day (SchoolCalendar.day) in the athlete's town; {} with the school model off.
func _school_day(date: Dictionary) -> Dictionary:
	var ss := SchoolSystem.sys()
	return {} if ss == null else SchoolCalendar.day(ss.town(), date)


func _tests(date: Dictionary) -> int:
	var ss := SchoolSystem.sys()
	return 0 if ss == null else ss.tests_on(date).size()


## The latest report card: days since it (card_days_ago), its academic average (card_avg) and the change from the card before
## (card_change; 0 for the first card).
func _card_check(key: String, v, date: Dictionary) -> bool:
	var ss := SchoolSystem.sys()
	if ss == null or ss.reports.is_empty():
		return false
	var last: Dictionary = ss.reports.back()
	match key:
		"cards":   # (the number of report cards so far)
			return _in_range(ss.reports.size(), v)
		"card_days_ago":
			return _in_range(Calendar.days_between(Game.int_date(last.date), date), v)
		"card_avg":
			return _in_range(float(last.academic_average), v)
		"card_change":
			var change := 0.0
			if ss.reports.size() > 1:
				change = float(last.academic_average) - float(ss.reports[ss.reports.size() - 2].academic_average)
			return _in_range(change, v)
	return false


## How the latest application went: "first" (a place from the first wish), "other" (from another wish), "none" (no place),
## "" (no results yet).
func _app_result() -> String:
	var ss := SchoolSystem.sys()
	if ss == null:
		return ""
	var years := ss.applications.keys()
	if years.is_empty():
		return ""
	years.sort()
	var rows: Array = ss.applications[years.back()].get("results", [])
	if rows.is_empty():
		return ""
	if str(rows[0].get("status", "")) == "yes":
		return "first"
	for r in rows:
		if str(r.get("status", "")) == "yes":
			return "other"
	return "none"


## The life load of a late night on day `d` (a reply's `sleep` the evening before; session P1): read by SchoolSystem.load_parts.
func late_night(d: Dictionary) -> float:
	return float(late_nights.get(str(day_no(d)), 0.0))


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
	var fill := {
		"name": a.first_name, "full_name": a.full_name(), "from": str(p.get("first_name", "")),
		"coach": person_name(coach[0]) if not coach.is_empty() else "",
		"coach_first": str(coach[0].first_name) if not coach.is_empty() else "",
		"teammate": str(mates[rng.randi_range(0, mates.size() - 1)].first_name) if not mates.is_empty() else "",
		"club": str(Data.get_club(a.club_id).get("name", "")),
		"meet": str(next.get("name", "")), "race_days": str(_next_race_days(ctx.date)) if not next.is_empty() else "",
		"pb": Calendar.format_time(pb) if pb > 0.0 else "",
		"weekday": str(names[int(ctx.day)]), "tomorrow": str(names[(int(ctx.day) + 1) % 7]),
	}
	if people_enabled:
		_fill_people(fill, ctx, p)
	return fill


## Session P1's placeholders: {from} is what the athlete calls the sender ("Mum"), {mum} / {dad} / {parent} (another parent
## when a parent writes), {sibling}, {best}, {friend}, {partner} (a close training partner other than the sender), {rival},
## {class_teacher}, {pe_teacher}, {counsellor}, {town}, {test_subject} (tomorrow's test, else today's), {avg} (the latest
## report card's academic average), {old_sport}, {family_word}.
func _fill_people(fill: Dictionary, ctx: Dictionary, p: Dictionary) -> void:
	fill.from = short_name(p)
	var pid := str(p.get("id", ""))
	fill.mum = _first_of("parent:mum")
	fill.dad = _first_of("parent:dad")
	fill.parent = _first_of("parent", pid)
	if fill.parent == "":
		fill.parent = _first_of("parent")
	fill.sibling = _first_of("sibling")
	fill.best = _first_of("best_friend")
	fill.friend = _first_of("friend", pid)
	var partners := people_for("partner").filter(func(q): return q.id != pid)
	fill.partner = short_name(partners[rng.randi_range(0, partners.size() - 1)]) if not partners.is_empty() else fill.teammate
	fill.rival = _first_of("rival", pid)
	fill.class_teacher = _first_of("school:class_teacher")
	fill.pe_teacher = _first_of("school:pe_teacher")
	fill.counsellor = _first_of("school:counsellor")
	var ss := SchoolSystem.sys()
	fill.town = ss.town() if ss != null else str(Game.athlete.hometown)
	fill.test_subject = ""
	fill.avg = ""
	if ss != null:
		for d in [Game.add_days(ctx.date, 1), ctx.date]:
			var t := ss.tests_on(d)
			if not t.is_empty():
				fill.test_subject = ss.subject_name(str(t[0]))
				break
		if not ss.reports.is_empty():
			fill.avg = "%.1f" % float(ss.reports.back().academic_average)
	fill.old_sport = str(Data.cast.get("sport_words", {}).get(str(cast_info.get("old_sport", "")), ""))
	fill.family_word = Cast.attitude_word(str(family.get("attitude", "")))


# --- People and threads ----------------------------------------------------------------------------------------

## Keeps the people in step with the career: the head coach (C1's record) and his training group; with `people_enabled`
## (session P1) also the cast: the family and the friends (made once), the close training partners of the group, the staff of
## the school the athlete goes to now, the rivals who became people. People who are no longer around stay, inactive, so old
## messages keep their names.
func _sync_people() -> void:
	var cs := Game.get_system("coach") as CoachSystem
	var head: Dictionary = cs.head() if cs else {}
	for p in people.values():
		p.active = false
	if not head.is_empty():
		var parts := str(head.name).split(" ", false, 1)
		_person(str(head.id), "coach", "coach", parts[0], parts[1] if parts.size() > 1 else "")
		for t in head.get("group", []):
			_person("%s.%s" % [head.id, t.id], "group", str(t.role), str(t.first_name), str(t.last_name))
	if not people_enabled or Game.athlete == null:
		return
	ensure_cast(Game.athlete)
	for p in people.values():
		if str(p.thread) in ["family", "friends"]:
			p.active = true
	if not head.is_empty():   # the close training partners
		var close := Cast.pick_partners(str(head.id), head.get("group", []))
		for t in head.get("group", []):
			var pid := "%s.%s" % [head.id, t.id]
			people[pid].close = pid in close
	_sync_school()
	_sync_rivals()


## The family and the friends of a career, once (session P1): from the creation answers (`a.origin` / `old_sport` are not
## saved with the athlete, so they are kept here). Called by Game.start_career and, for an older save, on the first day.
func ensure_cast(a: Athlete) -> void:
	if not people_enabled or a == null or not cast_info.is_empty():
		return
	cast_info = {"origin": a.origin, "old_sport": a.old_sport, "family": a.family}
	family = {"attitude": Cast.attitude_for(a.family)}
	for p in Cast.make(a, cast_info):
		if not people.has(p.id):
			people[p.id] = p


## The staff of the school the athlete goes to now (grades 8-9: the comprehensive school; after it the path's school).
func _sync_school() -> void:
	var ss := SchoolSystem.sys()
	if ss == null:
		return
	var stage := ss.stage_of(Game.date)
	if not bool(stage.get("subjects", false)):
		return   # (no school now: after the last year, or a gap)
	var kind := "comprehensive" if str(stage.id) in ["grade_8", "grade_9"] else "secondary"
	var key := "comp"
	if kind == "secondary":
		var path := ss.current_path()
		key = "%s_%d" % [str(path.get("school", "")) if str(path.get("school", "")) != "" else str(path.get("kind", "sec")), int(path.get("start_year", 0))]
	var made := false
	for p in people.values():
		if str(p.id).begins_with("sch.%s." % key):
			p.active = true
			made = true
	if not made:
		for p in Cast.make_school(Game.athlete, key, kind, str(cast_info.get("origin", ""))):
			people[p.id] = p


## Rivals met often enough become people (data/cast.json rivals: at most `max`, the ones met most first); a rival stays a
## person while they are in the rival pool.
func _sync_rivals() -> void:
	var rc: Dictionary = Data.cast.rivals
	var in_pool := {}
	for r in Game.rivals:
		in_pool[str(r.id)] = r
	var n := 0
	for p in people.values():
		if str(p.thread) == "rivals" and in_pool.has(str(p.get("rival_id", ""))):
			p.active = true
			n += 1
	if n >= int(rc.max):
		return
	var cands := Game.rivals.filter(func(r): return int(r.get("met", 0)) >= int(rc.met_min) and not people.has("rv." + str(r.id)))
	cands.sort_custom(func(x, y): return int(x.met) > int(y.met) or (int(x.met) == int(y.met) and str(x.id) < str(y.id)))
	for r in cands.slice(0, int(rc.max) - n):
		people["rv." + str(r.id)] = {"id": "rv." + str(r.id), "thread": "rivals", "role": "rival", "rival_id": str(r.id),
				"first_name": str(r.first_name), "last_name": str(r.last_name), "gender": Game.athlete.gender,
				"word": str(rc.word), "relation": Cast.relation_start("rival"), "active": true, "memory": {}}


func _first_of(sel: String, avoid := "") -> String:
	for q in people_for(sel):
		if str(q.id) != avoid:
			return short_name(q)
	return ""


func _person(pid: String, thread: String, role: String, first: String, last: String) -> void:
	if not people.has(pid):
		people[pid] = {"id": pid, "thread": thread, "role": role, "first_name": first, "last_name": last,
				"relation": float(Data.moments.relation.start)}
	people[pid].active = true
	people[pid].thread = thread   # (a coach of the market who becomes the head coach, session C6)
	people[pid].role = role


## 0-100; the head coach's is his trust.
func relation_of(p: Dictionary) -> float:
	if p.get("role", "") == "coach":
		var cs := Game.get_system("coach") as CoachSystem
		return cs.trust() if cs else float(Data.moments.relation.start)
	return float(p.get("relation", Data.moments.relation.start))


## The name shown for a person: their full name, or what the athlete calls them (a parent: "Mum", session P1).
static func person_name(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	if str(p.get("call", "")) != "":
		return str(p.call)
	return ("%s %s" % [p.first_name, p.last_name]).strip_edges()


## The short name in a sentence: "Mum" for a parent, else the first name.
static func short_name(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	return str(p.call) if str(p.get("call", "")) != "" else str(p.get("first_name", ""))


static func thread_name(thread: String) -> String:
	return str(Data.moments.threads.get(thread, {}).get("name", thread))


func _message(thread: String, from: String, text: String, moment_id: String, date: Dictionary) -> void:
	if not threads.has(thread):
		threads[thread] = []
	text = CoachSystem.words(text, _coach_record(from))   # (session F1: the coach's pronouns; already filled texts pass unchanged)
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


## Session L3a (the planner's quiet line): the people with unread messages, newest first: [{id, thread, name, count}].
func unread_senders() -> Array:
	var by := {}
	var last := {}
	for t in threads:
		for x in threads[t]:
			if bool(x.read) or x.from == "you" or x.from == "system":
				continue
			by[x.from] = int(by.get(x.from, 0)) + 1
			last[x.from] = maxi(int(last.get(x.from, -1)), int(x.day))
	var out := []
	for pid in by:
		var p: Dictionary = people.get(pid, {})
		if p.is_empty():
			continue
		out.append({"id": pid, "thread": str(p.thread), "name": short_name(p), "count": int(by[pid]), "day": int(last[pid])})
	out.sort_custom(func(a, b): return a.day > b.day or (a.day == b.day and str(a.id) < str(b.id)))
	return out


# --- Save / load ---------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := {}
	if started_day < 0:
		if test_content:
			d.test_content = true
		if stop_setting != "":
			d.stop_setting = stop_setting
		if not cast_info.is_empty():   # (session P1: the cast is made when the career starts, before the first day)
			d.people = people
	else:
		d = {"rng_seed": str(rng.seed), "rng_state": str(rng.state), "stop_setting": stop_setting,
				"test_content": test_content, "started_day": started_day, "seen": seen, "flags": flags, "counters": counters,
				"people": people, "threads": threads, "moments": moments, "queue": queue, "week": week,
				"stop_tokens": stop_tokens, "last_from": last_from, "standing": standing, "standing_history": standing_history,
				"standing_declined": standing_declined.keys(), "next": _next}
	# Session P1 (only when there is something, so a career without the people saves exactly as before):
	if not cast_info.is_empty():
		d.cast_info = cast_info
		d.family = family
	if not late_nights.is_empty():
		d.late_nights = late_nights
	if not rival_stats.is_empty():
		d.rival_stats = rival_stats
	if not planner_line.is_empty():
		d.planner_line = planner_line
	if drawn_week >= 0:
		d.drawn_week = drawn_week
	return d


## JSON makes every number a float: counts, days and dates back to ints.
func from_dict(d: Dictionary) -> void:
	HabitSystem.touch()   # (other invitations now: HabitSystem's cache)
	stop_setting = str(d.get("stop_setting", ""))
	test_content = bool(d.get("test_content", false))
	cast_info = d.get("cast_info", {})
	family = d.get("family", {})
	late_nights = {}
	var ln: Dictionary = d.get("late_nights", {})
	for k in ln:
		late_nights[str(k)] = float(ln[k])
	rival_stats = d.get("rival_stats", {})
	for st in rival_stats.values():
		for k in st:
			st[k] = int(st[k])
	planner_line = d.get("planner_line", {})
	if planner_line.has("monday"):
		planner_line.monday = int(planner_line.monday)
	drawn_week = int(d.get("drawn_week", -1))
	if not d.has("started_day"):
		people = d.get("people", {})
		_people_numbers()
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
	_people_numbers()
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
		if m.has("slot_day"):   # (session L1b: an invitation's slot)
			m.slot_day = int(m.slot_day)
		if m.has("week"):   # (session L3a: a story beat's week)
			m.week = int(m.week)
		if m.has("took"):
			m.took.days = (m.took.days as Array).map(func(x): return int(x))
	_close_retired()
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
	for g in standing.keys():   # (session L3a: a rule for a recurring choice that no longer exists goes)
		if not _group_exists(str(g)):
			standing.erase(g)


static func _group_exists(group: String) -> bool:
	return Data.storylets.any(func(s): return str(s.get("standing", "")) == group)


## Session L3a (an older save): a moment still open whose storylet is now a message that asks nothing, or gone (docs/L3_SORT.md),
## closes quietly: no "you didn't answer", no effect. Invitations, beats, the coach's own kinds and stop moments stay.
func _close_retired() -> void:
	for m in moments:
		if m.answer != "" or m.stop or m.has("invite") or m.has("beat"):
			continue
		if str(m.kind) == "moment":
			var s := storylet(str(m.storylet))
			if not s.is_empty() and not is_feed(s) and (bool(s.get("test", false)) or s.has("replies")):
				continue
		elif str(m.kind) == "rule":
			if _group_exists(str(m.get("group", ""))):
				continue
		else:
			continue
		m.answer = NONE
		m.answered_day = int(m.day)
		m.closed = true
		for x in threads.get(str(m.thread), []):
			if str(x.moment) == str(m.id):
				x.read = true


## JSON makes every number a float: a person's relationship stays a float, their memory days and birth year back to ints.
func _people_numbers() -> void:
	for p in people.values():
		p.relation = float(p.relation)
		for x in p.get("log", []):   # (session L2b: the relationship's recent causes)
			x.date = Game.int_date(x.date)
		if p.has("birth_year"):
			p.birth_year = int(p.birth_year)
		var mem: Dictionary = p.get("memory", {})
		for k in mem:
			mem[k] = int(mem[k])
