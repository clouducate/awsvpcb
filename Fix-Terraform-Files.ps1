#Requires -RunAsAdministrator
<#
.SYNOPSIS
    CIS-4641 Cloud DevOps - Terraform File Cleanup Script
    Run after copying HCL from PowerPoint slides into .tf files.
    Usage: cd C:\code\NM-FSM-App\devops-course\terraform
           .\Fix-Terraform-Files.ps1
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "    [!!] $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "+============================================================+" -ForegroundColor Magenta
Write-Host "|  CIS-4641 - Terraform File Character Cleanup               |" -ForegroundColor Magenta
Write-Host "+============================================================+" -ForegroundColor Magenta

Write-Step "Scanning for .tf files in: $(Get-Location)"

$tfFiles = Get-ChildItem -Filter "*.tf" -File
if ($tfFiles.Count -eq 0) {
    Write-Warn "No .tf files found. Make sure you are in the terraform directory."
    exit 0
}
Write-OK "Found $($tfFiles.Count) file(s): $($tfFiles.Name -join ', ')"

# Build substitution table using char codes to avoid any encoding issues
# in this script file itself
$subs = @(
    @{ Code = 0x201C; Name = "left double quote";      Plain = '"' },
    @{ Code = 0x201D; Name = "right double quote";     Plain = '"' },
    @{ Code = 0x2018; Name = "left single quote";      Plain = "'" },
    @{ Code = 0x2019; Name = "right single quote";     Plain = "'" },
    @{ Code = 0x2014; Name = "em dash";                Plain = "-" },
    @{ Code = 0x2013; Name = "en dash";                Plain = "-" },
    @{ Code = 0x00A0; Name = "non-breaking space";     Plain = " " },
    @{ Code = 0x2026; Name = "ellipsis";               Plain = "..." }
)

$totalFixes = 0

Write-Step "Cleaning typographic characters"

foreach ($file in $tfFiles) {
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $fileFixes = 0

    foreach ($sub in $subs) {
        $char = [char]$sub.Code
        if ($content.Contains($char)) {
            $count = ($content.ToCharArray() | Where-Object { $_ -eq $char }).Count
            $content = $content.Replace([string]$char, $sub.Plain)
            $fileFixes += $count
            Write-Host "    $($file.Name): $count x $($sub.Name) -> '$($sub.Plain)'" -ForegroundColor DarkGray
        }
    }

    if ($fileFixes -gt 0) {
        # Write back UTF-8 without BOM using Out-File
        $content | Out-File -FilePath $file.FullName -Encoding utf8 -NoNewline
        Write-OK "$($file.Name): $fileFixes fix(es) applied"
        $totalFixes += $fileFixes
    } else {
        Write-OK "$($file.Name): clean"
    }
}

Write-Step "Running terraform fmt"
# Refresh PATH in case terraform was installed in this session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")
try {
    terraform fmt 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -eq 0) {
        Write-OK "terraform fmt complete"
    } else {
        Write-Warn "terraform fmt reported issues - run terraform validate for details"
    }
} catch {
    Write-Warn "terraform not found in PATH - skipping fmt"
}

Write-Host ""
Write-Host "+============================================================+" -ForegroundColor Green
Write-Host "|  DONE - $totalFixes total substitution(s) made              |" -ForegroundColor Green
Write-Host "+============================================================+" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    terraform validate   <- check for syntax errors" -ForegroundColor DarkGray
Write-Host "    terraform plan       <- review what will be created" -ForegroundColor DarkGray
Write-Host "    terraform apply      <- provision the infrastructure" -ForegroundColor DarkGray
Write-Host ""