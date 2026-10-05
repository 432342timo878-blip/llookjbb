extends Node
## Loads the static world data (data/*.json) once at startup.
## Game data lives in JSON files so it can be corrected without touching code.

var events: Array = []      # data/events.json
var attributes: Array = []  # data/attributes.json


func _ready() -> void:
	events = _load_list("res://data/events.json", "events")
	attributes = _load_list("res://data/attributes.json", "attributes")


func get_event(id: String) -> Dictionary:
	for event in events:
		if event.id == id:
			return event
	return {}


func _load_list(path: String, key: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary and parsed.get(key) is Array:
		return parsed[key]
	push_error("Could not load '%s' from %s" % [key, path])
	return []
