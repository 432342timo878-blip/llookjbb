extends Control
## Career home screen: athlete header, tabs (Overview / Training / Calendar / Rankings / Last week) and
## Continue, which plays one week. Wide layout on PC (tabs on top); on a phone the content is stacked and
## the tabs sit in a bar at the bottom, within thumb reach.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## id, tab text, short tab text (phone)
const VIEWS := [["overview", "Overview", "Overview"], ["training", "Training", "Training"],
		["calendar", "Calendar", "Calendar"], ["rankings", "Rankings", "Rankings"], ["report", "Last week", "Report"]]
const MONTH_NAMES := ["January", "February", "March", "April", "May", "June", "July", "August",
		"September", "October", "November", "December"]

var _view := "overview"
var _tabs := {}   # view id -> tab Button
var _margin: MarginContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _name_label: Label
var _info_label: Label
var _date_label: Label


func _ready() -> void:
	Router.layout_changed.connect(func(_c): _build_shell(); _show(_view))
	_build_shell()
	# Coming back from a race day: show how the week went.
	_show("report" if Game.open_report and not Game.last_report.is_empty() else "overview")
	Game.open_report = false


## Header, tab bar, scrolling content. Rebuilt when the window switches between wide and phone layout.
func _build_shell() -> void:
	if _margin:
		_margin.queue_free()
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	Layout.page_margin(_margin)
	add_child(_margin)
	var column := UIKit.vbox(10 if Layout.compact else 16)
	_margin.add_child(column)

	column.add_child(_build_header())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content = UIKit.vbox(14)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_tabs.clear()
	var group := ButtonGroup.new()
	var bar := UIKit.hbox(4)
	for v in VIEWS:
		var b := Button.new()
		b.text = v[2] if Layout.compact else v[1]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "BottomTabButton" if Layout.compact else "TabButton"
		b.custom_minimum_size = Vector2(0 if Layout.compact else 130, 48 if Layout.compact else 44)
		if Layout.compact:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show.bind(v[0]))
		bar.add_child(b)
		_tabs[v[0]] = b
	if Layout.compact:
		column.add_child(_scroll)
		column.add_child(HSeparator.new())
		column.add_child(bar)
	else:
		column.add_child(bar)
		column.add_child(HSeparator.new())
		column.add_child(_scroll)
	_refresh_header()


func _build_header() -> Control:
	_name_label = UIKit.label("", "TitleLabel")
	_info_label = UIKit.wrapped("")
	_date_label = UIKit.label("", "SubheadingLabel")
	var cont := UIKit.button("Continue", true, 160)
	cont.pressed.connect(_on_continue)
	var save := UIKit.button("Save", false, 110)
	save.pressed.connect(func():
		SaveGame.save_snapshot()
		save.text = "Saved ✓"
		get_tree().create_timer(1.5).timeout.connect(func(): save.text = "Save"))
	var menu := UIKit.button("Menu" if Layout.compact else "Main menu", false, 140)
	menu.pressed.connect(Router.go.bind("main_menu"))

	if Layout.compact:
		var box := UIKit.vbox(6)
		var top := UIKit.hbox(8)
		_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_label.clip_text = true
		top.add_child(_name_label)
		top.add_child(menu)
		box.add_child(top)
		box.add_child(_info_label)
		var actions := UIKit.hbox(8)
		_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_date_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		actions.add_child(_date_label)
		actions.add_child(save)
		cont.custom_minimum_size.x = 130
		actions.add_child(cont)
		box.add_child(actions)
		return box

	var row := UIKit.hbox(16)
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_name_label)
	titles.add_child(_info_label)
	row.add_child(titles)
	_date_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_date_label.custom_minimum_size.y = 44
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_date_label)
	for b in [cont, save, menu]:
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(b)
	return row


func _on_continue() -> void:
	if Game.advance_week():
		Router.go("race")
		return
	_refresh_header()
	_show("report")


func _refresh_header() -> void:
	var a := Game.athlete
	var club := Data.get_club(a.club_id)
	_name_label.text = a.full_name()
	_info_label.text = "%s · %d years · %s · %s" % [
		Data.get_event(a.main_event).name, a.age_on(Game.date), club.get("name", ""), a.hometown]
	_date_label.text = "Mon %d %s %d" % [Game.date.day, MONTHS[Game.date.month - 1], Game.date.year]
	_tabs.report.disabled = Game.last_report.is_empty()


