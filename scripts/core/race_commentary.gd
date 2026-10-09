class_name RaceCommentary
extends RefCounted
## The broadcast of a watched race (GDD 4.3.1, step R4). It only READS the race: the engine's events (Race.events),
## the player's choices (Race.say_log, Race.card_log) and the state of the runners; it never changes the race and
## uses its own dice, so a watched race is the same race with or without it. All texts are in
## data/race_commentary.json (the broadcast), data/coaches.json (the coach's words); see the note in the first.
##
## Who speaks depends on the meet (tier, by level): the stadium announcer alone at small meets, a commentator
## (selostaja) with an expert (asiantuntija) at championships. The commentator calls the race, the expert adds the
## why, between the calls both talk about the field and the season. The coach speaks only about what he can see from
## his spot (Race.coach_sees_at), in his own personality's words. After a decision card the player gets a verdict
## ~10 s later. Lines are never repeated within a race and the last `rules.memory` lines are avoided across races.
##
## Use: var c := RaceCommentary.new(race, {meet, rd, athlete, targets, today, entries}); then c.update() after every
## race step; c.take_new() gives the lines said since the last call: {t, voice, text, id, key, banner}.

## The last lines used (ids), across races.
static var _recent: Array = []

var race: Race
var tier := "announcer"
var style := "yle"
var coach_id := ""
var lines: Array = []             # every line said: {t, voice, text, id, key, banner}
var verdicts: Array = []          # the verdicts given: {t, card, answer, outcome, text, score}
var synth_events: Array = []      # events the commentary made itself (finish, move results, player_finish): for the story
## For the tools: per event type {seen, said, gated, maxed, no_match, silent, dropped}.
var stats := {}

var _cfg: Dictionary
var _rules: Dictionary
var _rng := RandomNumberGenerator.new()
var _athlete: Athlete = null
var _meet: Dictionary = {}
var _rd = null
var _new: Array = []
var _seen := 0
var _say_seen := 0
var _card_seen := 0
var _used := {}
var _counts := {}
var _queue: Array = []
var _last := {"cast": -100.0, "coach": -100.0, "you": -100.0}
var _base_c := {}
var _base_f := {}
var _facts := {}
var _fav_name := ""
var _fillers_said := 0
var _after_mark := 0
var _watch: Array = []
var _verdict_wait: Array = []
var _pending_mover: Race.Runner = null
var _crossed := {}
var _first_t := 0.0
var _coach_called := {}
var _fan_said := 0
var _p_pb := 0.0
var _p_sb := 0.0
var _tier_cfg: Dictionary
var _coach: Dictionary
var _exhausted := false           # the last _pick found lines that fit, all used in this race already
var _last_bar := -100.0           # when a line for an action-bar command was last said


## `ctx`: meet (the meet's dictionary), rd (RaceDay, or null), athlete (or null), targets (RaceDay.targets()),
## today (date dict), entries (the entered meet keys), seed (0 = random), level / tier / style (tools without a meet).
func _init(r: Race, ctx := {}) -> void:
	race = r
	_cfg = Data.race_commentary
	_rules = _cfg.rules
	_meet = ctx.get("meet", {})
	_rd = ctx.get("rd", null)
	_athlete = ctx.get("athlete", null)
	if int(ctx.get("seed", 0)) != 0:
		_rng.seed = int(ctx.seed)
	else:
		_rng.randomize()
	var level: String = str(ctx.get("level", _meet.get("level", "local")))
	tier = str(ctx.get("tier", _cfg.level_tier.get(level, "announcer")))
	style = str(ctx.get("style", _cfg.style_by_meet.get(str(_meet.get("id", "")), _cfg.style_by_level.get(level, "yle"))))
	_tier_cfg = _cfg.tiers[tier]
	coach_id = r.coach_id if r.coach_id != "" else Coaches.id_of(_athlete)
	_coach = Coaches.get_coach(coach_id)
	_build_base(ctx)
	_build_facts(ctx)
	r.decision_needed.connect(func(_d): _pending_mover = r._card_mover)
	if _athlete != null:
		_p_pb = float(_athlete.personal_bests.get(_athlete.main_event, 0.0))
		_p_sb = Rankings.player_season_best(_athlete, _season())


## Forget the lines used in earlier races (tools).
static func reset_memory() -> void:
	_recent.clear()


## The names of the broadcast crew for the header ("Olli Vartiainen & Satu Rinne"), or the announcer's role.
func crew_text() -> String:
	var key := tier if tier != "tv" else style
	var crew: Dictionary = _cfg.crews.get(key, _cfg.crews.stream)
	if not _tier_cfg.expert or str(crew.expert) == "":
		return str(crew.tv)
	return "%s & %s" % [crew.tv, crew.expert]


func tier_label() -> String:
	return str(_tier_cfg.label)


## Lines said since the last call.
func take_new() -> Array:
	var out := _new
	_new = []
	return out


