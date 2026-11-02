#!/usr/bin/env python3
"""Generate the synthesized sounds added for the polish update.

Python 3 standard library only. A fixed random seed makes every run produce
byte-identical files. drop.wav, stack_success.wav and fail.wav were generated
for the project earlier and are NOT rewritten here; only the sounds listed in
SOUNDS are produced.

  perfect.wav     22050 Hz  bright glassy ping (perfect drop)
  streak.wav      22050 Hz  quick rising sparkle run (perfect streak x3+)
  mission.wav     22050 Hz  short two-note chime (mission complete)
  level_up.wav    22050 Hz  cheerful rising fanfare (player level up)
  music_loop.wav  16000 Hz  upbeat, light marimba-pop loop, seamless

Everything is mono 16-bit PCM. The music runs at 16 kHz so the 22.5 s loop
stays under 1 MB. It is rendered on a circular timeline (note tails wrap
around the end and every filter/delay runs over two tiled periods, keeping
the second), so the last sample flows into the first without a click.

Usage: python3 tool/generate_sounds.py
"""

import math
import os
import random
import struct
import wave

SFX_RATE = 22050
MUSIC_RATE = 16000
SFX_PEAK = 0.708  # about -3 dBFS
MUSIC_PEAK = 0.251  # about -12 dBFS
TAU = 2.0 * math.pi


# --------------------------------------------------------------------------
# Small DSP helpers (all work on plain lists of floats)
# --------------------------------------------------------------------------

def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def lowpass(x, cutoff, rate):
    """One-pole low-pass."""
    a = 1.0 - math.exp(-TAU * cutoff / rate)
    y = 0.0
    out = []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff, rate):
    lp = lowpass(x, cutoff, rate)
    return [s - l for s, l in zip(x, lp)]


def fade_edges(x, rate, attack=0.002, release=0.03):
    """Linear ramps so a one-shot starts and ends exactly at zero."""
    n = len(x)
    a = max(1, int(attack * rate))
    r = max(1, int(release * rate))
    for i in range(min(a, n)):
        x[i] *= i / a
    for i in range(min(r, n)):
        x[n - 1 - i] *= i / r
    return x


def mix_into(buf, sig, start, wrap=False):
    """Add sig into buf at sample offset start; wrap=True makes it circular."""
    n = len(buf)
    if wrap:
        for i, s in enumerate(sig):
            buf[(start + i) % n] += s
    else:
        for i, s in enumerate(sig):
            j = start + i
            if j >= n:
                break
            buf[j] += s


def feedback_delay(x, delay, feedback, damp_hz, rate):
    """Echo: y[n] = x[n] + feedback * lowpass(y[n - delay]). Returns y - x."""
    a = 1.0 - math.exp(-TAU * damp_hz / rate)
    y = [0.0] * len(x)
    wet = [0.0] * len(x)
    lp = 0.0
    for i in range(len(x)):
        if i >= delay:
            lp += a * (wet[i - delay] - lp)
        wet[i] = x[i] + feedback * lp if i >= delay else x[i]
        y[i] = wet[i] - x[i]
    return y


def schroeder_reverb(x, rate):
    """Small mono room: four damped combs in parallel, two all-passes."""
    out = [0.0] * len(x)
    for delay_ms, fb in ((29.7, 0.77), (37.1, 0.75), (41.1, 0.73), (43.7, 0.71)):
        d = int(delay_ms * rate / 1000.0)
        buf = [0.0] * len(x)
        lp = 0.0
        for i in range(len(x)):
            fed = buf[i - d] if i >= d else 0.0
            lp += 0.45 * (fed - lp)
            buf[i] = x[i] + fb * lp
            out[i] += buf[i] * 0.25
    for delay_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(delay_ms * rate / 1000.0)
        buf = [0.0] * len(out)
        res = [0.0] * len(out)
        for i in range(len(out)):
            delayed = buf[i - d] if i >= d else 0.0
            buf[i] = out[i] + g * delayed
            res[i] = delayed - g * buf[i]
        out = res
    return out


def circular(effect, x, *args):
    """Run a stateful effect over two tiled periods and keep the second one.

    The first period warms up filters and delay lines with the signal that
    precedes the loop point, so the seam carries no startup transient.
    """
    n = len(x)
    return effect(x + x, *args)[n:]


# --------------------------------------------------------------------------
# Voices
# --------------------------------------------------------------------------

