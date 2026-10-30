#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Backlog of Tandem Commander - check and change it (feature 242).

The backlog lives in ``backlog/`` at the repository root:

  backlog/BACKLOG.md          overview: sections, order (= priority), legend
  backlog/RUNS.md             journal of /tandem-backlog-implement runs
  backlog/RELEASE.md          release procedure (free text)
  backlog/items/<slug>/       one folder per item: desc.md [issue.md reply.md evidence/]

Formats are binding and described in
specs/242-backlog-system/contracts/item-format.md and overview-format.md;
the commands in contracts/cli.md.

Design rules
------------
* ``desc.md`` is the only source of an item's data.  In ``BACKLOG.md`` people
  own only the position and the section of a row; every other cell is derived
  from the items and rewritten by every changing command (``sync``).
* The allowed values of the header fields are read from the legend of
  ``BACKLOG.md`` - adding an area is one table row there, no code change.
* Every changing command validates first, writes atomically, rewrites the
  overview and runs the full check; exit 1 when the check has findings.

Run it as ``bin/backlog.sh <command>`` (feature 342).

Standard library only: the build already requires Python, nothing else.
Exit codes: 0 success / no findings, 1 findings or refused, 2 usage error.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import http.client
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants (the vocabularies themselves live in the legend of BACKLOG.md)

HEADER_KEYS = [
    "title", "type", "status", "severity", "area", "source", "who", "created",
    "updated", "verified", "effort", "feature", "related", "depends-on", "reason",
]
LIST_KEYS = {"related", "depends-on"}

SEC_PROGRESS = "In progress"
SEC_NEXT = "Next"
SEC_DECISIONS = "Decisions for the maintainer"
SEC_PERSON = "Person steps"
SEC_INBOX = "Inbox"
SEC_PARKED = "Parked"
SEC_REJECTED = "Rejected"
SECTIONS = [SEC_PROGRESS, SEC_NEXT, SEC_DECISIONS, SEC_PERSON, SEC_INBOX, SEC_PARKED, SEC_REJECTED]
ORDERED = {SEC_PROGRESS, SEC_NEXT, SEC_DECISIONS, SEC_PERSON}
SECTION_ALIASES = {
    "progress": SEC_PROGRESS, "in-progress": SEC_PROGRESS, "inprogress": SEC_PROGRESS,
    "next": SEC_NEXT,
    "decisions": SEC_DECISIONS, "decision": SEC_DECISIONS,
    "person": SEC_PERSON, "person-steps": SEC_PERSON, "persons": SEC_PERSON,
    "inbox": SEC_INBOX,
    "parked": SEC_PARKED,
    "rejected": SEC_REJECTED,
}
COLUMNS = {
    SEC_PROGRESS: ["#", "Item", "Type", "Sev", "Area", "Feature"],
    SEC_NEXT: ["#", "Item", "Type", "Sev", "Area", "Who", "Effort", "Status"],
    SEC_DECISIONS: ["#", "Item", "Sev", "Area", "Status"],
    SEC_PERSON: ["#", "Item", "Area", "Status"],
    SEC_INBOX: ["Item", "Type", "Sev", "Area", "Source", "Created"],
    SEC_PARKED: ["Item", "Area", "Reason"],
    SEC_REJECTED: ["Item", "Area", "Reason"],
}
LEGEND_TABLES = ["Types", "Statuses", "Severity", "Areas", "Sources", "Who", "Effort"]

KNOWN_HEADINGS = [
    "Problem", "Evidence", "Expected", "Approach", "Notes",
    "Question", "Options", "Recommendation", "Steps", "Log",
]
REQUIRED_HEADINGS = ["Problem", "Evidence", "Expected", "Log"]
TYPE_HEADINGS = {
    "decision": ["Question", "Options", "Recommendation"],
    "person-step": ["Steps"],
}

KNOWN_STATUSES = {"new", "open", "blocked", "in-progress", "parked", "rejected"}

RUN_OUTCOMES = ["closed", "blocked", "not-reproduced", "split", "nothing-to-do"]
RUNS_COLUMNS = ["Date", "Item", "Outcome", "Feature", "Branch", "Inbox", "Person steps", "Note"]

TOP_LEVEL = {"BACKLOG.md", "RUNS.md", "RELEASE.md", "items"}
ITEM_FILES = {"desc.md", "issue.md", "reply.md"}
ITEM_DIRS = {"evidence"}

SLUG_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SLUG_MAX = 60
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
VERIFIED_RE = re.compile(r"^(\d{4}-\d{2}-\d{2}) ([0-9a-f]{7,40})$")
FEATURE_RE = re.compile(r"^\d{3}$")
LOG_RE = re.compile(r"^- (\d{4}-\d{2}-\d{2}) \u2014 \S.*$")
REPLY_STATE_RE = re.compile(r"^state: (not-sent|sent \d{4}-\d{2}-\d{2})$")
# the row's own link: an unescaped "](" before the target; the LAST match wins,
# so a title quoting "(items/x/desc.md)" cannot take over the row
ITEM_LINK_RE = re.compile(r"(?:^|[^\\])(?:\\\\)*\]\(items/([^/()]+)/desc\.md\)")
CONTROL_RE = re.compile(r"[\x00-\x1f\x7f]")
LAST_TRIAGED_RE = re.compile(r"^Last triaged: (\d{4}-\d{2}-\d{2})\s*$")

STALE_HOURS = 24
LOCK_NAME = "tandem-backlog-run.lock"
GITHUB_REPO = "tandemcommander/tandemcommander"
# labels that say an issue needs no work; 'import-github --label' skips such issues
GITHUB_SKIP_LABELS = ("fixed", "duplicate", "invalid", "wontfix")
# what reading GitHub can raise: a refusal or a 'failed' line, never a traceback
NET_ERRORS = (urllib.error.URLError, http.client.HTTPException, OSError, ValueError)
EMDASH = "\u2014"


class Refused(Exception):
    """An operation the tool will not do; the message says why."""


# ---------------------------------------------------------------------------
# Time (injectable for tests through TANDEM_BACKLOG_NOW=YYYY-MM-DDTHH:MM:SS)


def now() -> dt.datetime:
    fixed = os.environ.get("TANDEM_BACKLOG_NOW")
    if fixed:
        return dt.datetime.fromisoformat(fixed)
    return dt.datetime.now()


def today() -> str:
    return now().date().isoformat()


def valid_date(text: str) -> bool:
    if not DATE_RE.match(text):
        return False
    try:
        dt.date.fromisoformat(text)
    except ValueError:
        return False
    return True


# ---------------------------------------------------------------------------
# Files


def read_text(path: Path) -> str:
    with open(path, "r", encoding="utf-8", newline="") as f:
        text = f.read()
    return text.replace("\r\n", "\n")


def decode(data: bytes) -> str:
    """The text of a file's bytes as read_text gives it (raises UnicodeDecodeError)."""
    return data.decode("utf-8").replace("\r\n", "\n")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


# Every file the running command wrote or deleted, in order (feature 344: the
# 'written' list of a --json result, which lets a caller snapshot and undo).
_WRITTEN: list = []


def record(path: Path) -> None:
    if path not in _WRITTEN:
        _WRITTEN.append(path)


def write_text(path: Path, text: str) -> None:
    """Atomic write: a uniquely named temporary file in the same folder, then replace."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".", suffix=".tmp~")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    record(path)


# ---------------------------------------------------------------------------
# Sources: where the read commands take backlog/ from (feature 344)


class TreeSource:
    """The working tree."""

    ref = None

    def is_dir(self, path: Path) -> bool:
        return path.is_dir()

    def is_file(self, path: Path) -> bool:
        return path.is_file()

    def children(self, path: Path) -> list:
        return sorted(path.iterdir())

    def read_bytes(self, path: Path) -> bytes:
        with open(path, "rb") as f:
            return f.read()


TREE = TreeSource()


class GitSource:
    """backlog/ and the folder names of specs/ at a git REF, read from the
    objects (git ls-tree, git cat-file --batch): no file of the working tree
    is opened, so a run's branch state or a half-written file never shows."""

    def __init__(self, root: Path, ref: str):
        self.root = root
        self.ref = ref
        if ref.startswith("-"):
            raise Refused(f"'{ref}' is not a ref")
        commit = self._git("rev-parse", "--verify", "--quiet", ref + "^{commit}", what=f"unknown ref '{ref}'")
        commit = commit.decode("ascii").strip()
        self.files: dict = {}  # posix path relative to root -> object id
        self.dirs: set = set()
        for entry in self._git("ls-tree", "-r", "-z", commit, "--", "backlog").split(b"\0"):
            if not entry:
                continue
            meta, path = entry.split(b"\t", 1)
            if meta.split(b" ")[1] != b"blob":
                continue
            name = path.decode("utf-8")
            self.files[name] = meta.split(b" ")[2].decode("ascii")
            parts = name.split("/")
            for k in range(1, len(parts)):
                self.dirs.add("/".join(parts[:k]))
        for entry in self._git("ls-tree", "-z", commit, "--", "specs/").split(b"\0"):
            if entry and entry.split(b"\t", 1)[0].split(b" ")[1] == b"tree":
                self.dirs.add("specs")
                self.dirs.add(entry.split(b"\t", 1)[1].decode("utf-8"))
        self.blobs = self._cat(list(dict.fromkeys(self.files.values())))

    def _git(self, *args, what: str = "", data: bytes | None = None) -> bytes:
        try:
            res = subprocess.run(["git", "-C", str(self.root), *args], input=data, capture_output=True)
        except OSError as e:
            raise Refused(f"cannot run git: {e}")
        if res.returncode != 0:
            raise Refused(what or f"git {' '.join(args)} failed: {res.stderr.decode('utf-8', 'replace').strip()}")
        return res.stdout

    def _cat(self, oids: list) -> dict:
        if not oids:
            return {}
        out = self._git("cat-file", "--batch", data=("\n".join(oids) + "\n").encode("ascii"))
        blobs, pos = {}, 0
        for oid in oids:
            nl = out.index(b"\n", pos)
            size = int(out[pos:nl].split(b" ")[2])
            blobs[oid] = out[nl + 1:nl + 1 + size]
            pos = nl + 1 + size + 1
        return blobs

    def _rel(self, path: Path) -> str | None:
        try:
            return path.relative_to(self.root).as_posix()
        except ValueError:
            return None

    def is_dir(self, path: Path) -> bool:
        return self._rel(path) in self.dirs

    def is_file(self, path: Path) -> bool:
        return self._rel(path) in self.files

    def children(self, path: Path) -> list:
        prefix = self._rel(path) + "/"
        names = {p[len(prefix):].split("/")[0] for p in list(self.files) + list(self.dirs) if p.startswith(prefix)}
        return sorted(path / n for n in names)

    def read_bytes(self, path: Path) -> bytes:
        name = self._rel(path)
        if name not in self.files:
            raise FileNotFoundError(f"{name} is not in {self.ref}")
        return self.blobs[self.files[name]]


def one_line(text: str, what: str) -> str:
    """A header value or reason: one line, no control characters."""
    if CONTROL_RE.search(text or ""):
        raise Refused(f"{what} must be one line without control characters")
    return (text or "").strip()


def flatten(text: str) -> str:
    """Log lines and journal cells: whitespace runs (also line breaks) -> one space."""
    return re.sub(r"\s+", " ", text or "").strip()


def first_line(path: Path, src=None) -> str:
    """First line of a text file; a marker the format rules never accept if unreadable."""
    try:
        return decode((src or TREE).read_bytes(path)).split("\n", 1)[0].strip()
    except UnicodeDecodeError:
        return "<not valid UTF-8>"


def row_slug(line: str) -> str | None:
    found = ITEM_LINK_RE.findall(line)
    return found[-1] if found else None


