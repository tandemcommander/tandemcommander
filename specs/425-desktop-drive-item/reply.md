state: not-sent

Thank you for the report and the screenshot!

You are right that the entry was misleading. The "Desktop" item in the drive menu came from the Folders
plug-in. It did not open your Desktop folder (`C:\Users\<user>\Desktop`): it opened the Windows shell
namespace (`fld:`), where the items of the desktop are mixed with This PC, Libraries, Network, Control
Panel and the Recycle Bin, and the path line said only `fld:`. Worse, a real folder you opened there
(Documents, a drive) stayed in that view, without the usual file operations.

The next version should fix it (feature 425):

- The drive menu (Alt+F1 / Alt+F2) and the drive bar get a real **Desktop** item right after
  Documents, with the same hot key `'`. It opens your Desktop folder as an ordinary disk folder, also
  when the Desktop is redirected (for example to OneDrive). If Windows reports no Desktop folder, a
  message says so and the panel stays where it is. A new check box *Desktop* on Configuration > Change
  Drive Menu and Drive Bar hides the item.
- The Folders plug-in's item is now called **Shell Folders** (in Czech *Složky Windows*), hot key `-`.
- Inside Shell Folders, a folder that is a real folder on disk (Documents, your user folder, a drive, a
  folder on the desktop) now opens as its disk path, with every file operation. Virtual places (This
  PC, Control Panel, Network, the Recycle Bin and its items) and folder shortcuts stay in the shell view.

What stays: inside the shell view the path line still shows only `fld:`; a readable path there is not
planned. Please tell us whether the next version works for you.
