# Balance plan — numbers, XP, and the perk pool

Modelled on Brotato, changed where our game is a different shape. Every number
here is either measured from our build or sourced from Brotato's wiki; nothing
is a guess dressed up as a decision.

**Status: all six steps are done.**

| Step | State |
|---|---|
| 1. Wave-length ramp + spawn floor | **done** |
| 2. Quadratic XP, deferred level-ups, +1 max HP a level | **done** |
| 3. Pact tiers and weighted offers | **done** |
| 4. Crit and dodge | **done** |
| 5. Pierce / bounce / luck / knockback | **done** |
| 6. Re-tune tier 3 against the target | **done** — see section 11 |

Milestone 2 (the enemy roster) also landed alongside these, which changed the
numbers below -- see section 10.

---

## 1. The problem, measured

Deleting the debuffs left difficulty resting on a single dial — the enemy
curve — and that dial is currently set to a wall. Projected enemy pressure,
in HP arriving per second:

| Vigil | Wave length | Spawn interval | Enemies spawned | Enemy HP | **HP/sec** |
|---|---|---|---|---|---|
| 1 | 20s | 0.52 | 38 | 12 | **23** |
| 5 | 20s | 0.40 | 50 | 28 | **70** |
| 10 | 20s | 0.25 | 80 | 48 | **192** |
| 15 | 20s | 0.12 | 167 | 68 | **567** |

Pressure rises **24x** across a run while a fresh Necromancer deals 21.8 DPS
(37.8 with both bolts). Nothing in the pact pool multiplies power 24x, so a run
becomes arithmetically unwinnable somewhere around vigil 10-12 — not hard,
*impossible*. Meanwhile every vigil is 20 seconds, so vigil 15 is the same
length as vigil 1 but eight times denser: a spike, not a climb.

## 2. What Brotato does

| | Brotato | Us today |
|---|---|---|
| Run length | 20 waves, ~25 min | 15 vigils, ~7 min |
| Wave length | 20s, **+5s per wave, capped at 60s**; wave 20 is 90s | flat 20s |
| Enemy scaling | base HP + flat HP **per wave**, linear | same shape (good) |
| Enemy HP values | Chaser 1 (+1/wave), Baby Alien 3 (+2), Charger 4 (+2.5), Spitter 8 (+1) | Bat 8 (+4) |
| XP curve | **quadratic** — level L costs `(L+3)^2`: 16, 25, 36, 49, 64 | linear `10 + L*8` |
| Level-up | **deferred to end of wave**, plus a free +1 Max HP | interrupts the vigil |
| Upgrades | 4 random stat choices, rarity scales with Luck and wave | 4 random pacts, no rarity |
| Items | tier 1-4, bought with materials, many carry **downsides** | free, untiered, no downsides |
| Stats | 16 primary + 22 secondary | ~17 axes |

