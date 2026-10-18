class_name SchoolPathPart
extends RefCounted
## The joint application after grade 9, the path and moving (session S3a; split out of school_system.gd in the fix session 2026-10-18). Static functions over a SchoolSystem: the state (paths, applications) stays in the system, SchoolSystem forwards to these.

# --- The joint application and the path after grade 9 (session S3a) ----------------------------------------------------------------
# The state changes (the list is locked, the test is taken, the results decide the path) happen on their dates in every
# career, with sensible defaults; only with decisions_enabled (the real game) does the player get a stop for each of them.

## The application made in the spring of `year` ({} before it is touched).
static func application(me: SchoolSystem, year: int) -> Dictionary:
	return me.applications.get(str(year), {})


static func _app(me: SchoolSystem, year: int) -> Dictionary:
	var k := str(year)
	if not me.applications.has(k):
		me.applications[k] = {"wishes": [], "locked": false, "test": {}, "results": [], "decided": false}
	return me.applications[k]


## The application year the athlete is making now (the spring after this school year), 0 when the stage does not apply.
static func app_year_now(me: SchoolSystem) -> int:
	if Game.athlete == null or not bool(me.stage_of(Game.date).get("applies", false)):
		return 0
	return SchoolCalendar.year_of(Game.date) + 1


## "before" (the window has not opened), "open", "locked" (closed, no results yet) or "done" (the path is decided).
static func app_state(me: SchoolSystem, year: int) -> String:
	var A := application(me, year)
	if bool(A.get("decided", false)):
		return "done"
	var dt := SchoolApplication.dates(year)
	var k := Calendar.date_key(Game.date)
	if k < Calendar.date_key(dt.open):
		return "before"
	if k <= Calendar.date_key(dt.close) and not bool(A.get("locked", false)):
		return "open"
	return "locked"


static func can_edit_wishes(me: SchoolSystem, year: int) -> bool:
	return app_state(me, year) == "open"


static func wishes_of(me: SchoolSystem, year: int) -> Array:
	return application(me, year).get("wishes", [])


static func add_wish(me: SchoolSystem, year: int, wish_id: String) -> bool:
	if not can_edit_wishes(me, year) or wish_id in wishes_of(me, year) or wishes_of(me, year).size() >= int(Data.application.window.max_wishes):
		return false
	if SchoolApplication.option(wish_id, me._town()).is_empty():
		return false
	_app(me, year).wishes.append(wish_id)
	return true


static func remove_wish(me: SchoolSystem, year: int, wish_id: String) -> void:
	if can_edit_wishes(me, year):
		_app(me, year).wishes.erase(wish_id)


## Moves a wish one place up (-1) or down (+1) in the list.
static func move_wish(me: SchoolSystem, year: int, wish_id: String, step: int) -> void:
	if not can_edit_wishes(me, year):
		return
	var list: Array = _app(me, year).wishes
	var i := list.find(wish_id)
	var j := i + step
	if i < 0 or j < 0 or j >= list.size():
		return
	list[i] = list[j]
	list[j] = wish_id


static func set_wishes(me: SchoolSystem, year: int, list: Array) -> void:
	if not can_edit_wishes(me, year):
		return
	var out := []
	for w in list:
		if not SchoolApplication.option(str(w), me._town()).is_empty() and not str(w) in out and out.size() < int(Data.application.window.max_wishes):
			out.append(str(w))
	_app(me, year).wishes = out


## The application days: the window opens, the reminder, the test day, the results, and moving day.
static func _application_day(me: SchoolSystem, d: Dictionary) -> void:
	var key := Calendar.date_key(d)
	_arrival_day(me, d, key)
	var stage := me.stage_of(d)
	if not bool(stage.get("applies", false)):
		return
	var year := SchoolCalendar.year_of(d) + 1
	var dt := SchoolApplication.dates(year)
	if key == Calendar.date_key(dt.open):
		_open_window(me, year)
	elif key == Calendar.date_key(dt.remind):
		if not bool(_app(me, year).locked) and wishes_of(me, year).is_empty() and SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
			_post_apply(me, year, "remind")
	elif key == Calendar.date_key(dt.test):
		_test_day(me, year)
	elif key == Calendar.date_key(dt.results):
		_results(me, year)


static func _open_window(me: SchoolSystem, year: int) -> void:
	_app(me, year)
	if SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
		_post_apply(me, year, "open")