def rel(root: Path, path: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


# ---------------------------------------------------------------------------
# Slugs


def derive_slug(title: str) -> str:
    text = unicodedata.normalize("NFKD", title)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    if len(text) > SLUG_MAX:
        cut = text[: SLUG_MAX + 1]
        pos = cut.rfind("-")
        text = cut[:pos] if pos > 0 else text[:SLUG_MAX]
        text = text.strip("-")
    return text


def valid_slug(slug: str) -> bool:
    return bool(SLUG_RE.match(slug)) and len(slug) <= SLUG_MAX


# ---------------------------------------------------------------------------
# Markdown table cells


def esc_cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")


def esc_link_text(text: str) -> str:
    return esc_cell(text.replace("\\", "\\\\")).replace("[", "\\[").replace("]", "\\]")


def split_row(line: str) -> list[str]:
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|") and not s.endswith("\\|"):
        s = s[:-1]
    cells, cur, i = [], [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s) and s[i + 1] == "|":
            cur.append("\\|")
            i += 2
            continue
        if c == "|":
            cells.append("".join(cur).strip())
            cur = []
        else:
            cur.append(c)
        i += 1
    cells.append("".join(cur).strip())
    return cells


def join_row(cells: list[str]) -> str:
    return "| " + " | ".join(cells) + " |"


def separator(n: int) -> str:
    return "|" + "|".join(["---"] * n) + "|"


def is_separator(line: str) -> bool:
    return bool(re.match(r"^\|(\s*:?-{3,}:?\s*\|)+\s*$", line.strip()))


def unbacktick(text: str) -> str:
    text = text.strip()
    if len(text) >= 2 and text.startswith("`") and text.endswith("`"):
        return text[1:-1].strip()
    return text


# ---------------------------------------------------------------------------
# Item


@dataclass
class Item:
    slug: str
    folder: Path
    header: dict = field(default_factory=dict)
    header_lines: dict = field(default_factory=dict)  # key -> 1-based line number
    body: list = field(default_factory=list)  # lines after the closing '---'
    body_start: int = 0  # 1-based line number of body[0]
    errors: list = field(default_factory=list)  # (line, rule, message)
    ok: bool = False  # header parsed completely
    revision: str = ""  # SHA-256 of desc.md as read

    @property
    def path(self) -> Path:
        return self.folder / "desc.md"

    def get(self, key: str, default=""):
        return self.header.get(key, default)

    def list_of(self, key: str) -> list:
        value = self.header.get(key, [])
        return value if isinstance(value, list) else []


def parse_list(value: str):
    v = value.strip()
    if not (v.startswith("[") and v.endswith("]")):
        return None
    inner = v[1:-1].strip()
    if not inner:
        return []
    return [p.strip() for p in inner.split(",")]


def format_header_value(key: str, value) -> str:
    if key in LIST_KEYS:
        return "[" + ", ".join(value) + "]"
    return str(value)


def parse_item(folder: Path, src=None, data: bytes | None = None) -> Item:
    """The item of folder, read from src (default: the working tree), or from
    data (the bytes of a desc.md not written yet)."""
    item = Item(slug=folder.name, folder=folder)
    path = item.path
    try:
        if data is None:
            data = (src or TREE).read_bytes(path)
        item.revision = sha256(data)
        raw = decode(data)
    except UnicodeDecodeError as e:
        item.errors.append((1, "header", f"not valid UTF-8 (byte {e.start}); save the file as UTF-8 without BOM"))
        return item
    if raw.startswith("\ufeff"):
        item.errors.append((1, "header", "file starts with a BOM (UTF-8 without BOM required)"))
        raw = raw[1:]
    lines = raw.split("\n")
    if not lines or lines[0] != "---":
        item.errors.append((1, "header", "metadata header missing: first line must be '---'"))
        item.body = lines
        item.body_start = 1
        return item
    try:
        end = lines.index("---", 1)
    except ValueError:
        item.errors.append((1, "header", "metadata header not closed by '---'"))
        return item
    keys_seen = []
    for idx in range(1, end):
        line = lines[idx]
        lineno = idx + 1
        m = re.match(r"^([a-z-]+): (.*)$", line)
        if not m:
            item.errors.append((lineno, "header", f"malformed header line: {line!r}"))
            continue
        key, value = m.group(1), m.group(2).strip()
        if key not in HEADER_KEYS:
            item.errors.append((lineno, "header", f"unknown key '{key}'"))
            continue
        if key in item.header:
            item.errors.append((lineno, "header", f"duplicate key '{key}'"))
            continue
        if value == "":
            item.errors.append((lineno, "header", f"empty value of '{key}' (use '-')"))
        if key in LIST_KEYS:
            parsed = parse_list(value)
            if parsed is None:
                item.errors.append((lineno, "header", f"'{key}' must be a list like [a, b] or []"))
                parsed = []
            item.header[key] = parsed
        else:
            item.header[key] = value
        item.header_lines[key] = lineno
        keys_seen.append(key)
    missing = [k for k in HEADER_KEYS if k not in item.header]
    if missing:
        item.errors.append((1, "header", "missing keys: " + ", ".join(missing)))
    present_order = [k for k in keys_seen if k in HEADER_KEYS]
    expected_order = [k for k in HEADER_KEYS if k in present_order]
    if present_order != expected_order:
        item.errors.append((1, "header", "keys out of order; expected: " + ", ".join(HEADER_KEYS)))
    item.body = lines[end + 1:]
    item.body_start = end + 2
    item.ok = not missing and all(r != "header" for _, r, _ in item.errors)
    return item


def render_item(item: Item) -> str:
    out = ["---"]
    for key in HEADER_KEYS:
        out.append(f"{key}: {format_header_value(key, item.header[key])}")
    out.append("---")
    body = list(item.body)
    while body and body[-1] == "":
        body.pop()
    return "\n".join(out + body) + "\n"


def headings(item: Item) -> list:
    """(name, index-in-body) of level-2 headings outside fenced code blocks."""
    result, fence = [], None
    for i, line in enumerate(item.body):
        s = line.lstrip()
        if fence:
            if s.startswith(fence):
                fence = None
            continue
        if s.startswith("```") or s.startswith("~~~"):
            fence = s[:3]
            continue
        if line.startswith("## "):
            result.append((line[3:].strip(), i))
    return result


def set_title_line(item: Item, title: str) -> None:
    for i, line in enumerate(item.body):
        if line.strip() == "":
            continue
        if line.startswith("# "):
            item.body[i] = "# " + title
        return


def append_log(item: Item, text: str) -> None:
    entry = f"- {today()} {EMDASH} {flatten(text)}"
    hs = headings(item)
    log_idx = next((i for name, i in hs if name == "Log"), None)
    if log_idx is None:
        while item.body and item.body[-1] == "":
            item.body.pop()
        item.body += ["", "## Log", "", entry]
        return
    nxt = next((i for name, i in hs if i > log_idx), len(item.body))
    last = log_idx
    for i in range(log_idx + 1, nxt):
        if item.body[i].strip():
            last = i
    if last == log_idx:
        item.body[log_idx + 1:log_idx + 1] = ["", entry]
    else:
        item.body.insert(last + 1, entry)


def touch(item: Item, log_text: str | None) -> None:
    item.header["updated"] = today()
    if log_text:
        append_log(item, log_text)


# ---------------------------------------------------------------------------
# Overview (BACKLOG.md)


@dataclass
class Row:
    slug: str | None
    cells: list
    lineno: int


@dataclass
class Section:
    name: str
    heading_line: int  # 0-based index in lines
    table_start: int = -1  # 0-based, inclusive
    table_end: int = -1  # 0-based, exclusive
    tables: int = 0
    rows: list = field(default_factory=list)
    header_cells: list = field(default_factory=list)


@dataclass
class Overview:
    path: Path
    lines: list
    sections: dict = field(default_factory=dict)
    legend: dict = field(default_factory=dict)  # table name -> list of first-column values
    errors: list = field(default_factory=list)  # (lineno, rule, message)
    last_triaged_line: int = -1
    revision: str = ""  # SHA-256 of BACKLOG.md as read
    legend_rows: dict = field(default_factory=dict)  # table name -> list of row cells

    def section_of(self, slug: str):
        for name in SECTIONS:
            sec = self.sections.get(name)
            if sec:
                for pos, row in enumerate(sec.rows):
                    if row.slug == slug:
                        return name, pos
        return None, None

    def vocab(self, table: str) -> list:
        return self.legend.get(table, [])


def table_blocks(lines: list, start: int, end: int) -> list:
    blocks, i = [], start
    while i < end:
        if lines[i].lstrip().startswith("|"):
            j = i
            while j < end and lines[j].lstrip().startswith("|"):
                j += 1
            blocks.append((i, j))
            i = j
        else:
            i += 1
    return blocks


def parse_overview(path: Path, src=None) -> Overview:
    data = (src or TREE).read_bytes(path)
    try:
        raw = decode(data)
    except UnicodeDecodeError as e:
        ov = Overview(path=path, lines=[], revision=sha256(data))
        ov.errors.append((1, "overview", f"not valid UTF-8 (byte {e.start}); save the file as UTF-8 without BOM"))
        return ov
    ov = Overview(path=path, lines=raw.split("\n"), revision=sha256(data))
    if raw.startswith("\ufeff"):
        ov.errors.append((1, "overview", "file starts with a BOM"))
        ov.lines[0] = ov.lines[0][1:]
    lines = ov.lines
    h2 = [(i, ln[3:].strip()) for i, ln in enumerate(lines) if ln.startswith("## ")]
    names = [n for _, n in h2]
    expected = SECTIONS + ["Legend"]
    if names != expected:
        missing = [n for n in expected if n not in names]
        extra = [n for n in names if n not in expected]
        msg = "section headings must be exactly, in order: " + ", ".join(expected)
        if missing:
            msg += "; missing: " + ", ".join(missing)
        if extra:
            msg += "; unexpected: " + ", ".join(extra)
        ov.errors.append((1, "overview", msg))
    for i, ln in enumerate(lines):
        if ln.startswith("Last triaged:"):
            ov.last_triaged_line = i
            m = LAST_TRIAGED_RE.match(ln)
            if not m or not valid_date(m.group(1)):
                ov.errors.append((i + 1, "overview", "malformed 'Last triaged: YYYY-MM-DD' line"))
            break
    else:
        ov.errors.append((1, "overview", "'Last triaged: YYYY-MM-DD' line missing"))
    bounds = [i for i, _ in h2] + [len(lines)]
    for k, (i, name) in enumerate(h2):
        end = bounds[k + 1]
        if name == "Legend":
            parse_legend(ov, i + 1, end)
            continue
        if name not in SECTIONS:
            continue
        sec = Section(name=name, heading_line=i)
        blocks = table_blocks(lines, i + 1, end)
        sec.tables = len(blocks)
        if len(blocks) != 1:
            ov.errors.append((i + 1, "overview", f"section '{name}' must contain exactly one table (found {len(blocks)})"))
        if blocks:
            a, b = blocks[0]
            sec.table_start, sec.table_end = a, b
            sec.header_cells = split_row(lines[a])
            if sec.header_cells != COLUMNS[name]:
                ov.errors.append((a + 1, "overview", f"section '{name}': columns must be " + " | ".join(COLUMNS[name])))
            if b - a < 2 or not is_separator(lines[a + 1]):
                ov.errors.append((a + 1, "overview", f"section '{name}': table separator line missing"))
                data_from = a + 1
            else:
                data_from = a + 2
            for r in range(data_from, b):
                cells = split_row(lines[r])
                slug = row_slug(lines[r])
                if slug is None:
                    ov.errors.append((r + 1, "overview", "row without an item link '[title](items/<slug>/desc.md)' (kept as it is; 'sync' refuses until it is fixed)"))
                elif len(cells) != len(COLUMNS[name]):
                    ov.errors.append((r + 1, "overview", f"row has {len(cells)} cells, section '{name}' has {len(COLUMNS[name])} columns"))
                sec.rows.append(Row(slug=slug, cells=cells, lineno=r + 1))
        ov.sections[name] = sec
    return ov


def parse_legend(ov: Overview, start: int, end: int) -> None:
    lines = ov.lines
    h3 = [(i, lines[i][4:].strip()) for i in range(start, end) if lines[i].startswith("### ")]
    bounds = [i for i, _ in h3] + [end]
    for k, (i, name) in enumerate(h3):
        blocks = table_blocks(lines, i + 1, bounds[k + 1])
        values, rows = [], []
        if blocks:
            a, b = blocks[0]
            first = a + 2 if b - a >= 2 and is_separator(lines[a + 1]) else a + 1
            for r in range(first, b):
                cells = split_row(lines[r])
                if cells and cells[0]:
                    values.append(unbacktick(cells[0]))
                    rows.append(cells)
        ov.legend[name] = values
        ov.legend_rows[name] = rows
    for name in LEGEND_TABLES:
        if not ov.legend.get(name):
            ov.errors.append((start + 1, "overview", f"legend table '{name}' missing or empty"))


def item_cells(section: str, item: Item, position: int) -> list:
    h = item.header
    link = f"[{esc_link_text(h.get('title', item.slug))}](items/{item.slug}/desc.md)"
    values = {
        "#": str(position),
        "Item": link,
        "Type": h.get("type", ""),
        "Sev": str(h.get("severity", "")),
        "Area": h.get("area", ""),
        "Who": h.get("who", ""),
        "Effort": h.get("effort", ""),
        "Status": h.get("status", ""),
        "Feature": h.get("feature", ""),
        "Source": h.get("source", ""),
        "Created": h.get("created", ""),
        "Reason": esc_cell(h.get("reason", "")),
    }
    return [esc_cell(values[c]) if c not in ("Item", "Reason") else values[c] for c in COLUMNS[section]]


def sort_key(section: str, items: dict):
    def key(row):
        it = items.get(row.slug)
        h = it.header if it and it.ok else {}
        if section == SEC_INBOX:
            return (h.get("created", ""), row.slug)
        return (h.get("area", ""), row.slug)
    return key


def render_table(ov: Overview, section: str, items: dict) -> list:
    """The section's table as sync writes it.  Ordered sections keep every row
    in place; unordered ones are sorted.  A row without an item link (a
    hand-written note) and a row whose item cannot be read are kept verbatim
    - never dropped (the check reports them)."""
    out = [join_row(COLUMNS[section]), separator(len(COLUMNS[section]))]
    rows = ov.sections[section].rows
    if section not in ORDERED:
        rows = sorted((r for r in rows if r.slug), key=sort_key(section, items)) + [r for r in rows if not r.slug]
    pos = 0
    for r in rows:
        if not r.slug:
            out.append(ov.lines[r.lineno - 1])
            continue
        pos += 1
        if r.slug in items and items[r.slug].ok:
            out.append(join_row(item_cells(section, items[r.slug], pos)))
        elif r.lineno > 0:
            out.append(ov.lines[r.lineno - 1])
        else:
            cells = ([str(pos)] if section in ORDERED else []) + [f"[{r.slug}](items/{r.slug}/desc.md)"]
            out.append(join_row(cells))
    return out


def render_overview(ov: Overview, items: dict) -> list:
    lines = list(ov.lines)
    for name in reversed(SECTIONS):  # bottom-up keeps earlier indexes valid
        sec = ov.sections.get(name)
        if not sec or sec.tables != 1:
            continue
        lines[sec.table_start:sec.table_end] = render_table(ov, name, items)
    return lines


def overview_structurally_ok(ov: Overview) -> bool:
    return all(name in ov.sections and ov.sections[name].tables == 1 for name in SECTIONS)


# ---------------------------------------------------------------------------
# Backlog (items + overview)


class Backlog:
    def __init__(self, root: Path, src=None):
        self.root = root
        self.src = src or TREE  # where it is read from: the working tree or a GitSource (read commands)
        self.dir = root / "backlog"
        self.items_dir = self.dir / "items"
        self.overview_path = self.dir / "BACKLOG.md"
        self.runs_path = self.dir / "RUNS.md"
        self.release_path = self.dir / "RELEASE.md"
        self.items: dict = {}
        self.ov: Overview | None = None
        self.load()

    def load(self) -> None:
        src = self.src
        self.items = {}
        if src.is_dir(self.items_dir):
            for folder in [p for p in src.children(self.items_dir) if src.is_dir(p)]:
                if src.is_file(folder / "desc.md"):
                    self.items[folder.name] = parse_item(folder, src)
        self.ov = parse_overview(self.overview_path, src) if src.is_file(self.overview_path) else None

    def require_overview(self) -> Overview:
        if self.ov is None:
            raise Refused(f"{rel(self.root, self.overview_path)} does not exist")
        if not overview_structurally_ok(self.ov):
            raise Refused("BACKLOG.md sections are malformed; run 'check' and fix them first")
        return self.ov

    def item(self, slug: str) -> Item:
        it = self.items.get(slug)
        if it is None:
            raise Refused(f"no item '{slug}'")
        if not it.ok:
            raise Refused(f"item '{slug}' has a malformed header; run 'check'")
        return it

    # -- writing -----------------------------------------------------------

    # A changing command writes its item(s) first, changes the rows of the
    # overview in memory, and writes BACKLOG.md exactly once at the end
    # (save_overview), so an interruption never leaves an item without a row.

    def save_item(self, item: Item) -> None:
        write_text(item.path, render_item(item))
        self.items[item.slug] = parse_item(item.folder)

    def save_overview(self) -> None:
        ov = self.require_overview()
        write_text(self.overview_path, "\n".join(render_overview(ov, self.items)).rstrip("\n") + "\n")
        self.load()

    def place_row(self, slug: str, section: str, position: int | None = None) -> None:
        """Put the item's row into section (in memory); removes it elsewhere."""
        ov = self.require_overview()
        self.unplace_row(slug)
        rows = ov.sections[section].rows
        row = Row(slug=slug, cells=[], lineno=0)
        if section in ORDERED and position is not None:
            # position counts item rows only (hand-written rows keep their place)
            item_rows = [i for i, r in enumerate(rows) if r.slug]
            if position <= len(item_rows):
                rows.insert(item_rows[max(position, 1) - 1], row)
                return
        rows.append(row)

    def unplace_row(self, slug: str) -> None:
        ov = self.require_overview()
        for name in SECTIONS:
            ov.sections[name].rows = [r for r in ov.sections[name].rows if r.slug != slug]

    def touch_triaged(self) -> None:
        ov = self.require_overview()
        if ov.last_triaged_line >= 0:
            ov.lines[ov.last_triaged_line] = f"Last triaged: {today()}"


# ---------------------------------------------------------------------------
# Rules


def expected_section(item: Item) -> str | None:
    h = item.header
    st = h.get("status")
    if st == "in-progress":
        return SEC_PROGRESS
    if st == "new":
        return SEC_INBOX
    if st == "parked":
        return SEC_PARKED
    if st == "rejected":
        return SEC_REJECTED
    if st in ("open", "blocked"):
        if h.get("type") == "decision":
            return SEC_DECISIONS
        if h.get("who") == "person" or h.get("type") == "person-step":
            return SEC_PERSON
        return SEC_NEXT
    return None


def source_patterns(ov: Overview | None) -> list:
    pats = []
    for form in (ov.vocab("Sources") if ov else []):
        p = re.escape(form)
        p = p.replace("NNN", r"\d{3}").replace("N", r"\d+")
        pats.append(re.compile("^" + p + "$"))
    return pats


def value_findings(item: Item, ov: Overview | None, root: Path) -> list:
    """(lineno, rule, message) for header values; no cross-item rules."""
    out = []
    h = item.header
    ln = item.header_lines

    def bad(key, msg, rule="value"):
        out.append((ln.get(key, 1), rule, msg))

    vocab = {
        "type": ov.vocab("Types") if ov else [],
        "status": ov.vocab("Statuses") if ov else [],
        "area": ov.vocab("Areas") if ov else [],
        "who": ov.vocab("Who") if ov else [],
        "effort": (ov.vocab("Effort") if ov else []) + ["-"],
    }
    title = h.get("title", "")
    if not title or title == "-":
        bad("title", "title is empty")
    for key, value in h.items():
        if key not in LIST_KEYS and CONTROL_RE.search(str(value)):
            bad(key, f"{key} contains a control character (tab, line break, …)")
    if h.get("type") == "person-step" and h.get("who") != "person":
        bad("who", "a person-step item has who: person")
    if h.get("status") in vocab["status"] and h.get("status") not in KNOWN_STATUSES:
        bad("status", f"status '{h.get('status')}' is in the legend but has no section rule in the tool")
    for key, allowed in vocab.items():
        if key in h and h[key] not in allowed:
            bad(key, f"{key} '{h[key]}' not in the legend ({', '.join(allowed) or 'legend missing'})")
    sev = h.get("severity", "")
    if not re.fullmatch(r"\d{1,2}", str(sev)) or not 0 <= int(sev) <= 10:
        bad("severity", f"severity '{sev}' must be an integer 0-10")
    src = h.get("source", "")
    if not any(p.match(src) for p in source_patterns(ov)):
        bad("source", f"source '{src}' matches no form of the legend")
    for key in ("created", "updated"):
        if key in h and not valid_date(h[key]):
            bad(key, f"{key} '{h[key]}' is not a date YYYY-MM-DD")
    if valid_date(h.get("created", "")) and valid_date(h.get("updated", "")) and h["updated"] < h["created"]:
        bad("updated", "updated is earlier than created")
    ver = h.get("verified", "")
    if ver != "-":
        m = VERIFIED_RE.match(ver)
        if not m or not valid_date(m.group(1)):
            bad("verified", f"verified '{ver}' must be '-' or 'YYYY-MM-DD <commit>'")
    feat = h.get("feature", "")
    st = h.get("status", "")
    if feat != "-" and not FEATURE_RE.match(feat):
        bad("feature", f"feature '{feat}' must be '-' or three digits")
    if st == "in-progress" and feat == "-":
        bad("feature", "status in-progress needs a feature number", "required")
    if st != "in-progress" and feat != "-":
        bad("feature", "feature is set only while in-progress", "required")
    reason = h.get("reason", "")
    if st in ("blocked", "parked", "rejected") and reason in ("", "-"):
        bad("reason", f"status {st} needs a reason", "required")
    if st not in ("blocked", "parked", "rejected") and reason not in ("", "-"):
        bad("reason", f"reason is set only for blocked, parked or rejected (status is {st})", "required")
    for key in LIST_KEYS:
        for s in item.list_of(key):
            if not valid_slug(s):
                bad(key, f"'{s}' in {key} is not a slug")
    return out


def body_findings(item: Item) -> list:
    out = []
    body = item.body
    base = item.body_start
    first = next(((i, ln) for i, ln in enumerate(body) if ln.strip()), None)
    title = item.header.get("title", "")
    if first is None or first[1] != "# " + title:
        out.append((base + (first[0] if first else 0), "body", "first line of the body must be '# <title>' with the header's title"))
    hs = headings(item)
    names = [n for n, _ in hs]
    for n, i in hs:
        if n not in KNOWN_HEADINGS:
            out.append((base + i, "body", f"unknown section '## {n}' (allowed: {', '.join(KNOWN_HEADINGS)})"))
    for n in set(names):
        if names.count(n) > 1:
            out.append((base, "body", f"section '## {n}' appears more than once"))
    required = REQUIRED_HEADINGS + TYPE_HEADINGS.get(item.header.get("type", ""), [])
    for n in required:
        if n not in names:
            out.append((base, "body", f"required section '## {n}' missing"))
    known = [n for n in names if n in KNOWN_HEADINGS]
    if known != sorted(known, key=KNOWN_HEADINGS.index):
        out.append((base, "body", "sections out of order; order: " + ", ".join(KNOWN_HEADINGS)))
    if "Log" in names:
        idx = dict((n, i) for n, i in hs)["Log"]
        nxt = next((i for n, i in hs if i > idx), len(body))
        entries, last = 0, ""
        for i in range(idx + 1, nxt):
            ln = body[i]
            if not ln.strip():
                continue
            m = LOG_RE.match(ln)
            if not m or not valid_date(m.group(1)):
                out.append((base + i, "body", f"log line must be '- YYYY-MM-DD {EMDASH} text': {ln!r}"))
                continue
            if m.group(1) < last:
                out.append((base + i, "body", "log dates must not decrease"))
            last = m.group(1)
            entries += 1
        if entries == 0:
            out.append((base + idx, "body", "the log is empty"))
    if "Steps" in names and item.header.get("type") == "person-step":
        idx = dict((n, i) for n, i in hs)["Steps"]
        nxt = next((i for n, i in hs if i > idx), len(body))
        if not any(re.match(r"^\s*- \[[ xX]\] ", body[i]) for i in range(idx + 1, nxt)):
            out.append((base + idx, "body", "'## Steps' needs at least one checklist line '- [ ] ...'"))
    return out


def find_cycles(items: dict) -> list:
    graph = {s: [d for d in it.list_of("depends-on") if d in items] for s, it in items.items() if it.ok}
    color, stack, cycles = {}, [], []

    def visit(node):
        color[node] = 1
        stack.append(node)
        for d in graph.get(node, []):
            if color.get(d) == 1:
                cycles.append(stack[stack.index(d):] + [d])
            elif color.get(d) is None:
                visit(d)
        stack.pop()
        color[node] = 2

    for n in sorted(graph):
        if color.get(n) is None:
            visit(n)
    return cycles


def check(bl: Backlog) -> list:
    """All findings as (path, line, rule, message)."""
    root = bl.root
    src = bl.src
    F = []

    def add(path, line, rule, msg):
        F.append((rel(root, path) if isinstance(path, Path) else path, line, rule, msg))

    if not src.is_dir(bl.dir):
        add(bl.dir, 1, "layout", "backlog/ folder missing")
        return F
    for entry in src.children(bl.dir):
        if entry.name not in TOP_LEVEL:
            add(entry, 1, "layout", "unexpected entry at the top level of backlog/")
    for name in ("BACKLOG.md", "RUNS.md", "RELEASE.md"):
        if not src.is_file(bl.dir / name):
            add(bl.dir / name, 1, "layout", f"{name} missing")
    if src.is_dir(bl.items_dir):  # a missing items/ is an empty backlog (git keeps no empty folder)
        for entry in src.children(bl.items_dir):
            if not src.is_dir(entry):
                add(entry, 1, "layout", "only item folders belong in backlog/items/")
                continue
            if not valid_slug(entry.name):
                add(entry, 1, "slug", f"folder name '{entry.name}' is not a slug (^[a-z0-9]+(-[a-z0-9]+)*$, max {SLUG_MAX})")
            if not src.is_file(entry / "desc.md"):
                add(entry, 1, "desc-missing", "item folder without desc.md")
            for sub in src.children(entry):
                if sub.name in ITEM_FILES and src.is_file(sub):
                    continue
                if sub.name in ITEM_DIRS and src.is_dir(sub):
                    continue
                add(sub, 1, "layout", "unexpected file in an item folder (allowed: desc.md, issue.md, reply.md, evidence/)")

    ov = bl.ov
    if ov:
        for line, rule, msg in ov.errors:
            add(bl.overview_path, line, rule, msg)

    items = bl.items
    github_seen = {}
    for slug, it in items.items():
        for line, rule, msg in it.errors:
            add(it.path, line, rule, msg)
        if not it.ok:
            continue
        for line, rule, msg in value_findings(it, ov, root):
            add(it.path, line, rule, msg)
        for line, rule, msg in body_findings(it):
            add(it.path, line, rule, msg)
        h = it.header
        if h["status"] == "in-progress" and FEATURE_RE.match(h["feature"]):
            specs = root / "specs"
            if not any(src.is_dir(p) and p.name.startswith(h["feature"] + "-") for p in (src.children(specs) if src.is_dir(specs) else [])):
                add(it.path, it.header_lines.get("feature", 1), "feature-missing", f"no folder specs/{h['feature']}-* for the in-progress feature")
        for key in ("related", "depends-on"):
            for other in it.list_of(key):
                if other == slug:
                    add(it.path, it.header_lines.get(key, 1), "ref", f"{key} names the item itself")
                elif other not in items:
                    add(it.path, it.header_lines.get(key, 1), "ref", f"{key} names '{other}', which does not exist")
                elif key == "depends-on" and items[other].ok and items[other].header.get("status") == "rejected":
                    add(it.path, it.header_lines.get(key, 1), "ref", f"depends-on '{other}', which is rejected and never done")
        m = re.match(r"^github#(\d+)$", h["source"])
        if m:
            num = m.group(1)
            if num in github_seen:
                add(it.path, it.header_lines.get("source", 1), "github", f"issue #{num} is also imported as '{github_seen[num]}'")
            else:
                github_seen[num] = slug
            issue = it.folder / "issue.md"
            if not src.is_file(issue):
                add(issue, 1, "github", "source github#N needs issue.md")
            else:
                first = first_line(issue, src)
                if first != f"number: {num}":
                    add(issue, 1, "github", f"first line must be 'number: {num}'")
        reply = it.folder / "reply.md"
        if src.is_file(reply):
            first = first_line(reply, src)
            if not REPLY_STATE_RE.match(first):
                add(reply, 1, "value", "first line must be 'state: not-sent' or 'state: sent YYYY-MM-DD'")
    for cyc in find_cycles(items):
        add(items[cyc[0]].path, items[cyc[0]].header_lines.get("depends-on", 1), "cycle", "depends-on cycle: " + " -> ".join(cyc))

    if ov and overview_structurally_ok(ov):
        seen = {}
        for name in SECTIONS:
            for row in ov.sections[name].rows:
                if not row.slug:
                    continue
                if row.slug in seen:
                    add(bl.overview_path, row.lineno, "duplicate", f"'{row.slug}' is listed more than once (also line {seen[row.slug][1]})")
                    continue
                seen[row.slug] = (name, row.lineno)
                if row.slug not in items:
                    add(bl.overview_path, row.lineno, "dangling", f"row names '{row.slug}', which has no items/{row.slug}/desc.md")
                    continue
                it = items[row.slug]
                if it.ok:
                    exp = expected_section(it)
                    if exp and exp != name:
                        add(bl.overview_path, row.lineno, "section", f"'{row.slug}' (status {it.header['status']}, type {it.header['type']}, who {it.header['who']}) belongs in '{exp}', not '{name}'")
        for slug, it in items.items():
            if slug not in seen:
                add(it.path, 1, "orphan", "item has no row in BACKLOG.md")
        # derived cells: compare with what sync would write
        for name in SECTIONS:
            sec = ov.sections[name]
            want = render_table(ov, name, items)
            have = ov.lines[sec.table_start:sec.table_end]
            for k in range(max(len(want), len(have))):
                w = want[k] if k < len(want) else None
                hv = have[k] if k < len(have) else None
                if (w or "").rstrip() != (hv or "").rstrip():
                    line = sec.table_start + k + 1
                    add(bl.overview_path, line, "derived", f"differs from 'sync' in section '{name}'; expected: {w!r}")
                    break

    if src.is_file(bl.runs_path):
        F.extend(runs_findings(bl))
    F.sort(key=lambda f: (f[0], f[1], f[2]))
    return F


def runs_findings(bl: Backlog) -> list:
    out = []
    path = rel(bl.root, bl.runs_path)
    try:
        lines = decode(bl.src.read_bytes(bl.runs_path)).split("\n")
    except UnicodeDecodeError as e:
        return [(path, 1, "runs", f"not valid UTF-8 (byte {e.start})")]
    blocks = table_blocks(lines, 0, len(lines))
    if len(blocks) != 1:
        return [(path, 1, "runs", f"RUNS.md must contain exactly one table (found {len(blocks)})")]
    a, b = blocks[0]
    if split_row(lines[a]) != RUNS_COLUMNS:
        out.append((path, a + 1, "runs", "columns must be " + " | ".join(RUNS_COLUMNS)))
    if b - a < 2 or not is_separator(lines[a + 1]):
        out.append((path, a + 1, "runs", "table separator line missing"))
        return out
    for r in range(a + 2, b):
        cells = split_row(lines[r])
        if len(cells) != len(RUNS_COLUMNS):
            out.append((path, r + 1, "runs", f"row has {len(cells)} cells, expected {len(RUNS_COLUMNS)}"))
            continue
        if cells[2] not in RUN_OUTCOMES:
            out.append((path, r + 1, "runs", f"outcome '{cells[2]}' not one of {', '.join(RUN_OUTCOMES)}"))
    return out


def print_findings(findings: list) -> None:
    for path, line, rule, msg in findings:
        print(f"{path}:{line}: {rule}: {msg}")
    print(f"TOTAL: {len(findings)}")


@dataclass
class Output:
    """What a changing command reports.  With --json (feature 344) it is
    printed as one result object at the end instead of text lines."""
    json: bool = False
    slugs: list = field(default_factory=list)
    section: str | None = None  # set by a command about a section (reorder)
    notices: list = field(default_factory=list)
    findings: list = field(default_factory=list)
    bl: Backlog | None = None


OUT = Output()


def notice(text: str) -> None:
    """A line a person should read (moved, sections added, an issue skipped)."""
    if OUT.json:
        OUT.notices.append(text)
    else:
        print(text)


def emit_slug(slug: str) -> None:
    """The slug a command created: its first output line, or 'slugs' in JSON."""
    if slug not in OUT.slugs:
        OUT.slugs.append(slug)
    if not OUT.json:
        print(slug)


def finding_json(f) -> dict:
    path, line, rule, msg = f
    return {"path": path, "line": line, "rule": rule, "message": msg}


def finish(bl: Backlog, ok_message: str | None = None) -> int:
    """Run the full check after a change; report and return the exit code."""
    bl.load()
    findings = check(bl)
    if OUT.json:
        OUT.findings = findings
        return 1 if findings else 0
    if ok_message:
        print(ok_message)
    if findings:
        print("check after the change found problems:")
        print_findings(findings)
        return 1
    return 0


# ---------------------------------------------------------------------------
# Eligibility (autonomous runs)


def eligibility(bl: Backlog, item: Item) -> str | None:
    """None if an autonomous run may take the item, else the reason."""
    h = item.header
    if h["status"] != "open":
        return f"status {h['status']}"
    if h["who"] not in ("agent", "both"):
        return f"who {h['who']}"
    if h["type"] in ("decision", "person-step"):
        return f"type {h['type']}"
    for d in item.list_of("depends-on"):
        if d in bl.items:
            return f"depends-on {d}"
    return None


def next_eligible(bl: Backlog, ov: Overview) -> tuple:
    """(the first eligible slug of Next or None, the rows skipped above it with their reasons)."""
    skipped = []
    for row in ov.sections[SEC_NEXT].rows:
        if not row.slug:
            continue
        it = bl.items.get(row.slug)
        if not it or not it.ok:
            skipped.append({"slug": row.slug, "reason": "unreadable item"})
            continue
        reason = eligibility(bl, it)
        if reason:
            skipped.append({"slug": row.slug, "reason": reason})
            continue
        return row.slug, skipped
    return None, skipped


# ---------------------------------------------------------------------------
# Git and lock


def git(root: Path, *args: str) -> str:
    res = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, encoding="utf-8")
    if res.returncode != 0:
        raise Refused(f"git {' '.join(args)} failed: {res.stderr.strip()}")
    return res.stdout.strip()


