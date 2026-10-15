<#
.SYNOPSIS
    Feature 222: a name of an archive member longer than 256 BYTES of UTF-8 but within the 255
    UTF-16 units a Windows file system takes is a valid name - F4 (Edit) of it is not refused
    "Name of this file is invalid on Windows file systems".

.DESCRIPTION
      LONG   a ZIP with a member of 90 CJK letters + '.txt' (274 bytes, 94 units); inside the
             archive, End focuses it, F4 (743): PASS = the archive opens ("Cannot add file to the
             list." before) and no "invalid on Windows" refusal (the editor is started, or the
             disk cache refuses a name too long for its folder - the probe ends every editor)
      F5LONG the same archive, F5 (727) to the other panel: PASS = the member extracted under its
             whole name
      CTL    a member 'short.txt' - the control
      DIRLONG a ZIP with 'keep.txt' and a FOLDER of 90 CJK letters holding x.txt; F5 of keep.txt:
             PASS = the archive opens (the folder skipped with "Some directories or files may be
             missing" - folders keep the 255-byte limit: their contents' path part is limited) and
             keep.txt is extracted
      BAD    a member 'bad.txt.' (a trailing dot - invalid on Windows): PASS = the message (the
             refusal kept)
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
$Root = $TempRoot + '\tc222'
$StartDir = $Root + '\start'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

function Zip-One([string]$Zip, [string]$Name) {
    $z = [IO.Compression.ZipFile]::Open($LP + $Zip, [IO.Compression.ZipArchiveMode]::Create)
    try { $e = $z.CreateEntry($Name); $w = New-Object IO.StreamWriter($e.Open()); $w.Write('CONTENT'); $w.Dispose() } finally { $z.Dispose() }
}
function Editors([datetime]$Since) {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object { @('notepad', 'notepad++', 'wordpad', 'write') -contains $_.ProcessName -and $_.StartTime -ge $Since })
}

function Run-Case([string]$Case, [string]$Member, [bool]$ExpectRefusal) {
    $d = $Root + '\' + $Case; NewDir $d
    Zip-One "$d\a.zip" $Member
    $id = 0; $before = Reports; $t0 = Get-Date
    try {
        $id = Start-Tc "$d\a.zip"
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) 743
        $r = Serve $id 15 @(1, 6)
        $m = Msgs $r
        $eds = @(Editors $t0)
        $refused = $m -match 'Unable to edit|Cannot add file'
        foreach ($p in $eds) { try { Stop-Process -Id $p.Id -Force } catch { } }
        Start-Sleep -Milliseconds 800
        $r2 = Serve $id 10 @(7, 2, 1)   # a question after the editor ended: No / Cancel
        [void](Do-ChangeDir $id $StartDir)   # leave the archive: its "about to close" note answered here
        $r3 = Serve $id 8 @(1, 7, 2)
        $ok = $(if ($ExpectRefusal) { $refused } else { -not $refused })
        Row $Case 'RUN' (V $ok) ("member {0} bytes / {1} units; refused {2}; editor processes {3}; windows: {4}{5}" -f [Text.Encoding]::UTF8.GetByteCount($Member), $Member.Length, $refused, $eds.Count, (Tail $m 300), $(if ((Msgs $r2) -ne 'no window') { '; after: ' + (Tail (Msgs $r2) 200) } else { '' }))
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc222_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("editname222_probe (feature 222) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    Run-Case 'LONG' ((-join (1..90 | ForEach-Object { [char](0x4E00 + $_) })) + '.txt') $false
    Run-Case 'CTL' 'short.txt' $false
    # F5 out of the archive to the other panel
    $long = (-join (1..90 | ForEach-Object { [char](0x4E00 + $_) })) + '.txt'
    $d = $Root + '\F5LONG'; NewDir $d; NewDir "$d\tgt"; Zip-One "$d\a.zip" $long
    $id = 0; $before = Reports; $save = $StartDir; $StartDir = "$d\tgt"
    try {
        $id = Start-Tc "$d\a.zip"; $StartDir = $save
        Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 30 @(1, 6)
        $got = ''; try { $got = [IO.File]::ReadAllText($LP + "$d\tgt\" + $long) } catch { }
        Row 'F5LONG' 'RUN' (V ($got -ceq 'CONTENT')) ("extracted under the whole name {0}; windows: {1}" -f ($got -ceq 'CONTENT'), (Tail (Msgs $r) 300))
        End-Row 'F5LONG' $id $null $before; $id = 0
    }
    catch { Row 'F5LONG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { $StartDir = $save; if ($id) { End-Row 'F5LONG' $id $null $before } }
    # a folder of a long name next to a file: the folder skipped, the listing goes on
    $d = $Root + '\DIRLONG'; NewDir $d; NewDir "$d\tgt"
    $folder = (-join (1..90 | ForEach-Object { [char](0x4E00 + $_) }))
    $z = [IO.Compression.ZipFile]::Open($LP + "$d\a.zip", [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($n in @('keep.txt', ($folder + '/x.txt'))) { $e = $z.CreateEntry($n); $w = New-Object IO.StreamWriter($e.Open()); $w.Write('CONTENT'); $w.Dispose() }
    }
    finally { $z.Dispose() }
    $id = 0; $before = Reports; $save = $StartDir; $StartDir = "$d\tgt"
    try {
        $id = Start-Tc "$d\a.zip"; $StartDir = $save
        $r0 = Serve $id 8 @(1)
        Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500   # the last item: keep.txt (folders first)
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 30 @(1, 6)
        $got = ''; try { $got = [IO.File]::ReadAllText($LP + "$d\tgt\keep.txt") } catch { }
        $m0 = Msgs $r0
        $ended = $m0 -match 'Cannot add (file|directory) to the list\.'
        Row 'DIRLONG' 'RUN' (V ((-not $ended) -and $got -ceq 'CONTENT')) ("the listing ended {0}; keep.txt extracted {1}; at the open: {2}; F5: {3}" -f $ended, ($got -ceq 'CONTENT'), (Tail $m0 200), (Tail (Msgs $r) 200))
        End-Row 'DIRLONG' $id $null $before; $id = 0
    }
    catch { Row 'DIRLONG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { $StartDir = $save; if ($id) { End-Row 'DIRLONG' $id $null $before } }
    Run-Case 'BAD' 'bad.txt.' $true
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
