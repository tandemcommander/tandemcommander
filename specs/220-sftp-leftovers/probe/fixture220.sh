#!/bin/bash
# Feature 220: prepares /home/tctest/tc220 in the test container (run as user tctest):
#   docker exec -i -u tctest tandem-sftp bash -s < fixture220.sh
# "state" prints nothing of use (kept for the driver); "clean" removes all.
B=/home/tctest/tc220
if [ "$1" = "state" ]; then
    echo "v1_entries=$(ls -l $B/v1 2>/dev/null | tr '\n' ' ')"
    exit 0
fi
chmod -R u+rwx $B 2>/dev/null
rm -rf $B
if [ "$1" = "clean" ]; then
    exit 0
fi
mkdir -p $B/v1 $B/v2
printf 'SECRET' > $B/v1/secret.txt
chmod 000 $B/v1/secret.txt
printf 'OPEN' > $B/v2/open.txt
echo "prepared: $B"