def pluck(freq, dur, rate, decay=3.0, harmonics=6, brightness=1.0):
    """Soft plucked string: additive partials, higher ones die faster."""
    n = int(dur * rate)
    out = [0.0] * n
    for k in range(1, harmonics + 1):
        f = freq * k
        if f > rate * 0.45:
            break
        amp = (k ** -1.35) * (brightness if k > 1 else 1.0)
        dec = decay + 1.6 * (k - 1)
        w = TAU * f / rate
        for i in range(n):
            out[i] += amp * math.sin(w * i) * math.exp(-dec * i / rate)
    # 6 ms attack removes the click of an instantly started partial stack.
    a = int(0.006 * rate)
    for i in range(min(a, n)):
        out[i] *= i / a
    return out


def bell(freq, dur, rate, decay=5.0, shimmer=1.0):
    """Glassy bell: harmonic body plus two quickly fading inharmonic partials."""
    n = int(dur * rate)
    out = [0.0] * n
    parts = ((1.0, 1.0, decay), (2.0, 0.45, decay * 1.6),
             (2.76, 0.22 * shimmer, decay * 2.4), (5.4, 0.10 * shimmer, decay * 4.0))
    for ratio, amp, dec in parts:
        f = freq * ratio
        if f > rate * 0.45:
            continue
        w = TAU * f / rate
        for i in range(n):
            out[i] += amp * math.sin(w * i) * math.exp(-dec * i / rate)
    a = int(0.003 * rate)
    for i in range(min(a, n)):
        out[i] *= i / a
    return out


def soft_tone(freq, dur, rate, decay=2.5, release=0.15):
    """Warm sustained tone (triangle-ish stack) with a plucked front."""
    n = int(dur * rate)
    out = [0.0] * n
    for k, amp in ((1, 1.0), (2, 0.38), (3, 0.14), (4, 0.06)):
        w = TAU * freq * k / rate
        for i in range(n):
            out[i] += amp * math.sin(w * i)
    r = int(release * rate)
    a = int(0.008 * rate)
    for i in range(n):
        g = 0.35 + 0.65 * math.exp(-decay * i / rate)
        if i < a:
            g *= i / a
        if i > n - r:
            g *= (n - i) / r
        out[i] *= g
    return out




def marimba(freq, dur, rate, decay=9.0):
    """Wooden mallet: fundamental plus a 4x partial that dies very fast."""
    n = int(dur * rate)
    out = [0.0] * n
    for ratio, amp, dec in ((1.0, 1.0, decay), (4.0, 0.35, decay * 4.5),
                            (10.0, 0.08, decay * 9.0)):
        f = freq * ratio
        if f > rate * 0.45:
            continue
        w = TAU * f / rate
        for i in range(n):
            out[i] += amp * math.sin(w * i) * math.exp(-dec * i / rate)
    a = int(0.002 * rate)
    for i in range(min(a, n)):
        out[i] *= i / a
    return out


# --------------------------------------------------------------------------
# Effects
# --------------------------------------------------------------------------

def perfect():
    """Bright glassy ping with a fifth on top, 0.45 s."""
    rate = SFX_RATE
    n = int(0.45 * rate)
    buf = [0.0] * n
    mix_into(buf, bell(midi_hz(88), 0.45, rate, decay=7.0), 0)  # E6
    mix_into(buf, [0.6 * s for s in bell(midi_hz(95), 0.35, rate, decay=9.0)],
             int(0.035 * rate))  # B6
    echo = feedback_delay(buf, int(0.08 * rate), 0.25, 6000, rate)
    buf = [a + 0.4 * b for a, b in zip(buf, echo)]
    return fade_edges(buf, rate, 0.002, 0.08)


def streak():
    """Quick rising sparkle run, 0.55 s."""
    rate = SFX_RATE
    n = int(0.55 * rate)
    buf = [0.0] * n
    for step, note in enumerate((81, 85, 88, 93, 97)):  # A5 C#6 E6 A6 C#7
        voice = bell(midi_hz(note), 0.32, rate, decay=8.0)
        mix_into(buf, [0.8 * s for s in voice], int(step * 0.045 * rate))
    echo = feedback_delay(buf, int(0.1 * rate), 0.3, 6000, rate)
    buf = [a + 0.4 * b for a, b in zip(buf, echo)]
    return fade_edges(buf, rate, 0.002, 0.1)


def mission():
    """Short warm two-note chime, 0.4 s."""
    rate = SFX_RATE
    n = int(0.4 * rate)
    buf = [0.0] * n
    mix_into(buf, marimba(midi_hz(79), 0.35, rate, decay=7.0), 0)
    mix_into(buf, marimba(midi_hz(86), 0.3, rate, decay=6.0), int(0.09 * rate))
    mix_into(buf, [0.3 * s for s in bell(midi_hz(98), 0.25, rate, decay=9.0)],
             int(0.09 * rate))
    buf = lowpass(buf, 7000, rate)
    return fade_edges(buf, rate, 0.002, 0.08)


