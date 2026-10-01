# Implementation Plan: FTP anonymous placeholder

**Branch**: `090-ftp-anonymous-default` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

## Summary

One constant and one rule. The default lives in `CConfiguration`'s
constructor (`src/plugins/ftp/ftp3.cpp:508`); the stored value is read in
`CPluginInterface::LoadConfiguration` (`ftp.cpp:512`) and written back in
`SaveConfiguration` (`ftp.cpp:746`). The rule "what does a stored value
become" is a pure function in a header-only file in `src/common`, so it is
unit-tested in `saltests` (the plug-in itself is not reachable from the test
executable).

## Technical Context

**Language**: C++ (MSVC v143) · **Storage**: registry value `Anonymous
Password` of the FTP plug-in (plain text, as before) · **Testing**: saltests;
a source scan for the old placeholder · **Constraints**: no plug-in
configuration version bump is needed (the rule is idempotent: after the
replacement the stored value no longer matches)

## Research

- **R1** — the value is used at `fs2.cpp:430`, `fs5.cpp:782`,
  `operats2.cpp:932`, `dialogs1.cpp:104/108/971`: all through
  `Config.GetAnonymousPasswd`; one place to change.
- **R2** — `example.com` is reserved by RFC 2606 §3 for documentation and
  examples; IANA answers for it and delivers no mail. curl sends
  `ftp@example.com` for anonymous FTP.
- **R3** — the translations and the manual do not contain the old
  placeholder (before the change `grep someserver` found only `ftp3.cpp` and
  `PRIVACY.md`; after it: the recognition constant, its test, and the
  documents that describe the change).
- **R4** — `PRIVACY.md` names the placeholder twice (stored data, network);
  it is updated in the same change (project rule, feature 083).

## Constitution Check

Backward compatibility: a stored user value is never changed; the old
placeholder is not a user value ✅. Release documentation: CHANGELOG and
`PRIVACY.md` in the same change ✅.

## Stages

1. `src/common/salftpanon.h` (constants + rule) and tests.
2. FTP plug-in: default and load.
3. `PRIVACY.md`, CHANGELOG, NEXT-WORK, fix log; gates; independent review;
   commit.
