class_name Enemy
extends Node2D

# The things in the dark.
#
# If the archetype has art, it plays sprite animations. If it does not, it
# falls back to the drawn silhouette -- near-black body with a blood rim -- so
# a new archetype is playable before anyone draws it.
#
# Dying is a STATE, not an instant free: the corpse plays its death animation
# while being ignored by targeting, collision and movement.

var kind := {}
var radius := 12.0
var speed := 60.0
var max_hp := 10
var hp := 10
var damage := 6
var motes := 1
var gold_chance := 0.0
var gold := 0
var is_dying := false

# Damage already in flight toward this creature. Targeting treats anything with
# `incoming >= hp` as already dead, which is what stops three bolts spending
# three shots to kill something one shot had covered. main.gd owns both sides:
# _shoot adds, _release gives back.
var incoming := 0

# Ranged archetypes stop at standoff range and throw instead of closing.
var ranged := {}
# Bosses plant themselves and swing, rather than damaging on contact.
var melee_attack := {}
var is_boss := false
var fire_cooldown := 0.0
var windup := 0.0
var _throw_pending := false
var knock := Vector2.ZERO

var _touch_cooldown := 0.0
var _hurt_flash := 0.0
var _anim: SpriteAnim = null
var _face_left := false
var _drawn_hurt := false


func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


# All per-vigil difficulty scaling lives here. This is the first knob to play
# with -- it is what makes the game feel fair or unfair.
func setup(wave: int, kind_id := "bat") -> void:
	kind = EnemyKinds.by_id(kind_id)
	radius = float(kind.get("radius", 10.0))
	max_hp = int(kind.get("hp_base", 8)) + int(kind.get("hp_per_wave", 4)) * wave
	hp = max_hp
	speed = float(kind.get("speed_base", 50.0)) + float(kind.get("speed_per_wave", 4.0)) * float(wave)
	damage = int(kind.get("damage_base", 4)) + int(kind.get("damage_per_wave", 1)) * wave
	motes = int(kind.get("motes", 1))
	gold_chance = float(kind.get("gold_chance", 0.0))
	gold = int(kind.get("gold", 0))
	ranged = kind.get("ranged", {})
	melee_attack = kind.get("melee_attack", {})
	is_boss = bool(kind.get("boss", false))
	fire_cooldown = randf_range(0.4, 1.4)     # stagger, so a pack does not volley as one

	var anims: Dictionary = kind.get("anims", {})
	if anims.has("run"):
		_anim = SpriteAnim.new()
		_anim.frame_size = kind.get("frame", Vector2i(64, 64))
		_anim.pivot = kind.get("pivot", Vector2(32.0, 32.0))
		_anim.scale = float(kind.get("scale", 1.0))
		_anim.play("run", anims["run"])


func tick(delta: float, face_left: bool) -> void:
	_touch_cooldown = maxf(0.0, _touch_cooldown - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	knock = knock.move_toward(Vector2.ZERO, 600.0 * delta)
	windup = maxf(0.0, windup - delta)
	# Redrawing is not free, and a late vigil holds close to two hundred of
	# these. Nothing in here MOVES the sprite -- a Node2D's position is a
	# transform the renderer reapplies to the command list it already has -- so
	# a redraw is only owed when the PICTURE changes: a new animation frame, a
	# flip, or the hurt tint going on or off. The animations run at ~10fps
	# against a 60fps game, so this drops roughly five redraws in six.
	var dirty := false
	if not is_dying:
		if _face_left != face_left:
			_face_left = face_left
			dirty = true
		# One place decides the animation, so a hurt or a throw always has a
		# way back to walking instead of freezing on its last frame.
		if windup > 0.0:
			dirty = _play("attack") or dirty
		elif _hurt_flash > 0.0:
			dirty = _play("hurt") or dirty
		else:
			dirty = _play("run") or dirty
	if _anim != null:
		dirty = _anim.advance(delta) or dirty

	# take_damage sets the flash from outside tick, so the transition is caught
	# here rather than at the point it is set.
	var hurt := _hurt_flash > 0.0
	if hurt != _drawn_hurt:
		_drawn_hurt = hurt
		dirty = true

	if dirty:
		queue_redraw()


func is_ranged() -> bool:
	return not ranged.is_empty()


func has_swing() -> bool:
	return not melee_attack.is_empty()


func standoff() -> float:
	return float(ranged.get("standoff", 0.0))


func swing_reach() -> float:
	return float(melee_attack.get("reach", 0.0))


# Both kinds of attacker share one wind-up: the animation plays before anything
# lands. An unannounced hit is the cheapest kind of unfair, and for a boss it
# is the whole fight.
func _spec() -> Dictionary:
	return ranged if is_ranged() else melee_attack


func wants_to_attack(dist: float) -> bool:
	if is_dying or (not is_ranged() and not has_swing()):
		return false
	if fire_cooldown > 0.0 or windup > 0.0:
		return false
	var at := standoff() * 1.05 if is_ranged() else swing_reach()
	return dist <= at


func begin_attack() -> void:
	var spec := _spec()
	windup = float(spec.get("windup", 0.4))
	fire_cooldown = 1.0 / maxf(float(spec.get("rate", 0.5)), 0.05)
	_throw_pending = true


# True exactly once, on the frame the wind-up finishes.
func consume_attack() -> bool:
	if _throw_pending and windup <= 0.0:
		_throw_pending = false
		return true
	return false


func throw_ready() -> bool:
	return is_ranged() and windup <= 0.0


func _play(anim_name: String) -> bool:
	var anims: Dictionary = kind.get("anims", {})
	if _anim != null and anims.has(anim_name):
		return _anim.play(anim_name, anims[anim_name])
	return false


func can_touch() -> bool:
	# A boss deals its damage through its swing, not by walking into you.
	return not is_dying and not has_swing() and _touch_cooldown <= 0.0


func is_rooted() -> bool:
	return windup > 0.0


func note_touched() -> void:
	_touch_cooldown = 0.6


func take_damage(amount: int, crit := false, push := Vector2.ZERO) -> void:
	if is_dying:
		return
	hp -= amount
	_hurt_flash = 0.16 if crit else 0.09
	if push != Vector2.ZERO:
		knock += push


# Start the death animation. The enemy stops being a threat immediately; it
# just has not finished falling over yet.
func begin_death() -> void:
	if is_dying:
		return
	is_dying = true
	var anims: Dictionary = kind.get("anims", {})
	if _anim != null and anims.has("death"):
		_anim.loop = false
		_anim.play("death", anims["death"], true)


func death_finished() -> bool:
	if _anim == null:
		return true
	return _anim.finished()


func _draw() -> void:
	if _anim != null:
		var tint := Color(1.0, 0.45, 0.45) if _hurt_flash > 0.0 else Color.WHITE
		_anim.draw_on(self, Vector2.ZERO, _face_left, tint)
		return

	# No art for this archetype yet.
	if _hurt_flash > 0.0:
		draw_circle(Vector2.ZERO, radius, Palette.BLOOD_BRIGHT)
		return
	draw_circle(Vector2.ZERO, radius, Palette.VOID_LIT)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Palette.BLOOD, 2.0)
