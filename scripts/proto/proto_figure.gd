class_name ProtoFigure
extends Node3D
## R6a prototype: an athlete built in code from rounded shapes (no model files). Faces -Z (Godot's forward); the viewer turns it to the
## heading. The run cycle plants each foot on the track: during its short contact the foot moves back relative to the hip at exactly the
## running speed (so it does not slide), in the swing it lifts and comes forward, and a 2-bone IK puts the knee where it must be. The phase is
## an integral of distance / cycle length (the viewer keeps it), so a seek or slow motion needs no state.
## The joint pivots are public so the field-event animators can pose the same body (jump, throw, vault).

const L1 := 0.43          # thigh
const L2 := 0.42          # shin
const ANKLE := 0.08       # ankle height above the ground
const SH_H := 0.50        # shoulder height above the hip pivot

var body: Node3D          # pelvis pivot, at hip height
var torso: Node3D
var head: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var foot_l: Node3D
var foot_r: Node3D
var sh_l: Node3D
var sh_r: Node3D
var el_l: Node3D
var el_r: Node3D
var hip_y := 0.9
var skin: Color
var singlet: Color
var shorts: Color
var held: Node3D          # whatever is in the hand (a javelin, a pole, a shot)

var glow: MeshInstance3D
var glow_mat: StandardMaterial3D
var tag: Label3D
var cue: Label3D


func _init(singlet_color: Color, number: String, is_player: bool, name_text: String, shorts_color := Color("#12141a")) -> void:
	singlet = singlet_color
	shorts = shorts_color
	var h := hash(name_text)
	skin = [Color("#e0b08a"), Color("#d9a27c"), Color("#c68863"), Color("#8a5a3c"), Color("#f0c6a4")][absi(h) % 5]
	var hair: Color = [Color("#1a1d26"), Color("#3a2a1a"), Color("#c9a35a"), Color("#6b3d1f"), Color("#101010")][absi(h / 7) % 5]
	body = Node3D.new()
	body.position.y = 0.9
	add_child(body)
	_part(body, _capsule(0.11, 0.26, Vector3(1.45, 0.9, 1.0)), Vector3(0, 0.0, 0), shorts)           # pelvis in shorts
	torso = Node3D.new()
	torso.position.y = 0.07
	body.add_child(torso)
	_part(torso, _capsule(0.135, 0.52, Vector3(1.2, 1.0, 0.72)), Vector3(0, 0.24, 0), singlet)      # chest
	_part(torso, _cyl(0.045, 0.1), Vector3(0, 0.52, 0), skin)                                        # neck
	head = Node3D.new()
	head.position = Vector3(0, 0.63, -0.005)
	torso.add_child(head)
	_part(head, _sphere(0.105), Vector3.ZERO, skin)
	_part(head, _sphere(0.108, 0.5), Vector3(0, 0.03, 0.012), hair)                                  # hair cap
	for side in [1, -1]:
		var bib := _part(torso, _box(Vector3(0.22, 0.17, 0.008)), Vector3(0, 0.27, 0.098 * side), Color.WHITE)
		var lab := Label3D.new()
		lab.text = number
		lab.font_size = 64
		lab.pixel_size = 0.0026
		lab.modulate = Color("#12141a")
		lab.position = Vector3(0, 0.27, 0.104 * side)
		lab.rotation.y = 0.0 if side == 1 else PI
		torso.add_child(lab)
		bib.name = "Bib"
	sh_l = _arm(-0.195)
	sh_r = _arm(0.195)
	el_l = sh_l.get_child(1)
	el_r = sh_r.get_child(1)
	hip_l = _leg(-0.095)
	hip_r = _leg(0.095)
	knee_l = hip_l.get_child(2)
	knee_r = hip_r.get_child(2)
	foot_l = knee_l.get_child(1)
	foot_r = knee_r.get_child(1)
	# the effort glow on the ground
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
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	tag = Label3D.new()   # (the labels live in the viewer's world so they do not turn with the figure)
	cue = Label3D.new()


# --- building blocks ----------------------------------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _capsule(radius: float, height: float, squash := Vector3.ONE) -> Array:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 3
	return [m, squash]


func _cyl(radius: float, height: float) -> Array:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 8
	m.rings = 1
	return [m, Vector3.ONE]


func _sphere(radius: float, squash_y := 1.0) -> Array:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	return [m, Vector3(1, squash_y if squash_y != 1.0 else 1.12, 1)]


func _box(size: Vector3) -> Array:
	var m := BoxMesh.new()
	m.size = size
	return [m, Vector3.ONE]


