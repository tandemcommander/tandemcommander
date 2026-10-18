# Contract: the options allow-list (research R15)

Only values listed here are ever imported by the option groups. Kind `B` =
`REG_DWORD` 0/1 (any non-zero source value is taken as 1), `R a..b` =
`REG_DWORD` in the closed range, `M` = `REG_DWORD` bit mask taken as is. A
source value that is absent, of another type, or out of range is not
imported ("skipped: unexpected value"). Applying assigns the in-memory field;
the refresh of R6 then makes it visible. The authoritative table is
`CfgImpOptionTable` in `src/cfgimport.cpp`; `saltests` mirrors its names and
checks that none is forbidden by `SalCfgImpIsForbiddenOption`.

## `confirmations` — key `Configuration\Confirmation`, all `B`

Files or Dirs Del · Non-empty Dir Del · File Overwrite · Directory Overwrite ·
SH File Del · SH Dir Del · SH File Overwrite · NTFS Compress and Uncompress ·
NTFS Encrypt and Decrypt · Drag and Drop · Close Archive · Close Find · Stop
Find · Create Target Path · Always on Top · Close Salamander · Send Email ·
Add To Archive · Create Dir · Change Dir TC · Show Names To Compare · DST
Shifts Ignored · DST Shifts Occured · Copy Move Options Not Supported

## `panelopts` — key `Configuration`

`B`: Select/Deselect Directories · Primary Context Menu · Hide Hidden and
System Files and Directories · Single Click · Click to Quick Rename · Quick
Search Enter Alt · Use Shift For GoTo HotPath · Full Row Select · Full Row
Highlight · Use Icon Tincture · Show Panel Caption · Show Panel Zoom · Sort
Uses Locale · Sort Detects Numbers · Sort Newer On Top · Sort Dirs By Name ·
Sort Dirs By Ext · Quick Rename Select All · Edit New File Select All · Use
DragDrop Min Time
`R`: File Name Format (the values the Configuration dialog offers; 1 is
converted to 7 as `LoadConfig` does) · Size Format · Thumbnail Size (the
dialog's range) · DragDrop Min Time (the dialog's range)

## `general` — key `Configuration` (+ `Drive Special Settings`)

`B`: Clear Readonly Attribute · Close Shell Window · Status Area · Save
History · Save Working Dirs · Enable CmdLine History · Save CmdLine History ·
Show Errors In Find Files · Show Full Row In Find Files · Use Speeker Beep ·
Copy Find Text · Netware Fast Dir Move · Async Copy Alg On Network · Reload
Environment Variables · Title bar show path · Title bar prefix · Change Drive
Show My Documents · Change Drive Show Another · Change Drive Show Cloud
Storages · Change Drive Network · Compare By Time · Compare By Size · Compare
By Content · Compare By Attr · Compare By Subdirs · Compare By Subdirs Attr ·
Compare One Panel Dirs · Compare More Options · Compare Ignore Files · Compare
Ignore Dirs · Use Time Resolution · Ignore DST Shifts
`R`: Use Recycle Bin (0..2) · Title bar mode (the dialog's values) · Time
Resolution (the dialog's range)
*Units* (review round 1): an option and the value it depends on are taken over
together or not at all — Use Recycle Bin + Use Recycle Bin For (masks), Compare
Ignore Files + Compare Ignore Files Masks, Compare Ignore Dirs + Compare
Ignore Dirs Masks, Title bar prefix + Title bar prefix text. A companion that
is absent, too long (never cut) or invalid masks leaves the whole unit out
(reported). *Keep Plugins Sorted* is not on the list: taking it over would
re-order the plug-ins the next time the Plugins dialog opens (FR-013).
`M`: Visible Drives · Separated Drives
`Drive Special Settings`, all `B`: Floppy/Removable/Fixed/Remote/CDROM
Automatic Refresh · …Simple Icons · Remote Do Not Refresh on Activation

## `viewer` — key `Viewer`

`B`: EOL CRLF · EOL CR · EOL LF · EOL NULL · Wrap Text · Auto-Select ·
Auto-Copy Selection · Go to Offset Is Hex
`R`: Tabelator Size (the viewer's range) · Default Mode (the viewer's values),
as a unit with Text Masks; Hex Masks on its own (masks, validated)

## `defaultdirs` — key `Default Directories`

Values `A`…`Z`, `REG_SZ`, kept only when 057's filter F2 accepts them
(`SalCfgImpDefaultDirValid`).

## Never on the table (TC-owned, FR-016 — `SalCfgImpIsForbiddenOption`)

Theme Mode · Panel Tabs · Quick Search Filter · Command Shell Preset ·
Command Shell Program · Command Shell Arguments · Language · Use Alternate
Language for Plugins · Alternate Language for Plugins · Language Changed ·
Plugins.ver Version (x64) · Plugins.ver Version (x86) · Enable Custom Icon
Overlays · Disabled Custom Icon Overlays · Main window icon index ·
Conversion Table · Only One Instance · Last Focused Page · Configuration
Height · Viewers And Editors Expanded · Packers And Unpackers Expanded ·
Skill Level · Top ToolBar · Middle ToolBar · Left ToolBar · Right ToolBar ·
Save Configuration On Exit · Current Tip Index · Show Translation Is
Incomplete · Right Panel Focused · Command Line · Command Line Focused ·
the rebar layout values (Menu/ToolBar/PluginsBar/User Menu/Hot Paths/Drive
Bar Index/Break/Width, Grips Visible, User Menu Labels) · the bar visibility
values (Show … ToolBar/Bar, Hot Paths Bar) · Always On Top · window
placement values of `Viewer` (Save Window Position, Left, Right, Top, Bottom,
Show) and its search session values (Find Text, HEX-mode).
