#Requires -RunAsAdministrator
<#
.SYNOPSIS
    CIS-4641 Cloud DevOps — Environment Setup Script
    Run once on the Windows Bastion (t3.large) after first RDP login.

.DESCRIPTION
    LOCAL  (this Bastion):  WSL2, Google Antigravity, Python 3, Flask, Git, GitHub CLI, AWS CLI v2, Terraform
    REMOTE (Control Node):  Jenkins, Ansible, Packer

.NOTES
    Prerequisites:
      - Run as Administrator in PowerShell
      - Bastion has internet access via the Control Node NAT
      - Windows Server 2019 — WSL2 installation will trigger ONE automatic reboot
        and the script will resume automatically after login

    The Control Node IP and SSH key path are pre-configured below.
    No parameters are required for a standard course environment.

    Usage (standard — no parameters needed):
      .\Setup-DevOps-Environment.ps1

    Usage (override defaults if needed):
      .\Setup-DevOps-Environment.ps1 -ControlNodeIP "172.31.132.151" -SSHKeyPath "C:\path\to\key.ppk"
#>

param(
    # Control Node fixed private IP — set by professor setup script at launch
    [string]$ControlNodeIP = "172.31.132.151",

    # SSH private key — placed on the Bastion by professor setup script
    [string]$SSHKeyPath    = "C:\Users\Administrator\Desktop\awsvpcb-scripts\secfiles\privkey.ppk",

    [string]$SSHUser       = "ec2-user"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Step  { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "    [!!] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "    [FAIL] $msg" -ForegroundColor Red; exit 1 }

function Test-Command {
    param($Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ── Verify SSH key exists and convert .ppk to .pem if needed ─────────────────
if (-not (Test-Path $SSHKeyPath)) {
    Write-Fail "SSH key not found at '$SSHKeyPath'. Check that the professor setup script has run."
}

# OpenSSH on Windows requires PEM format — convert .ppk if needed
if ($SSHKeyPath -like "*.ppk") {
    $pemPath = $SSHKeyPath -replace "\.ppk$", ".pem"
    if (-not (Test-Path $pemPath)) {
        Write-Step "Converting .ppk key to .pem format for OpenSSH"
        # Install PuTTY tools via Chocolatey to get puttygen
        if (-not (Test-Command "puttygen")) {
            choco install putty -y --no-progress | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
        & puttygen $SSHKeyPath -O private-openssh -o $pemPath
        if (-not (Test-Path $pemPath)) {
            Write-Fail "Key conversion failed. Ensure PuTTY is installed and the .ppk file is valid."
        }
        Write-OK "Converted: $pemPath"
    } else {
        Write-OK "PEM key already exists: $pemPath"
    }
    $SSHKeyPath = $pemPath
}

# Fix key permissions — OpenSSH on Windows requires restricted ACL
Write-Step "Fixing SSH key permissions on $SSHKeyPath"
icacls $SSHKeyPath /inheritance:r /grant:r "${env:USERNAME}:(R)" | Out-Null
Write-OK "Key permissions set"

# ── Helper: run a command block on the Control Node via SSH ───────────────────
function Invoke-RemoteScript {
    param(
        [string]$Description,
        [string]$Script           # bash heredoc-safe single-line or multiline
    )
    Write-Step "[REMOTE] $Description"
    $sshArgs = @(
        "-i", $SSHKeyPath,
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=15",
        "${SSHUser}@${ControlNodeIP}",
        "bash -s"
    )
    $Script | ssh @sshArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Remote step failed: $Description"
    }
    Write-OK "Done: $Description"
}

# ═════════════════════════════════════════════════════════════════════════════
# PART 1 — LOCAL INSTALLS (Windows Bastion)
# ═════════════════════════════════════════════════════════════════════════════
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host   "║  PART 1 — Local Bastion Setup            ║" -ForegroundColor Magenta
Write-Host   "╚══════════════════════════════════════════╝" -ForegroundColor Magenta

# ── 0. WSL2 — must run before all other installs; requires a reboot ───────────
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
    Write-Host "    Enabling WSL2 (Windows Subsystem for Linux + Virtual Machine Platform)..."

    # Enable both required Windows features
    if (-not $wslEnabled) {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
        Write-OK "Windows Subsystem for Linux feature enabled"
    }
    if (-not $vmpEnabled) {
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
        Write-OK "Virtual Machine Platform feature enabled"
    }

    # Set WSL default version to 2
    # wsl.exe may not be on PATH yet before reboot — use the full path if needed
    $wslExe = "$env:SystemRoot\System32\wsl.exe"
    if (Test-Path $wslExe) {
        & $wslExe --set-default-version 2 2>$null
    }

    # Schedule the script to re-run automatically after reboot via a Run key
    $scriptPath   = $MyInvocation.MyCommand.Path
    $psArgs       = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $regPath      = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    Set-ItemProperty -Path $regPath -Name "DevOpsSetupResume" `
                     -Value "powershell.exe $psArgs"
    Write-OK "Script registered to resume automatically after reboot"

    Write-Warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Warn "  A REBOOT IS REQUIRED to complete WSL2 installation."
    Write-Warn "  The script will resume automatically after login."
    Write-Warn "  Rebooting in 15 seconds — press Ctrl+C to cancel."
    Write-Warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Start-Sleep -Seconds 15
    Restart-Computer -Force
    exit   # unreachable but keeps the script clean
}

# Remove the auto-resume registry key if it exists (cleanup after reboot)
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
if (Get-ItemProperty -Path $regPath -Name "DevOpsSetupResume" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $regPath -Name "DevOpsSetupResume"
    Write-OK "Auto-resume registry key removed"
}

# ── 1. Chocolatey (package manager) ──────────────────────────────────────────
Write-Step "Installing Chocolatey package manager"
if (Test-Command "choco") {
    Write-OK "Chocolatey already installed"
} else {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    # Reload PATH so choco is available immediately
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-OK "Chocolatey installed"
}

# ── 2. Git ────────────────────────────────────────────────────────────────────
Write-Step "Installing Git"
if (Test-Command "git") {
    Write-OK "Git already installed: $(git --version)"
} else {
    choco install git -y --no-progress
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-OK "Git installed: $(git --version)"
}

# ── 3. GitHub CLI ─────────────────────────────────────────────────────────────
# Used from Module 1 onward for forking repos, creating PRs, and interacting
# with GitHub from the terminal and Antigravity without needing a browser.
Write-Step "Installing GitHub CLI (gh)"
if (Test-Command "gh") {
    Write-OK "GitHub CLI already installed: $(gh --version | Select-Object -First 1)"
} else {
    choco install gh -y --no-progress
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-OK "GitHub CLI installed: $(gh --version | Select-Object -First 1)"
}
 
# ── 4. Python 3 ───────────────────────────────────────────────────────────────
Write-Step "Installing Python 3"
if (Test-Command "python") {
    Write-OK "Python already installed: $(python --version)"
} else {
    choco install python3 -y --no-progress --params "'/AddToPath=1'"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-OK "Python installed: $(python --version)"
}

# ── 5. Flask + SQLAlchemy (course dependencies) ───────────────────────────────
# Only flask and flask-sqlalchemy are needed on the Bastion — the app uses
# SQLite here (no MySQL driver required). PyMySQL and cryptography belong in
# the project's requirements.txt so they are installed inside the Docker image
# during Module 5 (docker build), giving the container MySQL connectivity.
Write-Step "Installing Flask and SQLAlchemy via pip"
python -m pip install --upgrade pip --quiet
python -m pip install flask flask-sqlalchemy --quiet
Write-OK "Flask and SQLAlchemy installed"
Write-Warn "PyMySQL + cryptography + gunicorn go in requirements.txt (needed in Docker image, not here)"

# ── 6. AWS CLI v2 ─────────────────────────────────────────────────────────────
Write-Step "Installing AWS CLI v2"
if (Test-Command "aws") {
    Write-OK "AWS CLI already installed: $(aws --version)"
} else {
    $awsInstaller = "$env:TEMP\AWSCLIV2.msi"
    Write-Host "    Downloading AWS CLI v2..."
    Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" `
                      -OutFile $awsInstaller -UseBasicParsing
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$awsInstaller`" /quiet /norestart"
    Remove-Item $awsInstaller -Force
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-OK "AWS CLI installed: $(aws --version)"
}

# ── 7. Terraform ─────────────────────────────────────────────────────────────
Write-Step "Installing Terraform"
if (Test-Command "terraform") {
    Write-OK "Terraform already installed: $(terraform version -json | ConvertFrom-Json | Select-Object -ExpandProperty terraform_version)"
} else {
    choco install terraform -y --no-progress
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-OK "Terraform installed: $(terraform version | Select-Object -First 1)"
}

# ── 8. Google Antigravity (VS Code-based IDE) ─────────────────────────────────
Write-Step "Installing Google Antigravity IDE"
$antigravityInstalled = Test-Path "$env:LOCALAPPDATA\Programs\Google Antigravity\Antigravity.exe"
if ($antigravityInstalled) {
    Write-OK "Google Antigravity already installed"
} else {
    Write-Host "    Opening Google Antigravity download page..."
    Write-Warn "Antigravity requires manual download from:"
    Write-Warn "https://codelabs.developers.google.com/getting-started-google-antigravity"
    Write-Warn "Download and run the installer, then press Enter to continue..."
    Read-Host "Press Enter once Antigravity is installed"
    Write-OK "Google Antigravity install acknowledged"
}

# ── Verify local installs ─────────────────────────────────────────────────────
Write-Step "Verifying local installations"
$checks = @(
    @{ Name = "git";       Cmd = { git --version } },
    @{ Name = "gh";        Cmd = { gh --version | Select-Object -First 1 } },
    @{ Name = "python";    Cmd = { python --version } },
    @{ Name = "pip";       Cmd = { python -m pip --version } },
    @{ Name = "aws";       Cmd = { aws --version } },
    @{ Name = "terraform"; Cmd = { terraform version | Select-Object -First 1 } }
)
foreach ($c in $checks) {
    try {
        $ver = & $c.Cmd 2>&1
        Write-OK "$($c.Name): $ver"
    } catch {
        Write-Warn "$($c.Name): not found in PATH — open a new shell and re-check"
    }
}

# ═════════════════════════════════════════════════════════════════════════════
# PART 2 — REMOTE INSTALLS (Linux Control Node via SSH)
# ═════════════════════════════════════════════════════════════════════════════
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host   "║  PART 2 — Control Node Setup (SSH)       ║" -ForegroundColor Magenta
Write-Host   "╚══════════════════════════════════════════╝" -ForegroundColor Magenta

# ── Test SSH connectivity first ───────────────────────────────────────────────
Write-Step "Testing SSH connectivity to Control Node ($ControlNodeIP)"
$sshTest = ssh -i $SSHKeyPath `
               -o StrictHostKeyChecking=no `
               -o ConnectTimeout=10 `
               "${SSHUser}@${ControlNodeIP}" `
               "echo connected" 2>&1
if ($sshTest -notmatch "connected") {
    Write-Fail "Cannot SSH to $ControlNodeIP. Check the IP, key, and security group (port 22 from Bastion)."
}
Write-OK "SSH connection successful"

# ── 8. System update ─────────────────────────────────────────────────────────
Invoke-RemoteScript -Description "System update (dnf)" -Script @'
sudo dnf update -y -q
'@

# ── 9. Python 3 + pip on Control Node (needed by Ansible) ────────────────────
Invoke-RemoteScript -Description "Python 3 and pip" -Script @'
sudo dnf install -y python3 python3-pip -q
python3 --version
'@

# ── 10. Ansible ───────────────────────────────────────────────────────────────
Invoke-RemoteScript -Description "Ansible" -Script @'
sudo dnf install -y ansible -q 2>/dev/null || \
    sudo pip3 install ansible --quiet
ansible --version | head -1
'@

# ── 11. Packer ────────────────────────────────────────────────────────────────
Invoke-RemoteScript -Description "HashiCorp Packer" -Script @'
# Add HashiCorp repo and install Packer
sudo dnf install -y dnf-plugins-core -q
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo -q
sudo dnf install -y packer -q
packer version
'@

# ── 12. Java 17 (Jenkins dependency) ─────────────────────────────────────────
Invoke-RemoteScript -Description "Java 17 (Jenkins dependency)" -Script @'
sudo dnf install -y java-17-amazon-corretto-headless -q
java -version 2>&1 | head -1
'@

# ── 13. Jenkins ───────────────────────────────────────────────────────────────
Invoke-RemoteScript -Description "Jenkins LTS" -Script @'
# Add Jenkins repo
sudo wget -q -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key 2>/dev/null || \
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo dnf install -y jenkins -q

# Enable and start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Wait for Jenkins to be ready (up to 60 seconds)
echo "Waiting for Jenkins to start..."
for i in $(seq 1 12); do
    if sudo systemctl is-active --quiet jenkins; then
        echo "Jenkins is running"
        break
    fi
    sleep 5
done

sudo systemctl status jenkins --no-pager | grep -E "Active:|Main PID:"
'@

# ── 14. Open port 8080 for Bastion in firewalld (if running) ─────────────────
Invoke-RemoteScript -Description "Firewall: allow port 8080 (Jenkins)" -Script @'
if sudo systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
    echo "firewalld: port 8080 opened"
else
    echo "firewalld not active — security group controls access"
fi
'@

# ── 15. AWS CLI on Control Node ───────────────────────────────────────────────
Invoke-RemoteScript -Description "AWS CLI v2 on Control Node" -Script @'
if command -v aws &>/dev/null; then
    echo "AWS CLI already installed: $(aws --version)"
else
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
    echo "AWS CLI installed: $(aws --version)"
fi
'@

# ── 16. Retrieve Jenkins initial admin password ───────────────────────────────
Write-Step "[REMOTE] Retrieving Jenkins initial admin password"
$jenkinsPass = ssh -i $SSHKeyPath `
                   -o StrictHostKeyChecking=no `
                   "${SSHUser}@${ControlNodeIP}" `
                   "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo NOT_READY_YET"

# ── 17. Verify all remote installs ────────────────────────────────────────────
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

# ═════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════════════════════
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host   "║  SETUP COMPLETE                                              ║" -ForegroundColor Green
Write-Host   "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`nBastion (local):" -ForegroundColor White
Write-Host "  WSL2, Git, GitHub CLI, Python 3, Flask, SQLAlchemy, AWS CLI v2, Terraform" -ForegroundColor Gray
Write-Host "  Google Antigravity IDE" -ForegroundColor Gray

Write-Host "`nControl Node ($ControlNodeIP):" -ForegroundColor White
Write-Host "  Ansible, Packer, Jenkins (port 8080), AWS CLI v2" -ForegroundColor Gray

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

Write-Host "`nNext step: Authenticate GitHub CLI, then fork and clone the NM-FSM-App repo." -ForegroundColor Cyan
Write-Host "  gh auth login                                              # authenticate once" -ForegroundColor Gray
Write-Host "  gh repo fork https://github.com/ts0491/NM-FSM-App --clone # fork + clone in one step" -ForegroundColor Gray
Write-Host "  cd NM-FSM-App`n" -ForegroundColor Gray