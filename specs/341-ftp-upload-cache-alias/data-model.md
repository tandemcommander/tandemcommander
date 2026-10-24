# Data model - feature 341

## Cached server entry (`CUploadListingsOnServer`, unchanged)

User (anonymous = NULL), host as typed, port; its cached folder listings.

## Cache reaction to a change report (new)

A change reported for (user, host, port):

| Entry | Reaction |
|---|---|
| the exact entry (`FindServer`) | the report as before (features 302 / 323) |
| same user and port, another host | `InvalidateAllListings()` - ready listings dropped; listings in progress marked possibly outdated (their waiting workers are woken when the listing ends and list again) |
| another user or port | nothing (another server, as before) |

The first design's in-memory table of looked-up addresses (`CSalFtpHostAddrTable`) and its
relation rule were removed after review 1 (M1): addresses do not prove two servers different.
