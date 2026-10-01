# Tasks: workflow action versions

- [X] T001 Measure: latest tags and `runs.using` of every action used in .github/workflows/*.yml; release notes of each candidate major
- [X] T002 [US1] Bump `actions/checkout` v4 → v7 in pr-comments-guard.yml, pr-msbuild.yml, winget-publish.yml
- [X] T003 [US1] Bump `actions/upload-artifact` v4 → v7 in pr-msbuild.yml, winget-publish.yml
- [X] T004 [US1] Bump `actions/github-script` v7 → v9 in auto-label-author.yml, pr-squash-guard.yml
- [X] T005 [US1] Bump `microsoft/setup-msbuild` v2 → v3 in pr-msbuild.yml
- [X] T006 Verify: YAML parses, diff is version-only, inputs exist in the chosen versions, scripts use nothing removed
- [X] T007 Independent review
- [X] T008 Records: specs/NEXT-WORK.md item 6 P4, specs/072-winget-distribution/REMAINING-WORK.md P4, CLAUDE.md, specs/091-workflow-actions-node/fix-log.md
