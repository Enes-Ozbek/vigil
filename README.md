# Vigil

A dark fantasy arena roguelite in Godot 4. You hold a ruined chapel against the
things in the dark. Survive the vigil, and something offers you power — you
must take one of its offers, and every one of them costs you.

**[STATUS.md](docs/STATUS.md) is the map** — what exists, what does not, what to do
next. Also: [PLAN.md](docs/PLAN.md) for the design and milestones, [BALANCE.md](docs/BALANCE.md)
for the numbers, [META.md](docs/META.md) for between-run progression, and
[ASSETS.md](docs/ASSETS.md) for the art.

## Run it

1. Open the Godot 4 project manager → **Import** → pick this folder's `project.godot`
2. Press **F5**

The game opens on `menu.tscn`. **Esc** pauses mid-run and brings up the same
menu in its pause mode. To launch straight into the arena, press **F6** with
`main.tscn` open, or from the command line:

```
godot --path . res://main.tscn
```

Runs at **1920x1080**. Gameplay lives in a 960x540 *world* drawn through a node
scaled 2x, so gameplay numbers stay small and sprites get a clean integer
blow-up; the HUD draws unscaled at native resolution so text stays crisp.

| Key | Does |
|---|---|
| WASD / arrows | Move |
| Mouse | Click any card to choose it. Cards highlight on hover |
| 1–4 | Same choices from the keyboard |
| R or click | Rise again, after death |

The run opens on a character select. **Each character owns one weapon that is
theirs alone** — there is no shared pool and nothing is picked up mid-run.

| Character | Health / speed | Weapon | Art |
|---|---|---|---|
| The Necromancer | 85 / 205 | The Ashen Cane — slow bolts that bore through crowds | sprite |
| The Vessel | 140 / 190 | The Moonstone Blade — cuts sideways, and throws | sprite |
| The Poacher | 75 / 250 | The Wailing Bow — kills at distance | silhouette |

A character with no sprite still plays perfectly — see [ASSETS.md](docs/ASSETS.md)
for how to add art later.

## Files

| File | What it does |
|---|---|
| `main.gd` | The loop: spawning, collision, the vigil timer, pacts, HUD |
| `pacts.gd` | Pact **data** only — 25 pacts and what they grant |
| `weapon.gd` | A carried weapon: per-bolt cooldowns and where it last aimed |
| `player.gd` | Player stats, movement, weapons, and animation state |
| `enemy.gd` | Enemy stats and per-wave scaling (`setup()`) |
| `bullet.gd` | A position, a velocity, and a damage number |
| `characters.gd` | Character **data** — stats, their weapon and its bolts, sprite animations |
| `enemy_kinds.gd` | Enemy archetype **data** — stats and sprite animations |
| `sprite_anim.gd` | Sprite-sheet playback, drawn through `_draw()` |
| `menu.tscn` / `menu.gd` | Main menu **and** pause menu — real `Control` nodes |
| `ui_theme.gd` | One `Theme` for every Control, built from the palette |
| `settings.gd` | Fullscreen / vsync / reach ring, saved to `user://` |
| `coin.gd` | Gold pickup — a spinning amber disc |
| `profile.gd` | The purse, run history and owned upgrades, saved to `user://` |
| `upgrades.gd` | Per-character upgrade **data** — 8 nodes each |
| `chapel.tscn` / `chapel.gd` | The between-runs spend screen |
| `dungeon.gd` | The procedural chapel floor |
| `palette.gd` | The whole colour scheme. Three hues, on purpose. |
| `tools/balance_sim.gd` | Headless harness that plays 15 vigils and prints the numbers |
| `tools/smoke_test.gd` | Drives every state as every character, with `_draw` running |

Collision is circle-vs-circle distance math with no physics nodes, and
everything is rendered through `_draw()` — sprites where art exists, shapes
where it does not. See [ASSETS.md](docs/ASSETS.md) for the sprite sheets. Real Godot projects lean much harder on scenes (`.tscn`) —
converting the player/enemy/bullet into proper scenes is a good exercise once
you are comfortable.

## Pacts

**35 pacts in three tiers** — Common (grey-white), Grim (green), Damned
(orange) — using the loot-rarity convention every player already reads. The
tier colours the card's **name, badge, spine and background wash**, and Damned
cards get a glow; rarity is legible before you have read a word. Offers roll a *tier* first and then a pact within
it, so rarity lives in the roll rather than in how many of each exist. Better
tiers get likelier as a run goes on, and Luck pushes them further.

The cards are animated, and everything scales with tier: they **slide in
staggered** from the right, the border and glow **breathe** (faster and
stronger the rarer the pact), a **shimmer sweeps** diagonally across each one
(every ~2.5s on a Damned, ~4.5s on a Common), Damned cards **give off embers**,
and hovering **swells** the card with a doubled glow.

Axes: damage, attack speed, reach, area, move speed, max
health, armour, regeneration, projectile speed, projectile lifetime, projectile
count, life steal, revival, **critical chance and damage**, **dodge** (capped
at 60%), piercing, bouncing, knockback, luck and XP gain.

