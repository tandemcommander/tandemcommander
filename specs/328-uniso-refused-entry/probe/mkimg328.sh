#!/bin/sh
# Feature 328: the seed images of iso328_probe.ps1 - one deep tree written by genisoimage and by
# xorriso (WSL Ubuntu). Both tools are fetched without root (apt-get download + dpkg -x) once, into
# ~/tc-genisoimage and ~/tc-xorriso (as features 322 / 326).
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# The tree: a<59 x>/b<59 x>/c<59 x>/d<59 x>/e<59 x>/deep.txt (a folder part of 305 bytes - longer
# than the panel listing takes - with the Rock Ridge / Joliet names of 60 letters), a<59 x>/side.txt,
# top.txt, zlast/z.txt (after the deep folder in the directory order).
# Writes: gdeep.iso (genisoimage -R: ISO 9660 level 1 + Rock Ridge, 'RR' and 'SP' entries),
#         jdeep.iso (genisoimage -J: ISO 9660 + Joliet - the plug-in lists Joliet),
#         xdeep.iso (xorriso: ISO 9660 + Rock Ridge 1.12, no 'RR' entry), each with the volume id TC328.
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
printf 'SIDE' > "$src/a$seg/side.txt"
printf 'TOP' > "$src/top.txt"
mkdir -p "$src/zlast"
printf 'Z' > "$src/zlast/z.txt"
rm -f "$out/gdeep.iso" "$out/jdeep.iso" "$out/xdeep.iso"
$GI -quiet -R -V TC328 -o "$out/gdeep.iso" "$src"
$GI -quiet -J -V TC328 -o "$out/jdeep.iso" "$src"
$XO -outdev "$out/xdeep.iso" -volid TC328 -joliet off -map "$src" / >/dev/null 2>&1
# review 1: jloop.iso (genisoimage -J) of two one-letter folders a, b and top.txt - the probe points
# both folders back to the root (a cycle whose path grows two bytes a level)
rm -rf "$out/srcloop"
mkdir -p "$out/srcloop/a" "$out/srcloop/b"
printf 'A' > "$out/srcloop/a/fa.txt"
printf 'B' > "$out/srcloop/b/fb.txt"
printf 'T' > "$out/srcloop/top.txt"
rm -f "$out/jloop.iso"
$GI -quiet -J -V TC328 -o "$out/jloop.iso" "$out/srcloop"
ls "$out"
