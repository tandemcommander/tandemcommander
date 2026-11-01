# Fix log - feature 380 (backlog item `regedt-full-path-cut-reported-as-success`)

## Measurements before the fix (HEAD0 823f2873, Debug x64 build of HEAD - `build.cmd` up to date)

1. **The API fills the buffer before failing** (Python ctypes): `WideCharToMultiByte(CP_UTF8, 0,
   200 x U+010D, -1, buf, 260)` → returns 0, `GetLastError` 122, all 260 bytes written. The helper
   `WStrToU8` (`src/plugins/regedt/utils.h`) then sets `dest[259] = 0`: 259 bytes ending in a lone
   lead byte `0xC4`.
2. **Probe** `probe/regpath380_probe.ps1` (hidden desktop, `result_before.txt`):
   - SHORT (control, typed `s`) PASS - the panel at `...\X\s`;
   - LONG FAIL - current key `reg:\HKEY_CURRENT_USER\Software\TcProbe380\<150 x 'x'>` (194 bytes
     with the backslash), typed 100 x 'r' (full path 294 bytes): **no message, the panel went to
     `...\<65 x 'r'>`**, another existing key (the path cut at 259 bytes);
   - CJK FAIL - 40 CJK letters typed under a 40-CJK-letter key: the path cut inside a character,
     "Unable to open registry key `...\uFFFD`", the panel stayed;
   - EXACT (added after analyze, `result_before_exact.txt`): typed the 65-letter name - full path
     exactly 259 bytes - PASS, the panel at `...\<65 x 'r'>` (the boundary is accepted before).
   - Registry restored identical (SHA-256), fixture key removed.
3. **Reachability**: Change Directory (Shift+F7) or the command line `cd` with a relative path while
   a Registry Editor key is in the panel → `src/fileswn3.cpp` (`IDS_INCOMLETEFILENAME`, relative path
   on a plug-in FS) → `GetFullFSPath(..., absFSPath, MAX_PATH, success)` with `success = TRUE` →
   with `success` still TRUE the core goes to `CHANGE_AGAIN_NO_DLG` with the buffer. Default
   configuration (regedt is `on`).

Severity note: the item said to raise it into the 7-8 band if a probe shows the cut key existing -
the LONG row shows exactly that. The item is closed by this feature, so the field is not changed.

## Inventory of `WStrToU8` in the plug-in (30 calls, research R5)

Reaching the panel unchecked: `fs2.cpp` GetFullFSPath (`>= 0`), `fs3.cpp` QuickRename `newName`,
`fs5.cpp` `nextFocus` (rename by Move), `finddlg2.cpp` Focus (path + name). All others are checked or
write into buffers three times the wide maximum (cannot fail). The helper is unchanged.

## Decisions

- No heap buffer: the full-path buffer is the core's (`char absFSPath[MAX_PATH]`, `pathSize`); a
  longer one is a core change for all FS plug-ins → Inbox item (leftover).
- Rename focus names: empty on failure, the rename stays done (as `CreateDir` in `fs3.cpp` does).
- No `saltests` rule: the changes are single result checks in plug-in code; nothing pure for
  `src/common/`.
- No UI string change (`IDS_LONGNAME` exists) → no `.slt` refresh.

## Implementation

- `src/plugins/regedt/fs2.cpp` `GetFullFSPath`: a failed `U8ToWStr` of the typed path and a failed
  (or impossible: no room after `fs-name:`) `WStrToU8` of the full path set `success = FALSE` after
  `Error(IDS_LONGNAME)`; success only when the whole path was written.
- `src/plugins/regedt/fs3.cpp` `QuickRename`: focus name empty when it does not fit `MAX_PATH`.
- `src/plugins/regedt/fs5.cpp` (rename by Move): `nextFocus` empty when it does not fit `2 * MAX_PATH`.
- `src/plugins/regedt/finddlg2.cpp` Focus: both conversions checked; failure → `IDS_LONGNAME`, nothing
  posted.

## Checks after the fix

- `.\build.cmd` → `BUILD SUCCEEDED` (the C4267 warnings of `fs2.cpp` are in older code below the
  function, lines 470-686).
- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `saltests`: not run for a reason - nothing in the core or `src/common/` changed.
- Probe `result_after.txt`: SHORT PASS, EXACT PASS (259 bytes still accepted), LONG PASS (message
  "Unable to finish operation because of too long path name." + the system text of error 122, the
  panel stays at `...\X`, the core re-opens Change Directory for correction), CJK PASS (same message,
  instead of "Unable to open ...\uFFFD"); 8/8 rows, registry restored identical, fixture key removed.
  Negative control: the same probe on the build of HEAD0 (`result_before.txt`) - LONG and CJK FAIL.
- SC-002: `grep -n WStrToU8` over the four files - the unchecked calls left are the display /
  comparison ones of research R5 (`fs3.cpp` AcceptChangeOnPathNotification, `fs5.cpp` overwrite and
  error dialog texts), whose buffers are three times the wide maximum.
- Rename and Find Focus rows: NOT DRIVEN by the probe (reading the focused item of the owner-drawn
  panel, driving the Find window); proven by reading - each now tests the result and never hands on a
  cut name. Not a person step: the changes are guards on paths that the probe's conversion failure
  already exercises in `GetFullFSPath`.

## Review

Review 1 (independent agent, refute-first): **no MUST, no SHOULD**. It re-ran the probe on the fixed
build (8 PASS) and built its own negative control (worktree at c825e93b, only `regedt.vcxproj`, a
separate build folder, the old `regedt.spl` in a copy of the build tree): SHORT and EXACT PASS, LONG
FAIL (the panel went to the other existing key), CJK FAIL - the probe tells the old plug-in from the
new one. Callers enumerated (one core caller of `GetFullFSPath`), no data-loss route, all 30
conversion calls re-checked. NOTEs:

1. `Error()` appends the text of the last error (122, "data area too small") to the new messages -
   **fixed**: `SetLastError(ERROR_SUCCESS)` before each new `Error(IDS_LONGNAME)` (the plug-in's own
   convention, `finddlg2.cpp` hex pattern). Probe re-run (`result_after.txt`, label after-review): 8/8
   PASS, the message is now only "Unable to finish operation because of too long path name.".
2. The rename and Find guards are proven by reading only (NOT DRIVEN) - as recorded above; the Quick
   Rename one is reachable (200 x U+010D = 400 bytes over `MAX_PATH`).
3. The core cuts the focus name at `MAX_PATH` in `ChangePathToPluginFS` (`fileswn2.cpp`, `backup3`) -
   outside the item: Inbox item `changing-to-a-plug-in-path-cuts-the-name-to-focus-at-259`
   (`review:380`).
4. The Find window's message box was parented to the main window (`DialogStackPeek()` empty on the
   Find thread) - **fixed** for the new message: `Error(HWindow, IDS_LONGNAME)`.

No MUST → no second review. After the NOTE fixes: `.\build.cmd` BUILD SUCCEEDED, encoding guard
`TOTAL: 0 finding(s)`, probe 8/8 PASS, registry restored identical.
