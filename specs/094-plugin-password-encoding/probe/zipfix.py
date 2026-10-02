# Feature 094 probe: fixture archives keyed with an exact byte FORM of a typed
# password, and the question "which form opens each item of this archive".
#
# The forms are those of src/common/salzippwd.h, derived here with the same
# Win32 calls (so they are the forms of THIS machine):
#   acp      WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS), only when no
#            default character was used
#   oem      CharToOemA(acp)
#   utf8     UTF-8
#   oldread  WideCharToMultiByte(CP_ACP, 0) cut to 254 bytes - GetDlgItemTextA
#            of the versions up to 0.1.8
#
#   zipfix.py forms <password code points>
#   zipfix.py which <archive> <password code points>
#        one line per item:  <item>|<kind>|<forms that open it, in candidate order>
#   zipfix.py make <archive> <plain dir> <item> [<item> ...]
#        item = name,kind,form,password[,opt...]
#          kind      zipcrypto | aes256
#          form      acp | oem | utf8 | oldread
#          password  hex code points joined with '.'  (68.65.73.6C.6F.2D.159)
#          opt       deflate         store the item deflated (default: stored)
#                    fp=FORM[+FORM]  zipcrypto only: choose the 11 random header
#                                    bytes so that those OTHER forms of the same
#                                    password pass the one-byte check by chance
#                    fpw=PASSWORD    the same for the code-page form of ANOTHER
#                                    password (a wrong password that passes)
#                    fpw2=PASSWORD   the same for the code-page AND the UTF-8 form
#                                    of another password (two forms pass)
#        the plain content of every item is written to <plain dir>\<name>
#
# Pure ASCII; needs Windows, Python 3.8+, "cryptography" for aes256 items.

import ctypes
import hashlib
import hmac
import os
import struct
import sys
import zlib

import zipkey

WC_NO_BEST_FIT_CHARS = 0x400
_k32 = ctypes.windll.kernel32


def text_of(arg, sep):
    return ''.join(chr(int(x, 16)) for x in arg.split(sep)) if arg else ''


def forms(text):
    """Ordered [(name, bytes)] - only the forms that exist; duplicates kept."""
    out = []
    w = ctypes.create_unicode_buffer(text)
    n = len(text.encode('utf-16-le')) // 2
    used = ctypes.c_int(0)
    buf = ctypes.create_string_buffer(4 * n + 8)
    got = _k32.WideCharToMultiByte(0, WC_NO_BEST_FIT_CHARS, w, n, buf, len(buf), None, ctypes.byref(used)) if n else 0
    if n == 0 or (got > 0 and not used.value):
        acp = buf.raw[:got]
        out.append(('acp', acp))
        out.append(('oem', zipkey.char_to_oem(acp)))
    out.append(('utf8', text.encode('utf-8', 'surrogatepass')))
    got = _k32.WideCharToMultiByte(0, 0, w, n, buf, len(buf), None, None) if n else 0
    out.append(('oldread', buf.raw[:got][:254]))
    return out


def distinct(fs):
    seen, out = set(), []
    for name, b in fs:
        if b not in seen:
            seen.add(b)
            out.append((name, b))
    return out


def content(name):
    return ((name + ' - feature 094 zip password probe\r\n') * 60).encode('ascii')


def zipcrypto_payload(data, key, crc, want_pass):
    """12-byte header + data, encrypted with 'key'. want_pass: byte strings
    that must pass the check byte although they are not the key."""
    check = crc >> 24
    seed = 0
    while True:
        rnd = hashlib.sha256(b'094' + struct.pack('<I', seed)).digest()[:11]
        z = zipkey.ZipCrypto(key)
        head = z.encrypt(rnd + bytes([check]))
        ok = True
        for other in want_pass:
            if zipkey.ZipCrypto(other).decrypt(head)[11] != check:
                ok = False
                break
        if ok:
            return head + z.encrypt(data), seed
        seed += 1
        if seed > 40000000:
            raise RuntimeError('no header found')


