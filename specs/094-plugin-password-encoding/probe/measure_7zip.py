# Feature 094 research probe: what the 7-Zip program (and Windows' tar.exe)
# use as the password bytes of a ZIP archive, measured.
#   part 1: 7z.exe creates ZipCrypto and AES-256 archives; which candidate
#           byte string opens them (zipkey.py)
#   part 2: archives written here with each candidate byte string; does
#           "7z t -p<typed text>" / "tar -tf --passphrase <typed text>" accept them
# usage: python measure_7zip.py <scratch directory> [7z.exe]
import os, subprocess, sys
import zipkey

scratch = sys.argv[1]
seven = sys.argv[2] if len(sys.argv) > 2 else r'C:\Program Files\7-Zip\7z.exe'
tar = os.path.join(os.environ['SystemRoot'], 'System32', 'tar.exe')
os.makedirs(scratch, exist_ok=True)
src = os.path.join(scratch, 'plain.txt')
data = b'feature 094 zip password probe\r\n' * 40
open(src, 'wb').write(data)

PW = [
    ('ascii', 'heslo123'),
    ('in-cp', 'heslo-' + chr(0x159)),
    ('cyrillic', ''.join(chr(c) for c in (0x43F, 0x430, 0x440, 0x43E, 0x43B, 0x44C))),
]

def run(args):
    r = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
    return r.returncode

print(subprocess.run([seven], stdout=subprocess.PIPE).stdout.decode('ascii', 'replace').splitlines()[1])
print('ACP %d, OEMCP %d' % (zipkey._k32.GetACP(), zipkey._k32.GetOEMCP()))
for tag, text in PW:
    print('password %-8s %s' % (tag, zipkey.esc(text)))
    for cname, cb, note in zipkey.candidates(text):
        print('    %-18s %s %s' % (cname, cb.hex(' '), note))

print()
print('PART 1 - archives made by 7z.exe: 7z a -tzip -mem=<method> -p<typed>')
for mem in ('ZipCrypto', 'AES256'):
    for cu in ('', '-mcu=on'):
        for tag, text in PW:
            arc = os.path.join(scratch, 'p1_%s_%s%s.zip' % (mem, tag, '_mcu' if cu else ''))
            if os.path.exists(arc):
                os.remove(arc)
            args = [seven, 'a', '-tzip', '-mem=' + mem, '-p' + text, '-bso0', '-bsp0']
            if cu:
                args.append(cu)
            rc = run(args + [arc, src])
            if rc != 0 or not os.path.exists(arc):
                print('  %-9s %-8s %-8s rc=%d 7z.exe REFUSES TO CREATE THE ARCHIVE ("System ERROR: the parameter is incorrect")' % (mem, cu, tag, rc))
                continue
            hits = zipkey.which(arc, text)
            for item, (kind, h) in hits.items():
                print('  %-9s %-8s %-8s rc=%d [%s] opens with: %s' % (mem, cu, tag, rc, kind, ', '.join(h) if h else 'NO CANDIDATE'))

print()
print('PART 2 - archives written with an exact byte string; opened with the typed text')
print('  %-9s %-8s %-18s %-8s %-8s' % ('method', 'password', 'bytes used', '7z t', 'tar -xO'))
for mem, maker in (('ZipCrypto', zipkey.make_zipcrypto), ('AES256', zipkey.make_aes256)):
    for tag, text in PW:
        seen = {}
        for cname, cb, note in zipkey.candidates(text):
            if cb in seen:
                print('  %-9s %-8s %-18s (same bytes as %s)' % (mem, tag, cname, seen[cb]))
                continue
            seen[cb] = cname
            arc = os.path.join(scratch, 'p2.zip')
            maker(arc, 'plain.txt', data, cb)
            assert zipkey.test_item(open(arc, 'rb'), zipkey.describe(arc)[0][2], cb) == 'OPENS'
            rc7 = run([seven, 't', '-bso0', '-bsp0', '-bse0', '-p' + text, arc])
            r = subprocess.run([tar, '-xOf', arc, '--passphrase', text], stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
            tarok = (r.returncode == 0 and r.stdout == data)
            print('  %-9s %-8s %-18s %-8s %-8s %s' % (mem, tag, cname, 'opens' if rc7 == 0 else 'refused', 'opens' if tarok else 'refused', note))
            os.remove(arc)
