# Contract - access of the backlog app's state folder (feature 412, amends 344 review M2)

At every start of the backlog app, after the check for a running instance and before the
services are constructed (they read the state folder's files - the event log's last id, the
jobs) and before `instance.json` is written:

1. The folder `<git-common-dir>/tandem-backlog-app/` gets a protected DACL with full control,
   inheritable to files and folders, for the user running the app and SYSTEM, nothing else.
   Failure (judged by the exit code of a call without `/C`) -> the launcher secret is off
   (unchanged).
2. Every entry inside, at any depth, gets its DACL reset to the inherited one (no explicit ACE,
   not protected). Entries an earlier start locked are repaired by this step. A reset that
   fails is repeated once with `/C` so the other entries are still repaired; the step then
   reports `failed`.
3. A link (junction, symbolic link) inside is never followed: its target keeps its access.
4. A failure of step 2 does not turn the launcher secret off; the start prints
   `note: some files of the app's state folder could not be reset to the folder's permissions`.
5. POSIX: `chmod 700` on the folder only (unchanged; a failure reports `private: false`,
   `contents: "failed"`).

The side worktree (`main-worktree/`): a folder or `.git` that exists but cannot be read is
reported as `tool-failed` ("the side worktree of main cannot be read") and the folder is kept;
only a folder without `.git` (or one git does not know) is removed and recreated.