# --- The update, once per race step --------------------------------------------------------------------

func update() -> void:
	_base_c.shape = race.shape
	_base_c.lap = 1 if race._leader == null or race._leader.d < 400.0 else 2
	_base_c.after_mark = _after_mark
	while _seen < race.events.size():
		var ev: Dictionary = race.events[_seen]
		_seen += 1
		if ev.type == "pace":
			_after_mark = maxi(_after_mark, int(ev.mark))
			_base_c.after_mark = _after_mark
		_on_event(ev)
	_card_answers()
	_say_lines()
	_coach_splits()
	_watchers()
	_verdicts_due()
	_crossings()
	_maybe_filler()
	_flush()


# --- Events -> lines -------------------------------------------------------------------------------------

func _on_event(ev: Dictionary) -> void:
	var type: String = ev.type
	if type in ["finish", "close_finish", "photo_finish"] and not ev.get("synth", false):
		return   # (the engine posts these when the last runner is home: the commentary calls them as they happen)
	var st := _stat(type)
	st.seen += 1
	if type == "move":
		_watch.append({"i": int(ev.i), "t0": race.time, "pos0": int(ev.pos), "stage": 0, "player": ev.player,
				"behind0": _gap_behind(race.runners[int(ev.i)])})
	var spec: Dictionary = _cfg.events.get(type, {})
	if spec.is_empty():
		st.silent += 1
		return
	var cf := _ctx(ev)
	var c: Dictionary = cf[0]
	var f: Dictionary = cf[1]
	_coach_event(spec, ev, c, f)
	_fan_event(spec, ev, c, f)
	if not _gate(spec, c):
		st.gated += 1
		return
	if int(_counts.get(type, 0)) >= int(spec.get("max", 99)):
		st.maxed += 1
		return
	if not _crossed.is_empty() and not bool(spec.get("after_finish", false)):
		st.late += 1   # (the winner is home: the race is over, only the news of the finish line is told)
		return
	var voice: String = _tier_cfg.lead
	var list: Array = spec.get(voice, [])
	if list.is_empty():
		st.silent += 1
		return
	var pick := _pick(list, "%s.%s" % [type, voice], c, f)
	if pick.is_empty():
		if _exhausted:
			st.exhausted += 1
		else:
			st.no_match += 1
		return
	var out := [_line(voice, pick, f, type)]
	if _tier_cfg.expert and spec.has("expert") and _rng.randf() < float(_rules.expert_chance):
		var ex := _pick(spec.expert, "%s.expert" % type, c, f)
		if not ex.is_empty():
			out.append(_line("expert", ex, f, type))
	if spec.has("banner") and _match(spec.get("banner_when", {}), c):
		out[0].banner = String(spec.banner).format(f)
	_counts[type] = int(_counts.get(type, 0)) + 1
	st.said += 1
	_enqueue("cast", out, int(spec.get("weight", 5)), bool(spec.get("important", false)), type)


## The conditions of an event with an `or` of gates: a busy pack makes many events, only some are worth a line.
func _gate(spec: Dictionary, c: Dictionary) -> bool:
	var gates: Array = spec.get("gates", [])
	if gates.is_empty():
		return true
	for g in gates:
		if _match(g, c):
			return true
	return false


## [c (conditions: numbers and flags), f (the placeholders: texts)] for an event.
func _ctx(ev: Dictionary) -> Array:
	var c := _base_c.duplicate()
	var f := _base_f.duplicate()
	for k in ev:
		c[k] = ev[k]
	var r: Race.Runner = null
	if ev.has("i"):
		r = race.runners[int(ev.i)]
	var d := float(ev.get("d", Race.DISTANCE))
	var to_go := float(ev.get("to_go", Race.DISTANCE - d))
	c.to_go = to_go
	c.late = to_go <= 200.0
	c.d = d
	c.answer = str(ev.get("answer_to", "")) != ""
	c.kick = bool(ev.get("kick", false))
	c.heat = race.auto_places > 0
	c.player = bool(ev.get("player", false))
	c.leader = int(ev.get("pos", 0)) == 1
	var who := str(ev.get("who", ""))
	c.fav = who != "" and who == _fav_name
	var other := ""
	for k in ["answer_to", "with", "of", "by", "behind", "from"]:
		if str(ev.get(k, "")) != "":
			other = str(ev[k])
			break
	c.involves_player = other != "" and race.player != null and other == race.player.name
	f.name = Race._surname(who) if who != "" else ""
	f.full = who
	f.first = _first_name(r) if r != null else ""
	f.club = r.club if r != null else ""
	f.other = Race._surname(other) if other != "" else ""
	f.to_go = str(roundi(to_go))
	f.m = str(roundi(d))
	f.pos = Race._ordinal(int(ev.get("pos", 1)))
	f.gap = _num(float(ev.get("gap", 0.0)))
	f.mark = str(ev.get("mark", ""))
	f.split = _t1(float(ev.split)) if ev.has("split") else ""
	f.vs = "%.1f" % absf(float(ev.vs_even)) if ev.has("vs_even") else ""
	f.group = str(ev.get("group", ""))
	f.spread = str(roundi(float(ev.spread))) if ev.has("spread") else ""
	f.leader = Race._surname(race._leader.name) if race._leader != null else ""
	f.time = Calendar.format_time(float(ev.time)) if ev.has("time") else ""
	f.margin = "%.2f" % float(ev.margin) if ev.has("margin") else ""
	f.seconds = _num(float(ev.seconds)) if ev.has("seconds") else ""
	f.lost = _num(float(ev.lost)) if ev.has("lost") else ""
	f.place = Race._ordinal(int(ev.place)) if ev.has("place") else ""
	f.place_next = Race._ordinal(int(ev.place) + 1) if ev.has("place") else ""
	f.bell = "Halfway" if race.indoor else "The bell"
	f.bell_l = "halfway" if race.indoor else "the bell"
	c.known = false
	c.personality = ""
	f.tag = ""
	if r != null and not r.is_player and not r.rival.is_empty():
		c.personality = r.personality
		if int(r.rival.get("met", 0)) >= 2 and Data.races.personalities.has(r.personality):
			c.known = true
			f.tag = str(Data.races.personalities[r.personality].name).to_lower()
	return [c, f]


