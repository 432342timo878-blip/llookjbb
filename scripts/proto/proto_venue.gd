class_name ProtoVenue
extends Node3D
## R6a prototype, round 2: the finish area and the people and boards that make it look like a meet: a 5 cm finish line, finish posts, a
## timing tower with the RACE CLOCK, a lap board, an official who RINGS THE BELL as the leader starts the last lap, judges and photographers
## at the line, the break line with its cones, and a scoreboard on the infield facing the main stand (clock, lap, the first places and what
## is going on in the field). Dynamic parts are updated by the viewer every frame (`update`).

var rec: RaceRecording
var style := "club"
var field_lines: PackedStringArray = PackedStringArray()   # the viewer sets: what is on in the field right now (from the meet program)
var meet_title := "KEVÄTKISAT · BOYS 14 · 800 M"

var _half := 0.0
var _r_in := 0.0
var _r_out := 0.0
var _clock: Label3D
var _lap: Label3D
var _lap_board_text: Label3D
var _board: Label3D
var _bell_man: ProtoFigure
var _lap_man: ProtoFigure
var _bell: MeshInstance3D
var _people: Array = []
var _last_clock := ""
var _last_board := ""
var _font: Font


func _init(recording: RaceRecording, style_name: String) -> void:
	rec = recording
	style = style_name
	_half = rec.straight / 2.0
	_r_in = rec.r_in
	_r_out = rec.r_in + Race.LANE_W * rec.lanes
	_font = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	_finish_line()
	_break_marks()
	_timing_tower()
	_lap_station()
	_judges()
	_scoreboard()


