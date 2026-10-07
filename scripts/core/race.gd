class_name Race
extends RefCounted
## One 800 m race, simulated in small time steps on a real track: outdoor 400 m (8 lanes) or indoor 200 m (6 lanes).
##
## Each runner has a sustainable speed (cs) and an anaerobic reserve (dprime, in metres): running faster than
## cs drains the reserve, running close behind someone (drafting) costs less, and an empty reserve means tying
## up. Pack racing (GDD 4.3.1, step R1): the race has a shape (fast / honest / tactical) and the leader runs its
## pace; everyone else follows the runner ahead while the reserve they *feel* they will have at their kick point
## is enough, and is dropped when it isn't. The plan is the place a runner wants (lead / pack / back).
## The player's choices (detailed mode) arrive at decision points; in quick mode the athlete decides on their
## own based on race tactics. All numbers in data/races.json (`engine`, `shapes`, `personalities`); all dice
## from the race's own RNG.

const DISTANCE := 800.0
const LANE_W := 1.22
const DT := 0.1
## Indoor bends are tight: runners lose a little speed on them.
const INDOOR_BEND_SPEED := 0.985

# Track geometry (set in setup). Distances are along the lane 1 measuring line, 30 cm outside the kerb.
var indoor := false
var r_in := 36.5                  # inner kerb radius
var r1 := 36.8                    # lane 1 measuring line radius
var straight := 84.39
var bend := PI * 36.8             # 115.6 m outdoors
var lap := 400.0
var lanes := 8
var break_line := bend            # 800 m runners stay in lanes for the first bend

signal decision_needed(decision: Dictionary)
signal commentary(text: String)

var runners: Array[Runner] = []
var player: Runner
var time := 0.0
var finished := false
var interactive := false          # detailed mode: pause at decision points
var pending: Dictionary = {}      # decision waiting for the player
var log_lines: Array[String] = []

var shape := ""                   # fast / honest / tactical (rolled at the start)
var lap1_pace := 1.0              # the leader's pace as a share of the field's even speed: lap 1 ...
var lap2_pace := 1.0              # ... and lap 2 (until the kicks)
var ref_speed := 0.0              # the field's even speed (m/s)

var _asked := {}
var _rng: RandomNumberGenerator
var _eng: Dictionary              # data/races.json "engine"
var _mix := ""
var _leader: Runner
var _box_timer := 0.0
var _announced := {}


class Runner:
	var name := ""
	var club := ""
	var is_player := false
	var rival: Dictionary = {}    # the rival pool entry, for PBs
	var lane := 1
	var ability := 0.0            # race-day ability after form
	var speed := 0.0
	var tactics := 10.0
	var even_time := 0.0          # time for an even-paced race at this ability
	var cs := 0.0                 # sustainable speed, m/s
	var dprime := 0.0             # anaerobic reserve, metres above cs
	var dleft := 0.0
	var vmax := 0.0
	var kick_v := 0.0             # the fastest they can kick at the end of the race
	var d := 0.0                 # distance run (lane 1 equivalent)
	var v := 0.0
	var lat := 0.0                # metres outside the lane 1 line
	var lat_target := 0.0
	var personality := ""         # front / pack / kicker / surger (data/races.json); "" = the player
	var want := "pack"            # the place they run for: lead / pack / back (the player's plan)
	var pace_factor := 1.0        # the player's bell choice (push / hold / ease)
	var kick_at := 200.0          # metres to go when the kick starts
	var kicking := false
	var drafting := false
	var draft := 0.0              # share of speed saved this step by running behind someone
	var err := 0.0                # misjudged reserve, share of dprime (fixed for the race)
	var dig := 0.0                # how much of the kick reserve they give up to hang on
	var dropped := false          # more than drop_gap metres behind the runner ahead
	var t := 0.0                  # finish time
	var done := false
	var split_400 := 0.0