func _stat(type: String) -> Dictionary:
	if not stats.has(type):
		stats[type] = {"seen": 0, "said": 0, "gated": 0, "maxed": 0, "no_match": 0, "exhausted": 0, "silent": 0, "late": 0, "dropped": 0}
	return stats[type]


# --- Picking a variant ----------------------------------------------------------------------------------

## A variant of `list` whose `when` holds for `c` and whose placeholders all have a value in `f`, not used in this race,
## not among the last lines of earlier races if possible (else the one used longest ago). {id, text} or {}.
func _pick(list: Array, key: String, c: Dictionary, f: Dictionary) -> Dictionary:
	var fresh := []
	var old := []
	var fitting := 0
	for i in list.size():
		var v = list[i]
		var text: String = v if v is String else str(v.t)
		var id := "%s.%d" % [key, i]
		if v is Dictionary and v.has("when") and not _match(v.when, c):
			continue
		if not _resolvable(text, f):
			continue
		fitting += 1
		if _used.has(id):
			continue
		(old if id in _recent else fresh).append({"id": id, "text": text})
	_exhausted = fresh.is_empty() and old.is_empty() and fitting > 0   # (all that fit were used in this race)
	if not fresh.is_empty():
		return fresh[_rng.randi_range(0, fresh.size() - 1)]
	if old.is_empty():
		return {}
	var best: Dictionary = old[0]
	var best_at := _recent.find(best.id)
	for o in old:
		var at := _recent.find(o.id)
		if at < best_at:
			best = o
			best_at = at
	return best


static var _holes: RegEx = null


## Do all {placeholders} of the text have a value?
static func _resolvable(text: String, f: Dictionary) -> bool:
	if _holes == null:
		_holes = RegEx.new()
		_holes.compile("\\{(\\w+)\\}")
	for m in _holes.search_all(text):
		var k := m.get_string(1)
		if not f.has(k) or str(f[k]) == "":
			return false
	return true


## Conditions: key: value (equal), key: [a, b] (one of), key: bool, key_min / key_max (numbers). A missing key never matches
## (a missing flag counts as false).
static func _match(when: Dictionary, c: Dictionary) -> bool:
	for k in when:
		var want = when[k]
		if k.ends_with("_min") or k.ends_with("_max"):
			var base: String = k.substr(0, k.length() - 4)
			if not c.has(base):
				return false
			var v := float(c[base])
			if k.ends_with("_min") and v < float(want):
				return false
			if k.ends_with("_max") and v > float(want):
				return false
		elif want is bool:
			if bool(c.get(k, false)) != want:
				return false
		elif want is Array:
			if not c.has(k) or not (c[k] in want):
				return false
		else:
			if not c.has(k) or c[k] != want:
				return false
	return true


## A line made from a pick: the text with its placeholders filled; the variant is taken (no second use in this race).
func _line(voice: String, pick: Dictionary, f: Dictionary, key: String) -> Dictionary:
	_used[pick.id] = true
	return {"voice": voice, "text": String(pick.text).format(f), "id": pick.id, "key": key}


# --- Queue and timing --------------------------------------------------------------------------------------

func _enqueue(chan: String, out: Array, prio: int, important: bool, key: String) -> void:
	for l in out:
		_used[l.id] = true
	_queue.append({"chan": chan, "lines": out, "prio": prio, "important": important, "t0": race.time, "key": key})


func _gap_of(chan: String) -> float:
	match chan:
		"coach": return float(_coach.get("gap_s", 6.0))
		"you": return float(_rules.you_gap_s)
	return float(_rules.gap_s)


