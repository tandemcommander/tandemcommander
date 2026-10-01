# Quickstart: verifying feature 088

## Automated (implementation session; results in `fix-log.md`)

| What | How | Expected |
|---|---|---|
| unit tests | `saltests.exe` | 0 failed (`TestCloseApp080` extended, `TestPluginVer088`) |
| update with viewers open | `probe\viewers_probe.ps1 -Exe <Debug tandemcommander.exe>` | every positive case: Restart Manager shutdown exit 0, process gone, no window left; every negative case: declined, process alive |
| long names | `probe\longpath_probe.ps1 -Exe <Debug exe>` | next / previous file works in PictView and the Database Viewer on a 300+ character path; process alive, no run-time check failure |
| interface diff | `git diff <base> -- src/plugins/shared/*.h` | additions at the end of `CSalamanderGeneralAbstract`, one constant, comments |

## Owed to a person

1. A real update (installer or `winget upgrade`) over a running installed
   version with a Code Viewer window open: the program closes, is updated and
   starts again.
2. Normal exit (Alt+F4) with a viewer window open: the plug-in's question
   appears, *No* keeps the program running.
3. Sign-out / shutdown with a viewer open: unchanged.
4. PictView and the Database Viewer on a deep folder: Space / Backspace step
   through the files.
