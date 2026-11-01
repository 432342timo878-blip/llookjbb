class_name CareerView
extends VBoxContainer
## The Career tab (GDD 4.10 decision 10, session K1a). Four pages behind one row of toggles: NOW (the next big thing and the long path,
## your name, the season goals, the personal best over time, the season list), RESULTS (every race, filtered by season, level and meet
## name; a tap opens the "what this race did" card where one was kept), TIMELINE (the milestones) and PROFILE (the old athlete page:
## attributes, body, recent races; built by the hub). Reading only. Texts: data/career.json `ui`, data/reputation.json `texts`; the help
## entry is "career". V1 look (GDD 5): panels, CaptionLabel heads, BigNumber for the one number a block is about.

signal card_pressed(id: String)
signal review_pressed(year: int)   # (K1b) a season's review from the Seasons page

const PAGES := ["now", "results", "timeline", "seasons", "profile"]

## Kept while the hub rebuilds the page (a resize, a card answered).
static var page := "now"
static var results_year := 0          # 0 = every season
static var results_level := ""        # "" = every meet, else local / district / national (national also holds international and elite)
static var results_text := ""
static var rep_open := false

var _profile_builder: Callable
var _on_goals_ask: Callable
var _body: VBoxContainer
var _list: VBoxContainer


func _init(profile_builder: Callable, on_goals_ask: Callable) -> void:
	_profile_builder = profile_builder
	_on_goals_ask = on_goals_ask
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build()


static func ui() -> Dictionary:
	return Data.career.ui


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bar := UIKit.hbox(4 if Layout.compact else 6)
	add_child(bar)   # (in the tree first: the buttons' styles are looked up through the theme)
	var group := ButtonGroup.new()
	for p in PAGES:
		var b := UIKit.toggle(str(ui().tabs[p]), group)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = p == page
		var id: String = p
		b.pressed.connect(func():
			page = id
			_show_page())
		bar.add_child(b)
		if Layout.compact:   # five pages in a 480 px column: a smaller word and less padding, so no word is cut and the page stays narrow
			b.add_theme_font_size_override("font_size", 14)
			b.clip_text = true
			for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
				var sb := b.get_theme_stylebox(state)
				if sb is StyleBoxFlat:
					var tight: StyleBoxFlat = sb.duplicate()
					tight.content_margin_left = 3.0
					tight.content_margin_right = 3.0
					b.add_theme_stylebox_override(state, tight)
	_body = UIKit.vbox(12)
	add_child(_body)
	_show_page()


func _show_page() -> void:
	for c in _body.get_children():
		c.queue_free()
	match page:
		"results": _page_results()
		"timeline": _page_timeline()
		"seasons": _page_seasons()
		"profile": _profile_builder.call(_body)
		_: _page_now()


# --- Pieces -------------------------------------------------------------------------------------------------------------------------

static func card(title: String, content: Control) -> PanelContainer:
	var box := UIKit.vbox(8)
	if title != "":
		box.add_child(UIKit.label(title, "CaptionLabel"))
	box.add_child(content)
	return UIKit.panel(box, 16)


static func _sys() -> CareerSystem:
	return CareerSystem.sys()


## Makes `c` answer a tap (not a scroll drag) with `on_tap`.
static func tappable(c: Control, on_tap: Callable) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var press := {"at": Vector2.ZERO}
	c.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press.at = event.position
			elif event.position.distance_to(press.at) < 10.0:
				on_tap.call())
	return c


# --- NOW ------------------------------------------------------------------------------------------------------------------------------

func _page_now() -> void:
	var left := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(next_big_card())
	left.add_child(path_card())
	var right := UIKit.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cs := _sys()
	if cs != null:
		right.add_child(reputation_card(cs, func(): _show_page()))
	var goals := GoalsUI.overview_panel(func():
		if _on_goals_ask.is_valid():
			_on_goals_ask.call())
	if goals != null:
		right.add_child(goals)
	if Layout.compact:
		_body.add_child(left)
		_body.add_child(right)
	else:
		var row := UIKit.hbox(12)
		row.add_child(left)
		row.add_child(right)
		_body.add_child(row)
	_body.add_child(pb_card())
	var rank := rank_card()
	if rank != null:
		_body.add_child(rank)


