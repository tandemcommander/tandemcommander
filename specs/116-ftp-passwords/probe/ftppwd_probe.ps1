<#
.SYNOPSIS
    Feature 116 probe: the FTP plug-in's password fields keep and send the text that was typed,
    "Show password" shows it, a password of up to 100 characters of any script is taken (the
    buffers hold 301 bytes), and a password saved by 0.1.8 in code-page bytes is sent - and
    retried from the login-error dialog - as those bytes.
    On the build of this feature (-Expect fixed) and on the build before it
    (-Expect before, build\tandemcommander\Debug_x64_pre116, the control).

.DESCRIPTION
    A local log server (ftplog_server.py, 127.0.0.1 only) logs the bytes of every USER / PASS /
    ACCT and refuses every login, so the plug-in shows its login-error dialog. The bookmark is a
    registry fixture (Plugins Configuration\FTP\Bookmarks\1, re-created for every case); the stored
    password is read back from the registry and unscrambled by the probe (no Master Password may
    be set - the probe reports PasswordE and stops judging the stored bytes).

    Rows (names for -Only):
      uni       IsWindowUnicode of the Connect dialog's password field (fixed: TRUE; before: FALSE,
                the code-page subclass CPasswordEditLine).
      type      A password TYPED into the Connect dialog (WM_CHAR posted through the dialog's loop),
                Connect: the server receives exactly its UTF-8 bytes, and the bookmark stores them.
                Cases cz (heslo-r-caron), cyr (Zhaba), cjk (nihongo), emo (U+1F4C1, a surrogate
                pair), fw (fullwidth AB), voila (voil<U+00E0>), lone (a lone surrogate - WTF-8).
                Before: '?' for every character outside the code page, best-fit look-alikes (AB,
                voila); cz depends on the keyboard layout's code page (INFO on the build before).
      set       The same texts set with WM_SETTEXT, Close: the stored bytes are the UTF-8 form.
      show      Ctrl+right click on the password field, Yes: the "password is" box shows the text
                exactly; with -Clipboard also Yes to "copy" and the clipboard's Unicode text is
                compared (the user's clipboard text is saved and restored).
      long      100 x c-caron (200 bytes) and 100 x U+4E2D (300 bytes) typed, Connect: sent whole
                (before: "too long", nothing sent); 105 x 'a' typed: the field takes 100 (both);
                160 x c-caron SET (320 bytes, past the field's limit - only another program can do
                that): Close refuses "too long", nothing stored (both); a user name of 60 x c-caron
                SET: refused (both - user names were not widened).
      prompt    A bookmark without a password, Connect: the "enter password" prompt, 100 x c-caron
                typed: sent whole (before: "too long").
      tab       A password stored correctly as UTF-8 (Zhaba - as a password typed into the address
                field as ftp://user:password@host is), the Connect dialog opened and the password
                field only tabbed through, Close: the stored bytes are unchanged (before: the field
                showed and re-read it through the code page and stored '????').
      legacy    A password saved by 0.1.8 in code-page form (60 x c-caron = 60 bytes 0xE8, written
                by the probe as 0.1.8's scrambled blob): KEEP - the field tabbed through, Close:
                the stored blob is byte-identical; RETRY - Connect sends 60 x e8, then Retry in the
                login-error dialog with the field untouched: sent again as 60 x e8 (before: "too
                long", no second attempt); RETYPE - in the login-error dialog a new password
                (Zhaba + 59 x c-caron, 120 bytes) typed, Retry: sent as its UTF-8 (before: refused).
      compat    With -OldExe (the build before): a password of 86 bytes stored by this build is
                sent unchanged by the build before (stored format unchanged); a password of 200
                bytes stored by this build is sent CUT to its first 100 bytes by the build before
                (the documented downgrade limit).

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while another tandemcommander.exe
    runs. HKCU\Software\Tandem Commander exported before, restored and SHA-256-verified after.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [string]$OldExe,     # compat: the build before (Debug_x64_pre116)
    [switch]$Clipboard   # show: also copy to the clipboard and compare (the user's text is restored)
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }
Add-Type -TypeDefinition 'public static class Desk116 { [System.Runtime.InteropServices.DllImport("user32.dll")] public static extern System.IntPtr GetThreadDesktop(uint t); [System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId(); [System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)] public static extern bool GetUserObjectInformationW(System.IntPtr h, int i, System.Text.StringBuilder s, int n, out int need); public static string Name() { var s = new System.Text.StringBuilder(256); int n; GetUserObjectInformationW(GetThreadDesktop(GetCurrentThreadId()), 2, s, 512, out n); return s.ToString(); } }'
if ([Desk116]::Name() -ieq 'Default') { Write-Output 'REFUSED: run this probe through tools\run_on_hidden_desktop.ps1 (it is on the Default desktop)'; exit 98 }
# a Master Password makes the stored blob AES-encrypted (the probe cannot read it back) and asks for it
$mp = Get-ItemProperty -Path 'HKCU:\Software\Tandem Commander\0.1\Password Manager' -Name 'Use Master Password' -ErrorAction SilentlyContinue
if ($mp -and $mp.'Use Master Password' -ne 0) { Write-Output 'REFUSED: a Master Password is in use (Password Manager\Use Master Password = 1)'; exit 97 }
# -Clipboard copies a test password to the clipboard: Windows clipboard history (Win+V) and the cloud
# clipboard would record it - refused while either is on
if ($Clipboard) {
    $ch = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Clipboard' -ErrorAction SilentlyContinue
    if ($ch -and (($ch.EnableClipboardHistory -eq 1) -or ($ch.EnableCloudClipboard -eq 1) -or ($ch.CloudClipboardAutomaticUpload -eq 1))) {
        Write-Output 'REFUSED: -Clipboard with Windows clipboard history or the cloud clipboard on (they would keep the test password); run without -Clipboard'; exit 96
    }
}

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Drv116' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
public static class Drv116
{
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 5000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    // posts 'msg' to 'target' while the target thread sees the keys of 'mods' down (bit 1 Ctrl,
    // bit 2 Shift): the probe thread shares the target thread's input state and sets the key-state
    // table - no real key press (the 100/102/104 method)
    public static string WithMods(IntPtr target, uint msg, long w, long l, int mods)
    {
        uint pid; uint tid = GetWindowThreadProcessId(target, out pid);
        uint me = GetCurrentThreadId();
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed " + Marshal.GetLastWin32Error();
        var saved = new byte[256]; GetKeyboardState(saved);
        try
        {
            var k = (byte[])saved.Clone();
            if ((mods & 2) != 0) { k[0x10] = k[0xA0] = 0x80; }
            if ((mods & 1) != 0) { k[0x11] = k[0xA2] = 0x80; }
            if (!SetKeyboardState(k)) return "SetKeyboardState failed";
            PostMessageW(target, msg, (IntPtr)w, (IntPtr)l);
            IntPtr r; SendMessageTimeoutW(target, 0, IntPtr.Zero, IntPtr.Zero, 0, 3000, out r);
            Thread.Sleep(400);
            return "ok";
        }
        finally
        {
            SetKeyboardState(saved);
            AttachThreadInput(me, tid, false);
        }
    }
}
'@
}

$Fixed = ($Expect -eq 'fixed')
$Root = $TempRoot + '\tc116_ftp'
$StartDir = $Root + '\start'
$Port = 18116
$LogFile = $Root + '\ftplog.txt'
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }
$Cz = 'heslo-' + [char]0x0159
$Cyr = S 0x0416, 0x0430, 0x0431, 0x0430          # Zhaba
$Cjk = S 0x65E5, 0x672C, 0x8A9E                  # nihongo
$Emo = S 0x1F4C1
$Fw = S 0xFF21, 0xFF22
$Voila = 'voil' + [char]0x00E0
$Lone = 'lone' + [char]0xD800 + 'x'
$TooLongText = (New-Object ComponentModel.Win32Exception 206).Message.Trim()

# UTF-8 bytes of a .NET string with WTF-8 for a lone surrogate (what the plug-in sends)
function Wtf8Hex([string]$s) {
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $s.Length; $i++) {
        $c = [int]$s[$i]
        if ($c -ge 0xD800 -and $c -le 0xDBFF -and $i + 1 -lt $s.Length -and [int]$s[$i + 1] -ge 0xDC00 -and [int]$s[$i + 1] -le 0xDFFF) {
            $cp = 0x10000 + (($c - 0xD800) -shl 10) + ([int]$s[$i + 1] - 0xDC00); $i++
            $b = @((0xF0 -bor ($cp -shr 18)), (0x80 -bor (($cp -shr 12) -band 0x3F)), (0x80 -bor (($cp -shr 6) -band 0x3F)), (0x80 -bor ($cp -band 0x3F)))
        }
        elseif ($c -lt 0x80) { $b = @($c) }
        elseif ($c -lt 0x800) { $b = @((0xC0 -bor ($c -shr 6)), (0x80 -bor ($c -band 0x3F))) }
        else { $b = @((0xE0 -bor ($c -shr 12)), (0x80 -bor (($c -shr 6) -band 0x3F)), (0x80 -bor ($c -band 0x3F))) }
        foreach ($x in $b) { [void]$sb.AppendFormat('{0:x2}', $x) }
    }
    return $sb.ToString()
}
function BytesHex([byte[]]$b) { return (($b | ForEach-Object { '{0:x2}' -f $_ }) -join '') }

# ---- the password manager's scrambled form (src/pwdmngr.cpp, ScramblePassword) ------------
$ScrambleTable = @(0, 223, 235, 233, 240, 185, 88, 102, 22, 130, 27, 53, 79, 125, 66, 201, 90, 71, 51, 60, 134, 104, 172, 244, 139, 84, 91, 12, 123, 155, 237, 151,
    192, 6, 87, 32, 211, 38, 149, 75, 164, 145, 52, 200, 224, 226, 156, 50, 136, 190, 232, 63, 129, 209, 181, 120, 28, 99, 168, 94, 198, 40, 238, 112,
    55, 217, 124, 62, 227, 30, 36, 242, 208, 138, 174, 231, 26, 54, 214, 148, 37, 157, 19, 137, 187, 111, 228, 39, 110, 17, 197, 229, 118, 246, 153, 80,
    21, 128, 69, 117, 234, 35, 58, 67, 92, 7, 132, 189, 5, 103, 10, 15, 252, 195, 70, 147, 241, 202, 107, 49, 20, 251, 133, 76, 204, 73, 203, 135,
    184, 78, 194, 183, 1, 121, 109, 11, 143, 144, 171, 161, 48, 205, 245, 46, 31, 72, 169, 131, 239, 160, 25, 207, 218, 146, 43, 140, 127, 255, 81, 98,
    42, 115, 173, 142, 114, 13, 2, 219, 57, 56, 24, 126, 3, 230, 47, 215, 9, 44, 159, 33, 249, 18, 93, 95, 29, 113, 220, 89, 97, 182, 248, 64,
    68, 34, 4, 82, 74, 196, 213, 165, 179, 250, 108, 254, 59, 14, 236, 175, 85, 199, 83, 106, 77, 178, 167, 225, 45, 247, 163, 158, 8, 221, 61, 191,
    119, 16, 253, 105, 186, 23, 170, 100, 216, 65, 162, 122, 150, 176, 154, 193, 206, 222, 188, 152, 210, 243, 96, 41, 86, 180, 101, 177, 166, 141, 212, 116)
$Unscramble = New-Object int[] 256
for ($i = 0; $i -lt 256; $i++) { $Unscramble[$ScrambleTable[$i]] = $i }
# the stored blob (signature 1 = scrambled) for the plain bytes $plain; padding 'A' (deterministic)
function Scramble([byte[]]$plain) {
    $len = $plain.Length
    $padding = ([math]::Floor(($len + 3) / 17) * 17 + 17) - 3 - $len
    $buf = New-Object System.Collections.Generic.List[byte]
    for ($i = 0; $i -lt $padding; $i++) { $buf.Add(65) }
    $buf.Add([byte](48 + $len % 10)); $buf.Add([byte](48 + [math]::Floor($len / 10) % 10)); $buf.Add([byte](48 + [math]::Floor($len / 100) % 10))
    foreach ($b in $plain) { $buf.Add($b) }
    $out = New-Object System.Collections.Generic.List[byte]
    $out.Add(1)
    $last = 31
    foreach ($b in $buf) { $last = ($last + [int]$b) % 255 + 1; $out.Add([byte]$ScrambleTable[$last]) }
    return , $out.ToArray()
}
# the plain bytes of a stored scrambled blob, or $null
function Unscramble-Blob([byte[]]$blob) {
    if (-not $blob -or $blob.Length -lt 2 -or $blob[0] -ne 1) { return $null }
    $plain = New-Object System.Collections.Generic.List[byte]
    $last = 31
    for ($i = 1; $i -lt $blob.Length; $i++) {
        $x = $Unscramble[$blob[$i]] - 1 - ($last % 255); if ($x -le 0) { $x += 255 }
        $plain.Add([byte]$x); $last = ($last + $x) % 255 + 1
    }
    $p = 0; while ($p -lt $plain.Count -and ($plain[$p] -lt 48 -or $plain[$p] -gt 57)) { $p++ }
    if ($plain.Count - $p -lt 3) { return $null }
    $len = ($plain[$p] - 48) + 10 * ($plain[$p + 1] - 48) + 100 * ($plain[$p + 2] - 48)
    if ($plain.Count - $p - 3 -ne $len) { return $null }
    return , $plain.GetRange($p + 3, $len).ToArray()
}

# ---- fixtures, server, instances ----------------------------------------------------------
$FtpKey = 'HKCU:\Software\Tandem Commander\0.1\Plugins Configuration\FTP'
$FtpBm = $FtpKey + '\Bookmarks\1'
# re-creates bookmark 1 ('B116', 127.0.0.1:$Port, user 'probe116'); $Blob = the stored password blob or $null
function Ftp-Fixture([byte[]]$Blob, [int]$Save = 1) {
    if (Test-Path $FtpBm) { Remove-Item -Path $FtpBm -Recurse -Force }
    [void](New-Item -Path $FtpBm -Force)
    Set-ItemProperty -Path $FtpBm -Name 'Name' -Value 'B116' -Type String
    Set-ItemProperty -Path $FtpBm -Name 'Address' -Value '127.0.0.1' -Type String
    Set-ItemProperty -Path $FtpBm -Name 'User' -Value 'probe116' -Type String
    Set-ItemProperty -Path $FtpBm -Name 'Anonymous' -Value 0 -Type DWord
    Set-ItemProperty -Path $FtpBm -Name 'Port' -Value $Port -Type DWord
    Set-ItemProperty -Path $FtpBm -Name 'Save Password' -Value $Save -Type DWord
    if ($Blob) { Set-ItemProperty -Path $FtpBm -Name 'PasswordS' -Value $Blob -Type Binary }
    Set-ItemProperty -Path $FtpKey -Name 'Delay Connect Retries' -Value 1 -Type DWord   # Retry reconnects after 1 s
}
# the stored password: 'NONE', 'E:<hex>' (encrypted - a Master Password is set), or the plain bytes' hex
function Ftp-StoredPwd {
    $k = Get-Item -LiteralPath $FtpBm -ErrorAction SilentlyContinue
    if (-not $k) { return '<no bookmark>' }
    $e = $k.GetValue('PasswordE'); if ($e) { return 'E:' + (BytesHex $e) }
    $p = $k.GetValue('PasswordS'); if (-not $p) { return 'NONE' }
    $plain = Unscramble-Blob $p
    if ($null -eq $plain) { return 'UNREADABLE:' + (BytesHex $p) }
    return (BytesHex $plain)
}
function Ftp-StoredBlob { $k = Get-Item -LiteralPath $FtpBm -ErrorAction SilentlyContinue; if (-not $k) { return '' }; $p = $k.GetValue('PasswordS'); if ($p) { return (BytesHex $p) }; return '' }
function Ftp-StoredUser { $k = Get-Item -LiteralPath $FtpBm -ErrorAction SilentlyContinue; if (-not $k) { return '<no bookmark>' }; return [string]$k.GetValue('User') }
function Log-Lines { if (Test-Path -LiteralPath $LogFile) { return @(Get-Content -LiteralPath $LogFile) } else { return @() } }
function Log-Since([int]$N) { return @(Log-Lines | Select-Object -Skip $N) }
function Pass-Hex($Lines) { return @($Lines | Where-Object { $_ -like 'PASS *' } | ForEach-Object { ($_ -split 'hex=')[1] }) }

function Start-P {
    $a = @('-t', 'T116', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Type-Into([IntPtr]$Edit, [string]$Text) { foreach ($ch in $Text.ToCharArray()) { [void][Drv116]::PostMessageW($Edit, 0x0102, [IntPtr][int]$ch, [IntPtr]1) } }
function Focus-Ctl([IntPtr]$Dlg, [IntPtr]$Ctl) { [void][Drv116]::SendR($Dlg, 0x0028, $Ctl.ToInt64(), 1) }   # WM_NEXTDLGCTL
# answers the boxes of the instance (ids in $WantIds, else close); windows in $Ignore are not boxes
function Answer([int]$Id, [double]$Seconds = 20, [int[]]$WantIds = @(7, 2), $Ignore = @()) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not (Test-Alive $Id)) { break }
        $boxes = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $Ignore -notcontains $_ -and [Drv098f]::IsWindowEnabled($_) })
        if (-not $boxes.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 150; continue
        }
        $idleSince = $null
        foreach ($b in $boxes) {
            $key = $b.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - $seen[$key] -lt 0.7) { continue }
            $seen.Remove($key)
            $d = WinDesc $b
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            [void]$r.Messages.Add($d)
            $btn = $null
            foreach ($w in $WantIds) { $btn = Buttons $b | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($btn) { break } }
            if ($btn) { Click $btn } else { Close-Win $b }
            Start-Sleep -Milliseconds 600
        }
    }
    return $r
}
function Msgs2($r) { if ($r.Messages.Count) { return ($r.Messages -join ' || ') } else { return 'no box' } }
function End-P([string]$Case, [int]$Id, $Before) {
    Start-Sleep -Milliseconds 500
    [void](Answer $Id 6 @(2, 7, 1))
    End-Row $Case $Id $null $Before
}
function Open-FtpConnect([int]$Id) {
    $known = Get-Tops $Id
    $r = [Drv116]::WithMods((Get-LeftList $Id), 0x0100, 0x46, 1, 3)   # Ctrl+Shift+F (WM_KEYDOWN)
    [void][Drv116]::PostMessageW((Get-LeftList $Id), 0x0101, [IntPtr]0x46, [IntPtr]0xC0000001)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and ((Kid $_ 561 $null) -ne $null) }) | Select-Object -First 1
        if ($w) {
            Start-Sleep -Milliseconds 800
            $lb = Kid $w 561 $null
            [void][Drv116]::SendR($lb, 0x0186, 1, 0)                                   # LB_SETCURSEL 1 = bookmark B116
            [void][Drv116]::SendR($w, 0x0111, ((1 -shl 16) -bor 561), $lb.ToInt64())  # LBN_SELCHANGE
            Start-Sleep -Milliseconds 500
            return $w
        }
        Start-Sleep -Milliseconds 200
    }
    throw ('the FTP Connect dialog did not open (' + $r + ')')
}
# waits for the login-error dialog (it has the server-reply field 633); answers other boxes Cancel/No
function Wait-LoginError([int]$Id, [double]$Seconds = 25) {
    $msgs = New-Object System.Collections.ArrayList
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) })) {
            if ((Kid $h 633 'Edit') -ne $null -and (Kid $h 568 'Edit') -ne $null) { Start-Sleep -Milliseconds 700; return [pscustomobject]@{ Dlg = $h; Msgs = $msgs } }
        }
        Start-Sleep -Milliseconds 250
    }
    return [pscustomobject]@{ Dlg = [IntPtr]::Zero; Msgs = $msgs }
}
# the instance's open dialog (password prompt 622, login error 633, Connect 561) is cancelled
function Cancel-All([int]$Id) {
    for ($k = 0; $k -lt 6; $k++) {
        $w = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) })
        if (-not $w.Count) { break }
        foreach ($h in $w) { Post-Cmd $h 2 }
        Start-Sleep -Milliseconds 800
    }
    [void](Answer $Id 5 @(2, 7, 1))
}

