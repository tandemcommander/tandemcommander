# Fix log: feature 093 - Unicode dialogs (encoding cluster B-1)

Branch `093-unicode-dialogs`, based on `092-name-identity-unicode`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T001 - baseline

- saltests before the feature: 12,828 / 0. Strict guard `TOTAL: 0`.
- `probe/B1Probe.cs` + `result.txt`: the Win32 semantics the feature rests on
  (research sections 1.3, 1.4), measured on this machine (code page 1250).

## T003 - the premise measured in the product

`probe/dialogs_probe.ps1` on the Debug build, two runs with identical output
(`probe/baseline_result.txt`): 56 PASS, 25 LOSSY. Test text `a ř Ж 日 📁`.

| Surface | prefill | set by program | typed |
|---|---|---|---|
| Create Directory (created as a Unicode dialog - the control case) | - | ok | ok |
| Change Directory, Pack, Unpack (path and mask), Select, panel filter | ok | ok | ok |
| Find: Named | - | ok | **lossy** |
| Find: Look in, Containing | **lossy** | **lossy** | **lossy** |
| Configuration: Hot Paths (path, name), User Menu (command, arguments, directory) | ok | ok | **lossy** |
| Command line | - | **lossy** | **lossy** |

The executable carries the common-controls 6 manifest and the process loads
comctl32 6.0 from WinSxS. With it `Edit` and `ComboBox` are Unicode controls
also inside a dialog created through the code-page entry point - research
section 1.3 ("the entry point decides"), measured in a process without that
manifest, does **not** hold in the product. Section 1.4 (the loop decides
for typed characters) holds: the typing-only losses sit exactly on the two
code-page loops (Find's thread, the Configuration window), and Find's two
all-channel losses on the fields with the code-page helper `CComboboxEdit`
attached (their inner edit reports a non-Unicode window).

Consequence: no dialog needs to be re-created as a Unicode window. Scope
revised (plan, tasks).

Seen by the probe, not part of the feature: the main window title shows `?`
for such a folder; a message box's text control is Unicode, its buttons are
not.

## Before S2 - the 7-Zip password measured

Confirmed, shipped since 0.1.0 (feature 005 made `EditLine` return UTF-8 one
day after feature 004 wrote the code-page conversion): `dialogs.cpp` reads
the password as UTF-8 into `char[128]`; `open.cpp`, `extract.cpp`,
`update.cpp`, `7zip.cpp` convert it with the code page. Measured:

| Archive | typed in the plug-in | result |
|---|---|---|
| made by 7-Zip 22.01 with `heslo-ř` | `heslo-ř` | nothing extracted |
| made by 7-Zip with `heslo-Ĺ™` (the garbled form) | `heslo-ř` | extracted, content equal |
| made by the plug-in with `heslo-ř` | - | 7-Zip opens it with `heslo-Ĺ™`, not with `heslo-ř` |
| ASCII password | same | extracted |

Also seen: with the wrong password no error window appeared within 9 s (not
traced); the `char` password buffers are never wiped.
