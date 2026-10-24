# Research - feature 341

## R0. Revised after review 1 (M1) - supersedes R1, R3 (its "different" half), R4, R5, R6

- **Decision**: one server cannot be recognised under two names from the client; every other host
  name with the same user and port is maybe the same server and its listings are invalidated on
  each change report (R2's reaction). No address table, no recording in the lookup thread, no new
  lock, no pure header.
- **Rationale**: the review (M1) showed that known, disjoint addresses do not prove two servers -
  one server answers on 127.0.0.1 and 127.0.0.2 (any address of a machine), on its LAN and public
  address (NAT), on several interfaces; it reproduced the data loss on the first design (probe row
  MULTI-REN, one folder served on both loopback addresses: `STOR b.txt` without the question). The
  item's *Expected* asks that an upload not trust its listings when identity cannot be told, and a
  safety check fails closed (CLAUDE.md, 098).
- **Cost**: concurrent uploads under two names with the same user and port - also of two different
  servers - list again after each change through the other (R3's cost, now for every pair).
- **Alternatives**: keep the table to save listings for "proven different" pairs - nothing proves
  it; another signal (welcome text, SYST reply) - not proof either. Rejected.

## R1. (superseded by R0) How to recognise one server under two names without new network traffic

- **Decision**: remember the addresses of the lookups the plug-in already performs. Every
  connection (panel `CControlConnectionSocket` state `sccsGetIP`, operation workers
  `CFTPWorker` `fwssConGetIP`) calls `CSocket::GetHostByAddress(host)`: a typed IPv4 string is
  converted by `inet_addr` without any lookup; a name is resolved by `gethostbyname` in
  `CGetHostByNameThread::Body`. That thread records the received address list for the name.
  For a typed IPv4 address the rule side calls `inet_addr` again (pure conversion).
- **Rationale**: no new lookup, no new network request, nothing stored beyond the process -
  outside the maintainer-owned *Network* / *Stored data* areas; the item's Notes asked to check
  this before resolving names.
- **Alternatives**: resolving the host in the cache (`gethostbyname` per report) - a new lookup,
  network behaviour change (maintainer-owned), and blocking under a critical section; carrying the
  connection's `ServerIP` through ~40 report call sites - invasive, and through a proxy it is the
  proxy's address, which would wrongly prove two servers behind one proxy "the same".

## R2. What to do with a maybe-same entry

- **Decision**: invalidate every cached listing of it (`CUploadListingsOnServer::InvalidateAllListings`,
  feature 302/323's reaction to a rename or a typed command).
- **Rationale**: always safe - the upload lists the folder again; applying the precise report to
  a server not proven the same could hide a needed question (a delete report removes a name the
  other server still has). An equal address does not prove one file system (proxy, NAT).
- **Alternatives**: merge both names into one entry (changes the cache's keying for every caller;
  listings in progress and waiting workers would need migrating) - rejected.

## R3. Unknown addresses (R0: now every other name, known addresses or not)

- **Decision**: a name with no recorded addresses (connection through a proxy - the plug-in looks
  up the proxy's name, not the server's; a name longer than the table slot; a table overflow
  evicted it) is "maybe the same" as any other name with the same user and port.
- **Rationale**: the item's *Expected*: "when the identity of the server cannot be told, the upload
  does not trust its cached listings".
- **Cost**: through a proxy, concurrent uploads to two different servers with the same user and
  port make each other list again after each change. Correct, slower; recorded as a limit.

## R4. (superseded by R0) Table bounds and eviction

- **Decision**: 64 host slots, 8 addresses each (the first 8 of `h_addr_list`), host text up to
  255 bytes (DNS names are at most 253; `HOST_MAX_SIZE` is 201). A longer host is not recorded.
  A re-lookup of a name replaces its addresses (latest wins); a full table replaces the slot
  recorded longest ago (round robin).
- **Rationale**: a session connects to few servers; an evicted name only becomes "unknown"
  (maybe the same) - never "different".

## R5. (superseded by R0) Host name comparison in the table

- **Decision**: ASCII case-insensitive, other bytes exact (DNS rule).
- **Note**: the existing exact match (`FindServer`, `SalamanderGeneral->StrICmp`) is unchanged.

## R6. (superseded by R0) Locking

- **Decision**: one `SRWLOCK` around the table in `ftputils.cpp` (as feature 288's
  `FTPServerEncLock`); it is a leaf - taken inside `UploadLstCacheCritSect` by the reports and
  alone by the lookup thread; nothing is called while holding it.

## R7. Which reports fan out

- **Decision**: the six reports of changes (`ReportCreateDirs`, `ReportRename`, `ReportDelete`,
  `ReportStoreFile`, `ReportFileUploaded`, `ReportUnknownChange`). Not: `AddOrUpdateListing`,
  `ListingFinished`, `ListingFailed`, `InvalidatePathListing`, `IsListingFromPanel`, `GetListing`,
  `RemoveServer`, `RemoveNotAccessibleListings` - bookkeeping of the entry's own listings.
- **Callers enumerated** (Grep `UploadListingCache\.`): panel `ctrlcon5.cpp` (Create Directory x2,
  Quick Rename x2), `fs3.cpp` (Send FTP Command x2); operations `operats3.cpp`, `operats4.cpp`,
  `operats8.cpp` (delete and other operation workers), `operatsa.cpp`, `operatsb.cpp` (upload). All
  go through the six methods; none needs a change.
