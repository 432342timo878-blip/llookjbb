extends SceneTree
## R6a check + screenshots for the viewpoint prototypes (scenes/screens/viewpoint_proto.tscn).
##   godot --headless --path . -s res://tools/proto_view_check.gd               the recording checks + opens the screen in all three views
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 -s res://tools/proto_view_check.gd -- shots <out_dir> [indoor]
##                                                                              the same, then saves screenshots of every view at several times
## Checks: the recording is deterministic and replays what the engine did (finish times = the engine's), it is tight enough to be worth
## watching, every runner's frames line up; the screen builds and renders without a script error in each view, outdoors and indoors.

var _fails := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _run() -> void:
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	load("res://scripts/core/game_config.gd").use("lab")
	await _frames(10)
	var args := OS.get_cmdline_user_args()
	var Rec = load("res://scripts/proto/race_recording.gd")
	for indoor in [false, true]:
		var label := "indoor" if indoor else "outdoor"
		var a = Rec.make(indoor, 4100, 60)
		var b = Rec.make(indoor, 4100, 60)
		print("proto_view_check: %s seed %d, %d frames (%.1f s), tightness score %.2f, results %s" % [label, a.seed_used, a.count, a.duration(),
				a.score, str(a.results.map(func(r): return "%s %.2f" % [r.name, r.time]))])
		_ok("%s: the same arguments give the same race" % label, a.seed_used == b.seed_used and a.d[a.player] == b.d[b.player] and a.finish_t == b.finish_t)
		var times_match := true
		for r in a.results:
			if r.status == "":
				var i: int = a.names.find(r.name)
				if absf(float(a.finish_t[i]) - float(r.time)) > 0.011:
					times_match = false
		_ok("%s: finish times are the engine's own" % label, times_match)
		var lined_up := true
		for i in a.n:
			if a.d[i].size() != a.count or a.v[i].size() != a.count or a.flags[i].size() != a.count or a.res[i].size() != a.count or a.lat[i].size() != a.count:
				lined_up = false
		_ok("%s: every runner has every frame" % label, lined_up)
		var monotone := true
		for i in a.n:
			for f in range(1, a.count):
				if a.d[i][f] < a.d[i][f - 1] - 0.001:
					monotone = false
		_ok("%s: distances never go backwards" % label, monotone)
		_ok("%s: the race is tight (score < 4)" % label, a.score < 4.0)
		var p = a.position_at(a.player, 20.0)
		_ok("%s: positions are on the track" % label, p.length() < 80.0)
	# the screen, every view
	var router = current_scene.get_node("/root/Router")
	router.go("viewpoint_proto")
	await _frames(5)
	var screen: Control = current_scene.get_node("ScreenHost").get_child(-1)
	var guard := 0
	while (screen.rec == null or screen._busy) and guard < 4000:
		guard += 1
		await _frames(1)
	_ok("the screen loaded a recording", screen.rec != null)
	var shots_dir := ""
	if args.has("shots") and args.find("shots") + 1 < args.size():
		shots_dir = args[args.find("shots") + 1]
		DirAccess.make_dir_recursive_absolute(shots_dir)
	var times := [2.0, 25.0, 60.0, 95.0, 118.0, 126.0, 133.0, 138.0, 145.0]
	var tracks := [false, true] if args.has("indoor") else [false]
	if args.has("arena"):
		screen.toggle_style()
		await _frames(5)
	for indoor in tracks:
		if indoor:
			screen._load(true)
			await _frames(5)
			guard = 0
			while screen._busy and guard < 4000:
				guard += 1
				await _frames(1)
		for v in 3:
			screen.set_view(v)
			screen.playing = false
			for tt in times:
				screen.seek(minf(tt, screen.rec.duration() - 0.2))
				await _frames(6)
				if shots_dir != "":
					var img: Image = root.get_viewport().get_texture().get_image()
					img.save_png("%s/%s%s_view%d_t%03d.png" % [shots_dir, "indoor" if indoor else "outdoor", "_arena" if args.has("arena") else "", v + 1, int(tt)])
		# play a few seconds for real in each view (the live loop)
		for v in 3:
			screen.set_view(v)
			screen.seek(40.0)
			screen.playing = true
			await _frames(40)
		screen.playing = false
	# fixed looks at the stadium: the field events, the finish area, an overview
	if shots_dir != "" and not args.has("indoor"):
		screen.set_view(0)
		screen.playing = false
		screen.seek(70.0)
		var looks := {
			"hj": [Vector3(-2, 2.2, -14), Vector3(-8, 1.2, -24), 42.0],
			"pv": [Vector3(6, 2.4, 14), Vector3(14, 1.8, 25), 42.0],
			"jt": [Vector3(32, 2.4, 10), Vector3(22, 1.0, 0), 45.0],
			"sp": [Vector3(46, 2.4, 22), Vector3(56, 0.8, 10), 40.0],
			"finish": [Vector3(31, 2.2, 36), Vector3(42.2, 1.0, 42), 40.0],
			"tower": [Vector3(30, 3.0, 40), Vector3(43, 3.5, 53), 45.0],
			"overview": [Vector3(0, 70, 95), Vector3(0, 0, 0), 55.0],
			"stand": [Vector3(-20, 3.5, 20), Vector3(0, 6, 60), 60.0],
		}
		for k in looks:
			var l: Array = looks[k]
			screen.debug_cam = {"pos": l[0], "look": l[1], "fov": l[2]}
			await _frames(6)
			var img2: Image = root.get_viewport().get_texture().get_image()
			img2.save_png("%s/look_%s%s.png" % [shots_dir, k, "_arena" if args.has("arena") else ""])
		# contact sheets of the field events in action (6 moments each, 3 x 2)
		for k in ["hj", "pv", "jt", "sp"]:
			var l2: Array = looks[k]
			screen.debug_cam = {"pos": l2[0], "look": l2[1], "fov": l2[2]}
			var sheet := Image.create(1920, 720, false, Image.FORMAT_RGBA8)
			var n := 0
			for tt in [70.0, 74.0, 78.0, 82.0, 86.0, 90.0]:
				screen.seek(tt)
				await _frames(4)
				var im: Image = root.get_viewport().get_texture().get_image()
				im.convert(Image.FORMAT_RGBA8)
				im.resize(640, 360, Image.INTERPOLATE_BILINEAR)
				sheet.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i((n % 3) * 640, (n / 3) * 360))
				n += 1
			sheet.save_png("%s/sheet_%s%s.png" % [shots_dir, k, "_arena" if args.has("arena") else ""])
		screen.debug_cam = {}
	_ok("the three views ran (read the output above for SCRIPT ERROR lines)", true)
	print("proto_view_check: ALL CHECKS PASSED" if _fails == 0 else "proto_view_check: %d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
