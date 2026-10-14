# Fix log: 155 - refusal texts that say what is refused

Backlog: `specs/NEXT-WORK.md` item 10.

## Before (measured)

`probe/refusal_texts_probe.ps1` on the build before (`probe/result_pre155.txt`, 3/7): a folder
copied onto itself "Cannot copy a file to itself."; moved into itself / into its subfolder "Cannot
move a directory to itself."; a pack into itself "Cannot copy/move a file to itself."; the Renamer
"Unable to rename file: Cannot create a file when that file already exists.". Passing on both: a
folder moved onto itself and the worker's merge refusal ("Cannot move a directory to itself.").

**Found on the way:** the folder copy onto itself BY NAME had no folder-level refusal - the
script builder descended and `BuildScriptFile` refused the first file inside ("a file"); an empty
folder was not refused at all.

## Work

- Strings (bundle 12160-12175): 12161 `IDS_CANNOTCOPYDIRTOITSELF` "Cannot copy a directory to
  itself.", 12162 `IDS_CANNOTMOVEDIRINTOITSELF` "Cannot move a directory into itself or into one of
  its subdirectories.", 12163 `IDS_PACKINTOITSELF` "Cannot pack an archive into itself. Leave the
  archive (or the directory that contains it) out of the selection."; Renamer 1243
  `IDS_MOVETOITSELF` "Cannot move a file to itself.", 1287 `IDS_MOVEDIRTOITSELF` "Cannot move a
  directory to itself.".
- `fileswn6.cpp`: `DirTargetIsSource107` - the copy's folder text, the move into itself / into a
  subfolder its own text (the low-memory branch keeps "to itself": the reason is unknown);
  `BuildScriptDir` refuses a folder copied onto itself by name at the folder (as the move's branch
  next to it). `worker.cpp`: the merge refusal of a copy. `fileswn7.cpp`: the pack refusal.
- Renamer `rendlg3.cpp`: the link renamed onto its target and the rename into another root that
  meets the file itself - their own texts (no system reason); a folder (junction) gets the folder
  text.
- Translations: `translate.merge` for `salamand` and `renamer`; pins in
  `translations/ui-overrides.json`: the formal register (de "Lassen Sie", fr "N'incluez", es
  "Deje", nl without "je"), Czech grammar (12162 "do jednoho z jeho podadresářů"), Hungarian
  "mappa" and Spanish "trasladar" as the rest of those translations; the Renamer's two texts are
  the core's existing translations of the same sentences (10179, 10180). The Renamer's `.slt` /
  `.origin` files carry only the two entries: the merge re-laid out 159 dialog controls of the
  committed Renamer translations (the tool drift of NEXT-WORK item 16 - not this feature).
- 107's probe accepts the new folder texts beside the old ones (it no longer tells the builds
  apart by text; 155's probe does).

## Decision taken (recorded)

An empty folder (or one holding only subfolders / filtered-out files) copied onto itself by name
is now refused - before nothing happened and nothing was said. On a per-folder case-sensitive
folder `Foo` copied to `foo` is refused too (a non-empty one was refused by 092's file rule
already).

## Review (refute-first agent, 2026-10-14)

No critical finding. Taken over: (MEDIUM) the Renamer's copy onto itself is a rename into another
root (its only caller) - "move", not "copy" (string 1287 became the folder text); the junction case
gets the folder text; the low-memory branch keeps the generic text; a stale comment; Hungarian
"mappa", Spanish "trasladar". Recorded: the decision above; the worker's copy refusal, the newly
refused empty-folder copy and the Renamer's folder / cross-root routes are not driven by a row.

## After

- Debug build clean, `build.cmd full` BUILD SUCCEEDED; `check_encoding.py` TOTAL 0; saltests
  21,862/0.
- `probe/result.txt` 10/0 (before 3/7).
- Regression: 107 `folderalias_probe -Expect107` 150/0/60 (`probe/regress_folderalias107_155.txt`;
  the WebDAV rows not driven - the WebClient service is not running today), 119 `packleft_probe`
  104/0, 103 `samefile_probe` 46/0.
- Owed to a person: the texts on screen in a translated language (one refusal of each).
