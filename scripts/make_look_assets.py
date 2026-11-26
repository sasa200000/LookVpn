#!/usr/bin/env python3
"""Builds LookVPN's launcher, splash and status-bar icons from images/icon/source.jpg.

The supplied artwork is one 512x512 card: a chrome shield holding a rainbow fibre-optic eye,
with the wordmark "LookVpn" underneath. Launcher icons cannot show the wordmark legibly at
48dp, so every generated asset uses the shield-and-eye mark only, cropped out of the card and
re-composited at each density.

Run from the repository root:

    python3 scripts/make_look_assets.py

Needs Pillow (``pip install pillow``).
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "images" / "icon" / "source.jpg"

# The card is 512x512. Everything below the mark's bottom point is the wordmark, which we drop;
# the emblem occupies this band of the source.
MARK_BAND = (58, 290)
LUMA_FLOOR = 92

# Near-black field sampled from the card's corners.
BG = (2, 2, 3)

# Launcher artwork keeps a generous margin: adaptive icons may be masked to a circle or a
# squircle, so the mark must sit inside the 66dp safe circle of the 108dp layer.
ADAPTIVE_MARK_SCALE = 0.60
LEGACY_MARK_SCALE = 0.80
ROUND_MARK_SCALE = 0.72
MONOCHROME_MARK_SCALE = 0.60

_MASTER: Image.Image | None = None


def mark_bbox(src: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of the glowing emblem, excluding the wordmark under it."""
    luma = src.convert("L")
    w, _ = luma.size
    px = luma.load()
    left, right = w, 0
    top, bottom = luma.size[1], 0
    for y in range(MARK_BAND[0], MARK_BAND[1]):
        for x in range(w):
            if px[x, y] > LUMA_FLOOR:
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
    if right <= left:
        raise SystemExit("Could not find the emblem in images/icon/source.jpg")
    return left, top, right + 1, bottom + 1


def square_mark() -> Image.Image:
    """The emblem alone on a square field: the wordmark under it is cut away entirely.

    The card stacks the mark over the wordmark, so no symmetric square crop can avoid the
    text. Crop the mark's own bounding box (plus a little of its glow), then centre it on a
    square of the card's own background instead.
    """
    global _MASTER
    if _MASTER is not None:
        return _MASTER
    src = Image.open(SOURCE).convert("RGB")
    box = mark_bbox(src)
    pad = 6
    crop = src.crop(
        (
            max(0, box[0] - pad),
            max(0, box[1] - pad),
            min(src.width, box[2] + pad),
            min(MARK_BAND[1], box[3] + pad),
        )
    )
    side = int(max(crop.width, crop.height) * 1.06)
    tile = Image.new("RGB", (side, side), BG)
    tile.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2))

    scale = 8
    _MASTER = tile.resize((side * scale, side * scale), Image.LANCZOS).convert("RGBA")
    return _MASTER


