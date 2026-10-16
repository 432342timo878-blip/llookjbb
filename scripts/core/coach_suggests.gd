class_name CoachSuggests
extends GameSystem
## "Coach suggests" (GDD 4.9.2, session C5; moved here from C4, user 2026-10-16): the head coach suggests a meet to race or a meet to
## make a target. GameSystem id "suggests", last in Game.systems. Each Monday morning he looks at the next weeks of the calendar, at
## most `per_month` suggestions a calendar month (data/advice.json suggest), counted with CoachProposals' 2 a week. A meet comes
## with a REASON: a gap in your racing, a tune-up before a target, a chance to run the limit of the next target. He judges it with
## the C4 verdict model (CoachVerdict.meet_change / target_change: the weeks played with it and without, through HIS attributes) and
## suggests it only when HE thinks it a Good idea, so a poor judge can suggest a meet that does you no good, and miss one that would.
## The player decides: he never enters a meet by himself. "Let the coach adjust my days" (CoachProposals.setting()): Ask me first =
## a message with Yes / No thanks that stops Play week; Always, tell me = the same message without the stop; Never = he only writes
## it. In every case the Calendar marks it (COACH SUGGESTS: his reason, Yes / No thanks). A meet you said no to is never suggested again.
## Static `enabled` is OFF unless the app shell (main.gd) switches it on, like the proposals, so the tools that play seasons are
## unchanged; tools/goals_check.gd tests it on.

static var enabled := false

var list: Array = []       # suggestions, oldest first (the last suggest.keep): see _suggest
var declined: Array = []   # meet keys he must not suggest again
var last_month := -1       # year * 12 + month of the last suggestion
var _next := 1
## Not saved, for the tools: every suggestion made since the system was made.
var fired: Array = []


func _init() -> void:
	id = "suggests"


static func cfg() -> Dictionary:
	return Data.advice.suggest


static func sys() -> CoachSuggests:
	return Game.get_system("suggests") as CoachSuggests


# --- The day loop ----------------------------------------------------------------------------------------------------

## Monday morning: does he suggest something this month?
func on_day_start(ctx: Dictionary) -> void:
	if not enabled or Game.athlete == null or int(ctx.day) != int(cfg().look_weekday):
		return
	_expire(ctx.date)
	var month: int = int(ctx.date.year) * 12 + int(ctx.date.month)
	if month == last_month or Calendar.days_between(Game.START_DATE, ctx.date) < int(cfg().start_after_days):
		return
	var cp := Game.get_system("proposals") as CoachProposals
	var mode := cp.setting() if cp != null else "ask"
	if mode == "ask" and not Game.pending_event().is_empty():
		return
	var monday := StoryletSystem.day_no(ctx.date) - int(ctx.day)
	if cp != null and int(cp.week.get("count", 0)) >= int(Data.coaching.proposals.max_per_week) and int(cp.week.get("monday", -1)) == monday:
		return
	var cs := Game.get_system("coach") as CoachSystem
	if cs == null or cs.head().is_empty():
		return
	var best := _best(CoachVerdict.head_view())
	if not best.is_empty():
		_suggest(best, ctx, mode, cp)


## A suggestion whose meet has passed is over.
func _expire(today: Dictionary) -> void:
	for s in list:
		if str(s.status) in ["asked", "noticed", "listed"]:
			var m := Calendar.get_meet(str(s.meet))
			if m.is_empty() or Calendar.date_key(m.date) < Calendar.date_key(today):
				s.status = "over"


# --- What he might suggest ---------------------------------------------------------------------------------------------

## The best candidate of the coming weeks as he sees it: {kind, meet, reasons, j} or {}.
func _best(coach: Dictionary) -> Dictionary:
	var a := Game.athlete
	var today := Game.date
	var c := cfg()
	var best := {}
	var from := Game.add_days(today, int(c.min_ahead_days))
	var to := Game.add_days(today, 7 * int(c.look_weeks))
	for m in Calendar.meets_between(from, to):
		if str(m.key) in Game.entries or str(m.key) in declined or not Calendar.can_enter(a, m, today).ok or _open_for(str(m.key), "meet"):
			continue
		var reasons := _reasons(m)
		if reasons.is_empty():
			continue
		var j := CoachVerdict.judge(CoachVerdict.meet_change(m), coach)
		if j.verdict == CoachVerdict.GOOD and float(j.seen.total) >= float(c.propose_min_w) \
				and (best.is_empty() or float(j.seen.total) > float(best.j.seen.total)):
			best = {"kind": "meet", "meet": m, "reasons": reasons, "j": j}
	if Game.season.mode == SeasonPlan.PHASES and best.is_empty():
		best = _best_target(coach)
	return best


