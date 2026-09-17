class_name Upgrades

# Permanent per-character upgrades, bought with gold in the Chapel. META.md.
#
# Every node here is one a character can actually USE -- the trees in META.md
# section 5 also listed nodes needing systems that do not exist yet (burning
# ground, raising the dead, invulnerability windows). Those are deferred rather
# than shipped as buttons that do nothing. A tree of eight working nodes is a
# feature; a tree of nine where one lies is not.
#
# Prices come from the tier: Common 150, Grim 550, Damned 1300.

# Chests roughly doubled what a run pays, so prices moved with them -- a full
# tree is still about two and a half full clears.
const PRICE := {1: 150, 2: 550, 3: 1300}

const ALL := {
	"necromancer": [
		{"id": "ashen_grip", "name": "Ashen Grip", "desc": "+5% damage", "tier": 1},
		{"id": "long_practice", "name": "Long Practice", "desc": "+25 reach", "tier": 1},
		{"id": "second_hand", "name": "Second Hand", "desc": "begin holding the Bound Skull", "tier": 1},
		{"id": "heavier_bone", "name": "Heavier Bone", "desc": "every bolt leaps to one more", "tier": 2},
		{"id": "patient_dead", "name": "Patient Dead", "desc": "+1 soul mote from every kill", "tier": 2},
		{"id": "fevered_litany", "name": "Fevered Litany", "desc": "+12% attack speed", "tier": 2},
		{"id": "bore", "name": "Bore", "desc": "every bolt pierces one more", "tier": 3},
		{"id": "widening_dark", "name": "The Widening Dark", "desc": "+25% area", "tier": 3},
	],
	"vessel": [
		{"id": "set_stance", "name": "Set Stance", "desc": "+12 max health", "tier": 1},
		{"id": "kept_edge", "name": "Kept Edge", "desc": "begin with Moonfall unsheathed", "tier": 1},
		{"id": "iron_grip", "name": "Iron Grip", "desc": "+5% damage", "tier": 1},
		{"id": "ironhide", "name": "Ironhide", "desc": "+2 armour", "tier": 2},
		{"id": "reaping", "name": "Reaping", "desc": "heal 2 for every kill", "tier": 2},
		{"id": "follow_through", "name": "Follow Through", "desc": "your blows shove them back", "tier": 2},
		{"id": "wider_cut", "name": "The Wider Cut", "desc": "+30% area", "tier": 3},
		{"id": "unbroken", "name": "Unbroken", "desc": "rise once, when you fall", "tier": 3},
	],
	"poacher": [
		{"id": "steady_hand", "name": "Steady Hand", "desc": "+5% damage", "tier": 1},
		{"id": "light_feet", "name": "Light Feet", "desc": "+6% move speed", "tier": 1},
		{"id": "second_quiver", "name": "Second Quiver", "desc": "begin with Spite nocked", "tier": 1},
		{"id": "keen_eye", "name": "Keen Eye", "desc": "+9% chance to strike true", "tier": 2},
		{"id": "smoke_step", "name": "Smoke Step", "desc": "+6% of blows miss you", "tier": 2},
		{"id": "long_shot", "name": "Long Shot", "desc": "+45 reach", "tier": 2},
		{"id": "split_arrow", "name": "Split Arrow", "desc": "+1 arrow on every shot", "tier": 3},
		{"id": "vanishing", "name": "Vanishing", "desc": "+12% of blows miss you", "tier": 3},
	],
}


static func for_character(char_id: String) -> Array:
	return ALL.get(char_id, [])


static func price(node: Dictionary) -> int:
	return int(PRICE.get(int(node.get("tier", 1)), 100))


static func tree_cost(char_id: String) -> int:
	var total := 0
	for n in for_character(char_id):
		total += price(n)
	return total
