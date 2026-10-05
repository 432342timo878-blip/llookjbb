extends Node
## Screen navigation. Screens call `Router.go("main_menu")`; main.gd swaps the screen in.

signal screen_requested(scene: PackedScene)

const SCREENS := {
	"main_menu": "res://scenes/screens/main_menu.tscn",
	"new_career": "res://scenes/screens/new_career.tscn",
	"career_hub": "res://scenes/screens/career_hub.tscn",
}


func go(screen_id: String) -> void:
	assert(SCREENS.has(screen_id), "Unknown screen: %s" % screen_id)
	screen_requested.emit(load(SCREENS[screen_id]))