func _flush() -> void:
	var now := race.time
	var keep := []
	for item in _queue:
		var limit := float(_rules.stale_important_s) if item.important else float(_rules.stale_s)
		if now - float(item.t0) > limit:
			_stat(item.key).dropped += 1
			for l in item.lines:
				_used.erase(l.id)   # (never said: free to be used later)
		else:
			keep.append(item)
	_queue = keep
	for chan in ["cast", "coach", "you"]:
		while true:
			var best := -1
			for i in _queue.size():
				if _queue[i].chan != chan:
					continue
				if best < 0 or _before(_queue[i], _queue[best]):
					best = i
			if best < 0:
				break
			var q: Dictionary = _queue[best]
			if not q.important and now - float(_last[chan]) < _gap_of(chan):
				break
			_queue.remove_at(best)
			_say_entry(q)
			_last[chan] = now


func _before(a: Dictionary, b: Dictionary) -> bool:
	if a.important != b.important:
		return a.important
	if a.prio != b.prio:
		return a.prio > b.prio
	return a.t0 < b.t0


func _say_entry(q: Dictionary) -> void:
	for l in q.lines:
		l.t = race.time
		_recent.append(l.id)
		while _recent.size() > int(_rules.memory):
			_recent.pop_front()
		lines.append(l)
		_new.append(l)


# --- The coach ---------------------------------------------------------------------------------------------

## What the coach says about an event he can see (his spot: Race.coach_sees_at), in his personality's words.
func _coach_event(spec: Dictionary, ev: Dictionary, c: Dictionary, f: Dictionary) -> void:
	if not spec.has("coach") or race.player == null:
		return
	var key = spec.coach
	if key is Dictionary:
		key = key.get("player" if c.player else "other", "")
	if str(key) == "":
		return
	var d := float(ev.get("d", race.player.d))
	if str(key) == "finish":
		var place := int(ev.get("place", 1))
		key = "finish_win" if place == 1 else ("finish_podium" if place <= 3 else "finish_other")
	elif not race.coach_sees_at(d):
		return
	elif not c.player and absf(d - race.player.d) > float(_rules.coach_near_m):
		return
	_coach_say(str(key), f, ev, false)


## One line of the coach's `lines[key]`, at the chance of his talkativeness; queued on his own channel.
func _coach_say(key: String, f: Dictionary, ev: Dictionary, always: bool) -> void:
	var list: Array = _coach.lines.get(key, [])
	if list.is_empty():
		return
	var cat := key
	if key.begins_with("split_"):
		cat = "split"
	elif key.begins_with("finish_"):
		cat = "finish"
	elif key in ["good", "bad"]:
		cat = "verdict"
	var chance := minf(1.0, float(_rules.coach_chance.get(cat, 0.5)) * float(_coach.get("talk", 1.0)))
	if not always and _rng.randf() >= chance:
		return
	var pick := _pick(list, "coach.%s.%s" % [coach_id, key], {}, f)
	if pick.is_empty():
		return
	var line := _line("coach", pick, f, "coach." + key)
	line.d = float(ev.get("d", race.player.d))   # (where it happened: the tools check that he could see it)
	_enqueue("coach", [line], 5, key.begins_with("finish_") or key == "fall", "coach." + key)


## The coach calls the player's split as they pass his spot at the 200 / 400 / 600 m marks (outdoors he sees 200 and 600
## from his spot at the 200 m start, indoors every one): hard / back / front / ok by how the player looks.
func _coach_splits() -> void:
	var p := race.player
	if p == null or p.down_left > 0.0:
		return
	for m in Race.SPLIT_MARKS:
		if _coach_called.has(m) or not p.marks.has(m):
			continue
		_coach_called[m] = true
		if not race.coach_sees_at(float(m)):
			continue
		var order := race.standings()
		var gap := maxf(0.0, order[0].d - p.d)
		var band := "ok"
		if race.feeling().index >= int(_rules.split_hard_feeling) and m < 600:
			band = "hard"
		elif order[0] == p:
			band = "front"
		elif gap > float(_rules.split_back_gap):
			band = "back"
		var f := _base_f.duplicate()
		f.split = _t1(float(p.marks[m].t))
		f.pos = Race._ordinal(order.find(p) + 1)
		f.gap = _num(gap)
		f.to_go = str(roundi(Race.DISTANCE - m))
		_coach_say("split_" + band, f, {"d": float(m)}, false)


# --- Fans of other runners -----------------------------------------------------------------------------------

func _fan_event(spec: Dictionary, ev: Dictionary, c: Dictionary, f: Dictionary) -> void:
	if not spec.has("fan") or c.player or _fan_said >= 1 or int(ev.get("pos", 9)) > 3 or str(f.first) == "":
		return
	if _rng.randf() >= float(_rules.fan_chance):
		return
	var pick := _pick(_cfg.fan.get(str(spec.fan), []), "fan." + str(spec.fan), c, f)
	if pick.is_empty():
		return
	_fan_said += 1
	_enqueue("cast", [_line("fan", pick, f, "fan")], 2, false, "fan")


