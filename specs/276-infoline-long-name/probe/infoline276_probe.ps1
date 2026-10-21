<#
.SYNOPSIS
    Feature 276: focusing an item with a very long name shows "Expanded string is too large."
    (the information line's expansion, ItemFocused's 1000-byte buffer) - the information line
    must show the item without a box.

.DESCRIPTION
    Each case opens the left panel at a folder or archive holding 'a_short.txt', 'b_other.txt'
    and one long-named item (sorted last). The probe focuses a_short.txt (Home, Down - no box
    possible), captures the information line (PrintWindow of the main window, the info line's
    rectangle hashed), then posts End (the long item gets the focus) and serves the windows
    that appear. PASS = no window appeared AND the information line changed (with the old
    code the expansion failed and the line kept the short item's text).
      PIXCTL    control of the capture: a_short.txt vs b_other.txt must give different hashes
                (else the capture rows are NOT DRIVEN - the line's content is not observable)
      ARCCAP    a ZIP with a member of 200 CJK letters + '.txt' (604 bytes) at the top
      ARCMAX    a ZIP with a member of 251 CJK letters + '.txt' (757 bytes / 255 units, the listing's limit)
      ARCDEEP   a ZIP; the panel at a.zip\<84 CJK letters>, the member <200 CJK letters>.txt
      DISK      a disk folder with a file of 250 CJK letters + '.txt' (754 bytes, 254 units);
                the facts say whether Windows gave it a short (8.3) name
      ARCSHORT  a ZIP with only short names: End focuses 'c_last.txt' (control: no box before
                either)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc276'
$StartDir = $Root + '\start'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem, System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Cap276
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    // PrintWindow of the top-level window, the rectangle of 'part' cut out and hashed
    public static string Hash(IntPtr top, IntPtr part)
    {
        RECT tr, pr;
        if (!GetWindowRect(top, out tr) || !GetWindowRect(part, out pr)) return "<no rect>";
        int w = tr.Right - tr.Left, h = tr.Bottom - tr.Top;
        if (w <= 0 || h <= 0) return "<empty>";
        using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(bmp))
            {
                IntPtr dc = g.GetHdc();
                bool ok = PrintWindow(top, dc, 2 /* PW_RENDERFULLCONTENT */);
                g.ReleaseHdc(dc);
                if (!ok) return "<PrintWindow failed>";
            }
            var r = new Rectangle(pr.Left - tr.Left, pr.Top - tr.Top, pr.Right - pr.Left, pr.Bottom - pr.Top);
            r.Intersect(new Rectangle(0, 0, w, h));
            if (r.Width <= 0 || r.Height <= 0) return "<outside>";
            var data = bmp.LockBits(r, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try
            {
                var bytes = new byte[data.Stride * r.Height];
                Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
                int distinct = 0; var seen = new System.Collections.Generic.HashSet<int>();
                for (int i = 0; i + 3 < bytes.Length; i += 4) if (seen.Add(BitConverter.ToInt32(bytes, i)) && ++distinct > 64) break;
                using (var md5 = System.Security.Cryptography.MD5.Create())
                    return BitConverter.ToString(md5.ComputeHash(bytes)).Replace("-", "").Substring(0, 16) + "/" + distinct + "c";
            }
            finally { bmp.UnlockBits(data); }
        }
    }
}
'@

function Cjk([int]$From, [int]$Count) { return (-join ($From..($From + $Count - 1) | ForEach-Object { [char](0x4E00 + $_) })) }
$Cap = (Cjk 1 200) + '.txt'          # 604 bytes / 204 units
$Max = (Cjk 1 251) + '.txt'          # 757 bytes / 255 units (the longest name the ZIP listing takes)
$DeepDir = Cjk 300 84                # 252 bytes
$DiskName = (Cjk 600 250) + '.txt'   # 754 bytes / 254 units
$Shorts = @('a_short.txt', 'b_other.txt')

function Zip-Make([string]$Zip, [string[]]$Names) {
    $z = [IO.Compression.ZipFile]::Open($LP + $Zip, [IO.Compression.ZipArchiveMode]::Create)
    try { foreach ($n in $Names) { $e = $z.CreateEntry($n); $w = New-Object IO.StreamWriter($e.Open()); $w.Write('CONTENT'); $w.Dispose() } } finally { $z.Dispose() }
}
# the left panel's information line: the universal-window child of the panel right below the list
function Find-InfoLine([int]$Id) {
    $list = Get-LeftList $Id
    $panel = [Drv098f]::GetParent($list)
    $lr = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($list, [ref]$lr)
    $line = [IntPtr]::Zero; $best = 1e9
    foreach ($h in @([Drv098f]::Kids($panel) | Where-Object { [Drv098f]::Cls($_) -eq $LineClass -and [Drv098f]::GetParent($_) -eq $panel -and [Drv098f]::IsWindowVisible($_) })) {
        $wr = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($h, [ref]$wr)
        if ($wr.Top -ge $lr.Bottom - 1 -and $wr.Top -lt $best) { $best = $wr.Top; $line = $h }
    }
    return $line
}
function Snap([int]$Id) {
    [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 10000)
    Start-Sleep -Milliseconds 700
    $line = Find-InfoLine $Id
    if ($line -eq [IntPtr]::Zero) { return '<no info line>' }
    return [Cap276]::Hash((Get-Main $Id), $line)
}
function Post-Key([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv098f]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)
}
$script:PixOk = $null

