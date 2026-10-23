extends ColorRect
## The app background. Draws the gradient from `ui/backdrop.gdshader`; if a photo exists for the current
## screen (assets/backgrounds/<screen_id>.jpg/.png/.webp, or default.*) it shows it blurred and darkened.

const SHADER := preload("res://ui/backdrop.gdshader")
const FOLDER := "res://assets/backgrounds/"
const EXTENSIONS := ["jpg", "jpeg", "png", "webp"]
## V1 (GDD 5 "Backdrop", session L1a): data screens get the plain BG; the photo belongs to the big moments (main menu, race intro,
## career start, the season review).
const PLAIN_SCREENS := ["career_hub"]

var _material := ShaderMaterial.new()


func _ready() -> void:
	_material.shader = SHADER
	material = _material
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_update_size)
	_update_size()
	show_for("default")


func _update_size() -> void:
	_material.set_shader_parameter("rect_size", size)


## Photo for this screen id, falling back to default.*, falling back to the plain gradient.
func show_for(screen_id: String) -> void:
	if screen_id in PLAIN_SCREENS:
		material = null
		color = Palette.BG
		return
	material = _material
	color = Color.WHITE
	var tex := _find_photo(screen_id)
	if tex == null:
		tex = _find_photo("default")
	_material.set_shader_parameter("has_photo", tex != null)
	if tex != null:
		_material.set_shader_parameter("photo", tex)
		_material.set_shader_parameter("photo_size", Vector2(tex.get_size()))


func _find_photo(id: String) -> Texture2D:
	for ext in EXTENSIONS:
		var path := "%s%s.%s" % [FOLDER, id, ext]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null