def aes256_payload(data, key):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    salt = hashlib.sha256(b'094salt' + key).digest()[:16]
    dk = hashlib.pbkdf2_hmac('sha1', key, salt, 1000, 66)
    enc = Cipher(algorithms.AES(dk[:32]), modes.ECB()).encryptor()
    body = bytearray()
    for i in range(0, len(data), 16):                   # CTR, little-endian counter from 1
        ks = enc.update(struct.pack('<QQ', i // 16 + 1, 0))
        body += bytes(a ^ b for a, b in zip(data[i:i + 16], ks))
    mac = hmac.new(dk[32:64], bytes(body), hashlib.sha1).digest()[:10]
    return salt + dk[64:] + bytes(body) + mac


def make(arc, plain_dir, specs):
    local, central, notes = b'', b'', []
    dosdt = (0x6000, 0x5B41)
    for spec in specs:
        parts = spec.split(',')
        name, kind, form, pw = parts[0], parts[1], parts[2], text_of(parts[3], '.')
        opts = parts[4:]
        fs = dict(forms(pw))
        key = fs[form]
        plain = content(name)
        with open(os.path.join(plain_dir, name), 'wb') as f:
            f.write(plain)
        crc = zlib.crc32(plain) & 0xFFFFFFFF
        body, method = plain, 0
        if 'deflate' in opts:
            c = zlib.compressobj(6, zlib.DEFLATED, -15)
            body, method = c.compress(plain) + c.flush(), 8
        extra = b''
        if kind == 'zipcrypto':
            want = []
            for o in opts:
                if o.startswith('fp='):
                    want += [fs[x] for x in o[3:].split('+')]
                if o.startswith('fpw='):
                    want.append(dict(forms(text_of(o[4:], '.')))['acp'])
                if o.startswith('fpw2='):
                    other = dict(forms(text_of(o[5:], '.')))
                    want += [other['acp'], other['utf8']]
            for b in want:
                if b == key:
                    raise ValueError('fp form equals the key form')
            payload, seed = zipcrypto_payload(body, key, crc, want)
            hmethod, hcrc, ver = method, crc, 20
            if want:
                notes.append('%s: header seed %d' % (name, seed))
        else:
            payload = aes256_payload(body, key)
            extra = struct.pack('<HHH2sBH', 0x9901, 7, 2, b'AE', 3, method)
            hmethod, hcrc, ver = 99, 0, 51
        nb = name.encode('ascii')
        offset = len(local)
        local += struct.pack('<IHHHHHIIIHH', 0x04034B50, ver, 1, hmethod, dosdt[0], dosdt[1],
                             hcrc, len(payload), len(plain), len(nb), len(extra)) + nb + extra + payload
        central += struct.pack('<IHHHHHHIIIHHHHHII', 0x02014B50, 63, ver, 1, hmethod, dosdt[0], dosdt[1],
                               hcrc, len(payload), len(plain), len(nb), len(extra), 0, 0, 0, 0x20, offset) + nb + extra
        notes.append('%s: %s keyed with %s = %s' % (name, kind, form, key.hex(' ') if len(key) <= 24 else '%d bytes' % len(key)))
    end = struct.pack('<IHHHHIIH', 0x06054B50, 0, 0, len(specs), len(specs), len(central), len(local), 0)
    with open(arc, 'wb') as f:
        f.write(local + central + end)
    return notes


def which(arc, pw):
    out = []
    fs = distinct(forms(pw))
    with open(arc, 'rb') as f:
        for name, kind, zi in zipkey.describe(arc):
            if kind == 'not encrypted':
                out.append('%s|%s|-' % (name, kind))
                continue
            hits = []
            for fname, fb in fs:
                r = zipkey.test_item(f, zi, fb)
                if r:
                    hits.append(fname + ('' if r == 'OPENS' else '(' + r + ')'))
            out.append('%s|%s|%s' % (name, kind, ', '.join(hits) if hits else 'NO FORM'))
    return out


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'forms':
        for name, b in forms(text_of(sys.argv[2], ',')):
            print('%-8s %s' % (name, b.hex(' ')))
    elif cmd == 'which':
        for line in which(sys.argv[2], text_of(sys.argv[3], ',')):
            print(line)
    elif cmd == 'make':
        for line in make(sys.argv[2], sys.argv[3], sys.argv[4:]):
            print(line)
