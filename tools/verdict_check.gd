extends SceneTree
## Check of the coach's verdicts and proposals (GDD 4.9.2 "Ask the coach" / "Proposals and the veto", session C4;
## CoachVerdict, CoachProposals, data/coaching.json verdict / proposals, data/coach_talk.json verdict / proposal):
## 1. the data: every verdict, reason, voice, compare key, setting and veto reason has its text;
## 2. sanity cases of THE TRUTH (a rest day on a fresh day loses training, a hard day on painful legs is Risky, hard work the
##    day before a race costs Form, scratching with loaded legs lowers the risk);
## 3. the coach's view against the truth over many real situations of a season (two careers, every candidate change of the
##    coming days, some with extra soreness): agreement by attribute level 5 / 10 / 15 / 20 (a 20 nearly always right, a 5
##    often wrong, and wrong both ways), the demands bias (a steady coach likes lighter days more, an ambitious one less);
## 4. proposals through the game (a season-plan career, health and moments on, every stop answered): only unplayed non-race
##    days (scratch advice only race days still to come), at most max_per_week a week and one a day, OK changes the day
##    (by = "coach"), a veto keeps the plan, "Always" changes the day and Veto in the day editor puts the plan back, a silent
##    veto from the third within four weeks costs trust, the Sunday talk's request leads to a proposal or a "no";
## 5. "Never" changes nothing (the same career with the proposals off and on "Never": identical days and attributes), and
##    "Ask me first" with every proposal vetoed changes nothing either;
## 6. save / load: a career with proposals saved mid-week and loaded goes on exactly as without saving.
## Run: godot --headless --path . -s res://tools/verdict_check.gd [-- <weeks for parts 3-4, default 16>]
## NOTE: read stderr too: a SCRIPT ERROR does not change the "ALL CHECKS PASSED" line.

