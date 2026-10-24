# Data model - feature 341

## Known addresses of a host (`CSalFtpHostAddrTable`, in memory)

| Field | Meaning |
|---|---|
| host | the looked-up name, up to 255 bytes; compared ASCII case-insensitively |
| addrs[0..7], count | IPv4 addresses (network byte order) of the latest lookup |

- Record (host, addrs, n): n = 0 or host too long -> nothing recorded; an existing slot of the
  host is replaced; otherwise a free slot, else the slot recorded longest ago (round robin).
- Lookup (host) -> count copied (0 = unknown).
- Capacity 64 slots. Lives as long as the plug-in DLL; never written anywhere.

## Server relation (`SalFtpCompareServerNames`)

Input: same host text (case-insensitive), the two known-address lists.

| Condition | Result |
|---|---|
| same host text | `sfsnSame` (the existing exact entry) |
| either list empty | `sfsnMaybeSame` (identity cannot be told) |
| an address in common | `sfsnMaybeSame` |
| none in common | `sfsnDifferent` |

User (anonymous normalised) and port must be equal before the rule is asked; otherwise the
entries are different servers, as before.

## Cache reaction

For each cached entry other than the exact one, same user and port: `sfsnMaybeSame` ->
`InvalidateAllListings()` (ready listings dropped; listings in progress marked possibly outdated,
so the upload lists again).
