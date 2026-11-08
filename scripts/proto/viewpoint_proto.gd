class_name ViewpointProto
extends Control
## R6a prototype screen (Dev menu -> "Viewpoint prototypes"): ONE recorded race (RaceRecording) replayed through three viewpoints that
## share one 3D stadium and one set of figures:  1 chase camera behind your runner,  2 TV side camera (a rail camera on the infield with
## a head-on shot for the finish),  3 the top-down view made rich (zoomed on the pack, figures, effort glows).  A prototype to look
## at and choose from (GDD 4.11): nothing here is a game system, no game state is touched and no engine file changed.
## Keys: 1 2 3 or V = viewpoint, Space = play / pause, R = restart, Left / Right = back / forward 5 s (Shift: 1 s), Up / Down = speed,
## I = indoor / outdoor track, N = another race, H = hide / show the graphics, M = slow motion at key moments on / off, Esc = back.

enum View { CHASE, BROADCAST, TOP }
const VIEW_NAMES := ["Chase", "TV side", "Top-down"]
const CLUB_COLORS := [Color("#2f6db5"), Color("#e8e8ee"), Color("#6aa84f"), Color("#f2b632"), Color("#8e5ea2"), Color("#2fb5a5"), Color("#d94a8a"), Color("#c9c9d3")]
const SPEEDS := [0.5, 1.0, 2.0, 4.0]
const SLOW_FACTOR := 0.35
const SLOW_SECONDS := 1.8

var rec: RaceRecording
var view := View.CHASE
var t := 0.0
var playing := true
var speed_i := 1
var slow_on := true
var _indoor := false
var _seed_base := 4100
var _recs := {}

var _container: SubViewportContainer
var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _figs: Array = []
var _stadium: ProtoStadium
var _plan_bar: MeshInstance3D
var _hud: ProtoHud
var _bar: PanelContainer
var _slider: HSlider
var _view_buttons: Array = []
var _play_button: Button
var _speed_button: Button
var _track_button: Button
var _slow_button: Button
var _status: Label
var _moments: Array = []
var _last_t := 0.0
var _alert := ""
var _alert_t := 99.0
var _split := ""
var _split_t := 99.0
var _snap := true
var _shot := ""
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _cam_fov := 60.0
var _top_h := 30.0
var _fade := 0.0
var _busy := false
var _rank := {}   # runner -> place now (0 = leading)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit_bar)
	_status = UIKit.label("Recording a race from the real engine ...", "TitleLabel")
	_status.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_status)
	_load.call_deferred(false)


func _load(indoor_track: bool, new_race := false) -> void:
	if _busy:
		return
	_busy = true
	_indoor = indoor_track
	playing = false
	if _status:
		_status.visible = true
		_status.text = "Recording a race from the real engine ..."
	await get_tree().process_frame
	await get_tree().process_frame
	if new_race:
		_seed_base += 97
		_recs.erase(_indoor)
	if not _recs.has(_indoor):
		_recs[_indoor] = RaceRecording.make(_indoor, _seed_base + (1000 if _indoor else 0))
	rec = _recs[_indoor]
	_moments = _find_moments()
	_build_all()
	t = 0.0
	_last_t = 0.0
	_alert_t = 99.0
	_split_t = 99.0
	_snap = true
	playing = true
	_busy = false
	if _status:
		_status.visible = false


