"""L'occhio che si apre sulla luna piena: 4 celle grandi come la luna (48x48),
così si sovrappone esattamente. Cella 0 = chiuso, 3 = aperto."""
import math
from pathlib import Path

from PIL import Image

from palette import CLEAR, EYE_WHITE, GOLD, IRIS, IRIS_DARK, OUTLINE, PUPIL, WHITE

CELL = 48
CX, CY = 23.5, 25.5      # un filo sotto il centro della luna
HALF_W = 13.0            # mezza larghezza dell'occhio
OPEN_H = [0.0, 2.5, 5.0, 7.0]   # mezza altezza per cella
IRIS_R = 5.2


def eye_pixel(x: int, y: int, half_h: float) -> tuple:
    px, py = x + 0.5, y + 0.5
    nx = (px - CX) / HALF_W
    if abs(nx) > 1.0:
        return CLEAR
    # Forma a mandorla: l'altezza segue un arco di coseno.
    lid = half_h * math.cos(nx * math.pi / 2)
    dy = py - CY
    if half_h == 0.0:   # chiuso: una linea leggermente curva verso il basso
        curve = 1.2 * math.cos(nx * math.pi / 2)
        return OUTLINE if abs(dy - curve) < 0.6 else CLEAR
    if abs(dy) > lid + 0.9:
        return CLEAR
    if abs(dy) > lid - 0.3:
        return OUTLINE
    d = math.hypot(px - CX, py - CY)
    if abs(px - CX) < 0.9 and abs(dy) < IRIS_R + 0.5:
        return PUPIL                       # pupilla a fessura
    if d < IRIS_R - 1.6:
        return IRIS
    if d < IRIS_R - 0.6:
        return GOLD                        # anello d'oro, come l'occhio di Erbalta
    if d < IRIS_R + 0.4:
        return IRIS_DARK
    return EYE_WHITE


def draw_cell(half_h: float) -> Image.Image:
    img = Image.new("RGBA", (CELL, CELL), CLEAR)
    p = img.load()
    for y in range(CELL):
        for x in range(CELL):
            p[x, y] = eye_pixel(x, y, half_h)
    if half_h >= OPEN_H[-1]:
        p[int(CX) + 2, int(CY) - 3] = WHITE   # riflesso
    return img


def make_eye_sheet(path: Path) -> None:
    sheet = Image.new("RGBA", (CELL * len(OPEN_H), CELL), CLEAR)
    for i, h in enumerate(OPEN_H):
        sheet.paste(draw_cell(h), (i * CELL, 0))
    sheet.save(path)
