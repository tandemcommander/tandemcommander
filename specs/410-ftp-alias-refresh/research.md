# Research - 410-ftp-alias-refresh

## R1 - Which connections are "another name of the server"

- Decision: another host with the same user (case-sensitive; no user = `anonymous`) and the same
  port (text; no port = `21`), as `FTPHasTheSameRootPath` compares them today.
- Rationale: the item's *Expected*; feature 341's rule (a client cannot tell names of one server
  from two servers: maybe the same server).
- Alternatives: 345's wider rule (any other connection, also another user / port) - rejected by the
  item's wording and its *Notes* on the cost of extra listings; noted as a limit.

## R2 - Refresh or "outdated" mark

- Decision: a panel whose path the notification covers is refreshed (same code path and timing as
  under its own name); cached listings of folders not shown are dropped (the next use lists them).
- Rationale: the stale listing on screen is the defect; the plug-in has no "outdated" display state
  (`PathListingMayBeOutdated` only guards uploads). Cost: one listing per covered panel - at most the
  two panels; detached FSs are not shown (the refresh request of a detached FS does nothing until it
  is attached, as today).

## R3 - What the refresh may trust

- Under its own name the refresh sets `NextRefreshWontClearCache` (the notification already dropped
  the plug-in's cache of that name). Under another name nothing of the panel's name was dropped, so
  the flag is cleared: the forced refresh (`ChangePath` mode 1) drops the viewer files of the panel
  path (and below) and, once the new listing arrives, `ListingCache.RefreshOnPath` of the path and
  below - the behaviour of Ctrl+R.

## R4 - Listing cache (`CListingCache`)

- Measured (row CACHE-ALIAS): keyed by host `StrICmp`; a folder visited at 127.0.0.1 and changed via
  localhost is shown from the cache. Decision: drop the host from the comparison in
  `CListingCache::AcceptChangeOnPathNotification` (user + port + path rule only).

## R5 - Viewer cache (FR-007)

- Unique names of viewed files are `<fs-name>:` + the FS's user part (`MakeUserPart`, no password)
  + the file path. The core drops them by prefix (`RemoveFilesFromCache`). For each FS of another
  host (same user and port) the plug-in builds its own root + the notified server path and drops
  both `ftp:` and `ftps:` variants, as `CPluginInterface::AcceptChangeOnPathNotification` does for
  the notified name. A root that does not fit the buffer is skipped (nothing cut: nothing is
  dropped, only the cache stays - same as today).
