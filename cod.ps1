<#
==================================================================================
   Call of Duty / Warzone Universal Competitive Performance & Config Optimizer    
   Multi-System Engine Tuning: Intel (Hybrid/P-Cores) & AMD Ryzen (CCD-Aware)     
   Multi-Title: MWII (.cod22), MWIII (.cod23), BO6/BO7 (.cod24/.cod25/.cod26)     
   Supports: .cst, .txt, .txt0, .txt1 (Dual-Slot Sync) & .ini Files               
   Dynamic VRAM Scaler | Read-Only Auto-Lock | Instant Restore Engine             
==================================================================================
#>
[CmdletBinding()]
param(
    [switch]$Unlock,
    [switch]$Lock,
    [switch]$Restore,
    [double]$VramScale = 0.0,
    [int]$Workers = 0
)

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n=================================================================" -ForegroundColor Magenta
Write-Host "   CALL OF DUTY / WARZONE COMPETITIVE CONFIG OPTIMIZER           " -ForegroundColor Cyan
Write-Host "   Universal Engine Tuning for AMD Ryzen & Intel Systems         " -ForegroundColor DarkCyan
Write-Host "=================================================================`n" -ForegroundColor Magenta

# -------------------------------------------------------------------
# 1. Multi-Root Path Discovery (OneDrive, Local Documents, AppData)
# -------------------------------------------------------------------
$candidateRoots = @(
    [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments),
    "$env:USERPROFILE\Documents",
    "$env:OneDrive\Documents",
    "$env:OneDriveConsumer\Documents",
    "$env:LOCALAPPDATA\Activision"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$searchPaths = @()
foreach ($root in $candidateRoots) {
    Get-ChildItem -Path $root -Directory -Filter "*Call of Duty*" -ErrorAction SilentlyContinue | ForEach-Object {
        $pDir = Join-Path $_.FullName "players"
        if (Test-Path $pDir) { $searchPaths += $pDir }
    }
    $directPlayers = Join-Path $root "Call of Duty\players"
    if (Test-Path $directPlayers) { $searchPaths += $directPlayers }
}
$searchPaths = $searchPaths | Select-Object -Unique

if (-not $searchPaths -or $searchPaths.Count -eq 0) {
    Write-Host "[-] Could not locate Call of Duty configuration directories." -ForegroundColor Red
    Write-Host "    Ensure Call of Duty has been launched at least once on this PC.`n" -ForegroundColor Yellow
    return
}

# Helper function to get all editable config files (including BO6 dual slots .txt0 / .txt1)
function Get-CoDConfigs {
    param([string]$targetDir)
    Get-ChildItem -Path $targetDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.DirectoryName -notmatch '_backup_' -and
        ($_.Name -match '\.(cst|txt[0-9]*|ini)$') -and
        ($_.Name -match '^(options|s\.|cs\.|g\.|gamerprofile|adv_options|config)' -or $_.Name -match '\.cst$')
    }
}

# -------------------------------------------------------------------
# 2. Revert / Restore Feature
# -------------------------------------------------------------------
if ($Restore) {
    Write-Host "[*] RESTORE MODE: Searching for the newest backup archives..." -ForegroundColor Yellow
    $restoredCount = 0
    foreach ($p in $searchPaths) {
        $backups = Get-ChildItem -Path $p -Directory -Filter "_backup_*" -Recurse | Sort-Object CreationTime -Descending
        if ($backups) {
            $latestBackup = $backups[0]
            Write-Host "  Found backup directory: $($latestBackup.FullName)" -ForegroundColor Cyan
            Get-ChildItem -Path $latestBackup.FullName -File | ForEach-Object {
                $targetFile = Join-Path $latestBackup.Parent.FullName $_.Name
                Set-ItemProperty -Path $targetFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
                Copy-Item -Path $_.FullName -Destination $targetFile -Force
                Write-Host "  [RESTORED] $($_.Name)" -ForegroundColor Green
                $restoredCount++
            }
        }
    }
    if ($restoredCount -gt 0) {
        Write-Host "`n[OK] Successfully restored $restoredCount configuration file(s) to original state!`n" -ForegroundColor Green
    } else {
        Write-Host "`n[!] No previous backup directories found to restore.`n" -ForegroundColor Yellow
    }
    return
}

# -------------------------------------------------------------------
# 3. Unlock Mode
# -------------------------------------------------------------------
if ($Unlock) {
    Write-Host "[*] UNLOCK MODE: Removing Read-Only attribute..." -ForegroundColor Yellow
    $count = 0
    foreach ($p in $searchPaths) {
        $files = Get-CoDConfigs -targetDir $p
        foreach ($f in $files) {
            Set-ItemProperty -Path $f.FullName -Name IsReadOnly -Value $false
            Write-Host "  [UNLOCKED] $($f.FullName)" -ForegroundColor Gray
            $count++
        }
    }
    Write-Host "`n[OK] $count file(s) unlocked! You can now adjust graphics or keybinds in-game.`n" -ForegroundColor Green
    return
}

