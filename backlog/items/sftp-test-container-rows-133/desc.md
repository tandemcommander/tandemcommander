---
title: SFTP test container: read-only upload, stale reason, long Quick Rename
type: person-step
status: open
severity: 4
area: sftp
source: leftover:133
who: person
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [zip-sftp-passwords-real-keyboard-086-094, sftp-leaks-and-waits-after-broken-connection]
depends-on: []
reason: -
---

# SFTP test container: read-only upload, stale reason, long Quick Rename

## Problem

Three SFTP rows of feature 133 cannot be driven on the hidden desktop and are owed to a person: an upload into a read-only directory, the stale-reason row (a second failure must show its own reason, not the previous one's), and Quick Rename to a 250-letter name. Two rows of feature 140 need the same test server: Ctrl+R on a connection that died while idle, and a refused Change Attributes on a file of another owner.

## Evidence

Migrated from specs/NEXT-WORK.md header, 'Before 0.1.10 - steps owed to a person' point 2 (at 7993914c). Steps: specs/133-sftp-server-verify/quickstart.md 'Owed to a person (not drivable on the hidden desktop)'. Server: the Docker container tandem-sftp, sftp://tctest@localhost:2222/home/tctest (password in the session notes); fixture: docker exec -i -u tctest tandem-sftp bash -s < specs/133-sftp-server-verify/probe/fixture133.sh; clean with '... bash -s clean < fixture133.sh'.

## Expected

Each row behaves as the quickstart says; result recorded in specs/133-sftp-server-verify/fix-log.md.

## Notes

Second of the four person steps owed before 0.1.10 (`backlog/RELEASE.md`, *Current release*). The two rows of feature 140 (`specs/140-sftp-dead-session/`; NEXT-WORK §D L650-653, L665-666) need the same container and are done in the same session. The 0.1.10 closing pass also saw 133's probe at 74 / 2, both in RENCASE - the intermittent 'SSH handshake failed: Unable to exchange encryption keys' with leak boxes at exit; its root cause was fixed by feature 217 after the 0.1.10 state (whether 217 joins 0.1.10: `post-142-fixes-joining-0-1-10-decision`); what is left of the failed path is `sftp-leaks-and-waits-after-broken-connection`. 131's SFTP rows R1-R5, P1-P5 (specs/131-plugin-defect-batch/items/sftp.md) were also not driven against a server in 131; 133 was the feature that verified SFTP against the server.

## Steps

- [ ] Prepare the fixture in the tandem-sftp container (fixture133.sh) and connect to sftp://tctest@localhost:2222/home/tctest
- [ ] 133: upload into a read-only directory: local panel on a file, other panel in tc133/ro4, F5 - the message ends with 'Permission denied.'
- [ ] 133: stale reason: in tc133/ro1 F2 on f.txt to g.txt (fails); go up and F8 on p4 - the second message has its own reason, not the rename's
- [ ] 133: Quick Rename to a long name: in tc133/p1/deep F2 on file.txt, a new name of 250 letters - renamed to all 250 letters (docker exec ... ls shows it)
- [ ] 140: Ctrl+R on a connection that died while idle - the panel stays on the server after the reconnect
- [ ] 140: a refused Change Attributes on a file of another owner - the refusal names the reason
- [ ] Remove the fixture (fixture133.sh clean)

## Log

- 2026-10-14 — 0.1.10 closing pass: 133 probe 74 / 2, both in RENCASE (intermittent SSH handshake failure); the row alone again: PASS
- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — moved to Person steps position 2
- 2026-10-17 — migration review M1/N1/N3: second of the four steps owed before 0.1.10; duplicate 133 steps removed, 140 rows named in Problem; migration remarks replaced (217, sftp-leaks-and-waits-after-broken-connection)
