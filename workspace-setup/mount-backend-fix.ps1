# fythaniya backend mount - drive-letter method.
# Auth is handled via an ~/.ssh/config Host block (the system 'ssh' that sshfs
# drives reads it automatically), so the key path never goes through sshfs's
# option parser. Launched by MOUNT-BACKEND.bat. Writes mount-result.txt.
$ErrorActionPreference = 'Continue'

$SshUser    = 'omar_elzanaty_almobarmg'
$ServerIp   = '34.79.246.143'
$RemotePath = '/home/omar_elzanaty_almobarmg/fythaniya-api'
$Workspace  = Join-Path $HOME 'fythaniya-workspace'
$BackendDir = Join-Path $Workspace 'backend'
$ErrLog     = Join-Path $env:TEMP 'sshfs-fythaniya-err.log'
$ResultFile = Join-Path $PSScriptRoot 'mount-result.txt'

$log = New-Object System.Collections.Generic.List[string]
function Say($m) { Write-Host $m; $log.Add([string]$m) }
function Save() { Set-Content -Path $ResultFile -Value $log -Encoding UTF8 }

Say ""
Say "=== fythaniya backend mount (drive-letter + ssh config) ==="
Say ("time: " + (Get-Date))

# locate sshfs.exe
$sshfs = @(
    "$env:ProgramFiles\SSHFS-Win\bin\sshfs.exe",
    "${env:ProgramFiles(x86)}\SSHFS-Win\bin\sshfs.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $sshfs) { Say "RESULT: FAILED - SSHFS-Win not installed (sshfs.exe not found)."; Save; return }
Say ("sshfs.exe : " + $sshfs)

# locate SSH key (gcloud key preferred)
$key = @(
    "$HOME\.ssh\google_compute_engine",
    "$HOME\.ssh\id_ed25519",
    "$HOME\.ssh\id_rsa"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $key) { Say "RESULT: FAILED - no SSH key found in $HOME\.ssh\"; Save; return }
Say ("SSH key   : " + $key)
$keyFwd = ($key -replace '\\','/')

# ensure an ~/.ssh/config Host block so the system 'ssh' uses this key for the VM
$sshConfig = Join-Path $HOME '.ssh\config'
$sshDir = Split-Path -Parent $sshConfig
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Force -Path $sshDir | Out-Null }
$blkStart = '# >>> fythaniya backend (added by mount tool) >>>'
$blkEnd   = '# <<< fythaniya backend (added by mount tool) <<<'
$blk = @"
$blkStart
Host $ServerIp
    HostName $ServerIp
    User $SshUser
    IdentityFile "$keyFwd"
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
$blkEnd
"@
$cur = ''
if (Test-Path $sshConfig) { $cur = (Get-Content $sshConfig -Raw -ErrorAction SilentlyContinue) }
if ($null -eq $cur) { $cur = '' }
if ($cur -match [regex]::Escape($blkStart)) {
    $pat = [regex]::Escape($blkStart) + '[\s\S]*?' + [regex]::Escape($blkEnd)
    $cur = [regex]::Replace($cur, $pat, '').TrimEnd()
    Set-Content -Path $sshConfig -Value ($cur + "`r`n`r`n" + $blk + "`r`n") -Encoding ascii
} else {
    Add-Content -Path $sshConfig -Value ("`r`n" + $blk + "`r`n") -Encoding ascii
}
Say ("ssh config: " + $sshConfig + "  (Host block ensured)")

# helper: does a drive root look like our backend?
function Is-OurBackend($root) {
    return ((Test-Path (Join-Path $root 'package.json')) -and (Test-Path (Join-Path $root 'ecosystem.config.js')))
}

# already mounted via the workspace junction?
if (Test-Path (Join-Path $BackendDir 'package.json')) {
    Say "RESULT: ALREADY MOUNTED - workspace\backend already shows live files:"
    Get-ChildItem $BackendDir | Select-Object -First 12 -ExpandProperty Name | ForEach-Object { Say ("  " + $_) }
    Save; return
}

# reuse an existing drive that is already our backend, else pick a free letter
$drive = $null
foreach ($L in @('Z','Y','X','W','V','U','T','S','R','Q','P')) {
    if ((Test-Path ($L + ':\')) -and (Is-OurBackend ($L + ':\'))) { $drive = $L + ':'; break }
}
if ($drive) {
    Say ("found existing mount on " + $drive)
} else {
    $letter = $null
    foreach ($L in @('Z','Y','X','W','V','U','T','S','R','Q','P')) {
        if (-not (Test-Path ($L + ':\'))) { $letter = $L; break }
    }
    if (-not $letter) { Say "RESULT: FAILED - no free drive letter available."; Save; return }
    $drive = $letter + ':'
    Say ("drive     : " + $drive)

    # auth + host-key handling all come from ~/.ssh/config now
    $opts = "idmap=user,uid=-1,gid=-1,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3"
    $argList = @(($SshUser + "@" + $ServerIp + ":" + $RemotePath), $drive, "-o", $opts)
    if (Test-Path $ErrLog) { Remove-Item $ErrLog -Force -ErrorAction SilentlyContinue }
    Say ("mounting  : " + $SshUser + "@" + $ServerIp + ":" + $RemotePath + "  ->  " + $drive)
    Say "(connecting, please wait up to 20 seconds...)"
    Start-Process -FilePath $sshfs -ArgumentList $argList -WindowStyle Hidden -RedirectStandardError $ErrLog | Out-Null

    $mounted = $false
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 2
        if (Test-Path ($drive + '\package.json')) { $mounted = $true; break }
    }
    if (-not $mounted) {
        Say ""
        Say "RESULT: FAILED - mount did not come up. sshfs error output:"
        if ((Test-Path $ErrLog) -and ((Get-Item $ErrLog).Length -gt 0)) {
            Get-Content $ErrLog | ForEach-Object { Say ("  " + $_) }
        } else {
            Say "  (no error text captured)"
        }
        Save; return
    }
    Say ("mounted OK on " + $drive)
}

# link the drive into workspace\backend via a junction
if (Test-Path $BackendDir) { cmd /c rmdir "$BackendDir" 2>&1 | Out-Null }
if (-not (Test-Path $BackendDir)) {
    cmd /c mklink /J "$BackendDir" "$drive\" 2>&1 | ForEach-Object { Say ("  " + $_) }
}

if (Test-Path (Join-Path $BackendDir 'package.json')) {
    Say ""
    Say "RESULT: SUCCESS - backend mounted on $drive and linked into the workspace."
    Say "Live server files now in workspace\backend:"
    Get-ChildItem $BackendDir | Select-Object -First 14 -ExpandProperty Name | ForEach-Object { Say ("  " + $_) }
    Say ""
    Say "Done. Run 'fythaniya' for the full unified Claude Code session."
} else {
    Say ""
    Say "RESULT: PARTIAL - backend IS mounted and usable at $drive\ ,"
    Say "  but linking it into workspace\backend did not take."
}
Save
