extends SceneTree

# Balance harness. Not part of the game -- run it to see how pact stacking
# plays out over a full run without having to play fifteen vigils by hand.
#
# Run with:
#   godot --headless --path . -s tools/balance_sim.gd
#
# Respects MAX_STACKS by drawing from the same filtered pool the real
# _end_vigil() builds, so the numbers reflect what a player can actually do.
# Stats are reported through Player.effective_* for the reference character's
# starting weapon, because pacts modify weapons rather than the player directly.

var _done := false


# This is measurement, not play -- it simulates whole runs, and main cannot tell
# the difference. Without this the run left on disk is the simulation's,
# and the menu offers it back to the player as their own.
func _initialize() -> void:
	RunSave.suspended = true


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run("greedy blood (Widow's Gift / Blood Price first)", ["widows_gift", "blood_price"])
	_run("greedy speed (A Thousand Cuts / Fevered Hands first)", ["thousand_cuts", "fevered_hands"])
	_run("world-worsening (Gluttony / Hungering Dark first)", ["gluttony", "hungering_dark"])
	_run("random", [])
	_weapon_table()
	_every_pact_check()
	_tier_check()
	_vigil_kind_check()
	_armour_check()
	_rail_check()
	_hits_to_kill()
	_clear_rate()
	_run_projection(false)
	_run_projection(true)
	return true


func _run(label: String, prefer: Array) -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	# Run as a real character so max_hp and the starting weapon are honest.
	main.player.apply_character(Characters.ALL[0])
	var w = main.player.weapons[0]

	print("\n=== %s ===   (as %s, holding the %s)" % [label, Characters.ALL[0]["name"], w.data["name"]])
	print("vigil  dmg   rate  reach  maxhp    ehp   espd  srate    dps")

	for v in 15:
		var pool := _available(main)
		if pool.is_empty():
			print("  pool exhausted at vigil %d" % main.wave)
			break

		var pact: Dictionary = pool[randi() % pool.size()]
		for want in prefer:
			var hit := false
			for p in pool:
				if p["id"] == want:
					pact = p
					hit = true
					break
			if hit:
				break

		main._swear_pact(pact)
		main._begin_vigil()

		var p2 = main.player
		var dmg: int = p2.effective_damage(w)
		var rate: float = p2.effective_rate(w)
		print("%5d %4d %6.2f %6d %6d %6.2f %6.2f %6.2f %6.1f" % [
			main.wave, dmg, rate, int(p2.effective_range(w)), p2.max_hp,
			main.enemy_hp_mult, main.enemy_speed_mult, main.spawn_rate_mult,
			float(dmg) * rate])

	root.remove_child(main)
	main.free()


# Each character owns one weapon; this shows what each actually brings, per
# bolt, so a "different" character that is really the same numbers shows up.
func _weapon_table() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	print("\n=== characters at base (no pacts) ===")
	print("character         weapon                 bolt           dmg   rate    dps")
	for c in Characters.ALL:
		main.player.weapons.clear()
		main.player.apply_character(c)
		var w = main.player.weapons[0]
		w.unlocked_bolts = w.bolts().size()
		var total := 0.0
		for bi in w.bolts().size():
			var bd = w.bolt_at(bi)
			var dmg: int = maxi(1, roundi(float(main.player.effective_damage(w)) * float(bd.get("damage_mult", 1.0))))
			var rate: float = main.player.effective_rate_of(w, bd)
			total += float(dmg) * rate
			print("%-17s %-22s %-14s %4d %6.2f %6.1f" % [
				c["name"], w.data["name"], bd.get("name", "-"), dmg, rate, float(dmg) * rate])
		print("%-17s %-22s %-14s %4s %6s %6.1f  <- all bolts unlocked" % ["", "", "TOTAL", "", "", total])
	root.remove_child(main)
	main.free()


func _available(main) -> Array:
	var pool := []
	for p in Pacts.ALL:
		if int(main.pact_counts.get(p["id"], 0)) < main.MAX_STACKS:
			pool.append(p)
	return pool


