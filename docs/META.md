# Meta-progression plan — what carries between runs

Milestone 6. Gold earned in runs, spent between them on **per-character**
upgrade trees and on unlocking new characters.

**Status: steps 1 and 2 of section 11 are built** — coins are collected and
banked, and THE CHAPEL spends them on per-character upgrades. Steps 3-5 (the
deferred nodes, Danger tiers, character unlocks) are still a plan.

Decisions taken (section 10 records what they cost):

| Question | Answer |
|---|---|
| Currency | **Gold with prices**, **dropped by chance and collected in the run** |
| Power ceiling | **+80-100%** for a fully-upgraded character |
| Unlocks | **Yes — new characters, as well as stats** |

---

## 1. The shape

```
during the run: enemies drop coins, you pick them up
        |
run ends (died, or cleared vigil 15)
        |
   you keep exactly what you touched
        |
   THE CHAPEL: spend it
        |-- deepen: a node on one character's tree
        |-- broaden: unlock a new character
        |
   next run
```

Gold is **one shared wallet**; the trees it buys are **per character**. That is
the interesting shape: every coin is a choice between making the character you
like better, or opening up one you have never played. A per-character wallet
would remove that decision, and would punish you for wanting to try someone new.

## 2. Gold is collected, not awarded

**Coins drop where enemies die and you have to go and get them.** A run-end
formula would make gold a passive reward for surviving; collecting it makes it
a decision — chase that pile into the swarm, or let it go.

Two rules make that decision real:

- **Gold banks the instant you touch it.** Die a second later and you still
  have it. Your take-home is exactly what you picked up.
- **Coins left on the floor when a vigil ends are lost.** Otherwise collection
  is free and "collected in runs" means nothing.

This is deliberately different from soul motes, which *are* swept up at the end
of a vigil. Motes are your progress *this* run; gold is what you carry out. To
keep the two from being confused they differ in colour, shape and motion —
section 3.

### Gold drops by chance, not by rule

Most things that die leave nothing. A coin is a **moment**, not a trickle —
and a swarm enemy paying out reliably would turn gold into a second XP bar.

| Archetype | Chance | Coin | Expected per kill |
|---|---|---|---|
| Nightwing (swarm) | 12% | 1 | 0.12 |
| Catto (rusher) | 14% | 1 | 0.14 |
| Hollow Mage (ranged) | 25% | 2 | 0.50 |
| Abomination (tank) | 55% | 4 | 2.19 |
| NightBorne (elite) | **100%** | 9 | 9.00 |

Measured over 4000 kills each: 12% / 25% / 55% / 100%, exactly the table.

The elite is the only certainty, and it is the payday. That creates a second
question every time one appears: **is this worth fighting, or worth avoiding?**
Right now the only answer is "kill it or die" — with a guaranteed 26 gold on
it, walking away has a price.

Coins are sparse by design — about **4 in vigil 1 and 62 in vigil 15**, against
35 and 273 kills. Every one is an event.

### Luck decides how much of it you see

Luck already exists and does exactly one thing: shift pact tier weights. This
gives it its second job, which is what Luck does in Brotato.

```
raw    = base_chance x (1 + 0.14 x luck)
chance = min(1, raw)
value  = coin x max(1, raw)      # the overflow past 100% becomes value
```

**Luck first buys you more drops, then bigger ones.** That overflow rule
matters: without it, Luck would stop doing anything for the NightBorne the
moment its chance hit 100%, and a luck build would quietly cap out.

Black Fortune therefore stops being a niche pact and becomes a real build
choice — it now pays in both rarity and gold.

### What that actually yields

Computed against the live spawn table, vigil lengths and drop table:

| Died at vigil | Luck 0 | Luck 3 | Luck 6 |
|---|---|---|---|
| 3 | ~17 | ~24 | ~31 |
| 5 | ~40 | ~56 | ~73 |
| 8 | ~150 | ~212 | ~275 |
| 10 | ~331 | ~471 | ~610 |
| 12 | ~613 | ~871 | ~1,129 |
| cleared 15 | **~1,208** | ~1,715 | ~2,222 |

**A luck-6 run earns 1.84x a luck-0 one.** Big enough that stacking Luck is a
real strategy, small enough that ignoring it is not a mistake.

The curve is steep on purpose — a deep run is worth many shallow ones — but a
bad run still pays for something.

## 3. Coins, and telling them from motes

Two pickups on the same floor is a UX risk, so they differ on **three** axes at
once, not one:

| | Soul mote | Coin |
|---|---|---|
| Colour | green-gold | **amber** |
| Shape | round, haloed | **flat disc with a dark rim** |
| Motion | pulses and twinkles | **spins** (width squashes to nothing and back) |
| At vigil end | swept up for you | **lost** |

The spin is the strongest signal: a disc turning edge-on is unmistakably a coin
and looks nothing like a pulsing orb, even at a glance in a crowd.

