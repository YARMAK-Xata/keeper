#!/usr/bin/env python3
"""Builds Keeper's app icon from the knight sprite. Requires Pillow and iconutil.

The icon is a close crop of the sprite — helmet, eyes, shield, sword — and the whole design
rests on one rule: **every icon size must be a whole number of screen pixels per sprite pixel.**
The 1024 master is filled edge to edge by a 16 x 16 sprite crop at exactly 64 px each, so 512,
256, 128, 64, 32 and 16 all divide cleanly. The previous icon scaled the sprite by 30 and landed
off that grid, which is why its small sizes smudged. The assertions below keep that from
coming back quietly.

Two artefacts come out, because macOS 26 and macOS 14-15 want different things:

  Assets/AppIcon.icon   an Icon Composer bundle: flat layers plus icon.json, no baked shadow,
                        highlight or gradient. macOS 26 lights it live and derives the Dark,
                        Clear and Tinted appearances from it. scripts/build-app.sh compiles it.
  Assets/AppIcon.icns   for macOS 14 and 15, which do not mask app icons, so this one draws its
                        own rounded square with a highlight and a shadow that approximate what
                        macOS 26 renders. Never seen on macOS 26, which prefers CFBundleIconName.
"""
import math
import os
import subprocess
import json
import tempfile
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CANVAS = 1024
CROP = 16                      # sprite pixels across the icon
TOP_ROW = 3                    # first sprite row of the crop, measured down the 22 px character
BACKGROUND = (0x0E, 0x10, 0x20)

# The legacy icon draws its own rounded square inside the canvas. 832 keeps the sprite on whole
# pixels there too; Apple's own grid is 824, and 1% is not a difference anyone can see.
LEGACY_SIDE = 832
SQUIRCLE_N = 5.0

assert CANVAS % CROP == 0, "the master must divide into whole sprite pixels"
assert LEGACY_SIDE % CROP == 0, "the legacy square must divide into whole sprite pixels"
PPX = CANVAS // CROP           # 64
LEGACY_PPX = LEGACY_SIDE // CROP


def portrait(pixels_per_sprite_pixel):
    """The crop, nearest-neighbour scaled. Transparent where the sprite is transparent."""
    sheet = Image.open(os.path.join(ROOT, "Assets", "knight-rgsdev-v3.png")).convert("RGBA")
    # The character sits at (24, 26) in the sheet and is 16 wide by 22 tall, top-down.
    crop = sheet.crop((24, 26 + TOP_ROW, 24 + CROP, 26 + TOP_ROW + CROP))
    side = CROP * pixels_per_sprite_pixel
    return crop.resize((side, side), Image.NEAREST)


def squircle_mask(size, side, samples=4):
    """A superellipse: the continuous-curve rounded square macOS used for app icons before it
    began masking them itself. Drawn at 4x and resampled so the curve has no stair-steps."""
    big = size * samples
    mask = Image.new("L", (big, big), 0)
    a = side * samples / 2
    centre = big / 2
    steps = 720
    points = []
    for i in range(steps + 1):
        t = 2 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        x = a * abs(ct) ** (2 / SQUIRCLE_N) * math.copysign(1, ct)
        y = a * abs(st) ** (2 / SQUIRCLE_N) * math.copysign(1, st)
        points.append((centre + x, centre + y))
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def icon_source():
    """Writes Assets/AppIcon.icon — the layers macOS 26 lights itself."""
    bundle = os.path.join(ROOT, "Assets", "AppIcon.icon")
    assets = os.path.join(bundle, "Assets")
    os.makedirs(assets, exist_ok=True)

    layer = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    layer.alpha_composite(portrait(PPX), (0, 0))
    layer.save(os.path.join(assets, "Knight.png"))

    r, g, b = (c / 255 for c in BACKGROUND)
    manifest = {
        "fill": {"solid": f"srgb:{r:.3f},{g:.3f},{b:.3f},1.000"},
        "groups": [
            {
                "layers": [{"image-name": "Knight.png", "name": "Knight"}],
                # The system's own shadow and specular. Nothing is baked into the layer: a
                # pre-rendered highlight collides with the live one and comes out muddy.
                "shadow": {"kind": "neutral", "opacity": 0.5},
                "specular": True,
                "translucency": {"enabled": False, "value": 0.5},
            }
        ],
        "supported-platforms": {"circles": ["watchOS"], "squares": ["iOS", "macOS"]},
    }
    with open(os.path.join(bundle, "icon.json"), "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    return bundle


def legacy_master():
    """The macOS 14/15 artwork: the crop inside a rounded square that carries its own shading."""
    icon = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    mask = squircle_mask(CANVAS, LEGACY_SIDE)

    # The drop shadow macOS 26 casts for you, and older systems expect in the artwork.
    shadow = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 90), (0, 0), mask)
    icon.alpha_composite(ImageChops.offset(shadow, 0, 18).filter(ImageFilter.GaussianBlur(20)))

    plate = Image.new("RGBA", icon.size, BACKGROUND + (255,))
    art = portrait(LEGACY_PPX)
    offset = (CANVAS - LEGACY_SIDE) // 2
    plate.alpha_composite(art, (offset, offset))

    # A restrained highlight down the top third, standing in for the live specular.
    sheen = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    pixels = sheen.load()
    top, depth = offset, LEGACY_SIDE * 0.42
    for y in range(top, int(top + depth)):
        alpha = round(26 * (1 - (y - top) / depth))
        if alpha <= 0:
            continue
        for x in range(CANVAS):
            pixels[x, y] = (255, 255, 255, alpha)
    plate.alpha_composite(sheen)

    clipped = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    clipped.paste(plate, (0, 0), mask)
    icon.alpha_composite(clipped)
    return icon


def write_icns(master):
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.mkdir(iconset)
        for base in (16, 32, 128, 256, 512):
            for suffix, size in ((f"{base}x{base}", base), (f"{base}x{base}@2x", base * 2)):
                master.resize((size, size), Image.LANCZOS).save(
                    os.path.join(iconset, f"icon_{suffix}.png"))
        out = os.path.join(ROOT, "Assets", "AppIcon.icns")
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out], check=True)
        return out


if __name__ == "__main__":
    bundle = icon_source()
    print("wrote", bundle, f"({CROP}x{CROP} sprite pixels at {PPX} px each)")
    master = legacy_master()
    master.save(os.path.join(ROOT, "Assets", "AppIcon-1024.png"))
    print("wrote", write_icns(master), f"(legacy, {LEGACY_PPX} px per sprite pixel)")
