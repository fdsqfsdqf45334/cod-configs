<#
========================================================================
   Call of Duty / Warzone Competitive Performance & Config Optimizer   
   Tuned for: AMD Ryzen 5 5500 | Radeon RX 6600 (8GB) | 200Hz Display  
========================================================================
#>
[CmdletBinding()]
param(
    [switch]$UnlockOnly,
    [switch]$LockOnly,
    [double]$VramScale = 0.70
)

$ErrorActionPreference = "SilentlyContinue"

Write-Host "`n========================================================" -ForegroundColor Magenta
Write-Host "   Call of Duty / Warzone Competitive Config Optimizer   " -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Magenta

# 1. Multi-Root Detection (Handles OneDrive Redirection, Custom Docs & LocalAppData)
$possibleRoots = @(
    [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments),
    "$env:USERPROFILE\Documents",
    "$env:OneDrive\Documents",
    "$env:OneDriveConsumer\Documents",
    "$env:LOCALAPPDATA\Activision"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$paths = @()
foreach ($root in $possibleRoots) {
    Get-ChildItem -Path $root -Directory -Filter "*Call of Duty*" -ErrorAction SilentlyContinue | ForEach-Object {
        $playerDir = Join-Path $_.FullName "players"
        if (Test-Path $playerDir) { $paths += $playerDir }
    }
    # Also check direct players paths
    $directPlayers = Join-Path $root "Call of Duty\players"
    if (Test-Path $directPlayers) { $paths += $directPlayers }
}
$paths = $paths | Select-Object -Unique

# Helper function to find all target config files (including account subdirectories)
function Get-CoDConfigFiles {
    param([string]$basePath)
    Get-ChildItem -Path $basePath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.DirectoryName -notmatch '_backup_' -and
        ($_.Extension -in '.cst', '.txt', '.ini') -and
        ($_.Name -match '^(options|s\.|cs\.|gamerprofile|adv_options|config)' -or $_.Extension -eq '.cst')
    }
}

# 2. Unlock Mode
if ($UnlockOnly) {
    Write-Host "[*] Unlocking configuration files (removing Read-Only)..." -ForegroundColor Yellow
    $count = 0
    foreach ($p in $paths) {
        $files = Get-CoDConfigFiles -basePath $p
        foreach ($f in $files) {
            Set-ItemProperty -Path $f.FullName -Name IsReadOnly -Value $false
            Write-Host "  [UNLOCKED] $($f.FullName)" -ForegroundColor Gray
            $count++
        }
    }
    if ($count -eq 0) {
        Write-Host "  [!] No matching config files found to unlock." -ForegroundColor Yellow
    } else {
        Write-Host "`n[OK] $count config file(s) unlocked! You can now adjust in-game settings." -ForegroundColor Green
    }
    return
}

# 3. Lock Mode
if ($LockOnly) {
    Write-Host "[*] Locking configuration files to Read-Only..." -ForegroundColor Yellow
    $count = 0
    foreach ($p in $paths) {
        $files = Get-CoDConfigFiles -basePath $p
        foreach ($f in $files) {
            Set-ItemProperty -Path $f.FullName -Name IsReadOnly -Value $true
            Write-Host "  [LOCKED] $($f.FullName)" -ForegroundColor Gray
            $count++
        }
    }
    if ($count -eq 0) {
        Write-Host "  [!] No matching config files found to lock." -ForegroundColor Yellow
    } else {
        Write-Host "`n[OK] $count config file(s) locked to Read-Only! Settings are protected." -ForegroundColor Green
    }
    return
}

# 4. CPU Core Detection & Optimal Worker Allocation
Write-Host "[*] Detecting CPU hardware topology..." -ForegroundColor Cyan
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$physicalCores = if ($cpu.NumberOfCores) { $cpu.NumberOfCores } else { 6 }
$threads = if ($cpu.NumberOfLogicalProcessors) { $cpu.NumberOfLogicalProcessors } else { 12 }

# Optimal Worker Allocation for Ryzen 5 5500 (6 cores, 12 threads):
# 5 workers leaves 1 physical core for OS/audio/RICOCHET tasks, eliminating micro-stutters
$optimalWorkers = if ($physicalCores -eq 6) { 5 } elseif ($physicalCores -gt 6) { $physicalCores - 1 } else { [Math]::Max(2, $physicalCores) }

