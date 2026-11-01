#!/bin/sh
# Feature 365: the seed sessions of iso365_probe.ps1, made by genisoimage in WSL Ubuntu (fetched without
# root into ~/tc-genisoimage once, as features 328 / 334).
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# Writes: s1.iso (session 1: genisoimage -R, a.txt "A1", volume id TC365A),
#         s2.iso (session 2: genisoimage -R -C 0,<sectors of s1 + 11400>, b.txt "B2", volume id TC365B) -
#         addressed as a real second session is: after session 1's lead-out (6750), the lead-in of
#         session 2 (4500) and its first track's pregap (150) - 11400 sectors no image file holds
#         (CloneCD omits them, libmirage's and DiscImageCreator's reading),
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
rm -rf "$out/src365a" "$out/src365b"
mkdir -p "$out/src365a" "$out/src365b"
printf 'A1' > "$out/src365a/a.txt"
printf 'B2' > "$out/src365b/b.txt"
rm -f "$out/s1.iso" "$out/s2.iso" "$out/s2.lba"
$GI -quiet -R -V TC365A -o "$out/s1.iso" "$out/src365a"
n=$(( $(stat -c %s "$out/s1.iso") / 2048 + 11400 ))
$GI -quiet -R -V TC365B -C 0,$n -o "$out/s2.iso" "$out/src365b"
printf '%s' "$n" > "$out/s2.lba"
rm -rf "$out/src365a" "$out/src365b"
ls "$out"