# Swears every pact in the game. A boon that writes to a property that does not
# exist fails loudly here instead of silently doing nothing in a real run.
func _every_pact_check() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.player.apply_character(Characters.ALL[0])
	print("\n=== every pact applied (%d total) ===" % Pacts.ALL.size())
	var w = main.player.weapons[0]
	for p in Pacts.ALL:
		main._swear_pact(p)
	var pl = main.player
	print("  after swearing all %d: dmg=%d rate=%.2f reach=%d shots=%d maxhp=%d armor=%d regen=%.1f revives=%d" % [
		Pacts.ALL.size(), pl.effective_damage(w), pl.effective_rate(w),
		int(pl.effective_range(w)), pl.effective_shots(w), pl.max_hp,
		pl.armor, pl.regen, pl.revives])
	print("  new axes: crit %.0f%% x%.2f | dodge %.0f%% (cap %.0f%%) | pierce +%d | bounce +%d | luck %.0f | knockback %.0f" % [
		pl.crit_chance * 100.0, pl.crit_mult, pl.dodge * 100.0, Player.DODGE_CAP * 100.0,
		pl.pierce_bonus, pl.bounce_bonus, pl.luck, pl.knockback])
	print("  world: ehp=%.2f espd=%.2f srate=%.2f corruption=%d" % [
		main.enemy_hp_mult, main.enemy_speed_mult, main.spawn_rate_mult, main.corruption])
	root.remove_child(main)
	main.free()


# How often each tier is actually offered, early and late, with and without
# Luck. A rarity system that does not visibly change the offers is decoration.
func _tier_check() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.player.apply_character(Characters.ALL[0])
	print("\n=== pact tier distribution (2000 offers each) ===")
	print("A card is not a screen: %d cards are offered, so per-card odds understate"
		% main.OFFER_COUNT)
	print("how often a Damned actually appears. The last column is what you see.")
	print("situation                 Common   Grim  Damned   >=1 Damned/screen")
	for case in [[1, 0.0], [4, 0.0], [7, 0.0], [8, 0.0], [12, 0.0], [15, 0.0], [15, 3.0]]:
		main.wave = int(case[0])
		main.player.luck = float(case[1])
		var count := [0, 0, 0, 0]
		var screens_with := 0
		var screens := 500
		for i in screens:
			var any := false
			for o in main._roll_offers():
				count[int(o.get("tier", 1))] += 1
				if int(o.get("tier", 1)) == 3:
					any = true
			if any:
				screens_with += 1
		var tot: float = maxf(float(count[1] + count[2] + count[3]), 1.0)
		print("vigil %2d, luck %.0f          %5.0f%% %5.0f%% %6.0f%%   %13.0f%%" % [
			case[0], case[1], 100.0 * count[1] / tot, 100.0 * count[2] / tot,
			100.0 * count[3] / tot, 100.0 * float(screens_with) / float(screens)])
	root.remove_child(main)
	main.free()


# A full simulated run: kill everything that spawns, bank the motes, level up,
# take pacts by the real tier weights, and see whether the player's damage
# keeps up with what the arena is throwing. This is the only honest way to
# check BALANCE.md section 5, because the pact pool is far too tangled to add
# up on paper.
func _run_projection(greedy: bool) -> void:
	var who := "picking the rarest offer" if greedy else "picking at random"
	print("\n=== run projection: 40 runs, Necromancer, %s ===" % who)
	var dps_at := {}
	var pacts_at := {}
	for v in [1, 5, 10, 15]:
		dps_at[v] = 0.0
		pacts_at[v] = 0.0

	for trial in 40:
		var main = load("res://main.tscn").instantiate()
		root.add_child(main)
		main.player.apply_character(Characters.by_id("necromancer"))
		var w = main.player.weapons[0]
		var pool := 0.0
		var taken := 0

		for v in range(1, 16):
			main.wave = v
			if v == 2:
				w.unlock_bolt()
			# income for this vigil
			var length: float = main.vigil_length(v)
			var interval: float = maxf(main.SPAWN_FLOOR, main.SPAWN_INTERVAL - float(v) * main.SPAWN_RAMP)
			var spawned: float = length / interval
			var motes := 0.0
			for i in int(spawned):
				var k := EnemyKinds.by_id(EnemyKinds.roll(v))
				motes += float(k.get("motes", 1))
			pool += motes
			# levels
			var gained := 0
			while pool >= float(main.player.xp_to_next()):
				pool -= float(main.player.xp_to_next())
				main.player.level += 1
				gained += 1
			# pacts: one per level, plus the vigil's own
			for i in gained + 1:
				var offers = main._roll_offers()
				if offers.is_empty():
					continue
				var choice = offers[randi() % offers.size()]
				if greedy:
					# stand in for a player who knows what they are doing:
					# always take the rarest thing on offer
					for o in offers:
						if int(o.get("tier", 1)) > int(choice.get("tier", 1)):
							choice = o
				main._swear_pact(choice)
				taken += 1

			if dps_at.has(v):
				var d := 0.0
				for bi in w.live_bolt_count():
					var bd = w.bolt_at(bi)
					var dmg: float = float(main.player.effective_damage(w)) * float(bd.get("damage_mult", 1.0))
					dmg *= 1.0 + main.player.crit_chance * (main.player.crit_mult - 1.0)
					dmg *= main.player.shot_damage_factor(w)
					d += dmg * main.player.effective_rate_of(w, bd) * float(main.player.effective_shots(w))
				dps_at[v] += d
				pacts_at[v] += float(taken)

		root.remove_child(main)
		main.free()

	print("vigil   pacts taken   player DPS   arena HP/sec   ratio")
	var probe = load("res://main.tscn").instantiate()
	root.add_child(probe)
	for v in [1, 5, 10, 15]:
		var d: float = dps_at[v] / 40.0
		var pk: float = pacts_at[v] / 40.0
		var pressure: float = _pressure(probe, v)
		print("%5d %13.1f %12.0f %14.0f %7.2f" % [v, pk, d, pressure, d / pressure])
	root.remove_child(probe)
	probe.free()
	print("  ratio >= 1.0 means the arena can be cleared on damage alone")