## THE NEXT BIG THING: the meet, the countdown, what you need.
static func next_big_card() -> Control:
	var u: Dictionary = ui().next_big
	var box := UIKit.vbox(6)
	var t := NextBig.target()
	if t.is_empty():
		box.add_child(UIKit.wrapped(str(u.none)))
		return card(str(u.title), box)
	var m: Dictionary = t.meet
	var head := UIKit.hbox(10)
	var name_col := UIKit.vbox(2)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := UIKit.wrapped(str(m.name), "CardHeading")
	name.custom_minimum_size.x = 120
	name_col.add_child(name)
	var when := "%s · %s" % [str(t.when), str(Data.competitions.levels.get(str(m.level), m.level))]
	name_col.add_child(UIKit.wrapped(when, "WhyLabel"))
	head.add_child(name_col)
	var days := UIKit.label(str(t.days_text), "BigNumber")
	days.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(days)
	box.add_child(head)
	for line in t.lines:
		var l := UIKit.wrapped(str(line), "BodyLabel")
		l.custom_minimum_size.x = 120
		box.add_child(l)
	return card(str(u.title), box)


## THE LONG PATH: the application, the limits of the coming ages, the school years.
static func path_card() -> Control:
	var steps := NextBig.path()
	var box := UIKit.vbox(8)
	if steps.is_empty():
		box.add_child(UIKit.wrapped(str(Data.career.path.none)))
		return card("THE LONG PATH", box)
	for s in steps:
		var row := UIKit.hbox(10)
		var when := UIKit.label(str(s.when), "ItemLabel")
		when.custom_minimum_size.x = 64 if Layout.compact else 92
		when.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(when)
		var col := UIKit.vbox(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := UIKit.wrapped(str(s.title), "ItemLabel")
		title.custom_minimum_size.x = 120
		col.add_child(title)
		var text := UIKit.wrapped(str(s.text), "BodyLabel")
		text.custom_minimum_size.x = 120
		col.add_child(text)
		if s.has("reach"):
			var reach := UIKit.wrapped(str(s.reach), "WhyLabel")
			reach.custom_minimum_size.x = 120
			col.add_child(reach)
		row.add_child(col)
		box.add_child(row)
	var gain := UIKit.wrapped(str(Data.career.path.reach_note).format({"gain": "%.1f" % NextBig.yearly_gain(Game.athlete.age_on(Game.date))}), "WhyLabel")
	box.add_child(gain)
	return card("THE LONG PATH", box)


## YOUR NAME: the step, how far to the next, and (open) the points that count now with their parts.
static func reputation_card(cs: CareerSystem, on_toggle: Callable) -> Control:
	var rc: Dictionary = Data.reputation
	var t: Dictionary = rc.texts
	var rep := cs.reputation(Game.date)
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(rep.name), "CardHeading"))
	var short := UIKit.wrapped(str(rep.short), "BodyLabel")
	short.custom_minimum_size.x = 120
	box.add_child(short)
	if str(rep.next) != "":
		var steps: Array = rc.steps
		var lo := float(steps[int(rep.step)].min)
		var hi := float(rep.next_min)
		var share := clampf((float(rep.score) - lo) / maxf(0.01, hi - lo), 0.0, 1.0) * 100.0
		var bar := StatBar.new(str(rep.next), share, -1.0, str(rep.hint), "%.1f / %.0f" % [float(rep.score), hi])
		box.add_child(bar)
	else:
		box.add_child(UIKit.wrapped(str(t.top), "WhyLabel"))
	var toggle := UIKit.button(("▾ " if rep_open else "▸ ") + str(t.tap).trim_suffix("."), false, 0.0)
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.pressed.connect(func():
		rep_open = not rep_open
		on_toggle.call())
	box.add_child(toggle)
	if rep_open:
		box.add_child(_rep_rows(rep))
	return card(str(t.title), box)


