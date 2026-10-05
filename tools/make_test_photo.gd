extends SceneTree
## Dev tool: writes a deliberately harsh, busy, bright "stadium-like" test image to assets/backgrounds/default.png,
## to check that the backdrop shader keeps screens readable even with a bad photo. Delete the file afterwards.
##   godot --headless -s res://tools/make_test_photo.gd

func _initialize() -> void:
	var w := 1920
	var h := 1080
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in h:
		for x in w:
			var sky := Color(0.35, 0.55, 0.9).lerp(Color(0.95, 0.85, 0.7), float(y) / h)
			var track := Color(0.85, 0.3, 0.2) if y > h * 0.62 else sky
			img.set_pixel(x, y, track)
	# Bright "floodlights" and "crowd" speckles.
	for i in 400:
		var cx := rng.randi_range(0, w - 1)
		var cy := rng.randi_range(0, int(h * 0.6))
		var c := Color.from_hsv(rng.randf(), 0.6, 1.0)
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var px := cx + dx
				var py := cy + dy
				if px >= 0 and px < w and py >= 0 and py < h:
					img.set_pixel(px, py, c)
	for lane in 8:
		var y0 := int(h * 0.64) + lane * 40
		for x in w:
			for t in 4:
				if y0 + t < h:
					img.set_pixel(x, y0 + t, Color.WHITE)
	DirAccess.make_dir_recursive_absolute("res://assets/backgrounds")
	img.save_png("res://assets/backgrounds/default.png")
	quit()
