extends SceneTree
## Dev tool: parses every data/*.json (and data/storylets/*.json) and prints the line of the first error in a file that does not parse.
## Godot's parser accepts a trailing comma ("a", ]) and a BOM, standard JSON (an editor, another tool) does not, so the text
## is also scanned for those two (fix session 2026-10-10).
## Run: godot --headless --path . -s res://tools/json_check.gd


func _initialize() -> void:
	var bad := 0
	var comma := RegEx.new()
	comma.compile(",\\s*[}\\]]")
	var files := []
	for folder in ["res://data/", "res://data/storylets/"]:   # (the moments have their own folder, session C2)
		for f in DirAccess.get_files_at(folder):
			files.append(folder + f)
	for path in files:
		var f: String = path.trim_prefix("res://data/")
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
	bad += _check_research_data()
	print("json_check: %s" % ("ALL FILES PARSE" if bad == 0 else "%d PROBLEMS" % bad))
	quit(0 if bad == 0 else 1)


func _load_json(f: String) -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://data/" + f)) != OK:
		return null
	return json.data


## Session D1 (research data): every real coach has a source, a url with the date read for each source, attributes 1-20 for
## all 11 attributes, no youth names; urheilulukiot.json and school.json: every `src` points at an existing source with a url
## and a read date. Returns the number of problems.
func _check_research_data() -> int:
	var bad := 0
	var coaching = _load_json("coaching.json")
	if coaching is Dictionary:
		var ids := []
		for a in coaching.get("attributes", []):
			ids.append(str(a.id))
		var seen := {}
		for c in coaching.get("real", []):
			var who := str(c.get("id", "?"))
			if seen.has(who):
				bad += 1
				print("ERROR coaching.json real %s: id used twice" % who)
			seen[who] = true
			if not bool(c.get("real", false)) or str(c.get("source", "")) == "":
				bad += 1
				print("ERROR coaching.json real %s: needs real = true and a `source`" % who)
			var srcs: Array = c.get("sources", [])
			if srcs.is_empty():
				bad += 1
				print("ERROR coaching.json real %s: no `sources` (url + read date)" % who)
			for s in srcs:
				if not str(s.get("url", "")).begins_with("http") or str(s.get("read", "")) == "":
					bad += 1
					print("ERROR coaching.json real %s: a source needs a url and the date it was read" % who)
			for id in ids:
				var v = c.get("attributes", {}).get(id, null)
				if not (v is float or v is int) or v < 1 or v > 20 or v != floor(v):
					bad += 1
					print("ERROR coaching.json real %s: attribute %s must be a whole number 1-20" % [who, id])
	for f in ["urheilulukiot.json", "school.json", "lukio.json"]:   # (lukio.json: session S3b)
		var data = _load_json(f)
		if not data is Dictionary:
			continue
		var ids := {}
		var list: Array = data.get("sources", [])
		if f == "school.json":
			list = data.get("verified", {}).get("sources", data.get("sources", []))
		for s in list:
			ids[int(s.get("id", -1))] = true
			if not str(s.get("url", "")).begins_with("http") or str(s.get("read", "")) == "":
				bad += 1
				print("ERROR %s: source %s needs a url and the date it was read" % [f, str(s.get("id", "?"))])
		bad += _check_src(f, data, ids, "")
	return bad


## Walks a data tree; every `src` (a number or a list of numbers) must be an id of the file's `sources`.
func _check_src(f: String, node: Variant, ids: Dictionary, path: String) -> int:
	var bad := 0
	if node is Dictionary:
		for k in node:
			if (str(k) == "src" or str(k).ends_with("_src")) and (node[k] is float or node[k] is int or node[k] is Array):
				for n in (node[k] if node[k] is Array else [node[k]]):
					if not ids.has(int(n)):
						bad += 1
						print("ERROR %s %s: src %s is not in `sources`" % [f, path, str(n)])
			elif str(k) != "sources":
				bad += _check_src(f, node[k], ids, path + "/" + str(k))
	elif node is Array:
		for i in node.size():
			bad += _check_src(f, node[i], ids, path + "[%d]" % i)
	return bad
