class_name ProtoStadium
extends Node3D
## R6a prototype: the stadium in 3D, built in code from the engine's own track geometry (taken from the recording, which copied
## it from Race): outdoor = the World Athletics 400 m standard track (two semicircles of 36.50 m, straights of 84.39 m, lanes 1.22 m,
## eight lanes), indoor = the 200 m hall track as the engine has it (see docs/R6A_RESEARCH.md for what is and is not verified).
## Track coordinates (x, y) become world (x, 0, y); seen from above the race runs anticlockwise.

const APRON := 4.0
const ARC_STEPS := 28

var rec: RaceRecording
## "club" = a local ground in daylight (a small main stand with a roof along the home straight, a grass bank opposite, trees); "arena" = the big
## floodlit ring with the six-tier stand all round. (The meet level picks one in the real game, GDD 4.11 decision 13.)
var style := "club"
var r_out := 0.0
## Roof, ceiling and light strips: hidden in the top-down view, which looks down through them.
var roof := Node3D.new()


func _init(recording: RaceRecording, style_name := "club") -> void:
	rec = recording
	style = style_name
	add_child(roof)
	r_out = rec.r_in + Race.LANE_W * rec.lanes
	if rec.indoor:
		_build_indoor()
	else:
		_build_outdoor()
	_marks()


# --- shapes ---------------------------------------------------------------------------------------------------------

## The stadium outline at radius `r`, as one point per step, starting at the left end of the home straight, in the order of the
## race. Each point has the same index for every radius, so two radii make a ring of quads.
func _outline(r: float) -> PackedVector2Array:
	var half := rec.straight / 2.0
	var pts := PackedVector2Array()
	var cuts := maxi(2, int(rec.straight / 6.0))
	for k in cuts:
		pts.append(Vector2(-half + rec.straight * k / cuts, r))
	for k in ARC_STEPS:
		pts.append(Vector2(half, 0.0) + Vector2.from_angle(PI / 2.0 - PI * k / ARC_STEPS) * r)
	for k in cuts:
		pts.append(Vector2(half - rec.straight * k / cuts, -r))
	for k in ARC_STEPS:
		pts.append(Vector2(-half, 0.0) + Vector2.from_angle(-PI / 2.0 - PI * k / ARC_STEPS) * r)
	return pts


