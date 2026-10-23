"""Capture the public pages at three widths for pixel comparison.

usage: capture_pages.py <outdir> [name_width ...]

With no further arguments every page is captured; otherwise only the named
ones (e.g. `home_820 login_820`), which is how verify_pages.py re-captures a
single image.

Windows are tall enough to hold the whole page, and every shot at a given width
uses the same height, so two captures of the same build are comparable
byte-for-byte. Headless Chrome clamps the viewport to a 500px minimum, so the
narrowest width is 520, not a real 390 phone.
"""
import subprocess, sys, os, pathlib

OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
ONLY = set(sys.argv[2:])
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BASE = "http://localhost:8777"
ROUTES = {"home": "/", "help": "/help", "terms": "/terms", "privacy": "/privacy",
          "returns": "/returns", "login": "/login", "signup": "/signup"}
SIZES = {520: 14000, 820: 10000, 1280: 7600}

for name, path in ROUTES.items():
    for w, h in SIZES.items():
        if ONLY and f"{name}_{w}" not in ONLY:
            continue
        dest = OUT / f"{name}_{w}.png"
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
                        "--force-device-scale-factor=1", "--hide-scrollbars",
                        "--virtual-time-budget=25000", f"--window-size={w},{h}",
                        f"--screenshot={dest}", BASE + path],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=180)
        print(f"{dest.name:22s} {dest.stat().st_size//1024:6d} KB" if dest.exists() else f"{dest.name}: MISSING")
