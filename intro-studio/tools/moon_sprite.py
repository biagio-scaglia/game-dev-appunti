"""La luna: un foglio di fasi, dalla luna nuova alla piena, e le scintille."""
import math
from pathlib import Path

from PIL import Image

from palette import CLEAR, CREAM, CREAM_SHADE, GOLD, NIGHT_CRATER, NIGHT_SIDE, OUTLINE, WHITE

CELL = 48            # lato di una cella
CENTER = 23.5        # centro del disco
RADIUS = 20.0
PHASES = 12          # celle: 0 = luna nuova, PHASES-1 = luna piena
# Crateri in coordinate normalizzate del disco (x, y, raggio), da -1 a 1.
CRATERS = [(-0.35, -0.30, 0.22), (0.30, 0.25, 0.28), (0.45, -0.45, 0.12),
           (-0.15, 0.50, 0.14), (-0.55, 0.20, 0.10)]


def is_lit(nx: float, ny: float, phase: float) -> bool:
    """Luna crescente illuminata da destra. phase 0 = nuova, 1 = piena.
    Il terminatore è un'ellisse: x = t * sqrt(1 - y²), con t che va da 1 a -1."""
    t = 1.0 - 2.0 * phase
    return nx > t * math.sqrt(max(0.0, 1.0 - ny * ny))


def in_crater(nx: float, ny: float) -> bool:
    return any((nx - cx) ** 2 + (ny - cy) ** 2 < cr ** 2 for cx, cy, cr in CRATERS)


def moon_pixel(x: int, y: int, phase: float) -> tuple:
    px, py = x + 0.5, y + 0.5
    d = math.hypot(px - CENTER, py - CENTER)
    if d > RADIUS + 0.5:
        return CLEAR
    if d > RADIUS - 0.6:
        return OUTLINE
    nx, ny = (px - CENTER) / RADIUS, (py - CENTER) / RADIUS
    crater = in_crater(nx, ny)
    if is_lit(nx, ny, phase):
        return CREAM_SHADE if crater else CREAM
    return NIGHT_CRATER if crater else NIGHT_SIDE


def draw_phase(phase: float) -> Image.Image:
    img = Image.new("RGBA", (CELL, CELL), CLEAR)
    p = img.load()
    for y in range(CELL):
        for x in range(CELL):
            p[x, y] = moon_pixel(x, y, phase)
    return img


def make_moon_sheet(path: Path) -> None:
    sheet = Image.new("RGBA", (CELL * PHASES, CELL), CLEAR)
    for i in range(PHASES):
        sheet.paste(draw_phase(i / (PHASES - 1)), (i * CELL, 0))
    sheet.save(path)


def make_sparkle_sheet(path: Path) -> None:
    """Scintilla a 4 punte, 4 celle da 7x7: nasce, piena, cala, puntino."""
    shapes = [
        ["...", ".x.", "..."],
        ["..x..", "..x..", "xxXxx", "..x..", "..x.."],
        ["...x...", "...x...", "...x...", "xxxXxxx", "...x...", "...x...", "...x..."],
        [".x.", "xXx", ".x."],
    ]
    sheet = Image.new("RGBA", (7 * len(shapes), 7), CLEAR)
    p = sheet.load()
    for i, rows in enumerate(shapes):
        off = (7 - len(rows)) // 2
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    p[i * 7 + off + x, off + y] = WHITE if ch == "X" else GOLD
    sheet.save(path)
