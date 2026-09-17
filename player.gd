class_name Player
extends Node2D

# The damned soul holding the chapel.
#
# If the chosen character has art, it plays sprite animations (idle / walk /
# cast / hurt / death). If it does not, it falls back to the pale drawn circle,
# so a character without art is still fully playable.
#
# IMPORTANT: pacts do not set absolute stats. Each weapon carries its own base
# damage / rate / reach, so pacts hold MODIFIERS (bonus + multiplier) that every
# carried weapon reads through the effective_* functions below. That is what
# lets "+6 damage" mean something sane whether you hold a 9-damage blade or a
# 26-damage cane.
#
# Positions here are WORLD units. The world node is scaled up for display, so
# these numbers stay small and readable -- see main.gd.

const RADIUS := 14.0
const MIN_MAX_HP := 10        # max health can be eaten by banes, but never to 0
const MAX_FIRE_RATE := 15.0   # backstop only -- additive stacking cannot reach it
const PICKUP_RADIUS := 70.0   # how far soul motes are dragged in from
const ARMOR_SCALE := 15.0     # see take_damage: each point is +1/15 effective health
const DAMAGE_TAKEN_CAP := 0.80
const MIN_RANGE := 50.0
const CAST_HOLD := 0.30       # how long the cast animation is held after firing

var speed_base := 220.0
var max_hp := 100
var hp := 100

# --- pact modifiers ---------------------------------------------------------
var damage_bonus := 0
# PERCENTAGES ADD, THEY DO NOT COMPOUND.
#
# These are bonus FRACTIONS starting at zero, applied as (1.0 + x) at the point
# of use -- so three pacts worth +25% each give +75%, not 1.25^3 = +95%.
#
# They used to be multipliers that each did `*= 1.25`, which compounded: a build
# that stacked one axis ran away from a build that spread, and MAX_FIRE_RATE had
# to exist as a load-bearing safety rail to stop attack speed reaching four
# figures. Brotato states plainly that its percentage stats stack additively,
# and that is why it needs no such rail. See BALANCE.md section 14.
var damage_pct := 0.0
var rate_pct := 0.0
var range_bonus := 0.0
var range_pct := 0.0
var area_pct := 0.0           # melee reach and projectile size
var bullet_speed_pct := 0.0
var bullet_life_pct := 0.0
var extra_shots := 0
var heal_on_kill := 0
var damage_taken_pct := 0.0   # fraction of incoming damage removed, capped
var armor := 0                # see take_damage: a divisor, never a subtraction
var regen := 0.0              # health per second
var revives := 0
var pickup_pct := 0.0         # widens PICKUP_RADIUS, motes are dragged further
var speed_pct := 0.0          # over the character's own speed
var xp_pct := 0.0
var luck := 0.0               # pushes pact offers up the tiers

# Crit gives damage variance, which is most of what makes a build feel alive.
var crit_chance := 0.0
var crit_mult := 1.8

# Dodge is a flat chance to take nothing at all. Brotato caps it at 60% and so
# do we: an uncapped avoid-everything stat ends the game as a decision.
var dodge := 0.0
const DODGE_CAP := 0.60

var pierce_bonus := 0
var bounce_bonus := 0
var knockback := 0.0
var mote_bonus := 0
var start_bolts := 1          # how many of the weapon's bolts are free at vigil 1

var level := 1
var xp := 0

var weapons: Array[Weapon] = []
var character := {}

var _regen_pool := 0.0
var _dodge_flash := 0.0
var _anim: SpriteAnim = null
var _face_left := false
var _cast_timer := 0.0
var _hurt_flash := 0.0
var _dead := false


func _ready() -> void:
	z_index = -1              # keep the HUD drawn on top of us
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hp = max_hp


