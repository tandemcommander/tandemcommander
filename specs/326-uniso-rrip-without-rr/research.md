# Research - 326-uniso-rrip-without-rr

## R1 How does an RRIP 1.12 volume announce itself?

- **Decision**: by the SUSP `SP` entry at byte 0 of the System Use area of the root directory's
  first record (`.`): `'S' 'P'`, length 7, version 1, check bytes `BE EF`, then LEN_SKP (1 byte).
- **Rationale**: SUSP 1.12 makes `SP` mandatory for any volume that uses System Use entries and
  places it exactly there; `NM` is defined only by RRIP. Measured on xorriso 1.5.6 images
  (`rr.iso`, `rrlong.iso`, `-compliance old_rr`): `SP(len 7 v1 be ef 00)` present; the `ER`
  `RRIP_1991A` lies in the root's continuation area. The Linux kernel (`fs/isofs/rock.c`) enables
  Rock Ridge on the `SP` of the root's `.` record and does not require `ER`.
- **Alternatives considered**:
  - require `ER` with an RRIP identifier: needs following the root's `CE`; refuses volumes whose
    `ER` is missing although they carry `NM`; rejected (more reads, no gain for names).
  - per record, read `NM` whenever any SUSP-looking entry exists (no volume check): a non-SUSP
    System Use area (CD-XA's 14-byte record, Apple extensions) could be misparsed; rejected.

## R2 LEN_SKP

- **Decision**: honoured only when `SP` was found: each record's entry parsing starts LEN_SKP bytes
  into its System Use area; continuation areas are not skipped (SUSP 1.12 5.3). An area too short
  for an entry after the skip gives the plain name.
- **Rationale**: the standard; LEN_SKP is 0 in every image measured, so it changes nothing there.

## R3 Records starting with `RR`

- **Decision**: unchanged: a record whose first entry (byte 0 of its System Use area) is `RR` is read
  as Rock Ridge with parsing from byte 0, on every volume; checked before the `SP` rule.
- **Rationale**: FR-003; genisoimage images (feature 223's probe) keep the exact path they took.

## R4 Where to read the root record

- **Decision**: in `CISO9660::Open`, after the root record is filled from the PVD (not for Joliet):
  read the first sector of the root extent (the block `ListDirectoryRe` reads first) and pass the
  first record to the rule. A failed read or a record that does not fit: no SUSP (silent - the
  listing reports read errors as today).
- **Rationale**: one read per open; `CUDFISO` and multi-session sessions open `CISO9660` through
  the same `Open`.

## R5 Proof without genisoimage

- **Decision**: the probe patches a copy of xorriso's `rr.iso`: the root's `SP` check bytes are
  broken (no SUSP on the volume) and `top.txt`'s first entry `PX` is renamed `RR`. Expected:
  `top.txt` by the `RR` path, `FOLDER` (no `RR`, no `SP`) - FR-003 and FR-004 in one image.
- **Rationale**: Docker (genisoimage) is not running on this machine; the patch reproduces the
  only property of a genisoimage image that matters here (a first entry `RR`).
