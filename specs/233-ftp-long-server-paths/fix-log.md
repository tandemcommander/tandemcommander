# Fix log: 233 - FTP server paths over 300 bytes (measured: refused, not cut and acted on)

Backlog (215's audit): "server paths over 300 bytes cut and acted on" - the plug-in's paths are
`FTP_MAX_PATH` (301) buffers filled with `lstrcpyn` in many places (`fs2.cpp:723/730` ChangePath,
the upload target `fs5.cpp:744/856/923-1002`, `WorkingPath`, the queue's paths, PWD decoding).

## Measured

Probe `probe/ftp233_probe.ps1` with 215's `ftpmini.py`: five folders of 58 letters under /<row>
make "/<row>/c1/.../c5" 299 bytes - the deepest path that fits - and "/<row>/.../c5/leaf" 304 bytes,
which a cut at 300 bytes turns into ".../c5/", the PARENT of leaf (both hold an x.txt). The build at
232 (`probe/result.txt`, `probe/result_dlt_files.txt`, and the runs of the CD / DEL / DL / UP rows
recorded during the probe's development):
- **a typed path, or Enter into a folder, of about 260 bytes or more is refused by the core**
  ("The path specified is too long") - the panel never shows such a path, so ChangePath and the
  upload target never get one from it;
- **the operation queue refuses a sub-path over 300 bytes** - a tree copied down (DLT) or up (UPT)
  from c3: the queue entered c4 and c5 (CWD 240 / 299 bytes) and did not enter leaf
  (`FTPPathAppend` fails, `operats7.cpp:506`; the operation ends "Some parts of operation were not
  finished") - never c5 under leaf's name; the server's c5\x.txt stayed as it was (UPT);
- a PWD reply (a home folder) longer than 300 bytes is the one input left that `lstrcpyn` cuts
  (`FTPDecodeServerReplyPathInPlace` and the PWD parsing) - the panel then shows and works in that
  cut path under its own (cut) name: an ancestor, but not one disguised as another folder.

No code change. Found on the way (NEXT-WORK): **the tree download whose leaf was refused left
nothing on disk - not even c5\x.txt, which the server sent (RETR) and which fits** (DLT, "local
files: none").
