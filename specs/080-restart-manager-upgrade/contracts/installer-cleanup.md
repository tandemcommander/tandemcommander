# Contract — removing the stale helper on upgrade

**Feature**: 080 · **Binding for**: `setup/tandemcommander.iss`. Evidence:
`research.md` R8, `fix-log.md` B4 and B6.

## I1 — What is removed

Exactly one file: `{app}\utils\salmon.exe` — the crash-reporting helper that
releases up to 0.1.7 shipped and feature 079 removed from the product. Nothing
else in `{app}\utils\` is touched (`sqlite.dll` stays).

## I2 — How — and how NOT

The file is deleted from the `[Code]` section, in
`CurStepChanged(ssPostInstall)`.

It MUST NOT be listed in `[InstallDelete]`, and no other section or directive
may make the installer register it with the Restart Manager. **Measured**: an
`[InstallDelete]` entry for it makes every update over a running 0.1.7 fail
with exit code 5, because the running, windowless helper is then put on the
list of programs to close, and the Restart Manager fails the whole list when
it contains a process it cannot close. A comment in the script says so, in
the style of the *"do not narrow it, winget depends on it"* comment of
feature 072.

## I3 — Timing and tolerance

At `ssPostInstall` the old program has been closed and its helper — which
watches its parent — has ended. Because the helper may take a moment to die,
the step retries for a few seconds (about 5 s in total) before giving up.

- file absent → nothing happens, one log line at most;
- deleted → log line;
- still not deletable after the retries → log line *left behind*, and the
  installation **succeeds** regardless. The file is removed by the
  uninstaller later in any case (the uninstall log is cumulative).

The step never shows a message box and works identically in silent and
interactive runs, per-user and per-machine.

## I4 — What must stay as it is (feature 072)

`PrivilegesRequiredOverridesAllowed=dialog`, `AppId`, the silent operation of
the disclaimer page (`WizardSilent` guard), the `[Run]` entry's
`skipifsilent`, and the defaults of `CloseApplications` / `RestartApplications`
(neither is set in the script; *yes* / *yes*), on which the close and the
restart of the running program depend.
