# Contract: the import wizard (user-visible behaviour)

Entry: *Options → Import Settings from Sala&mander…* (after *Import
Configuration…*), and the one-time offer (FR-002, research R13). Five modal
pages, one at a time, centred on the main window, house dialog style, dark
theme. Every page: *< Back*, *Next >* (or *Import* / *Close*), *Cancel*,
*Help*. Esc and the close box = Cancel. Before *Import* nothing is changed.

## Guard (before page 1 and again before applying)

Another Tandem Commander instance runs ⇒ a box: "Close the other Tandem
Commander windows first; they would overwrite the imported settings when
they close." The wizard does not open (or returns to the preview).

Before applying also: a Find window or a viewer window of this instance is
open ⇒ "Close the Find windows and the viewer windows … first" (they read
settings the import replaces, in their own threads); the wizard stays on the
preview. A plugin whose archive or file system is open in a panel or detached
⇒ its whole-settings group fails with "The plugin is in use …" (nothing is
closed, nothing asked); the other groups are applied.

## Page 1 — Source

- Intro text: what the wizard does, that the old program's settings are only
  read and never changed, that nothing changes before the final *Import*.
- List of found configurations: "Altap Salamander 4.0 — configuration
  version 103"; unsupported ones are marked "(not supported: older than Altap
  Salamander 2.5)" / "(not supported: newer than this program)" and cannot be
  chosen (*Next* stays disabled; a standard list box has no greyed rows). The
  newest supported one is selected.
- Notes under the list for the selected source: "The program seems to be
  running; settings it has not saved yet are not imported." / "The last save
  of these settings may have been interrupted; they may be incomplete."
- No configuration found ⇒ the list shows "No settings of Altap Salamander or
  Open Salamander were found for this Windows user." and only *Close*.

## Page 2 — What to import

- List view with check boxes, columns *Settings* | *Items* | *Mode*.
  Rows per research R4 (one row per plugin with settings in the source).
  Unavailable rows (empty, absent, not transferable) are shown greyed with the
  reason in the *Mode* column and cannot be ticked.
- Below the list, for the selected row: radio buttons *Add to my current
  settings* / *Replace my current settings* (enabled only for list groups
  with both modes) and a one-line description of what the row does.
- Notes: "Shortcuts of Tandem Commander's own commands are fixed; only
  shortcuts you assigned to plugin commands can be imported." "Archiver
  settings, plugin installation, the language, the theme, panel tabs and
  window positions are never imported (use *Archivers Autoconfiguration* for
  archivers)."
- *Next* is disabled while nothing is ticked.

## Page 3 — Saved passwords (only when the FTP row is ticked and the source has saved passwords)

- Counts: passwords stored without and with a master password.
- If some are protected: an edit (password style) for the old master
  password; *Next* checks it against the old program's record — wrong ⇒
  "This is not the master password of <source>." and stays.
- Radio buttons: *Import saved passwords* / *Do not import saved passwords*.
- When Tandem Commander has no master password and protected passwords would
  be imported: a check box "Store them without a master password (they were
  protected by one in <source>)"; unticked ⇒ protected passwords are left out.
  A hint: set a master password in *Configuration → Security* first to keep
  them protected.
- When Tandem Commander uses a master password: "Imported passwords will be
  protected by your Tandem Commander master password." (it is asked for once,
  after this page and before the preview, if not entered in this session).

## Page 4 — Preview

- Read-only multi-line text: per group, a heading and lines "+ added",
  "= already present", "~ replaced (current → new)", "- removed", "! check",
  "x skipped: reason"; at the end the backup note.
- If anything will be overwritten or removed: a check box "I allow the
  changes of my current settings marked ~ and - above"; *Import* is disabled
  until it is ticked. Otherwise no check box.
- *Import* runs: guard → save → backup → apply → save. A wait cursor; no
  further questions (the program's master password was asked before the
  preview, R10).

## Page 5 — Result

- Read-only multi-line text: per group "applied" / "not applied: reason",
  the same item lines as the preview (what really happened), flagged items,
  "Backup of your previous settings: <file>" and the restore steps.
- *Copy* (whole text to the clipboard), *Save…* (UTF-8 text file),
  *Close*. No *Back*.
