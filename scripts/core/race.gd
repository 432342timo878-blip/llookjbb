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
var break_line := bend            # 800 m runners stay in lanes for the first bend (indoors two, decision 29)
var break_bends := 1              # bends run in lanes (the stagger the race screen draws)

signal decision_needed(decision: Dictionary)
signal commentary(text: String)

var runners: Array[Runner] = []
var player: Runner
var time := 0.0
var finished := false
var interactive := false          # detailed mode: pause at decision points
var age := 0.0                    # the runners' age in years (one birth year; set by RaceDay before setup): older runners' race-day form varies less (races.json engine.form_sd.by_age, step 7); 0 = not known, the full spread
var manual_kick := false          # the watched race on the race screen: "wait" means the player kicks by pressing Kick now (set by the screen; tools and quick mode keep "wait" = kick at 100 m)
var kick_plan := 0.0              # quick result: the metres to go at which the athlete kicks (0 = their own natural point; set_kick_plan)
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

## The player's controls (GDD 4.3.1, step R3): the cards asked so far (how many of each id), the action bar's
## effort (push / hold / ease) and the log of cards for tools: {id, t, d, answer}.
var cards_shown := 0
var effort := "hold"
var card_log: Array = []
## R4 (recording only): the player's choices and commands as they happened: {key ("break.lead", "bar.push", ...), t,
## to_go}, for the commentary's "you" lines. `coach_id` = the player's coach (data/coaches.json): his shouts' wording.
var say_log: Array = []
var coach_id := ""
var _card_counts := {}
var _last_card_t := -1000.0
var _ctl: Dictionary              # data/races.json "controls"
var _gender := "male"
var _player_fatigue := 0.0
var _coach_rng: RandomNumberGenerator
var _rng: RandomNumberGenerator
var _eng: Dictionary              # data/races.json "engine"
var _mix := ""
var _leader: Runner
var _box_timer := 0.0
var _announced := {}
var _last_leader: Runner          # for lead_change events
var _lead_since := 0.0
var _card_mover: Runner           # whose move the "A rival makes a move" card is about
var _card_kinds: Array = []       # the card ids, most important first
var _card_info := {}              # the placeholders of the card being asked (the coach's shout uses them)
const MARKS := [200, 300, 400, 500, 600]   # pace calls (200 / 400 / 600) and pack shape (300 / 500)
const SPLIT_MARKS := [200, 400, 600]        # the splits every runner's `marks` records (R4)
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
	var prev_d := 0.0             # d and lat before the last step (the race screen draws in between: smooth at 1x)
	var prev_lat := 0.0
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
	var marks: Dictionary = {}    # R4 (recording only): metres → {t (time the runner passed it), pos (their place then)}
	var scripted: Dictionary = {} # dev tools: a scripted race (tools/race_shape.gd duel rows)
	# Moves (R2)
	var surge_left := 0.0         # metres of their surge still to run
	var surge_v := 0.0
	var surges := 0
	var covering: Runner = null   # the surger they go with
	var hold_left := 0.0          # letting a move go: metres more at no more than hold_v
	var driving := false          # after their surge, leading: pressing on while they can afford it (R5)
	var let_go_of := -1           # the mover they let go (index): no chasing while that move goes on (R5)
	# The player's controls (R3)
	var out_left := 0.0           # Move out: seconds more outside, going for a pass
	var out_to := 0.0             # ... and how far out (metres from the rail)
	var dig_boost := 0.0          # "Dig in" / "Get up and chase": digs this much deeper, even when dropped
	var dropped_s := 0.0          # seconds in a row they have been dropped
	var let_go_until := 0.0       # metres run until which a runner who let a move go closes on the field only slowly
	var commit_left := 0.0        # metres more the player runs committed: the speed cap that protects the kick is off
	var kick_nat := 0.0           # the kick point their body suits (metres to go): an earlier kick overshoots
	var box_pending := false      # boxed, and the box card is still to be decided (after box_after_s)
	var hold_v := 0.0
	var decided := {}             # "move <i> <n>" / "kick <i>" -> already decided about that move or kick
	var kick_free := true         # answers kicks (off when the player chose to wait for the home straight)
	var kick_hold := false        # watched race, the player chose to wait: the kick starts only when they press Kick now
	var kick_began := 0.0         # metres to go when the kick started (the commentary tells a late kick from an early one)
	# Boxed in (R2)
	var boxed := false
	var box_way := ""             # wait / ease / push while a box lasts
	var box_time := 0.0
	var box_ref := -1             # the runner ahead when the box began (index), and the gap to them then (the
	var box_gap0 := 0.0           # escape event reports the metres the box cost against them)
	var room := false             # boxed: room to push out (the runner on the shoulder is half a stride back)
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


## The share of the race-day form spread at this age (races.json engine.form_sd.by_age, [age, share] interpolated;
## 1.0 when the age is not known): GDD 4.3.1 decision 12, step 7. Real elite runners vary about 1 % from race to race,
## youngsters more (Hopkins 2005; Hopkins & Hewson 2001).
static func form_age_share(years: float) -> float:
	var table: Array = Data.races.engine.form_sd.get("by_age", [])
	if years <= 0.0 or table.is_empty() or years <= float(table[0][0]):
		return 1.0 if years <= 0.0 or table.is_empty() else float(table[0][1])
	for i in range(1, table.size()):
		if years <= float(table[i][0]):
			return lerpf(float(table[i - 1][1]), float(table[i][1]), (years - float(table[i - 1][0])) / (float(table[i][0]) - float(table[i - 1][0])))
	return float(table.back()[1])


