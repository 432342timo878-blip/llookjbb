class_name WeekCauses
extends RefCounted
## Causes everywhere (GDD 4.10 decision 2, "L2b's questions", session L2b): turns what the game RECORDED into rows of words +
## value + one cause, each with the exact numbers for a tap. Reading only: it never draws a die or changes a number.
## A row: {kind, id, icon, title, value (two decimals / the full words), short (the planner's value), tone ("good" / "bad" /
## "warn" / "plain"), cause (<= ~6 words), detail (lines for the tap), main (shown in the planner's list), group (the order of
## importance, L2b decision 7), size (biggest first inside a group)}.
## Sources: the week report (WeekSim.end_week + Game._end_week: parts, sources, stimulus, mods, attrs, slots), HealthSystem's
## strain_log, MindSystem's causes + drift, the people's relationship logs (StoryletSystem._note_relation), the coach's trust
## causes + last_drift, the day log (life_parts, loads), SchoolSystem.tests_log, the moments (invitations). Texts: data/causes.json.

const GROUPS := {"injury": 0, "body": 1, "attr": 2, "mood": 3, "person": 4, "trust": 4, "test": 5, "slot": 6, "mental": 6, "invite": 7, "tired": 8}


static func cfg() -> Dictionary:
	return Data.causes


## Every row of the week in report `r`, in the order of importance: the main ones first (injuries and areas over their line,
## attributes biggest first, moods and people whose word changed, tests, the slots' effects, invitations), then the rest.
static func rows(r: Dictionary) -> Array:
	if r.is_empty():
		return []
	var out := []
	out.append_array(injury_rows(r))
	out.append_array(body_rows(r))
	out.append_array(attr_rows(r))
	out.append_array(mood_rows(r))
	out.append_array(people_rows(r))
	out.append_array(test_rows(r))
	out.append_array(slot_rows(r))
	out.append_array(mental_rows(r))
	out.append_array(invite_rows(r))
	out.sort_custom(func(x, y):
		if bool(x.main) != bool(y.main):
			return bool(x.main)
		if int(x.group) != int(y.group):
			return int(x.group) < int(y.group)
		return float(x.size) > float(y.size))
	return out


static func _row(kind: String, id: String, icon: String, title: String, value: String, tone: String, cause: String, detail: Array,
		main: bool, size: float) -> Dictionary:
	return {"kind": kind, "id": id, "icon": icon, "title": title, "value": value, "short": value, "tone": tone, "cause": cause,
			"detail": "\n".join(detail.filter(func(x): return str(x) != "")), "main": main, "group": int(GROUPS.get(kind, 9)), "size": size}


# --- The week -----------------------------------------------------------------------------------------------------------------

## The week's 7 date keys -> day index.
static func _week_keys(monday: Dictionary) -> Dictionary:
	var out := {}
	for i in 7:
		out[Calendar.date_key(Game.add_days(monday, i))] = i
	return out


static func _in_week(r: Dictionary, date: Dictionary) -> bool:
	var k := Calendar.date_key(date)
	return k >= Calendar.date_key(r.monday) and k <= Calendar.date_key(Game.add_days(r.monday, 6))


## The day log entries of the week, in order (the log keeps about two weeks).
static func _log_of(r: Dictionary) -> Array:
	return Game.day_log.filter(func(e): return _in_week(r, e.date))


static func _day_name(i: int) -> String:
	return str(Training.DAY_NAMES[clampi(i, 0, 6)])


static func _days_text(days: Array) -> String:
	var names := []
	for d in days:
		names.append(_day_name(int(d)))
	return ", ".join(names)


## A number with its sign: two decimals, three when it is that small (so a recorded part never reads +0.00).
static func num(v: float) -> String:
	return RaceRecap.signed(v, 2 if absf(v) >= 0.01 or v == 0.0 else 3)


static func _arrow(v: float) -> String:
	return "▲" if v > 0.0 else "▼"


# --- Attributes -----------------------------------------------------------------------------------------------------------------

## Which days each source of the week's stimulus trained: {session id or "race:<meet>": [day index]} (the day log; a race by
## its meet).
static func _source_days(r: Dictionary) -> Dictionary:
	var out := {}
	var keys := _week_keys(r.monday)
	for e in _log_of(r):
		var i := int(keys.get(Calendar.date_key(e.date), 0))
		if str(e.race) != "":
			out["race:" + str(e.race)] = [i]
			continue
		for sid in e.sessions:
			var list: Array = out.get(str(sid), [])
			list.append(i)
			out[str(sid)] = list
	return out


