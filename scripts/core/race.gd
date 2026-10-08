class_name Race
extends RefCounted
## One 800 m race, simulated in small time steps on a real track: outdoor 400 m (8 lanes) or indoor 200 m (6 lanes).
##
## Each runner has a sustainable speed (cs) and an anaerobic reserve (dprime, in metres): running faster than
## cs drains the reserve, running close behind someone (drafting) costs less, and an empty reserve means tying
## up. Pack racing (GDD 4.3.1, step R1): the race has a shape (fast / honest / tactical) and the leader runs its
## pace; everyone else follows the runner ahead while the reserve they *feel* they will have at their kick point
## is enough, and is dropped when it isn't. The plan is the place a runner wants (lead / pack / back).
## Step R2: moves (surges) that the runners close by cover or let go, the kick chain (a kick near the front sets
## off answers), boxed in with three ways out (wait / ease and step out / push through), contact, stumbles and
## falls, the obstruction DQ, DNF, heats easing in, and the race's event list for the commentary (`events`).
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
## Heats: the automatic qualifying places (0 = none). Runners safely in one ease off near the line.
var auto_places := 0
## What happened, for the commentary (R4) and the race story: {type, t, who, i (runner index), player, d,
## pos, gap (metres behind the leader)} + per type: start {shape, pace}, break_leader, pace {mark, split, vs_even
## (% faster than the field's even pace), group (runners within 5 m of the leader), spread (leader to last, m)},
## pack {mark, group, spread}, move {pct, length}, cover / let_go {of}, dropped {behind}, boxed {way},
## escape {way, seconds}, gap_opens, contact {with, where}, stumble {metres}, fall {where}, brought_down {by},
## dnf, dq {reason}, spiked {by}, lead_change {from}, kick {to_go, answer_to}, kick_dying {to_go}, ease,
## close_finish / photo_finish {with, place, margin}, finish {time}.
var events: Array = []
var print_events := false         # dev: print each event to the Output panel (the race screen, debug builds)

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
var _last_leader: Runner          # for lead_change events
var _lead_since := 0.0
var _card_mover: Runner           # whose move the "A rival makes a move" card is about
const MARKS := [200, 300, 400, 500, 600]   # pace calls (200 / 400 / 600) and pack shape (300 / 500)
var _next_mark := 0
var _order: Array[Runner] = []    # standings() keeps its order here
## Neighbour searches look this many metres beyond their range in the step's order (runners move < 1 m a step).
const SLACK := 2.0
# Engine numbers read in every step, cached at setup (data/races.json engine).
var _p := 0.0                     # drain_power
var _k_need := 0.0                # kick_need_per_100
var _dig_max := 0.0
var _own_floor := 0.0
var _surge_max := 0
var _surge_after := 0.0


class Runner:
	var name := ""
	var club := ""
	var is_player := false
	var rival: Dictionary = {}    # the rival pool entry, for PBs
	var index := 0                # place in Race.runners
	var lane := 1
	var ability := 0.0            # race-day ability after form
	var speed := 0.0
	var tactics := 10.0
	var skill := 0.5              # race tactics as 0..1: how well they judge moves, kicks and boxes
	var grit := 10.0              # competitiveness (rivals) / determination (player)
	var even_time := 0.0          # time for an even-paced race at this ability
	var even_v := 0.0             # 800 m / even_time
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
	var scripted: Dictionary = {} # dev tools: a scripted race (tools/race_shape.gd duel rows)
	# Moves (R2)
	var surge_left := 0.0         # metres of their surge still to run
	var surge_v := 0.0
	var surges := 0
	var covering: Runner = null   # the surger they go with
	var hold_left := 0.0          # letting a move go: metres more at no more than hold_v
	var hold_v := 0.0
	var decided := {}             # "move <i> <n>" / "kick <i>" -> already decided about that move or kick
	var kick_free := true         # answers kicks (off when the player chose to wait for the home straight)
	# Boxed in (R2)
	var boxed := false
	var box_way := ""             # wait / ease / push while a box lasts
	var box_time := 0.0
	var push_left := 0.0          # pushing through: seconds of squeezing out regardless
	# Contact, stumbles and falls (R2)
	var down_left := 0.0          # on the ground after a fall: seconds left
	var getting_up := false
	var contacts := 0
	var stumbles := 0
	var falls := 0
	var spiked := false
	var status := ""              # "" finished, "dnf" did not finish, "dq" disqualified
	var out_weeks := 0            # a rival hurt in a fall: weeks out (Game._record, when the health model is on)
	# Heats (R2)
	var ease_from := 0.0          # metres to go from which a runner safely in an automatic place eases off
	var easing := false
	var was_dropped := false
	var kick_died := false
	var said_kick := false        # (the old commentary line "X kicks!" said)
	var sk := 0.0                 # sort key for standings()
	var oi := 0                   # place in the last standings() (0 = first)


