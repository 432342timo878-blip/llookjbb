class_name RaceRecording
extends RefCounted
## R6a prototype: ONE race, run by the real engine (Race, untouched) and recorded read-only, so that the three viewpoint
## prototypes can replay exactly the same race. The recorder only steps a Race of its own (own dice, own field) and READS the
## runners after every step: no game state, no autoload, no global dice, `race.gd` is not changed, so the races hash is untouched.
## Frame i = the state after i engine steps (frame 0 = the start), `dt` seconds apart. After a runner finishes the recording
## goes on without the engine: they ease off (a made-up jog-out, for the picture only).

const F_KICK := 1
const F_BOX := 2
const F_DOWN := 4
const F_DRAFT := 8
const F_DROP := 16
const F_SURGE := 32
const F_DONE := 64

const RIVAL_NAMES := ["A. Lahti", "J. Virta", "M. Salo", "T. Heino", "O. Rantala", "E. Niemi", "K. Lehto"]   # (made up: youth opponents are fictional)
const TAIL_FRAMES := 90   # 9 s of easing off after the last finisher

var indoor := false
var seed_used := 0
var dt := Race.DT
var count := 0           # frames
var n := 0               # runners
var player := 0          # index of the player's runner
var names: Array = []
var lane_of := PackedInt32Array()
# geometry copied from the Race (metres)
var r_in := 0.0
var r1 := 0.0
var straight := 0.0
var bend := 0.0
var lap := 0.0
var lanes := 0
var break_line := 0.0
var break_bends := 1
# per runner constants
var even_v := PackedFloat32Array()
var cs := PackedFloat32Array()
var dprime := PackedFloat32Array()
var err := PackedFloat32Array()
var skill := PackedFloat32Array()
var kick_at := PackedFloat32Array()
var personality: Array = []
var finish_t := PackedFloat32Array()   # -1 = did not finish
var even_time := 0.0                   # the player's even-paced time
var plan_time := 0.0                   # the time of the plan line of the prototypes: an even split to just under the player's own finish time
# per runner, per frame
var d: Array = []        # PackedFloat32Array each
var lat: Array = []
var v: Array = []
var res: Array = []      # the true reserve left as a share of dprime
var flags: Array = []    # PackedByteArray each
var marks: Array = []    # per runner: {metres: {t, pos}} as the engine recorded them
var events: Array = []   # the engine's own event list (read-only copy)
var results: Array = []
var score := 0.0         # how "tight" the race is (lower = better; see _score)


## Searches `tries` seeds from `first_seed` for a tight race (the player in the thick of it, a close finish, lead changes) and
## records the best. Deterministic: the same arguments give the same race.
static func make(indoor_track: bool, first_seed := 4100, tries := 150) -> RaceRecording:
	var best_seed := first_seed
	var best := 1.0e9
	for k in tries:
		var s := first_seed + k
		var rec := RaceRecording.new()
		var race := rec._build(indoor_track, s)
		race.run()
		var sc := rec._score(race)
		if sc < best:
			best = sc
			best_seed = s
		if sc < 1.0:
			break
	var out := RaceRecording.new()
	out._record(indoor_track, best_seed)
	out.score = best
	return out


func _field(rng: RandomNumberGenerator, runners: int) -> Array:
	var out := []
	for k in runners - 1:
		var ab := 9.0 + rng.randfn(0.0, 0.35)
		out.append({"name": RIVAL_NAMES[k % RIVAL_NAMES.size()], "club": "", "ability": ab, "speed": ab + rng.randfn(0.0, 2.0),
				"anaerobic": rng.randfn(0.0, 2.0), "tactics": clampf(rng.randfn(8.0, 3.0), 1.0, 20.0),
				"consistency": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0), "composure": 10.0,
				"competitiveness": clampf(rng.randfn(9.0, 3.0), 1.0, 20.0)})
	var pa := 9.0 + rng.randfn(0.0, 0.2)
	out.append({"name": "You", "club": "", "ability": pa, "speed": pa, "anaerobic": rng.randfn(0.0, 1.5), "tactics": 10.0,
			"consistency": 10.0, "composure": 10.0, "determination": 10.0, "is_player": true})
	return out


