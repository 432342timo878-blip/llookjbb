class_name Coaches
extends RefCounted
## The coaches' voices (GDD 4.3.1, step R4): each personality has his own words (data/coaches.json). Since session C1
## (GDD 4.9.1) a coach is a record of CoachSystem and Athlete.coach_id names it; the record's `voice` is the personality
## used here. Tools may still set Athlete.coach_id to a voice id directly.


## The voice id (data/coaches.json) of the athlete's coach: a voice id set directly, else the voice of their coach
## record, else the club coach's voice made from their name.
static func id_of(a: Athlete) -> String:
	if a == null:
		return default_id()
	if a.coach_id != "" and Data.coaches.coaches.has(a.coach_id):
		return a.coach_id
	var cs := Game.get_system("coach") as CoachSystem
	if cs and cs.coaches.has(a.coach_id):
		var voice := str(cs.coaches[a.coach_id].get("voice", ""))
		if Data.coaches.coaches.has(voice):
			return voice
	return club_voice(a)


## The voice of the athlete's club coach: a voice id set as their coach_id, else one of `pool` picked from a hash of
## their name (as before C1, so older careers keep their coach).
static func club_voice(a: Athlete) -> String:
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