## `entrants`: Dictionaries with name, club, ability, speed, anaerobic, tactics, consistency, composure
## (+ is_player, rival, personality, competitiveness / determination, and for dev tools `script`: a scripted
## race, see _apply_script). `big_meet` makes composure matter. `player_fatigue` 0–100. `mix` = the race-shape
## mix (data/races.json shapes.mix: local / district / heat / final; "" = the default).
func setup(entrants: Array, gender: String, big_meet: bool, player_fatigue: float, rng: RandomNumberGenerator,
		indoor_track := false, mix := "") -> void:
	_rng = rng
	_eng = Data.races.engine
	_mix = mix
	_p = float(_eng.drain_power)
	_k_need = float(_eng.kick_need_per_100)
	_dig_max = float(_eng.dig_max)
	_own_floor = float(_eng.own_floor)
	_surge_max = int(_eng.moves.max_per_runner)
	_surge_after = float(_eng.moves.after_break)
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
		r.index = i
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
		r.even_v = DISTANCE / r.even_time
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
		r.skill = clampf((r.tactics - 1.0) / 19.0, 0.0, 1.0)
		r.err = rng.randfn(0.0, lerpf(float(e_cfg.misjudge_sd.at_1), float(e_cfg.misjudge_sd.at_20), r.skill))
		var kick_sd := lerpf(float(e_cfg.kick_noise_sd.at_1), float(e_cfg.kick_noise_sd.at_20), r.skill)
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
		r.grit = float(e.get("determination", e.get("competitiveness", 10.0)))
		r.dig = clampf(dig + (r.grit - 10.0) * float(e_cfg.dig_per_point), 0.0, float(e_cfg.dig_max))
		var ease: Dictionary = e_cfg.heat_ease
		r.ease_from = rng.randf_range(float(ease.from[0]), float(ease.from[1]))
		r.lat = (r.lane - 1) * LANE_W
		r.d = 0.0
		r.lat_target = r.lat
		_apply_script(r, e.get("script", {}))
		runners.append(r)
		if r.is_player:
			player = r


## Dev tools (tools/race_shape.gd duel rows) can script a runner's race: want (lead / pack / back), kick_at
## (metres to go), lead_pace (the pace they lead at until 600 m, as a share of their own even speed),
## box_way (wait / ease / push), cover / answer (chance to cover a move / answer a kick), no_surge, and
## perfect (feels their reserve exactly and decides like race tactics 20).
func _apply_script(r: Runner, s: Dictionary) -> void:
	r.scripted = s
	if s.has("want"):
		r.want = s.want
	if s.has("kick_at"):
		r.kick_at = float(s.kick_at)
	if s.get("perfect", false):
		r.err = 0.0
		r.skill = 1.0


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
	_event("start", null, {"shape": shape, "pace": lap1_pace})


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
		if not r.done and r.down_left <= 0.0:
			_leader = r
			break
	for r in order:
		if r.done:
			continue
		_move(r, order)
	_contacts(order)
	for r in runners:
		if not r.done and r.d >= DISTANCE:
			r.t = time - (r.d - DISTANCE) / maxf(r.v, 0.1)
			r.done = true
	finished = runners.all(func(x): return x.done)
	_race_events(order)
	_commentate(order)
	if not finished and player and not player.done:
		_check_decisions(order)


## Runners ordered by position (finished ones by time; those who did not finish last). The order is kept
## between calls and fixed up by insertion sort (it hardly changes from one step to the next).
func standings() -> Array[Runner]:
	if _order.size() != runners.size():
		_order = runners.duplicate()
	for r in _order:
		if r.status == "dnf":
			r.sk = -1.0e9 + r.d
		elif r.done:
			r.sk = 1.0e9 - r.t
		else:
			r.sk = r.d
	for i in range(1, _order.size()):
		var x: Runner = _order[i]
		var j := i - 1
		while j >= 0 and _order[j].sk < x.sk:
			_order[j + 1] = _order[j]
			j -= 1
		_order[j + 1] = x
	for i in _order.size():
		_order[i].oi = i
	return _order.duplicate()


## r's place in `order` (cached by standings(); found the slow way for another order).
func _idx(r: Runner, order: Array[Runner]) -> int:
	return r.oi if r.oi < order.size() and order[r.oi] == r else order.find(r)


func position_of(r: Runner) -> int:
	return standings().find(r) + 1


func choose(option_id: String) -> void:
	var id: String = pending.get("id", "")
	pending = {}
	_apply_choice(player, id, option_id)


# --- Movement ---------------------------------------------------------------------------

