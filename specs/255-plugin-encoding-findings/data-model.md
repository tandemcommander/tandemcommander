# Data model: 255

## Verdict table (`verdicts.md`)

One row per finding of `check_encoding.py --plugins` at e849e68c (78 rows).

| Field | Meaning |
|---|---|
| # | 1..78, in the scan's order |
| Site | `plugins/<plugin>/<file>:<line at e849e68c>` |
| Rule | the guard's rule id |
| Shipped | `on` / `off` per `plugins.cfg` |
| Verdict | `false positive` or `real defect` |
| Reason / item | for a false positive: the reason (the same text as the marker); for a real defect: the backlog item slug |

Rules:
- every row has exactly one verdict;
- a `false positive` row's site carries a marker for the same rule;
- a `real defect` row's site carries no marker and is reported by the scan after the feature;
- the count of `real defect` rows = the scan's TOTAL after the feature.