func _build_all() -> void:
	for c in get_children():
		if c != _status:
			c.queue_free()
	_figs.clear()
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.handle_input_locally = false
	_container.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_cam = Camera3D.new()
	_cam.near = 0.1
	_cam.far = 700.0
	_world.add_child(_cam)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#080b14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a97b8")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, 35.0, 0.0)
	sun.light_color = Color("#fff1da")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_world.add_child(sun)
	_stadium = ProtoStadium.new(rec)
	_world.add_child(_stadium)
	# the runners
	for i in rec.n:
		var is_p := i == rec.player
		var fig := ProtoFigure.new(Palette.ACCENT if is_p else CLUB_COLORS[i % CLUB_COLORS.size()], str(i + 1), is_p, str(rec.names[i]))
		_world.add_child(fig)
		_figs.append(fig)
		var tag: Label3D = fig.tag
		tag.text = "YOU" if is_p else str(rec.names[i])
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.font_size = 72 if is_p else 56
		tag.outline_size = 14
		tag.modulate = Palette.ACCENT if is_p else Color.WHITE
		tag.outline_modulate = Color(0.04, 0.05, 0.08, 0.9)
		tag.render_priority = 5
		_world.add_child(tag)
		var cue: Label3D = fig.cue
		cue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cue.no_depth_test = true
		cue.font_size = 48
		cue.outline_size = 12
		cue.modulate = Palette.LEAD
		cue.outline_modulate = Color(0.04, 0.05, 0.08, 0.9)
		cue.render_priority = 6
		_world.add_child(cue)
	# the plan line: where an even-paced run (the coach's plan) would be by now
	_plan_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(Race.LANE_W * rec.lanes + 1.0, 0.22)
	_plan_bar.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(Palette.LEAD, 0.4)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plan_bar.material_override = m
	_plan_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_plan_bar)
	# the graphics and the controls
	_hud = ProtoHud.new()
	_hud.rec = rec
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hud)
	_build_controls()


# --- controls ---------------------------------------------------------------------------------------------------------

func _build_controls() -> void:
	_bar = PanelContainer.new()
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.anchor_top = 1.0
	_bar.offset_top = -66.0
	_bar.offset_bottom = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.067, 0.09, 0.92)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_bar.add_theme_stylebox_override("panel", sb)
	add_child(_bar)
	var col := UIKit.vbox(2)
	_bar.add_child(col)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = rec.duration()
	_slider.step = 0.1
	_slider.custom_minimum_size.y = 14
	_slider.value_changed.connect(func(v): seek(v))
	col.add_child(_slider)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	col.add_child(flow)
	var group := ButtonGroup.new()
	_view_buttons.clear()
	for k in 3:
		var b := UIKit.toggle("%d  %s" % [k + 1, VIEW_NAMES[k]], group)
		b.custom_minimum_size = Vector2(110, 44)
		b.button_pressed = k == view
		b.pressed.connect(func(): set_view(k))
		flow.add_child(b)
		_view_buttons.append(b)
	_play_button = UIKit.button("Pause", false, 80)
	_play_button.custom_minimum_size.y = 44
	_play_button.pressed.connect(toggle_play)
	flow.add_child(_play_button)
	var restart := UIKit.button("Restart", false, 80)
	restart.custom_minimum_size.y = 44
	restart.pressed.connect(restart_race)
	flow.add_child(restart)
	_speed_button = UIKit.button("1x", false, 56)
	_speed_button.custom_minimum_size.y = 44
	_speed_button.pressed.connect(cycle_speed)
	flow.add_child(_speed_button)
	_slow_button = UIKit.button("Slow-mo on", false, 100)
	_slow_button.custom_minimum_size.y = 44
	_slow_button.pressed.connect(toggle_slow)
	flow.add_child(_slow_button)
	var hud := UIKit.button("Graphics", false, 90)
	hud.custom_minimum_size.y = 44
	hud.pressed.connect(toggle_hud)
	flow.add_child(hud)
	_track_button = UIKit.button("Indoor" if not _indoor else "Outdoor", false, 90)
	_track_button.custom_minimum_size.y = 44
	_track_button.pressed.connect(func(): _load(not _indoor))
	flow.add_child(_track_button)
	var nr := UIKit.button("New race", false, 90)
	nr.custom_minimum_size.y = 44
	nr.pressed.connect(func(): _load(_indoor, true))
	flow.add_child(nr)
	var back := UIKit.button("Back", false, 70)
	back.custom_minimum_size.y = 44
	back.pressed.connect(Router.go.bind("dev_menu"))
	flow.add_child(back)
	_fit_bar()
	_refresh_buttons()


