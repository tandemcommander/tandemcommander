# Fix log: 182 - Focus Shortcut Target's error box with a long name

Found by 181's review (older): `fileswn0.cpp` `FocusShortcutTarget` composed its error box with
`sprintf` into `char errBuf[MAX_PATH + 300]` - the shortcut's name may have up to 780 bytes.

## Measured (before)

Probe `probe/badlnk_probe.ps1`, the build at 181: a broken shortcut (a text file named `*.lnk`)
named with 200 CJK letters (604 bytes), Focus Shortcut Target (838): the box was shown, then the
program **crashed** - "Stack memory corruption" (a bug report written). `bad.lnk`: fine. 2 / 2
(`probe/result_before.txt`).

## Work

`src/fileswn0.cpp`: the text on the heap (`CSalHeapString::Printf`), the whole name; low memory -
the name alone.

Build: BUILD SUCCEEDED.

## Measured (after)

4 / 0 (`probe/result_after.txt`): the box names the whole file, no report, the program exits clean.
