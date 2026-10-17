class_name Lukio
extends RefCounted
## Lukio courses (GDD 4.9.3, session S3b), static helpers over SchoolSystem.lukio (the state: the choices, every course, the
## matriculation exams). A course is a 2-credit study unit; the whole lukio is 75 courses (150 credits) spread over its periods
## (5 a school year, data/school.json rules.lukio_periods). The study counsellor's plan puts every compulsory course and enough
## optional courses into the periods (exam subjects first, each subject's courses spread so they end before its exam session);
## the player changes the current period's courses in the period's stop (move a course later, add or drop an optional one, and in
## a sports lukio leave out compulsory ones by the real rule). Every number and text: data/lukio.json.
##
## A course: {id, s (subject), n (its number in the subject), k ("comp" / "opt" / "coach"), p (the lukio period index from 0, -1 =
## not placed), st ("plan" / "done" / "pool" (an optional course not in the plan) / "drop" (a compulsory course left out)),
## g (the grade: 0 none yet, -1 passed, 4-10), x (the exam's score, -1 = none), by ("" = the counsellor, "player"), r (a retake)}.

static var _period_cache := {}   # "town|year" -> the year's periods


static func cfg() -> Dictionary:
	return Data.lukio


# --- Subjects -----------------------------------------------------------------------------------------------------------------

## The lukio subjects of this athlete's choices (the new language only when chosen, coaching only in a sports lukio).
static func subject_defs(L: Dictionary) -> Array:
	var out := []
	for s in cfg().subjects.list:
		match str(s.get("only_if", "")):
			"b3":
				if str(L.get("b3", "none")) == "none":
					continue
			"sports":
				if not bool(L.get("sports", false)):
					continue
		out.append(s)
	return out


static func subject_def(sid: String) -> Dictionary:
	for s in cfg().subjects.list:
		if str(s.id) == sid:
			return s
	return {}


static func subject_name(sid: String, L: Dictionary) -> String:
	return str(subject_def(sid).get("name", sid)).format({"language": language_name(str(L.get("b3", "none")))})


static func language_name(lang: String) -> String:
	for l in cfg().subjects.languages:
		if str(l.id) == lang:
			return str(l.name)
	return lang


## Compulsory courses of a subject for these choices (maths: the common course + the syllabus; music / art: the third course
## of the two goes to `music_art`).
static func comp_count(sid: String, L: Dictionary) -> int:
	var s := subject_def(sid)
	if sid == "maths":
		return int(s.common) + int(s[str(L.get("maths", "short"))].comp)
	var n := int(s.get("comp", 0))
	if sid == str(L.get("music_art", "")):
		n += int(cfg().subjects.music_art_extra)
	return n


static func opt_count(sid: String, L: Dictionary) -> int:
	var s := subject_def(sid)
	if sid == "maths":
		return int(s[str(L.get("maths", "short"))].opt)
	return int(s.get("opt", 0))


static func is_classroom(u: Dictionary) -> bool:
	return str(u.k) != "coach"


## "Finnish 3", "Maths 4", "Sports coaching 2".
static func course_name(u: Dictionary, L: Dictionary) -> String:
	return "%s %d" % [subject_name(str(u.s), L), int(u.n)]


static func kind_of(sid: String) -> String:
	return str(subject_def(sid).get("kind", "academic"))


# --- Periods ------------------------------------------------------------------------------------------------------------------

## The five periods of a school year in a town: [{i, start, end, exam (the exam week's school days, in order)}]. The exam weeks
## are the stage's exam days (SchoolSystem._exam_set) inside each period.
static func year_periods(ss: SchoolSystem, year: int) -> Array:
	var ck := "%s|%d" % [ss.town(), year]
	if _period_cache.has(ck):
		return _period_cache[ck]
	var y := SchoolCalendar.year_for(ss.town(), year)
	var lp: Dictionary = Data.school.rules.lukio_periods
	var offs: Array = lp.start_offsets_days
	var exams := ss._exam_set(year)
	var out := []
	for i in offs.size():
		var start := Game.add_days(y.start, int(offs[i]))
		var end: Dictionary = Game.add_days(y.start, int(offs[i + 1]) - 1) if i + 1 < offs.size() else y.end
		var ex := []
		var d := start
		while Calendar.date_key(d) <= Calendar.date_key(end):
			if exams.has(Calendar.date_key(d)):
				ex.append(d)
			d = Game.add_days(d, 1)
		out.append({"i": i, "start": start, "end": end, "exam": ex})
	_period_cache[ck] = out
	return out


