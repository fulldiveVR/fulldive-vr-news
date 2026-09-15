#!/usr/bin/env python3
"""Generates the Google Play listing artwork from the device captures.

    python3 tools/store_assets.py

Reads the raw screenshots in store/screenshots/raw/ and writes everything
Play asks for into store/metadata/en-US/images/ — the 512x512 icon, the
1024x500 feature graphic and the 1080x1920 phone screenshots.

Re-run it after retaking screenshots; nothing here is hand-edited, so the
listing can always be rebuilt from the app itself.
"""

from __future__ import annotations

import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

PROJECT = pathlib.Path(__file__).resolve().parent.parent
RAW = PROJECT / "store/screenshots/raw"
OUT = PROJECT / "store/metadata/en-US/images"
LOGO = PROJECT / "assets/images/fulldive_logo.png"
WORDMARK = PROJECT / "assets/images/fulldive_wordmark.png"

FONT_DIR = pathlib.Path.home() / "flutter/bin/cache/artifacts/material_fonts"

# Brand palette, same values the app uses (lib/src/theme/fulldive_theme.dart).
NAVY = (33, 46, 71)
NAVY_DEEP = (12, 19, 34)
NAVY_MID = (26, 36, 64)
ORANGE = (250, 138, 25)
WHITE = (255, 255, 255)

# Screenshot layout: copy lives between TEXT_TOP and DEVICE_TOP, device below.
TEXT_TOP = 90
DEVICE_TOP = 500
TITLE_LEADING = 96
SUBHEAD_LEADING = 52

SCREENSHOTS = [
    ("1_feed.png", "01_feed.png",
     "Every VR headline\nin one feed",
     "Road to VR, UploadVR, MIXED and more."),
    ("2_story.png", "02_reader.png",
     "Read the whole\nstory",
     "Full text, images and source in one tap."),
    ("3_reading.png", "03_reader_body.png",
     "Made for reading",
     "Clean type on a dark, distraction-free theme."),
    ("4_fresh.png", "04_feed_scrolled.png",
     "Never run out",
     "Scroll on — new stories load as you go."),
]


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    path = FONT_DIR / name
    if not path.exists():
        sys.exit(f"Missing font {path}. Run `flutter precache` or point FONT_DIR at a Roboto copy.")
    return ImageFont.truetype(str(path), size)


def gradient(size: tuple[int, int], top: tuple[int, int, int],
             bottom: tuple[int, int, int]) -> Image.Image:
    """Vertical linear gradient, drawn one row at a time."""
    width, height = size
    base = Image.new("RGB", (1, height))
    pixels = base.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        pixels[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return base.resize(size, Image.BILINEAR)


def add_glow(image: Image.Image, centre: tuple[int, int], radius: int,
             color: tuple[int, int, int], strength: float) -> None:
    """Soft radial light, painted as a blurred disc so the flat gradient
    picks up some depth without washing the brand colours out."""
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).ellipse(
        [centre[0] - radius, centre[1] - radius, centre[0] + radius, centre[1] + radius],
        fill=round(255 * strength),
    )
    mask = mask.filter(ImageFilter.GaussianBlur(radius * 0.55))
    image.paste(Image.new("RGB", image.size, color), (0, 0), mask)


def text_width(draw: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont) -> int:
    box = draw.textbbox((0, 0), text, font=f)
    return box[2] - box[0]


def draw_text_centred(draw: ImageDraw.ImageDraw, x: int, centre_y: int, text: str,
                      f: ImageFont.FreeTypeFont, fill) -> tuple[int, int]:
    """Draws `text` with its *ink* centred on `centre_y`.

    PIL positions text by the font's ascender, which sits well above the cap
    height, so aligning by the draw origin leaves text visibly off against
    anything else. Measuring the glyphs and correcting puts them where the eye
    expects. Returns the ink's (top, bottom).
    """
    x0, y0, x1, y1 = draw.textbbox((0, 0), text, font=f)
    top = centre_y - (y1 - y0) // 2
    draw.text((x, top - y0), text, font=f, fill=fill)
    return top, top + (y1 - y0)


def trimmed(image: Image.Image) -> Image.Image:
    """Crops a PNG to its non-transparent content.

    The Fulldive wordmark ships with ~25% vertical transparent padding, so
    scaling it by the file's height makes the letters both smaller than asked
    for and off-centre.
    """
    box = image.getbbox()
    return image.crop(box) if box else image


def rounded_shadow(canvas: Image.Image, box: tuple[int, int, int, int],
                   radius: int, blur: int, opacity: int) -> None:
    """Drop shadow under the device frame."""
    shadow = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(box, radius=radius, fill=opacity)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new("RGB", canvas.size, (0, 0, 0)), (0, 0), shadow)


