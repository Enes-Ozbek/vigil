class_name Pacts

# Pact DATA only. The effects live in main.gd (_apply_boon) so
# that data and logic stay separated and neither file depends on the other.
#
# Boons are IMMEDIATE and FLAT: +6 damage, right now, for the rest of the run.
#
# NOTE: pacts used to carry a matching bane, so that every upgrade was a
# bargain. That was removed by design decision -- see PLAN.md section 9. All
# difficulty now comes from enemy scaling alone, which means the per-vigil
# enemy curve in enemy_kinds.gd is the ONLY thing holding a run back.
#
# "tier" is how rare and how strong: 1 Common, 2 Grim, 3 Damned. Offers are
# rolled by tier with better tiers becoming likelier as a run goes on, so a
# late pact screen feels different from an early one. See BALANCE.md section 6.
#
# "corruption" is a HOOK for Milestone 3. Nothing reads it yet.
#
# "icon" names a symbol in card_face.gd, and is chosen by the STAT the pact
# moves rather than by the pact. All four damage pacts show the same broken
# blade; all three attack-speed pacts show the same chevrons. That is the whole
# point of having them: a player learns roughly a dozen marks and can then read
# any pact screen at a glance, instead of learning thirty-five pictures.

const ALL := [
	{
		"id": "blood_price",
		"icon": "blade",
		"name": "Blood Price",
		"boon": "+6 damage",
		"corruption": 2,
		"tier": 1,
	},
	{
		"id": "fevered_hands",
		"icon": "swift",
		"name": "Fevered Hands",
		"boon": "+30% attack speed",
		"corruption": 1,
		"tier": 2,
	},
	{
		"id": "fleet_dread",
		"icon": "boot",
		"name": "Fleet Dread",
		"boon": "+18% move speed",
		"corruption": 2,
		"tier": 2,
	},
	{
		"id": "grave_vigour",
		"icon": "heart",
		"name": "Grave Vigour",
		"boon": "+30 max health, heal 30",
		"corruption": 1,
		"tier": 1,
	},
	{
		"id": "long_stare",
		"icon": "eye",
		"name": "The Long Stare",
		"boon": "+70 reach",
		"corruption": 1,
		"tier": 1,
	},
	{
		"id": "gluttony",
		"icon": "leech",
		"name": "Gluttony",
		"boon": "heal 4 for every kill",
		"corruption": 3,
		"tier": 2,
	},
	{
		"id": "swift_judgment",
		"icon": "dart",
		"name": "Swift Judgment",
		"boon": "+140 projectile speed, +2 damage",
		"corruption": 1,
		"tier": 1,
	},
	{
		"id": "iron_bargain",
		"icon": "heart",
		"name": "Iron Bargain",
		"boon": "+45 max health",
		"corruption": 1,
		"tier": 1,
	},
	{
		"id": "hungering_dark",
		"icon": "blade",
		"name": "The Hungering Dark",
		"boon": "+25% damage",
		"corruption": 3,
		"tier": 3,
	},
	{
		"id": "ashen_skin",
		"icon": "shield",
		"name": "Ashen Skin",
		"boon": "take 25% less damage",
		"corruption": 1,
		"tier": 2,
	},
	{
		"id": "widows_gift",
		"icon": "blade",
		"name": "Widow's Gift",
		"boon": "+12 damage",
		"corruption": 3,
		"tier": 3,
	},
	{
		"id": "candleflame",
		"icon": "heart",
		"name": "Candleflame",
		"boon": "heal to full",
		"corruption": 2,
		"tier": 1,
	},
	{
		"id": "thousand_cuts",
		"icon": "swift",
		"name": "A Thousand Cuts",
		"boon": "+60% attack speed",
		"corruption": 2,
		"tier": 3,
	},
	{
		"id": "watchers_eye",
		"icon": "eye",
		"name": "The Watcher's Eye",
		"boon": "+90 reach, +10% projectile speed",
		"corruption": 2,
		"tier": 2,
	},
	{
		"id": "whetstone",
		"icon": "blade",
		"name": "The Whetstone",
		"boon": "+18% damage",
		"corruption": 1,
		"tier": 2,
	},
	{
		"id": "grave_plate",
		"icon": "shield",
		"name": "Grave Plate",
		"boon": "+3 armour against every blow",
		"corruption": 1,
		"tier": 1,
	},
	{
		"id": "swollen_heart",
		"icon": "heart",
		"name": "Swollen Heart",
		"boon": "+25% max health",
		"corruption": 1,
		"tier": 2,
	},
	{
		"id": "rotwort",
		"icon": "sprig",
		"name": "Rotwort",
		"boon": "regenerate 1.5 health a second",
		"corruption": 2,
		"tier": 1,
	},
	{
		"id": "empty_psalter",
		"icon": "swift",
		"name": "The Empty Psalter",
		"boon": "+35% attack speed",
		"corruption": 2,
		"tier": 2,
	},
	{
		"id": "wide_censer",
		"icon": "rings",
		"name": "The Wide Censer",
		"boon": "+30% area: melee arcs and projectiles",
		"corruption": 2,
		"tier": 2,
	},
	{
		"id": "dried_sinew",
		"icon": "dart",
		"name": "Dried Sinew",
		"boon": "+40% projectile speed",
		"corruption": 1,
		"tier": 1,
	},
	{
		"id": "lingering_word",
		"icon": "tail",
		"name": "The Lingering Word",
		"boon": "+50% projectile lifetime",
		"corruption": 1,
		"tier": 1,
	},
	{
		"id": "split_tongue",
		"icon": "split",
		"name": "Split Tongue",
		"boon": "+1 projectile on every shot",
		"corruption": 3,
		"tier": 3,
	},
	{
		"id": "carrion_wings",
		"icon": "boot",
		"name": "Carrion Wings",
		"boon": "+22% move speed",
		"corruption": 2,
		"tier": 2,
	},
	{
		"id": "lodestone",
		"icon": "magnet",
		"name": "The Lodestone",
		"boon": "+60% reach on soul motes",
		"corruption": 1,
		"tier": 1,
	},
	{
		"id": "grave_wisdom",
		"icon": "mote",
		"name": "Grave Wisdom",
		"boon": "+30% from every soul mote",
		"corruption": 2,
		"tier": 2,
	},
	{
		"id": "second_breath",
		"icon": "urn",
		"name": "Second Breath",
		"boon": "rise once, when you fall",
		"corruption": 3,
		"tier": 3,
	},
	{"id": "sure_cut",
		"icon": "fang", "name": "The Sure Cut", "boon": "+12% chance to strike true", "corruption": 1, "tier": 2},
	{"id": "executioners_eye",
		"icon": "fang", "name": "Executioner's Eye", "boon": "+60% damage when you strike true", "corruption": 2, "tier": 2},
	{"id": "smoke_and_ash",
		"icon": "veil", "name": "Smoke and Ash", "boon": "+9% of blows miss you entirely", "corruption": 2, "tier": 2},
	{"id": "long_shadow",
		"icon": "veil", "name": "The Long Shadow", "boon": "+5% of blows miss you entirely", "corruption": 1, "tier": 1},
	{"id": "boneshear",
		"icon": "pierce", "name": "Boneshear", "boon": "every projectile pierces one more", "corruption": 3, "tier": 3},
	{"id": "ricochet_psalm",
		"icon": "ricochet", "name": "The Ricochet Psalm", "boon": "every projectile leaps to one more", "corruption": 3, "tier": 3},
	{"id": "black_fortune",
		"icon": "coin", "name": "Black Fortune", "boon": "the dark offers you better bargains", "corruption": 2, "tier": 2},
	{"id": "iron_wind",
		"icon": "impact", "name": "The Iron Wind", "boon": "your blows shove them back", "corruption": 1, "tier": 1},
]


