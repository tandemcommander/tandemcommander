# Quickstart: verifying feature 091

Static (done in the implementation session): see `fix-log.md`.

## Owed to the maintainer (needs a push)

1. Open a pull request (or run *PR Build* by hand, `workflow_dispatch`): the
   build job runs; the only Node 20 annotation left names
   `ilammy/msvc-dev-cmd@v1`.
2. A pull request with the label `comments translation` from a fork:
   *PR Comment Guard* checks out the head and runs.
3. *Run workflow* on `winget-publish` without `submit`: manifests are
   generated, validated and uploaded as an artifact.