## The parts of attribute `id`'s change in report `r`: [{key, label, short, value, share}] (sources of the training first, by
## their share of the week's stimulus; then the coach, growing up, not training it and the week's other changes).
static func attr_parts(r: Dictionary, id: String) -> Array:
	var c: Dictionary = cfg().attr
	var out := []
	var p: Dictionary = r.get("parts", {}).get(id, {})
	var trained := float(p.get("trained", 0.0))
	if trained != 0.0:
		var days := _source_days(r)
		var src: Dictionary = r.get("sources", {}).get(id, {})
		var total := float(r.get("stimulus", {}).get(id, 0.0))
		var sum := 0.0
		for k in src:
			sum += float(src[k])
		if total <= 0.0:
			total = sum
		for k in src:
			var share := float(src[k]) / total if total > 0.0 else 0.0
			var label := ""
			var short := ""
			if str(k).begins_with("race:"):
				var mk := str(k).substr(5)
				var meet := Calendar.get_meet(mk)
				var day := _days_text(days.get(str(k), []))
				label = str(c.source_race).format({"meet": str(meet.get("name", mk)), "day": day})
				short = str(c.short_race).format({"day": day})
			else:
				var list: Array = days.get(str(k), [])
				var n := list.size()
				var name := Icons.session_short(str(k))
				label = str(c.source_session if n > 1 else c.source_session_one).format({"n": n, "session": name, "days": _days_text(list)})
				short = str(c.short_session if n > 1 else c.short_session_one).format({"n": n, "session": name})
			out.append({"key": str(k), "label": label.replace(" ()", ""), "short": short, "value": trained * share, "share": share, "source": true})
		if total > 0.0 and total - sum > total * 0.001:
			var share := (total - sum) / total
			out.append({"key": "unrecorded", "label": str(c.source_unrecorded), "short": "", "value": trained * share, "share": share, "source": true})
		out.sort_custom(func(x, y): return float(x.share) > float(y.share))
	for key in p:
		if str(key) == "trained" or float(p[key]) == 0.0:
			continue
		var kind := str(key).get_slice(":", 0)
		var meet := Calendar.get_meet(str(key).get_slice(":", 1)) if str(key).contains(":") and kind != "mental" else {}
		var fill := {"meet": str(meet.get("name", "")), "value": num(float(p[key]))}
		if kind == "mental":   # (session L3b1: "mental:<kind>", the session and its day)
			var mk := str(key).get_slice(":", 1)
			fill.session = str(Data.mind.mental.kinds.get(mk, {}).get("short", mk))
			fill.day = _days_text(_mental_days(r).get(mk, []))
		var label := str(c.parts.get(kind, kind)).format(fill).replace(" ()", "")
		out.append({"key": str(key), "label": label, "short": str(c.parts_short.get(kind, kind)), "value": float(p[key]), "share": 0.0, "source": false})
	return out


static func attr_rows(r: Dictionary) -> Array:
	var c: Dictionary = cfg().attr
	var out := []
	var attrs: Dictionary = r.get("attrs", {})
	var recorded := r.has("parts")
	if attrs.is_empty() and not recorded:
		attrs = r.get("changes", {})   # (a report from before L2b: only Sunday's changes, without their causes)
	var hide := float(cfg().small.hide_below)
	var main_at := float(cfg().small.main)
	var ids := attrs.keys()
	ids.sort()
	for id in ids:
		var def := Data.get_attribute(str(id))
		if def.is_empty() or bool(def.get("hidden", false)):
			continue
		var b := float(attrs[id].before)
		var a := float(attrs[id].after)
		var d := a - b
		if absf(d) < hide:
			continue
		var name := str(def.get("name", id))
		var lines := [str(c.detail_head).format({"name": name, "before": "%.2f" % b, "after": "%.2f" % a, "delta": num(d)})]
		var parts := attr_parts(r, str(id)) if recorded else []
		var cause_parts := parts.duplicate()
		cause_parts.sort_custom(func(x, y): return absf(float(x.value)) > absf(float(y.value)))
		var shorts := []
		for x in cause_parts:
			if str(x.short) != "" and shorts.size() < 2 and (signf(float(x.value)) == signf(d) or shorts.is_empty()):
				shorts.append(str(x.short))
		var trained := float(r.get("parts", {}).get(str(id), {}).get("trained", 0.0))
		if trained != 0.0:
			lines.append(str(c.trained).format({"value": num(trained)}))
		for x in parts:
			if bool(x.source):
				lines.append("   " + str(c.source).format({"label": str(x.label), "pct": roundi(float(x.share) * 100.0), "value": num(float(x.value))}))
		for x in parts:
			if not bool(x.source):
				lines.append(str(x.label))
		var mods: Dictionary = r.get("mods", {})
		var total := float(r.get("stimulus", {}).get(str(id), 0.0))
		var lost := float(mods.get("tired", {}).get(str(id), 0.0))
		if trained != 0.0 and lost > 0.0 and total + lost > 0.0:
			var pct := roundi(lost / (total + lost) * 100.0)
			if pct >= 1:
				lines.append(str(c.tired).format({"days": _days_text(mods.get("tired_days", [])), "pct": pct}))
		var extra := float(mods.get("motivation", {}).get(str(id), 0.0))
		if trained != 0.0 and extra != 0.0 and total - extra > 0.0:
			var pct := roundi(absf(extra) / (total - extra) * 100.0)
			if pct >= 1:
				lines.append(str(c.motivation_up if extra > 0.0 else c.motivation_down).format({"pct": pct}))
		var cause := " + ".join(shorts)
		if roundi(b) != roundi(a):
			lines.append(str(c.whole).format({"before": roundi(b), "after": roundi(a)}))
		if not recorded:
			lines.append(str(c.not_recorded))
		var row := _row("attr", str(id), WeekPlanner._attr_icon(str(id), str(def.get("category", ""))), name, num(d),
				"good" if d > 0.0 else "bad", cause, lines, absf(d) >= main_at, absf(d))
		row.short = RaceRecap.signed(d, 1)
		row.whole = roundi(a) if roundi(b) != roundi(a) else -1
		out.append(row)
	return out


