#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
R = os.path.dirname(os.path.abspath(__file__))

# Use the existing mark as the source, but remove its outer padding and soften
# the source texture before producing small launcher sizes.
source = Image.open(f'{R}/web/icons/Icon-512.png').convert('RGB').resize(
    (1024, 1024), Image.Resampling.LANCZOS
)
source = ImageEnhance.Color(source).enhance(1.08)
source = ImageEnhance.Contrast(source).enhance(1.04)
source = source.filter(ImageFilter.MedianFilter(size=3))

img = Image.new('RGB', (1024, 1024), '#063c3a')
mask = Image.new('L', (1024, 1024), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    (0, 0, 1023, 1023), radius=180, fill=255
)
img.paste(source, (0, 0), mask)


def gen(name, size):
    d = os.path.join(R, name)
    os.makedirs(os.path.dirname(d), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(d)
    print(f"  {name} {size}x{size}")


ANDROID = [
    ("mipmap-mdpi", 48),
    ("mipmap-hdpi", 72),
    ("mipmap-xhdpi", 96),
    ("mipmap-xxhdpi", 144),
    ("mipmap-xxxhdpi", 192),
]
for folder, s in ANDROID:
    for n in ["ic_launcher.png", "ic_launcher_round.png"]:
        gen(f"android/app/src/main/res/{folder}/{n}", s)

IOS = [
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]
for n, s in IOS:
    gen(f"ios/Runner/Assets.xcassets/AppIcon.appiconset/{n}", s)

WEB = [("Icon-192.png", 192), ("Icon-512.png", 512),
       ("Icon-maskable-192.png", 192), ("Icon-maskable-512.png", 512)]
for n, s in WEB:
    gen(f"web/icons/{n}", s)

print("Done.")
