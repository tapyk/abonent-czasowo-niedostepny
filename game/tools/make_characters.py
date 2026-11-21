"""Builds the in-game character strips from the team's 64x64 drawings.

Source: assets/source/johnny/*.png and assets/source/ludzie/*.png (64x64, drawn
mostly in 2x2 pixel blocks; Adam Białawski's czarny_*.png are 128x128 in 4x4 blocks).
Output: assets/sprites/characters/hd/*.png.

Every drawing is halved down to 32x32 (each 2x2 block becomes its most common opaque
colour, so the art keeps its look) and turned into a strip of 5 frames, 32x32 each:

    0  standing (the drawing itself)
    1  step: left leg lifted 1 px, body up 1 px
    2  standing
    3  step: right leg lifted 1 px, body up 1 px
    4  breath: head and torso 1 px lower (idle)

Johnny's poses (idle, shoot_flat/up/down, each also with the muzzle-flash variant)
share one horizontal shift so the body stays in place when the pose changes, and
all wear the aluminium cap (czapka.png, drawn on the same 64x64 canvas). Extra:
johnny_cap.png (the cap alone, where it sits in the frame; it falls off on death)
and johnny_dead.png (the drawing without the cap turned 90 degrees, lying).
Player 2, Adam Białawski (bialawski_*): the same poses from czarny_front / up / down
(*2 = firing), no cap (bald: the waves bounce off), and bialawski_dead.png.
The dead worker becomes a single trimmed image (worker.png).

Run from game/:  python tools/make_characters.py
"""

from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "source"
OUT = ROOT / "assets" / "sprites" / "characters" / "hd"
F = 32  # frame size


def halve(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    out = Image.new("RGBA", (w // 2, h // 2), (0, 0, 0, 0))
    po = out.load()
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


def shift(img: Image.Image, dx: int, dy: int = 0) -> Image.Image:
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (dx, dy), img)
    return out


def body_box(img: Image.Image) -> tuple[int, int, int, int]:
    return img.getbbox()


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
    xs = [x for y in range(y0, bottom) for x in range(F) if img.getpixel((x, y))[3] > 0]
    return (min(xs), max(xs) + 1)


def make_set(name: str, files: dict[str, str], folder: Path, overlay: Path | None = None) -> int:
    def load(v: str) -> Image.Image:
        im = Image.open(folder / v).convert("RGBA")
        if overlay:
            im.alpha_composite(Image.open(overlay).convert("RGBA"))
        while im.width > F:
            im = halve(im)
        return im
    imgs = {k: load(v) for k, v in files.items()}
    base = imgs["idle"]
    bx0, by0, bx1, by1 = body_box(base)
    legs = legs_of(base, by0, by1)
    # centre the body (the legs) on the frame, the same for every pose
    dx = F // 2 - (legs[0] + legs[1]) // 2
    legs = (legs[0] + dx, legs[1] + dx)
    # touching the top edge: one row down, so the step frames (body up 1 px) keep it
    dy = 1 if by0 == 0 and by1 < F else 0
    for k, img in imgs.items():
        img = shift(img, dx, dy)
        strip(frames(img, legs, by0 + dy, by1 + dy)).save(OUT / f"{name}_{k}.png")
        print("wrote", f"{name}_{k}.png")
    return dx, dy


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    lz = SRC / "ludzie"
    jw = SRC / "johnny"
    cap = lz / "czapka.png"
    dx, dy = make_set("johnny", {
        "idle": "idle.png",
        "shoot_flat": "shoot_flat.png", "shoot_flat_fire": "shoot_flat_2.png",
        "shoot_up": "shoot_up.png", "shoot_up_fire": "shoot_up_2.png",
        "shoot_down": "shoot_down.png", "shoot_down_fire": "shoot_down2.png",
    }, jw, cap)
    shift(halve(Image.open(cap)), dx, dy).save(OUT / "johnny_cap.png")
    print("wrote johnny_cap.png")
    # lying: rotated in the 64 px original (lossless), halved, feet line at the bottom
    dead = halve(Image.open(jw / "idle.png").convert("RGBA").rotate(90))
    x0, y0, x1, y1 = dead.getbbox()
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    out.paste(dead.crop((x0, y0, x1, y1)), ((F - (x1 - x0)) // 2, F - 1 - (y1 - y0)))
    out.save(OUT / "johnny_dead.png")
    print("wrote johnny_dead.png")
    make_set("bialawski", {
        "idle": "czarny_front.png",
        "shoot_flat": "czarny_front.png", "shoot_flat_fire": "czarny_front2.png",
        "shoot_up": "czarny_up.png", "shoot_up_fire": "czarny_up2.png",
        "shoot_down": "czarny_down.png", "shoot_down_fire": "czarny_down2.png",
    }, lz)
    dead = Image.open(lz / "czarny_front.png").convert("RGBA").rotate(90)
    while dead.width > F:
        dead = halve(dead)
    x0, y0, x1, y1 = dead.getbbox()
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    out.paste(dead.crop((x0, y0, x1, y1)), ((F - (x1 - x0)) // 2, F - 1 - (y1 - y0)))
    out.save(OUT / "bialawski_dead.png")
    print("wrote bialawski_dead.png")
    for name, file in [("farmer", "farmer.png"), ("braun", "donaldbraun.png"), ("mama", "mama.png"),
                       ("mutant", "mutant_bialy.png"), ("mutant_burnt", "mutant_spalony.png")]:
        make_set(name, {"idle": file}, lz)
    worker = halve(Image.open(lz / "worker.png"))
    worker.crop(worker.getbbox()).save(OUT / "worker_dead.png")
    print("wrote worker_dead.png")


if __name__ == "__main__":
    main()
