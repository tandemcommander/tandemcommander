# Research - 280-user-menu-long-paths

## R1 - Work or refuse on the enumeration routes

- **Decision**: refuse ("too long name") for an item whose folder or folder + name does not fit
  259 bytes - from the whole values.
- **Rationale**: the item's folder becomes the launched program's current folder (direct route:
  `lpDirectory`; batch: cmd's start folder and `cd /d`), limited to MAX_PATH; the expansion
  (`ExpandCommand2`: `fileName`, `dosName`, `initDir`) is MAX_PATH-bound. Making it "work" would
  only move the refusal into the launch for most items. The behaviour users see is today's
  refusal; what changes is that no cut text exists any more.
- **Alternatives**: heap buffers through the whole expansion (`fileName`, the variables, the 8.3
  name of a long path) - rejected: larger, and the current-folder limit stays.

## R2 - "Before anything runs" on the route without a shell

- **Decision**: the loop prepares (expands) every item and keeps the prepared command, arguments,
  initial folder and item folder; only when the loop ended without an error are they started,
  in order.
- **Rationale**: the batch route already behaves this way (an error leaves the batch file unrun).
  A pre-pass over the enumeration is not possible - the callbacks free their index at the end
  (the panel's selection is cleared by the caller after the commands started - review 1).
- **Alternatives**: a length pre-check in the callers (mainwnd3 / finddlg1) - rejected: it would
  have to repeat the enumeration's choice of items (focus, up-dir, group commands use one item).

## R3 - Full paths of the panels

- **Decision**: `SalUMPathWithBackslash(panelPath, buf, MAX_PATH)` - whole with a trailing
  backslash, else empty + a "too long" flag; `UserMenu` shows "too long name" instead of "not
  defined" when the command uses the variable.
- **Rationale**: measured - the 259-byte cut ending at a backslash gave the parent folder.

## R4 - Names to compare

- **Decision**: `SalUMJoinWhole(path, name, buf, MAX_PATH)`; a name that does not fit leaves the
  name empty with a "too long" flag; `UserMenu` refuses (after the swap / clear rules, before the
  "files or folders" question and the dialog) when a flag of a name that is not cleared is set.
- **Rationale**: the compare dialog's fields hold 259 bytes; an empty dialog gave no reason.

## R5 - Panel's list of full names

- **Decision**: `CSalPathBuf` Set + AppendComponent, as the Find route since 004.
- **Rationale**: the list holds 32771 bytes; the MAX_PATH copy refused a list that fits.

## R6 - The enumeration contract

- **Decision**: `typedef int (*UM_GetNextFileName)(int index, char* path, char* name, void* param)`
  returning `UMNEXT_END` (0), `UMNEXT_ITEM` (1), `UMNEXT_TOOLONG` (2); buffers of
  `UM_ITEM_TEXT_SIZE` = `SAL_MAX_PATH_UTF8` bytes (heap, `CSalMaxPathBuffer`).
- **Rationale**: a value that does not fit is reported, never cut (a Windows path has at most
  32767 UTF-16 units = `SAL_MAX_PATH_UTF8 - 1` bytes of WTF-8, so it does not happen, but the
  channel exists). Only two implementers and one caller, all in the core.
