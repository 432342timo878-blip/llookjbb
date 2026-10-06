class_name GameSystem
extends RefCounted
## Base for systems that hook into the day loop (GDD 4.7): Health now, Coach and School later.
## Every played day the game calls, in this order:
##   on_day_start → (training or race) → on_health → on_day_end, and after Sunday's day end: on_week_end.
## `ctx` is {date, day (0 = Mon), day_type ("weekday" / "weekend"), week (the WeekSim)}; on_health and
## on_day_end also get "record" (what was actually done today, see WeekSim.played) and on_week_end gets
## "report" (the weekly report). A system can change today or later days of this week through ctx.week
## (e.g. set_sessions(d, ids, "injury")) and post events with Game.post_event(id, ...). The player's answer
## to one of its events comes back in on_answer. Each system saves its own state (to_dict / from_dict).
## on_week_start comes when a new week is set up (before its first day starts), so a system can put its
## day changes into the new week straight away (e.g. injury limits).

var id := ""   # also the event `source` this system answers for


func on_week_start(_week: WeekSim) -> void:
	pass


func on_day_start(_ctx: Dictionary) -> void:
	pass


func on_health(_ctx: Dictionary) -> void:
	pass


func on_day_end(_ctx: Dictionary) -> void:
	pass


func on_week_end(_ctx: Dictionary) -> void:
	pass


## The player picked `choice` (a choice id, or "ok" for an event without choices) on one of this system's events.
func on_answer(_event: Dictionary, _choice: String) -> void:
	pass


func to_dict() -> Dictionary:
	return {}


func from_dict(_d: Dictionary) -> void:
	pass
