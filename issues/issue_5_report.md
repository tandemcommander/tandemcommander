Thank you for the report and for tracing it to the exact branch of `CFilesWindow::ChangeDir`.

**Verdict: valid.** Fixed for the next release, **0.1.10** (feature 125, branch `125-unc-server-shares`) - but not by the proposed `nethood=on`; the reasons are below.

### What was measured on 0.1.9

On a hidden desktop, with an automated probe:

| Typed in Change Directory | 0.1.9 |
|---|---|
| `\\localhost\`, `\\localhost`, `\\<this computer>\` | *Error Changing Directory* - `A share name is missing in the path specified.` (as reported) |
| `\\<a server that does not exist>\` | the same message, at once - the check is purely syntactic, the network is never asked |
| `\\` | `A server name is missing in the path specified.` |

The cause is as you describe: an incomplete UNC path is handed only to a plug-in that called `SetPluginIsNethood()`, and the default build has none.

### Why not `nethood=on`

I built 0.1.9 with the plug-in switched on and ran the same probe. It builds without changes and `\\server\` does open `net:\\server`. But:

- **after every session in which the plug-in was used, the Debug build reports "Detected memory leaks!" at exit.** The plug-in ends its worker threads by force (`Release()` -> `KillAll(TRUE, 0, 0)`, zero wait) - while they may be inside a network call or holding its cache lock;
- a server that does not exist opens an empty `net:\\name` panel with no message;
- it changes more than this report: every share root gains `..` leading to `net:`, *Go to root* jumps there, and the *Network* item of the Change Drive menu becomes the plug-in's panel, whose root depends on the old network discovery;
- the plug-in was disabled before the work on UTF-8 names, long paths and "never cut a name": it still compares names with the code-page functions, puts code-page texts into UTF-8 places, and uses `MAX_PATH` buffers that cut silently;
- its texts still say "Salamander" / "Open Salamander" in all languages;
- which plug-ins ship is a recorded policy of the project and part of the public privacy statement.

So enabling it is a feature of its own and a decision for the maintainer; it is recorded with this list in `specs/NEXT-WORK.md`. It is not ruled out - and if the plug-in is present, the new code steps aside and the path goes to the plug-in exactly as before.

### The fix

When no Network plug-in is present and the path names a server without a share, the program now **asks the server for its shared folders and offers them in a list** under the panel's path line (the same kind of list as the directory history):

- visible folders first, in alphabetical order; the hidden `$` shares (`C$`, `ADMIN$`, ...) after them, set apart; printers and `IPC$` are not offered;
- choose one (arrows + Enter, or the mouse) and the panel opens `\\server\<share>`; Esc returns to the Change Directory dialog;
- the server is asked on a worker thread: after a moment the usual *"Checking path ..., press the ESC key to cancel"* notice appears, and Esc ends the wait;
- a server that cannot be read is reported with the path and the reason Windows gives (e.g. *(53) The network path was not found*); a server with no folder share gives the old message;
- share names are shown and used exactly (any script, never cut).

No new texts were needed, so all languages are covered. `\\` alone still reports a missing server name - without the plug-in the program has no list of servers to offer. The privacy statement has a sentence about the new request.

### Tests

- 93 new unit checks of the rules (what counts as "server only", which shares are offered, hidden / visible, order, building the path without ever cutting it).
- An automated probe on a hidden desktop, 30 rows on the fixed build: **26 pass, 0 fail**, 3 are informational captures and one step is left to a person:
  - the list's content and order, checked item by item (11 shares incl. a printer, `IPC$`, a Czech name and `R&D`);
  - the real thing: `\\localhost\` -> the computer's own shares -> pick `C$` -> the panel stands in `\\localhost\C$`;
  - errors: a server that does not exist, a refused list, a server with no folder share;
  - a slow server: the wait notice appears, then the list;
  - the path given on the command line (`-l \\localhost\`);
  - closing the program while the list is open or while the server is being read: no crash, no hang, clean exit;
  - not driven by the probe: Esc in the wait notice (it reads the real keyboard) - checked by hand before the release.
- Controls: the same probe on 0.1.9 shows the error boxes above; on a build with the plug-in, `\\localhost\` still opens `net:\\localhost`.
- An independent code review; its findings (an Esc pressed earlier could cancel the wait, the worker thread's exception handling and its registration for the program's exit, a too generous sentence in the privacy statement) are fixed.

### Not part of this change

- `..` / Backspace at the root of `\\server\share` still does nothing without the plug-in (it could offer the same list - noted as a follow-up).
- A server that wants a name and password before it gives its share list: the Windows error is shown; a full `\\server\share` path offers the sign-in as before.

The fix will be part of **Tandem Commander 0.1.10**.