func apply_character(c: Dictionary) -> void:
	character = c
	max_hp = int(c.get("max_hp", 100))
	hp = max_hp
	speed_base = float(c.get("speed", 220.0))
	damage_bonus += int(c.get("damage_bonus", 0))

	var anims: Dictionary = c.get("anims", {})
	if anims.has("idle"):
		_anim = SpriteAnim.new()
		_anim.frame_size = c.get("frame", Vector2i(64, 64))
		_anim.pivot = c.get("pivot", Vector2(32.0, 32.0))
		_anim.scale = float(c.get("scale", 1.0))
		_anim.play("idle", anims["idle"])

	if c.has("weapon"):
		add_weapon(c["weapon"])

	# Permanent upgrades bought in the Chapel, applied before the run begins.
	apply_upgrades(String(c.get("id", "")))
	for w in weapons:
		w.unlocked_bolts = clampi(start_bolts, 1, maxi(1, w.bolts().size()))
	hp = max_hp


# Permanent, bought with gold. Everything here writes the same modifier fields
# a pact would, so nothing downstream has to know where the power came from.
func apply_upgrades(char_id: String) -> void:
	if char_id == "":
		return
	Profile.load_all()
	for node_id in Profile.owned_for(char_id):
		match String(node_id):
			# Necromancer
			"ashen_grip": damage_pct += 0.08
			"long_practice": range_bonus += 25.0
			"second_hand": start_bolts = maxi(start_bolts, 2)
			"heavier_bone": bounce_bonus += 1
			"patient_dead": mote_bonus += 1
			"fevered_litany": rate_pct += 0.20
			"bore": pierce_bonus += 1
			"widening_dark": area_pct += 0.35
			# Vessel
			"set_stance": max_hp += 12
			"kept_edge": start_bolts = maxi(start_bolts, 2)
			"iron_grip": damage_pct += 0.08
			"ironhide": armor += 2
			"reaping": heal_on_kill += 2
			"follow_through": knockback += 120.0
			"wider_cut": area_pct += 0.42
			"unbroken": revives += 1
			# Poacher
			"steady_hand": damage_pct += 0.08
			"light_feet": speed_pct += 0.10
			"second_quiver": start_bolts = maxi(start_bolts, 2)
			"keen_eye": crit_chance = minf(crit_chance + 0.09, 1.0)
			"smoke_step": dodge = minf(dodge + 0.06, DODGE_CAP)
			"long_shot": range_bonus += 45.0
			"split_arrow": extra_shots += 1
			"vanishing": dodge = minf(dodge + 0.12, DODGE_CAP)


