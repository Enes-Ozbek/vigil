class_name Palette

# Three values, on purpose. See PLAN.md section 6.
#
#   VOID  - near-black. The background, and the body of everything hostile.
#   ASH   - desaturated mid-tone. The player, UI chrome, anything neutral.
#   BLOOD - the only hot colour in the game. Reserved for danger and pacts.
#
# BONE is not a fourth hue, it is ASH at a high value, used for text and for
# the player. If you ever want to add a colour, delete one first.

const VOID := Color(0.043, 0.043, 0.055)
const VOID_LIT := Color(0.085, 0.080, 0.098)

const ASH := Color(0.42, 0.43, 0.47)
const ASH_DIM := Color(0.20, 0.21, 0.24)
const BONE := Color(0.86, 0.84, 0.79)
const BONE_DIM := Color(0.55, 0.54, 0.51)

const BLOOD := Color(0.62, 0.11, 0.14)
const BLOOD_BRIGHT := Color(0.87, 0.24, 0.22)

# --- soul motes -------------------------------------------------------------
# A deliberate exception to the three-hue rule. Everything else on screen is
# void, ash or blood, which means a pickup drawn in any of them could be read
# as danger for the split second that matters. Green-gold belongs to nothing
# else in the game, so a mote can only ever mean "take this".
const XP_GLOW := Color(0.32, 0.86, 0.30)
const XP_MID := Color(0.80, 0.95, 0.28)
const XP_CORE := Color(1.00, 1.00, 0.82)

# --- pact rarity ------------------------------------------------------------
# Loot-rarity colours, and the second deliberate exception to the three-hue
# rule. They have to be unmistakable at a glance and unmistakable from EACH
# OTHER, which ash-grey and bone-white were not, and Damned must not be the
# same red as "something is hurting you".
#
# Grey-white -> green -> orange is the convention every player already knows.
const TIER_COMMON := Color(0.78, 0.78, 0.83)
const TIER_GRIM := Color(0.24, 0.80, 0.38)
const TIER_DAMNED := Color(1.00, 0.58, 0.15)

# --- coins ------------------------------------------------------------------
# Amber, and told apart from soul motes by shape and motion as much as hue --
# a coin is a flat rimmed disc that spins edge-on, a mote is a haloed orb that
# pulses. See META.md section 3.
const COIN := Color(0.95, 0.72, 0.22)
const COIN_HI := Color(1.00, 0.93, 0.64)
const COIN_RIM := Color(0.34, 0.21, 0.05)

# --- the chapel floor -------------------------------------------------------
# All of these are VOID-family values, not new hues: the dungeon is built out
# of the dark end of the existing palette so it can never fight the sprites for
# attention. The only colour down there is brazier light, which is BLOOD.
const STONE := Color(0.108, 0.108, 0.128)
const STONE_LIT := Color(0.140, 0.139, 0.162)
const STONE_DARK := Color(0.074, 0.074, 0.092)
const MORTAR := Color(0.052, 0.052, 0.066)
const PIT := Color(0.026, 0.026, 0.034)
const WALL := Color(0.060, 0.060, 0.076)
const WALL_CAP := Color(0.150, 0.150, 0.172)
