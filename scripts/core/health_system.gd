class_name HealthSystem
extends GameSystem
## Injuries and illness (GDD 4.6). Placeholder: it sits in the day loop and saves its (empty) state.
## M2 step 3 fills it in: body-area strain after each day (on_health), soreness warnings and new injuries
## as stop events, and injury restrictions as day changes made "by" injury.


func _init() -> void:
	id = "health"