func _move(r: Runner, order: Array[Runner]) -> void:
	var e := _eng
	if r.down_left > 0.0:
		# On the ground after a fall: no running, no recovery.
		r.down_left -= DT
		r.v = 0.0
		if r.down_left <= 0.0:
			r.getting_up = true
		return
	var rem := DISTANCE - r.d
	var top := r.kick_v
	r.draft = _draft_of(r, order)
	r.drafting = r.draft > 0.0
	var front := _runner_in_front(r, order)          # nearest runner ahead in any line
	var gap_front := front.d - r.d if front else INF
	r.dropped = r != _leader and r.d >= break_line and gap_front > float(e.drop_gap)
	if r.dropped and not r.was_dropped and r.d > break_line + 50.0 and not r.getting_up and front != null:
		r.was_dropped = true
		_event("dropped", r, {"behind": front.name}, order)
	var wants_past := false
	var pace := _pace(r)

	if not r.kicking and rem <= r.kick_at:
		_start_kick(r, order, null)
	var target: float
	if r.kicking:
		# Fastest speed the reserve they feel they have can hold to the line: rem / (rem - felt) times cs.
		target = _kick_speed(r)
		if r.dleft <= 0.0 and not r.kick_died and rem > float(e.kick_dying_to_go):
			r.kick_died = true
			_event("kick_dying", r, {"to_go": roundi(rem)}, order)
	else:
		var follow: Runner = front if gap_front <= float(e.follow_range) else null
		var cap := _cap(r, float(e.draft) if follow else 0.0)
		if r.d < break_line:
			# In lanes: the race's pace, a little quicker for those who want the lead.
			target = minf(pace * float(e.place_speed[r.want]), cap)
		elif follow == null:
			# Leading: the race's pace. Detached: their own pace, closing in no faster than close_max.
			target = minf(pace if r == _leader else pace * float(e.close_max), cap)
			if r == _leader and r.scripted.has("lead_pace") and r.d < float(e.lead_until):
				target = pace   # a scripted bad race: too fast, whatever it costs
		else:
			# Following: the runner ahead's speed, closing to follow_gap behind (or alongside in another line).
			var same_line := absf(follow.lat - r.lat) < 0.9
			var want_gap := float(e.follow_gap) if same_line else 0.0
			# Lead runners work to the front, pack runners up to pack_place (when they have the energy to spare).
			var moving_up: bool = r.want == "lead" or (r.want == "pack" and _idx(r, order) + 1 > int(e.pack_place))
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
		# Moves (R2): a surge of their own, going with someone's surge, or letting it go.
		if r.d >= break_line:
			_maybe_surge(r, order, pace)
		if r.surge_left > 0.0:
			target = minf(r.surge_v, top)
			wants_past = true
			r.surge_left -= r.v * DT
		elif r.covering != null:
			var s := r.covering
			if s.done or s.down_left > 0.0 or (s.surge_left <= 0.0 and not s.kicking) or s.d < r.d - 2.0:
				r.covering = null
			else:
				var mv: Dictionary = e.moves
				var gap_s := s.d - r.d
				var go := clampf(s.v + (gap_s - float(e.follow_gap)) * float(e.close_rate), s.v * 0.9,
						s.v * float(mv.cover_max))
				target = minf(maxf(target, go), _cap(r, float(e.draft), float(mv.cover_dig)))
				wants_past = wants_past or (front != null and front != s)
		if r.hold_left > 0.0:
			target = minf(target, maxf(r.hold_v, pace))
			r.hold_left -= r.v * DT
		target *= r.pace_factor

	if r.d >= break_line:
		target = _traffic(r, order, target, wants_past, rem)

	# Heats (R2): safely in an automatic qualifying place near the line, they ease off.
	if auto_places > 0 and rem < r.ease_from and order.size() > auto_places:
		var pos := _idx(r, order) + 1
		var chaser: Runner = order[auto_places]
		if pos <= auto_places and r.d - chaser.d >= float(e.heat_ease.margin):
			target *= float(e.heat_ease.speed)
			if not r.easing:
				r.easing = true
				_event("ease", r, {}, order)

	if r.dleft <= 0.0:
		var tie: Dictionary = e.tie_up
		target = minf(target, r.cs * (float(tie.speed) - float(tie.extra) * clampf(-r.dleft / float(tie.over), 0.0, 1.0)))

	var acc: Dictionary = e.accel
	var up := float(acc.start) if r.d < float(acc.start_until) or r.getting_up else float(acc.up)
	if r.v < target:
		r.v = minf(target, r.v + up * DT)
	else:
		r.v = maxf(target, r.v - float(acc.down) * DT)
	if r.getting_up and r.v >= target * 0.95:
		r.getting_up = false

	# Running behind someone costs `draft` of speed less; the leader pays full price.
	var cost := r.v * (1.0 - r.draft)
	if cost > r.cs:
		r.dleft -= _drain(r, cost) * DT
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


## The race's pace for this runner now: the shape's lap pace (a scripted runner may lead at their own:
## lead_pace x their own even speed until lead_until).
func _pace(r: Runner) -> float:
	if r.scripted.has("lead_pace") and r.d < float(_eng.lead_until):
		return DISTANCE / r.even_time * float(r.scripted.lead_pace)
	return ref_speed * (lap1_pace if r.d < DISTANCE / 2.0 else lap2_pace)


## The fastest speed the reserve they feel they have can hold to the line (their kick).
func _kick_speed(r: Runner) -> float:
	var rem := DISTANCE - r.d
	var felt := _felt(r)
	if rem <= felt + 1.0:
		return r.kick_v
	return minf(r.kick_v, _hold_speed(r, rem, felt))


## Runner ahead in the same line: following, passing, boxed in (GDD 4.3.1). Returns the target speed.
func _traffic(r: Runner, order: Array[Runner], target: float, wants_past: bool, rem: float) -> float:
	var b: Dictionary = _eng.box
	if r.push_left > 0.0:
		r.push_left -= DT
	var ahead := _runner_ahead(r, order)
	var in_box := false
	if ahead != null:
		var gap := ahead.d - r.d
		# (a box lasts while they ease back a little to step out: box.hold metres)
		if (gap < 2.0 or (r.box_way != "" and gap < float(b.hold))) and absf(ahead.lat - r.lat) < 0.9:
			wants_past = wants_past or r.kicking or target > ahead.v * 1.02
			var out_lat := ahead.lat + 1.0
			if wants_past and (r.push_left > 0.0 or _outside_clear(r, out_lat, order)):
				r.lat_target = out_lat
				in_box = r.box_way != ""   # out of the box once they are out of that line
			elif wants_past and (r.box_way != "" or (gap < float(b.gap) and _urgent(r, rem))):
				in_box = true
				target = _boxed(r, ahead, out_lat, target, order)
			elif gap < 1.2:
				target = minf(target, ahead.v)   # happy to sit (or not in a hurry yet)
				if r == player and wants_past:
					_box_timer += DT
		elif gap > 3.0 and not r.kicking:
			r.lat_target = _inside_target(r, order)
	else:
		r.lat_target = _inside_target(r, order)
	r.boxed = in_box
	if not in_box and r.box_way != "":
		_event("escape", r, {"way": r.box_way, "seconds": snappedf(r.box_time, 0.1)}, order)
		r.box_way = ""
	return target


## Boxed in counts when it matters: kicking, in a move, or in the last box.urgent_to_go metres.
func _urgent(r: Runner, rem: float) -> bool:
	return r.kicking or r.surge_left > 0.0 or r.covering != null or rem < float(_eng.box.urgent_to_go)