static func clear_cache() -> void:
	_period_cache = {}


## How many periods the lukio has (5 a year).
static func period_count(L: Dictionary) -> int:
	return int(L.years) * per_year()


static func per_year() -> int:
	return (Data.school.rules.lukio_periods.start_offsets_days as Array).size()


## The period (index from the lukio's start) a date falls in: {p, year (school year), i (0-4), start, end, exam}; {} outside
## the lukio's school years or in the summer.
static func period_at(ss: SchoolSystem, L: Dictionary, d: Dictionary) -> Dictionary:
	if L.is_empty():
		return {}
	var year := SchoolCalendar.year_of(d)
	var yi := year - int(L.start_year)
	if yi < 0 or yi >= int(L.years):
		return {}
	var key := Calendar.date_key(d)
	for per in year_periods(ss, year):
		if key >= Calendar.date_key(per.start) and key <= Calendar.date_key(per.end):
			var out: Dictionary = per.duplicate()
			out.p = yi * per_year() + int(per.i)
			out.year = year
			out.year_index = yi
			return out
	return {}


## The period with index `p`: the same fields as period_at.
static func period_info(ss: SchoolSystem, L: Dictionary, p: int) -> Dictionary:
	var yi := p / per_year()
	var year := int(L.start_year) + yi
	var out: Dictionary = (year_periods(ss, year)[p % per_year()] as Dictionary).duplicate()
	out.p = p
	out.year = year
	out.year_index = yi
	return out


## The last period that ends before a matriculation session (its courses must be done by then).
static func deadline_period(L: Dictionary, session_key: String) -> int:
	var cal := Matriculation.year_of(session_key)
	if Matriculation.season_of(session_key) == "spring":
		return (cal - 1 - int(L.start_year)) * per_year() + 2   # the spring exams are in period 4: courses done by period 3
	return (cal - int(L.start_year)) * per_year() - 1           # the autumn exams are in period 1: done by the spring before


# --- Building the plan -------------------------------------------------------------------------------------------------------

## Every course this lukio needs exists: the compulsory ones and the coaching ones in the plan, every optional one at least in
## the pool; courses of another maths syllabus or a dropped language that were not done disappear.
static func ensure_units(ss: SchoolSystem, L: Dictionary) -> void:
	var have := {}
	for u in L.units:
		have[str(u.id)] = u
	var keep := []
	for s in subject_defs(L):
		var sid := str(s.id)
		var comp := comp_count(sid, L)
		var opt := opt_count(sid, L)
		var coach := int(s.get("coaching", 0))
		for n in range(1, comp + opt + coach + 1):
			var uid := _unit_id(sid, n, L)
			var k := "coach" if coach > 0 else ("comp" if n <= comp else "opt")
			keep.append(uid)
			if have.has(uid):
				var u: Dictionary = have[uid]
				if str(u.st) != "done":
					u.k = k
					if k != "opt" and str(u.st) == "pool":
						u.st = "plan"
						u.p = -1
				continue
			L.units.append({"id": uid, "s": sid, "n": n, "k": k, "p": -1, "st": "pool" if k == "opt" else "plan", "g": 0, "x": -1.0, "by": "", "r": false})
	# Courses that no longer belong (the other maths syllabus, a language you stopped): kept only when done.
	L.units = (L.units as Array).filter(func(u): return str(u.id) in keep or str(u.st) == "done")


static func _unit_id(sid: String, n: int, L: Dictionary) -> String:
	if sid == "maths" and n > 1:
		return "maths_%s%d" % ["l" if str(L.get("maths", "short")) == "long" else "s", n]
	return "%s_%d" % [sid, n]


