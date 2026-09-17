# Dark fantasy arena roguelite — development plan

Working title: **Bombom** (placeholder). Candidates: *Tithe*, *Blackwake*, *The
Long Vigil*, *Carrion Vigil*.

**Current state of the build: [STATUS.md](STATUS.md).**

---

## 1. The pitch

You are a damned soul held in a ruined chapel, besieged in waves by the things
that live in the dark. You cannot win by strength alone. Between each assault a
voice offers you power — and it always wants something back.

Mechanically this is Brotato: one arena, one screen, auto-attacking, wave timer,
upgrade between waves. The dark fantasy is not a paint job; it lives in **how
upgrades work**.

## 2. The one hook

**Every upgrade is a pact: a boon paired with a bane.**

Brotato's shop gives you strictly good things. Here, the shop gives you a
choice of four *bargains*, each with an upside and a cost.

| Pact | Boon | Bane |
|---|---|---|
| Blood Price | +40% damage | Lose 5 max HP per wave |
| Hollow Speed | +25% move speed | −20% attack range |
| Gluttony | Heal 10 on kill | Enemies gain +15% HP |
| The Long Stare | See enemy health bars | Attack range circle no longer shown |
| Iron Bargain | +50 max HP | −15% fire rate |

This single change does a lot of work:

- It makes the shop a **decision** instead of a reward. That is the whole game.
- It fits the theme exactly, so theme and mechanics reinforce each other.
- It is **one system**, not ten. Scope stays small.

Second-order effect to build on top (Milestone 3): **Corruption**. Each pact
adds Corruption. At thresholds (5 / 10 / 15) every enemy gains a permanent
modifier — faster, tougher, splits on death. Now taking power is *visibly*
making the world worse, and the tension compounds across a run.

## 3. Scope: what is explicitly NOT in v1

Write this down and defend it. Each line is a project that has killed someone
else's first game.

- No multiplayer of any kind
- No procedural rooms or floors (that is an Isaac-like — a different, bigger game)
- No dialogue, cutscenes, or story mode
- No crafting, no inventory grid, no equipment slots
- No NPC hub or town
- No 3D, no lighting engine, no shaders beyond a hit-flash
- No console or mobile ports

## 4. Milestones

Each milestone ends in something playable. Do not start the next until the
current one is *played* and it feels better than the one before.

| # | Milestone | Done when | Est. (10–15 hrs/wk) |
|---|---|---|---|
| 0 | ~~**Reskin**~~ **DONE** | The existing prototype uses the dark palette and dark-fantasy names. No new systems. | 1 evening |
| 1 | ~~**Pacts**~~ **DONE** | Shop offers 4 pacts with boon + bane; 12 pacts exist; banes actually apply. | 1 week |
| 2 | ~~**Enemy roster**~~ **DONE** | 5 archetypes: swarm, rusher, ranged, tank, elite. Each visually distinct at a glance. | 1–2 weeks |
| 3 | **Corruption** | Corruption meter, 3 thresholds, enemy modifiers, HUD display. | 1 week |
| 4 | **Juice pass** | Hit flash, screen shake, damage numbers, death burst, 8–10 sound effects, one music loop. | 1–2 weeks |
| 5 | **Run structure** | 15 waves, bosses at 5/10/15, win screen, death screen with a run summary. | 2 weeks |
| 6 | **Meta** | Per-character permanent upgrades funded by run payouts. Save file. **Planned in [META.md](META.md)** | 2–3 weeks |
| 7 | **Shippable** | Menus, options, key rebinding, pause, Steam page, trailer. | Open-ended |

**Milestones 0–4 are the vertical slice: ~6–8 weeks.** If it is not fun at the
end of Milestone 4, do not continue to 5 — fix 1–4 or stop. That decision point
is the most valuable thing in this document.

## 5. Content targets — keep them small

Deliberately low numbers. Brotato launched into Early Access with a fraction of
what it has now.

| | v1 target | Not now |
|---|---|---|
| Pacts | 20 (**25 built**) | 120 |
| Enemy types | 4 + 3 bosses | 20 |
| Playable classes | 3 | 15 |
| Arenas | 1 | 6 |
| Weapons | 4 | 40 |