def lock_path(root: Path, lock_dir: str | None) -> Path:
    if lock_dir:
        return Path(lock_dir) / LOCK_NAME
    common = Path(git(root, "rev-parse", "--git-common-dir"))
    if not common.is_absolute():
        common = root / common
    return common / LOCK_NAME


def read_lock(path: Path) -> dict:
    fields = {}
    for line in read_text(path).split("\n"):
        if ": " in line:
            k, v = line.split(": ", 1)
            fields[k.strip()] = v.strip()
    return fields


def describe_lock(fields: dict) -> str:
    started = fields.get("started", "?")
    age_txt, stale = "?", False
    try:
        age = now() - dt.datetime.fromisoformat(started)
        hours = age.total_seconds() / 3600
        age_txt = f"{hours:.1f} h"
        stale = hours > STALE_HOURS
    except ValueError:
        pass
    text = f"held since {started} ({age_txt}) by item {fields.get('slug', '-')}, branch {fields.get('branch', '-')}, host {fields.get('host', '-')}"
    if stale:
        text += f" - STALE (older than {STALE_HOURS} h); the maintainer releases it with 'lock release --force'"
    return text


# ---------------------------------------------------------------------------
# GitHub


def fetch_json(url: str):
    """GET a GitHub API resource; the GitHub CLI is used when installed."""
    if shutil.which("gh"):
        api = url.replace("https://api.github.com/", "")
        res = subprocess.run(["gh", "api", api], capture_output=True, text=True, encoding="utf-8")
        if res.returncode == 0:
            return json.loads(res.stdout)
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "tandemcommander-backlog-tool",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_all(url: str) -> list:
    """GET every page of a GitHub list resource (100 per page)."""
    out, page = [], 1
    sep = "&" if "?" in url else "?"
    while True:
        batch = fetch_json(f"{url}{sep}per_page=100&page={page}")
        out += batch
        if len(batch) < 100:
            return out
        page += 1


