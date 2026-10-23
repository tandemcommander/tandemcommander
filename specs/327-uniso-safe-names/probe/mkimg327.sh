#!/bin/sh
# Feature 327: the xorriso seeds of iso327_probe.ps1 (xorriso 1.5.6 in WSL Ubuntu, fetched without
# root into ~/tc-xorriso once, as features 322 and 326).
# $1 = the output folder (a /mnt/c/... path inside the probe's fixture)
# Writes: plain.iso (ISO 9660 only: folder SET with placeholder names img327.py replaces),
#         hfs.iso (ISO 9660 + Rock Ridge + HFS+ hybrid: folder set with names Linux allows and
#         Windows must not take as they are - HFS+ keeps them, '12:30' as '12/30')
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
rm -rf "$out/srcplain" "$out/srchfs"
mkdir -p "$out/srcplain/set/ddddddd"
printf 'PESC' > "$out/srcplain/set/aaaaaaaa.txt"
printf 'PCOLON' > "$out/srcplain/set/bbbbbbbb.txt"
printf 'PDEV' > "$out/srcplain/set/cccccccc.txt"
printf 'PTDOT' > "$out/srcplain/set/eeeeeeee.txt"
printf 'PSLASH' > "$out/srcplain/set/ffffffff.txt"
printf 'INNER' > "$out/srcplain/set/ddddddd/inner.txt"
printf 'TOP' > "$out/srcplain/set/top.txt"
rm -f "$out/plain0.iso" "$out/hfs.iso"
$XO -outdev "$out/plain0.iso" -volid TC327 -rockridge off -joliet off -map "$out/srcplain" / >/dev/null 2>&1
mkdir -p "$out/srchfs/set/"'..\..\hd'
printf 'HESC' > "$out/srchfs/set/"'..\..\hesc.txt'
printf 'HCOLON' > "$out/srchfs/set/12:30h.txt"
printf 'HDEV' > "$out/srchfs/set/con.txt"
printf 'HTDOT' > "$out/srchfs/set/htrail."
printf 'INNER' > "$out/srchfs/set/"'..\..\hd'"/inner.txt"
printf 'TOP' > "$out/srchfs/set/top.txt"
$XO -outdev "$out/hfs.iso" -volid TC327 -joliet off -hfsplus on -map "$out/srchfs" / >/dev/null 2>&1
ls "$out"
