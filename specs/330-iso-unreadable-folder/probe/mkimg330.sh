#!/bin/sh
# Feature 330: the seed images of iso330_probe.ps1, made by genisoimage in WSL Ubuntu (fetched without
# root into ~/tc-genisoimage once, as features 328 / 329). Review 4 of 328's tree:
#   a/side.txt (SIDE), top.txt (TOP), zlast/z.txt (Z) - folder A comes before zlast in every directory.
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# Writes: rd.iso (genisoimage -R: ISO 9660 + Rock Ridge), ud.iso (genisoimage -udf: ISO 9660 + UDF),
#         udh.iso (as ud.iso, side.txt hidden from the ISO 9660 part - it is only in the UDF part,
#         after the first reviewer's mkhide.sh), each with the volume id TC330.
set -e
G="$HOME/tc-genisoimage"
if [ ! -x "$G/root/usr/bin/genisoimage" ]; then
    mkdir -p "$G"
    cd "$G"
    apt-get download genisoimage >/dev/null 2>&1
    for f in ./*.deb; do dpkg -x "$f" root; done
    cd - >/dev/null
fi
GI="$G/root/usr/bin/genisoimage"
out="$1"
src="$out/src330"
rm -rf "$src"
mkdir -p "$src/a" "$src/zlast"
printf 'SIDE' > "$src/a/side.txt"
printf 'TOP' > "$src/top.txt"
printf 'Z' > "$src/zlast/z.txt"
rm -f "$out/rd.iso" "$out/ud.iso" "$out/udh.iso"
$GI -quiet -R -V TC330 -o "$out/rd.iso" "$src"
$GI -quiet -udf -V TC330 -o "$out/ud.iso" "$src"
$GI -quiet -udf -V TC330 -hide side.txt -o "$out/udh.iso" "$src"
rm -rf "$src"
ls "$out"
