#!/bin/bash
# Feature 279: prepares /home/tctest/tc279 in the test container (run as ROOT):
#   docker exec -i -u root tandem-sftp bash -s < fixture279.sh
# /home/tctest/tc279/pub    a plain folder of tctest (the start folder of the rows)
# /home/tctest/tc279/lockd  root:root 0700 - tctest cannot enter it
# /home/tctest/tc279/x, x2  symbolic links to lockd/inner, lockd/inner2 (review 2 of 258: the
#                           creation of x answers FAILURE, the followed stat PERMISSION_DENIED)
# "state" as the first argument prints the facts the probe compares; "clean" removes all.
B=/home/tctest/tc279
count() { if [ -d "$1" ]; then ls -A "$1" | wc -l; else echo -1; fi; }

if [ "$1" = "state" ]; then
    echo "x_link=$( [ -L $B/x ] && echo 1 || echo 0 )"
    echo "x2_link=$( [ -L $B/x2 ] && echo 1 || echo 0 )"
    echo "inner_entries=$(count $B/lockd/inner)"
    echo "inner2_entries=$(count $B/lockd/inner2)"
    echo "ctl_dir=$( [ -d $B/pub/ctl ] && echo 1 || echo 0 )"
    echo "ctl_entries=$(count $B/pub/ctl)"
    exit 0
fi
rm -rf "$B"
if [ "$1" = "clean" ]; then
    exit 0
fi
mkdir -p $B/pub $B/lockd/inner $B/lockd/inner2
chown tctest:tctest $B $B/pub
chown -R root:root $B/lockd
chmod 0700 $B/lockd
ln -s $B/lockd/inner $B/x
ln -s $B/lockd/inner2 $B/x2
echo ready