## `entrants`: Dictionaries with name, club, ability, speed, anaerobic, tactics, consistency, composure
## (+ is_player, rival, personality, competitiveness / determination, and for dev tools `script`: a scripted
## race, see _apply_script). `big_meet` makes composure matter. `player_fatigue` 0–100. `mix` = the race-shape
## mix (data/races.json shapes.mix: local / district / heat / final; "" = the default).
func setup(entrants: Array, gender: String, big_meet: bool, player_fatigue: float, rng: RandomNumberGenerator,
		indoor_track := false, mix := "") -> void:
	_rng = rng
	_eng = Data.races.engine
	_ctl = Data.races.controls
	_gender = gender
	_player_fatigue = player_fatigue
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
		# In lanes for two bends (the back straight between them), as the 400 m: the World Athletics rule since
		# 1 Nov 2025 (GDD 4.3.1 decision 29); outdoors one bend.
		break_bends = int(_eng.get("indoor_break_bends", 1))
		break_line = bend * break_bends + straight * (break_bends - 1)
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
		# Race-day form: consistency narrows the spread, so do the years (seniors), composure matters at big meets.
		var fsd: Dictionary = e_cfg.form_sd
		var form := rng.randfn(0.0, (float(fsd.base) + (20.0 - float(e.consistency)) / 20.0 * float(fsd.per_inconsistency)) * float(fsd.scale) * form_age_share(age))
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
			r.kick_nat = r.kick_at
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


## The player's kick plan for a quick result (the athlete follows it): kick at `to_go` metres to go (0 = their natural
## point, with the usual noise). The kick card is then answered "Kick now" there. A kick earlier than the body suits
## still overshoots and dies (controls.kick_early), so the plan has a price.
func set_kick_plan(to_go: float) -> void:
	kick_plan = to_go
	if player and to_go > 0.0:
		player.kick_at = to_go


## The player's kick plan (a Quick result) says the kick comes later than this: the home straight card does not start it.
func _plan_waits(p: Runner) -> bool:
	return kick_plan > 0.0 and DISTANCE - p.d > kick_plan


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
	for r in runners:
		r.prev_d = r.d
		r.prev_lat = r.lat
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
		_check_cards(order)


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
	if not card_log.is_empty():
		card_log[-1].answer = option_id
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
	if r.is_player:
		r.dropped_s = r.dropped_s + DT if r.dropped else 0.0
	if r.dropped and not r.was_dropped and r.d > break_line + 50.0 and not r.getting_up and front != null:
		r.was_dropped = true
		_event("dropped", r, {"behind": front.name}, order)
	var wants_past := false
	var pace := _pace(r)

	if not r.kicking and rem <= r.kick_at:
		if r == player and int(_card_counts.get("kick", 0)) == 0:
			# The player reaches their own kick point: the "metres to go" card asks (R3); the answer starts the
			# kick (or waits for the home straight). If another card is open, the kick waits a step.
			if pending.is_empty():
				_ask("kick")
		elif not r.kick_hold:
			_start_kick(r, order, null)   # (a player who chose to wait kicks only when they press Kick now)
	var target: float
	if r.kicking:
		# Fastest speed the reserve they feel they have can hold to the line: rem / (rem - felt) times cs.
		target = _kick_speed(r)
		if r.dleft <= 0.0 and not r.kick_died and rem > float(e.kick_dying_to_go):
			r.kick_died = true
			_event("kick_dying", r, {"to_go": roundi(rem), "began": roundi(r.kick_began)}, order)
	else:
		var follow: Runner = front if gap_front <= float(e.follow_range) else null
		var cap := _cap(r, float(e.draft) if follow else 0.0)
		# Someone who let a move go closes on the field only slowly until their own kick (moves.let_go_close).
		var close_max := float(e.moves.let_go_close) if r.d < r.let_go_until else float(e.close_max)
		if r.d < break_line:
			# In lanes: the race's pace, a little quicker for those who want the lead.
			target = minf(pace * float(e.place_speed[r.want]), cap)
		elif follow == null:
			# Leading: the race's pace. Detached: their own pace, closing in no faster than close_max.
			target = minf(pace if r == _leader else pace * close_max, cap)
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
					follow.v * close_max)
			if to_front:
				target = follow.v * float(e.pass_speed)          # working to the front
				wants_past = true
			elif past_fader:
				target = minf(cap, maxf(pace, follow.v * float(e.pass_speed)))   # past a runner who is fading
				wants_past = true
			target = minf(target, cap)   # can't hold it: dropped
			if r.out_left > 0.0:   # Move out (the action bar): going for a pass on the outside
				target = minf(cap, maxf(target, follow.v * float(e.pass_speed)))
				wants_past = true
		# Moves (R2): a surge of their own, going with someone's surge, or letting it go.
		if r.d >= break_line:
			_maybe_surge(r, order, pace)
		if r.driving and r.surge_left <= 0.0:
			# After their surge the mover presses on (moves.drive), past anyone slower, while they can afford it;
			# one who can't settles back into the race and is caught (R5, decision 23).
			var dv: Dictionary = e.moves.drive
			var cap0 := _cap(r, 0.0)
			if cap0 >= pace * float(dv.min):
				target = maxf(target, minf(pace * float(dv.speed), cap0))
				wants_past = true
			else:
				r.driving = false
		if r.surge_left > 0.0:
			target = minf(r.surge_v, top)
			wants_past = true
			r.surge_left -= r.v * DT
			if r.surge_left <= 0.0 and not r.is_player:
				r.driving = true   # the surge is over: press on if they lead and can afford it (above)
		elif r.covering != null:
			var s := r.covering
			if s.done or s.down_left > 0.0 or (s.surge_left <= 0.0 and not s.kicking and not s.driving) or s.d < r.d - 2.0:
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
		if r.let_go_of >= 0:
			# They let the move go: no chasing while it goes on (the mover's surge and drive), until their own kick.
			var m: Runner = runners[r.let_go_of]
			if (m.surge_left > 0.0 or m.driving) and not m.done and r.d < r.let_go_until:
				target = minf(target, maxf(r.hold_v, pace))
			else:
				r.let_go_of = -1
		target *= r.pace_factor

	if r.d >= break_line:
		target = _traffic(r, order, target, wants_past, rem)

	# Heats (R2, decision 33): safely in an automatic qualifying place near the line, they ease off, and go on easing
	# while the first runner outside the places stays `keep` metres behind.
	if auto_places > 0 and rem < r.ease_from and order.size() > auto_places:
		var pos := _idx(r, order) + 1
		var chaser: Runner = order[auto_places]
		var need := float(e.heat_ease.get("keep", e.heat_ease.margin)) if r.easing else float(e.heat_ease.margin)
		if pos <= auto_places and r.d - chaser.d >= need:
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
	if r.commit_left > 0.0:
		r.commit_left = maxf(0.0, r.commit_left - progress)
	if r.split_400 == 0.0 and r.d >= 400.0:
		r.split_400 = time
	if r.marks.size() < SPLIT_MARKS.size() and r.d >= SPLIT_MARKS[r.marks.size()]:
		# (R4: splits for the Race story and the coach's calls; recording only, nothing in the race reads it)
		var at: int = SPLIT_MARKS[r.marks.size()]
		r.marks[at] = {"t": time - (r.d - at) / maxf(r.v, 0.1), "pos": r.oi + 1}


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
	var v := _hold_speed(r, rem, felt)
	if r.is_player:
		# A kick started earlier than the player's body suits feels fine at first: they run a little above what
		# the reserve can hold to the line (controls.kick_early), and die before it. At their own point: none.
		var ke: Dictionary = _ctl.kick_early
		v *= 1.0 + float(ke.per_m) * maxf(0.0, rem - r.kick_nat - float(ke.free_m))
	return minf(r.kick_v, v)


