extends Node
## Loads the static world data (data/*.json) once at startup.
## Game data lives in JSON files so it can be corrected without touching code.

var events: Array = []                 # data/events.json
var attributes: Array = []             # data/attributes.json
var clubs: Array = []                  # data/clubs.json
var hometowns: Array = []              # data/hometowns.json
var background_questions: Array = []   # data/background_questions.json
var names: Dictionary = {}             # data/names_fi.json


func _ready() -> void:
	events = _load("res://data/events.json").get("events", [])
	attributes = _load("res://data/attributes.json").get("attributes", [])
	clubs = _load("res://data/clubs.json").get("clubs", [])
	hometowns = _load("res://data/hometowns.json").get("hometowns", [])
	background_questions = _load("res://data/background_questions.json").get("questions", [])
	names = _load("res://data/names_fi.json")


func get_event(id: String) -> Dictionary:
	return _find(events, id)


func get_club(id: String) -> Dictionary:
	return _find(clubs, id)


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