func _show(view: String) -> void:
	_view = view
	_tabs[view].button_pressed = true
	_scroll.scroll_vertical = 0
	for child in _content.get_children():
		child.queue_free()
	match view:
		"overview": _build_profile(Game.athlete)
		"training": _build_training()
		"calendar": _build_calendar()
		"rankings": _build_rankings()
		"report": _build_report(Game.last_report)


# --- Overview ---------------------------------------------------------------------------

func _build_profile(a: Athlete) -> void:
	var columns := UIKit.flex(16)
	var attribute_panels := []
	for category in ["physical", "technical", "mental"]:
		var col := UIKit.vbox(2)
		col.add_child(UIKit.label(category.to_upper(), "CaptionLabel"))
		for attr in Data.attributes_in(category):
			col.add_child(UIKit.attr_row(attr.name, a.get_attr(attr.id), a.trend(attr.id), attr.description))
		attribute_panels.append(_column_panel(col))
	if not Layout.compact:
		for p in attribute_panels:
			columns.add_child(p)

	var body := UIKit.vbox(6)
	body.add_child(UIKit.label("CONDITION", "CaptionLabel"))
	body.add_child(_fact_row("Fatigue", _fatigue_label(a.fatigue)))
	body.add_child(UIKit.label(" "))
	body.add_child(UIKit.label("NEXT RACE", "CaptionLabel"))
	var next := Game.next_race()
	if next.is_empty():
		body.add_child(UIKit.wrapped("No races entered. Pick some in the Calendar.", "MutedLabel"))
	else:
		body.add_child(UIKit.wrapped(next.name, ""))
		body.add_child(UIKit.wrapped("%s · %s" % [Calendar.format_meet_date(next), Calendar.place(a, next)], "MutedLabel"))
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
	body.add_child(UIKit.label("PERSONAL BEST", "CaptionLabel"))
	var pb: float = a.personal_bests.get(a.main_event, 0.0)
	if pb == 0.0:
		body.add_child(UIKit.wrapped("No races yet. Enter some in the Calendar.", "MutedLabel"))
	else:
		body.add_child(_fact_row(Data.get_event(a.main_event).name, UIKit.label(Calendar.format_time(pb))))
		body.add_child(UIKit.label(" "))
		body.add_child(UIKit.label("RECENT RACES", "CaptionLabel"))
		for r in a.results.slice(-5):
			var where: String = "" if r.round == "Race" else " (%s)" % r.round.to_lower()
			var line := "%d.%d. %s%s: %s %s" % [int(r.date.day), int(r.date.month), r.meet, where,
					Race._ordinal(int(r.place)), Calendar.format_time(r.time)]
			body.add_child(UIKit.wrapped(line + (" PB" if r.pb else ""), "MutedLabel"))
	columns.add_child(_column_panel(body))
	if Layout.compact:   # condition and next race first, then the attributes
		for p in attribute_panels:
			columns.add_child(p)
	_content.add_child(columns)

	_content.add_child(UIKit.wrapped(
			"Arrows show attributes that have been rising or falling lately. Tap an attribute to see what it does. "
			+ "Plan your week under Training, then press Continue.", "MutedLabel"))


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

	var days := UIKit.vbox(14 if Layout.compact else 8)
	for day in 7:
		if day > 0 and Layout.compact:
			days.add_child(HSeparator.new())
		days.add_child(_day_row(day, a, month, refresh_summary))
	_content.add_child(UIKit.panel(days, 16))

	var buttons := UIKit.hbox(8)
	var coach := UIKit.button("Coach's plan", false, 160)
	coach.pressed.connect(func(): Game.training_plan = Training.coach_plan(); _show("training"))
	var clear := UIKit.button("Clear week", false, 160)
	clear.pressed.connect(func(): Game.training_plan = Training.empty_plan(); _show("training"))
	buttons.add_child(coach)
	buttons.add_child(clear)
	if Layout.compact:
		coach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(buttons)
	_content.add_child(UIKit.wrapped("Coach's plan puts back the starter week your club coach suggests."))

	_content.add_child(UIKit.panel(summary, 16))
	refresh_summary.call()
	_content.add_child(_session_library(a, month))


