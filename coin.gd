class_name Coin
extends Node2D

# Gold, dropped where something died. Unlike a soul mote it is NOT swept up
# when a vigil ends -- a coin you did not reach is a coin you did not earn.
# See META.md section 2.
#
# Told apart from motes by three things at once: amber rather than green-gold,
# a flat rimmed disc rather than a haloed orb, and a spin rather than a pulse.
# The spin is the strongest of the three -- a disc turning edge-on reads as a
# coin instantly, even glimpsed in a crowd.

const RADIUS := 4.2
const DRAG := 3.2
const PULL := 900.0
const SPIN := 5.0

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


func _draw() -> void:
	# Squash the width to spin it. Never quite to zero, or it vanishes for a
	# frame and reads as a flicker rather than a turn.
	var squash := maxf(absf(cos(_t * SPIN + _phase)), 0.10)
	var glow := 0.10 + 0.05 * sin(_t * 3.0 + _phase)
	if pulled:
		glow += 0.08

	draw_circle(Vector2.ZERO, RADIUS + 5.0, Color(Palette.COIN, glow))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(squash, 1.0))
	draw_circle(Vector2.ZERO, RADIUS + 1.3, Palette.COIN_RIM)
	draw_circle(Vector2.ZERO, RADIUS, Palette.COIN)
	draw_circle(Vector2.ZERO, RADIUS * 0.46, Palette.COIN_HI)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