## The bar is one row of buttons on a wide window, three on a phone.
func _fit_bar() -> void:
	if _bar:
		_bar.offset_top = -(76.0 if size.x > 1000.0 else (150.0 if size.x > 560.0 else 214.0))
		if _hud:
			_hud.bottom_margin = -_bar.offset_top + 4.0
			_hud.queue_redraw()


func _refresh_buttons() -> void:
	if _play_button:
		_play_button.text = "Pause" if playing else "Play"
	if _speed_button:
		_speed_button.text = "%sx" % str(SPEEDS[speed_i])
	if _slow_button:
		_slow_button.text = "Slow-mo on" if slow_on else "Slow-mo off"
	for k in _view_buttons.size():
		_view_buttons[k].set_pressed_no_signal(k == view)


func set_view(v: int) -> void:
	if v == int(view):
		return
	view = v as View
	_snap = true
	_shot = ""
	_fade = 1.0
	_refresh_buttons()


func toggle_play() -> void:
	if not playing and t >= rec.duration() - 0.05:
		restart_race()
		return
	playing = not playing
	_refresh_buttons()


func restart_race() -> void:
	seek(0.0)
	playing = true
	_refresh_buttons()


func cycle_speed() -> void:
	speed_i = (speed_i + 1) % SPEEDS.size()
	_refresh_buttons()


func toggle_slow() -> void:
	slow_on = not slow_on
	_refresh_buttons()


func toggle_hud() -> void:
	_hud.visible_hud = not _hud.visible_hud
	_hud.queue_redraw()


func seek(to: float) -> void:
	t = clampf(to, 0.0, rec.duration())
	_last_t = t
	_alert_t = 99.0
	_split_t = 99.0
	_snap = true


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or rec == null:
		return
	var e := event as InputEventKey
	match e.keycode:
		KEY_1: set_view(View.CHASE)
		KEY_2: set_view(View.BROADCAST)
		KEY_3: set_view(View.TOP)
		KEY_V: set_view((int(view) + 1) % 3)
		KEY_SPACE: toggle_play()
		KEY_R: restart_race()
		KEY_LEFT: seek(t - (1.0 if e.shift_pressed else 5.0))
		KEY_RIGHT: seek(t + (1.0 if e.shift_pressed else 5.0))
		KEY_UP:
			speed_i = mini(speed_i + 1, SPEEDS.size() - 1)
			_refresh_buttons()
		KEY_DOWN:
			speed_i = maxi(speed_i - 1, 0)
			_refresh_buttons()
		KEY_I: _load(not _indoor)
		KEY_N: _load(_indoor, true)
		KEY_H: toggle_hud()
		KEY_M: toggle_slow()
		KEY_ESCAPE: Router.go("dev_menu")
		_:
			return
	get_viewport().set_input_as_handled()


# --- the key moments (read from the recording) -----------------------------------------------------------------------

func _find_moments() -> Array:
	var out: Array = []
	var P := rec.player
	var last_t := -10.0
	for f in range(1, rec.count):
		var tt := f * rec.dt
		var dp: float = rec.d[P][f]
		var text := ""
		for i in rec.n:
			var before: int = rec.flags[i][f - 1]
			var now: int = rec.flags[i][f]
			var near := absf(float(rec.d[i][f]) - dp) < 22.0
			if i == P:
				if (now & RaceRecording.F_BOX) and not (before & RaceRecording.F_BOX):
					text = "BOXED IN"
				elif (now & RaceRecording.F_KICK) and not (before & RaceRecording.F_KICK):
					text = "YOU KICK"
				elif (now & RaceRecording.F_DOWN) and not (before & RaceRecording.F_DOWN):
					text = "YOU GO DOWN"
			elif near:
				if (now & RaceRecording.F_SURGE) and not (before & RaceRecording.F_SURGE) and float(rec.d[i][f]) > 120.0:
					text = "%s MAKES A MOVE" % str(rec.names[i]).to_upper()
				elif (now & RaceRecording.F_KICK) and not (before & RaceRecording.F_KICK):
					text = "%s KICKS" % str(rec.names[i]).to_upper()
				elif (now & RaceRecording.F_DOWN) and not (before & RaceRecording.F_DOWN):
					text = "%s GOES DOWN" % str(rec.names[i]).to_upper()
			if text != "":
				break
		if text != "" and tt - last_t >= 6.0:
			out.append({"t": tt, "text": text})
			last_t = tt
	return out


