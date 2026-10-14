# Fix log: 166 - translation layout: what the drift is, an untranslated dialog, clipped labels

Backlog: `specs/NEXT-WORK.md` item 16: "`translate.merge --module zip` would re-lay out 510
controls of the committed ZIP translations (drift since build 185)".

## Measured

- `translate.merge --module zip` (no translation needed): the 510 is the count of controls the
  merge widens in all, not the change - the committed files differ in about 20 lines per
  language: check box and radio widths +12 DLU, the glyph allowance of feature 063 the committed
  ZIP files predate. The drift is the tool's newer rule, not damage.
- A dry run over every module found **untranslated text shipped in all 8 languages**: the
  Markdown Viewer's configuration dialog (DIALOG 310 - caption, check box, note, Cancel; added by
  088 with state 0 = English), and one PictView string in Spanish (`DPI%`, the same in both).
- `probe/layout_check.py` measures every single-line label in the dialog font (MS Shell Dlg
  8 pt, base units as Windows computes them; a check box / radio button counts its glyph as the
  module's `lang.rc` says): English templates **0** clipped. Committed translations of the 8
  enabled languages: **711 clipped labels** (cs 72, de 99, fr 163, nl 83, hu 46, ro 76, sk 84,
  es 88; all 11 folders 1,260), and 661 controls reaching past the frame of their group box.
  Example (Czech, Configuration > Viewer): "Velikost tabulatoru:" needs 90 px and has 57,
  "Vynutit sestnactkovy rezim pro soubory:" needs 188 and has 145.
- A full merge (every module) with the tool as it is: 1,237 clipped - the widening finds no free
  space for almost all of them (the next control or the dialog edge); it also widened labels
  across group box frames.

## Work

- `translations/*/mdview.slt` (+ `.origin`): DIALOG 310 translated (DeepL), checked by
  measuring: the note needed three lines in two in de, fr, nl, hu, es - shorter texts pinned in
  `translations/ui-overrides.json` (measured: every language fits, `probe/measure` in the
  scratch of the session: 311 and 3001 per language). Slovak check box in the infinitive (the
  corpus' form) and the same wording in Code Viewer's identical option (`codeview.slt` entry
  edited in place, pinned for both modules).
- `tools/translate/layout.py` `widen`: a control does not grow past the frame of a row that holds
  its left edge and its whole height (a group box, found by geometry - its id is often
  IDC_STATIC). Full merge with it: crossing 661 -> 459 (the rest is the templates' own geometry:
  English 36).
- **Not done**: the wholesale regeneration of all modules (170 files) - it removes 23 of 1,260
  clipped labels and needs a visual check that the hidden desktop could not give (the
  maintainer's own instance was running - probes share its registry key). The clipped labels
  are recorded in NEXT-WORK as their own item with the measuring tool; `probe/cfgshot_probe.ps1`
  takes a picture of a configuration page for that check.

Build: `build.cmd full` BUILD SUCCEEDED (language modules with the new texts).

## Evidence on screen

`probe/cfgshot_probe.ps1` (after the maintainer closed the program), Czech, Configuration >
Viewer, the committed translation: `probe/cfg_viewer_czech_committed.png` shows exactly what the
measurement says - "Velikost" (of "Velikost tabulatoru:"), "Vynutit Textovy rezim pro" and
"Vynutit Sestnactkovy rezim" (without "soubory:"), "napoveda k ma", "Barva normalniho" /
"Barva vybraneho" (without "textu"). Registry restored, identical.

## Left

- The bundle re-key of the merge tool (the second half of item 16) - not touched.
- The clipped labels (NEXT-WORK, new item).
