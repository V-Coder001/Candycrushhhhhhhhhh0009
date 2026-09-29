#!/usr/bin/env python3
"""Generates Sött's sound effects and music loop into App/Sounds.

Everything is synthesised (no samples, no licences). Run again after tweaking:
    python3 -m pip install numpy imageio-ffmpeg
    python3 scripts/make_sounds.py
"""
import os
import subprocess
import wave

import numpy as np

SR = 44_100
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Sounds")
rng = np.random.default_rng(7)


def t(duration):
    return np.arange(int(duration * SR)) / SR


def env(n, attack=0.005, decay=8.0):
    x = np.arange(n) / SR
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-x * decay)


def sine(freq, duration, phase=0.0):
    tt = t(duration)
    if np.ndim(freq) == 0:
        return np.sin(2 * np.pi * freq * tt + phase)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR + phase)


def glide(f0, f1, duration, curve=2.0):
    x = np.linspace(0, 1, int(duration * SR))
    return f0 + (f1 - f0) * (1 - (1 - x) ** curve)


def noise(duration, smooth=0.0):
    n = rng.uniform(-1, 1, int(duration * SR))
    if smooth > 0:
        out = np.empty_like(n)
        acc = 0.0
        for i, v in enumerate(n):
            acc = acc * smooth + v * (1 - smooth)
            out[i] = acc
        return out / (np.max(np.abs(out)) + 1e-9)
    return n


def bell(freq, duration, decay=6.0, bright=0.5):
    """Glassy candy bell: fundamental plus inharmonic partials."""
    partials = [(1, 1.0), (2.76, 0.45 * bright), (5.4, 0.25 * bright), (8.93, 0.12 * bright)]
    out = np.zeros(int(duration * SR))
    for ratio, amp in partials:
        out += amp * sine(freq * ratio, duration) * env(len(out), 0.002, decay * (1 + ratio * 0.35))
    return out


def marimba(freq, duration, decay=9.0):
    out = sine(freq, duration) + 0.25 * sine(freq * 4, duration) * np.exp(-t(duration) * 30)
    return out * env(len(out), 0.003, decay)


def reverb(x, amount=0.25, length=0.6):
    n = int(length * SR)
    ir = rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / SR * 7)
    ir[0] = 0
    wet = np.concatenate([np.convolve(x, ir), [0.0]])[: len(x) + n]
    dry = np.concatenate([x, np.zeros(n)])
    wet = wet / (np.max(np.abs(wet)) + 1e-9) * np.max(np.abs(x))
    return dry + amount * wet


def mix(*parts):
    n = max(len(p) for _, p in parts)
    out = np.zeros(n)
    for offset, p in parts:
        start = int(offset * SR)
        end = min(n, start + len(p))
        if start >= n:
            continue
        out[start:end] += p[: end - start]
    return out


def pad(parts, total):
    out = np.zeros(int(total * SR))
    for offset, p in parts:
        s = int(offset * SR)
        e = min(len(out), s + len(p))
        out[s:e] += p[: e - s]
    return out


