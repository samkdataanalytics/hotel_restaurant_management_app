# Website CMS verification tooling

Used to prove the landing page and other public pages render identically after
they are moved onto the CMS renderer.

```
# 1. build with motion frozen (Reveal / CountUp / WordCycler show their end state)
flutter build web --release --dart-define=FREEZE_MOTION=true \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# 2. serve build/web on :8777 with a SPA fallback, then capture 7 routes x 3 widths
python3 tool/cms/capture_pages.py build/cms_baselines/candidate

# 3. compare against the golden set (re-captures an image that differs, see below)
python3 tool/cms/verify_pages.py build/cms_baselines/golden build/cms_baselines/candidate
# for diff images of whatever still differs:
python3 tool/cms/compare_pages.py build/cms_baselines/golden build/cms_baselines/candidate
```

`verify_pages.py` captures everything, and re-captures any single image that
differs, up to twice. Headless Chrome occasionally rasterises one tile of a very
tall page differently (about one image in twenty, always in an untouched part of
the page, never twice in the same place); a real regression differs every time.

Headless Chrome clamps the viewport to 500px, so the narrowest width is 520.
Captures at the same width use the same canvas height, so a plain pixel diff is
meaningful. Pricing comes from the dev database, so re-baseline if plans change.
Requires Python with Pillow, and Google Chrome at the macOS default path.

## Re-baselines

A baseline changes only for a deliberate, explained reason.

- 2026-10-23, `home_520`: the header gained a menu button on phones (148 px, in
  the header only), because the nav links were unreachable below 768 px. Every
  other capture, at every width, was unchanged.
- 2026-10-23, `terms_*`, `privacy_*`, `returns_*` (all widths): the footer
  copyright read "© 2025" typed into the page; it is `© {year}` now and reads 2026
  (48 px, one digit). Nothing else on those pages changed.
- 2026-10-23, `help_*` (all widths): the search box's rotating placeholder. The
  old timer ran even in frozen builds, so the baseline caught whichever hint
  happened to be showing ("How do I add a menu item?"); frozen builds now show
  the first hint. The live page still rotates every 3 s. The rest of the page,
  and every topic's text, is identical (checked widget by widget: 104 of 104
  texts, 18 topics, 91 steps).
