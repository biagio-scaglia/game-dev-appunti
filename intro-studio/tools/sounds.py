"""I suoni dell'intro, sintetizzati da zero in stile 8 bit (WAV mono 16 bit)."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050


def save_wav(path: Path, samples: list) -> None:
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.8 / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * gain * 32767)) for s in samples))


def square(phase: float) -> float:
    return 1.0 if (phase % 1.0) < 0.5 else -1.0


def triangle(phase: float) -> float:
    return 4 * abs((phase % 1.0) - 0.5) - 1


def rise() -> list:
    """La luna che sale: un accordo morbido (La, Mi) che cresce e sale piano."""
    n = int(RATE * 1.6)
    out = []
    for i in range(n):
        t = i / RATE
        bend = 1.0 + 0.06 * (i / n)
        env = min(1.0, t / 0.9) * (1.0 - max(0.0, (i / n - 0.75) / 0.25))
        s = triangle(t * 220 * bend) + 0.6 * triangle(t * 330 * bend) + 0.3 * triangle(t * 440 * bend)
        out.append(s * env)
    return out


def chime() -> list:
    """La luna piena: tre note (Mi, Si, Mi alto) che si sovrappongono e sfumano."""
    n = int(RATE * 1.6)
    out = [0.0] * n
    for start, f in ((0.0, 659.25), (0.12, 987.77), (0.24, 1318.5)):
        s0 = int(start * RATE)
        for i in range(n - s0):
            t = i / RATE
            env = math.exp(-t * 3.0) * min(1.0, t * 200)
            out[s0 + i] += (triangle(t * f) * 0.7 + square(t * f) * 0.12) * env
    return out


def blip() -> list:
    """Una lettera che appare: un 'tic' quadro brevissimo."""
    n = int(RATE * 0.035)
    return [square(i * 990 / RATE) * 0.5 * (1 - i / n) for i in range(n)]


def whoosh() -> list:
    """La stella cadente: un fruscio che scende, con un filo di nota sopra."""
    rnd = random.Random(3)
    n = int(RATE * 0.5)
    out, last, lp = [], 0.0, 0.0
    for i in range(n):
        t = i / n
        if i % 2 == 0:
            last = rnd.uniform(-1, 1)
        lp += (last - lp) * (0.5 - 0.4 * t)     # filtro che si chiude: il suono "scende"
        env = math.sin(math.pi * t) ** 2
        tone = triangle(i / RATE * (1800 - 900 * t)) * 0.25
        out.append((lp + tone) * env)
    return out


def thrum() -> list:
    """L'occhio che si apre: due battiti gravi, come un cuore lontano."""
    n = int(RATE * 0.9)
    out = [0.0] * n
    for start, amp in ((0.0, 1.0), (0.28, 0.7)):
        s0 = int(start * RATE)
        for i in range(min(int(RATE * 0.35), n - s0)):
            t = i / RATE
            f = 70 - 25 * min(1.0, t / 0.2)      # cade di tono: un tonfo
            env = math.exp(-t * 11) * min(1.0, t * 400)
            out[s0 + i] += (math.sin(2 * math.pi * f * t) + 0.3 * triangle(t * f * 2)) * env * amp
    return out


def make_all_sounds(out_dir: Path) -> None:
    sounds = (("rise", rise), ("chime", chime), ("blip", blip), ("whoosh", whoosh), ("thrum", thrum))
    for name, fn in sounds:
        save_wav(out_dir / f"{name}.wav", fn())
