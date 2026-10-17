class_name LukioEventPanel
extends VBoxContainer
## The lukio's stops that need more than buttons (GDD 4.9.3, session S3b): a period's courses (the LukioCoursesEditor), a
## period's results (every course of it with its grade, the retakes, the subject grades now) and the matriculation plan / a
## session's registration (the MatricPlanView with the coach's line). The rest (the three lukio choices, an exam day, the
## results of a session, the certificate) use the generic stop panel. Emits `rebuilt` when its content changes (the hub fits the
## card again). Texts: data/lukio.json `stops` and `ui`.

signal rebuilt

const KINDS := ["lukio_courses", "lukio_results", "matric_plan"]
const MAX_WIDTH := 620.0   # (wider than the usual 480 on PC: the plan's session buttons and the course rows)


static func handles(e: Dictionary) -> bool:
	return str(e.get("source", "")) == "school" and str(e.get("kind", "")) in KINDS and SchoolUI.system() != null \
			and not SchoolUI.system().lukio.is_empty()


func _init(e: Dictionary, width: float, on_answer: Callable) -> void:
	add_theme_constant_override("separation", 12)
	custom_minimum_size.x = width
	var ss := SchoolUI.system()
	var L: Dictionary = ss.lukio
	add_child(UIKit.label(Calendar.format_day(e.date).to_upper(), "CaptionLabel"))
	add_child(UIKit.wrapped(str(e.title), "HeadingLabel"))
	add_child(UIKit.wrapped(str(e.text), ""))
	match str(e.kind):
		"lukio_courses":
			var ed := LukioCoursesEditor.new(int(e.period))
			ed.changed.connect(func(): rebuilt.emit())
			add_child(UIKit.panel(ed, 14))
		"lukio_results":
			add_child(UIKit.panel(_results(ss, L, e), 14))
		"matric_plan":
			var line := _coach_line()
			if line != "":
				add_child(UIKit.wrapped(line, ""))
			var mp := MatricPlanView.new()
			mp.changed.connect(func(): rebuilt.emit())
			add_child(UIKit.panel(mp, 14))
	for ch in e.choices:
		var b := UIKit.button(str(ch.label), true, 200)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): on_answer.call(str(ch.id)))
		add_child(b)


## The period's courses with their grades, the retakes and the subject grades now.
func _results(ss: SchoolSystem, L: Dictionary, e: Dictionary) -> Control:
	var u: Dictionary = Data.lukio.ui
	var c: Dictionary = Data.lukio.stops
	var box := UIKit.vbox(4)
	var index := int(e.get("index", -1))
	var rep: Dictionary = ss.reports[index] if index >= 0 and index < ss.reports.size() else {}
	var courses: Array = rep.get("courses", [])
	if courses.is_empty():
		box.add_child(UIKit.wrapped(str(c.results_none), "MutedLabel"))
	for x in courses:
		var g := int(x.g)
		var row := UIKit.hbox(8)
		var n := UIKit.label(Lukio.course_name(x, L))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		row.add_child(n)
		var v := UIKit.label(str(u.passed) if g < 0 else str(g), "AttrValueLabel")
		if g >= 4:
			v.add_theme_color_override("font_color", SchoolUI.grade_color(float(g)))
		row.add_child(v)
		box.add_child(row)
	for x in L.units:
		if bool(x.get("r", false)) and int(x.p) == int(e.period) + 1:
			box.add_child(UIKit.wrapped(str(c.results_retake).format({"course": Lukio.course_name(x, L)}), ""))
	var subj := []
	for sid in rep.get("grades", {}):
		subj.append("%s %d" % [Lukio.subject_name(str(sid), L), int(rep.grades[sid])])
	if not subj.is_empty():
		box.add_child(UIKit.wrapped(str(u.results_subjects).format({"list": ", ".join(subj)}), "MutedLabel"))
	return box


## The head coach's word on the sessions (the autumn exams come after the summer's meets).
static func _coach_line() -> String:
	var cs := Game.get_system("coach") as CoachSystem
	if cs == null:
		return ""
	var head: Dictionary = cs.head()
	if head.is_empty():
		return ""
	var st: Dictionary = Data.lukio.stops
	return str(st.coach_line).format({"coach": str(head.get("name", "")), "line": str(st.coach_lines.autumn)})
