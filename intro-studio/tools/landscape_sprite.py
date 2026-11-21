"""Il paesaggio all'orizzonte: colline lontane, una fila di pini e il lago.
Un'unica striscia larga (copre anche gli schermi più larghi del 16:9)."""
import math
import random
from pathlib import Path

from PIL import Image

from palette import CLEAR, HILLS_FAR, HILLS_NEAR, WATER, WATER_LINE

WIDTH = 760
HEIGHT = 130
HORIZON = 34             # riga dove inizia l'acqua


def hill_height(x: int, waves: list) -> float:
    return sum(a * math.sin(x * f + ph) for a, f, ph in waves)


def draw_pine(p, cx: int, base: int, h: int) -> None:
    """Un pino a triangoli impilati, tutto in silhouette."""
    for y in range(h):
        half = int((y % max(3, h // 3)) * 0.8 + y * 0.18) // 1
        for x in range(cx - half, cx + half + 1):
            if 0 <= x < WIDTH and 0 <= base - h + y < HEIGHT:
                p[x, base - h + y] = HILLS_NEAR


def make_landscape(path: Path) -> None:
    rnd = random.Random(11)
    img = Image.new("RGBA", (WIDTH, HEIGHT), CLEAR)
    p = img.load()
    far = [(5, 0.011, 0.4), (3, 0.027, 1.9), (1.5, 0.061, 0.7)]
    near = [(3, 0.019, 2.2), (2, 0.043, 0.3)]
    for x in range(WIDTH):
        top_far = int(HORIZON - 19 - hill_height(x, far))
        top_near = int(HORIZON - 8 - hill_height(x, near))
        for y in range(max(0, top_far), HORIZON):
            p[x, y] = HILLS_FAR
        for y in range(max(0, top_near), HORIZON):
            p[x, y] = HILLS_NEAR
    # Pini sparsi sulla collina vicina, mai al centro (lì si riflette la luna).
    x = 6
    while x < WIDTH:
        if abs(x - WIDTH // 2) > 70:
            draw_pine(p, x, HORIZON, rnd.randint(12, 22))
        x += rnd.randint(7, 16)
    # Il lago: scuro, con qualche riga d'onda appena più chiara.
    for y in range(HORIZON, HEIGHT):
        for x in range(WIDTH):
            p[x, y] = WATER
    for _ in range(60):
        y = rnd.randint(HORIZON + 3, HEIGHT - 1)
        x0 = rnd.randint(0, WIDTH - 20)
        for x in range(x0, x0 + rnd.randint(4, 14)):
            p[x, y] = WATER_LINE
    img.save(path)
