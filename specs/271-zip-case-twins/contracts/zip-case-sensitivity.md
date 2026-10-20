# Contract: ZIP listing case sensitivity (feature 271)

Internal to the ZIP plug-in; no plug-in interface change.

1. A ZIP listing is case-sensitive (`SALDIRFLAG_CASESENSITIVE`) iff an entry was made on Unix or a
   folder of the listing holds case twins (`SalDirTreeHasCaseTwins`, 252's rule).
2. Without twins and Unix entries the listing is the one of 0.1.10 (built case-sensitively, the flag
   cleared: every merge joins byte-identical names).
3. Every operation started from a listing (`UnpackArchive`, `UnpackOneFile`, `DeleteFromArchive`)
   compares archive names with that listing's case sensitivity, whatever is selected - also a folder
   without its own entry.
4. Adding into an archive (`PackToArchive`) is not bound by this contract (no listing is handed to
   it).