# $Open: what the panel opens; the long item is the last one there
function Focus-Case([string]$Case, [string]$Open, [string]$LongName) {
    $id = 0; $before = Reports
    try {
        if (-not $Open.StartsWith($Root + '\')) { throw "typed path outside the fixture: $Open" }
        $id = Start-Tc $Open
        $r0 = Serve $id 3 @(1)
        Key $id 0x24; Key $id 0x28                         # Home, Down: a_short.txt
        $a = Snap $id
        Post-Key $id 0x23                                  # End: the long item
        $r = Serve $id 8 @(1)
        $b = Snap $id
        $boxes = $r.Messages.Count
        $changed = ($a -ne $b) -and ($a -notmatch '^<') -and ($b -notmatch '^<')
        if ($script:PixOk -eq $false) { $pix = 'NOT DRIVEN' } else { $pix = (V $changed) }
        $ok = ($boxes -eq 0) -and -not $r.Fatal
        Row $Case 'FOCUS' (V $ok) ("long item {0} bytes / {1} units; boxes {2}: {3}{4}" -f (U8Len $LongName), $LongName.Length, $boxes, (Tail (Msgs $r) 260), $(if ((Msgs $r0) -ne 'no window') { '; at the start: ' + (Tail (Msgs $r0) 200) } else { '' }))
        Row $Case 'LINE' $pix ("information line a_short.txt {0} -> long item {1} (changed {2})" -f $a, $b, $changed)
        End-Row $Case $id $r.Fatal $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

function PixCtl-Case([string]$Case, [string]$Open) {
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Open
        [void](Serve $id 3 @(1))
        Key $id 0x24; Key $id 0x28; $a = Snap $id         # a_short.txt
        Key $id 0x28; $b = Snap $id                        # b_other.txt
        $script:PixOk = ($a -ne $b) -and ($a -notmatch '^<') -and ($b -notmatch '^<')
        Row $Case 'RUN' $(if ($script:PixOk) { 'PASS' } else { 'NOT DRIVEN' }) ("a_short.txt {0}; b_other.txt {1}" -f $a, $b)
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc276_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("infoline276_probe (feature 276) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; TEMP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $TempRoot)
    Out ''
    $d = $Root + '\pix'; NewDir $d; Zip-Make "$d\a.zip" ($Shorts + 'c_last.txt')
    PixCtl-Case 'PIXCTL' "$d\a.zip"
    $d = $Root + '\arccap'; NewDir $d; Zip-Make "$d\a.zip" ($Shorts + $Cap)
    Focus-Case 'ARCCAP' "$d\a.zip" $Cap
    $d = $Root + '\arcmax'; NewDir $d; Zip-Make "$d\a.zip" ($Shorts + $Max)
    Focus-Case 'ARCMAX' "$d\a.zip" $Max
    $d = $Root + '\arcdeep'; NewDir $d; Zip-Make "$d\a.zip" @(($DeepDir + '/' + $Shorts[0]), ($DeepDir + '/' + $Shorts[1]), ($DeepDir + '/' + $Cap))
    Focus-Case 'ARCDEEP' ("$d\a.zip\" + $DeepDir) $Cap
    $d = $Root + '\disk'; NewDir $d
    foreach ($n in ($Shorts + $DiskName)) { WriteFile "$d\$n" 'CONTENT' }
    $fso = New-Object -ComObject Scripting.FileSystemObject
    $short = '?'; try { $short = $fso.GetFile($LP + "$d\$DiskName").ShortName } catch { $short = '<' + $_.Exception.Message + '>' }
    Out ("DISK: the long file's short (8.3) name: '{0}'" -f $short)
    Focus-Case 'DISK' $d $DiskName
    $d = $Root + '\arcshort'; NewDir $d; Zip-Make "$d\a.zip" ($Shorts + 'c_last.txt')
    Focus-Case 'ARCSHORT' "$d\a.zip" 'c_last.txt'
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
}
exit $nf
