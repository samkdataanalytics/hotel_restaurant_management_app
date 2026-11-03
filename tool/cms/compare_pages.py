"""Compare two capture directories page by page.

usage: compare_pages.py <baseline_dir> <candidate_dir> [--tolerance PIXELS]

Exits non-zero if any page differs by more than the tolerance (default 0, i.e.
pixel-identical). Writes a highlighted diff image next to the candidate for each
page that differs, so a failure shows *where*, not just *that*.

This is the Phase 1 exit criterion for the website CMS: converting the landing
page to render from a document must not change a single pixel at 520, 820 and
1280 px wide.
"""
import sys, pathlib
from PIL import Image, ImageChops

args = [a for a in sys.argv[1:] if not a.startswith("--")]
tol = int(sys.argv[sys.argv.index("--tolerance") + 1]) if "--tolerance" in sys.argv else 0
if "--tolerance" in sys.argv:
    args = [a for a in args if a != str(tol)]
base, cand = pathlib.Path(args[0]), pathlib.Path(args[1])

failed = 0
for f in sorted(base.glob("*.png")):
    g = cand / f.name
    if not g.exists():
        print(f"{f.name:20s} MISSING in candidate"); failed += 1; continue
    a, b = Image.open(f).convert("RGB"), Image.open(g).convert("RGB")
    if a.size != b.size:
        print(f"{f.name:20s} SIZE {a.size} -> {b.size}"); failed += 1; continue
    diff = ImageChops.difference(a, b)
    box = diff.getbbox()
    if not box:
        print(f"{f.name:20s} identical"); continue
    n = sum(1 for p in diff.convert("L").getdata() if p)
    status = "within tolerance" if n <= tol else "DIFFERS"
    print(f"{f.name:20s} {status}: {n} px differ, in {box}")
    if n > tol:
        failed += 1
        mask = diff.convert("L").point(lambda v: 255 if v else 0)
        out = a.copy(); out.paste((255, 0, 80), mask=mask)
        out.save(cand / f"DIFF_{f.name}")

print(f"\n{'PASS' if not failed else 'FAIL'}: {failed} page(s) differ")
sys.exit(1 if failed else 0)
