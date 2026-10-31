"""Backlog item iso-plug-in-a-udf-image-with-a-vat-and-data-past-it-crashes: UDF images of a sequential
medium (a virtual allocation table, VAT) written by mkudffs (mkudf356.sh), with more in the file than the
volume - the images of review 2 of feature 356 (compose2.py, %TEMP%\rev356b).

    python -I vatimg.py <kind> <mk_cdr.img> <out>

kinds (S = 2048-byte sectors; mkudffs --media-type=cdr 4000 writes a 300-sector volume ending with its VAT,
its partition descriptor claims the whole 4000 sectors):
    data100    the volume + 100 sectors of 0x5A (the VAT is not in the file's last sectors)
    toclaim    the volume + 0x5A up to the claimed 4000 sectors (the VAT sector the reader asks for is read
               from the 0x5A data, the read past it fails: "Error reading virtual allocation table")
    claim16    the volume + 0x5A up to 4016 sectors (every sector the reader looks at is 0x5A)
    claim100z  the volume + 0x5A up to 4000 sectors + 100 zero sectors
"""
import sys

S = 2048


def main():
    kind, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    cdr = open(src, 'rb').read()
    if len(cdr) % S:
        raise SystemExit('not whole sectors: %d' % len(cdr))
    n = len(cdr) // S
    if kind == 'data100':
        img = cdr + b'\x5a' * (100 * S)
    elif kind == 'toclaim':
        img = cdr + b'\x5a' * ((4000 - n) * S)
    elif kind == 'claim16':
        img = cdr + b'\x5a' * ((4016 - n) * S)
    elif kind == 'claim100z':
        img = cdr + b'\x5a' * ((4000 - n) * S) + bytes(100 * S)
    else:
        raise SystemExit('unknown kind ' + kind)
    open(out, 'wb').write(img)
    print(kind, len(img) // S, 'sectors')


if __name__ == '__main__':
    main()
