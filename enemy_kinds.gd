class_name EnemyKinds

# Enemy archetypes -- Milestone 2. One enemy type meant one answer to every
# vigil; these five each demand something different from you.
#
#   Nightwing    swarm   weak, endless, comes from everywhere
#   Catto        rusher  fast and fragile, punishes standing still
#   Rotmaw       charger heavy and fast; you cannot simply walk away from it
#   Mage         ranged  stops at a distance and throws; you have to go to it
#   Abomination  tank    slow, enormous, soaks a whole build
#   NightBorne   elite   rare, fast, hits like a truck
#
# Base stats are "at vigil 1"; per_wave is added once per vigil, the same
# linear shape Brotato uses. Enemy.setup() is still the only place scaling
# happens.
#
# "motes" is XP and always drops. "gold_chance"/"gold" is money and drops on a
# roll -- a coin should be a moment, not a trickle. The elite is the only
# certainty, which is what makes it worth hunting. See META.md section 2.
#
# Art: the Horror Enemy Pack sheets are already one animation per ROW, so they
# are referenced directly -- no assembly step. Rows and frame counts are from
# the pack's own ReadMe and were verified against the sheets.

const BAT := "res://assets/bat/"
const FOES := "res://assets/foes/"
const DK := "res://assets/foes/dreadknight/"
const SKEL := "res://assets/foes/skeleton/"

const ALL := [
	{
		"id": "bat",
		"name": "Nightwing",
		"role": "swarm",
		"radius": 10.0,
		"hp_base": 60, "hp_per_wave": 11,
		"speed_base": 50.0, "speed_per_wave": 4.0,
		"damage_base": 4, "damage_per_wave": 1,
		"motes": 3,
		"gold_chance": 0.36, "gold": 1,
		"frame": Vector2i(64, 64),
		"pivot": Vector2(32.0, 34.0),
		"scale": 0.95,
		"anims": {
			"run": [BAT + "Bat-Run.png", 0, 8, 14.0],
			"hurt": [BAT + "Bat-Hurt.png", 0, 5, 16.0],
			"death": [BAT + "Bat-Die.png", 0, 12, 14.0],
		},
	},
	{
		"id": "catto",
		"name": "Catto",
		"role": "rusher",
		"radius": 9.0,
		"hp_base": 47, "hp_per_wave": 9,
		"speed_base": 105.0, "speed_per_wave": 6.0,
		"damage_base": 5, "damage_per_wave": 1,
		"motes": 3,
		"gold_chance": 0.42, "gold": 1,
		"frame": Vector2i(48, 32),
		"pivot": Vector2(23.0, 32.0),
		"scale": 1.05,
		"anims": {
			"run": [FOES + "catto.png", 2, 4, 10.0],
			"attack": [FOES + "catto.png", 6, 6, 12.0],
			"hurt": [FOES + "catto.png", 7, 2, 10.0],
			"death": [FOES + "catto.png", 8, 9, 12.0],
		},
	},
	{
		"id": "mage",
		"name": "The Hollow Mage",
		"role": "ranged",
		"radius": 9.0,
		"hp_base": 75, "hp_per_wave": 13,
		"speed_base": 42.0, "speed_per_wave": 2.0,
		"damage_base": 6, "damage_per_wave": 2,
		"motes": 9,
		"gold_chance": 0.75, "gold": 2,
		# Stops at standoff range and throws instead of closing. The one enemy
		# you cannot solve by walking away from it.
		"ranged": {
			"standoff": 250.0,
			"rate": 0.55,
			"bolt_speed": 210.0,
			"bolt_size": 6.0,
			"windup": 0.45,
		},
		"frame": Vector2i(112, 48),
		"pivot": Vector2(55.0, 48.0),
		"scale": 1.15,
		"anims": {
			"run": [FOES + "mage.png", 1, 4, 9.0],
			"attack": [FOES + "mage.png", 2, 10, 14.0],
			"hurt": [FOES + "mage.png", 3, 2, 10.0],
			"death": [FOES + "mage.png", 4, 9, 12.0],
		},
	},
	{
		"id": "abomination",
		"name": "Abomination",
		"role": "tank",
		"radius": 22.0,
		"hp_base": 200, "hp_per_wave": 36,
		"speed_base": 30.0, "speed_per_wave": 2.0,
		"damage_base": 11, "damage_per_wave": 2,
		"motes": 15,
		"gold_chance": 1.00, "gold": 7,
		"frame": Vector2i(112, 48),
		"pivot": Vector2(25.0, 48.0),
		"scale": 1.05,
		"anims": {
			"run": [FOES + "abomination.png", 1, 4, 7.0],
			"attack": [FOES + "abomination.png", 2, 10, 12.0],
			"hurt": [FOES + "abomination.png", 3, 2, 10.0],
			"death": [FOES + "abomination.png", 4, 9, 11.0],
		},
	},
	{
		"id": "dreadknight",
		"name": "Rotmaw",
		"role": "charger",
		"radius": 15.0,
		"hp_base": 114, "hp_per_wave": 21,
		# Fast. Not quite as fast as you, so running is a delay rather than an
		# escape -- which is the whole point of a charger.
		"speed_base": 120.0, "speed_per_wave": 7.0,
		"damage_base": 8, "damage_per_wave": 2,
		"motes": 9,
		"gold_chance": 0.90, "gold": 3,
		"frame": Vector2i(80, 96),
		"pivot": Vector2(36.0, 80.0),
		"scale": 0.90,
		"anims": {
			"run": [DK + "run.png", 0, 17, 16.0],
			"attack": [DK + "attack.png", 0, 14, 15.0],
			"death": [DK + "death.png", 0, 10, 13.0],
		},
	},
	{
		"id": "skeleton_knight",
		"name": "The Skeleton Knight",
		"role": "boss",
		"boss": true,
		"radius": 20.0,
		"hp_base": 600, "hp_per_wave": 90,
		"speed_base": 70.0, "speed_per_wave": 4.0,
		"damage_base": 25, "damage_per_wave": 4,
		"motes": 40,
		"gold_chance": 1.00, "gold": 60,
		# A telegraphed swing rather than damage-on-touch: it plants itself,
		# winds up, and only then cuts. Rooted while winding up, so stepping
		# out of the arc is always possible -- a boss you cannot read is just
		# a large enemy that kills you.
		"melee_attack": {
			"reach": 74.0,
			"rate": 0.55,
			"windup": 0.55,
			"damage_mult": 1.0,
		},
		"frame": Vector2i(170, 125),
		"pivot": Vector2(52.0, 82.0),
		"scale": 1.40,
		"anims": {
			"run": [SKEL + "walk.png", 0, 9, 11.0],
			"attack": [SKEL + "side_swing.png", 0, 7, 11.0],
			"hurt": [SKEL + "hurt.png", 0, 2, 10.0],
			"death": [SKEL + "death.png", 0, 9, 10.0],
		},
	},
	{
		"id": "nightborne",
		"name": "NightBorne",
		"role": "elite",
		"radius": 17.0,
		"hp_base": 280, "hp_per_wave": 52,
		"speed_base": 88.0, "speed_per_wave": 5.0,
		"damage_base": 15, "damage_per_wave": 3,
		"motes": 30,
		"gold_chance": 1.00, "gold": 27,
		"frame": Vector2i(80, 80),
		"pivot": Vector2(36.0, 64.0),
		"scale": 1.05,
		"anims": {
			"run": [FOES + "nightborne.png", 1, 6, 12.0],
			"attack": [FOES + "nightborne.png", 2, 12, 16.0],
			"hurt": [FOES + "nightborne.png", 3, 5, 14.0],
			"death": [FOES + "nightborne.png", 4, 23, 18.0],
		},
	},
]

