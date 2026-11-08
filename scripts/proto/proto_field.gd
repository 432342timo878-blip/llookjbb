class_name ProtoField
extends Node3D
## R6a prototype, round 2: the other events of the meet, playing out in the infield while the 800 m is run. WHAT is on comes from the
## meet's program, never made up on the spot (GDD 4.11 decision 12): `PROGRAM` is a small FICTIONAL timetable standing in for the real
## meet-schedule system that is still to be designed; an event is "on" when its window overlaps the race. Each active event shows its
## real equipment and athletes who take their attempts in turn (walk to the mark, wait, the attempt, the result, walk back).
## Sites are Node3D frames: local +X is the direction of the run-up / throw, local -Z... is simply z; athletes are children of the frame.
## Everything is animated from the time alone (deterministic), the athletes use the same ProtoFigure body as the runners.

## start / end = seconds from the 800 m start (negative = already under way); "done" = finished before: equipment only.
const PROGRAM := [
	{"id": "high_jump", "label": "HJ", "title": "Boys 14 High jump", "start": -1500, "end": 2400, "athletes": 8, "bar": 1.45},
	{"id": "pole_vault", "label": "PV", "title": "Boys 14 Pole vault", "start": -900, "end": 3000, "athletes": 6, "bar": 2.80},
	{"id": "javelin", "label": "JT", "title": "Boys 14 Javelin", "start": -300, "end": 1500, "athletes": 9},
	{"id": "shot_put", "label": "SP", "title": "Boys 14 Shot put", "start": -600, "end": 1800, "athletes": 9},
	{"id": "long_jump", "label": "LJ", "title": "Girls 14 Long jump", "start": -4000, "end": -1500, "athletes": 0, "done": true},
]

const BODY_H := 0.95   # the pelvis pivot above the figure's feet (ProtoFigure.pose_stand)
const SHIRTS := [Color("#d94a3a"), Color("#2f6db5"), Color("#e8e8ee"), Color("#6aa84f"), Color("#f2b632"), Color("#8e5ea2"), Color("#2fb5a5"), Color("#d94a8a"), Color("#3a3f4b")]

var rec: RaceRecording
var enabled := true
var sites: Dictionary = {}
var duration := 160.0
var _font: Font


func _init(recording: RaceRecording) -> void:
	rec = recording
	duration = rec.duration()
	_font = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	if rec.indoor:
		return   # (the hall's field events are another site list: later)
	var layout := {
		"high_jump": [Vector3(-8, 0, -24), PI / 2.0],
		"pole_vault": [Vector3(14, 0, 25), 0.0],
		"javelin": [Vector3(20, 0, 0), PI],
		"shot_put": [Vector3(56, 0, 10), 0.0],
		"long_jump": [Vector3(34, 0, -28), 0.0],
	}
	for ev in PROGRAM:
		var l: Array = layout[ev.id]
		var frame := Node3D.new()
		frame.position = l[0]
		frame.rotation.y = l[1]
		add_child(frame)
		var s := {"ev": ev, "frame": frame, "figs": [], "home": [], "nodes": {}, "k": -1, "active": _is_active(ev)}
		sites[ev.id] = s
		call("_build_" + str(ev.id), s)
		if s.active:
			_spawn(s)


func _is_active(ev: Dictionary) -> bool:
	return not ev.get("done", false) and float(ev.start) < duration and float(ev.end) > 0.0


## What is going on in the field now, one short line per active event (for the scoreboard).
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	if not enabled or rec.indoor:
		return out
	for id in sites:
		var s: Dictionary = sites[id]
		if s.active:
			var ev: Dictionary = s.ev
			var extra := ""
			if ev.has("bar"):
				extra = "  %.2f" % float(ev.bar)
			out.append("%s%s" % [str(ev.label), extra])
	if not out.is_empty():
		out.insert(0, "IN THE FIELD")
	return out


# --- helpers ----------------------------------------------------------------------------------------------------------