## `entrants`: Dictionaries with name, club, ability, speed, anaerobic, tactics, consistency, composure
## (+ is_player, rival, personality, competitiveness / determination). `big_meet` makes composure matter.
## `player_fatigue` 0–100. `mix` = the race-shape mix (data/races.json shapes.mix: local / district / heat /
## final; "" = the default).
func setup(entrants: Array, gender: String, big_meet: bool, player_fatigue: float, rng: RandomNumberGenerator,
		indoor_track := false, mix := "") -> void:
	_rng = rng
	_eng = Data.races.engine
	_mix = mix
	var e_cfg := _eng
	if indoor_track:
		# A standard 200 m indoor track with 6 lanes.
		indoor = true
		r_in = 17.2
		r1 = 17.5
		bend = PI * r1
		straight = (200.0 - 2.0 * bend) / 2.0
		lap = 200.0
		lanes = 6
		break_line = bend
	var lane_order := range(1, lanes + 1)
	for k in range(lane_order.size() - 1, 0, -1):   # shuffled with the race's own dice
		var j := rng.randi_range(0, k)
		var tmp = lane_order[k]
		lane_order[k] = lane_order[j]
		lane_order[j] = tmp
	var i := 0
	for e in entrants:
		var r := Runner.new()
		r.name = e.name
		r.club = e.club
		r.is_player = e.get("is_player", false)
		r.rival = e.get("rival", {})
		r.lane = lane_order[i % lanes]
		i += 1
		r.speed = e.speed
		r.tactics = e.tactics
		# Race-day form: consistency narrows the spread, composure matters at big meets.
		var form := rng.randfn(0.0, 0.25 + (20.0 - float(e.consistency)) / 20.0 * 0.6)
		if big_meet:
			form += (float(e.composure) - 10.0) * 0.04
		if r.is_player:
			if player_fatigue > 25.0:
				form -= (player_fatigue - 25.0) / 75.0 * 1.5
			elif player_fatigue < 10.0:
				form += 0.1
		r.ability = float(e.ability) + form
		r.even_time = RacePerformance.time_for(r.ability, gender)
		var rs: Dictionary = e_cfg.reserve_share
		var share := clampf(float(rs.base) + float(rs.per_anaerobic) * float(e.anaerobic), float(rs.min), float(rs.max))
		r.dprime = DISTANCE * share
		r.dleft = r.dprime
		# The standing start costs ~1.5 s, so the cruising speed is set a little higher. cs_scale calibrates the
		# engine (drafting and race shapes) back onto the time table.
		r.cs = (DISTANCE - r.dprime) / (r.even_time - float(e_cfg.start_cost)) * float(e_cfg.cs_scale)
		var top := (6.4 + 0.17 * r.speed) if gender == "male" else (5.9 + 0.15 * r.speed)
		r.vmax = maxf(top, r.cs * 1.2)
		# Sprint speed hardly changes from day to day: the kick comes from the ability before the day's form.
		var base_time := RacePerformance.time_for(float(e.ability), gender)
		var base_v := DISTANCE / base_time * float(e_cfg.cs_scale)
		r.kick_v = minf(r.vmax * float(e_cfg.kick_top_vmax), base_v * (float(e_cfg.kick_vs_even)
				+ float(e_cfg.kick_per_speed) * (r.speed - float(e.ability))))
		# Race tactics: how well they feel their reserve and time their kick.
		var skill := clampf((r.tactics - 1.0) / 19.0, 0.0, 1.0)
		r.err = rng.randfn(0.0, lerpf(float(e_cfg.misjudge_sd.at_1), float(e_cfg.misjudge_sd.at_20), skill))
		var kick_sd := lerpf(float(e_cfg.kick_noise_sd.at_1), float(e_cfg.kick_noise_sd.at_20), skill)
		var dig := 0.0
		if r.is_player:
			# Kickers (big reserve) wait; grinders go long. The place comes from the plan (set_player_plan).
			var pk: Dictionary = e_cfg.player_kick
			r.kick_at = clampf(float(pk.base) + float(pk.per_anaerobic) * float(e.anaerobic) + rng.randfn(0.0, kick_sd),
					float(pk.min), float(pk.max))
		else:
			var types: Dictionary = Data.races.personalities
			r.personality = e.get("personality", "")
			if not types.has(r.personality):   # tools' made-up fields: rolled like the rival pool's
				r.personality = Rivals.personality_from(float(e.anaerobic), rng.randf())
			var p: Dictionary = types[r.personality]
			r.want = p.want
			r.kick_at = clampf(rng.randf_range(float(p.kick_at[0]), float(p.kick_at[1])) + rng.randfn(0.0, kick_sd),
					80.0, 450.0)
			dig = float(p.dig)
		var grit := float(e.get("determination", e.get("competitiveness", 10.0)))
		r.dig = clampf(dig + (grit - 10.0) * float(e_cfg.dig_per_point), 0.0, float(e_cfg.dig_max))
		r.lat = (r.lane - 1) * LANE_W
		r.d = 0.0
		r.lat_target = r.lat
		runners.append(r)
		if r.is_player:
			player = r