## Boxed in: no faster than the runner ahead, and a way out: wait for a gap, ease and step out, push through.
func _boxed(r: Runner, ahead: Runner, out_lat: float, target: float, order: Array[Runner]) -> float:
	var b: Dictionary = _eng.box
	if r.box_way == "":
		r.box_way = _box_way(r)
		r.box_time = 0.0
		_event("boxed", r, {"way": r.box_way}, order)
	r.box_time += DT
	var blocker := _blocker(r, out_lat, order)
	match r.box_way:
		"wait":
			target = minf(target, ahead.v)
			var rate := lerpf(float(b.gap_rate.at_1), float(b.gap_rate.at_20), r.skill)
			if blocker != null and _rng.randf() < rate * DT:
				# The runner on their shoulder drifts wide (or moves on): a gap opens.
				blocker.lat_target = maxf(blocker.lat_target, blocker.lat + 1.0)
				_event("gap_opens", r, {"by": blocker.name}, order)
		"ease":
			target = minf(target, ahead.v * float(b.ease_speed))
		"push":
			target = minf(target, ahead.v)
			if r.push_left <= 0.0:
				r.push_left = float(b.push_time)
				var other := blocker if blocker != null else ahead
				other.lat_target = maxf(other.lat_target, out_lat + 0.6)
				if _rng.randf() < float(b.push_contact):
					_contact(r, other, "push", order)
				if r.status == "" and _rng.randf() < float(b.push_dq):
					r.status = "dq"
					_event("dq", r, {"reason": "obstruction"}, order)
	return target


## How a runner gets out of a box: weights by time left, race tactics and grit (data races.json engine.box).
func _box_way(r: Runner) -> String:
	if r.scripted.has("box_way"):
		return r.scripted.box_way
	var b: Dictionary = _eng.box
	var rem := DISTANCE - r.d
	var w := {
		"wait": float(b.wait) * clampf(rem / float(b.wait_to_go), 0.2, 2.0) * (1.0 + r.skill),
		"ease": float(b.ease) + float(b.ease_skill) * r.skill,
		"push": (float(b.push) + float(b.push_grit) * maxf(0.0, r.grit - 10.0)) * (float(b.push_late) if rem < float(b.late) else 1.0),
	}
	return _pick(w)


## The runner alongside on the outside that blocks the way out, or null.
func _blocker(r: Runner, lat: float, order: Array[Runner]) -> Runner:
	return _at(r, lat, order)


## A weighted pick from {id: weight}.
func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var x := _rng.randf() * total
	for k in weights:
		x -= float(weights[k])
		if x < 0.0:
			return k
	return weights.keys().back()


# --- Moves and kicks (R2) -----------------------------------------------------------------

## A runner may surge (+4–8 % for 50–150 m) at any point after the break: chance per 100 m by personality
## (Surgers mostly in their window), race shape and place; only when they feel they can afford it.
func _maybe_surge(r: Runner, order: Array[Runner], pace: float) -> void:
	if r.is_player or r.kicking or r.surge_left > 0.0 or r.covering != null or r.hold_left > 0.0 or r.dropped \
			or r.getting_up or r.surges >= _surge_max or r.d < break_line + _surge_after \
			or r.scripted.get("no_surge", false):
		return
	var m: Dictionary = _eng.moves
	var rate := float(m.rate_per_100.get(r.personality, 0.0))
	var sw: Dictionary = m.surger
	if r.personality == "surger" and r.d >= float(sw.from) and r.d <= float(sw.to):
		rate = float(sw.rate_per_100)
	rate *= float(m.shape_mult.get(shape, 1.0))
	if r == _leader:
		rate *= float(m.leader_mult)
	elif _leader != null and _leader.d - r.d > float(m.front_group):
		rate *= float(m.behind_mult)
	if _rng.randf() >= rate * r.v * DT / 100.0:
		return
	var length := _rng.randf_range(float(m.length[0]), float(m.length[1]))
	var mult := _rng.randf_range(float(m.speed[0]), float(m.speed[1]))
	var v_s := minf(maxf(r.v, pace) * mult, r.kick_v)
	if _spare(r) < length * _drain(r, v_s) / v_s:
		return   # they don't feel they have it in them
	r.surge_left = length
	r.surge_v = v_s
	r.surges += 1
	r.hold_left = 0.0
	_event("move", r, {"pct": roundi((mult - 1.0) * 100.0), "length": roundi(length)}, order)
	_react_to_move(r, order)


## The runners close to a move (just ahead of the surger or up to react_range behind) cover it or let it go.
func _react_to_move(s: Runner, order: Array[Runner]) -> void:
	var m: Dictionary = _eng.moves
	var key := "move %d %d" % [s.index, s.surges]
	for o in order:
		if o == s or o.done or o.down_left > 0.0 or o.kicking or o.decided.has(key):
			continue
		var gap := s.d - o.d
		if gap < -2.0 or gap > float(m.react_range):
			continue
		if o == player and _move_card_coming(o):
			continue   # the "A rival makes a move" card decides
		o.decided[key] = true
		if _rng.randf() < _cover_chance(o, s):
			_cover(o, s, order)
		else:
			_let_go(o, s, order)


func _cover(o: Runner, s: Runner, order: Array[Runner]) -> void:
	o.covering = s
	o.hold_left = 0.0
	_event("cover", o, {"of": s.name}, order)


func _let_go(o: Runner, s: Runner, order: Array[Runner]) -> void:
	o.covering = null
	o.hold_left = maxf(s.surge_left, 0.0) + float(_eng.moves.let_go_after)
	o.hold_v = o.v
	_event("let_go", o, {"of": s.name}, order)