def save(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    fade = min(len(x), int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (x * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav {len(x) / SR:.2f}s")


# --- Effects -----------------------------------------------------------------------------

def pop():
    # "Plopp": a round bubble that drops in pitch, with a soft click on top.
    d = 0.16
    body = sine(glide(900, 320, d, 3), d) * env(int(d * SR), 0.002, 22)
    sub = sine(glide(260, 140, d, 2), d) * env(int(d * SR), 0.002, 25) * 0.6
    click = noise(0.012) * np.linspace(1, 0, int(0.012 * SR)) * 0.25
    return reverb(mix((0, body), (0, sub), (0, click)), 0.12, 0.25)


def swap():
    d = 0.14
    whoosh = noise(d, 0.93) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2
    tone = sine(glide(420, 640, d, 1.5), d) * env(int(d * SR), 0.01, 14) * 0.25
    return mix((0, whoosh * 0.7), (0, tone))


def crunch():
    d = 0.22
    grains = np.zeros(int(d * SR))
    for k in range(9):
        start = int(rng.uniform(0, d * 0.6) * SR)
        g = noise(0.03) * env(int(0.03 * SR), 0.001, 90)
        grains[start:start + len(g)] += g[: len(grains) - start] * rng.uniform(0.4, 1)
    thump = sine(glide(180, 70, d, 2), d) * env(int(d * SR), 0.002, 18) * 0.7
    return reverb(grains * 0.8 + thump, 0.1, 0.2)


def stripe():
    # Laser zip for striped candies.
    d = 0.32
    f = glide(1800, 300, d, 1.6)
    zap = (sine(f, d) + 0.4 * sine(f * 1.5, d)) * env(int(d * SR), 0.002, 9)
    shimmer = noise(d, 0.6) * env(int(d * SR), 0.002, 14) * 0.25
    return reverb(zap + shimmer, 0.25, 0.4)


def bomb():
    d = 0.9
    boom = sine(glide(120, 38, d, 2.5), d) * env(int(d * SR), 0.003, 4.5)
    rumble = noise(d, 0.97) * env(int(d * SR), 0.003, 5) * 1.4
    crack = noise(0.08) * env(int(0.08 * SR), 0.001, 40) * 0.6
    glitter = sum(bell(f, 0.5, 9, 0.8) * 0.12 for f in (2093, 2637, 3136))
    return reverb(mix((0, boom), (0, rumble), (0, crack), (0.05, glitter)), 0.3, 0.8)


def colorbomb():
    d = 1.0
    parts = []
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0, 2093.0]
    for i, f in enumerate(notes):
        parts.append((i * 0.055, bell(f, 0.6, 7, 0.7) * 0.5))
    sweep = noise(d, 0.8) * np.linspace(0, 1, int(d * SR)) ** 2 * np.exp(-t(d) * 2) * 0.3
    parts.append((0, sweep))
    return reverb(mix(*parts), 0.35, 0.9)


def special():
    # Sparkly chime when a special candy is created.
    parts = [(0.0, bell(1318.5, 0.6, 7) * 0.6), (0.06, bell(1760, 0.6, 7) * 0.5),
             (0.12, bell(2637, 0.6, 8) * 0.35)]
    return reverb(mix(*parts), 0.3, 0.6)


def fish():
    d = 0.35
    blub = sine(glide(300, 900, d, 1.3), d) * env(int(d * SR), 0.01, 7) * 0.5
    bubbles = mix(*[(k * 0.06, sine(glide(700 + 150 * k, 1200 + 150 * k, 0.05), 0.05)
                     * env(int(0.05 * SR), 0.002, 50) * 0.35) for k in range(5)])
    return reverb(mix((0, blub), (0, bubbles)), 0.2, 0.3)


def invalid():
    d = 0.24
    a = sine(220, 0.1) * env(int(0.1 * SR), 0.005, 25)
    b = sine(185, 0.12) * env(int(0.12 * SR), 0.005, 20)
    return pad([(0, a), (0.1, b)], d) * 0.6


def collect():
    notes = [(0.0, 1046.5), (0.08, 1318.5), (0.16, 1568.0), (0.24, 2093.0)]
    return reverb(mix(*[(o, bell(f, 0.5, 8) * 0.5) for o, f in notes]), 0.3, 0.6)


def star():
    return reverb(mix((0, bell(1568, 0.9, 4.5, 0.9) * 0.7), (0.0, bell(2349, 0.9, 5, 0.6) * 0.35)), 0.35, 0.8)


def tap():
    d = 0.06
    return sine(glide(1400, 900, d), d) * env(int(d * SR), 0.001, 70) * 0.6


def jelly():
    d = 0.25
    wob = sine(glide(500, 250, d) * (1 + 0.08 * np.sin(2 * np.pi * 28 * t(d))), d)
    return wob * env(int(d * SR), 0.004, 14) * 0.6


def win():
    # Rising marimba run into a sparkling chord.
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    parts = [(i * 0.09, marimba(f, 0.5) * 0.6) for i, f in enumerate(notes)]
    chord = [1046.5, 1318.5, 1568.0, 2093.0]
    parts += [(0.5, bell(f, 1.4, 2.8, 0.6) * 0.35) for f in chord]
    return reverb(mix(*parts), 0.35, 1.0)


def lose():
    notes = [(0.0, 392.0), (0.22, 349.23), (0.44, 311.13), (0.66, 261.63)]
    return reverb(mix(*[(o, marimba(f, 0.7, 5) * 0.6) for o, f in notes]), 0.3, 0.8)


def sugarrush():
    d = 1.2
    f = glide(300, 2400, d, 1.2)
    rise = (sine(f, d) * 0.4 + sine(f * 1.5, d) * 0.2) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 0.5
    sparkles = mix(*[(rng.uniform(0.1, 1.0), bell(rng.uniform(1500, 3500), 0.3, 12) * 0.2) for _ in range(14)])
    return reverb(mix((0, rise), (0, sparkles)), 0.4, 1.0)


def whoosh():
    d = 0.4
    w = noise(d, 0.95) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2
    return w * 0.8


# --- Music loop --------------------------------------------------------------------------

def music():
    """Light, bouncy 8-bar loop (C major, 112 bpm): marimba melody, pizzicato bass, soft shaker."""
    bpm = 112
    beat = 60 / bpm
    bars = 8
    total = bars * 4 * beat
    parts = []
    chords = [[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63],
              [196.0, 246.94, 293.66]] * 2
    roots = [130.81, 110.0, 87.31, 98.0] * 2
    melody = [
        [784, 0, 659, 784, 880, 784, 659, 0], [659, 0, 523, 659, 784, 0, 659, 587],
        [523, 0, 587, 659, 698, 659, 587, 523], [587, 0, 494, 587, 784, 0, 587, 0],
        [784, 880, 988, 1047, 988, 880, 784, 659], [659, 0, 784, 880, 784, 659, 523, 0],
        [698, 0, 659, 587, 523, 587, 659, 698], [784, 0, 587, 494, 523, 0, 0, 0],
    ]
    for bar in range(bars):
        start = bar * 4 * beat
        # Bass on 1 and 3, fifth on the "and" of 4.
        root = roots[bar]
        for off, f in [(0, root), (2 * beat, root), (3.5 * beat, root * 1.5)]:
            b = (sine(f, 0.5) + 0.3 * sine(f * 2, 0.5)) * env(int(0.5 * SR), 0.004, 7) * 0.55
            parts.append((start + off, b))
        # Soft chord stabs on 2 and 4.
        for off in (beat, 3 * beat):
            for f in chords[bar]:
                parts.append((start + off, bell(f * 2, 0.45, 9, 0.3) * 0.12))
        # Melody in eighths.
        for i, f in enumerate(melody[bar]):
            if f:
                parts.append((start + i * beat / 2, marimba(f, 0.45, 8) * 0.32))
        # Shaker on every eighth, accent on offbeats.
        for i in range(8):
            s = noise(0.05) * env(int(0.05 * SR), 0.002, 60) * (0.07 if i % 2 else 0.035)
            parts.append((start + i * beat / 2, s))
    out = pad(parts, total)
    # Wrap the reverb tail around so the loop is seamless.
    wet = reverb(out, 0.25, 1.2)
    loop = wet[: len(out)].copy()
    tail = wet[len(out):]
    loop[: len(tail)] += tail
    return loop


def to_m4a(name):
    try:
        import imageio_ffmpeg
    except ImportError:
        print("imageio-ffmpeg missing, keeping", name + ".wav")
        return
    src = os.path.join(OUT, name + ".wav")
    dst = os.path.join(OUT, name + ".m4a")
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", src,
                    "-c:a", "aac", "-b:a", "96k", dst], check=True)
    os.remove(src)
    print(name + ".m4a")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    effects = dict(pop=pop, swap=swap, crunch=crunch, stripe=stripe, bomb=bomb, colorbomb=colorbomb,
                   special=special, fish=fish, invalid=invalid, collect=collect, star=star, tap=tap,
                   jelly=jelly, win=win, lose=lose, sugarrush=sugarrush, whoosh=whoosh)
    for name, make in effects.items():
        save(name, make())
    save("music", music(), peak=0.6)
    to_m4a("music")
