#!/bin/sh
# Feature 338: the seed image of iso338_probe.ps1, made by genisoimage in WSL Ubuntu (fetched without
# root into ~/tc-genisoimage once, as features 328 - 330).
#   a/side.txt (SIDE), top.txt (TOP), tou.txt (TOU), zlast/z.txt (Z)
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# Writes plain.iso: plain ISO 9660 (no Rock Ridge, no Joliet - the records' names are the names the
# plug-in lists, so img338.py can give two records one name), volume id TC338.
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
src="$out/src338"
rm -rf "$src"
mkdir -p "$src/a" "$src/zlast"
printf 'SIDE' > "$src/a/side.txt"
printf 'TOP' > "$src/top.txt"
printf 'TOU' > "$src/tou.txt"
printf 'Z' > "$src/zlast/z.txt"
rm -f "$out/plain.iso"
$GI -quiet -V TC338 -o "$out/plain.iso" "$src"
rm -rf "$src"
ls "$out"
