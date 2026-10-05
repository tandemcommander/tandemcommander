# Feature 117 fixtures: files with Czech, Cyrillic, CJK, lone-surrogate and look-alike names,
# and checksum lists that name them in every encoding real tools write (measured in
# research.md section A). Writes <dir>\data\..., <dir>\rt\... and <dir>\expected117.json.
#
#   python make_lists117.py <dir>
#
# Verdicts: OK, CORRUPT, MISSING, SKIPPED (the build before: the open fails, the error box is
# answered Skip). A list-level "BADFILE" = the plug-in refuses the list ("not a checksum file").
# The code-page lists are written for code page 1250 and OEM 852 (this machine's ACP / OEMCP);
# the probe reports them NOT DRIVEN on another code page.
import ctypes
import hashlib
import json
import os
import sys
import zlib

root = os.path.abspath(sys.argv[1])
data = os.path.join(root, 'data')
rt = os.path.join(root, 'rt')
os.makedirs(os.path.join(data, 'sub'), exist_ok=True)
os.makedirs(os.path.join(rt, 'sub'), exist_ok=True)

CZ = '\u010de\u0161tina.txt'        # cestina with c-caron, s-caron
VG = 'voil\u00e0.txt'               # a-grave
VP = 'voila.txt'                    # its ASCII look-alike (decoy, other content)
RU = '\u0416\u0443\u043a.txt'       # Cyrillic
JP = '\u65e5\u672c.txt'             # CJK
SP = 'a b.txt'
ABC = 'abc.txt'                     # what "???.txt" would match as a wildcard (decoy)
RZ = 'sub/\u0159.txt'               # r-caron in a subfolder
LS = 'lone\ud800.txt'               # an unpaired surrogate (legal on NTFS)

content = {CZ: 'TC117 cestina', VG: 'TC117 voila grave', VP: 'TC117 voila plain (decoy)',
           RU: 'TC117 zhuk', JP: 'TC117 nihon', SP: 'TC117 a b', ABC: 'TC117 abc (decoy)',
           RZ: 'TC117 r-caron in sub', LS: 'TC117 lone surrogate'}


def fs(name):
    return name.replace('/', os.sep)


for n, c in content.items():
    with open(os.path.join(data, fs(n)), 'wb') as f:
        f.write(c.encode('ascii'))
for n in (CZ, VG, VP, RU, JP, SP, RZ):   # the round-trip folder (no lone surrogate: coreutils cannot name it)
    with open(os.path.join(rt, fs(n)), 'wb') as f:
        f.write(content[n].encode('ascii'))


def digest(kind, name):
    b = content[name].encode('ascii')
    if kind == 'crc':
        return '%08x' % (zlib.crc32(b) & 0xFFFFFFFF)
    return hashlib.new(kind, b).hexdigest()


def enc_text(text, how):
    if how == 'utf8':
        return text.encode('utf-8', 'surrogatepass')
    if how == 'utf8bom':
        return b'\xef\xbb\xbf' + text.encode('utf-8', 'surrogatepass')
    if how == 'utf16le':
        return b'\xff\xfe' + text.encode('utf-16-le', 'surrogatepass')
    if how == 'utf16be':
        return b'\xfe\xff' + text.encode('utf-16-be', 'surrogatepass')
    if how == 'utf16le-nobom':
        return text.encode('utf-16-le', 'surrogatepass')
    if how == 'cp1250':
        return text.encode('cp1250')    # strict: the fixture holds only names that fit
    if how == 'oem852':
        return text.encode('cp852')
    raise ValueError(how)


lists = []


def add(fname, how, kind, form, rows, eol, what, before_list=None, header='', raw_after=None):
    """rows: (written name, hashed file, after, before, display, why)"""
    lines = []
    for written, hashed, after, before, display, why in rows:
        h = digest(kind, hashed)
        if form == 'hashfirst':
            lines.append('%s  %s' % (h, written))
        elif form == 'binary':
            lines.append('%s *%s' % (h, written))
        elif form == 'tag':
            lines.append('%s (%s) = %s' % (kind.upper(), written, h))
        elif form == 'sfv':
            lines.append('%s  %s' % (written, h))
        elif form == 'gnu-escaped':
            lines.append('\\%s *%s' % (h, written.replace('\\', '\\\\')))
        else:
            raise ValueError(form)
    text = header + ''.join(l + eol for l in lines)
    b = enc_text(text, how)
    if raw_after is not None:
        b = raw_after(b)
    with open(os.path.join(data, fname), 'wb') as f:
        f.write(b)
    lists.append({'file': fname, 'encoding': how, 'what': what, 'before_list': before_list,
                  'rows': [{'name': r[4] if r[4] is not None else r[0].replace('/', '\\'),
                            'after': r[2], 'before': r[3], 'why': r[5]} for r in rows]})