var game
var data
var F
var V
var P
var H
var MS
var Cal
var C
var SS
var WP
var saves
var _fails := 0
var weeks := 16


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/core/athlete_factory.gd")
	V = load("res://scripts/core/coach_verdict.gd")
	P = load("res://scripts/core/coach_proposals.gd")
	H = load("res://scripts/core/health_system.gd")
	MS = load("res://scripts/core/storylet_system.gd")
	Cal = load("res://scripts/core/calendar.gd")
	C = load("res://scripts/core/coach_system.gd")
	SS = load("res://scripts/core/season_system.gd")
	WP = load("res://scripts/core/week_plan.gd")
	saves = load("res://scripts/core/save_game.gd")
	saves.DIR = "user://tool_saves/"
	data = root.get_node("/root/Data")
	game = root.get_node("/root/Game")
	game.autosave = false
	# Lab (the moods in the middle, no life load) with the health model on, real club coaches and no "three plans" stop.
	load("res://scripts/core/game_config.gd").use("lab", {"health": true, "coach_neutral": false, "season_offers": false})
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			weeks = arg.to_int()
	var t0 := Time.get_ticks_msec()
	_data_checks()
	_sanity()
	_accuracy()
	_proposals_ask()
	_proposals_always()
	_scratch_advice()
	_neutral()
	_save_load()
	P.enabled = false
	MS.talks_enabled = false
	print("\n(%.0f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(what: String, passed: bool) -> void:
	print(("  PASS  " if passed else "  FAIL  ") + what)
	if not passed:
		_fails += 1


func _athlete(i: int, gender := ""):
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + i
	var answers := {}
	for q in data.background_questions:
		answers[q.id] = rng.randi_range(0, q.answers.size() - 1)
	var g := gender if gender != "" else ("male" if i % 2 == 0 else "female")
	return F.create({
		"first_name": "Test", "last_name": "Runner%d" % i, "gender": g, "hometown": "Tampere", "club_id": "tap",
		"main_event": "800m", "birth_date": {"year": 2012, "month": rng.randi_range(1, 10), "day": rng.randi_range(1, 28)},
		"answers": answers}, rng)


## A career with fixed dice: health, moments and proposals seeded from `i`.
func _career(i: int, mode: String, variant := "") -> void:
	game.start_career(_athlete(i), mode, variant)
	game.get_system("health").rng.seed = 900 + i
	game.get_system("moments").rng.seed = 1900 + i
	game.get_system("proposals").rng.seed = 2900 + i


## A coach of `level` in every attribute.
func _coach(level: int, demands := "balanced", tag := "") -> Dictionary:
	var attrs := {}
	for at in data.coaching.attributes:
		attrs[at.id] = level
	return {"id": "test%d%s%s" % [level, demands, tag], "attributes": attrs, "demands": demands, "voice": "calm"}


## Plays today: a race is finished without being run (as season_check does); stop events are answered by `answer`.
func _play(answer: Callable) -> String:
	var r: String = game.advance_day()
	if r == game.RACE:
		r = game.finish_race()
	var guard := 0
	while not game.pending_event().is_empty() and guard < 20:
		guard += 1
		var e: Dictionary = game.pending_event()
		game.answer_event(e.id, answer.call(e))
	return r


## The default answer: a moment by its id's hash, a "sore" warning = keep going, anything else "ok".
func _answer_any(e: Dictionary) -> String:
	if str(e.get("kind", "")) == "moment" and not e.choices.is_empty():
		return str(e.choices[posmod(e.id.hash(), e.choices.size())].id)
	if str(e.get("kind", "")) == "sore":
		return "keep"
	return "ok"


# --- 1. Data -----------------------------------------------------------------------------------------

func _data_checks() -> void:
	print("== 1. Data (coaching.json verdict / proposals, coach_talk.json verdict / proposal)")
	var v: Dictionary = data.coach_talk.verdict
	var reasons := ["rest", "fresh", "work", "race", "risk", "form", "lose_work", "form_loss", "bit_risky", "nothing", "fine", "tradeoff"]
	_ok("every verdict has a word", V.ORDER.all(func(x): return str(v.words.get(x, "")) != ""))
	var ok := true
	for r in reasons:
		ok = ok and v.reasons.has(r) and not v.reasons[r].is_empty() and str(v.short.get(r, "")) != "" and str(v.detail.get(r, "")) != ""
	_ok("every reason has texts, a short and a detail line", ok)
	ok = true
	for voice in data.coaches.pool:
		for x in V.ORDER:
			ok = ok and str(v.voice.get(voice, {}).get(x, "")) != ""
	_ok("every voice of the pool has an opening word for every verdict", ok)
	ok = true
	for k in ["day_changed", "day_plan", "day_rest", "race", "week_changed", "week_plan", "phase_changed", "phase_plan"]:
		ok = ok and str(v.compare.get(k, "")) != ""
	_ok("every compare key has a text", ok)
	var p: Dictionary = data.coach_talk.proposal
	ok = true
	for voice in data.coaches.pool:
		ok = ok and str(p.intro.get(voice, "")) != ""
		for k in ["accept", "veto", "silent"]:
			ok = ok and str(p.answered.get(voice, {}).get(k, "")) != ""
	_ok("every voice has an intro and three answers", ok)
	ok = true
	for m in data.coaching.proposals.modes:
		ok = ok and str(p.settings.get(m, {}).get("name", "")) != "" and str(p.settings.get(m, {}).get("text", "")) != ""
	_ok("every setting has a name and a text", ok)
	_ok("the default setting is one of the modes", str(data.coaching.proposals.default_mode) in data.coaching.proposals.modes)
	ok = true
	for k in ["lighter", "heavier", "scratch"]:
		ok = ok and not p.veto_reasons.get(k, []).is_empty()
		for r in p.veto_reasons.get(k, []):
			ok = ok and str(r.id) != "none"
	_ok("veto reasons for lighter / heavier / scratch, none called 'none'", ok)
	_ok("the easy and light sessions exist", not data.get_session(str(data.coaching.proposals.easy_session)).is_empty()
			and not data.get_session(str(data.coaching.proposals.light_session)).is_empty())
	_ok("'proposal' is a known moment effect", "proposal" in data.moments.effects.known)
	_ok("the proposal stop caption exists", str(data.moments.ui.get("stop_head_proposal", "")) != "")


# --- 2. Sanity cases of the truth -----------------------------------------------------------------------

## The first day from today with a session tagged hard or speed, or -1.
func _hard_day(w) -> int:
	for d in range(w.day, 7):
		if w.can_change(d) and P._hardest(w.session_ids(d)) != "":
			return d
	return -1


func _sanity() -> void:
	print("\n== 2. Sanity cases of the truth (the game plays both on copies)")
	H.model_enabled = true
	_career(1, "repeat")
	game.season.repeat_week = WP.coach()
	var w = game.current_week()
	var d := _hard_day(w)
	_ok("the coach week has a hard day", d >= 0)
	var cur: Dictionary = V.day_now(w, d)
	var t0 := Time.get_ticks_usec()
	var rest: Dictionary = V.truth(V.day_change({d: cur}, {d: {"sessions": [], "intensity": cur.intensity}}))
	print("     (one truth: %.0f ms)" % ((Time.get_ticks_usec() - t0) / 1000.0))
	print("     fresh, %s -> rest: train %+.2f risk %+.2f form %+.2f = %s (%s)" % [_dn(d), rest.train_w, rest.risk_w, rest.form_w, rest.verdict, rest.reason])
	_ok("fresh: a rest day instead of the hard session loses training (train < 0)", rest.train_w < 0.0)
	_ok("fresh: ... and is Pointless", rest.verdict == V.POINTLESS)
	var easy: Dictionary = V.truth(V.day_change({d: cur}, {d: {"sessions": cur.sessions, "intensity": "easy"}}))
	print("     fresh, %s -> Easy: train %+.2f risk %+.2f = %s (%s)" % [_dn(d), easy.train_w, easy.risk_w, easy.verdict, easy.reason])
	_ok("fresh: Easy loses less than a rest day", easy.train_w > rest.train_w)
	# Painful legs: every area at the painful strain level.
	var h = game.get_system("health")
	h._ensure_started()
	var saved: Dictionary = h.strain.duplicate()
	var painful := float(data.health.soreness.levels[2]) * 1.15
	for area in H.areas():
		h.strain[area.id] = painful
	var keep: Dictionary = V.truth(V.for_day(d))   # (the day as planned against a rest day)
	print("     painful, %s as planned vs rest: train %+.2f risk %+.2f = %s (%s)" % [_dn(d), keep.train_w, keep.risk_w, keep.verdict, keep.reason])
	_ok("painful: the hard day as planned is Risky", keep.verdict == V.RISKY and keep.reason == "risk")
	var ease: Dictionary = V.truth(V.day_change({d: cur}, {d: {"sessions": [], "intensity": cur.intensity}}))
	_ok("painful: a rest day instead is a Good idea (rest)", ease.verdict == V.GOOD and ease.reason == "rest")
	h.strain = saved
	# Hard work the day before a race: the season plan's first race.
	_career(2, "phases", "balanced")
	var found := false
	for _i in 120:
		w = game.current_week()
		var tomorrow: int = w.day + 1
		if tomorrow < 7 and w.is_race_day(tomorrow) and w.can_change(w.day) and not w.session_ids(w.day).is_empty():
			found = true
			break
		_play(_answer_any)
	_ok("the season plan reaches a day before a race", found)
	if found:
		var today: Dictionary = V.day_now(w, w.day)
		var hard: Dictionary = V.truth(V.day_change({w.day: today}, {w.day: {"sessions": ["intervals_800"], "intensity": "hard"}}))
		print("     day before %s, hard 800s: train %+.2f risk %+.2f form %+.2f = %s (%s)" % [hard.meet, hard.train_w, hard.risk_w, hard.form_w, hard.verdict, hard.reason])
		_ok("the day before a race: hard 800s cost Form (form < 0)", hard.form_w < 0.0)
		_ok("... and are not a Good idea", hard.verdict != V.GOOD)
		h = game.get_system("health")
		h._ensure_started()
		saved = h.strain.duplicate()
		for area in H.areas():
			h.strain[area.id] = painful
		var scratch: Dictionary = V.truth(V.race_change(w.day + 1))
		print("     painful, scratch %s: risk %+.2f race %+.2f = %s (%s)" % [scratch.meet, scratch.risk_w, scratch.race_w, scratch.verdict, scratch.reason])
		_ok("painful: scratching lowers the injury risk (risk > 0) and loses the race (race < 0)", scratch.risk_w > 0.0 and scratch.race_w < 0.0)
		h.strain = saved
	_ok("lighter_of makes Hard -> Normal -> Easy", V.lighter_of(WP.make([["easy_run"], ["intervals_800"], [], [], [], [], []],
			["easy", "hard", "normal", "normal", "normal", "normal", "normal"])).intensity == ["easy", "normal", "easy", "easy", "easy", "easy", "easy"])
	_ok("lighter_of an all-Easy week = a week of rest", V.lighter_of(WP.make([["easy_run"], [], [], [], [], [], []],
			["easy", "easy", "easy", "easy", "easy", "easy", "easy"])).days.all(func(x): return x.is_empty()))
	_ok("classify: a big risk is Risky whatever the gain", V.classify(5.0, -1.0, 0.0).verdict == V.RISKY)
	_ok("classify: a small gain is Fine, a big one Good", V.classify(0.05, 0.0, 0.0).verdict == V.FINE and V.classify(0.5, 0.0, 0.0).verdict == V.GOOD)


func _dn(d: int) -> String:
	return str(data.moments.day_names[d])


# --- 3. The coach's view against the truth ----------------------------------------------------------------

## Real situations: two season-plan careers played for `weeks`; every other morning every candidate change (lighter and
## heavier) of today and the next two days, and every race day's race-or-scratch; every third sample with extra soreness.
func _situations() -> Array:
	var out := []
	var sample := 0
	for k in 2:
		_career(10 + k, "phases", "ambitious" if k == 0 else "balanced")
		var h = game.get_system("health")
		for day in weeks * 7:
			var w = game.current_week()
			if day % 2 == 0:
				h._ensure_started()
				var saved: Dictionary = h.strain.duplicate()
				sample += 1
				if sample % 3 == 0:
					for area in H.areas():
						h.strain[area.id] = float(h.strain[area.id]) * 1.6 + 15.0
				for d in range(w.day, mini(7, w.day + 3)):
					if w.is_race_day(d):
						out.append({"t": V.truth(V.for_race(d)), "dir": "race"})
						continue
					if not w.can_change(d):
						continue
					var cur: Dictionary = V.day_now(w, d)
					for dir in ["lighter", "heavier"]:
						for cand in P.candidates(w, d, dir, false):
							out.append({"t": V.truth(V.day_change({d: cur}, {d: cand})), "dir": dir})
				h.strain = saved
			_play(_answer_any)
	return out


func _accuracy() -> void:
	print("\n== 3. The coach's view against the truth (%d weeks of two careers)" % weeks)
	var t0 := Time.get_ticks_msec()
	var sits := _situations()
	print("     %d changes judged in %.0f s" % [sits.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	var by_truth := {}
	var reasons := {}
	for s in sits:
		by_truth[s.t.verdict] = int(by_truth.get(s.t.verdict, 0)) + 1
		reasons[s.t.reason] = int(reasons.get(s.t.reason, 0)) + 1
	print("     the truth: %s" % _shares(by_truth, sits.size()))
	print("     reasons:   %s" % _shares(reasons, sits.size()))
	_ok("the truth uses every verdict", V.ORDER.all(func(x): return by_truth.has(x)))
	var samples := 12
	var agree := {}
	for level in [5, 10, 15, 20]:
		var same := 0
		var good_when_bad := 0
		var bad_when_good := 0
		var n_bad := 0
		var n_good := 0
		var conf := {}
		for i in sits.size():
			var t: Dictionary = sits[i].t
			for k in samples:
				var coach := _coach(level, "balanced", str(k))
				var r: Dictionary = V.perceive(t, coach, ("%d|%d|%d" % [level, i, k]).hash())
				if r.verdict == t.verdict:
					same += 1
				var key := "%s>%s" % [t.verdict.left(4), r.verdict.left(4)]
				conf[key] = int(conf.get(key, 0)) + 1
				if t.verdict in [V.POINTLESS, V.RISKY]:
					n_bad += 1
					if r.verdict == V.GOOD:
						good_when_bad += 1
				if t.verdict == V.GOOD:
					n_good += 1
					if r.verdict in [V.POINTLESS, V.RISKY]:
						bad_when_good += 1
		agree[level] = float(same) / (sits.size() * samples)
		print("     level %2d: agrees %3d%% | says Good when it is Pointless/Risky %3d%% | says Pointless/Risky when it is Good %3d%%" % [
				level, roundi(agree[level] * 100), roundi(100.0 * good_when_bad / maxi(1, n_bad)), roundi(100.0 * bad_when_good / maxi(1, n_good))])
		if level == 5:
			_ok("level 5 is wrong both ways (each at least 5 %)", float(good_when_bad) / maxi(1, n_bad) >= 0.05 and float(bad_when_good) / maxi(1, n_good) >= 0.05)
	_ok("a coach of 20 is nearly always right (>= 90 %%: %d %%)" % roundi(agree[20] * 100), agree[20] >= 0.9)
	_ok("a coach of 5 is often wrong (<= 70 %%: %d %%)" % roundi(agree[5] * 100), agree[5] <= 0.7)
	_ok("better coaches agree more (5 < 10 < 15 < 20)", agree[5] < agree[10] and agree[10] < agree[15] and agree[15] < agree[20])
	# The demands bias: lighter changes the truth calls Good / Fine, judged by coaches of 15.
	var share := {}
	for dm in ["steady", "balanced", "ambitious"]:
		var good := 0
		var n := 0
		for i in sits.size():
			if sits[i].dir != "lighter":
				continue
			for k in samples:
				var r: Dictionary = V.perceive(sits[i].t, _coach(15, dm, str(k)), ("dm|%d|%d" % [i, k]).hash())
				n += 1
				if r.verdict == V.GOOD:
					good += 1
		share[dm] = float(good) / maxi(1, n)
	print("     lighter changes called Good by a coach of 15: steady %d %%, balanced %d %%, ambitious %d %%" % [
			roundi(share.steady * 100), roundi(share.balanced * 100), roundi(share.ambitious * 100)])
	_ok("a steady coach likes lighter days more, an ambitious one less", share.steady > share.balanced and share.balanced > share.ambitious)
	# The same question on the same day gets the same answer.
	_career(3, "repeat")
	var w = game.current_week()
	var d := _hard_day(w)
	var j1: Dictionary = V.judge(V.for_day(d), _coach(8))
	var j2: Dictionary = V.judge(V.for_day(d), _coach(8))
	_ok("the same question on the same day gets the same answer and text", j1.verdict == j2.verdict and j1.text == j2.text and j1.text != "")
	print("     e.g. \"%s\" (%s)" % [j1.text, j1.compare])


func _shares(counts: Dictionary, total: int) -> String:
	var parts := []
	for k in counts:
		parts.append("%s %d%%" % [k, roundi(100.0 * counts[k] / maxi(1, total))])
	return ", ".join(parts)


# --- 4. Proposals through the game ---------------------------------------------------------------------

## A system that runs after the proposals and checks each new one against the week as it is when it is made.
class Watcher extends RefCounted:
	var cp
	var seen := 0
	var bad := []
	var game


	func check(where: String) -> void:
		var w = game.current_week()
		while seen < cp.fired.size():
			var p: Dictionary = cp.fired[seen]
			seen += 1
			for x in p.days:
				if str(p.monday) != str(w.monday):
					bad.append("%s: %s not in this week" % [where, p.id])
				elif p.kind == "scratch":
					if not w.is_race_day(int(x.d)) or int(x.d) < w.day:
						bad.append("%s: %s scratch advice for a day that is no race to come" % [where, p.id])
				elif int(x.d) < w.day or w.is_race_day(int(x.d)):
					bad.append("%s: %s changes a played day or a race day" % [where, p.id])


func _proposals_ask() -> void:
	print("\n== 4. Proposals through the game: 'Ask me first' (%d weeks, health, moments and the Sunday talk on)" % weeks)
	P.enabled = true
	MS.talks_enabled = true
	H.model_enabled = true
	var results := {"accept": 0, "veto": 0, "silent": 0, "none": 0}
	var checks := {"accepted_ok": 0, "accepted_bad": 0, "vetoed_ok": 0, "vetoed_bad": 0, "scratched_ok": 0, "scratched_bad": 0}
	var counts := {"trust_drops": 0, "requests": 0}   # (a lambda copies plain numbers: counters live in a dictionary)
	var total := 0
	var bad := []
	var truths := {}
	for k in 2:
		_career(20 + k, "phases", "ambitious" if k == 0 else "balanced")
		var cp = game.get_system("proposals")
		cp.set_setting("ask")
		var watcher := Watcher.new()
		watcher.cp = cp
		watcher.game = game
		var answer := func(e: Dictionary) -> String:
			var ms = game.get_system("moments")
			var m: Dictionary = ms.moment(str(e.get("moment", "")))
			if m.get("kind", "") != "proposal":
				for c in e.choices:
					if str(c.id) in ["bothers", "lighter", "more"]:
						counts.requests += 1
						return str(c.id)   # (ask for a lighter week / more when the talk offers it)
				return _answer_any(e)
			watcher.check("posted")
			var p: Dictionary = cp.proposal(str(m.proposal))
			var ids: Array = e.choices.map(func(c): return str(c.id))
			var pick: String = ids[posmod(str(p.id).hash(), ids.size())]
			var trust_before: float = game.get_system("coach").trust()
			var week = game.current_week()
			game.answer_event(e.id, pick)
			if game.get_system("coach").trust() < trust_before - 0.5:
				counts.trust_drops += 1
			var kind := "accept" if pick == "accept" else ("silent" if pick == "veto_none" else "veto")
			results[kind] += 1
			for x in p.days:
				if p.kind == "scratch":
					var gone: bool = not str(p.meet) in game.entries
					checks["scratched_ok" if gone == (pick == "accept") else "scratched_bad"] += 1
					continue
				var d := int(x.d)
				var by: Dictionary = week.changed_by(d)
				if pick == "accept":
					var ok: bool = by.values().all(func(who): return who == "coach") and week.session_ids(d) == x.to.sessions \
							and week.intensity(d) == str(x.to.intensity)
					checks["accepted_ok" if ok else "accepted_bad"] += 1
				else:
					var ok2: bool = not by.values().has("coach") and (by.values().has("injury")
							or (week.session_ids(d) == x.from.sessions and week.intensity(d) == str(x.from.intensity)))
					checks["vetoed_ok" if ok2 else "vetoed_bad"] += 1
			return "__answered"
		for day in weeks * 7:
			var r: String = game.advance_day()
			watcher.check("day")
			if r == game.RACE:
				game.finish_race()
			var guard := 0
			while not game.pending_event().is_empty() and guard < 20:
				guard += 1
				var e: Dictionary = game.pending_event()
				var a: String = answer.call(e)
				if a != "__answered":
					game.answer_event(e.id, a)
		bad += watcher.bad
		total += cp.fired.size()
		# At most max_per_week a week and one a day.
		var per_week := {}
		var per_day := {}
		for p in cp.fired:
			var mon: int = Cal.date_key(p.monday)
			per_week[mon] = int(per_week.get(mon, 0)) + 1
			per_day[int(p.day)] = int(per_day.get(int(p.day), 0)) + 1
		var most_week: int = per_week.values().max() if not per_week.is_empty() else 0
		var most_day: int = per_day.values().max() if not per_day.is_empty() else 0
		var kinds := {}
		for p in cp.fired:
			kinds[p.kind] = int(kinds.get(p.kind, 0)) + 1
			truths[p.truth] = int(truths.get(p.truth, 0)) + 1
		print("     career %d: %d proposals in %d weeks (%s), at most %d a week, %d a day; requests in the talk %d" % [
				k + 1, cp.fired.size(), weeks, kinds, most_week, most_day, counts.requests])
		_ok("career %d: at most %d a week and one a day" % [k + 1, int(data.coaching.proposals.max_per_week)],
				most_week <= int(data.coaching.proposals.max_per_week) and most_day <= 1)
	for b in bad.slice(0, 5):
		print("     " + b)
	_ok("proposals came (%d)" % total, total > 0)
	print("     what his proposals really were (the truth): %s" % _shares(truths, total))
	_ok("his proposals are mostly right (Good or Fine in truth >= 70 %)",
			float(int(truths.get(V.GOOD, 0)) + int(truths.get(V.FINE, 0))) / maxi(1, total) >= 0.7)
	_ok("only unplayed non-race days (scratch advice only races to come)", bad.is_empty())
	print("     answers %s; %s; trust lost to silent vetoes %d times" % [results, checks, counts.trust_drops])
	_ok("OK puts the change into the day (by the coach)", checks.accepted_bad == 0 and checks.accepted_ok > 0)
	_ok("a veto keeps the plan", checks.vetoed_bad == 0 and checks.vetoed_ok > 0)
	_ok("a scratch is done only on OK", checks.scratched_bad == 0)
	# The silent-veto rule by itself.
	var cp2 = game.get_system("proposals")
	cp2.silent = []
	var cs = game.get_system("coach")
	var t0: float = cs.trust()
	cp2._silent_veto()
	cp2._silent_veto()
	var t1: float = cs.trust()
	var line: Array = cp2._silent_veto()
	var t2: float = cs.trust()
	_ok("two silent vetoes are free, the third costs %.0f trust (and says so)" % float(data.coaching.proposals.veto.silent_cost),
			absf(t1 - t0) < 0.001 and absf((t1 - t2) - float(data.coaching.proposals.veto.silent_cost)) < 0.001 and line.size() == 1)


func _proposals_always() -> void:
	print("\n== 4b. 'Always, tell me': he changes the day, Veto in the day editor puts the plan back")
	P.enabled = true
	MS.talks_enabled = true
	_career(30, "phases", "ambitious")
	var cp = game.get_system("proposals")
	cp.set_setting("always")
	var applied := 0
	var applied_ok := 0
	var vetoed := 0
	var vetoed_ok := 0
	var seen := 0
	var asked_scratch := 0
	for day in weeks * 7:
		_play(_answer_any)
		while seen < cp.fired.size():
			var p: Dictionary = cp.fired[seen]
			seen += 1
			if p.kind == "scratch":
				asked_scratch += 1 if p.status in ["asked", "accepted", "vetoed", "none"] else 0
				continue
			if p.status != "applied":
				continue
			var w = game.current_week()
			for x in p.days:
				var d := int(x.d)
				if Cal.date_key(p.monday) != Cal.date_key(w.monday) or not w.can_change(d):
					continue
				applied += 1
				var info: Dictionary = load("res://scripts/ui/day_info.gd").of(w, d)
				if info.by.values().has("coach") and not cp.applied_for(x.date).is_empty():
					applied_ok += 1
				if applied % 2 == 0:
					vetoed += 1
					var lines: Array = cp.veto(x.date, "fine" if applied % 4 == 0 else "none")
					if not w.changed_by(d).values().has("coach") and cp.applied_for(x.date).is_empty() and not lines.is_empty():
						vetoed_ok += 1
	print("     %d changes applied (%d shown as the coach's), %d vetoed (%d back to plan), scratch advice asked %d" % [
			applied, applied_ok, vetoed, vetoed_ok, asked_scratch])
	_ok("he changed days himself", applied > 0)
	_ok("each shows as changed by the coach", applied_ok == applied)
	_ok("Veto in the day editor puts the plan back", vetoed_ok == vetoed)
	var scratch_applied: int = cp.fired.filter(func(p): return p.kind == "scratch" and p.status == "applied").size()
	_ok("a race is never scratched by itself", scratch_applied == 0)
	var msgs := 0
	for x in game.get_system("moments").thread("coach"):
		if str(x.text).contains(str(data.coach_talk.proposal.applied_end)):
			msgs += 1
	_ok("he tells you in the thread (%d messages)" % msgs, msgs > 0)


## Part 4c: the day before a race with shin splints (a niggle that racing can make worse) and painful legs: a coach of 20's
## "scratch?" advice in every setting. It is never done by itself.
func _scratch_advice() -> void:
	print("\n== 4c. Scratch advice (forced: shin splints and painful legs the day before a race)")
	P.enabled = true
	MS.talks_enabled = false
	_career(60, "phases", "balanced")
	var found := false
	for _i in 140:
		var w0 = game.current_week()
		if w0.day + 1 < 7 and w0.is_race_day(w0.day + 1) and not w0.day_started:
			found = true
			break
		_play(_answer_any)
	_ok("found a day before a race", found)
	if not found:
		return
	var cs = game.get_system("coach")
	for at in data.coaching.attributes:
		cs.head().attributes[at.id] = 20
	var h = game.get_system("health")
	h._ensure_started()
	var saved_strain: Dictionary = h.strain.duplicate()
	for area in H.areas():
		h.strain[area.id] = float(data.health.soreness.levels[2]) * 1.15
	h._start(data.get_injury("shin_splints"), game.date, [])   # (a niggle that racing can make worse)
	h.refresh()
	var w = game.current_week()
	var d: int = w.day + 1
	var meet: Dictionary = w.races[d]
	var cp = game.get_system("proposals")
	var ms = game.get_system("moments")
	var jt: Dictionary = V.judge(V.race_change(d), V.head_view())
	print("     scratch %s, as he sees it: %s (train %+.2f risk %+.2f form %+.2f race %+.2f)" % [
			meet.name, jt.verdict, jt.seen.train, jt.seen.risk, jt.seen.form, jt.seen.race])
	_ok("with shin splints scratching even a target race is a Good idea", jt.verdict == V.GOOD)
	for mode in ["ask", "always", "never"]:
		cp.set_setting(mode)
		cp.list = []
		cp.week = {}
		cp.last_day = -1
		cp.requests = []
		game.enter(str(meet.key))
		w = game.current_week()
		w.reset_day(d)
		var n_msgs: int = ms.thread("coach").size()
		cp._look(game._day_context(), w.day)
		var p: Dictionary = cp.list.back() if not cp.list.is_empty() else {}
		var e: Dictionary = game.pending_event()
		if mode == "never":
			_ok("never: a message only, the race stays", p.get("kind", "") == "scratch" and p.status == "noticed" and e.is_empty()
					and str(meet.key) in game.entries and ms.thread("coach").size() > n_msgs)
			continue
		_ok("%s: he asks (a stop), nothing scratched yet" % mode, p.get("kind", "") == "scratch" and p.status == "asked"
				and not e.is_empty() and str(meet.key) in game.entries)
		if e.is_empty():
			continue
		print("     \"%s\"" % e.text)
		var pick := "accept" if mode == "ask" else "veto_race"
		game.answer_event(e.id, pick)
		w = game.current_week()
		if pick == "accept":
			_ok("OK scratches the race and the day becomes an easy run (by the coach)", not str(meet.key) in game.entries
					and not w.is_race_day(d) and w.session_ids(d) == [str(data.coaching.proposals.easy_session)]
					and w.changed_by(d).values().has("coach"))
		else:
			_ok("Race anyway: the race stays", str(meet.key) in game.entries and w.is_race_day(d))
	h.strain = saved_strain
	h.injuries = []


# --- 5. Nothing changes without your setting ---------------------------------------------------------------

## The fingerprint of a career played `n` days: the attributes, fatigue and every day's load.
func _fingerprint_run(i: int, setting: String, n: int, answer: Callable) -> Dictionary:
	P.enabled = setting != "off"
	_career(i, "phases", "ambitious")
	if setting != "off":
		game.get_system("proposals").set_setting(setting)
	_play_days(n, answer)
	var total := 0.0
	for id in game.athlete.attributes:
		total += game.athlete.get_attr(id)
	var loads := 0.0
	for e in game.day_log:
		loads += float(e.load) * (1 + e.date.day)
	var cp = game.get_system("proposals")
	return {"fp": "%.9f %.9f %.9f %s" % [total, game.athlete.fatigue, loads, game.entries], "fired": cp.fired.size()}


func _veto_all(e: Dictionary) -> String:
	var m: Dictionary = game.get_system("moments").moment(str(e.get("moment", "")))
	if m.get("kind", "") == "proposal":
		var ids: Array = e.choices.map(func(c): return str(c.id))
		var vetoes := ids.filter(func(x): return str(x).begins_with("veto_"))
		return vetoes[posmod(e.id.hash(), vetoes.size())]
	if str(e.get("kind", "")) == "moment":
		return str(e.choices[0].id)   # (the same reply in every run: no proposal requests come from a reply's hash)
	return "keep" if str(e.get("kind", "")) == "sore" else "ok"


func _neutral() -> void:
	print("\n== 5. Nothing changes without your setting (the same career, %d weeks)" % weeks)
	MS.talks_enabled = true
	var n := weeks * 7
	var off: Dictionary = _fingerprint_run(40, "off", n, _veto_all)
	var never: Dictionary = _fingerprint_run(40, "never", n, _veto_all)
	var ask: Dictionary = _fingerprint_run(40, "ask", n, _veto_all)
	print("     off   %s\n     never %s (%d proposals)\n     ask   %s (%d proposals, all vetoed)" % [off.fp, never.fp, never.fired, ask.fp, ask.fired])
	_ok("'Never' changes nothing (and he did notice things)", never.fp == off.fp and never.fired > 0)
	_ok("'Ask me first' with every proposal vetoed changes nothing", ask.fp == off.fp and ask.fired > 0)
	P.enabled = true


# --- 6. Save / load --------------------------------------------------------------------------------------

func _save_load() -> void:
	print("\n== 6. Save / load with proposals")
	P.enabled = true
	MS.talks_enabled = true
	_career(50, "phases", "ambitious")
	var cp = game.get_system("proposals")
	cp.set_setting("always")
	var days := 0
	while (cp.fired.size() < 3 or cp.list.filter(func(p): return p.status == "applied").is_empty()) and days < weeks * 7:
		_play(_answer_any)
		days += 1
	cp.set_setting("ask")
	saves.save("verdict_check")
	var before: String = JSON.stringify(cp.to_dict())
	var after_play := _play_on(21)
	_ok("loads", saves.load_slot("verdict_check"))
	cp = game.get_system("proposals")
	_ok("the proposals come back as they were (setting, list, counters)", JSON.stringify(cp.to_dict()) == before and cp.setting() == "ask")
	_ok("a loaded career goes on exactly as without saving (3 weeks)", _play_on(21) == after_play)
	saves.delete("verdict_check")


## Plays `n` days by the date (a stop before the day uses a press without playing it).
func _play_days(n: int, answer: Callable) -> void:
	var target: int = Cal.date_key(game.add_days(game.date, n))
	var guard := 0
	while Cal.date_key(game.date) < target and guard < n * 4:
		guard += 1
		_play(answer)


## (`fired` is not saved, for the tools only: the list itself is compared.)
func _play_on(n: int) -> String:
	_play_days(n, _answer_any)
	var total := 0.0
	for id in game.athlete.attributes:
		total += game.athlete.get_attr(id)
	var cp = game.get_system("proposals")
	return "%.9f %.9f %d %s %d" % [total, game.athlete.fatigue, cp.list.size(), JSON.stringify(cp.list).md5_text(),
			game.get_system("moments").thread("coach").size()]
