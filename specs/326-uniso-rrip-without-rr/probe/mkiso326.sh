#!/bin/sh
# Feature 326 (review 2): one Rock Ridge image (xorriso 1.5.6, no Joliet) of a folder, for
# twins326_probe.ps1. $1 = the source folder, $2 = the image (/mnt/c/... paths in the probe's fixture).
# xorriso is fetched without root into ~/tc-xorriso once (as mkimg326.sh / feature 322).
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
rm -f "$2"
env LD_LIBRARY_PATH=$X/usr/lib/x86_64-linux-gnu $X/usr/bin/xorriso -outdev "$2" -volid TC326 -joliet off -map "$1" / >/dev/null 2>&1
ls -la "$2"
