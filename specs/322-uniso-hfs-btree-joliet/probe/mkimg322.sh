#!/bin/sh
# Feature 322: the seed images of iso322_probe.ps1, made by xorriso 1.5.6 in WSL Ubuntu.
# xorriso is fetched without root (apt-get download + dpkg -x) into ~/tc-xorriso once.
# $1 = the output folder (a /mnt/c/... path inside the probe's fixture)
# Writes: hyb.iso (ISO 9660 + Rock Ridge + Joliet + HFS+), rr.iso (ISO 9660 + Rock Ridge),
#         plain.iso (ISO 9660 only). Each holds folder/note.txt, top.txt.
#         rrlong.iso (Rock Ridge, a 200-letter name); many.iso (hybrid of 1001 files in 40 folders -
#         an HFS+ catalog of many leaf nodes)
set -e
D="$HOME/tc-xorriso"
X="$D/root"
if [ ! -x "$X/usr/bin/xorriso" ]; then
    mkdir -p "$D"
    cd "$D"
    apt-get download xorriso libisoburn1t64 libisofs6t64 libburn4t64 >/dev/null 2>&1
    mkdir -p root
    for f in *.deb; do dpkg -x "$f" root; done
    cd - >/dev/null
fi
XO="env LD_LIBRARY_PATH=$X/usr/lib/x86_64-linux-gnu $X/usr/bin/xorriso"
out="$1"
mkdir -p "$out/src/folder"
printf 'NOTE' > "$out/src/folder/note.txt"
printf 'TOP' > "$out/src/top.txt"
rm -f "$out/hyb.iso" "$out/rr.iso" "$out/plain.iso" "$out/rrlong.iso"
$XO -outdev "$out/hyb.iso" -volid TC322 -hfsplus on -joliet on -map "$out/src" / >/dev/null 2>&1
$XO -outdev "$out/rr.iso" -volid TC322 -joliet off -map "$out/src" / >/dev/null 2>&1
$XO -outdev "$out/plain.iso" -volid TC322 -rockridge off -joliet off -map "$out/src" / >/dev/null 2>&1
# a Rock Ridge name of 200 letters (feature 223's RR-LONG case, without Docker): 'z' + 195 'r' + '.txt'
mkdir -p "$out/srclong"
long="z$(printf 'r%.0s' $(seq 1 195)).txt"
printf 'LONG' > "$out/srclong/$long"
$XO -outdev "$out/rrlong.iso" -volid TC322 -joliet off -map "$out/srclong" / >/dev/null 2>&1
# a catalog of many leaf nodes (review 1): 40 folders of 25 files, and zz.txt sorted after them
rm -rf "$out/srcmany"
mkdir -p "$out/srcmany"
for d in $(seq -w 0 39); do
    mkdir -p "$out/srcmany/d$d"
    for f in $(seq -w 0 24); do printf 'x' > "$out/srcmany/d$d/file_with_a_longer_name_$f.txt"; done
done
printf 'MANY' > "$out/srcmany/zz.txt"
rm -f "$out/many.iso"
$XO -outdev "$out/many.iso" -volid TC322 -hfsplus on -joliet on -map "$out/srcmany" / >/dev/null 2>&1
ls "$out"