## A national / international meet that could become a target: judged with the plan built round it.
func _best_target(coach: Dictionary) -> Dictionary:
	var a := Game.athlete
	var t: Dictionary = cfg().target
	var best := {}
	if Game.season.targets(SeasonPlan.year_of(Game.date)).size() >= int(Data.periodization.season.max_targets):
		return best
	var limit := Game.add_days(Game.date, 7 * int(t.look_weeks))
	for year in [SeasonPlan.year_of(Game.date), SeasonPlan.year_of(Game.date) + 1]:
		for m in Game.season.target_candidates(year, Game.add_days(Game.date, int(cfg().min_ahead_days))):
			if Calendar.date_key(m.date) > Calendar.date_key(limit) or str(m.level) not in t.levels or str(m.key) in declined \
					or not Calendar.can_enter(a, m, Game.date).ok or _open_for(str(m.key), "target"):
				continue
			var j := CoachVerdict.judge(CoachVerdict.target_change(m), coach)
			if j.verdict == CoachVerdict.GOOD and float(j.seen.total) >= float(t.propose_min_w) \
					and (best.is_empty() or float(j.seen.total) > float(best.j.seen.total)):
				best = {"kind": "target", "meet": m, "reasons": ["target"], "j": j}
	return best


## Why a meet might be worth racing: ["gap", "tune", "standard"] (those that hold). `target` / `limit` of the first one found go
## with it in `_why` for the texts.
func _reasons(m: Dictionary) -> Array:
	var out := []
	var c := cfg()
	var a := Game.athlete
	# gap: no race in the last gap.weeks and none entered in the weeks before this meet
	var last := _last_race_date()
	var weeks := int(c.gap.weeks)
	var since := Calendar.days_between(last, Game.date) if not last.is_empty() else 7 * weeks
	if since >= 7 * weeks and not _entered_between(Game.date, m.date):
		out.append("gap")
	var targets: Array = Game.season.targets(SeasonPlan.year_of(m.date)) if Game.season.mode == SeasonPlan.PHASES else []
	for key in targets:
		var t := Calendar.get_meet(str(key))
		if t.is_empty() or str(key) == str(m.key):
			continue
		var days := Calendar.days_between(m.date, t.date)
		if days >= int(c.tune.min_days) and days <= int(c.tune.max_days) and not _entered_between(Game.add_days(m.date, -int(c.tune.free_before_days)), Game.add_days(t.date, -int(c.tune.free_before_days))):
			if not out.has("tune"):
				out.append("tune")
		# standard: the target has a limit you have not run yet and your best is close to it
		if t.has("standard") and days >= int(c.standard.before_days) and days <= 8 * 7:
			var limits: Dictionary = Data.competitions.standards[t.standard].get(a.main_event, {})
			var cls := Calendar.age_class(a, t.date.year)
			var pb := float(a.personal_bests.get(a.main_event, 0.0))
			if limits.has(cls) and pb > float(limits[cls]) and pb <= float(limits[cls]) * (1.0 + float(c.standard.within)) and not out.has("standard"):
				out.append("standard")
	return out


## The first reason's placeholders: {weeks, meet, date, target, limit}.
func _fill(m: Dictionary, reasons: Array) -> Dictionary:
	var a := Game.athlete
	var f := {"weeks": int(cfg().gap.weeks), "meet": str(m.name), "date": Calendar.format_meet_date(m), "target": "", "limit": ""}
	if Game.season.mode == SeasonPlan.PHASES:
		for key in Game.season.targets(SeasonPlan.year_of(m.date)):
			var t := Calendar.get_meet(str(key))
			if t.is_empty() or str(key) == str(m.key) or Calendar.date_key(t.date) <= Calendar.date_key(m.date):
				continue
			f.target = str(t.name)
			if t.has("standard"):
				var limits: Dictionary = Data.competitions.standards[t.standard].get(a.main_event, {})
				var cls := Calendar.age_class(a, t.date.year)
				if limits.has(cls):
					f.limit = "%s limit (%s)" % [str(Data.standards.sets.sm.short), Calendar.format_time(float(limits[cls]))]
			break
	return f