# --- The player's own choices ("you" lines) and the verdicts on cards ---------------------------------------------

func _say_lines() -> void:
	while _say_seen < race.say_log.size():
		var s: Dictionary = race.say_log[_say_seen]
		_say_seen += 1
		var list: Array = _cfg.you.get(str(s.key), [])
		if list.is_empty():
			continue
		if str(s.key).begins_with("bar."):
			if race.time - _last_bar < float(_rules.bar_gap_s):
				continue   # (a player who taps the bar often does not need an answer to every tap)
			_last_bar = race.time
		var f := _base_f.duplicate()
		f.to_go = str(int(s.to_go))
		var pick := _pick(list, "you." + str(s.key), {}, f)
		if not pick.is_empty():
			_enqueue("you", [_line("you", pick, f, "you")], 5, false, "you")


## A new answered card: remember how things stood, to judge it `verdict_after_s` later.
func _card_answers() -> void:
	while _card_seen < race.card_log.size():
		var e: Dictionary = race.card_log[_card_seen]
		if str(e.answer) == "":
			return   # (still open: the loop waits for the answer; cards come one at a time)
		_card_seen += 1
		var p := race.player
		var order := race.standings()
		var mover: Race.Runner = _pending_mover if str(e.id) == "move" else null
		_verdict_wait.append({"due": race.time + float(_rules.verdict_after_s), "card": e.id, "answer": e.answer,
				"pos0": order.find(p) + 1, "gap0": maxf(0.0, order[0].d - p.d), "feel0": int(race.feeling().index),
				"mover": mover, "dm0": (mover.d - p.d) if mover != null else 0.0})


func _verdicts_due() -> void:
	var rest := []
	for v in _verdict_wait:
		if race.time < float(v.due):
			rest.append(v)
		else:
			_give_verdict(v)
	_verdict_wait = rest


## How a choice is working out, from what changed since: places gained (dpos), metres closed on the leader (dgap), how much
## harder it feels (dfeel, the Feeling word), and the card's own signs: the mover (stay close with "go with" / "counter";
## the gap closing or not with "let go"), still boxed in, the kick dying, the Feeling word for a push or an easy lap.
## Above verdict_good = good, below its minus = bad.
func _verdict_score(v: Dictionary, p: Race.Runner, pos: int, gap: float, mover: Race.Runner) -> float:
	var dpos := float(int(v.pos0) - pos)
	var dgap := float(v.gap0) - gap
	var dfeel := float(int(race.feeling().index) - int(v.feel0))
	var hurt := maxf(float(race.feeling().index) - 1.0, 0.0)   # (hurting or empty)
	match str(v.card):
		"move":
			if mover != null and not mover.done:
				var ahead := mover.d - p.d
				if v.answer == "wait":
					return (float(v.dm0) - ahead) / 3.0 + 0.5 * dpos
				return (1.5 if absf(ahead) <= 3.0 else (-1.5 if ahead > 10.0 else 0.0)) + 0.5 * dpos - 0.7 * hurt
		"box":
			return (-1.5 if p.boxed else 1.0) + 0.5 * dpos
		"dropped":
			if v.answer == "dig":
				return dgap / 3.0 - 0.6 * hurt
			return (dgap + 8.0) / 6.0   # (running your own pace: a gap that grows a little is expected)
		"break":
			match str(v.answer):
				"lead": return 1.5 if pos <= 2 else (-1.5 if pos >= 4 else 0.0)
				"shoulder": return 1.5 if pos <= 4 and gap <= 5.0 else (-1.5 if gap > 12.0 else 0.0)
				_: return 1.5 if gap <= 8.0 else (-1.5 if gap > 16.0 else 0.0)
		"straight":
			return dpos + dgap / 6.0
		"kick":
			return (-2.0 if p.kick_died else 0.0) + dpos + dgap / 6.0
		"bell":
			match str(v.answer):
				"push": return dgap / 3.0 - 0.8 * hurt + 0.5 * dpos
				"ease": return 0.5 * dpos + dgap / 6.0 - 0.4 * dfeel
				_: return 0.5 * dpos + dgap / 6.0 - 0.5 * hurt
	return dpos + dgap / 4.0 - 0.8 * hurt