## The order optional courses are added in: the exam subjects' (in the order of their sessions), then the academic subjects by
## level, then the practical ones (PE first) and the thematic studies.
static func optional_order(ss: SchoolSystem, L: Dictionary) -> Array:
	var plan: Dictionary = L.matric.plan
	var exam_subjects := []
	var keys := plan.keys()
	keys.sort_custom(func(a, b): return _session_rank(str(plan[a])) < _session_rank(str(plan[b])))
	for ex in keys:
		var sid := str(Matriculation.exam(str(ex)).get("subject", ""))
		if sid != "" and not sid in exam_subjects:
			exam_subjects.append(sid)
	var academic := []
	var practical := []
	for s in subject_defs(L):
		var sid := str(s.id)
		if sid in exam_subjects:
			continue
		match str(s.kind):
			"academic":
				academic.append(sid)
			"practical":
				practical.append(sid)
	academic.sort_custom(func(a, b): return ss.level(a) > ss.level(b))
	practical.sort_custom(func(a, b): return (0 if a == "pe" else 1) < (0 if b == "pe" else 1))
	return exam_subjects + academic + practical + ["thematic"]


static func _session_rank(key: String) -> int:
	return Matriculation.year_of(key) * 2 + (0 if Matriculation.season_of(key) == "spring" else 1)


## Optional courses in or out of the plan so the whole lukio is 75 courses (coaching included); dropped compulsory courses are
## replaced by optional ones. Courses the player added are never taken out; only the counsellor's own, from `from_p` on.
static func fill_optional(ss: SchoolSystem, L: Dictionary, from_p: int) -> void:
	var target := int(cfg().rules.total_courses)
	var count := 0
	for u in L.units:
		if str(u.st) in ["plan", "done"]:
			count += 1
	var order := optional_order(ss, L)
	if count < target:
		for sid in order:
			for u in _units_of(L, sid):
				if count >= target:
					return
				if str(u.k) == "opt" and str(u.st) == "pool":
					u.st = "plan"
					u.p = -1
					count += 1
	elif count > target:
		var rev := order.duplicate()
		rev.reverse()
		for sid in rev:
			var list := _units_of(L, sid)
			list.reverse()
			for u in list:
				if count <= target:
					return
				if str(u.k) == "opt" and str(u.st) == "plan" and str(u.by) == "" and (int(u.p) < 0 or int(u.p) >= from_p):
					u.st = "pool"
					u.p = -1
					count -= 1


static func _units_of(L: Dictionary, sid: String) -> Array:
	var out := []
	for u in L.units:
		if str(u.s) == sid:
			out.append(u)
	out.sort_custom(func(a, b): return int(a.n) < int(b.n))
	return out


## The weight of each period in the plan (year_share, and the last year's periods by last_year_periods).
static func period_weights(L: Dictionary) -> Array:
	var p: Dictionary = cfg().plan
	var shares: Array = p.year_share.get(str(int(L.years)), p.year_share["3"])
	var out := []
	for yi in int(L.years):
		var pw := []
		for i in per_year():
			pw.append(float((p.last_year_periods as Array)[i]) if yi == int(L.years) - 1 else 1.0)
		var sum := 0.0
		for w in pw:
			sum += float(w)
		for w in pw:
			out.append(float(shares[yi]) * float(w) / maxf(sum, 0.0001))
	return out


