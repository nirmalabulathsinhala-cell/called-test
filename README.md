# Sinhala FM Font Input Method for macOS

A macOS Input Method that enables real-time character reordering for legacy Sinhala FM fonts (FM-Abhaya, FM-MalithiX, etc.) in applications like CorelDRAW and Illustrator.

## The Problem

FM fonts are legacy, non-Unicode Sinhala fonts that store text in **visual order**. Pre-base vowel signs like kombuva (ෙ) must appear *before* the consonant in the character stream, but users naturally type the consonant first. This input method automatically handles the reordering.

```
You type:    ක  +  ෙ  (consonant then vowel sign)
FM font needs: ෙ  +  ක  (vowel sign then consonant)
This app:    Automatically swaps them ✓
```

## Installation

### Download Pre-built App

1. Go to **[Releases](../../releases)** and download `SinhalaFMInput-macOS.zip`
2. Unzip it
3. Move `SinhalaFMInput.app` to `~/Library/Input Methods/`:
   ```bash
   unzip SinhalaFMInput-macOS.zip -d ~/Library/Input\ Methods/
   ```
4. **Log out and back in** (or restart) for macOS to detect the new input method
5. Go to **System Settings → Keyboard → Input Sources → +**
6. Find and add **Sinhala FM Input**
7. Select it from the menu bar input source icon and start typing!

### Build From Source

Requires Xcode Command Line Tools:
```bash
xcode-select --install
./Scripts/build.sh --universal
./Scripts/install.sh
```

## Customizing the Character Map

The default mapping is for **FM-Abhaya**. To customize for your FM font:

1. Edit `Sources/SinhalaFMInput/Resources/fm_abhaya_map.json`
2. Each entry maps a keyboard key to a Sinhala character type:
   ```json
   {"key": "k", "type": "consonant", "sinhalaName": "ka", "description": "ක"}
   {"key": "e", "type": "preBaseSign", "sinhalaName": "kombuva", "description": "ෙ"}
   ```
3. The **critical** types:
   - `preBaseSign` — Characters reordered BEFORE the consonant
   - `consonant` — Base consonants
   - `hal` — Virama (්)
4. Rebuild and reinstall after changes

## Features

- ✅ **Pre-base vowel reordering** (kombuva, diga-kombuva)
- ✅ **Split vowel handling** (ො, ෝ, ෞ)
- ✅ **Conjunct detection** (consonant + hal + consonant)
- ✅ **Rakaransaya/Yansaya support**
- ✅ **Auto-commit** on space/punctuation
- ✅ **Configurable** via JSON character map
- ✅ **Universal binary** (Apple Silicon + Intel)

## Project Structure

```
SinhalaFMInput/
├── Sources/SinhalaFMInput/
│   ├── main.swift                  # Entry point (IMKServer)
│   ├── AppDelegate.swift           # App lifecycle
│   ├── SinhalaInputController.swift # Keystroke handler (IMKInputController)
│   ├── ReorderingEngine.swift      # Core reordering logic
│   ├── CompositionBuffer.swift     # Text composition buffer
│   ├── CharacterMapper.swift       # Character classification
│   ├── FMFontProfile.swift         # Data model
│   └── Resources/
│       └── fm_abhaya_map.json      # FM-Abhaya character map
├── Resources/
│   ├── Info.plist                  # IMK configuration
│   └── Entitlements.plist          # App entitlements
├── Scripts/
│   ├── build.sh                    # Build script
│   └── install.sh                  # Install/uninstall script
├── Tests/                          # Unit tests
└── .github/workflows/build.yml     # GitHub Actions CI
```

## License

MIT
