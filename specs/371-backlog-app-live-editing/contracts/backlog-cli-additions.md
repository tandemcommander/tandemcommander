# Backlog CLI additions - 371 (`tools/backlog/backlog.py`)

Amends `specs/344-backlog-web-app/contracts/backlog-cli-additions.md`. Backward compatible.

## `next --except <slug>`

```text
backlog.py [--ref main] [--json] next [--slug SLUG] [--except SLUG]
```

`--except` leaves one item out of the answer as if it were not in *Next*: it is neither chosen
nor listed in `skipped`. The app uses it while a run holds the run lock: on `main` the running
item is still an `open` row of *Next*, and "next up" must name the item the next run would take
after it. With `--slug` the option is refused (`--except is for the search without --slug`).

Unknown slug: accepted (nothing to leave out).

## Tests (`tools/backlog/test_backlog.py`)

- `next --except` of the first eligible item names the second and lists the rows above the second
  (without the excepted one) in `skipped`;
- `--except` with `--slug` is refused;
- an unknown `--except` slug changes nothing.
