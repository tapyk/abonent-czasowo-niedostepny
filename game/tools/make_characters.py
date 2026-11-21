"""Builds the in-game character strips from the team's 64x64 drawings.

Source: assets/source/johnny/*.png and assets/source/ludzie/*.png (64x64, drawn
mostly in 2x2 pixel blocks). Output: assets/sprites/characters/hd/*.png.

Every drawing is halved to 32x32 (each 2x2 block becomes its most common opaque
colour, so the art keeps its look) and turned into a strip of 5 frames, 32x32 each:

    0  standing (the drawing itself)
    1  step: left leg lifted 1 px, body up 1 px
    2  standing
    3  step: right leg lifted 1 px, body up 1 px
    4  breath: head and torso 1 px lower (idle)

Johnny's poses (idle, shoot_flat/up/down, each also with the muzzle-flash variant)
share one horizontal shift so the body stays in place when the pose changes.
The dead worker becomes a single trimmed image (worker.png).

Run from game/:  python tools/make_characters.py
"""

from collections import Counter
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "source"
OUT = ROOT / "assets" / "sprites" / "characters" / "hd"
F = 32  # frame size


def halve(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px: Any = img.load()
    out = Image.new("RGBA", (w // 2, h // 2), (0, 0, 0, 0))
    po: Any = out.load()
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            block = [px[x, y], px[x + 1, y], px[x, y + 1], px[x + 1, y + 1]]
            solid = [c for c in block if c[3] >= 128]
            if len(solid) >= 2:
                # Most common colour; ties go to the darker one (keeps outlines).
                counts = Counter(solid)
                best = max(counts.items(), key=lambda kv: (kv[1], -sum(kv[0][:3])))[0]
                po[x // 2, y // 2] = best[:3] + (255,)
    return out


def shift(img: Image.Image, dx: int) -> Image.Image:
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(img, (dx, 0)) if dx >= 0 else out.alpha_composite(img.crop((-dx, 0, img.width, img.height)), (0, 0))
    return out


def body_box(img: Image.Image) -> tuple[int, int, int, int]:
    bbox = img.getbbox()
    assert bbox is not None
    return bbox


def frames(img: Image.Image, legs_x: tuple[int, int], top: int, bottom: int) -> list[Image.Image]:
    """img: 32x32 drawing. legs_x: (left edge, right edge) of the legs, top/bottom:
    figure rows. The hip line sits at 70% of the figure height."""
    hip = top + int((bottom - top) * 0.70)
    mid = (legs_x[0] + legs_x[1]) // 2

    def step(left: bool) -> Image.Image:
        out = Image.new("RGBA", img.size, (0, 0, 0, 0))
        # upper body 1 px up
        out.alpha_composite(img.crop((0, 0, F, hip)), (0, -1))
        out.alpha_composite(img.crop((0, hip, F, F)), (0, hip))
        # the hip row is drawn twice so nothing tears between body and legs
        out.alpha_composite(img.crop((0, hip, F, hip + 1)), (0, hip - 1))
        # lift one leg by 1 px (its bottom row disappears)
        x0, x1 = (0, mid) if left else (mid, F)
        leg = img.crop((x0, hip, x1, F))
        clear = Image.new("RGBA", (x1 - x0, F - hip), (0, 0, 0, 0))
        out.paste(clear, (x0, hip))
        out.alpha_composite(img.crop((x0, hip - 1, x1, hip)), (x0, hip - 1))
        out.alpha_composite(leg, (x0, hip - 1))
        return out

    def breath() -> Image.Image:
        out = Image.new("RGBA", img.size, (0, 0, 0, 0))
        out.alpha_composite(img.crop((0, hip, F, F)), (0, hip))
        out.alpha_composite(img.crop((0, 0, F, hip)), (0, 1))
        return out

    return [img, step(True), img, step(False), breath()]


def strip(fr: list[Image.Image]) -> Image.Image:
    s = Image.new("RGBA", (F * len(fr), F), (0, 0, 0, 0))
    for i, f in enumerate(fr):
        s.alpha_composite(f, (i * F, 0))
    return s


def legs_of(img: Image.Image, top: int, bottom: int) -> tuple[int, int]:
    """Horizontal extent of the opaque pixels in the bottom 20% of the figure."""
    y0 = top + int((bottom - top) * 0.8)
    px: Any = img.load()
    xs = [x for y in range(y0, bottom) for x in range(F) if px[x, y][3] > 0]
    return (min(xs), max(xs) + 1)


def make_set(name: str, files: dict[str, str], folder: Path) -> None:
    imgs = {k: halve(Image.open(folder / v)) for k, v in files.items()}
    base = imgs["idle"]
    bx0, by0, bx1, by1 = body_box(base)
    legs = legs_of(base, by0, by1)
    # centre the body (the legs) on the frame, the same for every pose
    dx = F // 2 - (legs[0] + legs[1]) // 2
    legs = (legs[0] + dx, legs[1] + dx)
    for k, img in imgs.items():
        img = shift(img, dx)
        strip(frames(img, legs, by0, by1)).save(OUT / f"{name}_{k}.png")
        print("wrote", f"{name}_{k}.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    make_set("johnny", {
        "idle": "idle.png",
        "shoot_flat": "shoot_flat.png", "shoot_flat_fire": "shoot_flat_2.png",
        "shoot_up": "shoot_up.png", "shoot_up_fire": "shoot_up_2.png",
        "shoot_down": "shoot_down.png", "shoot_down_fire": "shoot_down2.png",
    }, SRC / "johnny")
    lz = SRC / "ludzie"
    for name, file in [("farmer", "farmer.png"), ("braun", "donaldbraun.png"),
                       ("mutant", "mutant_bialy.png"), ("mutant_burnt", "mutant_spalony.png")]:
        make_set(name, {"idle": file}, lz)
    worker = halve(Image.open(lz / "worker.png"))
    wb = worker.getbbox()
    if wb is not None:
        worker.crop(wb).save(OUT / "worker_dead.png")
    print("wrote worker_dead.png")


if __name__ == "__main__":
    main()
