#!/usr/bin/env python3
"""Generates the Alfie app icon (three discs on a money-green ground) per the
design handoff geometry, as a proportional-to-size drawing so one script
produces a clean icon at any resolution. Not part of the app target — run
manually and commit the resulting PNG.

Usage: python3 scripts/generate_app_icon.py
"""

from PIL import Image, ImageDraw

SIZE = 1024

GROUND = "#0E7C6B"
DISC_LOWER_LEFT = "#F7F4EE"
DISC_LOWER_RIGHT = "#C05E45"
DISC_TOP = "#A07A22"

DISC_DIAMETER_FRACTION = 0.449
CENTERS_FRACTION = {
    "lower_left": (0.383, 0.605),
    "lower_right": (0.617, 0.605),
    "top": (0.5, 0.391),
}


def draw_disc(draw: ImageDraw.ImageDraw, s: int, center_fraction: tuple[float, float], color: str) -> None:
    radius = (DISC_DIAMETER_FRACTION * s) / 2
    cx, cy = center_fraction[0] * s, center_fraction[1] * s
    bbox = (cx - radius, cy - radius, cx + radius, cy + radius)
    draw.ellipse(bbox, fill=color)


def main() -> None:
    image = Image.new("RGB", (SIZE, SIZE), GROUND)
    draw = ImageDraw.Draw(image)

    # Stacking order: lower-left, lower-right, then top drawn last (on top).
    draw_disc(draw, SIZE, CENTERS_FRACTION["lower_left"], DISC_LOWER_LEFT)
    draw_disc(draw, SIZE, CENTERS_FRACTION["lower_right"], DISC_LOWER_RIGHT)
    draw_disc(draw, SIZE, CENTERS_FRACTION["top"], DISC_TOP)

    out_path = "Bruschetta/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    image.save(out_path, "PNG")
    print(f"Wrote {out_path} ({image.size[0]}x{image.size[1]}, mode={image.mode})")


if __name__ == "__main__":
    main()
