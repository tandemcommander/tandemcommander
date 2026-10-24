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

## Change stamps (`CUploadChangeStamp`, review 2)

| Field | Meaning |
|---|---|
| User, Host, Port | the server name a change was reported for (user anonymous = NULL) |
| Time | `IncListingCounter()` at the latest reported change |

- Stamped by every change report (inside `InvalidateOtherNamesOfServer`); kept after the uploads end.
- `AddOrUpdateListing(user, host, port, ..., listingStartTime)`: a stamp with the same user and port,
  another host and `Time > listingStartTime` -> the listing is not added (returns TRUE, the upload
  lists the path itself).
- Bound 1,000 names; past it, or when memory runs out, `ChangeStampsLost` refuses every panel
  listing (fails closed).

The first design's in-memory table of looked-up addresses (`CSalFtpHostAddrTable`) and its
relation rule were removed after review 1 (M1): addresses do not prove two servers different.
