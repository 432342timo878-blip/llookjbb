class_name SaveGame
## Save slots as JSON files in user://saves/. "autosave" is rewritten after every played day; other slots
## are snapshots the player makes with the Save button and never change.
## Version 2 (M2) adds the week in progress, day log, events and system states; version 3 (M2 step 6a) replaces
## the plain `training_plan` with the `season` plan. Older saves still load (see Game.from_dict).

## Where saves go. Dev tools point this elsewhere so they never touch the player's saves.
static var DIR := "user://saves/"
const AUTOSAVE := "autosave"
const VERSION := 3


static func save(slot: String) -> void:
	if Game.dev_test:
		return   # a test career of the Dev menu is never saved
	DirAccess.make_dir_recursive_absolute(DIR)
	var a := Game.athlete
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"summary": "%s · %s" % [a.full_name(), Calendar.format_day(Game.date)],
		"game": Game.to_dict(),
	}
	var f := FileAccess.open(DIR + slot + ".json", FileAccess.WRITE)
	# Full precision, so a loaded game continues exactly as it would have without saving.
	f.store_string(JSON.stringify(data, " ", true, true))


## A new snapshot slot (never overwritten). Returns its name.
static func save_snapshot() -> String:
	var slot := "save_" + Time.get_datetime_string_from_system(false, false).replace(":", "-")
	save(slot)
	return slot


static func load_slot(slot: String) -> bool:
	var text := FileAccess.get_file_as_string(DIR + slot + ".json")
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.has("game"):
		push_error("Could not load save %s" % slot)
		return false
	if int(parsed.get("version", 1)) > VERSION:
		push_error("Save %s is from a newer version of the game" % slot)
		return false
	_exact_numbers(parsed, _number_tokens(text), {"i": 0})
	Game.from_dict(parsed.game)
	return true


# --- Exact numbers -------------------------------------------------------------------------------
# Godot's JSON reader can be off in the last binary digit of a decimal number (about 1 in 8), so a loaded
# game would drift from the saved one by ~1e-15. The text itself is exact, so every decimal is read again:
# the parsed value or a neighbouring one, whichever writes back as exactly the same text.

## The number tokens of a JSON text, in order (strings skipped).
static func _number_tokens(text: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	var n := text.length()
	var i := 0
	while i < n:
		var c := text.unicode_at(i)
		if c == 34:   # " starts a string: skip it, and escaped characters inside it
			i += 1
			while i < n and text.unicode_at(i) != 34:
				i += 2 if text.unicode_at(i) == 92 else 1
		elif c == 45 or (c >= 48 and c <= 57):   # - or a digit
			var start := i
			while i < n and "-+.eE0123456789".contains(text[i]):
				i += 1
			tokens.append(text.substr(start, i - start))
			continue
		i += 1
	return tokens


## Walks the parsed data in text order and corrects every decimal with its token.
static func _exact_numbers(v: Variant, tokens: PackedStringArray, at: Dictionary) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v:
				v[k] = _exact_numbers(v[k], tokens, at)
		TYPE_ARRAY:
			for i in v.size():
				v[i] = _exact_numbers(v[i], tokens, at)
		TYPE_FLOAT:
			if at.i < tokens.size():
				var token: String = tokens[at.i]
				at.i += 1
				return _exact_float(v, token)
	return v


static func _exact_float(value: float, token: String) -> float:
	if not (token.contains(".") or token.contains("e") or token.contains("E")):
		return value   # whole numbers are read exactly
	if JSON.stringify(value, "", true, true) == token:
		return value
	# A close estimate from the digits (within a few steps of the exact value), then the neighbour
	# that writes back as exactly the token.
	var estimate := _estimate(token)
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, estimate)
	var bits := bytes.decode_s64(0)
	for step in [0, 1, -1, 2, -2, 3, -3, 4, -4]:
		bytes.encode_s64(0, bits + step)
		var candidate := bytes.decode_double(0)
		if JSON.stringify(candidate, "", true, true) == token:
			return candidate
	return value   # e.g. an old save written with fewer digits: keep what was read


## "-0.0032010087842753" → all digits as one whole number × a power of ten.
static func _estimate(token: String) -> float:
	var t := token.to_lower()
	var exponent := 0
	if t.contains("e"):
		exponent = t.get_slice("e", 1).to_int()
		t = t.get_slice("e", 0)
	var negative := t.begins_with("-")
	t = t.trim_prefix("-")
	var fraction := t.get_slice(".", 1) if t.contains(".") else ""
	exponent -= fraction.length()
	var digits := (t.get_slice(".", 0) + fraction).lstrip("0")
	if digits == "":
		return 0.0
	if digits.length() > 18:   # more than a 64-bit whole number holds: drop the extra digits
		exponent += digits.length() - 18
		digits = digits.left(18)
	var result := float(digits.to_int())
	while exponent < 0:
		var e := mini(-exponent, 22)   # 10^22 is the largest power of ten a float holds exactly
		result /= pow(10.0, e)
		exponent += e
	while exponent > 0:
		var e := mini(exponent, 22)
		result *= pow(10.0, e)
		exponent -= e
	return -result if negative else result


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