# Who shows up when. "from" is the first vigil an archetype can appear; weights
# are relative within whatever is eligible. Introducing them one at a time
# means each new threat gets a vigil where it is the thing you notice.
#
# "ramp" is how many vigils a newcomer takes to reach full weight. Without it,
# a heavy archetype arriving at full strength steps the average enemy health up
# all at once -- which made vigil 10 the hardest point of a run, harder than
# vigil 15. Difficulty should climb, not spike and subside. Measured with
# tools/balance_sim.gd.
# HEALTH WAS REBASED, not multiplied. The complaint was that early enemies died
# in one shot, and the cause was the BASE rather than the curve: a vigil-1
# Nightwing had 13hp against a 29 damage Cinder, so 55% of every shot was thrown
# away, while a vigil-12 one already took the three hits it should. So the bases
# rose ~5x, and the SLOPES were then tuned against the player's actual output.
#
# The slopes have moved twice. They were doubled while the player's percentage
# stats still COMPOUNDED, and had to come back down by nearly half once those
# were made additive (BALANCE.md section 14) -- because removing compounding took
# roughly a third off late-run player damage, and the arena had been sized
# against the inflated figure. The lesson is that an enemy curve is meaningless
# on its own: it is only ever correct relative to a specific player-power curve,
# and changing one silently invalidates the other. Each archetype keeps its old health RATIO
# against the Nightwing at the same vigil, so the roster's internal balance is
# untouched. Spawn rate came down to match -- see SPAWN_INTERVAL in main.gd;
# the two numbers only make sense together.
const SPAWNS := [
	{"id": "bat", "from": 1, "weight": 10, "ramp": 1},
	{"id": "catto", "from": 3, "weight": 9, "ramp": 2},
	{"id": "mage", "from": 5, "weight": 4, "ramp": 3},
	{"id": "dreadknight", "from": 5, "weight": 5, "ramp": 3},
	{"id": "abomination", "from": 6, "weight": 3, "ramp": 5},
	{"id": "nightborne", "from": 9, "weight": 1, "ramp": 5},
]


static func weight_at(s: Dictionary, wave: int) -> float:
	var from := int(s["from"])
	if wave < from:
		return 0.0
	var ramp := maxi(1, int(s.get("ramp", 1)))
	var t := clampf(float(wave - from + 1) / float(ramp), 0.0, 1.0)
	return float(s["weight"]) * t


# Which vigil summons which boss. Bosses are NOT in SPAWNS -- they arrive once,
# announced, at the start of their vigil, on top of the normal wave.
const BOSSES := {
	5: "skeleton_knight",
}


static func boss_for(wave: int) -> String:
	return String(BOSSES.get(wave, ""))


static func by_id(id: String) -> Dictionary:
	for e in ALL:
		if e["id"] == id:
			return e
	return {}


static func roll(wave: int) -> String:
	var total := 0.0
	for s in SPAWNS:
		total += weight_at(s, wave)
	if total <= 0.0:
		return "bat"
	var pick := randf() * total
	for s in SPAWNS:
		pick -= weight_at(s, wave)
		if pick <= 0.0:
			return String(s["id"])
	return "bat"
