<#
.SYNOPSIS
    Feature 289 probe: the texts of the Change Drive menu, the drive bar tooltips and the panel's
    folder type names are UTF-8 (they were code page).

.DESCRIPTION
    Debug build with the probe seam TC_PROBE_DRIVES_DUMP (specs/246-network-drive-labels/contracts/
    probe-seam.md + specs/289-drive-list-wide-texts/contracts/probe-seam.md). For each language
    module (English, Czech) the probe starts tandemcommander.exe with the seam on, opens and closes
    the Change Drive menu (Alt+F1, command 707), shows the drive bars (command 756) and reads the
    dump as bytes:
      TYPES-<lang>  the TYPES line: valid UTF-8; folder = SHGetFileInfoW(SHGFI_TYPENAME) of the
                    system directory; updir = the language's "Upper Directory"
      ITEM-<lang>   every ITEM line valid UTF-8; the item of a fixed drive without a label reads
                    the language's "Local Drive"
      ALL-<lang>    every ALL line of a drive, cloud, Documents, Network or "As Other Panel" item
                    valid UTF-8; the Documents item (and the Network / "As Other Panel" items when
                    listed) read the language's words
      TIP-<lang>    every TIP line valid UTF-8; the unlabelled fixed drive's tooltip starts with
                    the language's "Local Drive" + " ("
    The ALL rows leave out hot paths and plug-in items (the user's own data); the TIP rows check
    every tooltip the drive bar build asks for - a hot path's tooltip is empty, a plug-in item's
    is its command name.
    -DecodedFile receives every checked line decoded the way the sinks decode it (UTF-8, else the
    code page), free-space parts removed, for the before / after comparison (SC-002).

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs.
    Backs up and restores HKCU\Software\Tandem Commander (SHA-256 verified). Exit code = number
    of FAIL rows.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$DecodedFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Sh289' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Sh289
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct SHFILEINFOW { public IntPtr hIcon; public int iIcon; public uint dwAttributes;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szDisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)] public string szTypeName; }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr SHGetFileInfoW(string path, uint attr, ref SHFILEINFOW fi, uint cb, uint flags);
    public static string TypeName(string path)
    {
        var fi = new SHFILEINFOW();
        if (SHGetFileInfoW(path, 0, ref fi, (uint)Marshal.SizeOf(fi), 0x400) == IntPtr.Zero) return null;
        return fi.szTypeName;
    }
}
'@
}

$Root = $TempRoot + '\tc289'
$StartDir = $Root + '\start'
$Strict = New-Object Text.UTF8Encoding($false, $true)
$Acp = [Text.Encoding]::GetEncoding([int][Drv098f]::GetACP())
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$Decoded = New-Object System.Collections.ArrayList

# the Czech texts from the translation the language module is built from (UTF-8)
function SltText([string]$Lang, [int]$Id) {
    $file = Join-Path $Repo ('translations\' + $Lang + '\salamand.slt')
    foreach ($l in [IO.File]::ReadAllLines($file, $Utf8)) {
        if ($l.StartsWith('' + $Id + ',')) { $q = $l.IndexOf('"'); return $l.Substring($q + 1, $l.Length - $q - 2) }
    }
    throw "string $Id not found in $file"
}
$Langs = @(
    @{ Name = 'english'; Local = 'Local Drive'; Docs = 'Documents'; Net = 'Network'; Other = 'As Other Panel'; UpDir = 'Upper Directory' },
    @{ Name = 'czech'; Local = (SltText 'czech' 10814); Docs = (SltText 'czech' 10927); Net = (SltText 'czech' 10191); Other = (SltText 'czech' 10192); UpDir = (SltText 'czech' 12220) }
)
$FolderType = [Sh289]::TypeName([Environment]::SystemDirectory)

# a dump line: bytes -> (valid UTF-8?, the text as the sinks show it)
function Dec([byte[]]$B) {
    try { return @{ Ok = $true; Text = $Strict.GetString($B) } }
    catch { return @{ Ok = $false; Text = $Acp.GetString($B) } }
}
function Read-Dump([string]$File) {
    $lines = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $File)) { return $lines }
    $b = [IO.File]::ReadAllBytes($File); $s = 0
    for ($i = 0; $i -lt $b.Length - 1; $i++) {
        if ($b[$i] -eq 13 -and $b[$i + 1] -eq 10) {
            $n = $i - $s; $part = New-Object byte[] $n; [Array]::Copy($b, $s, $part, 0, $n)
            $d = Dec $part; [void]$lines.Add($d); $s = $i + 2; $i++
        }
    }
    return $lines
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000); Start-Sleep -Milliseconds 300 }
function Wait-Menu([int]$Id, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        $m = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq 'PopupMenuClass' }) | Select-Object -First 1
        if ($m) { Start-Sleep -Milliseconds 400; return $m }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
