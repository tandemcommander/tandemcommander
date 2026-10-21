---
title: Ship the Network plug-in (nethood) enabled?
type: decision
status: open
severity: 3
area: other-plugins
source: github#5
who: person
created: 2026-10-13
updated: 2026-10-21
verified: -
effort: -
feature: -
related: [getshobjectname-code-page-cut-server-links]
depends-on: []
reason: -
---

# Ship the Network plug-in (nethood) enabled?

## Problem

GitHub #5 asked for `nethood=on`. Feature 125 made the reported case (`\\server\` in Change Directory) work in the core instead and left the policy of feature 007 (nethood off) alone. Enabling the plug-in would restore the predecessor's `net:` panel (a server's shares as a list in the panel, `..` from a share's root, the network root), at a measured and audited price.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L509-527. The price is measured and audited in `specs/125-unc-server-shares/research.md` R2; probe outputs with the plug-in in `specs/125-unc-server-shares/probe/unc_measure_with_nethood_plugin.txt` and `unc_result_fixed_code_with_nethood_plugin.txt`.

## Expected

(not stated in the source)

## Notes

The recommendation is the migrating agent's reading of the source, which states the price but no preference. Items reachable only with the plug-in (e.g. `GetSHObjectName`) are parked in this part.

## Question

Should the Network plug-in (`nethood`) ship enabled in the default build (`plugins.cfg` `nethood=on`), as GitHub #5 asks?

## Options

- A - keep it off (state now): the core's share list of feature 125 answers `\\server\`; the parent of a share's root and a sign-in for a server's share list can be added in the core (separate items).
- B - enable it: restores the `net:` panel (share list in the panel, `..` from a share's root, the network root). Its price (125 research R2): (1) shutdown - `Release()` -> `KillAll(TRUE, 0, 0)` terminates its threads with zero wait, the Debug build reports \"Detected memory leaks!\" at every exit after the plug-in was used; (2) it changes more than #5 - every UNC root gains `..` to `net:`, *Go to root* jumps there, the Change Drive menu's *Network* item becomes the plug-in panel (whose root depends on legacy network discovery) instead of the Windows folder picker; (3) a server that does not exist opens an empty `net:\\name` panel with no message; (4) encoding and buffers - `_tcsicmp` on UTF-8 names (rule 092), `LoadStr` / `FormatMessageA` texts in UTF-8 sinks, `MAX_PATH` buffers with silent cuts, an unbounded copy in `ChangePath`; the core's logon path only this plug-in reaches (`drivelst.cpp`, `WNetAddConnection2` / `CredUIPromptForCredentialsA`) is ANSI; (5) texts - \"Salamander\" / \"Open Salamander\" in `lang.rc` and in all eight `.slt` files; (6) public claims - `PRIVACY.md` (a plug-in enabled by default; its \"scan network on start\" option), the plug-in counts in `CLAUDE.md`, `architecture/09`, `CHANGELOG.md`. With the plug-in present, the core fallback of 125 steps aside by itself.

## Recommendation

A - keep it off. The reported case works in the core since 125; enabling costs the six listed items of work (leak at exit, wider behaviour change, silent empty panel, encoding residue, branding, public claims). Revisit only if users ask for the `net:` panel itself.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-21 — related item share-root-parent-offers-share-list done in feature 284
- 2026-10-21 — related item share-list-offers-sign-in done in feature 285
