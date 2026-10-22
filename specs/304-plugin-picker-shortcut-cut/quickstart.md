# Quickstart: validating 304

1. Build: `.\build.cmd` (PowerShell, repository root) → `BUILD SUCCEEDED` (the plug-ins
   PictView, UnCAB, Undelete and saltests include the header).
2. Unit + end-to-end: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` →
   `saltests: <n> checks, 0 failed`. The 304 block prints whether the cut was reproduced on the
   fixture volume (a volume without 8.3 names - the build folder on this machine).
3. Measurement before/after (optional): build `probe/measure3.cpp` with `cl` (see `fix-log.md`)
   and run it with a base folder on a volume without 8.3 names: before the fix
   `ResolveNetHoodFolderW` returns 259 units for 260-400-unit targets; after it returns the whole
   plain target.
4. Not driven: picking a network location in the real dialog (needs a real mouse) - a person
   step (see `fix-log.md`).
