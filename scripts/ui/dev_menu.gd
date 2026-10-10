class_name DevMenu
extends Control
## The Dev menu (debug builds only: the main menu offers it when the game runs from the Godot editor, never in an exported
## game). Two things for playtesting without a command line (see DevTools):
##   - Watch a test race: a separate test career, played to an indoor / outdoor race run in sections or heats, at a chosen
##     meet level (who commentates follows it); the race screen opens and the race is yours.
##   - Jump the career forward: plays the career you have open to the next race day or to a date.
## Built in code, wide or phone layout (rebuilt on Router.layout_changed).

const HELP := "dev_menu"
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## [label, month] of the jump targets (the next 1st of that month)
const JUMP_MONTHS := [["1 Jan", 1], ["1 Mar", 3], ["1 May", 5], ["1 Jul", 7], ["1 Sep", 9], ["1 Nov (next season)", 11]]

# The test race choices (kept when the layout switches)
var _indoor := true
var _round := ""          # "" any, "sections", "heats"
var _level := ""          # "" any, local, district, national, international
var _female := false
var _ability := 0.0

var _margin: MarginContainer
var _race_message: Label
var _jump_message: Label
var _busy := false


func _ready() -> void:
	if not DevTools.available():
		Router.go.call_deferred("main_menu")
		return
	Router.layout_changed.connect(func(_c): _build())
	_build()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		var key := (event as InputEventKey).keycode
		if key == KEY_F1:
			HelpOverlay.open(self, HELP)
			get_viewport().set_input_as_handled()


func _build() -> void:
	if _margin:
		_margin.queue_free()
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	Layout.page_margin(_margin, 1000.0)
	add_child(_margin)
	var column := UIKit.vbox(12 if Layout.compact else 16)
	_margin.add_child(column)

	var header := UIKit.hbox(12)
	var title := UIKit.label("Dev menu", "TitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	var help := HelpButton.new(HELP)
	help.pressed.connect(func(): HelpOverlay.open(self, HELP))
	header.add_child(help)
	var back := UIKit.button("Menu" if Layout.compact else "Main menu", false, 140)
	back.pressed.connect(Router.go.bind("main_menu"))
	header.add_child(back)
	column.add_child(header)
	column.add_child(UIKit.wrapped("For testing the game. Only in a test build: you will not see this menu in a finished game."))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := UIKit.vbox(16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	column.add_child(scroll)
	body.add_child(_race_panel())
	body.add_child(_jump_panel())


# --- Watch a test race ---------------------------------------------------------------------------------------

func _race_panel() -> Control:
	var col := UIKit.vbox(10)
	col.add_child(UIKit.label("WATCH A TEST RACE", "CaptionLabel"))
	col.add_child(UIKit.wrapped("Makes a separate test career, plays it to a race of the kind you pick and opens the race. "
			+ "Your own saves are never touched. To go back to your career, use Continue or Load in the main menu."))
	col.add_child(_choice_row("Track", [["Indoor", "indoor"], ["Outdoor", "outdoor"]], "indoor" if _indoor else "outdoor",
			func(v): _indoor = v == "indoor"))
	col.add_child(_choice_row("Meet", [["Any", ""], ["Sections", "sections"], ["Heats", "heats"]], _round,
			func(v): _round = v))
	col.add_child(_choice_row("Level (who commentates)", [["Any", ""], ["Local", "local"], ["District", "district"],
			["National", "national"], ["International", "international"]], _level, func(v): _level = v))
	col.add_child(_choice_row("Runner", [["Boy", "male"], ["Girl", "female"]], "female" if _female else "male",
			func(v): _female = v == "female"))
	col.add_child(_choice_row("Strength", [["As a new 14-year-old", "0"], ["Youth finalist", "9"], ["Strong", "12"]],
			str(int(_ability)), func(v): _ability = float(v)))
	var go := UIKit.button("Start test race", true, 220)
	go.custom_minimum_size.y = 48
	go.size_flags_horizontal = Control.SIZE_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
	col.add_child(go)
	_race_message = UIKit.wrapped("")
	col.add_child(_race_message)
	go.pressed.connect(_start_race)
	var p := UIKit.panel(col, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _start_race() -> void:
	if _busy:
		return
	_busy = true
	_race_message.text = "Preparing the test race. This takes a few seconds; the window may not answer meanwhile..."
	await get_tree().process_frame
	await get_tree().process_frame
	var res := DevTools.start_test_race({"indoor": _indoor, "round": _round, "level": _level, "female": _female,
			"ability": _ability})
	_busy = false
	if not is_instance_valid(_race_message):
		return
	_race_message.text = res.message
	if res.ok:
		Router.go("race")


# --- Jump the career forward -----------------------------------------------------------------------------------

func _jump_panel() -> Control:
	var col := UIKit.vbox(10)
	col.add_child(UIKit.label("JUMP THE CAREER FORWARD", "CaptionLabel"))
	var have := Game.athlete != null
	if have:
		col.add_child(UIKit.wrapped("%s%s · today is %s. The days are played for real (training, health, rivals) and the game "
				% ["TEST CAREER: " if Game.dev_test else "", Game.athlete.full_name(), Calendar.format_day(Game.date)]
				+ "is saved once at the end. It stops early at a race day or when something needs your answer."))
	else:
		col.add_child(UIKit.wrapped("No career is open. Start one or choose Continue in the main menu first."))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var next_race := UIKit.button("To the next race day", true, 200)
	next_race.disabled = not have
	next_race.pressed.connect(func(): _jump({}))
	flow.add_child(next_race)
	for j in JUMP_MONTHS:
		var b := UIKit.button("To " + j[0], false, 120)
		b.disabled = not have
		var month: int = j[1]
		b.pressed.connect(func(): _jump(DevTools.next_first_of(month)))
		flow.add_child(b)
	col.add_child(flow)
	_jump_message = UIKit.wrapped("")
	col.add_child(_jump_message)
	var p := UIKit.panel(col, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _jump(until: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	_jump_message.text = "Playing the days. This can take a few seconds; the window may not answer meanwhile..."
	await get_tree().process_frame
	await get_tree().process_frame
	var res := DevTools.jump(until)
	_busy = false
	if res.result == Game.RACE:
		Router.go("race")
	else:
		Router.go("career_hub")


# --- Small pieces ------------------------------------------------------------------------------------------------

## A title and a row of toggle buttons (one chosen). `options`: [[label, value], ...]; `on_pick` gets the value.
func _choice_row(title: String, options: Array, current: String, on_pick: Callable) -> Control:
	var box := UIKit.vbox(4)
	box.add_child(UIKit.label(title, "MutedLabel"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var group := ButtonGroup.new()
	for o in options:
		var b := UIKit.toggle(o[0], group)
		b.custom_minimum_size.x = 100
		b.button_pressed = str(o[1]) == current
		var value: String = str(o[1])
		b.pressed.connect(func(): on_pick.call(value))
		flow.add_child(b)
	box.add_child(flow)
	return box
