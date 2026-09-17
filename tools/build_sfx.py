"""Builds every sound effect in the game from six recorded sources.

    python tools/build_sfx.py

Replaces the synthesised set that used to live in make_sfx.py. Those were
oscillators and envelopes -- honest placeholder work, and they sounded like it.
These start from real recordings.

THE PROBLEM THIS SOLVES. The source pack has six sounds; the game has sixteen
slots. Rather than leave ten silent or reuse six verbatim, each output is DERIVED
-- pitched, stretched, filtered, trimmed, reversed, layered -- which is what a
sound designer does with a small library. The family resemblance between, say,
the three shot sounds is deliberate: they come from one throat.

Where a mapping is a genuine compromise it says so in the recipe.

Sources live in assets/sfx_src/ so this is reproducible without the original
download. Output is 16-bit mono at the source rate.
"""

import os
import struct
import wave

import numpy as np

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "assets", "sfx_src")
OUT = os.path.join(HERE, "assets", "sfx")
SR = 44100


# --- the workbench ----------------------------------------------------------

def load(name):
    """A source, as floats in -1..1. The pack is 8-bit unsigned."""
    with wave.open(os.path.join(SRC, name + ".wav")) as w:
        n, sw, ch, sr = w.getnframes(), w.getsampwidth(), w.getnchannels(), w.getframerate()
        raw = w.readframes(n)
    if sw == 1:
        a = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    else:
        a = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    if ch > 1:
        a = a[::ch]
    if sr != SR:                       # everything works at one rate
        a = speed(a, sr / SR)
    return a


def speed(a, k):
    """Resample. k > 1 plays faster AND higher, like a tape sped up."""
    if len(a) < 2 or abs(k - 1.0) < 1e-6:
        return a
    n = max(2, int(len(a) / k))
    return np.interp(np.linspace(0, len(a) - 1, n), np.arange(len(a)), a).astype(np.float32)


def lowpass(a, cut):
    """One pole. Takes the fizz off, which is most of what turns a bright
    platformer sound into something that belongs underground."""
    c = float(np.exp(-2.0 * np.pi * cut / SR))
    out = np.empty_like(a)
    prev = 0.0
    for i, v in enumerate(a):
        prev = prev * c + v * (1.0 - c)
        out[i] = prev
    return out


def highpass(a, cut):
    return a - lowpass(a, cut)


def fade(a, attack=0.004, release=0.05):
    """Any cut edge clicks. Both ends always get a ramp."""
    n = len(a)
    at = min(int(attack * SR), n // 2)
    rl = min(int(release * SR), n // 2)
    if at > 0:
        a[:at] *= np.linspace(0.0, 1.0, at)
    if rl > 0:
        a[-rl:] *= np.linspace(1.0, 0.0, rl)
    return a


def trim(a, seconds):
    return a[:int(seconds * SR)].copy()


def pad(a, seconds):
    n = int(seconds * SR)
    return np.concatenate([a, np.zeros(max(0, n - len(a)), np.float32)]) if n > len(a) else a


def mix(*layers, gain=0.9):
    n = max(len(x) for x in layers)
    out = np.zeros(n, np.float32)
    for x in layers:
        out[:len(x)] += x
    peak = float(np.max(np.abs(out))) or 1.0
    return out * (gain / peak)


def norm(a, level=0.9):
    """The pack's levels are all over the place -- hurt peaks at 55% and
    power_up at 30%. Without this the mix is unusable."""
    peak = float(np.max(np.abs(a))) or 1.0
    return a * (level / peak)


def save(name, a):
    os.makedirs(OUT, exist_ok=True)
    a = np.clip(a, -1.0, 1.0)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32000)) for v in a))
    return len(a) / SR, os.path.getsize(path)


# --- the recipes ------------------------------------------------------------