## Runner ahead in the same line: following, passing, boxed in (GDD 4.3.1). Returns the target speed.
func _traffic(r: Runner, order: Array[Runner], target: float, wants_past: bool, rem: float) -> float:
	var b: Dictionary = _eng.box
	if r.push_left > 0.0:
		r.push_left -= DT
	var moving_out := r.out_left > 0.0   # the player's Move out
	if moving_out:
		r.out_left -= DT
		wants_past = true
	var ahead := _runner_ahead(r, order)
	var in_box := false
	if ahead != null:
		var gap := ahead.d - r.d
		# (a box lasts while they drop back to step out: up to box.hold metres behind, easing box.ease_hold)
		var hold := float(b.ease_hold) if r.box_way == "ease" else float(b.hold)
		if (gap < 2.0 or (r.box_way != "" and gap < hold)) and absf(ahead.lat - r.lat) < 0.9:
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
	if moving_out and not in_box:
		var beside := _at(r, r.out_to, order)
		if beside == null or r.d - beside.d >= float(b.room_m):
			r.lat_target = maxf(r.lat_target, r.out_to)   # out (stay out instead of drifting back to the rail)
		else:
			# Someone right beside them: drop back a stride and step out behind them, as easing out of a box (R5).
			target = minf(target, beside.v * float(b.ease_speed))
	r.boxed = in_box
	if not in_box and r.box_way != "":
		var lost := 0.0
		if r.box_ref >= 0 and not runners[r.box_ref].done:
			lost = (runners[r.box_ref].d - r.d) - r.box_gap0
		_event("escape", r, {"way": r.box_way, "seconds": snappedf(r.box_time, 0.1), "lost": snappedf(lost, 0.1)}, order)
		r.box_way = ""
		r.box_pending = false
	return target


## Boxed in counts when it matters: kicking, in a move, or in the last box.urgent_to_go metres.
func _urgent(r: Runner, rem: float) -> bool:
	return r.kicking or r.surge_left > 0.0 or r.covering != null or rem < float(_eng.box.urgent_to_go)