func _last_race_date() -> Dictionary:
	var best := {}
	for r in Game.athlete.results:
		var d := Game.int_date(r.date)
		if best.is_empty() or Calendar.date_key(d) > Calendar.date_key(best):
			best = d
	return best


## Is a meet entered on a date from `from` to `to`?
func _entered_between(from: Dictionary, to: Dictionary) -> bool:
	for m in Calendar.meets_between(from, to):
		if str(m.key) in Game.entries:
			return true
	return false


# --- Making a suggestion -------------------------------------------------------------------------------------------------

## A suggestion: {id, day (posted), date (posted), kind, meet, meet_name, meet_date, reasons, verdict, said, status ("asked" /
## "listed" (Always: a message, not a stop) / "noticed" (Never) / "accepted" / "declined" / "none" / "over"), moment, mode}.
func _suggest(best: Dictionary, ctx: Dictionary, mode: String, cp: CoachProposals) -> void:
	var m: Dictionary = best.meet
	var j: Dictionary = best.j
	var s := {"id": "s%d" % _next, "day": StoryletSystem.day_no(ctx.date), "date": ctx.date.duplicate(), "kind": str(best.kind),
			"meet": str(m.key), "meet_name": str(m.name), "meet_date": m.date.duplicate(), "reasons": best.reasons.duplicate(),
			"verdict": str(j.verdict), "said": _clean(j), "status": "", "moment": "", "mode": mode}
	_next += 1
	list.append(s)
	while list.size() > int(cfg().keep):
		list.pop_front()
	last_month = int(ctx.date.year) * 12 + int(ctx.date.month)
	if cp != null:
		var monday := StoryletSystem.day_no(ctx.date) - int(ctx.day)
		if int(cp.week.get("monday", -1)) != monday:   # (his suggestion counts as one of his two a week)
			cp.week = {"monday": monday, "count": 0}
		cp.week["count"] = int(cp.week.get("count", 0)) + 1
	fired.append(s)
	var ms := Game.get_system("moments") as StoryletSystem
	var end_key := "ask_end" if mode == "ask" else ("always_end" if mode == "always" else "noticed_end")
	var text := _text(s, end_key)
	match mode:
		"ask":
			s.status = "asked"
			if ms != null:
				s.moment = str(ms.post_custom("suggest", s.id, text, _replies(s), true).get("id", ""))
		"always":
			s.status = "asked"
			if ms != null:
				s.moment = str(ms.post_custom("suggest", s.id, text, _replies(s), false).get("id", ""))
		_:
			s.status = "noticed"
			if ms != null:
				ms.coach_says(text)


## His reason (his verdict's) without the opening word.
static func _clean(j: Dictionary) -> String:
	return CoachProposals._reason(j)


func _text(s: Dictionary, end_key: String) -> String:
	var c := cfg()
	var voice := Coaches.id_of(Game.athlete)
	var m := Calendar.get_meet(str(s.meet))
	var reasons: Array = s.reasons
	var parts := [str(c.intro.get(voice, c.intro.calm))]
	parts.append(str(c.reason[reasons[0]]).format(_fill(m, reasons)))
	if str(s.said) != "":
		parts.append(str(s.said))
	parts.append(str(c.get(end_key)[s.kind]))
	return " ".join(parts)


func _replies(s: Dictionary) -> Array:
	var r: Dictionary = cfg().replies
	var accept: Dictionary = r.accept_target if str(s.kind) == "target" else r.accept_meet
	return [{"id": "accept", "label": str(accept.label), "hint": str(accept.hint)},
			{"id": "decline", "label": str(r.decline.label), "hint": str(r.decline.hint)}]