## A ring between radius ra (height ya) and rb (height yb). `colors`: optional per-quad colour function (index -> Color).
func _ring(ra: float, rb: float, ya: float, yb: float, mat: Material, color_of: Callable = Callable()) -> MeshInstance3D:
	var A := _outline(ra)
	var B := _outline(rb)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := ra < rb
	for i in A.size():
		var j := (i + 1) % A.size()
		var c := Color.WHITE
		if color_of.is_valid():
			c = color_of.call(i)
		var a0 := Vector3(A[i].x, ya, A[i].y)
		var a1 := Vector3(A[j].x, ya, A[j].y)
		var b0 := Vector3(B[i].x, yb, B[i].y)
		var b1 := Vector3(B[j].x, yb, B[j].y)
		var n := (a1 - a0).cross(b0 - a0).normalized()
		if n.y < 0.0 and absf(yb - ya) < 0.001:
			n = -n
		for p in [[a0, 0], [b0, 1], [a1, 2], [a1, 2], [b0, 1], [b1, 3]]:
			st.set_color(c)
			st.set_normal(n)
			st.add_vertex(p[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	return mi


func _std(c: Color, rough := 0.9, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m


func _vc_mat(rough := 0.9) -> StandardMaterial3D:
	var m := _std(Color.WHITE, rough)
	m.vertex_color_use_as_albedo = true
	return m


func _flat_box(center: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = center
	add_child(mi)
	return mi


# --- outdoor --------------------------------------------------------------------------------------------------------

func _build_outdoor() -> void:
	var plane := _flat_box(Vector3(0, -0.06, 0), Vector3(400, 0.1, 400), _std(Color("#1d3a2a"), 1.0))
	plane.name = "Ground"
	# infield: the grass inside the kerb, mown in stripes
	var half := rec.straight / 2.0
	_ring(0.01, rec.r_in - 0.2, -0.005, -0.005, _std(Color("#21502f"), 1.0))
	# the track: eight lanes of red-brown synthetic surface, lane lines, a white kerb and the apron round it
	_ring(rec.r_in - 0.2, rec.r_in + 0.0, 0.03, 0.03, _std(Color.WHITE, 0.7))
	_ring(rec.r_in, r_out, 0.0, 0.0, _std(Palette.TRACK, 0.95))
	_ring(r_out, r_out + APRON, 0.0, 0.0, _std(Palette.TRACK_APRON, 0.95))
	_lane_lines()
	# the concourse and the advertising boards
	var board_r := r_out + APRON
	_ring(board_r, board_r + 3.0, 0.0, 0.0, _std(Palette.CONCOURSE.lightened(0.05), 1.0))
	var palette := [Color("#1f4fa8"), Color("#0e1117"), Color("#e8e8ee"), Color("#0e1117"), Color("#d83a2a"), Color("#0e1117")]
	_ring(board_r, board_r, 0.0, 1.0, _vc_mat(0.6), func(i): return palette[(i / 2) % palette.size()])
	if style == "club":
		_club_surroundings(board_r + 2.5)
	else:
		_stands(board_r + 3.0)
		_floodlights(board_r + 28.0)


## The local ground: one stand with a roof along the home straight, a grass bank on the far straight with standing spectators, light poles, and
## pines all round (a Finnish ground).
func _club_surroundings(edge: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var length := rec.straight + 46.0
	var depth := 0.9
	var rise := 0.45
	var tiers := 7
	var seat := _std(Palette.STAND.lightened(0.22), 1.0)
	var shirts := [Color("#a8392d"), Color("#b4b6c0"), Color("#25528c"), Color("#c0952a"), Color("#3a3f4b"), Color("#507f3c"), Color("#6f4a80"), Color("#8f909a"), Color("#e8e8ee"), Color("#d6a23a")]
	var spots: Array = []
	for t in tiers:
		var h := 0.3 + rise * (t + 1)
		var zc := edge + depth * (t + 0.5)
		_flat_box(Vector3(0, h / 2.0, zc), Vector3(length, h, depth), seat)
		for k in int(length / 0.62):
			if rng.randf() < 0.5:
				spots.append([Vector3(-length / 2.0 + k * 0.62 + rng.randf_range(-0.08, 0.08), h + 0.42, zc), shirts[rng.randi() % shirts.size()]])
	var back_z := edge + depth * tiers + 0.2
	_flat_box(Vector3(0, 4.0, back_z), Vector3(length, 8.0, 0.4), _std(Color("#8f96a6"), 0.9))
	_to_roof(_flat_box(Vector3(0, 7.4, edge + depth * tiers / 2.0 + 0.9), Vector3(length + 2.0, 0.3, depth * tiers + 3.6), _std(Palette.ROOF.lightened(0.35), 0.7)))
	var steel := _std(Color("#6a7184"), 0.6)
	for k in 9:
		_to_roof(_flat_box(Vector3(-length / 2.0 + k * length / 8.0, 3.7, edge - 0.9), Vector3(0.3, 7.4, 0.3), steel))
	# a banner on the front of the roof
	_to_roof(_flat_box(Vector3(0, 6.9, edge - 0.9), Vector3(length * 0.4, 0.9, 0.08), _std(Color("#1f4fa8"), 0.6)))
	# the grass bank opposite, with spectators standing along its upper rows
	var bank_len := length * 0.8
	for t in 4:
		var h2 := 0.25 + 0.38 * (t + 1)
		var zc2 := -(edge + 0.9 * (t + 0.5))
		_flat_box(Vector3(0, h2 / 2.0, zc2), Vector3(bank_len, h2, 0.9), _std(Color("#2f6240"), 1.0))
		for k in int(bank_len / 1.1):
			if rng.randf() < 0.22:
				spots.append([Vector3(-bank_len / 2.0 + k * 1.1 + rng.randf_range(-0.2, 0.2), h2 + 0.43, zc2), shirts[rng.randi() % shirts.size()]])
	# spectators standing behind the boards along the home straight, a thin row
	for k in int(length / 1.3):
		if rng.randf() < 0.3:
			spots.append([Vector3(-length / 2.0 + k * 1.3 + rng.randf_range(-0.3, 0.3), 0.43, edge - 1.8), shirts[rng.randi() % shirts.size()]])
	_crowd_from_spots(spots, rng)
	for sgn in [-1.0, 1.0]:
		for x in [-rec.straight * 0.55, rec.straight * 0.55]:
			_flat_box(Vector3(x, 10.0, sgn * (edge + 14.0)), Vector3(0.4, 20.0, 0.4), steel)   # slim light poles
	_trees()


func _crowd_from_spots(spots: Array, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.85, 0.35)
	mm.mesh = box
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), spots[i][0]))
		mm.set_instance_color(i, spots[i][1])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var m := _std(Color.WHITE, 0.95)
	m.vertex_color_use_as_albedo = true
	inst.material_override = m
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## Pines scattered outside the ground.
func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.0
	cone.height = 9.0
	cone.radial_segments = 7
	cone.rings = 1
	mm.mesh = cone
	var spots: Array = []
	var half := rec.straight / 2.0
	var tries := 0
	while spots.size() < 300 and tries < 4000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-150.0, 150.0)
		var d := Vector2(maxf(absf(x) - half, 0.0), z).length()
		if d > r_out + APRON + 34.0:
			spots.append([Vector3(x, 0.0, z), rng.randf_range(0.7, 1.5)])
	mm.instance_count = spots.size()
	for i in spots.size():
		var sc: float = spots[i][1]
		var p: Vector3 = spots[i][0]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), Vector3(p.x, 4.5 * sc, p.z)))
		mm.set_instance_color(i, Color("#1f4a2b").lerp(Color("#2c6a3a"), rng.randf()))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var m := _std(Color.WHITE, 1.0)
	m.vertex_color_use_as_albedo = true
	inst.material_override = m
	add_child(inst)


