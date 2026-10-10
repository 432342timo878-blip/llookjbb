extends SceneTree
## Dev tool: parses every data/*.json and prints the line of the first error in a file that does not parse.
## Godot's parser accepts a trailing comma ("a", ]) and a BOM, standard JSON (an editor, another tool) does not, so the text
## is also scanned for those two (fix session 2026-10-10).
## Run: godot --headless --path . -s res://tools/json_check.gd


func _initialize() -> void:
	var bad := 0
	var comma := RegEx.new()
	comma.compile(",\\s*[}\\]]")
	var dir := DirAccess.open("res://data")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var bytes := FileAccess.get_file_as_bytes("res://data/" + f)
		if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
			bad += 1
			print("ERROR %s: starts with a BOM (write data files without one)" % f)
		var text := FileAccess.get_file_as_string("res://data/" + f)
		var json := JSON.new()
		if json.parse(text) != OK:
			bad += 1
			print("ERROR %s line %d: %s" % [f, json.get_error_line(), json.get_error_message()])
			continue
		for m in comma.search_all(text):
			bad += 1
			print("ERROR %s line %d: trailing comma (Godot accepts it, standard JSON does not)" % [f, text.substr(0, m.get_start()).count("\n") + 1])
	print("json_check: %s" % ("ALL FILES PARSE" if bad == 0 else "%d PROBLEMS" % bad))
	quit(0 if bad == 0 else 1)
