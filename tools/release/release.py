#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Release preparation of Tandem Commander - status, stamp, check (feature 243).

The skill /tandem-release calls this tool; the maintainer may run it by hand.
It prepares the records of ONE version for release on ONE day (default today)
and never builds, signs, tags, pushes or publishes anything.

The release records (the list is also in backlog/RELEASE.md, "Release records";
formats in specs/243-tandem-release-skill/contracts/records.md):

  src/plugins/shared/spl_vers.h            version macros, build number, build history
  setup/tandemcommander.iss                MyAppVersion
  CHANGELOG.md                             ## [x.y.z] - YYYY-MM-DD, lead "**Build N.** ..."
  PRIVACY.md                               "This statement describes ...", "Last updated ..."
  CLAUDE.md                                product line, "## Status (date)"
  architecture/12-project-reference.md     product line
  backlog/RELEASE.md                       "## Current release: ...", "Gating person steps:"
  release_notes/release_notes_v<x.y.z>.md  GitHub release body

Commands (specs/243-tandem-release-skill/contracts/cli.md):

  status <ver>   release context, state, refusals, warnings (reads only)
  stamp <ver>    the mechanical edits of all records (idempotent; --dry-run)
  check <ver>    consistency of all records for version, build and date
  summary <ver>  the winget release summary exactly as tools/winget/publish.ps1 makes it

Design rules
------------
* The state is derived from git tags, the source and the changelog; nothing is
  stored besides the records themselves.
* The build number of a version is the build of the previous release tag + 1.
* Edits keep each file's BOM and line endings; an unchanged file is never
  rewritten, so a second stamp on the same day changes nothing.
* Wording that needs judgement is left to the skill: stamp writes the
  placeholders TODO-SUMMARY, TODO-KIND, TODO-PRIVACY and TODO, and check fails
  while any of them remains.

Standard library only. Exit codes: 0 success / no findings, 1 refused or
findings, 2 usage error.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants

PATH_SPL = "src/plugins/shared/spl_vers.h"
PATH_ISS = "setup/tandemcommander.iss"
PATH_CHANGELOG = "CHANGELOG.md"
PATH_PRIVACY = "PRIVACY.md"
PATH_CLAUDE = "CLAUDE.md"
PATH_REFERENCE = "architecture/12-project-reference.md"
PATH_RELEASE = "backlog/RELEASE.md"
PATH_VERSINFO = "src/versinfo.rh2"
NOTES_DIR = "release_notes"
ITEMS_DIR = "backlog/items"
BACKLOG_TOOL = "tools/backlog/backlog.py"
ISS_BUILD_DIR = "build"  # setup/tandemcommander.iss packs ..\build\tandemcommander\Release_x64

MONTHS = ["January", "February", "March", "April", "May", "June", "July",
          "August", "September", "October", "November", "December"]
NOTES_SECTIONS = ["New", "Changed", "Fixed", "Removed"]
NOTES_FOOTER = ("Install over the previous version — settings are preserved · "
                "Free software under the GNU GPL v2 or later · <https://tandemcommander.org> "
                "· full detail in `CHANGELOG.md`")
PLACEHOLDER = "TODO"
SUMMARY_MAX_CHARS = 900   # tools/winget/publish.ps1 $SummaryMaxChars
SUMMARY_WRAP_COLUMN = 76  # tools/winget/publish.ps1 $SummaryWrapColumn
CERT_WARN_DAYS = 60
DATE_AHEAD_DAYS = 30

EM = "—"
EN = "–"
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
VERSION_RE = re.compile(r"(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})")
HEADING_RE = re.compile(r"^## \[(?P<label>[^\]]+)\](?:\s+" + EM + r"\s+(?P<when>\S.*?))?\s*$")
LIST_ITEM_RE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s")
HISTORY_RE = re.compile(r"^// (?P<build>\d+) - Tandem Commander (?P<ver>\S+) \(", re.M)
FEATURES_RE = re.compile(
    r"\bfeatures?\s+(\d{3}(?:\s*[-" + EN + r"]\s*\d{3})?(?:(?:\s*,\s*|\s+and\s+)\d{3}(?:\s*[-" + EN + r"]\s*\d{3})?)*)")
ISSUE_RE = re.compile(r"(?<![\w/#-])#(\d{1,5})\b")
SLUG_RE = re.compile(r"`([a-z0-9][a-z0-9-]*)`")

CLAUDE_PRODUCT_RE = re.compile(
    r"\*\*Tandem Commander (?P<ver>[^*\s]+)\*\* \(internal build (?P<build>\d+),\s+"
    r"release dated (?P<date>\S+?);\s+carries features (?P<range>\d+[" + EN + r"-]\d+);\s+"
    r"previous:\s+(?P<prev>\S+)\s+/\s+build\s+(?P<pbuild>\d+)\s+/\s+tag\s+`v(?P<ptag>[^`]+)`\)")
REFERENCE_PRODUCT_RE = re.compile(
    r"version \*\*(?P<ver>[^*\s]+)\*\* \(internal build (?P<build>\d+),\s+"
    r"release dated (?P<date>\S+) " + EM + r" it carries features (?P<range>\d+[" + EN + r"-]\d+),\s+"
    r"everything made since (?P<prev>\S+) / build (?P<pbuild>\d+) / tag `v(?P<ptag>[^`]+)`\)")
PRIVACY_DESCRIBES_RE = re.compile(r"This statement describes Tandem Commander (?P<ver>\S+) \(`CHANGELOG\.md`\)\.")
PRIVACY_CHAIN_RE = re.compile(
    r"This statement describes Tandem Commander (?P<ver>\S+) \(`CHANGELOG\.md`\)\.\s+"
    r"In (?P<pold>\S+?),\s+the version before it,\s*")
PRIVACY_DATE_RE = re.compile(r"Last updated (?P<date>\d{4}-\d{2}-\d{2})\.")
STATUS_RE = re.compile(r"^## Status \((?P<date>[^)]*)\)\s*$", re.M)
CURRENT_RE = re.compile(r"^## Current release: .*$", re.M)
NOTES_HEADER_RE = re.compile(
    r"^\*\*Released (?P<date>\d{1,2} [A-Z][a-z]+ \d{4}) · build (?P<build>\d+) · "
    r"Windows 11 or newer, 64-bit · (?P<kind>[^*]+)\*\*$")


class Refused(Exception):
    """A condition that forbids preparing the release (nothing is written)."""


class UsageError(Exception):
    pass


# ---------------------------------------------------------------------------
# Versions and dates


@dataclass(frozen=True, order=True)
class Version:
    major: int
    minora: int
    minorb: int

    @staticmethod
    def parse(text: str) -> "Version | None":
        m = VERSION_RE.fullmatch(text or "")
        return Version(int(m[1]), int(m[2]), int(m[3])) if m else None

    @property
    def text(self) -> str:
        return f"{self.major}.{self.minora}.{self.minorb}"

    @property
    def tag(self) -> str:
        return "v" + self.text

    @property
    def installer(self) -> str:
        return f"tandemcommander-{self.text}-x64-setup.exe"

    def same_line(self, other: "Version") -> bool:
        return (self.major, self.minora) == (other.major, other.minora)

    def __str__(self) -> str:
        return self.text


