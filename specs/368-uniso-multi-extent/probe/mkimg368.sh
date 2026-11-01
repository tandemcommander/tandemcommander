#!/bin/sh
# Feature 368: a real disc image with a file over 4 GiB, made by xorrisofs -iso-level 3 (it stores the file
# in several extents of 4 GiB - 2 KiB) in WSL Ubuntu (xorriso fetched without root into ~/tc-xorriso once,
# as feature 327; genisoimage cannot store such a file).
#   huge.bin   4 GiB + 3000 bytes, sparse, with markers: "HEAD368" at 0, "EDGE368A" just before the first
#              extent's end (4 GiB - 2 KiB), "EDGE368B" at it, "TAIL368" in the last bytes
#   small.txt  "SMALL"
# $1 = the output folder (a /mnt/... path inside the probe's fixture). Writes big.iso (ISO 9660 level 3 +
# Rock Ridge + Joliet, volume id TC368) and big.sha256 (the sha256 of huge.bin). The image is made in the
# Linux file system and copied out once (about 4.3 GB).
set -e
X="$HOME/tc-xorriso"
if [ ! -x "$X/root/usr/bin/xorriso" ]; then
    mkdir -p "$X"
    cd "$X"
    for p in xorriso libisoburn1t64 libisoburn1 libisofs6t64 libisofs6 libburn4t64 libburn4 libjte2; do
        apt-get download "$p" >/dev/null 2>&1 || true
    done
    for f in ./*.deb; do dpkg -x "$f" root; done
    cd - >/dev/null
fi
export LD_LIBRARY_PATH="$X/root/usr/lib/x86_64-linux-gnu"
XO="$X/root/usr/bin/xorriso"
out="$1"
w="$HOME/tc368"
rm -rf "$w"
mkdir -p "$w/src"
f="$w/src/huge.bin"
size=$((4294967296 + 3000))
truncate -s $size "$f"
printf 'HEAD368' | dd of="$f" bs=1 seek=0 conv=notrunc 2>/dev/null
printf 'EDGE368A' | dd of="$f" bs=1 seek=$((4294965248 - 8)) conv=notrunc 2>/dev/null
printf 'EDGE368B' | dd of="$f" bs=1 seek=4294965248 conv=notrunc 2>/dev/null
printf 'TAIL368' | dd of="$f" bs=1 seek=$((size - 7)) conv=notrunc 2>/dev/null
printf 'SMALL' > "$w/src/small.txt"
sha256sum "$f" | cut -d' ' -f1 > "$w/big.sha256"
"$XO" -as mkisofs -quiet -iso-level 3 -R -J -V TC368 -o "$w/big.iso" "$w/src" 2>&1
"$XO" -indev "$w/big.iso" -lsl / 2>&1 | tail -5
cp "$w/big.iso" "$out/big.iso"
cp "$w/big.sha256" "$out/big.sha256"
rm -rf "$w"
ls -la "$out"
