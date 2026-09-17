class_name Orb
extends Node2D

# A soul mote dropped where something died. Drifts on its scatter for a moment,
# then flies to the player once inside the pickup radius.
#
# Green-gold, and it shines: a green halo, a yellow-green body, a hot core, and
# a four-point sparkle that waxes and wanes. Every mote gets a random phase so
# a floor covered in them twinkles instead of pulsing in unison -- nothing
# reads as fake faster than a hundred lights blinking together.

const RADIUS := 3.4
const DRAG := 3.2          # how fast the initial scatter bleeds off
const PULL := 900.0        # acceleration once the player has hold of it

var value := 1
var velocity := Vector2.ZERO
var pulled := false

# Motes and coins are the only things on the floor that animate for their own
# sake, and a big map can hold a lot of them off screen where the animation is
# nobody's business. Two savings: an invisible CanvasItem never runs _draw at
# all, and the twinkle is stepped rather than continuous -- offset by the
# existing random phase so they do not all fall on the same frame and turn the
# saving back into a spike.
const REDRAW_HZ := 20.0

var _t := 0.0
var _phase := 0.0
var _redraw_t := 0.0


func _ready() -> void:
	z_index = -1
	_phase = randf() * TAU
	_t = randf() * 4.0


func tick(delta: float, view: Rect2 = Rect2()) -> void:
	_t += delta
	var seen := view.size == Vector2.ZERO or view.has_point(position)
	if seen != visible:
		visible = seen
	if not seen:
		return
	_redraw_t += delta
	if _redraw_t >= 1.0 / REDRAW_HZ:
		_redraw_t = 0.0
		queue_redraw()


# A mote worth more is visibly worth more.
func radius() -> float:
	return RADIUS * (1.0 + 0.16 * float(value - 1))


func _draw() -> void:
	var R := radius()
	var beat := sin(_t * 4.6 + _phase)
	var pulse := 0.80 + 0.20 * beat
	var caught := 1.35 if pulled else 1.0     # brighter once it is coming to you

	# green halo
	draw_circle(Vector2.ZERO, (R + 6.0) * pulse, Color(Palette.XP_GLOW, 0.09 * caught))
	draw_circle(Vector2.ZERO, (R + 3.0) * pulse, Color(Palette.XP_GLOW, 0.20 * caught))

	# yellow-green body, hot core
	draw_circle(Vector2.ZERO, R, Palette.XP_MID)
	draw_circle(Vector2.ZERO, R * 0.45, Palette.XP_CORE)

	# the shine
	var twinkle := 0.5 + 0.5 * sin(_t * 3.1 + _phase * 1.7)
	var reach := (R + 7.0) * (0.45 + 0.55 * twinkle)
	var col := Color(Palette.XP_CORE, (0.22 + 0.42 * twinkle) * caught)
	draw_line(Vector2(-reach, 0.0), Vector2(reach, 0.0), col, 1.0)
	draw_line(Vector2(0.0, -reach), Vector2(0.0, reach), col, 1.0)
