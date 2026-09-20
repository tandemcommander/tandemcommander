#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Classifies every resource reference the mdview generator emits against the
content security policy the shared WebView2 host now serves with the document.

Why this exists
---------------
Feature 081 moved the Markdown Viewer onto src/common/webhost/, which adds a
CSP header the plugin's own host never sent:

    default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:;
    object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'

That is a hardening for a hostile document, but it must not cost a legitimate
one a single element. Reading the generator (research R4) says it emits only
inline styles, own-origin img/<n> images and pass-through data: URIs -- this
script proves it over the whole fixture corpus instead of trusting the reading.

It renders each fixture with the committed dumper
(tests/mdview_htmlgen_test/build_and_run.cmd dump) and walks the HTML with the
standard library's parser.

Verdicts
--------
    ALLOWED  the policy permits it (own-origin image, data: image, inline style)
    BLOCKED  the policy refuses it (remote anything, iframe/object/embed,
             media, external script or stylesheet, <base>, form action, a
             url() inside a style, a web font)

Which layer refuses which fixture
---------------------------------
The corpus is not uniform, and pretending it is would make this check lie.
Three of the hostile fixtures are refused by a layer that leaves no resource
reference in the HTML at all, so a "blocked reference" count of zero is the
CORRECT result for them:

  * "csp"        the content policy is the layer under test -> expect >= 1 blocked
  * "navigation" a link the NAVIGATION GATE or the download handler refuses at
                 runtime (javascript: links, <a download>): they are anchors,
                 not resource loads, so the policy never sees them -> expect 0
  * "generator"  the GENERATOR already refused it and emitted a placeholder
                 (image paths outside the document's folder) -> expect 0, and
                 the one legitimate image must survive
  * "control"    must render completely -> expect 0 blocked
  * "target"     a link target, not a test of its own

Exit code 0 when every fixture matched its expectation.

Stdlib only; Python 3.13 as the project's tools use.
"""
from __future__ import annotations

import argparse
import html.parser
import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
FEATURE = HERE.parent
ROOT = FEATURE.parent.parent
FIXTURES = FEATURE / "fixtures" / "security"
DUMPER = ROOT / "tests" / "mdview_htmlgen_test" / "build_and_run.cmd"

OWN_ORIGIN = "https://mdview.invalid/"

# Which layer refuses each fixture (see the module docstring). An unlisted
# fixture is treated as "csp", so adding a hostile file without a decision
# fails loudly rather than silently passing.
LAYER = {
    "01-script-tag.md": "csp",
    "02-event-handlers.md": "csp",
    "03-javascript-link.md": "navigation",
    "04-remote-image.md": "csp",
    "05-iframe.md": "csp",
    "06-meta-refresh.md": "csp",
    "07-form.md": "csp",
    "08-path-traversal-image.md": "generator",
    "09-download-link.md": "navigation",
    "10-legit-control.md": "control",
    "10b-linked.md": "target",
}


class Ref:
    def __init__(self, kind: str, value: str, allowed: bool, why: str):
        self.kind = kind
        self.value = value
        self.allowed = allowed
        self.why = why

    def short(self) -> str:
        v = self.value if len(self.value) <= 58 else self.value[:55] + "..."
        return f"{self.kind:<12} {v}"


def classify_url(kind: str, url: str) -> Ref:
    """One resource reference against the policy above."""
    u = (url or "").strip()
    low = u.lower()

    if kind == "img":
        if low.startswith("data:"):
            return Ref(kind, u, True, "img-src data:")
        if u.startswith(OWN_ORIGIN):
            return Ref(kind, u, True, "img-src 'self'")
        return Ref(kind, u, False, "img-src allows only 'self' and data:")

    if kind in ("iframe", "object", "embed"):
        return Ref(kind, u, False, "default-src 'none' / object-src 'none'")
    if kind in ("video", "audio", "source"):
        return Ref(kind, u, False, "media-src falls back to default-src 'none'")
    if kind == "script":
        return Ref(kind, u, False, "no script-src: default-src 'none'")
    if kind == "stylesheet":
        return Ref(kind, u, False, "style-src allows only 'self' and inline")
    if kind == "prefetch":
        return Ref(kind, u, False, "default-src 'none'")
    if kind == "base":
        return Ref(kind, u, False, "base-uri 'none'")
    if kind == "form":
        return Ref(kind, u, False, "form-action 'none'")
    if kind == "css-url":
        if low.startswith("data:"):
            # A data: URL inside a style is fetched as whatever it is used for;
            # img-src permits data:, and nothing else in the document uses one.
            return Ref(kind, u, True, "data: in a style (img-src data:)")
        return Ref(kind, u, False, "default-src 'none' covers url() in a style")
    if kind == "font":
        return Ref(kind, u, False, "font-src falls back to default-src 'none'")

    return Ref(kind, u, False, "unclassified -> treated as blocked")


class Collector(html.parser.HTMLParser):
    """Collects every reference the policy has an opinion about."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.refs: list[Ref] = []
        self.inline_styles = 0
        self.in_style = False
        self._style_buf: list[str] = []

    def add(self, kind: str, url: str | None) -> None:
        if url:
            self.refs.append(classify_url(kind, url))

    def _scan_css(self, css: str) -> None:
        for m in re.finditer(r"url\(\s*['\"]?([^'\")]+)", css, re.I):
            self.add("css-url", m.group(1))
        for m in re.finditer(r"@font-face[^}]*?src\s*:\s*[^;}]*?url\(\s*['\"]?([^'\")]+)",
                             css, re.I | re.S):
            self.add("font", m.group(1))

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        a = {k.lower(): (v or "") for k, v in attrs}

        if "style" in a:
            self.inline_styles += 1
            self._scan_css(a["style"])

        if tag == "style":
            self.in_style = True
            self._style_buf = []
        elif tag == "img":
            self.add("img", a.get("src"))
            for part in a.get("srcset", "").split(","):
                url = part.strip().split(" ")[0]
                self.add("img", url)
        elif tag == "source":
            for part in a.get("srcset", "").split(","):
                url = part.strip().split(" ")[0]
                self.add("img" if a.get("type", "").startswith("image") else "source", url)
            self.add("source", a.get("src"))
        elif tag == "script":
            if a.get("src"):
                self.add("script", a["src"])
        elif tag == "iframe":
            self.add("iframe", a.get("src"))
        elif tag == "object":
            self.add("object", a.get("data"))
        elif tag == "embed":
            self.add("embed", a.get("src"))
        elif tag in ("video", "audio"):
            self.add(tag, a.get("src"))
        elif tag == "base":
            self.add("base", a.get("href") or "(empty)")
        elif tag == "form":
            self.add("form", a.get("action") or "(self)")
        elif tag == "link":
            rel = a.get("rel", "").lower()
            if "stylesheet" in rel:
                self.add("stylesheet", a.get("href"))
            elif "prefetch" in rel or "preload" in rel or "dns-prefetch" in rel:
                self.add("prefetch", a.get("href"))

    def handle_endtag(self, tag: str) -> None:
        if tag == "style":
            self.in_style = False
            self._scan_css("".join(self._style_buf))

    def handle_data(self, data: str) -> None:
        if self.in_style:
            self._style_buf.append(data)


def render(md: pathlib.Path, out: pathlib.Path) -> str:
    r = subprocess.run(["cmd", "/c", str(DUMPER), "dump", str(md), str(out)],
                       capture_output=True, text=True)
    if r.returncode != 0 or not out.exists():
        raise SystemExit(f"dumper failed for {md.name}:\n{r.stdout}\n{r.stderr}")
    return out.read_text(encoding="utf-8", errors="replace")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--fixtures", default=str(FIXTURES), help="fixture folder")
    ap.add_argument("--outdir", default=str(HERE / "out"), help="where to put rendered HTML")
    ap.add_argument("--extra", action="append", default=[],
                    help="another .md to check (e.g. the harness sample)")
    args = ap.parse_args()

    fixtures = pathlib.Path(args.fixtures)
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    targets = sorted(p for p in fixtures.glob("*.md") if p.name != "README.md")
    fixture_names = {p.name for p in targets}
    # --extra paths are resolved: the dumper runs with its own working
    # directory, so a relative path would not be found.
    targets += [pathlib.Path(e).resolve() for e in args.extra]

    failures: list[str] = []
    print(f"{'fixture':<28} {'layer':<11} {'inline':>6} {'allow':>6} {'block':>6}  verdict")
    print("-" * 82)

    for md in targets:
        htmltext = render(md, outdir / (md.stem + ".html"))
        c = Collector()
        c.feed(htmltext)

        allowed = [r for r in c.refs if r.allowed]
        blocked = [r for r in c.refs if not r.allowed]

        # An --extra document is real content that must render completely.
        layer = LAYER.get(md.name, "csp") if md.name in fixture_names else "control"

        if layer == "target":
            ok, verdict = True, "n/a"
        elif layer == "control":
            ok = not blocked
            verdict = "CLEAN" if ok else "LEAKS"
            if not ok:
                failures.append(f"{md.name}: {len(blocked)} blocked reference(s) in a document "
                                "that must render completely")
        elif layer == "csp":
            ok = bool(blocked)
            verdict = "refused by CSP" if ok else "TESTS NOTHING"
            if not ok:
                failures.append(f"{md.name}: declared a CSP test but emits no blocked reference")
        elif layer == "navigation":
            ok = not blocked
            verdict = "runtime gate" if ok else "UNEXPECTED"
            if not ok:
                failures.append(f"{md.name}: refused by the navigation gate at runtime, so the "
                                f"generator should emit no blocked reference, but {len(blocked)} "
                                "appeared")
        elif layer == "generator":
            own = [r for r in allowed if r.value.startswith(OWN_ORIGIN)]
            ok = (not blocked) and len(own) == 1
            verdict = "refused by generator" if ok else "UNEXPECTED"
            if not ok:
                failures.append(f"{md.name}: expected the generator to refuse every hostile path "
                                f"and keep exactly one legitimate image; got {len(blocked)} "
                                f"blocked and {len(own)} own-origin image(s)")
        else:
            ok, verdict = False, "UNKNOWN LAYER"
            failures.append(f"{md.name}: unknown layer '{layer}'")

        print(f"{md.name:<28} {layer:<11} {c.inline_styles:>6} {len(allowed):>6} "
              f"{len(blocked):>6}  {verdict}")
        for r in blocked:
            print(f"    BLOCKED  {r.short():<72} [{r.why}]")
        for r in allowed:
            print(f"    allowed  {r.short():<72} [{r.why}]")

    print("-" * 82)
    if failures:
        for f in failures:
            print("FAIL:", f)
        return 1
    print("RESULT: PASS - every document matched the layer that is supposed to refuse it; "
          "the control document renders completely.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
