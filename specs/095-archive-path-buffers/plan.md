# Implementation Plan: archive path buffers

**Branch**: `095-archive-path-buffers` (from `094-plugin-password-encoding`) | **Spec**: [spec.md](spec.md)

## Summary

Four functions build a disk-cache name from the panel's archive path with an
unbounded `StrICpy` (+ `strcat` / `sprintf`) into stack buffers of 260-830
bytes, while the archive path can be up to `SAL_MAX_PATH_UTF8` bytes. Replace
the buffers on that path with storage of sufficient size and bounded
operations; where a consumer has a real limit, take the existing
"name too long" outcome.

## Technical Context

C++ (MSVC v143), core only: `src/fileswn2.cpp` (`PrepareCloseCurrentPath`),
`src/fileswn5.cpp` (view/edit from the panel), `src/fileswn6.cpp`
(`ExecuteFromArchive`), `src/fileswn9.cpp` (`OfferArchiveUpdateIfNeeded`),
possibly `src/cache.*` if the cache has its own name limit. The cache name is
the byte-folded archive path (feature 092 left the fold alone on purpose: the
key and the comparison in `PrepareCloseCurrentPath` must agree) - **the
content of the names must not change**, only where they are stored.
A pure helper (bounded lower-casing copy / name builder) goes to
`src/common` with saltests if one is needed.

## Constitution Check

Backward compatibility: no behaviour change for values that fit. Incremental:
one bounded change. Gate passes.

## Stages

| Stage | Content | Evidence |
|---|---|---|
| S1 | inventory of every fixed buffer in the four functions fed by the archive path / inner path / name; the fix; saltests for any pure helper | probe on the hidden desktop: deep folders of ~300/600/1000 bytes, view, edit, leave; fixed and previous build; independent review |
| S2 | gates and records | builds, saltests, guard, CHANGELOG, NEXT-WORK, CLAUDE.md |
