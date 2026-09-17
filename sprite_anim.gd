class_name SpriteAnim
extends RefCounted

# Minimal sprite-sheet playback, drawn through _draw() like everything else in
# this project -- no AnimatedSprite2D nodes to wire up.
#
# Handles both layouts we have:
#   necromancer  one sheet, animations on different ROWS   (row 0..6)
#   bat          one file PER animation, always row 0
#
# An animation is [texture_path, row, frame_count, fps].

static var _cache := {}

var texture: Texture2D
var frame_size := Vector2i(64, 64)
var pivot := Vector2(32, 32)     # point in the frame that sits on the entity's position
var scale := 1.0

var row := 0
var frames := 1
var fps := 10.0
var loop := true

var time := 0.0
var name := ""


# Textures live here for the life of the process, which is right for a game and
# wrong for a headless tool that quit()s: the engine then reports them as
# resources still in use, and that noise sits exactly where a real error should
# stand out. The tools drop the cache before they exit.
static func clear_cache() -> void:
	_cache.clear()


static func texture_for(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


# Returns true when the visible frame actually changed, so a caller can decide
# whether it owes the engine a redraw. See Enemy.tick.
func play(anim_name: String, spec: Array, restart := false) -> bool:
	if name == anim_name and not restart:
		return false
	name = anim_name
	texture = texture_for(String(spec[0]))
	row = int(spec[1])
	frames = maxi(1, int(spec[2]))
	fps = float(spec[3])
	time = 0.0
	return true


func advance(delta: float) -> bool:
	var before := frame_index()
	time += delta
	return frame_index() != before


func frame_index() -> int:
	var i := int(time * fps)
	if loop:
		return i % frames
	return mini(i, frames - 1)


func finished() -> bool:
	return not loop and time * fps >= float(frames)


func draw_on(ci: CanvasItem, at: Vector2, flip: bool, tint := Color.WHITE) -> void:
	if texture == null:
		return
	var f := frame_index()
	var src := Rect2(
		float(f * frame_size.x), float(row * frame_size.y),
		float(frame_size.x), float(frame_size.y))

	# Flip by mirroring the transform around the pivot, so the sprite turns on
	# the spot instead of sliding sideways.
	ci.draw_set_transform(at, 0.0, Vector2(-scale if flip else scale, scale))
	ci.draw_texture_rect_region(texture, Rect2(-pivot, Vector2(frame_size)), src, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
