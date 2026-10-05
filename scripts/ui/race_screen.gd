extends Control
## Race day: the field and your race plan → the race (quick result, or watched with decisions) → results.
## Works on Game.race_day; when it's all done, Game.finish_race() continues the week.

const PLANS := [
	["front", "Run from the front", "Go out hard and make the others chase. Suits strong, even runners."],
	["pack", "Stay with the pack", "Sit near the front and react. The safe, flexible choice."],
	["back", "Start easy, kick late", "Hang back and save energy for a big finish. Suits fast finishers."],
]
const SPEEDS := [2.0, 4.0, 8.0]

var _rd: RaceDay
var _race: Race
var _plan := "pack"
var _speed := 4.0
var _acc := 0.0
var _running := false
var _finish_wait := 0.0

var _title: Label
var _subtitle: Label
var _header_right: HBoxContainer
var _body: Control
# Running-phase widgets
var _runners_view: Control
var _clock: Label
var _info: Label
var _standings: VBoxContainer
var _commentary: VBoxContainer
var _decision: PanelContainer


func _ready() -> void:
	_rd = Game.race_day
	if _rd == null:
		Router.go.call_deferred("career_hub")
		return
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [["left", 48], ["right", 48], ["top", 28], ["bottom", 24]]:
		margin.add_theme_constant_override("margin_" + side[0], side[1])
	add_child(margin)
	var column := UIKit.vbox(16)
	margin.add_child(column)

	var header := UIKit.hbox(16)
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = UIKit.label("", "TitleLabel")
	_subtitle = UIKit.label("", "MutedLabel")
	titles.add_child(_title)
	titles.add_child(_subtitle)
	header.add_child(titles)
	_header_right = UIKit.hbox(8)
	_header_right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(_header_right)
	column.add_child(header)

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	_show_pre()


func _set_body(content: Control) -> void:
	for child in _body.get_children():
		child.queue_free()
	for child in _header_right.get_children():
		child.queue_free()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(content)


func _update_titles() -> void:
	var m := _rd.meet
	_title.text = m.name
	_subtitle.text = "%s · 800 m %s · %s · %s" % [_rd.round_name(), Calendar.age_class(Game.athlete, m.date.year),
			Calendar.place(Game.athlete, m), Calendar.format_meet_date(m)]


# --- Before the race ----------------------------------------------------------------------

func _show_pre() -> void:
	_update_titles()
	var a := Game.athlete
	var row := UIKit.hbox(16)

	var field := UIKit.vbox(6)
	field.add_child(UIKit.label("THE FIELD", "CaptionLabel"))
	var entrants := _rd.current_entrants().duplicate()
	entrants.sort_custom(func(x, y): return _pb_of(x) < _pb_of(y))
	for e in entrants:
		var line := UIKit.hbox(8)
		var n := UIKit.label(e.name)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if e.get("is_player", false):
			n.add_theme_color_override("font_color", Palette.ACCENT)
		line.add_child(n)
		line.add_child(UIKit.label(e.club, "MutedLabel"))
		var pb := _pb_of(e)
		var pb_label := UIKit.label("PB " + (Calendar.format_time(pb) if pb < 9999.0 else "–"), "MutedLabel")
		pb_label.custom_minimum_size.x = 110
		pb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(pb_label)
		field.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(field)
	var field_panel := UIKit.panel(scroll, 16)
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field_panel)

	var side := UIKit.vbox(10)
	side.custom_minimum_size.x = 440
	side.add_child(UIKit.label("YOU", "CaptionLabel"))
	var state := Training.fatigue_state(a.fatigue)
	var cond := UIKit.label("Feeling %s (fatigue %d)" % [state[0].to_lower(), roundi(_rd.fatigue)])
	cond.add_theme_color_override("font_color", state[1])
	side.add_child(cond)
	var standard := Calendar.standard_text(a, _rd.meet)
	if standard != "":
		side.add_child(UIKit.wrapped(standard))
	side.add_child(UIKit.label("RACE PLAN", "CaptionLabel"))
	var group := ButtonGroup.new()
	for p in PLANS:
		var b := UIKit.toggle(p[1], group)
		b.button_pressed = p[0] == _plan
		b.tooltip_text = p[2]
		b.pressed.connect(func(): _plan = p[0])
		side.add_child(b)
		side.add_child(UIKit.wrapped(p[2]))
	var buttons := UIKit.hbox(8)
	var quick := UIKit.button("Quick result", false, 180)
	quick.pressed.connect(_start.bind(false))
	var watch := UIKit.button("Watch & decide", true, 200)
	watch.pressed.connect(_start.bind(true))
	buttons.add_child(quick)
	buttons.add_child(watch)
	side.add_child(buttons)
	var side_panel := UIKit.panel(side, 16)
	side_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(side_panel)
	_set_body(row)


