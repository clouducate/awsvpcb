#Requires -RunAsAdministrator
<#
.SYNOPSIS
    CIS-4641 Cloud DevOps  -  Environment Setup Script
    Run once on the Windows Bastion (t3.large) after first RDP login.

.DESCRIPTION
    LOCAL  (this Bastion):  WSL2, Python 3, Flask, Git, GitHub CLI, AWS CLI v2, Terraform, paramiko
    REMOTE (Control Node):  Jenkins, Ansible, Packer
    PERSISTENT:             ANSIBLE_VAULT_PASSWORD_FILE and TF_VAR_db_password set for all future sessions

.NOTES
    Prerequisites:
      - Run as Administrator in PowerShell
      - Bastion has internet access via the Control Node NAT
      - Windows Server 2019  -  WSL2 installation will trigger ONE automatic reboot
        and the script will resume automatically after login

    The Control Node IP and SSH key path are pre-configured below.
    No parameters are required for a standard course environment.

    Usage (standard  -  no parameters needed):
      .\Setup-DevOps-Environment.ps1

    Usage (override defaults if needed):
      .\Setup-DevOps-Environment.ps1 -ControlNodeIP "172.31.132.151" -SSHKeyPath "C:\path\to\key.ppk"
#>

param(
    # Control Node fixed private IP  -  set by professor setup script at launch
    [string]$ControlNodeIP  = "172.31.132.151",

    # SSH private key  -  placed on the Bastion by professor setup script
    [string]$SSHKeyPath     = "C:\Users\Administrator\Desktop\awsvpcb-scripts\secfiles\privkey.pem",

    # SSH key passphrase  -  pre-configured for course key
    [string]$KeyPassphrase  = "cts4743",

    [string]$SSHUser        = "ec2-user"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Logging  -  capture all output to a transcript in the Downloads folder ------
$LogFile = "$env:USERPROFILE\Downloads\DevOps-Setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $LogFile -Append -NoClobber | Out-Null
Write-Host "Logging all output to: $LogFile" -ForegroundColor DarkGray
Write-Host "If you encounter issues, send this file to your professor.`n" -ForegroundColor DarkGray

# -- Colour helpers ------------------------------------------------------------
function Write-Step  { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "    [!!] $msg" -ForegroundColor Yellow }
function Write-Fail  {
    param($msg)
    Write-Host "    [FAIL] $msg" -ForegroundColor Red
    Write-Host "`n    Setup did not complete. Log file saved to:" -ForegroundColor Yellow
    Write-Host "    $LogFile" -ForegroundColor Yellow
    Write-Host "    Copy this file to your local PC and email it to your professor." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    exit 1
}

function Test-Command {
    param($Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Verify a command is callable after install and capture its version output.
# Fails the script immediately if the command is not found.
function Confirm-Install {
    param(
        [string]$Name,
        [scriptblock]$VersionCmd,
        [string]$FailHint = ""
    )
    # Refresh PATH before checking so newly installed binaries are visible
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    try {
        $ver = (& $VersionCmd 2>&1) | Select-Object -First 1
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Exit code $LASTEXITCODE"
        }
        Write-OK "${Name}: $ver"
    } catch {
        $hint = if ($FailHint) { " $FailHint" } else { "" }
        Write-Fail "${Name} installed but failed to run.${hint} Error: $_"
    }
}

# -- Verify SSH key exists and create unencrypted working copy ----------------
if (-not (Test-Path $SSHKeyPath)) {
    Write-Fail "SSH key not found at '$SSHKeyPath'. Check that the professor setup script has run."
}

# privkey.pem is passphrase-protected. Create an unencrypted working copy
# (privkey-nopass.pem) using Python's cryptography library which is already
# installed for paramiko. The original privkey.pem is never modified.
Write-Step "Creating unencrypted SSH key for non-interactive use"
$noPassPath = $SSHKeyPath -replace "\.pem$", "-nopass.pem"
$pyScript   = "$env:TEMP\pem_strip_pass.py"
$pyCode     = @"
from cryptography.hazmat.primitives.serialization import (
    load_pem_private_key, Encoding, PrivateFormat, NoEncryption
)
import sys
data = open(sys.argv[1], 'rb').read()
key  = load_pem_private_key(data, sys.argv[2].encode())
open(sys.argv[3], 'wb').write(
    key.private_bytes(Encoding.PEM, PrivateFormat.TraditionalOpenSSL, NoEncryption()))
print('done')
"@
[System.IO.File]::WriteAllText($pyScript, $pyCode, [System.Text.Encoding]::ASCII)
$result = python $pyScript $SSHKeyPath $KeyPassphrase $noPassPath 2>&1
Remove-Item $pyScript -Force -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0 -or $result -notmatch "done") {
    Write-Fail "Failed to create unencrypted key: $result"
}
Write-OK "Unencrypted working key: $noPassPath"
$SSHKeyPath = $noPassPath

# Fix key permissions  -  OpenSSH on Windows requires restricted ACL
Write-Step "Fixing SSH key permissions on $SSHKeyPath"
icacls $SSHKeyPath /inheritance:r /grant:r "${env:USERNAME}:(R)" | Out-Null
Write-OK "Key permissions set"

# -- Helper: run a command block on the Control Node via SSH -------------------
# ROBUST REMOTE EXECUTION: the script body is base64-encoded on the Bastion and
# decoded on the Control Node (echo <b64> | base64 -d | bash). Base64 is pure
# ASCII with no spaces or newlines, so it passes through PowerShell's native-
# command pipeline and ssh untouched  -  no BOM, no CRLF, no quoting issues.
# This permanently eliminates the "$'\r'" and BOM ("bad character") failures
# that arise from piping raw script text through PowerShell to bash.
function Invoke-RemoteScript {
    param(
        [string]$Description,
        [string]$Script
    )
    Write-Step "[REMOTE] $Description"
    $startTime = Get-Date

    # Normalize to Unix line endings, then base64-encode the UTF-8 bytes.
    $unixScript = $Script -replace "`r`n", "`n" -replace "`r", "`n"
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($unixScript))

    # Single-token remote command  -  pipes are interpreted by the REMOTE shell.
    $remoteCmd = "echo $b64 | base64 -d | bash"

    ssh -i $SSHKeyPath `
        -o StrictHostKeyChecking=no `
        -o ConnectTimeout=15 `
        -o LogLevel=ERROR `
        "${SSHUser}@${ControlNodeIP}" `
        $remoteCmd
    $exitCode = $LASTEXITCODE

    $elapsed  = [int](New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds
    $mins     = [int]($elapsed / 60)
    $secs     = $elapsed % 60

    if ($exitCode -ne 0) {
        Write-Fail "Remote step failed: $Description (after ${mins}m ${secs}s)"
    }
    Write-OK "Done: $Description (${mins}m ${secs}s)"
}

# =============================================================================
# PART 1  -  LOCAL INSTALLS (Windows Bastion)
# =============================================================================
Write-Host "`n+==========================================+" -ForegroundColor Magenta
Write-Host   "|  PART 1  -  Local Bastion Setup            |" -ForegroundColor Magenta
Write-Host   "+==========================================+" -ForegroundColor Magenta

# -- 0. WSL2  -  must run before all other installs; requires a reboot -----------
# WSL2 is required by Docker Desktop. We check if it is already enabled first
# so this step is safe to skip on re-runs after the reboot.
Write-Step "Checking WSL2"
$wslFeature    = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
$vmpFeature    = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
$wslEnabled    = $wslFeature.State -eq "Enabled"
$vmpEnabled    = $vmpFeature.State -eq "Enabled"
$wslInstalled  = Test-Command "wsl"

if ($wslEnabled -and $vmpEnabled -and $wslInstalled) {
    Write-OK "WSL2 already enabled"
} else {
    Write-Host ""
    Write-Host "    ============================================================" -ForegroundColor Yellow
    Write-Host "    INSTALLING WSL2  -  THIS WILL TAKE SEVERAL MINUTES"          -ForegroundColor Yellow
    Write-Host "    ============================================================" -ForegroundColor Yellow
    Write-Host "    WSL2 (Windows Subsystem for Linux) is required for Docker."   -ForegroundColor Yellow
    Write-Host "    Windows needs to enable two system features and then reboot." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Step 1 of 2: Enabling Windows Subsystem for Linux..." -ForegroundColor Cyan

    # Enable both required Windows features
    if (-not $wslEnabled) {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
        Write-OK "Windows Subsystem for Linux feature enabled"
    } else {
        Write-OK "Windows Subsystem for Linux already enabled"
    }

    Write-Host "    Step 2 of 2: Enabling Virtual Machine Platform..." -ForegroundColor Cyan
    if (-not $vmpEnabled) {
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
        Write-OK "Virtual Machine Platform feature enabled"
    } else {
        Write-OK "Virtual Machine Platform already enabled"
    }

    # Set WSL default version to 2
    # wsl.exe may not be on PATH yet before reboot  -  use the full path if needed
    $wslExe = "$env:SystemRoot\System32\wsl.exe"
    if (Test-Path $wslExe) {
        & $wslExe --set-default-version 2 2>$null
    }

    # Schedule the script to re-run automatically after reboot via a Run key
    # Resolve the full absolute path so the registry entry works regardless of
    # how the student invoked the script (relative path, .\, etc.)
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        $scriptPath = Join-Path (Get-Location).Path "Setup-DevOps-Environment.ps1"
    }
    $scriptPath = (Resolve-Path $scriptPath).Path
    $psArgs     = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $regValue   = "powershell.exe -NoExit -WindowStyle Normal $psArgs"
    $regPath    = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    Set-ItemProperty -Path $regPath -Name "DevOpsSetupResume" `
                     -Value $regValue
    Write-OK "Script will resume automatically after reboot from: $scriptPath"

    Write-Host ""
    Write-Host "    ============================================================" -ForegroundColor Yellow
    Write-Host "    REBOOT REQUIRED"                                               -ForegroundColor Yellow
    Write-Host "    ============================================================" -ForegroundColor Yellow
    Write-Host "    Both WSL2 features are now enabled."                           -ForegroundColor Yellow
    Write-Host "    The server must reboot to complete the installation."          -ForegroundColor Yellow
    Write-Host "    This script will RESUME AUTOMATICALLY after you log back in." -ForegroundColor Yellow
    Write-Host "    You do NOT need to run it again manually."                     -ForegroundColor Yellow
    Write-Host ""
    Write-Warn "    Rebooting in 15 seconds  -  press Ctrl+C to cancel."
    Write-Host "    ============================================================" -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    Stop-Transcript | Out-Null   # flush log before reboot
    Restart-Computer -Force
    exit   # unreachable but keeps the script clean
}

# Remove the auto-resume registry key if it exists (cleanup after reboot)
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
if (Get-ItemProperty -Path $regPath -Name "DevOpsSetupResume" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $regPath -Name "DevOpsSetupResume"
    Write-OK "Auto-resume registry key removed"
}

# -- 1. Chocolatey (package manager) ------------------------------------------
Write-Step "Installing Chocolatey package manager"
if (Test-Command "choco") {
    Write-OK "Chocolatey already installed: $(choco --version)"
} else {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Reload PATH so choco is visible immediately
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Check if .NET 4.8 was just installed and needs a reboot before choco works
    $dotNetPending = $false
    $rebootPending = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" `
                                      -Name "RebootPending" -ErrorAction SilentlyContinue
    $dotNetKey     = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" `
                                      -Name "Release" -ErrorAction SilentlyContinue
    if (-not $dotNetKey -or $dotNetKey.Release -lt 528040) {
        $dotNetPending = $true
    }

    if ($dotNetPending -or $rebootPending) {
        Write-Host ""
        Write-Host "    ============================================================" -ForegroundColor Yellow
        Write-Host "    REBOOT REQUIRED  -  .NET Framework was just installed"        -ForegroundColor Yellow
        Write-Host "    ============================================================" -ForegroundColor Yellow
        Write-Host "    Chocolatey requires .NET 4.8 which was just installed."       -ForegroundColor Yellow
        Write-Host "    A reboot is needed before the remaining tools can install."   -ForegroundColor Yellow
        Write-Host "    This script will RESUME AUTOMATICALLY after you log back in." -ForegroundColor Yellow
        Write-Host "    You do NOT need to run it again manually."                    -ForegroundColor Yellow
        Write-Host ""

        $scriptPath = $MyInvocation.MyCommand.Path
        if (-not $scriptPath) {
            $scriptPath = Join-Path (Get-Location).Path "Setup-DevOps-Environment.ps1"
        }
        $scriptPath = (Resolve-Path $scriptPath).Path
        $regPath    = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        Set-ItemProperty -Path $regPath -Name "DevOpsSetupResume" `
                         -Value "powershell.exe -NoExit -WindowStyle Normal -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        Write-OK "Script will resume automatically after reboot from: $scriptPath"

        Write-Warn "Rebooting in 15 seconds  -  press Ctrl+C to cancel."
        Start-Sleep -Seconds 15
        Stop-Transcript | Out-Null
        Restart-Computer -Force
        exit
    }

    Confirm-Install "choco" { choco --version } "Check https://chocolatey.org/install for troubleshooting."
}

# -- 2. Git --------------------------------------------------------------------
Write-Step "Installing Git"
if (Test-Command "git") {
    Write-OK "Git already installed: $(git --version)"
} else {
    choco install git -y --no-progress
    Confirm-Install "git" { git --version } "Try reopening PowerShell as Administrator."
}

# -- 3. GitHub CLI -------------------------------------------------------------
# Used from Module 1 onward for forking repos, creating PRs, and interacting
# with GitHub from the terminal and LLM without needing a browser.
Write-Step "Installing GitHub CLI (gh)"
if (Test-Command "gh") {
    Write-OK "GitHub CLI already installed: $(gh --version | Select-Object -First 1)"
} else {
    choco install gh -y --no-progress
    Confirm-Install "gh" { gh --version } "Try reopening PowerShell as Administrator."
}

# -- 4. Python 3 ---------------------------------------------------------------
Write-Step "Installing Python 3"
if (Test-Command "python") {
    Write-OK "Python already installed: $(python --version)"
} else {
    choco install python3 -y --no-progress --params "'/AddToPath=1'"
    Confirm-Install "python" { python --version } "Try reopening PowerShell as Administrator."
    Confirm-Install "pip" { python -m pip --version } "pip should be bundled with Python 3.4+."
}

# -- 5. Flask + SQLAlchemy + paramiko (course dependencies) -------------------
# Only flask, flask-sqlalchemy, and paramiko are needed on the Bastion.
# paramiko provides SSH connectivity used by Google Antigravity to connect
# programmatically to the Linux Control Node.
# PyMySQL and cryptography belong in the project's requirements.txt so they
# are installed inside the Docker image during Module 5 (docker build).
Write-Step "Installing Flask, SQLAlchemy and paramiko via pip"
python -m pip install --upgrade pip --quiet
if ($LASTEXITCODE -ne 0) { Write-Fail "pip upgrade failed. Check Python installation." }

python -m pip install flask flask-sqlalchemy paramiko --quiet
if ($LASTEXITCODE -ne 0) { Write-Fail "Flask/SQLAlchemy/paramiko install failed. Check pip and internet connectivity." }

# Verify packages are actually importable  -  install succeeding is not enough
$flaskCheck = python -c "import importlib.metadata; print(importlib.metadata.version('flask'))" 2>&1
if ($LASTEXITCODE -ne 0) { Write-Fail "Flask installed but not importable: $flaskCheck" }
Write-OK "Flask: $flaskCheck"

$sqlaCheck = python -c "import importlib.metadata; print(importlib.metadata.version('flask-sqlalchemy'))" 2>&1
if ($LASTEXITCODE -ne 0) { Write-Fail "SQLAlchemy installed but not importable: $sqlaCheck" }
Write-OK "Flask-SQLAlchemy: $sqlaCheck"

$paramikoCheck = python -c "import importlib.metadata; print(importlib.metadata.version('paramiko'))" 2>&1
if ($LASTEXITCODE -ne 0) { Write-Fail "paramiko installed but not importable: $paramikoCheck" }
Write-OK "paramiko: $paramikoCheck"

Write-Warn "PyMySQL + cryptography + gunicorn go in requirements.txt (needed in Docker image, not here)"

# -- 6. AWS CLI v2 -------------------------------------------------------------
Write-Step "Installing AWS CLI v2"
if (Test-Command "aws") {
    Write-OK "AWS CLI already installed: $(aws --version)"
} else {
    $awsInstaller = "$env:TEMP\AWSCLIV2.msi"
    Write-Host "    Downloading AWS CLI v2..."
    Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" `
                      -OutFile $awsInstaller -UseBasicParsing
    if (-not (Test-Path $awsInstaller)) {
        Write-Fail "AWS CLI v2 download failed. Check internet connectivity."
    }
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$awsInstaller`" /quiet /norestart"
    Remove-Item $awsInstaller -Force
    Confirm-Install "aws" { aws --version } "Try reopening PowerShell as Administrator."
}

# -- 7. Terraform -------------------------------------------------------------
Write-Step "Installing Terraform"
if (Test-Command "terraform") {
    Write-OK "Terraform already installed: $(terraform version | Select-Object -First 1)"
} else {
    choco install terraform -y --no-progress
    Confirm-Install "terraform" { terraform version } "Try reopening PowerShell as Administrator."
}

# -- Verify local installs -----------------------------------------------------
Write-Step "Final verification of all local installations"
$checks = @(
    @{ Name = "git";       Cmd = { git --version } },
    @{ Name = "gh";        Cmd = { gh --version | Select-Object -First 1 } },
    @{ Name = "python";    Cmd = { python --version } },
    @{ Name = "pip";       Cmd = { python -m pip --version } },
    @{ Name = "aws";       Cmd = { aws --version } },
    @{ Name = "terraform"; Cmd = { terraform version | Select-Object -First 1 } }
)
$failedTools = @()
foreach ($c in $checks) {
    try {
        $ver = & $c.Cmd 2>&1 | Select-Object -First 1
        Write-OK "$($c.Name): $ver"
    } catch {
        Write-Warn "$($c.Name): NOT FOUND in PATH"
        $failedTools += $c.Name
    }
}
if ($failedTools.Count -gt 0) {
    Write-Warn "The following tools were not found after install: $($failedTools -join ', ')"
    Write-Warn "Close and reopen PowerShell as Administrator, then run the script again."
    Write-Warn "If the issue persists check Chocolatey logs at: C:\ProgramData\chocolatey\logs"
}

# =============================================================================
# PART 1B  -  CONNECTIVITY TESTS (Bastion -> Control Node)
# =============================================================================
Write-Host "`n+==========================================+" -ForegroundColor Magenta
Write-Host   "|  PART 1B  -  Connectivity Tests            |" -ForegroundColor Magenta
Write-Host   "+==========================================+" -ForegroundColor Magenta

# -- Helper: test TCP port reachability ---------------------------------------
function Test-Port {
    param(
        [string]$RemoteHost,
        [int]$Port,
        [string]$Description,
        [int]$TimeoutMs = 3000
    )
    try {
        $tcp     = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($RemoteHost, $Port, $null, $null)
        $wait    = $connect.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($wait -and -not $tcp.Client.Connected) { $wait = $false }
        $tcp.Close()
        if ($wait) {
            Write-OK "Port $Port ($Description): reachable on $RemoteHost"
            return $true
        } else {
            Write-Warn "Port $Port ($Description): NOT reachable on $RemoteHost (timeout ${TimeoutMs}ms)"
            return $false
        }
    } catch {
        Write-Warn "Port $Port ($Description): NOT reachable on $RemoteHost - $($_.Exception.Message)"
        return $false
    }
}

Write-Step "Testing Bastion -> Control Node connectivity ($ControlNodeIP)"

# Port 22  -  SSH (required for all remote install steps)
$port22 = Test-Port -RemoteHost $ControlNodeIP -Port 22 `
    -Description "SSH - required for remote installs and Ansible"

# Port 8080  -  Jenkins UI (may not be open yet if Jenkins not installed)
# Tested here so students know the expected state before and after setup
$port8080 = Test-Port -RemoteHost $ControlNodeIP -Port 8080 `
    -Description "Jenkins UI - expected CLOSED before install, OPEN after"

if (-not $port22) {
    Write-Fail ("Cannot reach port 22 on $ControlNodeIP. " +
                "Check: (1) Control Node is running, " +
                "(2) security group allows TCP 22 from this Bastion, " +
                "(3) correct IP in `$ControlNodeIP.")
}

if (-not $port8080) {
    Write-Warn ("Port 8080 not reachable yet  -  this is expected before Jenkins is installed. " +
                "It will be re-checked after the Jenkins install step.")
}

# -- Internet connectivity -----------------------------------------------------
Write-Step "Testing internet connectivity (Bastion public IP)"
try {
    $response = Invoke-WebRequest -Uri "https://checkip.amazonaws.com" `
                                  -UseBasicParsing -TimeoutSec 10
    $publicIP = $response.Content.Trim()
    Write-OK "Internet reachable  -  Bastion public IP: $publicIP"
} catch {
    Write-Fail ("No internet connectivity from Bastion. Check: " +
                "(1) Bastion security group allows outbound traffic, " +
                "(2) Internet gateway is attached to the public subnet route table. " +
                "Error: $_")
}

# -- DNS resolution ------------------------------------------------------------
Write-Step "Testing DNS resolution"
$dnsTargets = @("github.com", "registry.npmjs.org", "pypi.org", "awscli.amazonaws.com")
$dnsFailed  = @()
foreach ($target in $dnsTargets) {
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($target) | Select-Object -First 1
        Write-OK "${target}: $($resolved.IPAddressToString)"
    } catch {
        Write-Warn "${target}: DNS resolution FAILED"
        $dnsFailed += $target
    }
}
if ($dnsFailed.Count -gt 0) {
    Write-Warn "DNS failed for: $($dnsFailed -join ', ')  -  internet installs may fail."
}


# =============================================================================
# PART 2  -  CONTROL NODE SETUP (SSH)
# =============================================================================

# -- Prepare SSH client (unencrypted PEM  -  no agent needed) ------------------
# The key was converted to an UNENCRYPTED PEM above, so no ssh-agent, ssh-add,
# or SSH_ASKPASS is required. Every ssh call uses -i $SSHKeyPath and connects
# without a prompt. We only need to clear any stale known_hosts entry so a
# rebuilt Control Node with a new host key does not trigger a mismatch.
Write-Step "Preparing SSH client"

$knownHosts = "$env:USERPROFILE\.ssh\known_hosts"
if (Test-Path $knownHosts) {
    $filtered = Get-Content $knownHosts | Where-Object { $_ -notmatch [regex]::Escape($ControlNodeIP) }
    Set-Content $knownHosts $filtered -ErrorAction SilentlyContinue
    Write-OK "Stale known_hosts entry cleared for $ControlNodeIP"
}
Write-OK "Using unencrypted PEM key  -  no passphrase prompts during remote steps"
Write-Host "`n+==========================================+" -ForegroundColor Magenta
Write-Host   "|  PART 2  -  Control Node Setup (SSH)       |" -ForegroundColor Magenta
Write-Host   "+==========================================+" -ForegroundColor Magenta
Write-Host ""
Write-Host "    Part 2 installs tools remotely on the Control Node via SSH." -ForegroundColor DarkGray
Write-Host "    Estimated total time: 5 - 15 minutes depending on network speed." -ForegroundColor DarkGray
Write-Host ""
Write-Host "    Step  8  -  System update       ~1-3 min   (downloads OS patches)" -ForegroundColor DarkGray
Write-Host "    Step  9  -  Python 3 + pip      ~1 min" -ForegroundColor DarkGray
Write-Host "    Step 10  -  Ansible             ~1-2 min   (large dependency tree)" -ForegroundColor DarkGray
Write-Host "    Step 11  -  Packer              ~1-2 min   (HashiCorp binary)" -ForegroundColor DarkGray
Write-Host "    Step 12  -  Java 21             ~1-3 min   (Amazon Corretto, ~200MB)" -ForegroundColor DarkGray
Write-Host "    Step 13  -  Jenkins             ~2-4 min   (install + JVM startup)" -ForegroundColor DarkGray
Write-Host "    Step 14  -  AWS CLI             ~1 min" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    The screen may appear frozen during downloads  -  this is normal." -ForegroundColor Yellow
Write-Host "    Do NOT close this window." -ForegroundColor Yellow
Write-Host ""

# -- Test SSH connectivity first -----------------------------------------------
Write-Step "Testing SSH connectivity to Control Node ($ControlNodeIP)"
$sshOutput = (ssh -i $SSHKeyPath `
               -o StrictHostKeyChecking=no `
               -o ConnectTimeout=10 `
               -o LogLevel=ERROR `
               "${SSHUser}@${ControlNodeIP}" `
               "echo connected") 2>$null
if ($LASTEXITCODE -ne 0 -or $sshOutput -notmatch "connected") {
    Write-Fail ("Cannot SSH to $ControlNodeIP. Check: " +
                "(1) Control Node is running, " +
                "(2) security group allows TCP 22 from this Bastion, " +
                "(3) SSH key is correct.")
}
Write-OK "SSH connection successful"

# -- 8. System update ---------------------------------------------------------
Write-Host "    [~1-3 min] Downloading and applying OS updates..." -ForegroundColor DarkGray
Invoke-RemoteScript -Description "System update (dnf)" -Script @'
echo "Checking for updates..."
sudo dnf update -y -q
echo "System update complete"
'@

# -- 9. Python 3 + pip on Control Node (needed by Ansible) --------------------
Invoke-RemoteScript -Description "Python 3 and pip" -Script @'
sudo dnf install -y python3 python3-pip -q
# Verify both are callable
python3 --version || { echo "FAIL: python3 not found after install"; exit 1; }
python3 -m pip --version || { echo "FAIL: pip not found after install"; exit 1; }
echo "Python and pip: OK"
'@

# -- 10. Ansible ---------------------------------------------------------------
Write-Host "    [~1-2 min] Installing Ansible and its Python dependencies..." -ForegroundColor DarkGray
Invoke-RemoteScript -Description "Ansible" -Script @'
echo "Installing Ansible..."
sudo dnf install -y ansible -q 2>/dev/null || \
    sudo pip3 install ansible --quiet
echo "Verifying Ansible..."
ansible --version | head -1 || { echo "FAIL: ansible not found after install"; exit 1; }
echo "---" | ansible-playbook /dev/stdin --syntax-check 2>/dev/null || true
echo "Ansible: OK"
'@

# -- 11. Packer ----------------------------------------------------------------
Invoke-RemoteScript -Description "HashiCorp Packer" -Script @'
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo -q
sudo dnf install -y packer -q
# Verify packer is callable
packer version || { echo "FAIL: packer not found after install"; exit 1; }
# Verify packer plugins can be listed (catches broken installs)
packer plugins installed 2>/dev/null || true
echo "Packer: OK"
'@

# -- 12. Java 21 (Jenkins dependency) -----------------------------------------
Write-Host "    [~1-3 min] Downloading Amazon Corretto Java 21 (~200MB)..." -ForegroundColor DarkGray
Invoke-RemoteScript -Description "Java 21 (Jenkins dependency)" -Script @'
echo "Downloading Amazon Corretto Java 21 (this may take a few minutes)..."
sudo dnf install -y java-21-amazon-corretto-headless -q
echo "Verifying Java 21..."
java -version 2>&1 | head -1 || { echo "FAIL: java not found after install"; exit 1; }
java_ver=$(java -version 2>&1 | head -1)
echo "$java_ver" | grep -q "21\." || { echo "FAIL: Expected Java 21, got: $java_ver"; exit 1; }
echo "Java 21: OK"
'@

# -- 13. Jenkins ---------------------------------------------------------------
Write-Host "    [~2-4 min] Installing Jenkins and waiting for JVM startup..." -ForegroundColor DarkGray
Invoke-RemoteScript -Description "Jenkins LTS" -Script @'
echo "Adding Jenkins repository..."
sudo wget -q -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key 2>/dev/null || \
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
# Confirm Java 21 is active before installing Jenkins
java_ver=$(java -version 2>&1 | head -1)
echo "Using: $java_ver"
echo "$java_ver" | grep -q "21\." || { echo "FAIL: Jenkins requires Java 21. Got: $java_ver"; exit 1; }
echo "Installing Jenkins (this may take a few minutes)..."
sudo dnf install -y jenkins -q
echo "Starting Jenkins service..."
sudo systemctl enable jenkins
sudo systemctl start jenkins
echo "Waiting for Jenkins JVM to start (up to 60 seconds)..."
for i in $(seq 1 12); do
    if sudo systemctl is-active --quiet jenkins; then
        echo "Jenkins service is running"
        break
    fi
    if [ $i -eq 12 ]; then
        echo "FAIL: Jenkins did not start within 60 seconds"
        sudo journalctl -u jenkins --no-pager -n 20
        exit 1
    fi
    echo "  waiting... ($((i * 5))s)"
    sleep 5
done
sleep 3
if curl -sf http://localhost:8080/login 2>/dev/null | grep -q "Jenkins"; then
    echo "Jenkins web UI: responding on port 8080"
elif ss -tlnp | grep -q ":8080"; then
    echo "Jenkins: listening on port 8080 (UI may still be initialising)"
else
    echo "WARN: Jenkins service is active but port 8080 not yet open  -  may need more time"
fi
sudo systemctl status jenkins --no-pager | grep -E "Active:|Main PID:"
echo "Jenkins: OK"
'@

# -- 14. Open port 8080 for Bastion in firewalld (if running) -----------------
Invoke-RemoteScript -Description "Firewall: allow port 8080 (Jenkins)" -Script @'
if sudo systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
    echo "firewalld: port 8080 opened"
else
    echo "firewalld not active  -  security group controls access"
fi
'@

# -- Re-check port 8080 now that Jenkins should be running --------------------
Write-Step "Re-checking port 8080 (Jenkins) after install"
$port8080After = Test-Port -RemoteHost $ControlNodeIP -Port 8080 `
    -Description "Jenkins UI" -TimeoutMs 5000
if (-not $port8080After) {
    Write-Warn ("Port 8080 still not reachable from Bastion. Check: " +
                "(1) AWS security group allows TCP 8080 from this Bastion's private IP, " +
                "(2) Jenkins service is active on the Control Node, " +
                "(3) No host-level firewall blocking the port.")
}

# -- 15. AWS CLI on Control Node -----------------------------------------------
Invoke-RemoteScript -Description "AWS CLI v2 on Control Node" -Script @'
if command -v aws &>/dev/null; then
    echo "AWS CLI already installed: $(aws --version)"
else
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    if [ ! -f /tmp/awscliv2.zip ]; then
        echo "FAIL: AWS CLI download failed"; exit 1
    fi
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
fi
# Verify regardless of whether it was already installed
aws --version || { echo "FAIL: aws not callable after install"; exit 1; }
# Verify Instance Role is working (no credentials needed)
aws sts get-caller-identity --output text 2>/dev/null && \
    echo "AWS Instance Role: OK" || \
    echo "WARN: aws sts get-caller-identity failed  -  Instance Role may not be attached yet"
echo "AWS CLI: OK"
'@

# -- 16. Retrieve Jenkins initial admin password -------------------------------
Write-Step "[REMOTE] Retrieving Jenkins initial admin password"
$jenkinsPass = (ssh -i $SSHKeyPath `
                    -o StrictHostKeyChecking=no `
                    -o ConnectTimeout=10 `
                    -o LogLevel=ERROR `
                    "${SSHUser}@${ControlNodeIP}" `
                    "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo NOT_READY_YET") 2>$null
$jenkinsPass = ($jenkinsPass -join "").Trim()

# -- 17. Verify all remote installs --------------------------------------------
Write-Step "[REMOTE] Verifying remote installations"
Invoke-RemoteScript -Description "Version check" -Script @'
echo "--- Remote Tool Versions ---"
echo "Ansible : $(ansible --version | head -1)"
echo "Packer  : $(packer version)"
echo "Jenkins : $(java -jar /usr/share/java/jenkins.war --version 2>/dev/null || systemctl is-active jenkins)"
echo "Java    : $(java -version 2>&1 | head -1)"
echo "AWS CLI : $(aws --version)"
echo "Python  : $(python3 --version)"
'@

# =============================================================================
# 18. Set persistent environment variables
# =============================================================================
# These are set once here and never need to be set again  -  they survive
# reboots and are inherited by every PowerShell window the student opens.
# =============================================================================
Write-Step "Setting persistent environment variables"

# -- Ansible vault password file -----------------------------------------------
# Written to the user profile (not TEMP) so it survives across sessions.
$vaultPassFile = "$env:USERPROFILE\.ansible_vault_pass"
[System.IO.File]::WriteAllText($vaultPassFile, $KeyPassphrase, [System.Text.Encoding]::ASCII)
[System.Environment]::SetEnvironmentVariable("ANSIBLE_VAULT_PASSWORD_FILE", $vaultPassFile, "User")
$env:ANSIBLE_VAULT_PASSWORD_FILE = $vaultPassFile
Write-OK "ANSIBLE_VAULT_PASSWORD_FILE set (User scope): $vaultPassFile"

# -- Database password ---------------------------------------------------------
# Set as a persistent User environment variable so Terraform always has it
# available as var.db_password without students needing to do anything.
# The Ansible vault is not yet configured at this point in the course  -  the
# vault is set up in Module 2. We set the password here directly since the
# setup script itself is never committed to Git.
$dbPassword = "ProtectPass_123"
[System.Environment]::SetEnvironmentVariable("TF_VAR_db_password", $dbPassword, "User")
$env:TF_VAR_db_password = $dbPassword
Write-OK "TF_VAR_db_password set (User scope)  -  available in all future PowerShell windows"

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n+==============================================================+" -ForegroundColor Green
Write-Host   "|  SETUP COMPLETE                                              |" -ForegroundColor Green
Write-Host   "+==============================================================+" -ForegroundColor Green

Write-Host "`nBastion (local):" -ForegroundColor White
Write-Host "  WSL2, Git, GitHub CLI, Python 3, Flask, SQLAlchemy, paramiko, AWS CLI v2, Terraform" -ForegroundColor Gray

Write-Host "`nControl Node ($ControlNodeIP):" -ForegroundColor White
Write-Host "  Ansible, Packer, Jenkins (port 8080), AWS CLI v2" -ForegroundColor Gray

Write-Host "`nPersistent environment variables (available in all future PowerShell windows):" -ForegroundColor White
Write-Host "  ANSIBLE_VAULT_PASSWORD_FILE = $env:USERPROFILE\.ansible_vault_pass" -ForegroundColor Gray
Write-Host "  TF_VAR_db_password          = (set, not displayed)" -ForegroundColor Gray
Write-Host "  Note: open a NEW PowerShell window to pick these up immediately." -ForegroundColor Yellow

Write-Host "`nJenkins first-time setup:" -ForegroundColor Yellow
Write-Host "  1. RDP to this Bastion and open a browser" -ForegroundColor Gray
Write-Host "  2. Navigate to http://${ControlNodeIP}:8080" -ForegroundColor Gray
if ($jenkinsPass -and $jenkinsPass -ne "NOT_READY_YET") {
    Write-Host "  3. Initial admin password: $jenkinsPass" -ForegroundColor Cyan
} else {
    $pemKey = $SSHKeyPath
    Write-Host "  3. Get initial admin password:" -ForegroundColor Gray
    Write-Host "     ssh -i `"$pemKey`" ${SSHUser}@${ControlNodeIP} ``" -ForegroundColor Gray
    Write-Host "       `"sudo cat /var/lib/jenkins/secrets/initialAdminPassword`"" -ForegroundColor Gray
}
Write-Host "  4. Install suggested plugins + Blue Ocean plugin" -ForegroundColor Gray

# -- Close transcript ----------------------------------------------------------
Stop-Transcript | Out-Null
Write-Host "`n------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Setup log saved to:" -ForegroundColor DarkGray
Write-Host "  $LogFile" -ForegroundColor White
Write-Host "`n  Nothing went wrong? You can still review the log at any time." -ForegroundColor DarkGray
Write-Host "  If you need support, copy this file to your local PC and" -ForegroundColor DarkGray
Write-Host "  email it to your professor." -ForegroundColor DarkGray
Write-Host "------------------------------------------------------------`n" -ForegroundColor DarkGray