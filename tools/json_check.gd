extends SceneTree
## Dev tool: parses every data/*.json and prints the line of the first error in a file that does not parse.
## Run: godot --headless --path . -s res://tools/json_check.gd


func _initialize() -> void:
	var bad := 0
	var dir := DirAccess.open("res://data")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("res://data/" + f)
		var json := JSON.new()
		if json.parse(text) != OK:
			bad += 1
			print("ERROR %s line %d: %s" % [f, json.get_error_line(), json.get_error_message()])
	print("json_check: %s" % ("ALL FILES PARSE" if bad == 0 else "%d FILES FAILED" % bad))
	quit()
