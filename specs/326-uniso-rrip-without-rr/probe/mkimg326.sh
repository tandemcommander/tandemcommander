#!/bin/sh
# Feature 326: the seed images of iso326_probe.ps1, made by xorriso 1.5.6 in WSL Ubuntu (RRIP 1.12:
# the SUSP SP entry in the root's '.' record, no RR entry in any record).
# xorriso is fetched without root (apt-get download + dpkg -x) into ~/tc-xorriso once (as feature 322).
# $1 = the output folder (a /mnt/c/... path inside the probe's fixture)
# Writes: rr.iso (ISO 9660 + Rock Ridge: folder/note.txt, top.txt), oldrr.iso (the same with
#         -compliance old_rr: ER RRIP_1991A), plain.iso (-rockridge off), rrlong.iso (Rock Ridge, one
#         file of a 200-letter name - the name goes on in a continuation area), semi.iso (Rock Ridge, one
#         file named semi;colon.txt - a ';' inside a Rock Ridge name). No Joliet in any.
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
rm -f "$out/rr.iso" "$out/oldrr.iso" "$out/plain.iso" "$out/rrlong.iso" "$out/semi.iso"
$XO -outdev "$out/rr.iso" -volid TC326 -joliet off -map "$out/src" / >/dev/null 2>&1
$XO -compliance old_rr -outdev "$out/oldrr.iso" -volid TC326 -joliet off -map "$out/src" / >/dev/null 2>&1
$XO -outdev "$out/plain.iso" -volid TC326 -rockridge off -joliet off -map "$out/src" / >/dev/null 2>&1
mkdir -p "$out/srclong"
long="z$(printf 'r%.0s' $(seq 1 195)).txt"
printf 'LONG' > "$out/srclong/$long"
$XO -outdev "$out/rrlong.iso" -volid TC326 -joliet off -map "$out/srclong" / >/dev/null 2>&1
mkdir -p "$out/srcsemi"
printf 'SEMI' > "$out/srcsemi/semi;colon.txt"
$XO -outdev "$out/semi.iso" -volid TC326 -joliet off -map "$out/srcsemi" / >/dev/null 2>&1
# review 1: a deep tree - five folders of 60 letters (a folder path of 305 bytes, longer than the panel
# listing takes; the ISO 9660 names of 31 letters stay below it), deep.txt at the bottom
rm -rf "$out/srcdeep"
seg="$(printf 'x%.0s' $(seq 1 59))"
p="$out/srcdeep/a$seg/b$seg/c$seg/d$seg/e$seg"
mkdir -p "$p"
printf 'DEEP' > "$p/deep.txt"
printf 'TOP' > "$out/srcdeep/top.txt"
rm -f "$out/deep.iso"
$XO -outdev "$out/deep.iso" -volid TC326 -joliet off -map "$out/srcdeep" / >/dev/null 2>&1
# review 1 (MUST): Rock Ridge names Windows must not take as they are - one file each:
# esc.iso '..\escape.txt' (a backslash in a POSIX name), colon.iso '12:30.txt' (an NTFS stream),
# tdot.iso 'trail.' (Windows drops a trailing dot), dev.iso 'con.txt' (a device name)
for k in esc colon tdot dev; do
    rm -rf "$out/src$k"
    mkdir -p "$out/src$k"
done
printf 'ESC' > "$out/srcesc/"'..\escape.txt'
printf 'COLON' > "$out/srccolon/12:30.txt"
printf 'TDOT' > "$out/srctdot/trail."
printf 'DEV' > "$out/srcdev/con.txt"
for k in esc colon tdot dev; do
    rm -f "$out/$k.iso"
    $XO -outdev "$out/$k.iso" -volid TC326 -joliet off -map "$out/src$k" / >/dev/null 2>&1
done
ls "$out"
