#!/bin/sh
# Feature 322: the seed images of iso322_probe.ps1, made by xorriso 1.5.6 in WSL Ubuntu.
# xorriso is fetched without root (apt-get download + dpkg -x) into ~/tc-xorriso once.
# $1 = the output folder (a /mnt/c/... path inside the probe's fixture)
# Writes: hyb.iso (ISO 9660 + Rock Ridge + Joliet + HFS+), rr.iso (ISO 9660 + Rock Ridge),
#         plain.iso (ISO 9660 only). Each holds folder/note.txt, top.txt.
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
rm -f "$out/hyb.iso" "$out/rr.iso" "$out/plain.iso"
$XO -outdev "$out/hyb.iso" -volid TC322 -hfsplus on -joliet on -map "$out/src" / >/dev/null 2>&1
$XO -outdev "$out/rr.iso" -volid TC322 -joliet off -map "$out/src" / >/dev/null 2>&1
$XO -outdev "$out/plain.iso" -volid TC322 -rockridge off -joliet off -map "$out/src" / >/dev/null 2>&1
ls "$out"