static func _rep_rows(rep: Dictionary) -> Control:
	var t: Dictionary = Data.reputation.texts
	var box := UIKit.vbox(8)
	if rep.rows.is_empty():
		box.add_child(UIKit.wrapped("No points yet: a race puts the first ones here.", "WhyLabel"))
	for r in rep.rows:
		var e: Dictionary = r.event
		var row := UIKit.vbox(1)
		var head := UIKit.hbox(8)
		var name := UIKit.label(str(e.meet), "ItemLabel")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		head.add_child(name)
		head.add_child(UIKit.label("+%.1f" % float(r.now), "ItemLabel"))
		row.add_child(head)
		var parts := []
		for p in e.parts:
			parts.append("%s %s" % [str(p.text), str(p.value)])
		var why := UIKit.wrapped("%s · %s · %.0f %% still counts" % [Calendar.format_day(e.date), " · ".join(parts), float(r.weight) * 100.0], "WhyLabel")
		why.custom_minimum_size.x = 120
		row.add_child(why)
		box.add_child(row)
	if int(rep.faded) > 0:
		box.add_child(UIKit.wrapped(str(t.fades).format({"n": int(rep.faded)}), "WhyLabel"))
	box.add_child(UIKit.label(str(t.does_title), "CaptionLabel"))
	for line in t.does:
		var l := UIKit.wrapped("· " + str(line), "BodyLabel")
		l.custom_minimum_size.x = 120
		box.add_child(l)
	var no := UIKit.wrapped(str(t.does_not), "WhyLabel")
	no.custom_minimum_size.x = 120
	box.add_child(no)
	return box


static func pb_card() -> Control:
	var u: Dictionary = ui().now
	var series := CareerSystem.pb_series(Game.athlete)
	var box := UIKit.vbox(8)
	if series.size() < 2:
		box.add_child(UIKit.wrapped(str(u.pb_none)))
	else:
		box.add_child(PbChart.new(series, Game.date, 170.0 if Layout.compact else 190.0))
	return card(str(u.pb_title), box)


## The season list: your place at each month's end (the rankings history), and now.
static func rank_card() -> Control:
	var u: Dictionary = ui().now
	var cs := _sys()
	var box := UIKit.vbox(6)
	var rows := []
	var season := Rankings.season_of(Game.date)
	var now_list := Rankings.season_list(Game.athlete, Game.rivals, season)
	for r in now_list:
		if bool(r.is_player):
			rows.append(str(u.rank_line).format({"label": "Now · %d" % season, "rank": Race._ordinal(int(r.rank)), "of": now_list.size(), "time": Calendar.format_time(float(r.time))}))
	if cs != null:
		var log: Array = cs.rank_log.duplicate()
		log.reverse()
		for r in log.slice(0, 8):
			rows.append(str(u.rank_line).format({"label": "%s %d" % [str(Calendar.MONTHS_SHORT[int(r.month) - 1]), int(r.year)], "rank": Race._ordinal(int(r.rank)),
					"of": int(r.of), "time": Calendar.format_time(float(r.time))}))
	if rows.is_empty():
		box.add_child(UIKit.wrapped(str(u.rank_none)))
	for line in rows:
		box.add_child(UIKit.wrapped(line, "BodyLabel"))
	return card(str(u.rank_title), box)


# --- RESULTS --------------------------------------------------------------------------------------------------------------------------------

## Every meet day of the career, newest first: [{date, key, meet, level, rounds (the results), last}].
static func meet_days(a: Athlete) -> Array:
	var out := []
	var cur := {}
	for r in a.results:
		var key := "%d|%s" % [Calendar.date_key(Game.int_date(r.date)), str(r.meet_key)]
		if cur.is_empty() or str(cur.id) != key:
			cur = {"id": key, "date": Game.int_date(r.date), "key": str(r.meet_key), "meet": str(r.meet), "rounds": [], "last": r,
					"level": str(Calendar.get_meet(str(r.meet_key)).get("level", "local"))}
			out.append(cur)
		cur.rounds.append(r)
		cur.last = r
	out.reverse()
	return out


