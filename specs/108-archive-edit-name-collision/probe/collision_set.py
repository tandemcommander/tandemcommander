# Feature 108: the names that the OLD identity of an edited archive member (StrICmp, the
# code-page byte fold of str.cpp: LowerCase[i] = CharLowerA(i)) took for one name although the
# file system keeps them apart (CompareStringOrdinal(..., TRUE) says "different").
#
#   python collision_set.py        -> counts and the two-byte pairs of this machine's code page
#
# Every character of the BMP (assigned, not a surrogate / private / control) is encoded in UTF-8,
# folded byte by byte through CharLowerA, and grouped by the folded bytes; a pair from one group
# that is NOT equal by the ordinal case-insensitive rule is a collision.
import collections, ctypes, sys, unicodedata

u = ctypes.windll.user32
k = ctypes.windll.kernel32
LC = [0] * 256
for i in range(1, 256):
    LC[i] = u.CharLowerA(ctypes.c_void_p(i)) & 0xFF
cso = k.CompareStringOrdinal
cso.argtypes = [ctypes.c_wchar_p, ctypes.c_int, ctypes.c_wchar_p, ctypes.c_int, ctypes.c_int]


def fold(b):
    return bytes(LC[x] for x in b)


def ordinal_equal(a, b):
    return cso(a, len(a), b, len(b), 1) == 2


def esc(c):
    return 'U+%04X' % ord(c)


groups = collections.defaultdict(list)
for cp in range(0x80, 0x10000):
    if 0xD800 <= cp < 0xE000:
        continue
    c = chr(cp)
    if unicodedata.category(c) in ('Cn', 'Cs', 'Co', 'Cc'):
        continue
    groups[fold(c.encode('utf-8'))].append(c)
pairs = []
for cs in groups.values():
    for i in range(len(cs)):
        for j in range(i + 1, len(cs)):
            if not ordinal_equal(cs[i], cs[j]):
                pairs.append((cs[i], cs[j]))
two = [p for p in pairs if len(p[0].encode()) == 2 and len(p[1].encode()) == 2]
three = [p for p in pairs if len(p[0].encode()) == 3 and len(p[1].encode()) == 3]
print('ACP %d' % k.GetACP())
print('pairs that the byte fold merges and the file system keeps apart: %d' % len(pairs))
print('  two-byte characters: %d; three-byte characters: %d' % (len(two), len(three)))
print('  CJK ideograph pairs (U+4E00-9FFF): %d' %
      len([p for p in three if all(0x4E00 <= ord(c) <= 0x9FFF for c in p)]))
print('  Cyrillic pairs: %d' % len([p for p in two if all(0x400 <= ord(c) <= 0x4FF for c in p)]))
for a, b in two:
    sys.stdout.write('%s %s / %s %s\n' % (esc(a), unicodedata.name(a, '?'), esc(b), unicodedata.name(b, '?')))