## The grandstand: stepped tiers all round with a crowd of coloured boxes on them, a roof above.
func _stands(r0: float) -> void:
	var tiers := 6
	var depth := 1.7
	var rise := 0.85
	var seat := _std(Palette.STAND, 1.0)
	for t in tiers:
		_ring(r0 + depth * t, r0 + depth * (t + 1), 0.3 + rise * t, 0.3 + rise * (t + 1), seat)
		_ring(r0 + depth * t, r0 + depth * t, 0.3 + rise * t, 0.3 + rise * (t + 1) - 0.0, seat)
	_ring(r0 + depth * tiers, r0 + depth * tiers + 3.0, 0.3 + rise * tiers, 0.3 + rise * tiers, seat)
	_crowd(r0, depth, rise, tiers)
	# roof
	var roof_r0 := r0 + 1.0
	_to_roof(_ring(roof_r0, r0 + depth * tiers + 3.0, 9.0, 11.5, _std(Palette.ROOF, 0.8)))


func _crowd(r0: float, depth: float, rise: float, tiers: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var shirts := [Color("#a8392d"), Color("#b4b6c0"), Color("#25528c"), Color("#c0952a"), Color("#3a3f4b"), Color("#507f3c"), Color("#6f4a80"), Color("#8f909a"), Color("#1d2330")]
	var spots: Array = []
	for t in tiers:
		var r := r0 + depth * (t + 0.6)
		var total := 2.0 * rec.straight + 2.0 * PI * r
		var steps := int(total / 0.7)
		for k in steps:
			if rng.randf() < 0.28:
				continue
			var p := rec.stadium_point(r, total * k / steps + rng.randf_range(-0.1, 0.1))
			spots.append([Vector3(p.x, 0.3 + rise * (t + 0.5) + 0.42, p.y), shirts[rng.randi() % shirts.size()]])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.85, 0.35)
	mm.mesh = box
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), spots[i][0]))
		mm.set_instance_color(i, spots[i][1])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var m := _std(Color.WHITE, 0.95)
	m.vertex_color_use_as_albedo = true
	inst.material_override = m
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _floodlights(r: float) -> void:
	for ang in [PI * 0.2, PI * 0.8, PI * 1.2, PI * 1.8]:
		var p := Vector2.from_angle(ang) * r
		p.x += signf(p.x) * rec.straight / 2.0
		_flat_box(Vector3(p.x, 34.5, p.y), Vector3(5.0, 2.4, 1.0), _std(Palette.FLOODLIGHT, 0.4, 3.0))
		_to_roof(_flat_box(Vector3(p.x, 17.0, p.y), Vector3(0.8, 34.0, 0.8), _std(Color("#4a5163"), 0.6)))


