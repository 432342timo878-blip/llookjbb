extends Node
## The running career: the player's athlete and the current date.

## Career start: the Finnish training year begins in autumn.
const START_DATE := {"year": 2026, "month": 11, "day": 2}

var athlete: Athlete
var date := START_DATE.duplicate()


func start_career(new_athlete: Athlete) -> void:
	athlete = new_athlete
	date = START_DATE.duplicate()
