#!/bin/sh
# Feature 363 (review 1, SHOULD 1): big.iso for iso363_probe.ps1 - a valid ISO 9660 + UDF image (genisoimage -udf -R,
# fetched by specs/330-iso-unreadable-folder/probe/mkimg330.sh into ~/tc-genisoimage) whose root and sub-folder sub
# hold 140 files each, names 1 - 150 characters long: each folder is about 17.5 KB, so its identifiers cross sector
# boundaries and the walk steps sector by sector - the case where the new bound meets valid data.
#   root: r<i>_<x * k>.txt (content R<i>), sub: s<i>_<x * k>.txt (content S<i>), k = (i * 37) % 150 + 1
# $1 = the output folder (a /mnt/... path inside the probe's fixture). After the first reviewer's mkbig.sh.
set -e
GI="$HOME/tc-genisoimage/root/usr/bin/genisoimage"
out="$1"
src="$out/srcbig"
rm -rf "$src"
mkdir -p "$src/sub"
i=0
while [ $i -lt 140 ]; do
    k=$(( (i * 37) % 150 + 1 ))
    pad=$(printf '%*s' "$k" '' | tr ' ' 'x')
    printf "R$i" > "$src/r${i}_$pad.txt"
    printf "S$i" > "$src/sub/s${i}_$pad.txt"
    i=$((i + 1))
done
rm -f "$out/big.iso"
$GI -quiet -udf -R -V TCBIG -o "$out/big.iso" "$src"
rm -rf "$src"
ls -l "$out/big.iso"
