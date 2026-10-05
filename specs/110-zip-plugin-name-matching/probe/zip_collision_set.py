# Feature 110: which member names did the ZIP plug-in's OLD comparison take for one name?
#
#   python zip_collision_set.py [--list N]
#
# The plug-in compared member names (UTF-8 since interface 104) with
#   CompareStringA(LOCALE_USER_DEFAULT, NORM_IGNORECASE, ...) == CSTR_EQUAL
# i.e. the UTF-8 bytes read as text of the system code page, compared LINGUISTICALLY (not the
# core's byte fold of feature 108's collision_set.py). Equal sort keys (LCMapStringA with
# LCMAP_SORTKEY and the same flags) <=> CompareStringA says equal, so every character of the BMP
# (assigned, not surrogate / private / control) is put into "<c>.txt", keyed, and grouped.
#   merged : two names the old comparison called one name, the file system keeps apart
#            (CompareStringOrdinal(..., TRUE) != CSTR_EQUAL) - the defect
#   split  : two names the file system calls one (ordinal CI equal), the old comparison kept
#            apart - case pairs outside ASCII (C-caron / c-caron) and the 7 pairs with different
#            UTF-8 lengths; after feature 110 they are one name (as A.txt / a.txt always were)
# Also checked: every pair of printable ASCII characters - the old comparison and the ASCII
# fold of the new rule must agree (no change for ASCII names).
# Pure ASCII source: characters are written as chr(...).
import collections, ctypes, sys, unicodedata
from ctypes import wintypes

k = ctypes.windll.kernel32
LCMapStringA = k.LCMapStringA
LCMapStringA.argtypes = [wintypes.DWORD, wintypes.DWORD, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
CompareStringA = k.CompareStringA
CompareStringA.argtypes = [wintypes.DWORD, wintypes.DWORD, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
cso = k.CompareStringOrdinal
cso.argtypes = [ctypes.c_wchar_p, ctypes.c_int, ctypes.c_wchar_p, ctypes.c_int, ctypes.c_int]
LOCALE_USER_DEFAULT = 0x0400
NORM_IGNORECASE = 1
LCMAP_SORTKEY = 0x400


def sortkey(b, flags=NORM_IGNORECASE):
    n = LCMapStringA(LOCALE_USER_DEFAULT, LCMAP_SORTKEY | flags, b, len(b), None, 0)
    buf = ctypes.create_string_buffer(n)
    LCMapStringA(LOCALE_USER_DEFAULT, LCMAP_SORTKEY | flags, b, len(b), buf, n)
    return buf.raw


def old_equal(a, b, flags=NORM_IGNORECASE):
    return CompareStringA(LOCALE_USER_DEFAULT, flags, a, len(a), b, len(b)) == 2


def ordinal_equal(a, b):
    return cso(a, len(a), b, len(b), 1) == 2


def esc(c):
    return 'U+%04X' % ord(c)


chars = []
for cp in range(0x80, 0x10000):
    if 0xD800 <= cp < 0xE000:
        continue
    c = chr(cp)
    if unicodedata.category(c) in ('Cn', 'Cs', 'Co', 'Cc'):
        continue
    chars.append(c)

groups = collections.defaultdict(list)
for c in chars:
    groups[sortkey((c + '.txt').encode('utf-8'))].append(c)
merged = []
for cs in groups.values():
    for i in range(len(cs)):
        for j in range(i + 1, len(cs)):
            if not ordinal_equal(cs[i], cs[j]):
                merged.append((cs[i], cs[j]))
# split: ordinal-equal pairs (one upper-case class) that the old comparison keeps apart
up = collections.defaultdict(list)
for c in chars:
    buf = ctypes.create_unicode_buffer(c)
    ctypes.windll.user32.CharUpperBuffW(buf, 1)
    up[buf.value].append(c)
split = []
for u, cs in up.items():
    cs = sorted(set(cs))
    for i in range(len(cs)):
        for j in range(i + 1, len(cs)):
            a, b = cs[i], cs[j]
            if ordinal_equal(a, b) and not old_equal((a + '.txt').encode(), (b + '.txt').encode()):
                split.append((a, b))
difflen = [p for p in split if len(p[0].encode()) != len(p[1].encode())]

# ASCII: every printable pair, old vs the ASCII fold
asc_bad = []
for x in range(32, 127):
    for y in range(32, 127):
        a = ('n' + chr(x) + '.txt').encode()
        b = ('n' + chr(y) + '.txt').encode()
        fold = chr(x).upper() == chr(y).upper()
        if old_equal(a, b) != fold:
            asc_bad.append((chr(x), chr(y), old_equal(a, b)))

print('ACP %d, user locale 0x%04X' % (k.GetACP(), k.GetUserDefaultLCID()))
print('BMP characters examined: %d' % len(chars))
print('merged (old comparison: one name; file system: two): %d pairs' % len(merged))
print('  two-byte: %d; three-byte: %d; mixed length: %d (the update matching compared equal byte lengths only)' % (
    len([p for p in merged if len(p[0].encode()) == 2 and len(p[1].encode()) == 2]),
    len([p for p in merged if len(p[0].encode()) == 3 and len(p[1].encode()) == 3]),
    len([p for p in merged if len(p[0].encode()) != len(p[1].encode())])))
for name, a, b in (('h-circumflex / L-acute', chr(0x125), chr(0x139)), ('h-circumflex / l-acute', chr(0x125), chr(0x13A)),
                   ('I-acute / Y-acute', chr(0xCD), chr(0xDD)), ('z-caron / z-dot', chr(0x17E), chr(0x17C)),
                   ('CJK U+4E5D / U+4E4D', chr(0x4E5D), chr(0x4E4D)), ('Cyrillic em / o', chr(0x43C), chr(0x43E)),
                   ('C-caron / c-caron', chr(0x10C), chr(0x10D)), ('A-stroke / a-stroke', chr(0x23A), chr(0x2C65)),
                   ('e-acute NFC / NFD', chr(0xE9), 'e' + chr(0x301))):
    ea, eb = (a + '.txt').encode(), (b + '.txt').encode()
    print('  %-32s old %-5s  ordinal-CI %-5s' % (name, old_equal(ea, eb), ordinal_equal(a + '.txt', b + '.txt')))
print('split (file system: one name; old comparison: two): %d pairs, of them different UTF-8 length: %d' % (len(split), len(difflen)))
for a, b in difflen:
    print('  %s / %s' % (esc(a), esc(b)))
print('printable ASCII pairs where the old comparison differs from the ASCII fold: %d' % len(asc_bad))
for x in asc_bad[:20]:
    print('  %r %r old=%s' % x)
if '--list' in sys.argv:
    n = int(sys.argv[sys.argv.index('--list') + 1])
    for a, b in merged[:n]:
        sys.stdout.write('%s %s / %s %s\n' % (esc(a), unicodedata.name(a, '?'), esc(b), unicodedata.name(b, '?')))