static func _post_apply(me: SchoolSystem, year: int, which: String) -> void:
	var c: Dictionary = Data.application.apply
	var dt := SchoolApplication.dates(year)
	var fill := {"from": Calendar.format_day(dt.open), "to": Calendar.format_day(dt.close), "max": int(Data.application.window.max_wishes), "town": me._town()}
	var second := bool(me.paths.size() > 0 and str(me.paths.back().kind) == "grade_10")
	var title := str(c.open_title if which == "open" else c.remind_title)
	var text := str(c.remind_text if which == "remind" else (c.open_text_10 if second else c.open_text)).format(fill)
	var choices := []
	for id in ["build", "suggest", "later"]:
		choices.append({"id": id, "label": str(c.choices[id].label), "detail": str(c.choices[id].detail)})
	var e := Game.post_event(me.id, title, text, choices, true)
	e.kind = "school_apply"
	e.year = year


## The list is closed on the last day: an empty list becomes the general lukio of the town you train in.
static func _lock_list(me: SchoolSystem, year: int) -> void:
	var A := _app(me, year)
	if bool(A.locked):
		return
	A.locked = true
	var c: Dictionary = Data.application.apply
	var empty: bool = A.wishes.is_empty()
	if empty:
		A.wishes = ["general"]
	if SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
		var names := []
		for w in A.wishes:
			names.append(str(SchoolApplication.option(str(w), me._town()).get("name", w)))
		Game.post_event(me.id, str(Data.application.ui.head).capitalize(), str(c.locked_default if empty else c.locked).format({"list": ", ".join(names)}))


static func _test_day(me: SchoolSystem, year: int) -> void:
	var A := _app(me, year)
	_lock_list(me, year)
	if not (A.test as Dictionary).is_empty():
		return
	var a := Game.athlete
	var sp := SchoolApplication.sport_points(a, year)
	var invited := []
	for w in A.wishes:
		var o := SchoolApplication.option(str(w), me._town())
		if str(o.get("kind", "")) == "sports" and float(sp.total) >= SchoolApplication.invite_min(o):
			invited.append(str(w))
	var t: Dictionary = Data.application.test
	if invited.is_empty():
		A.test = {"done": true, "invited": [], "base": 0.0, "steps": {}}
		if SchoolSystem.decisions_enabled and not SchoolSystem.neutral and _has_sports_wish(me, A.wishes):
			Game.post_event(me.id, str(t.title), str(t.done_none))
		return
	A.test = {"done": false, "invited": invited, "phys": SchoolApplication.physical_points(a), "interview": SchoolApplication.interview_points(a),
			"steps": {}, "base": 0.0}
	if SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
		_post_test_step(me, year, 0)
	else:
		for step in t.steps:
			_apply_step(me, year, str(step.id), str(step.auto))
		_finish_test(me, year)


static func _has_sports_wish(me: SchoolSystem, wishes: Array) -> bool:
	for w in wishes:
		if str(w).begins_with("sports:"):
			return true
	return false


static func _post_test_step(me: SchoolSystem, year: int, i: int) -> void:
	var t: Dictionary = Data.application.test
	var step: Dictionary = t.steps[i]
	var choices := []
	for o in step.options:
		choices.append({"id": str(o.id), "label": str(o.label), "detail": str(o.detail)})
	var e := Game.post_event(me.id, str(step.title), (str(t.intro) + "\n\n" if i == 0 else "") + str(step.text), choices, true)
	e.kind = "school_test"
	e.year = year
	e.step = i


static func _apply_step(me: SchoolSystem, year: int, step_id: String, option_id: String) -> void:
	var A := _app(me, year)
	A.test.steps[step_id] = {"option": option_id, "delta": SchoolApplication.step_delta(me, year, step_id, option_id)}


static func _finish_test(me: SchoolSystem, year: int) -> void:
	var A := _app(me, year)
	var base: float = float(A.test.phys) + float(A.test.interview)
	for s in A.test.steps.values():
		base += float(s.delta)
	A.test.base = clampf(base, 0.0, float(Data.application.points.school.max))
	A.test.done = true
	if SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
		var t: Dictionary = Data.application.test
		Game.post_event(me.id, str(t.done_title), str(t.done_text).format({"date": Calendar.format_day(SchoolApplication.dates(year).results)}))


