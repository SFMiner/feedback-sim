class_name Art
extends RefCounted
## Optional artwork lookup for the biology modules. If res://assets/bio/<name>.png or .svg exists it
## is used; otherwise the view draws its procedural placeholder. Models never see artwork, so
## swapping a picture cannot change the science. See assets/bio/README.md for the names.

# === CONSTANTS ===
const DIR: String = "res://assets/bio/"

# === PRIVATE VARIABLES ===
static var _cache: Dictionary = {}


# === PUBLIC METHODS ===
## Returns the texture for `name`, or null when no artwork has been supplied.
static func texture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var found: Texture2D = null
	for ext: String in [".png", ".svg"]:
		var path: String = DIR + name + ext
		if ResourceLoader.exists(path):
			found = load(path) as Texture2D
			break
	_cache[name] = found
	return found


## Draws artwork `name` stretched into `rect` and returns true, or returns false if there is none.
static func draw(ci: CanvasItem, name: String, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	var tex: Texture2D = texture(name)
	if tex == null:
		return false
	ci.draw_texture_rect(tex, rect, false, modulate)
	return true
