class_name Coaches
extends RefCounted
## The coaches by the track (GDD 4.3.1, step R4): each has a personality and his own words (data/coaches.json).
## The club coach of a career is one of the pool, picked from a hash of the athlete's name; a hired coach (later) sets
## Athlete.coach_id.


## The id of the athlete's coach: their own coach_id, else the club coach made from their name.
static func id_of(a: Athlete) -> String:
	if a == null:
		return default_id()
	if a.coach_id != "" and Data.coaches.coaches.has(a.coach_id):
		return a.coach_id
	var pool: Array = Data.coaches.pool
	return str(pool[posmod((a.first_name + " " + a.last_name).hash(), pool.size())])


static func default_id() -> String:
	return str(Data.coaches.pool[0])


## The coach's data (name, title, talk, shouts, lines, story); the default coach for an unknown id.
static func get_coach(id: String) -> Dictionary:
	return Data.coaches.coaches.get(id, Data.coaches.coaches[default_id()])


## The words he shouts on a decision card for an answer, or `fallback` (data/race_cards.json coach.shouts).
static func shout(id: String, card: String, option: String, fallback: String) -> String:
	if id == "":
		return fallback
	return str(get_coach(id).shouts.get(card, {}).get(option, fallback))