# --- every frame ------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if rec == null or _busy or _cam == null:
		return
	var factor := 1.0
	for m in _moments:
		if slow_on and t >= m.t and t < m.t + SLOW_SECONDS:
			factor = SLOW_FACTOR
	if playing:
		t += delta * SPEEDS[speed_i] * factor
		if t >= rec.duration():
			t = rec.duration()
			playing = false
			_refresh_buttons()
	_alert_t += delta
	_split_t += delta
	_fade = maxf(0.0, _fade - delta * 4.0)
	if t > _last_t:
		for m in _moments:
			if m.t > _last_t and m.t <= t:
				_alert = m.text
				_alert_t = 0.0
		_check_splits()
	_last_t = t
	_update_runners()
	_update_camera(delta)
	_stadium.roof.visible = view != View.TOP
	_update_hud(factor)
	if _slider:
		_slider.set_value_no_signal(t)


func _check_splits() -> void:
	var P := rec.player
	var marks: Dictionary = rec.marks[P]
	for k in marks:
		var mt := float(marks[k].t)
		if mt > _last_t and mt <= t:
			_split = "%d m   %s   P%d" % [int(k), ProtoHud._fmt(mt), int(marks[k].pos)]
			_split_t = 0.0
	var ft: float = rec.finish_t[P]
	if ft > _last_t and ft <= t:
		var place := 1
		for i in rec.n:
			if rec.finish_t[i] >= 0.0 and rec.finish_t[i] < ft:
				place += 1
		_split = "FINISH   %s   P%d" % [ProtoHud._fmt(ft), place]
		_split_t = 0.0


