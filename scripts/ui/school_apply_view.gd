class_name SchoolApplyView
extends VBoxContainer
## The joint application and the school you go to (GDD 4.9.3, session S3a), on the School page: while the athlete is in grade 9 (or a
## 10th-grade year) the application panel (the points now, the wish list in order, every school you can add with what is known
## about it, the results afterwards), and from the first day at a new school the YOUR SCHOOL panel (the kind of school, its town,
## the years, the morning practice, the athletics centre). Reading the SchoolSystem and changing only the wish list; the list can
## be changed while the window is open. Every control is at least 44 px; a phone stacks the rows. Texts: data/application.json `ui`.

## Which schools' details are open (wish id -> bool), kept while the view redraws.
static var open := {}


func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var ss := SchoolUI.system()
	if ss == null:
		return
	var year := ss.app_year_now()
	if year > 0:
		add_child(_application(ss, year))
	var path := _path(ss)
	if path != null:
		add_child(path)


static func ui() -> Dictionary:
	return Data.application.ui


# --- The application ---------------------------------------------------------------------------------------------------------

func _application(ss: SchoolSystem, year: int) -> Control:
	var u := ui()
	var dt := SchoolApplication.dates(year)
	var state := ss.app_state(year)
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label(str(u.head), "CaptionLabel"))
	var text := ""
	match state:
		"before":
			text = str(u.closed).format({"date": Calendar.format_day(dt.open)})
		"open":
			text = str(u.open_state).format({"date": Calendar.format_day(dt.close)})
		"locked":
			text = str(u.locked_state).format({"date": Calendar.format_day(dt.results)})
		_:
			text = str(u.done_state)
	box.add_child(UIKit.wrapped(text, ""))
	if state == "before":
		return UIKit.panel(box, 14)
	box.add_child(_points(ss, year))
	box.add_child(_wishes(ss, year, state))
	var results: Array = ss.application(year).get("results", [])
	if not results.is_empty():
		box.add_child(_results(results))
	elif state == "open":
		box.add_child(_options(ss, year))
	return UIKit.panel(box, 14)


## The three parts of the points as they stand now.
func _points(ss: SchoolSystem, year: int) -> Control:
	var u := ui()
	var col := UIKit.vbox(3)
	col.add_child(UIKit.label(str(u.points_head), "CaptionLabel"))
	var avg := SchoolApplication.average_now(ss)
	col.add_child(UIKit.wrapped(str(u.points_grades).format({"avg": "%.2f" % avg, "pts": "%.1f" % SchoolApplication.grade_points(avg)}), ""))
	var sp := SchoolApplication.sport_points(Game.athlete, year)
	if float(sp.best) > 0.0:
		col.add_child(UIKit.wrapped(str(u.points_sport).format({"pts": "%.1f" % float(sp.total), "time": Calendar.format_time(float(sp.best))}), ""))
	else:
		col.add_child(UIKit.wrapped(str(u.points_sport_none), ""))
	var test: Dictionary = ss.application(year).get("test", {})
	if not test.is_empty() and bool(test.get("done", false)):
		if (test.get("invited", []) as Array).is_empty():
			col.add_child(UIKit.wrapped(str(u.points_school_none), ""))
		else:
			col.add_child(UIKit.wrapped(str(u.points_school_done).format({"pts": "%.1f" % float(test.base)}), ""))
	else:
		col.add_child(UIKit.wrapped(str(u.points_school), ""))
	col.add_child(UIKit.wrapped(str(u.points_note), "MutedLabel"))
	return col


