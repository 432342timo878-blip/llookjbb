class_name WeekPlan
extends RefCounted
## A week plan (GDD 4.8): what the athlete does on each weekday, as plain data so it can be saved and compared:
## {"days": [7 Arrays of session ids], "intensity": [7 × "easy" / "normal" / "hard"]} and, only when the week has one
## (session L3b1), "mental": [7 × a mental session kind or ""] (data/mind.json `mental`: a short extra on the day that takes
## none of its two training places; a week without any has no "mental" key, so it saves and compares as before).
## Everything that used to take the plain Array of days takes a week plan; `of()` also accepts the old Array
## (every day Normal), so older code and saves keep working.

const NORMAL := "normal"


## A week plan from the days (Mon..Sun, each an Array of session ids) and, optionally, the 7 intensities and the 7 mental
## sessions. Missing days are rest days, missing or unknown intensities are Normal, unknown mental kinds none. Copies what it
## is given.
static func make(days: Array = [], intensity: Array = [], mental: Array = []) -> Dictionary:
	var d := []
	var i := []
	for n in 7:
		d.append(Array(days[n]).duplicate() if n < days.size() else [])
		var level: String = str(intensity[n]) if n < intensity.size() else NORMAL
		i.append(level if level in Training.INTENSITIES else NORMAL)
	var out := {"days": d, "intensity": i}
	_put_mental(out, mental)
	return out


## `x` as a week plan: a week plan stays as it is (not copied: it is the one being edited), the old plain Array
## of days becomes a week plan with every day Normal.
static func of(x: Variant) -> Dictionary:
	if x is Dictionary:
		return x
	return make(x)


static func days(plan: Variant) -> Array:
	return of(plan).days


static func intensity(plan: Variant) -> Array:
	return of(plan).intensity


## The 7 mental sessions (kind or "") of a plan (session L3b1).
static func mental(plan: Variant) -> Array:
	var m: Array = of(plan).get("mental", [])
	var out := []
	for n in 7:
		out.append(str(m[n]) if n < m.size() else "")
	return out


## Sets day `d`'s mental session in place ("" = none); the key goes when the week has none left.
static func set_mental(plan: Dictionary, d: int, kind: String) -> void:
	var m := mental(plan)
	m[d] = kind
	_put_mental(plan, m)


static func is_mental(kind: String) -> bool:
	return Data.mind.mental.kinds.has(kind)


static func _put_mental(plan: Dictionary, mental: Array) -> void:
	var m := []
	var any := false
	for n in 7:
		var k: String = str(mental[n]) if n < mental.size() else ""
		if k != "" and not is_mental(k):
			k = ""
		any = any or k != ""
		m.append(k)
	if any:
		plan.mental = m
	else:
		plan.erase("mental")


## The club coach's starter week, every day Normal (with his mental sessions, session L3b1).
static func coach() -> Dictionary:
	return with_coach_mental(make(Training.coach_plan()))


## A week of rest days, every day Normal.
static func empty() -> Dictionary:
	return make()


static func copy_of(plan: Variant) -> Dictionary:
	var p := of(plan)
	return make(p.days, p.intensity, p.get("mental", []))


## The same days, the same intensities and the same mental sessions.
static func equals(a: Variant, b: Variant) -> bool:
	var x := of(a)
	var y := of(b)
	return x.days == y.days and x.intensity == y.intensity and mental(x) == mental(y)


## The lightest day of the plan without a mental session (a rest day first, then Easy, Normal, Hard; Monday first), or -1.
static func lightest_free_day(plan: Dictionary) -> int:
	var m := mental(plan)
	var best := -1
	var best_rank := 99
	for d in 7:
		if m[d] != "":
			continue
		var rank: int = 0 if Array(plan.days[d]).is_empty() else 1 + Training.INTENSITIES.find(str(plan.intensity[d]))
		if rank < best_rank:
			best_rank = rank
			best = d
	return best


## Adds each of `kinds` not yet in the week on its lightest free day (in place). Returns {kind: day} of what was added.
static func add_mental(plan: Dictionary, kinds: Array) -> Dictionary:
	var added := {}
	for k in kinds:
		if str(k) in mental(plan) or not is_mental(str(k)):
			continue
		var d := lightest_free_day(plan)
		if d < 0:
			break
		set_mental(plan, d, str(k))
		added[str(k)] = d
	return added


## The kinds the head coach puts in his plans (data/mind.json mental.coach: by his mental coaching); [] with the coach or the
## mind model off, or no coach.
static func coach_mental_kinds() -> Array:
	if not MindSystem.model_enabled or not CoachSystem.model_enabled:
		return []
	var cs := Game.get_system("coach") as CoachSystem
	if cs == null or cs.head().is_empty():
		return []
	var level := cs.attr("mental_coaching")
	var kinds := []
	for l in Data.mind.mental.coach.levels:
		if level >= float(l.from):
			kinds = Array(l.kinds)
	return kinds


## `plan` with the head coach's mental sessions added (a copy when he adds any; the plan itself when he adds none).
static func with_coach_mental(plan: Dictionary) -> Dictionary:
	var kinds := coach_mental_kinds()
	if kinds.is_empty():
		return plan
	var p := copy_of(plan)
	add_mental(p, kinds)
	return p
