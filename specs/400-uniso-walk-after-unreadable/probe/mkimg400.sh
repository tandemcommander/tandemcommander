#!/bin/sh
# Feature 400: the seed images of iso400_probe.ps1 - 330's seeds (mkimg330.sh: rd.iso, ud.iso, udh.iso,
# nest.iso) and rd2.iso: genisoimage -R of a/side.txt (SIDE), b/b.txt (B), top.txt (TOP), zlast/z.txt (Z)
# - folders A and B come before zlast. $1 = the output folder (a /mnt/... path inside the fixture)
set -e
here=$(dirname "$0")
sh "$here/../../330-iso-unreadable-folder/probe/mkimg330.sh" "$1" >/dev/null
GI="$HOME/tc-genisoimage/root/usr/bin/genisoimage"
out="$1"
src="$out/src400"
rm -rf "$src"
mkdir -p "$src/a" "$src/b" "$src/zlast"
printf 'SIDE' > "$src/a/side.txt"
printf 'B' > "$src/b/b.txt"
printf 'TOP' > "$src/top.txt"
printf 'Z' > "$src/zlast/z.txt"
rm -f "$out/rd2.iso"
$GI -quiet -R -V TC400 -o "$out/rd2.iso" "$src"
rm -rf "$src"
ls "$out"
