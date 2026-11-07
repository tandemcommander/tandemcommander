# Data model - 417

## Plug-in id

| | |
|---|---|
| Values | `7zip automation checksum checkver codeview dbviewer demomenu demoplug demoview diskmap filecomp folders ftp mdview mmviewer nethood peviewer pictview portables regedt renamer sftp tar uncab unchm undelete uniso unmime unole unrar zip` (31, lower case) |
| From | `CPluginData::DLLName` / `CPluginFSInterfaceEncapsulation::GetDLLName()`: exactly `<a>\<b>.spl`, `a` == `b` ignoring ASCII case, `a` in the list |
| Not an id | an absolute path, a drive or colon, `/`, more or fewer than one `\`, another extension, `a` != `b`, an unknown name, non-ASCII bytes |

## Plug-in set icon (file)

| Field | Rule |
|---|---|
| Standard | `<program>\iconsets\fluent\plugins\<id>.svg` |
| Dark | `<program>\iconsets\fluent\plugins\dark\<id>.svg` - used verbatim in the Dark theme when it parses with shapes |
| Defaults | `_plugin.svg` (a plug-in without an icon), `_pluginfs.svg` (a file system without an icon) |
| Classic | no plug-in folder: no set icon at all |
| Usable | 416's rule (`SalIconSetChooseSource`): dark if usable in Dark, else the standard file (adapted in Dark), else none |

## Site decision (per drawing)

```text
Fluent 2 active?  no  -> today's code
known id?         no  -> today's code (a default icon: Fluent 2 default if usable, else today's default)
fsIcon and id == folders -> today's code (GetFSIcon)
set file renders? no  -> today's code
                  yes -> the set icon at the site's size (gray copy by today's rule when the site wants gray)
```

## Identity-icon file systems

`ftp sftp regedt undelete portables nethood demoplug` - yes; `folders` - no (its icon is the current folder's).
