class_name SchoolEventPanel
extends RefCounted
## The report card day as a stop (SchoolSystem, event.kind "school_card"; GDD 4.9.3, session S2): the card with every grade, the
## average and how it moved since the last card, a word on it, and the choice for the next term as 44 px buttons (keep going,
## study harder, ease off; the final certificate only Continue). The meet-and-tests decision needs nothing special: the generic
## stop panel shows its title, text and three answers. Texts: data/school_life.json `card` and `ui.card_panel`.


static func handles(e: Dictionary) -> bool:
	return str(e.get("source", "")) == "school" and str(e.get("kind", "")) == "school_card" and SchoolUI.system() != null \
			and int(e.get("index", -1)) >= 0 and int(e.get("index", -1)) < SchoolUI.system().reports.size()


## The panel content for event `e`, `width` px wide; `on_answer(choice id)` is called with the player's answer.
static func build(e: Dictionary, width: float, on_answer: Callable) -> Control:
	var ss := SchoolUI.system()
	var index := int(e.index)
	var r: Dictionary = ss.reports[index]
	var prev: Dictionary = ss.reports[index - 1] if index > 0 else {}
	var p: Dictionary = Data.school_life.ui.card_panel
	var c: Dictionary = Data.school_life.card
	var box := UIKit.vbox(12)
	box.custom_minimum_size.x = width
	box.add_child(UIKit.label("%s · %s" % [str(p.head), Calendar.format_day(e.date).to_upper()], "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(e.title), "HeadingLabel"))
	box.add_child(UIKit.wrapped(str(e.text), ""))

	var card := UIKit.vbox(6)
	var avg := float(r.average)
	var avg_label := UIKit.label("%.2f" % avg, "SubheadingLabel")
	avg_label.add_theme_color_override("font_color", SchoolUI.grade_color(avg))
	card.add_child(UIKit.fact_row(str(p.avg), avg_label))
	card.add_child(UIKit.fact_row(str(p.avg_academic), UIKit.label("%.2f" % float(r.academic_average))))
	if prev.is_empty():
		card.add_child(UIKit.wrapped(str(c.first), "MutedLabel"))
	else:
		var delta := avg - float(prev.average)
		var arrow := ""
		if absf(delta) >= 0.005:
			arrow = "%s %.2f" % [str(Data.mind.ui.arrow_up if delta > 0.0 else Data.mind.ui.arrow_down), absf(delta)]
		var d := UIKit.label(arrow if arrow != "" else "-")
		if arrow != "":
			d.add_theme_color_override("font_color", Palette.ATTR_EXCELLENT if delta > 0.0 else Palette.ATTR_POOR)
		card.add_child(UIKit.fact_row(str(p.since), d))
		card.add_child(UIKit.wrapped(_verdict(delta), ""))
	card.add_child(UIKit.wrapped(_level(avg), ""))
	var best := ""
	var worst := ""
	var hi := -1
	var lo := 99
	for s in ss.subject_list():
		var g := int(r.grades.get(str(s.id), 0))
		if g > hi:
			hi = g
			best = str(s.name)
		if g < lo:
			lo = g
			worst = str(s.name)
	card.add_child(UIKit.fact_row(str(p.best), UIKit.label("%s %d" % [best, hi])))
	card.add_child(UIKit.fact_row(str(p.weakest), UIKit.label("%s %d" % [worst, lo])))
	box.add_child(UIKit.panel(card, 14))

	var grades := UIKit.vbox(4)
	grades.add_child(UIKit.label(str(p.grades), "CaptionLabel"))
	var grid := GridContainer.new()
	grid.columns = 1 if Layout.compact else 2   # (a phone: one column, the long subject names need the room)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 2)
	for s in ss.subject_list():
		grid.add_child(_grade_cell(str(s.name), int(r.grades.get(str(s.id), 0)), int(prev.get("grades", {}).get(str(s.id), 0))))
	grades.add_child(grid)
	box.add_child(UIKit.panel(grades, 14))

	box.add_child(UIKit.wrapped(str(c.choose_final if str(r.kind) == "final" else c.choose), "SubheadingLabel"))
	for ch in e.choices:
		var b := UIKit.button(str(ch.label), false, 200)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): on_answer.call(str(ch.id)))
		box.add_child(b)
		if str(ch.get("detail", "")) != "":
			box.add_child(UIKit.wrapped(str(ch.detail)))
	return box


## "Maths  8  ▲": the grade in its colour and whether it rose or fell since the last card.
static func _grade_cell(subject_name: String, grade: int, before: int) -> Control:
	var row := UIKit.hbox(6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UIKit.label(subject_name)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.custom_minimum_size.x = 135
	row.add_child(n)
	var trend := 0
	if before > 0:
		trend = 1 if grade > before else (-1 if grade < before else 0)
	row.add_child(UIKit.trend_arrow(trend))
	var g := UIKit.label(str(grade), "AttrValueLabel")
	g.add_theme_color_override("font_color", SchoolUI.grade_color(float(grade)))
	g.custom_minimum_size.x = 26
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(g)
	return row


static func _verdict(delta: float) -> String:
	for v in Data.school_life.card.verdict:
		if delta >= float(v.delta):
			return str(v.text)
	return ""


static func _level(avg: float) -> String:
	for l in Data.school_life.card.level:
		if avg >= float(l.min):
			return str(l.text)
	return ""
