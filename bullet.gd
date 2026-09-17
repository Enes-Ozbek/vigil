class_name Bullet
extends Node2D

const RADIUS := 4.0

var velocity := Vector2.ZERO
var damage := 10
var life := 1.5
var size := RADIUS
var pierce := 0

# How far the hit spreads, and what a bystander takes of the direct damage.
# Zero radius means a bullet that only hurts what it actually touched.
var splash := 0.0
var splash_mult := 0.5

# Bouncing is not piercing: a piercing bolt carries straight on through, a
# bouncing one stops dead in the first enemy and leaps to another.
var bounces := 0
var tint := Palette.BONE
var crit := false

# A weapon may fire an actual object rather than a dot. The skull the
# necromancer carries tumbles as it flies, which is why this rotates instead
# of pointing along the velocity.
var texture: Texture2D = null
var spin := 7.0
var angle := 0.0
# Sprites are drawn pointing up, so aligning one to its travel direction means
# rotating to the velocity angle plus a quarter turn.
var align_to_velocity := false

# Which way the ARTWORK points, as an angle. Up is -PI/2 and is the default,
# because most projectile art is drawn pointing up. The sword art points
# down-right, so it declares +PI/4.
#
# Stating the direction the art faces is far less error-prone than an offset
# to be added to something: the alignment is then just "turn the art from
# where it points to where it is going".
var art_forward := -PI * 0.5

# A projectile may be animated rather than a single frame.
var frames := 1
var frame_size := Vector2i.ZERO
var fps := 12.0
var anim_t := 0.0

# Where the actual artwork sits inside each texture. Both projectile sprites
# are padded to a square so they can rotate about their centre, so scaling by
# the texture width would size them by their padding: the skull is 6px of art
# in a 10px square and drew too small, the flame 19px in 23px and drew too big.
# Measured once per texture and cached.
static var _content := {}

# Instance ids, not node references: an enemy this bullet already hit may be
# freed before the bullet is, and comparing against freed objects is asking
# for trouble.
# The enemy this bullet's damage is reserved against, if any. Untyped on
# purpose -- Bullet naming Enemy and Enemy naming Bullet is a parse-time cycle.
var reserved = null
var hit_ids: Array[int] = []


func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func advance(delta: float) -> void:
	if texture == null:
		return
	anim_t += delta
	if align_to_velocity:
		angle = velocity.angle() - art_forward
	else:
		angle += spin * delta
	queue_redraw()


static func content_rect(tex: Texture2D) -> Rect2i:
	var key := tex.resource_path
	if not _content.has(key):
		var img := tex.get_image()
		_content[key] = img.get_used_rect() if img != null else Rect2i(Vector2i.ZERO, tex.get_size())
	return _content[key]


func _draw() -> void:
	if texture != null:
		if frames > 1 and frame_size != Vector2i.ZERO:
			_draw_animated()
			return
		# Draw so the VISIBLE art is exactly the collision radius: what you see
		# is what hits.
		var cr := content_rect(texture)
		var content_r := maxf(float(cr.size.x), float(cr.size.y)) * 0.5
		var k := size / maxf(content_r, 1.0)
		var centre := Vector2(cr.position) + Vector2(cr.size) * 0.5
		draw_set_transform(Vector2.ZERO, angle, Vector2(k, k))
		draw_texture(texture, -centre)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if crit:
		draw_circle(Vector2.ZERO, size + 2.5, Color(Palette.XP_CORE, 0.5))
	draw_circle(Vector2.ZERO, size, tint)
	if pierce > 0:
		draw_arc(Vector2.ZERO, size + 2.0, 0.0, TAU, 12, Palette.BLOOD, 1.0)


func _draw_animated() -> void:
	var f := int(anim_t * fps) % frames
	var src := Rect2(float(f * frame_size.x), 0.0, float(frame_size.x), float(frame_size.y))
	var half := Vector2(frame_size) * 0.5
	# Scale from the frame, not from a per-frame content rect: measuring each
	# frame separately would make an animated sprite breathe as it flies.
	var k := (size * 2.4) / maxf(float(maxi(frame_size.x, frame_size.y)), 1.0)
	draw_set_transform(Vector2.ZERO, angle, Vector2(k, k))
	draw_texture_rect_region(texture, Rect2(-half, Vector2(frame_size)), src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