## The player's pre-race plan: "front" (lead), "pack" or "back": the place they run for.
func set_player_plan(plan: String) -> void:
	if player:
		player.want = "lead" if plan == "front" else plan


## Rolled when the race starts (after the player's plan is known): the race shape from the mix, moved
## towards fast when someone wants to lead and towards tactical when nobody does, and the field's even speed.
func _roll_shape() -> void:
	var cfg: Dictionary = Data.races.shapes
	var mix: Dictionary = cfg.mix.get(_mix, cfg.mix[cfg.default_mix]).duplicate()
	var shift := float(cfg.front_runner_shift)
	if runners.any(func(x): return x.want == "lead"):
		shift = minf(shift, float(mix.tactical))
		mix.tactical = float(mix.tactical) - shift
		mix.fast = float(mix.fast) + shift
	else:
		shift = minf(shift, float(mix.fast))
		mix.fast = float(mix.fast) - shift
		mix.tactical = float(mix.tactical) + shift
	var total := 0.0
	for k in mix:
		total += float(mix[k])
	var x := _rng.randf() * total
	shape = mix.keys().back()
	for k in mix:
		x -= float(mix[k])
		if x < 0.0:
			shape = k
			break
	var s: Dictionary = cfg[shape]
	lap1_pace = _rng.randf_range(float(s.lap1[0]), float(s.lap1[1]))
	lap2_pace = _rng.randf_range(float(s.lap2[0]), float(s.lap2[1]))
	# The field's even speed: the runner at pace_ref_quantile of the field (0 = the strongest).
	var speeds := []
	for r in runners:
		speeds.append((r.cs * (r.even_time - float(_eng.start_cost)) + r.dprime) / r.even_time)
	speeds.sort()
	speeds.reverse()
	ref_speed = speeds[clampi(roundi(float(cfg.pace_ref_quantile) * (speeds.size() - 1)), 0, speeds.size() - 1)]


## Runs until a decision is needed (detailed mode) or the race is over.
func run() -> void:
	while not finished and pending.is_empty():
		step()


func step() -> void:
	if shape == "":
		_roll_shape()
	time += DT
	var order := standings()
	_leader = null
	for r in order:
		if not r.done:
			_leader = r
			break
	for r in order:
		if r.done:
			continue
		_move(r, order)
	for r in runners:
		if not r.done and r.d >= DISTANCE:
			r.t = time - (r.d - DISTANCE) / maxf(r.v, 0.1)
			r.done = true
	finished = runners.all(func(x): return x.done)
	_commentate(order)
	if not finished and player and not player.done:
		_check_decisions(order)


## Runners ordered by position (finished ones by time).
func standings() -> Array[Runner]:
	var order: Array[Runner] = runners.duplicate()
	order.sort_custom(func(x, y):
		if x.done and y.done:
			return x.t < y.t
		if x.done != y.done:
			return x.done
		return x.d > y.d)
	return order


