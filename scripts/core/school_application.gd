class_name SchoolApplication
extends RefCounted
## The joint application after grade 9 (GDD 4.9.3, session S3a): the dates of the window, the wishes a player can list, the points
## (grades + sport results + the school's own points from the entrance test) and the results against the cut-offs. Static and
## reading only: SchoolSystem keeps the player's list, the test result and the paths. Every number and text is in
## data/application.json (the schools themselves in data/urheilulukiot.json). Dice come from seeds of the career and what is
## rolled (the school and the year), so the same career gets the same cut-offs however often it is asked.


static func cfg() -> Dictionary:
	return Data.application


# --- Dates ---------------------------------------------------------------------------------------------------------------------

## The nth given weekday (0 = Monday) of a month.
static func nth_weekday(year: int, month: int, weekday: int, n: int) -> Dictionary:
	var d := {"year": year, "month": month, "day": 1}
	while Calendar.weekday(d) != weekday:
		d = Game.add_days(d, 1)
	return Game.add_days(d, 7 * (n - 1))


## The dates of the application made in the spring of `year`: open, close (the last day), remind, test, results, accept_by, move.
static func dates(year: int) -> Dictionary:
	var w: Dictionary = cfg().window
	var open := nth_weekday(year, int(w.open.month), 1, int(w.open.nth_tuesday))
	var close := Game.add_days(open, int(w.length_days))
	var res := {"year": year, "month": int(w.results.month), "day": int(w.results.day)}
	while Calendar.weekday(res) >= 5:
		res = Game.add_days(res, 1)
	return {"open": open, "close": close, "remind": Game.add_days(close, -int(w.reminder_days)),
			"test": nth_weekday(year, int(w.test.month), 1, int(w.test.nth_tuesday)), "results": res,
			"accept_by": Game.add_days(res, int(w.reply_days)),
			"move": {"year": year, "month": int(w.move.month), "day": int(w.move.day)}}


# --- What can be on the list --------------------------------------------------------------------------------------------------------

## Every wish a player can add, in the order of the list: [{id, kind (sports / general / vocational), name, town, school}].
static func options(town: String) -> Array:
	var out := []
	for s in Data.urheilulukiot.schools:
		out.append({"id": "sports:" + str(s.id), "kind": "sports", "name": str(s.name), "town": str(s.town), "school": s})
	out.append({"id": "general", "kind": "general", "name": str(cfg().wishes.general.name).format({"town": town}), "town": town, "school": {}})
	out.append({"id": "vocational", "kind": "vocational", "name": str(cfg().wishes.vocational.name).format({"town": town}), "town": town, "school": {}})
	return out


## One option by id ({} for an unknown id).
static func option(wish_id: String, town: String) -> Dictionary:
	for o in options(town):
		if str(o.id) == wish_id:
			return o
	return {}


## The path kind a wish leads to.
static func path_kind(o: Dictionary) -> String:
	match str(o.kind):
		"sports":
			return "urheilulukio"
		"general":
			return "lukio"
	return "vocational"


## True when the wish is in another maakunta than `town` (an unknown town counts as far).
static func is_far(wish_town: String, town: String) -> bool:
	if wish_town == town:
		return false
	var t1 := Data.get_town(wish_town)
	var t2 := Data.get_town(town)
	return t1.is_empty() or t2.is_empty() or str(t1.maakunta) != str(t2.maakunta)


# --- Grades ----------------------------------------------------------------------------------------------------------------------

## The average of the academic subjects + PE (what the application counts) from a dictionary of subject -> grade.
static func average_of(grades: Dictionary, ss: SchoolSystem, with_pe := true) -> float:
	var total := 0.0
	var n := 0
	for s in ss.subject_list():
		var sid := str(s.id)
		if str(s.kind) == "academic" or (with_pe and sid == "pe"):
			total += float(grades.get(sid, 0.0))
			n += 1
	return total / maxf(1.0, n)


## The average now (the levels), or from the latest report card of the school year when `final` (the certificate in June).
static func average_now(ss: SchoolSystem, with_pe := true) -> float:
	var grades := {}
	for sid in ss.subjects:
		grades[sid] = ss.level(sid)
	return average_of(grades, ss, with_pe)