static func by_id(id: String) -> Dictionary:
	for p in ALL:
		if p["id"] == id:
			return p
	return {}


static func name_of(id: String) -> String:
	return by_id(id).get("name", id)


const TIER_NAMES := ["", "Common", "Grim", "Damned"]

# HOW RARE EACH TIER IS, AND WHEN IT BECOMES POSSIBLE AT ALL.
#
# Brotato's structure, which is better than the weighted blend this replaced:
# each tier has a MINIMUM VIGIL below which it simply cannot appear, then a
# linear ramp, then a hard cap. Luck multiplies the result but can never beat
# the cap. Tiers are rolled highest-first and independently -- this is not a
# distribution that sums to 100.
#
# The gate is the point. Rolling Damned at 1% from vigil 1 means the first one
# arrives at a random moment and means nothing; making it impossible until
# vigil 8 gives the run a shape, and gives the player something to reach.
#
# Damned per card works out at 0% before vigil 8 and ~7% at vigil 15, which is
# about one screen in four. tools/balance_sim.gd prints BOTH the per-card and
# the per-screen figure, because reading only the per-card one is how this was
# mistuned twice.
const TIERS := [
	{},                                                     # 0 unused
	{"min": 1, "base": 100.0, "per": 0.0, "max": 100.0},    # Common
	{"min": 2, "base": 0.0,   "per": 4.5, "max": 45.0},     # Grim
	# base is 1.0 rather than 0.0 so the tier actually becomes possible ON its
	# minimum vigil. With base 0 the ramp is zero at min and the first real
	# chance is a vigil later, which makes the table quietly disagree with the
	# behaviour -- exactly the kind of off-by-one that survives for months.
	{"min": 8, "base": 1.0,   "per": 1.0, "max": 12.0},     # Damned
]

# Luck 4 doubles a tier's chance -- and still cannot pass its cap.
const LUCK_SCALE := 0.25


# The chance, in percent, that one card rolls at least this tier.
static func tier_chance(tier: int, vigil: int, luck: float) -> float:
	var spec: Dictionary = TIERS[tier]
	if vigil < int(spec["min"]):
		return 0.0
	var ramp := float(spec["per"]) * float(vigil - int(spec["min"])) + float(spec["base"])
	return minf(ramp * (1.0 + maxf(luck, 0.0) * LUCK_SCALE), float(spec["max"]))


# Roll one card's tier, best first. Each tier is an independent check, so a
# failed Damned roll falls through to Grim rather than redistributing weight.
static func roll_tier(vigil: int, luck: float) -> int:
	for tier in [3, 2]:
		if randf() * 100.0 < tier_chance(tier, vigil, luck):
			return tier
	return 1


static func of_tier(tier: int) -> Array:
	var out := []
	for p in ALL:
		if int(p.get("tier", 1)) == tier:
			out.append(p)
	return out
