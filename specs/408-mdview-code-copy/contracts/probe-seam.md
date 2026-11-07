# Contract - probe seam `TC_MDVIEW_PROBE_COPY_LOG` (feature 408)

Debug builds only (`#ifdef _DEBUG` in `src/plugins/mdview/viewer.cpp`); absent from
Release.

When the environment variable is set to a file path, a copy of a code block does not
touch the clipboard (the hidden desktop shares the maintainer's clipboard): the exact
text that would go to the clipboard (UTF-16, after `MdCodeClipboardText`) is written to
that file as UTF-8 without BOM, replacing its content, and the copy counts as
successful. A failed write counts as a failed copy (no notice).

After a successful copy the notice text (`MdCopyNoticeText`) is also written, UTF-8, to
`<path>.notice` - a probe cannot read a tooltip's text from outside the process; it
checks the tooltip window itself (visible, inside the viewer's bottom-right quarter).

When an http, https or mailto link is activated while the variable is set, the address
is written to `<path>.shell` instead of being handed to the shell (review 3: a browser
would start in another process, invisible to the probe's window checks; no browser
starts during a probe).

Used by `specs/408-mdview-code-copy/probe/copy408_probe.ps1`.