## Cover or let go: personality, then race tactics (a smart runner covers when they can afford it).
func _cover_chance(o: Runner, s: Runner) -> float:
	if o.scripted.has("cover"):
		return float(o.scripted.cover)
	var m: Dictionary = _eng.moves
	var base := float(m.cover.get("player" if o.is_player else o.personality, 0.5))
	var cost := maxf(s.surge_left, 0.0) * _drain(o, s.surge_v * (1.0 - float(_eng.draft))) / maxf(s.surge_v, 0.1)
	var afford := _spare(o) >= cost
	return lerpf(base, float(m.cover_smart[1 if afford else 0]), o.skill)


func _start_kick(r: Runner, order: Array[Runner], answer_to: Runner) -> void:
	r.kicking = true
	r.surge_left = 0.0
	r.covering = null
	r.hold_left = 0.0
	_event("kick", r, {"to_go": roundi(DISTANCE - r.d), "answer_to": answer_to.name if answer_to else ""}, order)
	if _near_front(r, order):
		_react_to_kick(r, order)


## In the first chain.front_pos places or within chain.front_m metres of the leader.
func _near_front(r: Runner, order: Array[Runner]) -> bool:
	var c: Dictionary = _eng.chain
	return _idx(r, order) + 1 <= int(c.front_pos) or (_leader != null and _leader.d - r.d <= float(c.front_m))


## The kick chain: runners close to a kick near the front answer it or wait. Answering = going with the
## kicker (sitting on them, digging deeper), or their own kick right away when they are near their own kick
## point anyway. Those who go with the kicker kick at their own point; an answer near the front sets off more.
func _react_to_kick(k: Runner, order: Array[Runner], origin: Runner = null) -> void:
	var c: Dictionary = _eng.chain
	var key := "kick %d" % k.index
	var v_k := _kick_speed(k)
	var from := origin if origin != null else k
	for o in order:
		if o == k or o == from or o.done or o.down_left > 0.0 or o.kicking or not o.kick_free or o.decided.has(key):
			continue
		var gap := from.d - o.d
		if gap < -float(c.ahead) or gap > float(c.answer_range):
			continue
		o.decided[key] = true
		if _rng.randf() >= _answer_chance(o, v_k):
			continue
		if DISTANCE - o.d <= o.kick_at * float(c.kick_now_share):
			_start_kick(o, order, k)
		elif o.covering != k:
			o.covering = k
			o.hold_left = 0.0
			_event("cover", o, {"of": k.name, "kick": true}, order)
			if _near_front(o, order):
				_react_to_kick(k, order, o)   # the ones behind them see it too


## Answer a kick: personality (less when it comes long before their own kick point), then race tactics
## (a smart runner answers when they could hold the kicker's speed to the line).
func _answer_chance(o: Runner, v_k: float) -> float:
	if o.scripted.has("answer"):
		return float(o.scripted.answer)
	var c: Dictionary = _eng.chain
	var rem := DISTANCE - o.d
	var base := float(c.answer.get("player" if o.is_player else o.personality, 0.5))
	if rem > o.kick_at:
		base *= float(c.early)
	var hold := _hold_speed(o, rem, maxf(_felt(o), 0.0))
	var can := minf(hold, o.kick_v) >= v_k * float(c.can_share)
	return lerpf(base, float(c.smart[1 if can else 0]), o.skill)


## The "A rival makes a move" card will ask the player about this move (detailed and quick mode alike).
func _move_card_coming(p: Runner) -> bool:
	return not _asked.has("move") and p.d >= 420.0 and DISTANCE - p.d > 230.0 and not p.kicking


# --- Contact, stumbles and falls (R2) --------------------------------------------------------

## Where paths cross at close range (one runner on another's heels: cutting in at the break, swinging out,
## a bunched bend), contact may happen. Front running is safest: nobody is on anyone's heels there.
func _contacts(order: Array[Runner]) -> void:
	var c: Dictionary = _eng.contact
	var along := float(c.along)
	var lat_max := float(c.lat)
	for i in order.size():
		var r: Runner = order[i]
		if r.done or r.down_left > 0.0 or r.d < break_line:
			continue
		for k in range(i - 1, -1, -1):
			var o: Runner = order[k]
			var gap := o.d - r.d
			if gap > along + SLACK:
				break
			if o.done or o.down_left > 0.0 or gap <= 0.0 or gap > along or absf(o.lat - r.lat) > lat_max:
				continue
			var swinging := absf(r.lat - r.lat_target) > 0.05 or absf(o.lat - o.lat_target) > 0.05
			var where := "straight"
			if r.d < break_line + float(c.break_zone) and swinging:
				where = "break"
			elif swinging:
				where = "swing"
			elif is_bend(r.d):
				where = "bend"
			if _rng.randf() < float(c.rate[where]) * DT:
				_contact(r, o, where, order)
			break


## A contact between `a` (behind, or the one pushing) and `b`: mostly nothing, sometimes a stumble, rarely a
## fall; sometimes someone gets spiked.
func _contact(a: Runner, b: Runner, where: String, order: Array[Runner]) -> void:
	var c: Dictionary = _eng.contact
	a.contacts += 1
	b.contacts += 1
	_event("contact", a, {"with": b.name, "where": where}, order)
	if _rng.randf() < float(c.spiked):
		b.spiked = true
		_event("spiked", b, {"by": a.name}, order)
	var victim := a if _rng.randf() < float(c.victim_behind) else b
	var x := _rng.randf()
	if x < float(c.fall):
		_fall(victim, where, null, order)
	elif x < float(c.fall) + float(c.stumble):
		_stumble(victim, order)