def background(size: int, round_icon: bool = False) -> Image.Image:
    """The card's near-black field with its soft centre glow."""
    master = Image.new("RGB", (256, 256), BG)
    px = master.load()
    c = 128.0
    for y in range(256):
        for x in range(256):
            t = max(0.0, 1.0 - math.hypot(x - c, y - c) / (256 * 0.62))
            halo = t * t * t
            px[x, y] = (int(BG[0] + 10 * halo), int(BG[1] + 12 * halo), int(BG[2] + 22 * halo))
    out = master.resize((size, size), Image.LANCZOS).convert("RGBA")
    if round_icon:
        mask = Image.new("L", out.size, 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
        rounded = Image.new("RGBA", out.size, (0, 0, 0, 0))
        rounded.paste(out, (0, 0), mask)
        return rounded
    return out


def composed(size: int, mark_scale: float, round_icon: bool = False) -> Image.Image:
    base = background(size, round_icon=round_icon)
    mark_size = int(size * mark_scale)
    mark = square_mark().resize((mark_size, mark_size), Image.LANCZOS)
    base.alpha_composite(mark, ((size - mark_size) // 2, (size - mark_size) // 2))
    return base


def adaptive_foreground(size: int) -> Image.Image:
    """A full-bleed dark layer carrying a centred mark, safe inside any adaptive mask."""
    canvas = Image.new("RGBA", (size, size), (*BG, 255))
    mark_size = int(size * ADAPTIVE_MARK_SCALE)
    mark = square_mark().resize((mark_size, mark_size), Image.LANCZOS)
    canvas.alpha_composite(mark, ((size - mark_size) // 2, (size - mark_size) // 2))
    return canvas


def _shield_path(size: int, width: float) -> list[tuple[float, float]]:
    """Shield outline points in unit space (0-100), scaled to size."""
    pts: list[tuple[float, float]] = []

    def add(x: float, y: float) -> None:
        pts.append((x / 100 * size, y / 100 * size))

    # Top edge, then a bezier sweep down each flank to the bottom point.
    add(30, 12)
    add(70, 12)
    for i in range(1, 25):
        t = i / 24
        # cubic from (70,12) to (50,92) bulging out to x=88
        x = (1 - t) ** 3 * 70 + 3 * (1 - t) ** 2 * t * 90 + 3 * (1 - t) * t**2 * 74 + t**3 * 50
        y = (1 - t) ** 3 * 12 + 3 * (1 - t) ** 2 * t * 34 + 3 * (1 - t) * t**2 * 70 + t**3 * 92
        add(x, y)
    for i in range(1, 25):
        t = i / 24
        x = (1 - t) ** 3 * 50 + 3 * (1 - t) ** 2 * t * 26 + 3 * (1 - t) * t**2 * 10 + t**3 * 30
        y = (1 - t) ** 3 * 92 + 3 * (1 - t) ** 2 * t * 70 + 3 * (1 - t) * t**2 * 34 + t**3 * 12
        add(x, y)
    return pts


def _almond(size: int) -> list[tuple[float, float]]:
    """The eye's lens shape: two mirrored arcs meeting at the corners."""
    pts: list[tuple[float, float]] = []

    def add(x: float, y: float) -> None:
        pts.append((x / 100 * size, y / 100 * size))

    for i in range(0, 41):
        t = i / 40
        add(22 + 56 * t, 46 - 15 * math.sin(math.pi * t))
    for i in range(0, 41):
        t = i / 40
        add(78 - 56 * t, 46 + 15 * math.sin(math.pi * t))
    return pts


def emblem_silhouette(size: int, *, rim_only: bool) -> Image.Image:
    """A clean vector silhouette of the shield and eye, drawn at 8x and downsampled.

    Thresholding the artwork would carry its JPEG noise into a 108dp themed icon, so the
    themed and status-bar icons redraw the same shape geometrically instead.
    """
    ss = 8
    big = size * ss
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    rim = max(2, int(big * 0.030))
    if rim_only:
        draw.line(_shield_path(big, rim), fill=(255, 255, 255, 255), width=rim, joint="curve")
        draw.line(_almond(big), fill=(255, 255, 255, 255), width=int(rim * 0.9), joint="curve")
        draw.ellipse(
            (
                big * 0.46,
                big * 0.46 - big * 0.055,
                big * 0.54,
                big * 0.46 + big * 0.055,
            ),
            fill=(255, 255, 255, 255),
        )
    else:
        # Solid shield with the eye punched out, so the mark survives at 24dp.
        draw.polygon(_shield_path(big, rim), fill=(255, 255, 255, 255))
        draw.polygon(_almond(big), fill=(255, 255, 255, 0))
    return canvas.resize((size, size), Image.LANCZOS)



def monochrome_icon(size: int) -> Image.Image:
    inner = int(size * MONOCHROME_MARK_SCALE * 1.7)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark = emblem_silhouette(inner, rim_only=False)
    out.alpha_composite(mark, ((size - inner) // 2, (size - inner) // 2))
    return out


def notification_icon(size: int) -> Image.Image:
    inner = int(size * 0.94)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark = emblem_silhouette(inner, rim_only=True)
    out.alpha_composite(mark, ((size - inner) // 2, (size - inner) // 2))
    return out


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  {image.size[0]}x{image.size[1]}")


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing artwork: {SOURCE}")
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    densities = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}

    box = mark_bbox(Image.open(SOURCE).convert("RGB"))
    print(f"Emblem in source: x {box[0]}-{box[2]}, y {box[1]}-{box[3]}")

    print("Launcher icons (adaptive layers included)")
    for density, scale in densities.items():
        folder = res / f"mipmap-{density}"
        save(composed(int(48 * scale), LEGACY_MARK_SCALE), folder / "ic_launcher.png")
        save(composed(int(48 * scale), ROUND_MARK_SCALE, round_icon=True), folder / "ic_launcher_round.png")
        save(adaptive_foreground(int(108 * scale)), folder / "ic_launcher_foreground.png")
        save(background(int(108 * scale)), folder / "ic_launcher_background.png")
        save(monochrome_icon(int(108 * scale)), folder / "ic_launcher_monochrome.png")
        splash = int(160 * scale)
        save(composed(splash, LEGACY_MARK_SCALE).convert("RGBA"), res / f"drawable-{density}" / "splash_icon.png")
        save(notification_icon(int(24 * scale)), res / f"drawable-{density}" / "ic_stat_vpn.png")

    print("In-app logo and title icon")
    save(square_mark().resize((512, 512), Image.LANCZOS), ROOT / "assets" / "look" / "logo.png")
    for folder, size in (("", 24), ("1.5x", 36), ("2.0x", 48), ("3.0x", 72), ("4.0x", 96)):
        save(notification_icon(size), ROOT / "assets" / "icons" / folder / "ic_stat_vpn.png")

    print("Brand preview")
    save(composed(512, LEGACY_MARK_SCALE), ROOT / "images" / "icon" / "preview.png")


if __name__ == "__main__":
    main()