def level_up():
    """Cheerful rising fanfare ending on a held major chord, 0.9 s."""
    rate = SFX_RATE
    n = int(0.9 * rate)
    buf = [0.0] * n
    for step, note in enumerate((74, 78, 81)):  # D5 F#5 A5
        mix_into(buf, soft_tone(midi_hz(note), 0.22, rate, decay=6.0,
                                release=0.05), int(step * 0.08 * rate))
    start = int(0.24 * rate)
    for note, amp in ((74, 0.7), (78, 0.7), (81, 0.7), (86, 0.9)):
        tone = soft_tone(midi_hz(note), (n - start) / rate, rate, decay=2.2,
                         release=0.3)
        mix_into(buf, [amp * s for s in tone], start)
    mix_into(buf, [0.25 * s for s in bell(midi_hz(98), 0.5, rate, decay=6.0)],
             start)
    echo = feedback_delay(buf, int(0.11 * rate), 0.3, 4500, rate)
    buf = [a + 0.35 * b for a, b in zip(buf, echo)]
    buf = lowpass(buf, 7000, rate)
    return fade_edges(buf, rate, 0.003, 0.15)


# --------------------------------------------------------------------------
# Music: upbeat, light marimba-pop loop in D major
# --------------------------------------------------------------------------

BPM = 128
BARS = 12
EIGHTH = 60.0 / BPM / 2.0  # seconds

# Pad voicings and bass roots (MIDI). One chord per bar:
#   D A Bm G | D A G A | Bm G D A  -> ends on the dominant for the turnaround.
CHORDS = {
    "D": ((62, 66, 69), 38),
    "A": ((61, 64, 69), 45),
    "Bm": ((62, 66, 71), 47),
    "G": ((62, 67, 71), 43),
}
PROGRESSION = ["D", "A", "Bm", "G", "D", "A", "G", "A", "Bm", "G", "D", "A"]

# Melody in D major pentatonic (D E F# A B). (eighth offset, MIDI, eighths).
MELODY = [
    [(0, 78, 1), (1, 81, 1), (2, 83, 2), (4, 81, 1), (5, 78, 1), (6, 76, 2)],
    [(0, 76, 1), (1, 78, 1), (2, 81, 2), (5, 76, 1), (6, 73, 2)],
    [(0, 74, 1), (1, 78, 1), (2, 83, 2), (4, 86, 1), (5, 83, 1), (6, 81, 2)],
    [(0, 79, 2), (2, 78, 1), (3, 76, 1), (4, 74, 4)],
    [(0, 78, 1), (1, 81, 1), (2, 83, 2), (4, 86, 1), (5, 88, 1), (6, 86, 2)],
    [(0, 85, 2), (2, 81, 1), (3, 83, 1), (4, 81, 2), (6, 76, 2)],
    [(0, 79, 1), (1, 81, 1), (2, 83, 1), (3, 86, 1), (4, 83, 2), (6, 79, 2)],
    [(0, 81, 3), (3, 76, 1), (4, 73, 2), (6, 76, 2)],
    [(0, 83, 1), (1, 86, 1), (2, 83, 1), (3, 81, 1), (4, 78, 2), (6, 81, 2)],
    [(0, 79, 1), (1, 83, 1), (2, 86, 2), (4, 83, 1), (5, 81, 1), (6, 79, 2)],
    [(0, 78, 2), (2, 81, 1), (3, 78, 1), (4, 74, 2), (6, 78, 2)],
    [(0, 76, 1), (1, 78, 1), (2, 81, 1), (3, 85, 1), (4, 88, 2), (6, 85, 2)],
]