func _update_runners() -> void:
	var P := rec.player
	_rank.clear()
	var ord := rec.order_at(t)
	for k in ord.size():
		_rank[ord[k]] = k
	var pp := rec.position_at(P, t)
	var cam_pos := _cam.global_position
	for i in rec.n:
		var fig: ProtoFigure = _figs[i]
		var p2 := rec.position_at(i, t)
		var h2 := rec.heading_at(i, t)
		fig.position = Vector3(p2.x, 0.0, p2.y)
		fig.rotation.y = atan2(-h2.x, -h2.y)
		var dd := rec.d_at(i, t)
		var vv := rec.v_at(i, t)
		var fl := rec.flags_at(i, t)
		var down := (fl & RaceRecording.F_DOWN) != 0
		var cyc := ProtoFigure.CYCLE_M * (0.72 + 0.28 * clampf(vv / 7.0, 0.0, 1.4))
		var amp := 0.0 if vv < 0.4 else clampf(vv / 6.8, 0.15, 1.25)
		var lean := 0.07 + 0.12 * clampf(vv / 7.0, 0.0, 1.3) + (0.07 if (fl & RaceRecording.F_KICK) else 0.0)
		fig.pose(dd / cyc * TAU + i * 0.9, amp, lean, down)
		# the effort glow: cool when easy, hot when giving everything
		var ratio := vv / maxf(rec.even_v[i], 0.1)
		var e := clampf((ratio - 0.85) / 0.4, 0.0, 1.0)
		var col := Color(0.35, 0.65, 1.0).lerp(Color(1.0, 0.95, 0.75), clampf(e * 2.0, 0.0, 1.0)).lerp(Color(1.0, 0.3, 0.12), clampf(e * 2.0 - 1.0, 0.0, 1.0))
		if fl & RaceRecording.F_KICK:
			col = Color(1.0, 0.25, 0.1)
		var size_m := 1.5 + 1.4 * e + (0.5 if i == P else 0.0)
		if view == View.TOP:
			size_m *= 1.35
		var a := (0.35 + 0.5 * e) * (0.0 if (fl & RaceRecording.F_DONE) else 1.0)
		if i == P:
			col = col.lerp(Palette.ACCENT, 0.55)
			a = maxf(a, 0.5)
		fig.glow.scale = Vector3(size_m, size_m, 1.0)
		fig.glow_mat.albedo_color = Color(col, a)
		# floating labels
		var dist_cam := cam_pos.distance_to(fig.position)
		var near_player := p2.distance_to(pp) < 14.0 and i != P
		var scale_ := clampf(dist_cam, 6.0, 90.0) / 10.0
		fig.tag.pixel_size = 0.0021 * scale_
		fig.cue.pixel_size = 0.0019 * scale_
		var cue := ""
		if near_player or (view == View.TOP and i != P and p2.distance_to(pp) < 25.0):
			cue = _cue(i)
		fig.cue.text = cue
		fig.cue.visible = cue != "" and _hud.visible_hud
		var lift := 2.25 if view != View.TOP else 0.3
		var north := -1.1 * scale_ if view == View.TOP else 0.0
		fig.tag.position = fig.position + Vector3(0, lift, north)
		fig.cue.position = fig.position + Vector3(0, lift + 0.42 * scale_ * (1.0 if view != View.TOP else 0.6), north - (0.9 * scale_ if view == View.TOP else 0.0))
		var rank: int = _rank.get(i, 9)
		var ahead_of_cam := (fig.position - cam_pos).dot(-_cam.global_transform.basis.z) > 3.0
		fig.tag.visible = _hud.visible_hud and ((view == View.CHASE and near_player and ahead_of_cam) or (view == View.BROADCAST and (i == P or rank < 3)) or view == View.TOP)
	# the plan line
	var target_d := Race.DISTANCE * clampf(t / rec.plan_time, 0.0, 1.0)
	var a := rec.point_free(target_d, -0.3)
	var b := rec.point_free(target_d, Race.LANE_W * rec.lanes - 0.3)
	var mid := (a + b) / 2.0
	_plan_bar.position = Vector3(mid.x, 0.06, mid.y)
	_plan_bar.rotation = Vector3(-PI / 2.0, atan2(-(b.y - a.y), b.x - a.x), 0.0)
	_plan_bar.visible = target_d > 1.0 and target_d < Race.DISTANCE - 0.5


func _cue(i: int) -> String:
	var fl := rec.flags_at(i, t)
	var r := rec.res_at(i, t)
	var to_go := Race.DISTANCE - rec.d_at(i, t)
	if fl & RaceRecording.F_DOWN:
		return "DOWN"
	if fl & RaceRecording.F_KICK:
		return "KICKING"
	if fl & RaceRecording.F_SURGE:
		return "MOVING"
	if fl & RaceRecording.F_BOX:
		return "BOXED IN"
	if r < 0.2 and to_go > 20.0:
		return "BREATHING HARD"
	if str(rec.personality[i]) == "kicker" and to_go > 0.0 and to_go < rec.kick_at[i] + 60.0 and r > 0.35:
		return "ABOUT TO GO"
	if fl & RaceRecording.F_DROP:
		return "LOSING CONTACT"
	return ""


# --- cameras ----------------------------------------------------------------------------------------------------------