Extra projectiles **split** the shot — each beyond the weapon's own carries 80%
damage — so a projectile pact is a clear gain without doubling output outright.

The stat *taxonomy* is standard survivors-like vocabulary. What is ours is that
**none of them are free** — every one is a pact with a cost, because pure-upside
buffs would undercut the whole design.

## Bolts: attacks that unlock mid-run

A weapon carries a list of **bolts** — its distinct attacks. Only the first is
available when a run begins; **each vigil survived frees one more**.

Every bolt runs on **its own cooldown at its own rate**, so they never wait for
each other and never fire in lockstep, and a newly freed bolt starts
deliberately out of phase. Two bolts are two weapons that happen to share a
handle. This works for melee swings exactly as it does for projectiles:

| Character | First bolt | Freed after a vigil |
|---|---|---|
| Necromancer | **Cinder** — the flame off his staff, pointing where it flies | **Bound Skull** — the skull in his other hand, tumbling; harder, pierces deeper |
| Vessel | **Cut** — the quick horizontal slash | **Moonfall**, then **Sever** — a thrown blade |
| Poacher | **Bone Arrow** | **Spite** — slower, heavier, pierces 3 |

Aim is computed from the **muzzle**, not the character's position. The staff
head sits (9, -25) from his feet, so aiming from the feet would send every shot
along a line parallel to the one that would have hit — 25px wide at any range.

Projectile art is scaled from the sprite's **content**, not its texture, so the
drawn bolt is exactly its collision radius — what you see is what hits. Both
cane sprites are padded to a square so they can rotate about their centre, and
scaling by texture width sized them by their padding instead (the skull is 6px
of art in a 10px square, the flame 19px in 23px).

Extra projectiles from **Split Tongue** pick **their own targets** rather than
piling onto the same enemy; only the surplus beyond the number of live enemies
fans out.

## The floor

The arena is a drawn dungeon, not a tileset: offset flagstones with per-stone
value jitter, missing stones, cracks, rubble, a masonry wall band, six
braziers each breathing on its own phase, and a vignette pulling the eye
inward. Generated once from a fixed seed in `dungeon.gd` so it never shimmers.

It is built entirely from VOID-family values in `palette.gd` — the only actual
colour on the floor is brazier light, and that is BLOOD.

## The roster

| Archetype | Role | From vigil | Behaviour |
|---|---|---|---|
| Nightwing | swarm | 1 | weak, endless, comes from every edge |
| Catto | rusher | 3 | fast and fragile; punishes standing still |
| The Hollow Mage | ranged | 5 | stops at 250 units and throws — you have to go to it |
| Rotmaw | charger | 5 | heavy and fast; walking away only buys time |
| Abomination | tank | 7 | slow, enormous, soaks a whole build |
| NightBorne | elite | 9 | rare, fast, hits like a truck |
| **The Skeleton Knight** | **boss** | **5** | announced, 600 health, a telegraphed swing you can step out of |

Weights are in `EnemyKinds.SPAWNS`; each archetype is introduced alone so it
gets a vigil where it is the thing you notice. Tougher archetypes drop far more
motes (a NightBorne is worth 10 bats), so the difficulty and the economy scale
together.

The Mage's throw has a **wind-up**: the attack animation plays before anything
leaves its hands. An unannounced projectile is the cheapest kind of unfair.

## The arena

**2x2 screens**, with the view following you and stopping at the walls.
`MAP_SCREENS` in `main.gd` is the one constant — 1x1 puts it back on a single
fixed screen.

**Chests** scatter across it each vigil and burst into coins when you walk into
one. Anything off-screen gets a gold marker at the screen edge pointing the
way. An unopened chest is lost when the vigil ends, which is the decision:
that chest is over there and the wave is thickening here.

## Gold

Enemies drop coins **on a roll**, not on a rule — 12% from a Nightwing, 55%
from an Abomination, always from a NightBorne. A coin is meant to be a moment,
so a whole vigil drops only a handful.

**Luck** raises the drop chance, and once a chance would pass 100% the overflow
raises the coin's *value* instead — so Luck never stops doing anything for an
enemy that already always drops.

Gold **banks the instant you touch it** (die a second later and it is still
yours), and coins left on the floor when a vigil ends are **lost**. That
asymmetry with soul motes, which are swept up for you, is deliberate: motes are
this run's progress, gold is what you carry out.

Coins are told apart from motes by three things at once — amber not green, a
flat rimmed disc not a haloed orb, and a **spin** rather than a pulse. The
purse persists in `user://profile.cfg`. What it buys is planned in
[META.md](docs/META.md).

## The Chapel

Between runs, gold buys **permanent per-character upgrades**. Reached from the
main menu (which shows your purse on the button) or by pressing **C** on the
death screen.

It opens on a **portrait picker** — three large cards, one per character, each
showing an animated portrait and how far their tree has been tended. Click one
and you go into *that* character's upgrades; esc steps back out. Showing every
node for every character at once is a list, not a place.