## The list in order, with Up / Down / Remove while the window is open.
func _wishes(ss: SchoolSystem, year: int, state: String) -> Control:
	var u := ui()
	var col := UIKit.vbox(6)
	col.add_child(UIKit.label(str(u.list_head), "SubheadingLabel"))
	var list: Array = ss.wishes_of(year)
	if list.is_empty():
		col.add_child(UIKit.wrapped(str(u.list_empty), "MutedLabel"))
	var editable := state == "open"
	for i in list.size():
		var wid := str(list[i])
		var o := SchoolApplication.option(wid, ss.town())
		var title := UIKit.wrapped("%d. %s" % [i + 1, str(o.get("name", wid))], "")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UIKit.vbox(4)   # (the name above, the three buttons under it: a narrow column never squeezes the name)
		row.add_child(title)
		if editable:
			var buttons := UIKit.hbox(6)
			for spec in [[str(u.up), -1, i > 0], [str(u.down), 1, i < list.size() - 1]]:
				var b := UIKit.button(str(spec[0]), false, 56)
				b.disabled = not bool(spec[2])
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.pressed.connect(func():
					ss.move_wish(year, wid, int(spec[1]))
					_build())
				buttons.add_child(b)
			var rm := UIKit.button(str(u.remove), false, 80)
			rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rm.pressed.connect(func():
				ss.remove_wish(year, wid)
				_build())
			buttons.add_child(rm)
			row.add_child(buttons)
		col.add_child(row)
	if editable and list.size() >= int(Data.application.window.max_wishes):
		col.add_child(UIKit.wrapped(str(u.full).format({"max": int(Data.application.window.max_wishes)}), "MutedLabel"))
	return col


## Every school that is not on the list yet, with what is known about it (tap Info) and an Add button.
func _options(ss: SchoolSystem, year: int) -> Control:
	var u := ui()
	var col := UIKit.vbox(8)
	col.add_child(UIKit.label(str(u.choices_head), "SubheadingLabel"))
	var list: Array = ss.wishes_of(year)
	var full := list.size() >= int(Data.application.window.max_wishes)
	for o in SchoolApplication.options(ss.town()):
		var wid := str(o.id)
		if wid in list:
			continue
		var head := UIKit.vbox(0)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(UIKit.wrapped(str(o.name), ""))
		head.add_child(UIKit.wrapped(_summary(ss, o, year), "MutedLabel"))
		var detail := UIKit.wrapped(_info(ss, o, year), "MutedLabel")
		detail.visible = bool(open.get(wid, false))
		var info := UIKit.button(str(u.info), false, 64)
		var add := UIKit.button(str(u.add), true, 64)
		add.disabled = full
		var buttons := UIKit.hbox(6)
		buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_END
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_END
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_END
		buttons.add_child(info)
		buttons.add_child(add)
		info.pressed.connect(func():
			detail.visible = not detail.visible
			open[wid] = detail.visible)
		add.pressed.connect(func():
			ss.add_wish(year, wid)
			_build())
		var row := UIKit.flex(6)
		row.add_child(head)
		row.add_child(buttons)
		var item := UIKit.vbox(4)
		item.add_child(row)
		item.add_child(detail)
		col.add_child(item)
	return col


## One line under a school's name: its town, the last limit and whether you would move.
func _summary(ss: SchoolSystem, o: Dictionary, year: int) -> String:
	var u := ui()
	var parts := [str(o.town)]
	var cut := SchoolApplication.cutoff(ss, o, year, false)
	if str(cut.kind) == "points":
		parts.append(("~%.1f" if bool(cut.estimated) else "%.1f") % float(cut.value))
	if str(o.town) != ss.town():
		parts.append(str(u.info_move).trim_suffix("."))
	return " · ".join(parts)