def validate_item(bl: Backlog, it: Item) -> list:
    """Messages for everything a write of this item would make the check report:
    header values, references (missing, self, rejected, cycles), type sections."""
    errs = [m for _, _, m in value_findings(it, bl.ov, bl.root)]
    for key in LIST_KEYS:
        for s in it.list_of(key):
            if s == it.slug:
                errs.append(f"{key} names the item itself")
            elif s not in bl.items:
                errs.append(f"{key} names '{s}', which does not exist")
            elif key == "depends-on" and bl.items[s].ok and bl.items[s].header.get("status") == "rejected":
                errs.append(f"depends-on '{s}', which is rejected and never done")
    graph = dict(bl.items)
    graph[it.slug] = it
    for cyc in find_cycles(graph):
        if it.slug in cyc:
            errs.append("depends-on cycle: " + " -> ".join(cyc))
    return errs


def ensure_type_sections(it: Item) -> list:
    """Insert the type's required sections (with placeholders) before *Log*;
    returns the names inserted, for the caller to report."""
    names = [n for n, _ in headings(it)]
    missing = [n for n in TYPE_HEADINGS.get(it.header.get("type", ""), []) if n not in names]
    if not missing:
        return []
    log_idx = next((i for n, i in headings(it) if n == "Log"), len(it.body))
    block = []
    for n in missing:
        block += [f"## {n}", "", "- [ ] (to be written)" if n == "Steps" else "(to be written)", ""]
    it.body[log_idx:log_idx] = block
    return missing


# ---------------------------------------------------------------------------
# Item creation


def new_item_text(header: dict, problem: str, evidence: str, expected: str, extra: dict | None = None) -> str:
    """extra: texts of the further sections (Approach ... Steps) by heading name
    (--input-json); a section the type requires gets a placeholder."""
    t = header["type"]
    extra = extra or {}
    body = ["", f"# {header['title']}", "",
            "## Problem", "", problem or "(to be written)", "",
            "## Evidence", "", evidence or "(to be written)", "",
            "## Expected", "", expected or "(to be written)", ""]
    for name in ("Approach", "Notes"):
        if extra.get(name):
            body += [f"## {name}", "", extra[name], ""]
    for name in ("Question", "Options", "Recommendation"):
        if extra.get(name) or t == "decision":
            body += [f"## {name}", "", extra.get(name) or "(to be written)", ""]
    if extra.get("Steps") or t == "person-step":
        body += ["## Steps", "", extra.get("Steps") or "- [ ] (to be written)", ""]
    body += ["## Log", "", f"- {today()} {EMDASH} created (source {header['source']})"]
    head = ["---"] + [f"{k}: {format_header_value(k, header[k])}" for k in HEADER_KEYS] + ["---"]
    return "\n".join(head + body) + "\n"


def refuse_invalid_header(bl: Backlog, header: dict, slug: str) -> None:
    probe = Item(slug=slug, folder=bl.items_dir / slug, header=dict(header), ok=True)
    probe.header_lines = {k: 1 for k in HEADER_KEYS}
    errs = validate_item(bl, probe)
    if errs:
        raise Refused("invalid values: " + "; ".join(errs))


def create_item(bl: Backlog, header: dict, slug: str | None, problem="", evidence="", expected="",
                extra: dict | None = None, check_body: bool = False) -> Item:
    """check_body: refuse a body that breaks the body rules before anything is
    written (texts from --input-json, which may contain any Markdown)."""
    ov = bl.require_overview()
    slug = slug or derive_slug(header["title"])
    if not slug:
        raise Refused("the title gives no slug; pass --slug")
    if not valid_slug(slug):
        raise Refused(f"'{slug}' is not a valid slug")
    folder = bl.items_dir / slug
    if folder.exists():
        other = bl.items.get(slug)
        title = other.header.get("title", "?") if other else "?"
        raise Refused(f"item '{slug}' already exists ({title}); choose another title or pass --slug")
    refuse_invalid_header(bl, header, slug)
    text = new_item_text(header, problem, evidence, expected, extra)
    if check_body:
        errs = [m for _, _, m in body_findings(parse_item(folder, data=text.encode("utf-8")))]
        if errs:
            raise Refused("the texts break the body rules: " + "; ".join(errs))
    folder.mkdir(parents=True)
    write_text(folder / "desc.md", text)
    bl.items[slug] = parse_item(folder)
    bl.place_row(slug, SEC_INBOX)
    bl.save_overview()
    return bl.items[slug]


def base_header(args, source: str, title: str) -> dict:
    return {
        "title": one_line(title, "the title"),
        "type": args.type,
        "status": "new",
        "severity": str(args.severity),
        "area": args.area,
        "source": source,
        "who": getattr(args, "who", "agent") or "agent",
        "created": today(),
        "updated": today(),
        "verified": "-",
        "effort": getattr(args, "effort", None) or "-",
        "feature": "-",
        "related": split_csv(getattr(args, "related", None)),
        "depends-on": split_csv(getattr(args, "depends_on", None)),
        "reason": "-",
    }


def split_csv(text: str | None) -> list:
    if not text:
        return []
    return [p.strip() for p in text.split(",") if p.strip()]


# ---------------------------------------------------------------------------
# Commands


def cmd_check(bl: Backlog, args) -> int:
    findings = check(bl)
    if args.json:
        print(json.dumps({"total": len(findings), "findings": [finding_json(f) for f in findings]}, ensure_ascii=False))
    else:
        print_findings(findings)
    return 1 if findings else 0


def cmd_sync(bl: Backlog, args) -> int:
    ov = bl.require_overview()
    listed = [r.slug for name in SECTIONS for r in ov.sections[name].rows if r.slug]
    problems = []
    for s in sorted(set(listed)):
        if listed.count(s) > 1:
            problems.append(f"'{s}' is listed more than once")
        if s not in bl.items:
            problems.append(f"row '{s}' has no item")
    for s in bl.items:
        if s not in listed:
            problems.append(f"item '{s}' has no row")
    if problems:
        raise Refused("rows and items do not correspond: " + "; ".join(problems))
    if ov.errors:
        raise Refused("BACKLOG.md has findings sync must not paper over: "
                      + "; ".join(f"line {ln}: {msg}" for ln, _, msg in ov.errors))
    bl.save_overview()
    return finish(bl, "synced")


