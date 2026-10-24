#!/bin/sh
# Feature 334: the seed sessions of iso334_probe.ps1, made by genisoimage in WSL Ubuntu (fetched without
# root into ~/tc-genisoimage once, as features 328 / 329 / 330).
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# Writes: s1.iso (session 1: genisoimage -R, a.txt "A1", volume id TC334A),
#         s2.iso (session 2: genisoimage -R -C 0,<sectors of s1>, addressed from the sector after
#         session 1 - b.txt "B2", volume id TC334B; no -M, so it holds only its own file),
#         s2.lba (the first sector of session 2, as text).
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
rm -rf "$out/src334a" "$out/src334b"
mkdir -p "$out/src334a" "$out/src334b"
printf 'A1' > "$out/src334a/a.txt"
printf 'B2' > "$out/src334b/b.txt"
rm -f "$out/s1.iso" "$out/s2.iso" "$out/s2.lba"
$GI -quiet -R -V TC334A -o "$out/s1.iso" "$out/src334a"
n=$(( $(stat -c %s "$out/s1.iso") / 2048 ))
$GI -quiet -R -V TC334B -C 0,$n -o "$out/s2.iso" "$out/src334b"
printf '%s' "$n" > "$out/s2.lba"
rm -rf "$out/src334a" "$out/src334b"
ls "$out"
