#!/bin/bash
# Feature 356: empty UDF file systems written by mkudffs (udftools) in WSL Ubuntu, into the folder $1.
# udftools is fetched once into $HOME/tc-udftools without installing it (as feature 354 fetched xorriso).
#   mk_hd.img        hd, 2048-byte blocks, 2000 blocks (anchors at 256 and the last sector)
#   mk_hd512.img     hd, 512-byte blocks (the anchor at block 256 is not at 2048-byte sector 256)
#   mk_dvd.img       dvd, 4000 blocks;  mk_dvdrw.img dvdrw;  mk_cdrw.img cdrw (sparable);  mk_cd.img cd
#   mk_dvdr.img, mk_bdr.img, mk_cdr.img   sequential media with a VAT, open (the partition descriptor
#                    claims the whole 4000 blocks, the file ends at the VAT)
#   mk_cdrclosed.img cdr with a VAT, closed (an anchor at the file's last sector - 256)
G="$HOME/tc-udftools"
M="$G/root/usr/sbin/mkudffs"
if [ ! -x "$M" ]; then
    mkdir -p "$G"
    (cd "$G" && apt-get download udftools >/dev/null 2>&1; for f in ./*.deb; do dpkg -x "$f" root; done)
fi
out="$1"
mkdir -p "$out"
mk() {
    name="$1"; blocks="$2"; shift 2
    rm -f "$out/$name"
    "$M" --new-file "$@" "$out/$name" "$blocks" >/dev/null 2>"$out/$name.err" || { echo "FAIL $name"; cat "$out/$name.err"; }
    rm -f "$out/$name.err"
}
mk mk_hd.img 2000 --media-type=hd --blocksize=2048
mk mk_hd512.img 8000 --media-type=hd --blocksize=512
mk mk_dvd.img 4000 --media-type=dvd
mk mk_dvdr.img 4000 --media-type=dvdr
mk mk_dvdrw.img 4000 --media-type=dvdrw
mk mk_bdr.img 4000 --media-type=bdr
mk mk_cdr.img 4000 --media-type=cdr
mk mk_cdrclosed.img 4000 --media-type=cdr --closed
mk mk_cdrw.img 4000 --media-type=cdrw
mk mk_cd.img 4000 --media-type=cd
