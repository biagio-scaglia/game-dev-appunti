"""La piccola OST dell'intro: 8 secondi in La minore, malinconica.
Un pad morbido, un basso e un carillon. È scritta sui tempi del regista
(studio_intro.gd), così ogni momento della scena ha la sua nota:

  0.0  notte e stelle        pad di La minore che cresce
  0.9  la luna sale/cresce   carillon: Mi, Do, La, Si...
  2.5  luna piena            ...Do, sul La minore che si apre
  3.05 l'occhio guarda       pad che scende in Re minore, un Sol# storto
  4.3  il nome               carillon che scende: Mi, Re, Do, Si
  5.7  "presenta"            La finale, accordo con la nona, sfuma
"""
import math
from pathlib import Path

from sounds import RATE, save_wav, triangle

LENGTH = 8.0
NOTES = {"D2": 73.42, "F2": 87.31, "A2": 110.0, "D3": 146.83, "F3": 174.61,
         "A3": 220.0, "C4": 261.63, "E4": 329.63, "G#4": 415.30, "A4": 440.0,
         "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25, "C6": 1046.5}

# (inizio, fine, note)
PAD = [(0.0, 3.1, ["A3", "C4", "E4"]), (3.0, 4.4, ["D3", "F3", "A3"]),
       (4.3, 5.8, ["F3", "A3", "C4", "E4"]), (5.7, 8.0, ["A3", "C4", "E4", "B4"])]
BASS = [(0.0, 3.1, "A2"), (3.0, 4.4, "D2"), (4.3, 5.8, "F2"), (5.7, 8.0, "A2")]
# (istante, nota, volume)
BOX = [(0.9, "E5", 1.0), (1.3, "C5", 0.9), (1.7, "A4", 0.9), (2.1, "B4", 0.9), (2.5, "C5", 1.0),
       (3.4, "G#4", 0.6),
       (4.35, "E5", 0.9), (4.6, "D5", 0.8), (4.85, "C5", 0.8), (5.1, "B4", 0.8),
       (5.7, "A4", 1.0), (5.7, "E5", 0.5), (6.3, "C6", 0.35)]


def pad_voice(f: float, t: float, span: float) -> float:
    """Due triangoli appena scordati (effetto chorus), attacco e rilascio lenti."""
    env = min(1.0, t / 0.9) * min(1.0, max(0.0, (span - t) / 0.6))
    return (triangle(t * f) + triangle(t * f * 1.004)) * 0.5 * env


def bass_voice(f: float, t: float, span: float) -> float:
    env = min(1.0, t / 0.3) * min(1.0, max(0.0, (span - t) / 0.4))
    return math.sin(2 * math.pi * f * t) * env


def box_voice(f: float, t: float) -> float:
    """Carillon: sinusoide, un'armonica e un parziale 'metallico', decadimento lungo."""
    env = math.exp(-t * 2.2) * min(1.0, t * 300)
    return (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t)
            + 0.12 * math.sin(2 * math.pi * f * 4.2 * t)) * env


def render() -> list:
    n = int(RATE * LENGTH)
    out = [0.0] * n

    def add(start: float, end: float, fn) -> None:
        s0, s1 = int(start * RATE), min(n, int(end * RATE))
        for i in range(s0, s1):
            out[i] += fn((i - s0) / RATE)

    for start, end, chord in PAD:
        for name in chord:
            add(start, end, lambda t, f=NOTES[name], s=end - start: 0.16 * pad_voice(f, t, s))
    for start, end, name in BASS:
        add(start, end, lambda t, f=NOTES[name], s=end - start: 0.35 * bass_voice(f, t, s))
    for start, name, vol in BOX:
        add(start, LENGTH, lambda t, f=NOTES[name], v=vol: 0.45 * v * box_voice(f, t))
    # Sfumatura finale, in tempo con la dissolvenza al nero.
    fade_from = int(7.1 * RATE)
    for i in range(fade_from, n):
        out[i] *= 1.0 - (i - fade_from) / (n - fade_from)
    return out


def make_theme(path: Path) -> None:
    save_wav(path, render())