# L1 the control: UTF-8 without a mark, LF (sha256sum, 7-Zip, Tandem 0.1.x) - every build reads it
add('utf8.sha256', 'utf8', 'sha256', 'hashfirst', [
    (CZ, CZ, 'OK', 'OK', None, ''), (VG, VG, 'OK', 'OK', None, 'a-grave: never the decoy'),
    (VP, VP, 'OK', 'OK', None, 'the decoy itself'), (RU, RU, 'OK', 'OK', None, ''),
    (JP, JP, 'OK', 'OK', None, ''), (RZ, RZ, 'OK', 'OK', None, 'subfolder'),
    (SP, SP, 'OK', 'OK', None, ''), (LS, LS, 'OK', 'OK', None, 'WTF-8 lone surrogate')],
    '\n', 'UTF-8, no mark, LF (coreutils / 7-Zip / Tandem 0.1.x): the control')

# L2 UTF-8 with a mark, CRLF, backslashes (Total Commander with a Unicode name; PS Out-File -Encoding utf8)
add('utf8bom.sha256', 'utf8bom', 'sha256', 'hashfirst', [
    (CZ, CZ, 'OK', '-', None, ''), (VG, VG, 'OK', '-', None, ''), (RU, RU, 'OK', '-', None, ''),
    (JP, JP, 'OK', '-', None, ''), ('sub\\\u0159.txt', RZ, 'OK', '-', None, 'backslash')],
    '\r\n', 'UTF-8 with a byte order mark, CRLF (Total Commander, Out-File -Encoding utf8)', before_list='BADFILE')

# L3 UTF-16 LE with a mark, CRLF (Windows PowerShell 5.1 '>' / Out-File default)
add('ps_utf16le.sha256', 'utf16le', 'sha256', 'hashfirst', [
    (CZ, CZ, 'OK', '-', None, ''), (VG, VG, 'OK', '-', None, ''), (RU, RU, 'OK', '-', None, ''),
    (JP, JP, 'OK', '-', None, ''), (SP, SP, 'OK', '-', None, ''), (LS, LS, 'OK', '-', None, 'lone surrogate')],
    '\r\n', 'UTF-16 LE with a mark, CRLF (PowerShell 5.1 > / Out-File)', before_list='BADFILE')

# L4 UTF-16 BE with a mark, BSD tag form, MD5
add('utf16be.md5', 'utf16be', 'md5', 'tag', [
    (CZ, CZ, 'OK', '-', None, ''), (JP, JP, 'OK', '-', None, ''), (RZ, RZ, 'OK', '-', None, '')],
    '\r\n', 'UTF-16 BE with a mark, "MD5 (name) = hash"', before_list='BADFILE')

# L5 UTF-16 LE without a mark, SHA-1
add('utf16le_nobom.sha1', 'utf16le-nobom', 'sha1', 'hashfirst', [
    (CZ, CZ, 'OK', '-', None, ''), (RU, RU, 'OK', '-', None, '')],
    '\r\n', 'UTF-16 LE without a mark', before_list='BADFILE')

# L6 the code page, as PowerShell Set-Content writes it: best fit by the WRITER (voila) and '?'
# for what does not fit (Cyrillic -> ???)
add('cp1250_setcontent.sha256', 'cp1250', 'sha256', 'hashfirst', [
    (CZ, CZ, 'OK', 'MISSING', None, 'code-page c-caron'),
    (SP, SP, 'OK', 'OK', None, 'ASCII'),
    ('voila.txt', VG, 'CORRUPT', 'CORRUPT', None, 'the writer best-fitted voila-grave to voila: the list names the decoy - never matched back to a-grave'),
    ('???.txt', RU, 'MISSING', 'SKIPPED', None, 'what Set-Content wrote for the Cyrillic name: the build before found abc.txt / the Cyrillic file by wildcard'),
    (RZ, RZ, 'OK', 'MISSING', None, 'r-caron in sub')],
    '\r\n', 'code page 1250, CRLF (PowerShell Set-Content, older tools)')

# L7 Open Salamander's own SFV: code page, ';' header, backslashes, CRLF
add('opensal.sfv', 'cp1250', 'crc', 'sfv', [
    (CZ, CZ, 'OK', 'MISSING', None, ''), ('sub\\\u0159.txt', RZ, 'OK', 'MISSING', None, ''),
    (SP, SP, 'OK', 'OK', None, '')],
    '\r\n', 'code page 1250 SFV with a ; header (Open Salamander, Tandem before 0.1.0)',
    header='; Generated by Open Salamander\r\n;\r\n')

# L8 OEM 852 (a DOS tool): read as the code page - accented names are reported, never another file
add('oem852.md5', 'oem852', 'md5', 'hashfirst', [
    (CZ, CZ, 'MISSING', 'MISSING', '\u017ae\u00e7tina.txt', 'OEM is not detected (no signal tells it from ACP): read as CP1250 "z-acute e c-cedilla tina" - reported missing'),
    (SP, SP, 'OK', 'OK', None, '')],
    '\r\n', 'OEM 852 (DOS tools) - a recorded limit')