## One day of the plan. Wide: day, two pickers and the load on one row. Phone: a header line
## (day + load) with the two pickers stacked under it.
func _day_row(day: int, a: Athlete, month: int, on_change: Callable) -> Control:
	var date := Game.add_days(Game.date, day)
	var day_label := UIKit.label("%s %d.%d." % [Training.DAY_NAMES[day], date.day, date.month],
			"SubheadingLabel" if Layout.compact else "")
	var load_label := UIKit.label("", "MutedLabel")
	var row: BoxContainer
	var slot_parent: Control
	if Layout.compact:
		row = UIKit.vbox(6)
		var head := UIKit.hbox(8)
		day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(day_label)
		head.add_child(load_label)
		row.add_child(head)
		slot_parent = row
	else:
		row = UIKit.hbox(10)
		day_label.custom_minimum_size.x = 100
		row.add_child(day_label)
		slot_parent = row
	var slots := []
	for slot in Training.MAX_SESSIONS_PER_DAY:
		var pick := _session_picker(a, month)
		var current: Array = Game.training_plan[day]
		var id: String = current[slot] if slot < current.size() else ""
		for i in pick.item_count:
			if pick.get_item_metadata(i) == id:
				pick.select(i)
		slots.append(pick)
		slot_parent.add_child(pick)
	if not Layout.compact:
		load_label.custom_minimum_size.x = 80
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
	pick.custom_minimum_size = Vector2(0 if Layout.compact else 200, 44)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	fat.add_child(UIKit.label("on average", "MutedLabel"))
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
		l.custom_minimum_size.x = 150 if Layout.compact else 200
		row.add_child(l)
		var bar := ColorRect.new()
		bar.color = Palette.ACCENT
		bar.custom_minimum_size = Vector2(minf(p.stimulus[id], 6.0) * (30.0 if Layout.compact else 50.0), 12)
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


# --- Calendar ---------------------------------------------------------------------------

func _build_calendar() -> void:
	var a := Game.athlete
	_content.add_child(UIKit.label("Season calendar", "HeadingLabel"))
	_content.add_child(UIKit.wrapped(
			"Enter the meets you want to race; a race replaces that day's training. Tap \"Entered\" again to withdraw. "
			+ "★ = your coach recommends it. "
			+ "\"Estimated\" dates are believable guesses for small meets whose real dates aren't published."))

	# The rest of this season and the whole next one.
	var meets := Calendar.meets_between(Game.date, {"year": Game.date.year + 1, "month": 10, "day": 31})
	var month := -1
	var box: VBoxContainer
	for m in meets:
		if m.date.month != month:
			month = m.date.month
			_content.add_child(UIKit.label("%s %d" % [MONTH_NAMES[month - 1].to_upper(), m.date.year], "CaptionLabel"))
			box = UIKit.vbox(18 if Layout.compact else 14)
			_content.add_child(UIKit.panel(box, 16))
		box.add_child(_meet_row(a, m))


## One meet. Wide: date | details | Enter button. Phone: date, details, then a full-width button.
func _meet_row(a: Athlete, m: Dictionary) -> Control:
	var row: BoxContainer = UIKit.vbox(6) if Layout.compact else UIKit.hbox(16)
	var date := UIKit.label(Calendar.format_meet_date(m), "CaptionLabel" if Layout.compact else "")
	if Layout.compact:
		date.text = date.text.to_upper()
	else:
		date.custom_minimum_size.x = 120
		date.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(date)

	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: String = m.name + ("  ★" if Calendar.coach_recommends(a, m, Game.date) else "")
	info.add_child(UIKit.wrapped(title, "SubheadingLabel" if not m.get("watch", false) else ""))
	var details := [Calendar.place(a, m), Data.competitions.levels.get(m.level, "")]
	if m.get("indoor", false):
		details.append("Indoor")
	if m.get("estimated", false):
		details.append("Estimated date")
	var fee := Calendar.fee_text(m)
	if fee != "" and not m.get("watch", false):
		details.append(fee)
	info.add_child(UIKit.wrapped(" · ".join(details), "MutedLabel"))
	if m.has("description"):
		info.add_child(UIKit.wrapped(m.description, "MutedLabel"))
	var check := Calendar.can_enter(a, m, Game.date)
	var standard := Calendar.standard_text(a, m)
	if check.ok and standard != "":
		info.add_child(UIKit.wrapped(standard, ""))
	if not check.ok:
		info.add_child(UIKit.wrapped(check.reason, "MutedLabel"))
	row.add_child(info)

	if check.ok:
		var b := UIKit.button("", false, 150)
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var refresh := func():
			var entered: bool = m.key in Game.entries
			b.text = "Entered ✓" if entered else "Enter"
			b.theme_type_variation = "PrimaryButton" if entered else ""
		b.pressed.connect(func():
			if m.key in Game.entries:
				Game.withdraw(m.key)
			else:
				Game.enter(m.key)
			refresh.call())
		refresh.call()
		row.add_child(b)
	return row


