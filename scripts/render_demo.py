#!/usr/bin/env python3
"""Render docs/demo.txt into docs/demo.gif.

The transcript is produced by the MoonBit CLI, so this script only paints it.
Regenerate with:

    moon run cmd -- demo > docs/demo.txt
    python scripts/render_demo.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "demo.txt"
TARGET = ROOT / "docs" / "demo.gif"

PADDING = 24
LINE_HEIGHT = 24
FONT_SIZE = 15

BACKGROUND = (12, 14, 18)
TEXT = (228, 233, 240)
MUTED = (125, 135, 150)
HEADER = (250, 190, 90)
TRACE = (120, 220, 180)
WIRE = (130, 180, 250)


def load_font() -> ImageFont.FreeTypeFont:
    for path in (
        Path("C:/Windows/Fonts/consola.ttf"),
        Path("C:/Windows/Fonts/CascadiaMono.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), FONT_SIZE)
    raise SystemExit("no monospace font found")


def colour_for(line: str) -> tuple[int, int, int]:
    stripped = line.strip()
    if stripped.startswith("KNX "):
        return HEADER
    if " -> " in stripped:
        return TRACE
    if stripped.startswith(("lamp", "dimmer", "sensor", "frames on")):
        return MUTED
    if stripped.startswith(("BC ", "10 ")):
        return WIRE
    return TEXT


def size_for(lines: list[str], font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    width = max(probe.textlength(line, font=font) for line in lines)
    return int(width) + 2 * PADDING, len(lines) * LINE_HEIGHT + 2 * PADDING


def draw(
    lines: list[str],
    shown: int,
    font: ImageFont.FreeTypeFont,
    size: tuple[int, int],
) -> Image.Image:
    image = Image.new("RGB", size, BACKGROUND)
    painter = ImageDraw.Draw(image)
    y = PADDING
    for index, line in enumerate(lines):
        if index > shown:
            break
        painter.text((PADDING, y), line, font=font, fill=colour_for(line))
        y += LINE_HEIGHT
    return image


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"missing {SOURCE}")
    lines = [line.rstrip() for line in SOURCE.read_text(encoding="utf-8").splitlines()]
    font = load_font()
    size = size_for(lines, font)
    frames = [draw(lines, index, font, size) for index in range(len(lines))]
    frames.append(draw(lines, len(lines) - 1, font, size))
    durations = [80] * len(lines) + [2600]
    frames[0].save(
        TARGET,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True,
    )
    print(f"wrote {TARGET} ({len(frames)} frames, {size[0]}x{size[1]})")


if __name__ == "__main__":
    sys.exit(main())
