#!/bin/bash
# Feature 354 measurement: how many 2048-byte sectors past the ISO 9660 volume (the primary volume
# descriptor's volume space size) do common authoring tools leave in a cooked .iso?
# $1 = output folder (a /mnt/... path)
out="$1"
GI="$HOME/tc-genisoimage/root/usr/bin/genisoimage"
X="$HOME/tc-xorriso/root/usr/bin/xorriso"
export LD_LIBRARY_PATH="$HOME/tc-xorriso/root/usr/lib/x86_64-linux-gnu"
rm -rf "$out" && mkdir -p "$out/src" "$out/src2"
printf 'A1' > "$out/src/a.txt"
head -c 300000 /dev/urandom > "$out/src/big.bin"
printf 'B2' > "$out/src2/b.txt"
dd if=/dev/zero of="$out/esp.img" bs=1024 count=2880 status=none
mkdir -p "$out/src/boot" && dd if=/dev/zero of="$out/src/boot/boot.img" bs=1024 count=1440 status=none

pvd() { # file -> "file_sectors pvd_sectors tail"
    python3 - "$1" <<'EOF'
import sys, os
p = sys.argv[1]
f = open(p, "rb"); f.seek(16 * 2048); d = f.read(2048)
n = os.path.getsize(p) // 2048
if d[1:6] != b"CD001" or d[0] != 1:
    print("%-34s file %7d  no PVD at 16 (%r)" % (os.path.basename(p), n, d[:6])); sys.exit()
v = int.from_bytes(d[80:84], "little")
print("%-34s file %7d  pvd %7d  tail %6d" % (os.path.basename(p), n, v, n - v))
EOF
}

$GI -quiet -R -o "$out/geniso_default.iso" "$out/src" && pvd "$out/geniso_default.iso"
$GI -quiet -R -pad -o "$out/geniso_pad.iso" "$out/src" && pvd "$out/geniso_pad.iso"
$GI -quiet -R -J -udf -o "$out/geniso_udf.iso" "$out/src" && pvd "$out/geniso_udf.iso"
$GI -quiet -R -J -b boot/boot.img -o "$out/geniso_eltorito.iso" "$out/src" && pvd "$out/geniso_eltorito.iso"
$X -as mkisofs -quiet -R -o "$out/xorriso_default.iso" "$out/src" 2>/dev/null && pvd "$out/xorriso_default.iso"
$X -as mkisofs -quiet -R -no-pad -o "$out/xorriso_nopad.iso" "$out/src" 2>/dev/null && pvd "$out/xorriso_nopad.iso"
$X -as mkisofs -quiet -R -partition_offset 16 --protective-msdos-label -o "$out/xorriso_mbr.iso" "$out/src" 2>/dev/null && pvd "$out/xorriso_mbr.iso"
$X -as mkisofs -quiet -R -J -append_partition 2 0xef "$out/esp.img" -o "$out/xorriso_append_esp.iso" "$out/src" 2>/dev/null && pvd "$out/xorriso_append_esp.iso"
$X -as mkisofs -quiet -R -J -append_partition 2 0xef "$out/esp.img" -appended_part_as_gpt -o "$out/xorriso_append_gpt.iso" "$out/src" 2>/dev/null && pvd "$out/xorriso_append_gpt.iso"
$X -as mkisofs -quiet -R -J -b boot/boot.img -no-emul-boot -boot-load-size 4 -isohybrid-gpt-basdat -o "$out/xorriso_hybrid_gpt.iso" "$out/src" 2>/dev/null && pvd "$out/xorriso_hybrid_gpt.iso"
# xorriso multi-session on a regular file: two sessions
$X -dev "$out/xorriso_ms.iso" -map "$out/src/a.txt" /a.txt -commit -map "$out/src2/b.txt" /b.txt -commit >/dev/null 2>&1 && pvd "$out/xorriso_ms.iso"
# a cooked two-session image as 334 / 353 build it (session 2 addressed after session 1, joined)
$GI -quiet -R -o "$out/s1.iso" "$out/src2"
n=$(( $(stat -c %s "$out/s1.iso") / 2048 ))
$GI -quiet -R -C 0,$n -o "$out/s2.iso" "$out/src2"
cat "$out/s1.iso" "$out/s2.iso" > "$out/joined_2sess.iso" && pvd "$out/joined_2sess.iso"
