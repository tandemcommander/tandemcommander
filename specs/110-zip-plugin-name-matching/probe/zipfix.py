# Feature 110 probe helper: makes the test ZIP archives and source files, and reads them back
# independently of the program (its own central-directory reader, no zipfile decoding of names).
#
#   python zipfix.py make <spec.json>
#   python zipfix.py read <spec.json> <marker>
#   python zipfix.py tree <dir> <marker>
#
# spec (UTF-8 JSON, never on a command line):
#   {"arc": path,
#    "members": [{"name": "dir/name.txt", "enc": "utf8"|"oem"|"raw", "raw": "hex", "host": "fat"|"unix"|"ntfs",
#                 "dir": false}, ...],
#    "files": [{"path": full path on disk, "tag": "S1"}, ...]}
#   member i (1-based, files only) holds "content-of-member-<i>\r\n"; a disk file holds
#   "content-of-source-<tag>\r\n".
#   enc utf8 : the UTF-8 name, general purpose bit 11 set when not ASCII (what Python, 7-Zip and
#              the ZIP plug-in write)
#   enc oem  : the name in the OEM code page of this machine (GetOEMCP), bit 11 clear - an old
#              DOS / Windows XP archive
#   enc raw  : the bytes given in "raw" (hex), bit 11 SET although they are not UTF-8
#   host     : "version made by" high byte: fat 0, unix 3, ntfs 11 (version 20 = 2.0)
# read prints one line per entry (files AND folders):
#   ENTRY <escaped name> raw=<hex or -> utf8=<0|1> host=<n> kind=<file|dir> tag=<m<i>|s<tag>|?> markers=<n>
# then COUNT <files> and CHECK <ok|...> (CRC of every file entry).
import ctypes, io, json, os, re, struct, sys, zlib


def esc(s):
    return ''.join(c if 32 <= ord(c) < 127 else '\\u%04X' % ord(c) for c in s)


OEM = 'cp%d' % ctypes.windll.kernel32.GetOEMCP()
HOST = {'fat': 0, 'unix': 3, 'ntfs': 11}


def name_bytes(m):
    enc = m.get('enc', 'utf8')
    if enc == 'raw':
        return bytes.fromhex(m['raw']), True
    n = m['name']
    if m.get('dir') and not n.endswith('/'):
        n += '/'
    if enc == 'oem':
        return n.encode(OEM), False
    b = n.encode('utf-8')
    return b, any(x >= 0x80 for x in b)


def make(spec):
    arc = spec['arc']
    if os.path.exists(arc):
        os.remove(arc)
    out = io.BytesIO()
    central = []
    i = 0
    for m in spec.get('members', []):
        nb, utf8 = name_bytes(m)
        isdir = bool(m.get('dir'))
        if isdir:
            data = b''
        else:
            i += 1
            data = ('content-of-member-%d\r\n' % i).encode('ascii')
        crc = zlib.crc32(data) & 0xFFFFFFFF
        comp = data if isdir else zlib.compress(data, 6)[2:-4]
        method = 0 if isdir else 8
        flag = 0x800 if utf8 else 0
        dostime = (3 << 11) | (4 << 5) | 3
        dosdate = ((2026 - 1980) << 9) | (1 << 5) | 2
        made = (HOST[m.get('host', 'fat')] << 8) | 20
        extattr = 0x10 if isdir else 0x20
        if m.get('host') == 'unix':
            extattr |= ((0o40755 if isdir else 0o100644) << 16)
        off = out.tell()
        out.write(struct.pack('<IHHHHHIIIHH', 0x04034B50, 20, flag, method, dostime, dosdate, crc, len(comp), len(data), len(nb), 0))
        out.write(nb)
        out.write(comp)
        central.append(struct.pack('<IHHHHHHIIIHHHHHII', 0x02014B50, made, 20, flag, method, dostime, dosdate, crc, len(comp), len(data),
                                   len(nb), 0, 0, 0, 0, extattr, off) + nb)
    cd = out.tell()
    for c in central:
        out.write(c)
    cdsize = out.tell() - cd
    out.write(struct.pack('<IHHHHIIH', 0x06054B50, 0, 0, len(central), len(central), cdsize, cd, 0))
    with open(arc, 'wb') as f:
        f.write(out.getvalue())
    for fl in spec.get('files', []):
        d = os.path.dirname(fl['path'])
        os.makedirs(d, exist_ok=True)
        with open(fl['path'], 'wb') as f:
            f.write(('content-of-source-%s\r\n' % fl['tag']).encode('ascii'))


