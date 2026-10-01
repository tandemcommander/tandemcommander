# Quickstart: feature 092 — name identity

## Automated (run by the feature, repeatable)

```
build.cmd                         Debug build
build\...\saltests.exe            12,828 checks, 0 failed (TestNameIdentity092)
python tools\check_encoding.py --strict        TOTAL: 0
specs\092-name-identity-unicode\probe\build_and_run.cmd    both probes PASS
specs\092-name-identity-unicode\probe\run_perf.cmd         comparator timing (prints only)
powershell -File specs\092-name-identity-unicode\probe\focus_probe.ps1    GUI: cursor after refresh
powershell -File specs\092-name-identity-unicode\probe\timing_probe.ps1   refresh of 100,000 files
```

The two PowerShell probes start their own instance, save the registry key
`HKCU\Software\Tandem Commander` first and restore it afterwards.

## Owed to a person (Release build, Czech or another accented language)

Make a folder with `Článek.txt`, `ĥ.txt`, `Ĺ.txt`, a subfolder `Článek` and
an archive `Č.zip`.

1. **Cursor**: put the cursor on `Ĺ.txt`, press Ctrl+R: it stays. Rename
   `Článek.txt` to `článek.txt` in Explorer while the panel shows the folder:
   the cursor stays on the file.
2. **Quick Rename (F2)** `Článek.txt` to `ČLÁNEK.TXT`: one rename, no
   question. F6 on the folder `Článek`, type `článek`: the folder is renamed.
3. **Move `ĥ.txt` onto `Ĺ.txt`** (F6, type `Ĺ.txt`): the overwrite question
   appears (before: an error).
4. **Change Directory (Shift+F7)**: type the folder's path in the other case
   (`...\článek`); Alt+F12 shows one entry for it; go up with Backspace: the
   cursor is on `Článek`.
5. **Viewer**: F3 on a file in the folder `Článek` entered as `článek`;
   Space steps to the next file.
6. **Archive in both panels**: open `Č.zip` in the left panel and, typed as
   `č.zip`, in the right one; edit a file from it (F4), save, leave the
   archive: both panels show the updated archive.
7. **Selection**: select `Článek.txt` and `ĥ.txt`, Ctrl+R: both stay
   selected; `Ĺ.txt` does not become selected.
8. **Copy to the same folder** (F5 with the other panel on the same folder):
   "Copy of ..." names are offered as for ASCII names.

## Not testable on this machine

A case-sensitive directory on a network share, and a server that folds case
differently from Windows (see `fix-log.md`, S3, item 1).
