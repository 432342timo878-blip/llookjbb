class_name SeasonPlan
extends RefCounted
## The player's training plan over time (GDD 4.8). Step 6a has repeat mode only: one week plan that repeats
## every week (the M1 behaviour). Phases, the coach's season plans and targets come in later steps; they
## add fields here, and `week_for` stays the one place the game asks "what is the plan for this week?".

var mode := "repeat"
var repeat_week: Dictionary = WeekPlan.empty()   # a week plan, see WeekPlan (Game.start_career puts the coach's in)


## A repeat-mode season with the given weekly plan (a week plan or the old plain Array of days).
static func repeating(plan: Variant) -> SeasonPlan:
	var s := SeasonPlan.new()
	s.repeat_week = WeekPlan.copy_of(plan)
	return s


## The week plan for the week starting on `monday` (the plan itself, not a copy: edits go straight into it).
func week_for(_monday: Dictionary) -> Dictionary:
	return repeat_week


# --- Save / load -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"mode": mode, "repeat_week": repeat_week}


static func from_dict(d: Dictionary) -> SeasonPlan:
	var s := SeasonPlan.new()
	s.mode = "repeat"   # the only mode so far
	var week = d.get("repeat_week", {})
	s.repeat_week = WeekPlan.make(week.get("days", []), week.get("intensity", [])) if week is Dictionary and not week.is_empty() \
			else WeekPlan.coach()
	return s