# --- The body -------------------------------------------------------------------------------------------------------------------

static func _health() -> HealthSystem:
	var h := Game.get_system("health") as HealthSystem
	return h if h != null and HealthSystem.model_enabled and h.started else null


static func sore_line() -> float:
	return float(Data.health.soreness.levels[HealthSystem.SORE - 1])


static func area_name(area_id: String) -> String:
	for area in HealthSystem.areas():
		if str(area.id) == area_id:
			return str(area.name)
	return area_id


## Injuries and illnesses that started in the week (and the ones still going).
static func injury_rows(r: Dictionary) -> Array:
	var h := _health()
	var out := []
	if h == null:
		return out
	var c: Dictionary = cfg().injury
	for inj in h.injuries + h.history:
		if not _in_week(r, inj.started) and not inj in h.injuries:
			continue
		var data := Data.get_injury(str(inj.id))
		if data.is_empty():
			continue
		var tier := str(HealthUI.TIER_NAMES.get(str(data.tier), str(data.tier)))
		var healed: bool = inj.has("healed")
		var range_text := ""
		for x in h.active():
			if str(x.get("id", "")) == str(inj.id):
				range_text = str(x.get("range", ""))
		var cause := str(c.cause_healed if healed else c.cause).format({"tier": tier, "range": range_text}).trim_suffix(" · back in ")
		out.append(_row("injury", str(inj.id), "triangle-alert", str(data.get("name", "")), "", "bad", cause,
				[str(data.get("description", ""))], _in_week(r, inj.started), 100.0))
	return out


## The body areas over the week (HealthSystem.strain_log): where each ended against the sore line, what raised it; then
## tiredness Monday -> Sunday.
static func body_rows(r: Dictionary) -> Array:
	var out := []
	var c: Dictionary = cfg().body
	var h := _health()
	if h != null and not h.strain_log.is_empty():
		var lo := Calendar.date_key(r.monday)
		var hi := Calendar.date_key(Game.add_days(r.monday, 6))
		var days: Array = h.strain_log.filter(func(x): return int(x.date) >= lo and int(x.date) <= hi)
		if not days.is_empty():
			var line := sore_line()
			for area in HealthSystem.areas():
				var aid := str(area.id)
				var first: Dictionary = days[0]
				var end := float(days.back().after.get(aid, 0.0))
				var start := float(first.after.get(aid, 0.0)) - _sum(first.add.get(aid, {})) + float(first.fade.get(aid, 0.0))
				var added := 0.0
				for x in days:
					added += _sum(x.add.get(aid, {}))
				if roundi(end) == roundi(start) and added < 0.5:
					continue
				if end < 1.0 and added < 1.0:
					continue
				var tone := "bad" if end >= line else ("warn" if end >= line - 15.0 else "plain")
				var cause := _top_adds(days, aid, 2)
				if cause == "":
					cause = str(c.area_cause_rest)
				out.append(_row("body", aid, "triangle-alert" if tone != "plain" else "activity", str(area.name),
						str(c.area_value).format({"before": roundi(maxf(start, 0.0)), "after": roundi(end)}), tone, cause,
						area_detail(aid, days, end), end >= line, end))
	var f0 := float(r.get("fatigue_start", 0.0))
	var f1 := float(r.get("fatigue_end", 0.0))
	var tline := float(Data.planner.body.tired_warning)
	var peak := float(r.get("fatigue_peak", f1))
	var keys := _week_keys(r.monday)
	var peak_day := ""
	var loads := []
	for e in _log_of(r):
		var i := int(keys.get(Calendar.date_key(e.date), 0))
		if absf(float(e.fatigue) - peak) < 0.01:
			peak_day = _day_name(i)
		loads.append({"day": i, "load": float(e.load)})
	loads.sort_custom(func(x, y): return float(x.load) > float(y.load))
	var heavy := []
	for x in loads.slice(0, 3):
		if float(x.load) > 0.0:
			heavy.append(str(c.tired_day_item).format({"day": _day_name(int(x.day)), "load": roundi(float(x.load))}))
	var lines := [str(c.tired_detail).format({"before": roundi(f0), "after": roundi(f1), "peak": roundi(peak), "day": peak_day, "line": roundi(tline)})]
	if not heavy.is_empty():
		lines.append(str(c.tired_days).format({"list": ", ".join(heavy)}))
	lines.append(str(c.tired_helps))
	if roundi(f0) != roundi(f1) or f1 >= tline - 15.0:
		out.append(_row("tired", "fatigue", "gauge", str(c.tired_title), str(c.tired_value).format({"before": roundi(f0), "after": roundi(f1)}),
				"bad" if f1 >= tline else ("warn" if f1 >= tline - 15.0 else "plain"),
				str(c.tired_cause).format({"peak": roundi(peak), "day": peak_day}).strip_edges(), lines, f1 >= tline, f1))
	return out


