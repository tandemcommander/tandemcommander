# Fix log - 297-regedt-delete-link

Backlog item `registry-editor-delete-or-move-deletes-a-linked-key` (source measure:296).

## Measured at 49147f36 (main, before the feature)

1. Sites (searched by name): `CPluginFSInterface::DeleteKey` (`src/plugins/regedt/fs3.cpp`) opens the
   key by name (`RegOpenKeyExW`, follows a link), enumerates and recursively deletes its subkeys
   (those of the link's target), then `RegDeleteKeyW(root, keyName)` - deletes the link's target;
   `CopyOrMoveKeyRec` (`fs5.cpp`) opens each source key by name, copies, and a Move ends with
   `SafeDeleteKey` (`RegDeleteKeyW`) on the source name.
2. Reachable: F8 (`CPluginFSInterface::Delete` -> `DeleteKey`), F6 / drag and drop
   (`CopyOrMoveFromFS` -> `CopyOrMoveKey`), Quick Rename (`QuickRename`, `fs3.cpp` ->
   `CopyOrMoveKey` with `move` TRUE) in a Registry Editor panel; plug-in on in `plugins.cfg`, default
   configuration. A link can be created unelevated under HKCU (`REG_OPTION_CREATE_LINK`). Callers of
   `DeleteKey`: only `Delete` and itself; of `SafeDeleteKey`: only `CopyOrMoveKeyRec`; of
   `CopyOrMoveKey`: `CopyOrMoveFromFS`, `QuickRename`.
3. New probe `probe/link297_probe.ps1` (style of 296's; links made / removed with
   `REG_OPTION_CREATE_LINK` / `REG_OPTION_OPEN_LINK` + `NtDeleteKey`; the snapshot never follows a
   link), first written in `%TEMP%\tc297scratch` (with `-Repo`) and copied here unchanged. Debug x64
   build of 49147f36 (`build.cmd`, BUILD SUCCEEDED):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tc297scratch\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File %TEMP%\tc297scratch\link297_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before -Repo E:\Projects\tandemcommander -OutFile %TEMP%\tc297scratch\link297_before.txt"
   ```

   First run: 15 / 15 with two probe bugs - `Jinde-Ok` expected the unsorted order (`'\'` sorts
   before `'|'`; the COPYTREE control failed on it - a negative finding about the probe, fixed), and
   the name in the error box is read through the code page (287's trap; `U8-Back` reverses it). A
   Bash here-doc collapsed `'\Top\'` to `'\Top'` in one edit (the known trap) - redone with the editor.
   Second run (`probe/link297_before.txt`): **16 PASS / 14 FAIL**, registry restored identical
   (SHA-256 34FA77DB...125A).
   - DELTREE / DELHKCR: `Jinde` and `Jinde\Sub` deleted, the link left, then "Unable to delete a
     registry key. (5) Access denied" for `Del\<K>`.
   - DELTOP: `Jinde` deleted, no box, the link left dangling.
   - DELDANGLE: the open-error box for the link, nothing deleted.
   - MOVETREE / MOVESKIP: `Jinde` copied into `Cil\<K>\L` and deleted, then "Unable to remove the
     original registry key. (5)" naming `Mov\<K>` (the TEXT row of MOVESKIP passes already before -
     STATE discriminates).
   - MOVETOP / RENAMETOP: `Jinde` copied and deleted, no box.
   - Controls COPYTREE, DEL, MOVE: PASS.

## Decisions

- Spec *Clarifications* (autonomous run): Delete removes the link itself (opened as a link,
  `NtDeleteKey`), a dangling one too; Move / drag and drop / Quick Rename refuse a link source key with
  the existing box `IDS_REMOVESOURCE` + `ERROR_NOT_SUPPORTED` (Retry / Skip / Skip All / Cancel) before
  anything of it is written; Copy unchanged; only the key of each level is looked at as a link (as
  296); other errors fail closed. No new string.
