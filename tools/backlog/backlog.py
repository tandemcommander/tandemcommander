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

Standard library only: the build already requires Python, nothing else.
Exit codes: 0 success / no findings, 1 findings or refused, 2 usage error.
"""

from __future__ import annotations

import argparse
import datetime as dt
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


def one_line(text: str, what: str) -> str:
    """A header value or reason: one line, no control characters."""
    if CONTROL_RE.search(text or ""):
        raise Refused(f"{what} must be one line without control characters")
    return (text or "").strip()


def flatten(text: str) -> str:
    """Log lines and journal cells: whitespace runs (also line breaks) -> one space."""
    return re.sub(r"\s+", " ", text or "").strip()


def first_line(path: Path) -> str:
    """First line of a text file; a marker the format rules never accept if unreadable."""
    try:
        return read_text(path).split("\n", 1)[0].strip()
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


def parse_item(folder: Path) -> Item:
    item = Item(slug=folder.name, folder=folder)
    path = item.path
    try:
        raw = read_text(path)
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


def parse_overview(path: Path) -> Overview:
    try:
        raw = read_text(path)
    except UnicodeDecodeError as e:
        ov = Overview(path=path, lines=[])
        ov.errors.append((1, "overview", f"not valid UTF-8 (byte {e.start}); save the file as UTF-8 without BOM"))
        return ov
    ov = Overview(path=path, lines=raw.split("\n"))
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
        values = []
        if blocks:
            a, b = blocks[0]
            first = a + 2 if b - a >= 2 and is_separator(lines[a + 1]) else a + 1
            for r in range(first, b):
                cells = split_row(lines[r])
                if cells and cells[0]:
                    values.append(unbacktick(cells[0]))
        ov.legend[name] = values
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
    def __init__(self, root: Path):
        self.root = root
        self.dir = root / "backlog"
        self.items_dir = self.dir / "items"
        self.overview_path = self.dir / "BACKLOG.md"
        self.runs_path = self.dir / "RUNS.md"
        self.release_path = self.dir / "RELEASE.md"
        self.items: dict = {}
        self.ov: Overview | None = None
        self.load()

    def load(self) -> None:
        self.items = {}
        if self.items_dir.is_dir():
            for folder in sorted(p for p in self.items_dir.iterdir() if p.is_dir()):
                if (folder / "desc.md").is_file():
                    self.items[folder.name] = parse_item(folder)
        self.ov = parse_overview(self.overview_path) if self.overview_path.is_file() else None

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
    F = []

    def add(path, line, rule, msg):
        F.append((rel(root, path) if isinstance(path, Path) else path, line, rule, msg))

    if not bl.dir.is_dir():
        add(bl.dir, 1, "layout", "backlog/ folder missing")
        return F
    for entry in sorted(bl.dir.iterdir()):
        if entry.name not in TOP_LEVEL:
            add(entry, 1, "layout", "unexpected entry at the top level of backlog/")
    for name in ("BACKLOG.md", "RUNS.md", "RELEASE.md"):
        if not (bl.dir / name).is_file():
            add(bl.dir / name, 1, "layout", f"{name} missing")
    if bl.items_dir.is_dir():  # a missing items/ is an empty backlog (git keeps no empty folder)
        for entry in sorted(bl.items_dir.iterdir()):
            if not entry.is_dir():
                add(entry, 1, "layout", "only item folders belong in backlog/items/")
                continue
            if not valid_slug(entry.name):
                add(entry, 1, "slug", f"folder name '{entry.name}' is not a slug (^[a-z0-9]+(-[a-z0-9]+)*$, max {SLUG_MAX})")
            if not (entry / "desc.md").is_file():
                add(entry, 1, "desc-missing", "item folder without desc.md")
            for sub in sorted(entry.iterdir()):
                if sub.name in ITEM_FILES and sub.is_file():
                    continue
                if sub.name in ITEM_DIRS and sub.is_dir():
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
            if not any(p.is_dir() and p.name.startswith(h["feature"] + "-") for p in (specs.iterdir() if specs.is_dir() else [])):
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
            if not issue.is_file():
                add(issue, 1, "github", "source github#N needs issue.md")
            else:
                first = first_line(issue)
                if first != f"number: {num}":
                    add(issue, 1, "github", f"first line must be 'number: {num}'")
        reply = it.folder / "reply.md"
        if reply.is_file():
            first = first_line(reply)
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

    if bl.runs_path.is_file():
        F.extend(runs_findings(bl))
    F.sort(key=lambda f: (f[0], f[1], f[2]))
    return F


def runs_findings(bl: Backlog) -> list:
    out = []
    path = rel(bl.root, bl.runs_path)
    try:
        lines = read_text(bl.runs_path).split("\n")
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


def finish(bl: Backlog, ok_message: str | None = None) -> int:
    """Run the full check after a change; report and return the exit code."""
    bl.load()
    findings = check(bl)
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
    while True:
        batch = fetch_json(f"{url}?per_page=100&page={page}")
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


def new_item_text(header: dict, problem: str, evidence: str, expected: str) -> str:
    t = header["type"]
    body = ["", f"# {header['title']}", "",
            "## Problem", "", problem or "(to be written)", "",
            "## Evidence", "", evidence or "(to be written)", "",
            "## Expected", "", expected or "(to be written)", ""]
    if t == "decision":
        body += ["## Question", "", "(to be written)", "",
                 "## Options", "", "(to be written)", "",
                 "## Recommendation", "", "(to be written)", ""]
    if t == "person-step":
        body += ["## Steps", "", "- [ ] (to be written)", ""]
    body += ["## Log", "", f"- {today()} {EMDASH} created (source {header['source']})"]
    head = ["---"] + [f"{k}: {format_header_value(k, header[k])}" for k in HEADER_KEYS] + ["---"]
    return "\n".join(head + body) + "\n"


def create_item(bl: Backlog, header: dict, slug: str | None, problem="", evidence="", expected="") -> Item:
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
    probe = Item(slug=slug, folder=folder, header=dict(header), ok=True)
    probe.header_lines = {k: 1 for k in HEADER_KEYS}
    errs = validate_item(bl, probe)
    if errs:
        raise Refused("invalid values: " + "; ".join(errs))
    folder.mkdir(parents=True)
    write_text(folder / "desc.md", new_item_text(header, problem, evidence, expected))
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
        chosen = None
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
            chosen = row.slug
            break
    if args.json:
        print(json.dumps({"slug": chosen, "skipped": skipped}, ensure_ascii=False))
    else:
        for s in skipped:
            print(f"skipped: {s['slug']}: {s['reason']}")
        print(chosen or "nothing-to-do")
    return 0


def cmd_new(bl: Backlog, args) -> int:
    header = base_header(args, args.source, args.title)
    it = create_item(bl, header, args.slug, args.problem or "", args.evidence or "", args.expected or "")
    print(it.slug)
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
    if any(c.startswith("title=") for c in changes):
        set_title_line(it, it.header["title"])
    added = ensure_type_sections(it)
    touch(it, args.log or "set " + ", ".join(changes))
    after_section = expected_section(it)
    bl.save_item(it)
    if added:
        print(f"added the sections {', '.join(added)} with placeholders - write them")
    if after_section != before_section and after_section:
        bl.place_row(it.slug, after_section)
        print(f"moved to '{after_section}' (type / who changed)")
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
    ov = bl.require_overview()
    it = bl.item(args.slug)
    target = resolve_section(args.section)
    reason = one_line(args.reason, "--reason") if args.reason else ""
    if args.position is not None and args.position < 1:
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
    if args.position and target in ORDERED:
        text += f" position {args.position}"
    touch(it, text + note)
    bl.save_item(it)
    bl.place_row(it.slug, target, args.position)
    if target != SEC_INBOX:
        bl.touch_triaged()
    bl.save_overview()
    return finish(bl, f"{it.slug}: {current or 'no row'} -> {target}")


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
    if sys.version_info >= (3, 12):
        shutil.rmtree(folder, onexc=onexc)
    else:  # pragma: no cover
        shutil.rmtree(folder, onerror=lambda f, p, e: onexc(f, p, e))


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
    return finish(bl, f"removed {it.slug} ({why})")


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


def cmd_import_github(bl: Backlog, args) -> int:
    num = str(args.number)
    for it in bl.items.values():
        if it.ok and it.header.get("source") == f"github#{num}":
            raise Refused(f"issue #{num} is already imported as '{it.slug}'")
    base = f"https://api.github.com/repos/{GITHUB_REPO}/issues/{num}"
    try:
        issue = fetch_json(base)
        comments = fetch_all(base + "/comments") if issue.get("comments") else []
    except (urllib.error.URLError, OSError, ValueError) as e:
        raise Refused(f"cannot read issue #{num}: {e}")
    if "pull_request" in issue:
        raise Refused(f"#{num} is a pull request, not an issue")
    if len(comments) != int(issue.get("comments") or 0):
        raise Refused(f"issue #{num} has {issue.get('comments')} comments but {len(comments)} were read; nothing written")
    title = (issue.get("title") or "").strip()
    body_text = (issue.get("body") or "").replace("\r\n", "\n").strip()
    url = issue.get("html_url", f"https://github.com/{GITHUB_REPO}/issues/{num}")
    header = base_header(args, f"github#{num}", title)
    header["who"] = "agent"
    it = create_item(bl, header, args.slug,
                     problem=problem_paragraph(body_text) or "(see issue.md)",
                     evidence=f"GitHub issue #{num}: {url} - original text in `issue.md`.",
                     expected="(to be written)")
    created = (issue.get("created_at") or "")[:10]
    lines = [f"number: {num}", f"url: {url}",
             f"author: {(issue.get('user') or {}).get('login', '?')}",
             f"created: {created}", "", f"# {title}", "", body_text or "(empty)"]
    if comments:
        lines += ["", "## Comments"]
        for c in comments:
            lines += ["", f"### {(c.get('user') or {}).get('login', '?')}, {(c.get('created_at') or '')[:10]}", "",
                      (c.get("body") or "").replace("\r\n", "\n").strip()]
    write_text(it.folder / "issue.md", "\n".join(lines) + "\n")
    write_text(it.folder / "reply.md", "state: not-sent\n\n(draft of the reply to the issue thread)\n")
    print(it.slug)
    return finish(bl)


# ---------------------------------------------------------------------------
# Command line


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="backlog.py", description="Check and change the backlog (feature 242).")
    p.add_argument("--root", help="repository root (default: the repository containing this script)")
    p.add_argument("--lock-dir", help=argparse.SUPPRESS)  # tests
    sub = p.add_subparsers(dest="command", required=True)

    sub.add_parser("check", help="run every rule; TOTAL: n")
    sub.add_parser("sync", help="rewrite derived cells and numbering of BACKLOG.md")

    s = sub.add_parser("list", help="items in backlog order")
    s.add_argument("--section")
    s.add_argument("--area")
    s.add_argument("--type")
    s.add_argument("--status")
    s.add_argument("--who")
    s.add_argument("--min-severity", type=int)
    s.add_argument("--needs", metavar="SLUG", help="only items whose depends-on names SLUG")
    s.add_argument("--related-to", metavar="SLUG", help="only items whose related names SLUG")
    s.add_argument("--json", action="store_true")

    s = sub.add_parser("next", help="the item an autonomous run would take")
    s.add_argument("--slug")
    s.add_argument("--json", action="store_true")

    s = sub.add_parser("new", help="create an item in Inbox")
    s.add_argument("--title", required=True)
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

    s = sub.add_parser("import-github", help="create an item from a GitHub issue")
    s.add_argument("number", type=int)
    s.add_argument("--area", required=True)
    s.add_argument("--type", default="bug")
    s.add_argument("--severity", type=int, default=5)
    s.add_argument("--slug")

    s = sub.add_parser("set", help="change header fields (not status)")
    s.add_argument("slug")
    s.add_argument("pairs", nargs="+", metavar="key=value")
    s.add_argument("--log")

    s = sub.add_parser("log", help="append a log line")
    s.add_argument("slug")
    s.add_argument("text")

    s = sub.add_parser("verify", help="stamp verified with today and a commit")
    s.add_argument("slug")
    s.add_argument("--commit")
    s.add_argument("--note")

    s = sub.add_parser("move", help="move an item to a section / position")
    s.add_argument("slug")
    s.add_argument("--section", required=True)
    s.add_argument("--position", type=int)
    s.add_argument("--reason")

    s = sub.add_parser("block", help="open -> blocked")
    s.add_argument("slug")
    s.add_argument("--reason", required=True)

    s = sub.add_parser("unblock", help="blocked -> open")
    s.add_argument("slug")
    s.add_argument("--note")

    s = sub.add_parser("start", help="open -> in-progress (autonomous run)")
    s.add_argument("slug")
    s.add_argument("--feature", required=True)

    s = sub.add_parser("remove", help="delete an item: its feature closed it (--feature) or it is closed without one (--reason)")
    s.add_argument("slug")
    s.add_argument("--feature")
    s.add_argument("--reason")
    s.add_argument("--force", action="store_true")

    s = sub.add_parser("run-log", help="append a row to RUNS.md")
    s.add_argument("--outcome", required=True)
    s.add_argument("--slug")
    s.add_argument("--feature")
    s.add_argument("--branch")
    s.add_argument("--inbox", type=int, default=0)
    s.add_argument("--person")
    s.add_argument("--note")

    s = sub.add_parser("lock", help="the lock of autonomous runs")
    s.add_argument("action", choices=["acquire", "update", "release", "status"])
    s.add_argument("--slug")
    s.add_argument("--branch")
    s.add_argument("--force", action="store_true")
    return p


COMMANDS = {
    "check": cmd_check, "sync": cmd_sync, "list": cmd_list, "next": cmd_next,
    "new": cmd_new, "import-github": cmd_import_github, "set": cmd_set,
    "log": cmd_log, "verify": cmd_verify, "move": cmd_move, "block": cmd_block,
    "unblock": cmd_unblock, "start": cmd_start, "remove": cmd_remove,
    "run-log": cmd_run_log, "lock": cmd_lock,
}


def main(argv=None) -> int:
    try:
        # LF also on Windows: the output is read by shell loops and skills
        sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    except (AttributeError, ValueError):
        pass
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as e:
        return 2 if e.code else 0
    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parents[2]
    try:
        bl = Backlog(root)
        return COMMANDS[args.command](bl, args)
    except Refused as e:
        print(f"refused: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