## The planner's tiredness tap: where it is now and the last played days (the day log: tiredness after each day and its load).
static func tired_now() -> String:
	var c: Dictionary = cfg().body
	var lines := []   # (the bar already says the % and its line)
	var items := []
	for e in Game.day_log.slice(-7):
		items.append(str(c.tired_now_item).format({"day": _day_name(Calendar.weekday(e.date)), "f": roundi(float(e.fatigue)), "load": roundi(float(e.load))}))
	if not items.is_empty():
		lines.append(str(c.tired_now_days).format({"list": ", ".join(items)}))
	lines.append(str(c.tired_helps))
	return "\n".join(lines)


static func _sum(d: Dictionary) -> float:
	var t := 0.0
	for k in d:
		t += float(d[k])
	return t


static func _source_name(src: String) -> String:
	return str(cfg().body.race_word) if src == "race" else Icons.session_short(src)


## "Tue tempo + Sat race": the `n` biggest additions of an area over `days` (strain_log entries).
static func _top_adds(days: Array, aid: String, n: int) -> String:
	var adds := []
	for x in days:
		var parts: Dictionary = x.add.get(aid, {})
		for src in parts:
			adds.append({"date": int(x.date), "src": str(src), "v": float(parts[src])})
	adds.sort_custom(func(a, b): return float(a.v) > float(b.v))
	var names := []
	for a in adds.slice(0, n):
		names.append("%s %s" % [_key_day(int(a.date)), _source_name(str(a.src)).to_lower()])
	return " + ".join(names)


static func _key_day(key: int) -> String:
	var d := {"year": key / 10000, "month": (key / 100) % 100, "day": key % 100}
	return _day_name(Calendar.weekday(d))


## What raised an area and what helps, from strain_log entries `days` (each addition by day and session, what faded, what made
## it build faster); `now` = the strain it is at. With no entries yet (an older save) the old rebuilt causes (soreness_info).
static func area_detail(aid: String, days: Array, now: float) -> Array:
	var c: Dictionary = cfg().body
	var lines := [str(c.detail_head).format({"name": area_name(aid), "now": roundi(now), "line": roundi(sore_line())})]
	var h := _health()
	if days.is_empty():
		lines.append(str(c.none_yet))
		if h != null:
			var info := h.soreness_info(aid)
			lines.append_array(info.causes)
			if str(info.helps) != "":
				lines.append(str(c.helps).format({"text": str(info.helps)}))
		return lines
	var items := []
	var faded := 0.0
	var tired := []
	var jump := 1.0
	var used := 1.0
	var growth := 1.0
	var old := 1.0
	for x in days:
		var parts: Dictionary = x.add.get(aid, {})
		for src in parts:
			if float(parts[src]) >= 0.5:
				items.append(str(c.added_item).format({"n": roundi(float(parts[src])), "day": _key_day(int(x.date)),
						"session": _source_name(str(src))}))
		faded += float(x.fade.get(aid, 0.0))
		if parts.is_empty():
			continue
		if float(x.get("tired", 1.0)) > 1.005:
			tired.append(_key_day(int(x.date)))
		jump = maxf(jump, float(x.get("jump", 1.0)))
		used = float(x.get("used_to", 1.0))
		var body: Dictionary = x.get("body", {}).get(aid, {})
		growth = maxf(growth, float(body.get("growth", 1.0)))
		old = maxf(old, float(body.get("old_injury", 1.0)))
	if not items.is_empty():
		lines.append(str(c.added).format({"list": ", ".join(items)}))
	if faded >= 0.5:
		lines.append(str(c.faded).format({"n": roundi(faded)}))
	var faster := []
	if not tired.is_empty():
		faster.append(str(c.tired).format({"days": ", ".join(tired)}))
	if jump > 1.005:
		faster.append(str(c.jump).format({"x": "%.2f" % jump}))
	if used > 0.0 and 1.0 / used > 1.02:
		faster.append(str(c.not_used).format({"x": "%.2f" % (1.0 / used)}))
	if growth > 1.005:
		faster.append(str(c.growth).format({"x": "%.2f" % growth}))
	if old > 1.005:
		faster.append(str(c.old_injury).format({"x": "%.2f" % old}))
	if not faster.is_empty():
		lines.append("%s %s" % [str(c.faster_head), ", ".join(faster)])
	elif used > 0.0 and 1.0 / used < 0.98:
		lines.append(str(c.used_to).format({"x": "%.2f" % (1.0 / used)}))
	for area in HealthSystem.areas():
		if str(area.id) == aid and str(area.get("helps", "")) != "":
			lines.append(str(c.helps).format({"text": str(area.helps)}))
	return lines


## The planner's body bar tap: the last 7 played days of an area (recorded), its strain now.
static func area_now(aid: String) -> String:
	var h := _health()
	if h == null:
		return ""
	return "\n".join(area_detail(aid, h.strain_log.slice(-7), float(h.strain.get(aid, 0.0))))


# --- The moods ------------------------------------------------------------------------------------------------------------------

static func _mind() -> MindSystem:
	var m := MindSystem.sys()
	return m if m != null and MindSystem.model_enabled else null


