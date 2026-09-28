#!/usr/bin/env python3
"""Design-token toolchain. The Swift token files are canonical (ADR-001); this script derives
everything else from them so the mirrors cannot drift. The app is light-only (ADR-006), so
every color is one fixed OKLCH value.

  ds_tokens.py contrast   WCAG table for every (foreground, background) pair in PAIRS.
                          Exit 1 on any FAIL or out-of-gamut OKLCH.
  ds_tokens.py emit-css   :root custom properties for design-system.html.
  ds_tokens.py lint       Every Swift token has a CSS var USED in the HTML (declared plus at least
                          one reference, counted by exact name outside comments) and a mention in
                          UI_DESIGN.md; the generated :root block matches emit-css; the brand name
                          appears in Brand.swift only. Tokens the guide cannot consume are listed
                          in DECLARATION_ONLY with a reason and printed as an EXCEPTION on every
                          run. Exits 1 on any problem; the empty icon-credits array prints a
                          WARNING, not a failure.

Standard library only. Paths resolve relative to this file, so the leading space in the parent
folder name is harmless.
"""
from __future__ import annotations

import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DS_DIR = ROOT / "Sift" / "DesignSystem"
COLOR_FILE = DS_DIR / "DSColor.swift"
LAYOUT_FILE = DS_DIR / "DSLayout.swift"
MOTION_FILE = DS_DIR / "DSMotion.swift"
HTML_FILE = ROOT / "design-system.html"
UI_DOC = ROOT / "docs" / "knowledge" / "UI_DESIGN.md"
BRAND_FILE = DS_DIR / "Brand.swift"

# ----------------------------------------------------------------------------- color math

def oklch_to_linear(L: float, C: float, H: float) -> tuple[float, float, float]:
    """Björn Ottosson's OKLab → linear sRGB (same matrices as DSColor.swift)."""
    h = math.radians(H)
    a, b = C * math.cos(h), C * math.sin(h)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return r, g, bl


def gamma_encode(x: float) -> float:
    v = min(max(x, 0.0), 1.0)
    return 1.055 * v ** (1 / 2.4) - 0.055 if v >= 0.0031308 else 12.92 * v


