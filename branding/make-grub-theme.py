#!/usr/bin/env python3
"""Render Constellation's GRUB theme images (branding/grub/).

The Fabergé Constellation Egg (1917) is a globe of deep blue glass set with the stars of
Leo, Tsarevich Alexei's sign. The boot menu takes that: enamel blue, a faint starfield,
Leo drawn in gold, and the Constellation mark.
    python3 branding/make-grub-theme.py
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE / 'grub'
W, H = 1920, 1080
TOP, BOTTOM = (22, 42, 104), (4, 9, 28)         # enamel blue, deepening downwards
GOLD = (224, 184, 104)
FONT = HERE / 'fonts/Inter-SemiBold.otf'

# Leo's brightest stars: (name, right ascension in hours, declination in degrees, magnitude)
LEO = [('Regulus', 10.139, 11.97, 1.4), ('Eta', 10.122, 16.76, 3.5), ('Algieba', 10.333, 19.84, 2.0),
       ('Adhafera', 10.278, 23.42, 3.4), ('Rasalas', 9.879, 26.01, 3.9), ('Algenubi', 9.764, 23.77, 3.0),
       ('Zosma', 11.235, 20.52, 2.6), ('Chertan', 11.237, 15.43, 3.3), ('Denebola', 11.818, 14.57, 2.1)]
LINES = [('Regulus', 'Eta'), ('Eta', 'Algieba'), ('Algieba', 'Adhafera'), ('Adhafera', 'Rasalas'),
         ('Rasalas', 'Algenubi'), ('Algieba', 'Zosma'), ('Zosma', 'Denebola'), ('Denebola', 'Chertan'),
         ('Chertan', 'Regulus'), ('Zosma', 'Chertan')]


def background() -> Image.Image:
    img = Image.new('RGB', (W, H))
    px = img.load()
    for y in range(H):                           # vertical gradient with a soft glow behind the menu
        for x in range(W):
            t = y / H
            d = math.hypot((x - W * 0.5) / W, (y - H * 0.55) / H)
            glow = max(0.0, 0.35 - d) * 0.9
            px[x, y] = tuple(min(255, round(a + (b - a) * t + 90 * glow * (i == 2) + 40 * glow * (i == 1)))
                             for i, (a, b) in enumerate(zip(TOP, BOTTOM)))
    rng = random.Random(1917)
    stars = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stars)
    for _ in range(900):                         # faint starfield
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.choice((0.6, 0.8, 1.0, 1.0, 1.3))
        a = rng.randint(40, 150)
        sd.ellipse((x - r, y - r, x + r, y + r), fill=(220, 230, 255, a))
    img.paste(stars, (0, 0), stars)

    # Leo, upper right, in gold: lines first, then glowing stars.
    pos = {}
    for name, ra, dec, mag in LEO:
        x = W * 0.78 + (10.8 - ra) * 250          # east is left on a sky chart
        y = H * 0.22 - (dec - 19.0) * 17
        pos[name] = (x, y, mag)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for a, b in LINES:
        ld.line((pos[a][:2], pos[b][:2]), fill=GOLD + (90,), width=2)
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for x, y, mag in pos.values():
        r = 4.5 * (4.5 - mag) + 4
        gd.ellipse((x - r * 2.2, y - r * 2.2, x + r * 2.2, y + r * 2.2), fill=GOLD + (70,))
    glow = glow.filter(ImageFilter.GaussianBlur(9))
    layer = Image.alpha_composite(glow, layer)
    ld = ImageDraw.Draw(layer)
    for x, y, mag in pos.values():
        r = 1.2 * (4.5 - mag) + 2
        ld.ellipse((x - r, y - r, x + r, y + r), fill=(255, 238, 200, 255))
    img.paste(layer, (0, 0), layer)

    # The mark and the name, top left.
    mark = logo(150)
    img.paste(mark, (110, 92), mark)
    d = ImageDraw.Draw(img)
    d.text((290, 110), 'Созвездие', font=ImageFont.truetype(str(FONT), 64), fill=(236, 240, 252))
    d.text((294, 192), 'CONSTELLATION', font=ImageFont.truetype(str(FONT), 26), fill=GOLD)
    return img


def logo(size: int) -> Image.Image:
    """The supplied mark, with its white background made transparent."""
    src = Image.open(HERE / 'constellation-logo.webp').convert('RGB')
    rgba = Image.new('RGBA', src.size)
    for (x, y), (r, g, b) in zip(((x, y) for y in range(src.height) for x in range(src.width)), src.get_flattened_data()):
        white = min(r, g, b)
        alpha = 0 if white > 238 else 255 if white < 200 else round((238 - white) / 38 * 255)
        rgba.putpixel((x, y), (r, g, b, alpha))
    rgba = rgba.crop(rgba.getchannel('A').getbbox())
    rgba.thumbnail((size, size), Image.LANCZOS)
    return rgba


def selection():
    """Nine-slice highlight for the selected menu entry: a soft gold-edged glass bar."""
    c = 14
    full = Image.new('RGBA', (3 * c, 3 * c), (0, 0, 0, 0))
    d = ImageDraw.Draw(full)
    d.rounded_rectangle((0, 0, 3 * c - 1, 3 * c - 1), radius=c - 2, fill=(90, 132, 210, 80), outline=GOLD + (200,), width=2)
    parts = {'nw': (0, 0), 'n': (1, 0), 'ne': (2, 0), 'w': (0, 1), 'c': (1, 1), 'e': (2, 1),
             'sw': (0, 2), 's': (1, 2), 'se': (2, 2)}
    for name, (i, j) in parts.items():
        full.crop((i * c, j * c, (i + 1) * c, (j + 1) * c)).save(OUT / f'select_{name}.png')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    background().save(OUT / 'background.png', optimize=True)
    background().resize((960, 540), Image.LANCZOS).save(HERE / 'grub-preview.png')
    selection()
    print('wrote', OUT)


if __name__ == '__main__':
    main()
