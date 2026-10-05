extends Control
## Career home screen: athlete profile, weekly training plan and last week's report.
## "Continue" plays one week of training.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const VIEWS := [["overview", "Overview"], ["training", "Training"], ["report", "Last week"]]

var _view := "overview"
var _tabs := {}   # view id -> tab Button

@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	%MenuButton.pressed.connect(Router.go.bind("main_menu"))
	var cont := UIKit.button("Continue", true, 160)
	cont.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cont.tooltip_text = "Play one week of training"
	cont.pressed.connect(_on_continue)
	%MenuButton.add_sibling(cont)
	%MenuButton.get_parent().move_child(cont, %MenuButton.get_index())

	var bar := UIKit.hbox(8)
	var group := ButtonGroup.new()
	for v in VIEWS:
		var b := UIKit.toggle(v[1], group)
		b.custom_minimum_size.x = 140
		b.pressed.connect(_show.bind(v[0]))
		bar.add_child(b)
		_tabs[v[0]] = b
	var column: Control = _content.get_parent().get_parent()
	column.add_child(bar)
	column.move_child(bar, 1)
	_refresh_header()
	_show("overview")


func _on_continue() -> void:
	Game.advance_week()
	_refresh_header()
	_show("report")


func _refresh_header() -> void:
	var a := Game.athlete
	var club := Data.get_club(a.club_id)
	%NameLabel.text = a.full_name()
	%InfoLabel.text = "%s · %d years · %s · %s" % [
		Data.get_event(a.main_event).name, a.age_on(Game.date), club.get("name", ""), a.hometown]
	%DateLabel.text = "Mon %d %s %d" % [Game.date.day, MONTHS[Game.date.month - 1], Game.date.year]
	_tabs.report.disabled = Game.last_report.is_empty()


func _show(view: String) -> void:
	_view = view
	_tabs[view].button_pressed = true
	for child in _content.get_children():
		child.queue_free()
	match view:
		"overview": _build_profile(Game.athlete)
		"training": _build_training()
		"report": _build_report(Game.last_report)


# --- Overview ---------------------------------------------------------------------------

func _build_profile(a: Athlete) -> void:
	var columns := UIKit.hbox(16)
	for category in ["physical", "technical", "mental"]:
		var col := UIKit.vbox(6)
		col.add_child(UIKit.label(category.to_upper(), "CaptionLabel"))
		for attr in Data.attributes_in(category):
			var row := UIKit.attr_row(attr.name, a.get_attr(attr.id), a.trend(attr.id))
			row.tooltip_text = attr.description
			col.add_child(row)
		columns.add_child(_column_panel(col))

	var body := UIKit.vbox(6)
	body.add_child(UIKit.label("CONDITION", "CaptionLabel"))
	body.add_child(_fact_row("Fatigue", _fatigue_label(a.fatigue)))
	body.add_child(UIKit.label(" "))
	body.add_child(UIKit.label("BODY", "CaptionLabel"))
	for f in [
		["Height", "%d cm" % a.height_cm],
		["Weight", "%d kg" % a.weight_kg],
		["Development", {"early": "Early", "average": "Average", "late": "Late"}[a.maturation]],
		["Born", UIKit.format_date(a.birth_date)],
	]:
		body.add_child(_fact_row(f[0], UIKit.label(f[1])))
	body.add_child(UIKit.label(" "))
	body.add_child(UIKit.label("PERSONAL BESTS", "CaptionLabel"))
	body.add_child(UIKit.wrapped("No races yet. Your first season starts soon.", "MutedLabel"))
	columns.add_child(_column_panel(body))
	_content.add_child(columns)

	_content.add_child(UIKit.wrapped(
			"Arrows show attributes that have been rising or falling lately. Plan your week under Training, then press Continue.",
			"MutedLabel"))


# --- Training plan ----------------------------------------------------------------------