## good / bad / flat (see _verdict_score), and the line for it.
func _give_verdict(v: Dictionary) -> void:
	var p := race.player
	if p == null or p.done or p.status != "":
		return
	var order := race.standings()
	var pos := order.find(p) + 1
	var gap := maxf(0.0, order[0].d - p.d)
	var dpos := int(v.pos0) - pos
	var mover: Race.Runner = v.mover
	var score := _verdict_score(v, p, pos, gap, mover)
	var edge := float(_rules.verdict_good)
	var outcome := "good" if score >= edge else ("bad" if score <= -edge else "flat")
	if outcome == "flat" and _rng.randf() >= float(_rules.verdict_flat_chance):
		return   # (nothing to say about a choice that has not changed much)
	var f := _base_f.duplicate()
	f.pos = Race._ordinal(pos)
	f.gap = _num(gap)
	f.to_go = str(roundi(Race.DISTANCE - p.d))
	if absi(dpos) > 0 and (dpos > 0) == (outcome == "good"):
		f.dpos = str(absi(dpos))
	if mover != null:
		f.name = Race._surname(mover.name)
	var vd: Dictionary = _cfg.verdicts
	var pick := {}
	var list: Array = vd.get(str(v.card), {}).get(str(v.answer), {}).get(outcome, [])
	if outcome != "flat" and not list.is_empty():
		pick = _pick(list, "verdict.%s.%s.%s" % [v.card, v.answer, outcome], {}, f)
	if pick.is_empty():
		pick = _pick(vd.any[outcome], "verdict.any.%s" % outcome, {}, f)
	if pick.is_empty():
		return
	var out := [_line("you", pick, f, "verdict")]
	verdicts.append({"t": race.time, "d": roundi(p.d), "card": v.card, "answer": v.answer, "outcome": outcome, "text": out[0].text, "score": score})
	_enqueue("you", out, 6, false, "verdict")
	if outcome != "flat" and race.coach_sees():
		_coach_say(outcome, f, {}, false)


# --- Moves: did they get away? -------------------------------------------------------------------------------

## The runner behind `r`: the gap in metres (99 for the last runner).
func _gap_behind(r: Race.Runner) -> float:
	var order := race.standings()
	var i := order.find(r)
	if i < 0 or i >= order.size() - 1:
		return 99.0
	return r.d - order[i + 1].d


## A move is followed: `move_check_s` later it is judged (got away / caught / fading), and what got away is judged again
## at `move_final_s` (held / caught). Events the engine does not have; the commentary makes them from the runners.
func _watchers() -> void:
	var rest := []
	for w in _watch:
		var r: Race.Runner = race.runners[int(w.i)]
		if r.done or r.status != "":
			continue
		var age := race.time - float(w.t0)
		if int(w.stage) == 0 and age >= float(_rules.move_check_s):
			var res := _move_result(r, w)
			if res == "move_away":
				w.stage = 1
				_synth(res, r, {"gap": snappedf(_gap_behind(r), 0.1)})
				rest.append(w)
			elif res == "":
				w.stage = 1   # (undecided: judge again at the final check)
				rest.append(w)
			else:
				_synth(res, r, {})
		elif int(w.stage) == 1 and age >= float(_rules.move_final_s):
			var res := _move_result(r, w)
			if res == "move_away":
				res = "move_held"
			if res != "":
				_synth(res, r, {"gap": snappedf(_gap_behind(r), 0.1)})
		else:
			rest.append(w)
	_watch = rest


func _move_result(r: Race.Runner, w: Dictionary) -> String:
	var order := race.standings()
	var pos := order.find(r) + 1
	var behind := _gap_behind(r)
	if pos - int(w.pos0) >= int(_rules.move_fade_places):
		return "move_fading"
	if pos <= int(w.pos0) and behind >= float(_rules.move_away_gap):
		return "move_away"
	if behind <= float(_rules.move_caught_gap) and pos >= int(w.pos0) and float(w.behind0) > behind + 1.0:
		return "move_caught"
	if behind <= float(_rules.move_caught_gap):
		return "move_caught"
	return ""


## An event of the commentary's own (not in Race.events): {type, t, who, i, player, d, pos, gap} + extra.
func _synth(type: String, r: Race.Runner, extra := {}) -> void:
	var order := race.standings()
	var ev := {"type": type, "t": snappedf(race.time, 0.1), "who": r.name, "i": r.index, "player": r.is_player,
			"d": roundi(r.d), "pos": order.find(r) + 1, "gap": snappedf(maxf(0.0, order[0].d - r.d), 0.1), "synth": true}
	ev.merge(extra, true)
	synth_events.append(ev)
	_on_event(ev)


# --- The finish: as they cross the line ---------------------------------------------------------------------------

func _crossings() -> void:
	var done := race.runners.filter(func(r): return r.done and r.status == "" and not _crossed.has(r.index))
	if done.is_empty():
		return
	done.sort_custom(func(a, b): return a.t < b.t)
	for r in done:
		_crossed[r.index] = true
		var k := _crossed.size()
		var marks := _record_flags(r)
		var extra := {"time": snappedf(r.t, 0.01), "place": k, "pb": marks.pb, "sb": marks.sb, "d": 800}
		if k == 1:
			_first_t = r.t
			_synth("finish", r, extra)
		else:
			var margin: float = r.t - _prev_t
			var eng: Dictionary = Data.races.engine
			if margin < float(eng.close_finish_s) and k <= 4:
				var prev: Race.Runner = _prev_runner
				_synth("photo_finish" if margin < float(eng.photo_finish_s) else "close_finish", prev,
						{"with": r.name, "place": k - 1, "margin": snappedf(margin, 0.01), "d": 800})
			if r.is_player:
				_synth("player_finish", r, extra)
		_prev_t = r.t
		_prev_runner = r


