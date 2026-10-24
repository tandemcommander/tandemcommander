#!/bin/sh
# Feature 332: the seed images of iso332_probe.ps1, made by image tools in WSL Ubuntu (fetched without
# root into ~/tc-xorriso and ~/tc-genisoimage once, as features 322 / 329 / 330). Review 4 of 328's tree:
#   a/side.txt (SIDE), top.txt (TOP), zlast/z.txt (Z) - folder a comes before zlast in every directory.
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# Writes: hdh.iso (xorriso -hfsplus on, no Rock Ridge / Joliet: ISO 9660 + HFS+, a/side.txt hidden from
#         the ISO 9660 part - it is only in the HFS+ part), ud.iso (genisoimage -udf: ISO 9660 + UDF),
#         each with the volume id TC332.
set -e
G="$HOME/tc-genisoimage"
if [ ! -x "$G/root/usr/bin/genisoimage" ]; then
    mkdir -p "$G"
    cd "$G"
    apt-get download genisoimage >/dev/null 2>&1
    for f in ./*.deb; do dpkg -x "$f" root; done
    cd - >/dev/null
fi
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
GI="$G/root/usr/bin/genisoimage"
XO="env LD_LIBRARY_PATH=$X/usr/lib/x86_64-linux-gnu $X/usr/bin/xorriso"
out="$1"
src="$out/src332"
rm -rf "$src"
mkdir -p "$src/a" "$src/zlast"
printf 'SIDE' > "$src/a/side.txt"
printf 'TOP' > "$src/top.txt"
printf 'Z' > "$src/zlast/z.txt"
rm -f "$out/hdh.iso" "$out/ud.iso"
$XO -outdev "$out/hdh.iso" -volid TC332 -rockridge off -joliet off -hfsplus on -map "$src" / -hide iso_rr /a/side.txt >/dev/null 2>&1
$GI -quiet -udf -V TC332 -o "$out/ud.iso" "$src"
rm -rf "$src"
ls "$out"