func _pb_of(e: Dictionary) -> float:
	if e.get("is_player", false):
		var pb: float = Game.athlete.personal_bests.get(Game.athlete.main_event, 0.0)
		return pb if pb > 0.0 else 9999.0
	var rival: Dictionary = e.get("rival", {})
	var rpb := float(rival.get("pb", 0.0))
	return rpb if rpb > 0.0 else 9999.0


func _start(interactive: bool) -> void:
	_race = _rd.start_round(interactive, _plan)
	if not interactive:
		_race.run()
		_show_result()
		return
	_show_running()


# --- The race -------------------------------------------------------------------------------

func _show_running() -> void:
	var row := UIKit.hbox(16)
	var track_area := Control.new()
	track_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not _race.indoor:
		var stadium := Control.new()
		stadium.set_script(preload("res://scripts/ui/track_drawing.gd"))
		stadium.set_anchors_preset(Control.PRESET_FULL_RECT)
		track_area.add_child(stadium)
	_runners_view = Control.new()
	_runners_view.set_script(preload("res://scripts/ui/race_runners_view.gd"))
	_runners_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_runners_view.set("race", _race)
	track_area.add_child(_runners_view)
	_decision = PanelContainer.new()
	_decision.set_anchors_preset(Control.PRESET_CENTER)
	_decision.visible = false
	track_area.add_child(_decision)
	row.add_child(track_area)

	var side := UIKit.vbox(8)
	side.custom_minimum_size.x = 330
	_clock = UIKit.label("0.0", "TitleLabel")
	side.add_child(_clock)
	_info = UIKit.label("", "MutedLabel")
	side.add_child(_info)
	side.add_child(UIKit.label("POSITIONS", "CaptionLabel"))
	_standings = UIKit.vbox(2)
	side.add_child(_standings)
	side.add_child(UIKit.label("COMMENTARY", "CaptionLabel"))
	_commentary = UIKit.vbox(4)
	side.add_child(_commentary)
	var side_panel := UIKit.panel(side, 16)
	row.add_child(side_panel)
	_set_body(row)

	var group := ButtonGroup.new()
	for s in SPEEDS:
		var b := UIKit.toggle("%dx" % s, group)
		b.custom_minimum_size.x = 64
		b.button_pressed = s == _speed
		b.pressed.connect(func(): _speed = s)
		_header_right.add_child(b)

	_race.commentary.connect(_add_commentary)
	_race.decision_needed.connect(_show_decision)
	_running = true
	_acc = 0.0
	_finish_wait = 0.0


func _process(delta: float) -> void:
	if not _running:
		return
	if _race.finished:
		_finish_wait += delta
		if _finish_wait > 1.2:
			_running = false
			_show_result()
		return
	if not _race.pending.is_empty():
		return
	_acc += delta * _speed
	while _acc >= Race.DT and _race.pending.is_empty() and not _race.finished:
		_race.step()
		_acc -= Race.DT
	_refresh_running()