## What a mood does at value `v` (data/mind.json ui.effects by its side).
static func mood_does(mood: String, v: float) -> String:
	var eff: Dictionary = Data.mind.ui.effects[mood]
	var mid: Array = Data.mind.moods[mood].middle
	var side := "low" if v < float(mid[0]) else ("high" if v > float(mid[1]) else "middle")
	if mood == "stress":
		return str(eff.low) if side == "middle" else str(eff.high)
	return str(eff.get(side, eff.get("low", "")))


## A mood's news (`list` = MindSystem.causes entries) and its Sunday drift as lines: "▲ 6 · Sat 7 Nov · PB at …", then
## "Sunday: ▲ +3.2 towards 66" with its pulls.
static func mood_lines(mood: String, list: Array, drift: Dictionary) -> Array:
	var c: Dictionary = cfg().mood
	var lines := []
	for x in list:
		lines.append(str(c.news).format({"arrow": _arrow(float(x.delta)), "delta": "%.1f" % absf(float(x.delta)),
				"date": DayInfo.short_day(x.date), "text": str(x.text)}))
	if drift.has(mood) and (absf(float(drift[mood].to) - float(drift[mood].from)) >= 0.05 or not drift[mood].get("pulls", []).is_empty()):
		var d: Dictionary = drift[mood]
		var moved := float(d.to) - float(d.from)
		lines.append(str(c.drift).format({"arrow": _arrow(moved) if absf(moved) >= 0.05 else "·", "delta": RaceRecap.signed(moved, 1),
				"target": roundi(float(d.target))}))
		var pulls: Array = d.get("pulls", [])
		if pulls.is_empty():
			lines.append(str(c.no_pulls))
		for p in pulls:
			lines.append(str(c.pull).format({"text": str(p.text), "delta": RaceRecap.signed(float(p.delta), 0 if absf(float(p.delta)) >= 1.0 else 1)}))
	return lines


static func mood_rows(r: Dictionary) -> Array:
	var out := []
	var mind := _mind()
	if mind == null or MindSystem.neutral:
		return out
	var c: Dictionary = cfg().mood
	var drift: Dictionary = mind.drift if mind.drift.has("date") and _in_week(r, mind.drift.date) else {}
	for mood in MindSystem.MOODS:
		var news: Array = mind.causes.get(mood, []).filter(func(x): return _in_week(r, x.date))
		var v0 := float(drift[mood].get("start", drift[mood].from)) if drift.has(mood) else float(mind.before.get(mood, mind.value(mood)))
		var v1 := float(drift[mood].get("end", mind.value(mood))) if drift.has(mood) else mind.value(mood)
		var w0 := MindSystem.word_for(mood, v0)
		var w1 := MindSystem.word_for(mood, v1)
		var changed := str(w0.id) != str(w1.id)
		var moved := v1 - v0
		var up := moved > 0.0
		var good := up if mood != "stress" else not up
		var value := str(c.steady)
		if changed:
			value = "%s → %s" % [str(w0.name), str(w1.name)]
		elif absf(moved) >= float(Data.mind.arrow_min):
			value = "%s %s" % [str(w1.name), _arrow(moved)]
		var biggest := {}
		for x in news:
			if biggest.is_empty() or absf(float(x.delta)) > absf(float(biggest.delta)):
				biggest = x
		var cause := str(biggest.get("text", ""))
		var drifted := absf(float(drift[mood].to) - float(drift[mood].from)) if drift.has(mood) else 0.0
		if drifted >= 0.5 and (biggest.is_empty() or drifted > absf(float(biggest.delta))):
			cause = str(c.drift_short).format({"word": str(MindSystem.word_for(mood, float(drift[mood].target)).name)})
		var lines := [str(c.detail_head).format({"word": str(w1.name), "value": roundi(v1), "does": mood_does(mood, v1)})]
		var ml := mood_lines(mood, news, drift)
		lines.append_array(ml if not ml.is_empty() else [str(c.no_news)])
		var tone := "plain" if value == str(c.steady) else ("good" if good else "bad")
		out.append(_row("mood", mood, str(Data.recap.mood_icons.get(mood, "brain")), str(Data.mind.moods[mood].name), value, tone,
				cause, lines, changed, absf(moved)))
	return out


## The planner's mood tap now: the word and what it does, the recent news (newest first), last Sunday's drift with its pulls,
## what helps.
static func mood_now(mood: String) -> String:
	var mind := _mind()
	if mind == null:
		return ""
	var c: Dictionary = cfg().mood
	var v := mind.value(mood)
	# (The row already says what it does: the tap starts with the number.)
	var lines := [str(c.now_head).format({"word": str(mind.word(mood).name), "value": roundi(v)})]
	var news := mind.recent(mood).slice(0, 5)
	news.reverse()
	var ml := mood_lines(mood, news, mind.drift)
	lines.append_array(ml)
	if ml.is_empty():
		lines.append(str(c.no_news))
	lines.append(str(c.helps).format({"text": str(Data.mind.ui.helps_text[mood])}))
	return "\n".join(lines)


# --- People ---------------------------------------------------------------------------------------------------------------------

static func _moments() -> StoryletSystem:
	var ms := Game.get_system("moments") as StoryletSystem
	return ms if ms != null and ms.active() else null


