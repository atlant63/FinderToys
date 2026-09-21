<div align="center">

<img src="./assets/logo.png" width="128" height="128" alt="FinderToys Logo">

# FinderToys 🛠️
**Полезные утилиты и горячие клавиши для macOS Finder**  
*The missing power-user utilities for macOS Finder*

[![macOS](https://img.shields.io/badge/macOS-13.0+-A2AAAD?style=flat-square&logo=apple)](https://apple.com)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-blue?style=flat-square)](#)
[![License](https://img.shields.io/badge/License-GPL--3.0-green?style=flat-square)](./LICENSE)
[![Size](https://img.shields.io/badge/DMG-942%20KB-success?style=flat-square)](#)

<br/>

### ⬇️ **[Скачать FinderToys.dmg (942 КБ)](https://github.com/Danikk13/FinderToys/releases/download/v2.0.0/FinderToys.dmg)**
*(Прямая ссылка на готовый установочный образ)*

</div>

---

## ⚡ Установка одной командой в Терминале / Quick Install

Откройте приложение **«Терминал»** (Terminal) и вставьте команду:
```bash
curl -fsSL https://raw.githubusercontent.com/Danikk13/FinderToys/main/install.sh | bash
```
> *Скрипт автоматически загрузит свежий `.dmg`, установит приложение в папку «Программы», снимет системный карантин macOS, активирует расширение Finder и сразу запустит утилиту.*

---

<details open>
<summary><h2>🇷🇺 Документация и возможности (нажмите, чтобы свернуть)</h2></summary>

### 💡 Что умеет FinderToys?
**FinderToys** расширяет стандартный Finder в macOS интуитивным управлением с клавиатуры, умным созданием файлов из буфера обмена и удобным контекстным меню по правому клику мыши. Приложение полностью нативное (Objective-C + AppKit), потребляет ~0% процессора и работает плавно.

---

### ⌨️ Горячие клавиши
| Действие | Сочетание клавиш | Описание |
| :--- | :--- | :--- |
| **Открыть файл/папку** | <kbd>Enter</kbd> (Return) | Мгновенно открывает выбранный элемент вместо его переименования. |
| **Переименовать** | <kbd>F2</kbd>, <kbd>⌥ Option + F2</kbd>, <kbd>⌘ Cmd + R</kbd> | Запускает стандартное системное переименование. |
| **Доп. переименование** | <kbd>⇧ Shift + Enter</kbd>, <kbd>⌥ Option + Enter</kbd> | Альтернативные сочетания для быстрого переименования. |

> [!NOTE]
> **Умная защита ввода:** При наборе текста (когда вы редактируете имя файла, ищете через Spotlight в Finder или вводите путь) клавиши <kbd>Enter</kbd> и <kbd>⌘V</kbd> работают в стандартном текстовом режиме и не перехватываются.

---

### 📋 Умная вставка из буфера (<kbd>⌘ Cmd + V</kbd>)
Нажмите <kbd>⌘V</kbd> в любой открытой папке Finder или на Рабочем столе:

* **Картинки:** Скопировали скриншот или изображение из браузера? Нажмите <kbd>⌘V</kbd> — файл сохранится как `image.png` (с авто-нумерацией: `image 2.png`, `image 3.png`...).
* **Текст и код:** Скопировали фрагмент кода или текст? Нажмите <kbd>⌘V</kbd> — создастся текстовый файл `Clipboard.txt`.
* **JSON:** Скопировали данные JSON? Нажмите <kbd>⌘V</kbd> — сохранится файл `Clipboard.json`.
* **Веб-ссылки:** Скопировали URL-адрес? Нажмите <kbd>⌘V</kbd> — создастся ярлык сайта `.webloc`.
* **Автоопределение папки:** Файл создается именно в той папке, в которой вы сейчас находитесь (Загрузки, Документы, внешний диск/SSD или Рабочий стол) и сразу подсвечивается.
* **Без конфликтов:** Если скопированы обычные файлы/папки в Finder, выполняется стандартная вставка macOS.

---

### 🖱️ Контекстное меню по правому клику (ПКМ)
Кликните правой кнопкой мыши в любом месте Finder или на Рабочем столе:
1. **Новый файл:** Создание пустых файлов шаблонов:
   * Текст (`.txt`), Markdown (`.md`), JSON (`.json`)
   * Microsoft Office: Word (`.docx`), Excel (`.xlsx`), PowerPoint (`.pptx`)
   * Apple iWork: Pages (`.pages`), Numbers (`.numbers`), Keynote (`.key`)
2. **Скопировать путь:** Копирует чистый POSIX-путь без лишних кавычек.
3. **Открыть терминал:** Мгновенно открывает Терминал в текущей папке.

---

### 🌐 Строка меню и автоопределение языка
* Иконка в строке меню с переключателями горячих клавиш.
* **Автоматический язык:** Если macOS на русском языке — интерфейс полностью на русском. На остальных системах автоматически включается английский.

---

### 🔒 Настройка разрешений macOS
1. **Универсальный доступ:** `Системные настройки` → `Конфиденциальность и безопасность` → `Универсальный доступ` → включите **FinderToys**.
2. **Расширение Finder:** `Системные настройки` → `Основные` → `Объекты входа и расширения` → `Расширения Finder` → включите **FinderToys**.

</details>

---

<details>
<summary><h2>🇬🇧 Documentation & Features (English)</h2></summary>

### 💡 What is FinderToys?
**FinderToys** supercharges macOS Finder with intuitive keyboard controls, smart clipboard file creation, and a rich right-click context menu. Written in native Objective-C & AppKit, zero Electron bloat, and near-zero CPU footprint.

---

### ⌨️ Hotkeys
| Action | Shortcut | Description |
| :--- | :--- | :--- |
| **Open File/Folder** | <kbd>Enter</kbd> (Return) | Opens the selected item immediately instead of renaming it. |
| **Rename** | <kbd>F2</kbd>, <kbd>⌥ Option + F2</kbd>, <kbd>⌘ Cmd + R</kbd> | Triggers native in-line file renaming without delay. |
| **Alternative Rename** | <kbd>⇧ Shift + Enter</kbd>, <kbd>⌥ Option + Enter</kbd> | Secondary shortcuts for quick renaming flexibility. |

> [!NOTE]
> **Input Safety:** When editing text fields (search bars, file renaming, Go to Folder), <kbd>Enter</kbd> and <kbd>⌘V</kbd> behave normally.

---

### 📋 Smart Clipboard Paste (<kbd>⌘ Cmd + V</kbd>)
Press <kbd>⌘V</kbd> inside any Finder folder or on Desktop:

* **Images:** Copy any screenshot or web image and press <kbd>⌘V</kbd> to save directly as `image.png` (auto-increments: `image 2.png`, etc.).
* **Text & Code:** Copy text or code and press <kbd>⌘V</kbd> to save as `Clipboard.txt`.
* **JSON:** Valid JSON automatically saves as `Clipboard.json`.
* **Web URLs:** Single web addresses save as `.webloc` internet shortcuts.
* **Context Aware:** Saves directly into whichever folder is currently focused (Downloads, Documents, external drives, or Desktop).
* **Zero Conflict:** Transparently passes through standard file/folder copying.

---

### 🖱️ Right-Click Context Menu
1. **New File:** Blank templates for Text, Markdown, JSON, MS Office (Word, Excel, PowerPoint), and Apple iWork (Pages, Numbers, Keynote).
2. **Copy Path:** Copies clean POSIX path without quotes.
3. **Open Terminal:** Launches Terminal positioned directly at the active folder.

---

### 🔒 Permissions
1. **Accessibility:** System Settings → Privacy & Security → Accessibility → Enable **FinderToys**.
2. **Finder Extension:** System Settings → General → Login Items & Extensions → Finder Extensions → Enable **FinderToys**.

---

### 🛠️ Building from Source
```bash
git clone git@github.com:Danikk13/FinderToys.git
cd FinderToys
./build.sh -d -i
```

</details>

---

## 📄 License
Distributed under the GNU General Public License v3.0. See [LICENSE](./LICENSE) for details.
