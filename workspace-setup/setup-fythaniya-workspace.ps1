<#
=====================================================================
 fythaniya - unified workspace setup  (Windows native)
=====================================================================
 Builds  ~\fythaniya-workspace\  joining the two local Flutter apps
 and the LIVE backend (SSHFS mount of the GCP VM) into one folder so
 Claude Code sees frontend + backend together.

 Steps:
   1. Create workspace folders
   2. Junction the two Flutter apps  (client + admin)
   3. Mount the live backend via SSHFS-Win
   4. Add PowerShell profile functions  (mount-fythaniya, fythaniya)
   5. Install CLAUDE.md into the workspace
   6. Verify
   7. Print the daily command

 Run it (no admin rights needed):
   powershell -ExecutionPolicy Bypass -File .\setup-fythaniya-workspace.ps1

 Re-running is safe - every step is idempotent.
=====================================================================
#>

# --- config ----------------------------------------------------------
$ProjectName  = 'fythaniya'
$SshUser      = 'omar_elzanaty_almobarmg'
$ServerIp     = '34.79.246.143'
$RemotePath   = '/home/omar_elzanaty_almobarmg/fythaniya-api'

$RepoRoot     = Split-Path -Parent $PSScriptRoot              # ...\Desktop\Projects\fythaniya
$ClientSrc    = Join-Path $RepoRoot 'fythaniya'               # customer Flutter app
$AdminSrc     = Join-Path $RepoRoot 'admin_app'               # admin Flutter app

$Workspace    = Join-Path $HOME "$ProjectName-workspace"      # ~\fythaniya-workspace
$FlutterDir   = Join-Path $Workspace 'flutter-app'
$BackendDir   = Join-Path $Workspace 'backend'
$MountScript  = Join-Path $Workspace 'mount-backend.ps1'
$ClaudeMdSrc  = Join-Path $PSScriptRoot 'CLAUDE.md'
$ClaudeMdDst  = Join-Path $Workspace 'CLAUDE.md'

$summary = [System.Collections.Generic.List[string]]::new()
function Note($ok, $msg) {
    $mark = if ($ok) { '[ OK ]' } else { '[WARN]' }
    $color = if ($ok) { 'Green' } else { 'Yellow' }
    Write-Host "$mark $msg" -ForegroundColor $color
    $summary.Add("$mark $msg")
}
function Section($n, $title) { Write-Host "`n--- STEP $n - $title ---" -ForegroundColor Cyan }

Write-Host "fythaniya workspace setup" -ForegroundColor White
Write-Host "Repo root : $RepoRoot"
Write-Host "Workspace : $Workspace"

# sanity: the two Flutter source folders must exist
if (-not (Test-Path $ClientSrc)) { Write-Host "ERROR: client app not found at $ClientSrc" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $AdminSrc))  { Write-Host "ERROR: admin app not found at $AdminSrc"  -ForegroundColor Red; exit 1 }

# --- STEP 1 - workspace folders -------------------------------------
Section 1 'Create workspace folders'
# NB: do NOT pre-create backend\ - SSHFS-Win needs the mount point to not exist.
New-Item -ItemType Directory -Force -Path $Workspace, $FlutterDir | Out-Null
Note $true "workspace + flutter-app folders ready"

# --- STEP 2 - junction the Flutter apps ------------------------------
Section 2 'Link the Flutter apps'
function Link-App($name, $target) {
    $link = Join-Path $FlutterDir $name
    if (Test-Path $link) {
        $item = Get-Item $link -Force
        if ($item.LinkType -eq 'Junction') {
            Remove-Item $link -Force                          # stale junction - recreate
        } else {
            Note $false "flutter-app\$name already exists as a real folder - left untouched"
            return
        }
    }
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Note $true "flutter-app\$name  ->  $target"
}
Link-App 'client' $ClientSrc
Link-App 'admin'  $AdminSrc

# --- STEP 5 (part) - write the mount helper + CLAUDE.md --------------
# (the mount helper is written before step 3 because step 3 uses it)
Section 5 'Install mount helper + CLAUDE.md'

# mount-backend.ps1 : idempotent SSHFS-Win mount of the live backend.
# Single-quoted here-string => written verbatim; it resolves paths at its own runtime.
$mountBody = @'
<# Mounts the LIVE fythaniya backend (GCP VM) into ~\fythaniya-workspace\backend via SSHFS-Win.
   Idempotent: does nothing if already mounted. Edit the config block if the server IP changes. #>
