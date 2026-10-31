#!/bin/sh
# Feature 362: the control seed of iso362_probe.ps1 - a UDF image with a REAL empty folder, made by genisoimage
# in WSL Ubuntu (fetched without root into ~/tc-genisoimage once, as mkimg330.sh does).
#   e/ (empty), f.txt (F), g/h.txt (H)
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# Writes: ue.iso (genisoimage -udf: ISO 9660 + UDF, volume id TC362)
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
src="$out/src362"
rm -rf "$src"
mkdir -p "$src/e" "$src/g"
printf 'F' > "$src/f.txt"
printf 'H' > "$src/g/h.txt"
rm -f "$out/ue.iso"
$GI -quiet -udf -V TC362 -o "$out/ue.iso" "$src"
rm -rf "$src"
ls "$out"
