extends Node
## Loads the static world data (data/*.json) once at startup.
## Game data lives in JSON files so it can be corrected without touching code.

var events: Array = []                 # data/events.json
var attributes: Array = []             # data/attributes.json
var clubs: Array = []                  # data/clubs.json
var hometowns: Array = []              # data/hometowns.json
var background_questions: Array = []   # data/background_questions.json
var background_pool: Dictionary = {}    # its "pool": the points pool rules (GDD 4.1.1)
var background_estimate: Dictionary = {}   # its "estimate": the coach's guess texts
var names: Dictionary = {}             # data/names_fi.json
var training: Dictionary = {}          # data/training.json: sessions, season rules, coach plan
var competitions: Dictionary = {}      # data/competitions.json: meets, standards, race training effect
var races: Dictionary = {}             # data/races.json: 800 m race model tuning
var race_cards: Dictionary = {}        # data/race_cards.json: the player's race cards, choice lines, the coach's shouts
var race_commentary: Dictionary = {}   # data/race_commentary.json: the broadcast voices, lines per race event, verdicts, the Race story
var coaches: Dictionary = {}           # data/coaches.json: the coaches' personalities and their words
var coaching: Dictionary = {}          # data/coaching.json: the coach model (attributes, effects, club coach, fit, trust)
var health: Dictionary = {}            # data/health.json: day intensity, body areas, strain, illness, risks
var injuries: Array = []               # data/injuries.json: the injury and illness catalogue
var periodization: Dictionary = {}     # data/periodization.json: phases, week rules, the coach's season plans
var form: Dictionary = {}              # data/form.json: race-day form (sharpness, freshness, words)
var help: Dictionary = {}              # data/help.json: the in-game help texts (screens and topics)
var moments: Dictionary = {}           # data/moments.json: rules and texts of the moments and message threads (GDD 4.9.5)
var coach_talk: Dictionary = {}        # data/coach_talk.json: the head coach's week talk, race message and day "why" lines (GDD 4.9.2)
var standards: Dictionary = {}         # data/standards.json: the real 800 m limits (SM, TF-juniorit / TF-nuoret, Kalevan kisat; GDD 4.9.2, session C5)
var goals: Dictionary = {}             # data/goals.json: the coach's season goals (levels, the estimate, process goals, texts; session C5)
var advice: Dictionary = {}            # data/advice.json: the coach's race advice by personality and his "Coach suggests" meets / targets (session C5)
var mind: Dictionary = {}              # data/mind.json: the moods confidence / motivation / stress, mental growth, the mental plan (GDD 4.9.4, session M1)
var market: Dictionary = {}            # data/market.json: the coach market (who you can get, scouting, distance, budget, the coaches' messages; session C6)
var towns: Dictionary = {}             # data/towns.json: the towns (population, region, SUL centre, winter-break group; session D1)
var urheilulukiot: Dictionary = {}     # data/urheilulukiot.json: sports schools and SUL's athletics centres (session D1)
var school: Dictionary = {}            # data/school.json: the school calendar (the real 2026-27 year, rules for later years; session D1)
var school_life: Dictionary = {}       # data/school_life.json: the school model (subjects, grades, tests, settings, life load; session S1)
var application: Dictionary = {}       # data/application.json: the joint application after grade 9, the test day, results, moving (session S3a)
## Every storylet of data/storylets/*.json (files sorted by name), each with "file" and "test" (the file's test flag) added.
var storylets: Array = []


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
	var background: Dictionary = _load("res://data/background_questions.json")
	background_questions = background.get("questions", [])
	background_pool = background.get("pool", {})
	background_estimate = background.get("estimate", {})
	names = _load("res://data/names_fi.json")
	training = _load("res://data/training.json")
	competitions = _load("res://data/competitions.json")
	races = _load("res://data/races.json")
	race_cards = _load("res://data/race_cards.json")
	race_commentary = _load("res://data/race_commentary.json")
	coaches = _load("res://data/coaches.json")
	coaching = _load("res://data/coaching.json")
	health = _load("res://data/health.json")
	injuries = _load("res://data/injuries.json").get("injuries", [])
	periodization = _load("res://data/periodization.json")
	form = _load("res://data/form.json")
	help = _load("res://data/help.json")
	moments = _load("res://data/moments.json")
	coach_talk = _load("res://data/coach_talk.json")
	standards = _load("res://data/standards.json")
	goals = _load("res://data/goals.json")
	advice = _load("res://data/advice.json")
	mind = _load("res://data/mind.json")
	market = _load("res://data/market.json")
	towns = _load("res://data/towns.json")
	urheilulukiot = _load("res://data/urheilulukiot.json")
	school = _load("res://data/school.json")
	school_life = _load("res://data/school_life.json")
	application = _load("res://data/application.json")
	storylets = []
	var files := Array(DirAccess.get_files_at("res://data/storylets"))
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var d := _load("res://data/storylets/" + f)
		for s in d.get("storylets", []):
			s.file = f
			s.test = bool(d.get("test", false))
			storylets.append(s)


func get_storylet(id: String) -> Dictionary:
	return _find(storylets, id)


func get_event(id: String) -> Dictionary:
	return _find(events, id)


func get_club(id: String) -> Dictionary:
	return _find(clubs, id)


## A town of data/towns.json by name, or {}.
func get_town(town_name: String) -> Dictionary:
	for t in towns.get("towns", []):
		if str(t.name) == town_name:
			return t
	return {}


## The size class id of a town (data/towns.json size_classes by population; "town" when it is not in the file).
func town_size(town_name: String) -> String:
	var t := get_town(town_name)
	if t.is_empty():
		return "town"
	var out := "town"
	for c in towns.size_classes:
		if int(t.population) >= int(c.min_population):
			out = str(c.id)
	return out


func get_session(id: String) -> Dictionary:
	return _find(training.get("sessions", []), id)


func get_injury(id: String) -> Dictionary:
	return _find(injuries, id)


func get_attribute(id: String) -> Dictionary:
	return _find(attributes, id)


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
