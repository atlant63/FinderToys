<div align="center">

<img src="./assets/logo.png" width="128" height="128" alt="FinderToys Logo - The PowerToys for macOS Finder">

# FinderToys 🛠️
### The Ultimate PowerToys Utility for macOS Finder
**Enter to Open • F2 to Rename • ⌘V Paste to File • Right-Click New File Menu**

**English** | [Русский](README.ru.md)

[![macOS](https://img.shields.io/badge/macOS-13.0+-A2AAAD?style=flat-square&logo=apple)](https://apple.com)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-blue?style=flat-square)](#)
[![License](https://img.shields.io/badge/License-GPL--3.0-green?style=flat-square)](./LICENSE)
[![Size](https://img.shields.io/badge/DMG-942%20KB-success?style=flat-square)](#)
[![GitHub Stars](https://img.shields.io/github/stars/Danikk13/FinderToys?style=flat-square&color=yellow)](https://github.com/Danikk13/FinderToys/stargazers)

<br/>

### ⬇️ **[Download FinderToys.dmg (942 KB)](https://github.com/Danikk13/FinderToys/releases/download/v2.0.0/FinderToys.dmg)**
*(Free & Open Source for Apple Silicon M1/M2/M3/M4 & Intel)*

</div>

---

**FinderToys** is a native, ultra-lightweight macOS productivity toolkit designed to fix the biggest pain points of Apple's Finder. It introduces essential desktop features familiar to Windows switchers and power users: **Enter to open files**, **F2 to rename**, **Cmd+V to save clipboard images and text directly as files**, and a **custom right-click "New File" context menu**.

Unlike heavy Electron alternatives, FinderToys is crafted with pure Objective-C and AppKit, consuming **0% CPU** and under **15 MB of RAM**.

---

## ⚡ Quick Installation

### Option 1: One-Line Terminal Command (Fastest)
Install and launch FinderToys in seconds without opening a browser:
```bash
curl -fsSL https://raw.githubusercontent.com/Danikk13/FinderToys/main/install.sh | bash
```

### Option 2: Drag-and-Drop DMG
1. Download **[`FinderToys.dmg`](https://github.com/Danikk13/FinderToys/releases/download/v2.0.0/FinderToys.dmg)**.
2. Open the disk image and drag **FinderToys** to your **Applications** folder.
3. Launch **FinderToys** from Applications or Spotlight.

---

## 📊 FinderToys vs. Default macOS Finder

| Feature | Default macOS Finder | Microsoft Windows | 🛠️ **FinderToys** |
| :--- | :---: | :---: | :---: |
| **<kbd>Enter</kbd> (Return) Action** | Renames item (frustrating) | Opens item | **Opens selected file or folder** |
| **Rename Shortcut** | <kbd>Enter</kbd> | <kbd>F2</kbd> | **<kbd>F2</kbd>, <kbd>⌥ Option + F2</kbd>, <kbd>⌘R</kbd>** |
| **Paste Image as File (<kbd>⌘V</kbd>)** | ❌ Not supported | ❌ Third-party required | **✅ Auto-saves as `image.png`** |
| **Paste Text as File (<kbd>⌘V</kbd>)** | ❌ Not supported | ❌ Third-party required | **✅ Auto-saves as `Clipboard.txt`** |
| **Right-Click "New File" Menu** | ❌ Not supported | ✅ Built-in | **✅ Office, iWork, Text, Markdown, JSON** |
| **Copy Path without Quotes** | ⚠️ Clunky shortcut | ⚠️ Manual copy | **✅ One-click clean POSIX path** |
| **Open Terminal at Current Folder** | ⚠️ Multi-step service setup | ✅ Address bar trick | **✅ One-click context menu item** |
| **Memory & Battery Impact** | High (third-party Electron apps) | N/A | **⚡ Native AppKit (~0% CPU, <15 MB RAM)** |

---

## ✨ Core Features Explained

### 1. ⌨️ Natural Keyboard Navigation: Enter to Open & F2 to Rename
Coming from Windows or Linux, pressing <kbd>Enter</kbd> in macOS Finder only renames the file instead of opening it. FinderToys restores intuitive keyboard behavior:
* **Press <kbd>Enter</kbd>:** Opens the selected file in its default application, or navigates inside the selected folder.
* **Press <kbd>F2</kbd>, <kbd>⌥ Option + F2</kbd>, or <kbd>⌘ Cmd + R</kbd>:** Instantly triggers in-line renaming.
* **Secondary Rename Keys:** Also supports <kbd>⇧ Shift + Enter</kbd> and <kbd>⌥ Option + Enter</kbd>.
* **Smart Typing Protection:** When editing a text field (renaming files, typing in Finder's search box, or using "Go to Folder"), <kbd>Enter</kbd> and <kbd>⌘V</kbd> operate normally so your text input is never interrupted.

### 2. 📋 Smart Clipboard to File (<kbd>⌘ Cmd + V</kbd>)
Never open Preview, Photoshop, or a text editor just to save what you copied. Simply press <kbd>⌘V</kbd> in any active Finder window or on your Desktop:
* **Screenshots & Images:** Copied an image from the web or taken a screenshot? Press <kbd>⌘V</kbd> to save it directly as `image.png`. Existing files won't be overwritten—FinderToys auto-increments names (`image 2.png`, `image 3.png`, etc.).
* **Code & Plain Text:** Copied a terminal command, code block, or snippet? Press <kbd>⌘V</kbd> to generate `Clipboard.txt`.
* **JSON Formatting:** Copied JSON objects or arrays? Press <kbd>⌘V</kbd> to generate `Clipboard.json`.
* **Web Links:** Copied a URL? Press <kbd>⌘V</kbd> to create a native macOS `.webloc` internet shortcut.
* **Active Folder Awareness:** Automatically detects the exact open folder (Downloads, Documents, external USB/SSD drives, or Desktop) and selects the new file immediately.
* **Zero Interference:** Standard file/folder copy-paste in Finder is completely preserved.

### 3. 🖱️ Right-Click Context Menu (Finder Sync Integration)
Right-click anywhere on empty space in Finder or on your Desktop:
* **New File:** Instant creation of pre-formatted blank documents:
  * **Text & Code:** Plain Text (`.txt`), Markdown (`.md`), JSON (`.json`)
  * **Microsoft Office:** Word (`.docx`), Excel (`.xlsx`), PowerPoint (`.pptx`)
  * **Apple iWork:** Pages (`.pages`), Numbers (`.numbers`), Keynote (`.key`)
* **Copy Path:** Copies the clean POSIX file or directory path directly to clipboard without surrounding quotes.
* **Open Terminal:** Launches Terminal directly at the current directory.

### 4. 🌐 Menu Bar & Bilingual Automatic Language Detection
* Minimalist status bar icon with toggles to enable/disable Enter to Open or Clipboard Paste at any time.
* **Seamless Language Adaptation:** Automatically matches your macOS system language:
  * Native **Russian** on Russian macOS configurations (`ru-RU`, `ru-UZ`, etc.).
  * Native **English** for international users.

---

## 🔒 macOS Permissions & Setup

To intercept Finder keystrokes and display context menus, FinderToys requires two standard macOS permissions:

1. **Accessibility (for Enter, F2, and ⌘V hotkeys):**
   * Open **System Settings** → **Privacy & Security** → **Accessibility**.
   * Toggle **FinderToys** to **ON**.
2. **Finder Extension (for Right-Click Context Menu):**
   * Open **System Settings** → **General** → **Login Items & Extensions** → **Finder Extensions**.
   * Toggle **FinderToys Extension** to **ON**.

---

## ❓ Frequently Asked Questions (FAQ)

### How do I make Enter open files on Mac like in Windows?
Install FinderToys. It automatically rebinds <kbd>Enter</kbd> to open selected files and folders in macOS Finder, while remapping <kbd>F2</kbd>, <kbd>Option + F2</kbd>, and <kbd>⌘R</kbd> for file renaming.

### How do I paste a copied image directly into Finder as a PNG?
Copy any image to your clipboard from a browser or screenshot tool, switch to Finder, and press <kbd>⌘V</kbd>. FinderToys instantly writes `image.png` to the active directory.

### How do I add a "New File" option to the Mac right-click menu?
FinderToys includes a native Apple Finder Sync extension that integrates "New File" directly into your right-click context menu, supporting `.txt`, `.docx`, `.xlsx`, `.pptx`, `.md`, and `.json`.

### Does FinderToys drain battery or slow down my Mac?
No. FinderToys is written in native Objective-C with event tap filtering. It uses 0% CPU at idle and takes less than 15 MB of memory.

---

## 🛠️ Building from Source

Requirements: macOS 13.0+ and Apple Command Line Tools (`xcode-select --install`).

```bash
git clone git@github.com:Danikk13/FinderToys.git
cd FinderToys
./build.sh -d -i
```
* `-d`: Compiles and builds `dist/FinderToys.dmg`.
* `-i`: Installs and registers the app in `/Applications/FinderToys.app`.

---

## 📄 License

FinderToys is licensed under the GNU General Public License v3.0. See [LICENSE](./LICENSE) for details.