func _part(parent: Node3D, shape: Array, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shape[0]
	mi.scale = shape[1]
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _leg(x: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(x, -0.02, 0)
	body.add_child(hip)
	_part(hip, _capsule(0.072, L1 + 0.04, Vector3(1.0, 1.0, 1.05)), Vector3(0, -L1 / 2.0, 0), skin)
	_part(hip, _capsule(0.078, 0.22, Vector3(1.0, 1.0, 1.1)), Vector3(0, -0.1, 0), shorts)         # the shorts' leg
	var knee := Node3D.new()
	knee.position = Vector3(0, -L1, 0)
	hip.add_child(knee)
	_part(knee, _capsule(0.052, L2 + 0.03, Vector3(1.0, 1.0, 1.1)), Vector3(0, -L2 / 2.0, 0), skin)
	var foot := Node3D.new()
	foot.position = Vector3(0, -L2, 0)
	knee.add_child(foot)
	_part(foot, _box(Vector3(0.09, 0.07, 0.26)), Vector3(0, -0.03, -0.07), Color("#f4f4f6"))      # shoe
	_part(foot, _box(Vector3(0.092, 0.02, 0.27)), Vector3(0, -0.07, -0.07), Color("#e8e8ee").darkened(0.45))
	return hip


func _arm(x: float) -> Node3D:
	var sh := Node3D.new()
	sh.position = Vector3(x, SH_H - 0.07, 0)
	torso.add_child(sh)
	_part(sh, _capsule(0.04, 0.3, Vector3.ONE), Vector3(0, -0.13, 0), skin)
	var el := Node3D.new()
	el.position = Vector3(0, -0.27, 0)
	sh.add_child(el)
	_part(el, _capsule(0.034, 0.28, Vector3.ONE), Vector3(0, -0.12, 0), skin)
	_part(el, _sphere(0.04), Vector3(0, -0.27, 0), skin)
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


# --- the run cycle --------------------------------------------------------------------------------------------------

## The metres of one full stride cycle (two steps) at this speed: a runner takes about 1.9 steps a second jogging and 3 a second at a
## 800 m pace. The viewer integrates distance / cycle_for(v) into the phase.
static func cycle_for(speed: float) -> float:
	var t := clampf((speed - 1.4) / 5.0, 0.0, 1.0)
	return 2.0 * maxf(speed, 0.3) / lerpf(1.9, 3.0, t)


## One leg to a foot target given by the phase `u` (0-1) of this leg: contact first (the foot goes back at running speed), then the swing.
## Sets the hip, knee and foot angles. t = how fast (0 jog … 1 race pace), travel = metres the foot moves back during contact.
func _leg_ik(hip: Node3D, knee: Node3D, foot: Node3D, u: float, df: float, travel: float, lift_h: float, hy: float) -> void:
	u = fposmod(u, 1.0)
	var a := minf(0.42 * travel, 0.43)
	var b := minf(0.58 * travel, 0.55)
	var f := 0.0
	var lift := 0.0
	var pitch := 0.0
	if u < df:
		var s := u / df
		f = a - (a + b) * s
		lift = 0.045 * s * s * s
		pitch = -0.75 * s * s * s
	else:
		var s := (u - df) / (1.0 - df)
		var e := s * s * (3.0 - 2.0 * s)
		f = lerpf(-b, a + 0.04, e)
		lift = lift_h * sin(PI * pow(s, 0.8))
		pitch = lerpf(-0.75, 0.15, clampf(s * 1.4, 0.0, 1.0))
	var dn := hy - ANKLE - lift
	var dist := clampf(sqrt(f * f + dn * dn), 0.25, L1 + L2 - 0.004)
	var cos_k := clampf((L1 * L1 + L2 * L2 - dist * dist) / (2.0 * L1 * L2), -1.0, 1.0)
	var flex := PI - acos(cos_k)
	var cos_g := clampf((L1 * L1 + dist * dist - L2 * L2) / (2.0 * L1 * dist), -1.0, 1.0)
	var thigh := atan2(f, dn) + acos(cos_g)
	hip.rotation.x = thigh
	knee.rotation.x = -flex
	foot.rotation.x = -(thigh - flex) + pitch


## phase = the cycle position (cycles run so far); speed in m/s; lean = the forward lean in radians; cyc = cycle_for(speed).
func pose_run(phase: float, speed: float, lean: float, cyc: float) -> void:
	_stand_up()
	var t := clampf((speed - 1.4) / 5.0, 0.0, 1.0)
	var df := lerpf(0.62, 0.22, t)
	var travel := df * cyc
	var lift_h := lerpf(0.10, 0.36, t)
	var bob := lerpf(0.012, 0.045, t)
	var h0 := lerpf(0.90, 0.872, t)
	hip_y = h0 - bob * cos(4.0 * PI * (phase - df / 2.0))
	body.position.y = hip_y + 0.02
	_leg_ik(hip_r, knee_r, foot_r, phase, df, travel, lift_h, hip_y)
	_leg_ik(hip_l, knee_l, foot_l, phase + 0.5, df, travel, lift_h, hip_y)
	torso.rotation = Vector3(-lean, 0.12 * t * sin(TAU * phase), 0.0)
	body.rotation.y = -0.06 * t * sin(TAU * phase)
	head.rotation.x = lean * 0.7
	var k := lerpf(0.22, 0.78, t)
	var arm := k * cos(TAU * (phase - 0.45))
	sh_r.rotation.x = arm
	sh_l.rotation.x = -arm
	var elbow := lerpf(0.45, 1.5, t)
	el_r.rotation.x = elbow + 0.2 * t * cos(TAU * (phase - 0.45))
	el_l.rotation.x = elbow - 0.2 * t * cos(TAU * (phase - 0.45))
	sh_r.rotation.z = 0.0
	sh_l.rotation.z = 0.0


## Standing still (an official, an athlete waiting): a neutral pose, optional arm angle.
func pose_stand(arm := 0.0) -> void:
	_stand_up()
	hip_y = 0.93
	body.position.y = hip_y + 0.02
	for p in [hip_l, hip_r, knee_l, knee_r, foot_l, foot_r, torso, head, body]:
		p.rotation = Vector3.ZERO
	sh_l.rotation = Vector3(arm, 0, 0.06)
	sh_r.rotation = Vector3(arm, 0, -0.06)
	el_l.rotation = Vector3(0.1, 0, 0)
	el_r.rotation = Vector3(0.1, 0, 0)


## After a fall: on the ground.
func pose_down() -> void:
	body.position = Vector3(0, 0.2, 0)
	body.rotation = Vector3(0, 0, PI / 2.0)
	for p in [hip_l, hip_r, knee_l, knee_r, foot_l, foot_r, torso, head, sh_l, sh_r, el_l, el_r]:
		p.rotation = Vector3.ZERO
	knee_l.rotation.x = -0.5
	knee_r.rotation.x = -0.9


func _stand_up() -> void:
	body.rotation = Vector3.ZERO