var _prev_t := 0.0
var _prev_runner: Race.Runner = null


## Did the runner's time beat their PB / season best? (Before the result is recorded.) {pb, sb}
func _record_flags(r: Race.Runner) -> Dictionary:
	var t := snappedf(r.t, 0.01)
	if r.is_player:
		return {"pb": _p_pb == 0.0 or t < _p_pb, "sb": _p_sb == 0.0 or t < _p_sb}
	var rv: Dictionary = r.rival
	if rv.is_empty():
		return {"pb": false, "sb": false}
	var pb := float(rv.get("pb", 0.0)) > 0.0 and t < float(rv.pb)
	var sb_ok := int(rv.get("sb_season", -1)) == _season()
	var sb := pb or (sb_ok and t < float(rv.get("sb", 0.0)))
	return {"pb": pb, "sb": sb}


# --- Talk between the calls ------------------------------------------------------------------------------------

func _maybe_filler() -> void:
	if race.finished or race.time < float(_rules.filler_after_s) or not race.pending.is_empty():
		return
	if _fillers_said >= int(_rules.filler_max.get(tier, 0)):
		return
	if race.time - float(_last.cast) < float(_rules.filler_gap_s):
		return
	for q in _queue:
		if q.chan == "cast":
			return
	if race._leader != null and race._leader.d > 720.0:
		return
	var c := _base_c.duplicate()
	var f := _base_f.duplicate()
	var voices := [str(_tier_cfg.lead)]
	if _tier_cfg.expert:
		voices.append("expert")
	var cands := []
	var total := 0.0
	for fl in _cfg.fillers:
		if not (str(fl.voice) in voices):
			continue
		var id := "filler." + str(fl.id)
		if _used.has(id):
			continue
		if fl.has("when") and not _match(fl.when, c):
			continue
		if not _resolvable(str(fl.t), f):
			continue
		var w := float(fl.get("weight", 1)) * (0.3 if id in _recent else 1.0)
		cands.append([fl, w])
		total += w
	if cands.is_empty():
		return
	var x := _rng.randf() * total
	var chosen: Dictionary = cands[0][0]
	for cw in cands:
		x -= cw[1]
		if x < 0.0:
			chosen = cw[0]
			break
	var id := "filler." + str(chosen.id)
	var out := [{"voice": str(chosen.voice), "text": str(chosen.t).format(f), "id": id, "key": "filler"}]
	if _tier_cfg.expert and chosen.has("reply") and _resolvable(str(chosen.reply), f):
		out.append({"voice": "expert", "text": str(chosen.reply).format(f), "id": id + ".reply", "key": "filler"})
	_fillers_said += 1
	_enqueue("cast", out, 1, false, "filler")


# --- The context of the race and the facts the broadcast knows ------------------------------------------------

func _season() -> int:
	return int(_meet.date.year) if _meet.has("date") else 2027


func _build_base(ctx: Dictionary) -> void:
	var kind := "race"
	if _rd != null and _rd.round_index < _rd.rounds.size():
		kind = str(_rd.rounds[_rd.round_index])
	_base_c = {"tier": tier, "style": style, "indoor": race.indoor, "kind": kind, "chase": race._mix == "chase",
			"shape": race.shape, "lap": 1, "after_mark": 0, "heat": race.auto_places > 0}
	_base_f = {"field": str(race.runners.size()), "meet": str(_meet.get("name", "the meet")),
			"round": _rd.round_name() if _rd != null else "Race", "coach_name": str(_coach.name)}
	var p := race.player
	if p != null:
		_base_f.pname = Race._surname(p.name)
		_base_f.pfull = p.name
	_base_f.coach_name = str(_coach.name)