## Boxed in: no faster than the runner ahead, and a way out: wait for a gap, ease and step out, push through.
func _boxed(r: Runner, ahead: Runner, out_lat: float, target: float, order: Array[Runner]) -> float:
	var b: Dictionary = _eng.box
	var blocker := _blocker(r, out_lat, order)
	r.room = _room(r, blocker)
	if r.box_way == "":
		r.box_time = 0.0
		r.box_ref = ahead.index
		r.box_gap0 = ahead.d - r.d
		if r == player:
			# The player waits at first; if the box lasts and a move is going, the box card asks (R3); else the
			# way is rolled like a rival's.
			r.box_way = "wait"
			r.box_pending = true
		else:
			r.box_way = _box_way(r)
		_event("boxed", r, {"way": r.box_way}, order)
	r.box_time += DT
	if r.box_pending and r.box_time >= float(_ctl.cards.box_after_s):
		r.box_pending = false
		if _move_going(r) and _card_ok("box"):
			var ph: Dictionary = Data.race_cards.phrases
			var room_line: String = ph.room if r.room else String(ph.no_room).format(
					{"name": _surname(blocker.name if blocker != null else ahead.name)})
			_ask("box", {"name": _surname(ahead.name), "room": room_line, "context": _move_context(r)})
		else:
			r.box_way = _box_way(r)
	match r.box_way:
		"wait":
			target = minf(target, ahead.v)
			# On a bend nobody drifts wide (it costs distance): a gap rarely opens there, so a box on the last bend
			# lasts until the home straight (R5: waiting works early, fails late).
			var rate := lerpf(float(b.gap_rate.at_1), float(b.gap_rate.at_20), r.skill) \
					* (float(b.gap_bend) if is_bend(r.d) else 1.0)
			if blocker != null and _rng.randf() < rate * DT:
				# The runner on their shoulder drifts wide (or moves on): a gap opens.
				blocker.lat_target = maxf(blocker.lat_target, blocker.lat + 1.0)
				_event("gap_opens", r, {"by": blocker.name}, order)
		"ease":
			# Ease off a stride and step out behind the runner on the shoulder: a little slower than them until the
			# outside is clear (then _traffic moves out). It costs the metres it takes to get behind them.
			target = minf(target, (blocker if blocker != null else ahead).v * float(b.ease_speed))
		"push":
			target = minf(target, ahead.v)
			if r.push_left <= 0.0:
				r.push_left = float(b.push_time)
				var other := blocker if blocker != null else ahead
				# With room (the runner on the shoulder is half a stride back) it is a nudge; without, a shove.
				var k := 1 if r.room else 0
				other.lat_target = maxf(other.lat_target, out_lat + 0.6)
				if _rng.randf() < float(b.push_contact[k]):
					_contact(r, other, "push", order)
				if r.status == "" and _rng.randf() < float(b.push_dq[k]):
					r.status = "dq"
					_event("dq", r, {"reason": "obstruction"}, order)
	return target


## Is there room to push out of the box? The runner on the outside shoulder is at least box.room_m behind (the
## boxed runner is half a stride up on them) or nobody is there.
func _room(r: Runner, blocker: Runner) -> bool:
	return blocker == null or r.d - blocker.d >= float(_eng.box.room_m)


## Was there room in the runner's box at its last step (the box card's text, the tools)?
func box_room(r: Runner) -> bool:
	return r.room


## The best way out of a box (R5, user 2026-10-09: the room decides; measured with tools/race_value.gd): with
## someone right on the shoulder, wait (the field moves and a gap comes in a second or two); with room, ease and
## step out, or push through in the last box.best.push_to_go metres. The sensible answer to the box card, and what
## a rival does with a chance that grows with race tactics.
func _box_best(r: Runner) -> String:
	if not r.room:
		return "wait"
	return "push" if DISTANCE - r.d < float(_eng.box.best.push_to_go) else "ease"


