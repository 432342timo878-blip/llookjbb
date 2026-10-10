extends SceneTree
## Dev tool: the multi-year progression check (ROADMAP step 7, GDD 4.2 "Multi-year check"). Athletes of a few kinds play
## several seasons (default 7: 2 Nov 2026 to Oct 2033, age classes 15–21) through the real game loop: health and form on,
## the coach's Balanced plan (the offers answered "balanced", easing back in accepted, "sore" warnings answered "keep
## going"), the creation pool spent the coach's way (AthleteFactory.coach_spread), the coach-recommended meets of every
## season entered, and EVERY race run for real (quick mode, the "pack" plan: the same engine as a watched race).
## Kinds (fixed background stories, as in start_spread.gd): beginner (pool 6), average (pool 12), trained (pool 16),
## early / late (the average story with an early / late developer's answer), random (random answers). Boys and girls
## alternate. In a copy from before step 7 (meets for 3 seasons only) the tool extends the calendar itself.
## Prints, per kind and per season (by the age class of its summer): the player's ability, PB / SB, where they sit among
## the rivals (ability percentile, SB rank), key attributes (from Game.progress), races (places, fields), health (weekly
## prevalence of any problem / a substantial one / time loss, injuries, illnesses); the rivals' curves (ability and SB
## quantiles); national championship field sizes and finish gaps; race-day spread (time / table time) by age.
## Run (headless; ~1–2 min per athlete for 7 seasons; run at most 4 processes at a time):
##   godot --headless --path . -s res://tools/career_check.gd -- <athletes per kind> [kinds, e.g. beginner,trained] [seasons] [first seed] [rows] [norace]
## "rows" also prints every athlete's season lines; "norace" finishes race days without running them (~10× faster: abilities,
## health and rivals only). Athlete i of every kind has the same random rolls (only the story differs), so kinds are compared
## pair by pair (the experience trade: beginner vs trained). Races use their own random numbers (RaceDay), so two runs differ a little.

const START_YEAR := 2026
const STORIES := {
	"beginner": ["Never really exercised", "Nobody, it was your own idea", "Not sporty at all", "Nowhere yet",
			"About average", "No idea, I've never raced", "Doing fine"],
	"average": ["Football", "Friends from school", "Sporty family, recreational level", "A small-town outdoor track",
			"About average", "Feel nervous but manage it", "Doing fine"],
	"trained": ["Athletics school since I was little", "Your parents signed you up", "A parent competed in athletics",
			"A big club with an indoor hall", "About average", "Feel nervous but manage it", "Doing fine"],
	"early": ["Football", "Friends from school", "Sporty family, recreational level", "A small-town outdoor track",
			"Taller and stronger than most", "Feel nervous but manage it", "Doing fine"],
	"late": ["Football", "Friends from school", "Sporty family, recreational level", "A small-town outdoor track",
			"One of the smallest", "Feel nervous but manage it", "Doing fine"],
}
const KEY_ATTRS := ["speed_endurance", "aerobic_capacity", "lactate_threshold", "speed", "running_economy", "strength", "potential"]

