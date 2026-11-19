# Builds the app icon for iPhone, iPad and Android from tank-coral.png.
#
#   python3 tools/brand/app_icon.py      (needs Pillow: pip install pillow)
#
# tank-coral.png is the tank from the Tropic Blue shirt print file
# (battle-baseball-350-tropicblue-300dpi.png): its tan fill recolored to the
# shirt's coral red #FF585D, black outlines and drop shadow kept, the BATTLE
# letters cut away. The icon puts it on Royal Blue, the app's own blue.
#
# ios/Runner/Assets.xcassets/AppIcon.appiconset  every size in Contents.json
# android/app/src/main/res/mipmap-*/ic_launcher.png  the square icon
# android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  the adaptive
#   icon's tank (Android 8+), on @color/ic_launcher_background
# assets/brand/tank.png  the tank alone, 480 px wide, beside Battle Shop's
#   name in its header (ShopMark in lib/screens/merch.dart)
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BLUE = (0x1F, 0x4F, 0xC4)  # Royal Blue, BB.field
tank = Image.open(Path(__file__).with_name("tank-coral.png")).convert("RGBA")


def square(width_frac, background):
    """The tank centered on a square, width_frac of its width, nudged down a
    hair so the heavy hull sits on the optical center. Built at the tank's
    full size and only ever scaled down."""
    side = round(tank.width / width_frac)
    canvas = Image.new("RGBA", (side, side), background)
    x = (side - tank.width) // 2
    y = (side - tank.height) // 2 + round(side * 0.01)
    canvas.alpha_composite(tank, (x, y))
    return canvas


def save(img, size, path, rgb=True):
    out = img.resize((size, size), Image.LANCZOS)
    (out.convert("RGB") if rgb else out).save(path, optimize=True)


# iPhone and iPad: full-bleed square, no transparency (iOS rounds it).
icon = square(0.88, BLUE + (255,))
ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for image in json.loads((ios / "Contents.json").read_text())["images"]:
    points = float(image["size"].split("x")[0])
    save(icon, round(points * int(image["scale"][0])), ios / image["filename"])

# Android: the square icon for older phones, and an adaptive icon. The
# adaptive foreground is 108 dp; launchers show the middle 72 dp and may cut
# to a 66 dp circle, so the tank stays 60 dp wide.
res = ROOT / "android/app/src/main/res"
fg = square(60 / 108, (0, 0, 0, 0))
for density, scale in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
    save(icon, round(48 * scale), res / f"mipmap-{density}/ic_launcher.png")
    save(fg, round(108 * scale), res / f"mipmap-{density}/ic_launcher_foreground.png", rgb=False)

# In the app: the tank on nothing, small enough to ship.
tank.resize((480, round(tank.height * 480 / tank.width)), Image.LANCZOS).save(
    ROOT / "assets/brand/tank.png", optimize=True
)