def decode_name(nb, flag, made):
    if flag & 0x800:
        try:
            return nb.decode('utf-8'), True
        except UnicodeDecodeError:
            return None, False
    try:
        return nb.decode(OEM if (made >> 8) in (0, 6, 11) else 'cp%d' % ctypes.windll.kernel32.GetACP()), False
    except UnicodeDecodeError:
        return None, False


def describe_data(data, marker):
    t = data or b''
    m = re.search(rb'content-of-member-(\d+)', t)
    s = re.search(rb'content-of-source-(\w+)', t)
    tag = ('m' + m.group(1).decode()) if m else (('s' + s.group(1).decode()) if s else '?')
    return tag, t.count(marker.encode('ascii'))


def read(spec, marker):
    arc = spec['arc']
    b = open(arc, 'rb').read()
    e = b.rfind(b'PK\x05\x06')
    if e < 0:
        print('CHECK no end of central directory')
        return
    _, _, _, _, total, cdsize, cd, _ = struct.unpack('<IHHHHIIH', b[e:e + 22])
    p = cd
    files = 0
    bad = []
    for _ in range(total):
        (sig, made, need, flag, method, t, d, crc, csize, usize, nlen, xlen, clen, disk, ia, ea, off) = struct.unpack('<IHHHHHHIIIHHHHHII', b[p:p + 46])
        if sig != 0x02014B50:
            bad.append('central header signature')
            break
        nb = b[p + 46:p + 46 + nlen]
        p += 46 + nlen + xlen + clen
        name, utf8 = decode_name(nb, flag, made)
        isdir = nb.endswith(b'/') or nb.endswith(b'\\')
        shown = esc(name) if name is not None else '<undecodable>'
        rawhex = nb.hex() if (name is None or any(x >= 0x80 for x in nb)) else '-'
        tag, n = '-', 0
        if not isdir:
            files += 1
            lsig, _, lflag, lmethod, _, _, _, lc, lu, lnl, lxl = struct.unpack('<IHHHHHIIIHH', b[off:off + 30])
            data_off = off + 30 + lnl + lxl
            comp = b[data_off:data_off + csize]
            try:
                data = comp if method == 0 else zlib.decompress(comp, -15)
                if zlib.crc32(data) & 0xFFFFFFFF != crc:
                    bad.append('CRC ' + shown)
            except Exception as ex:
                data = None
                bad.append('data %s: %s' % (shown, ex))
            tag, n = describe_data(data, marker)
        print('ENTRY %s raw=%s utf8=%d host=%d kind=%s tag=%s markers=%d' % (shown, rawhex, 1 if flag & 0x800 else 0, made >> 8,
                                                                            'dir' if isdir else 'file', tag, n))
    print('COUNT %d' % files)
    print('CHECK %s' % ('ok' if not bad else '; '.join(bad)))


def tree(root, marker):
    for dp, dn, fn in os.walk(root):
        for f in sorted(fn):
            full = os.path.join(dp, f)
            tag, n = describe_data(open(full, 'rb').read(), marker)
            print('FILE %s tag=%s markers=%d' % (esc(os.path.relpath(full, root).replace(os.sep, '/')), tag, n))


if __name__ == '__main__':
    if sys.argv[1] == 'tree':
        tree(sys.argv[2], sys.argv[3])
    else:
        spec = json.load(io.open(sys.argv[2], 'r', encoding='utf-8'))
        if sys.argv[1] == 'make':
            make(spec)
        else:
            read(spec, sys.argv[3])
