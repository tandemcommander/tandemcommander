# Fix log: 235 - $(ListOfSelectedNames) from Find results in several folders

Backlog (234's review): a User Menu command with `$(ListOfSelectedNames)` runs once, in the first
item's folder (234). From the Find window, with results from several folders, the bare names of the
other folders' items named other files - or none - in the first one.

## Work (`src/finddlg1.cpp` `CFindDialog::OnUserMenu`, by reading)

When the selected items' folders differ (byte comparison - in a case-sensitive folder "A" and "a"
are two folders; a false "differ" only gives full names, which are always right), the list holds
the full names (`ListOfSelFullNames`; quoted per name by `AddToListOfNames`, 229).

**Decision: full names instead of a refusal** (the backlog said "refuse"): there is no fitting
message (no new UI strings), and full names name exactly the selected files - safe for destructive
commands. A tool that expects bare names (a `ren` target, an archiver storing the paths it gets)
gets full paths without a message; the help says so now. A list too long as full names is refused
("too long"), as before; a '^' in a folder path is refused by 229's rule.

Not driven: the Find window's User Menu is a popup the probe could not drive (234) - a step owed to
a person. Help (`help/src/hh/salamand/customize_usrmn.htm`): the Find behaviour, 229's quoting rule,
a typo (`$(ListOfSelectedNames)` named twice).

Build: BUILD SUCCEEDED.

## Review

Refute-first review: no MUST. Taken: the help (it described bare names, "panel or Find window") and
the decision recorded here; the comment's feature number. Noted: `GetNextItemFromFind` cuts Path /
Name at MAX_PATH (`finddlg1.cpp:850`), but `ExpandCommand2` refuses path + name over MAX_PATH before
anything runs.
