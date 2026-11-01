---
title: Confirm Ctrl+; opens a long Documents folder whole on a real keyboard
type: person-step
status: new
severity: 3
area: long-paths
source: leftover:386
who: person
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Confirm Ctrl+; opens a long Documents folder whole on a real keyboard

## Problem

Feature 386 made the Documents drive open a long Documents folder (more than 259 bytes of UTF-8,
fewer than 260 UTF-16 units) whole instead of the folder named like its 259-byte prefix. The
drive bar button was driven by a probe; Ctrl+; in a panel takes the same helper with the same
buffer change but needs a real Ctrl key state, which the hidden desktop does not have.

## Evidence

Feature 386, `specs/386-mydocs-path-whole/fix-log.md` (*Checks*, NOT DRIVEN rows), probe
`specs/386-mydocs-path-whole/probe/mydocs386_probe.ps1` (`LONG` FAIL before, PASS after - the
drive bar button). Ctrl+; is `src/fileswn0.cpp` (case 186, `myDocuments`), now
`char path[SAL_MAX_PATH_UTF8]`. The Debug-only seam `TC_PROBE_MYDOCS_FILE`
(`specs/386-mydocs-path-whole/contracts/salmydocs.md`) names the Documents folder without
redirecting the real one.

## Expected

Ctrl+; opens the whole long Documents folder.

## Steps

- [ ] Build Debug (`build.cmd`). In a temporary folder create a folder named with 90 CJK letters
      (for example 丁丂七丄丅丆万丈三上下丌不与丏丐丑丒专且丕世丗丘丙业丛东丝丞丟丠両丢丣两严並丧丨丩个丫丬中丮丯丰丱串丳临丵丶丷丸丹为主丼丽举丿乀乁乂乃乄久乆乇么义乊之乌乍乎乏乐乑乒乓乔乕乖乗乘乙乚),
      and a text file `docs.txt` (UTF-8) holding that folder's full path.
- [ ] Close every running Tandem Commander; in a Command Prompt run
      `set TC_PROBE_MYDOCS_FILE=<full path of docs.txt>` (an ASCII path) and start
      `build\tandemcommander\Debug_x64\tandemcommander.exe` from that prompt.
- [ ] Press Ctrl+; in the left panel → the panel shows the long folder itself (the directory
      line ends with the last letter 乚), no message; not a folder with a shorter name.
- [ ] Alt+F1, choose *Documents* → the same folder.
- [ ] Close the program; delete the temporary folder.

## Log

- 2026-11-02 — created (source leftover:386)
