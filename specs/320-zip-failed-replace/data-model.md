# Data model - 320-zip-failed-replace

- **Archive** (`CZipPack::ZipName`, UTF-8/WTF-8; `ZipAttr` its attributes at the start): the
  user's existing ZIP file. Closed (`ZipFile = NULL`) before the replace.
- **Temporary working file** (`CZipPack::TempName`, `TempFile`): `Sal*.tmp` next to the archive,
  holding the complete updated archive; closed before the replace.

State at the end of a temporary-copy operation without error:

```text
replace -> srrDone           : archive = updated, temp gone
        -> srrFailedKept     : archive = as before, temp deleted by the plug-in
        -> srrLeftAtTemp     : archive gone, temp kept (only copy) and named
        -> srrFailedBothGone : both gone (third party), error shown
```
