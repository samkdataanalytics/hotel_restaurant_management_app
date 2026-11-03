"""Capture the public pages and require them to match the golden set.

usage: verify_pages.py <golden_dir> <candidate_dir>

Headless Chrome occasionally rasterises one tile of a very tall page slightly
differently (seen about once in twenty images, always in a part of the page the
change did not touch, and never in the same place twice). A genuine regression
reproduces every time, so an image that differs is captured again, up to twice,
and only counts as failed if every attempt differs.
"""
import pathlib, subprocess, sys
from PIL import Image, ImageChops

HERE = pathlib.Path(__file__).parent
golden, cand = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])


def same(name):
    a, b = golden / name, cand / name
    if not b.exists():
        return False
    x, y = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    return x.size == y.size and ImageChops.difference(x, y).getbbox() is None


def capture(*only):
    subprocess.run([sys.executable, str(HERE / "capture_pages.py"), str(cand), *only],
                   check=True, stdout=subprocess.DEVNULL)


capture()
failed = []
for f in sorted(golden.glob("*.png")):
    tries = 1
    while not same(f.name) and tries < 3:
        tries += 1
        capture(f.stem)
    if same(f.name):
        print(f"{f.name:20s} identical" + (f"  (after {tries} captures)" if tries > 1 else ""))
    else:
        failed.append(f.name)
        print(f"{f.name:20s} DIFFERS on all {tries} captures")

print(f"\n{'FAIL' if failed else 'PASS'}: {len(failed)} page(s) differ")
if failed:
    print("run compare_pages.py for the diff images")
sys.exit(1 if failed else 0)
