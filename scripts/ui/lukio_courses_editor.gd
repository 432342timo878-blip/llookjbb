class_name LukioCoursesEditor
extends VBoxContainer
## The courses of the period that starts (GDD 4.9.3, session S3b; the period's stop, user: a stop at the start of every period):
## each course with what kind it is and 44 px Later / Drop buttons, the optional courses that can be added, and in a sports lukio
## the compulsory courses left out (with Put back). Changes go through SchoolSystem (course_later / course_add / course_drop /
## course_put_back), which keeps the whole lukio at 75 courses. Emits `changed` after every change. Texts: data/lukio.json `ui`.

signal changed

var _p := -1


func _init(period: int) -> void:
	_p = period
	add_theme_constant_override("separation", 8)
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
	var editable := ss.editable_period() == _p
	var list := Lukio.courses_in(L, _p)
	var n := Lukio.class_count(L, _p)
	add_child(UIKit.label(str(u.editor_head), "CaptionLabel"))
	add_child(UIKit.wrapped(str(u.editor_load).format({"n": n, "load": str(u.period_load[Lukio.load_word(n)])}), ""))
	for c in list:
		add_child(_course_row(ss, L, c, editable))
	if editable:
		add_child(UIKit.label(str(u.add_head), "CaptionLabel"))
		var cands := ss.add_candidates(_p)
		if cands.is_empty():
			add_child(UIKit.wrapped(str(u.nothing_to_add), "MutedLabel"))
		for c in cands:
			var row := _row(Lukio.course_name(c, L), str(u.course_kinds.opt))
			var b := UIKit.button(str(u.add), true, 72)
			b.pressed.connect(func():
				ss.course_add(str(c.id))
				_build()
				changed.emit())
			row.add_child(b)
			add_child(row)
	if bool(L.get("sports", false)):
		var r: Dictionary = Data.lukio.rules.drop
		add_child(UIKit.label(str(u.drop_head), "CaptionLabel"))
		add_child(UIKit.wrapped(str(u.drop_text).format({"max": int(r.courses)}), "MutedLabel"))
		add_child(UIKit.wrapped(str(u.drop_used).format({"n": Lukio.dropped_count(L), "max": int(r.courses)}), ""))
		for c in L.units:
			if str(c.st) != "drop":
				continue
			var row := _row(Lukio.course_name(c, L), str(u.course_kinds.comp))
			if editable:
				var b := UIKit.button(str(u.put_back), false, 96)
				b.pressed.connect(func():
					ss.course_put_back(str(c.id))
					_build()
					changed.emit())
				row.add_child(b)
			add_child(row)
	var cr := Lukio.credits(L)
	add_child(UIKit.wrapped(str(u.credits).format({"done": int(cr.done), "total": int(cr.total), "planned": int(cr.planned)}), "MutedLabel"))


func _course_row(ss: SchoolSystem, L: Dictionary, c: Dictionary, editable: bool) -> Control:
	var u: Dictionary = Data.lukio.ui
	var kind := str(u.course_kinds.retake) if bool(c.get("r", false)) else str(u.course_kinds.get(str(c.k), ""))
	var col := UIKit.vbox(4)
	var row := _row(Lukio.course_name(c, L), kind)
	col.add_child(row)
	if not editable or str(c.st) != "plan":
		return col
	var buttons := UIKit.hbox(6)
	if _p + 1 < Lukio.period_count(L) and not bool(c.get("r", false)):
		var later := UIKit.button(str(u.later), false, 80)
		later.pressed.connect(func():
			ss.course_later(str(c.id))
			_build()
			changed.emit())
		buttons.add_child(later)
	if str(c.k) == "opt" or Lukio.can_drop_comp(L, c):
		var drop := UIKit.button(str(u.drop), false, 80)
		drop.pressed.connect(func():
			ss.course_drop(str(c.id))
			_build()
			changed.emit())
		buttons.add_child(drop)
	if buttons.get_child_count() > 0:
		if Layout.compact:
			for b in buttons.get_children():
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(buttons)
		else:
			row.add_child(buttons)
	return col


## "Finnish 3   compulsory" (the name expands; buttons are added by the caller).
static func _row(title: String, kind: String) -> HBoxContainer:
	var row := UIKit.hbox(8)
	row.custom_minimum_size.y = 44
	var name_box := UIKit.vbox(0)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := UIKit.label(title)
	n.clip_text = true
	name_box.add_child(n)
	if kind != "":
		name_box.add_child(UIKit.label(kind, "CaptionLabel"))
	row.add_child(name_box)
	return row
