---
title: Manual checks owed before the next release
type: person-step
status: open
severity: 5
area: build-release
source: manual
who: person
created: 2026-11-06
updated: 2026-11-12
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Manual checks owed before the next release

## Problem

Autonomous runs leave checks only a person can do: a real keyboard, mouse, clipboard or IME, another machine, admin rights, the look on a real screen. Until 2026-11-06 each such check became a `person-step` item of its own, and they piled up (97 of 99 *Person steps* items came from features' leftovers). From now on, every run appends its checks to this **one** checklist instead, and the maintainer works through it before a release.

## Evidence

The maintainer's rule of 2026-11-06 is recorded in:
- `/tandem-backlog-implement` `stop-rules.md` rule 9 (runs append lines here) and rule 11 (findings of severity 5 or less are fixed inside the feature);
- the exception in `/tandem-backlog` `SKILL.md` §0.3 (a run may only append lines, never change or remove them);
- `CLAUDE.md` *Working method*.

The *Person steps* items recorded before that day stay where they are.

## Expected

Before the release, every line below is ticked (`BL step <slug> <n> --done`). Or its failure has become an *Inbox* item named in the line's note. Then the maintainer closes this item. The first run after the release opens a new checklist.

## Steps

- [ ] Before the release: work through every unticked line below; each names the feature it comes from and the expected result
- [ ] Panel tab strip on a real screen at 100 %, Default and Dark theme: the rounded active tab with feet, location icons (folder, drive, archive, an SFTP tab), the hover pill and the hover circles of the X and + follow the real mouse and disappear when it leaves the strip (feature 404)
- [ ] Live tab drag with a real mouse: the tab follows the cursor, neighbours slide aside smoothly (about 150 ms), the tab glides into place on release; Esc during a drag puts every tab back; with Windows *Animation effects* off the tabs jump instead of gliding (feature 404)
- [ ] Close on release with a real mouse: pressing a tab's X shows it pressed and does not switch the tab; releasing over the X closes it, releasing elsewhere closes nothing (feature 404)
- [ ] Panel tab strip at 125 % and 150 % display scaling and under Windows High Contrast: metrics scale, icons sharp, texts readable (feature 404)
- [ ] Tab context menu: *Move to Other Panel* moves a folder tab and an SFTP tab (a second connection opens in the other panel, the first closes); *New Tab as Other Panel* opens the other panel's location; both greyed where the contract says (single tab, empty strip) (feature 404)
- [ ] Tab switch that asks a question, with a real mouse (GitHub issue #22): with an FTP connection in one tab of a panel, click another tab of the same panel, answer the FTP question with the mouse (*keep the connection*), then move the mouse over the strip and click a file in the panel -> no insert mark follows the mouse, the click goes to the panel, no tab moves; a tab dragged with the button held still moves (feature 405)
- [ ] Registry Editor, **elevated** (Run as administrator), Move of an HKEY_CLASSES_ROOT key held by both halves: as admin create a scratch key `HKLM\Software\Classes\.tc406` with a value `m` = `1` and a subkey `S`, and as the user `HKCU\Software\Classes\.tc406` with a value `u` = `2` and a subkey `S`; F6 `\HKEY_CLASSES_ROOT\.tc406` into `\HKEY_CURRENT_USER\Software\` -> no box, the copy holds `m`, `u` and `S`, both halves of `.tc406` are gone and HKCR no longer shows it. Repeat with the user's value named `m` = `9` -> the box "Unable to remove the original registry key. (50) The request is not supported." names `HKEY_LOCAL_MACHINE\Software\Classes\.tc406`, the machine's half is kept; delete the scratch keys afterwards (feature 406)
- [ ] Find (Ctrl+F) with a real mouse and keyboard, Default and Dark theme: search a folder with sub-folders, click the Date header twice and press Ctrl+F5 twice in the result list - the order reverses each time (folders stay first) and the Date header shows the arrow up, then down; Find again - no arrow. The Registry Editor's Find window: a second click on a column header reverses the order, the arrow shows (feature 407)
- [ ] Markdown Viewer, real mouse and clipboard, Default and a dark scheme (F9): open a .md file with several code blocks (one with Czech and an emoji, one in a list, a Makefile block with tab-indented lines); hover a block - *Copy* appears in its top-right corner; click - a native notice at the viewer's bottom right shows *Copied* and the first lines, gone after about 2.5 s; paste into Notepad - exactly the block's code, the Makefile's tabs kept, Windows line breaks, no extra last line; Tab to a control + Enter copies too and the focus stays there; the page never scrolls (feature 408)
- [ ] Markdown Viewer select-all: Ctrl+A, Ctrl+C on a page with code blocks, paste - the *Copy* labels are not in the pasted text (feature 408)
- [ ] Markdown Viewer copy control on a touch screen or pen, if available: one tap on a block's top-right corner copies and shows the notice (feature 408)
- [ ] Backlog app state folder repaired on the maintainer's tree: start the app once (`bin/start-backlog-app.sh`), then `Get-Acl` over `.git/tandem-backlog-app` shows no entry with an empty protected DACL (`D:PAI` alone; 375 before), `main-worktree/.git` and `events.jsonl` readable, and a change made in the app during a run lands on `main` (feature 412)
- [ ] Panel tab drag to the first place with a real mouse: in the left and in the right panel drag a tab that is not the first one to the left end of the strip and release - it becomes the first tab; with more tabs than fit, it becomes the first of the tabs shown (feature 413)
- [ ] Panel tab strip, Default and Dark theme side by side (also at a scaling other than 100 %): the strip looks equally high in both; in the Dark theme the inactive panel's active tab is a visible rounded tab (a lighter grey than its directory line, its title readable), likewise with a user colour scheme whose caption colour is close to the strip; tell whether the Dark theme still looks lower anywhere (feature 413)
- [ ] Toolbar icons on a real screen, Default and Dark theme, at your usual display scaling: with no choice made the program shows the Fluent 2 set - top and panel toolbars, drive bar and Change Drive menu, the `..` symbol of the file list, the toolbars of the configuration lists - legible and consistent; Configuration > Appearance > Toolbar icons shows both previews, Classic + OK switches at once (no restart) to exactly the 0.2.0 look, Fluent 2 + OK switches back (feature 416)
- [ ] Menus with icons (Files, Commands, the panel context menus) in the Fluent 2 set, both themes, with a real mouse or keyboard: every icon stays recognisable on the highlighted row and greyed items stay readable (feature 416)
- [ ] Toolbar buttons hot and pressed with a real mouse, both icon sets and both themes: no icon disappears; disabled buttons stay discernible (feature 416)
- [ ] Fluent 2 icons at 125 %, 150 % and 200 % display scaling: sharp, centred in their buttons, not clipped (toolbar, drive bar, `..`, the Appearance previews) (feature 416)
- [ ] Configuration > Appearance in Czech and German: the Toolbar icons group, its two choices and previews fit and read well (feature 416)
- [ ] Plug-in icons with a real mouse or keyboard in the Fluent 2 set, Default and Dark theme: the Plugins menu and each plug-in submenu, View With (F3 menu) and Help > About Plugin - every plug-in shipped with the program shows its Fluent 2 icon (DBViewer, PEViewer, TAR, UnCAB too), legible on the highlighted row, disabled items readable; with Classic exactly the old icons (feature 417)
- [ ] Plugins bar (Options > Toolbars > Plugins Bar) hot and pressed with a real mouse, Fluent 2, both themes: no plug-in icon disappears; its drop-down menus open as before (feature 417)
- [ ] Plug-in icons at 125 %, 150 % and 200 % display scaling, Fluent 2: sharp in the Plugins bar, the Plugins Manager, Alt+F1, the drive bar and the tab / Directory line of an FTP or Windows Registry file system (feature 417)
- [ ] Configuration > Appearance in Czech and Spanish: the group now reads "Styl ikon" / "Estilo de iconos" (English "Icon style"), fits and reads well; Alt+I (Czech) reaches it (feature 417)
- [ ] Default and Dark theme side by side at 100 %, 125 %, 150 % and 200 % display scaling: the toolbar area and the panel tabs at the same height, the Dark frame and the lines between toolbar rows dark (no light line), the toolbar grips at the same place and dark in Dark (no light stripe) (feature 418)
- [ ] Toolbars moved by their grips with a real mouse in the Dark theme (also with two drive bars shown): the bands move as in the default theme, and no grip shows a light stripe while dragging or after (feature 418)
- [ ] High Contrast switched on and then off (Windows Settings > Accessibility > Contrast themes) while the Dark theme is selected: the toolbar area takes the system colours, then the dark frame, lines and grips come back without a restart (feature 418)
- [ ] Backlog app *Live run* during a real loop run, on a real screen with a real mouse, Default and Dark theme: one row of views (Overview first, Chat last), the run in one line above it, the page itself never scrolls, each view scrolls by itself; the Story follows new lines, a wheel move up keeps it where you put it ("Latest" brings it back), opening a line keeps it in place; Chat uses the full width, a real Claude answer scrolls only the conversation and marks the Chat tab when it arrives while another view is shown; a reload keeps the view (`?view=`) (feature 419)
- [ ] Automatic update, all-users installation (Program Files) with a real UAC prompt: start the installed copy with `--updatetest`, level *Download it and offer installation*, click *Install Now* -> UAC prompt -> Yes: Setup's progress window, the program closes, the published version is installed and the program **comes back not elevated** (Task Manager: column *Elevated* = No) (feature 420)
- [ ] Same with UAC -> No: a message "was not installed ... (code n)" and the offer comes back; nothing is installed at the next exit unless an update was planned before (then a Yes/No question decides) (feature 420)
- [ ] Automatic update, level *Install it automatically when I close Tandem Commander*, all-users installation: close the program -> UAC prompt at the exit -> Yes: installed silently; the next start runs the published version; with No: the next start offers the update (notification), it does not start Setup by itself (feature 420)
- [ ] Automatic update with a real mouse and keyboard, one installed copy started with `--updatetest`: the three forms of the notification (offer, automatic, classic) look right in Default and Dark; Enter on the automatic form = OK (nothing installed); Tab moves through the buttons; *Install When I Close* then closing the program installs the update and the next start runs the published version (feature 420)
- [ ] Automatic update, keyboard after a failed *Install Now* (Debug build, `TC_UPDATE_PROBE_LAUNCHFAIL=1`, an update offered after two earlier launches): after the message the offer is shown again **without** *Install When I Close* and keeps the keyboard (Tab / Enter work on it without a click) (feature 420)
- [ ] Automatic update with a screen reader (Narrator) on the offer form: the buttons and the hint are read (feature 420)
- [ ] Automatic update on the next real release (0.2.0 -> next) without `--updatetest`, default level: the notification offers the downloaded version, *Install Now* updates in one click; `%LOCALAPPDATA%\Tandem Commander\Updates` is empty afterwards except the installer's log (feature 420)
- [ ] Before signing a release with a renewed code-signing certificate: its thumbprint was added to `SalUpdSignerThumbprints` (src/common/salupdinstall.h) in an earlier release (architecture/12-project-reference.md, "Automatic update") - otherwise installed copies only offer the browser download for that release (feature 420)
- [ ] Update notification, all-users installation, level *Notify me only*: *Download & Install* shows the progress, then the real UAC prompt; accepted - the program closes, the update installs with a progress window and the program starts again on the real desktop, not elevated; declined - the message offers installing at close (feature 421)
- [ ] Automatic level (*Install it automatically as soon as it is downloaded*) on the real desktop: no notification appears; after half a minute without keyboard or mouse use the installer starts with the UAC prompt (all users); decline it and answer No - from then on the update is only offered (the next check shows the offer, nothing starts on its own) (feature 421)
- [ ] Automatic level, Help > Check for New Version while the notification is in front with its level list open when the download finishes: the window is not closed under you - it becomes the offer (the hidden desktop has no foreground window) (feature 421)
- [ ] Notification with a real keyboard and mouse: the level list - arrow keys step without acting until a one-second pause, the open list acts when it closes; *Download & Install* is the default (Enter), *Cancel Download* stops it; Narrator reads the level label, the list and the buttons (feature 421)
- [ ] Notification design in every language, light and dark, 100 / 150 / 200 %: the taller window with the level row, the button row with *Download & Install* (and *Cancel Download* fitting the same width), the portable hint of a copy not installed by the installer (feature 421)
- [ ] Automatic level on the real desktop, all-users installation: right after the start-up check (while you work) the program closes, the UAC prompt appears, accepted - the update installs with a progress window and the program starts again (not elevated); nothing is ever installed when you close the program (feature 422; supersedes the "install at close" parts of the feature 421 lines above)
- [ ] The lock-out trap on the real desktop: let the automatic install start, decline the UAC prompt (or cancel the installer after it closed the program), start Tandem Commander again - nothing starts on its own, also at the next start and after the next daily check (only the offer); a failed Install Now shows OK only, no question about installing at close (feature 422)
- [ ] Automatic level: Help > Check for New Version and the About box's Check now show the window with Install Now and never install on their own; choosing the automatic level in the window keeps it open (feature 422)
- [ ] Automatic level while you type in the command line or have a Find window open: nothing starts until the line is empty / Find is closed (feature 422)
- [ ] Panel tabs on a real screen, Default and Dark theme, default configuration: the active tab is a plain rectangle that runs into the directory line (no rounded corners, no feet), as the maintainer's mockup `specs/423-square-panel-tabs/evidence/flat_tabs.png`; a real mouse over an inactive tab shows a rectangle that stops just above the directory line, in the active and the inactive panel; the feature 404 line about the rounded active tab is now checked with Tab style = Rounded (feature 423)
- [ ] Configuration > Appearance > Tab style with a real mouse and keyboard: Rounded + OK switches both panels to the rounded look at once, Square + OK back; Tab moves Font -> Information Line -> Icon style -> Tab style -> Thumbnails, arrow keys move only between Square and Rounded; the page reads well in Czech and German (feature 423)
- [ ] Panel tabs at 125 %, 150 % and 200 % display scale in both styles: the square active tab has straight edges and joins the directory line, the hover rectangle ends above it, nothing moves when the style is switched (feature 423)
- [ ] Code Viewer and Markdown Viewer after a display-scaling change (GitHub #29): start Tandem Commander at 100 %, set the display scaling to 150 % in Settings without signing out, then press F3 on a text file and on a `.md` file -> the page starts at the client's top-left corner, fills the client, the text is sharp and not cut off at the right or bottom edge; repeat after returning to 100 % (feature 424)
- [ ] The same two viewers with two monitors of different scaling: open each viewer while the main window is on the second monitor, then move an open viewer to the other monitor -> the window takes a size that fits the new scaling, the page fills the client, the Code Viewer's status bar text is not clipped, Find (Ctrl+F) and Go to line open readable on that monitor; in the Dark theme the menu bar and its pop-ups (and the Code Viewer's right-click menu) have the text size of that monitor (feature 424)
- [ ] Both viewers at 125 % and 150 % from the start (scaling set before signing in): the viewer opens where it opened in 0.3.0 with the same size, *Save position* restores the last place, and the page fills the client; a position saved by 0.3.0 on a second monitor of another scaling opens on that monitor, at most once larger or smaller, and is then kept (feature 424)
- [ ] Alt+F1 on a real screen, Fluent 2 and Classic icon set, Default and Dark theme: the *Desktop* item right after *Documents* has a Desktop folder icon (Classic: the blue Explorer Desktop folder), hot key `'` opens the Desktop folder as a disk path; the drive bar's Desktop button (tooltip *Desktop*) does the same (feature 425)
- [ ] Czech UI: Alt+F1 lists *Plocha* (hot key `'`) and the plug-in's *SloÄąÄľky Windows* (hot key `-`, the letters intact); pressing `-` opens `fld:`; Configuration > Change Drive Menu and Drive Bar shows the check box *Plocha*, unticking it hides the item and the button (feature 425)
- [ ] A Desktop redirected to a network share or a disconnected mapped drive (e.g. OneDrive or folder redirection to `\\server\share\Desktop`): the Desktop item reconnects or asks for the login as typing the path does, ESC cancels a slow check, and the panel stays where it was when it fails (feature 425)
- [ ] Inside Shell Folders (`fld:`): Enter on a folder shortcut (This PC > a network location added in Explorer) stays in `fld:` and lists the target; Enter on a junction or a directory symbolic link on the desktop opens it as a disk path (feature 425)
- [ ] Backlog app while the loop runs an item (feature 426): create an item in the app - the toast says "Landed on main as <hash>" and the item is on main; when the run ends its last message, the loop shows the item finished within about 30 s even if the run had scheduled a wakeup, and the live run page shows the same phase as the chat's run snapshot during the run
- [ ] Dark theme, on a real screen: the PictView viewer's toolbar (incl. the blue arrows and the disabled buttons), its status bar (dark, the crosshair / size / pipette icons light) and File Comparator (toolbar strip, "Difference" list dropped open, scrollbars, the frames of the views) have no light-grey part and every icon is readable (feature 427)
- [ ] With a PictView viewer and File Comparator open, switch Dark -> Default -> Dark (View menu or Configuration): every part follows at once - toolbars, status bar text and icons, scrollbars, File Comparator's strip - with nothing half-dark (feature 427)
- [ ] At 125 % or 150 % display scaling in Dark: PictView's status-bar icons are not stretched and the text after them is not cut (feature 427)

## Log

- 2026-11-06 — created (source manual)
- 2026-11-06 — body written: the release checklist runs append to (maintainer rule 2026-11-06)
- 2026-11-06 — moved to Person steps position 1
- 2026-11-06 — feature 404: 5 checks of the variant F tab strip
- 2026-11-06 — feature 405: 1 check of a tab switch that shows a question
- 2026-11-07 — edited Steps
- 2026-11-07 — edited Steps
- 2026-11-07 — edited Steps
- 2026-11-07 — edited Steps
- 2026-11-07 — feature 408: 3 checks added
- 2026-11-07 — feature 412: one check added
- 2026-11-07 — edited Steps
- 2026-11-07 — feature 416: 5 checks added
- 2026-11-07 — feature 417: 4 checks added
- 2026-11-07 — feature 418: 3 checks added
- 2026-11-08 — edited Steps
- 2026-11-08 — feature 419: one check added
- 2026-11-08 — edited Steps
- 2026-11-08 — feature 421: 5 checks added
- 2026-11-08 — feature 422: 4 checks added
- 2026-11-10 — feature 423 added 3 checks
- 2026-11-12 — feature 424: 3 checks added
- 2026-11-12 — feature 424: two checks widened (review 1)
- 2026-11-12 — edited Steps
- 2026-11-12 — step added by feature 426
- 2026-11-12 — 3 steps added by feature 427