static func average_final(ss: SchoolSystem, with_pe := true) -> float:
	if ss.reports.is_empty():
		return average_now(ss, with_pe)
	return average_of(ss.reports.back().grades, ss, with_pe)


static func grade_points(avg: float) -> float:
	var g: Dictionary = cfg().points.grades
	return clampf((avg - float(g.min)) / (float(g.max) - float(g.min)), 0.0, 1.0) * float(g.points)


# --- Sport points (the federation's 0-5) ---------------------------------------------------------------------------------------------

## The best 800 m (the main event) time of the last `seasons` calendar years up to `year` (0 = none).
static func best_time(a: Athlete, year: int) -> float:
	var seasons := int(cfg().points.sport.seasons)
	var best := 0.0
	for r in a.results:
		if str(r.get("status", "")) != "" or float(r.get("time", 0.0)) <= 0.0 or str(r.get("event", "")) != a.main_event:
			continue
		var y := int(r.date.year)
		if y > year or y <= year - seasons:
			continue
		if best <= 0.0 or float(r.time) < best:
			best = float(r.time)
	return best


## The anchors' times for this athlete (slowest first), each {id, time, points}. The athlete's own age class in the season before
## `year`; an age without a row uses the fallback time. Anchors that are not faster than the one before are left out.
static func anchors(a: Athlete, year: int) -> Array:
	var letter := "M" if a.gender == "male" else "N"
	var out := []
	var prev := 1.0e9
	for an in cfg().points.sport.anchors:
		var set := Standards.set_of(str(an.set))
		var t := 0.0
		if set.is_empty():
			continue
		if str(set.get("lookup", "")) == "gender":
			t = float((set.get("minimum", {}) if bool(an.get("minimum", false)) else set.times).get(letter, 0.0))
		else:
			t = Standards.time(str(an.set), a, year - 1)
			if t <= 0.0:
				t = float(cfg().points.sport.fallback.get(str(an.set), {}).get(letter, 0.0))
		if t > 0.0 and t < prev:
			out.append({"id": str(an.id), "time": t, "points": float(an.points)})
			prev = t
	return out


## The sport points: {best (s), ladder, statement, total, tf (the TF-juniorit time reached)}.
static func sport_points(a: Athlete, year: int) -> Dictionary:
	var c: Dictionary = cfg().points.sport
	var best := best_time(a, year)
	var list := anchors(a, year)
	var ladder := 0.0
	if best > 0.0 and not list.is_empty():
		# The curve: 0 points at zero_factor x the slowest anchor's time, then the anchors, straight lines in between.
		var nodes := [{"time": float(list[0].time) * float(c.zero_factor), "points": 0.0}]
		nodes.append_array(list)
		ladder = float(nodes.back().points)
		for i in nodes.size() - 1:
			var slow: Dictionary = nodes[i]
			var fast: Dictionary = nodes[i + 1]
			if best >= float(slow.time):
				ladder = float(slow.points)
				break
			if best >= float(fast.time):
				ladder = float(slow.points) + (float(fast.points) - float(slow.points)) * (float(slow.time) - best) / (float(slow.time) - float(fast.time))
				break
	var tf_time := Standards.time("tf_juniorit", a, year - 1)
	var tf := best > 0.0 and tf_time > 0.0 and best <= tf_time
	var statement := 0.0
	var cs := Game.get_system("coach") as CoachSystem
	if best > 0.0 and cs != null and cs.model_enabled:
		statement = float(c.statement.max) * clampf((cs.trust() - float(c.statement.trust_from)) / float(c.statement.trust_span), 0.0, 1.0)
	return {"best": best, "ladder": ladder, "statement": statement, "tf": tf, "total": minf(float(c.max), ladder + statement)}


# --- School points (the entrance test) ----------------------------------------------------------------------------------------------------

static func physical_points(a: Athlete) -> float:
	var p: Dictionary = cfg().points.school.physical
	return _scaled(a, p.attrs, float(p.low), float(p.high)) * float(p.points)


static func interview_points(a: Athlete) -> float:
	var p: Dictionary = cfg().points.school.interview
	var v := _scaled(a, p.attrs, float(p.low), float(p.high)) * float(p.points)
	var mind := MindSystem.sys()
	if mind != null and not MindSystem.neutral:
		var c: Dictionary = p.confidence
		v += clampf((mind.value("confidence") - float(c.mid)) / float(c.span), -1.0, 1.0) * float(c.points)
	return v


