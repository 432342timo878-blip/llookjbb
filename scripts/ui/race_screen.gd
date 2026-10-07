extends Control
## Race day: the field and your race plan → the race (quick result, or watched with decisions) → results.
## Works on Game.race_day; when it's all done, Game.finish_race() completes the race day.

const PLANS := [
	["front", "Lead", "Go to the front and set the pace. No traffic, but no shelter either. Suits strong runners."],
	["pack", "Sit in the pack", "Run behind others near the front and save energy. The safe, flexible choice."],
	["back", "Wait at the back", "Save the most for a late kick. Suits fast finishers; you may get boxed in."],
]
const SPEEDS := [1.0, 2.0, 4.0]   # 1x = real time (GDD 4.3.1 sketch)

var _rd: RaceDay
var _race: Race
var _plan := "pack"
var _speed := 4.0
var _acc := 0.0
var _running := false
var _finish_wait := 0.0

var _stage := "pre"   # pre / running / result: what a layout change should rebuild
var _margin: MarginContainer
var _title: Label
var _subtitle: Label
var _header_right: HBoxContainer
var _body: Control
# Running-phase widgets
var _runners_view: Control
var _clock: Label
var _info: Label
var _standings: VBoxContainer
var _stand_rows := []   # [name label, gap label] per position, reused every frame
var _commentary: VBoxContainer
var _decision: Control   # full-screen dimmed overlay holding the decision card
var _help_button: HelpButton   # "?" in the header: the help of this stage (GDD 5 "Help")
var _help: HelpOverlay         # open help; the race waits while it is open


func _ready() -> void:
	_rd = Game.race_day
	if _rd == null:
		Router.go.call_deferred("career_hub")
		return
	Router.layout_changed.connect(_on_layout_changed)
	_build_shell()
	_show_pre()


## Title, speed buttons and the empty body that the stages fill. Rebuilt when the layout switches.
func _build_shell() -> void:
	if _margin:
		_margin.queue_free()
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	Layout.page_margin(_margin)
	add_child(_margin)
	var column := UIKit.vbox(10 if Layout.compact else 16)
	_margin.add_child(column)

	var header := UIKit.hbox(16)
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = UIKit.wrapped("", "TitleLabel")
	_subtitle = UIKit.wrapped("")
	titles.add_child(_title)
	titles.add_child(_subtitle)
	header.add_child(titles)
	_header_right = UIKit.hbox(8)
	if Layout.compact:
		_header_right.visible = false   # shown (under the title) when there are speed buttons
	else:
		_header_right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		header.add_child(_header_right)
	_help_button = HelpButton.new(_help_id())
	_help_button.pressed.connect(func(): _open_help(_help_id()))
	header.add_child(_help_button)
	column.add_child(header)
	if Layout.compact:
		column.add_child(_header_right)

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)

	if _decision == null:
		_build_decision_overlay()


func _on_layout_changed(_compact: bool) -> void:
	if _stage == "running":
		return   # the race goes on; the next stage uses the new layout
	_build_shell()
	if _stage == "result":
		_show_result(false)
	else:
		_show_pre()


## A dimmed full-screen layer with a centred card, used for the in-race decisions.
func _build_decision_overlay() -> void:
	_decision = ColorRect.new()
	(_decision as ColorRect).color = Color(0.03, 0.035, 0.05, 0.72)
	_decision.set_anchors_preset(Control.PRESET_FULL_RECT)
	_decision.visible = false
	add_child(_decision)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_decision.add_child(margin)
	var center := CenterContainer.new()
	center.name = "Center"
	margin.add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	center.add_child(card)


func _set_body(content: Control) -> void:
	for child in _body.get_children():
		child.queue_free()
	for child in _header_right.get_children():
		child.queue_free()
	_header_right.visible = false
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(content)
	_help_button.entry_id = _help_id()


# --- Help (GDD 5 "Help") ------------------------------------------------------------------------

## The help of this stage: before the race, the race itself (with its decisions), the result.
func _help_id() -> String:
	return {"pre": "race_before", "running": "race_running", "result": "race_result"}.get(_stage, "race_before")


func _open_help(id: String) -> void:
	_help = HelpOverlay.open(self, id)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F1:
		_open_help(_help_id())
		get_viewport().set_input_as_handled()