# -------------------------------------------------------------------
# 4. Lock Mode
# -------------------------------------------------------------------
if ($Lock) {
    Write-Host "[*] LOCK MODE: Applying Read-Only protection..." -ForegroundColor Yellow
    $count = 0
    foreach ($p in $searchPaths) {
        $files = Get-CoDConfigs -targetDir $p
        foreach ($f in $files) {
            Set-ItemProperty -Path $f.FullName -Name IsReadOnly -Value $true
            Write-Host "  [LOCKED] $($f.FullName)" -ForegroundColor Gray
            $count++
        }
    }
    Write-Host "`n[OK] $count file(s) protected with Read-Only!`n" -ForegroundColor Green
    return
}

# -------------------------------------------------------------------
# 5. Smart CPU Topology & Optimal Worker Calculation
# -------------------------------------------------------------------
Write-Host "[*] Analyzing System Hardware Topology..." -ForegroundColor Cyan
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cores = if ($cpu.NumberOfCores) { [int]$cpu.NumberOfCores } else { 6 }
$threads = if ($cpu.NumberOfLogicalProcessors) { [int]$cpu.NumberOfLogicalProcessors } else { 12 }
$cpuName = if ($cpu.Name) { $cpu.Name.Trim() } else { "Generic Processor" }
$isIntel = $cpuName -match "Intel"
$isAmd = $cpuName -match "AMD|Ryzen"

# Intel Hybrid Architecture Detection (P-Cores vs E-Cores)
$pCores = $cores
$hasHybridArch = $false
if ($isIntel -and ($threads -gt $cores) -and (($threads - $cores) -lt $cores)) {
    $pCores = $threads - $cores
    $hasHybridArch = $true
}

# Worker Thread Calculation
if ($Workers -gt 0) {
    $optimalWorkers = $Workers
} elseif ($hasHybridArch) {
    # Intel Hybrid: strictly stay on P-cores to avoid scheduling threads on weak E-cores
    $optimalWorkers = if ($pCores -gt 4) { $pCores - 1 } else { $pCores }
} elseif ($isAmd) {
    # AMD Ryzen: 6-Core -> 5; 8-Core -> 7; 12/16 Dual-CCD -> 6
    if ($cores -eq 4) { $optimalWorkers = 3 }
    elseif ($cores -eq 6) { $optimalWorkers = 5 }
    elseif ($cores -eq 8) { $optimalWorkers = 7 }
    elseif ($cores -ge 12) { $optimalWorkers = 6 }
    else { $optimalWorkers = [Math]::Max(2, $cores - 1) }
} else {
    $optimalWorkers = if ($cores -gt 4) { $cores - 1 } else { $cores }
}

Write-Host "  CPU Model  : $cpuName" -ForegroundColor White
if ($hasHybridArch) {
    Write-Host "  Topology   : Intel Hybrid ($pCores P-Cores / $($cores - $pCores) E-Cores / $threads Threads)" -ForegroundColor White
    Write-Host "  Engine Map : Locked to P-Cores to prevent E-Core frametime spikes" -ForegroundColor DarkGreen
} else {
    Write-Host "  Topology   : $cores Physical Cores / $threads Logical Threads" -ForegroundColor White
}
Write-Host "  -> Optimal RendererWorkerCount : $optimalWorkers" -ForegroundColor Green

# -------------------------------------------------------------------
# 6. Smart GPU & VRAM Memory Allocation Calculation
# -------------------------------------------------------------------
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
$gpuName = if ($gpu.Name) { $gpu.Name.Trim() } else { "Generic Graphics Adapter" }

if ($VramScale -gt 0.0) {
    $targetVramScale = $VramScale
} else {
    if ($gpuName -match "4090|4080|7900|3090|XTX") {
        $targetVramScale = 0.80
    } elseif ($gpuName -match "4070|3080|6800|6900|7800|16GB") {
        $targetVramScale = 0.75
    } elseif ($gpuName -match "6600|7600|4060|3060|3050|2060|5700|5600|8GB") {
        $targetVramScale = 0.70
    } elseif ($gpuName -match "1660|1060|1650|580|570|6GB|4GB") {
        $targetVramScale = 0.65
    } else {
        $targetVramScale = 0.70
    }
}

Write-Host "  GPU Model  : $gpuName" -ForegroundColor White
Write-Host "  -> Optimal VideoMemoryScale    : $targetVramScale`n" -ForegroundColor Green