var game
var data
var F
var RP
var Cal
var SP
var SS
var H
var RV
var RK
var seasons := 7
var print_rows := false
var no_races := false   # "norace": race days are finished without running the race (fast; abilities only, no times)
var recs := []       # one per athlete-season: see _season_rec
var races := []      # one per player race day: {kind, gender, age, level, ratio, place, field, status, entrants, gaps}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	RP = load("res://scripts/core/race_performance.gd")
	Cal = load("res://scripts/core/calendar.gd")
	SP = load("res://scripts/core/season_plan.gd")
	SS = load("res://scripts/core/season_system.gd")
	H = load("res://scripts/core/health_system.gd")
	RV = load("res://scripts/core/rivals.gd")
	RK = load("res://scripts/core/rankings.gd")
	var saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	H.model_enabled = true
	SS.offers_enabled = true
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 4
	var kinds: Array = Array(args[1].split(",")) if args.size() > 1 and args[1] != "all" else ["beginner", "average", "trained", "early", "late", "random"]
	seasons = int(args[2]) if args.size() > 2 else 7
	var first := int(args[3]) if args.size() > 3 else 0
	print_rows = "rows" in args
	no_races = "norace" in args
	for arg in args:   # what-ifs: training.progression.novice.bonus=1.1 (a data path = a number)
		if arg.contains("=") and arg.contains("."):
			var path := arg.split("=")[0].split(".")
			var d = data.get(path[0])
			for k in range(1, path.size() - 1):
				d = d[path[k]]
			d[path[-1]] = float(arg.split("=")[1])
			print("what-if: %s" % arg)
	_extend_calendar(seasons)
	var t0 := Time.get_ticks_msec()
	print("career_check: %d athletes per kind, kinds %s, %d seasons from Nov %d" % [n, kinds, seasons, START_YEAR])
	for kind in kinds:
		for i in n:
			_career(kind, first + i)
	print("%.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_report(kinds)
	print("career_check done")
	quit()


## Before step 7 the calendar kept only 3 seasons of meets (Calendar.SEASONS_AHEAD 2): then fill its cache with
## `count` + 1 seasons the way it made them (52 weeks apart), so a pre-step-7 copy can be measured too.
func _extend_calendar(count: int) -> void:
	if int(Cal.SEASONS_AHEAD) >= count:
		return
	var meets := []
	for season in count + 1:
		for c in data.competitions.competitions:
			var m: Dictionary = c.duplicate(true)
			m.date = game.add_days(Cal.parse_date(c.date), 364 * season)
			m.key = "%s@%d" % [c.id, m.date.year]
			if season > 0:
				m.estimated = true
			meets.append(m)
	meets.sort_custom(func(x, y): return Cal.date_key(x.date) < Cal.date_key(y.date))
	Cal._meets_cache = meets


func _athlete(kind: String, i: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + i * 7   # (the same rolls for every kind: pairs)
	var answers := {}
	if kind == "random":
		for q in data.background_questions:
			answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	else:
		for q in data.background_questions:
			for k in q.answers.size():
				if q.answers[k].text in STORIES[kind]:
					answers[q.id] = k
	var a = F.create({"first_name": "Test", "last_name": "%s%d" % [kind.capitalize(), i], "gender": "male" if i % 2 == 0 else "female",
			"hometown": "Tampere", "club_id": "tap", "main_event": "800m",
			"birth_date": {"year": 2012, "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)}, "answers": answers}, rng)
	F.spend(a, F.coach_spread(a, F.pool_for(answers)))
	return [a, F.pool_for(answers)]


func _career(kind: String, i: int) -> void:
	var made: Array = _athlete(kind, i)
	var a = made[0]
	seed(12345 + i * 31)   # the rivals' weekly training uses the global random numbers
	game.start_career(a, SP.PHASES, "balanced")
	var rrng := RandomNumberGenerator.new()
	rrng.seed = 777 + i
	game.rivals = RV.generate(a, rrng)
	var h = game.get_system("health")
	h.rng.seed = 7000 + i
	var st := {"kind": kind, "i": i, "gender": a.gender, "pool": made[1], "entered": {}, "health": {}, "potential": a.get_attr("potential"),
			"maturation": a.maturation}
	_answer()
	var start_ab: float = RP.ability(a)
	var y := START_YEAR
	var end_key: int = Cal.date_key(SP.season_start(START_YEAR + seasons))
	var guard := 0
	var prev := {"ability": start_ab, "pb": 0.0}
	while Cal.date_key(game.date) < end_key and guard < 400 * seasons:
		guard += 1
		var sy: int = SP.year_of(game.date)
		if sy != y:
			prev = _season_rec(st, y, prev)
			y = sy
		if not st.entered.has(sy) and Cal.date_key(game.date) == Cal.date_key(SP.season_start(sy)):
			st.entered[sy] = true
			_enter_recommended(sy)
		var out_before: int = int(h.counters.days_out)
		var r: String = game.advance_day()
		if r == game.RACE:
			if not no_races:
				_run_race(st)
			r = game.finish_race()
		_health_day(st, sy, out_before)
		_answer()
	_season_rec(st, y, prev)


## The season's record, at its end (the first day of the next season, before it is played).
func _season_rec(st: Dictionary, y: int, prev: Dictionary) -> Dictionary:
	var a = game.athlete
	var year: int = y + 1   # the season's summer / calendar year
	var ab: float = RP.ability(a)
	var pb: float = float(a.personal_bests.get("800m", 0.0))
	var sb: float = RK.player_season_best(a, year)
	var below := 0
	var rab := []
	for r in game.rivals:
		rab.append(float(r.ability))
		if float(r.ability) < ab:
			below += 1
	rab.sort()
	var list: Array = RK.season_list(a, game.rivals, year)
	var rank := 0
	var rsb := []
	for row in list:
		if row.is_player:
			rank = row.rank
		else:
			rsb.append(float(row.time))
	var attrs := {}
	for rec in game.progress:
		if int(rec.year) == year and int(rec.month) == 10:
			attrs = rec.attrs
	if attrs.is_empty():
		for id in KEY_ATTRS:
			attrs[id] = a.get_attr(id)
	var hs: Dictionary = st.health.get(y, {})
	var hh = game.get_system("health")
	var inj := 0
	var serious := 0
	var ill := 0
	for x in hh.history + hh.injuries:
		if SP.year_of(x.started) != y:
			continue
		if x.tier == "illness":
			ill += 1
		else:
			inj += 1
			serious += 1 if x.tier == "serious" else 0
	var my_races := races.filter(func(r): return r.athlete == "%s%d" % [st.kind, st.i] and r.season == y)
	var rec := {"kind": st.kind, "i": st.i, "gender": st.gender, "pool": st.pool, "season": y, "age": year - 2012,
			"ability": ab, "gain": ab - float(prev.ability), "pb": pb, "sb": sb, "pct": 100.0 * below / maxf(game.rivals.size(), 1),
			"rank": rank, "ranked": list.size(), "attrs": attrs, "rivals_ab": rab, "rivals_sb": rsb,
			"weeks": int(hs.get("weeks", 0)), "w_any": int(hs.get("w_any", 0)), "w_sub": int(hs.get("w_sub", 0)),
			"w_out": int(hs.get("w_out", 0)), "d_any": int(hs.get("d_any", 0)), "d_sub": int(hs.get("d_sub", 0)),
			"d_out": int(hs.get("d_out", 0)), "days": int(hs.get("days", 0)), "inj": inj, "serious": serious, "ill": ill,
			"races": my_races.size(), "potential": st.potential, "maturation": st.maturation}
	recs.append(rec)
	if print_rows:
		print("  %-9s #%d %s age %d: ability %5.2f (%+.2f) PB %s SB %s pct %3.0f rank %d/%d · rivals p50 %.2f p90 %.2f max %.2f · inj %d ill %d · races %d" % [
				st.kind, st.i, st.gender.left(1), rec.age, ab, rec.gain, _t(pb), _t(sb), rec.pct, rank, list.size(),
				_q(rab, 0.5), _q(rab, 0.9), rab[-1], inj, ill, my_races.size()])
	return {"ability": ab, "pb": pb}


## Health of the day just played: any problem (a sore area or an injury / illness), substantial (an injury or illness:
## every one limits training), time loss (running not allowed). Counted per day and per week (a week with one such day).
func _health_day(st: Dictionary, y: int, out_before: int) -> void:
	if game.day_log.is_empty():
		return
	var h = game.get_system("health")
	var e: Dictionary = game.day_log[-1]
	if not st.health.has(y):
		st.health[y] = {"days": 0, "d_any": 0, "d_sub": 0, "d_out": 0, "weeks": 0, "w_any": 0, "w_sub": 0, "w_out": 0, "wk": [false, false, false]}
	var s: Dictionary = st.health[y]
	var sub: bool = not e.get("health", []).is_empty()
	var any: bool = sub or not e.get("soreness", {}).is_empty()
	var out: bool = int(h.counters.days_out) > out_before
	s.days += 1
	s.d_any += 1 if any else 0
	s.d_sub += 1 if sub else 0
	s.d_out += 1 if out else 0
	s.wk = [s.wk[0] or any, s.wk[1] or sub, s.wk[2] or out]
	if Cal.weekday(Game_int(e.date)) == 6:
		s.weeks += 1
		s.w_any += 1 if s.wk[0] else 0
		s.w_sub += 1 if s.wk[1] else 0
		s.w_out += 1 if s.wk[2] else 0
		s.wk = [false, false, false]


func Game_int(d: Dictionary) -> Dictionary:
	return {"year": int(d.year), "month": int(d.month), "day": int(d.day)}


func _answer() -> void:
	var guard := 0
	while not game.pending_event().is_empty() and guard < 20:
		guard += 1
		var e: Dictionary = game.pending_event()
		var answer := "ok"
		match str(e.get("kind", "")):
			"offer": answer = "balanced"
			"return": answer = "accept"
			"sore": answer = "keep"
		game.answer_event(e.id, answer)


func _enter_recommended(year: int) -> void:
	var from: Dictionary = game.date
	for m in Cal.meets_between(from, game.add_days(SP.season_start(year + 1), -1)):
		if Cal.coach_recommends(game.athlete, m, from) and not m.key in game.entries:
			game.enter(m.key)


func _run_race(st: Dictionary) -> void:
	var rd = game.race_day
	var a = game.athlete
	var table: float = RP.time_for(RP.ability(a), a.gender)
	var entrants: int = rd._seed.size()
	var guard := 0
	while not rd.is_done() and guard < 8:
		guard += 1
		var race = rd.start_round(false, "pack")
		race.run()
		rd.finish_round()
	# Finish gaps of the fastest race of the meet (the top section or the final): 1st→2nd, →4th, →last finisher.
	var best: Array = []
	var best_t := 99999.0
	for res in rd.all_results:
		var t := []
		for row in res:
			if row.get("status", "") == "" and float(row.time) > 0.0:
				t.append(float(row.time))
		t.sort()
		if t.size() >= 6 and t[0] < best_t:
			best_t = t[0]
			best = t
	var gaps := [] if best.is_empty() else [best[1] - best[0], best[3] - best[0], best[-1] - best[0]]
	var y: int = SP.year_of(rd.meet.date)
	for pr in rd.player_results:
		var final_round: bool = pr == rd.player_results[-1]
		races.append({"athlete": "%s%d" % [st.kind, st.i], "kind": st.kind, "gender": st.gender, "season": y,
				"age": int(rd.meet.date.year) - 2012, "level": str(rd.meet.get("level", "")), "meet": str(rd.meet.id),
				"ratio": float(pr.time) / table if float(pr.time) > 0.0 else 0.0, "place": int(pr.place), "field": int(pr.field),
				"status": str(pr.get("status", "")), "entrants": entrants, "gaps": gaps if final_round else [],
				"form": rd.form, "slow": rd.slowdown, "fatigue": rd.fatigue, "round": str(pr.round)})


# --- Report ---------------------------------------------------------------------------------------------------------

func _report(kinds: Array) -> void:
	var ages := []
	for r in recs:
		if not r.age in ages:
			ages.append(r.age)
	ages.sort()
	for g in ["male", "female"]:
		print("\n=== %s ===" % ("BOYS" if g == "male" else "GIRLS"))
		for kind in kinds:
			var rows := recs.filter(func(r): return r.kind == kind and r.gender == g)
			if rows.is_empty():
				continue
			var pools := rows.map(func(r): return r.pool)
			print("\n-- %s (%d athletes, pool %s, potential median %.1f)" % [kind, rows.size() / maxi(ages.size(), 1), pools[0],
					_q(rows.map(func(r): return r.potential), 0.5)])
			print("  age  ability (p25–p75)    gain   PB median (p25–p75)          SB median  rival pct (p25–p75)  SB rank   races  injuries  ill  weeks any/sub/out")
			for age in ages:
				var a := rows.filter(func(r): return r.age == age)
				if a.is_empty():
					continue
				var ab := a.map(func(r): return r.ability)
				var pb := a.map(func(r): return r.pb).filter(func(x): return x > 0.0)
				var sb := a.map(func(r): return r.sb).filter(func(x): return x > 0.0)
				var pct := a.map(func(r): return r.pct)
				var rk := a.map(func(r): return "%d/%d" % [r.rank, r.ranked])
				print("  %3d  %5.2f (%5.2f–%5.2f) %+5.2f  %s (%s–%s)  %s   %3.0f (%3.0f–%3.0f)    %-8s %5.1f   %5.2f  %4.2f  %3.0f/%3.0f/%3.0f %%" % [age,
						_mean(ab), _q(ab, 0.25), _q(ab, 0.75), _mean(a.map(func(r): return r.gain)),
						_t(_q(pb, 0.5)), _t(_q(pb, 0.25)), _t(_q(pb, 0.75)), _t(_q(sb, 0.5)),
						_q(pct, 0.5), _q(pct, 0.25), _q(pct, 0.75), rk[a.size() / 2], _mean(a.map(func(r): return r.races)),
						_mean(a.map(func(r): return r.inj)), _mean(a.map(func(r): return r.ill)),
						100.0 * _sum(a.map(func(r): return r.w_any)) / maxf(_sum(a.map(func(r): return r.weeks)), 1),
						100.0 * _sum(a.map(func(r): return r.w_sub)) / maxf(_sum(a.map(func(r): return r.weeks)), 1),
						100.0 * _sum(a.map(func(r): return r.w_out)) / maxf(_sum(a.map(func(r): return r.weeks)), 1)])
			print("  attributes at the end of October (mean):")
			var head := "  age " + " ".join(KEY_ATTRS.map(func(id): return "%8s" % id.left(8)))
			print(head)
			for age in ages:
				var a := rows.filter(func(r): return r.age == age)
				if a.is_empty():
					continue
				var line := "  %3d " % age
				for id in KEY_ATTRS:
					line += " %8.2f" % _mean(a.map(func(r): return float(r.attrs.get(id, 0.0))))
				print(line)
		# The rivals (every career has its own pool of 150; quantiles over all of them)
		var all := recs.filter(func(r): return r.gender == g)
		if all.is_empty():
			continue
		print("\n-- rivals (%s pools)" % ("boys'" if g == "male" else "girls'"))
		print("  age  ability p10   p25   p50   p75   p90   max   | SB 1st     3rd      8th      20th     50th     | with SB")
		for age in ages:
			var a := all.filter(func(r): return r.age == age)
			if a.is_empty():
				continue
			var qs := {0.1: [], 0.25: [], 0.5: [], 0.75: [], 0.9: [], 1.0: []}
			var sbq := {0: [], 2: [], 7: [], 19: [], 49: []}
			var n_sb := []
			for r in a:
				for q in qs:
					qs[q].append(_q(r.rivals_ab, q))
				var s: Array = r.rivals_sb
				for k in sbq:
					if s.size() > k:
						sbq[k].append(s[k])
				n_sb.append(s.size())
			print("  %3d        %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f | %s %s %s %s %s | %.0f" % [age, _mean(qs[0.1]), _mean(qs[0.25]), _mean(qs[0.5]),
					_mean(qs[0.75]), _mean(qs[0.9]), _mean(qs[1.0]), _t(_mean(sbq[0])), _t(_mean(sbq[2])), _t(_mean(sbq[7])),
					_t(_mean(sbq[19])), _t(_mean(sbq[49])), _mean(n_sb)])
		print("  (ability → time: %s)" % ", ".join([5, 7, 9, 11, 13, 15].map(func(x): return "%d = %s" % [x, _t(RP.time_for(x, g))])))
	_pairs(kinds, ages)
	_race_report(ages)


## The experience trade (GDD 4.1.1): each kind against "trained" with the same rolls (athlete i of both kinds): the
## mean ability gap and in how many pairs the other kind is ahead.
func _pairs(kinds: Array, ages: Array) -> void:
	if not "trained" in kinds:
		return
	print("\n=== PAIRS (same rolls, only the story differs): ability minus the trained athlete's, ahead in n of pairs")
	for kind in kinds:
		if kind == "trained" or kind == "random":
			continue
		var line := "  %-9s" % kind
		for age in ages:
			var gaps := []
			for r in recs:
				if r.kind != kind or r.age != age:
					continue
				for t in recs:
					if t.kind == "trained" and t.age == age and t.i == r.i:
						gaps.append(r.ability - t.ability)
			if not gaps.is_empty():
				line += "  %d: %+.2f (%d/%d)" % [age, _mean(gaps), gaps.filter(func(x): return x > 0.0).size(), gaps.size()]
		print(line)


func _race_report(ages: Array) -> void:
	print("\n=== RACES (the player's) ===")
	print("  age  races  wins  last  place/field (median)   time/table: mean  sd     | national meets: entrants (min–max)  | top race gaps 1→2 / 1→4 / 1→last")
	for age in ages:
		var a := races.filter(func(r): return r.age == age)
		if a.is_empty():
			continue
		var fin := a.filter(func(r): return r.status == "")
		var ratio := fin.map(func(r): return r.ratio)
		var nat := a.filter(func(r): return r.level == "national")
		var ent := nat.map(func(r): return r.entrants)
		var gaps := a.filter(func(r): return r.level == "national" and not r.gaps.is_empty())
		var pf := a.map(func(r): return float(r.place) / maxf(r.field, 1))
		print("  %3d  %5d  %4d  %4d  %.2f                    %.3f %.1f %%    | %5.1f (%s–%s) in %d meets       | %.2f / %.2f / %.2f s (%d)" % [age, a.size(),
				a.filter(func(r): return r.place == 1).size(), a.filter(func(r): return r.place == r.field).size(), _q(pf, 0.5),
				_mean(ratio), 100.0 * _sd(ratio), _mean(ent), str(_q(ent, 0.0)) if not ent.is_empty() else "-",
				str(_q(ent, 1.0)) if not ent.is_empty() else "-", nat.size(),
				_mean(gaps.map(func(r): return r.gaps[0])), _mean(gaps.map(func(r): return r.gaps[1])), _mean(gaps.map(func(r): return r.gaps[2])), gaps.size()])
	print("  national meets by id: entrants (mean) per age")
	var ids := {}
	for r in races:
		if r.level == "national":
			var k := "%s %d" % [r.meet, r.age]
			if not ids.has(k):
				ids[k] = []
			ids[k].append(r.entrants)
	var keys := ids.keys()
	keys.sort()
	for k in keys:
		print("    %-28s %5.1f (%d)" % [k, _mean(ids[k]), ids[k].size()])
	# Race-day spread for healthy, fresh races, by age (decision 12: seniors' consistency)
	print("  race-day spread, healthy and not tired (time / table time): age  races  mean   sd")
	for age in ages:
		var v := races.filter(func(r): return r.age == age and r.status == "" and r.slow == 0.0 and r.fatigue <= 25.0).map(func(r): return r.ratio)
		if v.size() > 2:
			print("    %3d  %4d  %.3f  %.2f %%" % [age, v.size(), _mean(v), 100.0 * _sd(v)])


# --- Helpers ---------------------------------------------------------------------------------------------------------

func _q(v: Array, p: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return float(s[clampi(int(p * (s.size() - 1) + 0.5), 0, s.size() - 1)])


func _mean(v: Array) -> float:
	if v.is_empty():
		return 0.0
	return _sum(v) / v.size()


func _sum(v: Array) -> float:
	var s := 0.0
	for x in v:
		s += float(x)
	return s


func _sd(v: Array) -> float:
	if v.size() < 2:
		return 0.0
	var m := _mean(v)
	var s := 0.0
	for x in v:
		s += pow(float(x) - m, 2)
	return sqrt(s / v.size())


func _t(sec: float) -> String:
	if sec <= 0.0:
		return "   -    "
	return "%d:%05.2f" % [int(sec) / 60, fmod(sec, 60.0)]
