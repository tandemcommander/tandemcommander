# Feature 113 probe helper: makes the test archives (ZIP with plain, ZipCrypto and AES-256 members,
# zip64 central records, data descriptors, comments, extra blocks; 7z through 7z.exe) and the source
# files, and reads the archives back independently of the program.
#
#   python zipskip.py make <spec.json>
#   python zipskip.py read <spec.json>
#
# spec (UTF-8 JSON, never on a command line):
#   {"arc": path, "kind": "zip" | "7z", "pw": "password of the encrypted members (old and added)",
#    "sevenzip": path of 7z.exe (kind 7z),
#    "members": [{"name": "x.txt", "enc": "none"|"zipcrypto"|"aes256", "z64": false, "desc": false,
#                 "comment": "", "xtra": false, "host": "fat"|"unix", "repeat": 1}, ...],
#    "files": [{"path": full path, "tag": "S1", "size": 0, "random": false}, ...]}
#   member i (1-based) holds "content-of-member-<i>\r\n" * repeat; a source file holds
#   "content-of-source-<tag>\r\n" repeated up to "size" bytes (at least once), or "size" random bytes.
#   make writes <arc>.tags.json: sha256 of every member and source content -> its tag (m<i> / s<tag>).
#   z64   the central record keeps the local header offset in a zip64 extra block (field 0xFFFFFFFF)
#   desc  general purpose bit 3: sizes and CRC in a data descriptor (with its signature) after the data
#   xtra  an extended time stamp block (0x5455) in the local header and the central record
# read prints one line per entry:
#   ENTRY <escaped name> kind=<file|dir> tag=<m<i>|s<tag>|?> enc=<none|zipcrypto|aes256> ok=<0|1> cd=<8 hex> lh=<8 hex>
#     cd: SHA-256 of the central record with the local header offset zeroed (also in a zip64 block)
#     lh: SHA-256 of the member's bytes from its local header to the end of its data descriptor
#   then COUNT <files>, CHECK <ok | problems> (structure, overlaps, CRC / AES MAC, every entry
#   decoded) and, for ZIP, ZIPFILE <ok | ...> (Python's zipfile over the entries it can decode).
# Pure ASCII; needs Python 3.8+, "cryptography" for AES members; Windows only for 7z.exe.
import hashlib, hmac, io, json, os, re, struct, subprocess, sys, zipfile, zlib


def esc(s):
    return ''.join(c if 32 <= ord(c) < 127 else '\\u%04X' % ord(c) for c in s)


def sha8(b):
    return hashlib.sha256(b).hexdigest()[:8]


# ---- ZipCrypto (traditional PKWARE) ----------------------------------------------------------
_crctab = [0] * 256
for _i in range(256):
    _c = _i
    for _ in range(8):
        _c = (_c >> 1) ^ 0xEDB88320 if _c & 1 else _c >> 1
    _crctab[_i] = _c


class ZipCrypto:
    def __init__(self, pw):
        self.k0, self.k1, self.k2 = 0x12345678, 0x23456789, 0x34567890
        for b in pw:
            self._upd(b)

    def _upd(self, b):
        self.k0 = (self.k0 >> 8) ^ _crctab[(self.k0 ^ b) & 0xFF]
        self.k1 = ((self.k1 + (self.k0 & 0xFF)) * 134775813 + 1) & 0xFFFFFFFF
        self.k2 = (self.k2 >> 8) ^ _crctab[(self.k2 ^ (self.k1 >> 24)) & 0xFF]

    def _stream(self):
        t = (self.k2 | 2) & 0xFFFF
        return ((t * (t ^ 1)) >> 8) & 0xFF

    def decrypt(self, data):
        out = bytearray()
        for c in data:
            p = c ^ self._stream()
            self._upd(p)
            out.append(p)
        return bytes(out)

    def encrypt(self, data):
        out = bytearray()
        for p in data:
            out.append(p ^ self._stream())
            self._upd(p)
        return bytes(out)


