Tandem Commander - portable edition
===================================

This is Tandem Commander @VERSION@, portable edition: a two-panel file manager
for Windows 11 (x64). It needs no installation and keeps nothing of its own in
the Windows registry: everything it keeps lives in the folder you unpacked.

Use
---
1. If you downloaded the ZIP with a web browser, right-click it first, choose
   Properties and tick "Unblock" (otherwise Windows may warn about every file
   unpacked from it).
2. Unpack the whole folder anywhere you can write: a USB stick, a folder in
   your profile, a network share.
3. Run tandemcommander.exe. The title bar says "[portable]".

Your settings
-------------
- Everything the program keeps - its configuration, the settings of every
  plugin, histories, hot paths, bookmarks, saved passwords - is in the folder
  "settings" next to tandemcommander.exe (created when settings are first
  saved). Help > About shows that folder and opens it.
- To take the program to another PC, copy the whole folder. Paths to files
  inside this folder (tools on the stick, for example) keep working when the
  drive letter changes.
- Saved passwords travel with the folder. Protect them with a master password
  (Configuration > Security) if the folder can get lost.
- The program also runs from a folder it cannot write to (a write-protected
  stick, a CD): it says so once, and changes are not kept.
- While it runs, the program keeps temporary data (for example of the code and
  Markdown viewers) in your temporary folder (%TEMP%); it is removed when the
  program closes.

Update
------
Help > Check for New Version (and, unless switched off, a check about once a
day) tells you about a new release and opens its page. Download the new
portable ZIP, unpack it next to this folder and copy the "settings" folder
into the new one. The portable edition never downloads or installs anything
by itself.

Remove
------
Delete the folder. Nothing else of the program stays on the PC.

Different from the installed program
------------------------------------
- No Explorer integration: dragging or copying files out of an archive or an
  FTP / SFTP connection to Explorer is not available (copy or unpack them to a
  disk folder first).
- No automatic update and no jump list on the taskbar.

Privacy and licence
-------------------
The privacy statement: https://tandemcommander.org (PRIVACY.md in the
source repository, section "Portable edition").
Tandem Commander is free software under the GNU General Public License,
version 2 or later - see LICENSE.txt and the notices in the doc folder.
https://github.com/tandemcommander/tandemcommander