# ---- rows ---------------------------------------------------------------------------------
# Connect dialog: the password field gets $Text (typed or set); $Button 1 = Connect, 575 = Close.
# Returns the facts: boxes, whether the dialog stayed, the server's lines, the stored password.
function Ftp-Run([string]$Case, [string]$Text, [switch]$Typed, [int]$Button, [int]$Field = 568, [byte[]]$Blob = $null, [int]$Save = 1) {
    Ftp-Fixture $Blob $Save
    $n0 = (Log-Lines).Count
    $id = 0; $before = Reports
    $res = [pscustomobject]@{ Ok = $false; Facts = ''; Stayed = $false; Boxes = ''; Lines = @(); Stored = ''; User = ''; Unicode = $null; LoginErr = $false }
    try {
        $id = Start-P
        $dlg = Open-FtpConnect $id
        $ed = Kid $dlg $Field 'Edit'
        $res.Unicode = [Drv116]::IsWindowUnicode((Kid $dlg 568 'Edit'))
        Focus-Ctl $dlg $ed
        [void][Drv116]::SendR($ed, 0x00B1, 0, -1)                     # EM_SETSEL all: typing replaces
        if ($Typed) { Type-Into $ed $Text } else { [void][Drv098f]::SetText($ed, $Text, 5000) }
        Start-Sleep -Milliseconds 400
        Click (Kid $dlg $Button 'Button')
        Start-Sleep -Milliseconds 1500
        if ($Button -eq 1) {
            $le = Wait-LoginError $id 20
            $res.LoginErr = $le.Dlg -ne [IntPtr]::Zero
            $res.Stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
            $ans = Answer $id 4 @(1, 2, 7) @($dlg, $le.Dlg)
            $res.Boxes = Msgs2 $ans
            Cancel-All $id
        }
        else {
            $ans = Answer $id 6 @(1, 2, 7) @($dlg)
            $res.Boxes = Msgs2 $ans
            $res.Stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
            if ($res.Stayed) { Post-Cmd $dlg 2; Start-Sleep -Milliseconds 800; [void](Answer $id 5 @(6, 1, 2)) }
        }
        End-P $Case $id $before; $id = 0
        $res.Lines = Log-Since $n0
        $res.Stored = Ftp-StoredPwd
        $res.User = Ftp-StoredUser
        $res.Ok = $true
    }
    catch { $res.Facts = $_.Exception.Message + ' @ ' + $_.ScriptStackTrace }
    finally { if ($id) { End-P $Case $id $before } }
    return $res
}
function Short([string]$hex, [int]$n = 64) { if ($hex.Length -le $n) { return $hex }; return ($hex.Substring(0, $n) + '...(' + ($hex.Length / 2) + ' bytes)') }
function SentFacts($r) { $p = Pass-Hex $r.Lines; if ($p.Count) { return (($p | ForEach-Object { Short $_ }) -join ' / ') } else { return 'no PASS' } }