$SshUser    = 'omar_elzanaty_almobarmg'
$ServerIp   = '34.79.246.143'
$RemotePath = '/home/omar_elzanaty_almobarmg/fythaniya-api'
$BackendDir = Join-Path $HOME 'fythaniya-workspace\backend'

function To-Cyg($p) {
    $p = $p -replace '\\','/'
    if ($p -match '^([A-Za-z]):/(.*)$') { return "/cygdrive/$($matches[1].ToLower())/$($matches[2])" }
    return $p
}

# already mounted?  (a real file from the repo proves the mount is live)
if (Test-Path (Join-Path $BackendDir 'package.json')) {
    Write-Host "[ OK ] backend already mounted" -ForegroundColor Green
    return
}

# locate sshfs.exe (SSHFS-Win)
$sshfs = @(
    "$env:ProgramFiles\SSHFS-Win\bin\sshfs.exe",
    "${env:ProgramFiles(x86)}\SSHFS-Win\bin\sshfs.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $sshfs) {
    Write-Host "[WARN] SSHFS-Win not found. Install WinFsp then SSHFS-Win:" -ForegroundColor Yellow
    Write-Host "       WinFsp     : https://winfsp.dev/rel/"
    Write-Host "       SSHFS-Win  : https://github.com/winfsp/sshfs-win/releases"
    Write-Host "       Then re-run:  mount-fythaniya"
    return
}

