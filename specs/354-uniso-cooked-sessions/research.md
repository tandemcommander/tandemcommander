# Research - 354-uniso-cooked-sessions

## R1. How common is a rest past the ISO 9660 volume in a one-volume cooked image?

- Decision: measured (probe scripts `probe/measure_tails.sh`, `probe/measure2.sh`, WSL Ubuntu,
  genisoimage 1.1.11 from 334's `~/tc-genisoimage`, xorriso 1.5.6 fetched without root into
  `~/tc-xorriso`). Results in the spec's *Background* table: every `mkisofs`-style tool counts its
  padding inside the volume (rest 0); xorriso's native mode leaves 168 zero sectors outside; an appended
  partition leaves its data outside (1590 sectors for 2880 KiB). No real `.iso` exists on the machine.
- Rationale: the item's *Notes* ask for this before the rule is chosen.
- Alternatives: none - a measurement.

## R2. The rule

- Decision: mark when the rest past the volume is more than 16 whole sectors and holds any non-zero
  byte; a zero-only rest up to 512 sectors is not marked; a longer rest is marked unread.
- Rationale: a later volume's descriptors at its sector 16 are not zero, so a zero rest holds no
  volume - and no data, so deleting it loses nothing; xorriso's native images stay deleted as today.
  The cap bounds what opening an image reads (it is opened for every listing).
- Alternatives considered: (a) the item's rule as written, more than 16 sectors marks - every
  xorriso-native image would be kept (measured 168 zero sectors) without any data at stake; (b) search
  the rest for a `CD001` / `BEA01` descriptor - would delete an appended partition's data and a later
  session whose descriptor is damaged; does not fail closed. Rejected both.

## R3. The cap

- Decision: 512 sectors (1 MiB), read in 64 KiB pieces.
- Rationale: covers xorriso's 300 KiB padding with alignment (168 measured) and isohybrid's alignment
  of the file to 1 MiB (at most 511 sectors); a real multi-session disc's gap between sessions (lead-out
  + lead-in, thousands of sectors) is longer and marks unread.
- Alternatives: 1024 / no cap - more read per open with no measured image needing it.

## R4. Which images

- Decision: only a file the plain detection opens with `CheckForISO` at the cooked layout (no sync at
  sector 0, 2048-byte sectors from offset 0) whose sector 16 is an ISO 9660 primary descriptor
  (`IsValidCDHeader`: type 1, `CD001`); a UDF-only image (`BEA01` at sector 16) unchanged; the raw rule
  of 353 unchanged; images with a track table and the other plain formats unchanged.
- Rationale: the item names cooked `.iso` / `.img`; the cases it does not name keep their behaviour.

## R5. Inputs that cannot be read

- Decision: the descriptor's size not readable (`SalIsoPvdVolumeSectors` false), the file shorter than
  the volume, a read of the rest that returns fewer bytes than asked - mark.
- Rationale: CLAUDE.md "a safe to delete? check fails closed"; feature 353's review 1 (a size claiming
  more than the file hides the later session).
