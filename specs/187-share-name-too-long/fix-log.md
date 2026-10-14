# Fix log: 187 - a too long server or share name is refused as "too long"

Backlog: NEXT-WORK section D, "Found by the second verification of 124-128", item 6 (second half,
125): "a share name near the path limit in a non-Latin script is offered and then refused with 'A
share name is missing' (say 'too long' instead)".

## Measured (before)

Probe `probe/share_probe.ps1` (the build at 186): Change Directory to `\localhost\` + 300 x `a` +
`\x`: "A share name is missing in the path specified." and the Change Directory dialog again;
`\` + 300 x `a` + `\s\x`: "A server name is missing ..." (`probe/result_before.txt`, 2 / 2).
`SalGetFullName` returned the "missing" codes for a part longer than MAX_PATH - 1.

## Work

`src/salamdr3.cpp` `SalGetFullName`: `IDS_TOOLONGPATH` for a server or share part that is too long.

Build: BUILD SUCCEEDED; saltests 22,344 / 0.

## Measured (after)

"The path specified is too long." for both (`probe/result_after.txt`, 4 / 0).

## Review

Quick refute-first review: sound - the Nethood / share-list branches need `callNethood`, which was
never set for a too-long part (the share list came through the `IDS_SHARENAMEMISSING`-only branch);
`IDS_TOOLONGPATH` is a documented result, mapped for plug-ins (`GFN_TOOLONGPATH`). Behaviour change
recorded: a too-long server / share part on the command line is now refused as "too long" at start
(it was kept and failed later as "missing").