func _sm(cur: Vector3, target: Vector3, rate: float, delta: float) -> Vector3:
	return target if _snap else cur.lerp(target, 1.0 - exp(-rate * delta))


func _smf(cur: float, target: float, rate: float, delta: float) -> float:
	return target if _snap else lerpf(cur, target, 1.0 - exp(-rate * delta))


func _v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


func _update_camera(delta: float) -> void:
	var P := rec.player
	var pos := Vector3.ZERO
	var look := Vector3.ZERO
	var fov := 60.0
	var pos_rate := 8.0
	var look_rate := 10.0
	var up := Vector3.UP
	match view:
		View.CHASE:
			var dd := rec.d_at(P, t)
			var lt := rec.lat_at(P, t)
			var lane := rec.lane_of[P]
			var here := rec.position_at(P, t)
			var h := rec.heading_at(P, t)
			var back := rec.point(dd - 6.0, lt, lane) if dd > 6.0 else here - h * 6.0
			var right := Vector2(-h.y, h.x)
			pos = _v3(back + right * 0.55, 2.6)
			look = _v3(rec.point(dd + 14.0, lt, lane), 1.0)
			var kick := 1.0 if (rec.flags_at(P, t) & RaceRecording.F_KICK) else 0.0
			fov = 68.0 + 6.0 * kick + 3.0 * clampf(rec.v_at(P, t) / 7.0, 0.0, 1.0)
		View.BROADCAST:
			var order := rec.order_at(t)
			var leader: int = order[0]
			var ld := rec.d_at(leader, t)
			var finish_zone := Race.DISTANCE - rec.straight - 6.0
			var shot := "finish" if ld >= finish_zone else "rail"
			if shot != _shot:
				if _shot != "":
					_fade = 1.0
					_snap = true
				_shot = shot
			var half := rec.straight / 2.0
			var rm := rec.r_in + Race.LANE_W * rec.lanes / 2.0
			if shot == "finish":
				var r_out := rec.r_in + Race.LANE_W * rec.lanes
				pos = Vector3(half + (6.0 if not rec.indoor else 4.0), 2.2, r_out + (2.0 if not rec.indoor else 1.2))
				look = Vector3(half - 30.0, 1.1, rm - 3.0)
				fov = 30.0
				pos_rate = 20.0
				look_rate = 20.0
			else:
				var c := _pack_center()
				var h := rec.heading_at(P, t)
				var inward := Vector2(h.y, -h.x)
				var dist := 17.0 if not rec.indoor else 9.0
				pos = _v3(c + inward * dist, 1.9)
				look = _v3(c + h * 2.0, 1.0)
				fov = 36.0 if not rec.indoor else 46.0
				pos_rate = 3.2
				look_rate = 5.0
		View.TOP:
			var lo := Vector2(1.0e9, 1.0e9)
			var hi := Vector2(-1.0e9, -1.0e9)
			var dp := rec.d_at(P, t)
			var order := rec.order_at(t)
			var ld := rec.d_at(order[0], t)
			for i in rec.n:
				var di := rec.d_at(i, t)
				if absf(di - dp) < 45.0 or absf(di - ld) < 12.0:
					var p2 := rec.position_at(i, t)
					lo = Vector2(minf(lo.x, p2.x), minf(lo.y, p2.y))
					hi = Vector2(maxf(hi.x, p2.x), maxf(hi.y, p2.y))
			var ctr := (lo + hi) / 2.0
			var ext := (hi - lo) + Vector2(10.0, 10.0)
			var asp := maxf(size.x / maxf(size.y, 1.0), 0.5)
			var tan_h := tan(deg_to_rad(42.0) / 2.0) * (asp if asp >= 1.0 else 1.6)   # (portrait: the field of view is the horizontal one, see below)
			var tan_v := tan_h / asp
			var h_need := maxf(ext.x / (2.0 * tan_h), ext.y / (2.0 * tan_v)) * 1.1
			_top_h = _smf(_top_h, clampf(h_need, 12.0, 110.0), 2.0, delta)
			pos = Vector3(ctr.x, _top_h, ctr.y + _top_h * 0.2)
			look = Vector3(ctr.x, 0.0, ctr.y)
			up = Vector3(0, 0, -1)
			fov = 42.0
			pos_rate = 5.0
			look_rate = 6.0
	_cam_pos = _sm(_cam_pos, pos, pos_rate, delta)
	_cam_look = _sm(_cam_look, look, look_rate, delta)
	_cam_fov = _smf(_cam_fov, fov, 4.0, delta)
	# a vertical field of view on a wide window; on a phone held upright the same picture needs the horizontal one
	var portrait := size.x < size.y
	_cam.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	_cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_cam_fov) / 2.0) * 1.6)) if portrait else _cam_fov
	if _cam_pos.distance_to(_cam_look) > 0.05:
		_cam.look_at_from_position(_cam_pos, _cam_look, up)
	_snap = false