Eight nodes per character across the same Common / Grim / Damned tiers, priced
100 / 300 / 700 — **2,600 for a full tree**. Nodes you cannot afford are dimmed
rather than hidden, so you can see what you are saving for.

Upgrades write the same modifier fields a pact does, so nothing downstream
needs to know where the power came from. Owned nodes live in
`user://profile.cfg` per character.

| Character | Its tree is about |
|---|---|
| The Necromancer | reach, pierce, bounce, and starting with the Bound Skull |
| The Vessel | armour, healing, knockback, area, and an extra breath |
| The Poacher | speed, crit, dodge, and an extra arrow |

## Soul motes and levels

Everything that dies leaves a **soul mote** where it fell — a green halo around
a yellow-green body around a hot core, with a four-point sparkle that waxes and
wanes. Every mote gets a random phase, so a floor covered in them twinkles
instead of pulsing in unison, and a caught mote brightens as it comes to you.

Green-gold is a **deliberate exception** to the three-hue palette. Everything
else on screen is void, ash or blood; a pickup drawn in any of those could read
as danger for the split second that matters. Green-gold belongs to nothing else
in the game, so a mote can only ever mean "take this".
 Motes scatter, settle,
and fly to you once inside your pickup radius — and once caught they stay caught,
so you cannot shake one off by running past it. Anything still on the floor when
a vigil ends is collected rather than lost.

Motes fill a level bar. Levels earned during a vigil are **spent at the end of
it** — one pact screen each, with the vigil's own pact last. Interrupting a
fight to shop is Vampire Survivors' model; ours follows Brotato, because the
interruption otherwise lands while you are surrounded.

Pacing lives in one function: `Player.xp_to_next()`, now `(level + 3)²` —
Brotato's curve, 16 / 25 / 36 / 49.
Lower it and pacts arrive in a flood; raise it and a run stalls. Two pacts feed
this loop — **The Lodestone** (+60% pickup reach) and **Grave Wisdom** (+30% per
mote).

## Piercing vs bouncing

They are not the same and the two cane bolts show the difference: **Cinder
pierces** — it carries straight on through and struck 3 enemies in a line in
testing. **The Bound Skull bounces** — it stops dead in the first enemy and
leaps to one more within 220 units that it has not already hit, striking
exactly 2.

## Difficulty comes from one place

Pacts are pure upgrades — they cost nothing. That means the **only** thing
holding a run back is the per-vigil enemy curve in `Enemy.setup()`
(`enemy_kinds.gd`) and the spawn pacing in `main.gd`. If runs feel too easy,
that is where to look; there is no longer a second dial pulling the other way.

## About scenes

Almost everything here is built in code rather than in scenes. That was a
bootstrapping decision and it is **not** idiomatic Godot — see PLAN.md
section 10 for what should move and in what order.

`menu.tscn` is the first piece done properly: the layout is editable in the
editor, the buttons are real `Control` nodes with focus and keyboard navigation
for free, and styling comes from one `Theme` in `ui_theme.gd` rather than being
repeated at every draw call. Compare it to the character-select screen in
`main.gd`, which does the same job with about four times the code.

## Checking a change did not break anything

```bash
godot --headless --path . -s tools/smoke_test.gd
```

Runs the real game as **every character**, through playing / pact screen /
taking a pact / death, with enemies on the field and `_draw` executing for each
state. Any engine error is printed.

This exists because a HUD-only crash shipped once: `main.gd` read a property
that had been deleted from `Weapon`, and every check until then had sat on the
character-select screen without ever entering play, so nothing executed the
line. **A project that "runs" clean while only ever rendering its first screen
has not been checked.** Reintroducing that bug produces 265 error lines under
the smoke test and zero under a plain headless run.

## Running the balance sim

```bash
godot --headless --path . -s tools/balance_sim.gd
```

It plays four full 15-vigil runs with different strategies and prints damage,
attack speed, reach, max health, and the enemy multipliers per vigil. Use it
whenever you change a number — it catches runaway scaling in seconds instead of
in a playtest you have to sit through.

## Tuning knobs, in the order you should touch them

1. `VIGIL_SURVIVAL_HEAL` in `main.gd` — health granted for surviving a vigil.
   Set to 0 to make healing available **only** through pacts. Considerably
   harsher; try it once you know the game.
2. `Enemy.setup()` in `enemy.gd` — all base per-wave difficulty scaling.
3. `WAVE_LENGTH` and `SPAWN_INTERVAL` in `main.gd` — pacing.
4. The boon numbers in `_apply_boon` in `main.gd`.

## Adding a pact

1. Add an entry to `ALL` in `pacts.gd` (id, name, boon text, corruption).
2. Add a case to `_apply_boon()` in `main.gd` for what it actually does.

Note: after adding a new script with `class_name`, Godot needs to rescan before
other scripts can see it. The editor does this on save; from the command line
it is `godot --headless --path . --import`.
