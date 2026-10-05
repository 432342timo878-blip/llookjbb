extends Control
## Placeholder until character creation is built in M1.

func _ready() -> void:
	%BackButton.pressed.connect(Router.go.bind("main_menu"))
