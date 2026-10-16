extends SceneTree
## Dev tool: loads every script of scripts/ (core and ui) so a parse or type error is printed (a headless import does not show them).
## Run: godot --headless --path . -s res://tools/load_check.gd
## Read stderr too. Prints LOAD OK or the scripts that did not load.


func _initialize() -> void:
	var bad := 0
	for folder in ["res://scripts/core/", "res://scripts/ui/", "res://scripts/"]:
		for f in DirAccess.get_files_at(folder):
			if not f.ends_with(".gd"):
				continue
			var s = load(folder + f)
			if s == null or (s is GDScript and not s.can_instantiate() and not s.is_abstract()):
				bad += 1
				print("DID NOT LOAD: %s%s" % [folder, f])
	print("LOAD OK" if bad == 0 else "%d script(s) did not load" % bad)
	quit(0 if bad == 0 else 1)
