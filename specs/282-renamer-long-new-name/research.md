# Research: 282

## R1 - How large is "any length the file system accepts"?

- Decision: `REN_MAX_NAME = SAL_MAX_PATH_UTF8` (3 x 32,767 + 1 bytes, `spl_base.h`).
- Rationale: Windows paths (with the `\\?\` form the plug-in's W calls use, `SplU8ToWExtAlloc`)
  reach 32,767 UTF-16 units; a unit is at most 3 bytes of UTF-8 (WTF-8: a lone surrogate is 3
  bytes, a pair 4 bytes for 2 units). Every path the file system accepts fits; a longer built name
  cannot be a valid path and is refused as before ("Expanded string is too large.").
- Alternatives: exact sizing per item (two passes of the var-string expansion - more change, same
  result); `SAL_MAX_PATH_W` UTF-16 units counted at the end (the builders work in bytes).

## R2 - Where the storage lives

- Decision: one heap buffer per `BuildScript` call and per preview window; `Rename`'s substitution
  temporary is a heap buffer per call.
- Rationale: 98 KB on the stack of the dialog thread (1 MB default) is not acceptable; per-call
  allocation in `Rename` costs one malloc per item and keeps the class free of state shared between
  the preview's and the script's instances.

## R3 - Recursion of "Include subdirectories" without the 260-byte limit

- Finding: `LoadSubdir` recurses per folder level; its frame held `WIN32_FIND_DATAW` (592 bytes)
  and `char fileName[780]`. The 260-byte path bounded the depth to ~130 levels; a 32,767-unit path
  allows ~16,000 ("a\a\a..."), far past a 1 MB stack.
- Decision: the find data and the converted name on the heap (a frame of ~200 bytes) and a depth
  guard: a folder deeper than 1024 levels below the selected item is refused with the existing
  "Unable to read directory because of too long path name" (Skip / Skip all / Cancel as for a long
  path). 1024 x ~0.3 KB stays well inside the stack also with the message pumping done inside.
- Alternatives: an iterative walk (a larger rewrite of a function with ESC / message handling); a
  larger thread stack (still bounded only by chance).

## R4 - The preview's texts

- Finding: `TextBufferW[3 * MAX_PATH]` - a longer text failed both conversions and showed empty;
  `TextBuffer[MAX_PATH]` + `lstrcpyn` cut the path column at a byte (a piece of a letter, then shown
  through `CP_ACP`).
- Decision: growing buffers sized from the text. The list view may still clip what it paints - that
  is the control's display, not a cut name.

## R5 - What stays out

- `Root[MAX_PATH]` (the panel folder): refused before the dialog (207) - a separate limit.
- The pattern fields (`NewName` / `SearchFor` 2 x MAX_PATH, `ReplaceWith` MAX_PATH): the field
  refuses a longer pattern (winliblt `EditLine`, measured); an Inbox item.
- No pure rule worth a `src/common` header: the change is buffer sizes and one constant; the
  behaviour is proven by the GUI probe.
