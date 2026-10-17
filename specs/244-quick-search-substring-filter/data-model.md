# Data Model: Quick search that finds text anywhere in a name and filters the panel

Feature 244. All state is per panel (`CFilesWindow`), in memory, never stored
except the one configuration value.

## Configuration

| Field | Type | Default | Stored | Meaning |
|-------|------|---------|--------|---------|
| `CConfiguration::QuickSearchFilter` | `BOOL` | `TRUE` | `HKCU\Software\Tandem Commander\0.1\Configuration`, value `Quick Search Filter` (DWORD); absent = `TRUE` | On: substring matching, filtered view, tint, the search ends only at the R2 points. Off: the 0.1.10 quick search. Read when a search starts. |

## Search state (existing fields, new meaning in the new mode)

| Field | Existing | In the new mode |
|-------|----------|-----------------|
| `QuickSearchMode` | quick search on | the search runs: text not empty, the filter is applied; survives `CancelUI` |
| `QuickSearchMask[3*MAX_PATH]` | typed text in UTF-8, wildcards kept | unchanged: the *search text* |
| `QuickSearch[3*MAX_PATH]` | the matched prefix of the focused name | the matched part `name[matchStart..matchEnd)` of the focused name (used by Left) |
| `QuickSearchPendingSurrogate` | high surrogate waiting | unchanged |

## Filtered view (new fields)

| Field | Type | Meaning |
|-------|------|---------|
| `QFActive` | `BOOL` | the visible arrays are installed (`QuickSearchMode` in the new mode) |
| `QFFullDirs`, `QFFullFiles` | `CFilesArray*` | the panel's full listing as it was before filtering, with its original ownership (`SetDeleteData` as `ReadDirectory` set it) |
| `QFDirMap`, `QFFileMap` | `TDirectArray<int>` | visible index → full index, ascending (order kept, FR-007) |
| `QFKinds` | `TDirectArray<BYTE>` | per visible item: `SALQF_PREFIX` / `SALQF_SUBSTRING` (focus rule input) |
| `QFTotalCount` | `int` | items of the full listing without `..` (the "of N" of FR-026) |
| `QFTintBk` | `COLORREF` | the tint (R7); recomputed on `ColorsChanged` |
| `QFTintBrush` | `HBRUSH` | per-panel brush of `QFTintBk`; destroyed with the filter |

While `QFActive`: `Dirs`/`Files` point to the **visible arrays**, which own
nothing (`SetDeleteData(FALSE)`), hold whole-struct copies of the matching
full items in the full order, and never contain `..`.

### Invariants

- I1 `Dirs->Count == QFDirMap.Count`, `Files->Count == QFFileMap.Count`; maps strictly ascending, each value < the full array's count.
- I2 Before a rebuild, a suspend or the end: `full[map[i]] = visible[i]` for every `i` (whole-struct write-back, R1). After it no visible copy is used.
- I3 `SelectedCount` == number of `Selected` items in the visible arrays (the debug check in `GetSelCount`).
- I4 Every swap of the arrays runs inside icon-reader sleep and invalidates both `CVisibleItemsArray`s (R4).
- I5 At least one visible item exists while `QFActive` (a character that would leave none is refused, FR-005; a refresh leaving none ends the search).
- I6 Nothing in the full arrays changes because of filtering; their order is the current sort, and a sort change sorts the full arrays and rebuilds the visible ones.

## State transitions

```text
            printable char (option on, ≥1 match)
  Idle ───────────────────────────────────────────► Searching
   ▲                                                   │  char (narrows, incremental)
   │                                                   │  Backspace / Left (widens, from full)
   │                                                   │  Right (extends by the focused name)
   │                                                   │  refresh → suspend → re-list → resume
   │                                                   │  sort change → sort full → rebuild
   │                                                   │  colours changed → new tint
   │                                                   │  CancelUI / focus loss / menu / dialog /
   │                                                   │  scroll / click / app deactivation → stays
   │   EndQuickFilter():                               │
   └─── Esc · Backspace of the last character ◄────────┘
        · path change (before history is recorded) · tab switch
        · other panel activated · refresh failed · refresh left no match
        · NextFocusName not a match · option switched off · panel destroyed
```

`EndQuickFilter()`: write back (I2) → sleep icon reader → free the visible
arrays and maps → `Dirs`/`Files` = full arrays → map the focus to its full
index → recount `SelectedCount` → invalidate visible-items arrays → wake →
destroy caret and tint brush → repaint list box and directory line → post
`WM_USER_SELCHANGED`.

## Matching result (pure rule, `salquickfilter.h`)

| Field | Meaning |
|-------|---------|
| `Kind` | `SALQF_NONE`, `SALQF_SUBSTRING`, `SALQF_PREFIX` |
| `MatchStart` | byte offset where the first literal segment matched (0 for a prefix) |
| `MatchEnd` | byte offset after the last literal segment (= today's `offset`) |

Rule: prefix exactly as `AgreeQSMaskU8` today (`wholeString = FALSE`, the
trailing-dot tolerance included); otherwise the leftmost substring match =
the same algorithm with an implicit leading wildcard. `..` is never matched.