def cmd_list(bl: Backlog, args) -> int:
    ov = bl.require_overview()
    want_section = resolve_section(args.section) if args.section else None
    result = []
    for name in SECTIONS:
        if want_section and name != want_section:
            continue
        pos = 0
        for row in ov.sections[name].rows:
            if not row.slug:
                continue
            pos += 1
            it = bl.items.get(row.slug)
            if not it or not it.ok:
                continue
            h = it.header
            if args.area and h["area"] != args.area:
                continue
            if args.type and h["type"] != args.type:
                continue
            if args.status and h["status"] != args.status:
                continue
            if args.who and h["who"] != args.who:
                continue
            if args.min_severity is not None and (not str(h["severity"]).isdigit() or int(h["severity"]) < args.min_severity):
                continue
            if args.needs and args.needs not in it.list_of("depends-on"):
                continue
            if args.related_to and args.related_to not in it.list_of("related"):
                continue
            entry = {"slug": it.slug, "section": name, "position": pos}
            entry.update(h)
            result.append(entry)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        for e in result:
            pos = str(e["position"]) if e["section"] in ORDERED else "-"
            print(f"{e['section']:<28} {pos:>3}  sev {e['severity']:>2}  {e['type']:<12} {e['area']:<16} {e['status']:<11} {e['slug']}  {e['title']}")
        print(f"{len(result)} item(s)")
    return 0


def cmd_next(bl: Backlog, args) -> int:
    ov = bl.require_overview()
    skipped = []
    if args.slug:
        try:
            it = bl.item(args.slug)
            reason = eligibility(bl, it)
        except Refused as e:
            reason = str(e)
        if reason:
            if args.json:
                print(json.dumps({"slug": None, "refused": args.slug, "reason": reason}, ensure_ascii=False))
            else:
                print(f"not eligible: {args.slug}: {reason}")
            return 1
        chosen = args.slug
    else:
        chosen, skipped = next_eligible(bl, ov)
    if args.json:
        print(json.dumps({"slug": chosen, "skipped": skipped}, ensure_ascii=False))
    else:
        for s in skipped:
            print(f"skipped: {s['slug']}: {s['reason']}")
        print(chosen or "nothing-to-do")
    return 0


def cmd_new(bl: Backlog, args) -> int:
    header = base_header(args, args.source, args.title)
    extra = {key.capitalize(): getattr(args, key, None) for key in ("approach", "notes", "question", "options", "recommendation", "steps")}
    it = create_item(bl, header, args.slug, args.problem or "", args.evidence or "", args.expected or "",
                     extra={k: v for k, v in extra.items() if v}, check_body=args.input_json is not None)
    emit_slug(it.slug)
    return finish(bl)


