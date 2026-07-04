"""
Generate the Sonic Cloud launcher icon as a high-resolution PNG.

The icon combines the brand's three signature elements:
  1. Deep indigo background (#131318) — the "Cloud" base
  2. A vibrant cyan sound-wave arc — the "Sonic" energy
  3. A glassmorphic circular disc — premium depth

Output: assets/icon/icon.png at 1024x1024 (rasterized down by
flutter_launcher_icons to all platform densities).
"""
from PIL import Image, ImageDraw, ImageFilter
import os

OUT = "/home/z/my-project/download/sonic_cloud_flutter/assets/icon/icon.png"
SIZE = 1024

# Brand colors
BG = (19, 19, 24)              # #131318 surface
PRIMARY_CONTAINER = (18, 18, 43)  # #12122B
CYAN = (0, 244, 254)           # #00F4FE secondary-container
VIOLET = (127, 102, 255)       # #7F66FF on-tertiary-container

img = Image.new("RGBA", (SIZE, SIZE), BG + (255,))
draw = ImageDraw.Draw(img, "RGBA")

cx, cy = SIZE // 2, SIZE // 2

# 1. Background radial glow (primary-container fading out)
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow, "RGBA")
for r in range(SIZE, 0, -8):
    alpha = int(80 * (1 - r / SIZE) ** 2)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=PRIMARY_CONTAINER + (alpha,))
img = Image.alpha_composite(img, glow)
draw = ImageDraw.Draw(img, "RGBA")

# 2. Outer glassmorphic ring (light edge)
ring_outer = int(SIZE * 0.42)
draw.ellipse(
    [cx - ring_outer, cy - ring_outer, cx + ring_outer, cy + ring_outer],
    outline=(255, 255, 255, 50),
    width=4,
)

# 3. Vinyl disc (dark gradient with cyan tint)
disc_r = int(SIZE * 0.35)
for r in range(disc_r, 0, -2):
    t = r / disc_r
    # interpolate from deep cyan-tinted indigo to near-black
    rr = int(BG[0] * (1 - t * 0.3) + PRIMARY_CONTAINER[0] * t * 0.5)
    gg = int(BG[1] * (1 - t * 0.3) + PRIMARY_CONTAINER[1] * t * 0.5)
    bb = int(BG[2] * (1 - t * 0.3) + PRIMARY_CONTAINER[2] * t * 0.5 + CYAN[2] * t * 0.2)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(rr, gg, bb, 255))

# 4. Sonic waveform — concentric arc segments with simulated glow
def draw_arc_glow(cx, cy, radius, start_deg, end_deg, color, width):
    bbox = [cx - radius, cy - radius, cx + radius, cy + radius]
    # Multiple wider arcs at lower alpha to simulate glow
    for w_extra, a in [(width + 18, 30), (width + 10, 60), (width + 4, 110)]:
        draw.arc(bbox, start_deg, end_deg, fill=color + (a,), width=w_extra)
    # Core
    draw.arc(bbox, start_deg, end_deg, fill=color + (255,), width=width)

# Outer cyan arc — sweeping around the upper-left
draw_arc_glow(cx, cy, int(SIZE * 0.30), 200, 340, CYAN, 14)
# Middle violet arc — sweeping around the lower-right
draw_arc_glow(cx, cy, int(SIZE * 0.22), 20, 160, VIOLET, 10)
# Inner cyan arc — top accent
draw_arc_glow(cx, cy, int(SIZE * 0.14), 250, 290, CYAN, 6)

# 5. Center spindle hole (vinyl style)
spindle_outer = int(SIZE * 0.05)
spindle_inner = int(SIZE * 0.018)
draw.ellipse(
    [cx - spindle_outer, cy - spindle_outer, cx + spindle_outer, cy + spindle_outer],
    fill=(0, 0, 0, 200),
    outline=(255, 255, 255, 40),
    width=2,
)
draw.ellipse(
    [cx - spindle_inner, cy - spindle_inner, cx + spindle_inner, cy + spindle_inner],
    fill=(0, 0, 0, 255),
)

# 6. Subtle outer vignette
vignette = Image.new("L", (SIZE, SIZE), 0)
vd = ImageDraw.Draw(vignette)
for r in range(int(SIZE * 0.55), int(SIZE * 0.7), 2):
    alpha = int(80 * (r - SIZE * 0.55) / (SIZE * 0.15))
    vd.ellipse([cx - r, cy - r, cx + r, cy + r], outline=alpha, width=2)
vignette = vignette.filter(ImageFilter.GaussianBlur(8))
dark = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
original_rgb = img.convert("RGB")
# Composite: where vignette is bright, blend toward black
blended = Image.composite(original_rgb, dark, vignette.point(lambda v: 255 - v))
img = blended.convert("RGBA")

img.convert("RGB").save(OUT, "PNG", optimize=True)
print(f"Wrote {OUT} ({os.path.getsize(OUT)} bytes, {img.size})")