func tick(delta: float, arena: Rect2) -> void:
	var dir := _input_dir()
	position += dir * speed() * delta
	position.x = clampf(position.x, arena.position.x + RADIUS, arena.end.x - RADIUS)
	position.y = clampf(position.y, arena.position.y + RADIUS, arena.end.y - RADIUS)

	for w in weapons:
		w.tick(delta)

	_tick_regen(delta)
	_cast_timer = maxf(0.0, _cast_timer - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_dodge_flash = maxf(0.0, _dodge_flash - delta)

	# A melee swing wins the facing argument: its damage box is horizontal and
	# tied to the direction the sprite is facing, so the two must never
	# disagree. Otherwise face where you are going, else where you are shooting.
	var swung := false
	for w in weapons:
		if w.is_melee() and w.flash > 0.0:
			_face_left = w.aim.x < 0.0
			swung = true
			break
	if not swung:
		if absf(dir.x) > 0.01:
			_face_left = dir.x < 0.0
		elif not weapons.is_empty():
			_face_left = weapons[0].aim.x < 0.0

	_update_anim(delta, dir)
	queue_redraw()


# Regen accumulates fractionally so that "1.5 health per second" is honest
# rather than rounding to nothing every frame.
func _tick_regen(delta: float) -> void:
	if regen <= 0.0 or hp >= max_hp or _dead:
		return
	_regen_pool += regen * delta
	if _regen_pool >= 1.0:
		var whole := int(_regen_pool)
		_regen_pool -= float(whole)
		heal(whole)


func _update_anim(delta: float, dir: Vector2) -> void:
	if _anim == null:
		return
	var anims: Dictionary = character.get("anims", {})
	if not _dead:
		var want := "idle"
		if _cast_timer > 0.0:
			want = "cast"
		elif dir != Vector2.ZERO:
			want = "walk"
		if anims.has(want):
			_anim.play(want, anims[want])
	_anim.advance(delta)


func note_cast() -> void:
	_cast_timer = CAST_HOLD


func play_death() -> void:
	if _dead:
		return
	_dead = true
	var anims: Dictionary = character.get("anims", {})
	if _anim != null and anims.has("death"):
		_anim.loop = false
		_anim.play("death", anims["death"], true)


# Second Breath and friends: spend a revive instead of dying.
func try_revive() -> bool:
	if revives <= 0:
		return false
	revives -= 1
	hp = max_hp
	_hurt_flash = 0.4
	return true


# What the next level costs. The single most important number in the pacing of
# a run: lower it and pacts arrive in a flood, raise it and the run stalls.
# Brotato's curve: level L costs (L+3) squared -- 16, 25, 36, 49, 64. Linear
# XP against exploding kill counts meant levels arrived fastest exactly when
# they should have been slowing down. See BALANCE.md section 4.
func xp_to_next() -> int:
	return (level + 3) * (level + 3)


# Returns how many levels were gained, so the caller can queue that many pact
# screens instead of silently swallowing a double level-up.
func gain_xp(amount: int) -> int:
	xp += maxi(1, roundi(float(amount) * (1.0 + xp_pct)))
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		Audio.play("level_up", 0.0)
		gained += 1
		max_hp += 1              # a free point of health per level, as Brotato does
		hp += 1
	return gained


func add_weapon(weapon_data: Dictionary) -> void:
	weapons.append(Weapon.new(weapon_data))


# Surviving a vigil frees another of the character's projectiles. Returns what
# was unlocked, or "" if everything already is.
func unlock_next_bolt() -> String:
	for w in weapons:
		if w.has_locked_bolts():
			return w.unlock_bolt()
	return ""


# Where the character actually holds things, in local space, flipped with the
# sprite. For a drawn silhouette this is simply the centre.
func local_body_offset() -> Vector2:
	var o: Vector2 = character.get("body_offset", Vector2.ZERO)
	return Vector2(o.x * (-1.0 if _face_left else 1.0), o.y)


# Projectiles leave from the weapon, not from the character's feet.
func muzzle_position() -> Vector2:
	return position + local_body_offset()


# The muzzle for a facing we are ABOUT to adopt. Using the current facing would
# be a frame behind, putting the staff on the wrong side whenever a target
# crosses in front of you.
func muzzle_for(facing_left: bool) -> Vector2:
	var o: Vector2 = character.get("body_offset", Vector2.ZERO)
	return position + Vector2(o.x * (-1.0 if facing_left else 1.0), o.y)


# True when the sprite is already drawn holding its starting weapon, in which
# case drawing a glyph for that slot too gives the character two of them.
func art_holds_first_weapon() -> bool:
	return _anim != null and bool(character.get("art_holds_weapon", false))


# --- effective stats: weapon base, then pact modifiers ----------------------

func effective_damage(w: Weapon) -> int:
	var base := int(w.data.get("damage", 1))
	return maxi(1, roundi(float(base + damage_bonus) * (1.0 + damage_pct)))


func effective_rate(w: Weapon) -> float:
	return minf(float(w.data.get("rate", 1.0)) * (1.0 + rate_pct), MAX_FIRE_RATE)


# Each projectile may run at its own multiple of the weapon's rate, which is
# what keeps two bolts on one weapon from drifting into lockstep.
func effective_rate_of(w: Weapon, bolt: Dictionary) -> float:
	var m := float(bolt.get("rate_mult", 1.0))
	return minf(float(w.data.get("rate", 1.0)) * m * (1.0 + rate_pct), MAX_FIRE_RATE)


# Area widens a melee arc, because that IS its reach. For a ranged weapon area
# makes the projectile fatter instead -- see effective_bullet_size.
func effective_range(w: Weapon) -> float:
	var base := (float(w.data.get("range", 100.0)) + range_bonus) * (1.0 + range_pct)
	if w.is_melee():
		base *= 1.0 + area_pct
	return maxf(MIN_RANGE, base)


func effective_bullet_speed(w: Weapon, bolt := {}) -> float:
	return float(bolt.get("speed", w.data.get("speed", 300.0))) * (1.0 + bullet_speed_pct)


# How big a projectile is -- which is also how big it HITS. bullet.gd draws the
# art so its visible radius is exactly this, on the principle that a projectile
# which looks bigger than it hits is a lie the player will notice and resent.
#
# A bolt may state its own size. The fallback derives one from pierce, which is
# where this used to come from for everything -- a coupling that made no sense
# and caused a real bug: giving the Cinder `no_pierce` silently shrank the flame
# by a third, because how far a thing bores through a crowd had been quietly
# doing double duty as how large it looks.
func effective_bullet_size(w: Weapon, bolt := {}) -> float:
	var base: float = bolt.get("size",
		Bullet.RADIUS + float(bolt.get("pierce", w.data.get("pierce", 0))))
	return base * (1.0 + area_pct) * float(bolt.get("size_mult", 1.0))


func effective_shots(w: Weapon) -> int:
	return maxi(1, int(w.data.get("shots", 1)) + extra_shots)


# Extra projectiles SPLIT the shot rather than duplicating it: each one beyond
# the weapon's own carries 80% damage. Still a clear gain (two shots is 1.6x
# the damage of one, and they hit two different enemies) but it stops a single
# pact from doubling total output every time it is taken.
const SHOT_SPLIT := 0.80


func shot_damage_factor(w: Weapon) -> float:
	var extra := effective_shots(w) - int(w.data.get("shots", 1))
	return pow(SHOT_SPLIT, float(maxi(extra, 0)))


func effective_pierce(bolt: Dictionary, w: Weapon) -> int:
	# A bolt can opt out of piercing entirely. Without this a single Boneshear
	# would quietly turn every flame into a lance, which is the opposite of what
	# the bolt is for.
	if bool(bolt.get("no_pierce", false)):
		return 0
	return maxi(0, int(bolt.get("pierce", w.data.get("pierce", 0))) + pierce_bonus)


func effective_bounces(bolt: Dictionary) -> int:
	return maxi(0, int(bolt.get("bounces", 0)) + bounce_bonus)


func effective_bullet_life(w: Weapon, bolt := {}) -> float:
	# Live exactly long enough to cross the reach, so a long-reach pact never
	# leaves arrows dying in mid-air.
	var travel := effective_range(w) * float(bolt.get("range_mult", 1.0)) * 1.25
	var spd := maxf(effective_bullet_speed(w, bolt), 1.0)
	return (travel / spd) * (1.0 + bullet_life_pct)


# --- damage and health ------------------------------------------------------

# Returns false when the blow was dodged, so the caller can skip its effects.
func take_damage(amount: int) -> bool:
	if randf() < minf(dodge, DODGE_CAP):
		_dodge_flash = 0.22
		return false
	# Armour MULTIPLIES rather than subtracts. Flat subtraction has a cliff: once
	# armour reaches the incoming damage every hit lands for exactly 1, so the
	# stat is worthless right up until it is total. This curve gives a constant
	# +1/ARMOR_SCALE effective health per point at every value -- the displayed
	# reduction has diminishing returns, the value per point never does.
	var soak := 1.0 / (1.0 + float(maxi(armor, 0)) / ARMOR_SCALE)
	var taken := float(amount) * soak * (1.0 - minf(damage_taken_pct, DAMAGE_TAKEN_CAP))
	hp -= maxi(1, roundi(taken))
	Audio.play("player_hurt", 0.05)
	_hurt_flash = 0.15
	return true


# The character's speed with its bonuses, so nothing has to remember whether a
# bonus has already been folded in.
func speed() -> float:
	return speed_base * (1.0 + speed_pct)


func pickup_range() -> float:
	return PICKUP_RADIUS * (1.0 + pickup_pct)


# What a point of armour is currently worth, for the balance sim to check.
func effective_hp() -> float:
	return float(max_hp) * (1.0 + float(maxi(armor, 0)) / ARMOR_SCALE) 		/ maxf(1.0 - minf(damage_taken_pct, DAMAGE_TAKEN_CAP), 0.01)


func roll_crit() -> bool:
	return randf() < crit_chance


func crit_damage(base: int) -> int:
	return maxi(1, roundi(float(base) * crit_mult))


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)


