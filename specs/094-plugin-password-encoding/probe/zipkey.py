# Feature 094 research probe: which BYTES is a ZIP archive's password?
#
# ZIP encryption works on password bytes; no standard says how typed text
# becomes bytes. This module
#   * derives the candidate byte strings of a typed password (Windows
#     conversions done by WideCharToMultiByte / CharToOemA themselves, so the
#     results are what a Windows program gets on THIS machine),
#   * tests which candidates open each encrypted item of an archive
#       ZIP 2.0 ("ZipCrypto"): 1-byte check, then full decrypt + inflate + CRC-32
#       WinZip AES (AE-1/AE-2): 2-byte verifier, then HMAC-SHA1 of the data
#   * writes small archives encrypted with an exact byte string (stored
#     method), to see what other programs accept.
#
# Pure ASCII source; test strings are built from character codes.
# Needs: Python 3.8+, Windows; "cryptography" only for make_aes().

import ctypes
import hashlib
import hmac
import struct
import sys
import zipfile
import zlib

CP_ACP, CP_OEMCP, CP_UTF8 = 0, 1, 65001
_k32 = ctypes.windll.kernel32
_u32 = ctypes.windll.user32


def wc2mb(text, cp):
    """(bytes, lossy) as WideCharToMultiByte(cp, 0, ...) gives them."""
    if text == '':
        return b'', False
    w = ctypes.create_unicode_buffer(text)
    n = len(text.encode('utf-16-le')) // 2
    used = ctypes.c_int(0)
    p_used = None if cp == CP_UTF8 else ctypes.byref(used)
    need = _k32.WideCharToMultiByte(cp, 0, w, n, None, 0, None, p_used)
    buf = ctypes.create_string_buffer(need)
    _k32.WideCharToMultiByte(cp, 0, w, n, buf, need, None, p_used)
    return buf.raw[:need], bool(used.value)


def char_to_oem(b):
    """CharToOemA on ANSI bytes (what the ZIP plug-in's InitKeys retries with)."""
    src = ctypes.create_string_buffer(b)
    dst = ctypes.create_string_buffer(len(b) * 2 + 2)
    _u32.CharToOemA(src, dst)
    return dst.value


def candidates(text):
    """Ordered list of (name, bytes, note). Duplicates are kept: the table shows them."""
    acp, acp_lossy = wc2mb(text, CP_ACP)
    oem, oem_lossy = wc2mb(text, CP_OEMCP)
    utf8 = text.encode('utf-8')
    out = [
        ('utf8', utf8, ''),
        ('acp', acp, 'lossy' if acp_lossy else ''),
        ('oem', oem, 'lossy' if oem_lossy else ''),
        ('acp->CharToOem', char_to_oem(acp), 'lossy' if acp_lossy else ''),
        ('utf16le', text.encode('utf-16-le'), ''),
    ]
    # the 7-Zip plug-in's legacy form (093): UTF-8 bytes read as code-page text, then UTF-8 again
    w = ctypes.create_unicode_buffer(len(utf8) + 1)
    n = _k32.MultiByteToWideChar(CP_ACP, 0, utf8, len(utf8), w, len(utf8) + 1)
    out.append(('utf8-as-acp->utf8', w[:n].encode('utf-8'), ''))
    return out


# ---- ZIP 2.0 stream cipher ---------------------------------------------------
_crctab = []
for _i in range(256):
    _c = _i
    for _ in range(8):
        _c = (_c >> 1) ^ 0xEDB88320 if _c & 1 else _c >> 1
    _crctab.append(_c)


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


# ---- reading -------------------------------------------------------------------
def _local_data(f, zi):
    f.seek(zi.header_offset)
    h = f.read(30)
    sig, ver, flag, method, mtime, mdate, crc, csize, usize, nlen, xlen = struct.unpack('<IHHHHHIIIHH', h)
    if sig != 0x04034B50:
        raise ValueError('no local header')
    f.seek(nlen, 1)
    extra = f.read(xlen)
    return flag, method, mtime, extra, f.read(zi.compress_size)


def _aes_extra(extra):
    i = 0
    while i + 4 <= len(extra):
        tag, ln = struct.unpack_from('<HH', extra, i)
        if tag == 0x9901:
            ver, vendor, strength, method = struct.unpack_from('<H2sBH', extra, i + 4)
            return ver, strength, method
        i += 4 + ln
    return None


def _inflate(method, data):
    if method == 0:
        return data
    if method == 8:
        return zlib.decompress(data, -15)
    raise ValueError('method %d' % method)


def test_item(f, zi, pw):
    """Returns 'OPENS', 'check only' (weak check passed, content wrong) or ''."""
    flag, method, mtime, extra, data = _local_data(f, zi)
    if method == 99:
        ver, strength, real = _aes_extra(extra)
        slen = {1: 8, 2: 12, 3: 16}[strength]
        klen = {1: 16, 2: 24, 3: 32}[strength]
        salt, verifier = data[:slen], data[slen:slen + 2]
        body, mac = data[slen + 2:-10], data[-10:]
        dk = hashlib.pbkdf2_hmac('sha1', pw, salt, 1000, 2 * klen + 2)
        if dk[2 * klen:] != verifier:
            return ''
        good = hmac.new(dk[klen:2 * klen], body, hashlib.sha1).digest()[:10] == mac
        return 'OPENS' if good else 'check only'
    z = ZipCrypto(pw)
    head = z.decrypt(data[:12])
    check = (mtime >> 8) & 0xFF if flag & 8 else (zi.CRC >> 24) & 0xFF
    if head[11] != check:
        return ''
    try:
        plain = _inflate(method, z.decrypt(data[12:]))
    except Exception:
        return 'check only'
    return 'OPENS' if (zlib.crc32(plain) & 0xFFFFFFFF) == zi.CRC else 'check only'


