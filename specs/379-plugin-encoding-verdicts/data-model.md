# Data model: the verdict table (`verdicts.md`)

One row per site.

| Field | Meaning |
|---|---|
| # | 255's row number (1-78); new rows 79-82 |
| Site | `plugins/<path>:<line at 3e0da39c>` (the scan's form); a fixed row keeps 255's line at e849e68c |
| Rule | the guard rule that reported it |
| Shipped | `plugins.cfg` value of the plug-in (`on`, `off`) or `shared` |
| Verdict | `false positive`, `real defect`, `fixed` |
| Reason / item | the marker's reason (false positive), the backlog slug (real defect), the feature (fixed) |

Rules:

- a `false positive` row's reason equals the text of its marker after `<rule> - `;
- a `real defect` row's site is reported by the scan after the feature, and its item exists in
  `backlog/items/`;
- the scan after the feature reports exactly the `real defect` rows.
