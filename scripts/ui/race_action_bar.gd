class_name RaceActionBar
extends VBoxContainer
## The always-there action bar of a watched race (GDD 4.3.1 "Player controls", step R3): Push / Hold / Ease (the pace
## until the kick; the active one is lit), Move out (a few seconds on the outside going for a pass; lit while it
## lasts) and Kick now (needs a second tap within controls.bar.kick_confirm_s seconds, against mistaken taps). No
## pause. 44 px buttons; PC = one row under the track, phone = four buttons and Move out in a second row.
## The race screen calls refresh() every frame; the buttons only change when their state does.

signal commanded(cmd: String)

const COMMANDS := ["push", "hold", "ease", "move_out", "kick"]
const LABELS := {"push": "Push", "hold": "Hold", "ease": "Ease", "move_out": "Move out", "kick": "Kick now"}

var _race: Race
var _buttons := {}
var _confirm_s := 2.0
var _armed_at := -1000.0      # real time (s) of the first tap on Kick now
var _shown := {}              # cmd -> the state the button was last given


func _init(race: Race) -> void:
	_race = race
	name = "ActionBar"
	_confirm_s = float(Data.races.controls.bar.kick_confirm_s)
	add_theme_constant_override("separation", 8)
	for cmd in COMMANDS:
		_buttons[cmd] = _make(cmd)
	if Layout.compact:
		var top := UIKit.hbox(8)
		for cmd in ["push", "hold", "ease", "kick"]:
			top.add_child(_buttons[cmd])
		add_child(top)
		add_child(_buttons.move_out)
	else:
		var row := UIKit.hbox(8)
		for cmd in COMMANDS:
			row.add_child(_buttons[cmd])
		add_child(row)


func _make(cmd: String) -> Button:
	var b := Button.new()
	b.text = LABELS[cmd]
	b.name = cmd
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE   # keys (F1, Esc) keep going to the screen
	if cmd == "kick":
		b.theme_type_variation = "PrimaryButton"
	else:
		b.toggle_mode = true
		b.theme_type_variation = "ToggleButton"
	b.pressed.connect(_on_pressed.bind(cmd))
	return b


func _on_pressed(cmd: String) -> void:
	if cmd == "kick":
		var now := Time.get_ticks_msec() / 1000.0
		if now - _armed_at > _confirm_s:
			_armed_at = now   # first tap: "Tap again to kick"
			refresh()
			return
		_armed_at = -1000.0
	if _race.command(cmd):
		commanded.emit(cmd)
	refresh()


## True while the first tap on Kick now is waiting for the second.
func kick_armed() -> bool:
	return Time.get_ticks_msec() / 1000.0 - _armed_at <= _confirm_s


func refresh() -> void:
	var p := _race.player
	if p == null:
		return
	for cmd in COMMANDS:
		var can := _race.can_command(cmd)
		var lit := false
		var text: String = LABELS[cmd]
		match cmd:
			"push", "hold", "ease":
				lit = _race.effort == cmd
			"move_out":
				lit = p.out_left > 0.0
			"kick":
				if p.kicking:
					text = "Kicking!"
				elif kick_armed() and can:
					text = "Tap again" if Layout.compact else "Tap again to kick"
		var state := "%s|%s|%s" % [can, lit, text]
		if _shown.get(cmd, "") == state:
			continue
		_shown[cmd] = state
		var b: Button = _buttons[cmd]
		b.disabled = not can
		b.text = text
		if b.toggle_mode:
			b.set_pressed_no_signal(lit)
