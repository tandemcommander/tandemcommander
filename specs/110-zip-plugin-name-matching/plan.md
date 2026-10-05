# Implementation Plan: the ZIP plug-in replaces only the member that has the added file's name (feature 110)

**Branch**: `110-zip-plugin-name-matching` (from `109-disk-cache-archive-key`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md) | **Contract**: [contracts/zip-member-identity.md](contracts/zip-member-identity.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre110`, binaries only). Every member-name comparison of the ZIP plug-in listed and classified (`research.md` 1). The old comparison's collision set computed (`probe/zip_collision_set.py`: linguistic `CompareStringA` on UTF-8 bytes, not the core's byte fold). `probe/zipname_probe.ps1` (+ `zipfix.py`, own ZIP writer/reader: UTF-8, OEM, raw-byte and Unix members) on the build before - every route x pair kind: F5 into the archive, F8, F5 out, F4 pack-back incl. the 108 review's `split_zip` |
| S1 rule | `src/common/salzipname.h` (header-only, pure): `SalZipNameEqual`, `SalZipNamePrefix` (covered bytes counted on the path), `SalZipMemberIs`, `SalZipMemberIsOrIsIn`; WTF-8 = the core's decoder; valid WTF-8 by `CompareStringOrdinal`, legacy text by the old `CompareStringA`, never equal across |
| S2 ZIP | `add.cpp CZipPack::MatchFiles`: the two comparisons and the Move folder test through the rule, no byte-length guard; the Unix branch copies the member's spelling from the covered folder length and grows the buffer; (review SF1) `CAddInfo::Replaced` - after a *Yes*, a later *Skip* keeps only that member instead of cancelling the add. `del.cpp CountFilesInRoot`: the selection's folder test (`Unix ? memcmp : MemICmp`, length checked) |
| S3 tests | saltests `TestZipName110`: pair tables, the 7 different-length pairs, every printable ASCII pair against the old comparison, legacy text, heap-size names, prefixes, the matching helpers, brute-force parity with 092's helpers, real NTFS agreement |
| S4 probe | `probe/zipname_probe.ps1` on both builds (hidden desktop); regressions 108 namecoll (incl. `hL1_zip`, `hL2_zip`), 106 packself, 094 ZIP passwords, 096 archedit; full Release build; records |

No plug-in interface change (107), no configuration change, no new string.
