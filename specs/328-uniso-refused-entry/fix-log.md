# Fix log - 328-uniso-refused-entry

Backlog item `iso-plug-in-an-entry-the-listing-refuses-ends-the-listing`.

## Measurement before (main d61d0612, Debug build)

New probe `probe/iso328_probe.ps1` (hidden desktop; seed images by `probe/mkimg328.sh` in WSL
Ubuntu - genisoimage 1.1.11 fetched without root into `~/tc-genisoimage`, xorriso 1.5.6 as in 326):
one tree `a<60>/b<60>/c<60>/d<60>/e<60>/deep.txt` (305-byte Rock Ridge / Joliet folder part),
`a<60>/side.txt`, `top.txt`, `zlast/z.txt`.

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\log_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\iso328_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile ...\result_before.txt"
```

`probe/result_before.txt`: RUN rows 0 PASS / 6 FAIL (END rows 6 PASS - no crash):

- G-COPY (genisoimage -R), L-COPY (the same, root SP check bytes cleared), J-COPY (genisoimage -J):
  "UnISO: Error" at the open; the listing holds `a<60>\side.txt` and `top.txt` only - the deep tree
  and `zlast\z.txt` are lost (after the error `ListDirectoryRe` descends no later folder).
- X-COPY (xorriso): no message, the whole volume under ISO 9660 names (`TOP.TXT`, `A<31>\...`) - 326's
  whole-volume fallback.
- J-UNP-DEL, G-UNP-DEL (Alt+F9, "Delete archive after unpacking"): "Error", 2 of 4 files extracted,
  the IMAGE DELETED.

Why genisoimage still hits it after 326 (record dump of gdeep.iso with a session script): the root's
`.` record carries `['SP','RR','PX','TF','CE']`, every other record starts with `RR`. 326's fit
check fails and sets `SuspVolume = FALSE`, but `SalSuspRockRidgeStart` still accepts the `RR` first
entry - the Rock Ridge names are read again and refused.

(The before run used an earlier form of the probe's "Error" box match - `Error'\]`, never matching
the box `[#32770 'UnISO'] [Static] Error`; the rows fail on their files anyway. Fixed in the probe
to `\] Error( \||$)` before the after run.)

## Decisions

See spec *Clarifications* and research R3 / R4. Analyze: two LOW findings - R4's box wording fixed
(the plug-in's `Error()` formats into 1024 bytes and would cut a path: the report uses
`ShowMessageBox` with a heap text); FR-005's "as today" for plain volumes now has one extra check
walk - accepted (same listing).

## Implementation