# the mount point must NOT exist for an SSHFS-Win directory mount
if (Test-Path $BackendDir) {
    if (@(Get-ChildItem $BackendDir -Force -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item $BackendDir -Force
    } else {
        Write-Host "[WARN] $BackendDir exists and is not empty - cannot mount over it" -ForegroundColor Yellow
        return
    }
}

# find an SSH key authorised on the VM
$key = @(
    "$HOME\.ssh\google_compute_engine",
    "$HOME\.ssh\id_ed25519",
    "$HOME\.ssh\id_rsa"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

$opts = @(
    'idmap=user','uid=-1','gid=-1',
    'reconnect','ServerAliveInterval=15','ServerAliveCountMax=3',
    'StrictHostKeyChecking=accept-new'
)
if ($key) {
    $opts += "IdentityFile=$(To-Cyg $key)"
    Write-Host "Using SSH key: $key"
} else {
    Write-Host "[WARN] No SSH key found in ~\.ssh\. The mount will fail unless your key is" -ForegroundColor Yellow
    Write-Host "       loaded another way. Generate the GCE key once with:" -ForegroundColor Yellow
    Write-Host "         gcloud compute ssh fythaniya-api --zone=europe-west1-b --project=dosadrivernew"
}

$argList = @("$SshUser@$ServerIp`:$RemotePath", $BackendDir)
foreach ($o in $opts) { $argList += '-o'; $argList += $o }

Write-Host "Mounting $SshUser@$ServerIp`:$RemotePath ..."
Start-Process -FilePath $sshfs -ArgumentList $argList -WindowStyle Hidden | Out-Null

# give FUSE a moment, then verify
for ($i = 0; $i -lt 6; $i++) {
    Start-Sleep -Seconds 2
    if (Test-Path (Join-Path $BackendDir 'package.json')) {
        Write-Host "[ OK ] backend mounted at $BackendDir" -ForegroundColor Green
        return
    }
}
Write-Host "[WARN] mount not confirmed. Check: SSHFS-Win installed, SSH key authorised on VM," -ForegroundColor Yellow
Write-Host "       VM running, IP still $ServerIp. You can also try a drive-letter mount:" -ForegroundColor Yellow
Write-Host "         net use Z: \\sshfs.kr\$SshUser@$ServerIp\home\$SshUser\fythaniya-api"
'@
Set-Content -Path $MountScript -Value $mountBody -Encoding UTF8
Note $true "mount-backend.ps1 written"

if (Test-Path $ClaudeMdSrc) {
    Copy-Item $ClaudeMdSrc $ClaudeMdDst -Force
    Note $true "CLAUDE.md installed into workspace"
} else {
    Note $false "CLAUDE.md not found next to this script - workspace CLAUDE.md NOT written"
}

# --- STEP 3 - mount the live backend --------------------------------
Section 3 'Mount the live backend (SSHFS)'
& powershell -NoProfile -ExecutionPolicy Bypass -File $MountScript
$backendMounted = Test-Path (Join-Path $BackendDir 'package.json')
Note $backendMounted ("backend mount " + ($(if($backendMounted){'verified'}else{'NOT verified - see warnings above'})))

# --- STEP 4 - PowerShell profile functions --------------------------
Section 4 'Add shell aliases to PowerShell profile'
$profilePath = $PROFILE                                       # current-user, current-host
$profileDir  = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Force -Path $profilePath | Out-Null }

$blockStart = '# >>> fythaniya workspace >>>'
$blockEnd   = '# <<< fythaniya workspace <<<'
$block = @"
$blockStart
# 'mount-fythaniya' : (re)mount the live backend.   'fythaniya' : start a Claude Code session.
`$FythaniyaWorkspace = Join-Path `$HOME 'fythaniya-workspace'
function mount-fythaniya { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path `$FythaniyaWorkspace 'mount-backend.ps1') }
function fythaniya {
    if (-not (Test-Path (Join-Path `$FythaniyaWorkspace 'backend\package.json'))) { mount-fythaniya }
    Set-Location `$FythaniyaWorkspace
    if (Get-Command claude -ErrorAction SilentlyContinue) { claude }
    else { Write-Host "Claude Code CLI ('claude') not on PATH - install it, then run 'claude' here." -ForegroundColor Yellow }
}
$blockEnd
"@

$current = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($null -eq $current) { $current = '' }
if ($current -match [regex]::Escape($blockStart)) {
    # strip the old block (replacement is '' so $-signs in $block are never interpreted),
    # then append the fresh block by plain string concatenation
    $pattern = [regex]::Escape($blockStart) + '[\s\S]*?' + [regex]::Escape($blockEnd)
    $current = [regex]::Replace($current, $pattern, '').TrimEnd()
    Set-Content -Path $profilePath -Value ($current + "`r`n`r`n" + $block + "`r`n") -Encoding UTF8
    Note $true "profile updated (replaced existing fythaniya block): $profilePath"
} else {
    Add-Content -Path $profilePath -Value ("`r`n" + $block + "`r`n") -Encoding UTF8
    Note $true "profile updated (added fythaniya block): $profilePath"
}

# --- STEP 6 - verify -------------------------------------------------
Section 6 'Verify'
$checks = @(
    @{ n = 'workspace folder';        ok = (Test-Path $Workspace) }
    @{ n = 'flutter-app\client link'; ok = (Test-Path (Join-Path $FlutterDir 'client\pubspec.yaml')) }
    @{ n = 'flutter-app\admin link';  ok = (Test-Path (Join-Path $FlutterDir 'admin\pubspec.yaml')) }
    @{ n = 'backend mounted (real files)'; ok = (Test-Path (Join-Path $BackendDir 'package.json')) }
    @{ n = 'CLAUDE.md present';       ok = (Test-Path $ClaudeMdDst) }
    @{ n = 'mount-backend.ps1 present'; ok = (Test-Path $MountScript) }
)
foreach ($c in $checks) { Note $c.ok $c.n }

# --- summary + STEP 7 ------------------------------------------------
Write-Host "`n=====================================================================" -ForegroundColor White
Write-Host " SETUP SUMMARY" -ForegroundColor White
Write-Host "=====================================================================" -ForegroundColor White
$summary | ForEach-Object { Write-Host "  $_" }

Write-Host "`n  Workspace layout:" -ForegroundColor White
Write-Host "    $Workspace\"
Write-Host "      flutter-app\client\  -> $ClientSrc"
Write-Host "      flutter-app\admin\   -> $AdminSrc"
Write-Host "      backend\             -> $SshUser@$ServerIp`:$RemotePath  (SSHFS)"
Write-Host "      CLAUDE.md"
Write-Host "      mount-backend.ps1"

if (-not $backendMounted) {
    Write-Host "`n  NOTE: the backend mount is not confirmed yet. Install WinFsp + SSHFS-Win" -ForegroundColor Yellow
    Write-Host "        and make sure your SSH key works, then run:  mount-fythaniya" -ForegroundColor Yellow
}

Write-Host "`n--- STEP 7 - your daily command ---" -ForegroundColor Cyan
Write-Host "  Open a NEW PowerShell window (so the profile loads), then just run:" -ForegroundColor White
Write-Host "      fythaniya" -ForegroundColor Green
Write-Host "  That re-mounts the backend if needed, cd's into the workspace, and starts Claude Code."
Write-Host ""