$TypeCases = @(
    @{ Case = 'cz'; Text = $Cz; Det = $false },
    @{ Case = 'cyr'; Text = $Cyr; Det = $true },
    @{ Case = 'cjk'; Text = $Cjk; Det = $true },
    @{ Case = 'emo'; Text = $Emo; Det = $true },
    @{ Case = 'fw'; Text = $Fw; Det = $true },
    @{ Case = 'voila'; Text = $Voila; Det = $true },
    @{ Case = 'lone'; Text = $Lone; Det = $true })

function Run-Type {
    $uniDone = $false
    foreach ($c in $TypeCases) {
        $r = Ftp-Run 'type' $c.Text -Typed -Button 1
        if (-not $r.Ok) { Row 'type' $c.Case 'FAIL' $r.Facts; continue }
        if (-not $uniDone -and (Want 'uni')) {
            $uniDone = $true
            if ($Fixed) { $v = V ($r.Unicode -eq $true) } else { $v = V ($r.Unicode -eq $false) }
            Row 'uni' 'FIELD' $v ("IsWindowUnicode(password field) = {0}" -f $r.Unicode)
        }
        $want = Wtf8Hex $c.Text
        $sent = @(Pass-Hex $r.Lines)
        $sentOk = $sent.Count -ge 1 -and $sent[0] -ceq $want
        $storedOk = $r.Stored -ceq $want
        $facts = ("typed {0} ({1}); Connect: login-error dialog {2}; sent: {3}; stored: {4}" -f (Esc $c.Text), $want, $r.LoginErr, (SentFacts $r), (Short $r.Stored))
        if ($Fixed) { $v = V ($sentOk -and $storedOk) }
        elseif ($c.Det) { $v = V ($sent.Count -ge 1 -and -not $sentOk) }
        else { $v = 'INFO' }
        Row 'type' $c.Case $v $facts
    }
}
function Run-Set {
    foreach ($c in @($TypeCases | Where-Object { @('cyr', 'cjk', 'lone', 'fw') -contains $_.Case })) {
        $r = Ftp-Run 'set' $c.Text -Button 575
        if (-not $r.Ok) { Row 'set' $c.Case 'FAIL' $r.Facts; continue }
        $want = Wtf8Hex $c.Text
        $ok = $r.Stored -ceq $want
        if ($Fixed) { $v = V ($ok -and -not $r.Stayed) } else { $v = V (-not $ok) }
        Row 'set' $c.Case $v ("set {0}, Close: dialog stayed {1}; boxes: {2}; stored {3} (want {4})" -f (Esc $c.Text), $r.Stayed, $r.Boxes, (Short $r.Stored), $want)
    }
}
function Run-Show {
    $text = $Cyr + $Cjk + $Emo + 'x'
    Ftp-Fixture $null 0
    $id = 0; $before = Reports
    try {
        $id = Start-P
        $dlg = Open-FtpConnect $id
        $ed = Kid $dlg 568 'Edit'
        Focus-Ctl $dlg $ed
        Type-Into $ed $text
        Start-Sleep -Milliseconds 500
        $known = @(Get-Tops $id)
        # WM_RBUTTONDOWN (MK_RBUTTON|MK_CONTROL) with Ctrl down; no WM_RBUTTONUP - the edit would open
        # its context menu (a menu loop nobody closes on the hidden desktop)
        $m = [Drv116]::WithMods($ed, 0x0204, 0x000A, 0x00050005, 1)
        # the confirmation: Yes
        $conf = Wait-NewWin $id $known 8
        if ($conf -eq [IntPtr]::Zero) { Row 'show' 'BOX' 'FAIL' ('no confirmation box after Ctrl+right click (' + $m + ')'); return }
        $confText = WinDesc $conf
        $yes = Buttons $conf | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
        if ($yes) { Click $yes } else { Close-Win $conf }
        Start-Sleep -Milliseconds 1000
        $box = Wait-NewWin $id $known 8
        if ($box -eq [IntPtr]::Zero) { Row 'show' 'BOX' 'FAIL' ('no password box; confirmation was: ' + $confText); return }
        $boxText = WinDesc $box
        $shown = $boxText.Contains((Esc $text))
        $clipFacts = 'not compared (no -Clipboard)'; $clipOk = $true
        if ($Clipboard) {
            Save-Clip
            if ($script:ClipOk) {
                try {
                    $yes = Buttons $box | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
                    if ($yes) { Click $yes }
                    Start-Sleep -Milliseconds 1200
                    $got = ''; if ([Windows.Forms.Clipboard]::ContainsText()) { $got = [Windows.Forms.Clipboard]::GetText() }
                    $clipOk = $got -ceq $text
                    $clipFacts = 'clipboard ' + (Esc $got) + ' exact ' + $clipOk
                }
                finally { Restore-Clip }   # the user's clipboard text comes back whatever happened
            }
            else { $clipFacts = 'clipboard not usable'; Close-Win $box }
        }
        else { $no = Buttons $box | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 7 } | Select-Object -First 1; if ($no) { Click $no } else { Close-Win $box } }
        Start-Sleep -Milliseconds 600
        Post-Cmd $dlg 2; Start-Sleep -Milliseconds 800; [void](Answer $id 5 @(6, 1, 2))
        if ($Fixed) { $v = V ($shown -and $clipOk) } else { $v = V (-not $shown) }
        Row 'show' 'BOX' $v ("typed {0}; the box: {1}; exact {2}; {3}" -f (Esc $text), (Tail $boxText 160), $shown, $clipFacts)
    }
    catch { Row 'show' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'show' $id $before } }
}
function Run-Long {
    $cz100 = [string][char]0x010D * 100; $cjk100 = [string][char]0x4E2D * 100
    foreach ($c in @(@{ Case = 'CZ100'; Text = $cz100 }, @{ Case = 'CJK100'; Text = $cjk100 })) {
        $r = Ftp-Run 'long' $c.Text -Typed -Button 1
        if (-not $r.Ok) { Row 'long' $c.Case 'FAIL' $r.Facts; continue }
        $want = Wtf8Hex $c.Text
        $sent = @(Pass-Hex $r.Lines)
        $refused = $r.Boxes.Contains((Esc $TooLongText))
        if ($Fixed) { $v = V ($sent.Count -ge 1 -and $sent[0] -ceq $want -and $r.Stored -ceq $want -and -not $refused) }
        else { $v = V ($refused -and $sent.Count -eq 0) }
        Row 'long' $c.Case $v ("typed 100 x {0} ({1} bytes), Connect: refused {2}; dialog stayed {3}; sent: {4}; stored {5} bytes" -f (Esc $c.Text.Substring(0, 1)), ($want.Length / 2), $refused, $r.Stayed, (SentFacts $r), $(if ($r.Stored -match '^[0-9a-f]*$') { $r.Stored.Length / 2 } else { $r.Stored }))
    }
    $r = Ftp-Run 'long' ('a' * 105) -Typed -Button 1
    if (-not $r.Ok) { Row 'long' 'LIMIT' 'FAIL' $r.Facts }
    else { $sent = @(Pass-Hex $r.Lines); Row 'long' 'LIMIT' (V ($sent.Count -ge 1 -and $sent[0] -ceq ('61' * 100))) ("typed 105 x 'a': sent {0}" -f (SentFacts $r)) }
    $r = Ftp-Run 'long' ([string][char]0x010D * 160) -Button 575
    if (-not $r.Ok) { Row 'long' 'OVER' 'FAIL' $r.Facts }
    else {
        $refused = $r.Boxes.Contains((Esc $TooLongText))
        Row 'long' 'OVER' (V ($refused -and $r.Stayed -and $r.Stored -eq 'NONE')) ("160 x c-caron SET (320 bytes, past the field's limit), Close: refused {0}; dialog stayed {1}; stored {2}" -f $refused, $r.Stayed, (Short $r.Stored))
    }
    $r = Ftp-Run 'long' ([string][char]0x010D * 60) -Button 575 -Field 567
    if (-not $r.Ok) { Row 'long' 'USER' 'FAIL' $r.Facts }
    else {
        $refused = $r.Boxes.Contains((Esc $TooLongText))
        Row 'long' 'USER' (V ($refused -and $r.Stayed -and $r.User -ceq 'probe116')) ("user name 60 x c-caron SET, Close: refused {0}; dialog stayed {1}; stored user '{2}' (user names keep 101 bytes)" -f $refused, $r.Stayed, (Esc $r.User))
    }
}
function Run-Prompt {
    Ftp-Fixture $null 0
    $n0 = (Log-Lines).Count
    $text = [string][char]0x010D * 100
    $id = 0; $before = Reports
    try {
        $id = Start-P
        $dlg = Open-FtpConnect $id
        Click (Kid $dlg 1 'Button')
        $pr = [IntPtr]::Zero
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 20 -and $pr -eq [IntPtr]::Zero) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) })) { if ((Kid $h 622 'Edit') -ne $null) { $pr = $h } }
            Start-Sleep -Milliseconds 250
        }
        if ($pr -eq [IntPtr]::Zero) { Row 'prompt' 'CZ100' 'FAIL' 'the password prompt did not appear'; return }
        Start-Sleep -Milliseconds 500
        $ed = Kid $pr 622 'Edit'
        Type-Into $ed ($text + [char]0x010D)   # 101 characters: the prompt takes 100
        Start-Sleep -Milliseconds 400
        Click (Kid $pr 1 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 3 @(1, 2, 7) @($pr)
        $refused = (Msgs2 $ans).Contains((Esc $TooLongText))
        $le = Wait-LoginError $id 15
        Cancel-All $id
        End-P 'prompt' $id $before; $id = 0
        $lines = Log-Since $n0
        $sent = @(Pass-Hex $lines)
        $want = Wtf8Hex $text
        if ($Fixed) { $v = V ($sent.Count -ge 1 -and $sent[0] -ceq $want -and -not $refused) } else { $v = V ($refused -and $sent.Count -eq 0) }
        Row 'prompt' 'CZ100' $v ("101 x c-caron typed into the password prompt, OK: refused {0}; sent: {1}" -f $refused, $(if ($sent.Count) { (($sent | ForEach-Object { Short $_ }) -join ' / ') } else { 'no PASS' }))
    }
    catch { Row 'prompt' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'prompt' $id $before } }
}
function Run-Tab {
    $plain = [Text.Encoding]::UTF8.GetBytes($Cyr)
    $want = BytesHex $plain
    Ftp-Fixture (Scramble $plain) 1
    $id = 0; $before = Reports
    try {
        $id = Start-P
        $dlg = Open-FtpConnect $id
        Focus-Ctl $dlg (Kid $dlg 568 'Edit')
        Focus-Ctl $dlg (Kid $dlg 567 'Edit')
        Start-Sleep -Milliseconds 300
        Click (Kid $dlg 575 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 5 @(1, 2, 7) @($dlg)
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        if ($stayed) { Post-Cmd $dlg 2; Start-Sleep -Milliseconds 800 }
        End-P 'tab' $id $before; $id = 0
        $after = Ftp-StoredPwd
        if ($Fixed) { $v = V ($after -ceq $want) } else { $v = V ($after -cne $want) }
        Row 'tab' 'UTF8' $v ("stored {0} (UTF-8 of Zhaba), field tabbed through, Close: boxes {1}; stored now {2}" -f $want, (Msgs2 $ans), (Short $after))
    }
    catch { Row 'tab' 'UTF8' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'tab' $id $before } }
}
function Run-Legacy {
    $legacy = New-Object byte[] 60; for ($i = 0; $i -lt 60; $i++) { $legacy[$i] = 0xE8 }
    $blob = Scramble $legacy
    $legacyHex = BytesHex $legacy
    # KEEP: tabbed through, Close: the blob is byte-identical
    Ftp-Fixture $blob 1
    $blobHex = Ftp-StoredBlob
    $id = 0; $before = Reports
    try {
        $id = Start-P
        $dlg = Open-FtpConnect $id
        Focus-Ctl $dlg (Kid $dlg 568 'Edit')
        Focus-Ctl $dlg (Kid $dlg 567 'Edit')
        Start-Sleep -Milliseconds 300
        Click (Kid $dlg 575 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 5 @(1, 2, 7) @($dlg)
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        if ($stayed) { Post-Cmd $dlg 2; Start-Sleep -Milliseconds 800 }
        End-P 'legacy' $id $before; $id = 0
        $after = Ftp-StoredBlob
        Row 'legacy' 'KEEP' (V ($after -ceq $blobHex -and -not $stayed)) ("0.1.8 form (60 x e8) tabbed through, Close: boxes {0}; blob byte-identical {1}; stored now {2}" -f (Msgs2 $ans), ($after -ceq $blobHex), (Short (Ftp-StoredPwd)))
    }
    catch { Row 'legacy' 'KEEP' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'legacy' $id $before } }

    # RETRY: Connect sends the stored bytes; Retry with the field untouched sends them again
    Ftp-Fixture $blob 1
    $n0 = (Log-Lines).Count
    $id = 0; $before = Reports
    try {
        $id = Start-P
        $dlg = Open-FtpConnect $id
        Click (Kid $dlg 1 'Button')
        $le = Wait-LoginError $id 20
        if ($le.Dlg -eq [IntPtr]::Zero) { Row 'legacy' 'RETRY' 'FAIL' ('no login-error dialog; server: ' + ((Log-Since $n0) -join ' / ')); return }
        Click (Kid $le.Dlg 1 'Button')   # Retry, nothing touched
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 3 @(1) @($le.Dlg)
        $refused = (Msgs2 $ans).Contains((Esc $TooLongText))
        $le2 = Wait-LoginError $id 15
        Cancel-All $id
        End-P 'legacy' $id $before; $id = 0
        $lines = Log-Since $n0
        $sent = @(Pass-Hex $lines)
        $conns = @($lines | Where-Object { $_ -like 'CONN *' }).Count
        $both = $sent.Count -ge 2 -and $sent[0] -ceq $legacyHex -and $sent[1] -ceq $legacyHex
        if ($Fixed) { $v = V ($both -and -not $refused) } else { $v = V ($refused -and $sent.Count -eq 1 -and $sent[0] -ceq $legacyHex) }
        Row 'legacy' 'RETRY' $v ("Connect then Retry (untouched): refused {0}; connections {1}; sent: {2}" -f $refused, $conns, $(if ($sent.Count) { (($sent | ForEach-Object { Short $_ 24 }) -join ' / ') } else { 'no PASS' }))
    }
    catch { Row 'legacy' 'RETRY' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'legacy' $id $before } }

    # RETYPE: a new password typed into the login-error dialog, Retry: its UTF-8 is sent
    Ftp-Fixture $blob 1
    $n0 = (Log-Lines).Count
    $text = $Cyr.Substring(0, 1) + ([string][char]0x010D * 59)
    $id = 0; $before = Reports
    try {
        $id = Start-P
        $dlg = Open-FtpConnect $id
        Click (Kid $dlg 1 'Button')
        $le = Wait-LoginError $id 20
        if ($le.Dlg -eq [IntPtr]::Zero) { Row 'legacy' 'RETYPE' 'FAIL' 'no login-error dialog'; return }
        $ed = Kid $le.Dlg 568 'Edit'
        Focus-Ctl $le.Dlg $ed
        [void][Drv116]::SendR($ed, 0x00B1, 0, -1)
        Type-Into $ed $text
        Start-Sleep -Milliseconds 400
        Click (Kid $le.Dlg 1 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 3 @(1) @($le.Dlg)
        $refused = (Msgs2 $ans).Contains((Esc $TooLongText))
        $le2 = Wait-LoginError $id 10
        Cancel-All $id
        End-P 'legacy' $id $before; $id = 0
        $sent = @(Pass-Hex (Log-Since $n0))
        $want = Wtf8Hex $text
        if ($Fixed) { $v = V ($sent.Count -ge 2 -and $sent[1] -ceq $want -and -not $refused) } else { $v = V ($refused) }
        Row 'legacy' 'RETYPE' $v ("Zhaba[0] + 59 x c-caron (120 bytes) typed into the login-error dialog, Retry: refused {0}; sent: {1}" -f $refused, $(if ($sent.Count) { (($sent | ForEach-Object { Short $_ 24 }) -join ' / ') } else { 'no PASS' }))
    }
    catch { Row 'legacy' 'RETYPE' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'legacy' $id $before } }
}
function Run-Compat {
    if (-not $OldExe) { Row 'compat' 'FORMAT' 'NOT DRIVEN' 'no -OldExe given'; return }
    if (-not $Fixed) { Row 'compat' 'FORMAT' 'NOT DRIVEN' 'only with -Expect fixed'; return }
    $old = (Resolve-Path -LiteralPath $OldExe).Path
    foreach ($c in @(@{ Case = 'FORMAT'; Text = ('heslo-' + ([string][char]0x010D * 40)) }, @{ Case = 'DOWNGRADE'; Text = ([string][char]0x010D * 100) })) {
        # this build stores the password (typed, Close)
        $r = Ftp-Run 'compat' $c.Text -Typed -Button 575
        if (-not $r.Ok) { Row 'compat' $c.Case 'FAIL' $r.Facts; continue }
        $want = Wtf8Hex $c.Text
        $blob = $null; $k = Get-Item -LiteralPath $FtpBm -ErrorAction SilentlyContinue; if ($k) { $blob = $k.GetValue('PasswordS') }
        if ($r.Stored -cne $want -or -not $blob) { Row 'compat' $c.Case 'FAIL' ('this build did not store the password: ' + (Short $r.Stored)); continue }
        # the build before connects with it (the password field is not touched)
        $exeSaved = $Exe; $script:Exe = $old
        $n0 = (Log-Lines).Count
        $id = 0; $before = Reports
        try {
            Ftp-Fixture $blob 1
            $id = Start-P
            $dlg = Open-FtpConnect $id
            Click (Kid $dlg 1 'Button')
            $le = Wait-LoginError $id 20
            Cancel-All $id
            End-P 'compat' $id $before; $id = 0
        }
        finally { if ($id) { End-P 'compat' $id $before }; $script:Exe = $exeSaved }
        $sent = @(Pass-Hex (Log-Since $n0))
        if ($c.Case -eq 'FORMAT') { $v = V ($sent.Count -ge 1 -and $sent[0] -ceq $want) }
        else { $v = V ($sent.Count -ge 1 -and $sent[0] -ceq $want.Substring(0, 200)) }
        Row 'compat' $c.Case $v ("stored by this build: {0} bytes; the build before sent: {1}{2}" -f ($want.Length / 2), $(if ($sent.Count) { Short $sent[0] } else { 'no PASS' }), $(if ($c.Case -eq 'DOWNGRADE') { ' (expected: the first 100 bytes - the documented downgrade limit)' } else { '' }))
    }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc116_ftp_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0; $srv = $null
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("ftppwd_probe (feature 116), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    if ($OldExe) { Out ("Before  : {0}" -f $OldExe) }
    Out ("Date    : {0}; ACP {1}; desktop {2}; registry key existed {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), [Desk116]::Name(), $existed)
    $srv = Start-Process -FilePath $Python -ArgumentList @(('"' + (Join-Path $PSScriptRoot 'ftplog_server.py') + '"'), $Port, ('"' + $LogFile + '"')) -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 1500
    if ($srv.HasExited) { throw 'the log server did not start (python?)' }
    Out ''
    if ((Want 'type') -or (Want 'uni')) { Run-Type }
    if (Want 'set') { Run-Set }
    if (Want 'show') { Run-Show }
    if (Want 'long') { Run-Long }
    if (Want 'prompt') { Run-Prompt }
    if (Want 'tab') { Run-Tab }
    if (Want 'legacy') { Run-Legacy }
    if (Want 'compat') { Run-Compat }
    if (-not $Only) {
        foreach ($nd in @('the proxy server dialog (its password field, Show password and the stored-bytes rule): needs a proxy configuration - same helpers as the Connect dialog',
                          'the account (ACCT) field and the proxy fields of the login-error dialog: the log server never asks for ACCT; same helpers as its password field',
                          'a Master Password set: the stored blob is then AES-encrypted and cannot be read back by the probe',
                          'real keyboard input and an IME: posted WM_CHAR only (the hidden desktop has no input)')) { Row 'nd' 'ROUTE' 'NOT DRIVEN' $nd }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    if ($srv -and -not $srv.HasExited) { Stop-Process -Id $srv.Id -Force }
    Start-Sleep -Milliseconds 600
    if (Test-Path -LiteralPath $LogFile) { Out ''; Out 'Server log:'; foreach ($l in (Log-Lines)) { Out ('  ' + (Short $l 140)) } }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    $ni = @($script:Rows | Where-Object { $_.Verdict -eq 'INFO' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}, INFO {3}. Left running: {4}; fixture removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, $ni, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