func grow_max_hp_pct(pct: float) -> void:
	max_hp = maxi(MIN_MAX_HP, roundi(float(max_hp) * (1.0 + pct)))


# Banes eat max health as a PERCENTAGE, never a flat amount. A flat -6 per
# vigil stops costing anything once you hit the floor, which turns the pact
# into free power; a percentage always bites in proportion to what you have.
func shrink_max_hp_pct(pct: float) -> void:
	max_hp = maxi(MIN_MAX_HP, roundi(float(max_hp) * (1.0 - pct)))
	hp = mini(hp, max_hp)


func _input_dir() -> Vector2:
	if _dead:
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	return dir.normalized()


# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	# A dodge has to be legible or it just looks like the hit missed by luck.
	if _dodge_flash > 0.0:
		var k := _dodge_flash / 0.22
		draw_arc(Vector2.ZERO, RADIUS + 10.0 * (1.2 - k), 0.0, TAU, 28,
			Color(Palette.BONE, 0.55 * k), 2.0)

	if _anim != null:
		var tint := Color.WHITE
		if _hurt_flash > 0.0:
			tint = Color(1.0, 0.5, 0.5)
		elif _dodge_flash > 0.0:
			tint = Color(0.72, 0.78, 0.9)
		_anim.draw_on(self, Vector2.ZERO, _face_left, tint)
	else:
		var body := Palette.BLOOD_BRIGHT if _hurt_flash > 0.0 else Palette.BONE
		draw_circle(Vector2.ZERO, RADIUS, body)
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Palette.ASH, 2.0)

	# Weapon glyphs sit outside the body so they read as aim indicators rather
	# than as part of the character art. Slot 0 is skipped when the sprite is
	# already holding that weapon -- otherwise the necromancer carries two canes.
	var skip_first := art_holds_first_weapon()
	for i in weapons.size():
		if i == 0 and skip_first:
			continue
		_draw_weapon(weapons[i])


