# Contract - the refusal (UI behaviour)

For Select, Unselect, Convert, Change Filter and Drive Information, on OK:

1. The whole text of the field is measured in UTF-8 (WTF-8 for a lone surrogate).
2. More than 259 bytes: the box "The path specified is too long." (`IDS_TOOLONGPATH`, error title)
   is shown; the dialog stays open; the field keeps the whole text and is focused / selected
   (`CTransferInfo::ErrorOn`); nothing else runs (no syntax check, no selection, no conversion, no
   filter change, no history entry, no label write).
3. Up to 259 bytes: the dialog behaves exactly as before.

Hot path page: the in-place label edit (F2, Enter) stores the whole name; OK or leaving the page
refuses a slot name of 260 bytes or more with the same box, the slot selected, its name field
showing the whole name (feature 251's check).

No new string; no plug-in interface; no registry change.