func position_of(r: Runner) -> int:
	return standings().find(r) + 1


func choose(option_id: String) -> void:
	var id: String = pending.get("id", "")
	pending = {}
	_apply_choice(player, id, option_id)


# --- Movement ---------------------------------------------------------------------------

func _move(r: Runner, order: Array[Runner]) -> void:
	var e := _eng
	var rem := DISTANCE - r.d
	var top := r.kick_v
	r.draft = _draft_of(r, order)
	r.drafting = r.draft > 0.0
	var front := _runner_in_front(r, order)          # nearest runner ahead in any line
	var gap_front := front.d - r.d if front else INF
	r.dropped = r != _leader and r.d >= break_line and gap_front > float(e.drop_gap)
	var wants_past := false

	if not r.kicking and rem <= r.kick_at:
		r.kicking = true
	var target: float
	if r.kicking:
		# Fastest speed the reserve they feel they have can hold to the line: rem / (rem - felt) times cs.
		var felt := _felt(r)
		if rem <= felt + 1.0:
			target = top
		else:
			target = minf(top, maxf(r.cs * rem / (rem - felt), r.cs))
	else:
		var pace := ref_speed * (lap1_pace if r.d < DISTANCE / 2.0 else lap2_pace)
		var follow: Runner = front if gap_front <= float(e.follow_range) else null
		var cap := _cap(r, float(e.draft) if follow else 0.0)
		if r.d < break_line:
			# In lanes: the race's pace, a little quicker for those who want the lead.
			target = minf(pace * float(e.place_speed[r.want]), cap)
		elif follow == null:
			# Leading: the race's pace. Detached: their own pace, closing in no faster than close_max.
			target = minf(pace if r == _leader else pace * float(e.close_max), cap)
		else:
			# Following: the runner ahead's speed, closing to follow_gap behind (or alongside in another line).
			var same_line := absf(follow.lat - r.lat) < 0.9
			var want_gap := float(e.follow_gap) if same_line else 0.0
			# Lead runners work to the front, pack runners up to pack_place (when they have the energy to spare).
			var moving_up: bool = r.want == "lead" or (r.want == "pack" and order.find(r) + 1 > int(e.pack_place))
			var to_front: bool = moving_up and r.d < float(e.lead_until) and cap >= follow.v * float(e.pass_speed)
			var past_fader: bool = follow.v < pace * float(e.pass_margin) and cap > follow.v * float(e.pass_speed)
			# Running wide on a bend costs distance: on (or just before) a bend, a runner alongside on the
			# outside drops in behind and moves to the inside.
			if not same_line and not to_front and not past_fader and r.lat > follow.lat \
					and (is_bend(r.d) or is_bend(r.d + float(e.tuck_ahead))):
				want_gap = float(e.tuck_gap)
				r.lat_target = _inside_target(r, order)
			target = clampf(follow.v + (gap_front - want_gap) * float(e.close_rate), follow.v * 0.9,
					follow.v * float(e.close_max))
			if to_front:
				target = follow.v * float(e.pass_speed)          # working to the front
				wants_past = true
			elif past_fader:
				target = minf(cap, maxf(pace, follow.v * float(e.pass_speed)))   # past a runner who is fading
				wants_past = true
			target = minf(target, cap)   # can't hold it: dropped
		target *= r.pace_factor

	if r.d >= break_line:
		var ahead := _runner_ahead(r, order)
		if ahead != null:
			var gap := ahead.d - r.d
			if gap < 2.0 and absf(ahead.lat - r.lat) < 0.9:
				wants_past = wants_past or r.kicking or target > ahead.v * 1.02
				if wants_past and _outside_clear(r, ahead.lat + 1.0, order):
					r.lat_target = ahead.lat + 1.0
				elif gap < 1.2:
					target = minf(target, ahead.v)   # boxed in or happy to sit
					if r == player and wants_past:
						_box_timer += DT
			elif gap > 3.0 and not r.kicking:
				r.lat_target = _inside_target(r, order)
		else:
			r.lat_target = _inside_target(r, order)

	if r.dleft <= 0.0:
		var tie: Dictionary = e.tie_up
		target = minf(target, r.cs * (float(tie.speed) - float(tie.extra) * clampf(-r.dleft / float(tie.over), 0.0, 1.0)))

	var acc: Dictionary = e.accel
	var up := float(acc.start) if r.d < float(acc.start_until) else float(acc.up)
	if r.v < target:
		r.v = minf(target, r.v + up * DT)
	else:
		r.v = maxf(target, r.v - float(acc.down) * DT)

	# Running behind someone costs `draft` of speed less; the leader pays full price.
	var cost := r.v * (1.0 - r.draft)
	if cost > r.cs:
		r.dleft -= (cost - r.cs) * DT
	else:
		r.dleft = minf(r.dprime, r.dleft + (r.cs - cost) * DT * float(e.recover))

	var progress := r.v * DT
	if indoor and is_bend(r.d):
		progress *= INDOOR_BEND_SPEED       # tight indoor bends slow everyone down
	if r.d < break_line:
		r.d += progress                     # in lanes: the stagger makes every lane equal
	else:
		r.lat = move_toward(r.lat, r.lat_target, 1.0 * DT)
		if is_bend(r.d):
			progress *= r1 / (r1 + r.lat)   # running wide on a bend costs distance
		r.d += progress
	if r.split_400 == 0.0 and r.d >= 400.0:
		r.split_400 = time