static func size_word(delta: float) -> String:
	var cfgc: Dictionary = Data.moments.changes
	var limits: Array = cfgc.size_limits
	var i := 0 if absf(delta) <= float(limits[0]) else (1 if absf(delta) <= float(limits[1]) else 2)
	return str(cfgc.sizes[i])


## What a person's relationship really does at value `v` (data/causes.json people_does; "" for most people until P2).
static func person_does(p: Dictionary, v: float) -> String:
	var list: Array = cfg().people_does.get(str(p.get("role", "")), [])
	for x in list:
		if x.has("below") and v < float(x.below):
			return str(x.text)
		if x.has("from") and v >= float(x.from):
			return str(x.text)
	return ""


## Why one relationship log entry happened, in words.
static func why_text(ms: StoryletSystem, p: Dictionary, x: Dictionary) -> String:
	var c: Dictionary = cfg().people
	if str(x.get("kind", "")) == "farewell":
		return str(c.why_farewell)
	var from := str(x.get("from", ""))
	var reply := str(x.get("reply", ""))
	var why := ""
	if from != "" and from != str(p.get("id", "")):
		var who := StoryletSystem.short_name(ms.people.get(from, {}))
		why = str(c.why_other if reply != "" else c.why_other_none).format({"who": who, "reply": reply})
	else:
		why = str(c.why_reply if reply != "" else c.why_none).format({"reply": reply})
	if str(x.get("about", "")) != "":
		why = str(c.why_about).format({"why": why, "about": str(x.about)})
	return why


## The lines of a person's relationship: the word and number, what it does, every recent cause.
static func person_lines(ms: StoryletSystem, p: Dictionary, entries: Array) -> Array:
	var c: Dictionary = cfg().people
	var v := ms.relation_of(p)
	var lines := [str(c.detail_head).format({"name": StoryletSystem.person_name(p), "word": Cast.relation_word(v), "value": roundi(v)})]
	var does := person_does(p, v)
	if does != "":
		lines.append(does[0].to_upper() + does.substr(1) + ".")
	for x in entries:
		lines.append(str(c.entry).format({"arrow": _arrow(float(x.delta)), "delta": "%.0f" % absf(float(x.delta)) if absf(float(x.delta)) >= 1.0 else "%.1f" % absf(float(x.delta)),
				"date": DayInfo.short_day(x.date), "why": why_text(ms, p, x)}))
	return lines


## A relationship move as a row: "Elmeri · Good → Close" (main) or "Good ▲" with the size.
static func person_row(ms: StoryletSystem, p: Dictionary, before: float, after: float, entries: Array) -> Dictionary:
	var c: Dictionary = cfg().people
	var w0 := Cast.relation_word(before)
	var w1 := Cast.relation_word(after)
	var d := after - before
	var changed := w0 != w1
	var value := "%s → %s" % [w0, w1] if changed else str(c.value_same).format({"word": w1, "arrow": "%s %s" % [_arrow(d), size_word(d)]})
	var last: Dictionary = entries.back() if not entries.is_empty() else {}
	var cause := why_text(ms, p, last) if not last.is_empty() else ""
	var does := person_does(p, after)
	if changed and does != "":
		cause = does
	var row := _row("person", str(p.get("id", "")), "user-round", StoryletSystem.person_name(p), value, "good" if d > 0.0 else "bad",
			cause, person_lines(ms, p, entries), changed, absf(d))
	return row


static func people_rows(r: Dictionary) -> Array:
	var out := []
	var ms := _moments()
	if ms != null:
		for pid in ms.people:
			var p: Dictionary = ms.people[pid]
			if str(p.get("role", "")) == "coach":
				continue
			var entries: Array = p.get("log", []).filter(func(x): return _in_week(r, x.date))
			if entries.is_empty():
				continue
			var before := float(entries[0].before)
			var after := float(entries.back().after)
			if absf(after - before) < 0.05:
				continue
			out.append(person_row(ms, p, before, after, entries))
	var t := trust_row(r)
	if not t.is_empty():
		out.append(t)
	return out


static func trust_cause(cause: String) -> String:
	var map: Dictionary = cfg().people.trust_causes
	var key := cause.get_slice(":", 0) if cause.begins_with("moment:") else cause
	return CoachSystem.words(str(map.get(key, str(map.other).format({"cause": cause}))))


