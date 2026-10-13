URL: https://github.com/tandemcommander/tandemcommander/issues/5

**Version:** Tandem Commander 0.1.9 (x64), Windows 11, computer in a Windows domain

**Steps to reproduce**
1. Press Shift+F7 (Change Directory).
2. Type the name of a file server without a share, e.g. `\\server\`, and press Enter.

**Expected** (as in Altap Salamander / Open Salamander): the panel opens `net:\\server` and lists the server's shares (APPS, DATA, HOME, NETLOGON, ...).

**Actual:** the message box "Error Changing Directory" - `Path: "\\server\"`, `Error: A share name is missing in the path specified.`

**Cause**

`CFilesWindow::ChangeDir()` in `src/fileswn3.cpp` hands an incomplete UNC path (`IDS_SERVERNAMEMISSING` / `IDS_SHARENAMEMISSING` with `callNethood`) to the first plugin that called `SetPluginIsNethood()`:

```cpp
if ((errTextID == IDS_SERVERNAMEMISSING || errTextID == IDS_SHARENAMEMISSING) && callNethood)
{ // incomplete UNC path will be given to the first plugin which supports FS and called SalamanderGeneral->SetPluginIsNethood()
    if (Plugins.GetFirstNethoodPluginFSName(absFSPath))
```

That plugin is the Network plugin (`nethood`), and `plugins.cfg` has had `nethood=off` since feature 007, so there is no such plugin and the error is shown. The code that depends on it is still in the core, e.g. the up-dir item (`..`) in the root of `\\server\share` and the root command there (`fileswn3.cpp`, `fileswn1.cpp`) also lead to `net:\\server` only when the plugin is present.

**Proposed fix** (tested on 0.1.9: `\\server\` then opens `net:\\server` with the shares, no message)

```diff
--- a/plugins.cfg
+++ b/plugins.cfg
-nethood=off
+nethood=on
```

The plugin builds without changes and has its translations and help in the repository. As it is then shipped in the default build, `PRIVACY.md` would need its line too (it browses the local network through the Windows networking API; nothing leaves the network).
