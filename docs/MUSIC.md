# Music

Prompts for generating the soundtrack, and how it fits the game.

The audio system is already built (`audio.gd`): there is a **Music bus** and a
volume slider in settings, and nothing on it. Drop files into `assets/music/`
and the tracks can be wired in.

---

## The one idea that ties it together

Undertale's soundtrack works because **one melody keeps coming back** wearing
different clothes — the same handful of notes as a lullaby, as a boss theme, as
a farewell. That, more than any instrument choice, is what makes a score feel
like it belongs to a single world.

So: generate **THE VIGIL BELL** first — a slow four-note descending figure, minor,
tolling. Then ask for it back inside the other tracks. In Suno that means putting
a line like *"built on a slow descending four-note bell motif"* into every prompt,
and if you get a first result whose motif you love, use Suno's **Cover** or
**Extend** on it so later tracks inherit the same tune rather than a new one.

Everything below assumes **Instrumental** is switched on.

---

## The tracks

### 1. Main menu — "The Long Vigil"

The screen it plays over: a dark room, braziers breathing, blood running down
from somewhere above, and eyes that open in the dark and watch you. The subtitle
is *something in the dark is still counting*. The music should be **patient and
wrong**, not exciting. Nothing has started yet.

> **Style:** dark ambient, gothic liturgical, low pipe organ drone, distant church bell, bowed double bass, faint male chant, no percussion, very slow, ominous, sparse
>
> **Prompt:** A near-silent cathedral at night, waiting. A slow descending four-note bell motif tolls every eight bars over a low organ drone. Distant, indistinct chanting far off. Long silences between phrases. Nothing resolves. 50 BPM, D minor, patient and dreadful.

### 2. The vigil — combat loop

The main loop, and the track you will hear most. Vampire Survivors' lesson: it
must be **propulsive and shameless**, and it must survive a hundred loops.

> **Style:** gothic baroque battle, driving harpsichord ostinato, pipe organ, staccato low strings, timpani, choir stabs, relentless, looping, heroic and grim
>
> **Prompt:** Relentless harpsichord ostinato under a soaring minor organ melody built from a descending four-note motif. Driving timpani and staccato cellos. Grand, propulsive, faintly ridiculous in the way great arcade music is. No breakdown, no fade — it should feel like it could go forever. 145 BPM, D minor.

### 3. The late vigils — combat, escalated

Vigils 10 onward, when the arena is thick. Same bones, more teeth. Generate this
as a **Cover of track 2** so it is recognisably the same piece.

> **Style:** gothic baroque battle, faster, double-time drums, full choir, brass, tremolo strings, organ, frantic, overwhelming
>
> **Prompt:** The same harpsichord ostinato and four-note motif, now at double speed with a full choir screaming over it, brass blasts and tremolo strings. Barely in control. 165 BPM, D minor.

### 4. The Skeleton Knight — boss

Arrives at vigil 5 with its name across the screen and a health bar. It plants
itself and swings; it does not chase. The music should be **heavy and
deliberate**, not fast — weight, not speed.

> **Style:** epic dark orchestral boss battle, war drums, low brass, Latin choir, church organ, dissonant strings, heavy, slow-stomping, monstrous
>
> **Prompt:** Enormous slow war drums like something walking. Low brass and a Latin male choir chanting the four-note motif as a dirge. Dissonant high strings shrieking above. Grand, ceremonial, and much bigger than you. 100 BPM, D minor, crushing.

### 5. The pact screen — choosing a sigil

The fight stops and something offers you power. Cards animate in with rarity
glow. This is a **held breath** — short, hanging, unresolved, because you are
about to agree to something.

> **Style:** dark ambient interlude, solo celesta, glass harmonica, sustained string pad, reversed cymbal, sparse, hanging, unresolved, no drums
>
> **Prompt:** Time stopped. A single celesta picks out the four-note motif slowly, each note ringing out over a barely-moving string pad. Something breathing underneath. It never resolves to the tonic — it just hangs there, waiting for you to decide. 60 BPM, D minor.

### 6. The Cursed Chest — a boss's reward

A chest a dead thing was carrying opens and offers three inked cards. Rarer and
stranger than the pact screen. Should feel like **opening something you should
not**.

> **Style:** dark ambient, music box, detuned celesta, low cello swell, bowed cymbal, faint whispers, curious and wrong
>
> **Prompt:** A music box found in a grave, playing the four-note motif slightly out of tune and slightly too slow. A cello swells underneath. Faint whispering just below hearing. Beautiful, and something is wrong with it. 55 BPM.

### 7. The Chapel — between runs

Meta progression. You are alive, spending what you carried out. The only place
in the game with any **warmth**, though not comfort.

> **Style:** solemn sacred ambient, solo pipe organ, soft choir pad, distant bell, warm reverb, reverent, restful, slow
>
> **Prompt:** A quiet chapel after the fighting. Solo pipe organ playing the four-note motif as a gentle hymn, warm and consonant for the first time. A soft wordless choir far behind it. Restful but not safe. 65 BPM, D minor resolving to F major.

### 8. Death — "You have fallen"

Short. One statement, then quiet. Do not loop this.

> **Style:** dark orchestral outro, single tolling bell, low strings, choir sigh, decaying organ, final, sparse
>
> **Prompt:** One bell. The four-note motif played once, very slowly, on low strings, then a choir exhales and the organ decays into nothing. Forty seconds. Final. D minor.

### 9. Vigil held — a short sting

Plays over the tally screen, where the vigil number is inked in and the count
reads itself out. **Not a loop** — six seconds, then silence under the writing.

> **Style:** short orchestral sting, single bell strike, brass swell, choir hit, resolving, triumphant but grim
>
> **Prompt:** A bell strikes and brass swells up under it, a brief choir hit, then it clears. Six seconds. Relief, not celebration. D minor to D major.

---

## Making them fit the game

**Export as OGG** if Suno lets you, otherwise convert. Godot loops OGG cleanly;
MP3 carries encoder padding that puts an audible gap at the loop point.

**Loops need trimming.** Suno will give you an intro and an ending, and neither
belongs in a loop. In Audacity: cut to a whole number of bars, then crossfade the
last second over the first. Tracks 8 and 9 are the exceptions — they are meant to
stop.

**Name them by their id** and drop them in `assets/music/`:

```
menu.ogg        vigil.ogg      vigil_late.ogg    boss.ogg
pact.ogg        chest.ogg      chapel.ogg        death.ogg    held.ogg
```

That matches how `assets/sfx/` already works — `audio.gd` loads by filename, so
nothing in the code needs to know how a file was made.

**Keep them quiet.** Music sits under the game, not over it. The Music bus
already defaults lower than SFX for this reason.

**One practical warning:** generate track 2 first and listen to it ten times in a
row before committing. A combat loop that is merely good becomes unbearable at
the twentieth repeat, and it is the one you will hear for an entire run.
