# Fix log: 225 - the User Menu never runs in a cut folder

Backlog (found by 222's audit): the User Menu (`mainwnd4.cpp:411-433`) cuts disk paths and names at
MAX_PATH and acts on them.

## Read (not driven)

`GetNextFileFromPanel` copies the panel path and the item's name into the User Menu's MAX_PATH
buffers with `lstrcpyn`. The review found the premise mostly wrong: `ExpandCommand2` already refuses
("name too long") whenever path + name do not fit MAX_PATH, so a cut NAME (or a cut path with a
name) never reached a command; the Find window's callback always has a name. The one real case: the
up-dir item or an empty panel (no name) with a panel path of 260+ bytes - the command ran in the
CUT path, another folder (possibly cut inside a letter). Not driven (User Menu items configured in
the registry, a deep panel path) - a step owed to a person.

## Work

`src/mainwnd4.cpp` `GetNextFileFromPanel` (no selection): a panel path that does not fit is refused
with the message `ExpandCommand2` gives ("name too long", `IDS_TOOLONGNAME`); nothing runs.

A first version refused in every route (also the Find window's) - the review rejected it: it changed
nothing real and in .bat mode ran the .bat built so far after the refusal (the old refusal inside
`ExpandCommand2` discarded it). Reverted to this one check.

Build: BUILD SUCCEEDED.

## Review

Refute-first review (of the first version): rejected for the reasons above; taken - the narrowed
fix. Recorded in `specs/NEXT-WORK.md`: **the User Menu's .bat ("Through shell") converts its UTF-8
command line and folder with `CharToOem`** (`mainwnd4.cpp` ~918) - read as the ANSI code page, an
accented path becomes other letters (the wrong file, or none); CJK never maps; long paths in the User
Menu (its MAX_PATH contract) as an own item; the Find window's `CompareName1/2` cut its path
(`finddlg1.cpp:2785/2795`, followed by `SalPathAppend` - to check).
