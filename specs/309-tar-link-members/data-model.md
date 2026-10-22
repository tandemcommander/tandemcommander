# Data model - 309-tar-link-members

## SCommonHeader (tar.h) - added fields

| Field | Meaning |
|---|---|
| `LinkType` | `0` (not a link), `LNKTYPE` ('1', hard link) or `SYMTYPE` ('2', symbolic link) |
| `LinkName` | malloc'd UTF-8: the name the link refers to, decoded and normalized like `Name`; NULL when none |

Both are reset by `Initialize()`. A link member stays `Ignored` (listing, devices unchanged).

## SalPaxValues (salpaxheader.h) - added fields

| Field | Meaning |
|---|---|
| `LinkPathState` | `SAL_PAX_UNSET` / `SAL_PAX_DELETED` / `SAL_PAX_SET` |
| `LinkPath` | malloc'd value of `linkpath` (a NUL inside refuses the header, as for `path`) |

`SalPaxEffectiveLinkPath(global, member)` - the member's value, else the global one, NULL = the GNU /
ustar link name stays.

## Decision (saltarlink.h)

`SalTarLinkDecide(linkType, targetWritten)`:

| linkType | targetWritten | Result |
|---|---|---|
| hard link | true | `SAL_TAR_LINK_COPY` |
| hard link | false | `SAL_TAR_LINK_REPORT_MISSING` (`ERROR_FILE_NOT_FOUND`) |
| symbolic link | any | `SAL_TAR_LINK_REPORT_UNSUPPORTED` (`ERROR_NOT_SUPPORTED`) |
| other | any | `SAL_TAR_LINK_NONE` |

## Written-member set (DoUnpackArchive, per operation)

Normalized archive names of files written in this operation (created and closed, not skipped) and of
reproduced hard links. Folders are not recorded.
