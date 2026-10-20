<#
.SYNOPSIS
    Feature 274 probe: Create Directory (F7, command 730) with a relative name typed in a folder
    whose path is 260+ bytes - created whole, or refused for a reason that is true.

.DESCRIPTION
    Rows (names for -Only); every row starts its own instance in English and ends it:

      SHORT   the control: the panel in a short folder, "nd" typed - created
      REL     the panel in a folder whose path is 288 bytes, "nd" typed (relative) - created
      CJK     the panel in the 288-byte folder, a name of 100 CJK letters typed (300 bytes) - created
      U255    the panel in a short folder, 255 CJK letters (exactly 255 UTF-16 units) - created
      U256    the panel in a short folder, 256 CJK letters (more than a file system takes): nothing
              created, "too long name" shown
      LIMIT   the panel in the 288-byte folder, a relative path of 98,244 bytes typed (the joined
              path is longer than the program's limit, SAL_MAX_PATH_UTF8): nothing created,
              "The path specified is too long." shown
      MULTI   the panel in a short folder, "a\" + 256 CJK letters typed: nothing created (also no
              missing parent "a"), "too long name" shown

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.
.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }   # $PSScriptRoot is empty in a param default (PS 5.1)
. $Lib

$Root = $TempRoot + '\tc274'
$StartDir = $Root + '\start'
$Cjk = [string][char]0x4E2D
$Seg = 'd' * 60

function Deep([string]$Name) { return ($Root + '\' + $Name + '\' + $Seg + '\' + $Seg + '\' + $Seg + '\' + $Seg) }

function Start-P([string]$Left) {
    $a = @('-t', 'T274', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Dialogs([int]$Id) { return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) -and [Drv098f]::IsWindowVisible($_) }) }
function Short([string]$t) { $e = [regex]::Replace((Esc $t), '(?:\\u4E2D){8,}', '<CJK letters>'); $e = [regex]::Replace($e, '(?:d){20,}', '<d...>'); $e = [regex]::Replace($e, '(?:x){20,}', '<x...>'); if ($e.Length -le 420) { return $e }; return ($e.Substring(0, 420) + ' ...') }

# answers every dialog until none shows for $Quiet seconds: OK / Yes by id, else Close / Cancel.
# The text is typed into the first dialog with an edit; an edit dialog that comes back is cancelled.
function Answer([int]$Id, [string]$Type, [double]$Seconds = 60, [double]$Quiet = 4) {
    $texts = @(); $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew(); $typed = $false
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and $last.Elapsed.TotalSeconds -lt $Quiet -and (Test-Alive $Id)) {
        $acted = $false
        foreach ($h in (Dialogs $Id)) {
            $bs = Buttons $h
            if ($bs.Count -eq 0) { continue }
            Start-Sleep -Milliseconds 500
            $desc = WinDesc $h
            if ($desc -match $FatalRx) { $texts += ('FATAL ' + (Tail $desc 300)); return $texts }
            $edits = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) })
            $isMsg = (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2477 }).Count -gt 0)
            if (-not $isMsg -and $edits.Count -and -not $typed) {
                [void][Drv098f]::SetText($edits[0], $Type, 5000); $typed = $true
                $texts += ('typed into [' + (Tail ([Drv098f]::Txt($h)) 40) + ']'); Click-Ok $h; $acted = $true; break
            }
            if (-not $isMsg -and $edits.Count) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
            $b = $null
            foreach ($w in @(1, 6)) { if (-not $b) { $b = $bs | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1 } }
            $texts += (Short $desc)
            if ($b) { Click $b } else { Close-Win $h }
            $acted = $true
            break
        }
        if ($acted) { $last.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    return $texts
}
# the folders inside $Dir (the panel's folder) - the verdict reads them
function DirNames([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetDirectories($LP + $Dir) | ForEach-Object { $_.Substring(($LP + $Dir).Length + 1) })
}
function Describe([string[]]$Names, [string]$Want) {
    if (-not $Names.Count) { return 'no folder' }
    return (($Names | ForEach-Object { if ($_ -ceq $Want) { 'the expected name (' + (U8Len $_) + ' bytes)' } else { "'" + (Short $_) + "' (" + $_.Length + ' letters, ' + (U8Len $_) + ' bytes)' } }) -join ', ')
}

# one row: the panel in $Panel (it must not hold a folder), $Type typed; $Want the folder expected
# there ($null: no folder may appear and a refusal saying $Said must be shown)
function Row-Do([string]$Case, [string]$Panel, [string]$Type, [string]$Want, [string]$Said) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        if (-not $Panel.StartsWith($Root + '\')) { throw 'a path outside the fixture' }
        if ([IO.Path]::IsPathRooted($Type) -or $Type.StartsWith('\') -or $Type.Contains(':')) { throw 'a typed name that is not relative' }
        NewDir $Panel
        if ((DirNames $Panel).Count) { throw 'the panel folder already holds a folder' }
        $id = Start-P $Panel
        Post-Cmd (Get-Main $id) 730; Start-Sleep -Milliseconds 700
        $texts = @(Answer $id $Type)
        [void][Drv098f]::Send((Get-Main $id), 0, 0, 0, 20000)
        $names = [string[]]@(DirNames $Panel)
        if ($Want) {
            $ok = ($names.Count -eq 1 -and $names[0] -ceq $Want)
            $facts = ("typed {0} bytes ({1}); the panel folder ({2} bytes) holds {3}" -f (U8Len $Type), (Short $Type), (U8Len $Panel), (Describe $names $Want))
        }
        else {
            $shown = [bool](@($texts | Where-Object { $_ -match [regex]::Escape($Said) }).Count)
            $ok = ($names.Count -eq 0 -and $shown)
            $facts = ("typed {0} bytes; the panel folder ({1} bytes) holds {2}; '{3}' shown {4}" -f (U8Len $Type), (U8Len $Panel), (Describe $names ''), $Said, $shown)
        }
        Row $Case 'ROW' (V $ok) ("{0}; dialogs: {1}" -f $facts, $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc274_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("createdir274_probe (feature 274) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}; deep folder {5} bytes" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash, (U8Len (Deep 'relx')))
    Out ''
    $tooLongPath = 'The path specified is too long.'
    $tooLongName = 'too long name'
    # LIMIT: 401 components of 244 'x' joined by '\' = 98,244 bytes; with the 288-byte folder and
    # its '\' the full path is 98,533 bytes, over SAL_MAX_PATH_UTF8 (98,302) - nothing may be made
    $limit = ((1..401) | ForEach-Object { 'x' * 244 }) -join '\'
    Row-Do 'SHORT' ($Root + '\short') 'nd' 'nd'
    Row-Do 'REL' (Deep 'relx') 'nd' 'nd'
    Row-Do 'CJK' (Deep 'cjkx') ($Cjk * 100) ($Cjk * 100)
    Row-Do 'U255' ($Root + '\u255') ($Cjk * 255) ($Cjk * 255)
    Row-Do 'U256' ($Root + '\u256') ($Cjk * 256) $null $tooLongName
    Row-Do 'LIMIT' (Deep 'limx') $limit $null $tooLongPath
    Row-Do 'MULTI' ($Root + '\multi') ('a\' + ($Cjk * 256)) $null $tooLongName   # review: no missing parent "a" is made either
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } }
    catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
