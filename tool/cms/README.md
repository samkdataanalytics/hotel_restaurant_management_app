# Website CMS verification tooling

Used to prove the landing page and other public pages render identically after
they are moved onto the CMS renderer.

```
# 1. build with motion frozen (Reveal / CountUp / WordCycler show their end state)
flutter build web --release --dart-define=FREEZE_MOTION=true \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# 2. serve build/web on :8777 with a SPA fallback, then capture 7 routes x 3 widths
python3 tool/cms/capture_pages.py build/cms_baselines/candidate

# 3. compare against the golden set
python3 tool/cms/compare_pages.py build/cms_baselines/golden build/cms_baselines/candidate
```

Headless Chrome clamps the viewport to 500px, so the narrowest width is 520.
Captures at the same width use the same canvas height, so a plain pixel diff is
meaningful. Pricing comes from the dev database, so re-baseline if plans change.
Requires Python with Pillow, and Google Chrome at the macOS default path.