## The reserve the runner thinks they have (misjudged by `err`, GDD 4.3.1).
func _felt(r: Runner) -> float:
	return r.dleft + r.err * r.dprime


## The fastest speed the runner is willing to run now (before the kick): following at it leaves the reserve
## they want at their kick point (kick_need_per_100 per 100 m of kick, less by how deep they dig; dropped
## runners stop digging). `dr` = the drafting they expect. Never below own_floor x the speed that would empty
## their reserve at the line: a dropped runner falls back to their own pace, not to a jog.
func _cap(r: Runner, dr: float) -> float:
	var e := _eng
	var rem := DISTANCE - r.d
	var felt := _felt(r)
	var v_line := r.cs * rem / maxf(rem - maxf(felt, 0.0), 1.0)
	var to_kick := rem - r.kick_at
	var v := v_line
	if to_kick > 1.0:
		var need := float(e.kick_need_per_100) * r.kick_at / 100.0 * r.dprime * (1.0 - (0.0 if r.dropped else r.dig))
		# No point saving more than the kick can use at full speed.
		need = minf(need, r.kick_at * (1.0 - r.cs / r.kick_v))
		var avail := felt - need
		var v_hang := r.cs / (1.0 - clampf(avail / to_kick, 0.0, 0.5))
		v = maxf(v_hang, v_line * float(e.own_floor))
	return minf(v / (1.0 - dr), r.kick_v)


## Share of speed saved by running close behind someone (same line: full, diagonally behind: second_row;
## less on a bend). No drafting in lanes.
func _draft_of(r: Runner, order: Array[Runner]) -> float:
	if r.d < break_line:
		return 0.0
	var e := _eng
	var best := 0.0
	for o in order:
		if o == r or o.done:
			continue
		var gap := o.d - r.d
		if gap <= 0.0 or gap > float(e.draft_dist):
			continue
		var lat := absf(o.lat - r.lat)
		if lat < float(e.draft_lat):
			best = maxf(best, float(e.draft))
		elif lat < float(e.draft_lat_max):
			best = maxf(best, float(e.draft) * float(e.draft_second_row))
	if best > 0.0 and is_bend(r.d):
		best *= float(e.draft_bend)
	return best


