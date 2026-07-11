#!/usr/bin/env python3
"""Generate macOS tray icon candidates for FlClashB."""

from PIL import Image, ImageDraw, ImageFont
import math, os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "icon", "candidates")
SIZE = 54  # @3x, template images

os.makedirs(OUT_DIR, exist_ok=True)

def new_icon():
    """Create a new RGBA image with transparent background, ready for drawing."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    return img, draw

def save(img, name):
    path = os.path.join(OUT_DIR, f"tray_{name}.png")
    # Save at 1x (18px) as well for reference
    img.save(path)
    # For template icons on macOS, size doesn't matter much — they get scaled
    print(f"  Saved {path} ({img.size[0]}x{img.size[1]})")

def circle_bbox(cx, cy, r):
    return (cx - r, cy - r, cx + r, cy + r)

# ── Design 1: Globe / World ──────────────────────────────────────────────
def design_globe():
    """A minimal globe — circle with latitude/longitude arcs."""
    img, d = new_icon()
    cx, cy = SIZE / 2, SIZE / 2
    R = 21
    # Outer circle
    d.ellipse(circle_bbox(cx, cy, R), outline="black", width=2)
    # Equator (ellipse, middle)
    d.ellipse((cx - R, cy - 4, cx + R, cy + 4), outline="black", width=2)
    # Central meridian (ellipse, full height)
    d.ellipse((cx - 4, cy - R, cx + 4, cy + R), outline="black", width=2)
    # Upper latitude arc
    d.arc((cx - R + 2, cy - R + 2, cx + R - 2, cy + R - 2), 200, 340, fill="black", width=2)
    save(img, "globe")
    return img

# ── Design 2: Paper Plane ────────────────────────────────────────────────
def design_paperplane():
    """A paper plane in flight — modern, dynamic."""
    img, d = new_icon()
    m = 12  # margin
    # Body: triangle folded shape
    pts = [
        (m, SIZE // 2 + 6),        # bottom-left
        (SIZE // 2, SIZE // 2 - 4),# nose
        (SIZE - m, SIZE // 2 + 7), # bottom-right
        (SIZE // 2, SIZE // 2 + 7),# fold center
    ]
    d.polygon(pts, fill="black")
    save(img, "paperplane")
    return img

# ── Design 3: Transfer Arrows ────────────────────────────────────────────
def design_arrows():
    """Up/down arrows — representing proxy traffic."""
    img, d = new_icon()
    # Arrow head function: draw an arrow at (cx, cy) pointing in direction
    def arrow(cx, cy, direction):  # 0=up, 1=down
        s = 11  # arrow size
        sign = -1 if direction == 0 else 1
        tip = (cx, cy + sign * s)
        base_left = (cx - s * 0.6, cy - sign * s * 0.3)
        base_right = (cx + s * 0.6, cy - sign * s * 0.3)
        d.polygon([tip, base_left, base_right], fill="black")
    arrow(SIZE // 2, SIZE // 2 - 4, 0)  # up
    arrow(SIZE // 2, SIZE // 2 + 4, 1)  # down
    save(img, "arrows")
    return img

# ── Design 4: Network Node (Hex) ─────────────────────────────────────────
def design_hex():
    """Hexagon with a dot — network node / mesh symbol."""
    img, d = new_icon()
    cx, cy = SIZE / 2, SIZE / 2
    R = 18
    import math
    pts = []
    for i in range(6):
        angle = math.pi / 6 + i * math.pi / 3
        pts.append((cx + R * math.cos(angle), cy + R * math.sin(angle)))
    d.polygon(pts, outline="black", width=2)
    # Center dot
    d.ellipse(circle_bbox(cx, cy, 4), fill="black")
    save(img, "hex")
    return img

# ── Design 5: Shield ─────────────────────────────────────────────────────
def design_shield():
    """Shield outline — security, protection."""
    img, d = new_icon()
    m = 10
    w, h = SIZE - 2 * m, SIZE - 2 * m
    x0, y0 = m, m
    pts = [
        (x0 + w * 0.15, y0),          # top-left
        (x0 + w * 0.85, y0),          # top-right
        (x0 + w, y0 + h * 0.4),       # right shoulder
        (x0 + w * 0.5, y0 + h),       # bottom point
        (x0, y0 + h * 0.4),           # left shoulder
    ]
    d.polygon(pts, outline="black", width=2)
    save(img, "shield")
    return img

# ── Design 6: Signal / Radio Waves ───────────────────────────────────────
def design_signal():
    """WiFi-like arcs radiating from a dot — connectivity."""
    img, d = new_icon()
    cx, cy = SIZE / 2, SIZE / 2
    # Center dot
    d.ellipse(circle_bbox(cx, cy + 6, 3), fill="black")
    # Three arcs
    radii = [10, 16, 22]
    angles = [(210, 330)] * 3
    for i, r in enumerate(radii):
        d.arc((cx - r, cy + 6 - r, cx + r, cy + 6 + r), 210, 330, fill="black", width=2)
    save(img, "signal")
    return img

# ── Design 7: Chain Link ─────────────────────────────────────────────────
def design_link():
    """Two interlocking links — connection, proxy chaining."""
    img, d = new_icon()
    # Two overlapping rounded rectangles
    def rounded_rect(bb, r=7):
        x0, y0, x1, y1 = bb
        d.rounded_rectangle(bb, radius=r, outline="black", width=2)
    # Left link
    rounded_rect((7, 17, 32, 44), r=6)
    # Right link
    rounded_rect((22, 10, 47, 37), r=6)
    save(img, "link")
    return img

# ── Design 8: Chain Link v2 ──────────────────────────────────────────────
def design_chain():
    """Two interlocking circles — proxy chain."""
    img, d = new_icon()
    d.ellipse(circle_bbox(16, 21, 10), outline="black", width=2)
    d.ellipse(circle_bbox(38, 33, 10), outline="black", width=2)
    save(img, "chain")
    return img

# ── Design 8b: Bolt / Lightning ───────────────────────────────────────────
def design_bolt():
    """Lightning bolt — speed, power."""
    img, d = new_icon()
    m = 11
    pts = [
        (SIZE // 2, m),                  # top point
        (SIZE // 2 - 8, SIZE // 2 + 2),  # left waist
        (SIZE // 2 - 2, SIZE // 2),      # inner left
        (SIZE // 2, SIZE // 2 + 1),      # center waist
        (SIZE // 2 - 3, SIZE - m),       # bottom point
        (SIZE // 2 + 8, SIZE // 2 - 2),  # right waist
        (SIZE // 2 + 2, SIZE // 2),      # inner right
    ]
    d.polygon(pts, fill="black")
    save(img, "bolt")
    return img

# ── Design 9: Power Symbol ───────────────────────────────────────────────
def design_power():
    """Power on/off symbol — clean and recognizable."""
    img, d = new_icon()
    cx, cy = SIZE / 2, SIZE / 2
    R = 18
    thick = 4
    # Arc from ~60° to ~300° (open at top)
    d.arc(circle_bbox(cx, cy, R), 60, 300, fill="black", width=thick)
    # Vertical bar at top (gap in the ring)
    bar_top = cy - R + thick * 0.3
    bar_bot = cy - R * 0.45
    d.line([(cx, bar_top), (cx, bar_bot)], fill="black", width=thick)
    save(img, "power")
    return img

# ── Design 10: Minimal Dot Circle ────────────────────────────────────────
def design_circledot():
    """Circle with a centered dot — minimal, similar to current but with dot accent."""
    img, d = new_icon()
    cx, cy = SIZE / 2, SIZE / 2
    # Outer ring
    d.ellipse(circle_bbox(cx, cy, 18), outline="black", width=2)
    # Center dot
    d.ellipse(circle_bbox(cx, cy, 4.5), fill="black")
    save(img, "circledot")
    return img

# ── Generate All ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Generating tray icon candidates...")
    design_globe()
    design_paperplane()
    design_arrows()
    design_hex()
    design_shield()
    design_signal()
    design_link()
    design_chain()
    design_bolt()
    design_power()
    design_circledot()
    print(f"\nDone! All icons saved to {OUT_DIR}")
