# Fixtures of `tools/release/test_release.py` (feature 243)

`repo/` is a miniature repository with the release records at their real
paths, at the state "0.1.1 (build 185) published, work collected under
`## [Unreleased]`":

| File | Miniature of |
|------|--------------|
| `src/plugins/shared/spl_vers.h` | version macros, build history, interface (UTF-8 with BOM) |
| `setup/tandemcommander.iss` | `MyAppVersion` |
| `CHANGELOG.md` | `[Unreleased]` (features 012, 013, GitHub #4), `[0.1.1]`, `[0.1.0]` |
| `PRIVACY.md` | the validity block |
| `CLAUDE.md` | product line and *Status* |
| `architecture/12-project-reference.md` | product line |
| `backlog/RELEASE.md` | *Current release*, *Standing dates* |
| `backlog/items/person-one/desc.md` | an open person step naming feature 013 |
| `src/versinfo.rh2` | `VERSINFO_COPYRIGHT` |
| `release_notes/release_notes_v0.1.1.md` | published notes |

The tests copy `repo/` into a temporary folder, `git init` it and make two
commits with tags: `v0.1.0` with `spl_vers.h` at 0.1.0 / build 184, then
`v0.1.1` with the files as they are here (0.1.1 / build 185). Each test then
changes what it needs; nothing here is modified.