## The nearest runner ahead in any line (still running).
func _runner_in_front(r: Runner, order: Array[Runner]) -> Runner:
	var best: Runner = null
	for o in order:
		if o == r or o.done or o.d <= r.d:
			continue
		if best == null or o.d < best.d:
			best = o
	return best


func _runner_ahead(r: Runner, order: Array[Runner]) -> Runner:
	var best: Runner = null
	for o in order:
		if o == r or o.done or o.d <= r.d:
			continue
		if absf(o.lat - r.lat) < 1.5 and (best == null or o.d < best.d):
			best = o
	return best


func _outside_clear(r: Runner, lat: float, order: Array[Runner]) -> bool:
	for o in order:
		if o != r and not o.done and absf(o.d - r.d) < 1.8 and absf(o.lat - lat) < 0.7:
			return false
	return true


## Back towards the rail unless someone is right there.
func _inside_target(r: Runner, order: Array[Runner]) -> float:
	var lat := 0.0
	while lat < r.lat and not _outside_clear(r, lat, order):
		lat += 1.0
	return minf(lat, r.lat)


func is_bend(d: float) -> bool:
	var p := fmod(d, lap)
	return p < bend or (p >= bend + straight and p < 2.0 * bend + straight)


# --- Decisions ----------------------------------------------------------------------------

func _check_decisions(order: Array[Runner]) -> void:
	var p := player
	var rem := DISTANCE - p.d
	if p.d >= break_line and not _asked.has("break"):
		_ask("break", "Break from the lanes",
				"The field cuts in to the inside lane. Where do you want to run?", [
			["lead", "Take the lead", "Control the pace from the front. Costs energy, but no traffic."],
			["shoulder", "Sit on the leader's shoulder", "Stay close in 2nd–3rd, ready to react."],
			["back", "Tuck in at the back", "Save energy behind everyone. Risk of getting boxed in later."],
		])
	elif p.d >= 400.0 and not _asked.has("bell"):
		var leader := order[0]
		var text := "%s The leader went through 400 m in %s. You: %s, %s." % ["Halfway!" if indoor else "Bell!",
				Calendar.format_time(leader.split_400), Calendar.format_time(p.split_400), _ordinal(position_of(p))]
		_ask("bell", "Halfway" if indoor else "The bell", text, [
			["push", "Push the pace", "Run the second lap harder. Good if you're strong, risky if not."],
			["hold", "Hold your position", "Keep doing what you're doing."],
			["ease", "Ease off a little", "Save energy for the kick."],
		])
	elif p.d >= 420.0 and rem > 230.0 and not p.kicking and not _asked.has("move"):
		for o in order:
			if o != p and o.kicking and absf(o.d - p.d) < 15.0:
				_ask("move", "A rival makes a move",
						"%s surges with %d m to go!" % [o.name, roundi(DISTANCE - o.d)], [
					["go", "Go with them", "Start your kick now and cover the move."],
					["wait", "Let them go", "Trust your own kick. They might pay for it later."],
				])
				break
	elif p.d >= 600.0 and not p.kicking and not _asked.has("kick"):
		_ask("kick", "200 metres to go", "You're %s. When do you go?" % _ordinal(position_of(p)), [
			["now", "Kick now", "A long sprint for home. Strong finishers love this."],
			["wait", "Wait for the home straight", "Kick with 100 m to go. Needs a fast finish and a clear path."],
		])
	elif p.d >= 700.0 and not _asked.has("straight") and position_of(p) > 1:
		var ahead := _runner_ahead(p, order)
		if ahead != null and ahead.d - p.d < 2.5:
			_ask("straight", "Home straight", "%s is right in front of you." % ahead.name, [
				["wide", "Swing wide and go round", "A clear path, but a few extra metres."],
				["inside", "Wait for a gap on the inside", "Shortest way, if a gap opens..."],
			])