func _stumble(r: Runner, order: Array[Runner]) -> void:
	var c: Dictionary = _eng.contact
	var metres := _rng.randf_range(float(c.stumble_m[0]), float(c.stumble_m[1]))
	# Losing dv and getting back up to speed at accel.up costs dv² / (2 up) metres.
	var dv := sqrt(2.0 * float(_eng.accel.up) * metres)
	r.v = maxf(0.0, r.v - dv)
	r.dleft -= _rng.randf_range(float(c.stumble_reserve[0]), float(c.stumble_reserve[1]))
	r.stumbles += 1
	_event("stumble", r, {"metres": snappedf(metres, 0.1)}, order)


## Down for a few seconds (rarely out of the race); the runner right behind may be brought down too. A rival
## may be hurt (out_weeks, applied after the race); the player's injury is rolled by the health model.
func _fall(r: Runner, where: String, by: Runner, order: Array[Runner]) -> void:
	var c: Dictionary = _eng.contact
	r.falls += 1
	r.v = 0.0
	r.down_left = _rng.randf_range(float(c.fall_down[0]), float(c.fall_down[1]))
	r.dleft -= float(c.fall_reserve)
	r.surge_left = 0.0
	r.covering = null
	r.hold_left = 0.0
	r.box_way = ""
	r.boxed = false
	if by != null:
		_event("brought_down", r, {"by": by.name}, order)
	else:
		_event("fall", r, {"where": where}, order)
	var dnf := _rng.randf() < float(c.dnf)
	if not r.is_player:
		var out: Dictionary = c.rival_out
		if _rng.randf() < float(out.dnf_chance if dnf else out.chance):
			r.out_weeks = maxi(r.out_weeks, _rng.randi_range(int(out.weeks[0]), int(out.weeks[1])))
	if dnf:
		r.down_left = 0.0
		r.done = true
		r.status = "dnf"
		_event("dnf", r, {}, order)
	if by == null:
		var behind := _runner_behind(r, float(c.brought_along))
		if behind != null and _rng.randf() < float(c.brought_down):
			_fall(behind, where, r, order)


## The nearest runner right behind in the same line (within `along` metres), or null.
func _runner_behind(r: Runner, along: float) -> Runner:
	var best: Runner = null
	for o in runners:
		if o == r or o.done or o.down_left > 0.0:
			continue
		var gap := r.d - o.d
		if gap > 0.0 and gap <= along and absf(o.lat - r.lat) < 0.9 and (best == null or o.d > best.d):
			best = o
	return best


# --- Energy -------------------------------------------------------------------------------

## The reserve the runner thinks they have (misjudged by `err`, GDD 4.3.1).
func _felt(r: Runner) -> float:
	return r.dleft + r.err * r.dprime


## Reserve used per second at cost speed u (above cs): (u - cs) x (u / their even speed)^drain_power. At their
## even pace it is the plain (u - cs); above it the reserve goes faster (a too-fast start or a long sprint
## costs more than it gives back later), below it slower (a tactical first lap saves real energy for the kick).
func _drain(r: Runner, u: float) -> float:
	if u <= r.cs:
		return 0.0
	if _p == 3.0:
		var x := u / r.even_v
		return (u - r.cs) * x * x * x
	return (u - r.cs) * (1.0 if _p == 0.0 else pow(u / r.even_v, _p))


static func _cbrt(x: float) -> float:
	return pow(x, 1.0 / 3.0) if x >= 0.0 else -pow(-x, 1.0 / 3.0)


## The steady cost speed at which `budget` metres of reserve last exactly `dist` metres (at least cs).
func _hold_speed(r: Runner, dist: float, budget: float) -> float:
	if budget <= 0.0:
		return r.cs
	var p := _p
	if p == 0.0 or budget >= dist:
		return r.cs * dist / maxf(dist - budget, 1.0)
	# (u - cs) u^(p-1) = k with k = budget ve^p / dist
	var k := budget * pow(r.even_v, p) / dist
	if p == 2.0:
		return (r.cs + sqrt(r.cs * r.cs + 4.0 * k)) * 0.5
	if p == 3.0:
		# u³ - cs u² - k = 0: with u = t + cs/3, t³ + a t + b = 0 has one real root (Cardano).
		var c := r.cs
		var a := -c * c / 3.0
		var b := -2.0 * c * c * c / 27.0 - k
		var s := sqrt(b * b / 4.0 + a * a * a / 27.0)
		return _cbrt(-b / 2.0 + s) + _cbrt(-b / 2.0 - s) + c / 3.0
	var u := maxf(r.cs * dist / (dist - budget), r.cs * 1.001)   # Newton from the linear answer
	for i in 6:
		var f := (u - r.cs) * pow(u, p - 1.0) - k
		var df := pow(u, p - 1.0) + (u - r.cs) * (p - 1.0) * pow(u, p - 2.0)
		u = maxf(u - f / df, r.cs * 1.0001)
	return u


## The reserve they want to keep for their kick (kick_need_per_100 per 100 m of kick, less by how deep they
## dig; dropped runners stop digging), never more than the kick can use at full speed.
func _need(r: Runner, extra_dig := 0.0) -> float:
	var dig := 0.0 if r.dropped else minf(r.dig + extra_dig, _dig_max)
	var need := _k_need * r.kick_at / 100.0 * r.dprime * (1.0 - dig)
	return minf(need, r.kick_at * _drain(r, r.kick_v) / r.kick_v)


## What they feel they could spend now and still kick as planned.
func _spare(r: Runner) -> float:
	return _felt(r) - _need(r)


