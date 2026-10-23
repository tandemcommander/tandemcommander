# Contract note - the name bound of the panel listing (feature 307)

Interface: `CSalamanderDirectoryAbstract::AddFile` / `AddDir` (`src/plugins/shared/spl_com.h`,
unchanged). They "return success"; on failure the caller frees the entry's data.

Behaviour since feature 307 (no header change, no interface version change):

- An entry added with **no folder part** (`path == NULL`, what file-system plug-ins always pass)
  is refused when its name is **780 bytes (`SAL_FIND_NAME_U8`) or longer**. Before, it was
  accepted and overflowed the panel's fixed name buffers when shown (a crash; in a release build
  stack corruption). Every shorter name is accepted as before, also over 255 UTF-16 units.
- An entry added **with a folder part** keeps the feature-222 rule unchanged.

Plug-ins written against older interfaces keep loading; they see `FALSE` only for names that
crashed the program before.
