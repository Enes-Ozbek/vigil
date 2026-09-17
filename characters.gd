class_name Characters

# Playable characters. Data only, same split as pacts.gd.
#
# A character is a stat slant, a look, and ONE weapon that belongs to them
# alone. There is no shared weapon pool and nothing is picked up mid-run: the
# Cane is the Necromancer's, the Blade is the Vessel's, and neither will ever
# hold the other's.
#
# A weapon carries a list of "bolts" -- its distinct attacks. Only the first is
# available when a run starts; each vigil survived frees one more, and every
# bolt runs on its OWN cooldown, so they never wait for each other or fire in
# lockstep. This works for melee swings exactly as it does for projectiles.
#
# "anims" maps a state name to [texture_path, row, frame_count, fps]. Leave it
# empty and the character falls back to a drawn silhouette, still fully
# playable. Adding art later is one entry here and nothing else.

const NECRO := "res://assets/necromancer.png"
# Starting move speed came down 15% across the board. It was fast enough that
# the opening vigils played themselves -- you could outrun everything without
# deciding anything. The move-speed pacts and the Poacher's Light Feet are now
# how you buy that back, which is what they were always for.
const KEEPER := "res://assets/keeper/"

const ALL := [
	{
		"id": "necromancer",
		"name": "The Necromancer",
		"blurb": "traded warmth for reach",
		"note": "slow bolts that bore through crowds",
		"max_hp": 85,
		"speed": 175.0,
		"damage_bonus": 3,
		"frame": Vector2i(160, 128),
		"pivot": Vector2(80.0, 110.0),
		"scale": 0.9,
		"art_holds_weapon": true,
		# Where the staff's flame sits, measured from the sprite. Bolts leave
		# from here, and aim is computed from here.
		"body_offset": Vector2(9.0, -25.0),
		"weapon": {
			"name": "The Ashen Cane",
			"kind": "shot",
			"glyph": "cane",
			"damage": 26,
			"rate": 0.75,
			"range": 300.0,
			"shots": 1,
			"bolts": [
				{
					"name": "Cinder",
					"sfx": "shoot_cinder",
					"sprite": "res://assets/necro_flame.png",
					"align": true,        # a flame points where it is going
					"damage_mult": 1.0,
					"rate_mult": 1.0,
					# A flame does not bore a hole through anything -- it stops
					# where it lands and catches what is standing next to it.
					# "no_pierce" makes that true even for a player who has
					# stacked pierce; the Bound Skull is the bolt that scales
					# with those pacts, and the two should not want the same
					# things. splash_mult is what a caught bystander takes.
					"pierce": 0,
					"no_pierce": true,
					"splash": 30.0,
					"splash_mult": 0.55,
					# Matched by measurement to the flame burning on the staff in
					# the character's own sprite: that art is ~28px across a
					# 160x128 cell drawn at scale 0.9, which is 25 world units,
					# so a radius of 12. Anything smaller reads as the cane
					# spitting sparks rather than throwing its fire.
					"size": 12.0,
					"size_mult": 1.0,
				},
				{
					"name": "Bound Skull",
					"sfx": "shoot_skull",
					# It leaps to whatever is nearest once it lands, so sending
					# it at the nearest thing wastes the bounce on ground the
					# Cinder already covers. Scatter it and the two bolts work
					# opposite sides of the crowd.
					"target": "random3",
					"sprite": "res://assets/necro_skull.png",
					"align": false,       # a skull tumbles
					"damage_mult": 1.35,
					"rate_mult": 0.55,
					"pierce": 0,          # it does not bore through anything
					"bounces": 1,         # it leaps to one more enemy instead
					"size_mult": 1.0,
				},
			],
		},
		"anims": {
			"idle": [NECRO, 0, 8, 8.0],
			"walk": [NECRO, 1, 8, 12.0],
			"cast": [NECRO, 2, 13, 18.0],
			"hurt": [NECRO, 5, 5, 14.0],
			"death": [NECRO, 6, 9, 10.0],
		},
	},
	{
		"id": "vessel",
		"name": "The Vessel",
		"blurb": "something else wears this body",
		"note": "cuts sideways; line them up",
		"max_hp": 140,
		"speed": 162.0,
		"damage_bonus": 0,
		# Moonstone Keeper. tools/build_keeper_strips.py assembles the pack's
		# per-frame PNGs onto a uniform 200x150 grid; pivot measured from the
		# assembled strip -- gem at x=100, feet on y=110.
		"frame": Vector2i(200, 150),
		"pivot": Vector2(100.0, 111.0),
		"scale": 0.6,
		"art_holds_weapon": true,
		"body_offset": Vector2(4.0, -22.0),
		"weapon": {
			"name": "The Moonstone Blade",
			"kind": "melee",
			"glyph": "blade",
			"damage": 9,
			"rate": 2.2,
			"range": 78.0,
			# The swing is a flat horizontal cut, so damage is a horizontal BOX
			# and not a circle: range is its length to one side, melee_height
			# its half-height.
			"melee_height": 26.0,
			"shots": 1,
			"bolts": [
				{
					"name": "Cut",
					"damage_mult": 1.0,
					"rate_mult": 1.0,
					"reach_mult": 1.0,
					"height_mult": 1.0,
				},
				{
					"name": "Moonfall",
					"damage_mult": 2.4,
					"rate_mult": 0.35,    # a slow, heavy sweep
					"reach_mult": 1.7,
					"height_mult": 1.6,
				},
				{
					"name": "Sever",
					"sfx": "shoot_arrow",
					# The Vessel can only cut sideways. This is the answer to
					# everything standing above or below him -- a thrown blade
					# that goes wherever it needs to.
					"kind": "shot",
					"sprite": "res://assets/sword.png",
					"frame": Vector2i(64, 64),
					"frames": 12,
					"fps": 14.0,
					"align": true,
					"art_forward": PI / 4.0,  # the art points down-right, not up
					"speed": 430.0,
					"range_mult": 4.0,
					"damage_mult": 1.7,
					"rate_mult": 0.42,
					"pierce": 1,
					"size_mult": 1.6,
				},
			],
		},
		"anims": {
			"idle": [KEEPER + "idle.png", 0, 17, 10.0],
			"walk": [KEEPER + "walk.png", 0, 12, 14.0],
			"cast": [KEEPER + "attack.png", 0, 11, 20.0],
			"hurt": [KEEPER + "hurt.png", 0, 3, 12.0],
			"death": [KEEPER + "death.png", 0, 19, 12.0],
		},
	},
	{
		"id": "poacher",
		"name": "The Poacher",
		"blurb": "knows every way out of the wood",
		"note": "fast and fragile; kills at distance",
		"max_hp": 75,
		"speed": 212.0,
		"damage_bonus": 0,
		"frame": Vector2i(64, 64),
		"pivot": Vector2(32.0, 32.0),
		"scale": 1.0,
		"weapon": {
			"name": "The Wailing Bow",
			"kind": "shot",
			"glyph": "bow",
			"damage": 22,
			"rate": 1.1,
			"range": 420.0,
			"shots": 1,
			"bolts": [
				{"name": "Bone Arrow", "damage_mult": 1.0, "rate_mult": 1.0, "pierce": 1,
					"sfx": "shoot_arrow"},
				# Pierces three, so it wants the LONGEST line through the
				# crowd rather than the closest body -- aiming it at your feet
				# throws away two of the three hits it paid for.
				{"name": "Spite", "damage_mult": 1.45, "rate_mult": 0.6, "pierce": 3,
					"target": "farthest", "sfx": "shoot_arrow"},
			],
		},
		"anims": {},          # no art yet -- drawn as a silhouette
	},
]


static func by_id(id: String) -> Dictionary:
	for c in ALL:
		if c["id"] == id:
			return c
	return {}