func _build(indoor_track: bool, s: int) -> Race:
	indoor = indoor_track
	seed_used = s
	var frng := RandomNumberGenerator.new()
	frng.seed = s * 7 + 13
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var race := Race.new()
	race.interactive = false
	race.setup(_field(frng, 6 if indoor_track else 8), "male", false, 10.0, rng, indoor_track, "final")
	race.set_player_plan("pack")
	return race


## Lower is tighter: the player 2nd-4th, the first four inside ~1.2 s, nobody out, lead changes happening.
func _score(race: Race) -> float:
	var res_list := race.results()
	var sc := 0.0
	var place := 0
	for i in res_list.size():
		if res_list[i].is_player:
			place = i + 1
		if res_list[i].status != "":
			sc += 5.0
	if place < 2 or place > 4:
		sc += 3.0 + absf(place - 3.0)
	var spread := 0.0
	if res_list.size() >= 4 and res_list[3].status == "":
		spread = float(res_list[3].time) - float(res_list[0].time)
	sc += maxf(0.0, spread - 1.2) * 2.0
	var changes := 0
	for e in race.events:
		if e.type == "lead_change":
			changes += 1
	sc += maxf(0.0, 2.0 - changes) * 0.6
	return sc


func _record(indoor_track: bool, s: int) -> void:
	var race := _build(indoor_track, s)
	r_in = race.r_in
	r1 = race.r1
	straight = race.straight
	bend = race.bend
	lap = race.lap
	lanes = race.lanes
	break_line = race.break_line
	break_bends = race.break_bends
	n = race.runners.size()
	for r in race.runners:
		names.append(r.name)
		lane_of.append(r.lane)
		even_v.append(r.even_v)
		cs.append(r.cs)
		dprime.append(r.dprime)
		err.append(r.err)
		skill.append(r.skill)
		kick_at.append(r.kick_at)
		personality.append(r.personality)
		d.append(PackedFloat32Array())
		lat.append(PackedFloat32Array())
		v.append(PackedFloat32Array())
		res.append(PackedFloat32Array())
		flags.append(PackedByteArray())
		if r.is_player:
			player = r.index
	even_time = race.runners[player].even_time
	var vd := PackedFloat32Array()    # distance and speed of runners that have finished (the jog-out)
	var vv := PackedFloat32Array()
	var vl := PackedFloat32Array()
	vd.resize(n)
	vv.resize(n)
	vl.resize(n)
	var done_at := PackedInt32Array()
	done_at.resize(n)
	done_at.fill(-1)
	var guard := 0
	var tail := 0
	_sample(race, vd, vv, vl, done_at)
	while guard < 5000 and tail < TAIL_FRAMES:
		guard += 1
		if not race.finished:
			race.step()
		else:
			tail += 1
		_sample(race, vd, vv, vl, done_at)
	count = d[0].size()
	events = race.events.duplicate(true)
	results = race.results()
	finish_t.resize(n)
	for r in race.runners:
		marks.append(r.marks.duplicate(true))
		finish_t[r.index] = r.t if (r.status == "" and r.done) else -1.0
	plan_time = float(finish_t[player]) - 0.5 if finish_t[player] > 0.0 else even_time


func _sample(race: Race, vd: PackedFloat32Array, vv: PackedFloat32Array, vl: PackedFloat32Array, done_at: PackedInt32Array) -> void:
	for r in race.runners:
		var i := r.index
		var f := 0
		var dist := r.d
		var speed := r.v
		var lt := r.lat
		if r.done and r.status == "":
			if done_at[i] < 0:
				done_at[i] = d[i].size()
				vd[i] = r.d
				vv[i] = maxf(r.v, 2.5)
				vl[i] = r.lat
			vv[i] = maxf(vv[i] * 0.975, 1.4)
			vd[i] += vv[i] * dt
			vl[i] += 0.04
			dist = vd[i]
			speed = vv[i]
			lt = vl[i]
			f |= F_DONE
		if r.kicking:
			f |= F_KICK
		if r.boxed:
			f |= F_BOX
		if r.down_left > 0.0 or r.getting_up:
			f |= F_DOWN
		if r.drafting:
			f |= F_DRAFT
		if r.dropped:
			f |= F_DROP
		if r.surge_left > 0.0:
			f |= F_SURGE
		if r.status == "dnf":
			f |= F_DONE
		d[i].append(dist)
		lat[i].append(lt)
		v[i].append(speed)
		res[i].append(clampf(r.dleft / maxf(r.dprime, 0.001), 0.0, 1.0))
		flags[i].append(f)


