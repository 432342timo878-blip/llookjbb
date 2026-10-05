extends Control
## App shell: applies the theme and hosts whichever screen the Router asks for.

@onready var _screen_host: Control = $ScreenHost


func _ready() -> void:
	theme = ThemeBuilder.build()
	Router.screen_requested.connect(_show_screen)
	Router.go("main_menu")


func _show_screen(scene: PackedScene) -> void:
	for child in _screen_host.get_children():
		child.queue_free()
	_screen_host.add_child(scene.instantiate())