func _build_training() -> void:
	var a := Game.athlete
	var month: int = Game.add_days(Game.date, 3).month
	_content.add_child(UIKit.label("Weekly plan", "HeadingLabel"))
	_content.add_child(UIKit.wrapped(
			"Your plan repeats every week until you change it. Up to %d sessions a day; an empty day is a rest day."
			% Training.MAX_SESSIONS_PER_DAY))

	var summary := UIKit.vbox(8)
	var refresh_summary := func(): _fill_plan_summary(summary, a, month)

	var days := UIKit.vbox(8)
	for day in 7:
		days.add_child(_day_row(day, a, month, refresh_summary))
	_content.add_child(UIKit.panel(days, 16))

	var buttons := UIKit.hbox(8)
	var coach := UIKit.button("Coach's plan", false, 160)
	coach.tooltip_text = "Reset to your club coach's starter week"
	coach.pressed.connect(func(): Game.training_plan = Training.coach_plan(); _show("training"))
	var clear := UIKit.button("Clear week", false, 160)
	clear.pressed.connect(func(): Game.training_plan = Training.empty_plan(); _show("training"))
	buttons.add_child(coach)
	buttons.add_child(clear)
	_content.add_child(buttons)

	_content.add_child(UIKit.panel(summary, 16))
	refresh_summary.call()
	_content.add_child(_session_library(a, month))


func _day_row(day: int, a: Athlete, month: int, on_change: Callable) -> HBoxContainer:
	var row := UIKit.hbox(10)
	var date := Game.add_days(Game.date, day)
	var day_label := UIKit.label("%s %d.%d." % [Training.DAY_NAMES[day], date.day, date.month])
	day_label.custom_minimum_size.x = 100
	row.add_child(day_label)
	var slots := []
	for slot in Training.MAX_SESSIONS_PER_DAY:
		var pick := _session_picker(a, month)
		var current: Array = Game.training_plan[day]
		var id: String = current[slot] if slot < current.size() else ""
		for i in pick.item_count:
			if pick.get_item_metadata(i) == id:
				pick.select(i)
		slots.append(pick)
		row.add_child(pick)
	var load_label := UIKit.label("", "MutedLabel")
	row.add_child(load_label)

	var update := func():
		var ids := []
		for p in slots:
			var sid: String = p.get_item_metadata(p.selected)
			if sid != "":
				ids.append(sid)
		Game.training_plan[day] = ids
		var load := 0.0
		for sid in ids:
			load += Training.session_load(a, Data.get_session(sid))
		load_label.text = "Rest day" if ids.is_empty() else "Load %d" % roundi(load)
	for p in slots:
		p.item_selected.connect(func(_i): update.call(); on_change.call())
	update.call()
	return row


func _session_picker(a: Athlete, month: int) -> OptionButton:
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(250, 44)
	pick.add_item("—")
	pick.set_item_metadata(0, "")
	for s in Data.training.sessions:
		var eff := Training.effectiveness(a, s, month)
		var text: String = s.name
		if eff > 0.0 and eff < 1.0:
			text += " (no track)"
		pick.add_item(text)
		var i := pick.item_count - 1
		pick.set_item_metadata(i, s.id)
		pick.set_item_tooltip(i, s.description)
		if eff == 0.0:
			pick.set_item_disabled(i, true)
			pick.set_item_tooltip(i, "Not possible this time of year")
	return pick


func _fill_plan_summary(box: VBoxContainer, a: Athlete, month: int) -> void:
	for child in box.get_children():
		child.queue_free()
	var p := Training.preview(a, Game.training_plan, month)
	var expected := Training.expected_fatigue(a, Game.training_plan, Game.date)
	var verdict: String
	if expected.avg < 15.0:
		verdict = "Light: easy to recover from, but slower progress."
	elif expected.avg < 45.0:
		verdict = "Balanced: you should recover well between sessions."
	elif expected.avg < 65.0:
		verdict = "Hard: heavy legs, and training gives less when you're tired. Plan lighter weeks too."
	else:
		verdict = "Too much: you'll be exhausted, so most of the training is wasted."

	box.add_child(UIKit.label("THIS PLAN", "CaptionLabel"))
	box.add_child(_fact_row("Weekly load", UIKit.label(str(roundi(p.load)))))
	var fat := UIKit.hbox(6)
	fat.add_child(_fatigue_label(expected.avg))
	fat.add_child(UIKit.label("on average after a few weeks", "MutedLabel"))
	box.add_child(_fact_row("Expected fatigue", fat))
	box.add_child(UIKit.wrapped(verdict, ""))

	box.add_child(UIKit.label("TRAINING FOCUS", "CaptionLabel"))
	var focus: Array = p.stimulus.keys()
	focus.sort_custom(func(x, y): return p.stimulus[x] > p.stimulus[y])
	if focus.is_empty():
		box.add_child(UIKit.wrapped("Nothing planned: a full rest week."))
	for id in focus:
		var row := UIKit.hbox(10)
		var l := UIKit.label(_attr_name(id))
		l.custom_minimum_size.x = 200
		row.add_child(l)
		var bar := ColorRect.new()
		bar.color = Palette.ACCENT
		bar.custom_minimum_size = Vector2(minf(p.stimulus[id], 6.0) * 50.0, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		box.add_child(row)


func _session_library(a: Athlete, month: int) -> PanelContainer:
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label("SESSIONS", "CaptionLabel"))
	for s in Data.training.sessions:
		var col := UIKit.vbox(2)
		var title := UIKit.hbox(8)
		title.add_child(UIKit.label(s.name, "SubheadingLabel"))
		title.add_child(UIKit.label("load %d" % s.load, "MutedLabel"))
		col.add_child(title)
		var trains := []
		for id in s.effects:
			trains.append(_attr_name(id).to_lower())
		var text: String = "%s Trains %s." % [s.description, ", ".join(trains)]
		var eff := Training.effectiveness(a, s, month)
		if eff == 0.0:
			text += " Not possible this time of year."
		elif eff < 1.0:
			text += " You have no indoor track this winter, so it's done on roads instead (less effective)."
		col.add_child(UIKit.wrapped(text))
		box.add_child(col)
	return UIKit.panel(box, 16)