def build():
    coin = load("coin")
    boom = load("explosion")
    hurt = load("hurt")
    jump = load("jump")
    power = load("power_up")
    tap = load("tap")
    out = {}

    # Money, and the sound the pack was built around.
    out["coin_pickup"] = norm(coin, 0.85)

    # Motes are the most frequent sound in the game by a wide margin, so this is
    # the same coin taken up an octave and cut to a third of its length -- short
    # enough that forty of them do not become a chord.
    out["mote_pickup"] = norm(fade(trim(speed(coin, 2.0), 0.09), 0.002, 0.05), 0.55)

    # A hit is the tap's transient in front of a very short thump, which is how
    # an impact actually reads: a click, then a body.
    out["enemy_hit"] = mix(norm(tap, 0.55),
                           norm(lowpass(fade(trim(boom, 0.10), 0.002, 0.07), 900), 0.7),
                           gain=0.75)

    # Death is the explosion, dropped and darkened so it lands underground.
    out["enemy_die"] = norm(lowpass(fade(trim(speed(boom, 0.85), 0.34)), 3200), 0.8)

    out["player_hurt"] = norm(hurt, 0.95)

    # Yours is the same wound, an octave down and dragged out, with the
    # explosion under it. It should not sound like an enemy dying.
    out["death"] = mix(norm(speed(hurt, 0.45), 0.9),
                       norm(lowpass(speed(boom, 0.4), 1400), 0.7), gain=0.95)

    # Something very large arriving: the explosion at less than half speed, which
    # turns a bang into a rumble, with its own low end doubled underneath.
    out["boss_spawn"] = mix(norm(lowpass(speed(boom, 0.35), 700), 0.9),
                            norm(lowpass(speed(boom, 0.22), 300), 0.6), gain=1.0)

    out["level_up"] = norm(power, 0.9)

    # A chest is the same jingle brighter and quicker -- related, but an object
    # opening rather than you growing.
    out["chest_open"] = norm(highpass(speed(power, 1.25), 200), 0.85)

    # Swearing a pact: the tap as the moment of decision, then a coin tail
    # pitched down so it rings wrong.
    out["pact_pick"] = mix(norm(tap, 0.7),
                           norm(lowpass(speed(coin, 0.55), 2200), 0.45), gain=0.8)

    # THE COMPROMISE. A platformer pack has no projectile sounds, and these fire
    # constantly, so they matter most. All three are the jump -- a short airy
    # blip -- pitched down and filtered into a whoosh, which is the closest
    # honest match available. Replace these first if you ever record more.
    out["shoot_cinder"] = norm(lowpass(fade(speed(jump, 0.55), 0.003, 0.09), 2600), 0.55)
    out["shoot_skull"] = norm(lowpass(fade(speed(jump, 0.40), 0.003, 0.07), 1500), 0.55)
    out["shoot_arrow"] = norm(highpass(fade(speed(tap, 0.75), 0.001, 0.05), 500), 0.5)

    # A blade through air: the jump reversed, so it swells into the strike
    # instead of decaying away from it.
    out["swing"] = norm(lowpass(fade(speed(jump[::-1].copy(), 0.7), 0.02, 0.04), 3000), 0.6)

    # A vigil beginning: the explosion slowed almost to a bell, low and far off.
    out["vigil_start"] = norm(lowpass(speed(boom, 0.30), 500), 0.75)

    # And surviving one: the jingle dropped a fifth, so it resolves rather than
    # celebrates.
    out["vigil_end"] = norm(lowpass(speed(power, 0.72), 5000), 0.8)

    return out


def main():
    # The old synthesised set is being replaced wholesale, not added to.
    if os.path.isdir(OUT):
        for f in os.listdir(OUT):
            if f.endswith(".wav"):
                os.remove(os.path.join(OUT, f))
    sounds = build()
    print("built %d sounds from %d sources" % (sounds and len(sounds), len(os.listdir(SRC))))
    total = 0
    for name in sorted(sounds):
        secs, size = save(name, sounds[name])
        total += size
        print("  %-14s %5.2fs %8d bytes" % (name, secs, size))
    print("total %.1f KB" % (total / 1024.0))


if __name__ == "__main__":
    main()