func _update_titles() -> void:
	var m := _rd.meet
	_title.text = m.name
	_subtitle.text = "%s · 800 m %s · %s · %s" % [_rd.round_name(), Calendar.age_class(Game.athlete, m.date.year),
			Calendar.place(Game.athlete, m), Calendar.format_meet_date(m)]


# --- Before the race ----------------------------------------------------------------------

func _show_pre() -> void:
	_stage = "pre"
	_update_titles()
	var a := Game.athlete

	var field := UIKit.vbox(6)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(UIKit.label("THE FIELD", "CaptionLabel"))
	var entrants := _rd.current_entrants().duplicate()
	entrants.sort_custom(func(x, y): return _pb_of(x) < _pb_of(y))
	for e in entrants:
		var line := UIKit.hbox(8)
		line.custom_minimum_size.y = 30
		var n := UIKit.label(e.name)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.clip_text = true
		if e.get("is_player", false):
			n.add_theme_color_override("font_color", Palette.ACCENT)
		line.add_child(n)
		if not Layout.compact:
			var club := UIKit.label(e.club, "MutedLabel")
			club.custom_minimum_size.x = 220
			club.clip_text = true
			line.add_child(club)
		var pb := _pb_of(e)
		var pb_label := UIKit.label("PB " + (Calendar.format_time(pb) if pb < 9999.0 else "–"), "MutedLabel")
		pb_label.custom_minimum_size.x = 110
		pb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(pb_label)
		field.add_child(line)
	var field_panel := UIKit.panel(field, 16)
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var side := UIKit.vbox(10)
	side.add_child(UIKit.label("YOU", "CaptionLabel"))
	var state := Training.fatigue_state(a.fatigue)
	var cond := UIKit.label("Feeling %s (fatigue %d)" % [state[0].to_lower(), roundi(_rd.fatigue)])
	cond.add_theme_color_override("font_color", state[1])
	side.add_child(cond)
	var form := FormUI.race_card()   # race-day form: Peaking / Sharp / OK / Rusty / Tired (GDD 4.8)
	if form != null:
		side.add_child(form)
	# Racing with a niggle or a cold: slower, and it may get worse (GDD 4.6).
	var injured := HealthUI.race_card(HealthUI.race_outlook(Game.current_week().day), true)
	# Scratching (not starting) is possible in the first round; when injured it sits right under the warning.
	var scratch: Control = null
	if _rd.round_index == 0:
		scratch = HealthUI.scratch_control(_rd.meet, func(): Router.go("career_hub"))
	if injured != null:
		side.add_child(injured)
		if scratch != null:
			side.add_child(scratch)
	var standard := Calendar.standard_text(a, _rd.meet)
	if standard != "":
		side.add_child(UIKit.wrapped(standard))
	side.add_child(UIKit.label("RACE PLAN", "CaptionLabel"))
	var group := ButtonGroup.new()
	for p in PLANS:
		var card := ChoiceCard.new(p[1], p[2], group)
		card.selected = p[0] == _plan
		card.button.pressed.connect(func(): _plan = p[0])
		side.add_child(card)
	var buttons := UIKit.hbox(8)
	var quick := UIKit.button("Quick result", false, 160)
	quick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick.pressed.connect(_start.bind(false))
	var watch := UIKit.button("Watch & decide", true, 200)
	watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch.pressed.connect(_start.bind(true))
	buttons.add_child(quick)
	buttons.add_child(watch)
	side.add_child(buttons)
	if injured == null and scratch != null:   # (once you've run a heat, you finish the meet: no scratch in the final)
		side.add_child(scratch)
	var side_panel := UIKit.panel(side, 16)
	side_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if Layout.compact:
		# One scrolling column: your plan and the start buttons first, the field below.
		var scroll := _scroll_column()
		var column := scroll.get_child(0) as VBoxContainer
		column.add_child(side_panel)
		column.add_child(field_panel)
		_set_body(scroll)
		return
	side_panel.custom_minimum_size.x = 440
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(field_panel)
	var side_scroll := ScrollContainer.new()   # the plan, buttons and health warning can be taller than a short window
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.custom_minimum_size.x = 440.0 + 12.0
	side_scroll.add_child(side_panel)
	var row := UIKit.hbox(16)
	row.add_child(scroll)
	row.add_child(side_scroll)
	_set_body(row)


