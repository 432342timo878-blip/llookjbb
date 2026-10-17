class_name MatricPlanView
extends VBoxContainer
## The matriculation exam plan (GDD 4.9.3, session S3b): the sessions (each with its registration deadline, or locked with the
## exams registered), every exam the athlete can take with a 44 px toggle per open session ("-" = not taking it), the board's
## rules as ✓ / ✗ lines, "Use the counsellor's plan", the results so far and the certificate. Used on the School page and in the
## plan / registration stops. Changes go through SchoolSystem.set_matric (which refuses what the rules don't allow). Emits
## `changed` after every change (the stop panel refits itself). Texts: data/lukio.json `ui`.

signal changed

## Whether the subjects that are not in the plan are listed (kept while the view redraws).
static var show_all := false


func _init() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var ss := SchoolUI.system()
	if ss == null or ss.lukio.is_empty():
		return
	var u: Dictionary = Data.lukio.ui
	var L: Dictionary = ss.lukio
	add_child(UIKit.label(str(u.matric_head), "CaptionLabel"))
	add_child(UIKit.wrapped(str(u.matric_text), "MutedLabel"))
	var sessions: Array = ss.matric_sessions()
	var main: Array = ss.matric_main_sessions()
	var names := []
	for k in main:
		names.append(Matriculation.session_name(str(k)))
	add_child(UIKit.wrapped(str(u.matric_sessions).format({"list": ", ".join(names)}), ""))
	# The sessions: locked ones with what is registered, open ones with their deadline.
	for k in sessions:
		var sk := str(k)
		var line := ""
		if sk in L.matric.locked:
			var ex := []
			for x in L.matric.registered.get(sk, []):
				ex.append(Matriculation.exam_name(str(x), L))
			line = "%s · %s: %s" % [_cap(Matriculation.session_name(sk)), str(u.matric_locked), ", ".join(ex)]
		elif ss.matric_open(sk) and (sk in main or _plan_has(L, sk)):
			line = "%s · %s" % [_cap(Matriculation.session_name(sk)), str(u.matric_closes).format({"date": Calendar.format_day(Matriculation.deadline(sk))})]
		if line != "":
			add_child(UIKit.wrapped(line, "MutedLabel"))
	# The exams: the plan's and the passed ones first, then (on request) the others.
	var open := []
	for k in sessions:
		if ss.matric_open(str(k)):
			open.append(str(k))
	var best := ss.matric_best()
	var listed := []
	for ex in Matriculation.available(L):
		if L.matric.plan.has(ex) or best.has(ex):
			listed.append(ex)
	var others := []
	for ex in Matriculation.available(L):
		if not ex in listed:
			others.append(ex)
	for ex in listed:
		add_child(_exam_row(ss, L, str(ex), open, best))
	if not others.is_empty():
		var more := UIKit.button(("▾ " if show_all else "▸ ") + str(u.matric_more).format({"n": others.size()}), false, 200)
		more.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
		more.pressed.connect(func():
			show_all = not show_all
			_build()
			changed.emit())
		add_child(more)
		if show_all:
			for ex in others:
				add_child(_exam_row(ss, L, str(ex), open, best))
	# The rules.
	add_child(UIKit.label(str(u.matric_rules), "CaptionLabel"))
	var chk := Matriculation.check(ss.matric_set(), L, L.matric.plan)
	for l in chk.lines:
		var row := UIKit.wrapped("%s %s" % [str(u.rule_ok if bool(l.ok) else u.rule_bad), str(l.text)], "")
		row.add_theme_color_override("font_color", Palette.ATTR_EXCELLENT if bool(l.ok) else Palette.ATTR_POOR)
		add_child(row)
	if not open.is_empty():
		var sug := UIKit.button(str(u.matric_suggest), false, 200)
		sug.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
		sug.pressed.connect(func():
			ss.matric_fill_suggestion()
			_build()
			changed.emit())
		add_child(sug)
	# Results and the certificate.
	if not (L.matric.results as Array).is_empty():
		add_child(UIKit.label(str(u.matric_results_head), "CaptionLabel"))
		for r in L.matric.results:
			var g := str(r.grade)
			var row := UIKit.wrapped(str(u.matric_result_line).format({"session": _cap(Matriculation.session_name(str(r.session))),
					"exam": Matriculation.exam_name(str(r.exam), L), "grade": g}), "")
			row.add_theme_color_override("font_color", Color(str(u.grade_colors.get(g, "#ffffff"))))
			add_child(row)
	if bool(L.matric.cert):
		var pts := 0
		for ex in best:
			if Matriculation.passed(str(best[ex])):
				pts += Matriculation.points(str(best[ex]))
		add_child(UIKit.wrapped(str(u.matric_certificate).format({"points": pts, "n": best.size()}), "SubheadingLabel"))


static func _plan_has(L: Dictionary, key: String) -> bool:
	for ex in L.matric.plan:
		if str(L.matric.plan[ex]) == key:
			return true
	return false


## One exam: its name, where it stands (passed / registered) and a toggle per open session.
func _exam_row(ss: SchoolSystem, L: Dictionary, ex: String, open: Array, best: Dictionary) -> Control:
	var u: Dictionary = Data.lukio.ui
	var col := UIKit.vbox(4)
	var head := UIKit.wrapped(Matriculation.exam_name(ex, L), "SubheadingLabel")
	col.add_child(head)
	var now := str(L.matric.plan.get(ex, ""))
	var notes := []
	if best.has(ex):
		notes.append("%s %s" % [str(u.passed) if Matriculation.passed(str(best[ex])) else "", str(best[ex])])
	if now != "" and not ss.matric_open(now):
		notes.append("%s (%s)" % [_cap(Matriculation.session_name(now)), str(u.matric_locked)])
	if not notes.is_empty():
		col.add_child(UIKit.wrapped(" · ".join(notes).strip_edges(), "MutedLabel"))
	if (now == "" or ss.matric_open(now)) and not open.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		var group := ButtonGroup.new()
		var none := UIKit.toggle(str(u.matric_not_taken), group)
		none.custom_minimum_size = Vector2(56, 44)
		none.button_pressed = now == ""
		none.pressed.connect(func():
			ss.set_matric(ex, "")
			_build()
			changed.emit())
		flow.add_child(none)
		var main: Array = ss.matric_main_sessions()
		for k in open:
			if not str(k) in main and now != str(k) and not ss.matric_allowed(ex, str(k)):
				continue   # (a later session only for retakes and better grades: not shown when it isn't possible)
			var b := UIKit.toggle(_cap(Matriculation.session_name(str(k))), group)
			b.custom_minimum_size = Vector2(0, 44)
			b.button_pressed = now == str(k)
			b.disabled = now != str(k) and not ss.matric_allowed(ex, str(k))
			b.pressed.connect(func():
				ss.set_matric(ex, str(k))
				_build()
				changed.emit())
			flow.add_child(b)
		col.add_child(flow)
	return col


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)