func _std(c: Color, rough := 0.8, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m


func _box(center: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = center
	(parent if parent else self).add_child(mi)
	return mi


func _label(text: String, size_m: float, color: Color, parent: Node3D, pos: Vector3, yaw := 0.0, emissive := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 96
	l.pixel_size = size_m / 96.0
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false   # (a board is blank from behind, as a real one is)
	l.position = pos
	l.rotation.y = yaw
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _person(shirt: Color, name_text: String, pos: Vector3, yaw: float, shorts := Color("#2a2f3a")) -> ProtoFigure:
	var f := ProtoFigure.new(shirt, "", false, name_text, shorts)
	f.position = pos
	f.rotation.y = yaw
	f.glow.visible = false
	add_child(f)
	f.pose_stand()
	return f


# --- the finish ---------------------------------------------------------------------------------------------------------

func _finish_line() -> void:
	var white := _std(Color.WHITE, 0.6)
	# the painted line: 5 cm wide, across all the lanes (the engine's finish is the lap distance 0 = the right end of the home straight)
	_box(Vector3(_half, 0.018, (_r_in + _r_out) / 2.0), Vector3(0.05, 0.012, _r_out - _r_in), white)
	# finish posts: one on the kerb and one beyond the last lane, white with an orange band, as at a real meet
	for z in [_r_in - 0.5, _r_out + 0.9]:
		_box(Vector3(_half, 0.65, z), Vector3(0.06, 1.3, 0.06), white)
		_box(Vector3(_half, 1.05, z), Vector3(0.065, 0.18, 0.065), _std(Color("#ff5a36"), 0.6))
	if style == "arena":   # a gantry over the finish with the meet's banner
		var steel := _std(Color("#4a5163"), 0.5)
		for z in [_r_in - 1.2, _r_out + 1.6]:
			_box(Vector3(_half + 1.2, 2.6, z), Vector3(0.25, 5.2, 0.25), steel)
		_box(Vector3(_half + 1.2, 5.3, (_r_in + _r_out) / 2.0), Vector3(0.3, 0.7, _r_out - _r_in + 3.4), _std(Color("#0e1117"), 0.5))
		_label("FINISH", 0.55, Color.WHITE, self, Vector3(_half + 1.02, 5.3, (_r_in + _r_out) / 2.0), -PI / 2.0)


## The break line: where the runners leave their lanes. A short line across and an orange cone on every lane line (as on a real track).
func _break_marks() -> void:
	var cone := _std(Color("#ff7a1a"), 0.7)
	var white := _std(Color.WHITE, 0.6)
	var dd := rec.break_line
	var a := rec.point_free(dd, -0.3)
	var b := rec.point_free(dd, Race.LANE_W * rec.lanes - 0.3)
	var mid := (a + b) / 2.0
	var line := _box(Vector3(mid.x, 0.017, mid.y), Vector3(a.distance_to(b), 0.01, 0.05), white)
	line.rotation.y = atan2(-(b.y - a.y), b.x - a.x)
	for k in range(0, rec.lanes + 1):
		var p := rec.point_free(dd, Race.LANE_W * k - 0.3)
		var m := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.1
		c.height = 0.28
		c.radial_segments = 8
		m.mesh = c
		m.material_override = cone
		m.position = Vector3(p.x, 0.14, p.y)
		add_child(m)


## The timing tower beyond the finish on the stand side: a hut with the photo-finish camera on the roof and a clock facing the track.
func _timing_tower() -> void:
	var zc := _r_out + (6.5 if style == "club" else 5.8)
	var wall := _std(Color("#c9ccd6"), 0.8)
	_box(Vector3(_half + 1.0, 1.6, zc), Vector3(3.4, 3.2, 3.0), wall)
	_box(Vector3(_half + 1.0, 1.9, zc - 1.52), Vector3(2.6, 0.9, 0.05), _std(Color("#1a2230"), 0.2))   # the window
	_box(Vector3(_half + 1.0, 3.3, zc), Vector3(3.6, 0.2, 3.2), _std(Color("#4a5163"), 0.6))        # the roof
	_box(Vector3(_half, 4.4, zc + 0.3), Vector3(0.1, 2.2, 0.1), _std(Color("#2a2f3a"), 0.6))   # the photo-finish camera on its post, in line with the finish, above and behind the clock
	_box(Vector3(_half, 5.6, zc + 0.3), Vector3(0.3, 0.22, 0.42), _std(Color("#12141a"), 0.4))
	# the clock board, readable from the track
	_box(Vector3(_half + 1.0, 4.35, zc - 1.05), Vector3(3.2, 1.2, 0.12), _std(Color("#0a0d14"), 0.4))
	_clock = _label("0:00.0", 0.95, Color("#ffc83d"), self, Vector3(_half + 1.0, 4.4, zc - 1.13), PI)


## The lap board (laps to go) held up on the infield side of the line, and the bell man next to it.
func _lap_station() -> void:
	var zc := _r_in - 2.0
	_lap_man = _person(Color("#ff8a1a"), "lap official", Vector3(_half - 3.2, 0.0, zc), PI)
	_lap_man.sh_l.rotation = Vector3(2.7, 0, 0.15)
	_lap_man.sh_r.rotation = Vector3(2.7, 0, -0.15)
	_lap_man.el_l.rotation.x = 0.4
	_lap_man.el_r.rotation.x = 0.4
	var card := _box(Vector3(_half - 3.2, 2.55, zc - 0.05), Vector3(0.9, 0.6, 0.03), _std(Color("#f2f2f2"), 0.5))
	_lap = _label("2", 0.52, Color("#12141a"), self, Vector3(_half - 3.2, 2.55, zc + 0.03), 0.0)
	_label("LAPS TO GO", 0.09, Color("#12141a"), self, Vector3(_half - 3.2, 2.84, zc + 0.03), 0.0)
	card.name = "LapCard"
	_bell_man = _person(Color("#ffffff"), "bell official", Vector3(_half + 1.8, 0.0, zc + 0.2), PI)
	_bell = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.14
	_bell.mesh = s
	_bell.material_override = _std(Color("#e0b030"), 0.3, 0.4)
	_bell_man.el_r.add_child(_bell)
	_bell.position = Vector3(0, -0.34, 0)
	_bell_man.sh_r.rotation = Vector3(2.0, 0, -0.1)
	_bell_man.el_r.rotation.x = 0.9


## Judges at the line (hi-vis), with clipboards, and two photographers on the infield side.
func _judges() -> void:
	var zc := _r_in - 1.3
	for k in 4:
		_people.append(_person(Color("#ffd31a") if k % 2 == 0 else Color("#ff8a1a"), "judge%d" % k, Vector3(_half - 0.6 + k * 0.55 - 1.0, 0.0, zc - 0.5 * (k % 2)), PI))
	for k in 2:
		var ph := _person(Color("#2a2f3a"), "photographer%d" % k, Vector3(_half + 2.0 + k * 1.2, 0.0, _r_out + 1.7), 0.0)
		ph.sh_l.rotation = Vector3(1.5, 0, 0.1)
		ph.sh_r.rotation = Vector3(1.5, 0, -0.1)
		ph.el_l.rotation.x = 1.6
		ph.el_r.rotation.x = 1.6
		_box(Vector3(0, -0.2, -0.12), Vector3(0.2, 0.16, 0.3), _std(Color("#12141a"), 0.4), ph.el_l)
		_people.append(ph)


# --- the scoreboard ---------------------------------------------------------------------------------------------------

func _scoreboard() -> void:
	var legs := _std(Color("#4a5163"), 0.6)
	var pos := Vector3(-46.0, 0.0, -(_r_in - 4.0))
	var frame := Node3D.new()
	frame.position = pos
	add_child(frame)
	for x in [-5.6, 5.6]:
		_box(Vector3(x, 2.2, 0.0), Vector3(0.2, 4.4, 0.2), legs, frame)
	_box(Vector3(0, 5.1, 0), Vector3(12.4, 5.2, 0.3), _std(Color("#0a0d14"), 0.4), frame)
	_label(meet_title, 0.42, Color("#9aa6c0"), frame, Vector3(0, 7.2, 0.17), 0.0)
	_board = _label("", 0.62, Color.WHITE, frame, Vector3(0, 6.15, 0.17), 0.0)
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_board.position.x = -5.7
	_board.vertical_alignment = VERTICAL_ALIGNMENT_TOP


# --- every frame ----------------------------------------------------------------------------------------------------

func update(t: float, order: Array) -> void:
	var clock_t := t
	var P := rec.player
	var ft: float = rec.finish_t[order[0]] if not order.is_empty() else -1.0
	if ft >= 0.0 and t >= ft:
		clock_t = ft          # the clock stops on the winner
	var txt := _fmt(clock_t)
	if txt != _last_clock:
		_last_clock = txt
		_clock.text = txt
	# laps to go: counted from the leader
	var laps_total := int(round(Race.DISTANCE / rec.lap))
	var ld := rec.d_at(order[0], t)
	var to_go := clampi(laps_total - int(floor(ld / rec.lap + 0.0001)), 0, laps_total)
	_lap.text = str(to_go) if to_go > 0 else "–"
	# the bell: from the moment the leader starts the last lap for 6 seconds
	var bell_from := _time_leader_reaches(float(laps_total - 1) * rec.lap)
	var ringing := bell_from >= 0.0 and t >= bell_from and t < bell_from + 6.0 and to_go == 1
	if ringing:
		var s := (t - bell_from) * 14.0
		_bell_man.sh_r.rotation.x = 2.2 + 0.35 * sin(s)
		_bell_man.el_r.rotation.x = 0.9 + 0.5 * sin(s + 1.2)
		_bell.scale = Vector3.ONE * (1.0 + 0.15 * sin(s * 2.0))
	else:
		_bell_man.sh_r.rotation.x = 1.7
		_bell_man.el_r.rotation.x = 0.7
		_bell.scale = Vector3.ONE
	# the scoreboard
	var lines: Array = [_fmt(clock_t) + "      LAP %d / %d" % [mini(laps_total - to_go + 1, laps_total), laps_total]]
	for k in mini(3, order.size()):
		var i: int = order[k]
		lines.append("%d  %s" % [k + 1, str(rec.names[i]).to_upper()])
	var pp := order.find(P)
	if pp >= 3:
		lines.append("%d  YOU" % (pp + 1))
	for fl in field_lines:
		lines.append(fl)
	var text := "\n".join(lines)
	if text != _last_board:
		_last_board = text
		_board.text = text


func bell_ringing(t: float) -> bool:
	var laps_total := int(round(Race.DISTANCE / rec.lap))
	var bell_from := _time_leader_reaches(float(laps_total - 1) * rec.lap)
	return bell_from >= 0.0 and t >= bell_from and t < bell_from + 6.0


var _reach_cache := {}

## The time at which the leader (the front runner) first has run `metres`, or -1.
func _time_leader_reaches(metres: float) -> float:
	if _reach_cache.has(metres):
		return _reach_cache[metres]
	var res_t := -1.0
	for f in rec.count:
		var best := 0.0
		for i in rec.n:
			best = maxf(best, rec.d[i][f])
		if best >= metres:
			res_t = f * rec.dt
			break
	_reach_cache[metres] = res_t
	return res_t


static func _fmt(t: float) -> String:
	var m := int(t / 60.0)
	return "%d:%04.1f" % [m, t - m * 60.0]
