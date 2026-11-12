state: not-sent

Thank you for the report and the screenshots!

The next version should fix two of the three things (feature 427):

- **Icons in PictView and File Comparator.** In the Dark theme their old toolbar icons now get the
  same dark adaptation as the program's own Classic icons: black outlines and dark shading are drawn
  light, and dark blue parts (the arrows, the magnifiers) are lightened until they are readable. The
  disabled buttons are readable too. PictView's status bar is now dark as well, with light icons.
  They are still the old pictures, not new Fluent icons.
- **The light-grey parts.** File Comparator's toolbar strip, the "Difference" list (also when it is
  dropped open), the strips between the toolbar and the file captions, the scrollbars and the thin
  frames around the two views were drawn in the classic light grey or white; PictView's status bar
  too. In the Dark theme they are dark now, and they follow a switch between the Default and the Dark
  theme while the windows are open.

The black checkbox labels (PictView's settings, page *Advanced*, and Batch Rename) we could not see
on our test machine: there all of them are drawn light, in the same way as in the program's
Configuration. Your screenshots show the check boxes themselves drawn differently than on our
machine, so it probably depends on the Windows version. Could you tell us your Windows version and
build? (Press Win+R, type `winver` and press Enter; the window shows e.g. "Version 23H2 (OS Build
22631.4460)".) If you saw light-grey parts in other windows than these, please tell us which ones,
a screenshot helps.