# --- Weekly report ----------------------------------------------------------------------

func _build_report(r: Dictionary) -> void:
	if r.is_empty():
		return
	var a := Game.athlete
	var sunday := Game.add_days(r.monday, 6)
	_content.add_child(UIKit.label("Week %d.%d. – %d.%d.%d" % [
			r.monday.day, r.monday.month, sunday.day, sunday.month, sunday.year], "HeadingLabel"))

	var facts := UIKit.vbox(6)
	facts.add_child(_fact_row("Sessions", UIKit.label(str(r.sessions))))
	facts.add_child(_fact_row("Training load", UIKit.label(str(roundi(r.load)))))
	var fat := UIKit.hbox(6)
	fat.add_child(_fatigue_label(r.fatigue_start))
	fat.add_child(UIKit.label("→", "MutedLabel"))
	fat.add_child(_fatigue_label(r.fatigue_end))
	facts.add_child(_fact_row("Fatigue (Mon → Sun)", fat))
	_content.add_child(UIKit.panel(facts, 16))

	for note in r.notes:
		_content.add_child(UIKit.wrapped("• " + note, ""))

	var up := []
	var down := []
	for id in r.changes:
		var c: Dictionary = r.changes[id]
		if roundi(c.after) != roundi(c.before):
			(up if c.after > c.before else down).append(id)
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label("ATTRIBUTES", "CaptionLabel"))
	if up.is_empty() and down.is_empty():
		box.add_child(UIKit.wrapped("No attribute has moved up a whole point this week. Progress builds up slowly, so keep going."))
	for id in up + down:
		var c: Dictionary = r.changes[id]
		var row := UIKit.hbox(8)
		var l := UIKit.label(_attr_name(id))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.attr_value_label(c.before))
		row.add_child(UIKit.label("→", "MutedLabel"))
		row.add_child(UIKit.trend_arrow(1 if c.after > c.before else -1))
		row.add_child(UIKit.attr_value_label(c.after))
		box.add_child(row)
	var improving := []
	for category in Training.TRAINED_CATEGORIES:
		for attr in Data.attributes_in(category):
			if a.trend(attr.id) > 0:
				improving.append(attr.name.to_lower())
	if not improving.is_empty():
		box.add_child(UIKit.wrapped("Improving lately: %s." % ", ".join(improving)))
	_content.add_child(UIKit.panel(box, 16))


# --- Helpers ------------------------------------------------------------------------------

func _fact_row(key: String, value: Control) -> HBoxContainer:
	var row := UIKit.hbox()
	var k := UIKit.label(key, "MutedLabel")
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.custom_minimum_size.x = 140
	row.add_child(k)
	row.add_child(value)
	return row


func _fatigue_label(fatigue: float) -> Label:
	var state := Training.fatigue_state(fatigue)
	var l := UIKit.label("%s (%d)" % [state[0], roundi(fatigue)])
	l.add_theme_color_override("font_color", state[1])
	return l


func _attr_name(id: String) -> String:
	for attr in Data.attributes:
		if attr.id == id:
			return attr.name
	return id


func _column_panel(content: Control) -> PanelContainer:
	var p := UIKit.panel(content, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return p