## Places every planned course that is not done and not in a period before `from_p`: classroom courses by the period weights,
## coaching courses evenly; inside the quota of a period the subject that is most behind its deadline goes first (at most two
## courses of a subject in one period).
static func spread(ss: SchoolSystem, L: Dictionary, from_p: int) -> void:
	var last := period_count(L) - 1
	from_p = clampi(from_p, 0, last)
	var weights := period_weights(L)
	var pending := []
	var coach := []
	for u in L.units:
		if str(u.st) != "plan":
			continue
		if int(u.p) >= 0 and int(u.p) < from_p:
			continue
		if str(u.k) == "coach":
			coach.append(u)
		else:
			pending.append(u)
	# Quotas: the pending courses dealt out by the weights of periods from_p..last (largest remainder).
	var quota := _deal(pending.size(), weights.slice(from_p, last + 1))
	var deadlines := {}
	for s in subject_defs(L):
		deadlines[str(s.id)] = last
	for ex in L.matric.plan:
		var sid := str(Matriculation.exam(str(ex)).get("subject", ""))
		if deadlines.has(sid):
			deadlines[sid] = mini(int(deadlines[sid]), maxi(from_p, deadline_period(L, str(L.matric.plan[ex]))))
	var queues := {}
	for u in pending:
		var sid := str(u.s)
		if not queues.has(sid):
			queues[sid] = []
		queues[sid].append(u)
	for sid in queues:
		(queues[sid] as Array).sort_custom(func(a, b):
			var ka := 0 if str(a.k) == "comp" else 1
			var kb := 0 if str(b.k) == "comp" else 1
			return ka < kb if ka != kb else int(a.n) < int(b.n))
	var order := []
	for s in subject_defs(L):
		order.append(str(s.id))
	var carry := 0
	for qi in quota.size():
		var p := from_p + qi
		var want := int(quota[qi]) + carry
		var taken := {}
		var got := 0
		while got < want:
			var best := ""
			var best_score := -1.0
			for sid in order:
				if not queues.has(sid) or (queues[sid] as Array).is_empty() or int(taken.get(sid, 0)) >= 2:
					continue
				var rem := (queues[sid] as Array).size()
				var left := int(deadlines[sid]) - p + 1
				var score := float(rem) / float(maxi(1, left)) if left > 0 else 100.0 * rem
				if score > best_score:
					best_score = score
					best = sid
			if best == "":
				break
			var u: Dictionary = (queues[best] as Array).pop_front()
			u.p = p
			taken[best] = int(taken.get(best, 0)) + 1
			got += 1
		carry = want - got
	# Anything left (every subject at its cap): the last periods that take courses.
	for sid in queues:
		for u in queues[sid]:
			u.p = _last_open_period(weights, from_p, last)
	# Coaching: evenly over the periods that take courses.
	var open := []
	for p in range(from_p, last + 1):
		if float(weights[p]) > 0.0:
			open.append(p)
	coach.sort_custom(func(a, b): return int(a.n) < int(b.n))
	for i in coach.size():
		coach[i].p = open[mini(open.size() - 1, i * open.size() / maxi(1, coach.size()))] if not open.is_empty() else last


static func _last_open_period(weights: Array, from_p: int, last: int) -> int:
	for p in range(last, from_p - 1, -1):
		if float(weights[p]) > 0.0:
			return p
	return last


## n items dealt out by weights (largest remainder): an Array of ints, one per weight.
static func _deal(n: int, weights: Array) -> Array:
	var sum := 0.0
	for w in weights:
		sum += float(w)
	var out := []
	var rests := []
	var given := 0
	for i in weights.size():
		var exact := n * float(weights[i]) / maxf(sum, 0.0001)
		out.append(floori(exact))
		given += floori(exact)
		rests.append({"i": i, "r": exact - floori(exact)})
	rests.sort_custom(func(a, b): return float(a.r) > float(b.r))
	var k := 0
	while given < n and not rests.is_empty():
		out[int(rests[k % rests.size()].i)] += 1
		given += 1
		k += 1
	return out


## The courses of a period, in subject order.
static func courses_in(L: Dictionary, p: int) -> Array:
	var out := []
	for u in L.units:
		if int(u.p) == p and str(u.st) in ["plan", "done"]:
			out.append(u)
	var order := {}
	var i := 0
	for s in cfg().subjects.list:
		order[str(s.id)] = i
		i += 1
	out.sort_custom(func(a, b):
		if str(a.s) != str(b.s):
			return int(order.get(str(a.s), 99)) < int(order.get(str(b.s), 99))
		return int(a.n) < int(b.n))
	return out