Sources: [Waves](https://brotato.wiki.spellsandguns.com/Waves) ·
[Experience](https://brotato.wiki.spellsandguns.com/Experience) ·
[Enemies](https://brotato.wiki.spellsandguns.com/Enemies) ·
[Stats guide](https://brotato-builds.com/stats)

## 3. What we take, and what we deliberately do not

**Take:**

- The **wave-length ramp**. It is the single best fix for section 1: it turns
  late vigils into endurance instead of density.
- The **quadratic XP curve**. Linear XP plus exploding kill counts means levels
  arrive faster and faster exactly when they should be slowing down.
- **Deferring level-ups to the end of a vigil.** Ours interrupt mid-fight,
  which is Vampire Survivors' model, not Brotato's. Our vigils are short and
  the interruption lands while you are surrounded.
- **Tiered upgrades** with rarity weighted by progress.
- **Low enemy HP, high enemy count.** Brotato's basic enemies have 1-8 HP. Ours
  has 8 and gains 4 a wave, which makes single kills feel slow.

**Do not take:**

- **Materials and a shop.** Motes are XP only. Adding a currency means a shop
  screen, prices, rerolls and an economy to balance — a second game.
- **Item downsides.** Removed by decision; noted in section 8 as a lever, not a
  recommendation.
- **20 waves.** 15 vigils at the new lengths is already ~11 minutes, which is
  the right length for a run you lose often.
- **Engineering / structures / burning / elemental.** Whole subsystems.

## 4. Numbers to change

| Constant | Where | Now | Proposed | Why |
|---|---|---|---|---|
| `WAVE_LENGTH` | main.gd | 20 flat | `min(20 + (v-1)*5, 60)` | the Brotato ramp |
| spawn interval | main.gd | `max(0.12, 0.55 - v*0.03)` | `max(0.22, 0.60 - v*0.028)` | raise the floor; length carries the load |
| `hp_per_wave` | enemy_kinds.gd | 4 | 5 | steeper per enemy, fewer per second |
| `xp_to_next` | player.gd | `10 + L*8` | `(L+3)^2` | Brotato's curve |
| level-up timing | main.gd | interrupts | queue, resolve at vigil end | keeps combat continuous |
| level-up bonus | — | none | +1 max HP free, on top of the pact | Brotato |

Projected result:

| Vigil | HP/sec now | HP/sec proposed | Enemies now | Enemies proposed |
|---|---|---|---|---|
| 1 | 23 | **23** | 38 | 35 |
| 5 | 70 | **72** | 50 | 87 |
| 10 | 192 | **181** | 80 | 188 |
| 15 | 567 | **377** | 167 | 273 |

Pressure climbs 16x instead of 24x, total kills roughly doubles (1190 → 2264),
and the run gets longer rather than spikier.

**Levels reached** (killing everything spawned):

| Wave length | XP curve | Level at vigil 1 / 5 / 10 / 15 |
|---|---|---|
| current | linear | 2 / 6 / 11 / 16 |
| current | quadratic | 2 / 6 / 9 / 12 |
| proposed | linear | 2 / 8 / 15 / **23** — too many |
| **proposed** | **quadratic** | 2 / 7 / 12 / **16** |

The last row is the target: **~15 level pacts + 15 vigil pacts = ~30 per run**,
comparable to Brotato's ~30 upgrades.

## 5. The power-growth target

This is the number that makes the rest checkable.

Enemy pressure rises **16x** under the proposal (23 → 377 HP/s). So player
power must rise about the same, split roughly **7x damage and 2x effective
survivability**. Across ~30 pacts that is an average of **~8% effective power
per pact**.

Two consequences:

- **Flat bonuses decay.** `+6 damage` is +23% at vigil 1 and +2% at vigil 15.
  Flat pacts belong in tier 1 and should mostly be early-game filler.
- **Multiplicative pacts are the backbone**, but `+30% damage` compounds far
  past 8%. Tier 3 pacts should be rare, not merely strong.

## 6. The perk pool

27 pacts today, all equal weight. Proposal: **three tiers**, offered by weighted
roll, with better tiers becoming likelier as the run goes on (Brotato ties this
to Luck; we add a Luck-alike below).

| Tier | Name | Weight at vigil 1 | Weight at vigil 15 | Feel |
|---|---|---|---|---|
| 1 | Common | 70% | 25% | small, always useful |
| 2 | Grim | 27% | 50% | a real multiplier |
| 3 | Damned | 3% | 25% | changes how the run plays |

### Existing 27, tiered

**Tier 1 — Common (11):** Blood Price, Grave Vigour, The Long Stare, Swift
Judgment, Iron Bargain, Grave Plate, Dried Sinew, The Lingering Word, The
Lodestone, Candleflame, Rotwort

**Tier 2 — Grim (11):** Fevered Hands, Fleet Dread, The Whetstone, Swollen
Heart, The Empty Psalter, The Wide Censer, Carrion Wings, Grave Wisdom,
Gluttony, The Watcher's Eye, Ashen Skin

**Tier 3 — Damned (5):** The Hungering Dark, A Thousand Cuts, Split Tongue,
Second Breath, Widow's Gift

### New axes worth adding (8 pacts)

Brotato's most interesting stats that we simply do not have:

| Pact | Tier | Effect | New stat needed |
|---|---|---|---|
| The Sure Cut | 2 | +12% critical chance | `crit_chance` |
| Executioner's Eye | 2 | +60% critical damage | `crit_mult` |
| Smoke and Ash | 2 | +8% dodge (hard cap 60%) | `dodge` |
| The Long Shadow | 1 | +10% dodge but −5% move speed | `dodge` |
| Boneshear | 3 | +1 piercing on every projectile | `pierce_bonus` |
| Ricochet Psalm | 3 | +1 bounce on every projectile | `bounce_bonus` |
| Black Fortune | 2 | +1 Luck: better pact tiers | `luck` |
| The Iron Wind | 1 | +knockback on hit | `knockback` |

**Crit and dodge are the two most valuable additions.** Crit adds variance to
damage, which is what makes a build feel like it is doing something; dodge is
Brotato's strongest defensive stat and we have no percentage defence at all
(armour is flat, damage reduction is a plain multiplier).

That gives **35 pacts**: 13 tier 1, 15 tier 2, 7 tier 3.

## 7. Rollout order

Do these one at a time, run `tools/balance_sim.gd` after each, and play it.

1. **Wave-length ramp + spawn-interval floor.** Biggest single fix, two
   constants. Section 4's table is the expected result.
2. **Quadratic XP + deferred level-ups + free +1 max HP.** Changes pacing, not
   power.
3. **Tiers and weighted offers.** Needs a `tier` field on every pact and a
   weighted roll in `_open_pact_screen`.
4. **Crit and dodge.** New stats in `player.gd`, four new pacts.
5. **Pierce/bounce/luck/knockback.** The remaining four.
6. **Re-tune tier 3 against the 8%-per-pact target** using the sim.

Step 1 alone should be tried before anything else — it may fix more than it
looks like on paper.

## 8. Levers deliberately not pulled

Recorded so they are choices rather than oversights:

- **Item downsides.** Brotato's own items frequently carry them, and this game
  used to be built on them. Removed by decision. If runs ever feel like they
  have no texture, a small number of tier-3 pacts carrying a real cost is the
  cheapest way to get it back — without returning to costs on everything.
- **Materials and a shop.** Section 3.
- **Enemy variety.** The single biggest missing thing, and it is not a balance
  problem — it is Milestone 2. One enemy type means one answer to every vigil.
  No amount of curve tuning fixes that.

## 9. How to check any of this

`tools/balance_sim.gd` already prints per-vigil stats and a full pact sweep. It
should be extended to print the **HP/sec pressure table** in section 4 next to
**player DPS**, so the two curves can be read against each other. That ratio —
player DPS over incoming HP/sec — is the one number that says whether a run is
winnable, and right now nothing reports it.


---

## 10. Measured after steps 1-2 and the enemy roster

Sections 1-4 were written when every enemy was a bat. Five archetypes with very
different HP changed the picture, so here is what the build actually does now.

| Vigil | Length | Interval | Spawned | Avg enemy HP | **HP/sec** | Motes dropped |
|---|---|---|---|---|---|---|
| 1 | 20s | 0.57 | 35 | 13 | **23** | 35 |
| 5 | 40s | 0.46 | 87 | 32 | **69** | 117 |
| 10 | 60s | 0.32 | 188 | 79 | **247** | 389 |
| 15 | 60s | 0.22 | 273 | 112 | **511** | 566 |

**The roster put the pressure back.** The plan predicted 377 HP/sec at vigil 15
for a bat-only game; tanks and elites carry far more health, so the real figure
is 511 — a 22x climb, close to the 24x that made the old build unwinnable.

**But it is not the same situation, because the economy scales with it.** An
Abomination is worth 5 motes and a NightBorne 10, against a bat's 1. Killing
harder things pays for the tools to kill harder things:

- ~4200 motes over a full run
- level 2 / 7 / 14 / **20** after vigils 1 / 5 / 10 / 15
- **~19 level pacts + 15 vigil pacts = 34 a run** (the plan targeted ~30)

At the 8%-per-pact target from section 5, 34 pacts is 1.08^34 = **14x** power
growth, against 22x pressure. That is close enough to sit right at the edge: a
good build clears vigil 15, a scattered one dies around 12. That is the shape
you want, and it is the first time these two curves have been in the same
league.

**Watch:** if runs still end too early, the cheapest lever is the tank/elite
spawn weights (`EnemyKinds.SPAWNS`), not the pact numbers. Weight moves both
pressure and income together, which keeps the ratio honest.

### Mote drops are consolidated

A vigil-15 kill count of ~273 was worth ~570 individual motes. That is a lot of
nodes on the floor, so a drop is now split across **at most 4 motes** carrying
the value between them, and a mote worth more is drawn bigger. The economy is
unchanged; the clutter is not.


---

## 11. Steps 3-6, and what measuring them changed

### Tier colours

Common **grey-white**, Grim **green**, Damned **orange** — the loot convention.
The first attempt used ash-grey / bone-white / blood-red, which failed twice
over: grey and bone are barely distinguishable, and Damned red read as the
"something is hurting you" colour used everywhere else on screen. Rarity now
drives the name, the badge, the left spine and a background wash that deepens
with tier, plus a glow on Damned.

This is the second deliberate exception to the three-hue palette rule, recorded
alongside the soul motes in `palette.gd`.

### Tiers behave

35 pacts across three tiers, rolled by tier and then within it. Rolling from
the flat pool would have made a Damned pact no rarer than a Common one --
rarity has to live in the roll, not in how many of each exist.

| Situation | Common | Grim | Damned |
|---|---|---|---|
| vigil 1 | 72% | 26% | 2% |
| vigil 8 | 45% | 39% | 16% |
| vigil 15 | 25% | 49% | 26% |
| vigil 15, Luck 3 | 14% | 54% | 32% |

### New stats, verified rather than assumed

- **Dodge** set to 30% dodged 31% of 2000 blows; set to 95% it dodged exactly
  60%, the cap holding.
- **Crit** at 25% chance and x2.0 produced 24.8% crits and +25% average damage.
- **Knockback** of 200 shoved an enemy 35px before the push decayed.

### The tuning pass, and why the first read was wrong

The projection first ran with **random** pact picks and showed the player
falling behind everywhere (ratio 0.64 at vigil 10). Read alone, that says the
pool is too weak.

Adding a **greedy** run -- always take the rarest offer, standing in for a
player who knows what they are doing -- showed the opposite:

| | vigil 1 | 5 | 10 | 15 |
|---|---|---|---|---|
| random | 1.04 | 0.97 | 0.64 | 0.71 |
| **greedy, before tuning** | 1.13 | 1.67 | 3.20 | **7.78** |

Nearly **8x more damage than the arena needs**, and a 10x spread between good
and bad play. Tier 3 was doing all the work, exactly as section 5 warned. One
number to measure the pool by is not enough: you need the floor *and* the
ceiling, or a pool that is simultaneously too weak and far too strong looks
merely "about right".

Changes made:

- Extra projectiles now **split** the shot -- each beyond the weapon's own
  carries 80% damage. Two shots is 1.6x one, not 2x, and they still hit two
  different enemies. Split Tongue was multiplying total output outright.
- A Thousand Cuts 1.60 -> 1.30, The Hungering Dark 1.25 -> 1.18,
  Executioner's Eye +0.6 -> +0.35 crit damage.
- Tier 2 was cut alongside tier 3 in the first attempt, which dropped random
  play to 0.34 -- unplayable. Restored and slightly raised, since tier 2 is
  what non-optimal play actually accumulates.
- The flat damage pacts were lifted (Blood Price 6 -> 9, Widow's Gift
  12 -> 16), since flat bonuses decay hardest and those are tier-1 filler.

Where it landed:

| | vigil 1 | 5 | 10 | 15 |
|---|---|---|---|---|
| random | 1.02 | 0.95 | 0.56 | 0.56 |
| greedy | 1.16 | 1.60 | 1.44 | **2.04** |

A 3.6x spread instead of 10x: build quality decides a run without being the
only thing that matters, and skilled play clears without walking over it. Note
the ratio counts **single-target damage only** -- piercing, bouncing, melee
arcs and the fact you need only survive rather than kill everything all sit on
top of it.

### Still crooked: the vigil-10 dip

Both curves sag around vigil 10 and recover by 15. Difficulty should climb, not
peak in the middle and subside.

Part of it was a step change -- Abomination and NightBorne used to arrive at
full weight, stepping average enemy health up all at once. Spawn weights now
**ramp in over several vigils** (`EnemyKinds.SPAWNS`), which lifted vigil 5 from
0.93 to 0.97 and vigil 10 from 0.63 to 0.68.

The rest is structural: pressure grows roughly linearly while player power
compounds, so they cross awkwardly in the middle. Fixing it properly means
either front-loading player power or bending the pressure curve. **This is the
next tuning target**, and `tools/balance_sim.gd` now measures it directly, so
it can be iterated instead of guessed at.


---

## 12. What meta-progression will do to all of this

[META.md](META.md) sets a **+90%** power ceiling for a fully-upgraded character.
Everything measured above assumes a fresh one.

At +90% the greedy column moves from 1.16 / 1.60 / 1.44 / 2.04 to roughly
2.2 / 3.0 / 2.7 / 3.9 — a maxed character walks the first two thirds of a run.

The answer is **Danger tiers**, planned in META.md section 7: enemy health
x1.25 per tier, cumulative. Danger 2 (x1.56) puts a maxed character back at
about the difficulty a fresh one meets at Danger 0, which is exactly the curve
this document tuned.

Two things follow for this file:

- The projection needs a **third row: fully upgraded**, so the ceiling is
  measured rather than asserted.
- The pressure table needs a **Danger multiplier**, so the ratio can be read at
  each tier rather than only at Danger 0.

## 13. The difficulty pass — three-hit enemies, and what it cost

Six pieces of play feedback drove this: enemies died in one shot, the character
started too fast, Damned pacts came constantly, the frame rate seemed to sag
around vigil 12, and every projectile flew at the same enemy. Two of them turned
out to be different problems than they looked.

### One-shotting was never an HP problem

A vigil-1 Nightwing had 13 health against a 29 damage Cinder — **55% of every
shot thrown away**. But the Necromancer fires at 0.75 shots/sec for 19.5 DPS,
and vigil 1 spawns ~35 enemies in 20 seconds. The game was survivable *because*
of one-shotting. Raising health alone would have presented 122 health/sec
against 19.5 DPS.

So health and spawn rate moved together. Bases rose ~5x, pinned by the rule that
a vigil-1 Nightwing must take exactly three Cinder hits (59–87 health, so 80).
Spawn interval went 0.60 → 2.40 with the floor at 0.66 and the ramp at 0.12.

**A first attempt raised only the bases and got the shape wrong**: vigil 1 became
much harder while vigil 15 got slightly *easier*, because shallow per-wave slopes
flattened the whole curve. The slopes then doubled too. The lesson is that base
and slope are not interchangeable — the base sets how the opening feels, the
slope is the entire difficulty curve.

| greedy pact picking | before | after |
|---|---|---|
| vigil 1 | 1.12 | 0.69 |
| vigil 5 | 1.38 | 0.95 |
| vigil 10 | 1.38 | 1.00 |
| vigil 15 | 2.10 | 1.03 |

About 1.5x harder throughout, and it now **climbs** rather than easing off at the
end. A good player sits near break-even for the back half of a run, which is the
tension the curve should have.

Rewards rose ~3x per kill to hold the XP and gold curves against ~3x fewer kills
(pacts taken across a run: 34.6 → 33.3, so the economy survived intact).

### The metric was lying

The old pressure ratio compared arena health/sec against raw DPS and **silently
ignored overkill** — the exact thing being fixed. It scored a character throwing
away half its damage at full value. `_clear_rate()` now reports waste directly:

| | before | after |
|---|---|---|
| Necromancer, vigil 1 | ~55% wasted | 8% |
| Necromancer, vigil 10 | — | 4% |
| Vessel, vigil 10 | — | 0% |

Same class of mistake as reading the random projection without the greedy one.

### A card is not a screen

Damned sat at 26% **per card**, and with four cards offered that put one on
**seven screens in ten**. Tuning the per-card number in isolation is how it got
there. `_tier_check()` now prints both.

| | per card | ≥1 per screen |
|---|---|---|
| vigil 1 | 3% → 1% | 8% → **5%** |
| vigil 15 | 26% → 8% | 70% → **30%** |
| vigil 15, Luck 3 | 32% → 12% | 78% → **41%** |

Luck's pull now leans on Grim rather than Damned (0.7/0.3 → 0.30/0.70).

### The frame rate report was real

`tools/perf_probe.gd` runs real vigils and measures. The first version stood
still, got swarmed, died, and spent the run measuring the death screen — which
reported the late game as *cheaper* than the early game. With an unkillable
kiting player it found the real thing: cost tracked enemy count, and the field
reached ~200 enemies because the player killed only 65 of 227 spawned.

**The orb hypothesis was wrong.** Motes never accumulated past ~30, because the
kill rate was too low to produce them. The cost was enemies redrawing.

| vigil | mean before | mean after | enemies before | after |
|---|---|---|---|---|
| 1 | 1.73 ms | 0.69 ms | 21 | 7 |
| 6 | 2.15 ms | 0.79 ms | 61 | 19 |
| 12 | 2.81 ms | **0.95 ms** | 161 | 42 |
| 15 | 2.65 ms | 1.27 ms | 197 | 75 |

Three things did it, in order of size:

1. **Enemies redrew 60 times a second** for an animation running at ~10fps.
   Moving a Node2D does not need a redraw — the renderer reapplies the transform
   to the command list it already has. Only a new frame, a flip or the hurt tint
   changing owes one.
2. **The dungeon redrew the whole floor every frame** and re-culled ~1,500
   tiles, rubble and cracks each time, to animate brazier light that breathes
   slowly. The cull is now cached until the view moves a tile, and the flicker
   runs at 20Hz.
3. **Motes and coins redrew off-screen.** An invisible CanvasItem skips `_draw`
   entirely; the twinkle is stepped and staggered by each mote's random phase so
   the saving does not turn into a synchronised spike.

Also: `_nearest_enemies` built a Dictionary per enemy and sorted the whole list
to pick one target, several times a second against ~200 enemies. It is now a
fixed-size insertion with no allocation.

### Bolts no longer converge

`_fire_ranged` ran per bolt, and each call independently asked for the nearest
enemy starting at index 0 — so every bolt got the same one, and unlocking more
made it worse. Enemies now carry `incoming` (damage already in flight) and
targeting prefers, in order: something nobody has shot at, something not already
dead on arrival, then anything.

**Overkill prevention alone was not enough**, and this nearly shipped. Once
enemies take three hits, one bolt's damage no longer covers one, so nothing is
ever "already dead" and the bolts converged again. The tougher enemies silently
undid the targeting fix. It was caught by `tools/targeting_check.gd` flaking
between runs — preferring *untouched* targets is what actually spreads them.

## 14. Brotato's actual numbers, and three formulas that were wrong

This game was built "Brotato-shaped" from memory. Reading Brotato's real
formulas found three places where the *shape* of a formula was wrong — not
tuning disagreements, but maths that misbehaves at the edges.

### The reference numbers

| System | Brotato | here, before |
|---|---|---|
| Armour | `1 / (1 + armour/15)` multiplier | `max(1, dmg − armour)` |
| % stats | stack **additively** | stacked multiplicatively |
| Enemies alive | hard cap 100, one culled on overflow | uncapped |
| XP to level | `(level+4)²` | `(level+3)²` — same curve |
| Wave length | 20 + 5/wave, cap 60 | identical |
| Dodge cap | 60% | 60% |
| Tier roll | min wave, linear ramp, hard cap, luck as multiplier | EARLY→LATE weight blend |
| Legendary | 1.4%/item at wave 15, impossible before wave 8 | 8%/card, possible at vigil 1 |
| Reroll | `floor(w×0.75) + floor(0.4×w)`, escalating | none |
| Shop price | `(base + w + base×0.1×w)` | Chapel prices are flat |

Brotato's tier table, which section 2 of this pass copied wholesale:

| Tier | Min wave | Base | Per wave | Max |
|---|---|---|---|---|
| 2 | 2 | 0% | 6% | 60% |
| 3 | 4 | 0% | 2% | 25% |
| 4 | 8 | 0% | 0.23% | 8% |

Rolled highest-first as independent checks — not a distribution summing to 100.

### Armour was worthless, then total

Flat subtraction has a cliff: at armour ≥ incoming damage every hit lands for
exactly 1. The multiplier form trades a diminishing *displayed* percentage for a
constant gain in damage absorbed, and the sim now checks that constant directly:

| armour | damage taken | effective HP | gain per point |
|---|---|---|---|
| 0 | 100% | 85 | — |
| 1 | 93.8% | 91 | 6.67% |
| 10 | 60.0% | 142 | 6.67% |
| 40 | 27.3% | 312 | 6.67% |

If that last column ever drifts, the formula has been broken.

### Percentages compounded, and the cap was load-bearing

`fire_rate_mult *= 1.25` three times is 1.95x, not 1.75x. Compounding is why a
build that stacked one axis ran away from a build that spread, and why
`MAX_FIRE_RATE` existed at all. Every percentage is now a bonus fraction applied
as `(1 + x)`. Swearing **every** attack-speed pact to its stack limit now reaches
+414% — 3.85 shots/sec against a 15.0 rail, so the rail is a backstop again
rather than a design element. The sim asserts this.

Percentage VALUES then had to rise ~1.7x, because percentages that add must be
larger than percentages that compound to reach the same place. Brotato's item
percentages are large (+30%, +50%) for exactly this reason.

### The enemy curve was correct against a player who no longer exists

**This is the part worth remembering.** Removing compounding took about a third
off late-run player damage. The enemy health slopes had been doubled earlier in
the same session, tuned against the *inflated* figure — so after the maths fix
the run became unclearable (greedy ratio 0.36 at vigil 15 against a target of
1.0). The slopes came back down by nearly half.

An enemy curve is meaningless on its own. It is only ever correct relative to a
specific player-power curve, and changing one silently invalidates the other.
The plan for this pass said to make the slopes *steeper*; the sim said the
opposite, and the sim was right.

| greedy pact picking | before this pass | after |
|---|---|---|
| vigil 1 | 0.69 | 0.78 |
| vigil 5 | 0.95 | 1.15 |
| vigil 10 | 1.00 | 1.00 |
| vigil 15 | 1.03 | 1.00 |

Greedy-vs-random spread at vigil 15 fell from 2.98x to 2.70x. A player who picks
well still ends up meaningfully stronger — they just no longer trivialise the
game.

### Rarity is gated, not merely unlikely

Damned is now **impossible before vigil 8** rather than a 1% roll available from
the start. A first Damned has a known earliest moment instead of arriving at
random and meaning nothing.

| vigil | Common | Grim | Damned | ≥1 Damned per screen |
|---|---|---|---|---|
| 1 | 100% | 0% | 0% | 0% |
| 7 | 76% | 24% | 0% | 0% |
| 8 | 72% | 27% | 1% | 4% |
| 15 | 53% | 40% | 8% | 26% |
| 15, luck 3 | 48% | 40% | 12% | 42% |

### Two things Brotato has that this did not

**Vigil kinds.** Every vigil was previously identical except its numbers, which
is the main reason a run stopped surprising anyone halfway through. Vigils 8, 11
and 14 are now a Horde or an Elite (Brotato's own 40/60 split), rolled fresh each
run. They are not harder vigils, they are different ones, and each rewards the
build the other punishes.

| at vigil 11 | health | spawn interval |
|---|---|---|
| NORMAL | 146 | one every 1.08s |
| HORDE | 58 | one every 0.36s |
| ELITE | 380 | one every 3.09s |

**Reroll.** "None of these four help me" had no answer. Brotato's escalating
cost — at vigil 12: 9 gold, then 13, then 17 — paid from the Chapel purse, so
rerolling this run costs every run after it. A cursed chest cannot be rerolled;
spinning a boss reward would make the thing you killed a slot machine.

### Also fixed

Enemies are capped at 90 alive, culling the oldest non-boss on overflow — a cull
pays nothing, since paying out for something the game removed for its own
convenience would make the cap an income source. Measured peak is now 60 at
vigil 15 (was 197), and frame cost fell from 1.27ms to 1.08ms.