# --- Reading the recording (the viewpoints use these) ---------------------------------------------------------------

func duration() -> float:
	return (count - 1) * dt


## The frame before `t` and how far `t` is towards the next (0-1).
func frame_at(t: float) -> Vector2i:
	var x := clampf(t / dt, 0.0, float(count - 1))
	var i := mini(int(x), count - 2)
	return Vector2i(i, roundi((x - i) * 1000.0))


func d_at(i: int, t: float) -> float:
	var fa := frame_at(t)
	return lerpf(d[i][fa.x], d[i][fa.x + 1], fa.y / 1000.0)


func lat_at(i: int, t: float) -> float:
	var fa := frame_at(t)
	return lerpf(lat[i][fa.x], lat[i][fa.x + 1], fa.y / 1000.0)


func v_at(i: int, t: float) -> float:
	var fa := frame_at(t)
	return lerpf(v[i][fa.x], v[i][fa.x + 1], fa.y / 1000.0)


func res_at(i: int, t: float) -> float:
	var fa := frame_at(t)
	return lerpf(res[i][fa.x], res[i][fa.x + 1], fa.y / 1000.0)


func flags_at(i: int, t: float) -> int:
	return flags[i][frame_at(t).x]


## Where runner i is at time t, in track metres (Vector2: x along the home straight, y towards the home straight's side).
func position_at(i: int, t: float) -> Vector2:
	return point(d_at(i, t), lat_at(i, t), lane_of[i])


## Track point of a runner who has run `dd` metres and is `lt` metres outside the lane 1 line (the same geometry as the race screen:
## RaceRunnersView._position).
func point(dd: float, lt: float, lane: int) -> Vector2:
	if dd < break_line:
		var radius := r_in + (lane - 0.5) * Race.LANE_W
		return stadium_point(radius, straight + break_bends * PI * (radius - r1) + dd)
	return point_free(dd, lt)


## The same without the lane stagger (a line across the track, the plan line).
func point_free(dd: float, lt: float) -> Vector2:
	var radius := r1 + lt + 0.3
	return stadium_point(radius, _path_s(fmod(dd, lap), radius))


func heading_at(i: int, t: float) -> Vector2:
	var dd := d_at(i, t)
	var lt := lat_at(i, t)
	var a := point(dd, lt, lane_of[i])
	var b := point(dd + 1.5, lt, lane_of[i])
	var h := b - a
	return h.normalized() if h.length() > 0.001 else Vector2.RIGHT


func _path_s(p: float, radius: float) -> float:
	var arc := PI * radius
	if p < bend:
		return straight + p / bend * arc
	p -= bend
	if p < straight:
		return straight + arc + p
	p -= straight
	if p < bend:
		return 2.0 * straight + arc + p / bend * arc
	p -= bend
	return p


## Point at distance `s` along a stadium-shaped path of radius `r`, starting at the left end of the home straight
## (y = +r) and running anticlockwise on screen (as seen from above).
func stadium_point(r: float, s: float) -> Vector2:
	var half := straight / 2.0
	var arc := PI * r
	s = fmod(s, 2.0 * straight + 2.0 * arc)
	if s < straight:
		return Vector2(-half + s, r)
	s -= straight
	if s < arc:
		return Vector2(half, 0.0) + Vector2.from_angle(PI / 2.0 - s / r) * r
	s -= arc
	if s < straight:
		return Vector2(half - s, -r)
	s -= straight
	return Vector2(-half, 0.0) + Vector2.from_angle(-PI / 2.0 - s / r) * r


## Runners in order of distance at time t (finished ones by finish time), as indices.
func order_at(t: float) -> Array:
	var idx := range(n)
	idx.sort_custom(func(a, b):
		var fa := finish_t[a]
		var fb := finish_t[b]
		var done_a := fa >= 0.0 and fa <= t
		var done_b := fb >= 0.0 and fb <= t
		if done_a and done_b:
			return fa < fb
		if done_a != done_b:
			return done_a
		return d_at(a, t) > d_at(b, t))
	return idx
