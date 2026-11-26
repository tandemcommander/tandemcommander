# Tandem Commander 0.4.0

**Released 26 November 2026 · build 197 · Windows 11 or newer, 64-bit · feature release**

## New

- **A portable edition.** Every release now also offers `tandemcommander-0.4.0-x64-portable.zip`: unpack it anywhere you can write — a USB stick, a folder, a network share — and run `tandemcommander.exe`. It keeps nothing of its own in the registry: settings, plug-in settings, histories and saved passwords are in the folder `settings` next to the program, so the whole folder can be carried to another PC; paths inside it keep working when the drive letter changes. The title bar says `[portable]` and the About box shows the settings folder. It tells you about a new release and opens its page, but never downloads or installs anything; copies in different folders and an installed Tandem Commander run side by side. Limits: no Explorer integration (dragging files out of an archive or an FTP / SFTP connection to Explorer is not available) and no jump list; saved passwords travel with the folder, so protect them with a master password if the folder can get lost.
- **A real *Desktop* item in the drive menu and drive bar** (#31), right after *Documents* (hot key `'`): it opens your Desktop folder as an ordinary disk folder, also a redirected one (OneDrive, a network share). A check box on *Configuration ▸ Change Drive Menu and Drive Bar* hides it.

## Changed

- **Panel tabs are square by default**: the active tab is a plain rectangle that runs straight into the Directory line. *Configuration ▸ Appearance ▸ Tab style* ▸ *Rounded* gives back the previous look at once. In the light theme the titles of inactive tabs are darker and easier to read.
- **The Folders plug-in's drive-menu item is now called *Shell Folders*** (hot key `-`) (#31); a real folder opened inside it (Documents, a drive) switches the panel to its disk path with the usual file operations, while This PC, Control Panel, Network, the Recycle Bin and folder shortcuts stay in the shell view.

## Fixed

**Viewers**

- **The Code Viewer and the Markdown Viewer fill their window after the display scaling changes** (#29) — before, after a scaling change in Settings, docking or undocking a laptop or a remote-desktop session, the page started far from the top-left corner, larger and cut off; on a second monitor with another scaling it was blurred. Both viewers now follow the monitor they are on. While an older version of Tandem Commander that has shown one of these viewers is running, the viewers of this version say the engine is not available: close the older version first.

**Dark theme**

- **PictView and File Comparator in the Dark theme** (#25): readable toolbar icons (light outlines, lightened dark blues, disabled buttons too), a dark PictView status bar with light icons, and no light-grey parts left in File Comparator (toolbar strip, list of differences, scrollbars, frames); everything follows a switch between the Default and the Dark theme while the windows are open. The toolbar icons are still the old pictures.

---

Install over the previous version — settings are preserved · Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full detail in `CHANGELOG.md`
