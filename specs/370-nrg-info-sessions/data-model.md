# Data model - feature 370

- **Session table** (`CISOImage::Session`, `TDirectArray<int>`): one entry a session, the track count the
  image declares (NRG: SINF chunk, an unsigned 32-bit number stored as `int`). Read as `unsigned int`.
- **Track table** (`CISOImage::Tracks`): the image's tracks in order.
- **Walk** (no stored state): session `s` starts at track `first_s` (`first_0 = 0`) and holds
  `n_s = SalIsoSessionTracks(first_s, (unsigned)Session[s], Tracks.Count, fits)` tracks;
  `first_{s+1} = first_s + n_s`. Tracks `first_{Count} .. Tracks.Count - 1` belong to no session.

## Output (image information text)

```text
Information on image "<label>"

Number of sessions: <Session.Count>
Session <s+1>
  Number of tracks: <n_s>
  Track: <t+1>, <type>, Size: <k> KBytes [- "<label>"]
    <file system details>
...
                                   (only when tracks are left:)
Tracks not in any session
  Track: <t+1>, ...
```
