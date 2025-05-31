# AlwaysOnTop

<div align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue?style=for-the-badge&logo=apple" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.5+-orange?style=for-the-badge&logo=swift" alt="Swift 5.5+">
  <img src="https://img.shields.io/github/license/itsabhishekolkha/AlwaysOnTop?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/github/stars/itsabhishekolkha/AlwaysOnTop?style=for-the-badge" alt="GitHub Stars">
</div>

<div align="center">
  <h3>🚀 Keep your most important app always visible on macOS</h3>
  <p>A lightweight, elegant macOS application that pins any window to stay on top of all other windows with a simple keyboard shortcut.</p>
</div>

## ✨ Features

###  Core Functionality
- **One-Click Window Pinning**: Pin any application window to stay always on top
- **Smart App Selection**: Beautiful popup interface to choose which app to pin
- **Customizable Keyboard Shortcuts**: Set your preferred hotkey combination for quick pin/unpin
- **Menu Bar Integration**: Convenient access from your menu bar



## 📋 Requirements

- **macOS 13.0 (Ventura) or later**
- **Accessibility permissions** (for window management)
- **Approximately 5MB disk space**

## 🚀 Installation

### Download and Install
1. Download the latest release: [**AlwaysOnTop v1.0.0**](https://github.com/itsabhishekolkha/AlwaysOnTop/releases/download/v1.0.0/AlwaysOnTop.v1.0.0.dmg)
2. Open the downloaded DMG file
3. Drag AlwaysOnTop to your Applications folder to complete the installation

### Important Security Notice for macOS Users

When you first attempt to open AlwaysOnTop, macOS may display a warning message stating that the app "cannot be opened because it is from an unidentified developer" or that it "may damage your computer." **This is a normal security response and does not indicate any actual threat.**

#### Method 1: Using Terminal (Recommended)
```bash
sudo xattr -rd com.apple.quarantine /Applications/AlwaysOnTop.app
```

#### Method 2: Using System Preferences
1. Go to **System Preferences** → **Privacy & Security**
2. Scroll down to find the blocked AlwaysOnTop app
3. Click **"Open Anyway"** next to the AlwaysOnTop entry
4. Confirm by clicking **"Open"** in the dialog that appears

### Grant Accessibility Permissions
For AlwaysOnTop to manage windows, you need to grant Accessibility permissions:

1. Open **System Preferences** → **Privacy & Security** → **Accessibility**
2. Click the **🔒 lock icon** and enter your password
3. Click **"+"** and add **AlwaysOnTop** from your Applications folder
4. Ensure the checkbox next to AlwaysOnTop is **checked**
5. Restart AlwaysOnTop if it was already running

## How to Use AlwaysOnTop

### Quick Start
1. **Launch AlwaysOnTop** - It will appear in your menu bar with a pin icon
2. **Now open preference using the menubar icon"
3. **Press the keyboard shortcut** (default: `ctrl + Z`) or (`ctrl + A`) to open app selection now close the preperence.
4. **Choose an app** press the shortcut and the popup interface will apear clik on any app
5. **Selected app window is now pinned!** It will stay on top of all other windows
6. **Unpin** press the press the shortcut again and the app will be unpinned.
7. **Note** suppose you opened the popup and dont want to pin any app then simply use the same shortcut to dismiss it.
8. **Persist Last Pinned App**: Toggle whether to remember pinned windows across app restarts

### Menu Bar Actions
- **Select Application**: Choose which app to pin from a submenu
- **Toggle Window Pin**: Pin or unpin the currently selected app
- **Preferences**: Access settings and customization options
- **Refresh Applications**: Update the list of running apps



### Startup Settings
- **Launch at Login**: Automatically start AlwaysOnTop when you log in to macOS
- **App Persistence**: Remember and restore your last pinned app after restart


### 🎨 Appearance Customization
- **Theme Modes**: Choose between Light, Dark, or Auto (follows system preference)
- **Accent Colors**: Select from multiple color options to personalize your experience
- **Modern UI**: All interface elements respect your theme and color choices


## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **⭐ Star this repository** to show your support
2. **🐛 Report bugs** by creating detailed GitHub issues
3. **💡 Suggest features** through GitHub discussions
4. **🔧 Submit pull requests** for bug fixes or improvements

### Development Setup
```bash
git clone https://github.com/itsabhishekolkha/AlwaysOnTop.git
cd AlwaysOnTop
open AlwaysOnTop.xcodeproj
```

## 💝 Support This Project

If AlwaysOnTop has improved your workflow, consider supporting its development:

<div align="center">

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/abhishekolkha)
[![PayPal](https://img.shields.io/badge/PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://paypal.me/abhishekolkha)
[![GitHub Sponsors](https://img.shields.io/badge/GitHub%20Sponsors-EA4AAA?style=for-the-badge&logo=github-sponsors&logoColor=white)](https://github.com/sponsors/itsabhishekolkha)

</div>

Your support helps maintain and improve AlwaysOnTop for everyone! 🚀

### Other Ways to Support
- ⭐ **Star this repository** on GitHub

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **🚀 Download Latest Release**: [AlwaysOnTop v1.0.0](https://github.com/itsabhishekolkha/AlwaysOnTop/releases/download/v1.0.0/AlwaysOnTop.v1.0.0.dmg)
- **📦 All Releases**: [GitHub Releases](https://github.com/itsabhishekolkha/AlwaysOnTop/releases)
- **🐛 Report Issues**: [GitHub Issues](https://github.com/itsabhishekolkha/AlwaysOnTop/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/itsabhishekolkha/AlwaysOnTop/discussions)

---

<div align="center">
  <p>Made with ❤️ by <a href="https://github.com/itsabhishekolkha">Abhishek Olkha</a></p>
  <p>⭐ Don't forget to star this repository if you found it helpful!</p>
</div>
