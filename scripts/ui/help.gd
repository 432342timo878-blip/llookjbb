class_name Help
## The in-game help (GDD 5 "Help"): the texts in `data/help.json` and which entries the player has read.
## Screen entries ("overview", "calendar", "day_editor", …) are opened by a screen's "?" (HelpButton); topic
## entries ("form", "plan_risk", …) are opened from a section's "See also". "Read" is a setting of the player, not
## of a career, so it is kept in its own file (not in the save): entry id -> the version that was read. An entry
## whose version went up since is "new" again.

## Where "read" is stored. Dev tools point it somewhere else so they never touch the player's file.
static var SEEN_PATH := "user://help_seen.cfg"

static var _seen: ConfigFile = null
static var _seen_path := ""


## The entry (screen or topic): {title, version, sections: [{heading, text, see?}]}, or {} when there is none.
static func entry(id: String) -> Dictionary:
	var screens: Dictionary = Data.help.get("screens", {})
	if screens.has(id):
		return screens[id]
	return Data.help.get("topics", {}).get(id, {})


static func exists(id: String) -> bool:
	return not entry(id).is_empty()


static func is_topic(id: String) -> bool:
	return Data.help.get("topics", {}).has(id)


## Not read yet, or changed since it was read (its version went up).
static func is_new(id: String) -> bool:
	var e := entry(id)
	if e.is_empty():
		return false
	return int(_config().get_value("seen", id, 0)) < int(e.get("version", 1))


static func mark_seen(id: String) -> void:
	var e := entry(id)
	if e.is_empty() or not is_new(id):
		return
	var cfg := _config()
	cfg.set_value("seen", id, int(e.get("version", 1)))
	cfg.save(SEEN_PATH)
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.call_group(HelpButton.GROUP, "refresh")   # every "?" of this entry loses its "new" dot


## Forgets what was read (dev tools; a "show help as new" option could use it).
static func reset_seen() -> void:
	_seen = ConfigFile.new()
	_seen_path = SEEN_PATH
	if FileAccess.file_exists(SEEN_PATH):
		DirAccess.remove_absolute(SEEN_PATH)


static func _config() -> ConfigFile:
	if _seen == null or _seen_path != SEEN_PATH:
		_seen = ConfigFile.new()
		_seen_path = SEEN_PATH
		_seen.load(SEEN_PATH)   # a missing file just leaves it empty
	return _seen
