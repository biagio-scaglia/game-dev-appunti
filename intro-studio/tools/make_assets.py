"""Genera gli asset dell'intro dello studio: luna, occhio, paesaggio e suoni.

Uso (dalla cartella intro-studio):
    python tools/make_assets.py

Scrive in studio_intro/assets/. Tutto è generato da zero: niente asset di terzi,
a parte il font Kenney (CC0) che sta già nella cartella.
Palette presa da Erbalta (vedi palette.py), così le intro e i giochi si somigliano.
"""
from pathlib import Path

from eye_sprite import make_eye_sheet
from landscape_sprite import make_landscape
from moon_sprite import make_moon_sheet, make_sparkle_sheet
from music import make_theme
from sounds import make_all_sounds

OUT = Path(__file__).resolve().parent.parent / "studio_intro" / "assets"

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    make_moon_sheet(OUT / "moon_phases.png")
    make_eye_sheet(OUT / "moon_eye.png")
    make_sparkle_sheet(OUT / "sparkle.png")
    make_landscape(OUT / "landscape.png")
    make_all_sounds(OUT)
    make_theme(OUT / "intro_theme.wav")
    print("Asset scritti in", OUT)