## What is known about a school, from the data: the programme, the limit, places, morning practice, dorm, minimums and your points there.
func _info(ss: SchoolSystem, o: Dictionary, year: int) -> String:
	var u := ui()
	var lines := []
	var s: Dictionary = o.school
	if str(o.kind) == "sports":
		lines.append(str(s.get("programme", "")))
		lines.append(str(u.info_athletics.get(str(s.get("athletics", "unverified")), "")))
		if s.get("places") != null:
			lines.append(str(u.info_places).format({"n": int(s.places)}))
		if s.get("morning_practice") != null:
			lines.append(str(u.info_morning).format({"text": str(s.morning_practice)}))
		if s.get("dorm") != null:
			lines.append(str(u.info_dorm) + " " + str(s.dorm))
		if s.get("min_grade") != null:
			lines.append(str(u.info_min).format({"pts": "%.1f" % float(s.min_grade)}))
		lines.append(str(u.info_invite).format({"pts": "%.1f" % SchoolApplication.invite_min(o)}))
	var cut := SchoolApplication.cutoff(ss, o, year, false)
	if str(cut.kind) == "avg":
		lines.append(str(u.info_cutoff_avg).format({"pts": "%.1f" % float(cut.value)}))
	elif bool(cut.estimated):
		lines.append(str(u.info_cutoff_est).format({"pts": "%.1f" % float(cut.value)}))
	else:
		lines.append(str(u.info_cutoff).format({"pts": "%.2f" % float(cut.value), "year": int(cut.year), "approx": " (approx.)" if bool(cut.approx) else ""}))
	lines.append(str(u.info_move if str(o.town) != ss.town() else u.info_stay))
	if str(o.kind) == "sports":
		var pv := SchoolApplication.preview(ss, o, year)
		var guess: bool = ss.application(year).get("test", {}).is_empty()
		lines.append(str(u.info_now).format({"pts": "%.1f" % float(pv.total),
				"note": str(u.info_now_guess).format({"guess": "%.0f" % float(Data.application.points.school.guess)}) if guess else ""}))
	return "\n".join(lines.filter(func(x): return str(x) != ""))


func _results(rows: Array) -> Control:
	var col := UIKit.vbox(4)
	col.add_child(UIKit.label(str(ui().results_head), "SubheadingLabel"))
	for r in rows:
		col.add_child(UIKit.wrapped(SchoolApplication.result_line(r), ""))
	return col


# --- Your school ---------------------------------------------------------------------------------------------------------------

## The school the athlete goes to now (null before the first path and in grades 8-9).
func _path(ss: SchoolSystem) -> Control:
	var stage := ss.stage_of(Game.date)
	if not Data.school_life.stages.secondary.has(str(stage.id)):
		return null
	var u := ui()
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label(str(u.path_head), "CaptionLabel"))
	var seg := ss.current_path()
	if str(stage.id) == "graduated" or seg.is_empty():
		box.add_child(UIKit.wrapped(str(u.after_school), ""))
		return UIKit.panel(box, 14)
	var row: Dictionary = {}
	for s in Data.urheilulukiot.schools:
		if str(s.id) == str(seg.school):
			row = s
	var school_name := str(row.get("name", u.kinds.get(str(seg.kind), "")))
	box.add_child(UIKit.wrapped(str(u.path_line).format({"name": school_name, "town": str(seg.town), "years": str(u.years.get(str(int(seg.years)), "%d years" % int(seg.years)))}), "SubheadingLabel"))
	box.add_child(UIKit.wrapped(str(u.kinds.get(str(seg.kind), "")), "MutedLabel"))
	box.add_child(UIKit.wrapped(str(u.path_arrive).format({"date": Calendar.format_day({"year": int(seg.start_year), "month": 8, "day": 1})}), "MutedLabel"))
	var y := SchoolCalendar.year_for(str(seg.town), int(seg.start_year) + int(seg.years) - 1)
	box.add_child(UIKit.wrapped(str(u.path_end).format({"date": Calendar.format_day(y.end)}), "MutedLabel"))
	if bool(stage.get("morning", false)):
		var days := []
		var names: Array = Data.application.arrival.morning_names
		for i in Data.application.morning.schools.get(str(seg.school), Data.application.morning.default):
			days.append(str(names[int(i)]))
		box.add_child(UIKit.wrapped(str(u.path_morning).format({"days": ", ".join(days)}), ""))
		var t := Data.get_town(str(seg.town))
		if t.get("centre") != null:
			for x in Data.urheilulukiot.centres.list:
				if str(x.id) == str(t.centre):
					box.add_child(UIKit.wrapped(str(u.path_centre).format({"centre": str(x.name)}), ""))
	if str(seg.kind) == "vocational":
		box.add_child(UIKit.wrapped(str(u.vocational_note), "MutedLabel"))
	return UIKit.panel(box, 14)
