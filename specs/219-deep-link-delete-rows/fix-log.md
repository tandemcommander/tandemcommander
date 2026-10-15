# Fix log: 219 - 197's rows not driven: deep directory symbolic links, Recycle Bin masks

Backlog (left by 197's review, `specs/NEXT-WORK.md`): "not driven: a deep directory symbolic link,
the delete by Recycle Bin masks, a cloud placeholder past 780 characters".

## Measured

Directory symbolic links can be made on this machine (`mklink /D` works without elevation).
Probe `probe/deeplink219_probe.ps1` (197's `deepjunc_probe.ps1` with the link kind and the Recycle
Bin mode as parameters; the masks `*.txt`; every box answered Yes), the build at 218
(`probe/result_before.txt`, 17 / 1):
- **SYM-SHALLOW / SYM-DEEP / SYM-DEEP2 / SYM-TREE** (a directory symbolic link in folders of 41,
  283 and 874 characters, and F8 on the deep folder holding it): "delete symbolic link?", only the
  link removed, the target's file kept - PASS;
- **MASK-SHALLOW / MASK-TREE / MASK-DEEPTREE** (Recycle Bin by masks: a junction, a folder holding
  one, a deep folder holding one): the target's file kept, the link gone - PASS;
- **SYM-FOCUS: FAIL** - Go to Shortcut Target on a link whose stored target is in the Win32 long
  form `\\?\C:\...` (as `mklink` stores it when given so; the probe made every link that way):
  "Error Changing Directory - Path: "\\?\C:\...\t6" Error: The path specified is invalid."
  SYM-FOCUS-PLAIN (the target stored as `C:\...`): PASS.

Not driven: a cloud placeholder past 780 characters (no OneDrive here) - owed to a person.

## Work

- `src/common/salreparse.h` `SalReparseNameAsPath` (header-only, saltests
  `TestReparseNameAsPath219`, 15 checks): a link's name in the Win32 long form (`\\?\C:\x`,
  `\\?\UNC\srv\share`) or the NT form (`\??\C:\x`, `\??\UNC\...`) is the path it names; a volume,
  `\\?\GLOBALROOT`, a name without a root, and a name with a component ending in `.` or ` ` (the
  plain path would name another folder - Win32 trims them) stay as they are;
- `src/salamdr2.cpp` `GetReparsePointDestination`: the print name and (when it is empty) the
  substitute name through it (the substitute name's `\??\UNC\` was made `UNC\...` before - a
  relative name).

Build: BUILD SUCCEEDED; saltests 22,443 / 0.

## Measured (after)

`probe/result_after.txt` 20 / 0 (the final build): SYM-FOCUS goes to the target; a new row
SYM-FOCUS-UNC (the link stored as `\\?\UNC\localhost\C$\...`) goes to `\\localhost\C$\...` (not
run on the build before). Regression: 197's probe 12 / 0 (`probe/regress_197.txt`).

## Review

Refute-first review: accept. Every caller checked: the delete's decisions pass no buffer
(untouched); Go to Shortcut Target is the fix; a junction with a long-form print name now passes
the junction check; `salamdr2.cpp` 1356 / 1846 (the path resolution through links) now follows such
a symbolic link as a local one and takes `\??\UNC\` for a network target - improvements, not
driven; long targets still open (the program adds `\\?\` itself). Taken: the rule as a header with
saltests; the substitute name's `\??\UNC\`; a name with a trailing dot / space component kept long.
Not driven (recorded): the Copy dialog's text and Enter on a junction with a long-form name; the
Recycle Bin "always" setting on a deep directory symbolic link (the link question is skipped there);
a Copy / Move through a `\\?\C:` symbolic link; `\\.\C:\x` (taken for a network path by
`IsUNCPath`).