def gamma_decode(v: float) -> float:
    return ((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92


GAMUT_TOLERANCE = 0.002
RGB = tuple[float, float, float]


def oklch_to_srgb(L: float, C: float, H: float) -> tuple[RGB, bool]:
    lin = oklch_to_linear(L, C, H)
    in_gamut = all(-GAMUT_TOLERANCE <= c <= 1 + GAMUT_TOLERANCE for c in lin)
    return tuple(gamma_encode(c) for c in lin), in_gamut


def luminance(rgb: RGB) -> float:
    r, g, b = (gamma_decode(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(fg: RGB, bg: RGB) -> float:
    la, lb = luminance(fg), luminance(bg)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def composite(fg: RGB, alpha: float, bg: RGB) -> RGB:
    """Source-over in gamma-encoded sRGB — what CSS and UIKit actually do on screen."""
    return tuple(alpha * f + (1 - alpha) * b for f, b in zip(fg, bg))


def hexstr(rgb: RGB) -> str:
    return "#" + "".join(f"{round(c * 255):02x}" for c in rgb)


# ----------------------------------------------------------------------------- token model

@dataclass
class ColorToken:
    name: str
    L: float
    C: float
    H: float
    alpha: float = 1.0
    derived_from: str | None = None

    def srgb(self) -> tuple[RGB, bool]:
        return oklch_to_srgb(self.L, self.C, self.H)

    def oklch_str(self) -> str:
        s = f"oklch({self.L:g} {self.C:g} {self.H:g}"
        return s + (f" / {self.alpha:g})" if self.alpha < 1 else ")")

    def css_value(self) -> str:
        rgb, _ = self.srgb()
        if self.alpha < 1:
            r, g, b = (round(c * 255) for c in rgb)
            return f"rgb({r} {g} {b} / {self.alpha:.2f})"
        return hexstr(rgb)


WHITE = ColorToken("white", 1, 0, 0)
BLACK = ColorToken("black", 0, 0, 0)

_OKLCH = re.compile(r"oklch\(([^)]*)\)")
_DERIVED = re.compile(r"\b(\w+)\.opacity\(([\d.]+)\)")
_LET = re.compile(r"static let (\w+)\s*(?::\s*[\w.]+)?\s*=\s*")
_CUT = re.compile(r"static let |static func |private static func |^\s*}\s*$", re.M)


def _nums(s: str) -> list[float]:
    return [float(x) for x in re.findall(r"-?[\d.]+", s)]


def _parse_expr(expr: str, name: str) -> ColorToken | None:
    m = _OKLCH.search(expr)
    if m:
        v = _nums(m.group(1))
        return ColorToken(name, v[0], v[1], v[2], v[3] if len(v) > 3 else 1.0)
    m = _DERIVED.search(expr)
    if m:
        return ColorToken(name, 0, 0, 0, float(m.group(2)), derived_from=m.group(1))
    return None


def strip_comments(src: str) -> str:
    return re.sub(r"//[^\n]*", "", src)


def parse_colors() -> dict[str, ColorToken]:
    src = strip_comments(COLOR_FILE.read_text())
    tokens: dict[str, ColorToken] = {}
    for m in _LET.finditer(src):
        name = m.group(1)
        start = m.end()
        nxt = _CUT.search(src, start)
        body = src[start: nxt.start() if nxt else len(src)]
        if "VerdictColorSet" in body:
            parts = re.split(r"\b(main|on|soft):", body)
            for key, expr in zip(parts[1::2], parts[2::2]):
                tok = _parse_expr(expr, f"{name}.{key}")
                if tok is None:
                    sys.exit(f"parse error: {name}.{key}")
                tokens[tok.name] = tok
        else:
            tok = _parse_expr(body, name)
            if tok is not None:
                tokens[tok.name] = tok
    for tok in tokens.values():
        if tok.derived_from:
            base = tokens[tok.derived_from]
            tok.L, tok.C, tok.H = base.L, base.C, base.H
    # Completeness: every `static let` in the file must have produced a token (3 for a verdict set).
    expected = 0
    missing = []
    for m in _LET.finditer(src):
        nxt = _CUT.search(src, m.end())
        body = src[m.end(): nxt.start() if nxt else len(src)]
        n = 3 if "VerdictColorSet" in body else 1
        expected += n
        names = [f"{m.group(1)}.{k}" for k in ("main", "on", "soft")] if n == 3 else [m.group(1)]
        missing += [x for x in names if x not in tokens]
    if missing or expected != len(tokens):
        sys.exit(f"ds_tokens: {len(missing)} color declaration(s) did not parse — {missing}. "
                 "Keep the literal shapes documented at the top of DSColor.swift.")
    return tokens


_STATIC_NUM = re.compile(r"static let (\w+)\s*:\s*(CGFloat|Double|Int)\s*=\s*(-?[\d.]+)")
_ENUM = re.compile(r"^enum (\w+)", re.M)


def parse_numbers(path: Path) -> dict[str, dict[str, float]]:
    """{EnumName: {token: value}} for `static let name: CGFloat = 16` lines."""
    out: dict[str, dict[str, float]] = {}
    current = None
    for line in strip_comments(path.read_text()).splitlines():
        em = _ENUM.match(line.strip())
        if em:
            current = em.group(1)
            out.setdefault(current, {})
            continue
        sm = _STATIC_NUM.search(line)
        if sm and current:
            out[current][sm.group(1)] = float(sm.group(3))
        elif current and re.search(r"static let \w+\s*:\s*(CGFloat|Double|Int)\b", line):
            sys.exit(f"ds_tokens: numeric token did not parse in {path.name}: {line.strip()}")
    return out


# ----------------------------------------------------------------------------- contrast pairs
# (foreground, background, minimum, use, background-under)   background-under is what a
# translucent background is composited over. text 4.5 · bold/large/non-text 3 · informational 1
# (the pair is printed but exempt — the reason is in the use column and in UI_DESIGN.md).

SURFACES = ["canvas", "surface", "surfaceRaised"]
PAIRS: list[tuple[str, str, float, str, str | None]] = []
for ink in ["ink", "ink2", "inkMuted"]:
    for surf in SURFACES:
        PAIRS.append((ink, surf, 4.5, "text", None))
PAIRS += [
    ("onToast", "toast", 4.5, "text", None),
    ("onAccent", "accent", 4.5, "text · primary button label", None),
    ("onImage", "viewerBackdrop", 4.5, "text · viewer bars", None),
    ("ink", "chip", 4.5, "text · chip over a white screenshot", "white"),
    ("ink", "chip", 4.5, "text · chip over a black screenshot", "black"),
    ("ink", "surfaceRaised", 3.0, "non-text · secondary button glyph", None),
    ("focus", "canvas", 3.0, "non-text · focus ring on canvas", "canvas"),
    ("focus", "surfaceRaised", 3.0, "non-text · focus ring on a raised control", "surfaceRaised"),
    ("accent", "canvas", 3.0, "non-text · primary button edge on canvas", None),
    # The CTA pill on a color block is filled with that block's ink, so the pill-vs-block pair is
    # the same one the block's copy already clears below. These two rows cover the LABEL on it.
    ("onAccent", "ink", 4.5, "text · CTA pill label on a block, the pill being the block's ink", None),
    ("accent", "onAccent", 4.5, "text · CTA pill label on the denied block, the pill being white", None),
    ("ink2", "canvas", 3.0, "non-text · chrome icons", None),
]
for v in ["trash", "archive", "fave"]:
    PAIRS += [
        (f"{v}.on", f"{v}.main", 3.0, "large text · stamp word (32 pt) and button glyph on main", None),
        ("ink", f"{v}.soft", 4.5, "text · chip on soft", None),
    ]
PAIRS += [
    ("trash.main", "canvas", 3.0, "non-text · button / badge edge on canvas", None),
    ("trash.main", "white", 3.0, "non-text · stamp pill on a white screenshot", None),
    ("archive.main", "canvas", 3.0, "non-text · button / badge edge on canvas", None),
    ("archive.main", "white", 3.0, "non-text · stamp pill on a white screenshot", None),
    ("fave.main", "canvas", 1.0, "informational · yellow edge is exempt, the navy word carries meaning (ADR-004)", None),
    ("fave.main", "white", 1.0, "informational · same exemption on a white screenshot", None),
    ("ink", "trash.main", 4.5, "text · destructive button label (16 pt bold) and onboarding copy on tomato", None),
    ("archive.on", "archive.main", 4.5, "text · white label on a cobalt fill", None),
    ("ink", "fave.main", 4.5, "text · copy on a yellow block", None),
    ("ink", "mint", 4.5, "text · copy on the mint block", None),
    ("ink", "lime", 4.5, "text · copy on the lime block", None),
    ("ink", "pink", 4.5, "text · copy on the pink block", None),
    ("ink", "lavender", 4.5, "text · copy on the lavender block", None),
    ("onAccent", "violet", 4.5, "text · white copy on the violet block", None),
    ("onAccent", "trash.main", 3.0, "large text · white stamp word on tomato — never a button label", None),
    ("surfaceRaised", "canvas", 1.0, "informational · raised fill vs canvas (tint separation, no border)", None),
]


def resolve(tokens: dict[str, ColorToken], name: str) -> ColorToken:
    if name == "white":
        return WHITE
    if name == "black":
        return BLACK
    if name not in tokens:
        sys.exit(f"unknown token in PAIRS: {name}")
    return tokens[name]


def rgb_of(tok: ColorToken, under: RGB | None = None) -> RGB:
    rgb, _ = tok.srgb()
    if tok.alpha < 1:
        rgb = composite(rgb, tok.alpha, under if under is not None else (0.0, 0.0, 0.0))
    return rgb


def cmd_contrast() -> int:
    tokens = parse_colors()
    failures = 0
    print("## Color tokens (OKLCH → sRGB)\n")
    print("| Token | OKLCH | Hex | Note |")
    print("|---|---|---|---|")
    for tok in tokens.values():
        rgb, ok = tok.srgb()
        note = "derived from `%s`" % tok.derived_from if tok.derived_from else ""
        if not ok:
            note = (note + " · " if note else "") + "⚠ OUT OF sRGB GAMUT"
            failures += 1
        print(f"| `{tok.name}` | {tok.oklch_str()} | {hexstr(rgb)}{f' @{tok.alpha:g}' if tok.alpha < 1 else ''} | {note} |")

    print("\n## Contrast (WCAG 2.x) — text ≥ 4.5 · bold/large/non-text ≥ 3 · informational rows are exempt\n")
    print("| # | Foreground | Background | Use | Min | Ratio | Result |")
    print("|---|---|---|---|---|---|---|")
    for i, (fg_n, bg_n, minimum, use, under_n) in enumerate(PAIRS, 1):
        fg, bg = resolve(tokens, fg_n), resolve(tokens, bg_n)
        under = rgb_of(resolve(tokens, under_n)) if under_n else None
        bg_rgb = rgb_of(bg, under)
        fg_rgb = rgb_of(fg, bg_rgb)
        ratio = contrast(fg_rgb, bg_rgb)
        info = minimum <= 1.0
        passed = info or ratio >= minimum
        if not passed:
            failures += 1
        bg_label = bg_n + (f" over {under_n}" if under_n else "")
        result = "info" if info else ("PASS" if passed else "**FAIL**")
        print(f"| {i} | `{fg_n}` | `{bg_label}` | {use} | {'—' if info else f'{minimum:g}'} | {ratio:.2f} | {result} |")
    print(f"\n{len(PAIRS)} pairs · {failures} failure(s)")
    return 1 if failures else 0


# ----------------------------------------------------------------------------- css

# Tokens the guide declares but cannot consume, each with the reason. Anything unused and NOT
# listed here fails the lint; these three are reported as exceptions on every run.
DECLARATION_ONLY = {
    "--grid-breakpoint": "CSS media queries cannot take var(); the guide's twelve max-width queries spell 1199.98px literally",
    "--motion-dur3": "surface transitions (sheet, card expand) — the guide has no animated sheet",
    "--motion-toast-visible": "the toast demo is a static swatch, so nothing counts down 2.5 s",
    "--motion-confetti": "the all-done celebration is not drawn in the guide; the deck demo shows the copy, not the burst",
    "--motion-stagger": "the guide has no emptying grid; the thumbnail swatches are static",
    "--size-viewer-zoom-double-tap": "the guide has no working viewer; its viewer mini is a static swatch",
    "--size-viewer-zoom-max": "same: nothing in the guide pinches",
    "--motion-demo-card": "the guide's deck demo is driven by the visitor, not by a loop",
    "--motion-demo-pause": "same: no auto-loop in the guide",
}

UNITLESS = {"stackScaleStep", "downFollow", "upScale", "promoteAt", "stampFaveRaise", "stampPopScale", "disabled",
            "viewerZoomDoubleTap", "viewerZoomMax",
            "gridColumns", "stackDepth", "desktopColumns", "mobileColumns"}
ENUM_PREFIX = {"DSSpace": "space", "DSRadius": "radius", "DSSize": "size", "DSSwipe": "swipe",
               "DSGrid": "grid", "DSOpacity": "opacity"}


def kebab(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "-", name).lower()


def css_name(token: str) -> str:
    """trash.main → --color-trash · trash.on → --color-trash-on · surfaceRaised → --color-surface-raised"""
    return "--color-" + kebab(token.replace(".main", "").replace(".", "-"))


def color_vars(tokens: dict[str, ColorToken]) -> list[str]:
    return [f"  {css_name(t.name)}: {t.css_value()};" for t in tokens.values()]


def number_var(enum: str, name: str, path: Path) -> str:
    prefix = "motion" if path == MOTION_FILE else ENUM_PREFIX.get(enum, enum.lower())
    return f"--{prefix}-{kebab(name)}"


def number_vars() -> list[str]:
    lines = []
    for path in (LAYOUT_FILE, MOTION_FILE):
        for enum, values in parse_numbers(path).items():
            for name, v in values.items():
                if path == MOTION_FILE:
                    unit = "" if name in UNITLESS else "s"  # a scale factor in the motion file carries no unit
                    lines.append(f"  {number_var(enum, name, path)}: {v:g}{unit};")
                else:
                    unitless = name in UNITLESS or name.endswith("Degrees") or name in ("commitVelocity", "rotationDivisor")
                    unit = "" if unitless else "px"
                    lines.append(f"  {number_var(enum, name, path)}: {v:g}{unit};")
    return lines


CSS_HEADER = "/* GENERATED by scripts/ds_tokens.py emit-css — edit the Swift tokens, not this block. */"


def css_block(tokens: dict[str, ColorToken]) -> str:
    out = [CSS_HEADER, ":root {", "  color-scheme: light;"]
    out += color_vars(tokens) + number_vars() + ["}"]
    return "\n".join(out)


def cmd_emit_css() -> int:
    print(css_block(parse_colors()))
    return 0


# ----------------------------------------------------------------------------- lint

def cmd_lint() -> int:
    problems: list[str] = []
    tokens = parse_colors()
    html_raw = HTML_FILE.read_text() if HTML_FILE.exists() else ""
    html = re.sub(r"<!--.*?-->", "", html_raw, flags=re.S)  # mentions inside comments do not count

    def uses(var: str) -> int:
        return len(re.findall(re.escape(var) + r"(?![A-Za-z0-9-])", html))
    doc = UI_DOC.read_text() if UI_DOC.exists() else ""
    if not html:
        problems.append(f"missing {HTML_FILE.name}")
    if not doc:
        problems.append(f"missing {UI_DOC.relative_to(ROOT)}")

    # 1. every color token → CSS var used in the HTML and a backticked mention in UI_DESIGN.md
    for tok in tokens.values():
        var = css_name(tok.name)
        if html and uses(var) < 2:  # declared once + used at least once, exact name, outside comments
            problems.append(f"{var} declared but never used in design-system.html")
        if doc and f"`{tok.name}`" not in doc:
            problems.append(f"`{tok.name}` not documented in UI_DESIGN.md")

    # 2. numeric tokens → CSS var + doc mention as `Enum.name` or `name`
    for path in (LAYOUT_FILE, MOTION_FILE):
        for enum, values in parse_numbers(path).items():
            for name in values:
                var = number_var(enum, name, path)
                if html and uses(var) < 2 and var not in DECLARATION_ONLY:
                    problems.append(f"{var} declared but never used or mentioned in design-system.html")
                if doc and f"`{enum}.{name}`" not in doc and f"`{name}`" not in doc:
                    problems.append(f"`{enum}.{name}` not documented in UI_DESIGN.md")

    # 3. the brand name lives in Brand.swift only
    brand = re.search(r'static let name = "([^"]+)"', BRAND_FILE.read_text())
    if brand:
        for swift in DS_DIR.glob("*.swift"):
            if swift.name != BRAND_FILE.name and re.search(rf"\b{re.escape(brand.group(1))}\b", swift.read_text()):
                problems.append(f"brand name '{brand.group(1)}' leaked into {swift.name}")

    # 4. the generated CSS block in the HTML is current
    if html and css_block(tokens) not in html:
        problems.append("design-system.html's generated :root block is stale — re-run emit-css and paste it")

    # 5. declaration-only tokens are printed every run, never silently tolerated
    for var, why in DECLARATION_ONLY.items():
        if html and uses(var) < 2:
            print(f"lint: EXCEPTION — {var} is declared but unused ({why})")

    # 6. shipping readiness (warning only): Noun Project credits must exist before release
    icon_src = (DS_DIR / "DSIcon.swift").read_text()
    if "static let entries: [DSIconCredit] = []" in icon_src:
        print("lint: WARNING — DSIconCredits.entries is empty; the 12 icons are still placeholders (ADR-017)")

    if problems:
        print("\n".join(f"LINT: {p}" for p in problems))
        print(f"{len(problems)} problem(s)")
        return 1
    print("lint: OK")
    return 0


COMMANDS = {"contrast": cmd_contrast, "emit-css": cmd_emit_css, "lint": cmd_lint}

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in COMMANDS:
        sys.exit(__doc__)
    sys.exit(COMMANDS[sys.argv[1]]())