## A vertically scrolling column (no sideways scrolling); returns the ScrollContainer, its child is the VBox.
func _scroll_column() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := UIKit.vbox(12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return scroll


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
	_stage = "running"
	var track_area := Control.new()
	track_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if Layout.compact:
		track_area.custom_minimum_size.y = 250
		track_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not _race.indoor:
		var stadium := Control.new()
		stadium.set_script(preload("res://scripts/ui/track_drawing.gd"))
		stadium.set_anchors_preset(Control.PRESET_FULL_RECT)
		track_area.add_child(stadium)
	else:
		# The hall track never changes: its own view, drawn once (the dots view redraws every frame).
		var floor_view := Control.new()
		floor_view.set_script(preload("res://scripts/ui/race_runners_view.gd"))
		floor_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		floor_view.set("race", _race)
		floor_view.set("track_only", true)
		track_area.add_child(floor_view)
	_runners_view = Control.new()
	_runners_view.set_script(preload("res://scripts/ui/race_runners_view.gd"))
	_runners_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_runners_view.set("race", _race)
	_runners_view.set("indoor_floor_below", true)
	track_area.add_child(_runners_view)

	_clock = UIKit.label("0.0", "TitleLabel")
	_info = UIKit.wrapped("")
	_standings = UIKit.vbox(2)
	_stand_rows.clear()
	_commentary = UIKit.vbox(4)
	var side := UIKit.vbox(8)
	if Layout.compact:
		var bar := UIKit.hbox(12)
		_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bar.add_child(_clock)
		bar.add_child(_info)
		side.add_child(bar)
	else:
		side.custom_minimum_size.x = 330
		side.add_child(_clock)
		side.add_child(_info)
	side.add_child(UIKit.label("POSITIONS", "CaptionLabel"))
	side.add_child(_standings)
	side.add_child(UIKit.label("COMMENTARY", "CaptionLabel"))
	side.add_child(_commentary)
	var side_panel := UIKit.panel(side, 16)

	if Layout.compact:
		var column := UIKit.vbox(10)
		column.add_child(track_area)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(side_panel)
		column.add_child(scroll)
		_set_body(column)
	else:
		var row := UIKit.hbox(16)
		row.add_child(track_area)
		row.add_child(side_panel)
		_set_body(row)

	_header_right.visible = true
	var group := ButtonGroup.new()
	for s in SPEEDS:
		var b := UIKit.toggle("%dx" % s, group)
		b.custom_minimum_size.x = 64
		if Layout.compact:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = s == _speed
		b.pressed.connect(func(): _speed = s)
		_header_right.add_child(b)

	_race.commentary.connect(_add_commentary)
	_race.decision_needed.connect(_show_decision)
	_running = true
	_acc = 0.0
	_finish_wait = 0.0


func _process(delta: float) -> void:
	if not _running or (is_instance_valid(_help) and not _help.is_queued_for_deletion()):
		return   # (the race waits while the help is open)
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
	# The rows are made once and only their text changes: rebuilding them every frame re-lays-out the whole
	# side panel (including the wrapped commentary) 60 times a second.
	if _stand_rows.size() != order.size():
		for child in _standings.get_children():
			child.queue_free()
		_stand_rows.clear()
		for i in order.size():
			var line := UIKit.hbox(6)
			var n := UIKit.label("")
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.clip_text = true
			line.add_child(n)
			var g := UIKit.label("", "MutedLabel")
			line.add_child(g)
			_standings.add_child(line)
			_stand_rows.append([n, g])
	var lead := order[0].d
	for i in order.size():
		var r: Race.Runner = order[i]
		var gap := "" if i == 0 else ("+%.1f m" % (lead - r.d) if not r.done else Calendar.format_time(r.t))
		if i == 0 and r.done:
			gap = Calendar.format_time(r.t)
		var n: Label = _stand_rows[i][0]
		n.text = "%d. %s" % [i + 1, r.name]
		if r.is_player:
			n.add_theme_color_override("font_color", Palette.ACCENT)
		else:
			n.remove_theme_color_override("font_color")
		(_stand_rows[i][1] as Label).text = gap
	_runners_view.queue_redraw()


func _add_commentary(text: String) -> void:
	_commentary.add_child(UIKit.wrapped(text, ""))
	while _commentary.get_child_count() > (3 if Layout.compact else 5):
		var old := _commentary.get_child(0)
		_commentary.remove_child(old)
		old.queue_free()


## The decision card: a dimmed overlay over the whole screen, so it fits any layout and can't be missed.
func _show_decision(d: Dictionary) -> void:
	_refresh_running()
	var card: PanelContainer = _decision.get_node("Margin/Center/Card")
	for child in card.get_children():
		child.queue_free()
	var box := UIKit.vbox(10)
	box.custom_minimum_size.x = minf(480.0, size.x - 32.0 - 36.0)   # screen margin + panel padding
	var head := UIKit.hbox(8)
	var title := UIKit.wrapped(d.title, "HeadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var help := HelpButton.new("race_running")
	help.pressed.connect(func(): _open_help("race_running"))
	head.add_child(help)
	box.add_child(head)
	box.add_child(UIKit.wrapped(d.text, ""))
	for o in d.options:
		var b := UIKit.button(o.label, false, 200)
		b.pressed.connect(func():
			_decision.visible = false
			_race.choose(o.id))
		box.add_child(b)
		box.add_child(UIKit.wrapped(o.detail))
	card.add_child(box)   # the panel style already pads it
	_decision.visible = true


# --- Results ----------------------------------------------------------------------------------

var _result := {}   # what the result stage shows (kept so a layout change can redraw it)


func _show_result(fresh := true) -> void:
	_stage = "result"
	if fresh:
		_decision.visible = false
		var res := _race.results()
		var old_pb: float = Game.athlete.personal_bests.get(Game.athlete.main_event, 0.0)
		_rd.finish_round()
		var mine: Dictionary = {}
		for r in res:
			if r.is_player:
				mine = r
		var place := res.find(mine) + 1
		var headline := "%s in %s" % [Race._ordinal(place), Calendar.format_time(mine.time)]
		var best_so_far := old_pb
		for r in _rd.player_results.slice(0, -1):
			if best_so_far == 0.0 or r.time < best_so_far:
				best_so_far = r.time
		if best_so_far == 0.0 or mine.time < best_so_far:
			headline += "  ·  Personal best!"
		var qualifiers := []
		if _rd.rounds.size() > 1 and _rd.round_index == 1:
			qualifiers = _rd.final_entrants.map(func(e): return e.name)
		_result = {"res": res, "headline": headline, "qualifiers": qualifiers,
				"done": _rd.is_done(), "qualified": _rd.qualified, "heats": _rd.rounds.size() > 1}
	var res: Array = _result.res

	var col := UIKit.vbox(12)
	col.add_child(UIKit.wrapped(_result.headline, "HeadingLabel"))

	var grid := GridContainer.new()
	grid.columns = 4 if Layout.compact else 5
	grid.add_theme_constant_override("h_separation", 14 if Layout.compact else 24)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var headers := ["", "NAME", "TIME", ""] if Layout.compact else ["", "NAME", "CLUB", "TIME", ""]
	for h in headers:
		grid.add_child(UIKit.label(h, "CaptionLabel"))
	for i in res.size():
		var r: Dictionary = res[i]
		var cells := [str(i + 1), r.name, Calendar.format_time(r.time), "Q" if r.name in _result.qualifiers else ""]
		if not Layout.compact:
			cells.insert(2, r.club)
		for c in cells.size():
			var l := UIKit.label(cells[c], "MutedLabel" if (not Layout.compact and c == 2) else "")
			if cells[c] == r.name:
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.clip_text = true
			if r.is_player:
				l.add_theme_color_override("font_color", Palette.ACCENT)
			grid.add_child(l)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var panel := UIKit.panel(grid, 16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	col.add_child(scroll)

	var next := UIKit.button("", true, 220)
	if not _result.done:
		col.add_child(UIKit.wrapped("You're through to the final!", ""))
		next.text = "On to the final"
		next.pressed.connect(_show_pre)
	else:
		if _result.heats and not _result.qualified:
			col.add_child(UIKit.wrapped("Not enough to make the final this time.", ""))
		next.text = "Continue"
		next.pressed.connect(_leave)
	col.add_child(next)

	if Layout.compact:
		_set_body(col)
		return
	# Wide screens: keep the table a readable width, centred.
	col.custom_minimum_size.x = 820
	next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var wrap := UIKit.hbox(0)
	wrap.add_child(UIKit.spacer())
	wrap.add_child(col)
	wrap.add_child(UIKit.spacer())
	_set_body(wrap)


## Completes the race day. If the race came up during Play week, the week goes on (and may reach another race).
func _leave() -> void:
	if Game.finish_race() == Game.RACE:
		Router.go("race")
	else:
		Router.go("career_hub")   # the hub shows the weekly report or a stop event if there is one