func _std(c: Color, rough := 0.85, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m


func _box(parent: Node3D, center: Vector3, size: Vector3, c: Color, rough := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _std(c, rough)
	mi.position = center
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, center: Vector3, radius: float, height: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 14
	mi.mesh = m
	mi.material_override = _std(c)
	mi.position = center
	parent.add_child(mi)
	return mi


func _runway(frame: Node3D, x0: float, x1: float, z := 0.0, w := 1.22) -> void:
	_box(frame, Vector3((x0 + x1) / 2.0, 0.012, z), Vector3(x1 - x0, 0.016, w), Palette.TRACK.darkened(0.05), 0.95)
	for dz in [-w / 2.0, w / 2.0]:
		_box(frame, Vector3((x0 + x1) / 2.0, 0.022, z + dz), Vector3(x1 - x0, 0.01, 0.05), Color.WHITE, 0.6)


func _sector(frame: Node3D, origin_x: float, length: float, half_angle_deg: float, z := 0.0) -> void:
	for sgn in [-1.0, 1.0]:
		var a: float = deg_to_rad(half_angle_deg) * float(sgn)
		var mi := _box(frame, Vector3(origin_x + cos(a) * length / 2.0, 0.015, z + sin(a) * length / 2.0), Vector3(length, 0.008, 0.07), Color(1, 1, 1, 1), 0.7)
		mi.rotation.y = -a


func _label(parent: Node3D, text: String, size_m: float, color: Color, pos: Vector3, yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 96
	l.pixel_size = size_m / 96.0
	l.modulate = color
	l.shaded = false
	l.double_sided = true
	l.position = pos
	l.rotation.y = yaw
	parent.add_child(l)
	return l


func _fig(s: Dictionary, k: int, shirt: Color) -> ProtoFigure:
	var f := ProtoFigure.new(shirt, str(10 + k * 7), false, "%s%d" % [str(s.ev.id), k], Color("#14161c") if k % 3 else Color("#2b3a6b"))
	f.glow.visible = false
	s.frame.add_child(f)
	return f


## The athletes of an active site: a group waiting at its home spot, the others taking their turn.
func _spawn(s: Dictionary) -> void:
	var ev: Dictionary = s.ev
	var n: int = ev.athletes
	var home: Vector3 = s.nodes.get("group", Vector3(-6, 0, 6))
	for k in n:
		var f := _fig(s, k, SHIRTS[(k * 2 + int(hash(str(ev.id)) % 5)) % SHIRTS.size()])
		var slot := home + Vector3(float(k % 3) * 0.9 - 0.9, 0.0, float(k / 3) * 0.9)
		f.position = slot
		f.rotation.y = _yaw(Vector3(1, 0, -0.2))
		f.pose_stand()
		s.figs.append(f)
		s.home.append(slot)
	# officials: one at the equipment, one with a clipboard
	for o in s.nodes.get("officials", []):
		var f2 := _fig(s, 20 + int(o.x), Color("#ffd31a"))
		f2.position = o
		f2.rotation.y = _yaw(Vector3(0, 0, 1) if o.z < 0 else Vector3(0, 0, -1))
		f2.pose_stand()


static func _yaw(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


# --- the sites --------------------------------------------------------------------------------------------------------

func _build_high_jump(s: Dictionary) -> void:
	var f: Node3D = s.frame
	var ev: Dictionary = s.ev
	_box(f, Vector3(2.2, 0.35, 0.0), Vector3(5.0, 0.7, 5.0), Color("#2f6db5"), 0.9)                 # the landing mat
	_box(f, Vector3(2.2, 0.72, 0.0), Vector3(4.9, 0.03, 4.9), Color("#d94a3a"), 0.9)
	for z in [-2.2, 2.2]:
		_cyl(f, Vector3(0, 0.95, z), 0.03, 1.9, Color("#e8e8ee"))
	var bar := _box(f, Vector3(0, float(ev.bar), 0.0), Vector3(0.03, 0.03, 4.0), Color("#f2f2f2"), 0.5)
	s.nodes["bar"] = bar
	s.nodes["group"] = Vector3(-8.0, 0.0, 6.5)
	s.nodes["officials"] = [Vector3(-0.8, 0, 3.0), Vector3(3.2, 0, -3.2)]
	# the approach arc, painted lightly on the grass
	for k in 12:
		var u := k / 11.0
		var p := _hj_path(u)
		_box(f, Vector3(p.x, 0.012, p.z), Vector3(0.5, 0.006, 0.04), Color(1, 1, 1, 1), 0.7).rotation.y = 0.0


func _hj_path(u: float) -> Vector3:
	var p0 := Vector3(-8.5, 0.0, 5.0)
	var p1 := Vector3(-5.5, 0.0, -1.0)
	var p2 := Vector3(-1.4, 0.0, 0.0)
	return p0 * (1.0 - u) * (1.0 - u) + p1 * 2.0 * (1.0 - u) * u + p2 * u * u


func _build_pole_vault(s: Dictionary) -> void:
	var f: Node3D = s.frame
	var ev: Dictionary = s.ev
	_runway(f, -32.0, 0.0)
	_box(f, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.2, 0.6), Color("#c9c9d3"), 0.7)               # the box
	_box(f, Vector3(3.4, 0.5, 0.0), Vector3(6.0, 1.0, 6.0), Color("#2f6db5"), 0.9)               # the mat
	_box(f, Vector3(3.4, 1.02, 0.0), Vector3(5.9, 0.03, 5.9), Color("#d94a3a"), 0.9)
	for z in [-3.2, 3.2]:
		_cyl(f, Vector3(0.9, 2.5, z), 0.04, 5.0, Color("#e8e8ee"))
	s.nodes["bar"] = _box(f, Vector3(0.9, float(ev.bar), 0.0), Vector3(0.03, 0.03, 4.5), Color("#f2f2f2"), 0.5)
	s.nodes["group"] = Vector3(-27.0, 0.0, 6.0)
	s.nodes["officials"] = [Vector3(-1.5, 0, 3.4), Vector3(5.5, 0, -4.2)]
	var pole := Node3D.new()
	var pm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.018
	cm.height = 4.4
	cm.radial_segments = 6
	pm.mesh = cm
	pm.material_override = _std(Color("#e0b030"), 0.4)
	pm.rotation.z = PI / 2.0
	pole.add_child(pm)
	f.add_child(pole)
	s.nodes["pole"] = pole
	pole.visible = s.active


func _build_javelin(s: Dictionary) -> void:
	var f: Node3D = s.frame
	_runway(f, -32.0, 0.0)
	# the foul line is an arc of 8 m radius at the end of the runway (local x = 0), the sector lines run out from the centre of that arc
	for k in 9:
		var a := lerpf(-0.45, 0.45, k / 8.0)
		var p := Vector3(cos(a) * 8.0 - 8.0 + 0.0, 0.015, sin(a) * 8.0)
		_box(f, p, Vector3(0.05, 0.008, 1.1), Color.WHITE, 0.7)
	_sector(f, -8.0, 62.0, 14.5)
	s.nodes["group"] = Vector3(-18.0, 0.0, 7.0)
	s.nodes["officials"] = [Vector3(-4.0, 0, 3.5), Vector3(42.0, 0, 6.0)]
	var jav := _javelin_mesh()
	f.add_child(jav)
	jav.visible = false
	s.nodes["jav"] = jav


func _javelin_mesh() -> Node3D:
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.012
	c.bottom_radius = 0.012
	c.height = 2.6
	c.radial_segments = 6
	m.mesh = c
	m.material_override = _std(Color("#d8d8e0"), 0.4)
	m.rotation.z = PI / 2.0          # the long axis along local +X: this node's forward is +X
	n.add_child(m)
	var tip := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.0
	tc.bottom_radius = 0.014
	tc.height = 0.3
	tc.radial_segments = 6
	tip.mesh = tc
	tip.material_override = _std(Color("#8a8a94"), 0.3)
	tip.rotation.z = -PI / 2.0
	tip.position = Vector3(1.4, 0, 0)
	n.add_child(tip)
	return n


func _build_shot_put(s: Dictionary) -> void:
	var f: Node3D = s.frame
	_cyl(f, Vector3(0, 0.01, 0), 1.0675, 0.02, Color("#9a9aa6"))
	_cyl(f, Vector3(0, 0.02, 0), 1.0, 0.02, Color("#b4b4be"))
	_box(f, Vector3(1.1, 0.06, 0.0), Vector3(0.12, 0.12, 1.1), Color("#f2f2f2"), 0.5)            # the stop board
	_sector(f, 0.0, 22.0, 17.46)
	s.nodes["group"] = Vector3(-7.0, 0.0, 6.0)
	s.nodes["officials"] = [Vector3(9.0, 0, 5.0), Vector3(16.0, 0, -3.0)]
	var ball := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.09
	sp.height = 0.18
	sp.radial_segments = 10
	sp.rings = 5
	ball.mesh = sp
	ball.material_override = _std(Color("#2a2f3a"), 0.3)
	f.add_child(ball)
	ball.visible = false
	s.nodes["ball"] = ball


func _build_long_jump(s: Dictionary) -> void:
	var f: Node3D = s.frame
	_runway(f, -32.0, 0.0)
	_box(f, Vector3(0.0, 0.02, 0.0), Vector3(0.2, 0.012, 1.22), Color.WHITE, 0.6)               # the take-off board
	_box(f, Vector3(5.5, 0.04, 0.0), Vector3(9.0, 0.08, 3.0), Color("#d9c08a"), 1.0)            # the sand pit, raked
	for k in 6:
		_box(f, Vector3(1.5 + k * 1.4, 0.085, 0.0), Vector3(0.05, 0.01, 2.8), Color("#cdb27e"), 1.0)
	s.nodes["officials"] = []


# --- every frame ----------------------------------------------------------------------------------------------------

func update(t: float) -> void:
	visible = enabled
	if not enabled or rec.indoor:
		return
	for id in sites:
		var s: Dictionary = sites[id]
		if not s.active:
			continue
		var ev: Dictionary = s.ev
		var period := _period(str(id))
		var tt := t + 3.0 * float(absi(hash(str(id))) % 10) + 7.0
		var k := int(floor(tt / period))
		var tau := tt - k * period
		if k != s.k:
			_new_attempt(s, k)
		var cur: int = k % int(ev.athletes)
		for i in s.figs.size():
			if i != cur:
				_idle(s, i)
		call("_do_" + str(id), s, s.figs[cur], cur, tau, k)


func _period(id: String) -> float:
	match id:
		"high_jump": return 34.0
		"pole_vault": return 46.0
		"javelin": return 32.0
		_: return 28.0


func _new_attempt(s: Dictionary, k: int) -> void:
	s.k = k
	var bar: Node3D = s.nodes.get("bar")
	if bar:
		bar.position.y = float(s.ev.bar)
		bar.rotation = Vector3.ZERO
	if s.nodes.has("jav"):
		var j: Node3D = s.nodes.jav
		j.visible = false
	if s.nodes.has("ball"):
		var b: Node3D = s.nodes.ball
		b.visible = false
	if s.nodes.has("pole"):
		var p: Node3D = s.nodes.pole
		p.visible = false


func _idle(s: Dictionary, i: int) -> void:
	var f: ProtoFigure = s.figs[i]
	var home: Vector3 = s.home[i]
	f.position = home
	f.rotation.y = _yaw(Vector3(1.0, 0.0, -0.3 + 0.25 * float(i % 3)))
	f.pose_stand()


## Walks `f` from a to b between the times t0 and t1 (a person walks about 1.4 m/s); returns true while walking.
func _walk(f: ProtoFigure, a: Vector3, b: Vector3, tau: float, t0: float, t1: float) -> bool:
	if tau < t0 or tau >= t1:
		return false
	var u := (tau - t0) / (t1 - t0)
	f.position = a.lerp(b, u)
	f.position.y = lerpf(a.y, b.y, clampf(u * 4.0, 0.0, 1.0))
	f.rotation.y = _yaw(b - a)
	var len := a.distance_to(b)
	var cyc := ProtoFigure.cycle_for(1.4)
	f.pose_run(u * len / cyc, 1.4, 0.04, cyc)
	return true


func _run_pose(f: ProtoFigure, dist_run: float, speed: float, lean := 0.2) -> void:
	var cyc := ProtoFigure.cycle_for(speed)
	f.pose_run(dist_run / cyc, speed, lean, cyc)


func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


# --- high jump ------------------------------------------------------------------------------------------------------

func _do_high_jump(s: Dictionary, f: ProtoFigure, i: int, tau: float, k: int) -> void:
	var home: Vector3 = s.home[i]
	var h: float = s.ev.bar
	var start := _hj_path(0.0)
	var take := _hj_path(1.0)
	var fail := hash(k * 31 + 7) % 3 == 0
	if _walk(f, home, start, tau, 0.0, 6.0):
		return
	if tau < 9.5:
		f.position = start
		f.rotation.y = _yaw(_hj_path(0.05) - start)
		f.pose_stand(0.0)
		return
	if tau < 11.7:        # the curved run-up
		var u := (tau - 9.5) / 2.2
		var uu := u * u * 0.5 + u * 0.5
		f.position = _hj_path(uu)
		f.rotation.y = _yaw(_hj_path(minf(uu + 0.03, 1.0)) - _hj_path(maxf(uu - 0.03, 0.0)))
		_run_pose(f, uu * 10.5, 2.0 + 3.8 * u, 0.12 + 0.12 * u)
		return
	if tau < 12.9:        # the flight: a back-first flop
		var u := (tau - 11.7) / 1.2
		f.position = Vector3(lerpf(take.x, 2.6, u), 0.0, lerpf(take.z, 0.2, u))
		var hip := lerpf(1.05, 0.95, u) + 4.0 * u * (1.0 - u) * (h - 0.93) - 0.1 * u
		f.position.y = hip - BODY_H
		f.pose_stand()
		f.rotation.y = lerp_angle(_yaw(_hj_path(1.0) - _hj_path(0.97)), _yaw(Vector3(-1, 0, 0)), _ease(u * 3.0))
		f.body.rotation.x = clampf(u * 2.0, 0.0, 1.0) * (PI / 2.0 + 0.15)
		f.knee_l.rotation.x = -1.4 * sin(PI * u)
		f.knee_r.rotation.x = -1.2 * sin(PI * u)
		f.torso.rotation.x = 0.35 * sin(PI * u)
		f.sh_l.rotation = Vector3(-0.4, 0, 0.5)
		f.sh_r.rotation = Vector3(-0.4, 0, -0.5)
		var bar: Node3D = s.nodes.bar
		if fail and u > 0.42:     # the bar comes down
			bar.position.y = lerpf(h, 0.74, clampf((u - 0.42) * 2.4, 0.0, 1.0))
			bar.rotation.x = clampf((u - 0.42) * 3.0, 0.0, 1.2)
		return
	if tau < 15.5:        # lying on the mat
		f.position = Vector3(2.6, 0.78 - BODY_H + 0.16, 0.2)
		f.rotation.y = _yaw(Vector3(-1, 0, 0))
		f.pose_stand()
		f.body.rotation.x = PI / 2.0 + 0.15
		f.knee_l.rotation.x = -0.5
		return
	if tau < 17.5:        # up on the mat
		f.position = Vector3(2.6, 0.72, 0.4)
		f.rotation.y = _yaw(Vector3(0.3, 0, 1))
		f.pose_stand()
		return
	if _walk(f, Vector3(2.6, 0.72, 0.4), home, tau, 17.5, 28.0):
		return
	_idle(s, i)


# --- pole vault -----------------------------------------------------------------------------------------------------

func _do_pole_vault(s: Dictionary, f: ProtoFigure, i: int, tau: float, k: int) -> void:
	var home: Vector3 = s.home[i]
	var h: float = s.ev.bar
	var pole: Node3D = s.nodes.pole
	var fail := hash(k * 17 + 3) % 3 == 0
	var start := Vector3(-24.0, 0.0, 0.0)
	var take_x := -3.1
	pole.visible = true
	if _walk(f, home, start, tau, 0.0, 12.0):
		pole.position = Vector3(f.position.x + 0.3, 1.0, f.position.z + 0.15)
		pole.rotation = Vector3(0, 0, 0.15)
		return
	if tau < 17.0:
		f.position = start
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		f.pose_stand()
		pole.position = Vector3(start.x + 0.3, 1.2, 0.15)
		pole.rotation = Vector3(0, 0, 0.3)
		return
	if tau < 20.6:        # the run-up, the pole carried low then lifted
		var u := (tau - 17.0) / 3.6
		var x := lerpf(start.x, take_x, u * u * 0.6 + u * 0.4)
		f.position = Vector3(x, 0.0, 0.0)
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		_run_pose(f, (x - start.x), 1.5 + 4.8 * u, 0.2)
		pole.position = Vector3(x + 0.3, 1.1 + 0.5 * u, 0.15)
		pole.rotation = Vector3(0, 0, 0.3 + 0.6 * u)
		f.sh_l.rotation = Vector3(1.5, 0, 0.1)
		f.sh_r.rotation = Vector3(1.7, 0, -0.1)
		return
	if tau < 23.4:        # the vault: swing up round the plant, turn over, over the bar, fall onto the mat
		var u := (tau - 20.6) / 2.8
		var beta := deg_to_rad(lerpf(35.0, 100.0, _ease(u * 1.15)))
		var dir := Vector3(-cos(beta), sin(beta), 0.0)
		var r := lerpf(3.1, 3.6, u)
		var hip := dir * r
		hip.y += 0.2
		var over := _ease((u - 0.55) * 2.2)
		var theta := PI * _ease(u * 1.5) - (PI / 2.0) * over
		var land := _ease((u - 0.75) * 4.0)
		var pos := Vector3(hip.x + 0.4 * over, hip.y, 0.0)
		pos = pos.lerp(Vector3(3.4, 0.9, 0.0), land)
		f.position = Vector3(pos.x, pos.y - BODY_H, 0.0)
		f.pose_stand()
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		f.body.rotation.x = theta
		f.sh_l.rotation = Vector3(2.9, 0, 0.1)
		f.sh_r.rotation = Vector3(2.9, 0, -0.1)
		var pb := beta if u < 0.55 else lerpf(deg_to_rad(100.0), deg_to_rad(8.0), _ease((u - 0.55) / 0.45))   # after the release the pole falls back
		var pdir := Vector3(-cos(pb), sin(pb), 0.0)
		pole.position = Vector3(0.0, 0.2, 0.0) + pdir * 2.2
		pole.rotation = Vector3(0, 0, PI - pb)
		var bar: Node3D = s.nodes.bar
		if fail and u > 0.6:
			bar.position.y = lerpf(h, 1.05, clampf((u - 0.6) * 2.6, 0.0, 1.0))
		return
	pole.visible = tau < 26.0
	pole.position = Vector3(0.0, 0.2, 0.0) + Vector3(-cos(deg_to_rad(8.0)), sin(deg_to_rad(8.0)), 0.0) * 2.2
	pole.rotation = Vector3(0, 0, PI - deg_to_rad(8.0))
	if tau < 26.0:        # on the mat
		f.position = Vector3(3.4, 0.72, 0.0)
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		f.pose_stand()
		f.body.rotation.x = PI / 2.0
		f.position.y = 1.02 - BODY_H + 0.15
		return
	if tau < 28.0:
		f.position = Vector3(3.4, 1.0, 0.8)
		f.rotation.y = _yaw(Vector3(0, 0, 1))
		f.pose_stand()
		return
	pole.visible = false
	if _walk(f, Vector3(3.4, 1.0, 0.8), home, tau, 28.0, 46.0):
		return
	_idle(s, i)


# --- javelin --------------------------------------------------------------------------------------------------------

func _do_javelin(s: Dictionary, f: ProtoFigure, i: int, tau: float, k: int) -> void:
	var home: Vector3 = s.home[i]
	var jav: Node3D = s.nodes.jav
	var dist := 31.0 + 14.0 * float(absi(hash(k * 13 + 5)) % 100) / 100.0
	var start := Vector3(-14.0, 0.0, 0.0)
	var line := Vector3(-0.6, 0.0, 0.0)
	jav.visible = true
	if _walk(f, home, start, tau, 0.0, 8.0):
		_javelin_in_hand(f, jav)
		return
	if tau < 10.0:
		f.position = start
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		f.pose_stand()
		_javelin_in_hand(f, jav)
		return
	if tau < 13.2:        # the run-up
		var u := (tau - 10.0) / 3.2
		var x := lerpf(start.x, -3.5, u * u * 0.4 + u * 0.6)
		f.position = Vector3(x, 0.0, 0.0)
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		_run_pose(f, x - start.x, 1.4 + 4.6 * u, 0.12)
		_javelin_in_hand(f, jav)
		return
	if tau < 14.1:        # the cross steps and the throw
		var u := (tau - 13.2) / 0.9
		f.position = Vector3(lerpf(-3.5, line.x, _ease(u)), 0.0, 0.0)
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		_run_pose(f, 3.0 + u * 2.0, 4.0 - 2.0 * u, 0.0)
		f.torso.rotation.x = lerpf(0.25, -0.35, u)
		f.torso.rotation.y = lerpf(0.5, -0.6, _ease(u))
		var back := _ease(u * 2.0)
		var fwd := _ease((u - 0.45) * 2.2)
		f.sh_r.rotation = Vector3(lerpf(2.2, -1.2, back) + 4.1 * fwd, 0, 0)
		f.el_r.rotation.x = lerpf(1.0, 0.1, back)
		f.sh_l.rotation = Vector3(0.8, 0, 0.6)
		if u < 0.5:
			_javelin_in_hand(f, jav)
			jav.rotation.z = lerpf(0.35, 0.1, u * 2.0)
		else:
			jav.position = f.position + Vector3(0.4, 1.95, 0.0)
			jav.rotation = Vector3(0, 0, 0.6)
		return
	if tau < 14.1 + 2.9:  # the javelin flies; the thrower follows through and stops
		f.position = Vector3(line.x + 0.7 * (1.0 - (tau - 14.1) / 2.9), 0.0, 0.0)
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		f.pose_stand(0.3)
		f.sh_r.rotation = Vector3(1.0, 0, 0.1)
		f.torso.rotation.x = 0.3
		_javelin_fly(jav, dist, (tau - 14.1) / 2.9)
		return
	_javelin_fly(jav, dist, 1.0)
	if _walk(f, Vector3(line.x, 0.0, 0.0), home, tau, 17.8, 30.0):
		return
	_idle(s, i)


## Held over the shoulder, along the thrower's heading, nose up.
func _javelin_in_hand(f: ProtoFigure, jav: Node3D) -> void:
	var yaw := f.rotation.y
	var h2 := Vector2(-sin(yaw), -cos(yaw))
	jav.position = f.position + Vector3(h2.x * 0.3, 1.78, h2.y * 0.3)
	jav.rotation = Vector3(0, atan2(-h2.y, h2.x), 0.35)
	f.sh_r.rotation = Vector3(2.35, 0, -0.25)
	f.el_r.rotation.x = 1.1


func _jav_pos(dist: float, u: float) -> Vector3:
	var x := lerpf(0.0, dist, u)
	var y := 2.0 * (1.0 - u) + 4.0 * 8.0 * u * (1.0 - u)
	return Vector3(x, maxf(y, 0.12), 0.35 * u)


## The flight (a parabola, nose along the path) and then stuck in the grass at the landing.
func _javelin_fly(jav: Node3D, dist: float, u: float) -> void:
	u = clampf(u, 0.0, 1.0)
	if u >= 1.0:
		jav.position = Vector3(dist, 0.12, 0.35)
		jav.rotation = Vector3(0, 0, -0.3)
		return
	var a := _jav_pos(dist, u)
	var b := _jav_pos(dist, minf(u + 0.01, 1.0))
	jav.position = a
	jav.rotation = Vector3(0, 0, atan2(b.y - a.y, maxf(b.x - a.x, 0.001)))


# --- shot put -------------------------------------------------------------------------------------------------------

func _do_shot_put(s: Dictionary, f: ProtoFigure, i: int, tau: float, k: int) -> void:
	var home: Vector3 = s.home[i]
	var ball: Node3D = s.nodes.ball
	var dist := 9.0 + 4.0 * float(absi(hash(k * 29 + 11)) % 100) / 100.0
	var back := Vector3(-1.4, 0.0, 0.0)
	if _walk(f, home, back, tau, 0.0, 5.5):
		ball.visible = false
		return
	if tau < 9.0:         # at the back of the circle, the shot at the neck
		f.position = back + Vector3(0.5 * _ease((tau - 5.5) / 3.5), 0.0, 0.0)
		f.rotation.y = _yaw(Vector3(-1, 0, 0.1)) if tau < 8.0 else lerp_angle(_yaw(Vector3(-1, 0, 0.1)), _yaw(Vector3(1, 0, 0)), _ease(tau - 8.0))
		f.pose_stand()
		f.sh_r.rotation = Vector3(2.4, 0, -0.3)
		f.el_r.rotation.x = 2.0
		f.knee_l.rotation.x = -0.35
		f.knee_r.rotation.x = -0.35
		ball.visible = true
		ball.position = f.position + Vector3(0.0, 1.62, 0.0)
		return
	if tau < 10.1:        # glide and push
		var u := (tau - 9.0) / 1.1
		f.position = Vector3(lerpf(-0.9, 0.6, _ease(u)), 0.0, 0.0)
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		f.pose_stand()
		f.torso.rotation.x = lerpf(0.5, -0.25, _ease(u))
		f.knee_r.rotation.x = lerpf(-1.1, -0.15, _ease(u))
		f.hip_r.rotation.x = lerpf(0.5, 0.0, _ease(u))
		f.sh_r.rotation = Vector3(lerpf(2.4, 3.0, _ease(u * 1.5)), 0, -0.3)
		f.el_r.rotation.x = lerpf(2.0, 0.1, _ease(u * 1.6))
		f.sh_l.rotation = Vector3(1.0, 0, 0.5)
		if u < 0.85:
			ball.visible = true
			ball.position = f.position + Vector3(0.15, 1.7 + 0.2 * u, 0.0)
		else:
			_shot_flight(ball, dist, (u - 0.85) / 0.15 * 0.05)
		return
	if tau < 12.0:        # the put in the air, the putter bent over the board
		f.position = Vector3(0.6, 0.0, 0.0)
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		f.pose_stand()
		f.torso.rotation.x = -0.1
		f.knee_l.rotation.x = -0.4
		f.sh_r.rotation = Vector3(1.3, 0, -0.2)
		_shot_flight(ball, dist, 0.05 + (tau - 10.1) / 1.9 * 0.95)
		return
	_shot_flight(ball, dist, 1.0)
	if _walk(f, Vector3(0.6, 0.0, 0.0) + Vector3(-1.0, 0, 1.5), home, tau, 14.0, 26.0):
		return
	if tau < 14.0:
		f.position = Vector3(-0.4, 0.0, 1.0)
		f.rotation.y = _yaw(Vector3(1, 0, 0))
		f.pose_stand()
		return
	_idle(s, i)


func _shot_flight(ball: Node3D, dist: float, u: float) -> void:
	ball.visible = true
	u = clampf(u, 0.0, 1.0)
	var x := lerpf(0.6, dist + 1.1, u)
	var y := 1.9 * (1.0 - u) + 4.0 * 3.2 * u * (1.0 - u)
	ball.position = Vector3(x, maxf(y, 0.09), 0.0)
