class_name Icons
## The Lucide icons of assets/icons (GDD 5 "Icons", session L1a): white SVGs tinted with `modulate`; the colour is the meaning (a
## session's icon takes its intensity colour, others are muted). Sizes: 16 in rows and chips, 13 in slots, 20 in the bottom bar.

const DIR := "res://assets/icons/"

static var _cache := {}


## The texture of an icon by its Lucide name ("footprints"); null (and an error) for a name that is not in assets/icons.
static func texture(icon: String) -> Texture2D:
	if not _cache.has(icon):
		var path := DIR + icon + ".svg"
		_cache[icon] = load(path) if ResourceLoader.exists(path) else null
		if _cache[icon] == null:
			push_error("Icons: no icon '%s' in %s" % [icon, DIR])
	return _cache[icon]


## An icon as a fixed-size control (it never takes clicks: the row or button around it does).
static func rect(icon: String, size := 16.0, color := Palette.TEXT_MUTED) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(icon)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.modulate = color
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The icon of a training session (data/planner.json sessions; "circle-dot" for one that has none).
static func session(session_id: String) -> String:
	return str(Data.planner.sessions.get(session_id, {}).get("icon", "circle-dot"))


## The short name of a session for the planner ("Club group"), else its full name.
static func session_short(session_id: String) -> String:
	var s: Dictionary = Data.planner.sessions.get(session_id, {})
	if s.has("short"):
		return str(s.short)
	return str(Data.get_session(session_id).get("name", session_id))