## The centre of the pack the TV camera follows: you and the leader count most, the runners near you a little.
func _pack_center() -> Vector2:
	var P := rec.player
	var order := rec.order_at(t)
	var sum := rec.position_at(P, t) * 2.0 + rec.position_at(order[0], t) * 2.0
	var w := 4.0
	var pp := rec.position_at(P, t)
	for i in rec.n:
		if i == P or i == order[0]:
			continue
		var p2 := rec.position_at(i, t)
		if p2.distance_to(pp) < 25.0:
			sum += p2
			w += 1.0
	return sum / w


# --- the graphics -----------------------------------------------------------------------------------------------------

func _update_hud(factor: float) -> void:
	var P := rec.player
	var order := rec.order_at(t)
	var rows := []
	var leader: int = order[0]
	var ld := rec.d_at(leader, t)
	var lv := maxf(rec.v_at(leader, t), 4.0)
	var first_finish := -1.0
	for pos in order.size():
		var i: int = order[pos]
		var fin: float = rec.finish_t[i]
		var gap := ""
		if fin >= 0.0 and fin <= t:
			if first_finish < 0.0:
				first_finish = fin
				gap = ProtoHud._fmt(fin)
			else:
				gap = "+%.2f" % (fin - first_finish)
		elif pos > 0:
			gap = "+%.1f" % maxf(0.0, (ld - rec.d_at(i, t)) / lv)
		rows.append({"pos": pos + 1, "name": rec.names[i], "gap": gap, "is_player": i == P,
				"color": Palette.ACCENT if i == P else CLUB_COLORS[i % CLUB_COLORS.size()]})
	var dots := []
	for i in rec.n:
		dots.append({"p": rec.position_at(i, t), "is_player": i == P, "color": CLUB_COLORS[i % CLUB_COLORS.size()]})
	var ratio := rec.v_at(P, t) / maxf(rec.even_v[P], 0.1)
	var target_d := Race.DISTANCE * clampf(t / rec.plan_time, 0.0, 1.0)
	_hud.s = {
		"view": VIEW_NAMES[view], "clock": minf(t, maxf(rec.finish_t[P], 0.0) if (rec.finish_t[P] >= 0.0 and t > rec.finish_t[P]) else t),
		"dist": rec.d_at(P, t), "rows": rows, "reserve": rec.res_at(P, t),
		"felt": clampf(rec.res_at(P, t) + rec.err[P], 0.0, 1.0), "fuzz": 0.05 + 0.2 * (1.0 - rec.skill[P]),
		"effort": clampf((ratio - 0.8) / 0.5, 0.0, 1.0), "plan": (rec.d_at(P, t) - target_d) / maxf(rec.even_v[P], 0.1),
		"alert": _alert, "alert_age": _alert_t, "split": _split, "split_age": _split_t, "dots": dots,
		"slow": factor < 1.0, "title": "",
	}
	_hud.queue_redraw()
