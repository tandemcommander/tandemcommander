#!/bin/sh
# Feature 364: big364.iso for iso364_probe.ps1 - a valid ISO 9660 + UDF image (genisoimage -udf, fetched by
# specs/330-iso-unreadable-folder/probe/mkimg330.sh into ~/tc-genisoimage) whose root and sub-folder sub each hold
# 40 files a_rather_long_file_name_NN.txt (content R<NN> in the root, S<NN> in sub): each folder's data is about
# 2.9 KB, more than one sector, in one extent - img364.py splits it into several. After the first reviewer's
# mkbig.sh of feature 362.
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
set -e
GI="$HOME/tc-genisoimage/root/usr/bin/genisoimage"
out="$1"
src="$out/src364"
rm -rf "$src"
mkdir -p "$src/sub"
i=0
while [ $i -lt 40 ]; do
    n=$(printf '%02d' $i)
    printf "R$n" > "$src/a_rather_long_file_name_$n.txt"
    printf "S$n" > "$src/sub/a_rather_long_file_name_$n.txt"
    i=$((i + 1))
done
rm -f "$out/big364.iso"
$GI -quiet -udf -R -V TC364 -o "$out/big364.iso" "$src"
rm -rf "$src"
ls -l "$out/big364.iso"
