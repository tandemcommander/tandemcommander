#!/bin/bash
# Feature 354 measurement 2: xorriso native (-dev) images - single session and two sessions: where the
# primary volume descriptors lie and what the one at sector 16 says.
out="$1"
X="$HOME/tc-xorriso/root/usr/bin/xorriso"
export LD_LIBRARY_PATH="$HOME/tc-xorriso/root/usr/lib/x86_64-linux-gnu"
rm -f "$out/xorriso_dev1.iso"
$X -dev "$out/xorriso_dev1.iso" -map "$out/src/a.txt" /a.txt -commit >/dev/null 2>&1
for f in xorriso_dev1.iso xorriso_ms.iso joined_2sess.iso xorriso_append_esp.iso; do
python3 - "$out/$f" <<'EOF'
import sys, os
p = sys.argv[1]
b = open(p, "rb").read()
n = len(b) // 2048
pv = []
for s in range(n):
    d = b[s * 2048 : s * 2048 + 2048]
    if d[1:6] == b"CD001" and d[0] == 1:
        pv.append((s, int.from_bytes(d[80:84], "little")))
last = max(i for i in range(len(b)) if b[i]) // 2048 if any(b) else -1
print("%-24s file %5d sectors, last non-zero sector %5d, PVDs (sector, size): %s" % (os.path.basename(p), n, last, pv[:6]))
EOF
done
