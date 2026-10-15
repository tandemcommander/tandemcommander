# Fix log: 227 - Compare Directories and a subfolder name of 260+ bytes (measured: no defect)

Backlog (found by 222's audit): Compare Directories (`mainwnd5.cpp:1560/1584`) copies a disk
subfolder's name into a MAX_PATH buffer with `lstrcpyn` - a name of 260+ bytes in UTF-8 (86 CJK
letters + 2) is cut; the premise: the cut name (possibly another existing folder) is compared in its
place and the result is wrong.

## Measured

Probe `probe/cmp227_probe.ps1`: both panels hold N (the long name, its f.txt differs between the
sides) and S (N cut to 259 bytes, its f.txt the same on both sides); Compare Directories by size and
time with subdirectories, then Change Attributes Hidden on what it selected. The build at 226
(`probe/result.txt`):
- SHORT (the control, "nn" / "ss"): N marked, S not;
- LONG: **refused** - "Cannot finish operation because of too long name", nothing marked.

Not reachable: the cut name alone is 259 bytes, so the panel path + the cut name never fits the
MAX_PATH bytes `CompareDirsAux` / `ReadDirsAndFilesAux` build (every `SalPathAppend` there is
checked and refuses). The same holds for the Find window's `CompareName1/2`
(`finddlg1.cpp:2772/2782`): a path cut at 259 bytes never takes a name - empty, not used.

Left (a limit, not a defect): Compare Directories refuses trees whose paths pass MAX_PATH bytes.

No code change.
