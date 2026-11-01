# Closing report - 373-wsl-share-list
Backlog item: wsl-localhost-offers-no-share-list - Server path of WSL (wsl.localhost) offers no share list: error 53 skips the provider fallback
Outcome: closed

## What changed

- `src/common/saluncserver.h`: three pure rules (feature 373) - `SalUncServerNotFoundErr`
  (the "server not reached" set of 125: 53, 51, 1231, 1232), `SalUncShareListAsksProviders`
  (the network providers are the second question when `NetShareEnum` gave nothing - now also at
  53; 51 / 1231 / 1232 still not), `SalUncProviderListError` (the error after the providers: 0
  with a folder share, otherwise `NetShareEnum`'s own error - the rule of 125, moved here).
- `src/shares.cpp`, `CUncSharesJob::Read`: uses the three rules; the provider loop is unchanged.
  The only route that changes is "53 with no share": the providers are asked.
- `src/saltests/saltests.cpp`: `TestUncShareListProviders373`, 35 checks.
- `specs/373-wsl-share-list/probe/wslshares_probe.ps1`: hidden-desktop probe of the real route.

For the user: `\\wsl.localhost`, `\\wsl.localhost\` and `\\wsl$` in Change Directory, and the way
up (Backspace, `..`) from `\\wsl.localhost\<distribution>`, offer the WSL distributions; a server
that does not exist still ends in the same single "(53)" box after the same wait. No new UI
string; `PRIVACY.md` unchanged (its claim stays true).

CHANGELOG entry (no `## [Unreleased]` section exists - versions are the maintainer's; to be added
there):

```markdown
- **`\\wsl.localhost` offers the WSL distributions** (feature 373).
  - **Before:** typing `\\wsl.localhost`, `\\wsl.localhost\` or `\\wsl$` in Change Directory, or going up (Backspace, `..`) from `\\wsl.localhost\Ubuntu`, showed "(53) The network path was not found" instead of the list of shared folders that other servers offer.
  - **Now:** the list shows the WSL distributions; picking one opens `\\wsl.localhost\<distribution>` (or `\\wsl$\<distribution>`). Other network places that are not Windows file servers but answer the same way through Windows get their list too. A server that does not exist still shows one error, after the same wait as before.
  - **Limitation:** measured with the Windows WebDAV client service stopped; with it running, a server that does not exist may take longer to report - the wait window's Esc / Close still end the wait.
```

## Measurements (before / after, commands)

Calls (PowerShell P/Invoke with the core's parameters, `research.md` R1): WSL - `NetShareEnum` 53,
providers list docker-desktop + Ubuntu in 1-7 ms; six missing servers - providers 1203 in 0-6 ms
right after `NetShareEnum`, but 2.7-21 s when asked first (the order is kept).

Probe (hidden desktop, `-Expect fixed`):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\373-wsl-share-list\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\373-wsl-share-list\probe\wslshares_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect fixed"
```

| | W1 `\\wsl.localhost` | W2 `\\wsl.localhost\` | W3 `\\wsl$` | W4 Backspace | C1 `\\localhost` | N1 missing name | U1 `\\192.0.2.1` |
|---|---|---|---|---|---|---|---|
| before / negative (main build) | (53) box | list (1707 by chance) | (53) box | (53) box | list | (53), 1.3 s | (53), 21.1 s |
| after | list, 12 ms | list, 6 ms | list, 7 ms | list, 129 ms | list | (53), 1.3 s | (53), 21.0 s |

`result_before.txt` (measure mode, 7 INFO), `result_negative.txt` (PASS 11 / FAIL 3: W1, W3, W4),
`result_after.txt` (PASS 14 / FAIL 0). Registry restored and verified identical in every run.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (Debug x64; no UI string, language file or resource changed,
  so `build.cmd full` and the `.slt` refresh were not needed).
- saltests -> `saltests: 30155 checks, 0 failed` (30120 before, +35).
- Probe `wslshares_probe.ps1`: 14 / 14 PASS (7 rows + 7 row ends), negative control fails the
  three rows of the defect.

## Reviews (findings and what was done)

One independent refute-first review: no MUST, no SHOULD; it re-ran the probe (14 / 14), its own
timing and a saltests negative control (the old rule fails exactly the key check). Five NOTEs:
the "only answer" wording (fixed), a saltests label (fixed; its older half - a list cut off by
"more data" shown as whole, code of 125 - became an Inbox item), deeper provider names
(recorded, unmeasured), WebDAV running (in *Assumptions*), closing documents (done).
Details: `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry above to `CHANGELOG.md` when an *Unreleased* section is created.
- No person-step item: the change was driven end to end on the hidden desktop with the real WSL
  provider (no keyboard / clipboard row).

## New Inbox items (slug - title)

- `share-list-a-list-a-server-never-finishes-more-data-without` - Share list: a list a server
  never finishes (more data without an end) is shown as if it were whole (`review:373`).
