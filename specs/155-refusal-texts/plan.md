# Plan: 155 - refusal texts

**Spec**: [spec.md](spec.md) · **Log**: [fix-log.md](fix-log.md)

Core: `DirTargetIsSource107` (`fileswn6.cpp`) returns the folder texts; `BuildScriptDir` refuses a
folder copied onto itself by name at the folder level; `worker.cpp` (the merge below the top level,
copy); `ShowPackIntoItselfRefusal` (`fileswn7.cpp`). Renamer: `rendlg3.cpp` - its own texts through
`FileError` with no system reason. Strings: core 12161-12163 (bundle 12160-12175), Renamer 1243
and 1287 (bundles with free slots). Translations: `translate.merge` + pins
(`translations/ui-overrides.json`); the Renamer's `.slt` files take only the two entries (the
merge re-lays out 159 controls - item 16's drift, not this feature).

Constitution I-VI: no dependency; no interface or registry change; strings by the documented
two-stage refresh; UI otherwise unchanged. PASS.