## How a runner gets out of a box: the best way with a chance from race tactics (box.smart), otherwise by their
## habits (weights wait / ease / push, push more with grit and in the last `late` metres).
func _box_way(r: Runner) -> String:
	if r.scripted.has("box_way"):
		return _box_best(r) if r.scripted.box_way == "best" else r.scripted.box_way
	var b: Dictionary = _eng.box
	if _rng.randf() < lerpf(float(b.smart[0]), float(b.smart[1]), r.skill):
		return _box_best(r)
	var rem := DISTANCE - r.d
	var w := {
		"wait": float(b.wait),
		"ease": float(b.ease),
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
		if o == player and _card_ok("move"):
			o.decided[key] = true
			_ask("move", _move_ctx(s, "surges"))   # the "A rival makes a move" card decides
			continue
		o.decided[key] = true
		if _rng.randf() < _cover_chance(o, s):
			_cover(o, s, order)
		else:
			_let_go(o, s, order)


func _cover(o: Runner, s: Runner, order: Array[Runner], kick := false) -> void:
	o.covering = s
	o.hold_left = 0.0
	var extra := {"of": s.name}
	if kick:
		extra["kick"] = true
	_event("cover", o, extra, order)


func _let_go(o: Runner, s: Runner, order: Array[Runner]) -> void:
	o.covering = null
	o.let_go_until = DISTANCE - o.kick_at   # no closing on them (moves.let_go_close) until their own kick point
	o.hold_left = maxf(s.surge_left, 0.0) + float(_eng.moves.let_go_after)
	o.hold_v = o.v
	o.let_go_of = s.index
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
	r.kick_hold = false
	r.kick_began = DISTANCE - r.d
	r.driving = false
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
		if o == player and _card_ok("move"):
			_ask("move", _move_ctx(k, "kicks"))   # the card decides (R3)
			continue
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
	r.driving = false
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
	if _p == 5.0:
		var x := u / r.even_v
		var x2 := x * x
		return (u - r.cs) * x2 * x2 * x
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
	if p == 5.0:   # (the same Newton iteration with multiplications instead of pow: this runs for every runner every step)
		var ve2 := r.even_v * r.even_v
		var k5 := budget * ve2 * ve2 * r.even_v / dist
		var u5 := maxf(r.cs * dist / (dist - budget), r.cs * 1.001)
		for i in 6:
			var u2 := u5 * u5
			var u3 := u2 * u5
			var f5 := (u5 - r.cs) * u3 * u5 - k5
			u5 = maxf(u5 - f5 / (u3 * u5 + 4.0 * (u5 - r.cs) * u3), r.cs * 1.0001)
		return u5
	var u := maxf(r.cs * dist / (dist - budget), r.cs * 1.001)   # Newton from the linear answer
	for i in 6:
		var f := (u - r.cs) * pow(u, p - 1.0) - k
		var df := pow(u, p - 1.0) + (u - r.cs) * (p - 1.0) * pow(u, p - 2.0)
		u = maxf(u - f / df, r.cs * 1.0001)
	return u


## The reserve they want to keep for their kick (kick_need_per_100 per 100 m of kick, less by how deep they
## dig; dropped runners stop digging), never more than the kick can use at full speed.
func _need(r: Runner, extra_dig := 0.0) -> float:
	var dig := 0.0 if (r.dropped and r.dig_boost <= 0.0) else minf(r.dig + r.dig_boost + extra_dig, _dig_max)
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
	if r.commit_left > 0.0:
		return r.kick_v   # the player has committed (went with a move, dug in, chased): nobody holds them back but the reserve
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


# --- Cards: the player's decisions (R3) -------------------------------------------------------

## Event-driven pause cards (GDD 4.3.1 "Player controls"): break, bell and 200 m to go always; a rival move or
## kick, being boxed in while a move goes, losing contact, a slow pace, the home straight and a fall when they
## happen. At most controls.cards.max per race, the most important first (see _card_ok). Moves and boxes ask from
## inside the step (_react_to_move, _react_to_kick, _boxed); the rest are checked here, once a step. In quick
## mode the athlete answers (_auto_choice), so both modes run the same engine.
func _check_cards(order: Array[Runner]) -> void:
	var p := player
	if p.down_left > 0.0 or not pending.is_empty():
		return
	var c: Dictionary = _ctl.cards
	var rem := DISTANCE - p.d
	if _card_kinds.is_empty():
		var pr: Dictionary = c.priority
		_card_kinds = pr.keys()
		_card_kinds.sort_custom(func(a, b): return float(pr[a]) > float(pr[b]))
	for kind in _card_kinds:
		if not _card_ok(kind):
			continue
		match kind:
			"break":
				if p.d >= break_line:
					_ask("break")
					return
			"bell":
				if p.d >= float(c.bell_at):
					var cfg: Dictionary = Data.race_cards.cards.bell
					var leader := order[0]
					_ask("bell", {"call": cfg.call_indoor if indoor else cfg.call, "leader": "The leader",
							"leader_split": Calendar.format_time(leader.split_400), "split": Calendar.format_time(p.split_400)})
					return
			"fall":
				if p.getting_up and p.falls > int(_card_counts.get("fall", 0)):
					var f := _runner_in_front(p, order)
					if f != null:
						_ask("fall", {"gap": roundi(f.d - p.d)})
						return
			"straight":
				if p.d >= float(c.straight_from) and _idx(p, order) > 0:
					var ahead := _runner_ahead(p, order)
					if ahead != null and ahead.d - p.d < float(c.straight_gap):
						_ask("straight", {"name": ahead.name})
						return
			"dropped":
				var f := _runner_in_front(p, order)
				var dr: Dictionary = c.dropped
				if f != null and p.dropped_s >= float(dr.hold_s) and not p.kicking and rem > float(dr.min_to_go) \
						and f.d - p.d >= float(dr.gap[0]) and f.d - p.d <= float(dr.gap[1]):
					_ask("dropped", {"gap": roundi(f.d - p.d), "name": _surname(f.name)})
					return
			"slow":
				var sl: Dictionary = c.slow
				if _leader != null and _leader != p and not p.kicking and p.want != "lead" and p.d >= float(sl.from) \
						and p.d <= float(sl.to) and _idx(p, order) + 1 <= int(sl.max_place) \
						and _leader.d - p.d <= float(sl.group_m) and _leader.v < ref_speed * float(sl.pace_max):
					_ask("slow", {"leader": _surname(_leader.name), "gap": roundi(_leader.d - p.d)})
					return


## How many of the always-asked cards (break, bell, 200 m to go) are still to come: they keep their place in the
## budget, so the optional cards can never push them out.
func _always_left() -> int:
	var n := 0
	for k in _ctl.cards.always:
		if int(_card_counts.get(k, 0)) == 0 and not (k == "kick" and player.kicking):
			n += 1
	return n


## May a card of this kind be asked now? Not while another is open; the always cards once each; the others only
## when there is room in the budget, not more than max_per_race, not too soon after the last card and (only_below)
## not when the low-priority ones would take the last places.
func _card_ok(kind: String) -> bool:
	if player == null or player.done or not pending.is_empty():
		return false
	var c: Dictionary = _ctl.cards
	var n := int(_card_counts.get(kind, 0))
	if kind in c.always:
		return n == 0
	if cards_shown + _always_left() >= int(c.max) or n >= int(c.max_per_race.get(kind, 1)):
		return false
	if c.only_below.has(kind) and cards_shown >= int(c.only_below[kind]):
		return false
	return kind in c.no_gap or time - _last_card_t >= float(c.min_gap_s)


func _ask(id: String, ctx := {}) -> void:
	var cfg: Dictionary = Data.race_cards.cards[id]
	_card_counts[id] = int(_card_counts.get(id, 0)) + 1
	cards_shown += 1
	_last_card_t = time
	_card_mover = ctx.get("mover", null)
	var info := {"pos": _ordinal(position_of(player)), "to_go": roundi(DISTANCE - player.d)}
	info.merge(ctx, true)
	info.erase("mover")
	_card_info = info
	var title: String = cfg.get("title_indoor", cfg.title) if indoor else cfg.title
	var opts := []
	for o in cfg.options:
		opts.append({"id": o.id, "label": o.label, "detail": o.detail})
	var decision := {"id": id, "title": title.format(info), "text": String(cfg.text).format(info), "options": opts}
	var coach := _coach_line(id, info)
	if not coach.is_empty():
		decision["coach"] = coach
	card_log.append({"id": id, "t": snappedf(time, 0.1), "d": roundi(player.d), "answer": "", "coach_sees": coach_sees()})
	if interactive:
		pending = decision
		decision_needed.emit(decision)
	else:
		var pick := _auto_choice(id)
		card_log[-1].answer = pick
		_apply_choice(player, id, pick)


## What the athlete does on their own (quick mode): the sensible answer with a chance that grows with race
## tactics (controls.auto), otherwise any answer. The break is the pre-race plan.
func _auto_choice(id: String) -> String:
	var sensible := sensible_choice(id)
	if id == "break":
		return sensible
	if id == "kick" and kick_plan > 0.0:
		return "now"   # (the athlete follows the player's kick plan)
	var a: Dictionary = _ctl.auto
	if _rng.randf() < lerpf(float(a.sensible_at_1), float(a.sensible_at_20), player.skill):
		return sensible
	var opts: Array = Data.race_cards.cards[id].options
	return opts[_rng.randi_range(0, opts.size() - 1)].id


## The sensible answer to the card `id` in the state of the race now (no dice): the coach's advice, what quick
## mode usually does, and the "sensible watched player" of the checks. See controls.sensible.
func sensible_choice(id: String) -> String:
	var p := player
	var s: Dictionary = _ctl.sensible
	var rem := DISTANCE - p.d
	var share := _felt(p) / p.dprime
	match id:
		"break":
			return {"lead": "lead", "pack": "shoulder", "back": "back"}.get(p.want, "shoulder")
		"bell":
			if share >= float(s.bell_push_share) and position_of(p) >= 3:
				return "push"
			return "ease" if share < float(s.bell_ease_share) else "hold"
		"kick":
			return "now" if share >= _k_need * rem / 100.0 * float(s.kick_now_factor) else "wait"
		"straight":
			return "wide"
		"fall":
			var f := _runner_in_front(p, standings())
			return "chase" if f != null and f.d - p.d < float(s.chase_gap) else "steady"
		"box":
			return _box_best(p)
		"dropped":
			var ahead := _runner_in_front(p, standings())
			var close: bool = ahead != null and ahead.d - p.d <= float(s.dig_gap)
			return "dig" if close and share >= float(s.dig_share) else "own"
		"slow":
			var better := 0
			for r in runners:
				if r != p and r.even_v > p.even_v:
					better += 1
			return "lead" if better < int(s.slow_rank) and share >= float(s.slow_share) else "stay"
		"move":
			var m := _card_mover
			if m == null:
				return "wait"
			var can: bool
			if m.kicking:
				can = minf(_hold_speed(p, rem, maxf(_felt(p), 0.0)), p.kick_v) >= _kick_speed(m) * float(_eng.chain.can_share)
			else:
				can = _spare(p) >= maxf(m.surge_left, 0.0) * _drain(p, m.surge_v * (1.0 - float(_eng.draft))) / maxf(m.surge_v, 0.1)
			if can and share >= float(s.counter_share) and rem <= float(s.counter_to_go) \
					and p.kick_v >= m.kick_v * float(s.counter_edge):
				return "counter"
			# Go with a mover who is clearly weaker on the day (they press on, and letting them go costs you the gap)
			# when you can afford it; let an equal or stronger one go: going with them is a commitment (no holding
			# back for the kick) that costs more than the gap (R5, measured with tools/race_value.gd).
			return "go" if can and m.even_v <= p.even_v * (1.0 + float(s.go_edge)) else "wait"
	return ""


func _apply_choice(p: Runner, id: String, option: String) -> void:
	var order := standings()
	match [id, option]:
		["break", "lead"]:
			p.want = "lead"
		["break", "shoulder"]:
			p.want = "pack"
		["break", "back"]:
			p.want = "back"
		["bell", "push"], ["bell", "hold"], ["bell", "ease"]:
			set_effort(option)
		["move", "go"]:
			var m := _card_mover
			if m != null:
				if m.kicking and DISTANCE - p.d <= p.kick_at * float(_eng.chain.kick_now_share):
					if not p.kicking:
						_start_kick(p, order, m)
				elif m.kicking or m.surge_left > 0.0:
					_cover(p, m, order, m.kicking)    # going with them
					# ... for real: the speed cap that protects the kick is off for as long as the move lasts
					var to_go := maxf(m.surge_left, 0.0) if not m.kicking else maxf(DISTANCE - p.d - p.kick_at, 0.0)
					p.commit_left = to_go + float(_ctl.commit.cover_extra_m)
		["move", "wait"]:
			var m := _card_mover
			if m != null and m.surge_left > 0.0 and not m.kicking:
				_let_go(p, m, order)
		["move", "counter"]:
			var m := _card_mover
			if m != null and (m.kicking or DISTANCE - p.d <= p.kick_at):
				if not p.kicking:
					_start_kick(p, order, m)
			else:
				var cc: Dictionary = _ctl.counter
				p.surge_left = float(cc.length)
				p.surge_v = minf(maxf(p.v, _pace(p)) * float(cc.speed), p.kick_v)
				p.surges += 1
				p.hold_left = 0.0
				p.covering = null
				_event("move", p, {"pct": roundi((float(cc.speed) - 1.0) * 100.0), "length": roundi(float(cc.length))}, order)
				_react_to_move(p, order)
		["box", "wait"], ["box", "ease"], ["box", "push"]:
			p.box_way = option
			p.box_pending = false
			if option == "push":
				p.push_left = 0.0
		["dropped", "dig"]:
			p.dig_boost = float(_ctl.dig_in)
			p.commit_left = float(_ctl.commit.dig_m)
		["dropped", "own"]:
			p.dig_boost = 0.0
		["slow", "lead"]:
			p.want = "lead"
			set_effort(_ctl.take_lead.effort)
		["fall", "chase"]:
			p.dig_boost = float(_ctl.chase.dig)
			p.commit_left = DISTANCE   # all the way: no holding back
			set_effort(_ctl.chase.effort)
		["fall", "steady"]:
			p.dig_boost = 0.0
			set_effort(_ctl.steady.effort)
			p.kick_at = minf(p.kick_at, float(_ctl.steady.kick_at))
		["kick", "now"]:
			if not p.kicking:
				_start_kick(p, order, null)
		["kick", "wait"]:
			p.kick_at = 100.0
			if interactive:
				p.kick_free = false   # your call: no answering other kicks before the home straight
			if manual_kick:
				p.kick_hold = true    # and nothing starts the kick for you: Kick now, at any distance, is yours to press
		["straight", "wide"]:
			var ahead := _runner_ahead(p, order)
			if ahead:
				p.lat_target = ahead.lat + 1.2
			if not p.kicking and not p.kick_hold and not _plan_waits(p):
				_start_kick(p, order, null)
		["straight", "inside"]:
			if not p.kicking and not p.kick_hold and not _plan_waits(p):
				_start_kick(p, order, null)
			var ahead := _runner_ahead(p, order)
			if ahead and _rng.randf() < 0.35 + p.tactics / 40.0:
				ahead.lat_target = ahead.lat + 1.0
				_say_line("straight.gap")
			else:
				_say_line("straight.boxed")
			return
	_say_line("%s.%s" % [id, option])


## A line of the player's choices in the commentary (data/race_cards.json "says").
func _say_line(key: String) -> void:
	if player != null:
		say_log.append({"key": key, "t": snappedf(time, 0.1), "to_go": roundi(DISTANCE - player.d)})
	var line: String = Data.race_cards.says.get(key, "")
	if line != "" and player != null:
		_say(line.format({"to_go": roundi(DISTANCE - player.d)}))


# --- The action bar (R3): Push / Hold / Ease / Move out / Kick now ---------------------------------

func set_effort(e: String) -> void:
	effort = e
	if player != null:
		player.pace_factor = float(_ctl.effort[e])


## Can the player give this command now? Push / Hold / Ease only before the kick; Move out and Kick now not in
## lanes (Move out not either when already 3 m or more from the rail); nothing while down or after the finish.
func can_command(cmd: String) -> bool:
	var p := player
	if p == null or p.done or finished or p.down_left > 0.0:
		return false
	match cmd:
		"push", "hold", "ease":
			return not p.kicking
		"move_out":
			return p.d >= break_line and p.lat < float(_ctl.move_out.max_lat) - 0.2   # (already out wide: nothing to do)
		"kick":
			return p.d >= break_line and not p.kicking
	return false


## The action bar's commands (no pause): push / hold / ease (the pace until the kick), move_out (a few seconds
## on the outside going for a pass; boxed in it is "ease and step out"), kick (the kick starts now).
func command(cmd: String) -> bool:
	if not can_command(cmd):
		return false
	var p := player
	match cmd:
		"push", "hold", "ease":
			set_effort(cmd)
		"move_out":
			var mo: Dictionary = _ctl.move_out
			p.out_to = minf(p.lat + float(mo.lane), maxf(float(mo.max_lat), p.lat))   # (never back towards the rail)
			p.out_left = float(mo.seconds)
			if p.boxed and p.box_way == "wait":
				p.box_way = "ease"
				p.box_pending = false
		"kick":
			_start_kick(p, standings(), null)
	_say_line("bar." + cmd)
	return true


# --- Feeling, the coach and the slow-down moments (R3) ----------------------------------------------

## The word under the clock: the share of the reserve the player FEELS they have left (their race tactics
## misjudge it), less a little for fatigue. {id, word, index} (0 comfortable … 3 empty); data controls.feeling.
func feeling() -> Dictionary:
	var f: Dictionary = _ctl.feeling
	var share := _felt(player) / player.dprime \
			- maxf(0.0, _player_fatigue - float(f.fatigue_from)) * float(f.fatigue_per_point)
	var i := 0
	for t in f.thresholds:
		if share >= float(t):
			break
		i += 1
	return {"id": f.ids[i], "word": f.words[i], "index": i, "share": share}


## Can the coach see the player now? Outdoors he stands at one spot (controls.coach.spot_outdoor metres round the
## lap: the 200 m start, in the stands) and sees view_m along the track either way; indoors he stands on the
## rail of the hall and sees the whole track.
func coach_sees() -> bool:
	return player != null and coach_sees_at(player.d)


## Can the coach see what happens `d` metres into the race? (R4: his spot is the 200 m start outdoors (in the stands), the hall rail
## indoors; the commentary lets him speak only about what he can see.)
func coach_sees_at(d: float) -> bool:
	if indoor:
		return true
	var c: Dictionary = _ctl.coach
	var dist := absf(fmod(d, lap) - float(c.spot_outdoor))
	return minf(dist, lap - dist) <= float(c.view_m)


## The coach's shout for the card `id`, or {} when he can't see: {option, text}. He is right with chance
## controls.coach.accuracy. His dice come from the race's seed but not from its dice, so a watched race and a
## quick one stay comparable.
func _coach_line(id: String, info: Dictionary) -> Dictionary:
	if not coach_sees():
		return {}
	var shouts: Dictionary = Data.race_cards.coach.shouts.get(id, {})
	if shouts.is_empty():
		return {}
	var right := sensible_choice(id)
	var pick := right
	if _coach_rng == null:
		_coach_rng = RandomNumberGenerator.new()
		_coach_rng.seed = hash("coach %d" % _rng.state)   # (the state, not the seed: it differs from race to race)
	if _coach_rng.randf() >= float(_ctl.coach.accuracy):
		var others := shouts.keys().filter(func(k): return k != right)
		if not others.is_empty():
			pick = others[_coach_rng.randi_range(0, others.size() - 1)]
	# No advice that contradicts what he just said, unless the race has changed (playtest fix 4): the shout is dropped.
	var dir := str(Data.race_cards.coach.get("dir", {}).get(id, {}).get(pick, ""))
	if coach_conflicts(dir):
		return {}
	coach_note(dir)
	var wording: String = Coaches.shout(coach_id, id, pick, String(shouts[pick]))   # (his own words, R4)
	return {"option": pick, "text": wording.format({"name": _surname(str(info.get("name", "")))})}


## What the coach advised lately: [{t, dir (push / ease), pos, gap}], newest last (the card shouts and, through
## coach_note, the commentary's coach lines). Display only: nothing in the race depends on it.
var coach_dir_log: Array = []


func coach_note(dir: String) -> void:
	if dir == "" or player == null:
		return
	coach_dir_log.append({"t": time, "dir": dir, "pos": position_of(player), "gap": _gap_to_leader()})


## Would advice in direction `dir` (push / ease) contradict the coach's last advice, said within controls.coach.conflict_s
## seconds, with the race much the same since (the gap to the leader and the player's place have hardly changed)?
func coach_conflicts(dir: String) -> bool:
	if dir == "" or coach_dir_log.is_empty() or player == null:
		return false
	var last: Dictionary = coach_dir_log[-1]
	var c: Dictionary = _ctl.coach
	if last.dir == dir or time - float(last.t) > float(c.conflict_s):
		return false
	if absf(_gap_to_leader() - float(last.gap)) >= float(c.changed_gap_m) or absi(position_of(player) - int(last.pos)) >= int(c.changed_places):
		return false
	return true


func _gap_to_leader() -> float:
	var order := standings()
	return maxf(0.0, order[0].d - player.d) if not order.is_empty() else 0.0


## Has something happened since event number `from` that the race screen slows down for (a move, kick, contact,
## stumble or fall within range_m of the player, or the player being boxed in)? data controls.slow_motion.
func moment_since(from: int) -> bool:
	return not moment_event(from).is_empty()


## The first such event (see moment_since), or {}.
func moment_event(from: int) -> Dictionary:
	if player == null:
		return {}
	var sm: Dictionary = _ctl.slow_motion
	for k in range(from, events.size()):
		var ev: Dictionary = events[k]
		if not ev.has("d"):
			continue
		var t: String = ev.type
		if (t in sm.types or (ev.player and t in sm.types_player)) and absf(float(ev.d) - player.d) <= float(sm.range_m):
			return ev
	return {}


## Why the screen slowed down, in a few words ("Savolainen kicks", "you are boxed in"): data race_cards.json "moments".
func moment_text(ev: Dictionary) -> String:
	var line: String = Data.race_cards.moments.get(ev.get("type", ""), "")
	return line.format({"name": _surname(str(ev.get("who", ""))), "m": roundi(absf(float(ev.get("d", 0)) - player.d))})


# --- Helpers of the cards ---------------------------------------------------------------------------

static func _surname(full: String) -> String:
	return full.get_slice(" ", full.get_slice_count(" ") - 1)


## The placeholders of the "A rival makes a move" card: who, what, how far to go, and where they are.
func _move_ctx(mover: Runner, what: String) -> Dictionary:
	var ph: Dictionary = Data.race_cards.phrases
	var gap := mover.d - player.d
	var where: String = ph.where_beside
	if gap > 1.5:
		where = String(ph.where_ahead).format({"m": roundi(gap)})
	elif gap < -1.5:
		where = String(ph.where_behind).format({"m": roundi(-gap)})
	return {"mover": mover, "name": mover.name, "what": ph[what], "to_go": roundi(DISTANCE - mover.d), "where": where}


## A rival who is surging or kicking close to the player (controls.cards.box_move_m ahead / behind), or null.
func _find_mover(p: Runner) -> Runner:
	var range_m: Array = _ctl.cards.box_move_m
	var best: Runner = null
	for o in runners:
		if o == p or o.done or o.down_left > 0.0 or not (o.kicking or o.surge_left > 0.0):
			continue
		var gap := o.d - p.d
		if gap >= float(range_m[0]) and gap <= float(range_m[1]) and (best == null or absf(gap) < absf(best.d - p.d)):
			best = o
	return best


## "A move goes": a rival's move or kick close by, or the player's own (kick, surge, going with someone).
func _move_going(p: Runner) -> bool:
	return p.kicking or p.surge_left > 0.0 or p.covering != null or _find_mover(p) != null


## The sentence about the move for the box card.
func _move_context(p: Runner) -> String:
	var ph: Dictionary = Data.race_cards.phrases
	var m := _find_mover(p)
	if m == null:
		return ph.own_move
	return String(ph.rival_move).format({"name": _surname(m.name), "what": ph["kicks" if m.kicking else "surges"]})


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
