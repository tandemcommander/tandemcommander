# Contract: SalIsValidFileNameComponent / SalMakeValidFileNameComponent (feature 222)

Interface version unchanged (107); the methods' signatures unchanged; their meaning follows the
interface 104 promise (`spl_com.h`: a name component may have up to 3 * 255 bytes of UTF-8).

- `SalIsValidFileNameComponent(name)`: too long is now **more than 255 UTF-16 units** (a Windows
  file system's limit). Before: more than `MAX_PATH - 4` BYTES - a valid name of 86+ CJK or 128+
  Cyrillic letters was "invalid". A valid name may now have up to 765 bytes.
- `SalMakeValidFileNameComponent(name)`: shortens at a whole character to 255 UTF-16 units **and**
  `MAX_PATH - 4` bytes. The buffer contract stays: at most `MAX_PATH` bytes of the buffer are used.
  So a name valid by the first service may still be shortened by the second (a caller that wants a
  long valid name kept calls the first one and the second only when it says invalid).
- `CSalamanderDirectoryAbstract::AddFile` with a path: a file name over 255 bytes is accepted when
  it has at most 255 UTF-16 units; `AddDir` keeps 255 bytes; a path part over `MAX_PATH - 5` bytes is
  still refused. `AddFile` / `AddDir` with a NULL path (file-system plug-ins) never checked a length.