func _draw_weapon(w: Weapon) -> void:
	var dir: Vector2 = w.aim
	var hand := local_body_offset()
	var base := hand + dir * (RADIUS + 6.0)
	var lit := w.flash > 0.0

	match String(w.data.get("glyph", "blade")):
		"blade":
			var sx := -1.0 if dir.x < 0.0 else 1.0
			draw_line(hand, hand + Vector2(sx * (RADIUS + 22.0), 0.0),
				Palette.BONE if lit else Palette.ASH, 3.0)
			if lit:
				# Show the actual damage box, not a fan: this weapon cuts
				# horizontally and the indicator has to say so.
				# Centred on the character's position, exactly like the
				# damage test in main.gd -- an indicator that does not match
				# the hitbox is worse than none.
				var half_h := float(w.data.get("melee_height", 26.0)) * (1.0 + area_pct)
				var reach := effective_range(w)
				var bx := 0.0 if sx > 0.0 else -reach
				draw_rect(Rect2(bx, -half_h, reach, half_h * 2.0),
					Palette.BONE_DIM, false, 2.0)
		"bow":
			var a := dir.angle()
			draw_arc(base + dir * 5.0, 10.0, a - 1.15, a + 1.15, 14, Palette.BONE if lit else Palette.ASH, 2.0)
			draw_line(base + dir.rotated(-1.15) * 10.0, base + dir.rotated(1.15) * 10.0, Palette.ASH_DIM, 1.0)
		"cane":
			draw_line(base, base + dir * 15.0, Palette.ASH, 2.0)
			draw_circle(base + dir * 17.0, 4.0, Palette.BLOOD_BRIGHT if lit else Palette.BLOOD)
		"censer":
			for k in 3:
				var off := dir.rotated(deg_to_rad(-20.0 + 20.0 * float(k)))
				draw_circle(hand + off * (RADIUS + 15.0), 2.5, Palette.BONE if lit else Palette.BONE_DIM)
