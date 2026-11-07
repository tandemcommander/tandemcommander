# Contract - probe seam `TC_MDVIEW_PROBE_COPY_LOG` (feature 408)

Debug builds only (`#ifdef _DEBUG` in `src/plugins/mdview/viewer.cpp`); absent from
Release.

When the environment variable is set to a file path, a copy of a code block does not
touch the clipboard (the hidden desktop shares the maintainer's clipboard): the exact
text that would go to the clipboard (UTF-16, after `MdCodeClipboardText`) is written to
that file as UTF-8 without BOM, replacing its content, and the copy counts as
successful (the notice is shown). A failed write counts as a failed copy (no notice).

Used by `specs/408-mdview-code-copy/probe/copy408_probe.ps1`.
