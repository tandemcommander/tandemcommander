# Fix log: 222 - a name is as long as a Windows file system allows (255 UTF-16 units), not 255 bytes

Backlog (`specs/NEXT-WORK.md`): "the core's `SalMakeValidFileNameComponent` cuts at byte 256" (137);
found by 215: `SalIsValidFileNameComponent` takes a name of more than 256 BYTES for invalid.

## Measured (before)

Probe `probe/editname222_probe.ps1` (`probe/result_before.txt` - the final probe on the build
without the fix, `src` stashed; 5 / 3):
- **LONG / F5LONG: a ZIP whose member is 90 CJK letters + `.txt` (274 bytes, 94 UTF-16 units - a
  valid Windows name) cannot be opened at all: "Cannot add file to the list."** -
  `CSalamanderDirectory::AddFile` (`src/zip.cpp`) refused a name over 255 BYTES (although interface
  104 says the cap is gone) and the ZIP plug-in ended the whole listing;
- CTL (`short.txt`), BAD (`bad.txt.` - a trailing dot: refused as invalid) as expected.

Read (two audits): the same 255-byte rule made `SalIsValidFileNameComponent` refuse such names
(F4 of an archive member: "invalid on Windows file systems"); `SalMakeValidFileNameComponent` cut
at byte 256 inside a letter; F3's copy of an invalid name was cut by `lstrcpyn`; the ZIP plug-in
ended the listing for a refused item whose path part had 256-259 bytes.

## Work

- `src/common/salmaskname.h` `SalNamePrefixBytesU8` (saltests `TestNamePrefixBytes222`, 11 checks):
  a name's whole-character prefix within UTF-16 units and bytes;
- `src/salamdr5.cpp`: `SalIsValidFileNameComponent` - over 255 UTF-16 units is too long (not 256
  bytes); `SalMakeValidFileNameComponent` - shortened at a whole character to 255 units AND
  `MAX_PATH - 4` bytes (its buffer contract - see `contracts/`);
- `src/zip.cpp` `CSalamanderDirectory::AddFile`: a FILE name over 255 bytes is taken when it has at
  most 255 UTF-16 units (and fewer than `SAL_FIND_NAME_U8` bytes); a FOLDER keeps 255 bytes (review:
  its contents' path part is limited to `MAX_PATH - 5` - a longer folder would be listed but never
  filled; a partial listing, a delete of members never shown); the path part keeps `MAX_PATH - 5`;
- `src/fileswn5.cpp` F3: the invalid name's copy at a whole character;
- `src/plugins/zip/list.cpp`: an item refused for its length is skipped with "Some directories or
  files may be missing" and the listing goes on;
- `src/plugins/uniso/isoimage.cpp`, `udf.cpp`: the path buffers the file systems append a name to
  hold a name of up to 3 * MAX_PATH bytes (the audit: they would overflow once the core takes long
  names);
- `src/plugins/shared/spl_gen.h`: the two services' description (`contracts/name-validity.md`).

Build: BUILD SUCCEEDED; saltests 22,454 / 0.

## Measured (after)

`probe/result_after.txt` 10 / 0 (the final build): LONG - the archive opens; F4 is refused by the
disk cache ("resulting filename is too long" - its folder + the name over `MAX_PATH`: safe, a
limit); F5LONG - extracted under the whole name; DIRLONG (a folder of 90 CJK letters next to
`keep.txt`; not run on the build before) - the folder skipped with the message, `keep.txt`
extracted; BAD refused as before. Regression: 204's probe 22 / 0 (`probe/regress_204.txt`).

## Review

Refute-first review: the core change holds - no route of the core or a built plug-in overflows or
acts on a cut name of 256-765 bytes (view, edit, extract, drag, clipboard, packers, the disk-tree
builder - better: one long disk name no longer failed the whole build). MUST taken: uniso would
have opened an image with a long FOLDER name as a partial listing - folders keep the 255-byte limit
(also fixes the empty-but-enterable folder of 256-258 bytes). SHOULD taken: the contract note; the
ZIP plug-in's test for a name too long (not every failure). Recorded in `specs/NEXT-WORK.md`:
the disk cache's folder limits F3 / F4 of long names; folders over 255 bytes in archives;
uniso `hfs.cpp:263-310` (`wchar_t fileNameW[256]` filled to a length read from the image - a
crafted image overflows the stack), `iso9660.cpp:197` (`strncat` with a Rock Ridge length under 5),
Joliet names cut at their byte length (`iso9660.cpp:217`); tar `gzip/gunzip.cpp:1076` (the gzip
name cut at 259 bytes and extracted under it); the User Menu (`mainwnd4.cpp:411-433`) and Compare
Directories (`mainwnd5.cpp:1560/1584`) cut disk names at MAX_PATH and act on them;
`fileswna.cpp:396` cuts `SrcPath`.
