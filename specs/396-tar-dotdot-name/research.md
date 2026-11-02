# Research - 396-tar-dotdot-name

## R1 Where the wrong result comes from

- Decision: only the `..` branch of `SalTarNormalizeNameU8` is wrong, and only when the dropped
  component is the first one of the output (the walk back reaches the start; `dst++` then keeps
  its first byte). Measured by hand trace and by the GUI probe at `6db68ab0` (fix-log).
- Rationale: with a previous separator the walk stops on it and `dst++` lands right after it - the
  right result; this is why `x/y/../b.txt` was right.
- Alternatives considered: none - the measurement decides.

## R2 Resolve or refuse

- Decision: resolve (`..` removes the previous component, never above the root).
- Rationale: the item's *Expected* names it first; the rule's own comment says so; the AIX case
  (`../../empty` -> `empty`) must stay; refusing would change names that extract right today.
  GNU tar and bsdtar refuse `..` members on extraction by default, but this plug-in has always
  resolved them - keeping the plug-in's behaviour and making it right changes least.
- Alternatives considered: refuse and report like 306 (more change, new failures of archives that
  work today).

## R3 The new `..` branch

- Decision: at a `..` component: if `dst > start`, step back over the trailing `\` the output
  always has at that point (a `..` component starts after a separator in the source, and the
  separator branch writes one `\` unless the output is empty), then walk back while
  `dst > start && dst[-1] != '\\'`. If `dst == start`, nothing. Then `src += 2`.
- Rationale: the result is exactly "drop the last component". Defensive: if the output does not end
  with `\` (cannot happen - see above), the walk still drops the partial last component, never
  reads before `start`.
- Invariant: the output only shrinks at `..`, so it is never longer than the input.

## R4 Callers and their consequences

- `CArchive::ReadArchiveHeader` (member name): a name that now resolves to nothing (`a/..`) takes
  the existing "skip invalid names" branch (395: a regular file is reported, a folder silent) -
  before it was named `a`. A trailing separator still marks a folder.
- `CArchive::ReadArchiveHeader` (link name): normalized only without `..` (309) - unchanged.
- saltests `TarNorm309` callers: pins in `TestTarLink309` (changed) and `TestCpioKeepsGroupMember394`
  (`..` -> `` unchanged).
- No other caller (grep `SalTarNormalizeNameU8`).

## R5 Testing

- saltests: the table of the spec; brute force over all names of up to 6 characters from
  `{a, b, ., /, \}` - names without a `..` component compared with the legacy loop copied into the
  test (must be equal), every name compared with a reference resolver (split into components,
  stack); output length <= input length; terminator written.
- Probe: `dotdot_probe.ps1` (6 rows) before 7 / 5 -> after expected 12 / 0; regression 306, 308,
  309, 395 probes.