func _build_facts(ctx: Dictionary) -> void:
	var f := _base_f
	var p := race.player
	var season := _season()
	if _athlete != null:
		f.pname = _athlete.last_name
		f.pfull = _athlete.full_name()
		f.pclub = str(Data.get_club(_athlete.club_id).get("name", ""))
		var date: Dictionary = _meet.get("date", ctx.get("today", {}))
		if not date.is_empty():
			f.page = str(_athlete.age_on(date))
		var pb := float(_athlete.personal_bests.get(_athlete.main_event, 0.0))
		var sb := Rankings.player_season_best(_athlete, season)
		_base_c.p_has_mark = pb > 0.0
		if pb > 0.0:
			f.ppb_text = ("a season best of %s" % Calendar.format_time(sb)) if sb > 0.0 else ("a best of %s" % Calendar.format_time(pb))
		var n := 1
		for r in _athlete.results:
			if int(r.date.year) == season:
				n += 1
		f.p_race_no = _ordinal_word(n)
	elif p != null:
		f.pclub = p.club
		_base_c.p_has_mark = false
	if not f.has("pclub") or str(f.pclub) == "":
		f.erase("pclub")
	if not _base_c.has("p_has_mark"):
		_base_c.p_has_mark = false
	# The favourite: the best mark (season best of the year, else PB) of the other runners.
	var best_t := 1.0e9
	var best: Race.Runner = null
	var clubs := {}
	var sbs := []
	for r in race.runners:
		if r.club != "":
			clubs[r.club] = true
		if r.is_player or r.rival.is_empty():
			continue
		var rv: Dictionary = r.rival
		var t := float(rv.get("pb", 0.0))
		var sb_ok := int(rv.get("sb_season", -1)) == season and float(rv.get("sb", 0.0)) > 0.0
		if sb_ok:
			t = float(rv.sb)
			sbs.append(t)
		if t > 0.0 and t < best_t:
			best_t = t
			best = r
	if best != null:
		_fav_name = best.name
		f.fav = Race._surname(best.name)
		f.fav_full = best.name
		f.fav_club = best.club if best.club != "" else "his club"
		var sbv := int(best.rival.get("sb_season", -1)) == season
		f.fav_mark_text = ("a season best of %s" if sbv else "a personal best of %s") % Calendar.format_time(best_t)
		if best.club == "":
			f.erase("fav_club")
		if int(best.rival.get("met", 0)) >= 2 and Data.races.personalities.has(best.personality):
			f.fav_style_text = {"front": "to run from the front", "pack": "to sit in the pack and cover the moves",
					"kicker": "to wait and kick late", "surger": "to throw in a surge in the middle of the race"}.get(best.personality, "")
	if clubs.size() >= 3:
		f.field_clubs = str(clubs.size())
	# A rival the player has raced at least twice: the personality tag.
	for r in race.runners:
		if r.is_player or r.rival.is_empty():
			continue
		if int(r.rival.get("met", 0)) >= 2 and Data.races.personalities.has(r.personality):
			f.tagged = Race._surname(r.name)
			f.tagged_met = _times_word(int(r.rival.met))
			f.tagged_tag = str(Data.races.personalities[r.personality].name).to_lower()
			break
	# The player's rank on season bests.
	if _athlete != null and sbs.size() >= 3:
		var mine := Rankings.player_season_best(_athlete, season)
		if mine > 0.0:
			var rank := 1
			for t in sbs:
				if t < mine:
					rank += 1
			f.p_sb_rank = "%s of %d" % [Race._ordinal(rank), sbs.size() + 1]
	if _meet.has("description"):
		f.meet_desc = str(_meet.description)
	# The next meet the player has entered.
	var today: Dictionary = ctx.get("today", {})
	if not today.is_empty() and not _meet.is_empty():
		var nxt := {}
		for key in ctx.get("entries", []):
			var m := Calendar.get_meet(str(key))
			if m.is_empty() or Calendar.date_key(m.date) <= Calendar.date_key(_meet.date):
				continue
			if nxt.is_empty() or Calendar.date_key(m.date) < Calendar.date_key(nxt.date):
				nxt = m
		if not nxt.is_empty():
			var days := Calendar.days_between(_meet.date, nxt.date)
			f.next_meet = str(nxt.name)
			f.next_in = ("%d days" % days) if days < 14 else ("%d weeks" % roundi(days / 7.0))
	# The times to beat (sections: medal / top 8; heats: the time-spot cutoff so far).
	var t: Dictionary = ctx.get("targets", {})
	if float(t.get("medal", 0.0)) > 0.0:
		f.target_medal = Calendar.format_time(float(t.medal))
	if float(t.get("top8", 0.0)) > 0.0:
		f.target_top8 = Calendar.format_time(float(t.top8))
	if float(t.get("cutoff", 0.0)) > 0.0:
		f.target_cutoff = Calendar.format_time(float(t.cutoff))


# --- Small helpers ---------------------------------------------------------------------------------------------

func _first_name(r: Race.Runner) -> String:
	if r.rival.has("first_name"):
		return str(r.rival.first_name)
	return r.name.get_slice(" ", 0)


## 31.2 -> "31.2", 63.4 -> "1:03.4".
static func _t1(seconds: float) -> String:
	var m := floori(seconds / 60.0)
	var s := seconds - m * 60.0
	if m == 0:
		return "%.1f" % s
	return "%d:%04.1f" % [m, s]


static func _num(x: float) -> String:
	return str(roundi(x)) if x >= 10.0 else "%.1f" % x


static func _times_word(n: int) -> String:
	return {2: "twice", 3: "three times", 4: "four times", 5: "five times"}.get(n, "%d times" % n)


static func _ordinal_word(n: int) -> String:
	var words := ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]
	return words[n - 1] if n >= 1 and n <= words.size() else Race._ordinal(n)