## The fastest speed the runner is willing to run now (before the kick): following at it leaves the reserve
## they want at their kick point. `dr` = the drafting they expect; `extra_dig` = digging deeper (covering a
## move). Never below own_floor x the speed that would empty their reserve at the line: a dropped runner falls
## back to their own pace, not to a jog.
func _cap(r: Runner, dr: float, extra_dig := 0.0) -> float:
	var rem := DISTANCE - r.d
	var felt := _felt(r)
	var v_line := _hold_speed(r, rem, maxf(felt, 0.0))
	var to_kick := rem - r.kick_at
	var v := v_line
	if to_kick > 1.0:
		var avail := felt - _need(r, extra_dig)
		var v_hang := _hold_speed(r, to_kick, clampf(avail, 0.0, 0.5 * to_kick))
		v = maxf(v_hang, v_line * _own_floor)
	return minf(v / (1.0 - dr), r.kick_v)


## Share of speed saved by running close behind someone (same line: full, diagonally behind: second_row;
## less on a bend). No drafting in lanes.
func _draft_of(r: Runner, order: Array[Runner]) -> float:
	if r.d < break_line:
		return 0.0
	var e := _eng
	var best := 0.0
	var dist := float(e.draft_dist)
	for k in range(_idx(r, order) - 1, -1, -1):
		var o: Runner = order[k]
		var gap := o.d - r.d
		if gap > dist + SLACK:
			break
		if o.done or o.down_left > 0.0 or gap <= 0.0 or gap > dist:
			continue
		var lat := absf(o.lat - r.lat)
		if lat < float(e.draft_lat):
			best = maxf(best, float(e.draft))
		elif lat < float(e.draft_lat_max):
			best = maxf(best, float(e.draft) * float(e.draft_second_row))
	if best > 0.0 and is_bend(r.d):
		best *= float(e.draft_bend)
	return best


## The nearest runner ahead in any line (still running, not on the ground). Searches the step's order
## backwards from r: runners further back can't be ahead (they haven't moved yet this step).
func _runner_in_front(r: Runner, order: Array[Runner]) -> Runner:
	var best: Runner = null
	for k in range(_idx(r, order) - 1, -1, -1):
		var o: Runner = order[k]
		if best != null and o.d - best.d > SLACK:
			break
		if o.done or o.down_left > 0.0 or o.d <= r.d:
			continue
		if best == null or o.d < best.d:
			best = o
	return best


## The nearest runner ahead in about the same line within AHEAD_RANGE metres, or null.
const AHEAD_RANGE := 12.0
func _runner_ahead(r: Runner, order: Array[Runner]) -> Runner:
	var best: Runner = null
	for k in range(_idx(r, order) - 1, -1, -1):
		var o: Runner = order[k]
		if o.d - r.d > (best.d - r.d if best != null else AHEAD_RANGE) + SLACK:
			break
		if o.done or o.down_left > 0.0 or o.d <= r.d:
			continue
		if absf(o.lat - r.lat) < 1.5 and (best == null or o.d < best.d):
			best = o
	return best if best != null and best.d - r.d <= AHEAD_RANGE else null


## No one within 1.8 m along the track at that lateral position.
func _outside_clear(r: Runner, lat: float, order: Array[Runner]) -> bool:
	return _at(r, lat, order) == null


