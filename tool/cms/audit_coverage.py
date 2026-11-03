"""Find visitor-facing text on the public pages that is typed into code.

usage: audit_coverage.py [--strict]

The CMS goal is that what a visitor reads on the public site comes from a
document, not from a Dart literal. This scans the files that draw those pages for
string literals handed to text-bearing widgets and arguments, and compares them to
`audit_allow.txt`, which lists the ones that are deliberately code, each with the
reason. Anything else is reported. With --strict, any unlisted literal fails the
run (used in CI so a new hardcoded sentence does not slip in).

It is a heuristic over source text, not a parser: it can miss text built by
concatenation and over-report identifiers. The allow-list is the record of the
judgement calls, and is meant to be read.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
FILES = [
    "lib/web/landing_screen.dart",
    "lib/web/landing/landing_dialogs.dart",
    "lib/web/help_screen.dart",
    "lib/web/legal_screen.dart",
    "lib/web/login_screen.dart",
    "lib/web/signup_screen.dart",
    "lib/web/auth/auth_scaffold.dart",
] + sorted(str(p.relative_to(ROOT)) for p in (ROOT / "lib/web/cms").rglob("*.dart")
           if "defaults" not in p.parts and "model" not in p.parts and "data" not in p.parts
           and "platform" not in p.parts and "registry" not in p.parts)

STR = r"'((?:[^'\\\n]|\\.)*)'"
PATTERNS = [
    re.compile(r"\bText\(\s*" + STR),
    re.compile(r"\b(?:label|hintText|labelText|title|subtitle|tooltip|message|text)\s*:\s*" + STR),
    re.compile(r"\bconst\s+Eyebrow\(\s*" + STR),
]
# Strings that are plainly not prose.
SKIP = re.compile(r"^(?:[a-z_]+|[A-Z0-9_]+|[./#:?=&%0-9 \-_]*|assets/.*|packages/.*|\$\{?\w+\}?|'')$")

allow = {}
ap = pathlib.Path(__file__).with_name("audit_allow.txt")
if ap.exists():
    for line in ap.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        text, _, reason = line.partition(" :: ")
        allow[text.strip()] = reason.strip()

found = {}
for rel in FILES:
    src = (ROOT / rel).read_text()
    for pat in PATTERNS:
        for m in pat.finditer(src):
            t = m.group(1).replace("\\'", "'")
            if len(t) < 2 or SKIP.match(t) or "$" in t and not re.search(r"[A-Za-z]{3}", re.sub(r"\$\{?\w+\}?", "", t)):
                continue
            found.setdefault(rel, set()).add(t)

unlisted = {f: sorted(t for t in ts if t not in allow) for f, ts in found.items()}
unlisted = {f: ts for f, ts in unlisted.items() if ts}
listed = sum(1 for ts in found.values() for t in ts if t in allow)

print(f"scanned {len(FILES)} files; {sum(len(v) for v in found.values())} text literals; "
      f"{listed} allow-listed with a reason")
for f, ts in unlisted.items():
    print(f"\n{f}")
    for t in ts:
        print(f"    {t!r}")
n = sum(len(v) for v in unlisted.values())
print(f"\n{n} literal(s) not allow-listed")
sys.exit(1 if (n and "--strict" in sys.argv) else 0)
