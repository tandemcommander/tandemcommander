# Closing report - 374-wsl-drive-item
Backlog item: change-drive-menu-and-drive-bar-have-no-wsl-item-for-the - Change Drive menu and drive bar have no WSL item for the Linux distributions
Outcome: closed

## What changed

- The Change Drive menu (Alt+F1 / Alt+F2) lists one item `Linux - <distribution>` per installed WSL
  distribution of the current user, sorted as the file system orders names, between the cloud
  storages and Network, with the Tux icon of `System32\wsl.exe` (the Network icon when it cannot be
  read). Choosing one opens `\\wsl.localhost\<distribution>`; when the panel shows a folder of a
  distribution, its item is the checked one.
- The drive bar holds one WSL button: with one distribution it opens it (tooltip
  `Linux - <name>`), with several it is a drop-down (tooltip `Linux`) listing them.
- The distributions are read only from `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss`
  (`State` absent or 1); a name that cannot form the path (reserved or control characters, a
  trailing `.` or space, longer than 255 characters, a 0 inside) is left out, never changed; a path
  that does not fit is refused (`IDS_TOOLONGPATH`). Building the list never starts WSL.
- New option *Linux Distributions (WSL)* on the *Change Drive Menu and Drive Bar* configuration page
  (registry value `Change Drive Show WSL`, default on) hides all of it.
- Pure rules in `src/common/salwsl.h` with `saltests`; new strings `IDS_WSLLINUX` "Linux" (14169)
  and the check box `IDC_CHD_SHOWWSL` (6290), translated into the 8 enabled languages; the manual
  (`configuration_chdrv.htm`, `navigating_chdrvmenu.htm`, `windows_drivebar.htm`).

CHANGELOG entry (there is no `## [Unreleased]` section in `CHANGELOG.md`; versions are the
maintainer's - add it to the next release's section):

```text
- **The Change Drive menu and the drive bar had no way to the WSL Linux file systems** (feature 374).
  - **Before:** to open a WSL distribution the user had to type `\\wsl.localhost\<distribution>` in Change Directory.
  - **Now:** on a computer with WSL, Alt+F1 / Alt+F2 list `Linux - <distribution>` for every installed distribution (with the Linux penguin), and the drive bar has a penguin button - a drop-down when there are several distributions; choosing one opens `\\wsl.localhost\<distribution>`. The new check box *Linux Distributions (WSL)* on the *Change Drive Menu and Drive Bar* configuration page hides them. Building the menu does not start WSL.
  - **Limitation:** the settings import from Altap Salamander / Open Salamander does not set the new option (those programs never had it); a distribution installed while the program runs appears on the drive bar after the next Alt+F1.
```

## Measurements (before / after, commands)

- Before (`30268b7c`, read): no WSL item in `CDrivesList::BuildData`; probe on `main` built in a
  worktree (`%TEMP%\tc374negbuild`): PASS 2, FAIL 11 (`probe/result_before.txt`).
- After: probe `probe/wsl374_probe.ps1` on the hidden desktop: PASS 13, FAIL 0, NOT DRIVEN 0
  (`probe/result_after.txt`); command in `fix-log.md`, section *Probe*.
- Timing: the WSL part of an Alt+F1 list build median ~0.9 ms (0.73-1.04 ms); the whole build with
  the option on vs off +0.6 to +1.1 ms; no distribution started by the builds.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED; `.\build.cmd full` -> BUILD SUCCEEDED (189 language modules).
- `saltests.exe` -> `saltests: 30227 checks, 0 failed` (30155 before).
- Translations: module `salamand`, 2 gaps per language, 240 DeepL characters, 0 validation
  failures, no pins; `translate.slt --verify` byte-exact (298 files).
- Probe 13 / 13 PASS; registry restored with identical SHA-256 every run.

## Reviews (findings and what was done)

Review 1: no MUST, no SHOULD; NOTE 1 (drop-down chose by position in a list a rebuild could
replace), NOTE 2 (trailing `.` stripped by Windows), NOTE 3 (embedded 0 shortened a name) fixed;
NOTE 4 (settings-import deviation) -> decision item; NOTE 5 -> person step. Details in
`fix-log.md`, section *Review*.

## Owed to a person (with the new person-step items)

- `check-by-hand-the-wsl-items-of-the-change-drive-menu-and-the` - the penguin icon, a real mouse
  click on the drive bar's drop-down, the check box on the configuration page.
- Add the CHANGELOG entry above to the next release's section.

## New Inbox items (slug - title)

- `check-by-hand-the-wsl-items-of-the-change-drive-menu-and-the` - Check by hand the WSL items of
  the Change Drive menu and the drive bar (374)
- `should-the-settings-import-carry-the-new-wsl-option-of-the` - Should the settings import carry
  the new WSL option of the Change Drive page (374)
