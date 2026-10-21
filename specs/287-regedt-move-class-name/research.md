# Research: feature 287

## R1. The buffer size at `fs3.cpp:218`

- Decision: no change; record that feature 131 fixed it.
- Rationale: at HEAD 243174e4 `CPluginFSInterface::AcceptChangeOnPathNotification` passes
  `sizeof(key)` (`char key[3 * MAX_KEYNAME]`), `sizeof(path2)`, and `path1` has the size of `path2`
  (commit d041841a, `specs/131-plugin-defect-batch/items/regedt.md` §8, with the comment
  "feature 131: the sizes passed are the sizes of the buffers"). 131 also found the effect
  unreachable: nobody posts a change notification with a registry path.
- Alternatives: a pure rule for the path comparison (131's suggestion) - not asked by the item.

## R2. Why the class-name question never appears

- Decision: read the target's class name with `SafeQueryInfoKey(targetHKey, targetRoot, target, ...)`.
- Rationale: `CopyOrMoveKey` opens the source (`KEY_READ`), reads its class name, then
  `SafeCreateKey(targetRoot, target, sourceClassName, KEY_WRITE | KEY_READ, targetHKey, ...)`.
  `RegCreateKeyExW` sets the class only when it creates the key; an existing key is opened as it is.
  The check that follows queried `sourceHKey` - the same key twice - so `CompareStringW` always
  returned `CSTR_EQUAL`. Upstream since 3945ecf7. With `targetHKey` (it has `KEY_READ`, which
  includes `KEY_QUERY_VALUE`, what `RegQueryInfoKeyW` needs) the class of the existing target is
  read. The error box of a failed query names the target (`targetRoot`, `target`), as the other
  target errors of the function do.
- Alternatives: (a) remove the check - loses a warning the program means to give; (b) copy the
  class name onto the existing key - impossible: Windows has no call to change a key's class.

## R3. Who reaches `CopyOrMoveKey`

- `CopyOrMoveFromFS` (F5 / F6 / drag and drop) for each selected key - the question's path.
- `QuickRename` (F2, `fs3.cpp`) with `move = TRUE` - `TestKey` refuses an existing target first,
  so a freshly created target always has the source's class: no question.
- Its own recursion for subkeys: a subkey of the same name in an existing target subtree is checked
  as well; "All" (`skipAllClassNames`) is shared by the whole operation.

## R4. The question's texts

- The name: `FormatWideU8("%ls\\%ls", ...)` - UTF-8, whole (feature 129); shown by the core's
  `CStaticText` (`IDS_FILENAME`, path ellipsis when too wide - the probe's names are short).
- The question: `LoadStr(IDS_COPYCLASSNAME)` - a code-page string; the core sets it with
  `SalSetWindowTextU8`, which falls back to the code-page path when the text is not valid UTF-8.
  The probe reads the shown text and compares it with the translation (Czech) - this is where a
  wrong reading would show.
- The title: `LoadStr(IDS_WARNING)`, set with `SetWindowText` (code page) - right for a code-page string.

## R5. Setting a class name in the probe

- Decision: P/Invoke `RegCreateKeyExW` (with `lpClass`) and `RegQueryInfoKeyW` through `Add-Type`
  in the probe; .NET's `Microsoft.Win32.Registry` has no class name.
- Every key the probe creates lives under `HKCU\Software\TcProbe287`, removed at the end.

## R6. Pure decision for `saltests`?

- Decision: none. The change is which handle is queried; the comparison is unchanged. The probe is
  the test; its question rows FAIL on the build before the fix (the negative control).
