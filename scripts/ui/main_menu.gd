extends Control

@onready var _new_career: Button = %NewCareerButton
@onready var _quit: Button = %QuitButton
@onready var _footer: Label = %FooterLabel


func _ready() -> void:
	_new_career.pressed.connect(Router.go.bind("new_career"))
	_quit.pressed.connect(get_tree().quit)
	# Quitting isn't a thing on mobile; the OS handles it.
	_quit.visible = not OS.has_feature("mobile")
	_footer.text = "v0.1 · %d events · %d attributes loaded" % [Data.events.size(), Data.attributes.size()]
	_new_career.grab_focus()
