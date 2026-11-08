class_name ProtoFigure
extends Node3D
## R6a prototype: a runner built in code from simple shapes (no model files). Faces -Z (Godot's forward); the viewer turns it
## to the heading. The stride is a function of the DISTANCE run (the viewer passes phase = d / cycle length), so the feet never
## slide and a seek or slow-motion needs no state.

const HIP_H := 0.92
const CYCLE_M := 4.3     # metres of two steps at about 7 m/s (the viewer scales it a little with speed)

var _body: Node3D
var _torso: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _sh_l: Node3D
var _sh_r: Node3D
var _el_l: Node3D
var _el_r: Node3D
var _skin: Color
var singlet: Color

var glow: MeshInstance3D
var glow_mat: StandardMaterial3D
var tag: Label3D
var cue: Label3D


func _init(singlet_color: Color, number: String, is_player: bool, name_text: String) -> void:
	singlet = singlet_color
	_skin = Color("#d9a27c") if hash(name_text) % 3 != 0 else Color("#8a5a3c")
	_body = Node3D.new()
	_body.position.y = HIP_H
	add_child(_body)
	# torso, pivoting at the hip
	_torso = Node3D.new()
	_body.add_child(_torso)
	_torso.add_child(_box(Vector3(0.36, 0.56, 0.2), Vector3(0, 0.30, 0), singlet))
	_torso.add_child(_box(Vector3(0.38, 0.06, 0.22), Vector3(0, 0.02, 0), Color("#12141a")))   # shorts' waist
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.11
	sph.height = 0.24
	head.mesh = sph
	head.material_override = _mat(_skin)
	head.position = Vector3(0, 0.70, -0.01)
	_torso.add_child(head)
	_torso.add_child(_box(Vector3(0.24, 0.07, 0.24), Vector3(0, 0.79, -0.01), Color("#1a1d26") if is_player == false else Palette.ACCENT))   # hair / the player's cap
	# bib front and back
	for side in [1, -1]:
		var bib := _box(Vector3(0.22, 0.2, 0.01), Vector3(0, 0.32, 0.105 * side), Color.WHITE)
		_torso.add_child(bib)
		var lab := Label3D.new()
		lab.text = number
		lab.font_size = 64
		lab.pixel_size = 0.0028
		lab.modulate = Color("#12141a")
		lab.outline_size = 0
		lab.position = Vector3(0, 0.32, 0.112 * side)
		lab.rotation.y = 0.0 if side == 1 else PI
		_torso.add_child(lab)
	# legs: hip pivot -> thigh -> knee pivot -> shin
	_hip_l = _leg(-0.1)
	_hip_r = _leg(0.1)
	_knee_l = _hip_l.get_child(1)
	_knee_r = _hip_r.get_child(1)
	# arms: shoulder pivot -> upper arm -> elbow pivot -> forearm
	_sh_l = _arm(-0.23)
	_sh_r = _arm(0.23)
	_el_l = _sh_l.get_child(1)
	_el_r = _sh_r.get_child(1)
	# effort glow on the ground
	glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	glow.mesh = q
	glow.rotation.x = -PI / 2.0
	glow.position.y = 0.04
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_mat.albedo_texture = _radial()
	glow_mat.no_depth_test = false
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	# the floating labels (name flag, cue) live in the viewer's world, not on the figure, so they do not turn with it
	tag = Label3D.new()
	cue = Label3D.new()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _box(size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c)
	mi.position = pos
	return mi


func _leg(x: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(x, 0, 0)
	_body.add_child(hip)
	hip.add_child(_box(Vector3(0.15, 0.46, 0.16), Vector3(0, -0.22, 0), Color("#12141a")))   # thigh in shorts
	var knee := Node3D.new()
	knee.position = Vector3(0, -0.45, 0)
	hip.add_child(knee)
	knee.add_child(_box(Vector3(0.11, 0.42, 0.12), Vector3(0, -0.20, 0), _skin))
	knee.add_child(_box(Vector3(0.12, 0.06, 0.24), Vector3(0, -0.43, -0.05), Color("#f2f2f2")))   # shoe
	return hip


func _arm(x: float) -> Node3D:
	var sh := Node3D.new()
	sh.position = Vector3(x, 0.5, 0)
	_torso.add_child(sh)
	sh.add_child(_box(Vector3(0.09, 0.28, 0.09), Vector3(0, -0.13, 0), singlet))
	var el := Node3D.new()
	el.position = Vector3(0, -0.27, 0)
	sh.add_child(el)
	el.add_child(_box(Vector3(0.08, 0.26, 0.08), Vector3(0, -0.12, 0), _skin))
	return sh


static var _radial_tex: GradientTexture2D

static func _radial() -> GradientTexture2D:
	if _radial_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_radial_tex = GradientTexture2D.new()
		_radial_tex.gradient = g
		_radial_tex.fill = GradientTexture2D.FILL_RADIAL
		_radial_tex.fill_from = Vector2(0.5, 0.5)
		_radial_tex.fill_to = Vector2(1.0, 0.5)
		_radial_tex.width = 128
		_radial_tex.height = 128
	return _radial_tex


## phase = metres run / cycle length * TAU; amp 0..1.3 (about the speed); lean in radians; down = on the ground after a fall.
func pose(phase: float, amp: float, lean: float, down: bool) -> void:
	if down:
		_body.position = Vector3(0, 0.22, 0)
		_body.rotation = Vector3(0, 0, PI / 2.0)
		_torso.rotation.x = 0.0
		for p in [_hip_l, _hip_r, _knee_l, _knee_r, _sh_l, _sh_r, _el_l, _el_r]:
			p.rotation.x = 0.0
		return
	_body.rotation = Vector3.ZERO
	_body.position = Vector3(0, HIP_H - 0.03 * amp + absf(sin(phase)) * 0.05 * amp, 0)
	_torso.rotation.x = -lean
	_torso.rotation.y = sin(phase) * 0.12 * amp
	var s := sin(phase)
	var c := cos(phase)
	_hip_r.rotation.x = amp * 0.75 * s + 0.1
	_hip_l.rotation.x = -amp * 0.75 * s + 0.1
	_knee_r.rotation.x = -(0.25 * amp + amp * 1.05 * maxf(0.0, cos(phase - 0.35)))
	_knee_l.rotation.x = -(0.25 * amp + amp * 1.05 * maxf(0.0, -cos(phase - 0.35)))
	_sh_r.rotation.x = -amp * 0.8 * s
	_sh_l.rotation.x = amp * 0.8 * s
	_el_r.rotation.x = 1.35 + 0.15 * c * amp
	_el_l.rotation.x = 1.35 - 0.15 * c * amp
