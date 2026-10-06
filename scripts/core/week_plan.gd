class_name WeekPlan
extends RefCounted
## A week plan (GDD 4.8): what the athlete does on each weekday, as plain data so it can be saved and compared:
## {"days": [7 Arrays of session ids], "intensity": [7 × "easy" / "normal" / "hard"]}.
## Everything that used to take the plain Array of days takes a week plan; `of()` also accepts the old Array
## (every day Normal), so older code and saves keep working.

const NORMAL := "normal"


## A week plan from the days (Mon..Sun, each an Array of session ids) and, optionally, the 7 intensities.
## Missing days are rest days, missing or unknown intensities are Normal. Copies what it is given.
static func make(days: Array = [], intensity: Array = []) -> Dictionary:
	var d := []
	var i := []
	for n in 7:
		d.append(Array(days[n]).duplicate() if n < days.size() else [])
		var level: String = str(intensity[n]) if n < intensity.size() else NORMAL
		i.append(level if level in Training.INTENSITIES else NORMAL)
	return {"days": d, "intensity": i}


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


## The club coach's starter week, every day Normal.
static func coach() -> Dictionary:
	return make(Training.coach_plan())


## A week of rest days, every day Normal.
static func empty() -> Dictionary:
	return make()


static func copy_of(plan: Variant) -> Dictionary:
	var p := of(plan)
	return make(p.days, p.intensity)


## The same days and the same intensities.
static func equals(a: Variant, b: Variant) -> bool:
	var x := of(a)
	var y := of(b)
	return x.days == y.days and x.intensity == y.intensity
