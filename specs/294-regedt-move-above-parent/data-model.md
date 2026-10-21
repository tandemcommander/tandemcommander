# Data model - feature 294

- **Key identity** (feature 292): the full internal name the registry reports for an opened key,
  e.g. `\REGISTRY\USER\<SID>\Software\TcProbe294\Zdroj\Klic\Klic`. A key path has a set of
  identities (`CSalRegKeyIds`, at most 2 used: HKCR paths held by both halves).
- **Path below** (new): for a source identity `s` lying strictly inside a target identity `t`
  (`t` a case-ignored prefix of `s` followed by `\`), the remainder of `s` after that `\`, e.g.
  `Klic` for `s = ...\Zdroj\Klic\Klic`, `t = ...\Zdroj\Klic`. Never empty; NULL when `s` is `t`,
  is not inside `t`, or either is empty.
- **Decision per selected key** (in `CopyOrMoveFromFS`, before `CopyOrMoveKey`):

| Condition | Result |
|---|---|
| target inside the source or equal (text or identity; 292) | refused "into itself" (unchanged) |
| some pair: source strictly inside target, and `source\below` exists | refused "into itself" (new) |
| some pair: source strictly inside target, open of `source\below` fails otherwise | open-error box; Retry repeats, Skip skips the key, Cancel stops |
| otherwise | copied / moved as before |