Write-Host "  CPU Detected: $($cpu.Name.Trim())" -ForegroundColor White
Write-Host "  Topology: $physicalCores Cores / $threads Threads" -ForegroundColor White
Write-Host "  -> RendererWorkerCount optimized to: $optimalWorkers" -ForegroundColor Green

# 5. Settings Table for Maximum Competitive Clarity and Frametime Stability
$settings = @{
    'RendererWorkerCount'    = "`"$optimalWorkers`""
    'VideoMemoryScale'       = "`"$VramScale`""
    'WorldMotionBlur'        = '"false"'
    'WeaponMotionBlur'       = '"false"'
    'DepthOfField'           = '"false"'
    'FilmGrain'              = '"0.000000"'
    'CorpsesMaxCount'        = '"0"'
    'Blood'                  = '"false"'
    'SubsurfaceScattering'   = '"false"'
    'Tessellation'           = '"Off"'
    'AmbientOcclusion'       = '"Off"'
    'ScreenSpaceReflections' = '"Off"'
    'WaterCaustics'          = '"false"'
    'ClutterMaxDistance'     = '"Lowest"'
    'SunShadowCascade'       = '"Low"'
    'SpotShadowQuality'      = '"Low"'
    'VolumetricQuality'      = '"Low"'
    'ParticleLightingQuality'= '"Low"'
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$totalOptimized = 0

foreach ($p in $paths) {
    Write-Host "`n[*] Scanning directory: $p" -ForegroundColor Cyan
    $files = Get-CoDConfigFiles -basePath $p
    
    if (-not $files -or $files.Count -eq 0) {
        Write-Host "  No active config files found in this path." -ForegroundColor DarkGray
        continue
    }

    foreach ($file in $files) {
        $backupDir = Join-Path $file.DirectoryName "_backup_$timestamp"
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        Copy-Item -Path $file.FullName -Destination $backupDir -Force
        
        Set-ItemProperty -Path $file.FullName -Name IsReadOnly -Value $false

        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $modified = $false

        foreach ($k in $settings.Keys) {
            $v = $settings[$k]
            # Match CST syntax: Key:0.0 = "Value"
            $patternCst = "(?m)^(\s*//?\s*|\s*)$([regex]::Escape($k))(:[0-9.]+\s*=\s*).*$"
            if ($content -match $patternCst) {
                $content = [regex]::Replace($content, $patternCst, "$k`$2$v")
                $modified = $true
            }
            # Match INI / TXT syntax: Key = Value
            $patternGen = "(?m)^(\s*)$([regex]::Escape($k))(\s*[:=]\s*).*$"
            if (-not $modified -and ($content -match $patternGen)) {
                $content = [regex]::Replace($content, $patternGen, "$k = $v")
                $modified = $true
            }
        }

        if ($modified) {
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
            Write-Host "  [OPTIMIZED] $($file.FullName)" -ForegroundColor Green
            $totalOptimized++
        } else {
            Write-Host "  [VERIFIED]  $($file.FullName)" -ForegroundColor Gray
        }

        Set-ItemProperty -Path $file.FullName -Name IsReadOnly -Value $true
        Write-Host "  [LOCKED]    $($file.Name) (Read-Only)" -ForegroundColor DarkGreen
    }
}

if ($totalOptimized -gt 0) {
    Write-Host "`n========================================================" -ForegroundColor Magenta
    Write-Host "  SUCCESS! Call of Duty is optimized and protected.   " -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host "• Files Optimized     : $totalOptimized" -ForegroundColor White
    Write-Host "• RendererWorkerCount : $optimalWorkers" -ForegroundColor White
    Write-Host "• VideoMemoryScale    : $VramScale (Stops PCIe bus stutter)" -ForegroundColor White
    Write-Host "• Motion Blur & Grain : Disabled (Clear 200Hz visibility)" -ForegroundColor White
    Write-Host "• Config Protection   : Read-Only Applied`n" -ForegroundColor White
} else {
    Write-Host "`n[!] No files were modified. Run the folder inspection command to check your directory structure.`n" -ForegroundColor Yellow
}