func _ask(id: String, title: String, text: String, options: Array) -> void:
	_asked[id] = true
	var opts := []
	for o in options:
		opts.append({"id": o[0], "label": o[1], "detail": o[2]})
	var decision := {"id": id, "title": title, "text": text, "options": opts}
	if interactive:
		pending = decision
		decision_needed.emit(decision)
	else:
		_apply_choice(player, id, _auto_choice(id))


## What the athlete does on their own (quick mode): based on plan and race tactics.
func _auto_choice(id: String) -> String:
	var p := player
	var smart := p.tactics / 20.0
	match id:
		"break":
			return {"lead": "lead", "pack": "shoulder", "back": "back"}[p.want]
		"bell":
			return "hold"
		"move":
			return "go" if _rng.randf() < 0.5 + (0.3 if p.dleft > p.dprime * 0.5 else -0.3) * smart else "wait"
		"kick":
			return "now" if p.kick_at >= 200.0 else "wait"
		"straight":
			return "wide" if _rng.randf() < 0.4 + smart * 0.5 else "inside"
	return ""


func _apply_choice(p: Runner, id: String, option: String) -> void:
	match [id, option]:
		["break", "lead"]:
			p.want = "lead"
			_say("You go to the front.")
		["break", "shoulder"]:
			p.want = "pack"
			_say("You settle on the leader's shoulder.")
		["break", "back"]:
			p.want = "back"
			_say("You tuck in at the back of the field.")
		["bell", "push"]:
			p.pace_factor = 1.03
			_say("You push on down the back straight.")
		["bell", "hold"]:
			p.pace_factor = 1.0
		["bell", "ease"]:
			p.pace_factor = 0.97
			_say("You ease off and save something for the finish.")
		["move", "go"]:
			p.kicking = true
			_say("You go with the move!")
		["move", "wait"]:
			_say("You let them go and stay patient.")
		["kick", "now"]:
			p.kicking = true
			_say("You kick with 200 to go!")
		["kick", "wait"]:
			p.kick_at = 100.0
		["straight", "wide"]:
			var ahead := _runner_ahead(p, standings())
			if ahead:
				p.lat_target = ahead.lat + 1.2
			p.kicking = true
			_say("You swing wide into lane 2 and go for it!")
		["straight", "inside"]:
			p.kicking = true
			var ahead := _runner_ahead(p, standings())
			if ahead and _rng.randf() < 0.35 + p.tactics / 40.0:
				ahead.lat_target = ahead.lat + 1.0
				_say("A gap opens on the inside!")
			else:
				_say("No gap... you're boxed in.")


# --- Commentary ---------------------------------------------------------------------------

func _commentate(order: Array[Runner]) -> void:
	var leader := order[0]
	if not _announced.has("break") and leader.d >= break_line + 5.0:
		_announced["break"] = true
		_say("%s leads at the break." % leader.name)
	if not _announced.has("400") and leader.d >= 400.0:
		_announced["400"] = true
		_say("%s %s: %s." % [leader.name, "at halfway" if indoor else "at the bell", Calendar.format_time(leader.split_400)])
	for r in order:
		if r.kicking and not _announced.has("kick_" + r.name) and not r.done:
			_announced["kick_" + r.name] = true
			if r.is_player or r == leader or position_of(r) <= 3:
				if not r.is_player:
					_say("%s kicks with %d m to go!" % [r.name, roundi(DISTANCE - r.d)])
	if finished and not _announced.has("finish"):
		_announced["finish"] = true
		var winner := standings()[0]
		_say("%s wins in %s!" % [winner.name, Calendar.format_time(winner.t)])


func _say(text: String) -> void:
	log_lines.append(text)
	commentary.emit(text)


static func _ordinal(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	return "%d%s" % [n, {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")]


## Final results: [{name, club, time, is_player, rival}], fastest first.
func results() -> Array:
	var out := []
	for r in standings():
		out.append({"name": r.name, "club": r.club, "time": snappedf(r.t, 0.01), "is_player": r.is_player,
				"rival": r.rival, "split_400": r.split_400})
	return out