func _page_results() -> void:
	var u: Dictionary = ui().results
	var a := Game.athlete
	var days := meet_days(a)
	var pbs := 0
	for r in a.results:
		if bool(r.get("pb", false)):
			pbs += 1
	var head := UIKit.wrapped(str(u.count).format({"n": a.results.size(), "pbs": pbs}) if not a.results.is_empty() else str(u.no_races), "BodyLabel")
	_body.add_child(head)
	if a.results.is_empty():
		return
	# the seasons
	var years := {}
	for d in days:
		years[int(d.date.year)] = true
	var year_list := years.keys()
	year_list.sort()
	year_list.reverse()
	var filters := UIKit.vbox(6)
	var row1 := UIKit.hbox(6)
	var g1 := ButtonGroup.new()
	for y in [0] + year_list:
		var b := UIKit.toggle(str(u.all) if int(y) == 0 else str(y), g1)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = int(y) == results_year
		var yy: int = y
		b.pressed.connect(func():
			results_year = yy
			_fill_list(days))
		row1.add_child(b)
	filters.add_child(row1)
	var row2 := UIKit.hbox(6)
	var g2 := ButtonGroup.new()
	for lv in ["", "local", "district", "national"]:
		var b := UIKit.toggle(str(u.level_all) if lv == "" else str(u.levels[lv]), g2)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = lv == results_level
		var l: String = lv
		b.pressed.connect(func():
			results_level = l
			_fill_list(days))
		row2.add_child(b)
	filters.add_child(row2)
	var search := LineEdit.new()
	search.placeholder_text = "Meet name"
	search.text = results_text
	search.custom_minimum_size = Vector2(0, 44)
	search.text_changed.connect(func(t: String):
		results_text = t
		_fill_list(days))
	filters.add_child(search)
	_body.add_child(filters)
	_list = UIKit.vbox(8)
	_body.add_child(_list)
	_fill_list(days)


func _match_level(level: String) -> bool:
	if results_level == "":
		return true
	if results_level == "national":
		return level in ["national", "international", "elite"]
	return level == results_level


func _fill_list(days: Array) -> void:
	if _list == null or not is_instance_valid(_list):
		return
	for c in _list.get_children():
		c.queue_free()
	var q := results_text.strip_edges().to_lower()
	var shown := 0
	for d in days:
		if results_year != 0 and int(d.date.year) != results_year:
			continue
		if not _match_level(str(d.level)):
			continue
		if q != "" and str(d.meet).to_lower().find(q) < 0:
			continue
		_list.add_child(result_row(d))
		shown += 1
	if shown == 0:
		_list.add_child(UIKit.wrapped("No race matches.", "WhyLabel"))


