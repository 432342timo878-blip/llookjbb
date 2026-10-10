extends Node
## Screen navigation. Screens call `Router.go("main_menu")`; main.gd swaps the screen in.

signal screen_requested(scene: PackedScene)
## Emitted with the screen id when a screen is opened (main.gd uses it to pick the backdrop).
signal screen_changed(screen_id: String)
## Emitted when the window switches between the wide and the compact (phone portrait) layout.
signal layout_changed(compact: bool)

const SCREENS := {
	"main_menu": "res://scenes/screens/main_menu.tscn",
	"new_career": "res://scenes/screens/new_career.tscn",
	"career_hub": "res://scenes/screens/career_hub.tscn",
	"load_game": "res://scenes/screens/load_game.tscn",
	"race": "res://scenes/screens/race.tscn",
	"dev_menu": "res://scenes/screens/dev_menu.tscn",   # debug builds only (the main menu offers it there)
}


func go(screen_id: String) -> void:
	assert(SCREENS.has(screen_id), "Unknown screen: %s" % screen_id)
	screen_changed.emit(screen_id)
	screen_requested.emit(load(SCREENS[screen_id]))
