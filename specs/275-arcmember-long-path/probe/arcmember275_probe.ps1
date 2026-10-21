<#
.SYNOPSIS
    Feature 275: F3 / F4 of an archive member whose path inside the archive has 520 bytes or more
    (feature 095's limit, lifted) - the temporary copy's rule (259 UTF-16 units, feature 260) is
    the only length refusal left.

.DESCRIPTION
      VIEWCAP   a ZIP with a top-level member of 200 CJK letters + '.txt' (604 bytes, 204 units);
                End, F3 (742): PASS = a viewer window opens (no "too long" message)
      VIEWDEEP  a ZIP entry <84 CJK letters>/<100 CJK letters>.txt (557 bytes inside the archive);
                the panel opened at a.zip\<folder>; F3: PASS = a viewer opens
      EDITCAP   the 604-byte member; F4 (743): an editor starts; the probe ends it, writes new
                content into the temporary copy, leaves the archive and answers the update question:
                PASS = the archive has ONE member, under the whole name, with the new content
      7Z        a .7z made by 7z.exe holding the 604-byte member; F3: PASS = a viewer opens
                (NOT DRIVEN when C:\Program Files\7-Zip\7z.exe is missing)
      TAR       a GNU tar built here (././@LongLink 'L' header + the regular header) holding the
                604-byte member; F3: PASS = a viewer opens
      OVERLIMIT a member of 250 letters + '.txt' (254 units - %TEMP%\SALxxxx.tmp\ + it is over 259
                units): F3: PASS = the "too long" message (the cache's refusal kept)
      CTL       a member 'short.txt': F3 opens a viewer (control)
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
$Root = $TempRoot + '\tc275'
$StartDir = $Root + '\start'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$SevenZip = 'C:\Program Files\7-Zip\7z.exe'

function Cjk([int]$From, [int]$Count) { return (-join ($From..($From + $Count - 1) | ForEach-Object { [char](0x4E00 + $_) })) }
$Cap = (Cjk 1 200) + '.txt'                       # 604 bytes / 204 units
$DeepDir = Cjk 300 84                             # 252 bytes
$DeepName = (Cjk 500 100) + '.txt'                # 304 bytes

function Zip-One([string]$Zip, [string]$Name) {
    $z = [IO.Compression.ZipFile]::Open($LP + $Zip, [IO.Compression.ZipArchiveMode]::Create)
    try { $e = $z.CreateEntry($Name); $w = New-Object IO.StreamWriter($e.Open()); $w.Write('CONTENT'); $w.Dispose() } finally { $z.Dispose() }
}
function Zip-Entries([string]$Zip) {
    $z = [IO.Compression.ZipFile]::Open($LP + $Zip, [IO.Compression.ZipArchiveMode]::Read)
    try {
        return @($z.Entries | ForEach-Object {
                $r = New-Object IO.StreamReader($_.Open()); $t = $r.ReadToEnd(); $r.Dispose()
                [pscustomobject]@{ Name = $_.FullName; Text = $t }
            })
    }
    finally { $z.Dispose() }
}
# a 512-byte GNU tar header (old GNU magic "ustar  \0")
function Tar-Header([byte[]]$Name, [long]$Size, [char]$Type) {
    $h = New-Object byte[] 512
    [Array]::Copy($Name, $h, [Math]::Min($Name.Length, 99))
    $put = { param($off, [string]$s) $b = [Text.Encoding]::ASCII.GetBytes($s); [Array]::Copy($b, 0, $h, $off, $b.Length) }
    & $put 100 '0000644'; & $put 108 '0000000'; & $put 116 '0000000'
    & $put 124 ([Convert]::ToString($Size, 8).PadLeft(11, '0'))
    & $put 136 ([Convert]::ToString([long]1700000000, 8).PadLeft(11, '0'))
    $h[156] = [byte][char]$Type
    & $put 257 'ustar  '
    for ($k = 148; $k -lt 156; $k++) { $h[$k] = 32 }
    $sum = 0; foreach ($b in $h) { $sum += $b }
    & $put 148 ([Convert]::ToString($sum, 8).PadLeft(6, '0')); $h[154] = 0; $h[155] = 32
    return $h
}
function Tar-One([string]$Tar, [string]$Name) {
    $ms = New-Object IO.MemoryStream
    $nb = $Utf8.GetBytes($Name)
    $ln = New-Object byte[] ($nb.Length + 1); [Array]::Copy($nb, $ln, $nb.Length)
    $w = { param([byte[]]$b) $ms.Write($b, 0, $b.Length); $pad = (512 - ($b.Length % 512)) % 512; if ($pad) { $ms.Write((New-Object byte[] $pad), 0, $pad) } }
    & $w (Tar-Header ([Text.Encoding]::ASCII.GetBytes('././@LongLink')) $ln.Length 'L')
    & $w $ln
    $data = [Text.Encoding]::ASCII.GetBytes('CONTENT')
    & $w (Tar-Header $nb $data.Length '0')
    & $w $data
    $ms.Write((New-Object byte[] 1024), 0, 1024)
    [IO.File]::WriteAllBytes($LP + $Tar, $ms.ToArray())
}
function SevenZip-One([string]$Arc, [string]$SrcDir, [string]$Name) {
    NewDir $SrcDir
    [IO.File]::WriteAllText($LP + $SrcDir + '\' + $Name, 'CONTENT', (New-Object Text.ASCIIEncoding))
    Push-Location -LiteralPath $SrcDir
    try { $o = & $SevenZip a -t7z $Arc '*' 2>&1 } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw ('7z.exe failed: ' + ($o -join ' ')) }
}
function Editors([datetime]$Since) {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object { @('notepad', 'notepad++', 'wordpad', 'write') -contains $_.ProcessName -and $_.StartTime -ge $Since })
}
function Find-TmpCopy([string]$Name, [string]$In) {
    foreach ($d in @([IO.Directory]::GetDirectories($LP + $In, 'SAL*.tmp'))) {
        $p = $d + '\' + $Name
        if ([IO.File]::Exists($p)) { return $p }
    }
    return $null
}

# F3 of the last item of the panel opened at $Open; $Make builds the archive
function View-Case([string]$Case, [string]$InArchive, [scriptblock]$Make, [string]$OpenSuffix, [bool]$ExpectRefusal) {
    $d = $Root + '\' + $Case; NewDir $d
    $id = 0; $before = Reports
    try {
        $arc = & $Make $d
        $open = $arc + $OpenSuffix
        if (-not $open.StartsWith($Root + '\')) { throw "typed path outside the fixture: $open" }
        $id = Start-Tc $open
        Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500
        $t = Which-Viewer $id
        $r = Serve $id 8 @(1)
        $refused = $t -match 'too long'
        $viewer = ($t -notmatch '^<')
        $ok = $(if ($ExpectRefusal) { $refused } else { $viewer -and -not $refused })
        Row $Case 'RUN' (V $ok) ("path inside the archive {0} bytes / {1} units; viewer {2}; refused {3}; F3: {4}{5}" -f (U8Len $InArchive), $InArchive.Length, $viewer, $refused, (Tail $t 220), $(if ((Msgs $r) -ne 'no window') { '; after: ' + (Tail (Msgs $r) 200) } else { '' }))
        [void](Do-ChangeDir $id $StartDir); [void](Serve $id 8 @(1, 7, 2))
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

# F4, edit the copy, leave the archive, update
function Edit-Case([string]$Case, [string]$Member) {
    $d = $Root + '\' + $Case; NewDir $d
    Zip-One "$d\a.zip" $Member
    $id = 0; $before = Reports; $t0 = Get-Date
    $in = $TempRoot
    try {
        $id = Start-Tc "$d\a.zip"
        Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500
        # focusing a member this long shows the information line's "Expanded string is too large."
        # (pre-existing, Inbox item focusing-an-archive-member-with-a-very-long-name-shows); while
        # that box is open the posted F4 is lost - it is answered first and reported
        $r0 = Serve $id 4 @(1)
        Post-Cmd (Get-Main $id) 743
        $r = Serve $id 15 @(1, 6)
        $m = Msgs $r
        if ((Msgs $r0) -ne 'no window') { $m = 'at the focus: ' + (Msgs $r0) + ' / F4: ' + $m }
        Start-Sleep -Milliseconds 1500
        $eds = @(Editors $t0)
        foreach ($p in $eds) { try { Stop-Process -Id $p.Id -Force } catch { } }
        Start-Sleep -Milliseconds 800
        $copy = Find-TmpCopy $Member $in
        $wrote = $false
        if ($copy) { [IO.File]::WriteAllText($copy, 'EDITED-CONTENT', (New-Object Text.ASCIIEncoding)); $wrote = $true }
        $r2 = Serve $id 6 @(1, 6)
        [void](Do-ChangeDir $id $StartDir)
        $r3 = Serve $id 30 @(1, 6)
        $ents = @(Zip-Entries "$d\a.zip")
        $ok = ($m -notmatch 'too long') -and $wrote -and $ents.Count -eq 1 -and $ents[0].Name -ceq $Member -and $ents[0].Text -ceq 'EDITED-CONTENT'
        $copyLen = $(if ($copy) { '{0} bytes / {1} units' -f (U8Len $copy.Substring($LP.Length)), $copy.Substring($LP.Length).Length } else { '-' })
        Row $Case 'RUN' (V $ok) ("member {0} bytes; editor processes {1}; temporary copy found {2} ({3}); archive members {4}: {5}; F4: {6}; leaving: {7}" -f (U8Len $Member), $eds.Count, $wrote, $copyLen, $ents.Count, (Tail (($ents | ForEach-Object { '{0} bytes "{1}"' -f (U8Len $_.Name), $_.Text }) -join ' | ') 160), (Tail $m 200), (Tail ((Msgs $r2) + ' / ' + (Msgs $r3)) 300))
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc275_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("arcmember275_probe (feature 275) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; TEMP {2} ({3} units)" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $TempRoot, $TempRoot.Length)
    Out ''
    View-Case 'VIEWCAP' $Cap { param($d) Zip-One "$d\a.zip" $Cap; "$d\a.zip" } '' $false
    View-Case 'VIEWDEEP' ($DeepDir + '\' + $DeepName) { param($d) Zip-One "$d\a.zip" ($DeepDir + '/' + $DeepName); "$d\a.zip" } ('\' + $DeepDir) $false
    Edit-Case 'EDITCAP' $Cap
    if (Test-Path -LiteralPath $SevenZip) {
        View-Case '7Z' $Cap { param($d) SevenZip-One "$d\a.7z" "$d\src" $Cap; "$d\a.7z" } '' $false
    }
    else { Row '7Z' 'RUN' 'NOT DRIVEN' "$SevenZip is missing" }
    View-Case 'TAR' $Cap { param($d) Tar-One "$d\a.tar" $Cap; "$d\a.tar" } '' $false
    View-Case 'OVERLIMIT' (('a' * 250) + '.txt') { param($d) Zip-One "$d\a.zip" (('a' * 250) + '.txt'); "$d\a.zip" } '' $true
    View-Case 'CTL' 'short.txt' { param($d) Zip-One "$d\a.zip" 'short.txt'; "$d\a.zip" } '' $false
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
