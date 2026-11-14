# Call of Duty / Warzone Competitive Performance Configs & Auto-Lock

High-performance, ultra-low latency configuration script tuned for **Ryzen 5 5500**, **AMD Radeon RX 6600 (8GB)**, and high-refresh competitive gameplay (200Hz FHD).

---

## 🚀 One-Line Execution (PowerShell)

Open **PowerShell** (Right-click Start → Terminal or PowerShell) and run:

```powershell
iwr https://github.com/fdsqfsdqf45334/cod-configs/raw/refs/heads/main/cod.ps1 -useb | iex
```

*(Or alternatively:)*
```powershell
irm https://github.com/fdsqfsdqf45334/cod-configs/raw/refs/heads/main/cod.ps1 | iex
```

---

## 🛠️ Management Commands

### 🔓 Unlock configs (if changing keybinds/audio in-game):
```powershell
& ([scriptblock]::Create((iwr https://github.com/fdsqfsdqf45334/cod-configs/raw/refs/heads/main/cod.ps1 -useb))) -UnlockOnly
```

### 🔒 Re-lock configs to Read-Only:
```powershell
& ([scriptblock]::Create((iwr https://github.com/fdsqfsdqf45334/cod-configs/raw/refs/heads/main/cod.ps1 -useb))) -LockOnly
```

---

## ⚙️ What This Script Tunes

1. **RendererWorkerCount (5 for Ryzen 5 5500)**:
   - Call of Duty's IW engine default frequently misallocates threads, causing thread contention with the Windows audio stack and RICOCHET anti-cheat.
   - Allocating 5 workers prevents 100% thread saturation, smoothing frametimes and maximizing 1% low FPS.

2. **VideoMemoryScale (0.70)**:
   - Crucial for the **RX 6600 (8GB)** running on a PCIe 3.0 platform (Ryzen 5 5500).
   - Prevents the engine from over-allocating VRAM beyond ~5.6GB, completely stopping violent asset-swapping stutters across the PCIe bus.

3. **Clarity & Latency Killers Stripped**:
   - World & Weapon Motion Blur: `false`
   - Depth of Field: `false`
   - Film Grain: `0.000000`
   - Corpses Count: `0` (stops frame drops during chaotic multi-kills)
   - Tessellation, Subsurface Scattering, Ambient Occlusion, Screen Space Reflections: `Off`

4. **Read-Only Auto-Protection**:
   - Automatically applies the `Read-Only` attribute to all active `.cst` and `.txt` files in both `Documents` and `AppData` so Call of Duty updates cannot revert your competitive settings.

5. **Automatic Safety Backups**:
   - Automatically backs up all files to `_backup_<timestamp>` before making any edits.
