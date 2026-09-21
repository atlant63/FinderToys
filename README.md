<div align="center">

<img src="./assets/logo.png" width="128" height="128" alt="FinderToys Logo">

# FinderToys 🛠️
**The missing power-user utilities for macOS Finder.**

**English** | [Русский](README.ru.md)

[![macOS](https://img.shields.io/badge/macOS-13.0+-A2AAAD?style=flat-square&logo=apple)](https://apple.com)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-blue?style=flat-square)](#)
[![License](https://img.shields.io/badge/License-GPL--3.0-green?style=flat-square)](./LICENSE)
[![Size](https://img.shields.io/badge/DMG-~1MB-success?style=flat-square)](#)

</div>

**FinderToys** supercharges macOS Finder with intuitive keyboard controls, smart clipboard file creation, and a rich right-click context menu. Written entirely in native Objective-C and AppKit, it runs with near-zero CPU usage, has zero Electron bloat, and seamlessly blends into macOS.

---

## ⚡ Quick Installation

### Option 1: Terminal One-Liner (Recommended)
Open Terminal and run:
```bash
curl -fsSL https://raw.githubusercontent.com/Danikk13/FinderToys/main/install.sh | bash
```

### Option 2: DMG Download
1. Download **[`FinderToys.dmg`](https://github.com/Danikk13/FinderToys/releases/latest/download/FinderToys.dmg)**.
2. Open the `.dmg` and drag **FinderToys** into your **Applications** folder.
3. Launch **FinderToys** from Applications.

---

## ✨ Features

### ⌨️ Intuitive Hotkeys
| Action | Key Combination | Description |
| :--- | :--- | :--- |
| **Open File/Folder** | <kbd>Enter</kbd> (Return) | Opens the selected item immediately instead of renaming it. |
| **Rename File/Folder** | <kbd>F2</kbd>, <kbd>⌥ Option + F2</kbd>, <kbd>⌘ Cmd + R</kbd> | Triggers native in-line file renaming without delay. |
| **Alternative Rename** | <kbd>⇧ Shift + Enter</kbd>, <kbd>⌥ Option + Enter</kbd> | Secondary shortcuts for quick renaming flexibility. |

> [!NOTE]
> **Safety First:** When renaming an item or typing in Finder search fields, <kbd>Enter</kbd> and <kbd>⌘V</kbd> behave normally so your input is never disrupted.

---

### 📋 Smart Clipboard Paste (<kbd>⌘ Cmd + V</kbd>)
Press <kbd>⌘V</kbd> inside any Finder folder or on your Desktop to instantly convert clipboard contents into files:

* **Images:** Copied a screenshot, meme, or web image? Press <kbd>⌘V</kbd> to save it directly as `image.png` (automatically increments: `image 2.png`, `image 3.png`, etc.).
* **Text & Code:** Copied code or text? Press <kbd>⌘V</kbd> to save it as `Clipboard.txt`.
* **JSON:** Copied valid JSON formatted data? Press <kbd>⌘V</kbd> to save it as `Clipboard.json`.
* **Web Links:** Copied a single URL? Press <kbd>⌘V</kbd> to create a `.webloc` internet shortcut.
* **Context Aware:** Dynamically detects the currently active Finder directory (Downloads, Documents, external drives, or Desktop) and selects the created file immediately.
* **Zero Conflict:** Bypasses file conversion if you copied actual files or folders in Finder, allowing native copy/paste.

---

### 🖱️ Right-Click Context Menu
Right-click anywhere in Finder or on Desktop:

1. **New File:** Instant creation of blank template documents:
   * **Plain Text** (`.txt`), **Markdown** (`.md`), **JSON** (`.json`)
   * **Microsoft Office:** Word (`.docx`), Excel (`.xlsx`), PowerPoint (`.pptx`)
   * **Apple iWork:** Pages (`.pages`), Numbers (`.numbers`), Keynote (`.key`)
2. **Copy Path:** Copies the clean POSIX path directly to clipboard (without wrapping quotes).
3. **Open Terminal:** Launches Terminal positioned directly at the current folder.

---

### 🌐 Menu Bar & Auto Language Detection
* Clean menu bar status item with toggles for all key features.
* **Automatic System Language:** Automatically detects your macOS system language:
  * Uses **Russian** on Russian macOS systems (`ru-RU`, `ru-UZ`, etc.).
  * Defaults to **English** for international systems.

---

## 🔒 Permissions & Setup

FinderToys requires two standard macOS permissions to function:

1. **Accessibility (for Enter to Open & F2 / ⌘V Hotkeys):**
   * Go to **System Settings** → **Privacy & Security** → **Accessibility**.
   * Toggle **FinderToys** (or `MacNewFile`) to **ON**.
2. **Finder Extension (for Context Menu):**
   * Go to **System Settings** → **General** → **Login Items & Extensions** → **Finder Extensions**.
   * Toggle **FinderToys Extension** to **ON**.

---

## 🛠️ Building from Source

Requirements: macOS 13.0+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone git@github.com:Danikk13/FinderToys.git
cd FinderToys
./build.sh -d -i
```
* `-d`: Generates `dist/MacNewFile.dmg` installer.
* `-i`: Installs and launches the application in `/Applications`.

---

## 📄 License

FinderToys is distributed under the GNU General Public License v3.0. See [LICENSE](./LICENSE) for details.