## Results day: every wish in order against its limit; the first that accepts you is your place.
static func _results(me: SchoolSystem, year: int) -> void:
	var A := _app(me, year)
	if bool(A.decided):
		return
	_lock_list(me, year)
	if (A.test as Dictionary).is_empty() or not bool(A.test.get("done", false)):
		A.test = {}
		_test_day_auto(me, year)
	var rows := SchoolApplication.evaluate(me, A.wishes, year)
	A.results = rows
	var place := ""
	for r in rows:
		if str(r.status) == "yes":
			place = str(r.wish)
			break
	if not (SchoolSystem.decisions_enabled and not SchoolSystem.neutral):
		_decide(me, year, place if place != "" else "general")
		return
	var c: Dictionary = Data.application.results
	var lines := [str(c.intro)]
	for r in rows:
		lines.append(SchoolApplication.result_line(r))
	var choices := []
	var fill := {"town": me._town(), "date": Calendar.format_day(SchoolApplication.dates(year).accept_by)}
	if place != "":
		var o := SchoolApplication.option(place, me._town())
		fill.name = str(o.name)
		fill.town = str(o.town)
		lines.append(str(c.accepted).format(fill))
		choices.append({"id": "accept", "label": str(c.accept_choice.label), "detail": str(c.accept_choice.detail).format(fill)})
		choices.append({"id": "decline", "label": str(c.decline_choice.label), "detail": str(c.decline_choice.detail)})
	else:
		lines.append(str(c.none))
		choices = _fallback_choices(me)
	var e := Game.post_event(me.id, str(c.title), "\n".join(lines), choices, true)
	e.kind = "school_result"
	e.year = year
	e.wish = place


static func _fallback_choices(me: SchoolSystem) -> Array:
	var c: Dictionary = Data.application.results
	var out := []
	for k in ["general", "vocational", "grade_10"]:
		out.append({"id": k, "label": str(c.none_choices[k].label).format({"town": me._town()}), "detail": str(c.none_choices[k].detail).format({"town": me._town()})})
	return out


## The test of a career that reached results day without one (a save from before, a tool): every step with its auto answer.
static func _test_day_auto(me: SchoolSystem, year: int) -> void:
	var A := _app(me, year)
	var a := Game.athlete
	var sp := SchoolApplication.sport_points(a, year)
	var invited := []
	for w in A.wishes:
		var o := SchoolApplication.option(str(w), me._town())
		if str(o.get("kind", "")) == "sports" and float(sp.total) >= SchoolApplication.invite_min(o):
			invited.append(str(w))
	if invited.is_empty():
		A.test = {"done": true, "invited": [], "base": 0.0, "steps": {}}
		return
	A.test = {"done": false, "invited": invited, "phys": SchoolApplication.physical_points(a), "interview": SchoolApplication.interview_points(a), "steps": {}, "base": 0.0}
	for step in Data.application.test.steps:
		_apply_step(me, year, str(step.id), str(step.auto))
	var base: float = float(A.test.phys) + float(A.test.interview)
	for s in A.test.steps.values():
		base += float(s.delta)
	A.test.base = clampf(base, 0.0, float(Data.application.points.school.max))
	A.test.done = true


## Puts the athlete on the path of a wish ("general" / "vocational" / "grade_10" / "sports:<id>") from the next 1 August.
static func _decide(me: SchoolSystem, year: int, wish_id: String) -> void:
	var A := _app(me, year)
	A.decided = true
	var kind := ""
	var school := ""
	var wtown := me._town()
	var name := ""
	if wish_id == "grade_10":
		kind = "grade_10"
		name = str(Data.school_life.stages.secondary.grade_10.name)
	else:
		var o := SchoolApplication.option(wish_id, me._town())
		if o.is_empty():
			o = SchoolApplication.option("general", me._town())
		kind = SchoolApplication.path_kind(o)
		school = str(o.school.get("id", ""))
		wtown = str(o.town)
		name = str(o.name)
	me.paths.append({"kind": kind, "school": school, "town": wtown, "start_year": year, "years": int(Data.school_life.stages.secondary[kind].years)})
	me._stage_cache = {}
	me._exam_days = {}
	me._schedules = {}
	var rows: Array = A.results
	var top := not rows.is_empty() and str(rows[0].status) == "yes"
	var any := false
	for r in rows:
		if str(r.status) == "yes":
			any = true
	var c: Dictionary = Data.application.results
	var ms := MindSystem.sys()
	if ms != null and not SchoolSystem.neutral and SchoolSystem.decisions_enabled:
		if any and wish_id != "general" and wish_id != "vocational":
			ms.add("confidence", float(c.news_delta.top if top else c.news_delta.yes), str(c.news_top if top else c.news_yes).format({"name": name}))
		elif not any:
			ms.add("confidence", float(c.news_delta.no), str(c.news_no))
	if SchoolSystem.decisions_enabled:
		Game.post_event(me.id, str(c.title), str(c.path_message_10 if kind == "grade_10" else c.path_message).format({"name": name, "town": wtown}))


