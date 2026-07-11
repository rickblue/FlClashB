#!/usr/bin/env python3
"""Create a contact sheet of all tray icon candidates for easy comparison."""
from PIL import Image, ImageDraw, ImageFont
import os, glob

CANDIDATES_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "icon", "candidates")
OUT_PATH = os.path.join(CANDIDATES_DIR, "_preview_sheet.png")

files = sorted(glob.glob(os.path.join(CANDIDATES_DIR, "tray_*.png")))
files = [f for f in files if "_sheet" not in f]

CELL = 80
GAP = 8
COLS = 4
ROWS = (len(files) + COLS - 1) // COLS

W = COLS * CELL + (COLS + 1) * GAP
H = ROWS * (CELL + 30) + (ROWS + 1) * GAP

canvas = Image.new("RGB", (W, H), (40, 40, 42))
draw = ImageDraw.Draw(canvas)

try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
except Exception:
    font = ImageFont.load_default()

for i, f in enumerate(files):
    col, row = i % COLS, i // COLS
    x = GAP + col * CELL
    y = GAP + row * (CELL + 30)

    # Draw cell background
    draw.rectangle([x, y, x + CELL - 1, y + CELL - 1], fill=(30, 30, 32))

    img = Image.open(f)
    # Center in cell
    iw, ih = img.size
    scale = min(CELL * 0.7 / iw, CELL * 0.7 / ih)
    nw, nh = int(iw * scale), int(ih * scale)
    img_resized = img.resize((nw, nh), Image.LANCZOS)
    ox, oy = x + (CELL - nw) // 2, y + (CELL - nh) // 2
    # Paste with alpha as mask
    canvas.paste(img_resized, (ox, oy), img_resized if img.mode == 'RGBA' else None)

    # Label
    name = os.path.splitext(os.path.basename(f))[0].replace("tray_", "")
    tw = draw.textlength(name, font=font) if hasattr(draw, 'textlength') else len(name) * 8
    draw.text((x + (CELL - tw) // 2, y + CELL + 5), name, fill=(200, 200, 205), font=font)

canvas.save(OUT_PATH)
print(f"Saved preview sheet: {OUT_PATH}")