## Classroom courses of a period (the ones that weigh on school days; coaching is training).
static func class_count(L: Dictionary, p: int) -> int:
	var n := 0
	for u in courses_in(L, p):
		if is_classroom(u) and not bool(u.get("r", false)):
			n += 1
	return n


## "lighter" / "normal" / "heavier" for a period's classroom courses.
static func load_word(n: int) -> String:
	var normal := int(cfg().plan.normal_courses)
	return "lighter" if n < normal else ("heavier" if n > normal else "normal")


# --- The exam week ------------------------------------------------------------------------------------------------------------

## The exam days of a period's academic courses: {date key: [course ids]}. The days of the exam week are dealt out from the
## career's dice, at most two exams a day while the week has room.
static func exam_schedule(ss: SchoolSystem, L: Dictionary, p: int) -> Dictionary:
	var per := period_info(ss, L, p)
	var days: Array = per.exam
	var out := {}
	if days.is_empty():
		return out
	var list := []
	for u in courses_in(L, p):
		if kind_of(str(u.s)) == "academic":
			list.append(str(u.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = ss._seed("lukio_exams|%d" % p)
	var slots := []
	for d in days:
		slots.append(d)
	_shuffle(slots, rng)
	for i in list.size():
		var d: Dictionary = slots[i % slots.size()]
		var key := Calendar.date_key(d)
		if not out.has(key):
			out[key] = []
		out[key].append(list[i])
	return out


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


static func unit(L: Dictionary, uid: String) -> Dictionary:
	for u in L.units:
		if str(u.id) == uid:
			return u
	return {}


# --- Grades -------------------------------------------------------------------------------------------------------------------

## The subject's grade: the average of its graded courses rounded to a whole grade (0 = none yet).
static func subject_grade(L: Dictionary, sid: String) -> int:
	var total := 0.0
	var n := 0
	for u in _units_of(L, sid):
		if str(u.st) == "done" and int(u.g) >= 4:
			total += int(u.g)
			n += 1
	if n == 0:
		return 0
	return clampi(floori(total / n + 0.5), 4, 10)


## The subject's courses done / in the plan (dropped ones and the pool not counted).
static func subject_counts(L: Dictionary, sid: String) -> Dictionary:
	var done := 0
	var total := 0
	for u in _units_of(L, sid):
		if str(u.st) == "done":
			done += 1
			total += 1
		elif str(u.st) == "plan":
			total += 1
	return {"done": done, "total": total}


## Credits done and in the plan.
static func credits(L: Dictionary) -> Dictionary:
	var per := int(cfg().rules.credits_per_course)
	var done := 0
	var planned := 0
	for u in L.units:
		if str(u.st) == "done":
			done += per
			planned += per
		elif str(u.st) == "plan":
			planned += per
	return {"done": done, "planned": planned, "total": int(cfg().decree.total_min)}


## Whether a course can be left out now (sports lukio, compulsory, not an exam subject, at least half of the subject kept, at
## most `drop.courses` in all).
static func can_drop_comp(L: Dictionary, u: Dictionary) -> bool:
	var r: Dictionary = cfg().rules.drop
	if not bool(L.get("sports", false)) or str(u.k) != "comp" or str(u.st) != "plan":
		return false
	var dropped := 0
	for x in L.units:
		if str(x.st) == "drop":
			dropped += 1
	if dropped >= int(r.courses):
		return false
	for ex in L.matric.plan:
		if str(Matriculation.exam(str(ex)).get("subject", "")) == str(u.s):
			return false
	for res in L.matric.get("results", []):
		if str(Matriculation.exam(str(res.exam)).get("subject", "")) == str(u.s):
			return false
	var comp := comp_count(str(u.s), L)
	var left := 0
	for x in _units_of(L, str(u.s)):
		if str(x.k) == "comp" and str(x.st) != "drop":
			left += 1
	return left - 1 >= ceili(comp / 2.0)


static func dropped_count(L: Dictionary) -> int:
	var n := 0
	for x in L.units:
		if str(x.st) == "drop":
			n += 1
	return n