def device_frame(screenshot: Image.Image, width: int) -> Image.Image:
    """Puts a screenshot in a simple black phone body with rounded corners."""
    bezel = max(round(width * 0.018), 8)
    inner_w = width - bezel * 2
    inner_h = round(screenshot.height * inner_w / screenshot.width)
    inner_radius = round(inner_w * 0.062)
    outer_radius = inner_radius + bezel

    shot = screenshot.convert("RGB").resize((inner_w, inner_h), Image.LANCZOS)
    mask = Image.new("L", (inner_w, inner_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, inner_w - 1, inner_h - 1],
                                           radius=inner_radius, fill=255)

    body = Image.new("RGBA", (width, inner_h + bezel * 2), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle(
        [0, 0, width - 1, inner_h + bezel * 2 - 1], radius=outer_radius, fill=(8, 12, 20, 255))
    body.paste(shot, (bezel, bezel), mask)
    return body


def build_icon() -> None:
    """512x512 Play icon: the launcher artwork on the brand navy, matching
    what the adaptive icon shows on the home screen."""
    size = 512
    canvas = Image.new("RGB", (size, size), NAVY)
    logo = Image.open(LOGO).convert("RGBA")
    mark = round(size * 0.78)
    logo = logo.resize((mark, mark), Image.LANCZOS)
    offset = (size - mark) // 2
    canvas.paste(logo, (offset, offset), logo)
    # Play wants a 32-bit PNG here: the background is opaque, but the file has
    # to carry an alpha channel or the uploader rejects it. The feature graphic
    # is the opposite — it must stay 24-bit, so only the icon gets converted.
    canvas.convert("RGBA").save(OUT / "icon.png")
    print(f"  icon.png            {size}x{size}")


def build_feature_graphic() -> None:
    """1024x500 feature graphic: mark on the left, headline on the right."""
    width, height = 1024, 500
    canvas = gradient((width, height), NAVY_MID, NAVY_DEEP)
    # Kept faint: orange over navy turns muddy brown well before it reads as a glow.
    add_glow(canvas, (150, 430), 260, ORANGE, 0.10)
    add_glow(canvas, (880, 60), 330, (70, 105, 170), 0.26)

    draw = ImageDraw.Draw(canvas)

    logo = Image.open(LOGO).convert("RGBA")
    mark = 248
    logo = logo.resize((mark, mark), Image.LANCZOS)
    canvas.paste(logo, (86, (height - mark) // 2), logo)

    headline = font("Roboto-Black.ttf", 52)
    lines = [("Every headline.", WHITE), ("Every source.", WHITE), ("One feed.", ORANGE)]
    x_bar, x_text, line_height = 400, 430, 68
    first_centre = (height - line_height * len(lines)) // 2 - 26 + line_height // 2

    for index, (line, color) in enumerate(lines):
        centre = first_centre + index * line_height
        top, bottom = draw_text_centred(draw, x_text, centre, line, headline, color)
        # Each bar spans exactly the glyphs it belongs to.
        draw.rounded_rectangle([x_bar, top, x_bar + 7, bottom],
                               radius=4, fill=ORANGE if index == 2 else (255, 255, 255, 90))

    # Bottom row sits on a shared baseline. Centring it instead would read as
    # crooked: the wordmark is all caps with no descenders, the tagline has them.
    baseline = first_centre + line_height * len(lines) + 6
    mark_h = 22

    wordmark = trimmed(Image.open(WORDMARK).convert("RGBA"))
    wordmark = wordmark.resize(
        (round(wordmark.width * mark_h / wordmark.height), mark_h), Image.LANCZOS)
    canvas.paste(wordmark, (x_text, baseline - mark_h), wordmark)

    tagline = font("Roboto-Medium.ttf", 24)
    divider_x = x_text + wordmark.width + 26
    draw.line([divider_x, baseline - mark_h - 7, divider_x, baseline + 7],
              fill=(255, 255, 255, 70), width=2)
    draw.text((divider_x + 26, baseline), "Virtual & mixed reality news",
              font=tagline, fill=(255, 255, 255, 200), anchor="ls")

    canvas.save(OUT / "featureGraphic.png")
    print(f"  featureGraphic.png  {width}x{height}")


def build_screenshot(name: str, source: pathlib.Path, headline: str, subhead: str) -> None:
    width, height = 1080, 1920
    canvas = gradient((width, height), NAVY_MID, NAVY_DEEP)
    add_glow(canvas, (width // 2, 1700), 520, ORANGE, 0.11)
    add_glow(canvas, (140, 150), 440, (70, 105, 170), 0.24)

    draw = ImageDraw.Draw(canvas)

    title = font("Roboto-Black.ttf", 78)
    body = font("Roboto-Regular.ttf", 38)

    title_lines = headline.split("\n")
    subhead_lines = subhead.split("\n")

    # The device sits at the same height on every screenshot, so the set reads
    # as one series in the Play carousel; the copy is centred above it.
    block_height = len(title_lines) * TITLE_LEADING + 14 + len(subhead_lines) * SUBHEAD_LEADING
    y = TEXT_TOP + (DEVICE_TOP - TEXT_TOP - block_height) // 2

    for line in title_lines:
        draw.text(((width - text_width(draw, line, title)) / 2, y), line,
                  font=title, fill=WHITE)
        y += TITLE_LEADING

    y += 14
    for line in subhead_lines:
        draw.text(((width - text_width(draw, line, body)) / 2, y), line,
                  font=body, fill=(255, 255, 255, 200))
        y += SUBHEAD_LEADING

    device = device_frame(Image.open(source), width=700)
    device_x = (width - device.width) // 2
    device_y = DEVICE_TOP
    rounded_shadow(canvas,
                   (device_x, device_y + 26, device_x + device.width, device_y + device.height),
                   radius=64, blur=40, opacity=150)
    canvas.paste(device, (device_x, device_y), device)

    canvas.save(OUT / "phoneScreenshots" / name)
    print(f"  {name:<20}{width}x{height}")


def main() -> None:
    (OUT / "phoneScreenshots").mkdir(parents=True, exist_ok=True)
    print(f"Writing to {OUT.relative_to(PROJECT)}")

    build_icon()
    build_feature_graphic()
    for name, raw, headline, subhead in SCREENSHOTS:
        source = RAW / raw
        if not source.exists():
            sys.exit(f"Missing capture {source.relative_to(PROJECT)}")
        build_screenshot(name, source, headline, subhead)


if __name__ == "__main__":
    main()