def cmd_set(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    before_section = expected_section(it)
    changes = []
    for pair in args.pairs:
        if "=" not in pair:
            raise Refused(f"'{pair}' is not key=value")
        key, value = pair.split("=", 1)
        key = key.strip()
        value = one_line(value, f"the value of '{key}'")
        if key not in HEADER_KEYS:
            raise Refused(f"unknown key '{key}'")
        if key in ("status", "updated"):
            raise Refused(f"'{key}' is not set directly (status: use move / block / unblock / start)")
        if key in LIST_KEYS:
            parsed = parse_list(value) if value.startswith("[") else split_csv(value)
            if parsed is None:
                raise Refused(f"'{key}' must be a list like [a, b], a,b or []")
            it.header[key] = parsed
        else:
            it.header[key] = value or "-"
        changes.append(f"{key}={value}")
    errs = validate_item(bl, it)
    if errs:
        raise Refused("invalid values: " + "; ".join(errs))
    after_section = expected_section(it)
    moves = bool(after_section) and after_section != before_section
    if args.position is not None:
        if args.position < 1:
            raise Refused("--position counts from 1 (the top)")
        if not moves:
            raise Refused("--position places the row when type / who move it to another section; to reorder, use move")
    if any(c.startswith("title=") for c in changes):
        set_title_line(it, it.header["title"])
    added = ensure_type_sections(it)
    touch(it, args.log or "set " + ", ".join(changes))
    bl.save_item(it)
    if added:
        notice(f"added the sections {', '.join(added)} with placeholders - write them")
    if moves:
        bl.place_row(it.slug, after_section, args.position)
        notice(f"moved to '{after_section}' (type / who changed)"
               + (f" at position {args.position}" if args.position is not None else ""))
    bl.save_overview()
    return finish(bl, f"updated {it.slug}")


def cmd_log(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    touch(it, args.text)
    bl.save_item(it)
    bl.save_overview()
    return finish(bl, f"logged {it.slug}")


def cmd_verify(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    commit = args.commit or git(bl.root, "rev-parse", "--short", "HEAD")
    if not re.fullmatch(r"[0-9a-f]{7,40}", commit):
        raise Refused(f"'{commit}' is not a commit (7-40 lowercase hex digits)")
    it.header["verified"] = f"{today()} {commit}"
    touch(it, f"verified at {commit}" + (f": {args.note}" if args.note else ""))
    bl.save_item(it)
    bl.save_overview()
    return finish(bl, f"verified {it.slug} at {commit}")


def resolve_section(text: str) -> str:
    key = text.strip().lower().replace(" ", "-")
    if key in SECTION_ALIASES:
        return SECTION_ALIASES[key]
    for name in SECTIONS:
        if name.lower() == text.strip().lower():
            return name
    raise Refused(f"unknown section '{text}' (one of: {', '.join(SECTIONS)})")


def cmd_move(bl: Backlog, args) -> int:
    bl.require_overview()
    it = bl.item(args.slug)
    target = resolve_section(args.section)
    reason = one_line(args.reason, "--reason") if args.reason else ""
    current = apply_move(bl, it, target, args.position, reason)
    bl.save_item(it)
    bl.save_overview()
    return finish(bl, f"{it.slug}: {current or 'no row'} -> {target}")


def apply_move(bl: Backlog, it: Item, target: str, position: int | None, reason: str) -> str | None:
    """The move of it to target in memory (status, reason, log line, row,
    Last triaged); nothing is written.  Returns the section it was in."""
    ov = bl.require_overview()
    if position is not None and position < 1:
        raise Refused("--position counts from 1 (the top)")
    if target == SEC_PROGRESS:
        raise Refused("only 'start' moves an item to 'In progress'")
    current, _ = ov.section_of(it.slug)
    old_status = it.header["status"]
    old_reason = it.header.get("reason", "-")
    if old_status == "in-progress":
        raise Refused("the item is in progress; a run ends it (remove or block)")
    reopening = old_status in ("parked", "rejected") and target not in (SEC_PARKED, SEC_REJECTED) \
        or old_status == "parked" and target == SEC_REJECTED or old_status == "rejected" and target == SEC_PARKED
    if reopening and not reason:
        raise Refused(f"moving a {old_status} item out of '{current}' needs --reason (the new reason)")
    note = ""
    if target in (SEC_PARKED, SEC_REJECTED):
        if not reason:
            raise Refused(f"moving to '{target}' needs --reason")
        new_status = "parked" if target == SEC_PARKED else "rejected"
        it.header["reason"] = reason
        note = f": {reason}"
    elif target == SEC_INBOX:
        new_status = "new"
        it.header["reason"] = "-"
        note = f" (reopened: {reason})" if reopening else (f": {reason}" if reason else "")
    elif old_status == "blocked":
        # moving never unblocks; 'unblock' does
        new_status = "blocked"
        note = (f": {reason}" if reason else "") + f" (still blocked: {old_reason})"
    else:
        new_status = "open"
        it.header["reason"] = "-"
        note = f" (reopened: {reason})" if reopening else (f": {reason}" if reason else "")
    it.header["status"] = new_status
    exp = expected_section(it)
    if exp != target:
        raise Refused(f"'{it.slug}' (type {it.header['type']}, who {it.header['who']}) belongs in '{exp}', not '{target}'; change type / who with 'set' first")
    text = f"moved to {target}"
    if position and target in ORDERED:
        text += f" position {position}"
    touch(it, text + note)
    bl.place_row(it.slug, target, position)
    if target != SEC_INBOX:
        bl.touch_triaged()
    return current


def cmd_block(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    reason = one_line(args.reason, "--reason")
    if not reason:
        raise Refused("--reason must not be empty")
    if it.header["status"] != "open":
        raise Refused(f"only an open item can be blocked (status is {it.header['status']})")
    it.header["status"] = "blocked"
    it.header["reason"] = reason
    touch(it, f"blocked: {reason}")
    bl.save_item(it)
    bl.save_overview()
    return finish(bl, f"blocked {it.slug}")


def cmd_unblock(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    if it.header["status"] != "blocked":
        raise Refused(f"the item is not blocked (status is {it.header['status']})")
    it.header["status"] = "open"
    it.header["reason"] = "-"
    touch(it, "unblocked" + (f": {args.note}" if args.note else ""))
    bl.save_item(it)
    bl.save_overview()
    return finish(bl, f"unblocked {it.slug}")


def cmd_start(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    if not FEATURE_RE.match(args.feature):
        raise Refused("--feature must be three digits")
    reason = eligibility(bl, it)
    if reason:
        raise Refused(f"not eligible for a run: {reason}")
    it.header["status"] = "in-progress"
    it.header["feature"] = args.feature
    touch(it, f"run started, feature {args.feature}")
    bl.save_item(it)
    bl.place_row(it.slug, SEC_PROGRESS)
    bl.save_overview()
    return finish(bl, f"started {it.slug} as feature {args.feature}")


def _rmtree(folder: Path) -> None:
    def onexc(func, path, exc):
        # a read-only file (e.g. in evidence/) - clear the flag and retry once
        os.chmod(path, 0o666)
        func(path)
    files = sorted(p for p in folder.rglob("*") if p.is_file())
    if sys.version_info >= (3, 12):
        shutil.rmtree(folder, onexc=onexc)
    else:  # pragma: no cover
        shutil.rmtree(folder, onerror=lambda f, p, e: onexc(f, p, e))
    for path in files:
        record(path)  # deleted files are part of what the command changed


def cmd_remove(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    h = it.header
    if bool(args.feature) == bool(args.reason):
        raise Refused("give exactly one of --feature NNN (its feature closed it) or --reason TEXT (closed without a feature)")
    if args.feature:
        if not FEATURE_RE.match(args.feature):
            raise Refused("--feature must be three digits")
        if not args.force and (h["status"] != "in-progress" or h["feature"] != args.feature):
            raise Refused(f"'{it.slug}' is not in progress as feature {args.feature} (status {h['status']}, feature {h['feature']}); --force to remove anyway")
        why = f"done in feature {args.feature}"
    else:
        reason = one_line(args.reason, "--reason")
        if h["status"] == "in-progress":
            raise Refused("an in-progress item is closed by its run ('remove --feature')")
        why = f"closed: {reason}"
    remove_item(bl, it, why)
    return finish(bl, f"removed {it.slug} ({why})")


def remove_item(bl: Backlog, it: Item, why: str) -> None:
    """Delete the item's folder, drop it from the others' related / depends-on
    (logging why there), then its row; BACKLOG.md is written last."""
    # the folder first: if it cannot be deleted, nothing else has changed
    _rmtree(it.folder)
    del bl.items[it.slug]
    for other in list(bl.items.values()):
        if not other.ok:
            continue
        changed = []
        for key in LIST_KEYS:
            if it.slug in other.list_of(key):
                other.header[key] = [s for s in other.list_of(key) if s != it.slug]
                changed.append(key)
        if changed:
            what = "dependency" if "depends-on" in changed else "related item"
            touch(other, f"{what} {it.slug} {why}")
            bl.save_item(other)
    bl.unplace_row(it.slug)
    bl.save_overview()


def cmd_run_log(bl: Backlog, args) -> int:
    if args.outcome not in RUN_OUTCOMES:
        raise Refused(f"outcome must be one of {', '.join(RUN_OUTCOMES)}")
    if not bl.runs_path.is_file():
        raise Refused("backlog/RUNS.md does not exist")
    lines = read_text(bl.runs_path).rstrip("\n").split("\n")
    blocks = table_blocks(lines, 0, len(lines))
    if len(blocks) != 1:
        raise Refused("RUNS.md must contain exactly one table")
    cells = [
        now().strftime("%Y-%m-%d %H:%M"),
        args.slug or "-", args.outcome, args.feature or "-", args.branch or "-",
        str(args.inbox or 0), args.person or "-", args.note or "-",
    ]
    cells = [flatten(c) or "-" for c in cells]
    _, b = blocks[0]
    lines.insert(b, join_row([esc_cell(c) for c in cells]))
    write_text(bl.runs_path, "\n".join(lines) + "\n")
    return finish(bl, "journal: " + " | ".join(cells))


def lock_text(fields: dict) -> str:
    return "".join(f"{k}: {fields.get(k, '-')}\n" for k in ("started", "slug", "branch", "host"))


def cmd_lock(bl: Backlog, args) -> int:
    path = lock_path(bl.root, args.lock_dir)
    if args.action == "status":
        if not path.exists():
            print("free")
        else:
            print(describe_lock(read_lock(path)))
        return 0
    if args.action == "acquire":
        content = lock_text({"started": now().replace(microsecond=0).isoformat(), "slug": args.slug or "-",
                             "branch": args.branch or "-", "host": socket.gethostname()})
        try:
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            print("another run in progress: " + describe_lock(read_lock(path)))
            return 1
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
        print(f"lock acquired: {path}")
        return 0
    if not path.exists():
        print("no lock" + (" to release" if args.action == "release" else " to update"))
        return 1
    fields = read_lock(path)
    if args.action == "update":
        if not args.slug or not args.branch:
            raise Refused("lock update needs --slug and --branch")
        if fields.get("slug", "-") != args.slug:
            print(f"refused: the lock belongs to item {fields.get('slug', '-')}, not {args.slug}")
            return 1
        fields["branch"] = one_line(args.branch, "--branch")
        write_text(path, lock_text(fields))
        print(f"lock updated: branch {args.branch}")
        return 0
    # release
    if not args.force and fields.get("slug", "-") != (args.slug or "-"):
        print(f"refused: the lock belongs to item {fields.get('slug', '-')}, not {args.slug or '-'} (--force for the maintainer)")
        return 1
    path.unlink()
    print("lock released")
    return 0


def problem_paragraph(body_text: str) -> str:
    """The first paragraph of an issue body that is not a heading, quoted
    so that Markdown inside it cannot become a section of desc.md."""
    for para in body_text.split("\n\n"):
        lines = [ln for ln in para.strip().split("\n") if ln.strip() and not ln.lstrip().startswith("#")]
        if lines:
            return "\n".join("> " + ln for ln in lines)
    return ""


def issue_labels(issue: dict) -> list:
    return [lb.get("name", "") for lb in issue.get("labels") or [] if isinstance(lb, dict) and lb.get("name")]


def type_from_labels(labels: list) -> str:
    """The starting type of an imported issue; the skill corrects it from the text."""
    names = {lb.lower() for lb in labels}
    if "bug" in names:
        return "bug"
    if "enhancement" in names:
        return "feature"
    if "documentation" in names:
        return "improvement"
    return "bug"


def imported_item(bl: Backlog, num: int) -> str | None:
    """The slug of the item that holds issue NUM now, if any."""
    for it in bl.items.values():
        if it.ok and it.header.get("source") == f"github#{num}":
            return it.slug
    return None


def removed_import(root: Path, num: int) -> str | None:
    """The newest commit whose change of backlog/items touched 'source: github#NUM'
    (an item imported before and since removed or re-sourced), or None.
    Outside a git repository, or before its first commit, there is no history: None."""
    if not (root / ".git").exists():
        return None
    # desc.md only: issue.md holds issue text verbatim, which may contain such a line
    args = ["log", "--format=%h", "-G", f"^source: github#{num}$", "--", ":(glob)backlog/items/*/desc.md"]
    try:
        head = subprocess.run(["git", "-C", str(root), "rev-parse", "--verify", "-q", "HEAD"],
                              capture_output=True, text=True, encoding="utf-8")
        if head.returncode != 0:
            return None  # no commit yet (the message is localized; the exit code is not)
        res = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, encoding="utf-8")
    except OSError as e:
        raise Refused(f"cannot run git to read the history of backlog/items: {e}")
    if res.returncode != 0:
        raise Refused(f"git {' '.join(args)} failed: {res.stderr.strip()}")
    out = res.stdout.strip()
    return out.split("\n")[0] if out else None


def import_issue(bl: Backlog, issue: dict, area: str, type_: str, severity: int, slug: str | None) -> Item:
    """Create the item of one GitHub issue (fetched with the issue list or alone);
    reads all its comments first, writes nothing when that fails."""
    num = issue.get("number")
    base = f"https://api.github.com/repos/{GITHUB_REPO}/issues/{num}"
    try:
        comments = fetch_all(base + "/comments") if issue.get("comments") else []
    except NET_ERRORS as e:
        raise Refused(f"cannot read the comments of issue #{num}: {e}")
    if len(comments) != int(issue.get("comments") or 0):
        raise Refused(f"issue #{num} has {issue.get('comments')} comments but {len(comments)} were read; nothing written")
    title = (issue.get("title") or "").strip()
    body_text = (issue.get("body") or "").replace("\r\n", "\n").strip()
    url = issue.get("html_url", f"https://github.com/{GITHUB_REPO}/issues/{num}")
    labels = issue_labels(issue)
    header = base_header(argparse.Namespace(type=type_, severity=severity, area=area), f"github#{num}", title)
    header["who"] = "agent"
    it = create_item(bl, header, slug,
                     problem=problem_paragraph(body_text) or "(see issue.md)",
                     evidence=f"GitHub issue #{num}: {url} - original text in `issue.md`.",
                     expected="(to be written)")
    created = (issue.get("created_at") or "")[:10]
    lines = [f"number: {num}", f"url: {url}",
             f"author: {(issue.get('user') or {}).get('login', '?')}",
             f"created: {created}", f"labels: {', '.join(labels) or '-'}", "", f"# {title}", "", body_text or "(empty)"]
    if comments:
        lines += ["", "## Comments"]
        for c in comments:
            lines += ["", f"### {(c.get('user') or {}).get('login', '?')}, {(c.get('created_at') or '')[:10]}", "",
                      (c.get("body") or "").replace("\r\n", "\n").strip()]
    write_text(it.folder / "issue.md", "\n".join(lines) + "\n")
    write_text(it.folder / "reply.md", "state: not-sent\n\n(draft of the reply to the issue thread)\n")
    return it


def cmd_import_github(bl: Backlog, args) -> int:
    if (args.number is None) == (args.label is None):
        raise Refused("give an issue number or --label NAME (exactly one)")
    if args.label is not None:
        return import_labelled(bl, args)
    if not args.area:
        raise Refused("an issue number needs --area")
    if args.dry_run:
        raise Refused("--dry-run belongs to --label")
    num = args.number
    slug = imported_item(bl, num)
    if slug:
        raise Refused(f"issue #{num} is already imported as '{slug}'")
    try:
        issue = fetch_json(f"https://api.github.com/repos/{GITHUB_REPO}/issues/{num}")
    except NET_ERRORS as e:
        raise Refused(f"cannot read issue #{num}: {e}")
    if "pull_request" in issue:
        raise Refused(f"#{num} is a pull request, not an issue")
    it = import_issue(bl, issue, args.area, args.type or type_from_labels(issue_labels(issue)), args.severity, args.slug)
    emit_slug(it.slug)
    return finish(bl)


def import_labelled(bl: Backlog, args) -> int:
    """Import every open issue labelled LABEL that the backlog has not held yet."""
    label = one_line(args.label, "--label")
    if args.slug or args.type:
        raise Refused("--label imports several issues; --slug and --type belong to a single issue number")
    # the values every issue will get, checked before GitHub is asked (also for --dry-run)
    sample = argparse.Namespace(type="bug", severity=args.severity, area=args.area or "panels-ui")
    refuse_invalid_header(bl, base_header(sample, "github#1", "sample"), "sample")
    url = f"https://api.github.com/repos/{GITHUB_REPO}/issues?state=open&labels={urllib.parse.quote(label, safe='')}"
    try:
        issues = fetch_all(url)
    except NET_ERRORS as e:
        raise Refused(f"cannot list the issues labelled '{label}': {e}")
    # decide every issue before writing anything: a refusal here leaves the backlog untouched
    plan = []
    for issue in sorted(issues, key=lambda i: int(i.get("number") or 0)):
        num = int(issue.get("number") or 0)
        stop = [lb for lb in issue_labels(issue) if lb.lower() in GITHUB_SKIP_LABELS]
        why = None
        if "pull_request" in issue:
            why = "a pull request"
        elif imported_item(bl, num):
            why = f"already imported as '{imported_item(bl, num)}'"
        elif stop:
            why = f"labelled {', '.join(stop)}"
        else:
            commit = removed_import(bl.root, num)
            if commit:
                why = f"imported before; its item left the backlog (commit {commit})"
        plan.append((num, issue, why))
    done = skipped = failed = 0
    for num, issue, why in plan:
        if why:
            notice(f"skipped #{num}: {why}")
            skipped += 1
            continue
        labels = issue_labels(issue)
        type_ = type_from_labels(labels)
        area = args.area or ("help-docs" if type_ == "improvement" else "panels-ui")
        if args.dry_run:
            notice(f"would import #{num} [{', '.join(labels)}] as {type_}, {area}: {issue.get('title', '').strip()}")
            done += 1
            continue
        try:
            it = import_issue(bl, issue, area, type_, args.severity, None)
        except Refused as e:
            notice(f"failed #{num}: {e}")
            failed += 1
            continue
        OUT.slugs.append(it.slug)
        notice(f"imported #{num} {it.slug}")
        done += 1
    verb = "would import" if args.dry_run else "imported"
    notice(f"{verb} {done}, skipped {skipped}, failed {failed}")
    if args.dry_run:
        return 0
    code = finish(bl)
    return 1 if failed else code


# ---------------------------------------------------------------------------
# Read commands for programs (feature 344): board, show, legend


STEP_RE = re.compile(r"^(\s*)- \[([ xX])\] (.*)$")
# the forms of an option in '## Options': '### A ...', '- **A ...', '- A - ...'
OPTION_RES = [
    re.compile(r"^###\s+([A-Z][0-9]?)(?=$|[\s.:)\-–—])"),
    re.compile(r"^- \*\*([A-Z][0-9]?)(?=[\s.:)\-–—*])"),
    re.compile(r"^- ([A-Z][0-9]?)\s*[-–—:.)]"),
]


def header_json(h: dict) -> dict:
    """Header fields for JSON: severity an integer 0-10 (else null), lists as
    arrays, '-' (and a missing key) as null."""
    out = {}
    for key in HEADER_KEYS:
        v = h.get(key)
        if key in LIST_KEYS:
            out[key] = list(v) if isinstance(v, list) else []
        elif key == "severity":
            out[key] = int(v) if isinstance(v, str) and re.fullmatch(r"\d{1,2}", v) and int(v) <= 10 else None
        else:
            out[key] = None if v in (None, "", "-") else v
    return out


def row_place(ov: Overview | None, slug: str) -> tuple:
    """(section, position) of the item's row; position counts item rows of an
    ordered section, None in a sorted one."""
    for name in SECTIONS:
        sec = ov.sections.get(name) if ov else None
        pos = 0
        for r in (sec.rows if sec else []):
            if r.slug:
                pos += 1
                if r.slug == slug:
                    return name, (pos if name in ORDERED else None)
    return None, None


def trim_blank(lines: list) -> list:
    a, b = 0, len(lines)
    while a < b and not lines[a].strip():
        a += 1
    while b > a and not lines[b - 1].strip():
        b -= 1
    return lines[a:b]


def body_text(text: str) -> str:
    """A section text as stored: LF line ends, no blank lines around it."""
    return "\n".join(trim_blank(text.replace("\r\n", "\n").split("\n")))


def section_blocks(it: Item) -> list:
    """(name, heading index, end index) of every '## ' section in file order."""
    hs = headings(it)
    return [(n, i, hs[k + 1][1] if k + 1 < len(hs) else len(it.body)) for k, (n, i) in enumerate(hs)]


def section_lines(it: Item, name: str) -> list:
    blk = next((b for b in section_blocks(it) if b[0] == name), None)
    return it.body[blk[1] + 1:blk[2]] if blk else []


def parse_log(it: Item) -> list:
    out = []
    for line in section_lines(it, "Log"):
        m = LOG_RE.match(line)
        if m:
            out.append({"date": m.group(1), "text": line[len(f"- {m.group(1)} {EMDASH} "):]})
    return out


def parse_steps(it: Item) -> list:
    out = []
    for line in section_lines(it, "Steps"):
        m = STEP_RE.match(line)
        if m:
            out.append({"index": len(out) + 1, "done": m.group(2) != " ", "text": m.group(3).rstrip()})
    return out


def parse_options(it: Item) -> list:
    """Options of a decision: each starts at '### A', '- **A' or '- A -' and
    runs to the next one; text = the option's Markdown without the marker."""
    out, cur = [], None
    for line in section_lines(it, "Options"):
        key = None
        for k, rx in enumerate(OPTION_RES):
            m = rx.match(line)
            if m:
                key = m.group(1)
                first = line[3:].lstrip() if k == 0 else line[2:]
                break
        if key:
            cur = {"key": key, "lines": [first]}
            out.append(cur)
        elif cur:
            cur["lines"].append(line)
    return [{"key": o["key"], "text": "\n".join(trim_blank(o["lines"]))} for o in out]


def safe_text(src, path: Path) -> str:
    return src.read_bytes(path).decode("utf-8", "replace").replace("\r\n", "\n")


def item_files(bl: Backlog, it: Item) -> dict:
    src = bl.src
    issue = reply = None
    if src.is_file(it.folder / "issue.md"):
        head = {}
        for line in safe_text(src, it.folder / "issue.md").split("\n"):
            if not line.strip():
                break
            if ": " in line:
                k, v = line.split(": ", 1)
                head[k.strip()] = v.strip()
        num = head.get("number", "")
        issue = {"number": int(num) if num.isdigit() else None, "head": head}
    if src.is_file(it.folder / "reply.md"):
        first = first_line(it.folder / "reply.md", src)
        reply = {"state": first[len("state: "):] if first.startswith("state: ") else first}
    evidence = []

    def walk(folder: Path, prefix: str) -> None:
        for child in src.children(folder):
            if src.is_dir(child):
                walk(child, prefix + child.name + "/")
            else:
                evidence.append(prefix + child.name)
    if src.is_dir(it.folder / "evidence"):
        walk(it.folder / "evidence", "")
    return {"issue": issue, "reply": reply, "evidence": evidence}


def unreadable_entries(bl: Backlog) -> list:
    out = []
    for slug, it in bl.items.items():
        if not it.ok:
            msg = it.errors[0][2] if it.errors else "the header cannot be read"
            out.append({"slug": slug, "path": rel(bl.root, it.path), "finding": msg})
    listed = [r.slug for sec in (bl.ov.sections.values() if bl.ov else []) for r in sec.rows if r.slug]
    for slug in dict.fromkeys(listed):
        if slug not in bl.items:
            out.append({"slug": slug, "path": f"backlog/items/{slug}/desc.md",
                        "finding": f"row names '{slug}', which has no items/{slug}/desc.md"})
    return out


def cmd_board(bl: Backlog, args) -> int:
    ov = bl.require_overview()
    m = LAST_TRIAGED_RE.match(ov.lines[ov.last_triaged_line]) if ov.last_triaged_line >= 0 else None
    sections = []
    for name in SECTIONS:
        rows, pos = [], 0
        for r in ov.sections[name].rows:
            if not r.slug:
                rows.append({"note": ov.lines[r.lineno - 1]})
                continue
            pos += 1
            it = bl.items.get(r.slug)
            row = {"position": pos if name in ORDERED else None, "slug": r.slug}
            row.update(header_json(it.header if it and it.ok else {}))
            if args.with_body:
                row["body"] = "\n".join(it.body) if it else None
                issue = it.folder / "issue.md" if it else None
                row["issue"] = safe_text(bl.src, issue) if issue and bl.src.is_file(issue) else None
            rows.append(row)
        sections.append({"name": name, "ordered": name in ORDERED, "rows": rows})
    board = {"revision": ov.revision, "last_triaged": m.group(1) if m else None,
             "sections": sections, "unreadable": unreadable_entries(bl)}
    if args.json:
        print(json.dumps(board, ensure_ascii=False))
        return 0
    print(f"Last triaged: {board['last_triaged'] or '-'}")
    for sec in sections:
        print(f"## {sec['name']}")
        for row in sec["rows"]:
            if "note" in row:
                print(f"       {row['note']}")
            else:
                print(f"  {row['position'] or '-':>3}  {row['slug']}  {row['title'] or '(unreadable)'}")
    for u in board["unreadable"]:
        print(f"unreadable: {u['path']}: {u['finding']}")
    return 0


def cmd_show(bl: Backlog, args) -> int:
    it = bl.items.get(args.slug)
    if it is None:
        raise Refused(f"no item '{args.slug}'")
    if not args.json:
        sys.stdout.write(safe_text(bl.src, it.path))
        return 0
    section, position = row_place(bl.ov, it.slug)
    obj = {"slug": it.slug, "revision": it.revision}
    obj.update(header_json(it.header))
    obj["section"], obj["position"] = section, position
    obj["body"] = [{"name": n, "markdown": "\n".join(trim_blank(it.body[i + 1:end]))} for n, i, end in section_blocks(it)]
    obj["log"] = parse_log(it)
    obj["steps"] = parse_steps(it)
    obj["options"] = parse_options(it)
    obj["files"] = item_files(bl, it)
    obj["dependents"] = sorted(s for s, o in bl.items.items() if o.ok and it.slug in o.list_of("depends-on"))
    folder = rel(bl.root, it.folder)
    overview_path = rel(bl.root, bl.overview_path)
    obj["findings"] = [finding_json(f) for f in check(bl)
                       if f[0] == folder or f[0].startswith(folder + "/")
                       or f[0] == overview_path and f"'{it.slug}'" in f[3]]
    reason = eligibility(bl, it) if it.ok else "unreadable item"
    obj["eligibility"] = {"eligible": reason is None, "reason": reason}
    print(json.dumps(obj, ensure_ascii=False))
    return 0


LEGEND_JSON = [("types", "Types", "value"), ("statuses", "Statuses", "value"), ("areas", "Areas", "value"),
               ("who", "Who", "value"), ("efforts", "Effort", "value"), ("sources", "Sources", "form"),
               ("severity", "Severity", "range")]


def cmd_legend(bl: Backlog, args) -> int:
    ov = bl.ov
    if ov is None:
        raise Refused(f"{rel(bl.root, bl.overview_path)} does not exist")
    out = {}
    for key, table, first in LEGEND_JSON:
        entries = []
        for cells in ov.legend_rows.get(table, []):
            value = cells[0].replace("`", "").strip() if first == "range" else unbacktick(cells[0])
            meaning = cells[1].replace("\\|", "|") if len(cells) > 1 else ""
            entries.append({first: value, "meaning": meaning})
        out[key] = entries
    if args.json:
        print(json.dumps(out, ensure_ascii=False))
    else:
        for key, table, first in LEGEND_JSON:
            print(f"{table}: " + ", ".join(e[first] for e in out[key]))
    return 0


# ---------------------------------------------------------------------------
# Changing commands for programs (feature 344): reorder, body, step, decide, reply


def cmd_reorder(bl: Backlog, args) -> int:
    ov = bl.require_overview()
    target = resolve_section(args.section)
    if target not in ORDERED:
        raise Refused(f"'{target}' is sorted by the tool; reorder takes one of: {', '.join(s for s in SECTIONS if s in ORDERED)}")
    rows = ov.sections[target].rows
    current = [r.slug for r in rows if r.slug]
    order = list(args.order)
    if sorted(order) != sorted(current):
        raise Refused(f"the order must name exactly the rows of '{target}'")
    # a hand-written row moves with the item row above it; rows above every item stay on top
    lead, groups = [], {}
    cur = None
    for r in rows:
        if r.slug:
            cur = [r]
            groups.setdefault(r.slug, []).append(cur)
        elif cur is None:
            lead.append(r)
        else:
            cur.append(r)
    new_rows = list(lead)
    for slug in order:
        new_rows += groups[slug].pop(0)
    ov.sections[target].rows = new_rows
    bl.touch_triaged()
    bl.save_overview()
    OUT.slugs, OUT.section = order, target
    return finish(bl, f"reordered '{target}': {len(order)} rows")


def resolve_heading(text: str) -> str:
    for name in KNOWN_HEADINGS:
        if name.lower() == text.strip().lower():
            return name
    raise Refused(f"unknown section '{text}' (one of: {', '.join(KNOWN_HEADINGS)})")


def refuse_new_body_findings(before: list, it: Item) -> None:
    """Refuse a body change that adds a finding of the body rule (a finding the
    item already had is not this change's)."""
    old = [m for _, _, m in before]
    new = []
    for _, _, m in body_findings(it):
        if m in old:
            old.remove(m)
        else:
            new.append(m)
    if new:
        raise Refused("the result breaks the body rules: " + "; ".join(new))


def cmd_body(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    name = resolve_heading(args.section)
    if name == "Log":
        raise Refused("the Log is appended by 'log', never replaced")
    if (args.markdown is None) == (args.remove is None):
        raise Refused("give either {\"markdown\": text} or {\"remove\": true}")
    before = body_findings(it)
    blk = next((b for b in section_blocks(it) if b[0] == name), None)
    if args.remove:
        required = REQUIRED_HEADINGS + TYPE_HEADINGS.get(it.header["type"], [])
        if name in required:
            raise Refused(f"'## {name}' is required for a {it.header['type']} item; replace it instead")
        if blk is None:
            raise Refused(f"the item has no '## {name}'")
        del it.body[blk[1]:blk[2]]
    else:
        text = body_text(args.markdown)
        if not text.strip():
            raise Refused("the markdown is empty (an optional section is dropped with {\"remove\": true})")
        lines = text.split("\n")
        if blk:
            it.body[blk[1] + 1:blk[2]] = [""] + lines + [""]
        else:
            # its fixed place: before the first present section that follows it in the order
            rank = KNOWN_HEADINGS.index(name)
            at = next((i for n, i, _ in section_blocks(it) if n in KNOWN_HEADINGS and KNOWN_HEADINGS.index(n) > rank), None)
            if at is None:
                while it.body and not it.body[-1].strip():
                    it.body.pop()
                it.body += ["", f"## {name}", ""] + lines
            else:
                it.body[at:at] = [f"## {name}", ""] + lines + [""]
    refuse_new_body_findings(before, it)
    touch(it, args.log or f"edited {name}")
    bl.save_item(it)
    bl.save_overview()
    return finish(bl, f"edited {it.slug}: {name}")


def cmd_step(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    blk = next((b for b in section_blocks(it) if b[0] == "Steps"), None)
    if blk is None:
        raise Refused(f"'{it.slug}' has no '## Steps'")
    idx = [k for k in range(blk[1] + 1, blk[2]) if STEP_RE.match(it.body[k])]
    if not 1 <= args.n <= len(idx):
        raise Refused(f"'{it.slug}' has no step {args.n} (its steps: 1-{len(idx)})" if idx else f"'{it.slug}' has no checklist step")
    k = idx[args.n - 1]
    m = STEP_RE.match(it.body[k])
    done = bool(args.done)
    if (m.group(2) != " ") == done:
        raise Refused(f"step {args.n} is already {'done' if done else 'open'}")
    it.body[k] = f"{m.group(1)}- [{'x' if done else ' '}] {m.group(3)}"
    text = f"step {args.n} {'done' if done else 'reopened'}"
    touch(it, text + (f": {args.note}" if args.note else ""))
    bl.save_item(it)
    bl.save_overview()
    return finish(bl, f"{it.slug}: {text}")


def split_position(spec: str) -> tuple:
    """'next@3' -> ('next', 3); 'next' -> ('next', None)."""
    if "@" not in spec:
        return spec, None
    head, pos = spec.rsplit("@", 1)
    if not pos.isdigit() or int(pos) < 1:
        raise Refused(f"'@{pos}' is not a position (1 = the top)")
    return head, int(pos)


def change_type(bl: Backlog, it: Item, type_: str, who: str | None = None) -> list:
    """type (and who) changed in memory, validated as 'set' does, the type's
    sections added, logged; returns the sections added."""
    changes = []
    it.header["type"] = one_line(type_, "the type")
    changes.append(f"type={it.header['type']}")
    if who is not None:
        it.header["who"] = one_line(who, "who")
        changes.append(f"who={it.header['who']}")
    errs = validate_item(bl, it)
    if errs:
        raise Refused("invalid values: " + "; ".join(errs))
    added = ensure_type_sections(it)
    touch(it, "set " + ", ".join(changes))
    return added


DECIDE_ACTIONS = "move:<section>[@N], set-type:<type>[,who:<who>][@N], park, close, keep"


def cmd_decide(bl: Backlog, args) -> int:
    bl.require_overview()
    it = bl.item(args.slug)
    if it.header["type"] != "decision":
        raise Refused(f"'{it.slug}' is a {it.header['type']} item, not a decision")
    key = one_line(args.option, "--option")
    if not re.fullmatch(r"[A-Za-z0-9]{1,8}", key):
        raise Refused(f"--option '{key}' is not an option key (A, B, ...)")
    keys = [o["key"] for o in parse_options(it)]
    if keys and key not in keys:
        raise Refused(f"no option '{key}' in '## Options' (its options: {', '.join(keys)})")
    decision = flatten(args.decision)
    if not decision:
        raise Refused("the decision is empty")
    kind, _, spec = args.then.partition(":")
    if kind not in ("move", "set-type", "park", "close", "keep") or (kind in ("park", "close", "keep") and spec) \
            or (kind in ("move", "set-type") and not spec):
        raise Refused(f"unknown --then '{args.then}' (one of: {DECIDE_ACTIONS})")
    if args.type and kind not in ("move", "keep"):
        raise Refused("--type belongs to --then move:<section> or keep")
    line = f"maintainer decision {today()}: option {key} - {decision}"
    if kind == "close":
        if it.header["status"] == "in-progress":
            raise Refused("an in-progress item is closed by its run ('remove --feature')")
        why = f"closed: {decision}"
        remove_item(bl, it, why)
        return finish(bl, f"decided {it.slug}: option {key}, removed ({why})")
    before = expected_section(it)
    touch(it, line)
    added, moved = [], None
    if args.type:
        added = change_type(bl, it, args.type)
    if kind == "move":
        name, pos = split_position(spec)
        target = resolve_section(name)
        reopening = it.header["status"] in ("parked", "rejected") or target in (SEC_PARKED, SEC_REJECTED)
        apply_move(bl, it, target, pos, decision if reopening else "")
    elif kind == "park":
        apply_move(bl, it, SEC_PARKED, None, decision)
    else:
        pos = None
        if kind == "set-type":
            tspec, pos = split_position(spec)
            parts = tspec.split(",")
            who = None
            for p in parts[1:]:
                if not p.startswith("who:"):
                    raise Refused(f"unknown --then '{args.then}' (one of: {DECIDE_ACTIONS})")
                who = p[len("who:"):]
            if parts[0] == "decision":
                raise Refused("set-type makes the decision work: a type other than decision")
            added = change_type(bl, it, parts[0], who)
        after = expected_section(it)
        if after and after != before:
            bl.place_row(it.slug, after, pos)
            moved = f"moved to '{after}' (type / who changed)" + (f" at position {pos}" if pos else "")
        elif pos is not None:
            raise Refused(f"@{pos} places the row when the type / who move it to another section; it stays in '{after}'")
    bl.save_item(it)
    if added:
        notice(f"added the sections {', '.join(added)} with placeholders - write them")
    if moved:
        notice(moved)
    bl.save_overview()
    return finish(bl, f"decided {it.slug}: option {key}, then {args.then}")


def cmd_reply(bl: Backlog, args) -> int:
    it = bl.item(args.slug)
    path = it.folder / "reply.md"
    if not path.is_file():
        raise Refused(f"'{it.slug}' has no reply.md (only an item imported from GitHub has one)")
    try:
        lines = read_text(path).split("\n")
    except UnicodeDecodeError:
        raise Refused(f"{rel(bl.root, path)} is not valid UTF-8")
    lines[0] = "state: " + ("not-sent" if args.state == "not-sent" else f"sent {today()}")
    touch(it, f"reply marked {args.state}")
    write_text(path, "\n".join(lines))
    bl.save_item(it)
    bl.save_overview()
    return finish(bl, f"reply of {it.slug}: {lines[0]}")


# ---------------------------------------------------------------------------
# Command line


def build_parser() -> argparse.ArgumentParser:
    # bin/backlog.sh names itself (feature 342)
    p = argparse.ArgumentParser(prog=os.environ.get("TANDEM_BACKLOG_PROG", "backlog.py"),
                                description="Check and change the backlog (feature 242).")
    p.add_argument("--root", help="repository root (default: the repository containing this script)")
    p.add_argument("--lock-dir", help=argparse.SUPPRESS)  # tests
    # feature 344: options for programs (the backlog web app)
    p.add_argument("--json", action="store_true", dest="g_json",
                   help="JSON output: one result object of a changing command, the JSON form of a read command")
    p.add_argument("--input-json", metavar="-",
                   help="take the text fields from one JSON object on standard input")
    p.add_argument("--ref", dest="g_ref", metavar="REF",
                   help="board, list, show, next, legend: read backlog/ from the git objects of REF")
    sub = p.add_subparsers(dest="command", required=True)
    SUBPARSERS.clear()

    def cmd(name, **kw):
        s = sub.add_parser(name, **kw)
        SUBPARSERS[name] = s
        if name != "lock":
            s.add_argument("--json", action="store_true", help=argparse.SUPPRESS if name in CHANGING else None)
        if name in READ_REF:
            s.add_argument("--ref", metavar="REF", help="read backlog/ from the git objects of REF (no working-tree file)")
        return s

    cmd("check", help="run every rule; TOTAL: n")
    cmd("sync", help="rewrite derived cells and numbering of BACKLOG.md")

    s = cmd("list", help="items in backlog order")
    s.add_argument("--section")
    s.add_argument("--area")
    s.add_argument("--type")
    s.add_argument("--status")
    s.add_argument("--who")
    s.add_argument("--min-severity", type=int)
    s.add_argument("--needs", metavar="SLUG", help="only items whose depends-on names SLUG")
    s.add_argument("--related-to", metavar="SLUG", help="only items whose related names SLUG")

    s = cmd("next", help="the item an autonomous run would take")
    s.add_argument("--slug")

    s = cmd("board", help="the whole overview: sections, rows, Last triaged, unreadable items")
    s.add_argument("--with-body", action="store_true", help="add each item's body and issue.md")

    s = cmd("show", help="one item: header, section, body sections, log, steps, options, files, findings")
    s.add_argument("slug")

    cmd("legend", help="the vocabularies of the legend with their meanings")

    s = cmd("new", help="create an item in Inbox")
    s.add_argument("--title", help="required (or 'title' from --input-json)")
    s.add_argument("--type", required=True)
    s.add_argument("--severity", required=True, type=int)
    s.add_argument("--area", required=True)
    s.add_argument("--source", default="manual")
    s.add_argument("--who", default="agent")
    s.add_argument("--effort")
    s.add_argument("--related")
    s.add_argument("--depends-on")
    s.add_argument("--slug")
    s.add_argument("--problem")
    s.add_argument("--evidence")
    s.add_argument("--expected")

    s = cmd("import-github", help="create an item from a GitHub issue, or from every new issue with a label")
    s.add_argument("number", type=int, nargs="?")
    s.add_argument("--label", help="import every open issue with this label not yet in the backlog")
    s.add_argument("--dry-run", action="store_true", help="with --label: list what would be imported, write nothing")
    s.add_argument("--area", help="required with a number; with --label the default is panels-ui (help-docs for documentation)")
    s.add_argument("--type", help="default: from the issue's labels (bug -> bug, enhancement -> feature, documentation -> improvement), else bug")
    s.add_argument("--severity", type=int, default=5)
    s.add_argument("--slug")

    s = cmd("set", help="change header fields (not status)")
    s.add_argument("slug")
    s.add_argument("pairs", nargs="*", metavar="key=value")
    s.add_argument("--log")
    s.add_argument("--position", type=int, help="when type / who move the row to another section: its position there")

    s = cmd("log", help="append a log line")
    s.add_argument("slug")
    s.add_argument("text", nargs="?")

    s = cmd("verify", help="stamp verified with today and a commit")
    s.add_argument("slug")
    s.add_argument("--commit")
    s.add_argument("--note")

    s = cmd("move", help="move an item to a section / position")
    s.add_argument("slug")
    s.add_argument("--section", required=True)
    s.add_argument("--position", type=int)
    s.add_argument("--reason")

    s = cmd("block", help="open -> blocked")
    s.add_argument("slug")
    s.add_argument("--reason", help="required (or 'reason' from --input-json)")

    s = cmd("unblock", help="blocked -> open")
    s.add_argument("slug")
    s.add_argument("--note")

    s = cmd("start", help="open -> in-progress (autonomous run)")
    s.add_argument("slug")
    s.add_argument("--feature", required=True)

    s = cmd("remove", help="delete an item: its feature closed it (--feature) or it is closed without one (--reason)")
    s.add_argument("slug")
    s.add_argument("--feature")
    s.add_argument("--reason")
    s.add_argument("--force", action="store_true")

    s = cmd("reorder", help="the new order of an ordered section (stdin {\"order\": [slug, ...]}); no item log line")
    s.add_argument("--section", required=True)

    s = cmd("body", help="replace, add or remove one body section (stdin {\"markdown\": text} or {\"remove\": true})")
    s.add_argument("slug")
    s.add_argument("--section", required=True)

    s = cmd("step", help="tick or untick the n-th checklist line of Steps")
    s.add_argument("slug")
    s.add_argument("n", type=int)
    g = s.add_mutually_exclusive_group(required=True)
    g.add_argument("--done", action="store_true")
    g.add_argument("--undone", action="store_true")

    s = cmd("decide", help="record a maintainer decision (stdin {\"decision\": text}) and apply it")
    s.add_argument("slug")
    s.add_argument("--option", required=True)
    s.add_argument("--then", required=True, metavar="ACTION", help=DECIDE_ACTIONS)
    s.add_argument("--type", help="with move:<section> or keep: change the type first")

    s = cmd("reply", help="mark the reply to a GitHub issue (reply.md) sent or not sent")
    s.add_argument("slug")
    s.add_argument("--state", required=True, choices=["not-sent", "sent"])

    s = cmd("run-log", help="append a row to RUNS.md")
    s.add_argument("--outcome", required=True)
    s.add_argument("--slug")
    s.add_argument("--feature")
    s.add_argument("--branch")
    s.add_argument("--inbox", type=int, default=0)
    s.add_argument("--person")
    s.add_argument("--note")

    s = cmd("lock", help="the lock of autonomous runs")
    s.add_argument("action", choices=["acquire", "update", "release", "status"])
    s.add_argument("--slug")
    s.add_argument("--branch")
    s.add_argument("--force", action="store_true")
    return p


COMMANDS = {
    "check": cmd_check, "sync": cmd_sync, "list": cmd_list, "next": cmd_next,
    "board": cmd_board, "show": cmd_show, "legend": cmd_legend,
    "new": cmd_new, "import-github": cmd_import_github, "set": cmd_set,
    "log": cmd_log, "verify": cmd_verify, "move": cmd_move, "block": cmd_block,
    "unblock": cmd_unblock, "start": cmd_start, "remove": cmd_remove,
    "reorder": cmd_reorder, "body": cmd_body, "step": cmd_step, "decide": cmd_decide,
    "reply": cmd_reply, "run-log": cmd_run_log, "lock": cmd_lock,
}
SUBPARSERS: dict = {}
READ_REF = ("board", "list", "show", "next", "legend")
CHANGING = ("sync", "new", "import-github", "set", "log", "verify", "move", "block", "unblock", "start",
            "remove", "reorder", "body", "step", "decide", "reply", "run-log")
# changing commands whose positional slug is the item they change
SLUG_COMMANDS = ("set", "log", "verify", "move", "block", "unblock", "start", "remove", "body", "step",
                 "decide", "reply", "run-log")
# --input-json: the keys each command takes (contracts/backlog-cli-additions.md of feature 344)
BODY_KEYS = ("problem", "evidence", "expected", "approach", "notes", "question", "options", "recommendation", "steps")
INPUT_KEYS = {
    "new": ("title",) + BODY_KEYS,
    "set": ("title", "log"),
    "log": ("text",),
    "verify": ("note",),
    "move": ("reason",), "block": ("reason",), "remove": ("reason",),
    "unblock": ("note",),
    "body": ("markdown", "remove", "log"),
    "decide": ("decision",),
    "step": ("note",),
    "reorder": ("order",),
}
# attributes a command reads that only --input-json sets
STDIN_ONLY = ("approach", "notes", "question", "options", "recommendation", "steps", "markdown", "remove",
              "decision", "order", "log", "note")


def usage_exit(message: str) -> None:
    print(f"usage: {message}", file=sys.stderr)
    raise SystemExit(2)


def read_input_json() -> tuple:
    """The JSON object on stdin and the keys it repeats; a usage error (exit 2)
    when it is not one JSON object - nothing has been read from the backlog yet."""
    buf = getattr(sys.stdin, "buffer", None)
    try:
        raw = buf.read().decode("utf-8") if buf is not None else sys.stdin.read()
    except UnicodeDecodeError as e:
        usage_exit(f"invalid JSON on stdin (not UTF-8 at byte {e.start})")
    if raw.startswith("﻿"):
        raw = raw[1:]
    repeated = []

    def pairs(items):
        obj = {}
        for k, v in items:
            if k in obj and k not in repeated:
                repeated.append(k)
            obj[k] = v
        return obj
    try:
        data = json.loads(raw, object_pairs_hook=pairs)
    except ValueError as e:
        usage_exit(f"invalid JSON on stdin ({e})")
    if not isinstance(data, dict):
        usage_exit("invalid JSON on stdin (one object {...} expected)")
    return data, repeated


def apply_input_json(args, data: dict, repeated: list) -> None:
    """Take the text fields from the JSON object into args (refused: a key given
    twice, an unknown key, a value of the wrong kind)."""
    if repeated:
        raise Refused(f"{repeated[0]} given twice")
    allowed = INPUT_KEYS[args.command]
    for key, value in data.items():
        if key not in allowed:
            raise Refused(f"unknown key '{key}' for '{args.command}' (allowed: {', '.join(allowed)})")
        if key == "order":
            if not isinstance(value, list) or not all(isinstance(s, str) for s in value):
                raise Refused("'order' must be a list of slugs")
        elif key == "remove":
            if value is not True:
                raise Refused("'remove' must be true")
        elif not isinstance(value, str):
            raise Refused(f"the value of '{key}' must be a string")
    for key, value in data.items():
        if args.command == "set" and key == "title":
            if any(p.split("=", 1)[0].strip() == "title" for p in args.pairs):
                raise Refused("title given twice")
            args.pairs.append("title=" + value)
            continue
        attr = "text" if args.command == "log" else key
        if getattr(args, attr, None) is not None:
            raise Refused(f"{key} given twice")
        if key in BODY_KEYS or key == "markdown":
            value = body_text(value)
        setattr(args, attr, value)


def require_texts(args) -> None:
    """What argparse required before --input-json existed is still required."""
    need = {"new": ("title", "--title"), "log": ("text", "text"), "block": ("reason", "--reason"),
            "decide": ("decision", "{\"decision\": text} from --input-json -"),
            "reorder": ("order", "{\"order\": [slug, ...]} from --input-json -")}
    if args.command in need and getattr(args, need[args.command][0], None) is None:
        SUBPARSERS[args.command].error(f"the following arguments are required: {need[args.command][1]}")
    if args.command == "set" and not args.pairs:
        SUBPARSERS["set"].error("the following arguments are required: key=value")
    if args.command == "body" and args.markdown is None and args.remove is None:
        SUBPARSERS["body"].error("the following arguments are required: {\"markdown\": text} or {\"remove\": true} from --input-json -")


def normalize_args(parser, args) -> None:
    """Merge the global and the command's --json / --ref; refuse (usage) an
    option the command does not take."""
    args.json = bool(getattr(args, "json", False) or args.g_json)
    ref = getattr(args, "ref", None) or args.g_ref
    if ref and args.command not in READ_REF:
        parser.error(f"--ref is for the read commands {', '.join(READ_REF)}, not '{args.command}'")
    args.ref = ref
    if args.json and args.command == "lock":
        parser.error("--json is not available for 'lock'")
    if args.input_json is not None:
        if args.input_json != "-":
            parser.error("--input-json takes '-' (standard input)")
        if args.command not in INPUT_KEYS:
            parser.error(f"--input-json is not for '{args.command}'")
    for attr in STDIN_ONLY:
        if not hasattr(args, attr):
            setattr(args, attr, None)


def result_json(root: Path, refused: str | None = None) -> str:
    section = position = None
    if refused is None:
        if OUT.section:
            section = OUT.section
        elif OUT.slugs and OUT.bl is not None:
            section, position = row_place(OUT.bl.ov, OUT.slugs[0])
    return json.dumps({
        "ok": refused is None, "refused": refused, "slugs": list(OUT.slugs),
        "section": section, "position": position, "notices": list(OUT.notices),
        "findings": [finding_json(f) for f in OUT.findings],
        "written": [rel(root, p) for p in _WRITTEN],
    }, ensure_ascii=False)


def main(argv=None) -> int:
    global OUT
    try:
        # LF also on Windows: the output is read by shell loops and skills
        sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    except (AttributeError, ValueError):
        pass
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
        normalize_args(parser, args)
        data = read_input_json() if args.input_json is not None else None
    except SystemExit as e:
        return 2 if e.code else 0
    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parents[2]
    OUT = Output(json=args.json and args.command in CHANGING)
    _WRITTEN.clear()
    if args.command in SLUG_COMMANDS and isinstance(getattr(args, "slug", None), str):
        OUT.slugs.append(args.slug)
    try:
        if data is not None:
            apply_input_json(args, *data)
        require_texts(args)
        bl = Backlog(root, GitSource(root, args.ref) if args.ref else None)
        OUT.bl = bl
        code = COMMANDS[args.command](bl, args)
    except SystemExit as e:
        return 2 if e.code else 0
    except Refused as e:
        if OUT.json:
            print(result_json(root, str(e)))
        else:
            print(f"refused: {e}")
        return 1
    if OUT.json:
        print(result_json(root))
    return code


if __name__ == "__main__":
    sys.exit(main())