static func _scaled(a: Athlete, attrs: Array, low: float, high: float) -> float:
	var total := 0.0
	for id in attrs:
		total += a.get_attr(str(id))
	return clampf((total / maxf(1.0, attrs.size()) - low) / (high - low), 0.0, 1.0)


## The extra points one answer of the test day gives (rolls come from the career's seed and the year).
static func step_delta(ss: SchoolSystem, year: int, step_id: String, option_id: String) -> float:
	for step in cfg().test.steps:
		if str(step.id) != step_id:
			continue
		for o in step.options:
			if str(o.id) != option_id:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = ss._seed("test|%d|%s|%s" % [year, step_id, option_id])
			var d := float(o.delta)
			if o.has("sd"):
				d += rng.randfn(0.0, float(o.sd))
			if o.has("chance") and rng.randf() >= float(o.chance):
				d = float(o.fail_delta)
			if o.has("attr") and Game.athlete.get_attr(str(o.attr)) < float(o.from):
				d = float(o.else_delta)
			return d
	return 0.0


## The test's school points for a wish (the base from the test day + the school's own adjustment), 0-5; -1 before the test day.
static func school_points(test: Dictionary, o: Dictionary) -> float:
	if test.is_empty() or not bool(test.get("done", false)):
		return -1.0
	if not (test.get("invited", []) as Array).has(str(o.id)):
		return 0.0
	var p: Dictionary = cfg().points.school
	var adj := float(p.athletics_adjust.get(str(o.school.get("athletics", "unverified")), 0.0))
	return clampf(float(test.base) + adj, 0.0, float(p.max))


## The minimum sport points a sports school wants before it invites you to its test.
static func invite_min(o: Dictionary) -> float:
	var w: Dictionary = cfg().wishes
	return float(w.invite.get(str(o.school.get("id", "")), w.invite_default))


# --- Cut-offs ----------------------------------------------------------------------------------------------------------------------------

## What a wish asks for: {value, kind ("points" of 20 / "avg" = a grade average), year (of the published one, 0 = none), approx,
## estimated, noise}. `year` seeds the yearly wobble (a published figure is the base; the result adds the wobble).
static func cutoff(ss: SchoolSystem, o: Dictionary, year: int, with_noise := true) -> Dictionary:
	var w: Dictionary = cfg().wishes
	var base := 0.0
	var out := {"kind": "points", "year": 0, "approx": false, "estimated": false}
	var sd := float(w.cutoff_noise_sd)
	match str(o.kind):
		"sports":
			var s: Dictionary = o.school
			var found := false
			for i in range(s.cutoffs.size() - 1, -1, -1):
				var c: Dictionary = s.cutoffs[i]
				if c.get("points") != null:
					base = float(c.points)
					out.year = int(c.year)
					out.approx = bool(c.get("approx", false)) or bool(c.get("preliminary", false))
					found = true
					break
			if not found:
				base = float(w.cutoff_unknown.get(str(s.status), w.cutoff_unknown.special_task))
				out.estimated = true
		"general":
			var g: Dictionary = w.general
			base = float(g.cutoff_avg) + float(g.size_shift.get(Data.town_size(str(o.town)), 0.0))
			out.kind = "avg"
			out.estimated = true
			sd = float(g.noise_sd)
		_:
			base = float(w.vocational.cutoff_avg)
			out.kind = "avg"
			out.estimated = true
			sd = float(w.vocational.noise_sd)
	out.base = base
	var v := base
	if with_noise:
		var rng := RandomNumberGenerator.new()
		rng.seed = ss._seed("cutoff|%s|%d" % [str(o.id), year])
		v += rng.randfn(0.0, sd)
	out.value = v
	return out


# --- The points together, the results ------------------------------------------------------------------------------------------------------

## The points a wish gives now (the preview; the school's own part is `guess` before the test day): {grades, sport, school, total, avg}.
static func preview(ss: SchoolSystem, o: Dictionary, year: int) -> Dictionary:
	var a := Game.athlete
	var avg := average_now(ss)
	var sp := sport_points(a, year)
	var sc := school_points(ss.application(year).get("test", {}), o)
	if sc < 0.0:
		sc = float(cfg().points.school.guess)
	return _sum(avg, sp, sc, str(o.kind))


