<#
.SYNOPSIS
    Feature 260: F3 / F4 of an archive member with a long valid name (the disk cache's temporary
    copy is limited by the Windows path, 259 UTF-16 units, not by 259 bytes); a gzip file's stored
    name is read whole, a name no file system takes is refused.

.DESCRIPTION
      VIEWLONG  a ZIP with a member of 90 CJK letters + '.txt' (274 bytes, 94 units); End, F3 (742):
                PASS = a viewer window opens (no "resulting filename is too long" message)
      EDITLONG  the same; F4 (743): an editor starts; the probe ends it, writes new content into the
                temporary copy (%TEMP%\SAL*.tmp\<name>), leaves the archive and answers the update
                question OK: PASS = the archive has ONE member, under the whole name, with the new
                content
      ARCCAP    a member of 200 CJK letters + '.txt' (604 bytes inside the archive): F3: PASS = the
                "too long" message (feature 095's 519-byte limit of the name handed to the archiver
                stays - review of 260, M1)
      OVERLIMIT a member of 250 letters + '.txt' (254 units - valid, but %TEMP%\SALxxxx.tmp\ + it is
                over 259 units): F3: PASS = the "too long" message (the refusal kept)
      CTL       a member 'short.txt': F3 opens a viewer (control)
      GZLONG    a .gz whose header stores the name 90 CJK letters + '.txt'; F5 (727) to the other
                panel: PASS = extracted under exactly that name
      GZOVER    a .gz storing a name of 300 letters + '.txt' (over 255 units): PASS = a "too long"
                message at the open and nothing in the target folder
      GZCTL     a .gz storing 'short.txt': F5: PASS = extracted as short.txt
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
$Root = $TempRoot + '\tc260'
$StartDir = $Root + '\start'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$Long = (-join (1..90 | ForEach-Object { [char](0x4E00 + $_) })) + '.txt'

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
function Crc32([byte[]]$Data) {
    # 64-bit arithmetic: the PowerShell literal 0xFFFFFFFF is the Int32 -1
    $mask = [long]4294967295; $poly = [long]3988292384   # 0xEDB88320
    $crc = $mask
    foreach ($b in $Data) {
        $crc = $crc -bxor [long]$b
        for ($k = 0; $k -lt 8; $k++) {
            if ($crc -band 1) { $crc = ($crc -shr 1) -bxor $poly } else { $crc = $crc -shr 1 }
        }
    }
    return [uint32](($crc -bxor $mask) -band $mask)
}
# a gzip file with FLG.FNAME and the stored name in UTF-8
function Gz-One([string]$Gz, [string]$StoredName) {
    $data = [Text.Encoding]::ASCII.GetBytes('CONTENT')
    $ms = New-Object IO.MemoryStream
    $hdr = [byte[]](0x1F, 0x8B, 8, 8, 0, 0, 0, 0, 0, 11)
    $ms.Write($hdr, 0, $hdr.Length)
    $nb = $Utf8.GetBytes($StoredName); $ms.Write($nb, 0, $nb.Length); $ms.WriteByte(0)
    $dm = New-Object IO.MemoryStream
    $ds = New-Object IO.Compression.DeflateStream($dm, [IO.Compression.CompressionMode]::Compress, $true)
    $ds.Write($data, 0, $data.Length); $ds.Dispose()
    $def = $dm.ToArray(); $ms.Write($def, 0, $def.Length)
    $ms.Write([BitConverter]::GetBytes((Crc32 $data)), 0, 4)
    $ms.Write([BitConverter]::GetBytes([uint32]$data.Length), 0, 4)
    [IO.File]::WriteAllBytes($LP + $Gz, $ms.ToArray())
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

# F3 of the last item of a one-member ZIP
function View-Case([string]$Case, [string]$Member, [bool]$ExpectRefusal) {
    $d = $Root + '\' + $Case; NewDir $d
    Zip-One "$d\a.zip" $Member
    $id = 0; $before = Reports
    try {
        $id = Start-Tc "$d\a.zip"
        Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500
        $t = Which-Viewer $id
        $r = Serve $id 8 @(1)
        $refused = $t -match 'too long'
        $viewer = ($t -notmatch '^<')
        $ok = $(if ($ExpectRefusal) { $refused } else { $viewer -and -not $refused })
        Row $Case 'RUN' (V $ok) ("member {0} bytes / {1} units; viewer {2}; refused {3}; F3: {4}{5}" -f (U8Len $Member), $Member.Length, $viewer, $refused, (Tail $t 220), $(if ((Msgs $r) -ne 'no window') { '; after: ' + (Tail (Msgs $r) 200) } else { '' }))
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
        Post-Cmd (Get-Main $id) 743
        $r = Serve $id 15 @(1, 6)
        $m = Msgs $r
        Start-Sleep -Milliseconds 1500
        $eds = @(Editors $t0)
        $edArgs = @($eds | ForEach-Object { Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue } | ForEach-Object { $_.CommandLine })
        foreach ($p in $eds) { try { Stop-Process -Id $p.Id -Force } catch { } }
        Start-Sleep -Milliseconds 800
        $copy = Find-TmpCopy $Member $in
        $where = ''
        if (-not $copy) {   # diagnostics: where did the program put it?
            $sys = Find-TmpCopy $Member $TempRoot
            $where = '; in the system TEMP: {0}; editor command line: {1}' -f $(if ($sys) { $sys.Substring($LP.Length) } else { '-' }), (Tail ($edArgs -join ' ') 400)
        }
        $wrote = $false
        if ($copy) { [IO.File]::WriteAllText($copy, 'EDITED-CONTENT', (New-Object Text.ASCIIEncoding)); $wrote = $true }
        $r2 = Serve $id 6 @(1, 6)
        [void](Do-ChangeDir $id $StartDir)
        $r3 = Serve $id 30 @(1, 6)
        $ents = @(Zip-Entries "$d\a.zip")
        $ok = ($m -notmatch 'too long') -and $wrote -and $ents.Count -eq 1 -and $ents[0].Name -ceq $Member -and $ents[0].Text -ceq 'EDITED-CONTENT'
        $copyLen = $(if ($copy) { '{0} bytes / {1} units' -f (U8Len $copy.Substring($LP.Length)), $copy.Substring($LP.Length).Length } else { '-' })
        Row $Case 'RUN' (V $ok) ("member {0} bytes; editor processes {1}; temporary copy found {2} ({3}); archive members {4}: {5}; F4: {6}; leaving: {7}" -f (U8Len $Member), $eds.Count, $wrote, $copyLen, $ents.Count, (Tail (($ents | ForEach-Object { '{0} bytes "{1}"' -f (U8Len $_.Name), $_.Text }) -join ' | ') 160), (Tail $m 200), ((Tail ((Msgs $r2) + ' / ' + (Msgs $r3)) 300) + $where))
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

# F5 of the member of a .gz to the other panel (or only the open, for a refused one)
function Gz-Case([string]$Case, [string]$Stored, [bool]$ExpectRefusal) {
    $d = $Root + '\' + $Case; NewDir $d; NewDir "$d\tgt"
    Gz-One "$d\a.gz" $Stored
    $id = 0; $before = Reports; $save = $StartDir; $StartDir = "$d\tgt"
    try {
        $id = Start-Tc "$d\a.gz"; $StartDir = $save
        $r0 = Serve $id 8 @(1)
        $m0 = Msgs $r0
        if ($ExpectRefusal) {
            $files = @([IO.Directory]::GetFileSystemEntries($LP + "$d\tgt"))
            $refused = $m0 -match 'too long|\(206\)'   # the system's text comes in the OS language: "(206) ..."
            Row $Case 'RUN' (V ($refused -and $files.Count -eq 0)) ("stored name {0} bytes / {1} units; refused {2}; files in the target {3}; at the open: {4}" -f (U8Len $Stored), $Stored.Length, $refused, $files.Count, (Tail $m0 250))
        }
        else {
            Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500
            Post-Cmd (Get-Main $id) 727
            $r = Serve $id 30 @(1, 6)
            $got = ''; try { $got = [IO.File]::ReadAllText($LP + "$d\tgt\" + $Stored) } catch { }
            $names = @([IO.Directory]::GetFileSystemEntries($LP + "$d\tgt") | ForEach-Object { [IO.Path]::GetFileName($_) })
            Row $Case 'RUN' (V ($got -ceq 'CONTENT' -and $names.Count -eq 1)) ("stored name {0} bytes / {1} units; extracted under the whole name {2}; target holds {3} ({4}); at the open: {5}; F5: {6}" -f (U8Len $Stored), $Stored.Length, ($got -ceq 'CONTENT'), $names.Count, (Tail ($names -join ' | ') 120), (Tail $m0 120), (Tail (Msgs $r) 200))
        }
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { $StartDir = $save; if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc260_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cache260_probe (feature 260) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; TEMP {2} ({3} units)" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $TempRoot, $TempRoot.Length)
    Out ''
    View-Case 'VIEWLONG' $Long $false

    Edit-Case 'EDITLONG' $Long
    # review of 260 (S1): a copy path over 620 bytes (the edit's way back held it in 620 bytes,
    # _TRUNCATE) needs a %TEMP% of about 88+ bytes - the name inside the archive stays under 520
    # bytes; it is not driven: the program regenerates its environment from the user's registry
    # (RegenerateUserEnvironment), a TEMP given to the started process is not used
    # review of 260 (M1): the name inside the archive is still limited to 519 bytes (feature 095 - the
    # longest name a plug-in has ever received): 200 CJK letters (604 bytes) keep the refusal
    View-Case 'ARCCAP' ((-join (1..200 | ForEach-Object { [char](0x4E00 + $_) })) + '.txt') $true
    View-Case 'OVERLIMIT' (('a' * 250) + '.txt') $true
    View-Case 'CTL' 'short.txt' $false
    Gz-Case 'GZLONG' $Long $false
    Gz-Case 'GZOVER' (('a' * 300) + '.txt') $true
    Gz-Case 'GZCTL' 'short.txt' $false
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
