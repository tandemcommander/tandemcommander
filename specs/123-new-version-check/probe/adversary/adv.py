#!/usr/bin/env python3
"""Differential tester for src/common/salupdcheck.h (feature 123).

Generates inputs, decides with Python's json module (and small independent
reference rules) what each input "really" says, runs the C++ harness over
the same inputs and compares.

    python adv.py --seed 1 --count 20000 --exe bin\\adv_o2_J.exe [--exe ...]

Every generator is seeded with (seed, generator name); a failure reproduces
with the same --seed/--count/--only. Mismatching inputs are saved under
out/mismatch/.
"""
import argparse
import datetime
import json
import os
import random
import re
import struct
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE = os.path.join(HERE, "..", "fixtures", "real-0.1.8.json")
REAL = open(FIXTURE, "rb").read()

MAX_ANSWER = 256 * 1024
MAX_DEPTH = 32
ERR = ["None", "NotJson", "MissingField", "Duplicate", "Draft", "Prerelease", "BadTag", "BadTime",
       "ForeignNotes", "NoInstaller"]
READ = ("draft", "prerelease", "tag_name", "published_at", "html_url", "assets")
REL = "https://github.com/tandemcommander/tandemcommander/releases/"


def notes_url(v):
    return "%stag/v%d.%d.%d" % ((REL,) + tuple(v))


def inst_name(v):
    return "tandemcommander-%d.%d.%d-x64-setup.exe" % tuple(v)


def inst_url(v):
    return "%sdownload/v%d.%d.%d/%s" % ((REL,) + tuple(v) + (inst_name(v),))


# ---------------------------------------------------------------------------
# the oracle
# ---------------------------------------------------------------------------

class Obj(list):
    """a JSON object as the list of its (name, value) pairs, in order, duplicates kept"""


def _no_constant(name):
    raise ValueError("constant " + name)


def _depth(v):
    # iterative: nesting depth of containers
    best = 0
    stack = [(v, 1)]
    while stack:
        x, d = stack.pop()
        if isinstance(x, Obj):
            best = max(best, d)
            for _, y in x:
                if isinstance(y, list):
                    stack.append((y, d + 1))
        elif isinstance(x, list):
            best = max(best, d)
            for y in x:
                if isinstance(y, list):
                    stack.append((y, d + 1))
    return best


def parse_json(text):
    """returns (value, None) or (None, reason)"""
    try:
        v = json.loads(text, object_pairs_hook=Obj, parse_constant=_no_constant,
                       parse_int=lambda s: 0, parse_float=lambda s: 0.0)
    except RecursionError:
        return None, "depth"
    except ValueError:
        return None, "json"
    if _depth(v) > MAX_DEPTH:
        return None, "depth"
    return v, None


TAG_RE = re.compile(r"v([0-9]{1,5})\.([0-9]{1,5})\.([0-9]{1,5})\Z")
TIME_RE = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})Z\Z")
EPOCH = datetime.datetime(1601, 1, 1)


def parse_time(s):
    m = TIME_RE.match(s)
    if not m:
        return None
    y, mo, d, h, mi, sec = (int(x) for x in m.groups())
    if y < 1601:
        return None
    try:
        t = datetime.datetime(y, mo, d, h, mi, sec)
    except ValueError:
        return None
    delta = t - EPOCH
    return (delta.days * 86400 + delta.seconds) * 10000000


def judge_record(v):
    """the rules of contracts/update-source.md on a parsed top-level value -> (err, version, filetime)"""
    if not isinstance(v, Obj):
        return "NotJson", None, None
    count = {k: 0 for k in READ}
    first = {}
    for k, val in v:
        if k in count:
            count[k] += 1
            first.setdefault(k, val)
    if any(c > 1 for c in count.values()):
        return "Duplicate", None, None
    if any(c == 0 for c in count.values()):
        return "MissingField", None, None
    if first["draft"] is not False:
        return "Draft", None, None
    if first["prerelease"] is not False:
        return "Prerelease", None, None
    tag = first["tag_name"]
    m = TAG_RE.match(tag) if isinstance(tag, str) else None
    if not m:
        return "BadTag", None, None
    ver = tuple(int(x) for x in m.groups())
    pub = first["published_at"]
    ft = parse_time(pub) if isinstance(pub, str) else None
    if ft is None:
        return "BadTime", None, None
    if first["html_url"] != notes_url(ver) or not isinstance(first["html_url"], str):
        return "ForeignNotes", None, None
    assets = first["assets"]
    found = False
    if isinstance(assets, list) and not isinstance(assets, Obj):
        for a in assets:
            if not isinstance(a, Obj):
                continue
            keys = [k for k, _ in a]
            if keys.count("name") != 1 or keys.count("state") != 1 or keys.count("browser_download_url") != 1:
                continue
            d = dict(a)
            if (isinstance(d["name"], str) and d["name"] == inst_name(ver) and
                    isinstance(d["state"], str) and d["state"] == "uploaded" and
                    isinstance(d["browser_download_url"], str) and d["browser_download_url"] == inst_url(ver)):
                found = True
    if not found:
        return "NoInstaller", None, None
    return "None", ver, ft


def oracle_record(data):
    """-> dict: g (grammar verdict of any value), err, ver, ft, utf8 (strictly valid UTF-8?)

    The verdict is taken on the bytes read as Latin-1: JSON's structure is ASCII, so this is the
    byte-exact reading (every member name and value the program compares is ASCII). 'utf8' tells
    separately whether a strict parser would have refused the text for its encoding.
    """
    try:
        data.decode("utf-8")
        utf8 = True
    except UnicodeDecodeError:
        utf8 = False
    v, why = parse_json(data.decode("latin-1"))
    g = v is not None or (why is None)
    if why is not None:
        g = False
    else:
        g = True
    if len(data) == 0 or len(data) > MAX_ANSWER or not g:
        return {"g": g, "err": "NotJson", "ver": None, "ft": None, "utf8": utf8}
    err, ver, ft = judge_record(v)
    return {"g": g, "err": err, "ver": ver, "ft": ft, "utf8": utf8}


def oracle_string(payload):
    """payload: u16 outSize + literal (valid UTF-8 by construction) -> (ok, bad, atEnd, outbytes)"""
    out_size = payload[0] | (payload[1] << 8)
    lit = payload[2:]
    try:
        text = lit.decode("utf-8")
    except UnicodeDecodeError:
        return None  # not judged
    i = 0
    while i < len(text) and text[i] in " \t\n\r":
        i += 1
    if i >= len(text) or text[i] != '"':
        return (0, 0, 0, b"")
    try:
        s, end = json.JSONDecoder().raw_decode(text, i)
    except ValueError:
        return (0, 0, 0, b"")
    if not isinstance(s, str):
        return (0, 0, 0, b"")
    at_end = 1 if text[end:].strip(" \t\n\r") == "" else 0
    bad = False
    if "\x00" in s or any(0xD800 <= ord(c) <= 0xDFFF for c in s):
        bad = True
        enc = b""
    else:
        enc = s.encode("utf-8")
        if not fits(s, out_size):
            bad = True
    return (1, 1 if bad else 0, at_end, b"" if bad else enc)


def fits(s, out_size):
    """the reader stores character by character and gives up at the first that does not fit"""
    o = 0
    for ch in s:
        n = len(ch.encode("utf-8"))
        if o + n >= out_size:
            return False
        o += n
    return True


VER_RE = re.compile(rb"([0-9]{1,5})\.([0-9]{1,5})\.([0-9]{1,5})\Z")


def oracle_version(payload):
    tag_form, explicit = payload[0] != 0, payload[1] != 0
    txt = payload[2:]
    if not explicit:
        txt = txt.split(b"\x00")[0]
    if tag_form:
        if txt[:1] != b"v":
            return (0, 0, 0, 0)
        txt = txt[1:]
    m = VER_RE.match(txt)
    if not m:
        return (0, 0, 0, 0)
    return (1,) + tuple(int(x) for x in m.groups())


