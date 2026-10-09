extends Node
## Loads the static world data (data/*.json) once at startup.
## Game data lives in JSON files so it can be corrected without touching code.

var events: Array = []                 # data/events.json
var attributes: Array = []             # data/attributes.json
var clubs: Array = []                  # data/clubs.json
var hometowns: Array = []              # data/hometowns.json
var background_questions: Array = []   # data/background_questions.json
var names: Dictionary = {}             # data/names_fi.json
var training: Dictionary = {}          # data/training.json: sessions, season rules, coach plan
var competitions: Dictionary = {}      # data/competitions.json: meets, standards, race training effect
var races: Dictionary = {}             # data/races.json: 800 m race model tuning
var race_cards: Dictionary = {}        # data/race_cards.json: the player's race cards, choice lines, the coach's shouts
var race_commentary: Dictionary = {}   # data/race_commentary.json: the broadcast voices, lines per race event, verdicts, the Race story
var coaches: Dictionary = {}           # data/coaches.json: the coaches' personalities and their words
var health: Dictionary = {}            # data/health.json: day intensity, body areas, strain, illness, risks
var injuries: Array = []               # data/injuries.json: the injury and illness catalogue
var periodization: Dictionary = {}     # data/periodization.json: phases, week rules, the coach's season plans
var form: Dictionary = {}              # data/form.json: race-day form (sharpness, freshness, words)
var help: Dictionary = {}              # data/help.json: the in-game help texts (screens and topics)


func _ready() -> void:
	events = _load("res://data/events.json").get("events", [])
	attributes = _load("res://data/attributes.json").get("attributes", [])
	clubs = _load("res://data/clubs.json").get("clubs", [])
	hometowns = _load("res://data/hometowns.json").get("hometowns", [])
	# Every club's home town can also be picked as a hometown.
	for club in clubs:
		if not club.city in hometowns:
			hometowns.append(club.city)
	hometowns.sort()
	background_questions = _load("res://data/background_questions.json").get("questions", [])
	names = _load("res://data/names_fi.json")
	training = _load("res://data/training.json")
	competitions = _load("res://data/competitions.json")
	races = _load("res://data/races.json")
	race_cards = _load("res://data/race_cards.json")
	race_commentary = _load("res://data/race_commentary.json")
	coaches = _load("res://data/coaches.json")
	health = _load("res://data/health.json")
	injuries = _load("res://data/injuries.json").get("injuries", [])
	periodization = _load("res://data/periodization.json")
	form = _load("res://data/form.json")
	help = _load("res://data/help.json")


func get_event(id: String) -> Dictionary:
	return _find(events, id)


func get_club(id: String) -> Dictionary:
	return _find(clubs, id)


func get_session(id: String) -> Dictionary:
	return _find(training.get("sessions", []), id)


func get_injury(id: String) -> Dictionary:
	return _find(injuries, id)


## Attribute definitions of one category ("physical", "technical", "mental", "hidden").
func attributes_in(category: String) -> Array:
	return attributes.filter(func(a): return a.category == category)


func _find(list: Array, id: String) -> Dictionary:
	for item in list:
		if item.id == id:
			return item
	return {}


func _load(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Could not load %s" % path)
	return {}