Coins use the **same pickup radius** as motes, so The Lodestone helps both and
collecting is about where you stand rather than pixel-hunting.

## 4. Prices

| Tier | Price | Per character |
|---|---|---|
| Common | 150 | 3 nodes = 450 |
| Grim | 550 | 3 nodes = 1,650 |
| Damned | 1300 | 2 nodes = 2,600 |
| | | **4,700 a tree** |

Raised once already: chests roughly doubled what a run pays (a full clear went
from ~1,200 gold to ~2,200), so prices moved with them to keep a tree at about
two and a half clears.

Unlocking a character: **150** — about four early runs.

Set against the table above: a full tree is **~22 mid-depth runs** (dying
around vigil 8) or a bit under three full clears. The first Common node lands
in your second or third run, so there is always something close enough to
want.

**These prices are provisional**, and now doubly so: they come from a
projection rather than play, and the two numbers a real player diverges from
most are both in this system. Someone who ignores coins to stay alive earns far
less than the table says; someone stacking Luck earns nearly twice it. Chance
drops also mean **two identical runs will pay differently** — that is normal
for loot, but it makes the price table something to set from a hundred runs,
not from arithmetic. Re-measure once it is playable.

## 5. The upgrade trees

This is what makes it character-based rather than a shared stat list. Every
node should say something about **who that character is**. A generic "+5%
damage" node could belong to anyone, and belongs nowhere.

Nine nodes each, over the three tiers already built, reusing the Common / Grim
/ Damned colours from the pact screen.

### The Necromancer — reach, crowds, the things he carries

| Tier | Node | Effect |
|---|---|---|
| Common | Ashen Grip | +4% cane damage |
| Common | Long Practice | +25 reach |
| Common | Second Hand | start each run with the Bound Skull already free |
| Grim | Ember Trail | the Cinder leaves a burn behind it |
| Grim | Heavier Bone | the Skull bounces twice |
| Grim | Patient Dead | +1 mote from every kill |
| Damned | The Third Hand | a third bolt: the staff itself |
| Damned | Bore | every bolt pierces one more |
| Damned | Gravecall | a slain enemy occasionally rises for you |

### The Vessel — standing in it, taking hits

| Tier | Node | Effect |
|---|---|---|
| Common | Set Stance | +10 max health |
| Common | Wider Cut | +15% swing height |
| Common | Kept Edge | start each run with Moonfall already free |
| Grim | Ironhide | +2 armour |
| Grim | Reaping | heal 2 per kill |
| Grim | Follow Through | swings knock back |
| Damned | Both Hands | the cut hits both sides at once |
| Damned | Moonfall Doubles | Moonfall swings twice |
| Damned | The Passenger | at low health, everything slows |

### The Poacher — distance, speed, never being touched

| Tier | Node | Effect |
|---|---|---|
| Common | Steady Hand | +4% bow damage |
| Common | Light Feet | +6% move speed |
| Common | Second Quiver | start each run with Spite already free |
| Grim | Keen Eye | +8% critical chance |
| Grim | Smoke Step | +6% dodge |
| Grim | Long Shot | +40 reach |
| Damned | Split Arrow | +1 projectile, no split penalty |
| Damned | Ghostfoot | brief invulnerability after a dodge |
| Damned | The Long Dark | every third arrow pierces everything |

The "start with X already free" nodes are deliberate: they hand back the
vigil-1 weakness in exchange for a permanent slot, which is a decision rather
than a number.

## 6. Hitting +90% without guessing

Nine nodes reaching +90% total means about **7.4% per node**, compounding. That
gives a budget:

| Tier | Budget per node | Three nodes |
|---|---|---|
| Common | ~+4% | x1.12 |
| Grim | ~+7% | x1.22 |
| Damned | ~+12% | x1.40 |
| | | **x1.94 = +94%** |

Qualitative nodes (Ghostfoot, Gravecall, Second Hand) are not in the numeric
budget — they buy a capability, not a multiplier. That means a tree is a mix,
and the stat nodes carry the arithmetic.

**This is checkable, not hopeful.** `tools/balance_sim.gd` already runs a
projection with random and greedy pact picks; it should gain a third row — a
**fully-upgraded** character — so the ceiling is measured rather than asserted.

## 7. Danger tiers — now required, not optional

At +90%, a maxed character walks vigils 1-8 of the current curve. BALANCE.md
tuned a run to a damage ratio of 1.0-2.0; roughly doubling the player's side
takes it to 2-4 and the tuning stops meaning anything.

So Danger tiers move from "nice later" to **part of this feature**. Brotato
solves exactly this problem the same way.

- Clearing vigil 15 at Danger *n* unlocks Danger *n+1*.
- Each tier: enemy health **x1.25**, enemy damage **x1.15**, spawn rate
  **x1.08**, cumulative.
