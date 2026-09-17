class_name StatSheet

# What the player has actually become, in words.
#
# ---------------------------------------------------------------------------
# THE POINT IS THE DERIVED NUMBERS, NOT THE RAW ONES.
#
# The player carries fifty-eight fields and every pact moves one of them, but
# almost none of those fields mean anything on their own. "Armour 8" is not a
# quantity anybody can reason about; "37% of damage absorbed" is. Worse, the
# raw number and the felt effect do not even move together -- armour has
# constant value per point and diminishing displayed reduction, which is
# exactly the sort of thing a player will get wrong by eye and then stop
# buying.
#
# So every line here that CAN be expressed as an outcome is. Raw values appear
# only where they are already the outcome (health, move speed).
#
# This lives apart from menu.gd because it is the arithmetic, not the layout:
# the pause screen renders it today, the death screen is the obvious next
# caller, and tools/smoke_test.gd checks the maths without touching either.
# ---------------------------------------------------------------------------

# Rows whose value is zero are mostly noise -- twenty "+0%" lines bury the six
# that matter. But hiding everything at rest makes the screen rearrange itself
# as a run goes on, and a stat you have never seen is a stat you never buy. So
# the core stats are always present, and only the situational ones (pierce,
# revives, regen...) appear when a pact has actually granted them.
static func sections(p) -> Array:
	return [
		{"title": "THE BODY", "rows": _body(p)},
		{"title": "THE HAND", "rows": _hand(p)},
		{"title": "THE WORLD", "rows": _world(p)},
	]


static func _body(p) -> Array:
	var rows := [
		_row("life", "%d / %d" % [p.hp, p.max_hp]),
		_row("armour", "%d" % p.armor, "%s absorbed" % _pct(armour_soak(p.armor))),
		_row("dodge", _pct(minf(p.dodge, p.DODGE_CAP)), "of blows miss you"),
	]
	if p.damage_taken_pct > 0.0:
		rows.append(_row("resilience",
			_pct(minf(p.damage_taken_pct, p.DAMAGE_TAKEN_CAP)), "less damage taken"))
	if p.regen > 0.0:
		rows.append(_row("regeneration", "%.1f/s" % p.regen))
	if p.heal_on_kill > 0:
		rows.append(_row("lifesteal", "%d per kill" % p.heal_on_kill))
	if p.revives > 0:
		rows.append(_row("revives", "%d" % p.revives))
	# The one number that folds the whole column together. Armour, resilience
	# and dodge all buy survival in different currencies and cannot be compared
	# by eye; this is how much damage you can actually absorb before dying.
	rows.append(_row("you survive", "%d damage" % roundi(survivability(p))))
	return rows


static func _hand(p) -> Array:
	var rows := []
	if not p.weapons.is_empty():
		var w = p.weapons[0]
		rows.append(_row(String(w.data.get("name", "weapon")).to_lower(),
			"%d dmg" % p.effective_damage(w), "%.1f/s" % p.effective_rate(w)))
		# How many of the weapon's attacks are awake. One is free at vigil 1 (two
		# with the right Chapel upgrade) and one more unlocks per vigil survived,
		# so this climbs all run -- and it was the only thing the player owns that
		# no screen anywhere put a number on.
		var total: int = maxi(w.bolts().size(), 1)
		rows.append(_row("bolts", "%d of %d" % [
			clampi(w.unlocked_bolts, 1, total), total],
			"sealed" if w.unlocked_bolts < total else ""))
	rows.append(_row("damage", _signed_int(p.damage_bonus) + "  " + _signed_pct(p.damage_pct)))
	rows.append(_row("attack speed", _signed_pct(p.rate_pct)))
	rows.append(_row("critical", _pct(p.crit_chance),
		"x%.1f  (%s damage)" % [p.crit_mult, _signed_pct(crit_gain(p))]))
	rows.append(_row("reach", _signed_int(roundi(p.range_bonus)) + "  " + _signed_pct(p.range_pct)))
	if not is_zero_approx(p.area_pct):
		rows.append(_row("area", _signed_pct(p.area_pct)))
	if p.extra_shots > 0:
		rows.append(_row("extra shots", "+%d" % p.extra_shots))
	if p.pierce_bonus > 0:
		rows.append(_row("pierce", "+%d" % p.pierce_bonus))
	if p.bounce_bonus > 0:
		rows.append(_row("bounce", "+%d" % p.bounce_bonus))
	if not is_zero_approx(p.knockback):
		rows.append(_row("knockback", _signed_pct(p.knockback)))
	return rows


static func _world(p) -> Array:
	var rows := [
		_row("speed", "%d/s" % roundi(p.speed())),
		_row("pickup", "%d" % roundi(p.pickup_range())),
		_row("experience", _signed_pct(p.xp_pct)),
		_row("luck", "%.1f" % p.luck, "better offers"),
	]
	if p.mote_bonus > 0:
		rows.append(_row("motes", "+%d per kill" % p.mote_bonus))
	if not is_zero_approx(p.bullet_speed_pct):
		rows.append(_row("shot speed", _signed_pct(p.bullet_speed_pct)))
	if not is_zero_approx(p.bullet_life_pct):
		rows.append(_row("shot life", _signed_pct(p.bullet_life_pct)))
	rows.append(_row("level", "%d" % p.level))
	return rows


# --- the arithmetic worth testing -------------------------------------------

# The fraction of incoming damage armour removes. Mirrors take_damage exactly:
# if these two ever disagree the screen is lying, which is worse than no screen.
static func armour_soak(armor: int) -> float:
	return 1.0 - 1.0 / (1.0 + float(maxi(armor, 0)) / 15.0)


# What crit is worth as flat damage, averaged over many hits. A 20% chance of
# x1.8 is +16% damage, which is the only form in which it can be weighed
# against a +16% damage pact sitting on the next card.
static func crit_gain(p) -> float:
	return clampf(p.crit_chance, 0.0, 1.0) * (p.crit_mult - 1.0)


# Total damage absorbed before death, counting armour, resilience AND dodge.
#
# player.effective_hp() deliberately leaves dodge out -- the balance sim uses it
# to measure armour in isolation -- but a player asking "how tough am I" is
# asking the question that includes dodge, so it is folded back in here rather
# than by changing the sim's instrument.
static func survivability(p) -> float:
	return p.effective_hp() / maxf(1.0 - minf(p.dodge, p.DODGE_CAP), 0.01)


# --- formatting -------------------------------------------------------------

static func _row(key: String, value: String, note := "") -> Dictionary:
	return {"k": key, "v": value, "n": note}


static func _pct(f: float) -> String:
	return "%d%%" % roundi(f * 100.0)


static func _signed_pct(f: float) -> String:
	return "%s%d%%" % ["+" if f >= 0.0 else "", roundi(f * 100.0)]


static func _signed_int(v: int) -> String:
	return "%s%d" % ["+" if v >= 0 else "", v]
