# Art assets

Every sprite in the project, how it is laid out, and what is wired up. Nothing
here needs licence checking — see [STATUS.md](STATUS.md).

## What is here

| Asset | Files | Layout | Used for |
|---|---|---|---|
| Necromancer | `assets/necromancer.png` | 17 x 7 grid of **160x128** | The Necromancer |
| Moonstone Keeper | `assets/keeper/*.png` | assembled strips, **200x150** | The Vessel |
| Horror Enemy Pack | `assets/foes/catto.png`, `mage.png`, `abomination.png`, `madghost.png` | one animation per **row**; 48x32 / 112x48 / 64x64 | Catto, Hollow Mage, Abomination |
| NightBorne | `assets/foes/nightborne.png` | 23 x 5 grid of **80x80** | The NightBorne elite |
| Dreadknight Rotmaws | `assets/foes/dreadknight/*.png` | assembled strips, **80x96** | The Rotmaw charger |
| Skeleton Knight | `assets/foes/skeleton/*.png` | **170x125** strips | The vigil-5 boss |
| Bat | `assets/bat/*.png` | one PNG per animation, **64x64** strips | The Nightwing swarm |
| Skull | `assets/necro_skull.png` | 10x10 | Bound Skull projectile |
| Flame | `assets/necro_flame.png` | 23x23 | Cinder projectile |
| Sword | `assets/sword.png` | 12 frames of **64x64** | Sever, the thrown blade |
| Cursed Chest | `assets/chest/*.png` | one PNG per animation, **64x64** strips | The boss drop |

## Row maps

**Necromancer** — idle 8, walk 8, cast 13, cast-2 13, summon 17, hurt 5,
death 9. Rows 3 and 4 (cast-2, summon) are **unused** and free for a heavy
attack or a Corruption transformation.

**Horror pack** (rows verified against the pack's own ReadMe):

| Creature | Cell | Rows |
|---|---|---|
| Abomination | 112x48 | idle 4, walk 4, attack 10, hit 2, death 9 |
| Catto | 48x32 | stare 1, stand 2, walk 4, turn 5, sit 2, idle-sit 4, attack 6, hit 2, death 9 |
| Mad Ghost | 64x64 | idle 4, move 4, unsheathe 5, attack 3, sheathe 4, hit 2, death 9 |
| Mage | 112x48 | idle 4, walk 4, attack 10, hit 2, death 9 |

**NightBorne** — idle 9, run 6, attack 12, hurt 5, death 23.

**Dreadknight** — run 17, attack 14, death 10 wired; `run_alt` 13 and `idle` 8
built but unused.

**Skeleton Knight** — walk 9, side_swing 7, hurt 2, death 9 wired; `idle` 11
built but unused. Also in the pack and not imported: DOWN_SWING, FWD_SWING and
a 21-frame FULL_COMBO, which would suit a second boss phase.

**Cursed Chest** — idle 6, opening 7 wired. `cursed_open_empty.png` (7 frames,
the same animation with no gold inside) is imported and **unused**; it would
suit a chest that has already been looted. The body sits at x 17..49, y 17..49
in the cell and the lid bursts upward out of that box, so the pivot is the
middle of the BODY (33, 33) rather than the base — see the note in `chest.gd`.

**Bat** — Run 8, Hurt 5, Die 12 wired; IdleFly 9, Attack1 8, Attack2 11,
Sleep 3, WakeUp 16 unused (`Bat-WakeUp` would suit an enemy that spawns
dormant and rises).

**Mad Ghost is imported but unused.** Its unsheathe / attack / sheathe trio
suits a wind-up attacker, which is a better fit for a future archetype than for
anything on the current roster.

## Sound

`assets/sfx/` holds 16 WAVs, all **derived from six recordings** by
`tools/build_sfx.py`:

```bash
python tools/build_sfx.py
```

The sources are in `assets/sfx_src/` — a coin, an explosion, a hurt, a jump, a
power-up and a tap, from the Brackeys platformer pack. Six sounds for sixteen
slots, so nothing is used verbatim twice: each output is pitched, stretched,
filtered, trimmed, reversed or layered into place. The family resemblance
between the three shot sounds is deliberate; they come from one throat.

This replaced a fully **synthesised** set built from oscillators and envelopes.
That was honest placeholder work and it sounded like it — recorded sources, even
six of them heavily processed, beat arithmetic.

**The known compromise: the shot sounds.** A platformer pack contains no
projectile audio, and those three fire constantly, so they matter most. All
three are the jump — a short airy blip — pitched down and filtered into a
whoosh. It is the closest honest match available and the first thing to replace
if better sources ever turn up.

Levels in the pack are wildly inconsistent (hurt peaks at 55%, power_up at 30%),
so everything is normalised on the way out or the mix is unusable.

Replacing one by hand is still just a file drop: put a WAV with the matching
name in `assets/sfx/` and nothing in the code changes.

## Assembly scripts

Two packs shipped one PNG per frame and needed assembling into strips:

```bash
python tools/build_keeper_strips.py "<unzipped Moonstone Keeper pack>"
python tools/build_dreadknight_strips.py "<unzipped Dreadknight pack>"
```

- **Keeper**: mixes 150x150 and 200x150 cells. The wide ones are the same
  drawing with 25px of extra canvas per side — verified by measuring the
  character's cyan gem (x=75 in a 150 cell, x=100 in a 200 cell). The script
  pads the narrow frames onto one uniform grid.
- **Dreadknight**: 256x256 canvas holding a ~54x57 sprite, over 90% empty. The
  script crops every frame to the **same** 80x96 window, which is what keeps
  the sprite in the same place from one animation to the next.

## Gotchas worth remembering

- **Measure sprites from the pose they are usually seen in.** Catto's idle is a
  *sitting* pose and NightBorne's run is a low lunge — both make the creature
  look half its real size if you scale from them.
- **Dark silhouettes vanish on dark panels.** Every portrait well in the UI is
  deliberately lighter than the card behind it. This has bitten three times.
- **Projectiles declare which way their art points** (`art_forward`), not an
  offset to add. The sword art points down-right at +45 degrees; the offset
  form was wrong by a half-turn on the first attempt.
- **Projectile art is scaled from its content**, not its texture, so padding
  does not shrink it. Both cane sprites are padded square so they can rotate.
- **A new `class_name` script needs a project rescan** before other scripts see
  it. The editor does this on save; from the CLI it is
  `godot --headless --path . --import`.

## Adding art

Animations are declared as `[texture_path, row, frame_count, fps]`.

- **Character**: fill in `anims` in `characters.gd`. An empty `anims` falls back
  to a drawn silhouette, so the character stays playable with no art at all.
- **Enemy**: same, in `enemy_kinds.gd`. Needs at least `run`; `attack`, `hurt`
  and `death` are optional.

Set `frame` (cell size), `pivot` (the point in the cell that sits on the
entity's position — near the feet for a walker, the centre for a flyer) and
`scale`. Nothing else needs to change.
