state: not-sent

Thank you for the report and the recording.

You were right: the result list of *Find Files and Directories* sorted every request in the same (ascending) order and remembered nothing, so a second click on the same column header re-sorted the same order - it looked as if nothing happened. The list did sort by date, but it puts folders before files, so a date-sorted list started with the folders and the oldest file came only after the last folder; that is most likely why your list seemed to start at 2015.

This is fixed in feature 407 (it will be in the next release):

- A click on a column header sorts by that column ascending (for Date: oldest first); a second click on the same column reverses the order (newest first), further clicks keep toggling. A click on another column starts ascending again. View > Name / Path / Date / Size and Ctrl+F3 - Ctrl+F6 work the same way.
- The sorted column shows the usual sort arrow (up or down), also in the dark theme.
- Folders stay before files in both directions, as in the panels; inside each group the order is reversed.
- A new search forgets the sort (the arrow disappears).

The Registry Editor plug-in's Find window had the same limitation and now toggles the same way.
