# Fix Log — Feature 080 (upgrading over a running instance)

Running record, newest entries at the bottom of each section. Written while
working, not reconstructed afterwards. The whole Spec Kit flow
(specify → plan → tasks → implement) runs autonomously; the maintainer is away.

**Baseline**: branch `080-restart-manager-upgrade` from `main` at `e6466db`
(0.1.8 / build 192 in the tree, **unreleased**; last published version 0.1.7).

## Status

| Phase | State | Notes |
|---|---|---|
| specify | done 2026-09-20 | `spec.md`, checklist 16/16, no clarification markers (three decisions recorded as assumptions) |
| plan | pending | |
| tasks | pending | |
| implement | pending | |

## Log

### 2026-09-20 — specify

- Branch created by the Spec Kit git hook: `080-restart-manager-upgrade`
  (feature number 080). `.specify/feature.json` points at the new directory.
- Read before writing: `specs/NEXT-WORK.md` item 2,
  `specs/072-winget-distribution/REMAINING-WORK.md` P1 and `quickstart.md`
  §2b, `setup/tandemcommander.iss`, the exit sequence in
  `src/mainwnd3.cpp` (`WM_ENDSESSION` / `WM_QUERYENDSESSION` /
  `WM_USER_CLOSE_MAINWND`, one shared handler).
- First observations from the code, to be confirmed by the baseline:
  - The handler never looks at `ENDSESSION_CLOSEAPP`; an installer's request
    is treated as an ordinary (non-critical) sign-out: the **whole interactive
    exit runs inside the question stage** — waiting windows, plug-in unload,
    panel close, configuration save, `DestroyWindow` — and only then returns
    TRUE. Any prompt on that path blocks an unattended requester.
  - A comment at the end of the handler states the design premise: *"all
    Windows versions kill the process as soon as the main window is destroyed
    during shutdown, so the following code is dead code in that case"*. For an
    installer's request that premise is false — nobody kills the process; it
    has to end by itself.
  - Nothing in `src/` calls `RegisterApplicationRestart`.
  - The installer script sets neither `CloseApplications` nor
    `RestartApplications`, so Inno Setup's defaults apply (close: yes,
    restart: yes).
- The 072 evidence also named `salmon.exe` as holding files; the helper was
  removed in feature 079, so the baseline has to be taken again at HEAD
  (spec FR-001).
- Decisions made without the maintainer (spec *Assumptions*): no program
  option for the restart; state survives through the stored configuration;
  restart after reboot/sign-out excluded.
