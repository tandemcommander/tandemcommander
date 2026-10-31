#!/bin/sh
# Feature 349: the seed image of iso349_probe.ps1, made by xorriso in WSL Ubuntu (fetched without root
# into ~/tc-xorriso once, as features 322 / 329 / 332).
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# The tree: a/a.txt (A), a/sub/s.txt (S), b/b.txt (B), c/c.txt (C), k/k.txt (K), k/kd/kd.txt (KD),
#           n1<60 x>/n2<60 x>/n3<60 x>/n4<60 x>/ (empty: its folder part, 11 + 4 x 63 = 263 bytes with
#           "HFS (TC349)", is over the listing's 255 - an entry inside it is left out), top.txt (TOP).
# Catalog IDs follow the names depth first (a 16 ... k, n1, n2, n3, n4 rising).
# Writes: hfs.iso (xorriso -hfsplus on, no Rock Ridge / Joliet: ISO 9660 + HFS+, volume id TC349; every
#         entry but top.txt hidden from the ISO 9660 part - the HFS+ part holds the tree, the ISO 9660 part
#         only top.txt). img349.py then moves folders inside its HFS+ catalog.
set -e
D="$HOME/tc-xorriso"
X="$D/root"
if [ ! -x "$X/usr/bin/xorriso" ]; then
    mkdir -p "$D"
    cd "$D"
    apt-get download xorriso libisoburn1t64 libisofs6t64 libburn4t64 >/dev/null 2>&1
    mkdir -p root
    for f in ./*.deb; do dpkg -x "$f" root; done
    cd - >/dev/null
fi
XO="env LD_LIBRARY_PATH=$X/usr/lib/x86_64-linux-gnu $X/usr/bin/xorriso"
out="$1"
src="$out/src349"
rm -rf "$src"
x="$(printf 'x%.0s' $(seq 1 60))"
n="n1$x/n2$x/n3$x/n4$x"
mkdir -p "$src/a/sub" "$src/b" "$src/c" "$src/k/kd" "$src/$n"
printf 'A' > "$src/a/a.txt"
printf 'S' > "$src/a/sub/s.txt"
printf 'B' > "$src/b/b.txt"
printf 'C' > "$src/c/c.txt"
printf 'K' > "$src/k/k.txt"
printf 'KD' > "$src/k/kd/kd.txt"
printf 'TOP' > "$src/top.txt"
rm -f "$out/hfs.iso"
$XO -outdev "$out/hfs.iso" -volid TC349 -rockridge off -joliet off -hfsplus on -map "$src" / -hide iso_rr /a /b /c /k "/n1$x" -- >/dev/null 2>&1
rm -rf "$src"
ls "$out"
