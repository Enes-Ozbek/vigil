class_name ChestCards

# What a Cursed Chest offers. Three cards, take one.
#
# ============================================================================
# PLACEHOLDER CONTENT. Every card below is invented to make the system real and
# testable, and is meant to be thrown away. Replacing them is a data edit:
# change the entries here and their matching arm in main.gd _take_card(). The
# chest, the spawn, the screen and the pick all work regardless of what is in
# this list.
# ============================================================================
#
# Same shape as pacts.gd -- id / name / boon / tier -- plus an "icon", which
# names one of the woodcut symbols in card_face.gd. Hover and keyboard
# selection work on these exactly as they do on pacts, because the screen does
# not know or care which pool a card came from.
#
# These are deliberately STRONGER than a pact of the same tier. A pact is the
# reward for surviving twenty seconds; one of these is the reward for killing
# the thing that arrived with its own health bar. If a chest card ever feels
# like a pact you found in a box, the chest has failed.
#
# All tier 3, because rarity is not the axis here -- the chest is already rare.
# The tier only drives the card's colour, and orange is what a boss drop should
# look like.

const ALL := [
	{
		"id": "cc_gilded_ruin",
		"icon": "blade",
		"name": "Gilded Ruin",
		"boon": "+28 damage",
		"tier": 3,
	},
	{
		"id": "cc_split_coin",
		"icon": "split",
		"name": "The Split Coin",
		"boon": "+1 projectile on every shot",
		"tier": 3,
	},
	{
		"id": "cc_kingsblood",
		"icon": "crown",
		"name": "Kingsblood",
		"boon": "+55 max health, and be made whole",
		"tier": 3,
	},
	{
		"id": "cc_hoarders_eye",
		"icon": "eye",
		"name": "The Hoarder's Eye",
		"boon": "+2 soul motes from every kill",
		"tier": 3,
	},
	{
		"id": "cc_unquiet_blade",
		"icon": "swift",
		"name": "The Unquiet Blade",
		"boon": "+35% attack speed",
		"tier": 3,
	},
	{
		"id": "cc_sepulchre_iron",
		"icon": "shield",
		"name": "Sepulchre Iron",
		"boon": "+5 armour, and take 10% less",
		"tier": 3,
	},
	{
		"id": "cc_long_count",
		"icon": "pierce",
		"name": "The Long Count",
		"boon": "every bolt pierces one more, and leaps one further",
		"tier": 3,
	},
	{
		"id": "cc_dead_kings_favour",
		"icon": "coin",
		"name": "The Dead King's Favour",
		"boon": "+2 luck, and the dark pays better",
		"tier": 3,
	},
	{
		"id": "cc_reliquary",
		"icon": "urn",
		"name": "The Reliquary",
		"boon": "rise once more, when you fall",
		"tier": 3,
	},
	{
		"id": "cc_wolfs_hour",
		"icon": "fang",
		"name": "The Wolf's Hour",
		"boon": "+20% crit chance, +40% crit damage",
		"tier": 3,
	},
]


# Three distinct cards. Fewer than three only if the pool itself is smaller,
# which it never is -- but the caller must not assume, because the day someone
# trims this list to two is the day an assumption becomes a crash.
static func roll(count: int) -> Array:
	var pool := ALL.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


static func by_id(id: String) -> Dictionary:
	for c in ALL:
		if c["id"] == id:
			return c
	return {}


static func name_of(id: String) -> String:
	for c in ALL:
		if c["id"] == id:
			return String(c["name"])
	return id
