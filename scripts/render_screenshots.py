"""
Render the four Sonic Cloud HTML mockups to PNG screenshots.

We use Playwright + headless Chromium to load each HTML file, then capture a
device-scale screenshot in a mobile viewport (iPhone 14 Pro: 393×852 @ 3x).

The HTML files reference Google-hosted album-art images and the Tailwind CDN,
so we wait for network idle before each shot.

Output: screenshots/{my_library, now_playing, cloud_storage, settings}.png
"""
import os
import sys
from playwright.sync_api import sync_playwright

HTML_DIR = "/home/z/my-project/upload"
OUT_DIR = "/home/z/my-project/download/sonic_cloud_flutter/screenshots"

# (html filename, output filename)
SHOTS = [
    ("my_library.html", "my_library.png"),
    ("now_playing.html", "now_playing.png"),
    ("cloud_storage.html", "cloud_storage.png"),
    ("settings.html", "settings.png"),
]

# iPhone 14 Pro CSS pixels @ 3x DPR = 1179×2556 actual pixels.
VIEWPORT_W = 393
VIEWPORT_H = 852
DEVICE_SCALE = 3

def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": VIEWPORT_W, "height": VIEWPORT_H},
            device_scale_factor=DEVICE_SCALE,
        )
        page = context.new_page()

        for html_name, out_name in SHOTS:
            html_path = os.path.join(HTML_DIR, html_name)
            if not os.path.exists(html_path):
                print(f"SKIP: {html_path} not found", file=sys.stderr)
                continue
            url = "file://" + html_path
            print(f"Rendering {html_name} → {out_name}")
            page.goto(url, wait_until="networkidle", timeout=30000)
            # Extra wait so web fonts and Material Symbols settle.
            page.wait_for_timeout(1500)
            out_path = os.path.join(OUT_DIR, out_name)
            page.screenshot(path=out_path, full_page=False)
            size = os.path.getsize(out_path)
            print(f"  wrote {out_path} ({size:,} bytes)")

        browser.close()

if __name__ == "__main__":
    main()
