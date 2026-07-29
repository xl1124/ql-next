#!/usr/bin/env python3
import os
from PIL import Image
R = os.path.dirname(os.path.abspath(__file__))
img = Image.open(f'{R}/11.png').convert('RGBA')
px = img.load()
w, h = img.size

r, g, b, n = 0, 0, 0, 0
for x in range(w):
    for y in range(h):
        if px[x, y][3] > 128:
            r += px[x, y][0]
            g += px[x, y][1]
            b += px[x, y][2]
            n += 1
fill = (r // n, g // n, b // n) if n > 0 else (0, 0, 0)
print(f"Fill color: rgb{fill}")

for x in range(w):
    for y in range(h):
        if px[x, y][3] < 255:
            px[x, y] = (fill[0], fill[1], fill[2], 255)


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
