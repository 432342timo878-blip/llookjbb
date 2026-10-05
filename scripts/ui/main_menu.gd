extends Control

@onready var _new_career: Button = %NewCareerButton
@onready var _load: Button = $Margin/Row/Left/LoadButton
@onready var _quit: Button = %QuitButton
@onready var _footer: Label = %FooterLabel


func _ready() -> void:
	_new_career.pressed.connect(Router.go.bind("new_career"))
	_quit.pressed.connect(get_tree().quit)
	# Quitting isn't a thing on mobile; the OS handles it.
	_quit.visible = not OS.has_feature("mobile")
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
