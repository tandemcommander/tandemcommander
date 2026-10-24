# Data model - 340-nrg-session-count

## Session count

- Source: one NRG SINF chunk (big-endian DWORD), stored by `readSINF` in `CISOImage::Session`
  (`TDirectArray<int>`, unchanged).
- Read by the listing as `unsigned int`.

## SalIsoSessionTracks(first, declared, trackCount, fits) -> int

| Input | Meaning |
|---|---|
| `first` | the track the session starts at (where the previous session ended) |
| `declared` | the session's count from the image, unsigned 32-bit |
| `trackCount` | the tracks of the image's track table |

| Output | Rule |
|---|---|
| return | `min(declared, left)`, `left` = `trackCount - first` when `0 <= first < trackCount`, else 0 |
| `fits` | `declared <= left` |

Validation: the return is in `[0, left]`; `first + return <= trackCount`; `fits` false means the listing
is marked incomplete.