# the unlabelled fixed drives of this machine (their item / tooltip carries "Local Drive")
$Unlabelled = @(Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 -and [string]::IsNullOrEmpty($_.VolumeName) } | ForEach-Object { $_.DeviceID.Substring(0, 1).ToUpperInvariant() })

function Run-Lang($L) {
    $lang = $L.Name
    $dump = $Root + '\dump_' + $lang + '.txt'
    & reg.exe add "$RegKey\Settings\Configuration" /v 'Language' /t REG_SZ /d ($lang + '.slg') /f | Out-Null
    $env:TC_PROBE_DRIVES_DUMP = $dump
    $id = 0
    try {
        $id = Start-Tc $StartDir
        Post-Cmd (Get-Main $id) 707   # CM_LCHANGEDRIVE (Alt+F1)
        $m = Wait-Menu $id
        if ($m -ne [IntPtr]::Zero) {
            [void][Drv098f]::PostMessageW($m, 0x0100, [IntPtr]0x1B, [IntPtr]1)
            [void][Drv098f]::PostMessageW($m, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001)
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($m)) { Start-Sleep -Milliseconds 100 }
        }
        Sync $id
        Post-Cmd (Get-Main $id) 756   # CM_TOGGLEDRIVEBAR2: the drive bar BUILD asks every tooltip
        Start-Sleep -Milliseconds 1500; Sync $id
        Stop-Tc $id; $id = 0
    }
    finally {
        if ($id) { Kill-Mine $id }
        Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
    }
    $lines = Read-Dump $dump
    Out ("[{0}] menu opened {1}; dump lines {2}" -f $lang, ($m -ne [IntPtr]::Zero), $lines.Count)

    # TYPES
    $t = @($lines | Where-Object { $_.Text.StartsWith('TYPES ') })
    if (-not $t.Count) { Row ('TYPES-' + $lang) 'RUN' 'FAIL' 'no TYPES line' }
    else {
        $allOk = @($t | Where-Object { -not $_.Ok }).Count -eq 0
        $x = $t[0].Text; $u = $x.IndexOf(' updir=')
        $folder = $x.Substring(13, $u - 13); $updir = $x.Substring($u + 7)
        $ok = $allOk -and ($folder -ceq $FolderType) -and ($updir -ceq $L.UpDir)
        Row ('TYPES-' + $lang) 'RUN' (V $ok) ("utf8 {0}; folder '{1}' (Windows '{2}'); updir '{3}' (expected '{4}')" -f $allOk, (Esc $folder), (Esc $FolderType), (Esc $updir), (Esc $L.UpDir))
        foreach ($e in $t) { [void]$Decoded.Add($lang + ' ' + $e.Text) }
    }

    # ITEM (drives of the list, menu and bar builds)
    $it = @($lines | Where-Object { $_.Text.StartsWith('ITEM ') })
    $bad = @($it | Where-Object { -not $_.Ok })
    $localOk = $true; $seen = 0
    foreach ($e in $it) {
        $p = $e.Text.Split([char]9)
        $letter = $e.Text.Substring(5, 1).ToUpperInvariant()
        $text = if ($p.Length -ge 2) { $p[1] } else { '' }
        if ($Unlabelled -contains $letter) { $seen++; if ($text -cne $L.Local) { $localOk = $false } }
        [void]$Decoded.Add($lang + ' ' + $p[0] + [char]9 + $text)   # free space removed
    }
    $ok = $it.Count -gt 0 -and $bad.Count -eq 0 -and $localOk -and ($seen -gt 0 -or -not $Unlabelled.Count)
    Row ('ITEM-' + $lang) 'RUN' (V $ok) ("{0} lines, {1} not UTF-8; unlabelled drives {2} -> '{3}' x{4} {5}; e.g. {6}" -f $it.Count, $bad.Count, ($Unlabelled -join ','), (Esc $L.Local), $seen, $localOk, ($(if ($bad.Count) { Esc $bad[0].Text } else { '-' })))

    # ALL (whole list; drives, cloud, Documents, Network only)
    $al = @($lines | Where-Object { $_.Text.StartsWith('ALL ') } | Where-Object {
            $ty = [int]($_.Text -replace '^ALL idx=\d+ type=(\d+) .*$', '$1'); $ty -ge 1 -and $ty -le 14 })
    $bad = @($al | Where-Object { -not $_.Ok })
    $docs = @($al | Where-Object { $_.Text -match ' type=7 ' } | ForEach-Object { $_.Text.Split([char]9)[1] })
    $nets = @($al | Where-Object { $_.Text -match ' type=13 ' } | ForEach-Object { $_.Text.Split([char]9)[1] })
    $docsOk = $docs.Count -gt 0 -and @($docs | Where-Object { $_ -cne $L.Docs }).Count -eq 0
    $netsOk = @($nets | Where-Object { $_ -cne $L.Net }).Count -eq 0
    $others = @($al | Where-Object { $_.Text -match ' type=14 ' } | ForEach-Object { $_.Text.Split([char]9)[1] })
    $netsOk = $netsOk -and (@($others | Where-Object { $_ -cne $L.Other }).Count -eq 0)
    foreach ($e in $al) { $p = $e.Text.Split([char]9); [void]$Decoded.Add($lang + ' ' + $p[0] + [char]9 + $(if ($p.Length -ge 2) { $p[1] } else { '' })) }
    $ok = $al.Count -gt 0 -and $bad.Count -eq 0 -and $docsOk -and $netsOk
    Row ('ALL-' + $lang) 'RUN' (V $ok) ("{0} lines, {1} not UTF-8; Documents {2} ('{3}'); Network items {4} ('{5}'), As Other Panel items {8} ('{9}') {6}; e.g. {7}" -f $al.Count, $bad.Count, $docsOk, (Esc $L.Docs), $nets.Count, (Esc $L.Net), $netsOk, ($(if ($bad.Count) { Esc $bad[0].Text } else { '-' })), $others.Count, (Esc $L.Other))

    # TIP
    $tp = @($lines | Where-Object { $_.Text.StartsWith('TIP ') })
    $bad = @($tp | Where-Object { -not $_.Ok })
    $tipOk = $true; $seen = 0
    foreach ($e in $tp) {
        $letter = $e.Text.Substring(4, 1).ToUpperInvariant(); $text = $e.Text.Substring(6)
        if ($Unlabelled -contains $letter) { $seen++; if (-not $text.StartsWith($L.Local + ' (')) { $tipOk = $false } }
        $k = $text.LastIndexOf(' ('); if ($k -gt 0 -and $text.EndsWith(')')) { $text = $text.Substring(0, $k) }   # free space removed
        [void]$Decoded.Add($lang + ' TIP ' + $letter + ' ' + $text)
    }
    $ok = $tp.Count -gt 0 -and $bad.Count -eq 0 -and $tipOk -and ($seen -gt 0 -or -not $Unlabelled.Count)
    Row ('TIP-' + $lang) 'RUN' (V $ok) ("{0} lines, {1} not UTF-8; unlabelled tooltips x{2} start '{3} (' {4}; e.g. {5}" -f $tp.Count, $bad.Count, $seen, (Esc $L.Local), $tipOk, ($(if ($bad.Count) { Esc $bad[0].Text } else { '-' })))
}

$backup = Join-Path $env:TEMP 'tc289_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("run289 (feature 289) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; UI culture {3}; unlabelled fixed drives {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), (Get-UICulture).Name, ($Unlabelled -join ','))
    Out ''
    foreach ($L in $Langs) {
        try { Run-Lang $L }
        catch { Row ('RUN-' + $L.Name) 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
    if ($DecodedFile) { [IO.File]::WriteAllLines($DecodedFile, [string[]]($Decoded | ForEach-Object { Esc $_ }), (New-Object Text.ASCIIEncoding)) }
}
exit $nf
