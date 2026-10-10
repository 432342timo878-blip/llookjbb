extends Control

@onready var _new_career: Button = %NewCareerButton
@onready var _load: Button = $Margin/Row/Left/LoadButton
@onready var _quit: Button = %QuitButton
@onready var _footer: Label = %FooterLabel


func _ready() -> void:
	Router.layout_changed.connect(func(_c): _apply_layout())
	_apply_layout.call_deferred()   # after the Continue button below has been added
	_new_career.pressed.connect(Router.go.bind("new_career"))
	_quit.pressed.connect(get_tree().quit)
	# Quitting isn't a thing on mobile; the OS handles it.
	_quit.visible = not OS.has_feature("mobile")
	if DevTools.available():   # (a test build, i.e. the game run from the Godot editor: a menu for playtesting)
		var dev := UIKit.button("Dev menu (test build)", false, 280)
		dev.pressed.connect(Router.go.bind("dev_menu"))
		_quit.add_sibling(dev)
		_quit.get_parent().move_child(dev, _quit.get_index())
	_footer.text = "v0.1 · %d events · %d attributes loaded" % [Data.events.size(), Data.attributes.size()]

	var saves := SaveGame.list()
	_load.disabled = saves.is_empty()
	_load.pressed.connect(Router.go.bind("load_game"))
	if saves.is_empty():
		_new_career.grab_focus()
		return
	# Continue the most recent save; New Career becomes a normal button.
	var cont := UIKit.button("Continue", true, 280)
	cont.custom_minimum_size.y = 48
	cont.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cont.tooltip_text = saves[0].summary
	cont.pressed.connect(func():
		if SaveGame.load_slot(saves[0].slot):
			Router.go("career_hub"))
	_new_career.add_sibling(cont)
	_new_career.get_parent().move_child(cont, _new_career.get_index())
	_new_career.theme_type_variation = ""
	cont.grab_focus()


## Wide: menu on the left, stadium on the right. Phone: the stadium is a banner above the menu,
## and the buttons use the full width.
func _apply_layout() -> void:
	var margin: MarginContainer = $Margin
	if Layout.compact:
		Layout.page_margin(margin)
		margin.add_theme_constant_override("margin_top", 24)
	else:
		margin.add_theme_constant_override("margin_left", 64)
		margin.add_theme_constant_override("margin_top", 48)
		margin.add_theme_constant_override("margin_right", 48)
		margin.add_theme_constant_override("margin_bottom", 32)
	var row: BoxContainer = $Margin/Row
	var left: Control = $Margin/Row/Left
	var track: Control = $Margin/Row/Track
	row.vertical = Layout.compact
	row.add_theme_constant_override("separation", 20 if Layout.compact else 48)
	left.custom_minimum_size.x = 0.0 if Layout.compact else 380.0
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track.custom_minimum_size.y = 190.0 if Layout.compact else 0.0
	track.size_flags_vertical = Control.SIZE_FILL if Layout.compact else Control.SIZE_EXPAND_FILL
	row.move_child(track, 0 if Layout.compact else 1)
	$Margin/Row/Left/Spacer.visible = not Layout.compact
	$Margin/Row/Left/Subtitle.custom_minimum_size.x = 0.0 if Layout.compact else 360.0
	for child in left.get_children():
		if child is Button:
			child.size_flags_horizontal = Control.SIZE_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
			child.custom_minimum_size.x = 0.0 if Layout.compact else 280.0
