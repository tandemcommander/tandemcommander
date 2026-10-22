# Contract - the Unpack dialog's refusal (feature 299)

UI contract of `CUnpackDialog` (Alt+F9), not a plug-in interface.

- On OK, the target path field is measured whole: its UTF-8 (WTF-8) form with the NUL must fit
  260 bytes. Otherwise: a box "The path specified is too long." (`IDS_TOOLONGPATH`, title Error,
  OK), the dialog stays, the path field focused, its text whole; nothing created or unpacked.
- Then the mask field, by the same rule and the same message.
- One refusal per OK; the path first.
- Text that fits: unchanged behaviour.
- No new string; no limit added to either field.
