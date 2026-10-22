# Contract - the case-only lookup (internal to the FTP plug-in, not a plug-in interface)

## `SalFtpFindCaseOnlyName` (`src/common/salftpupname.h`, header-only)

```text
template <class GetName> int SalFtpFindCaseOnlyName(int count, GetName getName, const char* name)
```

- `getName(i)` returns the i-th listed name (UTF-8 / WTF-8 bytes, NUL-terminated) or NULL (skipped).
- Returns the lowest index `i` whose name is **not byte-equal** to `name` and **is the same name**
  under `SalNameOrderEqualCI` (feature 092's rule); `-1` when there is none, when `name` is NULL or
  `count <= 0`.
- Each name is looked at once; nothing is allocated except what `SalNameOrderEqualCI` needs for a
  non-ASCII tail over 519 bytes.

## `GetListing(..., name, existingItem, nameExists, caseOnlyCounts)`

- Unchanged for `caseOnlyCounts = FALSE`.
- `caseOnlyCounts = TRUE`, listing ready, `FindItem(name)` fails: `SalFtpFindCaseOnlyName` over the
  listing; found -> `*nameExists = TRUE`, `*existingItem` = a copy of that item with
  `ByteSize = UPLOADSIZE_UNKNOWN`.
- Callers with TRUE: `operatsb.cpp` `fwssWorkStartWork` (file), `fwssWorkUploadGetFileSizeFromListing`,
  `fwssWorkUploadGenNewName`. With FALSE: `operatsa.cpp` `fwssWorkStartWork` (folder),
  `fwssWorkUploadAutorenDirSendMKD`.
