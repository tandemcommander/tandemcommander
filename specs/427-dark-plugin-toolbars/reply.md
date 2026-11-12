state: not-sent

Thank you for the report and the screenshots!

The next version should fix two of the three things (feature 427):

- **Toolbar icons in PictView and File Comparator.** In the Dark theme their old toolbar icons now
  get the same dark adaptation as the program's own Classic icons: black outlines and dark shading
  are drawn light, so the buttons are readable on the dark toolbar (also the disabled ones). They
  are still the old pictures, not new Fluent icons.
- **The light-grey parts of File Comparator.** Its toolbar strip, the "Difference" list, the strips
  between the toolbar and the file captions, the scrollbars and the thin frames around the two
  views were drawn in the classic light grey or white; in the Dark theme they are dark now.

The black checkbox labels (PictView's settings, page *Advanced*, and Batch Rename) we could not see
on our test machine: there all of them are drawn light, in the same way as in the program's
Configuration. Your screenshots show the check boxes themselves drawn differently than on our
machine, so it probably depends on the Windows version. Could you tell us your Windows version and
build? (Press Win+R, type `winver` and press Enter; the window shows e.g. "Version 23H2 (OS Build
22631.4460)".) If you saw light-grey parts in other windows than File Comparator, please tell us
which ones, a screenshot helps.
