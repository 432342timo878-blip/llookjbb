extends Control
## App shell: applies the theme and the responsive scale, and hosts whichever screen the Router asks for.

@onready var _screen_host: Control = $ScreenHost
@onready var _backdrop: ColorRect = $Background


func _ready() -> void:
	Router.screen_requested.connect(_show_screen)
	Router.screen_changed.connect(_backdrop.show_for)
	get_window().size_changed.connect(_update_layout)
	_update_layout()
	Router.go("main_menu")


## Picks wide or compact (phone portrait) from the window size and scales the UI to fit.
## Shrinking the PC window to a narrow strip is a quick way to try the phone layout.
func _update_layout() -> void:
	var window := get_window()
	var px := Vector2(window.size)
	if px.x < 1.0 or px.y < 1.0:
		return
	var compact := Layout.is_compact_for(px)
	var factor := Layout.scale_for(px, compact)
	var logical := Vector2i((px / factor).round())
	if window.content_scale_size != logical:
		window.content_scale_size = logical
	Layout.logical_width = float(logical.x)
	_apply_safe_area(px, factor)
	if theme == null or compact != Layout.compact:
		Layout.compact = compact
		theme = ThemeBuilder.build(compact)
		Router.layout_changed.emit(compact)


## Keeps the UI out of phone notches and rounded corners.
func _apply_safe_area(window_px: Vector2, factor: float) -> void:
	var inset := Vector4.ZERO   # left, top, right, bottom in logical pixels
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if safe.size.x > 0 and screen.x > 0:
			inset = Vector4(safe.position.x, safe.position.y,
					screen.x - safe.end.x, screen.y - safe.end.y) / factor
	_screen_host.offset_left = inset.x
	_screen_host.offset_top = inset.y
	_screen_host.offset_right = -inset.z
	_screen_host.offset_bottom = -inset.w


func _show_screen(scene: PackedScene) -> void:
	for child in _screen_host.get_children():
		child.queue_free()
	_screen_host.add_child(scene.instantiate())