static func _sum(avg: float, sp: Dictionary, sc: float, kind: String) -> Dictionary:
	var gp := grade_points(avg)
	return {"avg": avg, "grades": gp, "sport": float(sp.total), "school": sc, "total": gp + float(sp.total) + sc if kind == "sports" else avg}


## The results of the list in order: [{wish, name, town, kind, status (yes / no / skipped), why, total, cut, avg, points}] from the
## final certificate. The first "yes" is the place; the wishes after it are "skipped".
static func evaluate(ss: SchoolSystem, wishes: Array, year: int) -> Array:
	var a := Game.athlete
	var town := ss.town()
	var out := []
	var avg := average_final(ss)
	var avg_ac := average_final(ss, false)
	var sp := sport_points(a, year)
	var test: Dictionary = ss.application(year).get("test", {})
	var taken := false
	var r: Dictionary = cfg().results
	for wid in wishes:
		var o := option(str(wid), town)
		if o.is_empty():
			continue
		var row := {"wish": str(wid), "name": str(o.name), "town": str(o.town), "kind": str(o.kind), "status": "no", "why": ""}
		if taken:
			row.status = "skipped"
			row.why = str(r.why_skipped)
			out.append(row)
			continue
		var cut := cutoff(ss, o, year)
		row.cut = float(cut.value)
		row.cut_kind = str(cut.kind)
		if str(o.kind) == "sports":
			var sc := school_points(test, o)
			var s_pts := maxf(sc, 0.0)
			var tot := grade_points(avg) + float(sp.total) + s_pts
			row.total = tot
			row.points = {"grades": grade_points(avg), "sport": float(sp.total), "school": s_pts}
			var min_g := float(o.school.get("min_grade", 0.0)) if o.school.get("min_grade") != null else 0.0
			if float(sp.total) < invite_min(o):
				row.why = str(r.why_not_invited)
			elif min_g > 0.0 and avg_ac < min_g:
				row.why = str(r.why_min_grade).format({"points": "%.2f" % avg_ac, "cut": "%.1f" % min_g})
			elif tot >= float(cut.value):
				row.status = "yes"
			else:
				row.why = str(r.why_points).format({"points": "%.1f" % tot, "cut": "%.1f" % float(cut.value)})
		else:
			row.total = avg
			if avg >= float(cut.value):
				row.status = "yes"
			else:
				row.why = str(r.why_avg).format({"points": "%.2f" % avg, "cut": "%.2f" % float(cut.value)})
		if str(row.status) == "yes":
			taken = true
		out.append(row)
	return out


## The line of one result.
static func result_line(row: Dictionary) -> String:
	var r: Dictionary = cfg().results
	if str(row.status) == "skipped":
		return str(r.line_skipped).format({"name": row.name})
	if str(row.status) == "yes":
		if str(row.kind) == "sports":
			return str(r.line_yes).format({"name": row.name, "points": "%.1f" % float(row.total), "cut": "%.1f" % float(row.cut)})
		return str(r.line_yes_avg).format({"name": row.name, "points": "%.2f" % float(row.total), "cut": "%.2f" % float(row.cut)})
	return str(r.line_no).format({"name": row.name, "why": row.why})


## The study counsellor's list for `year` (see data apply.suggest): sports lukiot of the athlete's own region with athletics offered
## or a priority and a limit within reach, best limit first, then the general lukio as the safe last wish.
static func suggest(ss: SchoolSystem, year: int) -> Array:
	var town := ss.town()
	var s: Dictionary = cfg().apply.suggest
	var cands := []
	for o in options(town):
		if str(o.kind) != "sports" or is_far(str(o.town), town):
			continue
		if str(o.school.get("athletics", "unverified")) == "unverified":
			continue
		var cut := cutoff(ss, o, year, false)
		var pv := preview(ss, o, year)
		if float(pv.sport) < invite_min(o):
			continue
		if float(pv.total) >= float(cut.value) - float(s.reach):
			cands.append({"id": str(o.id), "cut": float(cut.value)})
	cands.sort_custom(func(x, y): return float(x.cut) > float(y.cut))
	var out := []
	for c in cands:
		if out.size() >= int(s.max_sports):
			break
		out.append(str(c.id))
	out.append("general")
	return out
