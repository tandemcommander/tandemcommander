#!/bin/bash
# Feature 358 (review 1): more mkudffs images of sequential media (a VAT) into the folder $1 - run after
# specs/356-uniso-udf-rest/probe/mkudf356.sh, which fetches udftools into $HOME/tc-udftools.
#   mk_cdr150.img     cdr, UDF 1.50 (the old VAT: a file of type 0 ending with "*UDF Virtual Alloc Tbl")
#   mk_cdr150c.img    the same, closed
#   mk_cdrnoefe.img   cdr, UDF 2.01 with plain file entries (no extended file entries)
M="$HOME/tc-udftools/root/usr/sbin/mkudffs"
out="$1"
[ -n "$out" ] || exit 2
[ -x "$M" ] || { echo "no mkudffs at $M"; exit 1; }
mkdir -p "$out" || exit 1
mk() {
    name="$1"; shift
    rm -f -- "$out/$name"
    "$M" --new-file "$@" "$out/$name" 4000 >/dev/null 2>"$out/$name.err" || { echo "FAIL $name"; cat "$out/$name.err"; }
    rm -f -- "$out/$name.err"
}
mk mk_cdr150.img --media-type=cdr --udfrev=1.50
mk mk_cdr150c.img --media-type=cdr --udfrev=1.50 --closed
mk mk_cdrnoefe.img --media-type=cdr --noefe