# L9 ./ prefixes, .. and empty components (find . -exec sha256sum)
add('dotslash.sha256', 'utf8', 'sha256', 'hashfirst', [
    ('./' + CZ, CZ, 'OK', 'MISSING', None, './'),
    ('./' + RZ, RZ, 'OK', 'MISSING', None, './sub/'),
    ('sub/../' + SP, SP, 'OK', 'MISSING', None, 'sub/../'),
    ('sub//\u0159.txt', RZ, 'OK', 'MISSING', None, 'an empty component'),
    ('../data/' + VG, VG, 'OK', 'MISSING', None, '../ back into the folder')],
    '\n', 'UTF-8 with ./ .. and // (find . -exec sha256sum {} +)')

# L10 GNU coreutils escape (sha256sum sub\r-caron.txt from cmd: "\hash *sub\\name") + binary marker
add('gnu_escape.sha256', 'utf8', 'sha256', 'gnu-escaped', [
    ('sub\\\u0159.txt', RZ, 'OK', '-', 'sub\\\u0159.txt', 'escaped backslash')],
    '\n', 'GNU coreutils escaped line', before_list='BADFILE')

# L11 two marked UTF-8 lists concatenated (a mark at the start of a line)
def concat(b):
    second = b'\xef\xbb\xbf' + ('%s  %s\r\n' % (digest('sha256', JP), JP)).encode('utf-8')
    return b + second
add('concat.sha256', 'utf8bom', 'sha256', 'hashfirst', [
    (CZ, CZ, 'OK', '-', None, '')],
    '\r\n', 'two marked UTF-8 lists concatenated', before_list='BADFILE', raw_after=concat)
lists[-1]['rows'].append({'name': JP, 'after': 'OK', 'before': '-', 'why': 'after the inner mark'})

# L12 a marked UTF-8 list with one byte that is not UTF-8
def breakit(b):
    return b.replace('voilX.txt'.encode('ascii'), b'voil\xe0.txt')
add('broken_utf8bom.sha256', 'utf8bom', 'sha256', 'hashfirst', [
    (CZ, CZ, 'OK', '-', None, ''),
    ('voilX.txt', VG, 'MISSING', '-', 'voil\ufffd.txt', 'a code-page byte inside UTF-8: shown as U+FFFD, reported - never voila-grave / voila'),
    (RU, RU, 'OK', '-', None, '')],
    '\r\n', 'UTF-8 with a mark and one broken byte', before_list='BADFILE', raw_after=breakit)

# L13 wildcard characters and a folder named in a UTF-8 list
add('wild.sha256', 'utf8', 'sha256', 'hashfirst', [
    ('voil?.txt', VG, 'MISSING', 'SKIPPED', None, 'a wildcard: the build before matched a voila file by look-up, then failed to open it'),
    ('sub', SP, 'MISSING', 'SKIPPED', None, 'a folder is not a file'),
    (JP, JP, 'OK', 'OK', None, '')],
    '\n', 'wildcards and a folder in a UTF-8 list')

# L14 absolute names (review B1): the list's own drive works; another drive, any UNC spelling and
# a stream are reported missing WITHOUT a look-up (the build before: joined to the folder - missing)
drive = os.path.splitdrive(data)[0]
other = 'D:' if drive.upper() != 'D:' else 'E:'
add('absolute.sha256', 'utf8', 'sha256', 'hashfirst', [
    (data + '\\' + CZ, CZ, 'OK', 'MISSING', None, 'absolute, on the list\'s own drive'),
    (other + '\\tc117-none\\' + SP, SP, 'MISSING', 'MISSING', None, 'absolute, another drive: never looked up'),
    ('//127.0.0.1/tc117-none/' + SP, SP, 'MISSING', 'MISSING', '\\\\127.0.0.1\\tc117-none\\' + SP, 'UNC: never looked up (no connection)'),
    ('\\\\?\\UNC\\127.0.0.1\\tc117-none\\' + SP, SP, 'MISSING', 'MISSING', None, 'extended UNC'),
    (CZ + ':secret', CZ, 'MISSING', 'MISSING', None, 'an alternate data stream'),
    (JP, JP, 'OK', 'OK', None, '')],
    '\n', 'absolute names, UNC, a stream')

# L15 / L16 trailing NUL bytes (review S1: the first 117 version refused these, 0.1.8 read them)
def pad(k):
    return lambda b: b + b'\0' * k
add('nul_tail1.sha256', 'utf8', 'sha256', 'hashfirst', [
    (CZ, CZ, 'OK', 'OK', None, ''), (JP, JP, 'OK', 'OK', None, 'one NUL after the text')],
    '\n', 'UTF-8 + one trailing NUL', raw_after=pad(1))
add('nul_tail11.sha256', 'utf8', 'sha256', 'hashfirst', [
    (CZ, CZ, 'OK', 'OK', None, ''), (JP, JP, 'OK', 'OK', None, '11 NULs of padding')],
    '\n', 'UTF-8 + 11 NULs of padding', raw_after=pad(11))

with open(os.path.join(root, 'expected117.json'), 'w', encoding='ascii') as f:
    json.dump({'acp': ctypes.windll.kernel32.GetACP(), 'oemcp': ctypes.windll.kernel32.GetOEMCP(),
               'lists': lists,
               'rt': [n.replace('/', '\\') for n in (CZ, VG, VP, RU, JP, SP, RZ)]}, f, indent=1)
print('%d lists, %d files' % (len(lists), len(content)))