def music_loop():
    rate = MUSIC_RATE
    bar = EIGHTH * 8
    n = int(round(bar * BARS * rate))
    rng = random.Random(1207)

    keys = [0.0] * n
    bass = [0.0] * n
    lead = [0.0] * n
    drums = [0.0] * n

    # --- off-beat chord stabs (bright, short) give the bouncy feel
    stab_cache = {}
    for b, name in enumerate(PROGRESSION):
        notes, _ = CHORDS[name]
        if name not in stab_cache:
            m = int(0.22 * rate)
            voice = [0.0] * m
            for note in notes:
                tone = marimba(midi_hz(note), 0.22, rate, decay=14.0)
                for i in range(m):
                    voice[i] += tone[i]
            stab_cache[name] = voice
        for e in (1, 3, 5, 7):
            mix_into(keys, [0.13 * s for s in stab_cache[name]],
                     int((b * bar + e * EIGHTH) * rate), wrap=True)
    keys = circular(lowpass, keys, 3200, rate)

    # --- bass: root on 1, octave bounce on 2&, fifth on 3, root on 4
    bass_cache = {}
    for b, name in enumerate(PROGRESSION):
        root = CHORDS[name][1]
        for e, interval, gain in ((0, 0, 0.6), (3, 12, 0.35), (4, 7, 0.45),
                                  (6, 0, 0.45)):
            note = root + interval
            if note not in bass_cache:
                bass_cache[note] = pluck(midi_hz(note), 0.42, rate, decay=7.0,
                                         harmonics=4)
            mix_into(bass, [gain * s for s in bass_cache[note]],
                     int((b * bar + e * EIGHTH) * rate), wrap=True)
    bass = circular(lowpass, bass, 900, rate)

    # --- marimba lead
    lead_cache = {}
    for b, notes in enumerate(MELODY):
        for off, midi, length in notes:
            key = (midi, length)
            if key not in lead_cache:
                dur = min(1.2, 0.35 + 0.18 * length)
                lead_cache[key] = marimba(midi_hz(midi), dur, rate,
                                          decay=5.5 if length > 1 else 8.0)
            gain = 0.36 if off % 2 == 0 else 0.3
            mix_into(lead, [gain * s for s in lead_cache[key]],
                     int((b * bar + off * EIGHTH) * rate), wrap=True)
    lead = circular(lowpass, lead, 4200, rate)

    # --- light drums: soft kick on 1 and 3, clap on 2 and 4, hats on eighths
    kick_len = int(0.16 * rate)
    kick = []
    phase = 0.0
    for i in range(kick_len):
        t = i / rate
        f = 55.0 + 90.0 * math.exp(-t * 30.0)
        phase += TAU * f / rate
        kick.append(math.sin(phase) * math.exp(-t * 22.0))
    for b in range(BARS):
        for beat in (0, 4):
            mix_into(drums, [0.45 * s for s in kick],
                     int((b * bar + beat * EIGHTH) * rate), wrap=True)
        for beat in (2, 6):
            clap = [rng.uniform(-1.0, 1.0) * math.exp(-35.0 * i / rate)
                    for i in range(int(0.12 * rate))]
            clap = highpass(clap, 900, rate)
            mix_into(drums, [0.16 * s for s in clap],
                     int((b * bar + beat * EIGHTH) * rate), wrap=True)
        for e in range(8):
            vel = 0.5 if e % 2 else 0.28
            vel *= 0.85 + 0.3 * rng.random()
            hat = [rng.uniform(-1.0, 1.0) * math.exp(-90.0 * i / rate)
                   for i in range(int(0.05 * rate))]
            mix_into(drums, [0.07 * vel * s for s in hat],
                     int((b * bar + e * EIGHTH) * rate), wrap=True)

    # --- short echo on the lead and a small room on keys + lead
    delay = int(round(EIGHTH * 3 * rate))
    echo = circular(feedback_delay, lead, delay, 0.3, 2600, rate)
    lead_bus = [p + 0.35 * e for p, e in zip(lead, echo)]
    room = circular(schroeder_reverb, [a + b for a, b in zip(keys, lead_bus)],
                    rate)
    mix = [k + l + b + d + 0.2 * r
           for k, l, b, d, r in zip(keys, lead_bus, bass, drums, room)]
    mix = circular(highpass, mix, 35, rate)
    return mix, MUSIC_PEAK


SOUNDS = {
    "perfect": (perfect, SFX_RATE, SFX_PEAK),
    "streak": (streak, SFX_RATE, SFX_PEAK),
    "mission": (mission, SFX_RATE, SFX_PEAK),
    "level_up": (level_up, SFX_RATE, SFX_PEAK),
    "music_loop": (music_loop, MUSIC_RATE, MUSIC_PEAK),
}


def write_wav(path, samples, rate, peak_target):
    peak = max(abs(s) for s in samples) or 1.0
    scale = peak_target / peak
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(
            b"".join(
                struct.pack("<h", int(round(max(-1.0, min(1.0, s * scale)) * 32767)))
                for s in samples
            )
        )




def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target = os.path.join(root, "assets", "audio")
    os.makedirs(target, exist_ok=True)
    for name, (build, rate, peak) in SOUNDS.items():
        result = build()
        if isinstance(result, tuple):
            result = result[0]
        path = os.path.join(target, name + ".wav")
        write_wav(path, result, rate, peak)
        print("wrote", os.path.relpath(path, root), os.path.getsize(path),
              "bytes", "%.2f s" % (len(result) / rate))


if __name__ == "__main__":
    main()
