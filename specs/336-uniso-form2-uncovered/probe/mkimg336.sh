#!/bin/sh
# Feature 336: the seed of iso336_probe.ps1's covered-stream images, made by genisoimage in WSL Ubuntu
# (fetched without root into ~/tc-genisoimage once, as features 328 .. 335).
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# Writes: s1c.iso (genisoimage -R, volume id TC336: a.txt "A1" and avseq01.dat - 16384 bytes of "V",
#         whose directory records img336.py points at the stream track).
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
rm -rf "$out/src336"
mkdir -p "$out/src336"
printf 'A1' > "$out/src336/a.txt"
head -c 16384 /dev/zero | tr '\0' 'V' > "$out/src336/avseq01.dat"
rm -f "$out/s1c.iso"
$GI -quiet -R -V TC336 -o "$out/s1c.iso" "$out/src336"
rm -rf "$out/src336"
ls "$out"
