# Call of Duty / Warzone Universal Competitive Performance Optimizer

High-performance engine optimization script with hardware auto-detection for **Intel** and **AMD Ryzen** platforms, dynamic VRAM scaling, and automatic Read-Only config protection.

---

## ⚡ Quick Start (1-Line Command)

Open **PowerShell** (Right-click Start → Terminal or PowerShell) and run:

```powershell
irm https://github.com/fdsqfsdqf45334/cod-configs/raw/refs/heads/main/cod.ps1 | iex
```
*(Or via `iwr -useb`:)*
```powershell
iwr https://github.com/fdsqfsdqf45334/cod-configs/raw/refs/heads/main/cod.ps1 -useb | iex
```

---

## 🧠 How It Automatically Adapts to Any PC

### 1. CPU Thread Allocation (`RendererWorkerCount`)
Call of Duty's default worker thread assignment causes micro-stuttering and drops 1% lows. This script detects your exact processor topology:
* **Intel 12th / 13th / 14th Gen & Core Ultra (Hybrid Architecture):**
  - Detects Performance (P) vs Efficiency (E) cores.
  - Pins worker threads exclusively to **P-Cores**, completely stopping workers from being dumped onto weak E-cores which cause massive stutter spikes.
* **AMD Ryzen 6-Core (5600, 5500, 7600):**
  - Sets worker count to **5**, leaving 1 physical core for Windows OS, audio stack, and RICOCHET anti-cheat to eliminate thread contention.
* **AMD Ryzen 8-Core (5700X, 5800X3D, 7800X3D, 9800X3D):**
  - Sets worker count to **7** for maximum multi-threaded framerate throughput.
* **AMD Ryzen Dual-CCD (5900X, 5950X, 7900X, 7950X):**
  - Caps worker threads to a single CCD (6 or 7), preventing cross-CCD latency penalties across AMD's Infinity Fabric bus.

### 2. Smart VRAM Scaling (`VideoMemoryScale`)
* **4GB - 6GB GPUs (GTX 1660, 1060, RX 580):** Sets to `0.65` to avoid overflowing into system RAM.
* **8GB GPUs (RX 6600, RTX 3060, RTX 4060):** Sets to `0.70` (~5.6GB cap) to eliminate PCIe bus saturation stutters.
* **10GB - 12GB GPUs (RTX 3080, 4070):** Sets to `0.75`.
* **16GB+ GPUs (RTX 4080, 4090, 7900 XTX):** Sets to `0.80`.

### 3. Competitive Clarity & Latency Optimization
* Completely disables **World & Weapon Motion Blur**, **Depth of Field**, and **Film Grain** for crystal-clear 144Hz–240Hz+ tracking.
* Sets `CorpsesMaxCount = 0` to eliminate frame drops during multi-kills.
* Strips performance-draining tessellation, ambient occlusion, water caustics, and volumetrics.

---

## 🛠️ Management & Safety Controls

### 🔄 Restore Original Settings (Revert at any time)
If you or a friend ever want to revert everything back to how it was:
```powershell
& ([scriptblock]::Create((irm https://github.com/fdsqfsdqf45334/cod-configs/raw/refs/heads/main/cod.ps1))) -Restore
```

### 🔓 Unlock Configs (To change keybinds or audio in-game)
```powershell
& ([scriptblock]::Create((irm https://github.com/fdsqfsdqf45334/cod-configs/raw/refs/heads/main/cod.ps1))) -Unlock
```

### 🔒 Re-lock Configs (Read-Only Protection)
```powershell
& ([scriptblock]::Create((irm https://github.com/fdsqfsdqf45334/cod-configs/raw/refs/heads/main/cod.ps1))) -Lock
```

---

## 📁 Supported Titles & Directory Structures
* **Call of Duty HQ (Warzone, Modern Warfare III, Black Ops 6, Modern Warfare II)**
* Supports standard `Documents`, **OneDrive redirected** paths, and Activision account ID subfolders.
* Backs up files with timestamped archives before making any changes.
