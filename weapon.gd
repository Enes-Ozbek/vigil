class_name Weapon
extends RefCounted

# The weapon a character carries. Weapons are not shared and are not picked up:
# each one is defined inline on its owner in characters.gd, so this just holds
# that dictionary plus the live firing state.
#
# Deliberately dumb: every "how strong is it really" question is answered by
# Player, because that is where the pact modifiers live.

var data: Dictionary
var cooldown := 0.0
var aim := Vector2.RIGHT
var flash := 0.0            # brief visual kick after firing

# A weapon may carry several projectiles. Only the first is available when a
# run begins; the rest unlock one per vigil survived, after which the weapon
# alternates between everything it has.
var unlocked_bolts := 1

# One cooldown per projectile, not one for the weapon. Two projectiles on the
# same cane must not take turns or fire in lockstep -- each runs on its own
# clock, at its own rate.
var bolt_cooldowns: Array[float] = []

# Where this weapon last fired from. Aim is computed from here, not from the
# character's position, or the shot leaves the staff head on a line parallel to
# the one that would actually hit.
var muzzle := Vector2.ZERO


func _init(weapon_data: Dictionary) -> void:
	data = weapon_data
	# A weapon with no "bolts" array behaves as one implicit attack, so the
	# firing path is identical for all of them.
	bolt_cooldowns.resize(maxi(1, bolts().size()))
	bolt_cooldowns.fill(0.0)


func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	for i in bolt_cooldowns.size():
		bolt_cooldowns[i] = maxf(0.0, bolt_cooldowns[i] - delta)
	flash = maxf(0.0, flash - delta)


func ready_to_fire() -> bool:
	return cooldown <= 0.0


func is_melee() -> bool:
	return data.get("kind", "shot") == "melee"


# A single bolt may swing the other way: a melee weapon can carry a thrown
# attack, and a ranged one could carry a swing. The weapon's kind is only the
# default.
func bolt_is_melee(bolt: Dictionary) -> bool:
	return String(bolt.get("kind", data.get("kind", "shot"))) == "melee"


func bolts() -> Array:
	return data.get("bolts", [])


func has_locked_bolts() -> bool:
	return unlocked_bolts < bolts().size()


func unlock_bolt() -> String:
	if not has_locked_bolts():
		return ""
	unlocked_bolts += 1
	# Start the new projectile out of phase so the two never fire together on
	# the very first shot.
	bolt_cooldowns[unlocked_bolts - 1] = 0.35
	return String(bolts()[unlocked_bolts - 1].get("name", "?"))


func unlocked_bolt_names() -> Array:
	var out := []
	for i in mini(unlocked_bolts, bolts().size()):
		out.append(String(bolts()[i].get("name", "?")))
	return out


func live_bolt_count() -> int:
	return maxi(1, mini(unlocked_bolts, maxi(1, bolts().size())))


func bolt_at(i: int) -> Dictionary:
	var bs := bolts()
	return bs[i] if i < bs.size() else {}


# Every unlocked projectile whose own cooldown has expired this frame.
func ready_bolts() -> Array:
	var out := []
	for i in live_bolt_count():
		if bolt_cooldowns[i] <= 0.0:
			out.append(i)
	return out


func note_bolt_fired(i: int, period: float) -> void:
	bolt_cooldowns[i] = period
	flash = 0.12
