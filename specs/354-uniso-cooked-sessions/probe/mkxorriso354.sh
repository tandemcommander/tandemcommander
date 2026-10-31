#!/bin/sh
# Feature 354: images as xorriso writes them, in WSL Ubuntu (xorriso fetched without root into
# ~/tc-xorriso once, as feature 334 fetched genisoimage).
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# Writes: xdev1.iso  (xorriso native, one session: a.txt "A1"; zero padding outside the volume)
#         xms.iso    (xorriso native, two sessions on the same file: a.txt "A1", then b.txt "B2";
#                     the volume descriptor at sector 16 describes the newest session)
#         xesp.iso   (xorriso -as mkisofs with an appended partition of 2880 KiB - the partition lies
#                     past the ISO 9660 volume and is not listed)
set -e
G="$HOME/tc-xorriso"
if [ ! -x "$G/root/usr/bin/xorriso" ]; then
    mkdir -p "$G"
    cd "$G"
    for p in xorriso libisoburn1t64 libisofs6t64 libburn4t64 libjte2; do
        apt-get download "$p" >/dev/null 2>&1 || true
    done
    for f in ./*.deb; do dpkg -x "$f" root; done
    cd - >/dev/null
fi
X="$G/root/usr/bin/xorriso"
export LD_LIBRARY_PATH="$G/root/usr/lib/x86_64-linux-gnu"
out="$1"
rm -rf "$out/src354x"
mkdir -p "$out/src354x"
printf 'A1' > "$out/src354x/a.txt"
printf 'B2' > "$out/src354x/b.txt"
rm -f "$out/xdev1.iso" "$out/xms.iso" "$out/xesp.iso" "$out/esp354.img"
$X -dev "$out/xdev1.iso" -map "$out/src354x/a.txt" /a.txt -commit >/dev/null 2>&1
$X -dev "$out/xms.iso" -map "$out/src354x/a.txt" /a.txt -commit -map "$out/src354x/b.txt" /b.txt -commit >/dev/null 2>&1
# the appended partition: 2880 KiB of 0x5A (any data the ISO 9660 volume does not cover)
python3 -c "open('$out/esp354.img','wb').write(b'\x5a'*2880*1024)"
rm "$out/src354x/b.txt"
$X -as mkisofs -quiet -R -append_partition 2 0xef "$out/esp354.img" -o "$out/xesp.iso" "$out/src354x" >/dev/null 2>&1
rm -rf "$out/src354x" "$out/esp354.img"
ls "$out"
