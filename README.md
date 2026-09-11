# Happy Mac Notch

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-black?style=for-the-badge&logo=apple" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20(M1--M4)-000000?style=for-the-badge&logo=apple" alt="Apple Silicon" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" />
  <img src="https://img.shields.io/badge/Build-Zero--Xcode-success?style=for-the-badge" alt="Zero-Xcode Build" />
</p>

<p align="center">
  <b>Happy Mac Notch</b> transforms your MacBook's physical notch into a native, hyper-responsive Dynamic Island experience. Built from the ground up in pure Swift and AppKit/SwiftUI with zero background polling, 0% idle CPU overhead, and instant responsiveness.
</p>

---

## ✨ Highlights

### 🎵 Now Playing Island
- **Seamless Player Sync**: Works with Spotify and Apple Music.
- **Zero-Polling Event Engine**: Listens to system notifications (`DistributedNotificationCenter`) rather than running AppleScript polling loops in the background.
- **Interactive Scrubber & Visualizer**: Scrub through tracks with precision dragging, toggle play/pause, skip tracks, and enjoy real-time equalizer waveforms.
- **Artwork & Metadata**: High-resolution album artwork caching with Apple-standard continuous corner squircle curves.

### 🗂️ Drop Shelf (File Parking Lot)
- **Universal Parking Station**: Drag files from Finder, browser downloads, or apps into your notch to park them across all spaces, Mission Control, and fullscreen apps.
- **Drag-Back-Out Ready**: Drag parked files directly back out into email drafts, chat windows, Slack, or terminal folders.
- **Native File Badges**: Accurate file size calculations, clean badges, and macOS system file icons.

### ⚡ Apple Silicon Hardware Vitals
- **Live Die Temperature**: Direct in-kernel sensor queries via `IOHIDEventSystemClient` for instant Apple Silicon SoC temperature readings.
- **Mach Kernel Statistics**: Real-time CPU usage (`host_cpu_load_info`) and memory pressure (`vm_statistics64`) without spawning external shell processes.
- **Instant Battery & Power**: Microsecond IOKit power source snapshots with battery health, percentage, and charging state.
- **SSD Storage Gauge & Ambient Weather**: Quick glance at available storage and local weather vitals.

### 🛡️ Edge-Touch Proximity Engine
- **Intentional Triggering**: Requires the cursor to deliberately reach the physical top bezel directly above the notch cutout (`distFromTop <= 2.0pt`), eliminating accidental pops while clicking browser tabs or menu items.
- **Side Rejection**: Constrained within the horizontal notch bounds—cursor movement along the menu bar cannot accidentally trigger expansion.
- **Zero-Delay Snap Back**: Collapses back into the notch immediately with an interactive spring animation the instant your cursor leaves the card.
- **Idle HUD Mode**: Displays hardware die temperature on the left wing and battery status on the right wing directly inside the notch when closed.

---

## 🏗️ Architecture & Performance

Happy Mac Notch is engineered with strict performance constraints:

| Metric | Happy Mac Notch | Traditional Utility Apps |
| :--- | :--- | :--- |
| **Idle CPU Usage** | **0.0%** (Event-driven) | 2% – 8% (Polling timers) |
| **Memory Footprint** | **~25 MB** | 120 MB – 300 MB (Electron/WebViews) |
| **Media Detection** | Native `DistributedNotificationCenter` | Continuous AppleScript process polling |
| **Thermal Monitoring**| In-process `IOHIDEventSystemClient` | Forked CLI tools (`osx-cpu-temp`, `powermetrics`) |
| **RAM / CPU Monitoring**| Direct Mach Kernel syscalls | Spawning `ps` / `top` subprocesses |
| **Xcode Requirement** | **None** (Pure Swift Package Manager) | Requires 30GB+ Xcode IDE installation |

---

## 🚀 Getting Started

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia).
- Apple Silicon Mac (M1, M2, M3, M4) or Intel Mac with Command Line Tools (`xcode-select --install`).

### Quick Build & Run (Single Command)

Clone the repository and run the automated build script:

```bash
git clone https://github.com/dadadadavin/happy-mac-notch.git
cd happy-mac-notch
./build.sh
open NotchApp.app
```

The build script compiles the release binary with SwiftPM, structures the macOS application bundle, generates the `Info.plist`, applies ad-hoc code-signing, and outputs a ready-to-run `.app` in seconds.

---

## ⌨️ Controls & Gestures

- **Hover to Expand**: Push your cursor to the physical top edge of the screen at the notch and pause for a fraction of a second to expand.
- **Click to Toggle**: Click the notch at any time to instantly expand or collapse.
- **Close Button**: Click the `✕` icon on the top-right header wing.
- **Drop Files**: Drag any file into the notch when open or closed to park it in the Drop Shelf.

---

## 🔒 Privacy & Permissions

Happy Mac Notch values user privacy:
- **100% Offline & Local**: No internet connectivity is required for core functionality.
- **Zero Analytics / Telemetry**: No tracking, telemetry, or network beacons.
- **Apple Events Permission**: Prompts for standard macOS automation permissions only when interacting with Spotify or Apple Music playback controls.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/dadadadavin/happy-mac-notch/issues).

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