## Moving day and the first day at a new school (1 August of a path's first year).
static func _arrival_day(me: SchoolSystem, d: Dictionary, key: int) -> void:
	if d.month != 8 or d.day != 1:
		return
	for sgm in me.paths:
		if int(sgm.start_year) != int(d.year) or bool(sgm.get("arrived", false)):
			continue
		sgm.arrived = true
		var new_town := str(sgm.town)
		if new_town != "" and new_town != me._town():
			_move_to(me, new_town, str(sgm.get("school", "")))
		if SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
			_post_arrival(me, sgm)
		if str(sgm.kind) == "urheilulukio" and SchoolSystem.decisions_enabled and CoachMarket.enabled:
			var cm := CoachMarket.sys()
			var school := _school_row(me, str(sgm.school))
			if cm != null and not school.is_empty():
				cm.post_academy_offer(cm.add_academy_coach(school), school)


static func _school_row(me: SchoolSystem, school_id: String) -> Dictionary:
	for s in Data.urheilulukiot.schools:
		if str(s.id) == school_id:
			return s
	return {}


static func _post_arrival(me: SchoolSystem, sgm: Dictionary) -> void:
	var c: Dictionary = Data.application.arrival
	var row := _school_row(me, str(sgm.school))
	var name := str(row.get("name", Data.application.ui.kinds.get(str(sgm.kind), "")))
	var text := ""
	match str(sgm.kind):
		"urheilulukio":
			var days := []
			for i in Data.application.morning.schools.get(str(sgm.school), Data.application.morning.default):
				days.append(str(c.morning_names[int(i)]))
			var centre := ""
			var t := Data.get_town(str(sgm.town))
			if t.has("centre") and t.centre != null:
				for x in Data.urheilulukiot.centres.list:
					if str(x.id) == str(t.centre):
						centre = str(c.centre).format({"centre": str(x.name)})
			text = str(c.urheilulukio).format({"name": name, "days": ", ".join(days), "centre": centre})
		"lukio":
			text = str(c.lukio).format({"name": name})
		"vocational":
			text = str(c.vocational).format({"name": name})
		_:
			text = str(c.grade_10)
	Game.post_event(me.id, str(c.title), text)


## Moves the athlete to `town` for school: the town they live and train in changes (the club stays), the old coach is now far
## away, the coaches around the new town appear in the market, the old coach and the group say goodbye.
static func _move_to(me: SchoolSystem, town_name: String, school_id: String) -> void:
	var a := Game.athlete
	var old := CoachSystem.home_town(a)
	var cs := Game.get_system("coach") as CoachSystem
	var head: Dictionary = cs.head() if cs != null else {}
	a.training_town = town_name
	var m: Dictionary = Data.application.moving
	if SchoolSystem.decisions_enabled and not SchoolSystem.neutral:
		var row := _school_row(me, school_id)
		var text := str(m.text_dorm if school_id in m.dorm else m.text_flat).format({"town": town_name, "school": str(row.get("name", "")), "old": old})
		Game.post_event(me.id, str(m.title).format({"town": town_name}), text)
		var ms := Game.get_system("moments") as StoryletSystem
		var cm := CoachMarket.sys()
		if ms != null and cm != null and not head.is_empty():
			ms.say("coach", str(head.id), cm.line(head, "farewell", {"new": town_name}))
			var mates := ms.people_for("teammate")
			if not mates.is_empty():
				var rng := RandomNumberGenerator.new()
				rng.seed = me._seed("goodbye|" + town_name)
				ms.say("group", str(mates[rng.randi_range(0, mates.size() - 1)].id), str(m.group_goodbye).format({"town": town_name}))
	var market := CoachMarket.sys()
	if market != null and CoachMarket.enabled:
		market.refresh_for_move()