# Enemy health arriving per second at vigil v, from the live constants and the
# live spawn table -- so it cannot drift out of date when either is tuned.
# The number the "make it three shots" change is actually aimed at. Damage per
# second hides this completely: a character doing 29 a hit against a 13hp
# creature and one doing 13 a hit against the same creature have identical DPS
# on paper and completely different games in the hand.
func _hits_to_kill() -> void:
	print("
=== hits to kill, opening bolt, no pacts ===")
	print("vigil-1 trash should read 3. One means the shot is mostly wasted.")
	var ids := []
	for k in EnemyKinds.ALL:
		ids.append(String(k["id"]))
	var head := ""
	for id in ids:
		head += "%7s" % String(id).substr(0, 6)
	print("%-14s %-6s%s" % ["character", "vigil", head])
	for c in Characters.ALL:
		# A fresh one per character: apply_character APPENDS its weapon and adds
		# to damage_bonus, so reusing a player reports the first character's
		# numbers three times over. It did exactly that on the first run.
		var main = load("res://main.tscn").instantiate()
		root.add_child(main)
		main.player.apply_character(c)
		var w = main.player.weapons[0]
		var bolt: Dictionary = w.bolt_at(0)
		for v in [1, 5, 10, 15]:
			main.wave = v
			var per_hit: int = maxi(1, roundi(float(main.player.effective_damage(w))
				* float(bolt.get("damage_mult", 1.0))))
			var row := ""
			for id in ids:
				var k: Dictionary = EnemyKinds.by_id(id)
				var hp := float(k.get("hp_base", 8)) + float(k.get("hp_per_wave", 5)) * float(v)
				row += "%7d" % int(ceil(hp / float(per_hit)))
			print("%-14s %-6d%s   (%d dmg/hit)" % [
				String(c["name"]).replace("The ", ""), v, row, per_hit])
		root.remove_child(main)
		main.free()


func _short(ids: Array) -> Array:
	var out := []
	for id in ids:
		out.append("%6s" % String(id).substr(0, 6))
	return out


# What the arena throws at you, against what you can actually apply to it.
#
# The ratio this replaces compared arena health per second against raw DPS and
# silently ignored overkill -- which is the entire thing being fixed here. A
# character one-shotting 13hp creatures with 29 damage was scored at full DPS
# while throwing away 55% of it, so the old numbers said the game was harder
# than it played. Same class of mistake as reading the random-pick projection
# without the greedy one.
func _clear_rate() -> void:
	print("
=== how much damage overkill throws away ===")
	print("Raw DPS is what the character sheet says; applied is what reaches a")
	print("health bar. No pacts here, so read the vigil-1 row -- later vigils")
	print("are fought with thirty pacts and belong to the run projection.")
	print("%-14s %-6s %8s %8s %8s %8s" % [
		"character", "vigil", "raw dps", "wasted", "applied", "arena/s"])
	for c in Characters.ALL:
		var main = load("res://main.tscn").instantiate()
		root.add_child(main)
		main.player.apply_character(c)
		var w = main.player.weapons[0]
		var bolt: Dictionary = w.bolt_at(0)
		for v in [1, 5, 10, 15]:
			main.wave = v
			var per_hit: int = maxi(1, roundi(float(main.player.effective_damage(w))
				* float(bolt.get("damage_mult", 1.0))))
			var rate: float = main.player.effective_rate(w)
			var raw := float(per_hit) * rate

			# Average overkill across the spawn table for this vigil.
			var waste := 0.0
			var n := 400
			for i in n:
				var k: Dictionary = EnemyKinds.by_id(EnemyKinds.roll(v))
				var hp := float(k.get("hp_base", 8)) + float(k.get("hp_per_wave", 5)) * float(v)
				var hits: float = ceil(hp / float(per_hit))
				waste += (hits * float(per_hit) - hp) / (hits * float(per_hit))
			waste /= float(n)

			var applied := raw * (1.0 - waste)
			print("%-14s %-6d %8.1f %7.0f%% %8.1f %8.1f" % [
				String(c["name"]).replace("The ", ""), v, raw, waste * 100.0,
				applied, _pressure(main, v)])
		root.remove_child(main)
		main.free()


# Armour has to be worth the SAME at every value.
#
# Flat subtraction was not: it did nothing until it reached the incoming damage
# and then made you immune. The multiplier form trades a diminishing displayed
# percentage for a constant gain in how much damage you can actually absorb, and
# that constant is the thing worth checking -- if the last column drifts, the
# formula has gone wrong.
# MAX_FIRE_RATE must be a backstop, not a design element.
#
# While percentage stats compounded, stacking attack speed could reach four
# figures and the cap was the only thing standing between the game and a
# thousand shots a second. Additive stacking should make it unreachable by any
# legal build -- and "should" is not "does", so this swears every attack-speed
# pact to its stack limit and checks.
func _rail_check() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.player.apply_character(Characters.ALL[0])
	var w = main.player.weapons[0]
	var taken := 0
	for pact in Pacts.ALL:
		if String(pact.get("icon", "")) != "swift":
			continue
		for i in main.MAX_STACKS:
			main._swear_pact(pact)
			taken += 1
	var rate: float = main.player.effective_rate(w)
	var uncapped: float = float(w.data.get("rate", 1.0)) * (1.0 + main.player.rate_pct)
	print("
=== the attack-speed rail ===")
	print("every attack-speed pact at max stacks (%d pacts): +%.0f%% -> %.2f/s" % [
		taken, main.player.rate_pct * 100.0, uncapped])
	print("MAX_FIRE_RATE is %.1f/s -- %s" % [Player.MAX_FIRE_RATE,
		"still a backstop" if uncapped < Player.MAX_FIRE_RATE else "LOAD-BEARING, the cap is doing design work"])
	if uncapped >= Player.MAX_FIRE_RATE:
		print("  RAIL REACHED: attack speed can still run away")
	root.remove_child(main)
	main.free()


# A vigil kind has to change the FIELD, not just the banner.
#
# Both halves are worth checking because they are wired through different
# systems -- spawn rate through the timer in _tick_playing, health through the
# multiplier in _spawn_enemy -- and either could be silently disconnected while
# the notice still appeared.
func _vigil_kind_check() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.player.apply_character(Characters.ALL[0])
	print("
=== vigil kinds ===")
	print("special vigils: %s" % str(main.SPECIAL_VIGILS))
	print("%-8s %9s %10s %12s" % ["kind", "hp mult", "spawn mult", "spawned hp"])
	for kind in [0, 1, 2]:
		main.wave = 11
		main.vigil_kind = kind
		main.vigil_hp_mult = [1.0, 0.40, 2.60][kind]
		main.vigil_spawn_mult = [1.0, 3.0, 0.35][kind]
		# spawn one and read what actually came out
		main.enemies.clear()
		main._spawn_enemy()
		var hp: int = main.enemies[0].max_hp if not main.enemies.is_empty() else -1
		var base := maxf(main.SPAWN_FLOOR, main.SPAWN_INTERVAL - 11.0 * main.SPAWN_RAMP)
		var gap: float = base / (main.spawn_rate_mult * main.vigil_spawn_mult)
		print("%-8s %9.2f %10.2f %12d   (one every %.2fs)" % [
			["NORMAL", "HORDE", "ELITE"][kind], main.vigil_hp_mult,
			main.vigil_spawn_mult, hp, gap])
	root.remove_child(main)
	main.free()


func _armour_check() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.player.apply_character(Characters.ALL[0])
	print("
=== what a point of armour is worth ===")
	print("%6s %10s %12s %14s" % ["armour", "dmg taken", "effective hp", "EHP per point"])
	var base: float = main.player.effective_hp()
	for a in [0, 1, 5, 10, 20, 40]:
		main.player.armor = a
		var soak := 1.0 / (1.0 + float(a) / Player.ARMOR_SCALE)
		var ehp: float = main.player.effective_hp()
		var per: float = 0.0 if a == 0 else (ehp - base) / float(a) / base * 100.0
		print("%6d %9.1f%% %12.0f %13.2f%%" % [a, soak * 100.0, ehp, per])
	main.player.armor = 0
	root.remove_child(main)
	main.free()


func _pressure(main, v: int) -> float:
	var interval: float = maxf(main.SPAWN_FLOOR, main.SPAWN_INTERVAL - float(v) * main.SPAWN_RAMP)
	var hp := 0.0
	var n := 600
	for i in n:
		var k := EnemyKinds.by_id(EnemyKinds.roll(v))
		hp += float(k.get("hp_base", 8)) + float(k.get("hp_per_wave", 5)) * float(v)
	return (hp / float(n)) / interval
