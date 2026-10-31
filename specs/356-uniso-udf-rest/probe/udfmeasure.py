"""Measure where a cooked UDF image's volume ends (2048-byte sectors).

For each file: sector 16 identifier, the anchors at 256 / N-1 / N-257 (tag id 2, tag location, checksum),
the main / reserve VDS extents, partition descriptors (start, length), LVD integrity extent, and the
nonzero sectors past the computed end.
"""
import struct
import sys

S = 2048


def tag(sec):
    if len(sec) < 16:
        return None
    tid, ver, cks, _, serial, crc, crclen, loc = struct.unpack('<HHBBHHHI', sec[:16])
    calc = (sum(sec[0:4]) + sum(sec[5:16])) & 0xFF
    return dict(id=tid, ver=ver, ok=calc == cks, loc=loc)


def main(path):
    data = open(path, 'rb').read()
    n = len(data) // S

    def sec(i):
        return data[i * S:(i + 1) * S]

    print(f'== {path}: {len(data)} bytes, {n} whole sectors, partial {len(data) % S}')
    print('  sector16:', sec(16)[:6])
    ends = []
    for at in (256, n - 1, n - 257):
        if at < 0:
            continue
        t = tag(sec(at))
        if t and t['id'] == 2:
            mlen, mloc = struct.unpack('<II', sec(at)[16:24])
            rlen, rloc = struct.unpack('<II', sec(at)[24:32])
            print(f'  anchor@{at}: loc={t["loc"]} ok={t["ok"]} MVDS {mloc}+{mlen // S} RVDS {rloc}+{rlen // S}')
            if at == 256 and t['loc'] == 256 and t['ok']:
                ends += [257, mloc + (mlen + S - 1) // S, rloc + (rlen + S - 1) // S]
                for b in range(mloc, mloc + (mlen + S - 1) // S):
                    tt = tag(sec(b))
                    if not tt:
                        break
                    if tt['id'] == 5:
                        pstart, plen = struct.unpack('<II', sec(b)[188:196])
                        print(f'    PD@{b}: start {pstart} length {plen} end {pstart + plen}')
                        ends.append(pstart + plen)
                    elif tt['id'] == 6:
                        bs = struct.unpack('<I', sec(b)[212:216])[0]
                        ilen, iloc = struct.unpack('<II', sec(b)[432:440])
                        print(f'    LVD@{b}: blocksize {bs} LVIS {iloc}+{ilen // S}')
                    elif tt['id'] == 8:
                        break
        elif t:
            print(f'  sector {at}: tag id {t["id"]} loc {t["loc"]}')
    if ends:
        end = max(ends)
        nz = [i for i in range(end, n) if any(sec(i))]
        print(f'  end(256-based)={end}; file sectors={n}; past={n - end}; nonzero past: {len(nz)} {nz[:8]}')


for p in sys.argv[1:]:
    main(p)
