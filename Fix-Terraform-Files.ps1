#Requires -RunAsAdministrator
#
.SYNOPSIS
    CIS-4641 Cloud DevOps  -  Terraform File Cleanup Script
    Run this after copying HCL code from the PowerPoint slides into your .tf files.

.DESCRIPTION
    PowerPoint silently substitutes typographic characters that look correct on
    screen but cause Terraform parse errors when pasted into text files

      Smart quotes       -        (causes Invalid character)
      Smart apostrophes  '  '  -  '  (causes Invalid character)
      Em dash        —        -  -   (causes Invalid character encoding)
      En dash        –        -  -   (causes Invalid character encoding)
      Non-breaking space     -    (causes Missing newline  unexpected token)

    This script fixes all of the above in every .tf file in the current
    directory. Always run  terraform fmt  afterwards to normalise indentation.

.NOTES
    Usage
      cd CcodeNM-FSM-Appdevops-courseterraform
      .Fix-TerraformFiles.ps1

    Then verify with
      terraform validate
#

param(
    [string]$TerraformDir = (Get-Location).Path
)

$ErrorActionPreference = Stop

# -- Colour helpers ------------------------------------------------------------
function Write-Step { param($msg) Write-Host `n== $msg -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host     [OK] $msg -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host     [!!] $msg -ForegroundColor Yellow }

Write-Host 
Write-Host +============================================================+ -ForegroundColor Magenta
Write-Host   CIS-4641  -  Terraform File Character Cleanup               -ForegroundColor Magenta
Write-Host +============================================================+ -ForegroundColor Magenta
Write-Host 

# Character substitution map  -  PowerPoint - plain ASCII
$substitutions = [ordered]@{
    u201C = ''   # left double quotation mark  
    u201D = ''   # right double quotation mark 
    u2018 = '   # left single quotation mark  '
    u2019 = '   # right single quotation mark '
    u2014 = -   # em dash                     —
    u2013 = -   # en dash                     –
    u00A0 =     # non-breaking space
    u2026 = ...  # ellipsis                   …
}

Write-Step Scanning for .tf files in $TerraformDir

$tfFiles = Get-ChildItem -Path $TerraformDir -Filter .tf -File
if ($tfFiles.Count -eq 0) {
    Write-Warn No .tf files found in $TerraformDir
    Write-Warn Make sure you are in the terraform directory and have created your .tf files.
    exit 0
}

Write-OK Found $($tfFiles.Count) .tf file(s) $($tfFiles.Name -join ', ')

$totalFixes = 0

Write-Step Cleaning typographic characters

foreach ($file in $tfFiles) {
    # Read as UTF-8  -  required to correctly decode multi-byte characters
    $content = [System.IO.File]ReadAllText($file.FullName, [System.Text.Encoding]UTF8)
    $original = $content
    $fileFixes = 0

    foreach ($pair in $substitutions.GetEnumerator()) {
        $char = [System.Text.RegularExpressions.Regex]Unescape($pair.Key)
        if ($content.Contains($char)) {
            $count = ($content.Split($char).Count - 1)
            $content = $content.Replace($char, $pair.Value)
            $fileFixes += $count
            Write-Host     $($file.Name) replaced $count x U+$($pair.Key.Substring(2)) - '$($pair.Value)' -ForegroundColor DarkGray
        }
    }

    if ($fileFixes -gt 0) {
        # Write back as UTF-8 without BOM  -  Terraform requires UTF-8, no BOM
        [System.IO.File]WriteAllText(
            $file.FullName,
            $content,
            [System.Text.UTF8Encoding]new($false)  # $false = no BOM
        )
        Write-OK $($file.Name) $fileFixes substitution(s) made
        $totalFixes += $fileFixes
    } else {
        Write-OK $($file.Name) no typographic characters found
    }
}

# =============================================================================
# Run terraform fmt to normalise indentation and line endings
# =============================================================================
Write-Step Running terraform fmt to normalise formatting

try {
    $fmtOutput = terraform fmt 2&1
    if ($LASTEXITCODE -eq 0) {
        if ($fmtOutput) {
            Write-OK terraform fmt reformatted $($fmtOutput -join ', ')
        } else {
            Write-OK terraform fmt all files already correctly formatted
        }
    } else {
        Write-Warn terraform fmt returned errors  -  run  terraform validate  to see details
    }
} catch {
    Write-Warn terraform not found in PATH  -  skipping fmt step
}

# =============================================================================
# Summary
# =============================================================================
Write-Host 
Write-Host +============================================================+ -ForegroundColor Green
Write-Host   CLEANUP COMPLETE                                            -ForegroundColor Green
Write-Host +============================================================+ -ForegroundColor Green
Write-Host 
Write-Host   Total substitutions made $totalFixes -ForegroundColor White
Write-Host 
Write-Host   Next steps -ForegroundColor Yellow
Write-Host     1. terraform validate   - check for remaining syntax errors -ForegroundColor DarkGray
Write-Host     2. terraform plan       - review what will be created -ForegroundColor DarkGray
Write-Host     3. terraform apply      - provision the infrastructure -ForegroundColor DarkGray
Write-Host 