def long_date(d: dt.date) -> str:
    return f"{d.day} {MONTHS[d.month - 1]} {d.year}"


# ---------------------------------------------------------------------------
# Records: byte-preserving text files


class Record:
    """A text file read with its BOM and line ending remembered; ``text`` uses \\n."""

    def __init__(self, root: Path, rel: str, eol_if_new: str = "\n"):
        self.rel = rel
        self.path = root / rel
        self.exists = self.path.is_file()
        raw = self.path.read_bytes() if self.exists else b""
        self.bom = raw.startswith(b"\xef\xbb\xbf")
        if self.bom:
            raw = raw[3:]
        text = raw.decode("utf-8")
        crlf = text.count("\r\n")
        lf = text.count("\n") - crlf
        self.eol = ("\r\n" if crlf > lf else "\n") if self.exists else eol_if_new
        self.original = text.replace("\r\n", "\n") if self.exists else None
        self.text = self.original if self.exists else ""

    @property
    def changed(self) -> bool:
        return self.text != self.original

    def line_of(self, index: int) -> int:
        return self.text.count("\n", 0, index) + 1

    def save(self) -> bool:
        if not self.changed:
            return False
        data = self.text.replace("\n", self.eol) if self.eol != "\n" else self.text
        payload = (b"\xef\xbb\xbf" if self.bom else b"") + data.encode("utf-8")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix=".release-", dir=str(self.path.parent))
        try:
            with os.fdopen(fd, "wb") as f:
                f.write(payload)
            os.replace(tmp, self.path)
        except BaseException:
            if os.path.exists(tmp):
                os.unlink(tmp)
            raise
        self.original = self.text
        self.exists = True
        return True


def sub_group(text: str, m: re.Match, values: dict[str, str]) -> str:
    """Replace named groups of one match, keeping everything between them."""
    out, pos = [], m.start()
    spans = sorted((m.span(k), v) for k, v in values.items())
    for (a, b), v in spans:
        out.append(text[pos:a])
        out.append(v)
        pos = b
    out.append(text[pos:m.end()])
    return text[:m.start()] + "".join(out) + text[m.end():]


# ---------------------------------------------------------------------------
# git


def git(root: Path, *args: str, timeout: int = 60) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=str(root), capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=timeout)


def git_out(root: Path, *args: str) -> str:
    r = git(root, *args)
    return r.stdout if r.returncode == 0 else ""


# ---------------------------------------------------------------------------
# Parsers


def spl_macros(text: str) -> dict[str, int]:
    out = {}
    for key in ("VERSINFO_SALAMANDER_MAJOR", "VERSINFO_SALAMANDER_MINORA", "VERSINFO_SALAMANDER_MINORB",
                "VERSINFO_BUILDNUMBER", "LAST_VERSION_OF_SALAMANDER"):
        m = re.search(r"^#define " + key + r"\s+(\d+)\s*$", text, re.M)
        if m:
            out[key] = int(m[1])
    return out


def spl_version(macros: dict[str, int]) -> Version | None:
    try:
        return Version(macros["VERSINFO_SALAMANDER_MAJOR"], macros["VERSINFO_SALAMANDER_MINORA"],
                       macros["VERSINFO_SALAMANDER_MINORB"])
    except KeyError:
        return None


def history_entry(text: str, build: int) -> list[tuple[str, str]]:
    """(version, whole entry text) of every build-history entry of ``build``."""
    out = []
    for m in HISTORY_RE.finditer(text):
        if int(m["build"]) != build:
            continue
        end = text.find("\n", m.start())
        lines = [text[m.start():end]]
        pos = end + 1
        while True:
            nxt = text.find("\n", pos)
            line = text[pos:nxt if nxt >= 0 else len(text)]
            if not line.startswith("//       "):
                break
            lines.append(line)
            pos = nxt + 1
        out.append((m["ver"], "\n".join(lines)))
    return out


@dataclass
class Section:
    label: str
    when: str | None
    start: int          # index of the heading line
    end: int            # index after the last line of the section
    lead: list[str] = field(default_factory=list)
    lead_start: int = -1
    grouped: bool = False

    @property
    def dated(self) -> bool:
        return bool(self.when and DATE_RE.fullmatch(self.when))

    @property
    def unreleased(self) -> bool:
        return self.label.lower() == "unreleased" or (self.when or "").lower() == "unreleased"


def changelog_sections(lines: list[str]) -> list[Section]:
    heads = [(i, HEADING_RE.match(ln)) for i, ln in enumerate(lines)]
    heads = [(i, m) for i, m in heads if m]
    out = []
    for k, (i, m) in enumerate(heads):
        end = heads[k + 1][0] if k + 1 < len(heads) else len(lines)
        s = Section(m["label"], m["when"], i, end)
        j = i + 1
        while j < end and not lines[j].strip():
            j += 1
        if j < end and not LIST_ITEM_RE.match(lines[j]) and not lines[j].startswith("#") \
                and not lines[j].startswith("|"):
            s.lead_start = j
            while j < end and lines[j].strip():
                s.lead.append(lines[j])
                j += 1
        s.grouped = any(ln.startswith("### ") for ln in lines[i + 1:end])
        out.append(s)
    return out


def section_body(lines: list[str], s: Section) -> list[str]:
    body = lines[s.start + 1:s.end]
    if s.lead:
        a = s.lead_start - (s.start + 1)
        body = body[:a] + body[a + len(s.lead):]
    while body and not body[0].strip():
        body.pop(0)
    while body and not body[-1].strip():
        body.pop()
    return body


def feature_numbers(text: str) -> set[int]:
    out: set[int] = set()
    for m in FEATURES_RE.finditer(text):
        for part in re.split(r"\s*,\s*|\s+and\s+", m[1]):
            r = re.split(r"\s*[-" + EN + r"]\s*", part)
            if len(r) == 2 and int(r[0]) <= int(r[1]) and int(r[1]) - int(r[0]) < 200:
                out.update(range(int(r[0]), int(r[1]) + 1))
            else:
                out.add(int(r[0]))
    return out


def issue_numbers(text: str) -> set[int]:
    return {int(n) for n in ISSUE_RE.findall(text)}