## Trust in the coach over the week: his trust causes dated in it + the Sunday drift (CoachSystem.last_drift).
static func trust_row(r: Dictionary) -> Dictionary:
	var cs := Game.get_system("coach") as CoachSystem
	if cs == null or not CoachSystem.model_enabled or cs.head().is_empty():
		return {}
	var c: Dictionary = cfg().people
	var rel := cs.relation()
	var entries: Array = rel.get("causes", []).filter(func(x): return _in_week(r, x.date))
	var drift: Dictionary = rel.get("last_drift", {})
	var drift_in := not drift.is_empty() and _in_week(r, drift.date)
	var total := 0.0
	for x in entries:
		total += float(x.delta)
	if drift_in:
		total += float(drift.delta)
	if absf(total) < 0.5 and entries.is_empty():
		return {}
	var after := cs.trust()
	var before := after - total
	var first := str(cs.head().get("name", "")).get_slice(" ", 0)
	var lines := [str(c.trust_detail).format({"before": roundi(before), "after": roundi(after), "word": cs.trust_word()})]
	var does := CoachSystem.words(str(cfg().trust_does.get(cs.trust_level(), "")))
	if does != "":
		lines.append(does[0].to_upper() + does.substr(1) + ".")
	for x in entries:
		lines.append(str(c.trust_entry).format({"arrow": _arrow(float(x.delta)), "delta": "%.0f" % absf(float(x.delta)),
				"date": DayInfo.short_day(x.date), "why": trust_cause(str(x.cause))}))
	if drift_in and absf(float(drift.delta)) >= 0.05:
		lines.append(str(c.trust_drift).format({"arrow": _arrow(float(drift.delta)), "delta": "%.1f" % absf(float(drift.delta)), "fit": cs.fit_word()}))
	var cause := trust_cause(str(entries.back().cause)) if not entries.is_empty() else ""
	var w := cs.trust_word()
	return _row("trust", "trust", "message-circle", str(c.trust_title).format({"name": first}),
			"%s %s" % [w, _arrow(total)] if absf(total) >= 0.5 else w, "good" if total > 0.0 else "bad", cause, lines, false, absf(total))


# --- School, the slots, invitations ---------------------------------------------------------------------------------------------

static func test_rows(r: Dictionary) -> Array:
	var out := []
	var ss := SchoolSystem.sys()
	if ss == null or SchoolSystem.neutral:
		return out
	var c: Dictionary = cfg().tests
	for t in ss.tests_log:
		if not _in_week(r, t.date):
			continue
		var sid := str(t.subject)
		var score := float(t.score)
		var recent := []
		for x in ss.tests_of(sid, 4):
			recent.append(SchoolSystem.score_text(float(x.score)))
		var subject := ss.subject_name(sid)
		var grade := ss.card_grade(sid)
		out.append(_row("test", sid, "pencil-line", str(c.title).format({"subject": subject}), SchoolSystem.score_text(score),
				"good" if score >= 8.0 else ("bad" if score <= 5.0 else "plain"), str(c.cause).format({"grade": grade}),
				[str(c.detail).format({"subject": subject, "list": ", ".join(recent), "grade": grade})], true, score))
	# (session L3b1: the report card is no longer a stop; its grades are a row of the week, every subject in the tap)
	for i in ss.reports.size():
		var rep: Dictionary = ss.reports[i]
		if not _in_week(r, rep.date):
			continue
		var avg := float(rep.average)
		var prev: Dictionary = ss.reports[i - 1] if i > 0 else {}
		var grades := []
		for s in ss.subject_list():
			if rep.grades.has(str(s.id)):
				grades.append("%s %d" % [str(s.name), int(rep.grades[str(s.id)])])
		out.append(_row("test", "card%d" % i, "graduation-cap", str(Data.school_life.card.title[str(rep.kind)]), "%.2f" % avg,
				"good" if avg >= 8.0 else ("bad" if avg < 7.0 else "plain"),
				str(Data.school_life.card.first) if prev.is_empty() else SchoolSystem.verdict_text(avg - float(prev.average)),
				[str(Data.school_life.card.average_line).format({"avg": "%.2f" % avg, "acad": "%.2f" % float(rep.academic_average)}),
				", ".join(grades)], true, 10.0 + avg))
	return out


## The slots' effects in the week (recorded in the day log's life_parts and the report's `slots`): late nights, extra or fewer
## study evenings, early nights.
static func slot_rows(r: Dictionary) -> Array:
	var out := []
	if not r.has("slots") or SchoolSystem.sys() == null:
		return out
	var c: Dictionary = cfg().slots
	var keys := _week_keys(r.monday)
	var late := []
	var early := []
	var study_load := 0.0
	var study_days := 0
	for e in _log_of(r):
		var parts: Dictionary = e.get("life_parts", {})
		var i := int(keys.get(Calendar.date_key(e.date), 0))
		if parts.has("slot_friends"):
			late.append({"day": i, "what": str(c.late_friends), "v": float(parts.slot_friends)})
		if parts.has("late_night"):
			late.append({"day": i, "what": str(c.late_moment), "v": float(parts.late_night)})
		if parts.has("slot_rest"):
			early.append({"day": i, "v": float(parts.slot_rest)})
		if parts.has("slot_study"):
			study_load += float(parts.slot_study)
			study_days += 1
	if not late.is_empty():
		var days := []
		var items := []
		for x in late:
			days.append(int(x.day))
			items.append(str(c.late_item).format({"day": _day_name(int(x.day)), "what": str(x.what), "n": "%.2f" % float(x.v)}))
		out.append(_row("slot", "late", "moon", str(c.late_title), str(late.size()), "warn", str(c.late_cause).format({"days": _days_text(days)}),
				[str(c.late_detail).format({"list": "; ".join(items)})], true, late.size()))
	if not early.is_empty():
		var days := []
		var items := []
		for x in early:
			days.append(int(x.day))
			items.append("%s %.2f" % [_day_name(int(x.day)), float(x.v)])
		out.append(_row("slot", "early", "moon", str(c.early_title), str(early.size()), "good", str(c.early_cause).format({"days": _days_text(days)}),
				[str(c.early_detail).format({"list": ", ".join(items)})], false, early.size()))
	var n := int(HabitSystem.counts(r.slots).study)
	var neutral := int(Data.habits.neutral.study)
	var shift := HabitSystem.shift_for(n)
	if shift != 0.0 or study_load > 0.0:
		var grades := str(c.grades_up if shift > 0.0 else (c.grades_down if shift < 0.0 else c.grades_hold))
		var load := str(c.study_load).format({"n": "%.2f" % (study_load / study_days)}) if study_days > 0 else ""
		out.append(_row("slot", "study", "book-open", str(c.study_title), str(n), "good" if shift > 0.0 else ("bad" if shift < 0.0 else "plain"),
				str(c.study_cause_load if study_load > 0.0 else c.study_cause).format({"grades": grades}),
				[str(c.study_detail).format({"n": n, "neutral": neutral, "grades": grades, "load": load})], true, absf(shift)))
	return out