Twenty pacts that interact with each other beat a hundred that do not. When
designing a new pact, ask: *does this change how I play, or just how big a
number is?* If it is the second, it is filler.

## 6. Art and audio

**Stay on colored shapes through Milestone 3.** No exceptions. Art before the
game is fun is the most common way solo projects die.

Dark fantasy is the cheapest possible theme for a programmer doing their own
art, and you should exploit that deliberately:

- **Near-black background.** Darkness hides everything you cannot draw.
- **Silhouettes with rim light.** Enemies as black shapes with a single
  colored edge read instantly and require no interior detail.
- **Three colors, total.** Near-black, one desaturated mid-tone (ash grey,
  cold green), one hot accent (blood red or sickly gold) used *only* for
  danger and pacts.
- **Particles do the heavy lifting.** Embers, ash, fog. Cheap to make, and
  motion sells atmosphere better than sprite detail.

At Milestone 4, decide once: free/paid asset packs (itch.io, Kenney) or commit
to the silhouette style yourself. Do not mix — inconsistent art looks worse
than crude consistent art.

Audio: one ambient drone loop, one combat loop, ~10 SFX. Freesound and itch.io
audio packs are fine. Sound is roughly 40% of "game feel" and costs a fraction
of what art does — do not skip it.

## 7. Balance targets

Write the intended numbers down *before* tuning, so you can tell when you are
off.

- Run length: **8–12 minutes** (15 waves × ~25s + shop time)
- First-time players should die around **wave 6–9**
- A competent run should end with **8–12 pacts** taken
- Enemy count on screen: **peaks around 60–80** by wave 15
- Time-to-kill on a basic enemy: **1–2 shots at wave 1, 3–4 at wave 15**
  (if this climbs, the player is losing the power race — that is the single
  most important balance ratio in the game)

## 8. Risks and traps

| Risk | Mitigation |
|---|---|
| Banes feel purely punishing, so players never take pacts | Boon must feel *stronger* than the bane hurts, early on. Front-load generosity. |
| Scope creep toward an Isaac-like | Section 3 is the contract. Rooms are v2 or never. |
| Art pass starts too early | Hard rule: no art before Milestone 4. |
| Building meta-progression to paper over a boring core | Milestone 6 is last for a reason. |
| Tutorial hell / not shipping | Ship Milestone 4 to 3 friends. Watch someone else play it. |
| Motivation collapse around week 5 | This is normal and expected. Milestone 4 (juice) is placed exactly there because it is the most rewarding week of work in the project. |

## 9. Decisions made

### Banes removed (design pivot)

**Pacts no longer carry a cost.** Every bane -- compounding and static -- was
deleted; pacts are now pure upgrades. This reverses section 2, which is kept
above as the record of what the game used to be.

The consequence to watch: difficulty now comes from **one dial only**, the
per-vigil enemy curve in `enemy_kinds.gd` plus spawn pacing. There is no longer
a second force pulling against the player's power, so the enemy curve has to do
all the work the banes used to do. Expect runs to feel easy until that curve is
re-tuned.

The measurement that shows it: swearing all 25 pacts now leaves `ehp`, `espd`
and `srate` at exactly 1.00, where they previously spiralled.

- **Refusing a pact: not allowed.** One of the four offers always comes home
  with you. Watch for the failure case this creates — four offers that are all
  wrong for your build feels unfair, so the offer pool must stay varied.
- **Boons win early, banes bite late.** Implemented as a single design rule:
  *boons are immediate and flat, banes compound every vigil.* This means new
  pacts do not each need their own timing curve — the rule handles it.
- **Corruption: hooked, not wired.** Every pact carries a corruption weight and
  the run totals it, but nothing reads it yet. Milestone 3 stays fully open.

### Learned from the balance sim (Milestone 1)

- **Banes must be percentages, never flat amounts.** Flat costs stop hurting
  once they hit a floor, which converts the pact into free power. Widow's Gift
  reached +190 damage at zero cost before this was fixed.
- **Pacts must cap at a few stacks** (currently 3). Uncapped, stacking one pact
  is always optimal — A Thousand Cuts reached 2305 shots/second — and the run
  stops being a sequence of decisions.