def item_header(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return out
    if not text.startswith("---"):
        return out
    for line in text.split("\n")[1:]:
        if line.strip() == "---":
            break
        if ":" in line:
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return out


# ---------------------------------------------------------------------------
# winget summary (exact replica of tools/winget/publish.ps1:119-207)


def winget_summary(changelog_text: str, version: str) -> dict:
    lines = changelog_text.replace("\r\n", "\n").split("\n")
    pat = re.compile(r"^##\s+\[" + re.escape(version) + r"\]\D*(\d{4}-\d{2}-\d{2})", re.I)
    start = next((i for i, ln in enumerate(lines) if pat.match(ln)), -1)
    res = {"found_heading": start >= 0, "text": None, "length": 0, "cut": False, "lines": [], "dropped": []}
    if start < 0:
        return res
    collected: list[str] = []
    for line in lines[start + 1:]:
        if re.match(r"^#{1,6}\s", line):
            break
        if not line.strip():
            if collected:
                break
            continue
        collected.append(line.strip())
    if not collected:
        return res
    text = " ".join(collected)
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    text = text.replace("**", "").replace("`", "")
    text = text.replace(EM, "-").replace(EN, "-")
    text = text.replace("“", '"').replace("”", '"').replace("‘", "'").replace("’", "'")
    text = re.sub(r"\s+", " ", text).strip()
    res["length"] = len(text)
    if len(text) > SUMMARY_MAX_CHARS:
        res["cut"] = True
        cut = text[:SUMMARY_MAX_CHARS]
        space = cut.rfind(" ")
        if space > 0:
            cut = cut[:space]
        text = cut.rstrip(" ,;-") + "..."
    res["text"] = text
    out, line = [], ""
    for word in text.split(" "):
        if not line:
            line = word
        elif len(line) + 1 + len(word) <= SUMMARY_WRAP_COLUMN:
            line = f"{line} {word}"
        else:
            out.append("  " + line)
            line = word
    if line:
        out.append("  " + line)
    res["lines"] = out
    res["dropped"] = [ln for ln in out if ln.lstrip().startswith("#")]
    return res


# ---------------------------------------------------------------------------
# Release context


@dataclass
class Context:
    root: Path
    target: Version
    date: dt.date
    offline: bool
    tags: list[Version] = field(default_factory=list)
    prev: Version | None = None
    prev_build: int | None = None
    prev_interface: int | None = None
    build: int | None = None
    branch: str = ""
    head: str = ""
    clean: bool = True
    lock: str = "free"
    tag_local: bool = False
    tag_remote: str = "unknown"
    source: Version | None = None
    source_build: int | None = None
    interface: int | None = None
    copyright_year: int | None = None
    features: set[int] = field(default_factory=set)
    issues: set[int] = field(default_factory=set)
    release_branches: list[str] = field(default_factory=list)
    gating: list[dict] = field(default_factory=list)
    gating_candidates: list[dict] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    refusals: list[str] = field(default_factory=list)
    state: str = "inconsistent"
    plan_messages: list[str] = field(default_factory=list)
    dropped_leads: list[str] = field(default_factory=list)
    records: dict[str, Record] = field(default_factory=dict)

    @property
    def interface_changed(self) -> bool:
        return self.prev_interface is not None and self.interface is not None \
            and self.prev_interface != self.interface

    def rec(self, rel: str) -> Record:
        if rel not in self.records:
            eol = "\n"
            if rel.startswith(NOTES_DIR + "/"):
                eol = self.rec(PATH_CHANGELOG).eol
            self.records[rel] = Record(self.root, rel, eol)
        return self.records[rel]

    @property
    def notes_rel(self) -> str:
        return f"{NOTES_DIR}/release_notes_v{self.target.text}.md"


def load_context(root: Path, target: Version, date: dt.date, offline: bool) -> Context:
    ctx = Context(root=root, target=target, date=date, offline=offline)
    for t in git_out(root, "tag", "--list", "v*").split():
        v = Version.parse(t[1:])
        if v and v.tag == t:
            ctx.tags.append(v)
    ctx.tags.sort()
    lower = [t for t in ctx.tags if t < target]
    ctx.prev = lower[-1] if lower else None
    if ctx.prev:
        old = spl_macros(git_out(root, "show", f"{ctx.prev.tag}:{PATH_SPL}"))
        ctx.prev_build = old.get("VERSINFO_BUILDNUMBER")
        ctx.prev_interface = old.get("LAST_VERSION_OF_SALAMANDER")
        if ctx.prev_build is not None:
            ctx.build = ctx.prev_build + 1
    ctx.branch = git_out(root, "branch", "--show-current").strip()
    ctx.head = git_out(root, "rev-parse", "--short", "HEAD").strip()
    ctx.clean = git_out(root, "status", "--porcelain").strip() == ""
    ctx.tag_local = target in ctx.tags
    if offline:
        ctx.tag_remote = "unknown"
    else:
        try:
            r = git(root, "ls-remote", "--tags", "origin", f"refs/tags/{target.tag}", timeout=30)
            ctx.tag_remote = ("yes" if r.stdout.strip() else "no") if r.returncode == 0 else "unknown"
        except (subprocess.TimeoutExpired, OSError):
            ctx.tag_remote = "unknown"
    tool = root / BACKLOG_TOOL
    if tool.is_file():
        r = subprocess.run([sys.executable, str(tool), "lock", "status"], cwd=str(root),
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        ctx.lock = (r.stdout.strip().splitlines() or ["?"])[0]
    macros = spl_macros(ctx.rec(PATH_SPL).text)
    ctx.source = spl_version(macros)
    ctx.source_build = macros.get("VERSINFO_BUILDNUMBER")
    ctx.interface = macros.get("LAST_VERSION_OF_SALAMANDER")
    vi = Record(root, PATH_VERSINFO)
    m = re.search(r"^#define VERSINFO_COPYRIGHT\s+(.*)$", vi.text or "", re.M)
    if m:
        years = [int(y) for y in re.findall(r"\b(\d{4})\b", m[1])]
        ctx.copyright_year = max(years) if years else None
    # Content of the release: the changelog region above the previous release.
    lines = ctx.rec(PATH_CHANGELOG).text.split("\n")
    secs = changelog_sections(lines)
    ip = next((k for k, s in enumerate(secs) if ctx.prev and s.label == ctx.prev.text), len(secs))
    region = "\n".join(lines[secs[0].start:secs[ip].start if ip < len(secs) else len(lines)]) if secs else ""
    ctx.features = feature_numbers(region)
    ctx.issues = issue_numbers(region)
    refs = git_out(root, "for-each-ref", "--format=%(refname:short)",
                   f"refs/heads/release-{target.text}*", f"refs/remotes/origin/release-{target.text}*")
    for ref in refs.split():
        n = git_out(root, "rev-list", "--count", f"HEAD..{ref}").strip()
        if n and n != "0":
            ctx.release_branches.append(f"{ref} ({n} commit(s) not in HEAD)")
    load_gating(ctx)
    return ctx


def current_release_section(text: str) -> tuple[int, int] | None:
    m = CURRENT_RE.search(text)
    if not m:
        return None
    nxt = re.search(r"^## ", text[m.end():], re.M)
    return m.start(), (m.end() + nxt.start()) if nxt else len(text)


def gating_slugs(text: str) -> list[str] | None:
    """Slugs listed under "Gating person steps:" of *Current release*; None if no list."""
    span = current_release_section(text)
    if not span:
        return None
    lines = text[span[0]:span[1]].split("\n")
    k = next((i for i, ln in enumerate(lines) if "Gating person steps:" in ln), None)
    if k is None:
        return None
    base = len(lines[k]) - len(lines[k].lstrip())
    slugs: list[str] = []
    for ln in lines[k + 1:]:
        if not ln.strip():
            break
        indent = len(ln) - len(ln.lstrip())
        if indent <= base:
            break
        if LIST_ITEM_RE.match(ln):
            m = SLUG_RE.search(ln)
            if m:
                slugs.append(m[1])
    return slugs


def load_gating(ctx: Context) -> None:
    text = ctx.rec(PATH_RELEASE).text or ""
    heading = CURRENT_RE.search(text)
    about_target = bool(heading and re.match(r"## Current release: " + re.escape(ctx.target.text) + r"\b",
                                             heading[0]))
    slugs = (gating_slugs(text) or []) if about_target else []
    items = ctx.root / ITEMS_DIR
    for slug in slugs:
        h = item_header(items / slug / "desc.md")
        status = "done" if not h or h.get("status") == "rejected" else "open"
        ctx.gating.append({"slug": slug, "title": h.get("title", "(removed)"), "status": status})
    if not items.is_dir():
        return
    for d in sorted(items.iterdir()):
        h = item_header(d / "desc.md")
        if h.get("type") != "person-step" or h.get("status") not in ("open", "blocked") or d.name in slugs:
            continue
        nums = {int(n) for n in re.findall(r"(?<![\d.])(\d{3})(?![\d.])", h.get("title", "") + " " + h.get("source", ""))}
        if nums & ctx.features:
            ctx.gating_candidates.append({"slug": d.name, "title": h.get("title", "")})


def evaluate(ctx: Context) -> None:
    """Fill refusals, warnings, state and the stamp plan (records edited in memory)."""
    t = ctx.target
    if ctx.prev is None or ctx.prev_build is None:
        ctx.refusals.append(f"no-previous-tag: no release tag below {t.tag} with a readable {PATH_SPL}")
        return
    if ctx.tag_local or ctx.tag_remote == "yes":
        where = "local" if ctx.tag_local else "remote"
        ctx.refusals.append(f"tag-exists: {t} is already released (tag {t.tag}, {where})")
    latest = ctx.tags[-1] if ctx.tags else None
    if latest and t < latest:
        ctx.refusals.append(f"not-higher: {t} is not higher than the last release {latest}")
    if not t.same_line(ctx.prev):
        ctx.refusals.append(f"line-change: {ctx.prev} -> {t} changes MAJOR.MINORA; the configuration root "
                            f"(HKCU\\Software\\Tandem Commander\\{ctx.prev.major}.{ctx.prev.minora}) follows it - "
                            "decide the migration first")
    if not ctx.clean:
        ctx.refusals.append("dirty-tree: the working tree has uncommitted changes")
    if ctx.lock != "free":
        ctx.refusals.append(f"lock-held: the backlog lock is held ({ctx.lock})")
    if ctx.copyright_year is not None and ctx.date.year > ctx.copyright_year:
        ctx.refusals.append(f"copyright-year: the release year {ctx.date.year} is after the copyright year "
                            f"{ctx.copyright_year} of {PATH_VERSINFO} - decide the notices first")
    if ctx.branch != "main":
        ctx.warnings.append(f"branch-not-main: the current branch is '{ctx.branch or '(detached)'}', not main")
    if t.same_line(ctx.prev) and t.minorb != ctx.prev.minorb + 1:
        ctx.warnings.append(f"minorb-skip: {ctx.prev} -> {t} skips a version")
    if ctx.tag_remote == "unknown":
        ctx.warnings.append("remote-unknown: the remote tags were not checked")
    env = os.environ.get("OPENSAL_BUILD_DIR")
    if env and Path(env).resolve() != (ctx.root / ISS_BUILD_DIR).resolve():
        ctx.warnings.append(f"build-dir: OPENSAL_BUILD_DIR={env}, but {PATH_ISS} packs "
                            f"{ISS_BUILD_DIR}\\tandemcommander\\Release_x64")
    m = re.search(r"before \*\*(\d{4}-\d{2}-\d{2})\*\*", ctx.rec(PATH_RELEASE).text or "")
    if m:
        expiry = dt.date.fromisoformat(m[1])
        if (expiry - ctx.date).days <= CERT_WARN_DAYS:
            ctx.warnings.append(f"certificate: the code-signing certificate expires {expiry}")
    if ctx.date > dt.date.today() + dt.timedelta(days=DATE_AHEAD_DAYS):
        ctx.warnings.append(f"date-range: the release date {ctx.date} is far ahead")
    for b in ctx.release_branches:
        ctx.warnings.append(f"release-branch-ahead: {b}")
    # A released version, a lower one or another line: nothing more to say about the records
    if ctx.tag_local or ctx.tag_remote == "yes":
        ctx.state = "released"
        return
    if any(r.startswith(("not-higher", "line-change")) for r in ctx.refusals):
        ctx.state = "refused"
        return
    # State and plan
    at_prev = ctx.source == ctx.prev and ctx.source_build == ctx.prev_build
    at_target = ctx.source == t and ctx.source_build == ctx.build
    if not (at_prev or at_target):
        ctx.refusals.append(f"inconsistent: {PATH_SPL} states {ctx.source} build {ctx.source_build}; expected "
                            f"{ctx.prev} build {ctx.prev_build} (not prepared) or {t} build {ctx.build}")
        ctx.state = "inconsistent"
        return
    try:
        plan(ctx)
    except Refused as e:
        ctx.refusals.append(f"inconsistent: {e}")
        ctx.state = "inconsistent"
        return
    if at_prev:
        ctx.state = "not-prepared"
    elif any(r.changed for r in ctx.records.values()):
        ctx.state = "prepared-earlier"
    else:
        ctx.state = "prepared-today"


# ---------------------------------------------------------------------------
# Stamp plan (edits in memory)


def note(ctx: Context, rec: Record, index: int, what: str) -> None:
    ctx.plan_messages.append(f"{rec.rel}:{rec.line_of(index)}: {what}")


def plan(ctx: Context) -> None:
    plan_spl(ctx)
    plan_iss(ctx)
    plan_changelog(ctx)
    plan_privacy(ctx)
    plan_claude(ctx)
    plan_reference(ctx)
    plan_release(ctx)
    plan_notes(ctx)


def plan_spl(ctx: Context) -> None:
    rec, t = ctx.rec(PATH_SPL), ctx.target
    for key, val in (("VERSINFO_SALAMANDER_MAJOR", t.major), ("VERSINFO_SALAMANDER_MINORA", t.minora),
                     ("VERSINFO_SALAMANDER_MINORB", t.minorb), ("VERSINFO_BUILDNUMBER", ctx.build)):
        m = re.search(r"^(#define " + key + r"\s+)(\d+)", rec.text, re.M)
        if not m:
            raise Refused(f"{PATH_SPL} has no #define {key}")
        if int(m[2]) != val:
            note(ctx, rec, m.start(), f"{key} {m[2]} -> {val}")
            rec.text = rec.text[:m.start(2)] + str(val) + rec.text[m.end(2):]
    entries = history_entry(rec.text, ctx.build)
    if any(v != t.text for v, _ in entries):
        raise Refused(f"{PATH_SPL}: build {ctx.build} is recorded for another version")
    if not entries:
        m = re.search(r"^// ! DULEZITE", rec.text, re.M)
        if not m:
            raise Refused(f"{PATH_SPL} has no '// ! DULEZITE' line to put the build history above")
        lines = rec.text.split("\n")
        k = rec.text.count("\n", 0, m.start())
        while k > 0 and not lines[k - 1].strip():
            k -= 1
        lines.insert(k, f"// {ctx.build} - Tandem Commander {t} (TODO-SUMMARY; see CHANGELOG.md)")
        rec.text = "\n".join(lines)
        ctx.plan_messages.append(f"{rec.rel}:{k + 1}: build history entry {ctx.build} added (TODO-SUMMARY)")
    if ctx.interface_changed:
        m = re.search(r"^(#define REQUIRE_LAST_VERSION_OF_SALAMANDER .*?first shipped )(after|in)( version )"
                      r"([0-9.]+?)(\.\")", rec.text, re.M)
        if m and (m[2] != "in" or m[4] != t.text):
            note(ctx, rec, m.start(), f"REQUIRE_LAST_VERSION_OF_SALAMANDER -> first shipped in version {t}")
            rec.text = rec.text[:m.start(2)] + "in" + m[3] + t.text + rec.text[m.end(4):]


def plan_iss(ctx: Context) -> None:
    rec = ctx.rec(PATH_ISS)
    m = re.search(r'^#define MyAppVersion "([^"]*)"', rec.text, re.M)
    if not m:
        raise Refused(f"{PATH_ISS} has no #define MyAppVersion")
    if m[1] != ctx.target.text:
        note(ctx, rec, m.start(), f"MyAppVersion {m[1]} -> {ctx.target}")
        rec.text = rec.text[:m.start(1)] + ctx.target.text + rec.text[m.end(1):]


def plan_changelog(ctx: Context) -> None:
    rec, t = ctx.rec(PATH_CHANGELOG), ctx.target
    lines = rec.text.split("\n")
    secs = changelog_sections(lines)
    ip = next((k for k, s in enumerate(secs) if s.label == ctx.prev.text), None)
    if ip is None:
        raise Refused(f"{PATH_CHANGELOG} has no section [{ctx.prev}]")
    region = secs[:ip]
    if not region:
        raise Refused(f"{PATH_CHANGELOG} has no section above [{ctx.prev}] - nothing to release")
    for s in region:
        if s.label.lower() == "unreleased" and s.when is None:
            continue
        v = Version.parse(s.label)
        if v is None:
            raise Refused(f"{PATH_CHANGELOG}:{s.start + 1}: heading [{s.label}] is not a version")
        if s.dated and v != t:
            raise Refused(f"{PATH_CHANGELOG}:{s.start + 1}: [{s.label}] is dated {s.when} above [{ctx.prev}]")
        if not s.dated and not s.unreleased:
            raise Refused(f"{PATH_CHANGELOG}:{s.start + 1}: heading [{s.label}] is neither dated nor unreleased")
        if v <= ctx.prev:
            raise Refused(f"{PATH_CHANGELOG}:{s.start + 1}: [{s.label}] is not above [{ctx.prev}]")
    heading = f"## [{t}] {EM} {ctx.date.isoformat()}"
    placeholder = [f"**Build {ctx.build}.** TODO-KIND release. TODO-SUMMARY"]
    if len(region) == 1:
        s = region[0]
        if lines[s.start] != heading:
            ctx.plan_messages.append(f"{rec.rel}:{s.start + 1}: {lines[s.start]} -> {heading}")
            lines[s.start] = heading
        if not s.lead:
            lines[s.start + 1:s.start + 1] = ["", *placeholder]
            ctx.plan_messages.append(f"{rec.rel}:{s.start + 2}: lead placeholder added")
        rec.text = "\n".join(lines)
        return
    if any(s.grouped for s in region):
        raise Refused(f"{PATH_CHANGELOG}: sections with ### groups cannot be folded mechanically - merge by hand")
    own = next((s for s in region if Version.parse(s.label) == t and s.lead), None)
    lead_src = own or next((s for s in region if s.lead), None)
    for s in region:
        if s.lead and s is not lead_src:
            ctx.dropped_leads.append(f"[{s.label}] (line {s.lead_start + 1}): " + " ".join(x.strip() for x in s.lead))
    new = [heading, ""] + (lead_src.lead if lead_src else placeholder) + [""]
    for s in region:
        body = section_body(lines, s)
        if body:
            new += body + [""]
    rebuilt = lines[:region[0].start] + new + lines[secs[ip].start:]
    ctx.plan_messages.append(f"{rec.rel}:{region[0].start + 1}: {len(region)} sections folded into {heading}")
    rec.text = "\n".join(rebuilt)


def plan_privacy(ctx: Context) -> None:
    rec, t = ctx.rec(PATH_PRIVACY), ctx.target
    m = PRIVACY_DESCRIBES_RE.search(rec.text)
    if not m:
        raise Refused(f"{PATH_PRIVACY} has no 'This statement describes Tandem Commander ...' sentence")
    if m["ver"] != t.text:
        if m["ver"] != ctx.prev.text:
            raise Refused(f"{PATH_PRIVACY} describes {m['ver']}, expected {ctx.prev} or {t}")
        c = PRIVACY_CHAIN_RE.search(rec.text)
        if not c:
            raise Refused(f"{PATH_PRIVACY} has no 'In <version>, the version before it,' after the describes sentence")
        repl = (f"This statement describes Tandem Commander {t} (`CHANGELOG.md`). In {ctx.prev}, the version "
                f"before it, TODO-PRIVACY. In {c['pold']}: ")
        note(ctx, rec, c.start(), f"describes {m['ver']} -> {t}; In {ctx.prev}, the version before it (TODO-PRIVACY)")
        rec.text = rec.text[:c.start()] + repl + rec.text[c.end():]
    d = PRIVACY_DATE_RE.search(rec.text)
    if not d:
        raise Refused(f"{PATH_PRIVACY} has no 'Last updated YYYY-MM-DD.' line")
    if d["date"] != ctx.date.isoformat():
        note(ctx, rec, d.start(), f"Last updated {d['date']} -> {ctx.date}")
        rec.text = rec.text[:d.start("date")] + ctx.date.isoformat() + rec.text[d.end("date"):]


def feature_range(ctx: Context, current: str) -> str:
    if not ctx.features:
        return current
    return f"{min(ctx.features):03d}{EN}{max(ctx.features):03d}"


def plan_product(ctx: Context, rel: str, regex: re.Pattern) -> None:
    rec = ctx.rec(rel)
    m = regex.search(rec.text)
    if not m:
        raise Refused(f"{rel} has no product line in the expected form")
    want = {"ver": ctx.target.text, "build": str(ctx.build), "date": ctx.date.isoformat(),
            "range": feature_range(ctx, m["range"]), "prev": ctx.prev.text, "pbuild": str(ctx.prev_build),
            "ptag": ctx.prev.text}
    diff = {k: v for k, v in want.items() if m[k] != v}
    if diff:
        note(ctx, rec, m.start(), "product line: " + ", ".join(f"{k} {m[k]} -> {v}" for k, v in diff.items()))
        rec.text = sub_group(rec.text, m, diff)


def plan_claude(ctx: Context) -> None:
    plan_product(ctx, PATH_CLAUDE, CLAUDE_PRODUCT_RE)
    rec = ctx.rec(PATH_CLAUDE)
    m = STATUS_RE.search(rec.text)
    if not m:
        raise Refused(f"{PATH_CLAUDE} has no '## Status (date)' heading")
    if m["date"] != ctx.date.isoformat():
        note(ctx, rec, m.start(), f"## Status ({m['date']}) -> ({ctx.date})")
        rec.text = rec.text[:m.start("date")] + ctx.date.isoformat() + rec.text[m.end("date"):]


def plan_reference(ctx: Context) -> None:
    plan_product(ctx, PATH_REFERENCE, REFERENCE_PRODUCT_RE)


def current_heading(ctx: Context) -> str:
    return f"## Current release: {ctx.target} (build {ctx.build}) {EM} prepared, not published"


def plan_release(ctx: Context) -> None:
    rec = ctx.rec(PATH_RELEASE)
    m = CURRENT_RE.search(rec.text)
    if not m:
        raise Refused(f"{PATH_RELEASE} has no '## Current release: ...' heading")
    want = current_heading(ctx)
    if m[0] != want:
        note(ctx, rec, m.start(), f"{m[0]} -> {want}")
        rec.text = rec.text[:m.start()] + want + rec.text[m.end():]


def notes_skeleton(ctx: Context) -> str:
    parts = [f"# Tandem Commander {ctx.target}", "",
             f"**Released {long_date(ctx.date)} · build {ctx.build} · Windows 11 or newer, 64-bit "
             f"· TODO-KIND**", ""]
    for s in NOTES_SECTIONS:
        parts += [f"## {s}", "", "- TODO", ""]
    parts += ["---", "", NOTES_FOOTER, ""]
    return "\n".join(parts)


def plan_notes(ctx: Context) -> None:
    rec = ctx.rec(ctx.notes_rel)
    if not rec.exists:
        rec.text = notes_skeleton(ctx)
        ctx.plan_messages.append(f"{rec.rel}:1: created (skeleton with TODO)")
        return
    lines = rec.text.split("\n")
    title = f"# Tandem Commander {ctx.target}"
    if lines and lines[0] != title:
        ctx.plan_messages.append(f"{rec.rel}:1: {lines[0]} -> {title}")
        lines[0] = title
    for i, ln in enumerate(lines):
        m = NOTES_HEADER_RE.match(ln)
        if m:
            new = (f"**Released {long_date(ctx.date)} · build {ctx.build} · Windows 11 or newer, "
                   f"64-bit · {m['kind']}**")
            if ln != new:
                ctx.plan_messages.append(f"{rec.rel}:{i + 1}: Released {m['date']} build {m['build']} -> "
                                         f"{long_date(ctx.date)} build {ctx.build}")
                lines[i] = new
            break
    else:
        raise Refused(f"{rec.rel} has no '**Released <date> · build N · ...**' line")
    rec.text = "\n".join(lines)


# ---------------------------------------------------------------------------
# Check


@dataclass
class Finding:
    path: str
    line: int
    rule: str
    message: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.rule}: {self.message}"


def check_notes(text: str | None, rel: str, ver: str, build: int, date: dt.date,
                issues: set[int]) -> list[Finding]:
    """The notes-* rules; usable for a published version too (its own date and build)."""
    if text is None:
        return [Finding(rel, 1, "notes-missing", "the release notes file does not exist")]
    f: list[Finding] = []
    lines = text.split("\n")
    if not lines or lines[0] != f"# Tandem Commander {ver}":
        f.append(Finding(rel, 1, "notes-header", f"the title is not '# Tandem Commander {ver}'"))
    hdr = next(((i, NOTES_HEADER_RE.match(ln)) for i, ln in enumerate(lines) if NOTES_HEADER_RE.match(ln)), None)
    if not hdr:
        f.append(Finding(rel, 3, "notes-header", "no '**Released <d Month yyyy> · build N · Windows 11 "
                                                  "or newer, 64-bit · <kind>**' line"))
    else:
        i, m = hdr
        if m["date"] != long_date(date):
            f.append(Finding(rel, i + 1, "notes-header", f"released {m['date']}, expected {long_date(date)}"))
        if int(m["build"]) != build:
            f.append(Finding(rel, i + 1, "notes-header", f"build {m['build']}, expected {build}"))
    heads = [(i, ln[3:].strip()) for i, ln in enumerate(lines) if ln.startswith("## ")]
    names = [h for _, h in heads]
    order = [n for n in NOTES_SECTIONS if n in names]
    for i, h in heads:
        if h not in NOTES_SECTIONS:
            f.append(Finding(rel, i + 1, "notes-sections", f"section '{h}' is not one of {', '.join(NOTES_SECTIONS)}"))
    if not heads:
        f.append(Finding(rel, 1, "notes-sections", "no section"))
    elif [n for n in names if n in NOTES_SECTIONS] != order or len(set(names)) != len(names):
        f.append(Finding(rel, heads[0][0] + 1, "notes-sections", "sections out of order or repeated"))
    ends = [k for k, ln in enumerate(lines) if ln.strip() == "---"]
    stop = ends[-1] if ends else len(lines)
    for k, (i, h) in enumerate(heads):
        end = heads[k + 1][0] if k + 1 < len(heads) else stop
        if not any(ln.strip() for ln in lines[i + 1:end]):
            f.append(Finding(rel, i + 1, "notes-sections", f"section '{h}' is empty"))
    tail = [ln for ln in lines if ln.strip()]
    if not tail or tail[-1] != NOTES_FOOTER or len(tail) < 2 or tail[-2].strip() != "---":
        f.append(Finding(rel, len(lines), "notes-footer", "the last lines are not '---' and the fixed footer"))
    have = issue_numbers(text)
    for n in sorted(issues - have):
        f.append(Finding(rel, 1, "notes-issues", f"GitHub #{n} of the changelog section is not in the notes"))
    for i, ln in enumerate(lines):
        if PLACEHOLDER in ln:
            f.append(Finding(rel, i + 1, "notes-todo", "a TODO placeholder remains"))
    return f


def run_check(ctx: Context) -> list[Finding]:
    f: list[Finding] = []
    t, build, date = ctx.target, ctx.build, ctx.date
    # spl_vers.h
    rec = ctx.rec(PATH_SPL)
    macros = spl_macros(rec.text)
    if spl_version(macros) != t:
        f.append(Finding(rec.rel, 35, "source-version", f"VERSINFO_SALAMANDER_* state {spl_version(macros)}, expected {t}"))
    if macros.get("VERSINFO_BUILDNUMBER") != build:
        f.append(Finding(rec.rel, 1, "source-build", f"VERSINFO_BUILDNUMBER {macros.get('VERSINFO_BUILDNUMBER')}, expected {build}"))
    entries = history_entry(rec.text, build)
    if len(entries) != 1 or entries[0][0] != t.text:
        f.append(Finding(rec.rel, 1, "build-history", f"expected one entry '// {build} - Tandem Commander {t} ('"))
    elif PLACEHOLDER in entries[0][1]:
        f.append(Finding(rec.rel, rec.line_of(rec.text.find(entries[0][1])), "build-history", "TODO-SUMMARY remains"))
    if ctx.interface_changed and f"first shipped in version {t}." not in rec.text:
        f.append(Finding(rec.rel, 1, "interface-text", f"the plugin interface changed since {ctx.prev.tag} but "
                                                      f"REQUIRE_LAST_VERSION_OF_SALAMANDER does not say 'first shipped in version {t}.'"))
    # installer
    rec = ctx.rec(PATH_ISS)
    m = re.search(r'^#define MyAppVersion "([^"]*)"', rec.text, re.M)
    if not m or m[1] != t.text:
        f.append(Finding(rec.rel, 2, "installer-version", f"MyAppVersion {m[1] if m else '(none)'}, expected {t}"))
    # changelog
    rec = ctx.rec(PATH_CHANGELOG)
    lines = rec.text.split("\n")
    secs = changelog_sections(lines)
    mine = [s for s in secs if s.label == t.text]
    if len(mine) != 1 or mine[0].when != date.isoformat():
        f.append(Finding(rec.rel, mine[0].start + 1 if mine else 1, "changelog-heading",
                         f"expected exactly one '## [{t}] {EM} {date}'"))
    for s in secs:
        if s.unreleased:
            f.append(Finding(rec.rel, s.start + 1, "changelog-unreleased", f"[{s.label}] is unreleased"))
    expect = [v.text for v in sorted((v for v in ctx.tags if v <= ctx.prev), reverse=True)]
    ip = next((k for k, s in enumerate(secs) if s.label == ctx.prev.text), None)
    below = [s.label for s in secs[ip:]] if ip is not None else []
    if below != expect or (ip is not None and secs[:ip] != mine[:1]) or ip is None:
        f.append(Finding(rec.rel, secs[ip].start + 1 if ip is not None else 1, "changelog-history",
                         "the sections are not exactly one for the target followed by one per release tag, newest first"))
    if mine:
        s = mine[0]
        lead = " ".join(x.strip() for x in s.lead)
        if not s.lead:
            f.append(Finding(rec.rel, s.start + 1, "changelog-lead", "no lead paragraph (the first block is a list or missing)"))
        else:
            ln = s.lead_start + 1
            if not lead.startswith(f"**Build {build}.**"):
                f.append(Finding(rec.rel, ln, "changelog-lead", f"the lead does not start with '**Build {build}.**'"))
            if "#" in lead:
                f.append(Finding(rec.rel, ln, "changelog-lead", "the lead contains '#'"))
            if PLACEHOLDER in lead:
                f.append(Finding(rec.rel, ln, "changelog-lead", "a TODO placeholder remains"))
        w = winget_summary(rec.text, t.text)
        if not w["text"]:
            f.append(Finding(rec.rel, s.start + 1, "winget-summary", "publish.ps1 would find no summary"))
        else:
            if w["cut"]:
                f.append(Finding(rec.rel, s.start + 1, "winget-summary",
                                 f"the summary has {w['length']} characters and would be cut at {SUMMARY_MAX_CHARS}"))
            for d in w["dropped"]:
                f.append(Finding(rec.rel, s.start + 1, "winget-summary", f"publish.ps1 would drop the line: {d.strip()}"))
    # privacy
    rec = ctx.rec(PATH_PRIVACY)
    if not re.search(r"This statement describes Tandem Commander " + re.escape(t.text) + r" \(`CHANGELOG\.md`\)\.", rec.text):
        f.append(Finding(rec.rel, 1, "privacy-version", f"no 'This statement describes Tandem Commander {t}'"))
    if not re.search(r"In " + re.escape(ctx.prev.text) + r",\s+the version before it,", rec.text):
        f.append(Finding(rec.rel, 1, "privacy-previous", f"no 'In {ctx.prev}, the version before it,'"))
    k = rec.text.find("TODO-PRIVACY")
    if k >= 0:
        f.append(Finding(rec.rel, rec.line_of(k), "privacy-previous", "TODO-PRIVACY remains"))
    if not re.search(r"Last updated " + re.escape(date.isoformat()) + r"\.", rec.text):
        f.append(Finding(rec.rel, 1, "privacy-date", f"no 'Last updated {date}.'"))
    # product lines
    ranges = {}
    for rel, regex, rule in ((PATH_CLAUDE, CLAUDE_PRODUCT_RE, "claude-product"),
                             (PATH_REFERENCE, REFERENCE_PRODUCT_RE, "reference-product")):
        rec = ctx.rec(rel)
        m = regex.search(rec.text)
        if not m:
            f.append(Finding(rel, 1, rule, "no product line in the expected form"))
            continue
        ranges[rel] = m["range"].replace("-", EN)
        want = {"ver": t.text, "build": str(build), "date": date.isoformat(), "prev": ctx.prev.text,
                "pbuild": str(ctx.prev_build), "ptag": ctx.prev.text}
        bad = [f"{k} {m[k]} (expected {v})" for k, v in want.items() if m[k] != v]
        if bad:
            f.append(Finding(rel, rec.line_of(m.start()), rule, "; ".join(bad)))
    if len(set(ranges.values())) > 1:
        f.append(Finding(PATH_REFERENCE, 1, "reference-product",
                         f"feature range {ranges.get(PATH_REFERENCE)} differs from CLAUDE.md {ranges.get(PATH_CLAUDE)}"))
    rec = ctx.rec(PATH_CLAUDE)
    m = STATUS_RE.search(rec.text)
    if not m or m["date"] != date.isoformat():
        f.append(Finding(rec.rel, rec.line_of(m.start()) if m else 1, "claude-status", f"no '## Status ({date})'"))
    else:
        nxt = re.search(r"^## ", rec.text[m.end():], re.M)
        para = rec.text[m.end():m.end() + nxt.start() if nxt else len(rec.text)]
        if not re.search(r"prepared for the\s+" + re.escape(t.text) + r"\s+release", para):
            f.append(Finding(rec.rel, rec.line_of(m.start()), "claude-status",
                             f"the Status paragraph does not say 'prepared for the {t} release'"))
    # RELEASE.md
    rec = ctx.rec(PATH_RELEASE)
    m = CURRENT_RE.search(rec.text)
    if not m or m[0] != current_heading(ctx):
        f.append(Finding(rec.rel, rec.line_of(m.start()) if m else 1, "release-current", f"expected '{current_heading(ctx)}'"))
    elif gating_slugs(rec.text) is None:
        f.append(Finding(rec.rel, rec.line_of(m.start()), "release-current", "no 'Gating person steps:' list"))
    # notes
    notes = ctx.rec(ctx.notes_rel)
    f += check_notes(notes.text if notes.exists else None, notes.rel, t.text, build, date, ctx.issues)
    if notes.exists and notes.bom:
        f.append(Finding(notes.rel, 1, "notes-encoding", "the file starts with a BOM"))
    return f


# ---------------------------------------------------------------------------
# Commands


def context_for(args) -> Context:
    target = Version.parse(args.version)
    if target is None:
        raise UsageError(f"version-form: '{args.version}' is not MAJOR.MINORA.MINORB without leading zeros "
                         "(for example 0.1.11)")
    return load_context(args.root, target, args.date, args.offline)


def status_dict(ctx: Context) -> dict:
    fs = sorted(ctx.features)
    return {
        "version": ctx.target.text, "tag": ctx.target.tag, "installer": ctx.target.installer,
        "date": ctx.date.isoformat(), "date_long": long_date(ctx.date),
        "previous": ctx.prev.text if ctx.prev else None, "previous_build": ctx.prev_build, "build": ctx.build,
        "branch": ctx.branch, "head": ctx.head, "clean": ctx.clean, "lock": ctx.lock,
        "tag_local": ctx.tag_local, "tag_remote": ctx.tag_remote,
        "source": ctx.source.text if ctx.source else None, "source_build": ctx.source_build,
        "interface": ctx.interface, "interface_changed": ctx.interface_changed, "state": ctx.state,
        "features": [fs[0], fs[-1], len(fs)] if fs else [], "issues": sorted(ctx.issues),
        "release_branches": ctx.release_branches, "gating": ctx.gating,
        "gating_candidates": ctx.gating_candidates, "warnings": ctx.warnings, "refusals": ctx.refusals,
        "planned_changes": ctx.plan_messages, "dropped_leads": ctx.dropped_leads,
    }


def print_status(ctx: Context) -> None:
    d = status_dict(ctx)
    p = print
    p(f"version: {d['version']}   tag: {d['tag']}   installer: {d['installer']}")
    p(f"date: {d['date']} ({d['date_long']})")
    p(f"previous: {d['previous']} (tag v{d['previous']}, build {d['previous_build']})   build: {d['build']}")
    p(f"branch: {d['branch'] or '(detached)'}   head: {d['head']}   clean: {'yes' if d['clean'] else 'no'}   "
      f"lock: {d['lock']}")
    p(f"tag-local: {'yes' if d['tag_local'] else 'no'}   tag-remote: {d['tag_remote']}")
    iface = f"{d['interface']} ({'changed' if d['interface_changed'] else 'unchanged'} since v{d['previous']})"
    p(f"source: {d['source']} build {d['source_build']}   interface: {iface}")
    p(f"state: {d['state']}")
    feats = f"{d['features'][0]:03d}-{d['features'][1]:03d} ({d['features'][2]})" if d["features"] else "none"
    p(f"features: {feats}   issues: {' '.join('#' + str(n) for n in d['issues']) or 'none'}")
    for b in d["release_branches"]:
        p(f"release-branch: {b}")
    for g in d["gating"]:
        p(f"gating: {g['status']} {g['slug']} {EM} {g['title']}")
    for g in d["gating_candidates"]:
        p(f"gating-candidate: {g['slug']} {EM} {g['title']}")
    for m in d["planned_changes"]:
        p(f"planned: {m}")
    for w in d["warnings"]:
        p(f"warning: {w}")
    for r in d["refusals"]:
        p(f"refused: {r}")


def cmd_status(args) -> int:
    ctx = context_for(args)
    evaluate(ctx)
    if args.json:
        print(json.dumps(status_dict(ctx), ensure_ascii=False, indent=2))
    else:
        print_status(ctx)
    return 1 if ctx.refusals else 0


def cmd_stamp(args) -> int:
    ctx = context_for(args)
    evaluate(ctx)
    for w in ctx.warnings:
        print(f"warning: {w}")
    if ctx.refusals:
        for r in ctx.refusals:
            print(f"refused: {r}")
        return 1
    for m in ctx.plan_messages:
        print(m)
    for d in ctx.dropped_leads:
        print(f"dropped-lead: {d}")
    changed = [r for r in ctx.records.values() if r.changed]
    if not changed:
        print("unchanged")
        return 0
    if args.dry_run:
        print(f"would change: {len(changed)} file(s) (dry run, nothing written)")
        return 0
    for r in changed:
        r.save()
    print(f"changed: {len(changed)} file(s)")
    return 0


def cmd_check(args) -> int:
    ctx = context_for(args)
    if ctx.prev is None or ctx.build is None:
        print(f"refused: no-previous-tag: no release tag below {ctx.target.tag}")
        return 1
    findings = run_check(ctx)
    for x in findings:
        print(x)
    print(f"findings: {len(findings)}")
    return 1 if findings else 0


def cmd_summary(args) -> int:
    ctx = context_for(args)
    w = winget_summary(ctx.rec(PATH_CHANGELOG).text, ctx.target.text)
    if not w["found_heading"]:
        print(f"no heading '## [{ctx.target}] ... YYYY-MM-DD' - publish.ps1 would use today's date and a generic summary")
        return 1
    if not w["text"]:
        print("no lead paragraph - publish.ps1 would use a generic summary")
        return 1
    print(f"length: {w['length']}{' (cut to ' + str(SUMMARY_MAX_CHARS) + ')' if w['cut'] else ''}")
    print(f"summary: {w['text']}")
    print("yaml:")
    for ln in w["lines"]:
        print(ln)
    for d in w["dropped"]:
        print(f"dropped-line: {d}")
    findings = [x for x in run_check(ctx) if x.rule in ("changelog-lead", "winget-summary")] \
        if ctx.prev and ctx.build else []
    for x in findings:
        print(x)
    return 1 if (w["cut"] or w["dropped"] or findings) else 0


def parse_date(text: str) -> dt.date:
    if not DATE_RE.fullmatch(text):
        raise argparse.ArgumentTypeError(f"'{text}' is not YYYY-MM-DD")
    try:
        return dt.date.fromisoformat(text)
    except ValueError:
        raise argparse.ArgumentTypeError(f"'{text}' is not a valid date") from None


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="release.py", description="Release preparation of Tandem Commander (feature 243).")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("version", help="the version to release, MAJOR.MINORA.MINORB")
    common.add_argument("--date", type=parse_date, default=dt.date.today(), help="release date YYYY-MM-DD (default today)")
    common.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2], help="repository root")
    common.add_argument("--offline", action="store_true", help="do not ask the remote for its tags")
    sub = ap.add_subparsers(dest="command", required=True)
    s = sub.add_parser("status", parents=[common], help="release context, state, refusals, warnings")
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_status)
    s = sub.add_parser("stamp", parents=[common], help="the mechanical edits of all release records")
    s.add_argument("--dry-run", action="store_true")
    s.set_defaults(func=cmd_stamp)
    s = sub.add_parser("check", parents=[common], help="consistency of all release records")
    s.set_defaults(func=cmd_check)
    s = sub.add_parser("summary", parents=[common], help="the winget release summary as publish.ps1 makes it")
    s.set_defaults(func=cmd_summary)
    return ap


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except UsageError as e:
        print(f"refused: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