- Each tier multiplies the gold payout by **1.5x**, so the harder run funds the
  deeper tree.
- Chosen on the character select screen, per run.

The arithmetic works out: a maxed character at **Danger 2** (enemy HP x1.56)
sits back at roughly the difficulty a fresh character faces at Danger 0. So
Danger 0 with a full tree is the victory lap you earned, and Danger 2-3 is
where the real game moves to.

## 8. Unlocking characters

The system is built now; the Poacher is the first thing behind it.

- The Necromancer and the Vessel are available from the start — the two with
  art, and enough to make a real choice on your first run.
- **The Poacher costs 400 gold**, about two runs.
- Locked characters appear on the select screen greyed out, with the price
  shown. Locked doors you can see are motivating; locked doors you cannot are
  just missing content.

Future characters slot into the same list with a price. **If locking the
Poacher feels bad in practice, it is one field to revert** — the system does not
depend on it.

## 9. Persistence, and where it appears

`user://profile.cfg`, the same ConfigFile pattern `settings.gd` already uses:

```
[wallet]
gold = 1240

[necromancer]
owned = ["ashen_grip", "second_hand"]
runs = 14
best_vigil = 11

[unlocked]
characters = ["necromancer", "vessel"]
```

- **Character select** shows each character's owned-node count, and the price
  on locked ones.
- **THE CHAPEL** — two views. First a **portrait picker**: one large card per
  character with an animated portrait, a progress bar and what the rest of
  their tree would cost. Then that character's nodes as cards, priced, greyed
  when unaffordable, in the pact screen's tier colours.
- **Run end** shows the payout breakdown and a prompt to go and spend it.

## 10. What these choices cost

Recorded honestly, since two of them were the more expensive option:

- **Gold instead of levels** buys real agency — save for a Damned node, skip
  the cheap ones — at the cost of a shop screen with prices and affordability
  states. The level model would have reused the pact screen almost as-is.
- **Collected instead of awarded** turns gold into a second thing to play for,
  and gives tanks and elites a reason to exist beyond danger. It costs a second
  pickup type on an already busy floor, and it means a player who plays safely
  earns less than one who plays greedily — which is the point, but it will make
  the price table harder to tune.
- **Chance instead of guaranteed** makes each coin a moment rather than a
  trickle, and hands Luck a real second job. The cost is variance: two runs
  played identically will pay differently, and a player on a cold streak may
  feel the game is stingy rather than random. The elite's guaranteed drop is
  the deliberate floor under that.
- **+90% instead of +35%** makes progression feel substantial, and **forces
  Danger tiers into scope** (section 7). Without them the balance work in
  BALANCE.md stops holding roughly the moment a first tree is finished.
- **Character unlocks** mean a new player starts with two characters instead of
  three. Worth it for the goal it creates, and reversible in one line.

## 11. Build order

1. ~~**Coins + profile persistence + run-end screen.**~~ **DONE.** Coins drop
   on the roll, are collected, bank on touch, are lost if left on the floor at
   a vigil's end, and survive a restart. Luck raises the drop chance and then
   the coin value. `coin.gd`, `profile.gd`, drop table in `enemy_kinds.gd`.
2. ~~**The Chapel screen** and the Common tier of one tree.~~ **DONE, and
   further than planned**: all three characters, eight nodes each, end to end.
   `upgrades.gd`, `chapel.gd`/`chapel.tscn`, purchases in `profile.gd`, and
   `Player.apply_upgrades()` writing the same modifier fields a pact does.
3. **The deferred nodes.** Eight of the 27 planned needed systems that do not
   exist: burning ground (Ember Trail), raising the dead (Gravecall), a third
   bolt (The Third Hand), a double swing (Moonfall Doubles), a slow-time
   trigger (The Passenger), invulnerability windows (Ghostfoot), an every-third
   -shot counter (The Long Dark), both-sides melee (Both Hands). They were left
   out rather than shipped as buttons that do nothing — a tree of eight working
   nodes is a feature, a tree of nine where one lies is not.
4. **Danger tiers.** Do not ship 3 without 4.
5. **Character unlocking.**
6. **Re-measure** with the sim's fully-upgraded row and re-tune.

## 12. Deliberately not in this plan

- **Respec.** Permanent choices are more interesting when they are permanent.
  Add it only if a tree turns out to have a trap node.
- **Achievements or challenges** as a second unlock source.
- **A shared account level** across characters. Everything here is per
  character except the wallet.
- **A separate gold-find pact.** Luck already does this job now. One stat with
  two uses beats two stats with one each.
- **Weapon and bolt unlocks.** The next natural step after characters, but it
  needs new content authored to fill it rather than just a system.
- **Coins surviving death mid-vigil.** They already do — gold banks on touch.
  What is *not* planned is any way to recover coins left on the floor: no
  end-of-vigil sweep, no magnet at the death screen. The loss is the mechanic.
