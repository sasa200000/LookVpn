#!/usr/bin/env python3
"""MiliConfig's metallic neon M emblem, drawn for every launcher, splash and status-bar size.

The mark is an angular, dark-metal M with a green neon rim, inside a thin green ring and
a tilted orbital ring. Everything is drawn once at high resolution and downsampled, so the
PNGs stay crisp at every density. Run from the repository root:

    python3 scripts/make_brand_assets.py

Needs Pillow (``pip install pillow``). The SVG sources in images/icon/ mirror it.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
GREEN = (56, 255, 92)
GREEN_HI = (184, 255, 184)
GREEN_DEEP = (5, 70, 26)
BG = (2, 4, 3)
MASTER = 1024
ORBIT_ANGLE = math.radians(-18)
ORBIT_CENTER = (512.0, 500.0)
ORBIT_RX, ORBIT_RY = 392.0, 158.0
RING_CENTER = (512.0, 512.0)
RING_RADIUS = 356.0

# Launcher artwork deliberately leaves a generous margin. Adaptive icons can be masked to a
# circle or squircle, so the mark must stay well inside the 66dp safe circle of the 108dp
# layer instead of touching the mask edge.
LEGACY_MARK_SCALE = 0.78
ROUND_MARK_SCALE = 0.72
ADAPTIVE_MARK_SCALE = 0.62
MONOCHROME_MARK_SCALE = 0.62

# The M itself sits slightly inside the outer ring instead of touching it.
M_SCALE = 0.88

# The angular M: two tapered blades and a thick central V, with open counters.
LEFT_BLADE = [(238.0, 205.0), (168.0, 770.0), (334.0, 610.0), (300.0, 300.0)]
RIGHT_BLADE = [(786.0, 205.0), (856.0, 770.0), (690.0, 610.0), (724.0, 300.0)]
V_POINTS = [(238.0, 205.0), (512.0, 730.0), (786.0, 205.0)]


def scaled(points: list[tuple[float, float]], factor: float) -> list[tuple[float, float]]:
    return [(x * factor, y * factor) for x, y in points]


def m_mask(size: int) -> Image.Image:
    """The solid M silhouette: two blades connected by a wide central V.

    The mark is drawn at [M_SCALE] and pasted centred, so it sits inside the ring rather
    than bleeding into it. This also gives the round and adaptive masks a real margin.
    """
    inner = max(1, int(size * M_SCALE))
    mark = Image.new("L", (inner, inner), 0)
    d = ImageDraw.Draw(mark)
    for points in (LEFT_BLADE, RIGHT_BLADE):
        d.polygon(scaled(points, inner / 1024), fill=255)
    d.line(
        scaled(V_POINTS, inner / 1024),
        fill=255,
        width=max(2, int(inner * 0.118)),
        joint="curve",
    )
    # Sharper peaks and a needle-sharp centre point.
    for x in (238.0, 786.0):
        d.polygon(
            scaled([(x - 38, 255), (x, 160), (x + 38, 255)], inner / 1024),
            fill=255,
        )
    d.polygon(
        scaled([(470, 675), (512, 810), (554, 675)], inner / 1024),
        fill=255,
    )
    mask = Image.new("L", (size, size), 0)
    mask.paste(mark, ((size - inner) // 2, (size - inner) // 2))
    return mask


def ellipse_point(
    cx: float, cy: float, rx: float, ry: float, angle: float, t: float
) -> tuple[float, float]:
    x, y = rx * math.cos(t), ry * math.sin(t)
    return (
        cx + x * math.cos(angle) - y * math.sin(angle),
        cy + x * math.sin(angle) + y * math.cos(angle),
    )


def ribbon(
    layer: Image.Image,
    *,
    start: float,
    end: float,
    width: float,
    color: tuple[int, int, int],
    alpha: int = 255,
    rx: float = ORBIT_RX,
    ry: float = ORBIT_RY,
) -> None:
    """One arc of the orbital ring, as a ribbon whose thickness follows the angle."""
    draw = ImageDraw.Draw(layer)
    steps = 180
    outer: list[tuple[float, float]] = []
    inner: list[tuple[float, float]] = []
    for i in range(steps + 1):
        t = start + (end - start) * i / steps
        # Thickest across the bottom/front, thinnest at the back, like the reference.
        w = width * (0.62 + 0.38 * (0.5 + 0.5 * math.sin(t)))
        outer.append(
            ellipse_point(*ORBIT_CENTER, rx + w / 2, ry + w / 2, ORBIT_ANGLE, t)
        )
        inner.append(
            ellipse_point(*ORBIT_CENTER, rx - w / 2, ry - w / 2, ORBIT_ANGLE, t)
        )
    draw.polygon(outer + inner[::-1], fill=(*color, alpha))


def add_orbit(img: Image.Image, *, front: bool, width: float = 22.0) -> None:
    """Draw the back or front half of the orbit, with its green bloom."""
    start, end = (0.0, math.pi) if front else (math.pi, 2 * math.pi)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ribbon(glow, start=start, end=end, width=width * 1.75, color=GREEN, alpha=110)
    glow = glow.filter(ImageFilter.GaussianBlur(width * 1.15))
    img.alpha_composite(glow)

    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ribbon(base, start=start, end=end, width=width, color=(3, 38, 16), alpha=255)
    ribbon(base, start=start, end=end, width=width * 0.78, color=(20, 180, 58), alpha=255)
    ribbon(base, start=start, end=end, width=width * 0.48, color=GREEN, alpha=255)
    ribbon(base, start=start, end=end, width=width * 0.18, color=GREEN_HI, alpha=220)
    img.alpha_composite(base)


def add_ring(img: Image.Image, width: float = 13.0) -> None:
    box = (
        RING_CENTER[0] - RING_RADIUS,
        RING_CENTER[1] - RING_RADIUS,
        RING_CENTER[0] + RING_RADIUS,
        RING_CENTER[1] + RING_RADIUS,
    )
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(box, outline=(*GREEN, 130), width=int(width * 2.1))
    glow = glow.filter(ImageFilter.GaussianBlur(width * 1.7))
    img.alpha_composite(glow)

    line = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(line)
    d.ellipse(box, outline=(*GREEN_DEEP, 255), width=int(width * 1.25))
    d.ellipse(box, outline=(*GREEN, 255), width=int(width * 0.74))
    d.ellipse(box, outline=(*GREEN_HI, 210), width=max(1, int(width * 0.18)))
    img.alpha_composite(line)


def gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    grad = Image.new("RGB", (1, size))
    px = grad.load()
    for y in range(size):
        t = y / max(1, size - 1)
        px[0, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return grad.resize((size, size), Image.BILINEAR)


def metallic_fill(size: int, mask: Image.Image) -> Image.Image:
    """Dark brushed metal for the M: vertical falloff, sheen and fine grain."""
    fill = gradient(size, (44, 96, 64), (9, 22, 14)).convert("RGBA")
    sheen = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(sheen)
    # A diagonal blade of light across the upper half.
    d.polygon(
        [(0, size * 0.34), (size * 0.58, 0), (size * 0.88, 0), (0, size * 0.62)],
        fill=(190, 255, 205, 44),
    )
    fill = Image.alpha_composite(fill, sheen)

    # Fine grain and faint vertical brushing.
    random.seed(7)
    texture = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    td = ImageDraw.Draw(texture)
    for _ in range(2200):
        x, y = random.randrange(size), random.randrange(size)
        td.line(
            [(x, y), (x, y + random.randint(2, 22))],
            fill=(210, 255, 220, random.randint(2, 8)),
            width=1,
        )
    fill = Image.alpha_composite(fill, texture)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(fill, (0, 0), mask)
    return out


def tint(mask: Image.Image, color: tuple[int, int, int], alpha: int = 255) -> Image.Image:
    out = Image.new("RGBA", mask.size, (*color, 0))
    out.putalpha(mask.point(lambda v: min(255, v * alpha // 255)))
    return out


def add_m(img: Image.Image, size: int) -> None:
    mask = m_mask(size)
    # The silhouette is drawn at M_SCALE and centred in m_mask; facets and highlights must
    # use the same transform or they no longer line up with the blades.
    mark_span = size * M_SCALE
    mark_offset = (size - mark_span) / 2

    def m_points(points):
        return [
            (
                mark_offset + x * mark_span / 1024,
                mark_offset + y * mark_span / 1024,
            )
            for x, y in points
        ]

    # Projected shadow gives the mark thickness.
    shadow_mask = Image.new("L", (size, size), 0)
    shadow_mask.paste(mask, (int(size * 0.018), int(size * 0.022)))
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow.putalpha(shadow_mask.point(lambda v: int(v * 0.9)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.012))
    img.alpha_composite(shadow)

    # Ambient bloom around the rim.
    wide_rim = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(31)))
    bloom = tint(wide_rim, GREEN, 190).filter(ImageFilter.GaussianBlur(size * 0.030))
    img.alpha_composite(bloom)

    img.alpha_composite(metallic_fill(size, mask))

    # Folded-metal facets: upper surfaces catch light, lower surfaces fall into shadow.
    facet = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fd = ImageDraw.Draw(facet)
    fd.polygon(m_points(LEFT_BLADE), fill=(150, 255, 180, 30))
    fd.polygon(m_points(RIGHT_BLADE), fill=(0, 8, 4, 54))
    fd.line(
        m_points(V_POINTS),
        fill=(210, 255, 222, 16),
        width=max(2, int(size * 0.118 * M_SCALE)),
        joint="curve",
    )
    facet.putalpha(Image.composite(facet.getchannel("A"), Image.new("L", (size, size), 0), mask))
    img.alpha_composite(facet)

    # A thin green neon rim follows the silhouette's real edge, including the counters.
    rim = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(29)))
    rim_glow = tint(rim, GREEN, 245).filter(ImageFilter.GaussianBlur(size * 0.010))
    img.alpha_composite(rim_glow)
    img.alpha_composite(tint(rim, GREEN, 255))
    inner_rim = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(7)))
    img.alpha_composite(tint(inner_rim, GREEN_HI, 190))

    # Silver ridge down the centre of the V and along the blades' inner edges.
    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.line(
        m_points(V_POINTS),
        fill=(232, 255, 238, 190),
        width=max(1, int(size * 0.0038 * M_SCALE)),
        joint="curve",
    )
    for blade in (LEFT_BLADE, RIGHT_BLADE):
        hd.line(
            m_points([blade[3], blade[2]]),
            fill=(205, 255, 218, 115),
            width=max(1, int(size * 0.0030 * M_SCALE)),
        )
    highlight = highlight.filter(ImageFilter.GaussianBlur(max(1, size * 0.0008)))
    img.alpha_composite(highlight)

    # Two small reflected glints at the peaks.
    glint = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glint)
    for x, y in ((238, 205), (786, 205)):
        r = size * 0.010 * M_SCALE
        gx = mark_offset + x * mark_span / 1024
        gy = mark_offset + y * mark_span / 1024
        gd.ellipse(
            (gx - r, gy - r, gx + r, gy + r),
            fill=(225, 255, 232, 210),
        )
    glint = glint.filter(ImageFilter.GaussianBlur(size * 0.0016))
    img.alpha_composite(glint)


def mark_image(size: int) -> Image.Image:
    """Transparent canvas with the complete emblem (ring, orbit, M and glow), centred."""
    master = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    add_ring(master)
    add_orbit(master, front=False)
    add_m(master, MASTER)
    add_orbit(master, front=True)
    # The orbit is asymmetric; centre the visible glow rather than the nominal 512,512 point.
    bbox = master.getbbox()
    if bbox is not None:
        visible = master.crop(bbox)
        centred = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
        centred.alpha_composite(
            visible,
            ((MASTER - visible.width) // 2, (MASTER - visible.height) // 2),
        )
        master = centred
    return master.resize((size, size), Image.LANCZOS)


_BACKGROUND: Image.Image | None = None


def background(size: int, round_icon: bool = False) -> Image.Image:
    """Near-black field with a soft green halo behind the emblem."""
    global _BACKGROUND
    if _BACKGROUND is None:
        master = Image.new("RGBA", (MASTER, MASTER), (*BG, 255))
        px = master.load()
        c = MASTER / 2
        max_r = MASTER * 0.58
        for y in range(MASTER):
            for x in range(MASTER):
                dist = math.hypot(x - c, y - c)
                t = max(0.0, 1.0 - dist / max_r)
                halo = t * t * t
                px[x, y] = (
                    int(BG[0] + 8 * halo),
                    int(BG[1] + 34 * halo),
                    int(BG[2] + 16 * halo),
                    255,
                )
        _BACKGROUND = master
    out = _BACKGROUND.resize((size, size), Image.LANCZOS)
    if round_icon:
        mask = Image.new("L", out.size, 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size, size), fill=255)
        rounded = Image.new("RGBA", out.size, (0, 0, 0, 0))
        rounded.paste(out, (0, 0), mask)
        return rounded
    return out


def legacy_icon(size: int, round_icon: bool = False) -> Image.Image:
    base = background(size, round_icon=round_icon)
    mark_size = int(size * (ROUND_MARK_SCALE if round_icon else LEGACY_MARK_SCALE))
    mark = mark_image(mark_size)
    base.alpha_composite(mark, ((size - mark_size) // 2, (size - mark_size) // 2))
    return base


def adaptive_foreground(size: int) -> Image.Image:
    # Adaptive icons are 108dp; the visible safe zone is the central 66dp. Keep the whole
    # emblem comfortably inside it, with a visible black margin on every mask shape.
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark_size = int(size * ADAPTIVE_MARK_SCALE)
    mark = mark_image(mark_size)
    canvas.alpha_composite(mark, ((size - mark_size) // 2, (size - mark_size) // 2))
    return canvas


def monochrome_icon(size: int) -> Image.Image:
    """Android 13 themed icon: a clean white silhouette, no colour or glow."""
    canvas = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    # Ring and orbit at low weight so the M remains the focus.
    box = (
        RING_CENTER[0] - RING_RADIUS,
        RING_CENTER[1] - RING_RADIUS,
        RING_CENTER[0] + RING_RADIUS,
        RING_CENTER[1] + RING_RADIUS,
    )
    d.ellipse(box, outline=(255, 255, 255, 255), width=12)
    # Themed icons stay clean: the M plus its outer ring, without the orbital band.
    canvas.alpha_composite(tint(m_mask(MASTER), (255, 255, 255)))
    # The monochrome layer uses the same safe-zone scale as the colour foreground.
    out = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    mark_size = int(MASTER * MONOCHROME_MARK_SCALE)
    mark = canvas.resize((mark_size, mark_size), Image.LANCZOS)
    out.alpha_composite(mark, ((MASTER - mark_size) // 2, (MASTER - mark_size) // 2))
    return out.resize((size, size), Image.LANCZOS)


def notification_icon(size: int) -> Image.Image:
    """Status-bar icons are alpha-only: a bold white M on transparent."""
    s = MASTER
    canvas = tint(m_mask(s), (255, 255, 255))
    return canvas.resize((size, size), Image.LANCZOS)


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  {image.size[0]}x{image.size[1]}")


def main() -> None:
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    densities = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}

    print("Launcher icons (adaptive layers included)")
    for density, scale in densities.items():
        folder = res / f"mipmap-{density}"
        save(legacy_icon(int(48 * scale)), folder / "ic_launcher.png")
        save(legacy_icon(int(48 * scale), round_icon=True), folder / "ic_launcher_round.png")
        save(adaptive_foreground(int(108 * scale)), folder / "ic_launcher_foreground.png")
        save(background(int(108 * scale)), folder / "ic_launcher_background.png")
        save(monochrome_icon(int(108 * scale)), folder / "ic_launcher_monochrome.png")
        save(mark_image(int(160 * scale)), res / f"drawable-{density}" / "splash_icon.png")
        save(notification_icon(int(24 * scale)), res / f"drawable-{density}" / "ic_stat_vpn.png")

    print("In-app title icon")
    for folder, size in (("", 24), ("1.5x", 36), ("2.0x", 48), ("3.0x", 72), ("4.0x", 96)):
        path = ROOT / "assets" / "icons" / folder
        save(notification_icon(size), path / "ic_stat_vpn.png")

    print("Brand source preview")
    save(legacy_icon(512, round_icon=True), ROOT / "images" / "icon" / "preview.png")


if __name__ == "__main__":
    main()
