class_name SaveGame
## Save slots as JSON files in user://saves/. "autosave" is rewritten every week; other slots are
## snapshots the player makes with the Save button and never change.

## Where saves go. Dev tools point this elsewhere so they never touch the player's saves.
static var DIR := "user://saves/"
const AUTOSAVE := "autosave"
const VERSION := 1


static func save(slot: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var a := Game.athlete
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"summary": "%s · %s" % [a.full_name(), UIKit.format_date(Game.date)],
		"game": Game.to_dict(),
	}
	var f := FileAccess.open(DIR + slot + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " "))


## A new snapshot slot (never overwritten). Returns its name.
static func save_snapshot() -> String:
	var slot := "save_" + Time.get_datetime_string_from_system(false, false).replace(":", "-")
	save(slot)
	return slot


static func load_slot(slot: String) -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + slot + ".json"))
	if not parsed is Dictionary or not parsed.has("game"):
		push_error("Could not load save %s" % slot)
		return false
	Game.from_dict(parsed.game)
	return true


static func delete(slot: String) -> void:
	DirAccess.remove_absolute(DIR + slot + ".json")


## Saves, newest first: [{slot, summary, saved_at, auto}].
static func list() -> Array:
	var saves := []
	if not DirAccess.dir_exists_absolute(DIR):
		return saves
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + file))
		if not parsed is Dictionary:
			continue
		var slot := file.trim_suffix(".json")
		saves.append({"slot": slot, "summary": parsed.get("summary", slot),
				"saved_at": parsed.get("saved_at", ""), "auto": slot == AUTOSAVE})
	saves.sort_custom(func(x, y): return x.saved_at > y.saved_at)
	return saves
