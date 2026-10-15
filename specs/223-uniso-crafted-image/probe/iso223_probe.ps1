<#
.SYNOPSIS
    Feature 223 regression: valid ISO images still open in the ISO plug-in and a file is extracted
    with its content - one made by Windows' IMAPI2 (ISO 9660 + Joliet), one by genisoimage with Rock
    Ridge names (in a throw-away Debian container; NOT DRIVEN without Docker or the network).

.DESCRIPTION
      ISO-F5   the image holds folder\note.txt and top.txt; inside the image End focuses top.txt,
               F5 (727) to the other panel: PASS = top.txt extracted with its content
      RR-LONG  a Rock Ridge image holding even1.txt, odd12.txt and a file of a 200-letter name: End
               focuses the long one (sorted last), F5: PASS = extracted under its whole Rock Ridge
               name with its content
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc223'
$StartDir = $Root + '\start'

if (-not ('Iso223' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class Iso223
{
    // copies the IMAPI2 result stream (an IStream) into a file
    public static void Save(object stream, string path)
    {
        IStream s = (IStream)stream;
        using (FileStream f = File.Create(path))
        {
            byte[] buf = new byte[65536];
            IntPtr readPtr = Marshal.AllocCoTaskMem(4);
            try
            {
                while (true)
                {
                    s.Read(buf, buf.Length, readPtr);
                    int n = Marshal.ReadInt32(readPtr);
                    if (n <= 0) break;
                    f.Write(buf, 0, n);
                }
            }
            finally { Marshal.FreeCoTaskMem(readPtr); }
        }
    }
}
'@
}

function Make-Iso([string]$SrcDir, [string]$IsoPath) {
    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = 3   # ISO 9660 + Joliet
    $fsi.VolumeName = 'TC223'
    $fsi.Root.AddTree($SrcDir, $false)
    $res = $fsi.CreateResultImage()
    [Iso223]::Save($res.ImageStream, $IsoPath)
}

$backup = Join-Path $env:TEMP 'tc223_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso223_probe (feature 223) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    $d = $Root + '\ISO-F5'; NewDir $d; NewDir "$d\src"; NewDir "$d\src\folder"; NewDir "$d\tgt"
    [IO.File]::WriteAllText("$d\src\folder\note.txt", 'NOTE')
    [IO.File]::WriteAllText("$d\src\top.txt", 'TOP')
    Make-Iso "$d\src" "$d\a.iso"
    $id = 0; $before = Reports; $save = $StartDir; $StartDir = "$d\tgt"
    try {
        $id = Start-Tc "$d\a.iso"; $StartDir = $save
        $r0 = Serve $id 6 @(1)
        Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 30 @(1, 6)
        $got = ''; try { $got = [IO.File]::ReadAllText("$d\tgt\top.txt") } catch { }
        Row 'ISO-F5' 'RUN' (V ($got -ceq 'TOP')) ("location '{0}'; top.txt extracted with its content {1}; at the open: {2}; F5: {3}" -f (Tail (Get-Loc $id) 60), ($got -ceq 'TOP'), (Tail (Msgs $r0) 150), (Tail (Msgs $r) 200))
        End-Row 'ISO-F5' $id $null $before; $id = 0
    }
    catch { Row 'ISO-F5' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { $StartDir = $save; if ($id) { End-Row 'ISO-F5' $id $null $before } }

    # a Rock Ridge image made by genisoimage (Debian container)
    $d = $Root + '\RR-LONG'; NewDir $d; NewDir "$d\src"; NewDir "$d\tgt"
    $longName = ('z' + ('r' * 195) + '.txt')   # sorted after the others
    [IO.File]::WriteAllText("$d\src\even1.txt", 'E')
    [IO.File]::WriteAllText("$d\src\odd12.txt", 'O')
    [IO.File]::WriteAllText("$d\src\$longName", 'LONG')
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $dock = & docker run --rm -v ("{0}:/w" -f $d) debian:bookworm-slim sh -c 'apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq genisoimage >/dev/null 2>&1 && genisoimage -quiet -R -o /w/rr.iso /w/src' 2>&1
    $ErrorActionPreference = $old
    if (-not [IO.File]::Exists("$d\rr.iso")) { Row 'RR-LONG' 'RUN' 'NOT DRIVEN' ('no Rock Ridge image: ' + (($dock | ForEach-Object { "$_" }) -join ' ')) }
    else {
        $id = 0; $before = Reports; $save = $StartDir; $StartDir = "$d\tgt"
        try {
            $id = Start-Tc "$d\rr.iso"; $StartDir = $save
            $r0 = Serve $id 6 @(1)
            Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500
            Post-Cmd (Get-Main $id) 727
            $r = Serve $id 30 @(1, 6)
            $got = ''; try { $got = [IO.File]::ReadAllText("$d\tgt\$longName") } catch { }
            $names = (@([IO.Directory]::GetFiles("$d\tgt") | ForEach-Object { [IO.Path]::GetFileName($_).Length }) -join ',')
            Row 'RR-LONG' 'RUN' (V ($got -ceq 'LONG')) ("the 200-letter name extracted with its content {0}; extracted name lengths: {1}; at the open: {2}; F5: {3}" -f ($got -ceq 'LONG'), $names, (Tail (Msgs $r0) 150), (Tail (Msgs $r) 150))
            End-Row 'RR-LONG' $id $null $before; $id = 0
        }
        catch { Row 'RR-LONG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { $StartDir = $save; if ($id) { End-Row 'RR-LONG' $id $null $before } }
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
}
exit $nf
