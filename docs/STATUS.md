# Status — what exists, what does not

A dark fantasy arena roguelite in Godot 4.6, Brotato-shaped: one arena, a vigil
timer, automatic attacking, a choice of upgrades between waves. Built to learn
game development. **It is not going to be sold, so nothing here needs licence
checking or commercial-readiness work** — where PLAN.md or META.md mention Steam
pages or prices, read those as flavour.

Roughly **4,500 lines of GDScript** across 17 game scripts and 2 tools.

---

## Done

### The run
- 15 vigils, length ramping 20s → 60s (Brotato's curve)
- **Vigils 8, 11 and 14 are a Horde or an Elite** — three times the spawns at
  40% health, or a third of the spawns at 2.6x health and double motes. Rolled
  fresh each run, so knowing a vigil is special does not tell you which. Not
  harder vigils: different ones, each rewarding what the other punishes.
- **The pact screen can be refused** for an escalating gold cost (Brotato's
  curve), paid from the Chapel purse — so rerolling this run costs every run
  after it. A cursed chest cannot be rerolled.
- **The arena is 2x2 screens** and the view follows you, clamped so it never
  shows past the walls. `MAP_SCREENS` is one constant — set it to 1x1 and the
  game is back to a single fixed screen.
- The view scrolls by **moving the world node**, not with a `Camera2D`. A
  camera would drag the HUD with it, since the HUD is drawn on that node.
- Enemies spawn just outside **the view**, not the map edge, so a big arena
  never means waiting for something to walk in from the dark
- **The Cursed Chest** drops where a boss falls, and offers a **choice of three
  cards** rather than money. It plays its opening animation first and the cards
  arrive when the lid does, so a pickup becomes a small event. Blood-lit rather
  than gold-lit, so it can never be mistaken for a common chest across a dark
  floor. The cards are drawn **Inscryption-style** by `card_face.gd`: a carved
  wooden plank with notched corners, aged parchment with seeded grain and
  stains, a woodcut symbol in a recessed well, and blood drops for cost. Upright
  and side by side, unlike the pact screen's list. That palette is a deliberate
  fourth exception to the three-hue rule — a card is an *object* being held up
  in front of you, and reads as one precisely because it does not match the
  dungeon. **The ten cards in `chest_cards.gd` are placeholders** — the system,
  the spawn, the screen and the pick all work regardless of what is in that
  list, and swapping them is a data edit plus a matching arm in `_take_card`.
- **One chest a vigil**, worth `12 + 6 x vigil`, bursting into real coins when
  touched. It used to be three: forty-five across a run, always one nearby, so
  the decision a chest exists to create — it is over there, the wave is
  thickening here — never came up. The value tripled with the cut, so a run pays
  the same gold and the Chapel keeps its pacing. Off-screen ones get a marker pinned at the screen edge.
  An unopened chest is lost when the vigil ends.
- Enemies spawn on a scaling interval from all four edges
- **A vigil ends on a tally**, not on the pact screen. The two used to be the
  same instant — the timer hit zero and four cards were already up, so a vigil
  ended the way a loading screen ends. Now the ground darkens, a frame is drawn
  edge by edge, the vigil number is struck in, a rule is dragged under it, and
  the count reads itself out: slain, gold taken, harm suffered (or *untouched*).
  Everything arrives in sequence rather than together, because a screen where
  everything appears at once has no rhythm. **It waits** — nothing advances on a
  timer, because a screen that leaves on its own trains you to ignore it. Click
  or press anything to go on, though not for the first half-second: otherwise the
  key still held down from moving would skip it before a stroke was drawn.
- **The run is saved at the start of every vigil** (`run.cfg`, separate from the
  wallet). It stores the DECISIONS, not their consequences: the list of pacts
  taken, replayed on load through the same `_swear_pact` / `_take_card` the game
  uses while you play. Mirroring the player's 28 modifier fields would have
  worked exactly once — the next pact writing a new field would be silently
  dropped from every save. Health, level and XP are stored directly, being the
  only things replaying cannot produce. Dying clears it.
- **CONTINUE** appears on the main menu when there is a run to return to, naming
  the character and vigil; BEGIN THE VIGIL becomes BEGIN ANEW beside it.
- Death, revive-on-fall (Second Breath), and a run summary
- Deterministic circle-vs-circle collision, no physics nodes

### Characters — 3
Each owns **one weapon** that is theirs alone; no shared pool, nothing picked
up mid-run.

| | Weapon | Bolts |
|---|---|---|
| Necromancer | The Ashen Cane | Cinder (flame, blast), Bound Skull (bounces) |
| Vessel | The Moonstone Blade | Cut, Moonfall, Sever (thrown sword) |
| Poacher | The Wailing Bow | Bone Arrow, Spite |

- **Bolts** are a weapon's distinct attacks. One is free at vigil 1; each vigil
  survived frees another. Every bolt runs on **its own cooldown at its own
  rate**, so they never wait for each other or fire in lockstep.
- **Bolts do not pile onto one enemy.** Each prefers a target nobody has shot
  at yet, then one that is not already dead on arrival, then anything. Damage
  in flight is tracked on the enemy (`incoming`), so nothing is shot at after
  enough damage to kill it is already on the way. A bolt can also declare its
  own style — the Bound Skull scatters among the three nearest, Spite takes the
  furthest target because it pierces three.
- **The Cinder does not pierce and never will** — it declares `no_pierce`, so
  stacking pierce pacts cannot turn a flame into a lance. It stops where it
  lands and burns a small radius around it for 55% damage, which is the only
  area effect any weapon currently has. The Bound Skull is the bolt that scales
  with pierce and bounce, so the two never want the same pacts.
- A bolt can override the weapon's kind — the Vessel's blade cuts with two
  attacks and throws with the third.
- Melee damage is a **horizontal box**, matching the swing animation, not a
  circle. Ranged aim is computed from the **muzzle**, not the character's feet.

### Enemies — 6 archetypes + a boss
Nightwing (swarm, v1), Catto (rusher, v3), Hollow Mage (ranged, v5), Rotmaw
(charger, v5), Abomination (tank, v6), NightBorne (elite, v9).

**The Skeleton Knight** arrives at vigil 5, announced, on top of the normal
wave — 600 health, a boss bar across the top, 40 motes and 60 gold when it
falls. It does not damage on contact: it plants itself, winds up, and swings.
Rooted while winding up, so stepping out of the arc always works. Measured:
parked in reach it lands 3 swings in 6.7s; stepping out during each wind-up
takes **zero** damage.

- Spawn weights **ramp in** over several vigils rather than switching on, so
  average enemy health climbs smoothly
- The Mage keeps its distance and throws, with a **wind-up** so the attack is
  telegraphed
- Death is a state, not an instant despawn: corpses animate while being ignored
  by targeting, collision and movement

### Pacts — 35
Every pact carries a **symbol chosen by the stat it moves**, not by the pact:
all four damage pacts show the same broken blade, all three attack-speed pacts
the same chevrons. Twenty-two marks cover the whole pool plus the chest cards,
so a player learns a small vocabulary once and can then read a pact screen at a
glance. Drawn by `card_face.gd` from one shape library with two renderers —
inked and hatched on parchment chest cards, flat and lit in the tier colour on
the animated pact panels, which redraw every frame and cannot afford the ink.

Three offers a screen, three tiers (Common / Grim / Damned) rolled by **tier first**, weighted toward
better tiers as a run goes on and further by Luck. Axes: damage, attack speed,
reach, area, move speed, max health, armour, regeneration, projectile speed /
lifetime / count, life steal, revival, crit chance and damage, dodge (capped
60%), pierce, bounce, knockback, luck, XP gain.

### XP and gold
- **Soul motes** drop from every kill, are pulled in, and level you up.
  `xp_to_next = (level+3)²`. Levels are spent at the **end** of a vigil.
- **Coins** drop on a roll (12% from a swarm enemy, 100% from an elite). Luck
  raises the chance, and past 100% the overflow raises the coin's *value*.
  Gold banks the instant you touch it; coins left on the floor are **lost**.

### Meta progression
- **THE CHAPEL** — opens on a portrait picker, then that character's tree
- 8 upgrade nodes per character, priced 150 / 550 / 1300 (4,700 a tree)
- Purchases persist in `user://profile.cfg` with run history
- Upgrades write the same modifier fields a pact does

### Screens
**The main menu is a dark room, not a title card.** Four braziers breathe on
their own clocks (the same construction the dungeon floor uses, so the menu
reads as a place in the same building), blood finds its way down from above the
screen, ash drifts, the dark leans in at the edges — and **eyes open in it**.
They open somewhere, hold on you, close, and open somewhere else; an eye that
returns to the same spot is a decoration, one that moves is something walking.
They stay out of the middle third, where the text lives.

Main menu, pause menu (same scene, two modes), settings (fullscreen, vsync,
reach ring, SFX and music volume — saved), character select, pact screen,
armoury, Chapel, death screen.

**Character select and the pact screen take full keyboard**: W/S, arrows or A/D
to move the highlight, Enter or Space to take it, 1-4 to jump straight to a
card. All four directions move the selection, because the screens disagree on
their own axis — pacts and characters are stacked vertically, the cursed chest
deals its three cards side by side — so the key you reach for is always right.
The highlight is shared with the mouse, and only a mouse that has actually
*moved* takes it back — reading the mouse position every frame would wipe an
arrow-key selection before it could be seen.

### Your measure — the pause screen
ESC mid-run shows what the run has made you, in three columns beside the pause
buttons: **THE BODY**, **THE HAND**, **THE WORLD**. `stat_sheet.gd` holds the
arithmetic and `menu.gd` only lays it out, so the death screen can show the same
sheet later without duplicating a formula.

Every line that *can* be an outcome is one. "Armour 3" tells a player nothing;
**"3 — 17% absorbed"** tells them whether to buy a fourth. Crit is quoted as the
flat damage it averages out to, which is the only form in which it can be
weighed against the +damage card next to it, and **"you survive N damage"** folds
armour, resilience and dodge into the one number they were all buying. Rows for
stats no pact has granted stay hidden; the core ones are always present, because
a stat you have never seen is a stat you never buy.

`smoke_test` hits the player four hundred times and checks the health actually
lost matches what the screen promised — a stat screen quoting its own arithmetic
back at itself is worse than no stat screen. A second check walks every script
variable on the player, nudges it, and re-renders: if the text does not change,
that field is invisible to the player whatever anyone intended. Only `xp` is
exempt, because the HUD's level bar owns it.

### Sound
- **16 effects, derived from six recordings** by `tools/build_sfx.py` — pitched,
  stretched, filtered, reversed and layered, because six sources have to cover
  sixteen slots and nothing should be reused verbatim. Sources kept in
  `assets/sfx_src/`. This replaced a synthesised set that was honest placeholder
  work and sounded like it.
- `audio.gd` is a static singleton like `settings.gd`, holding a pool of 24
  voices. **Every sound has a retrigger gap and a cap on overlapping copies**,
  because thirty motes landing on one frame is an ordinary end to a vigil and
  thirty copies of one sample is a clipped click rather than a louder sound.
- Buses (SFX / Music) are made in code, so there is no binary `.tres` to keep
  in step. Volume sliders are in settings and persist.
- These sound retro-arcade, not dark fantasy. Replacing one is a matter of
  dropping a WAV of the same name into `assets/sfx/` — no code change.

### Look
- **A minimap, top right.** The arena is 2x2 screens and the view shows a
  quarter of it, so the chest that expires with the vigil and the horde massing
  behind you are permanently out of sight. Deliberately sparse: player, enemies,
  boss, chests, and nothing else. No motes, no coins, no floor, and **no
  rectangle marking what is already on screen** — you can see that by looking at
  it. Everything drawn is something you cannot otherwise know. Chests are
  squares and everything alive is a circle, because at three pixels shape
  carries further than hue. The frame is chapel masonry (`PIT` inside,
  `WALL_CAP` edge, bone corner ticks) rather than UI chrome. It hides itself at
  `MAP_SCREENS` 1x1, where the whole arena is already on screen.
- **The vigil clock is top centre**, and reddens and swells over the last ten
  seconds so "nearly through" arrives in peripheral vision. The boss bar sits
  below it and carries its name inside itself rather than under it.
- Three-hue palette (void / ash / blood) with two deliberate exceptions: soul
  motes are green-gold, pact rarity is grey / green / orange
- Procedural dungeon floor: flagstones, cracks, rubble, masonry walls, six
  braziers each breathing on its own phase, vignette
- **Everything you are offered is dealt as a card.** Pacts, chest cards and
  level-up rewards all use the same inked parchment from `card_face.gd` — a
  hand of **three**, upright and side by side. Pacts used to be four wide bars
  stacked vertically, which read as a settings list rather than as something
  being handed to you; the neon panels, their glow, badges and ember effects are
  gone with them.
- **Rarity is encoded twice**: one blood drop per tier, *in* the tier's colour —
  dried blood for Common, verdigris for Grim, tarnished gold for Damned. Either
  signal alone would do; both means it survives a glance and survives
  colourblindness. The selected card's gilding takes the tier's colour too.
- **Impact blasts** — the first hit feedback in the game beyond a flash. Drawn on
  their own node under the world, so they inherit its transform instead of
  converting coordinates by hand.
- 1920x1080, with gameplay in a 960x540 world scaled 2x so sprites get a clean
  integer blow-up and the HUD stays crisp

### Tooling
- `tools/smoke_test.gd` — drives every state as every character with `_draw`
  running, clicks the Chapel for real, prints any engine error
- `tools/balance_sim.gd` — pact sweeps, tier distribution, a **hits-to-kill**
  table, an **overkill-waste** measure, and a 40-run projection of player DPS
  against arena pressure, for random *and* greedy pact picks
- `tools/perf_probe.gd` — runs real vigils headless and reports mean/p95 frame
  time and peak entity counts, so "it feels like it drops frames" becomes a
  number. Its player is unkillable and kites on a circuit; the first version
  stood still, died, and measured the death screen
- `tools/targeting_check.gd` — proves bolts spread across the crowd, that
  nothing is shot at twice over, and that no damage reservation leaks
- `tools/build_sfx.py` — derives all 16 sound effects from six recordings
- Two sprite-strip assemblers

**Analysis tools must set `RunSave.suspended = true`.** Anything that
instantiates `main.tscn` is driving the real game, and the real game saves — so
for months `balance_sim` swept a full run as the necromancer and left *vigil 16*
on disk, meaning every rebuild quietly replaced the player's run with the
simulation's and offered it back through a CONTINUE button. `smoke_test` is the
one exception, because it tests saving: it saves for real and backs the player's
file up around the whole run. A check in `smoke_test` reads the sources and fails
any tool that drives `main.tscn` without suspending.

---

## Not done

### No music
The SFX are in (see Done). There is a **Music bus** wired and a volume slider
for it, and no track to put on it — that one needs a real file from somewhere,
because looping music is not something arithmetic produces.

### Milestone 3 — Corruption
Every pact carries a `corruption` weight and the run totals it, but **nothing
reads it**. The design (thresholds at 5/10/15 giving every enemy a permanent
modifier) is in PLAN.md section 2.

### Milestone 4 — the juice pass
Beyond audio: screen shake, floating damage numbers, hit particles, death
bursts. Hit flashes exist; nothing else does.

### Milestone 5 — run structure
**One boss exists** (Skeleton Knight, vigil 5). `EnemyKinds.BOSSES` is a
vigil → id map, so 10 and 15 are one line each once there is art for them.
Still no **win screen** — clearing vigil 15 currently just... stops.

### Milestone 6 — the rest of meta
- **Danger tiers are required, not optional.** The upgrade ceiling was set at
  +90%, and BALANCE.md tuned a run to a damage ratio of 1.0–2.0. Doubling the
  player's side breaks that. META.md section 7 has the design: enemy health
  x1.25 per tier, gold payout x1.5. **Do not add more upgrade nodes before
  this exists.**
- **Character unlocking** — the system is designed but not built; all three are
  available from the start.
- **8 deferred upgrade nodes** needing systems that do not exist: burning
  ground, raising the dead, a third bolt, a double swing, a slow-time trigger,
  invulnerability windows, an every-third-shot counter, both-sides melee.

### Scene migration
Almost everything is built in code rather than scenes, which is **not
idiomatic Godot**. `menu.tscn` and `chapel.tscn` are the only real scenes.
PLAN.md section 10 has the order: character-select and pact screens to
`Control` next, then Player/Enemy/Bullet to `.tscn` with `AnimatedSprite2D`.
Data files (`pacts.gd`, `characters.gd`, `enemy_kinds.gd`) should stay code.

### Known problems
- **The pact pool is still all numbers.** 35 pacts moving 25 stats, and none of
  them change how the loop plays — no orbiting weapon, no aura, no on-kill
  effect. Vigil kinds now vary the fight, but two runs of one character still
  differ only in speed. This is the largest remaining design gap.
- **The vigil-10 dip.** Difficulty peaks in the middle of a run and eases by
  vigil 15, when it should climb throughout. Spawn ramping helped; the rest is
  structural (pressure grows linearly, player power compounds). The sim
  measures it directly.
- **Prices are provisional.** They come from a projection, and the two numbers
  a real player diverges from most — how many coins they bother collecting, and
  how much Luck they stack — are both in that system.
- **`main.gd` is 1,275 lines** and does the run loop, the HUD and three screens.
  The screens are the natural thing to lift out, and the Control migration
  would do it anyway.
- **The Poacher has no art.** It plays fine as a silhouette.

### Unused assets already imported
Mad Ghost (a whole creature, wind-up attacker), the Necromancer's cast-2 and
summon rows, the bat's IdleFly / Attack / Sleep / WakeUp, the Keeper's run,
the Dreadknight's run_alt and idle, and two potion sprites.

---

## Checking a change

```bash
godot --headless --path . -s tools/smoke_test.gd        # every state, every character
godot --headless --path . -s tools/targeting_check.gd   # where the bullets go
godot --headless --path . -s tools/balance_sim.gd       # numbers
godot --headless --path . --fixed-fps 60 -s tools/perf_probe.gd   # frame cost
godot --headless --path . res://main.tscn --fixed-fps 60 --quit-after 400
godot --headless --path . --fixed-fps 60 --quit-after 120   # the menu
```

Any engine error prints; all six should be silent. **A headless tool that
`quit()`s in the same frame it queues frees will report leaked objects on the
way out** — both new tools spend a dozen frames draining first, because that
warning would otherwise sit permanently where a real error should stand out. **A project that "runs"
clean while only ever rendering its first screen has not been checked** — the
smoke test exists because a HUD crash shipped exactly that way once.
