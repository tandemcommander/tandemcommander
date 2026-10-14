# Research: feature 144

## R1 - Measured on 0.1.10 (build of `bce0812a`, the core unchanged since 0.1.10)

109 probe, new case `resubst-both` (`probe/result_pre144.txt`): A\arc.zip (x.txt tag 1) and
B\arc.zip (x.txt tag 2), 131 bytes each, B given A's write time. R opens `T:\arc.zip` (-> A), F3
(tag 1 copy in SAL7F9.tmp); `T:` re-pointed to B; L opens `T:\arc.zip` (-> B):

- L's F3 was given **tag 1** (A's member - the R panel's copy, the same SAL folder);
- L's F4 edited that copy; leaving the archive packed it into **B\arc.zip**: B's x.txt now
  "content-of-member-1" + the edit. A unchanged. **B's own x.txt lost, silently.**

The case `resubst` (109's review row: the right panel left before the re-point) passes.

## R2 - Why

`CFilesWindow::SetArchiveCacheKey109` (fileswn2.cpp): keys equal (one name), size and time equal,
then `SalGetFileIdentity(GetZIPArchive())` and `SalGetFileIdentity(another->GetZIPArchive())` -
both read through `T:\arc.zip` NOW, i.e. both B: equal ids -> `sakShare`. The other panel's
archive is no longer the file its name names.

**Decision**: each panel stores the identity read at its own open (`ZIPArchiveIdentity`, the
archive was just listed through that name, so it is the listed file); the choice compares the own
fresh read with the other's stored one. Side benefit: the other panel's archive is not touched
at all any more (109 avoided the read only with the size/time pre-filter - a share that stopped
answering made the open wait).

Alternatives: comparing the volume serial alone (re-pointed SUBST to the same volume keeps it);
re-reading and comparing the path's final target (`GetFinalPathNameByHandle`) - also changes
with the re-point and needs the other's handle; rejected.

## R3 - The low-memory fallback

`SetArchiveCacheKey109` returns without a key when `SalNameIdentityKeyAlloc` or the unique key's
`Printf` fails; `GetArchiveCacheKey` then builds the key from the name on every use - which may
equal the other panel's key although the choice said "unique". **Decision**: a flag
`ZIPArchiveCacheKeyFailed`; `GetArchiveCacheKey` returns FALSE while it is set (its callers
already treat FALSE as low memory: F3 / F4 do nothing - `TRACE_E(LOW_MEMORY)` - and the flush of
the archive's copies is skipped, which is right since no copy was made through this key).
Not driven (no fault injection in the core); by reading.
