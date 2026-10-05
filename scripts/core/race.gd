class_name Race
extends RefCounted
## One 800 m race, simulated in small time steps on a real track: outdoor 400 m (8 lanes) or indoor 200 m (6 lanes).
##
## Each runner has a sustainable speed (cs) and an anaerobic reserve (dprime, in metres): running faster than
## cs drains the reserve, running behind someone (drafting) drains it a little slower, and an empty reserve
## means tying up. The player's choices (detailed mode) arrive at decision points; in quick mode the athlete
## decides on their own based on race tactics.

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

var _asked := {}
var _rng: RandomNumberGenerator
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
	var d := 0.0                  # distance run (lane 1 equivalent)
	var v := 0.0
	var lat := 0.0                # metres outside the lane 1 line
	var lat_target := 0.0
	var plan := "pack"            # front / pack / back
	var pace_factor := 1.0
	var kick_at := 200.0          # metres to go when the kick starts
	var kicking := false
	var drafting := false
	var t := 0.0                  # finish time
	var done := false
	var split_400 := 0.0


## `entrants`: Dictionaries with name, club, ability, speed, anaerobic, tactics, consistency, composure
## (+ is_player, rival). `big_meet` makes composure matter. `player_fatigue` 0–100.
func setup(entrants: Array, gender: String, big_meet: bool, player_fatigue: float, rng: RandomNumberGenerator,
		indoor_track := false) -> void:
	_rng = rng
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
	lane_order.shuffle()
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
		var share := clampf(0.18 + 0.006 * float(e.anaerobic), 0.13, 0.23)
		r.dprime = DISTANCE * share
		r.dleft = r.dprime
		# The standing start costs ~1.5 s, so the cruising speed is set a little higher.
		r.cs = (DISTANCE - r.dprime) / (r.even_time - 1.5)
		var top := (6.4 + 0.17 * r.speed) if gender == "male" else (5.9 + 0.15 * r.speed)
		r.vmax = maxf(top, r.cs * 1.2)
		# Kickers (big reserve) wait; grinders go long. Better tacticians time it better.
		r.kick_at = clampf(210.0 - float(e.anaerobic) * 15.0 + rng.randfn(0.0, 45.0 - r.tactics * 1.5), 100.0, 330.0)
		var roll := rng.randf()
		if float(e.anaerobic) < -1.5 and roll < 0.5:
			r.plan = "front"
		elif float(e.anaerobic) > 1.5 and roll < 0.5:
			r.plan = "back"
		else:
			r.plan = ["front", "pack", "pack", "back"][rng.randi() % 4]
		r.lat = (r.lane - 1) * LANE_W
		r.d = 0.0
		r.lat_target = r.lat
		runners.append(r)
		if r.is_player:
			player = r


## The player's pre-race plan: "front", "pack" or "back".
func set_player_plan(plan: String) -> void:
	if player:
		player.plan = plan


## Runs until a decision is needed (detailed mode) or the race is over.
func run() -> void:
	while not finished and pending.is_empty():
		step()


func step() -> void:
	time += DT
	var order := standings()
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
	var rem := DISTANCE - r.d
	var lap_factor: float
	if r.d < 400.0:
		lap_factor = {"front": 1.05, "pack": 1.03, "back": 1.01}[r.plan]
	else:
		lap_factor = 0.985
	var target := DISTANCE / r.even_time * lap_factor * r.pace_factor
	r.drafting = false

	if r.d >= break_line:
		var ahead := _runner_ahead(r, order)
		if r.plan == "front" and ahead != null and r.d < 600.0:
			target *= 1.02   # work towards the front
		if ahead != null:
			var gap := ahead.d - r.d
			if gap < 2.0 and absf(ahead.lat - r.lat) < 0.9:
				r.drafting = true
				var wants_past := r.kicking or target > ahead.v * 1.02
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

	if not r.kicking and rem <= r.kick_at:
		r.kicking = true
	if r.kicking:
		# Fastest speed the remaining reserve can hold to the line: rem / (rem - dleft) times cs.
		if rem <= r.dleft + 1.0:
			target = r.vmax * 0.95
		else:
			target = minf(r.vmax * 0.95, maxf(r.cs * rem / (rem - r.dleft), r.cs))
	if r.dleft <= 0.0:
		target = minf(target, r.cs * (0.97 - 0.05 * clampf(-r.dleft / 20.0, 0.0, 1.0)))

	var accel := 4.0 if r.d < 30.0 else 1.2
	if r.v < target:
		r.v = minf(target, r.v + accel * DT)
	else:
		r.v = maxf(target, r.v - 1.5 * DT)

	if r.v > r.cs:
		r.dleft -= (r.v - r.cs) * DT * (0.93 if r.drafting else 1.0)
	else:
		r.dleft = minf(r.dprime, r.dleft + (r.cs - r.v) * DT * 0.25)

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
			return {"front": "lead", "pack": "shoulder", "back": "back"}[p.plan]
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
			p.plan = "front"
			_say("You go to the front.")
		["break", "shoulder"]:
			p.plan = "pack"
			_say("You settle on the leader's shoulder.")
		["break", "back"]:
			p.plan = "back"
			p.pace_factor = 0.99
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
