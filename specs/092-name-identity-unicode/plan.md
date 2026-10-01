# Implementation Plan: name identity (encoding cluster B-2)

**Branch**: `092-name-identity-unicode` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Summary

New helpers in `src/common/salunicode.{h,cpp}` implement the file system's
identity rule (`CompareStringOrdinal(…, TRUE)` on UTF-16, ASCII fast path,
legacy byte fold for text that is not valid WTF-8). Core-internal call sites
that decide identity move to them, stage by stage; nothing exported to
plug-ins and nothing in `src/common/str.cpp` changes.

## Technical Context

**Language/Version**: C++ (MSVC v143), WinAPI
**Storage**: none (every affected structure is rebuilt in memory)
**Testing**: `saltests` (the helpers are in `src/common`); an evidence probe compiling verbatim pre-/post-fix bodies (the 075 pattern) for sites not reachable from `saltests`; GUI probes with feature 088's drivers (the focused file is observable through the viewer's title); a timing probe
**Constraints**: plug-in ABI frozen (`spl_gen.h` exports of `StrICmp`, tables, `IsTheSamePath`…); sort order untouched; each sorted pair moves atomically
**Scale/Scope**: about 125 core lines take names or paths (research §2.3); this feature converts them in five stages and records what stays

## Constitution Check

| Principle | Status |
|---|---|
| II. Backward compatibility | ASCII results identical; no stored data changes; exported services untouched ✅ |
| III. Incremental modernization | one stage per commit, each independently reviewed; sorted pairs move as pairs ✅ |
| V. Plug-in architecture | no `src/plugins/shared/` change ✅ |
| Release documentation | CHANGELOG *Unreleased*; `PRIVACY.md` unaffected ✅ |

## Design (contract: [contracts/name-identity.md](contracts/name-identity.md))

```
int  SalNameCompareOrdinalCI(const char* a, int aLen, const char* b, int bLen);
BOOL SalNameEqualOrdinalCI(const char* a, int aLen, const char* b, int bLen);
BOOL SalPathEqualOrdinalCI(const char* p1, const char* p2);
BOOL SalPathHasPrefixOrdinalCI(const char* path, const char* prefix, int prefixLen, int* pathBytes);
```

1. both ASCII → byte loop, fold to **upper** case (so the three-way order is
   the same order `CompareStringOrdinal` gives; equality is unaffected by the
   direction of the fold);
2. both valid WTF-8 → UTF-16 in stack buffers (heap only for long strings),
   `CompareStringOrdinal(…, TRUE)`;
3. otherwise → the legacy byte fold (`CharUpperA`-table semantics computed
   locally — the helper must not depend on `str.cpp`, which `saltests` does
   not link; the core passes the same answer `StrICmpEx` gave).

Step 3 needs the legacy tables. `salunicode.cpp` builds its own 256-entry
lower-case table lazily with `CharLowerBuffA` — the same construction as
`InitializeCase` in `str.cpp` — so results for non-UTF-8 text are identical
and `saltests` can link it.

## Stages (one commit each; independent review before each commit)

| Stage | Content | Gate |
|---|---|---|
| **S0** | guard: narrow `acp-byte-table-on-name` by the drive-letter shape, annotate the 4 intentional sites, make it strict; add a rule that flags the old comparison on a name in converted files, proven to fire | `check_encoding.py` strict 0; planted defect fails |
| **S1** | helpers + `saltests` (research §7.2 items 1–9) | saltests |
| **S2** | panel look-up of one name (FR-004) | saltests, GUI probe (focus), review |
| **S3** | "only a change of case", target-is-source (FR-005) | evidence probe, review |
| **S4** | core path identity and prefix (FR-006) | saltests for the helpers, evidence probe, review |
| **S5** | sorted pairs: `CNames`, `CDirectorySizes`, `ContainsString`, disk-cache keys (FR-007) | property tests, review |
| **S6** | timing (SC-005), full gates, records | all probes of 087–089, Debug + Release |

A stage whose review finds the conversion unsafe is cut back to what is
proven and the rest is recorded as deferred — the 069 rule (*"a half-moved
chain is worse than an unmoved one"*).

## Deferred by design (FR-008)

`CSalamanderDirectory` name comparison; the exported `StrICmp` family and
`IsTheSamePath` / `HasTheSameRootPath` bodies; the sort comparator (including
its intransitivity with *Use locale* off, research §0.4, a new backlog item);
Compare Directories' linguistic pairing; association and packer extension
look-ups; mask hash; `AlterFileName` / *Change Case* (cluster B-4); the shell
extension pair; Find's type-ahead (cluster B-1).

## Complexity Tracking

None.
