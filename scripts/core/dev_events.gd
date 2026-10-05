class_name DevEvents
extends GameSystem
## Debug builds only (running from the Godot editor): a test system for the stop-event flow, until the
## health system has real ones. Press F8 in the career hub to arm it: at the end of the next played day it
## posts a stop event (so Play week stops there), and the answer becomes a day change for tomorrow,
## just like a real system would do it.


var armed := false


func _init() -> void:
	id = "dev"


func on_day_end(_ctx: Dictionary) -> void:
	if not armed:
		return
	armed = false
	Game.post_event(id, "Test: heavy legs",
			"This is a test event (F8). Your legs feel heavy after today's training. What do you do tomorrow?", [
				{"id": "keep", "label": "Keep going", "detail": "Train as planned."},
				{"id": "easy", "label": "Take it easy", "detail": "Tomorrow's sessions at Easy intensity."},
				{"id": "rest", "label": "Rest day", "detail": "No training tomorrow."},
			], true)


## "Tomorrow" is today's date in the game by now: the day that hasn't been played yet.
func on_answer(_event: Dictionary, choice: String) -> void:
	var week := Game.current_week()
	match choice:
		"easy": week.set_intensity(week.day, "easy", "player")
		"rest": week.make_rest_day(week.day, "player")


func to_dict() -> Dictionary:
	return {"armed": armed}


func from_dict(d: Dictionary) -> void:
	armed = bool(d.get("armed", false))