func _lane_lines() -> void:
	var white := _std(Color(1, 1, 1), 0.7)
	for k in range(rec.lanes + 1):
		var r := rec.r_in + Race.LANE_W * k
		_ring(r - 0.03, r + 0.03, 0.012, 0.012, white)


# --- indoor ---------------------------------------------------------------------------------------------------------

func _build_indoor() -> void:
	var floor_mat := _std(Color("#2b3140"), 0.9)
	_flat_box(Vector3(0, -0.06, 0), Vector3(200, 0.1, 140), floor_mat)
	var half := rec.straight / 2.0
	# the infield mat (blue), the track (red), the lines
	_ring(0.01, rec.r_in - 0.2, -0.005, -0.005, _std(Palette.MAT.darkened(0.3), 0.9))
	_ring(rec.r_in - 0.2, rec.r_in, 0.03, 0.03, _std(Color.WHITE, 0.7))
	_ring(rec.r_in, r_out, 0.0, 0.0, _std(Palette.TRACK, 0.95))
	_ring(r_out, r_out + 2.0, 0.0, 0.0, _std(Palette.TRACK_APRON, 0.95))
	_lane_lines()
	# the hall: a wall, a balcony of spectators and a roof with light strips
	var wall_r := r_out + 12.0
	_ring(wall_r, wall_r, 0.0, 9.0, _std(Color("#1b2030"), 1.0))
	_ring(r_out + 2.0, r_out + 3.0, 0.0, 0.0, _std(Palette.CONCOURSE, 1.0))
	var palette := [Color("#1f4fa8"), Color("#0e1117"), Color("#e8e8ee"), Color("#0e1117"), Color("#d83a2a"), Color("#0e1117")]
	_ring(r_out + 2.0, r_out + 2.0, 0.0, 1.0, _vc_mat(0.6), func(i): return palette[i % palette.size()])
	for t in 4:
		_ring(r_out + 3.0 + 1.6 * t, r_out + 3.0 + 1.6 * (t + 1), 0.2 + 0.8 * t, 0.2 + 0.8 * (t + 1), _std(Palette.STAND, 1.0))
	_crowd(r_out + 3.0, 1.6, 0.8, 4)
	var ceiling := MeshInstance3D.new()   # one-sided, facing down: seen from above it is not there
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 140)
	ceiling.mesh = pm
	ceiling.material_override = _std(Color("#10131c"), 1.0)
	ceiling.material_override.cull_mode = BaseMaterial3D.CULL_BACK
	ceiling.position.y = 11.0
	ceiling.rotation.x = PI
	roof.add_child(ceiling)
	for k in 5:
		var x := -half + rec.straight * k / 4.0
		_to_roof(_flat_box(Vector3(x, 10.8, 0), Vector3(1.4, 0.2, r_out * 2.0 + 14.0), _std(Palette.FLOODLIGHT, 0.5, 2.5)))


# --- marks ----------------------------------------------------------------------------------------------------------

## The finish line and the start stagger lines (one per lane) on the track.
func _marks() -> void:
	# the start staggers: one short painted line across each lane, square to the lane (the finish line is the venue's)
	var half := rec.straight / 2.0
	var white := _std(Color.WHITE, 0.6)
	for lane in range(1, rec.lanes + 1):
		var rc := rec.r_in + Race.LANE_W * (lane - 0.5)
		var c := rec.stadium_point(rc, rec.straight + rec.break_bends * PI * (rc - rec.r1))
		var centre := Vector2(0.0, 0.0)
		var radial := Vector2(0.0, signf(c.y))
		if c.x > half:
			centre = Vector2(half, 0.0)
			radial = (c - centre).normalized()
		elif c.x < -half:
			centre = Vector2(-half, 0.0)
			radial = (c - centre).normalized()
		var a := c - radial * Race.LANE_W / 2.0
		var b := c + radial * Race.LANE_W / 2.0
		_line3(Vector3(a.x, 0.02, a.y), Vector3(b.x, 0.02, b.y), 0.05, white)


func _to_roof(mi: Node3D) -> Node3D:
	mi.get_parent().remove_child(mi)
	roof.add_child(mi)
	return mi


func _line3(a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(a.distance_to(b), 0.02, width)
	mi.mesh = box
	mi.material_override = mat
	add_child(mi)
	mi.position = (a + b) / 2.0
	mi.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
