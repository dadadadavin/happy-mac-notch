# Happy Mac Notch

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-black?style=for-the-badge&logo=apple" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20(M1--M4)-000000?style=for-the-badge&logo=apple" alt="Apple Silicon" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" />
  <img src="https://img.shields.io/badge/Status-Production%20Ready-success?style=for-the-badge" alt="Production Ready" />
</p>

<p align="center">
  <b>Happy Mac Notch</b> transforms your MacBook's physical notch into a native, hyper-responsive Dynamic Island experience. Built from the ground up in pure Swift and AppKit/SwiftUI with zero background polling, 0% idle CPU overhead, and instant responsiveness.
</p>

---

## ✨ Features

### 🎵 Now Playing & Live Synced Lyrics
- **Live Lyrics Pill**: Floating synced lyrics pill anchored beside your closed notch with real-time animated equalizer waves.
- **In-Widget Lyrics Toggle**: One-click `Lyrics` toggle right inside the music card.
- **Seamless Player Sync**: Works with **Spotify** and **Apple Music**.
- **Zero-Polling Event Engine**: Listens to system notifications (`DistributedNotificationCenter`) rather than running battery-draining AppleScript loops in the background.
- **Interactive Scrubber & Transport**: Drag along the timeline to scrub with precision timestamps (`0:00` / `3:35`), prominent circular play/pause, and skip controls.
- **Dynamic Waveform**: Active audio equalizer bars that bounce live during playback and rest elegantly when paused.

### 📥 Drop Shelf (Universal File Parking Lot)
- **Drag & Hold**: Drag files from Finder, Safari, Chrome, or any application directly onto the notch to park them across all spaces and fullscreen apps.
- **Drag-Back-Out**: Seamlessly drag parked files out of the shelf directly into Slack, email drafts, Discord, Terminal, or another folder.
- **File Management**: Native macOS file icons, accurate file sizes, reveal in Finder, and one-click clear.

### ⚡ Apple Silicon Hardware Vitals
- **Live SoC Temperature**: Direct in-kernel sensor queries via `IOHIDEventSystemClient` for instant Apple Silicon SoC temperature readings.
- **Mach Kernel Statistics**: Real-time CPU usage (`host_cpu_load_info`) and memory pressure (`vm_statistics64`) without spawning subprocesses.
- **Instant Battery & Power**: Microsecond IOKit power source snapshots with battery health, percentage, and charging state.
- **SSD Storage & Weather**: Quick glance at available storage and local weather vitals.
- **Quick Actions**: One-click Display Sleep / Lock screen and clean Quit shortcut.

### 🛡️ Edge-Touch Proximity Engine
- **Intentional Triggering**: Requires the cursor to touch the physical top bezel directly above the notch cutout (`distFromTop <= 2.0pt`), eliminating accidental pops while clicking browser tabs or menu items.
- **Side Rejection**: Constrained within the horizontal notch bounds—cursor movement along the menu bar cannot trigger expansion.
- **Zero-Delay Snap Back**: Collapses back into the notch immediately with an interactive spring animation the instant your cursor leaves the card.
- **Idle HUD Mode**: Displays hardware die temperature on the left wing and battery status on the right wing directly inside the notch when closed.

---

## 🚀 Quick Install (Recommended)

Run this one-liner in Terminal to clone, build, install to `/Applications`, and launch automatically:

```bash
git clone https://github.com/dadadadavin/happy-mac-notch.git
cd happy-mac-notch
./install.sh
```

The `install.sh` script automatically:
1. Compiles the optimized release binary using Swift 6.0.
2. Packages `NotchApp.app` and installs it to `/Applications/NotchApp.app`.
3. Clears Gatekeeper quarantine attributes (`xattr -cr`).
4. Signs the application bundle.
5. Launches Happy Mac Notch.

---

## 🛠️ Manual Build & Installation

If you prefer building manually without the installer:

```bash
# 1. Clone repository
git clone https://github.com/dadadadavin/happy-mac-notch.git
cd happy-mac-notch

# 2. Build release bundle
./build.sh

# 3. Copy to Applications
cp -R NotchApp.app /Applications/

# 4. Clear Gatekeeper quarantine flags
xattr -cr /Applications/NotchApp.app

# 5. Launch
open /Applications/NotchApp.app
```

---

## 🔒 Permissions Setup (Important)

To enable all features, grant the following standard macOS permissions when prompted:

### 1. Accessibility Permission (Required for Edge-Hover)
Happy Mac Notch uses an event monitor (`NSEvent.addGlobalMonitorForEvents`) to detect when your mouse touches the physical top bezel above the notch while you are in other apps.
- On first launch, macOS will display an **Accessibility Access** prompt. Click **Open System Settings**.
- Alternatively, open **System Settings** → **Privacy & Security** → **Accessibility**.
- Ensure **NotchApp** is toggled **ON**.

> [!NOTE]
> If Accessibility is not enabled, hover detection cannot monitor cursor position outside the notch window, though clicking the notch will still work.

### 2. Automation / Apple Events (For Media Controls)
To fetch track metadata and control Spotify or Apple Music:
- When music plays or you interact with playback controls, macOS will ask: *"NotchApp would like to control Spotify / Music"*.
- Click **OK** / **Allow**.
- Verify anytime in **System Settings** → **Privacy & Security** → **Automation** → **NotchApp**.

---

## 📖 How to Use

| Action | How to Trigger |
| :--- | :--- |
| **Expand Notch** | Push your mouse cursor to the physical top edge of the screen directly at the camera notch and pause for 0.1s. Alternatively, click on the notch. |
| **Collapse Notch** | Move your cursor away from the card, or click the `✕` close button in the top-right header wing. |
| **Switch Tabs** | Click `Music`, `Drop Shelf`, or `Stats` in the header bar flanking the notch. |
| **Toggle Live Lyrics** | Click the `[ 💬 Lyrics ]` button in the Music widget. A live lyric pill will float next to your notch whenever music plays with available lyrics. |
| **Scrub Music** | Drag anywhere on the progress bar in the Music widget to seek through the track. |
| **Park Files** | Drag any file from Finder or browser into the notch to hold it across desktop spaces. |
| **Retrieve Files** | Drag parked file cards out of the Drop Shelf into Slack, Mail, Terminal, or any destination. |

---

## 🔄 Launch at Login (Optional)

To have Happy Mac Notch start automatically when your Mac boots:
1. Open **System Settings** → **General** → **Login Items & Extensions**.
2. Under **Open at Login**, click the **`+`** button.
3. Select **`NotchApp`** from your `/Applications` folder and click **Open**.

---

## 🛑 Uninstallation

To completely remove Happy Mac Notch:

```bash
cd happy-mac-notch
./uninstall.sh
```

Or manually drag `/Applications/NotchApp.app` to the Trash and terminate the process with `killall NotchApp`.

---

## 🏗️ Architecture & Performance

| Metric | Happy Mac Notch | Traditional Utility Apps |
| :--- | :--- | :--- |
| **Idle CPU Usage** | **0.0%** (Event-driven) | 2% – 8% (Polling timers) |
| **Memory Footprint** | **~25 MB** | 120 MB – 300 MB (Electron/WebViews) |
| **Media Detection** | Native `DistributedNotificationCenter` | Continuous AppleScript process polling |
| **Thermal Monitoring**| In-process `IOHIDEventSystemClient` | Forked CLI tools (`powermetrics`) |
| **RAM / CPU Monitoring**| Direct Mach Kernel syscalls | Spawning `ps` / `top` subprocesses |
| **Xcode Requirement** | **None** (Pure Swift Package Manager) | Requires 30GB+ Xcode IDE installation |

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
