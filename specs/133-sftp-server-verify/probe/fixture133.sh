#!/bin/bash
# Feature 133: prepares /home/tctest/tc133 in the test container (run as user tctest):
#   docker exec -i -u tctest tandem-sftp bash -s < fixture133.sh
# "state" as the first argument prints the facts the probe compares instead; "clean" removes all.
B=/home/tctest/tc133
e=$(printf 'e%.0s' $(seq 1 250))
f=$(printf 'f%.0s' $(seq 1 250))
d=$(printf 'd%.0s' $(seq 1 240))
deepdir() { p=$B/long; for i in $(seq 1 12); do p=$p/$d; done; echo "$p"; }
treeend() { p=$1; for i in $(seq 1 $2); do p=$p/$e; done; echo "$p"; }
count() { if [ -d "$1" ]; then ls -A "$1" | wc -l; else echo -1; fi; }

if [ "$1" = "state" ]; then
    echo "ro1_f=$( [ -f $B/ro1/f.txt ] && echo 1 || echo 0 )"
    echo "ro2_entries=$(count $B/ro2)"
    echo "r3_secret=$( [ -f $B/r3/secret.txt ] && echo 1 || echo 0 )"
    echo "ro4_entries=$(count $B/ro4)"
    echo "deep_entries=$(count "$(deepdir)")"
    echo "deep_longest=$(ls -A "$(deepdir)" | awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }')"
    echo "p4_deepfiles=$(count "$(treeend $B/p4/tree 16)")"
    for t in p5 p5m; do
        echo "${t}_deepfiles=$(count "$(treeend $B/$t/tree 15)")"
    done
    for t in l1 l2 l3 m1; do
        echo "${t}_many=$(count $B/$t/many)"
    done
    echo "m1_dir=$( [ -d $B/m1/many ] && echo 1 || echo 0 )"
    echo "m2_file=$( [ -f $B/m2/one.txt ] && echo 1 || echo 0 )"
    for t in q1 q2; do
        echo "${t}_entries=$(count $B/$t)"
        echo "${t}_one=$( [ -f $B/$t/one.txt ] && echo 1 || echo 0 )"
        echo "${t}_longest=$(ls -A $B/$t | awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }')"
        echo "${t}_validutf8=$(ls -A $B/$t | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 && echo 1 || echo 0)"
    done
    echo "mt_tree=$( [ -e $B/mt/tree ] && echo 1 || echo 0 )"
    echo "mk_secret=$( [ -f $B/mk/tree/sub/secret.txt ] && echo 1 || echo 0 )"
    echo "mk_left=$( [ -d $B/mk/tree ] && (cd $B/mk/tree && find . -mindepth 1 | sort | tr '\n' ' ') || echo gone )"
    echo "ms_left=$( [ -d $B/ms/tree ] && (cd $B/ms/tree && find . -mindepth 1 | sort | tr '\n' ' ') || echo gone )"
    echo "mc_left=$( [ -d $B/mc/tree ] && (cd $B/mc/tree && find . -mindepth 1 | sort | tr '\n' ' ') || echo gone )"
    echo "mb_left=$( [ -d $B/mb/proj ] && (cd $B/mb/proj && find . -mindepth 1 | sort | tr '\n' ' ') || echo gone )"
    echo "d1_tree=$( [ -e $B/d1/tree ] && echo 1 || echo 0 )"
    echo "d2_kept=$( [ -f $B/d2/tree/locked/keep.txt ] && echo 1 || echo 0 )"
    echo "d2_free=$( [ -e $B/d2/tree/free ] && echo 1 || echo 0 )"
    exit 0
fi

chmod -R u+rwx "$B" 2>/dev/null
rm -rf "$B"
[ "$1" = "clean" ] && exit 0
set -e
mkdir -p "$B" && cd "$B"
mkdir ro1 && echo data > ro1/f.txt && chmod 555 ro1
mkdir ro2 && chmod 555 ro2
mkdir r3 && echo secret > r3/secret.txt && chmod 000 r3/secret.txt
mkdir ro4 && chmod 555 ro4
# a directory about 2,900 bytes deep, reached through a short link
p=$(deepdir); mkdir -p "$p"; echo x > "$p/file.txt"; mkdir p1; ln -s "$p" p1/deep
# p4: a tree whose two files pass 4,095 bytes (16 levels of 250-byte names + a 250-byte name).
#     OpenSSH's sftp-server does not list a name whose full path passes its own PATH_MAX, so a
#     client never sees these two files - the row records what a delete of such a tree says.
# p5, p5m: 15 levels - the files (about 4,040 bytes) are listed; the LOCAL name they would get
#     under a long target folder passes 4,095 bytes.
for t in p4:16 p5:15 p5m:15; do
    n=${t#*:}; t=${t%%:*}
    mkdir -p "$B/$t/tree" && cd "$B/$t/tree"
    for i in $(seq 1 $n); do mkdir "$e" && cd "$e"; done
    echo 1 > "$f"; echo 2 > "${f}.txt"
    cd "$B"
done
# directories of 30 files
for t in l1 l2 l3 m1; do
    mkdir -p "$B/$t/many"
    for i in $(seq -w 1 30); do echo "file $i" > "$B/$t/many/f$i.txt"; done
done
mkdir m2 && echo one > m2/one.txt
# q1, q2: one file each for the Quick Rename rows of feature 137
mkdir q1 q2 && echo one > q1/one.txt && echo one > q2/one.txt
# feature 138 - move: mt a tree with sub-directories and an empty directory; mk a tree with one
# unreadable file; ms a tree with a file that already exists locally (the probe answers No)
mkdir -p mt/tree/a/b mt/tree/empty && echo 1 > mt/tree/a/b/x.txt && echo 22 > mt/tree/a/y.txt && echo 333 > mt/tree/z.txt
mkdir -p mk/tree/sub mk/tree/other && echo ok > mk/tree/sub/good.txt && echo secret > mk/tree/sub/secret.txt && chmod 000 mk/tree/sub/secret.txt && echo ok2 > mk/tree/other/fine.txt && echo top > mk/tree/top.txt
mkdir -p ms/tree && echo new-content > ms/tree/exists.txt && echo other > ms/tree/moved.txt
# mc: two names that are one file on Windows (case), different content; mb: a tree of empty
# directories whose local counterpart cannot be created (the probe puts a FILE named proj there)
mkdir -p mc/tree && echo first-content-AAAA > mc/tree/A.txt && echo second > mc/tree/a.txt && echo third > mc/tree/b.txt
mkdir -p mb/proj/a mb/proj/b/c
# d1: an ordinary tree (deleted whole); d2: a tree with one directory that cannot be emptied
mkdir -p d1/tree/a/b d1/tree/c && echo 1 > d1/tree/a/b/x.txt && echo 2 > d1/tree/c/y.txt && echo 3 > d1/tree/z.txt
mkdir -p d2/tree/free d2/tree/locked && echo 1 > d2/tree/free/x.txt && echo 2 > d2/tree/locked/keep.txt && chmod 555 d2/tree/locked
echo "prepared: $(pwd -P); p4 tree end is $(treeend $B/p4/tree 16 | wc -c) bytes, p5 file path $(( $(treeend $B/p5/tree 15 | wc -c) + 251 )) bytes"