## One meet day as a row: the date, the meet and its level, the result, PB; a tap opens its card when one is kept.
func result_row(d: Dictionary) -> Control:
	var u: Dictionary = ui().results
	var last: Dictionary = d.last
	var card_id := "%d_%s" % [Calendar.date_key(d.date), str(d.key)]
	var has_card := not Game.card(card_id).is_empty()
	var row := UIKit.hbox(12)
	row.custom_minimum_size.y = 44
	var date_col := UIKit.vbox(0)
	date_col.custom_minimum_size.x = 52
	date_col.add_child(UIKit.label("%d" % int(d.date.day), "BigNumber"))
	date_col.add_child(UIKit.label(str(Calendar.MONTHS_SHORT[int(d.date.month) - 1]), "WhyLabel"))
	row.add_child(date_col)
	var mid := UIKit.vbox(1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := UIKit.wrapped(str(d.meet), "ItemLabel")
	name.custom_minimum_size.x = 100
	mid.add_child(name)
	var detail := str(u.levels.get(str(d.level), d.level))
	if d.rounds.size() > 1:
		var parts := []
		for r in d.rounds:
			parts.append("%s %s" % [str(r.round), Race.result_text(r, " ")])
		detail += " · " + " → ".join(parts)
	elif str(last.round) != "Race":
		detail += " · " + str(last.round)
	var dl := UIKit.wrapped(detail, "WhyLabel")
	dl.custom_minimum_size.x = 100
	mid.add_child(dl)
	row.add_child(mid)
	var right := UIKit.vbox(0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	var res := UIKit.label(Race.result_text(last, "  "), "ItemLabel")
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(res)
	var tags := ""
	if bool(last.get("pb", false)):
		tags = "PB"
	if tags != "" or has_card:
		var tl := UIKit.label((tags + (" " if tags != "" and has_card else "") + ("›" if has_card else "")).strip_edges(), "WhyLabel")
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if tags != "":
			tl.add_theme_color_override("font_color", Palette.LEAD)
		right.add_child(tl)
	row.add_child(right)
	var p := UIKit.panel(row, 12)
	if has_card:
		tappable(p, func(): card_pressed.emit(card_id))
	return p


# --- TIMELINE --------------------------------------------------------------------------------------------------------------------------------

func _page_timeline() -> void:
	var u: Dictionary = ui().timeline
	var cs := _sys()
	_body.add_child(UIKit.label(str(u.title), "CaptionLabel"))
	if cs == null or cs.milestones.is_empty():
		_body.add_child(UIKit.wrapped(str(u.empty)))
		return
	var list: Array = cs.milestones.duplicate()
	list.reverse()
	var group_year := -1
	var box: VBoxContainer = null
	var divider_done := cs.since.is_empty()
	for m in list:
		var yr := SeasonPlan.year_of(m.date)
		if yr != group_year:
			group_year = yr
			if box != null:
				_body.add_child(UIKit.panel(box, 12))
			_body.add_child(UIKit.label(SeasonSystem.season_label(yr), "SectionLabel"))
			box = UIKit.vbox(2)
		if not divider_done and Calendar.date_key(m.date) < Calendar.date_key(cs.since):
			divider_done = true
			box.add_child(UIKit.wrapped(str(u.recorded_from).format({"date": Calendar.format_day(cs.since)}), "WhyLabel"))
		box.add_child(_milestone_row(m))
	if box != null:
		if not divider_done:
			box.add_child(UIKit.wrapped(str(u.recorded_from).format({"date": Calendar.format_day(cs.since)}), "WhyLabel"))
		_body.add_child(UIKit.panel(box, 12))


# --- SEASONS (K1b) ---------------------------------------------------------------------------------------------------------------------------

## Every season that has ended, newest first; a tap opens its review chapter.
func _page_seasons() -> void:
	var u: Dictionary = Data.season_review.ui
	var cs := _sys()
	_body.add_child(UIKit.label(str(u.seasons_head), "CaptionLabel"))
	var list: Array = cs.review_list() if cs != null else []
	if list.is_empty():
		_body.add_child(UIKit.wrapped(str(u.seasons_none)))
		return
	_body.add_child(UIKit.wrapped(str(u.seasons_help), "WhyLabel"))
	for r in list:
		var n: Dictionary = r.numbers
		var row := UIKit.hbox(10)
		row.custom_minimum_size.y = 44
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(str(r.label), "CardHeading"))
		var line := UIKit.wrapped(str(u.season_line).format({"races": int(n.races), "best": Calendar.format_time(float(n.best)) if float(n.best) > 0.0 else "–",
				"met": int(r.met), "total": r.goals.size()}), "WhyLabel")
		line.custom_minimum_size.x = 100
		col.add_child(line)
		row.add_child(col)
		var arrow := UIKit.label("›", "ItemLabel")
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(arrow)
		var year: int = int(r.year)
		_body.add_child(tappable(UIKit.panel(row, 12), func(): review_pressed.emit(year)))


func _milestone_row(m: Dictionary) -> Control:
	var row := UIKit.hbox(12)
	row.custom_minimum_size.y = 44
	var icon := Icons.rect(str(m.icon), 20.0, Palette.TEXT_MUTED)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var col := UIKit.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UIKit.wrapped(str(m.title), "ItemLabel")
	title.custom_minimum_size.x = 100
	col.add_child(title)
	if str(m.text) != "":
		var text := UIKit.wrapped(str(m.text), "WhyLabel")
		text.custom_minimum_size.x = 100
		col.add_child(text)
	row.add_child(col)
	var card_id := str(m.get("card", ""))
	var has_card := card_id != "" and not Game.card(card_id).is_empty()
	var when := UIKit.label(Calendar.format_day(m.date) + (" ›" if has_card else ""), "WhyLabel")
	when.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(when)
	if has_card:
		tappable(row, func(): card_pressed.emit(card_id))
	return row
