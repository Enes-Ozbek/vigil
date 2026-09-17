class_name Chest
extends Node2D

# A strongbox sitting somewhere on the floor. Walk into it and it opens.
#
# Two kinds, and they are deliberately nothing alike:
#
#   COMMON  scattered three to a vigil, drawn rather than sprited, bursts into
#           coins. It exists to make the larger arena worth crossing -- the
#           decision it creates is the point: the chest is over there, the wave
#           is thickening here, and an unopened one is lost when the vigil ends.
#
#   CURSED  dropped by a boss, sprited and animated, and it offers a CHOICE of
#           three cards instead of money. One per boss, so seeing one at all
#           means something died that had a health bar across the top.
#
# A cursed chest does not hand over its cards the instant you touch it: it
# plays its opening animation first and the screen arrives when the lid does.
# Roughly half a second, and it turns a pickup into a small event.

const RADIUS := 15.0
const DIR := "res://assets/chest/"

# One PNG per animation, 64x64 frames laid out horizontally -- the same layout
# the bat uses. The chest body occupies x 17..49, y 17..49 inside the cell, and
# the opening frames burst UPWARD out of that box as the lid swings back.
#
# The pivot is the middle of the BODY, not the base and not the middle of the
# cell. A walker's position is its feet because that is where it stands, but a
# chest is a thing you bump into: anchoring at the base left the RADIUS 15
# collision circle half-buried in empty floor below the art, so you had to walk
# past the chest to open it. Anchored at the body centre the circle covers
# almost exactly the box you can see.
const ANIM_IDLE := [DIR + "cursed_idle.png", 0, 6, 8.0]
const ANIM_OPEN := [DIR + "cursed_open.png", 0, 7, 14.0]
const FRAME := Vector2i(64, 64)
const PIVOT := Vector2(33.0, 33.0)

enum Phase { SHUT, OPENING, DONE }

var value := 40
var opened := false
var cursed := false
var phase: Phase = Phase.SHUT

var _t := 0.0
var _phase_off := 0.0
var _anim: SpriteAnim = null


func _ready() -> void:
	z_index = -1
	_phase_off = randf() * TAU
	_t = randf() * 3.0


# Called instead of _ready for a boss drop, because the art has to be loaded
# before the first _draw and _ready has already run by then.
func make_cursed() -> void:
	cursed = true
	z_index = 0                    # it should sit above the floor litter
	_anim = SpriteAnim.new()
	_anim.frame_size = FRAME
	_anim.pivot = PIVOT
	_anim.scale = 1.0
	_anim.play("idle", ANIM_IDLE)


# The lid starts to move. The card screen waits for finished_opening().
func begin_open() -> void:
	if phase != Phase.SHUT:
		return
	phase = Phase.OPENING
	if _anim != null:
		_anim.loop = false
		_anim.play("open", ANIM_OPEN, true)


func finished_opening() -> bool:
	if phase != Phase.OPENING:
		return false
	# With no art there is nothing to wait for, so it opens at once rather than
	# hanging forever on an animation that will never finish.
	if _anim == null:
		return true
	return _anim.finished()


func tick(delta: float) -> void:
	_t += delta
	if _anim != null:
		_anim.advance(delta)
	queue_redraw()


func _draw() -> void:
	if cursed:
		_draw_cursed()
		return
	_draw_common()


# Blood-lit rather than gold-lit, so it can never be mistaken for the common
# kind at a glance across a dark floor -- the reward is different, so the light
# coming off it is a different colour.
func _draw_cursed() -> void:
	var pulse := 0.78 + 0.22 * sin(_t * 2.1 + _phase_off)
	if phase != Phase.DONE:
		draw_circle(Vector2.ZERO, 46.0 * pulse, Color(Palette.BLOOD_BRIGHT, 0.05))
		draw_circle(Vector2.ZERO, 27.0 * pulse, Color(Palette.BLOOD_BRIGHT, 0.075))
	draw_circle(Vector2(0.0, 15.0), 12.0, Color(0.0, 0.0, 0.0, 0.34))
	if _anim != null:
		_anim.draw_on(self, Vector2.ZERO, false)
	else:
		_draw_common()             # no art imported: still visible, still playable


func _draw_common() -> void:
	var pulse := 0.78 + 0.22 * sin(_t * 2.3 + _phase_off)

	# Glow, so it can be spotted across a dark floor.
	draw_circle(Vector2.ZERO, 34.0 * pulse, Color(Palette.COIN, 0.055))
	draw_circle(Vector2.ZERO, 21.0 * pulse, Color(Palette.COIN, 0.085))

	var w := 26.0
	var h := 19.0
	var top := -h * 0.55

	# a shadow, so it sits ON the floor rather than floating above it
	draw_circle(Vector2(0.0, h * 0.5), w * 0.42, Color(0.0, 0.0, 0.0, 0.30))

	# body and lid
	draw_rect(Rect2(-w * 0.5, top, w, h), Palette.STONE_LIT)
	draw_rect(Rect2(-w * 0.5, top, w, h * 0.42), Palette.STONE)
	draw_rect(Rect2(-w * 0.5, top, w, h), Palette.PIT, false, 1.0)

	# gold banding and the clasp
	for x in [-w * 0.28, w * 0.28]:
		draw_rect(Rect2(x - 1.5, top, 3.0, h), Color(Palette.COIN, 0.85))
	draw_rect(Rect2(-w * 0.5, top + h * 0.42 - 1.0, w, 2.0), Color(Palette.COIN, 0.7))
	draw_circle(Vector2(0.0, top + h * 0.42), 3.2, Palette.COIN)
	draw_circle(Vector2(0.0, top + h * 0.42), 1.4, Palette.COIN_HI)

	# a glint that crosses the lid
	var g := fmod(_t * 0.5 + _phase_off, 3.0) / 3.0
	if g < 0.25:
		var gx := -w * 0.5 + (g / 0.25) * w
		draw_line(Vector2(gx, top + 1.0), Vector2(gx - 4.0, top + h - 1.0),
			Color(Palette.COIN_HI, 0.35), 2.0)