# --- Rankings ---------------------------------------------------------------------------

const RANKING_TOP := 25

func _build_rankings() -> void:
	var a := Game.athlete
	var season := Rankings.season_of(Game.date)
	var event_name: String = Data.get_event(a.main_event).name
	_content.add_child(UIKit.label("%s %s · season %s" % [
			Calendar.age_class(a, Game.date.year), event_name, Rankings.season_label(season)], "HeadingLabel"))
	_content.add_child(UIKit.wrapped(
			"Season bests (1 Nov – 31 Oct), indoor and outdoor together. Rivals race on their own too, so the list "
			+ "fills up as the season goes on."))

	var rows := Rankings.season_list(a, Game.rivals, season)
	var box := UIKit.vbox(6)
	var mine := 0
	for r in rows:
		if r.is_player:
			mine = r.rank
	if mine == 0:
		box.add_child(UIKit.wrapped("You have no %s time this season yet. Enter a race in the Calendar." % event_name))
	else:
		box.add_child(UIKit.wrapped("You're ranked %d of %d." % [mine, rows.size()]))
	box.add_child(UIKit.label(" "))
	box.add_child(_ranking_header())
	for r in rows:
		if r.rank <= RANKING_TOP or r.is_player:
			if r.rank == RANKING_TOP + 1 or (r.rank > RANKING_TOP + 1 and r.is_player):
				box.add_child(UIKit.label("…", "MutedLabel"))
			box.add_child(_ranking_row(r))
	if rows.is_empty():
		box.add_child(UIKit.wrapped("No results this season yet."))
	_content.add_child(UIKit.panel(box, 16))


## Column widths: rank, athlete (0 = takes the free space), club (hidden on a phone), season best.
func _ranking_columns() -> Array:
	if Layout.compact:
		return [["#", 36], ["ATHLETE", 0], ["SB", 80]]
	return [["#", 50], ["ATHLETE", 260], ["CLUB", 0], ["SB", 90]]


func _ranking_header() -> HBoxContainer:
	var row := UIKit.hbox(10)
	for c in _ranking_columns():
		var l := UIKit.label(c[0], "CaptionLabel")
		l.custom_minimum_size.x = c[1]
		if c[1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if c[0] == "SB":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
	return row


func _ranking_row(r: Dictionary) -> Control:
	var row := UIKit.hbox(10)
	row.custom_minimum_size.y = 30
	var texts := [str(r.rank), r.name, Calendar.format_time(r.time)] if Layout.compact \
			else [str(r.rank), r.name, r.club, Calendar.format_time(r.time)]
	var columns := _ranking_columns()
	for i in columns.size():
		var l := UIKit.label(texts[i], "" if r.is_player else "MutedLabel")
		l.custom_minimum_size.x = columns[i][1]
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if columns[i][1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
		if columns[i][0] == "SB":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if r.is_player:
			l.add_theme_color_override("font_color", Palette.ACCENT)
		row.add_child(l)
	if not r.is_player:
		return row
	# Highlight the player's own row.
	var tint := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.ACCENT, 0.12)
	style.set_corner_radius_all(Palette.RADIUS)
	style.expand_margin_left = 8     # the tint reaches past the text so columns stay aligned
	style.expand_margin_right = 8
	tint.add_theme_stylebox_override("panel", style)
	tint.add_child(row)
	return tint


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
