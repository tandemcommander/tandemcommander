# Quickstart - validating 412

From `tools/backlog-app/`:

1. `npx vitest run --project server test/state-dir.test.ts test/side-worktree.test.ts` - the new
   cases: files, a hidden file and nested folders readable / writable / deletable after
   `restrictToOwner()`; a pre-locked file (`D:PAI`, made with the old call) repaired; every DACL
   names only the user and SYSTEM; a junction's outside target keeps its explicit ACE; an
   unreadable `.git` refused without deleting the worktree.
2. Negative control: with the old `restrictToOwner()` body the file cases fail (record in
   `fix-log.md`).
3. `npm run check` - the whole gate passes.

See [contracts/state-folder-access.md](contracts/state-folder-access.md).