# --- The answer ------------------------------------------------------------------------------------------------------------

## The answer to the moment (StoryletSystem routes it here): {result (his reply), changes (lines for the result card)}.
func on_reply(suggestion_id: String, reply_id: String) -> Dictionary:
	var s := suggestion(suggestion_id)
	if s.is_empty() or str(s.status) != "asked":
		return {}
	var answered: Dictionary = cfg().answered.get(Coaches.id_of(Game.athlete), cfg().answered.calm)
	var lines: Dictionary = cfg().lines
	if reply_id == "accept":
		accept(s)
		var key := "targeted" if str(s.kind) == "target" else "entered"
		return {"result": str(answered.accept), "changes": [str(lines[key]).format({"meet": s.meet_name})]}
	if reply_id == "decline":
		decline(s)
		return {"result": str(answered.decline), "changes": [str(lines.declined).format({"meet": s.meet_name})]}
	return {}   # (the message passed unanswered: nothing happens; the Calendar keeps his mark until the meet is over or you answer there)


## Enters the meet (and makes it a target for a target suggestion). The player's decision, from the message or the Calendar.
func accept(s: Dictionary) -> void:
	var m := Calendar.get_meet(str(s.meet))
	if m.is_empty():
		return
	if str(s.kind) == "target":
		Game.season.add_target(SeasonPlan.year_of(m.date), str(s.meet))
	if Calendar.can_enter(Game.athlete, m, Game.date).ok:
		Game.enter(str(s.meet))
	s.status = "accepted"
	Game.current_week()
	var h := Game.get_system("health") as HealthSystem
	if h != null:
		h.refresh()


func decline(s: Dictionary) -> void:
	s.status = "declined"
	if not str(s.meet) in declined:
		declined.append(str(s.meet))


## "No thanks" from the Calendar: answers the waiting message too.
func decline_from_calendar(meet_key: String) -> void:
	for s in list:
		if str(s.meet) == meet_key and str(s.status) in ["asked", "noticed"]:
			var ms := Game.get_system("moments") as StoryletSystem
			if str(s.status) == "asked" and str(s.moment) != "" and ms != null and not ms.moment(str(s.moment)).is_empty() \
					and str(ms.moment(str(s.moment)).answer) == "":
				ms.answer(str(s.moment), "decline")
			else:
				decline(s)
			return


func suggestion(suggestion_id: String) -> Dictionary:
	for s in list:
		if str(s.id) == suggestion_id:
			return s
	return {}


## The suggestion the Calendar shows on a meet (asked / listed / noticed and still open), or {}.
func open_for(meet_key: String) -> Dictionary:
	return _open_for(meet_key, "")


func _open_for(meet_key: String, kind: String) -> Dictionary:
	for i in range(list.size() - 1, -1, -1):
		var s: Dictionary = list[i]
		if str(s.meet) != meet_key or not str(s.status) in ["asked", "noticed"] or (kind != "" and str(s.kind) != kind):
			continue
		var m := Calendar.get_meet(meet_key)
		if str(s.kind) == "meet" and meet_key in Game.entries:
			return {}
		if str(s.kind) == "target" and not m.is_empty() and meet_key in Game.season.targets(SeasonPlan.year_of(m.date)):
			return {}
		return s
	return {}


## The line the Calendar shows under his mark: his reason (the first reason's text).
func calendar_text(s: Dictionary) -> String:
	if s.is_empty():
		return ""
	var m := Calendar.get_meet(str(s.meet))
	return str(cfg().reason[str(s.reasons[0])]).format(_fill(m, s.reasons)) if not m.is_empty() else ""


# --- Save / load ------------------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if list.is_empty() and declined.is_empty() and last_month < 0:
		return {}
	return {"list": list, "declined": declined, "last_month": last_month, "next": _next}


func from_dict(d: Dictionary) -> void:
	list = d.get("list", [])
	for s in list:
		s.day = int(s.day)
		s.date = Game.int_date(s.date)
		s.meet_date = Game.int_date(s.meet_date)
	declined = d.get("declined", []).map(func(x): return str(x))
	last_month = int(d.get("last_month", -1))
	_next = int(d.get("next", 1))