func _refresh_running() -> void:
	_clock.text = Calendar.format_time(_race.time) if _race.time >= 60.0 else "%.1f" % _race.time
	var p := _race.player
	var order := _race.standings()
	_info.text = "You: %s of %d · %d m to go" % [Race._ordinal(order.find(p) + 1), order.size(),
			maxi(0, roundi(Race.DISTANCE - p.d))]
	for child in _standings.get_children():
		child.queue_free()
	var lead := order[0].d
	for i in order.size():
		var r: Race.Runner = order[i]
		var gap := "" if i == 0 else ("+%.1f m" % (lead - r.d) if not r.done else Calendar.format_time(r.t))
		if i == 0 and r.done:
			gap = Calendar.format_time(r.t)
		var line := UIKit.hbox(6)
		var n := UIKit.label("%d. %s" % [i + 1, r.name])
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		if r.is_player:
			n.add_theme_color_override("font_color", Palette.ACCENT)
		line.add_child(n)
		line.add_child(UIKit.label(gap, "MutedLabel"))
		_standings.add_child(line)
	_runners_view.queue_redraw()


func _add_commentary(text: String) -> void:
	_commentary.add_child(UIKit.wrapped(text, ""))
	while _commentary.get_child_count() > 5:
		var old := _commentary.get_child(0)
		_commentary.remove_child(old)
		old.queue_free()


func _show_decision(d: Dictionary) -> void:
	_refresh_running()
	for child in _decision.get_children():
		child.queue_free()
	var box := UIKit.vbox(10)
	box.custom_minimum_size.x = 480
	box.add_child(UIKit.label(d.title, "HeadingLabel"))
	box.add_child(UIKit.wrapped(d.text, ""))
	for o in d.options:
		var b := UIKit.button(o.label, false, 440)
		b.tooltip_text = o.detail
		b.pressed.connect(func():
			_decision.visible = false
			_race.choose(o.id))
		box.add_child(b)
		box.add_child(UIKit.wrapped(o.detail))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 20)
	m.add_child(box)
	_decision.add_child(m)
	_decision.visible = true
	# Centre it over the track.
	await get_tree().process_frame
	_decision.position = (_decision.get_parent().size - _decision.size) / 2.0


# --- Results ----------------------------------------------------------------------------------

func _show_result() -> void:
	var res := _race.results()
	var old_pb: float = Game.athlete.personal_bests.get(Game.athlete.main_event, 0.0)
	_rd.finish_round()
	var mine: Dictionary = {}
	for r in res:
		if r.is_player:
			mine = r

	var col := UIKit.vbox(12)
	var place := res.find(mine) + 1
	var headline := "%s in %s" % [Race._ordinal(place), Calendar.format_time(mine.time)]
	var best_so_far := old_pb
	for r in _rd.player_results.slice(0, -1):
		if best_so_far == 0.0 or r.time < best_so_far:
			best_so_far = r.time
	if best_so_far == 0.0 or mine.time < best_so_far:
		headline += "  ·  Personal best!"
	col.add_child(UIKit.label(headline, "HeadingLabel"))

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	for h in ["", "NAME", "CLUB", "TIME", ""]:
		grid.add_child(UIKit.label(h, "CaptionLabel"))
	var qualifiers := []
	if _rd.rounds.size() > 1 and _rd.round_index == 1:
		qualifiers = _rd.final_entrants.map(func(e): return e.name)
	for i in res.size():
		var r: Dictionary = res[i]
		var cells := [str(i + 1), r.name, r.club, Calendar.format_time(r.time), "Q" if r.name in qualifiers else ""]
		for c in cells.size():
			var l := UIKit.label(cells[c], "" if c != 2 else "MutedLabel")
			if r.is_player:
				l.add_theme_color_override("font_color", Palette.ACCENT)
			grid.add_child(l)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(UIKit.panel(grid, 16))
	col.add_child(scroll)

	var next := UIKit.button("", true, 220)
	next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if not _rd.is_done():
		col.add_child(UIKit.wrapped("You're through to the final!", ""))
		next.text = "On to the final"
		next.pressed.connect(_show_pre)
	else:
		if _rd.rounds.size() > 1 and not _rd.qualified:
			col.add_child(UIKit.wrapped("Not enough to make the final this time.", ""))
		next.text = "Continue"
		next.pressed.connect(_leave)
	col.add_child(next)
	_set_body(col)


func _leave() -> void:
	if Game.finish_race():
		Router.go("race")   # another race later this week
	else:
		Game.open_report = true
		Router.go("career_hub")