- Any stat that multiplies needs a hard rail. `fire_rate` clamps at 15/sec on
  assignment.

### Weapons (decided, built ahead of schedule)

Weapons **are** a separate axis from pacts. You choose one before the first
vigil and gain another at vigils 5 and 10, to a maximum of 3.

This forced a refactor worth knowing about: pacts no longer set absolute player
stats, they set **modifiers** (`damage_bonus`, `damage_mult`, `fire_rate_mult`,
`range_bonus`, ...) which every weapon reads through `Player.effective_*`.
Without that, "+6 damage" would mean something wildly different on a 9-damage
blade than on a 26-damage cane.

Bar for a new weapon: **it must change where you stand.** Four weapons that
change your position are content; forty that change a number are filler.

### On borrowing from other survivors-likes

Stat categories — damage, area, cooldown, projectile count, duration, regen —
are shared genre vocabulary and free to use. Names are the creative part, so
ours are written fresh.

The rule when importing an idea from another game: **it has to arrive as a
pact.** A pure-upside buff bolted on beside the pact system would quietly
dissolve the one thing that makes this game not-Brotato. If an idea cannot be
given an honest cost, it does not belong in this game.

## 10. Scenes: the migration owed

The project was bootstrapped code-only -- one scene, one node, everything else
constructed at runtime. That was a deliberate trade (a code-only project is
guaranteed to open and run without anyone seeing the editor) and it has now
expired. It is **not** how Godot is meant to be used, and the cost is real:
hand-rolled sprite animation where `AnimatedSprite2D` exists, hand-rolled
circle collision where `Area2D` exists, and a hand-rolled UI layout engine
(`_card_rect`, `_text_fit`, manual hit-testing) where `Control` exists.

Migrate in this order, one step at a time, playing after each:

| # | Move | Why it is worth it | Risk |
|---|---|---|---|
| 1 | **Menus & UI -> Control nodes** | Focus, keyboard nav, theming, layout for free. Deletes the most code. | low -- **done for the menu** |
| 2 | Character-select & pact screens -> Control | Same again; removes `_card_rect` / `_text_fit` / hover plumbing entirely | medium |
| 3 | Player / Enemy / Bullet -> `.tscn` with `AnimatedSprite2D` | Visual editing, and the editor becomes useful | medium |
| 4 | Collision -> `Area2D` | Only if the circle math starts to hurt. It is simple, fast and testable today | low value |

**Keep as code**: `pacts.gd`, `characters.gd`, `enemy_kinds.gd`, `palette.gd`.
Data belongs in data files, not in scenes.

Who does what: scenes are worth having because *you* can drag things around in
the editor and see the result. Scaffolding them in text is fine; the value only
arrives when they are edited visually. So the useful split is scaffold-then-edit,
not scaffold-and-never-open.

## 11. Meta-progression

Planned in **[META.md](META.md)**: a shared gold wallet, per-character upgrade
trees, and character unlocks.

The consequence worth carrying here: the chosen power ceiling is **+90%** for a
fully-upgraded character, and BALANCE.md tuned a run to a damage ratio of
1.0-2.0. Roughly doubling the player's side takes that to 2-4. **Danger tiers
are therefore part of Milestone 6, not a later nicety** — without them the
balance work stops holding the moment a first tree is finished.

## 12. Balance

Numbers, the XP curve and the perk pool now live in their own document:
**[BALANCE.md](BALANCE.md)**. Headline finding: with the debuffs gone, enemy
pressure rises 24x across a run while nothing in the pact pool multiplies power
anywhere near that, so a run becomes arithmetically unwinnable around vigil
10-12. The fix is Brotato's wave-length ramp, not a bigger number somewhere.

## 13. Still open

- Is Corruption purely a downside, or does high Corruption unlock the strongest
  pacts (risk/reward)?
- Does the player choose a class before the run, or discover one during it?
- Should `VIGIL_SURVIVAL_HEAL` be 0, making pacts the only source of healing?

---

**Next action:** Milestone 0. Change the palette and the names in the existing
prototype. One evening. Then play it.
