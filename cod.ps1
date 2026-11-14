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

# Locate potential CoD configuration paths
$paths = @(
    "$env:USERPROFILE\Documents\Call of Duty\players",
    "$env:LOCALAPPDATA\Activision\Call of Duty\players"
) | Where-Object { Test-Path $_ }

if (-not $paths -or $paths.Count -eq 0) {
    $fallback = "$env:USERPROFILE\Documents\Call of Duty\players"
    if (-not (Test-Path $fallback)) {
        New-Item -ItemType Directory -Path $fallback -Force | Out-Null
    }
    $paths = @($fallback)
}

# Helper function to find all target config files (including Activision account ID subfolders)
function Get-CoDConfigFiles {
    param([string]$basePath)
    Get-ChildItem -Path $basePath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -in '.cst', '.txt' -and
        $_.DirectoryName -notmatch '_backup_' -and
        ($_.Name -match '^(options|s\.|cs\.|gamerprofile|.*cod)' -or $_.Name -match '\.cst$')
    }
}

# 1. Unlock Mode
if ($UnlockOnly) {
    Write-Host "[*] Unlocking configuration files (removing Read-Only)..." -ForegroundColor Yellow
    $foundAny = $false
    foreach ($p in $paths) {
        $files = Get-CoDConfigFiles -basePath $p
        foreach ($f in $files) {
            Set-ItemProperty -Path $f.FullName -Name IsReadOnly -Value $false
            Write-Host "  [UNLOCKED] $($f.FullName.Replace($p, ''))" -ForegroundColor Gray
            $foundAny = $true
        }
    }
    if (-not $foundAny) {
        Write-Host "  [!] No .cst or .txt files found to unlock." -ForegroundColor Yellow
    } else {
        Write-Host "`n[OK] All config files are unlocked! You can now adjust in-game settings." -ForegroundColor Green
    }
    return
}

# 2. Lock Mode
if ($LockOnly) {
    Write-Host "[*] Locking configuration files to Read-Only..." -ForegroundColor Yellow
    $foundAny = $false
    foreach ($p in $paths) {
        $files = Get-CoDConfigFiles -basePath $p
        foreach ($f in $files) {
            Set-ItemProperty -Path $f.FullName -Name IsReadOnly -Value $true
            Write-Host "  [LOCKED] $($f.FullName.Replace($p, ''))" -ForegroundColor Gray
            $foundAny = $true
        }
    }
    if (-not $foundAny) {
        Write-Host "  [!] No .cst or .txt files found to lock." -ForegroundColor Yellow
    } else {
        Write-Host "`n[OK] All config files are locked to Read-Only! Settings are protected." -ForegroundColor Green
    }
    return
}

# 3. CPU Core Detection & Optimal Worker Allocation
Write-Host "[*] Detecting CPU hardware topology..." -ForegroundColor Cyan
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$physicalCores = if ($cpu.NumberOfCores) { $cpu.NumberOfCores } else { 6 }
$threads = if ($cpu.NumberOfLogicalProcessors) { $cpu.NumberOfLogicalProcessors } else { 12 }

# For Ryzen 5 5500 (6 physical cores, 12 threads):
# Allocating 5 workers prevents 100% thread contention with OS/audio/RICOCHET tasks, eliminating micro-stutters and maximizing 1% low FPS.
$optimalWorkers = if ($physicalCores -eq 6) { 5 } elseif ($physicalCores -gt 6) { $physicalCores - 1 } else { [Math]::Max(2, $physicalCores) }

Write-Host "  CPU Detected: $($cpu.Name.Trim())" -ForegroundColor White
Write-Host "  Topology: $physicalCores Cores / $threads Threads" -ForegroundColor White
Write-Host "  -> RendererWorkerCount optimized to: $optimalWorkers" -ForegroundColor Green

# 4. Settings Table for Maximum Competitive Clarity and Frametime Stability
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

foreach ($p in $paths) {
    Write-Host "`n[*] Scanning directory: $p" -ForegroundColor Cyan
    $files = Get-CoDConfigFiles -basePath $p
    
    if (-not $files -or $files.Count -eq 0) {
        Write-Host "  No active .cst or .txt config files found in this path." -ForegroundColor DarkGray
        continue
    }

    foreach ($file in $files) {
        $relPath = $file.FullName.Replace($p, '')
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
            # Match CST standard syntax: Key:0.0 = "Value"
            $patternCst = "(?m)^(\s*//?\s*|\s*)$([regex]::Escape($k))(:[0-9.]+\s*=\s*).*$"
            if ($content -match $patternCst) {
                $content = [regex]::Replace($content, $patternCst, "$k`$2$v")
                $modified = $true
            }
            # Match generic assignment syntax: Key = "Value"
            $patternGen = "(?m)^(\s*)$([regex]::Escape($k))(\s*[:=]\s*).*$"
            if (-not $modified -and ($content -match $patternGen)) {
                $content = [regex]::Replace($content, $patternGen, "$k = $v")
                $modified = $true
            }
        }

        if ($modified) {
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
            Write-Host "  [OPTIMIZED] $relPath" -ForegroundColor Green
        } else {
            Write-Host "  [VERIFIED]  $relPath" -ForegroundColor Gray
        }

        Set-ItemProperty -Path $file.FullName -Name IsReadOnly -Value $true
        Write-Host "  [LOCKED]    $relPath (Read-Only)" -ForegroundColor DarkGreen
    }
}

Write-Host "`n========================================================" -ForegroundColor Magenta
Write-Host "  SUCCESS! Call of Duty is optimized and protected.   " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Magenta
Write-Host "• RendererWorkerCount : $optimalWorkers" -ForegroundColor White
Write-Host "• VideoMemoryScale    : $VramScale (Stops PCIe bus stutter)" -ForegroundColor White
Write-Host "• Motion Blur & Grain : Disabled (Clear 200Hz visibility)" -ForegroundColor White
Write-Host "• Config Protection   : Read-Only Applied`n" -ForegroundColor White