def oracle_time(payload):
    explicit = payload[0] != 0
    txt = payload[1:]
    if not explicit:
        txt = txt.split(b"\x00")[0]
    try:
        s = txt.decode("ascii")
    except UnicodeDecodeError:
        return (0, 0)
    ft = parse_time(s)
    return (1, ft) if ft is not None else (0, 0)


LOOP_RE = re.compile(r"http://127\.0\.0\.1:([0-9]{1,5})(/[\x21\x22\x24-\x7e]*)\Z")


def oracle_loopback(payload):
    path_size = struct.unpack("<h", payload[:2])[0]
    units = struct.unpack("<%dH" % ((len(payload) - 2) // 2), payload[2:])
    if 0 in units:
        units = units[:units.index(0)]
    s = "".join(chr(u) for u in units)
    m = LOOP_RE.match(s)
    if not m or path_size <= 1:
        return (0, 0, b"")
    port = int(m.group(1))
    path = m.group(2)
    if port < 1 or port > 65535 or len(path) >= path_size:
        return (0, 0, b"")
    return (1, port, path.encode("utf-16-le"))


# ---------------------------------------------------------------------------
# serialising a Python structure as JSON text in many spellings
# ---------------------------------------------------------------------------

class Raw(str):
    """a token written as it is (numbers, literals)"""


SHORT = {'"': '\\"', "\\": "\\\\", "\b": "\\b", "\f": "\\f", "\n": "\\n", "\r": "\\r", "\t": "\\t", "/": "\\/"}


def uesc(o, rng):
    h = "%04x" % o
    return "\\u" + (h.upper() if rng.random() < 0.4 else h)


def ser_str(s, rng, pe):
    out = ['"']
    for ch in s:
        o = ord(ch)
        must = o < 0x20 or ch in '"\\' or 0xD800 <= o <= 0xDFFF
        if must or rng.random() < pe:
            if ch in SHORT and not (ch == "/" and not must and rng.random() < 0.5) and rng.random() < 0.6:
                out.append(SHORT[ch])
            elif o > 0xFFFF:
                o -= 0x10000
                out.append(uesc(0xD800 + (o >> 10), rng) + uesc(0xDC00 + (o & 0x3FF), rng))
            else:
                out.append(uesc(o, rng))
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def ws(rng, pw):
    if rng.random() >= pw:
        return ""
    return "".join(rng.choice(" \t\n\r") for _ in range(rng.randint(1, 3)))


def ser(v, rng, pe=0.0, pw=0.0):
    if isinstance(v, Raw):
        return str(v)
    if v is True:
        return "true"
    if v is False:
        return "false"
    if v is None:
        return "null"
    if isinstance(v, str):
        return ser_str(v, rng, pe)
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, Obj):
        parts = []
        for k, x in v:
            parts.append(ws(rng, pw) + ser_str(k, rng, pe) + ws(rng, pw) + ":" + ws(rng, pw) + ser(x, rng, pe, pw) + ws(rng, pw))
        return "{" + (",".join(parts) if parts else ws(rng, pw)) + "}"
    if isinstance(v, list):
        parts = [ws(rng, pw) + ser(x, rng, pe, pw) + ws(rng, pw) for x in v]
        return "[" + (",".join(parts) if parts else ws(rng, pw)) + "]"
    raise TypeError(type(v))


# ---------------------------------------------------------------------------
# value pools
# ---------------------------------------------------------------------------

NUMS = ["0", "-0", "1", "-1", "392460282", "1e5", "1E+5", "-1.5e-3", "0.0", "1" * 400, "1e99999", "-0.0e-0", "4.9e-324"]
JUNK_STR = ['"tag_name":"v9.9.9"', "}", "{", "]", "[", '\\', '"', "\n", "\u010d", "\U0001F4C1", "\ud83d", "\udcc1", "\x00",
            "\x7f", "\u2028", "\ufeff", "\ufffd", "", "x" * 600, inst_url((9, 9, 9)), notes_url((9, 9, 9)), "uploaded", "false"]


def junk(rng, depth=0):
    r = rng.random()
    if depth > 3 or r < 0.35:
        return rng.choice(JUNK_STR) if rng.random() < 0.6 else "".join(rng.choice("ab{}[]\":,\\ /\u00e9") for _ in range(rng.randint(0, 12)))
    if r < 0.5:
        return Raw(rng.choice(NUMS))
    if r < 0.6:
        return rng.choice([True, False, None])
    if r < 0.8:
        return [junk(rng, depth + 1) for _ in range(rng.randint(0, 3))]
    return Obj((rng.choice(["a", "id", "url", "name", "state", "tag_name", "assets", "draft", "html_url", "browser_download_url", ""]),
                junk(rng, depth + 1)) for _ in range(rng.randint(0, 3)))


def pick_version(rng):
    r = rng.random()
    if r < 0.3:
        return (0, 1, 9)
    if r < 0.4:
        return (0, 1, 8)
    if r < 0.5:
        return rng.choice([(0, 0, 0), (99999, 99999, 99999), (1, 0, 0), (10, 20, 30), (0, 0, 1), (65536, 0, 0)])
    return (rng.randint(0, 99999), rng.randint(0, 120), rng.randint(0, 99999))


def bad_tag(rng, v):
    a, b, c = v
    c0 = "v%d.%d.%d" % v
    return rng.choice([
        "V%d.%d.%d" % v, "%d.%d.%d" % v, "v0%d.%d.%d" % v, "v%d.0%d.%d" % v, "v%d.%d.0%d" % v, "v%d.%d.%06d" % v,
        "v%d.%d.%05d" % v, "v%d.%d" % (a, b), c0 + ".0", c0 + " ", " " + c0, c0 + "\n", c0 + "-beta", c0 + "\x00", c0 + "\x00x",
        "v+%d.%d.%d" % v, "v-%d.%d.%d" % v, "v%d,%d,%d" % v, "v\uff10.%d.%d" % (b, c), "v\u0661.%d.%d" % (b, c), "",
        "v", "vv%d.%d.%d" % v, "v%d.%d.%d" % (a + 100000, b, c), "v%d.%d.%d" % (a, b, c + 1), "v%d.%d.%d" % (a, b + 1, c),
        "v%d..%d" % (a, c), "v%d.%d.%d." % v, c0 + "\ud83d", c0 + "\u200b", "v1e1.%d.%d" % (b, c), "v0x1.%d.%d" % (b, c),
        "latest", c0 + "/", c0 + "/../v0.0.1", "v4294967296.%d.%d" % (b, c), "v4294967297.0.0", "v%d.%d.%dv" % v])


def near_url(rng, good, v):
    a, b, c = v
    h = "github.com"
    cands = [
        good.replace("https", "http", 1), good.replace("https", "HTTPS", 1), good.replace(h, "GitHub.com", 1), good.replace(h, h + ".", 1),
        good.replace(h, h + ":443", 1), good.replace(h, h + "@evil.example", 1), good.replace(h, "evil.example", 1),
        good.replace(h, h + ".evil.example", 1), good.replace(h, "g\u0456thub.com", 1), good.replace(h, "github%2ecom", 1),
        good.replace(h, "user:pw@" + h, 1), good.replace(h, "\uff47ithub.com", 1), good + "/", good + "?x=1", good + "#f", good + " ",
        good + "\x00", good + "\x00x", good + "%00", good + "\ud800", " " + good, "\ufeff" + good, good.replace("/tandem", "/Tandem", 1),
        good.replace("releases/", "releases//", 1), good.replace("releases/", "releases/./", 1), good.replace("releases/", "releases%2F", 1),
        good[:-1], good[1:], good.replace("/", "\\"), good.replace("v%d." % a, "v%d." % (a + 1), 1), good.replace("https://", "https:/", 1),
        good.replace("https://", "https:///", 1), good.replace(".%d" % c, ".%d" % (c + 1)), good.replace("v%d.%d.%d" % v, "v%d.%02d.%d" % v),
        good.upper(), good + good, "", "javascript:alert(1)", "file:///C:/Windows/System32/calc.exe", good.replace("tag/", "download/", 1),
        good.replace("download/", "tag/", 1), good.replace("-x64-", "-x86-"), good + "\n", good.replace("github", "github\u00ad", 1),
        good.replace("0", "\uff10", 1), good.replace("https://github.com/", "https://github.com/../github.com/", 1), good + "\u0000"]
    return rng.choice(cands)


def good_time(rng):
    y = rng.choice([1601, 1700, 1900, 2000, 2024, 2026, 2100, 2400, 9999, rng.randint(1601, 9999)])
    mo = rng.randint(1, 12)
    for _ in range(50):
        d = rng.randint(1, 31)
        try:
            datetime.datetime(y, mo, d)
            break
        except ValueError:
            continue
    return "%04d-%02d-%02dT%02d:%02d:%02dZ" % (y, mo, d, rng.randint(0, 23), rng.randint(0, 59), rng.randint(0, 59))


BAD_TIMES = ["", "2026-10-14", "2026-02-29T00:00:00Z", "2100-02-29T00:00:00Z", "1900-02-29T00:00:00Z", "2026-04-31T08:00:00Z",
             "2026-10-14T24:00:00Z", "2026-10-14T08:60:00Z", "2026-10-14T08:00:60Z", "1600-12-31T23:59:59Z", "0000-01-01T00:00:00Z",
             "2026-10-14t08:00:00Z", "2026-10-14T08:00:00z", "2026-10-14T08:00:00+00:00", "2026-10-14T08:00:00.000Z",
             "2026-10-14 08:00:00Z", "2026-10-14T08:00:00Z ", " 2026-10-14T08:00:00Z", "2026-10-14T08:00:00ZZ", "2026-10-14T08:00:0Z",
             "2026-1\uff10-14T08:00:00Z", "2026-10-14T08:00:00Z\x00", "2026-00-14T08:00:00Z", "2026-13-14T08:00:00Z",
             "2026-10-00T08:00:00Z", "2026-10-32T08:00:00Z", "+026-10-14T08:00:00Z", "2026-10-14T08:00:00\u005a\ud83d", "20261014T080000Z"]
GOOD_FEB29 = ["2000-02-29T00:00:00Z", "2024-02-29T23:59:59Z", "2400-02-29T12:00:00Z", "1604-02-29T00:00:00Z"]


def build_record(rng):
    """a record that is valid or broken in a few chosen ways; returns the structure"""
    v = pick_version(rng)
    p = 0.93
    tag = "v%d.%d.%d" % v if rng.random() < p else bad_tag(rng, v)
    if rng.random() < 0.02:  # leading zeros in the tag with canonical addresses
        tag = "v%02d.%03d.%d" % v if v[0] < 1000 and v[1] < 100 else tag
    draft = False if rng.random() < p else rng.choice([True, None, Raw("0"), "false", [], Obj(), Raw("0.0")])
    pre = False if rng.random() < p else rng.choice([True, None, Raw("0"), "false", [False], Obj()])
    pub = (good_time(rng) if rng.random() < 0.9 else rng.choice(GOOD_FEB29)) if rng.random() < p else rng.choice(BAD_TIMES)
    notes = notes_url(v) if rng.random() < p else near_url(rng, notes_url(v), v)
    name = inst_name(v) if rng.random() < p else rng.choice([inst_name((v[0], v[1], v[2] + 1)), inst_name(v).upper(), inst_name(v) + " ",
                                                              "setup.exe", "", inst_name(v) + "\x00", inst_name(v).replace("x64", "arm64"),
                                                              inst_name(v) + ".sig"])
    state = "uploaded" if rng.random() < p else rng.choice(["open", "new", "Uploaded", "uploaded ", "", "uploaded\x00", "starter", " uploaded"])
    url = inst_url(v) if rng.random() < p else near_url(rng, inst_url(v), v)
    if rng.random() < 0.03:
        tag, pub, notes, name, state, url = (rng.choice([Raw("1"), None, True, [x], Obj([("v", x)])]) if rng.random() < 0.3 else x
                                              for x in (tag, pub, notes, name, state, url))

    asset = [("url", "https://api.github.com/x"), ("id", Raw("7")), ("name", name), ("label", None),
             ("uploader", Obj([("login", "a"), ("name", inst_name(v)), ("state", "uploaded"), ("browser_download_url", inst_url(v))])),
             ("state", state), ("size", Raw("8247136")), ("browser_download_url", url)]
    rng.shuffle(asset)
    asset = Obj(asset)
    other = Obj([("name", "notes.txt"), ("state", "uploaded"), ("browser_download_url", REL + "download/v0.1.9/notes.txt")])
    assets = [asset]
    r = rng.random()
    if r < 0.15:
        assets = [other, asset]
    elif r < 0.25:
        assets = [asset, other, Raw("1"), None, "x", [], Obj()]
    elif r < 0.30:
        assets = [rng.choice([Raw("0"), None, [], "s", [asset]]), asset]

    top = [("url", "https://api.github.com/x"), ("html_url", notes), ("id", Raw("392460282")),
           ("author", Obj([("login", "a"), ("html_url", "https://github.com/a"), ("tag_name", "v9.9.9"), ("draft", True)])),
           ("tag_name", tag), ("name", tag if isinstance(tag, str) else "x"), ("draft", draft), ("prerelease", pre),
           ("created_at", "2026-09-20T14:32:08Z"), ("published_at", pub), ("assets", assets),
           ("body", "text \"tag_name\":\"v9.9.9\" {x} [y]\n\u010d\U0001F4C1 " + inst_url((9, 9, 9)))]
    for _ in range(rng.randint(0, 3)):
        top.append((rng.choice(["x", "y", "node_id", "", "Tag_name", "tag_name ", "tag_nam", "tag_name_", "TAG_NAME", "asset", "assets_url",
                                "tag_name\x00", "tag_name\ud83d", "draft\x00x", "tag_name" + "x" * 40, "a" * 39, "a" * 40, "a" * 41]),
                    junk(rng)))
    if rng.random() < 0.6:
        rng.shuffle(top)

    # structural attacks
    if rng.random() < 0.22:
        op = rng.randint(0, 13)
        if op == 0:  # drop a read member
            k = rng.choice(READ)
            top = [(a, b) for a, b in top if a != k]
        elif op == 1:  # duplicate a read member, same or other value, before or after
            k = rng.choice(READ)
            val = dict(top)[k]
            alt = rng.choice([val, junk(rng), "v0.2.0", False, [], notes_url((9, 9, 9))])
            top.insert(rng.randint(0, len(top)), (k, alt))
        elif op == 2:  # the read members only inside a nested object
            top = [("release", Obj(top))]
        elif op == 3:  # duplicate a member inside the asset
            k = rng.choice(["name", "state", "browser_download_url"])
            val = dict(asset)[k]
            asset.insert(rng.randint(0, len(asset)), (k, rng.choice([val, "open", "https://evil.example/x.exe", None])))
        elif op == 4:  # name and address in two different assets
            d = dict(asset)
            a1 = Obj([("name", d["name"]), ("state", "uploaded"), ("browser_download_url", "https://evil.example/x.exe")])
            a2 = Obj([("name", "x.exe"), ("state", "uploaded"), ("browser_download_url", d["browser_download_url"])])
            top = [(a, [a1, a2]) if a == "assets" else (a, b) for a, b in top]
        elif op == 5:  # the installer one level deeper
            top = [(a, [Obj([("uploader", asset)])]) if a == "assets" else (a, b) for a, b in top]
        elif op == 6:  # assets of another type
            top = [(a, rng.choice([None, Obj(asset), "x", Raw("1"), [[asset]], Obj([("0", asset)]), True])) if a == "assets" else (a, b) for a, b in top]
        elif op == 7:  # a second assets member: the good one first or second
            first = rng.random() < 0.5
            new = []
            for a, b in top:
                if a == "assets":
                    new.append((a, b) if first else (a, []))
                    new.append((a, []) if first else (a, b))
                else:
                    new.append((a, b))
            top = new
        elif op == 8:  # empty assets
            top = [(a, []) if a == "assets" else (a, b) for a, b in top]
        elif op == 9:  # a state member missing in the asset
            k = rng.choice(["name", "state", "browser_download_url"])
            for i, (a, b) in enumerate(asset):
                if a == k:
                    del asset[i]
                    break
        elif op == 10:  # deep junk at the nesting limit
            d = rng.choice([29, 30, 31, 32, 33])
            x = Raw("1")
            for _ in range(d):
                x = [x] if rng.random() < 0.5 else Obj([("a", x)])
            top.insert(rng.randint(0, len(top)), ("deep", x))
        elif op == 11:  # a huge ignored string / total size near the limit
            n = rng.choice([511, 512, 513, 4096, MAX_ANSWER - 2000, MAX_ANSWER])
            top.insert(rng.randint(0, len(top)), ("pad", "p" * n))
        elif op == 12:  # the asset among many
            many = [Obj([("name", inst_name(v)), ("state", "open"), ("browser_download_url", inst_url(v))]) for _ in range(rng.randint(1, 5))]
            pos = rng.randint(0, len(many))
            many.insert(pos, asset)
            top = [(a, many) if a == "assets" else (a, b) for a, b in top]
        else:  # everything read is a wrong type
            k = rng.choice(READ)
            top = [(a, junk(rng)) if a == k else (a, b) for a, b in top]
    return Obj(top)


# ---------------------------------------------------------------------------
# byte-level mutation
# ---------------------------------------------------------------------------

TOKENS = [b"{", b"}", b"[", b"]", b'"', b":", b",", b"\\", b"\\u", b"\\ud83d", b"\\udcc1", b"\\u0000", b"true", b"false", b"null", b"0",
          b"-", b"1e9", b".", b" ", b"\n", b"\x00", b"\x1f", b"\x7f", b"\xef\xbb\xbf", b"/", b"\\/", b'"tag_name"', b'"assets"', b'"draft"',
          b"v0.1.8", b"v0.1.9", b"NaN", b"Infinity", b"'", b"/*", b"//", b"\t", b"\r", b"+", b"e", b"E", b"01", b'""', b"[]", b"{}", b'":"',
          b'","', b"\\\\", b'\\"', b"9", b"8",
          # not JSON white space, not hex digits (found missing by mutants.py: formfeed_space, hex_g)
          b"\x0c", b"\x0b", b"\xc2\xa0", b"\xe2\x80\xa8", b"\x85", b"G", b"g", b"@", b"`", b"\\u00G0"]


def mutate(data, rng, n=None):
    b = bytearray(data)
    for _ in range(n if n is not None else rng.choice([1, 1, 1, 2, 3])):
        if not b:
            b = bytearray(rng.choice(TOKENS))
            continue
        op = rng.randint(0, 9)
        i = rng.randrange(len(b))
        if op == 0:
            b[i] = rng.randrange(256)
        elif op == 1:
            b[i] ^= 1 << rng.randrange(8)
        elif op == 2:
            del b[i]
        elif op == 3:
            b[i:i] = rng.choice(TOKENS)
        elif op == 4:
            t = rng.choice(TOKENS)
            b[i:i + len(t)] = t
        elif op == 5:
            j = min(len(b), i + rng.randint(1, 40))
            b[i:i] = b[i:j]
        elif op == 6:
            j = min(len(b), i + rng.randint(1, 40))
            del b[i:j]
        elif op == 7:
            del b[i:]
        elif op == 8:
            j = rng.randrange(len(b))
            b[i], b[j] = b[j], b[i]
        else:
            # splice: move a chunk elsewhere
            j = min(len(b), i + rng.randint(1, 60))
            chunk = bytes(b[i:j])
            del b[i:j]
            k = rng.randrange(len(b) + 1)
            b[k:k] = chunk
    return bytes(b)


BAD_UTF8 = [b"\x80", b"\xbf", b"\xc0\xaf", b"\xc1\xa5", b"\xe0\x80\xaf", b"\xed\xa0\x80", b"\xed\xb3\x81", b"\xf4\x90\x80\x80", b"\xf8\x88\x80\x80\x80",
            b"\xff", b"\xfe", b"\xc3", b"\xe2\x82", b"\xf0\x9f\x93", b"\xc3\x28"]


# ---------------------------------------------------------------------------
# generators -> (kind, payload)
# ---------------------------------------------------------------------------

def gen_struct(rng):
    v = build_record(rng)
    style = rng.random()
    pe = 0.0 if style < 0.5 else rng.choice([0.02, 0.1, 0.5, 1.0])
    pw = 0.0 if rng.random() < 0.5 else rng.choice([0.1, 0.5, 1.0])
    data = ser(v, rng, pe, pw).encode("utf-8")
    if rng.random() < 0.3:
        data = ws(rng, 1.0).encode() + data + ws(rng, 1.0).encode()
    return b"R", data


def gen_struct_mut(rng):
    _, data = gen_struct(rng)
    return b"R", mutate(data, rng)


def gen_real_mut(rng):
    return b"R", mutate(REAL, rng)


MINI = None


def gen_mini_mut(rng):
    """a compact valid record: mutations hit the members that matter far more often than in the real one"""
    v = (0, 1, 9)
    data = ('{"tag_name":"v0.1.9","draft":false,"prerelease":false,"published_at":"2026-10-14T08:00:00Z","html_url":"%s",'
            '"assets":[{"name":"%s","state":"uploaded","browser_download_url":"%s"}]}' % (notes_url(v), inst_name(v), inst_url(v))).encode()
    return b"R", mutate(data, rng, rng.choice([1, 1, 2]))


REAL_TREE = None


def _objs(v, acc):
    if isinstance(v, Obj):
        acc.append(v)
        for _, x in v:
            _objs(x, acc)
    elif isinstance(v, list):
        for x in v:
            _objs(x, acc)
    return acc


def gen_real_reser(rng):
    """the real record re-serialised in another spelling (escapes, white space, member order), often
    with one member duplicated, removed or retyped at a random nesting level"""
    global REAL_TREE
    if REAL_TREE is None:
        REAL_TREE = REAL.decode("utf-8")
    v = json.loads(REAL_TREE, object_pairs_hook=Obj)
    objs = _objs(v, [])
    r = rng.random()
    if r < 0.5:
        o = rng.choice(objs)
        if o:
            i = rng.randrange(len(o))
            op = rng.randint(0, 3)
            if op == 0:
                o.insert(rng.randint(0, len(o)), o[i])
            elif op == 1:
                o.insert(rng.randint(0, len(o)), (o[i][0], junk(rng)))
            elif op == 2:
                del o[i]
            else:
                o[i] = (o[i][0], junk(rng))
    if rng.random() < 0.5:
        rng.shuffle(rng.choice(objs))
    data = ser(v, rng, rng.choice([0, 0, 0.05, 0.5, 1.0]), rng.choice([0, 0, 0.3, 1.0])).encode("utf-8")
    return b"R", data


def gen_utf8(rng):
    """a mostly valid record with invalid UTF-8 put somewhere"""
    _, data = gen_struct(rng)
    i = rng.randrange(len(data) + 1)
    return b"R", data[:i] + rng.choice(BAD_UTF8) + data[i:]


def rand_json(rng, depth):
    r = rng.random()
    if depth <= 0 or r < 0.3:
        r2 = rng.random()
        if r2 < 0.3:
            return ser_str(junk(rng, 9) if rng.random() < 0.7 else "", rng, rng.choice([0, 0.3, 1.0]))
        if r2 < 0.6:
            return rng.choice(NUMS + ["01", "1.", ".5", "+1", "-", "1e", "0x10", "1e+", "--1", "1.5.5", "00", "-01", "1E", "0e0", "0E-0"])
        return rng.choice(["true", "false", "null", "true", "false", "null", "True", "nul", "NaN", "Infinity", "-Infinity", "tru", "falsee"])
    w = lambda: ws(rng, 0.2)
    if r < 0.65:
        n = rng.randint(0, 4)
        return "[" + w() + ",".join(w() + rand_json(rng, depth - 1) + w() for _ in range(n)) + "]"
    n = rng.randint(0, 4)
    return "{" + w() + ",".join(w() + ser_str(rng.choice(["a", "b", "", "tag_name", "assets", "k\n"]), rng, 0.2) + w() + ":" + w() +
                                rand_json(rng, depth - 1) + w() for _ in range(n)) + "}"


def gen_grammar(rng):
    r = rng.random()
    if r < 0.15:  # a chain at the nesting limit
        d = rng.choice([1, 2, 30, 31, 32, 33, 34, 40, 100])
        opens, closes = [], []
        for _ in range(d):
            if rng.random() < 0.5:
                opens.append("[")
                closes.append("]")
            else:
                opens.append('{"a":')
                closes.append("}")
        text = "".join(opens) + rng.choice(["1", '"x"', "[]", "{}", "null"]) + "".join(reversed(closes))
        return b"R", text.encode()
    text = rand_json(rng, rng.randint(0, 6)).encode("utf-8", "surrogatepass")
    if rng.random() < 0.35:
        text = mutate(text, rng, 1)
    try:
        text.decode("utf-8")
    except UnicodeDecodeError:
        pass
    return b"R", text


STR_PARTS = ["a", "z", " ", "/", "\u00e9", "\u20ac", "\U0001F4C1", "\\n", "\\t", "\\\\", '\\"', "\\/", "\\b", "\\f", "\\r", "\\u0041", "\\u00e9",
             "\\u20AC", "\\ud83d\\udcc1", "\\uD83D\\uDCC1", "\\ud83d", "\\udcc1", "\\udcc1\\ud83d", "\\ud83d\\ud83d\\udcc1", "\\u0000", "\\u0001",
             "\\u007f", "\\uffff", "\\ud7ff", "\\ue000", "\\udbff\\udfff", "\\ud800\\udc00", "\\ud83d\\u0041", "\\ud83d\\n", "\\ud83dx",
             "\x7f", "\u0080", "\uffff", "\U0010FFFF"]
STR_BAD = ["\\u12G4", "\\u00G0", "\\u00`0", "\\u00@0", "\\u00:0", "\\u00/0", "\\u00g0", "\\uFFFG", "\\u 041", "\\u+041", "\\u-041", "\\u0x41",
           "\\x", "\\u12g4", "\\u12", "\\U0041", "\n", "\t", "\x00", "\x1f", "\\", "\\ud83d\\u12", "\\ud83d\\uzzzz", "\\'", "\\0", "\\a", "\\v", "\\e"]


def gen_string(rng):
    parts = [rng.choice(STR_PARTS) for _ in range(rng.choice([0, 1, 2, 3, 5, 8, 20, 200]))]
    if rng.random() < 0.15:
        parts.insert(rng.randint(0, len(parts)), rng.choice(STR_BAD))
    body = "".join(parts)
    lit = '"' + body + ('"' if rng.random() < 0.95 else "")
    r = rng.random()
    if r < 0.1:
        lit = ws(rng, 1.0) + lit
    if r > 0.9:
        lit = lit + rng.choice([" ", "x", '"', ",", "\n ", ":1"])
    raw = lit.encode("utf-8")
    # the unescaped length, when it is a valid literal
    need = 1
    o = oracle_string(struct.pack("<H", 4000) + raw)
    if o and o[0]:
        need = len(o[3]) + 1
    size = rng.choice([0, 1, 2, need - 4, need - 3, need - 2, need - 1, need, need + 1, 40, 512])
    size = max(0, min(size, 60000))
    return b"S", struct.pack("<H", size) + raw


VER_ALPHA = [b"0", b"1", b"9", b"12", b"99999", b"100000", b"00", b"007", b".", b".", b".", b"v", b"V", b"-", b"+", b" ", b"\x00", b"\xef\xbc\x90",
             b"\xb2", b"e", b"x", b",", b"/", b"\n", b"\xff", b"4294967296", b"65536", b"2147483648"]


def gen_version(rng):
    tag = rng.random() < 0.5
    r = rng.random()
    if r < 0.4:
        v = pick_version(rng)
        txt = (b"v" if rng.random() < 0.6 else b"") + ("%d.%d.%d" % v).encode()
    elif r < 0.5:
        txt = (b"v" if rng.random() < 0.6 else b"") + b".".join(b"0" * rng.randint(0, 6) + str(rng.randint(0, 999999)).encode()[:rng.randint(0, 6)]
                                                                 for _ in range(3))
    else:
        txt = b"".join(rng.choice(VER_ALPHA) for _ in range(rng.randint(0, 8)))
    if rng.random() < 0.3:
        txt = mutate(txt, rng, 1) if txt else txt
    explicit = rng.random() < 0.5
    return b"V", bytes([1 if tag else 0, 1 if explicit else 0]) + txt


def gen_time(rng):
    r = rng.random()
    if r < 0.35:
        s = good_time(rng)
    elif r < 0.5:
        s = rng.choice(BAD_TIMES + GOOD_FEB29)
    else:
        # every field independently in or slightly out of range
        s = "%04d-%02d-%02dT%02d:%02d:%02dZ" % (rng.choice([0, 1, 1600, 1601, 1900, 2000, 2023, 2024, 2100, 2400, 9999, rng.randint(0, 9999)]),
                                                 rng.choice([0, 1, 2, 2, 2, 4, 6, 9, 11, 12, 13, 99]), rng.choice([0, 1, 28, 29, 30, 31, 32, 99]),
                                                 rng.choice([0, 23, 24, 99]), rng.choice([0, 59, 60, 99]), rng.choice([0, 59, 60, 61, 99]))
    b = s.encode("utf-8", "surrogatepass")
    if rng.random() < 0.25:
        b = mutate(b, rng, 1)
    return b"D", bytes([1 if rng.random() < 0.5 else 0]) + b


LOOP_PARTS = ["http://127.0.0.1:", "http://127.0.0.1:", "http://127.0.0.1:", "https://127.0.0.1:", "http://localhost:", "HTTP://127.0.0.1:",
              "http://127.0.0.1", "http://127.0.0.2:", "http://127.0.0.1.:", "http://127.000.0.1:", " http://127.0.0.1:", "http://[::1]:", ""]
LOOP_PORTS = ["8123", "1", "65535", "65536", "0", "00080", "000080", "99999", "100000", "", "80a", "-1", "+80", "\uff18\uff10", "8 0", "0x50",
              "065535", "00001", "00000", "4294967297"]
LOOP_PATHS = ["/", "/latest/newer", "/a?b=c&d=%20", "", "x", "/a b", "/a#b", "/a\r\nHost: evil", "/\u010d", "/a\x7f", "/~!$&'()*+,;=:@[]\\^`{|}", "/" + "p" * 40,
              "//evil.example/x", "/a\tb", "/\x00hidden", "/a\x01", "/\ud83d", "/\"<>"]


def gen_loopback(rng):
    s = rng.choice(LOOP_PARTS) + rng.choice(LOOP_PORTS) + rng.choice(LOOP_PATHS)
    if rng.random() < 0.2 and s:
        i = rng.randrange(len(s))
        s = s[:i] + rng.choice([chr(rng.randrange(1, 0x100)), "", "\uffff", s[i] * 2]) + s[i + 1:]
    units = s.encode("utf-16-le", "surrogatepass")
    n = len(rng.choice(LOOP_PATHS))
    size = rng.choice([0, 1, 2, n, n + 1, n + 2, 64, 64, 300, -1, -32768])
    return b"L", struct.pack("<h", size) + units


def J(s):
    return s.encode("utf-8", "surrogatepass") if isinstance(s, str) else s


def hand_cases():
    """hand-written attack records: (name, bytes, expect_accept) - my own expectation, checked against the oracle too"""
    v = (0, 1, 9)
    N, U, F = notes_url(v), inst_url(v), inst_name(v)
    T = "2026-10-14T08:00:00Z"

    def rec(tag='"v0.1.9"', draft="false", pre="false", pub='"%s"' % T, notes='"%s"' % N, assets=None, extra="", tail=""):
        if assets is None:
            assets = '[{"name":"%s","state":"uploaded","browser_download_url":"%s"}]' % (F, U)
        return ('{%s"tag_name":%s,"draft":%s,"prerelease":%s,"published_at":%s,"html_url":%s,"assets":%s%s}' %
                (extra, tag, draft, pre, pub, notes, assets, tail))

    A = '{"name":"%s","state":"uploaded","browser_download_url":"%s"}' % (F, U)
    c = []
    add = lambda name, text, acc: c.append((name, J(text), acc))
    add("good", rec(), True)
    add("good, escaped slashes in both addresses", rec(notes='"%s"' % N.replace("/", "\\/"), assets=A.join(["[", "]"]).replace("https://", "https:\\/\\/")), True)
    add("good, every character of every read value as \\u escape",
        rec(tag='"%s"' % "".join("\\u%04x" % ord(ch) for ch in "v0.1.9"), notes='"%s"' % "".join("\\u%04X" % ord(ch) for ch in N)), True)
    add("good, escaped member names", rec().replace('"tag_name"', '"\\u0074ag_name"').replace('"assets"', '"asset\\u0073"').replace('"state"', '"st\\u0061te"'), True)
    add("installer address only in the body text", rec(assets="[]", tail=',"body":"%s"' % A.replace('"', '\\"')), False)
    add("installer asset only in a nested object", rec(assets='[{"x":%s}]' % A), False)
    add("installer asset in a nested array", rec(assets="[[%s]]" % A), False)
    add("assets is the asset object itself", rec(assets=A), False)
    add("second assets array holds the installer", rec(assets="[]", tail=',"assets":[%s]' % A), False)
    add("second assets array is empty", rec(tail=',"assets":[]'), False)
    add("name in one asset, address in another", rec(assets='[{"name":"%s","state":"uploaded","browser_download_url":"https://evil.example/x"},'
                                                         '{"name":"x","state":"uploaded","browser_download_url":"%s"}]' % (F, U)), False)
    add("asset with the name twice (same value)", rec(assets='[{"name":"%s","name":"%s","state":"uploaded","browser_download_url":"%s"}]' % (F, F, U)), False)
    add("asset with a second address (evil first)", rec(assets='[{"name":"%s","state":"uploaded","browser_download_url":"https://evil.example/x","browser_download_url":"%s"}]' % (F, U)), False)
    add("asset with a second address (evil last)", rec(assets='[{"name":"%s","state":"uploaded","browser_download_url":"%s","browser_download_url":"https://evil.example/x"}]' % (F, U)), False)
    add("asset state open then uploaded", rec(assets='[{"name":"%s","state":"open","state":"uploaded","browser_download_url":"%s"}]' % (F, U)), False)
    add("tag twice, second evil", rec(tail=',"tag_name":"v9.9.9"'), False)
    add("tag twice, first evil", rec(extra='"tag_name":"v9.9.9",'), False)
    add("tag twice, second via escape", rec(tail=',"tag_n\\u0061me":"v9.9.9"'), False)
    add("draft twice (false, false)", rec(tail=',"draft":false'), False)
    add("draft twice (true first)", rec(extra='"draft":true,'), False)
    add("tag with leading zeros, canonical addresses", rec(tag='"v00.01.009"'), True)
    add("tag with leading zeros, addresses with zeros", rec(tag='"v0.01.9"', notes='"%s"' % N.replace("0.1.9", "0.01.9")), False)
    add("tag with 6 digits", rec(tag='"v0.1.000009"'), False)
    add("tag unicode digits", rec(tag='"v\uff10.1.9"'), False)
    add("tag arabic digits", rec(tag='"v\u0660.1.9"'), False)
    add("tag upper V", rec(tag='"V0.1.9"'), False)
    add("tag with escaped NUL then more", rec(tag='"v0.1.9\\u0000.1"'), False)
    add("tag is a number", rec(tag="0.1"), False)
    add("tag v4294967296.1.9 (wraps to 0 in 32 bits)", rec(tag='"v4294967296.1.9"'), False)
    add("host upper case", rec(notes='"%s"' % N.replace("github.com", "GITHUB.COM")), False)
    add("host with trailing dot", rec(notes='"%s"' % N.replace("github.com", "github.com.")), False)
    add("userinfo", rec(notes='"%s"' % N.replace("github.com", "github.com@evil.example")), False)
    add("percent-encoded host", rec(notes='"%s"' % N.replace("github.com", "github%2Ecom")), False)
    add("homoglyph host", rec(notes='"%s"' % N.replace("github", "g\u0456thub")), False)
    add("address followed by escaped NUL", rec(notes='"%s\\u0000"' % N), False)
    add("address followed by escaped NUL and evil", rec(notes='"%s\\u0000@evil.example"' % N), False)
    add("address with lone surrogate", rec(notes='"%s\\ud83d"' % N), False)
    add("address padded to 511 bytes after an escaped NUL", rec(notes='"%s\\u0000%s"' % (N, "x" * 440)), False)
    add("asset address 512+ bytes beginning with the good one", rec(assets='[{"name":"%s","state":"uploaded","browser_download_url":"%s%s"}]' % (F, U, "x" * 600)), False)
    add("asset name 512+ bytes", rec(assets='[{"name":"%s%s","state":"uploaded","browser_download_url":"%s"}]' % (F, "x" * 600, U)), False)
    add("member name 'assets' + 40 bytes", rec().replace('"assets"', '"assets%s"' % ("s" * 40)), False)
    add("member name with escaped NUL after tag_name", rec().replace('"tag_name"', '"tag_name\\u0000"'), False)
    add("member name tag_name + lone surrogate", rec().replace('"tag_name"', '"tag_name\\udc00"'), False)
    add("draft null", rec(draft="null"), False)
    add("draft string false", rec(draft='"false"'), False)
    add("draft 0", rec(draft="0"), False)
    add("draft falsee", rec(draft="falsee"), False)
    add("draft false then junk literal", rec(draft="false false"), False)
    add("prerelease true", rec(pre="true"), False)
    add("published seconds 60", rec(pub='"2026-10-14T08:00:60Z"'), False)
    add("published 1600", rec(pub='"1600-10-14T08:00:00Z"'), False)
    add("published 1601 first second", rec(pub='"1601-01-01T00:00:00Z"'), True)
    add("published 9999", rec(pub='"9999-12-31T23:59:59Z"'), True)
    add("published Feb 29 2100", rec(pub='"2100-02-29T00:00:00Z"'), False)
    add("published Feb 29 2400", rec(pub='"2400-02-29T00:00:00Z"'), True)
    add("published with fullwidth digit", rec(pub='"2026-10-1\uff14T08:00:00Z"'), False)
    add("byte-order mark", b"\xef\xbb\xbf" + J(rec()), False)
    add("trailing NUL", J(rec()) + b"\x00", False)
    add("leading NUL", b"\x00" + J(rec()), False)
    add("two records", rec() + rec(), False)
    add("record in an array", "[%s]" % rec(), False)
    add("trailing comma", rec(tail=","), False)
    add("comment", rec(tail="/*x*/"), False)
    add("single quotes", rec().replace('"', "'"), False)
    for label, sp in (("form feed", b"\x0c"), ("vertical tab", b"\x0b"), ("NBSP", b"\xc2\xa0"), ("raw A0", b"\xa0"), ("U+2028", b"\xe2\x80\xa8"),
                      ("NEL", b"\x85"), ("U+FEFF", b"\xef\xbb\xbf"), ("NUL", b"\x00"), ("U+3000", b"\xe3\x80\x80")):
        add("%s as white space after {" % label, b"{" + sp + J(rec())[1:], False)
        add("%s as white space before }" % label, J(rec())[:-1] + sp + b"}", False)
        add("%s as white space after the record" % label, J(rec()) + sp, False)
    for h in ("G", "g", "@", "`", ":", "/", " ", "+", "-", "x"):
        add("hex digit '%s' in an ignored string" % h, rec(tail=',"x":"\\u00%s1"' % h), False)
        add("hex digit '%s' in tag_name" % h, rec(tag='"v0.1.\\u003%s"' % h), False)
    add("upper and lower hex mixed", rec(tail=',"x":"\\uAbCd\\uaBcD\\uFFFF\\uffff"'), True)
    add("NaN member", rec(tail=',"x":NaN'), False)
    add("-Infinity member", rec(tail=',"x":-Infinity'), False)
    add("number 01", rec(tail=',"x":01'), False)
    add("number 1.", rec(tail=',"x":1.'), False)
    add("number -", rec(tail=',"x":-'), False)
    add("number 1e400 (overflows a double)", rec(tail=',"x":1e400'), True)
    add("number -0.0e-0", rec(tail=',"x":-0.0e-0'), True)
    add("raw TAB in an ignored string", rec(tail=',"x":"a\tb"'), False)
    add("raw DEL in an ignored string", rec(tail=',"x":"a\x7fb"'), True)
    add("raw U+2028 in an ignored string", rec(tail=',"x":"a\u2028b"'), True)
    add("lone surrogate escape in an ignored string", rec(tail=',"x":"\\udc00"'), True)
    add("escaped NUL in an ignored string", rec(tail=',"x":"\\u0000"'), True)
    add("empty member name", rec(tail=',"":1'), True)
    add("duplicate ignored members", rec(tail=',"x":1,"x":2'), True)
    for d, acc in ((31, True), (32, False)):  # the member's value is itself at level 2
        add("ignored member nested %d arrays (level %d)" % (d, d + 1), rec(tail=',"x":' + "[" * d + "]" * d), acc)
        add("ignored member nested %d objects (level %d)" % (d, d + 1), rec(tail=',"x":' + '{"a":' * d + "1" + "}" * d), acc)
    for d, acc in ((29, True), (30, False)):  # inside an asset member: level 4
        add("asset member nested %d arrays" % d, rec(assets='[{"k":%s,"name":"%s","state":"uploaded","browser_download_url":"%s"}]' % ("[" * d + "]" * d, F, U)), acc)
    for d, acc in ((30, True), (31, False)):  # a non-object asset element: level 3
        add("asset element nested %d arrays" % d, rec(assets="[%s,%s]" % ("[" * d + "]" * d, A)), acc)
    pad = MAX_ANSWER - len(J(rec(tail=',"p":""')))
    add("exactly 256 KB", rec(tail=',"p":"%s"' % ("p" * pad)), True)
    add("256 KB + 1", rec(tail=',"p":"%s"' % ("p" * (pad + 1))), False)
    add("256 KB of white space around", " " * 1000 + rec() + "\n" * 1000, True)
    add("empty", b"", False)
    add("only white space", b"  \n", False)
    add("unterminated", rec()[:-1], False)
    add("true", "true", False)
    add("asset name value is an object holding the name", rec(assets='[{"name":{"name":"%s"},"state":"uploaded","browser_download_url":"%s"}]' % (F, U)), False)
    add("asset is a string holding the asset text", rec(assets='["%s"]' % A.replace('"', '\\"')), False)
    add("assets string", rec(assets='"%s"' % U), False)
    add("html_url array", rec(notes='["%s"]' % N), False)
    add("state Uploaded", rec(assets=A.join(["[", "]"]).replace("uploaded", "Uploaded")), False)
    add("state with trailing escaped NUL", rec(assets=A.join(["[", "]"]).replace('"uploaded"', '"uploaded\\u0000"')), False)
    add("everything good but name of another version", rec(assets=A.join(["[", "]"]).replace("er-0.1.9", "er-0.1.8", 1)), False)
    return c


GENS = {
    "struct": (gen_struct, 1.0),
    "struct_mut": (gen_struct_mut, 1.0),
    "mini_mut": (gen_mini_mut, 1.5),
    "real_mut": (gen_real_mut, 0.5),
    "real_reser": (gen_real_reser, 0.3),
    "utf8": (gen_utf8, 0.2),
    "grammar": (gen_grammar, 1.0),
    "string": (gen_string, 1.0),
    "version": (gen_version, 0.5),
    "time": (gen_time, 0.5),
    "loopback": (gen_loopback, 0.5),
}


def mini_record():
    v = (0, 1, 9)
    return ('{"tag_name":"v0.1.9","draft":false,"prerelease":false,"published_at":"2026-10-14T08:00:00Z","html_url":"%s",'
            '"assets":[{"name":"%s","state":"uploaded","browser_download_url":"%s"}]}' % (notes_url(v), inst_name(v), inst_url(v))).encode()


def exh_mini():
    """exhaustive single edits of a compact valid record: every byte value at every position, every
    deletion of 1 and 2 bytes, every token inserted at every position, every truncation"""
    base = mini_record()
    cases = []
    for i in range(len(base)):
        for c in range(256):
            if c != base[i]:
                cases.append((b"R", base[:i] + bytes([c]) + base[i + 1:]))
        cases.append((b"R", base[:i] + base[i + 1:]))
        cases.append((b"R", base[:i] + base[i + 2:]))
        cases.append((b"R", base[:i]))
    for i in range(len(base) + 1):
        for t in TOKENS:
            cases.append((b"R", base[:i] + t + base[i:]))
    return cases


def exh_short():
    """every text of 1 to 5 symbols over 16 JSON symbols - the grammar verdict against Python"""
    import itertools
    alpha = [b"{", b"}", b"[", b"]", b'"', b":", b",", b"0", b"1", b"-", b".", b"e", b"\\", b"n", b" ", b"a"]
    cases = []
    for n in range(1, 6):
        for t in itertools.product(alpha, repeat=n):
            cases.append((b"R", b"".join(t)))
    return cases


def exh_dup():
    """every read member duplicated at every member position of the top-level object and of the asset,
    with the same and with another value; every read member removed; every pair swapped"""
    v = (0, 1, 9)
    top = [("tag_name", '"v0.1.9"'), ("draft", "false"), ("prerelease", "false"), ("published_at", '"2026-10-14T08:00:00Z"'),
           ("html_url", '"%s"' % notes_url(v)), ("x", '{"tag_name":"v9.9.9","assets":[]}')]
    asset = [("name", '"%s"' % inst_name(v)), ("state", '"uploaded"'), ("browser_download_url", '"%s"' % inst_url(v)), ("id", "7")]
    alts = {"tag_name": ['"v0.2.0"', "null"], "draft": ["true", "null"], "prerelease": ["true", "0"], "published_at": ['"2027-01-01T00:00:00Z"', "1"],
            "html_url": ['"%s"' % notes_url((0, 2, 0)), "[]"], "assets": ["[]", "null"], "name": ['"x"', "null"], "state": ['"open"', "1"],
            "browser_download_url": ['"https://evil.example/x"', "{}"]}

    def text(t, a):
        members = ['"%s":%s' % kv for kv in t]
        if a is not None:
            members.insert(min(3, len(members)), '"assets":[{%s}]' % ",".join('"%s":%s' % kv for kv in a))
        return ("{" + ",".join(members) + "}").encode()

    cases = [(b"R", text(top, asset))]
    names = [k for k, _ in top if k != "x"]
    for k in names:
        val = dict(top)[k]
        for alt in [val] + alts[k]:
            for pos in range(len(top) + 1):
                t = list(top)
                t.insert(pos, (k, alt))
                cases.append((b"R", text(t, asset)))
        cases.append((b"R", text([kv for kv in top if kv[0] != k], asset)))
    for k in ("name", "state", "browser_download_url"):
        val = dict(asset)[k]
        for alt in [val] + alts[k]:
            for pos in range(len(asset) + 1):
                a = list(asset)
                a.insert(pos, (k, alt))
                cases.append((b"R", text(top, a)))
        cases.append((b"R", text(top, [kv for kv in asset if kv[0] != k])))
    # a second assets member at every position, good first / good second / both good
    good = '[{%s}]' % ",".join('"%s":%s' % kv for kv in asset)
    for first, second in ((good, "[]"), ("[]", good), (good, good), (good, "null"), ("null", good)):
        for p1 in range(len(top) + 1):
            for p2 in range(p1, len(top) + 1):
                t = list(top)
                t.insert(p2, ("assets", second))
                t.insert(p1, ("assets", first))
                cases.append((b"R", text(t, None)))
    return cases


EXH = {"exh_mini": exh_mini, "exh_short": exh_short, "exh_dup": exh_dup}


def expected_line(kind, payload):
    """-> (comparable tuple or None when not judged, info)"""
    if kind == b"R":
        o = oracle_record(payload)
        return o, o
    if kind == b"S":
        return oracle_string(payload), None
    if kind == b"V":
        return oracle_version(payload), None
    if kind == b"D":
        return oracle_time(payload), None
    if kind == b"L":
        return oracle_loopback(payload), None
    raise ValueError(kind)


def compare(kind, exp, line):
    """-> list of problem labels (empty = agreement)"""
    f = line.split(" ")
    probs = []
    if f[-1] != "ok":
        probs.append(f[-1])
    if kind == b"R":
        g, r, err = int(f[1]), int(f[2]), ERR[int(f[3])]
        ver = (int(f[4]), int(f[5]), int(f[6]))
        ft = int(f[7])
        if g != (1 if exp["g"] else 0):
            probs.append("GRAMMAR_ACCEPTS_INVALID" if g else "GRAMMAR_REJECTS_VALID")
        want = exp["err"] == "None"
        if r and not want:
            probs.append("SECURITY_ACCEPTED_BUT_ORACLE_REJECTS(%s)" % exp["err"])
        elif not r and want:
            probs.append("AVAILABILITY_REJECTED(%s)_BUT_ORACLE_ACCEPTS" % err)
        elif r and (ver != exp["ver"] or ft != exp["ft"]):
            probs.append("SECURITY_WRONG_VALUES")
        elif not r and err != exp["err"]:
            probs.append("ERRCLASS(%s,oracle %s)" % (err, exp["err"]))
    elif kind == b"S":
        if exp is None:
            return probs
        got = (int(f[1]), int(f[2]), int(f[3]), b"" if f[4] == "-" else bytes.fromhex(f[4]))
        if got != exp:
            probs.append("STRING(got %r, oracle %r)" % (got, exp))
    elif kind == b"V":
        got = (int(f[1]), int(f[2]), int(f[3]), int(f[4]))
        if got != exp:
            probs.append("VERSION(got %r, oracle %r)" % (got, exp))
    elif kind == b"D":
        got = (int(f[1]), int(f[2]))
        if got != exp:
            probs.append("TIME(got %r, oracle %r)" % (got, exp))
    elif kind == b"L":
        got = (int(f[1]), int(f[2]), b"" if f[3] == "-" else bytes.fromhex(f[3]))
        if got != exp:
            probs.append("LOOPBACK(got %r, oracle %r)" % (got, exp))
    return probs


def run(exe, cases, tag, outdir):
    outdir = os.path.join(outdir, "tmp_%d" % os.getpid())  # several runs may work at the same time
    os.makedirs(outdir, exist_ok=True)
    cases_file = os.path.join(outdir, "cases_%s.bin" % tag)
    with open(cases_file, "wb") as f:
        for kind, payload in cases:
            f.write(kind + struct.pack("<I", len(payload)) + payload)
    verdict_file = os.path.join(outdir, "verdicts_%s_%s.txt" % (tag, os.path.splitext(os.path.basename(exe))[0]))
    p = subprocess.run([os.path.abspath(exe), "batch", cases_file, verdict_file], capture_output=True, text=True)
    if p.returncode != 0:
        return None, "HARNESS EXIT %d (0x%X)\n%s\n%s" % (p.returncode, p.returncode & 0xFFFFFFFF, p.stdout[-3000:], p.stderr[-6000:])
    with open(verdict_file, "r", encoding="ascii") as f:
        lines = f.read().split("\n")
    return lines, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--count", type=int, default=2000, help="base number of cases per generator (scaled per generator)")
    ap.add_argument("--exe", action="append", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--exh", action="store_true", help="run the exhaustive generators instead of the random ones")
    ap.add_argument("--keep", action="store_true", help="keep the case files")
    a = ap.parse_args()
    outdir = os.path.join(HERE, "out")
    os.makedirs(os.path.join(outdir, "mismatch"), exist_ok=True)
    only = [x for x in a.only.split(",") if x]
    total_problems = 0
    summary = []
    groups = [("hand", None)] + [(n, g) for n, g in GENS.items()]
    if a.exh:
        groups = [(n, g) for n, g in EXH.items()]
    for name, g in groups:
        if only and name not in only:
            continue
        t0 = time.time()
        if g is None:
            hand = hand_cases()
            cases = [(b"R", data) for _, data, _ in hand]
        elif name in EXH:
            cases = g()
        else:
            rng = random.Random("%d/%s" % (a.seed, name))
            cases = [g[0](rng) for _ in range(int(a.count * g[1]))]
        exps = [expected_line(k, p)[0] for k, p in cases]
        stats = {"cases": len(cases)}
        if name == "hand":
            for (label, data, acc), exp in zip(hand, exps):
                if (exp["err"] == "None") != acc:
                    print("  ORACLE DISAGREES WITH MY EXPECTATION: %s (oracle %s)" % (label, exp["err"]))
                    total_problems += 1
        if cases and cases[0][0] == b"R":
            stats["oracle_accepts"] = sum(1 for e in exps if e["err"] == "None")
            stats["oracle_valid_json"] = sum(1 for e in exps if e["g"])
            stats["invalid_utf8"] = sum(1 for e in exps if not e["utf8"])
            byerr = {}
            for e in exps:
                byerr[e["err"]] = byerr.get(e["err"], 0) + 1
            stats["oracle_classes"] = byerr
        tag = "%s_%d" % (name, a.seed)
        for exe in a.exe:
            lines, fail = run(exe, cases, tag, outdir)
            exename = os.path.basename(exe)
            if fail:
                print("[%s] %s: %s" % (name, exename, fail))
                total_problems += 1
                summary.append((name, exename, len(cases), "CRASH", {}))
                continue
            kinds = {}
            nprob = 0
            utf8_dev = 0
            for i, ((kind, payload), exp) in enumerate(zip(cases, exps)):
                probs = compare(kind, exp, lines[i])
                if kind == b"R" and not exp["utf8"] and lines[i].split(" ")[1] == "1":
                    utf8_dev += 1  # the grammar accepted text that is not valid UTF-8 (C4 deviation, counted apart)
                if probs:
                    nprob += 1
                    for pr in probs:
                        key = pr.split("(")[0]
                        kinds[key] = kinds.get(key, 0) + 1
                    if nprob <= 15:
                        fn = os.path.join(outdir, "mismatch", "%s_%s_%d.bin" % (tag, os.path.splitext(exename)[0], i))
                        with open(fn, "wb") as f:
                            f.write(payload)
                        label = hand[i][0] if name == "hand" else ""
                        print("  [%s] %s case %d %s: %s | harness: %s | saved %s | %r" %
                              (name, exename, i, label, "; ".join(probs), lines[i], os.path.basename(fn), payload[:120]))
            total_problems += nprob
            tail = lines[len(cases)] if len(lines) > len(cases) else ""
            summary.append((name, exename, len(cases), nprob, dict(kinds, utf8_accepted=utf8_dev) if utf8_dev else kinds))
            print("[%s] %s: %d cases, %d disagreements %s%s %s" % (name, exename, len(cases), nprob, kinds if kinds else "",
                                                                  " [grammar accepted %d texts that are not valid UTF-8]" % utf8_dev if utf8_dev else "", tail))
        print("[%s] oracle: %s (%.1f s)" % (name, stats, time.time() - t0))
        if not a.keep:
            tmp = os.path.join(outdir, "tmp_%d" % os.getpid())
            for fn in os.listdir(tmp):
                os.remove(os.path.join(tmp, fn))
    try:
        os.rmdir(os.path.join(outdir, "tmp_%d" % os.getpid()))
    except OSError:
        pass
    print("TOTAL disagreements: %d" % total_problems)
    return 1 if total_problems else 0


if __name__ == "__main__":
    sys.exit(main())
