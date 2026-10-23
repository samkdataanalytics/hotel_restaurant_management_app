# Website CMS

Edit the public HotRest site from **Superadmin → Website**. Covers the landing
page, help centre, terms / privacy / refund pages, sign-in and sign-up wording,
header, footer, theme, site settings, pop-ups and a media library.

## Turn it on (one step)

The editor needs four tables, a storage bucket and a few functions. They are in
`supabase/migrations/20261023000001_site_cms.sql`. Until it is applied:

- the public site is unaffected (it draws the bundled content), and
- the Website tab opens, shows a banner saying the tables are missing, and
  nothing saves.

Apply it to **hotrest_dev** by pasting the file into the Supabase SQL editor.
Then run `supabase/tests/site_cms.sql` in the same editor: it ends in an error
on purpose (so nothing commits) and the message is a PASS/FAIL report. Expect
every line to read PASS.

Production: apply the same file only when you decide to. Nothing in this branch
applies anything to production.

## Using it

| Area | What you can do |
|---|---|
| Pages | Reorder, hide/show, duplicate, delete and add sections; edit every word, icon, link and picture; per-section layout, background, type sizes per device (desktop/tablet/phone), fonts and colours; per-device visibility; search title and description. |
| Header & footer | Links (each can be switched off without deleting), sign-in link, main button, phone menu, footer columns, copyright. |
| Theme | Type sizes and fonts, content width and section gap for the whole site. Pages and sections override it. Brand colours are fixed by the design system. |
| Settings | Support email (used by the legal pages), WhatsApp chat button, the demo tour and contact-sales wording. |
| Media | Upload JPEG/PNG/WebP/GIF (max 5 MB, 4000 px), alt text, delete (warns where it is used). |

**Drafts and publishing.** Edits autosave to a private draft. Nothing is public
until **Publish**, which shows what changed, lists claims to double-check and asks
for a note. **History** lists every published version; **Restore** loads one into
the draft (never straight to live). **Discard draft** goes back to the live page.
Two people editing the same page get a conflict banner instead of overwriting each
other.

**Placeholders.** `{trialDays}` and `{annualDiscountPct}` always match what the
database grants and the checkout charges (tests compare them with the SQL and the
payhere-hash function). Typing the number literally gets a warning. `{year}`,
`{supportEmail}` and `{starterPrice}` are filled in too.

## What it will not let you do

- Links can only go to the site's own pages, an `https://` address, `mailto:`,
  `tel:`, a section on the page, or one of four built-in actions. No
  `javascript:`, no `data:`, no `http:`.
- Pictures must come from the media library.
- Fonts are limited to the three the site bundles.
- Publishing is blocked while there are errors (a required field empty, an invalid
  link, a bad colour, an unknown placeholder, a picture from outside the library).

## What is not covered

- **Brand colours** are constants used throughout the app; the theme editor changes
  type and spacing, and sections can set their own background and heading colour.
- **Search-result and social previews.** The site is drawn on a canvas. The tab
  title and description are set at run time, which helps crawlers that run
  JavaScript; link-preview scrapers (WhatsApp, Slack, Facebook) still see the static
  `index.html`. Fixing that needs an edge function.
- **Sinhala and Tamil** are not in the bundled fonts; the browser fetches a fallback
  font and the look is not controlled. The editor warns when you type them.
- **Pictures are served exactly as uploaded** (no resizing on the free plan). Keep
  them small.
- **Plan names, prices and limits** stay in **Plans**; the pricing section only
  controls its headings and labels.
- **System messages** (sign-in errors, form validation, the "could not send" toast)
  stay in code. `tool/cms/audit_coverage.py` fails CI if any other visitor-facing
  text is typed into code without a recorded reason.
- Click-to-select in the preview selects the **section**, not an individual word.
- No roles: only a superadmin can edit.

## Content to check before publishing

The shipped copy was reproduced exactly, including claims nobody has confirmed. The
publish dialog lists them; they are yours to confirm or change:

- "Trusted by 500+ properties", "50K+ bookings", "99.9% uptime SLA", "4.9 rating"
- The three testimonials (named people and businesses)
- "SOC 2 compliant", "GDPR ready", "24/7 support"
- "Save 4+ hours a day", "under 30 seconds", "LKR 20,000+/mo" for traditional software
- "Direct messaging with front desk" (no such screen was found)
- "Dedicated account manager", "SLA & uptime guarantee"
- The product window's address `app.hotrest.app` (not a real host)
- FAQ plan limits ("Pro: up to three properties") that no longer match the live plans
- Legal pages: a Free plan that no longer exists, a 14-day refund window beside a
  45-day trial, Google Fonts named although fonts are bundled, and a personal
  contact address (`kasun@ideadeck.biz`, now editable in Settings)

## For developers

- Documents: `lib/web/cms/` (model, sections, renderer, repository, defaults).
  Editor: `lib/web/studio/`. A new section type needs: a widget + `SectionDefinition`
  in `registry/public_registry.dart`, a `SectionSpec` in `studio/specs/`, and (if it
  ships with content) a default in `defaults/`. Tests fail if any of the three is
  missing.
- Visual regression: `tool/cms/README.md`. Re-baselines are recorded there with
  the reason.
- `supabase/tests/site_cms.sql` also runs locally and in CI:
  `tool/cms/run_sql_tests.sh` (throwaway Postgres, never a real project).
