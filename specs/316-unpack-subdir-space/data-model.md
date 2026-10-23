# Data model - 316

No stored data, settings or structures change. The only value involved is the Unpack dialog's
target text (`path`, a MAX_PATH UTF-8 buffer in `CFilesWindow::Unpack`):

| Target text after OK | Before | After |
|---|---|---|
| relative, leading spaces (` ssss`) | `<archive folder>\ssss` | `<archive folder>\ ssss` - used if it exists, else refused (Error Creating Directory) |
| relative, no leading space (`typed`) | `<archive folder>\typed` | unchanged |
| spaces only | empty target (feature 315) | unchanged |
| absolute (`C:\...\ ssss`) | used / refused when new | unchanged |
| drive-relative / root-relative with leading spaces | trimmed | unchanged |