## The week's mental sessions by kind: {kind: [day index]} (the day log's `mental`, session L3b1).
static func _mental_days(r: Dictionary) -> Dictionary:
	var out := {}
	var keys := _week_keys(r.monday)
	for e in _log_of(r):
		var k := str(e.get("mental", ""))
		if k == "":
			continue
		var list: Array = out.get(k, [])
		list.append(int(keys.get(Calendar.date_key(e.date), 0)))
		out[k] = list
	return out


## The week's mental sessions as one row (session L3b1): which kinds on which days, and in the tap what each did as recorded (the
## composure part of each kind, relaxation's and self-talk's pull in Sunday's drift, the halved nerves, the school days' life
## load) and a repeat that added nothing.
static func mental_rows(r: Dictionary) -> Array:
	var out := []
	var days := _mental_days(r)
	if days.is_empty():
		return out
	var c: Dictionary = cfg().mental
	var defs: Dictionary = Data.mind.mental.kinds
	var parts: Dictionary = r.get("parts", {}).get("composure", {})
	var items := []
	var lines := []
	var n := 0
	for k in defs:
		if not days.has(k):
			continue
		var list: Array = days[k]
		n += list.size()
		var name := str(defs[k].short)
		items.append(str(c.item).format({"name": name, "day": _day_name(int(list[0]))}))
		var grown := float(parts.get("mental:" + str(k), 0.0))
		lines.append(str(c.composure).format({"name": name, "day": _day_name(int(list[0])), "value": num(grown)}))
		if list.size() > 1:
			lines.append(str(c.again).format({"name": name, "days": _days_text(list.slice(1))}))
	var ms := _mind()
	if ms != null and not ms.drift.is_empty() and _in_week(r, ms.drift.date):
		var pt: Dictionary = Data.mind.pulls
		for mood in ["stress", "confidence"]:
			for p in ms.drift.get(mood, {}).get("pulls", []):
				if str(p.text) == str(pt.relaxation) or str(p.text) == str(pt.self_talk):
					lines.append(str(c.pull).format({"what": str(p.text), "mood": str(Data.mind.moods[mood].name).to_lower(),
							"value": "%+d" % roundi(float(p.delta))}))
		var tail := str(Data.mind.causes.big_meet_relaxed).get_slice("{meet}", 1)
		var next_monday := Calendar.date_key(Game.add_days(r.monday, 7))
		for x in ms.causes.get("stress", []):   # (the nerves are news on Sunday night: dated that Sunday or the Monday after)
			if str(x.text).ends_with(tail) and (_in_week(r, x.date) or Calendar.date_key(x.date) == next_monday):
				lines.append(str(c.nerves).format({"text": str(x.text)}))
	var school_days := 0
	for e in _log_of(r):
		if e.get("life_parts", {}).has("mental"):
			school_days += 1
	if school_days > 0:
		lines.append(str(c.load).format({"n": school_days, "each": "%.2f" % float(Data.mind.mental.life_load)}))
	out.append(_row("mental", "week", "brain", str(c.title), str(n), "good", ", ".join(items), lines, false, n))
	return out


static func invite_rows(r: Dictionary) -> Array:
	var out := []
	var ms := _moments()
	if ms == null:
		return out
	var c: Dictionary = cfg().invites
	for m in ms.moments:
		if not m.has("invite") or str(m.answer) == "":
			continue
		var date := StoryletSystem._date_of(int(m.slot_day))
		if not _in_week(r, date):
			continue
		var went := HabitSystem.going(m)
		var answer := str(c.went if went else (c.none if str(m.answer) == StoryletSystem.NONE else c.stayed))
		var changes: Array = m.get("changes", []).duplicate()
		for x in m.get("rel", []):
			var p: Dictionary = ms.people.get(str(x.pid), {})
			changes.append("%s %s %s" % [StoryletSystem.short_name(p), _arrow(float(x.after) - float(x.before)), size_word(float(x.after) - float(x.before))])
		out.append(_row("invite", str(m.id), "party-popper", str(m.invite.title), answer, "plain",
				str(changes[0]) if not changes.is_empty() else "",
				[str(c.detail).format({"title": str(m.invite.title), "day": DayInfo.short_day(date), "answer": answer, "changes": " · ".join(changes)})],
				true, 0.0))
	return out
