---
title: FTP: two uploads under different connections can stall each other while listing
type: decision
status: new
severity: 4
area: ftp
source: review:345
who: person
created: 2026-10-30
updated: 2026-10-30
verified: -
effort: ?
feature: -
related: [ftp-opened-file-lock-two-names-of-one-server]
depends-on: []
reason: -
---

# FTP: two uploads under different connections can stall each other while listing

## Problem

Since feature 345, a change reported for one FTP connection (host, user, port) makes the running
uploads under **every other** connection stop trusting their cached folder listings - the client
cannot tell which accounts, ports and host names share folders, so it fails closed (no file is
replaced without the overwrite question). The cost: a listing that is still being downloaded when
such a change arrives is thrown away and downloaded again. Two uploads to two unrelated servers
(different users or ports), which never affected each other before 345, now can: while upload B
keeps storing files faster than upload A's listing of a large folder completes, A waits for its
listing for as long as B runs, downloading the whole listing again each time. A stall, not a hang
(the waiting upload makes no changes). Feature 341 already had the same effect for uploads with
the same user and port under two host names.

## Evidence

Review 1 of feature 345 (SHOULD, by reading; not measured on a probe),
`specs/345-ftp-upload-cache-user-port/fix-log.md` *Review*: at the branch head
`src/plugins/ftp/operats9.cpp` `CUploadListingsOnServer::InvalidateListing` sets an in-progress
listing to `ulsInProgressButMayBeOutdated`; `CUploadListingsOnServer::ListingFinished` then removes
it ("the listing will then be downloaded again") and the worker lists again, with no limit;
`CUploadListingCache::InvalidateOtherNamesOfServer` calls `InvalidateAllListings` on every entry
except the reporting connection's own.

## Expected

The maintainer decides whether the stall is acceptable or needs a mitigation that still never
lets an upload replace a file without the question.

## Notes

Related to `ftp-opened-file-lock-two-names-of-one-server` (the other open part of the identity
question of 341 / 345). Not measured: a probe would need a slow large listing next to a fast
storing upload (`specs/341-ftp-upload-cache-alias/probe/review3/ftpmini_slow.py` is a start).

## Question

Keep the fail-closed rule of 345 as it is, or bound its cost for uploads under different
connections?

## Options

- **A - keep as is.** Safe; two concurrent uploads to different connections can stall each other's
  listing of a large folder while the other one runs (seen only with many small files stored fast
  next to a large folder). No work.
- **B - an in-progress listing invalidated by another connection is kept, but marked "maybe
  outdated" per name**: the upload uses it for names the other connection did not report, and
  lists again only before deciding about a name some other connection changed since the listing
  started. Needs the change reports to carry names across connections (another account may see
  another folder under the same path - the name rule must stay conservative). A feature of its own
  (M), with probe rows for a large listing under load.
- **C - bound the restarts**: after N restarts the upload stops trusting any listing for that path
  and asks the overwrite question for every name that exists there per a plain `SIZE`/`MDTM`
  check, or asks the user. Changes the behaviour users see (more questions or more commands);
  needs care with servers without `SIZE`.
- **D - narrow 345 back** to "the same host name with another user or port" (the item's middle
  way): no stall between unrelated servers with different users, but a change made as user `u` at
  `127.0.0.1` again does not reach an upload as `v` at `localhost` (probe row ALL-REN loses data).

## Recommendation

A, until a stall is reported or measured; then B. D brings a measured data loss back; C trades
the stall for many more questions.

## Log

- 2026-10-30 — created (source review:345)