def _aes_ctr(key, data):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    enc = Cipher(algorithms.AES(key), modes.ECB()).encryptor()
    out = bytearray()
    for i in range(0, len(data), 16):  # WinZip AES: CTR, little-endian counter from 1
        ks = enc.update(struct.pack('<QQ', i // 16 + 1, 0))
        out += bytes(a ^ b for a, b in zip(data[i:i + 16], ks))
    return bytes(out)


def aes256_payload(comp, pw, seed):
    salt = hashlib.sha256(b'113salt' + seed).digest()[:16]
    dk = hashlib.pbkdf2_hmac('sha1', pw, salt, 1000, 66)
    body = _aes_ctr(dk[:32], comp)
    mac = hmac.new(dk[32:64], body, hashlib.sha1).digest()[:10]
    return salt + dk[64:] + body + mac


def aes_open(payload, pw, strength):
    slen = {1: 8, 2: 12, 3: 16}[strength]
    klen = {1: 16, 2: 24, 3: 32}[strength]
    salt, verifier = payload[:slen], payload[slen:slen + 2]
    body, mac = payload[slen + 2:-10], payload[-10:]
    dk = hashlib.pbkdf2_hmac('sha1', pw, salt, 1000, 2 * klen + 2)
    if dk[2 * klen:] != verifier:
        raise ValueError('AES password verifier')
    if hmac.new(dk[klen:2 * klen], body, hashlib.sha1).digest()[:10] != mac:
        raise ValueError('AES MAC')
    return _aes_ctr(dk[:klen], body)


# ---- making ------------------------------------------------------------------------------------
def member_content(i, m):
    return ('content-of-member-%d\r\n' % i).encode('ascii') * max(1, int(m.get('repeat', 1)))


def source_content(f):
    size = int(f.get('size', 0))
    if f.get('random'):
        return os.urandom(size)
    line = ('content-of-source-%s\r\n' % f['tag']).encode('ascii')
    n = max(1, (size + len(line) - 1) // len(line)) if size else 1
    return line * n


def make_zip(spec, tags):
    arc = spec['arc']
    pw = spec.get('pw', '').encode('utf-8')
    out = io.BytesIO()
    central = []
    i = 0
    for m in spec.get('members', []):
        i += 1
        data = member_content(i, m)
        tags[hashlib.sha256(data).hexdigest()] = 'm%d' % i
        nb = m['name'].encode('utf-8')
        utf8 = any(x >= 0x80 for x in nb)
        crc = zlib.crc32(data) & 0xFFFFFFFF
        comp = zlib.compress(data, 6)[2:-4]
        method, flag, need = 8, (0x800 if utf8 else 0), 20
        enc = m.get('enc', 'none')
        dostime = (3 << 11) | (4 << 5) | 3
        dosdate = ((2026 - 1980) << 9) | (1 << 5) | 2
        lextra = b''
        cextra = b''
        if m.get('xtra'):
            ts = struct.pack('<HHBI', 0x5455, 5, 1, 1700000000)
            lextra += ts
            cextra += ts
        crc_field = crc
        if enc == 'zipcrypto':
            flag |= 1
            z = ZipCrypto(pw)
            head = hashlib.sha256(b'113head' + nb).digest()[:11] + bytes([(dostime >> 8) & 0xFF if m.get('desc') else crc >> 24])
            payload = z.encrypt(head) + z.encrypt(comp)
        elif enc == 'aes256':
            flag |= 1
            ae = struct.pack('<HHH2sBH', 0x9901, 7, 2, b'AE', 3, method)
            lextra += ae
            cextra += ae
            method, need, crc_field = 99, 51, 0
            payload = aes256_payload(comp, pw, nb)
        else:
            payload = comp
        if m.get('desc'):
            flag |= 8
        made = ((3 if m.get('host') == 'unix' else 0) << 8) | 20
        extattr = 0x20 | ((0o100644 << 16) if m.get('host') == 'unix' else 0)
        off = out.tell()
        if m.get('desc'):
            out.write(struct.pack('<IHHHHHIIIHH', 0x04034B50, need, flag, method, dostime, dosdate, 0, 0, 0, len(nb), len(lextra)))
        else:
            out.write(struct.pack('<IHHHHHIIIHH', 0x04034B50, need, flag, method, dostime, dosdate, crc_field, len(payload), len(data), len(nb), len(lextra)))
        out.write(nb + lextra + payload)
        if m.get('desc'):
            out.write(struct.pack('<IIII', 0x08074B50, crc_field, len(payload), len(data)))
        offfield = off
        if m.get('z64'):
            cextra = struct.pack('<HHQ', 1, 8, off) + cextra
            offfield = 0xFFFFFFFF
            need = max(need, 45)
        cm = m.get('comment', '').encode('utf-8')
        central.append(struct.pack('<IHHHHHHIIIHHHHHII', 0x02014B50, made, need, flag, method, dostime, dosdate, crc_field, len(payload),
                                   len(data), len(nb), len(cextra), len(cm), 0, 0, extattr, offfield) + nb + cextra + cm)
    cd = out.tell()
    for c in central:
        out.write(c)
    out.write(struct.pack('<IHHHHIIH', 0x06054B50, 0, 0, len(central), len(central), out.tell() - cd, cd, 0))
    with open(arc, 'wb') as f:
        f.write(out.getvalue())


def make_7z(spec, tags):
    arc = spec['arc']
    stage = arc + '.stage'
    os.makedirs(stage, exist_ok=True)
    names = []
    i = 0
    for m in spec.get('members', []):
        i += 1
        data = member_content(i, m)
        tags[hashlib.sha256(data).hexdigest()] = 'm%d' % i
        p = os.path.join(stage, m['name'].replace('/', os.sep))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'wb') as f:
            f.write(data)
        names.append(m['name'].replace('/', os.sep))
    cmd = [spec['sevenzip'], 'a', '-t7z', '-bso0', '-bsp0', arc] + names
    r = subprocess.run(cmd, cwd=stage)
    if r.returncode != 0:
        raise RuntimeError('7z a failed')
    for n in names:
        os.remove(os.path.join(stage, n))
    os.rmdir(stage)


def make(spec):
    arc = spec['arc']
    if os.path.exists(arc):
        os.remove(arc)
    tags = {}
    if spec.get('kind', 'zip') == '7z':
        make_7z(spec, tags)
    else:
        make_zip(spec, tags)
    for fl in spec.get('files', []):
        data = source_content(fl)
        tags[hashlib.sha256(data).hexdigest()] = 's' + fl['tag']
        os.makedirs(os.path.dirname(fl['path']), exist_ok=True)
        with open(fl['path'], 'wb') as f:
            f.write(data)
    with open(arc + '.tags.json', 'w', encoding='utf-8') as f:
        json.dump(tags, f)


# ---- reading -------------------------------------------------------------------------------------
def zip64_offset_pos(rec):
    """Position of the local header offset inside the zip64 block of a central record, or None."""
    nlen, xlen = struct.unpack_from('<HH', rec, 28)
    comp, size = struct.unpack_from('<II', rec, 20)
    disk, = struct.unpack_from('<H', rec, 34)
    off, = struct.unpack_from('<I', rec, 42)
    if off != 0xFFFFFFFF:
        return None
    i = 46 + nlen
    end = i + xlen
    while i + 4 <= end:
        bid, bl = struct.unpack_from('<HH', rec, i)
        if bid == 1:
            return i + 4 + (8 if size == 0xFFFFFFFF else 0) + (8 if comp == 0xFFFFFFFF else 0)
        i += 4 + bl
    return None


def read_zip(spec, tags):
    arc = spec['arc']
    pw = spec.get('pw', '').encode('utf-8')
    b = open(arc, 'rb').read()
    e = b.rfind(b'PK\x05\x06')
    if e < 0:
        print('CHECK no end of central directory')
        return
    _, _, _, _, total, cdsize, cd, _ = struct.unpack('<IHHHHIIH', b[e:e + 22])
    bad = []
    if cd + cdsize != e:
        bad.append('central directory does not end at the end record (%d + %d != %d)' % (cd, cdsize, e))
    p = cd
    files = 0
    spans = []
    for _ in range(total):
        if b[p:p + 4] != b'PK\x01\x02':
            bad.append('central record signature at %d' % p)
            break
        (sig, made, need, flag, method, t, d, crc, csize, usize, nlen, xlen, clen, disk, ia, ea, off) = struct.unpack('<IHHHHHHIIIHHHHHII', b[p:p + 46])
        rec = bytearray(b[p:p + 46 + nlen + xlen + clen])
        z = zip64_offset_pos(rec)
        if off == 0xFFFFFFFF:
            if z is None:
                bad.append('zip64 offset missing')
                break
            off = struct.unpack_from('<Q', rec, z)[0]
            rec[z:z + 8] = b'\0' * 8
        rec[42:46] = b'\0' * 4
        cdfp = sha8(bytes(rec))
        nb = b[p + 46:p + 46 + nlen]
        cextra = b[p + 46 + nlen:p + 46 + nlen + xlen]
        p += 46 + nlen + xlen + clen
        name = nb.decode('utf-8' if flag & 0x800 else 'cp437', errors='replace')
        isdir = nb.endswith(b'/') or nb.endswith(b'\\')
        tag, ok, encname, lhfp = '-', 1, 'none', '-'
        if not isdir:
            files += 1
            try:
                if b[off:off + 4] != b'PK\x03\x04':
                    raise ValueError('no local header at %d' % off)
                lsig, lneed, lflag, lmethod, _, _, _, _, _, lnl, lxl = struct.unpack('<IHHHHHIIIHH', b[off:off + 30])
                if b[off + 30:off + 30 + lnl] != nb:
                    raise ValueError('local name differs')
                data_off = off + 30 + lnl + lxl
                payload = b[data_off:data_off + csize]
                end = data_off + csize + ((16 if b[data_off + csize:data_off + csize + 4] == b'PK\x07\x08' else 12) if flag & 8 else 0)
                spans.append((off, end, name))
                lhfp = sha8(b[off:end])
                real = method
                if method == 99:
                    encname = 'aes256'
                    i = 0
                    strength = 3
                    while i + 4 <= len(cextra):
                        bid, bl = struct.unpack_from('<HH', cextra, i)
                        if bid == 0x9901:
                            _, _, strength, real = struct.unpack_from('<H2sBH', cextra, i + 4)
                        i += 4 + bl
                    comp = aes_open(payload, pw, strength)
                elif flag & 1:
                    encname = 'zipcrypto'
                    zc = ZipCrypto(pw)
                    head = zc.decrypt(payload[:12])
                    check = (t >> 8) & 0xFF if flag & 8 else crc >> 24
                    if head[11] != check:
                        raise ValueError('ZipCrypto check byte')
                    comp = zc.decrypt(payload[12:])
                else:
                    comp = payload
                data = comp if real == 0 else zlib.decompress(comp, -15)
                if len(data) != usize:
                    raise ValueError('size %d, the record says %d' % (len(data), usize))
                if method != 99 and zlib.crc32(data) & 0xFFFFFFFF != crc:
                    raise ValueError('CRC')
                tag = tags.get(hashlib.sha256(data).hexdigest(), '?')
            except Exception as ex:
                ok = 0
                bad.append('%s: %s' % (esc(name), ex))
        print('ENTRY %s kind=%s tag=%s enc=%s ok=%d cd=%s lh=%s' % (esc(name), 'dir' if isdir else 'file', tag, encname, ok, cdfp, lhfp))
    spans.sort()
    for a, c in zip(spans, spans[1:]):
        if a[1] > c[0]:
            bad.append('members overlap: %s / %s' % (esc(a[2]), esc(c[2])))
    if spans and spans[-1][1] > cd:
        bad.append('member data runs into the central directory')
    print('COUNT %d' % files)
    print('CHECK %s' % ('ok' if not bad else '; '.join(bad)))
    # Python's zipfile over what it can decode (not AES)
    try:
        with zipfile.ZipFile(arc) as zf:
            probs = []
            for zi in zf.infolist():
                if zi.compress_type == 99 or zi.is_dir():
                    continue
                try:
                    zf.read(zi, pwd=pw if zi.flag_bits & 1 else None)
                except Exception as ex:
                    probs.append('%s: %s' % (esc(zi.filename), ex))
            print('ZIPFILE %s' % ('ok' if not probs else '; '.join(probs)))
    except Exception as ex:
        print('ZIPFILE cannot open: %s' % ex)


def read_7z(spec, tags):
    arc, sz = spec['arc'], spec['sevenzip']
    pw = spec.get('pw', '')
    args = ['-p' + pw] if pw else ['-p-']
    t = subprocess.run([sz, 't', '-bso0', '-bsp0', '-bse0'] + args + [arc])
    lst = subprocess.run([sz, 'l', '-slt', '-ba', '-sccUTF-8'] + args + [arc], capture_output=True)
    files = 0
    for block in lst.stdout.decode('utf-8', errors='replace').replace('\r\n', '\n').split('\n\n'):
        m = re.search(r'^Path = (.*)$', block, re.M)
        if not m:
            continue
        name = m.group(1).strip()
        isdir = re.search(r'^Folder = \+', block, re.M) is not None
        tag = '-'
        if not isdir:
            files += 1
            x = subprocess.run([sz, 'e', '-so'] + args + [arc, name], capture_output=True)
            tag = tags.get(hashlib.sha256(x.stdout).hexdigest(), '?') if x.returncode == 0 else 'unreadable'
        print('ENTRY %s kind=%s tag=%s enc=- ok=1 cd=- lh=-' % (esc(name.replace('\\', '/')), 'dir' if isdir else 'file', tag))
    print('COUNT %d' % files)
    print('CHECK %s' % ('ok' if t.returncode == 0 else '7z t exit %d' % t.returncode))


def read(spec):
    tags = json.load(io.open(spec['arc'] + '.tags.json', 'r', encoding='utf-8'))
    if spec.get('kind', 'zip') == '7z':
        read_7z(spec, tags)
    else:
        read_zip(spec, tags)


if __name__ == '__main__':
    spec = json.load(io.open(sys.argv[2], 'r', encoding='utf-8'))
    if sys.argv[1] == 'make':
        make(spec)
    else:
        read(spec)