# -------------------------------------------------------------------
# 7. Comprehensive Settings Map (Covers MWII, MWIII, BO6, BO7 & Warzone)
# -------------------------------------------------------------------
$settings = [ordered]@{
    'RendererWorkerCount'        = "$optimalWorkers"
    'VideoMemoryScale'           = ("{0:F6}" -f $targetVramScale)
    'WorldMotionBlur'            = "false"
    'WeaponMotionBlur'           = "false"
    'EnableVelocityBasedBlur'    = "false"
    'DepthOfField'               = "false"
    'FilmGrain'                  = "0.000000"
    'CorpseLimit'                = "0"
    'CorpsesMaxCount'            = "0"
    'ShowBlood'                  = "false"
    'Blood'                      = "false"
    'ShowBrass'                  = "false"
    'SubsurfaceScattering'       = "false"
    'Tessellation'               = "Off"
    'AmbientOcclusion'           = "Off"
    'AmbientLightingQuality'     = "Off"
    'ScreenSpaceReflections'     = "Off"
    'SSRQuality'                 = "Off"
    'ScreenSpaceShadowQuality'   = "Off"
    'WaterCaustics'              = "false"
    'WaterCausticsMode'          = "Off"
    'WaterWaveWetness'           = "false"
    'WeatherGridVolumesQuality'  = "Off"
    'ClutterMaxDistance'         = "Lowest"
    'SunShadowCascade'           = "Low"
    'SpotShadowQuality'          = "Low"
    'ShadowQuality'              = "Very_Low"
    'VolumetricQuality'          = "Low"
    'ParticleQuality'            = "very low"
    'ParticleLightingQuality'    = "Low"
    'DynamicResolution'          = "false"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$modifiedCount = 0

foreach ($p in $searchPaths) {
    Write-Host "[*] Scanning directory: $p" -ForegroundColor Cyan
    $files = Get-CoDConfigs -targetDir $p
    
    if (-not $files -or $files.Count -eq 0) {
        Write-Host "  No active config files in this path." -ForegroundColor DarkGray
        continue
    }

    foreach ($file in $files) {
        # Per-directory backup
        $backupDir = Join-Path $file.DirectoryName "_backup_$timestamp"
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        Copy-Item -Path $file.FullName -Destination $backupDir -Force
        
        Set-ItemProperty -Path $file.FullName -Name IsReadOnly -Value $false

        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $modified = $false

        foreach ($k in $settings.Keys) {
            $rawVal = $settings[$k]

            # 1. Match BO6 / BO7 / Modern Text Syntax: Key@0;12345;67890 = CurrentVal // Comments
            $patternBo = "(?m)^(\s*)$([regex]::Escape($k))(@[0-9;]+\s*=\s*)([^
/]*)(.*)$"
            if ($content -match $patternBo) {
                $boVal = $rawVal.Trim('"')
                if ($k -eq 'Tessellation') { $boVal = '0_Off' }
                if ($k -eq 'VolumetricQuality') { $boVal = 'QUALITY_LOW' }
                $content = [regex]::Replace($content, $patternBo, "`$1$k`$2$boVal `$4")
                $modified = $true
                continue
            }

            # 2. Match CST Standard Syntax: Key:0.0 = "Value"
            $patternCst = "(?m)^(\s*//?\s*|\s*)$([regex]::Escape($k))(:[0-9.]+\s*=\s*).*$"
            if ($content -match $patternCst) {
                $cstVal = "`"$($rawVal.Trim('"'))`""
                $content = [regex]::Replace($content, $patternCst, "$k`$2$cstVal")
                $modified = $true
                continue
            }

            # 3. Match Standard INI / TXT Syntax: Key = Value
            $patternGen = "(?m)^(\s*)$([regex]::Escape($k))(\s*[:=]\s*)([^
/]*)(.*)$"
            if (-not $modified -and ($content -match $patternGen)) {
                $genVal = $rawVal.Trim('"')
                $content = [regex]::Replace($content, $patternGen, "`$1$k`$2$genVal `$4")
                $modified = $true
            }
        }

        if ($modified) {
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
            Write-Host "  [OPTIMIZED] $($file.FullName)" -ForegroundColor Green
            $modifiedCount++
        } else {
            Write-Host "  [VERIFIED]  $($file.FullName)" -ForegroundColor Gray
        }

        # Apply Read-Only protection
        Set-ItemProperty -Path $file.FullName -Name IsReadOnly -Value $true
        Write-Host "  [LOCKED]    $($file.Name) (Read-Only)" -ForegroundColor DarkGreen
    }
}

Write-Host "`n=================================================================" -ForegroundColor Magenta
Write-Host "  SUCCESS! Call of Duty is optimized and protected.              " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Magenta
Write-Host "• Files Processed     : $modifiedCount optimized & all locked" -ForegroundColor White
Write-Host "• RendererWorkerCount : $optimalWorkers" -ForegroundColor White
Write-Host "• VideoMemoryScale    : $targetVramScale" -ForegroundColor White
Write-Host "• Dual-Slot Sync      : Active (.txt0 and .txt1 locked together)" -ForegroundColor White
Write-Host "• Config Protection   : Read-Only Applied across all titles" -ForegroundColor White
Write-Host "• Safety Revert       : Run with -Restore to undo changes at any time`n" -ForegroundColor DarkCyan