def describe(path):
    """[(name, kind)] for the encrypted items of an archive."""
    res = []
    with zipfile.ZipFile(path) as z, open(path, 'rb') as f:
        for zi in z.infolist():
            if not zi.flag_bits & 1:
                res.append((zi.filename, 'not encrypted', zi))
                continue
            flag, method, mtime, extra, data = _local_data(f, zi)
            if method == 99:
                ver, strength, real = _aes_extra(extra)
                kind = 'AES-%d AE-%d' % ({1: 128, 2: 192, 3: 256}[strength], ver)
            else:
                kind = 'ZipCrypto'
            res.append((zi.filename, kind, zi))
    return res


def which(path, text):
    """{item: (kind, [names of the candidates that open it])}"""
    out = {}
    cands = candidates(text)
    with open(path, 'rb') as f:
        for name, kind, zi in describe(path):
            if kind == 'not encrypted':
                out[name] = (kind, [])
                continue
            hits = []
            for cname, cb, note in cands:
                r = test_item(f, zi, cb)
                if r:
                    hits.append(cname + ('' if r == 'OPENS' else '(' + r + ')'))
            out[name] = (kind, hits)
    return out


# ---- writing (stored method, exact password bytes) -----------------------------
def _write_zip(path, name, flag, method, crc, payload, usize, extra, dosdt=(0x6000, 0x5B41)):
    nb = name.encode('ascii')
    lh = struct.pack('<IHHHHHIIIHH', 0x04034B50, 51 if method == 99 else 20, flag, method, dosdt[0], dosdt[1],
                     crc, len(payload), usize, len(nb), len(extra)) + nb + extra
    cd = struct.pack('<IHHHHHHIIIHHHHHII', 0x02014B50, 63, 51 if method == 99 else 20, flag, method, dosdt[0], dosdt[1],
                     crc, len(payload), usize, len(nb), len(extra), 0, 0, 0, 0x20, 0) + nb + extra
    end = struct.pack('<IHHHHIIH', 0x06054B50, 0, 0, 1, 1, len(cd), len(lh) + len(payload), 0)
    with open(path, 'wb') as f:
        f.write(lh + payload + cd + end)


def make_zipcrypto(path, name, data, pw, rnd=b'\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb'):
    crc = zlib.crc32(data) & 0xFFFFFFFF
    z = ZipCrypto(pw)
    payload = z.encrypt(rnd + bytes([crc >> 24]) + data)
    _write_zip(path, name, 1, 0, crc, payload, len(data), b'')


def make_aes256(path, name, data, pw, salt=bytes(range(1, 17))):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    dk = hashlib.pbkdf2_hmac('sha1', pw, salt, 1000, 66)
    enc = Cipher(algorithms.AES(dk[:32]), modes.ECB()).encryptor()
    body = bytearray()
    for i in range(0, len(data), 16):                   # CTR, little-endian counter from 1
        ks = enc.update(struct.pack('<QQ', i // 16 + 1, 0))
        body += bytes(a ^ b for a, b in zip(data[i:i + 16], ks))
    mac = hmac.new(dk[32:64], bytes(body), hashlib.sha1).digest()[:10]
    extra = struct.pack('<HHH2sBH', 0x9901, 7, 2, b'AE', 3, 0)
    _write_zip(path, name, 1, 99, 0, salt + dk[64:] + bytes(body) + mac, len(data), extra)


def esc(text):
    return ''.join(c if 32 <= ord(c) < 127 else '\\u%04X' % ord(c) for c in text)


def _text(arg):
    return ''.join(chr(int(x, 16)) for x in arg.split(',')) if arg else ''


if __name__ == '__main__':
    # zipkey.py which <archive> <password as hex code points: 68,65,73,6C,6F,2D,159> [-q]
    #     -q: one line per item: "<item>|<kind>|<candidate names that open it>"
    # zipkey.py make <zipcrypto|aes256> <candidate name> <password code points> <archive> <file>
    #     writes <file> (stored) encrypted with that candidate's bytes
    # zipkey.py bytes <password code points> <candidate name>   -> hex
    cmd = sys.argv[1]
    if cmd == 'which':
        text = _text(sys.argv[3])
        quiet = len(sys.argv) > 4 and sys.argv[4] == '-q'
        if not quiet:
            print('typed: %s' % esc(text))
            for cname, cb, note in candidates(text):
                print('  candidate %-18s %s %s' % (cname, cb.hex(' '), note))
        for item, (kind, hits) in which(sys.argv[2], text).items():
            if quiet:
                print('%s|%s|%s' % (item, kind, ', '.join(hits) if hits else 'NO CANDIDATE'))
            else:
                print('%s [%s]: %s' % (item, kind, ', '.join(hits) if hits else 'NO CANDIDATE OPENS IT'))
    elif cmd == 'make':
        kind, cname, text, arc, src = sys.argv[2:7]
        cb = dict((n, b) for n, b, _ in candidates(_text(text)))[cname]
        import os
        data = open(src, 'rb').read()
        (make_zipcrypto if kind == 'zipcrypto' else make_aes256)(arc, os.path.basename(src), data, cb)
        print(cb.hex(' '))
    elif cmd == 'bytes':
        print(dict((n, b) for n, b, _ in candidates(_text(sys.argv[2])))[sys.argv[3]].hex(' '))