## The runner within 1.8 m along the track at that lateral position (not r), or null.
func _at(r: Runner, lat: float, order: Array[Runner]) -> Runner:
	var i := _idx(r, order)
	for k in range(i - 1, -1, -1):
		var o: Runner = order[k]
		if o.d - r.d > 1.8 + SLACK:
			break
		if not o.done and o.down_left <= 0.0 and absf(o.d - r.d) < 1.8 and absf(o.lat - lat) < 0.7:
			return o
	for k in range(i + 1, order.size()):
		var o: Runner = order[k]
		if r.d - o.d > 1.8 + SLACK:
			break
		if not o.done and o.down_left <= 0.0 and absf(o.d - r.d) < 1.8 and absf(o.lat - lat) < 0.7:
			return o
	return null


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
	if p.down_left > 0.0:
		return
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
	elif _move_card_coming(p):
		for o in order:
			if o != p and not o.done and (o.kicking or o.surge_left > 0.0) and absf(o.d - p.d) < 15.0:
				_card_mover = o
				var what := "kicks" if o.kicking else "surges"
				_ask("move", "A rival makes a move",
						"%s %s with %d m to go!" % [o.name, what, roundi(DISTANCE - o.d)], [
					["go", "Go with them", "Cover the move now."],
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
			var o := _card_mover
			if o != null and o.surge_left > 0.0 and not o.kicking:
				_cover(p, o, standings())    # go with the surge
			elif not p.kicking:
				_start_kick(p, standings(), o)
			_say("You go with the move!")
		["move", "wait"]:
			if _card_mover != null and _card_mover.surge_left > 0.0 and not _card_mover.kicking:
				_let_go(p, _card_mover, standings())
			elif _card_mover != null:
				p.decided["kick %d" % _card_mover.index] = true
			_say("You let them go and stay patient.")
		["kick", "now"]:
			if not p.kicking:
				_start_kick(p, standings(), null)
			_say("You kick with 200 to go!")
		["kick", "wait"]:
			p.kick_at = 100.0
			if interactive:
				p.kick_free = false   # your call: no answering other kicks before the home straight
		["straight", "wide"]:
			var ahead := _runner_ahead(p, standings())
			if ahead:
				p.lat_target = ahead.lat + 1.2
			if not p.kicking:
				_start_kick(p, standings(), null)
			_say("You swing wide into lane 2 and go for it!")
		["straight", "inside"]:
			if not p.kicking:
				_start_kick(p, standings(), null)
			var ahead := _runner_ahead(p, standings())
			if ahead and _rng.randf() < 0.35 + p.tactics / 40.0:
				ahead.lat_target = ahead.lat + 1.0
				_say("A gap opens on the inside!")
			else:
				_say("No gap... you're boxed in.")


# --- Race events (R2) and commentary ------------------------------------------------------

## Adds an event (see `events`). `r` = who (null: the race itself).
func _event(type: String, r: Runner, extra := {}, order: Array[Runner] = []) -> void:
	var ev := {"type": type, "t": snappedf(time, 0.1)}
	if r != null:
		if order.is_empty():
			order = standings()
		var lead: Runner = _leader if _leader != null else order[0]
		ev.merge({"who": r.name, "i": r.index, "player": r.is_player, "d": roundi(r.d),
				"pos": _idx(r, order) + 1, "gap": snappedf(maxf(0.0, lead.d - r.d), 0.1)})
	ev.merge(extra)
	events.append(ev)
	if print_events:
		print("race ", ev)   # dev: follow the engine's events in the Output panel while watching (R4 turns them into commentary)


## Engine events that look at the whole field: break leader, pace calls and pack shape at 200 / 400 / 600,
## lead changes, and the close finishes.
func _race_events(order: Array[Runner]) -> void:
	var leader := _leader
	if leader == null:
		return
	if not _announced.has("ev_break") and leader.d >= break_line + 5.0:
		_announced["ev_break"] = true
		_event("break_leader", leader, {}, order)
		_last_leader = leader
		_lead_since = time
	while _next_mark < MARKS.size() and leader.d >= MARKS[_next_mark]:
		var mark: int = MARKS[_next_mark]
		_next_mark += 1
		var group := 0
		var last := leader
		for r in order:
			if r.done or r.status != "":
				continue
			if leader.d - r.d <= 5.0:
				group += 1
			if r.d < last.d:
				last = r
		var info := {"mark": mark, "group": group, "spread": snappedf(leader.d - last.d, 0.1)}
		if mark % 200 == 0:
			var even := float(mark) / ref_speed + float(_eng.start_cost) * (1.0 - float(mark) / DISTANCE)
			info.split = snappedf(time, 0.1)
			info.vs_even = snappedf((even / time - 1.0) * 100.0, 0.1)
			_event("pace", leader, info, order)
		else:
			_event("pack", leader, info, order)
	if _last_leader != null and leader != _last_leader and leader.d > break_line + 5.0:
		if time - _lead_since >= float(_eng.lead_change_s):
			_event("lead_change", leader, {"from": _last_leader.name}, order)
		_last_leader = leader
		_lead_since = time
	if finished and not _announced.has("ev_finish"):
		_announced["ev_finish"] = true
		var res := results()
		var fin := res.filter(func(x): return x.status == "")
		if not fin.is_empty():
			_event("finish", null, {"who": fin[0].name, "time": fin[0].time})
		for k in range(1, fin.size()):
			var margin: float = fin[k].time - fin[k - 1].time
			if margin < float(_eng.close_finish_s):
				var type := "photo_finish" if margin < float(_eng.photo_finish_s) else "close_finish"
				_event(type, null, {"who": fin[k - 1].name, "with": fin[k].name, "place": k, "margin": snappedf(margin, 0.01)})


func _commentate(order: Array[Runner]) -> void:
	var leader := order[0]
	if not _announced.has("break") and leader.d >= break_line + 5.0:
		_announced["break"] = true
		_say("%s leads at the break." % leader.name)
	if not _announced.has("400") and leader.d >= 400.0:
		_announced["400"] = true
		_say("%s %s: %s." % [leader.name, "at halfway" if indoor else "at the bell", Calendar.format_time(leader.split_400)])
	for r in order:
		if r.kicking and not r.said_kick and not r.done:
			r.said_kick = true
			if r.is_player or r == leader or position_of(r) <= 3:
				if not r.is_player:
					_say("%s kicks with %d m to go!" % [r.name, roundi(DISTANCE - r.d)])
	if finished and not _announced.has("finish"):
		_announced["finish"] = true
		var winner := standings()[0]
		if winner.status == "":
			_say("%s wins in %s!" % [winner.name, Calendar.format_time(winner.t)])


func _say(text: String) -> void:
	log_lines.append(text)
	commentary.emit(text)


static func _ordinal(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	return "%d%s" % [n, {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")]


## "2nd in 2:31.40" (`sep` between place and time), or "DNF" / "DQ" for a race without a time (results of
## the player, old ones too).
static func result_text(r: Dictionary, sep := " in ") -> String:
	match str(r.get("status", "")):
		"dnf": return "DNF"
		"dq": return "DQ"
	return _ordinal(int(r.place)) + sep + Calendar.format_time(float(r.time))


## The time, or "DNF" / "DQ".
static func time_text(r: Dictionary) -> String:
	match str(r.get("status", "")):
		"dnf": return "DNF"
		"dq": return "DQ"
	return Calendar.format_time(float(r.time))


## Final results: [{name, club, time, status, is_player, rival, split_400, fell, spiked, out_weeks}]:
## finishers fastest first, then the disqualified, then those who did not finish (time 0 for both).
func results() -> Array:
	var order := standings()
	var fin := order.filter(func(r): return r.status == "")
	var dq := order.filter(func(r): return r.status == "dq")
	var dnf := order.filter(func(r): return r.status == "dnf")
	var out := []
	for r in fin + dq + dnf:
		out.append({"name": r.name, "club": r.club, "time": snappedf(r.t, 0.01) if r.status == "" else 0.0,
				"status": r.status, "is_player": r.is_player, "rival": r.rival, "split_400": r.split_400,
				"fell": r.falls > 0, "spiked": r.spiked, "out_weeks": r.out_weeks})
	return out
