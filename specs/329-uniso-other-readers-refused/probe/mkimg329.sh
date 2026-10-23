#!/bin/sh
# Feature 329: the seed images of iso329_probe.ps1 made by image tools in WSL Ubuntu - 328's deep tree
# under the UDF and HFS+ file systems. genisoimage and xorriso are fetched without root (apt-get
# download + dpkg -x) once, into ~/tc-genisoimage and ~/tc-xorriso (as features 322 / 326 / 328).
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# The tree: a<59 x>/b<59 x>/c<59 x>/d<59 x>/e<59 x>/deep.txt (+ e<59 x>/f/g.txt, e<59 x>/f/h/hh.txt, review 1),
#           a<59 x>/side.txt, top.txt, zlast/z.txt.
# Writes: udeep.iso (genisoimage -udf: ISO 9660 level 1 + UDF; the UDF folder "UDF (TC329)" refuses
#         e<59 x> - its folder part is 256 bytes),
#         hdeep.iso (xorriso -hfsplus on, no Rock Ridge / Joliet: ISO 9660 + HFS+; the HFS+ folder
#         refuses an entry of the deep chain), each with the volume id TC329.
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
src="$out/srcdeep"
rm -rf "$src"
seg="$(printf 'x%.0s' $(seq 1 59))"
p="$src/a$seg/b$seg/c$seg/d$seg/e$seg"
mkdir -p "$p"
printf 'DEEP' > "$p/deep.txt"
# review 1: two levels below e - the contents of a left-out folder's subfolders are skipped too
mkdir -p "$p/f/h"
printf 'G' > "$p/f/g.txt"
printf 'H' > "$p/f/h/hh.txt"
printf 'SIDE' > "$src/a$seg/side.txt"
printf 'TOP' > "$src/top.txt"
mkdir -p "$src/zlast"
printf 'Z' > "$src/zlast/z.txt"
rm -f "$out/udeep.iso" "$out/hdeep.iso"
$GI -quiet -udf -V TC329 -o "$out/udeep.iso" "$src"
$XO -outdev "$out/hdeep.iso" -volid TC329 -rockridge off -joliet off -hfsplus on -map "$src" / >/dev/null 2>&1
ls "$out"
