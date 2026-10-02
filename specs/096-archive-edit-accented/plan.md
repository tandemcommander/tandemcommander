# Implementation Plan: edited files with non-ASCII names are packed back

**Branch**: `096-archive-edit-accented` (from `095-archive-path-buffers`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

One function, `CFileTimeStamps::CheckAndPackAndClear` (`src/salamdr3.cpp`):

1. the look-up of the temporary copy uses the wide helper `SalFindFirstFile`
   (`WIN32_FIND_DATAW`) instead of the code-page `FindFirstFile` on a UTF-8
   path;
2. only "not found" drops an item; another failure keeps it (FR-002);
3. the path buffer is bounded (`_snprintf_s`, `_TRUNCATE`);
4. `SetCurrentDirectory` before packing converts the UTF-8 path
   (`SalU8ToW` + `SetCurrentDirectoryW`, code-page call as the fallback - the
   house pattern of `RemoveTemporaryDir`).

No interface, string or configuration change. Evidence: the measurement probe
`probe/archedit_probe.ps1` on the hidden desktop, before and after;
independent review.
