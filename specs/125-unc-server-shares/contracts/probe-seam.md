# Contract: the probe seam of feature 125 (Debug builds only)

The share enumeration has a seam so that a probe can drive the list without a second machine.
It exists **only in Debug builds** (`#ifdef _DEBUG`); a Release binary must not contain the
names below (checked by a string search at the gates).

| Environment variable | Effect on `ReadUncShares` |
|---|---|
| `TC_PROBE_UNC_SHARES` | when set: the network is not asked; the value is the answer - entries separated by `\|`, each `name` or `name*<decimal share type>` (type 0 = folder, 1 = printer, 3 = IPC, 2147483648 = special folder); UTF-8 |
| `TC_PROBE_UNC_DELAY` | milliseconds to sleep before answering (with or without `TC_PROBE_UNC_SHARES`) |
| `TC_PROBE_UNC_ERROR` | when set: the answer is this Windows error code and no list |
| `TC_PROBE_UNC_CANCEL` | (feature 193) when set: milliseconds after the wait window opens, the wait is given up as if ESC was pressed - the main thread does not read this one, the worker is abandoned |

The variables are read by the worker thread at each enumeration (`TC_PROBE_UNC_CANCEL` by the
waiting main thread). They change nothing else:
the chosen `\\server\share` is opened by the ordinary path change against the real network.
