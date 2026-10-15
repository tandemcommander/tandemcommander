#!/bin/bash
# Feature 205: prepares /home/tctest/tc205 in the test container (run as user tctest):
#   docker exec -i -u tctest tandem-sftp bash -s < fixture205.sh
# "state" as the first argument prints the facts the probe compares instead; "clean" removes all.
# Remote names that are the SHORT (8.3) names of local entries the probe makes next to the target:
# LONGFI~1.TXT (of longfilename.txt) and LONGDI~1 (of the folder longdirname).
B=/home/tctest/tc205

if [ "$1" = "state" ]; then
    for t in f1 f2 d1 d2 m1 m2; do
        echo "${t}_entries=$( [ -d $B/$t ] && (cd $B/$t && find . -mindepth 1 | sort | tr '\n' ' ') || echo gone )"
    done
    exit 0
fi
rm -rf $B
if [ "$1" = "clean" ]; then
    exit 0
fi
mkdir -p $B/f1 $B/f2 $B/d1/LONGDI~1 $B/d2/LONGDI~1 $B/m1 $B/m2
printf 'SERVER-F1' > $B/f1/LONGFI~1.TXT
printf 'SERVER-F2' > $B/f2/LONGFI~1.TXT
printf 'SERVER-D1' > $B/d1/LONGDI~1/a.txt
printf 'SERVER-D2' > $B/d2/LONGDI~1/keep.txt
printf 'SERVER-M1' > $B/m1/LONGFI~1.TXT
printf 'SERVER-M2' > $B/m2/LONGFI~1.TXT
echo "prepared: $B"
