# 🚀 macOS Development Environment Setup

[![Checks](https://github.com/26zl/MacOS_Basic_Setup/workflows/Checks/badge.svg)](https://github.com/26zl/MacOS_Basic_Setup/actions)
[![Security Scan](https://github.com/26zl/MacOS_Basic_Setup/workflows/Security%20Scan/badge.svg)](https://github.com/26zl/MacOS_Basic_Setup/actions)
[![macOS Test](https://github.com/26zl/MacOS_Basic_Setup/workflows/macOS%20Test/badge.svg)](https://github.com/26zl/MacOS_Basic_Setup/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**One-command setup** for a complete macOS development environment with automated tool management, security best practices, and a beautiful terminal experience.

![Terminal preview](background/image.png)

## ✨ Why Use This?

Tired of manually updating dozens of tools? Spending hours configuring your development environment? This project solves that:

- ⚡ **Save Time**: One command updates everything (Homebrew, MacPorts, Nix, Python, Node.js, Ruby, Rust, Go, Swift, .NET, and more)
- 🎨 **Beautiful Terminal**: Pre-configured with Powerlevel10k, syntax highlighting, and autosuggestions
- 🛡️ **Safe & Smart**: Automatically protects system files, detects package managers, and gracefully handles missing tools
- 🔧 **Production Ready**: CI/CD safe, non-interactive mode support, comprehensive error handling
- 📦 **Multi-Language**: Supports 7+ languages with version managers (pyenv, nvm, chruby, rustup, swiftly)
- 🚀 **Zero Config**: Works out of the box on both Intel and Apple Silicon Macs

## 👥 Who Is This For?

- 🚀 **Developers** setting up a new Mac - Get productive in minutes, not hours
- 🔄 **DevOps Engineers** - Automate tool updates across multiple machines
- 🎓 **Students & Learners** - Focus on coding, not configuration
- 🏢 **Teams** - Standardize development environments across your organization
- 🤖 **CI/CD Pipelines** - Safe, non-interactive mode for automated setups

## 🚀 Quick Start

Get up and running in **2 minutes**:

```bash
git clone https://github.com/26zl/MacOS_Basic_Setup.git
cd MacOS_Basic_Setup
./install.sh        # Installs shell setup and system package managers (Oh My Zsh, Homebrew, MacPorts, Nix, mas)
./dev-tools.sh      # Installs language version managers and language runtimes (optional)
source ~/.zshrc
```

**That's it!** You now have:

- ✅ Automated tool updates (`update` command)
- ✅ Support for multiple languages (Python via pyenv, Node.js via nvm, Ruby via chruby, Rust via rustup, Swift via swiftly, Go, Java, .NET)
- ✅ Beautiful terminal with Powerlevel10k theme
- ✅ Security recommendations and best practices
- ✅ Database status checks (MySQL, MongoDB, PostgreSQL)

**Note**: Language version managers (pyenv, nvm, chruby, rustup, swiftly) are not automatically installed. Run `./dev-tools.sh` to install them.

**Daily usage:**

```bash
update    # Update all tools, package managers, and runtimes
verify    # Check status of all installed tools
versions  # Display versions of all tools
```

## 🎯 Features

| Feature | Description |
| ------- | ----------- |
| 🔄 **One Command Updates** | Update Homebrew, MacPorts, Nix, mas, Python, Node.js, Ruby, Rust, Go, Swift, .NET with `update` |
| 🌍 **Multi-Language Support** | Python (pyenv), Node.js (nvm), Ruby (chruby), Rust (rustup), Swift (swiftly), Go, Java, .NET |
| 📦 **Package Managers** | Homebrew, MacPorts, Nix, mas (Mac App Store CLI), Conda, pipx, npm, gem, cargo |
| 🎨 **Beautiful Terminal** | Oh My Zsh with Powerlevel10k, syntax highlighting, autosuggestions |
| ⚡ **Performance Optimized** | Lazy loading and PATH cleanup for faster shell startup |
| 🛡️ **System Protection** | Automatically detects and protects macOS system Python/Ruby from modification |
| 🔧 **Permanent Configuration** | Go toolchain upgrades via Homebrew are made permanent via `.zprofile` |
| 🤖 **CI/Cron Safe** | Non-interactive mode support (`NONINTERACTIVE=1` or `CI=1`). Note: MacPorts requires sudo and will be skipped in CI |
| 🧠 **Smart Detection** | Automatically sources nvm and chruby shell functions for non-interactive shells |

## Installation

### Quick Install (Recommended)

The installation script handles everything automatically:

```bash
git clone https://github.com/26zl/MacOS_Basic_Setup.git
cd MacOS_Basic_Setup
./install.sh
source ~/.zshrc
```

**Security Note**: The installation scripts download external content. For maximum security, review the scripts before running:
- `install.sh`: Downloads Homebrew installer, Oh My Zsh installer, Powerlevel10k (via git), zsh plugins (via git), MacPorts source tarball, Nix installer
- `dev-tools.sh`: Downloads nvm installer, rustup installer, swiftly installer, Conda/Miniforge (via Homebrew), pipx (via Homebrew)

**Security Features**:
- ✅ Input validation in `_ask_user()` function (sanitizes and validates user input)
- ✅ Selective error handling (critical components fail fast, optional components continue)
- ✅ Safe directory navigation (uses saved paths instead of `cd -`)
- ✅ HTTPS-only downloads with TLS verification (`--proto '=https' --tlsv1.2`)
- ⚠️  Note: `eval` is used for pyenv/nvm initialization (standard practice, required for these tools)

**Requirements**: Xcode Command Line Tools (required - will be installed automatically if missing), Git (included with Xcode CLT)

**Installs**:

- **Required**: Xcode Command Line Tools, Git, Homebrew, Oh My Zsh, Powerlevel10k, ZSH plugins, maintain-system script, zsh config
- **Optional** (with interactive prompts): MacPorts, mas (Mac App Store CLI), Nix, FZF

**Note**: `install.sh` focuses on shell setup and system package managers. For language version managers and language runtimes, run `./dev-tools.sh` after installation.

### Development Tools Installation

After running `install.sh`, you can optionally install language development tools:

```bash
./dev-tools.sh          # Interactive installation
./dev-tools.sh check    # Check what would be installed (dry-run)
./dev-tools.sh test     # Test detection of all tools
```

**Testing**: Before installing, you can test if the script correctly detects your existing tools:
```bash
./dev-tools.sh test     # Shows which tools are detected
./dev-tools.sh check    # Shows what would be installed (without installing)
```

This script will prompt you to install:

**Language Package Managers:**
- Conda/Miniforge (Python package manager)
- pipx (isolated Python applications)

**Language Version Managers & Runtimes:**
- pyenv (Python version manager)
- nvm (Node.js version manager)
- chruby + ruby-install (Ruby version manager - requires ruby-install)
- rustup (Rust toolchain manager)
- swiftly (Swift toolchain manager)
- Go (via Homebrew or manual install)
- Java/OpenJDK (via Homebrew or manual install)
- .NET SDK (via Homebrew or manual install)

**Note**: Some tools require Homebrew to be installed first. The script will guide you through the installation process.

## Usage

After installation, you have three main commands:

```bash
update    # Update all tools, package managers, and language runtimes
verify    # Check status of all installed tools
versions  # Display versions of all tools
```

### What Gets Updated

**Package Managers:**

- Homebrew (packages, cleanup, doctor check) - skipped if not installed (install via `./install.sh`)
- MacPorts (ports tree, packages, cleanup) - can be installed from source via CLI in `install.sh`, skipped if not installed. **Note**: Requires sudo and will be skipped in CI/CD environments
- Nix (profile/env updates, store cleanup, CLI upgrade checks, compaudit fixes) - secure installation with `--proto '=https' --tlsv1.2`, skipped if not installed
- mas (Mac App Store apps) - updates App Store apps via [mas-cli](https://github.com/mas-cli/mas), uses per-user authentication (no sudo), skipped if not installed
- Conda/Miniforge (conda and packages) - skipped if not installed
- pipx (all installed packages) - skipped if not installed

**Languages & Version Managers:**

- 🐍 **Python** (pyenv) - upgrades to latest, removes old versions, updates pip/setuptools/wheel (skips for system/Homebrew Python)
- 📗 **Node.js** (nvm) - ensures latest LTS, removes old versions, updates global npm packages
- 💎 **Ruby** (chruby) - installs latest via ruby-install (requires ruby-install), removes old versions, updates gems (skips for system Ruby)
- 🦀 **Rust** (rustup) - updates toolchains, sets stable as default, updates components
- 🕊️ **Swift** (swiftly) - updates swiftly, installs/updates to latest stable release
- 🐹 **Go** - updates via Homebrew when brew-installed; otherwise shows latest release info and links
- ☕ **Java** - version detection (manual installation required)
- 🔷 **.NET** - updates SDK via Homebrew (if installed), updates workloads and global tools

**Global Packages:**

- npm global packages
- Cargo global packages
- Go global tools (from GOBIN/GOPATH/bin)
- Python global packages (for pyenv Python, skips pip/setuptools/wheel for Homebrew Python)
- RubyGems (for non-system Ruby)

**Important Notes:**

- System Python/Ruby are automatically detected and protected from modification
- Homebrew Python: pip/setuptools/wheel are managed by Homebrew (skipped), but user-installed pip packages are updated
- Go upgrades via Homebrew are made permanent (GOROOT and PATH written to `.zprofile`)
- Project-specific files (e.g., `go.mod`, `package.json`, `requirements.txt`, `Gemfile.lock`) are **not** updated - this is a system maintenance tool, not a project dependency manager
- **Global packages** (installed via `npm install -g`, `gem install`, `pip install --user`, etc.) are updated in your home directory - this is safe and expected
- If you run `update` in a project directory, it will **not** modify project files (e.g., `package.json`, `Gemfile.lock`) - only global/system packages are updated
- Database servers are detected and reported; this project does not install or upgrade databases for you

**Behavior**:

- `install.sh` focuses on shell setup and system package managers (Oh My Zsh, terminal config, maintain-system script, Homebrew, MacPorts, Nix, mas)
- `dev-tools.sh` installs language version managers and language runtimes (Conda, pipx, pyenv, nvm, chruby, rustup, swiftly, Go, Java, .NET)
- `update` gracefully skips missing tools and refers to `install.sh` for system package managers (Homebrew, MacPorts, Nix, mas)
- `verify` shows installation instructions: refers to `install.sh` for system package managers, `dev-tools.sh` for language tools
- Missing package managers and version managers are skipped
- MacPorts requires sudo and will be skipped in CI/CD environments (`CI=1` or `NONINTERACTIVE=1`)

### Configuration

Customize with environment variables:

- `MAINTAIN_SYSTEM_FIX_RUBY_GEMS=0` - Disable Ruby gem auto-fix
- `MAINTAIN_SYSTEM_CLEAN_PYENV=0` - Disable Python cleanup (keeps all versions)
- `MAINTAIN_SYSTEM_CLEAN_NVM=0` - Disable Node.js cleanup (keeps all versions)
- `MAINTAIN_SYSTEM_CLEAN_CHRUBY=0` - Disable Ruby cleanup (keeps all versions)
- `MAINTAIN_SYSTEM_PYENV_KEEP="3.11.8,3.10.14"` - Keep specific Python versions during cleanup
- `MAINTAIN_SYSTEM_NVM_KEEP="v18.19.1"` - Keep specific Node.js versions during cleanup
- `MAINTAIN_SYSTEM_CHRUBY_KEEP="ruby-3.4.6"` - Keep specific Ruby versions during cleanup
- `MAINTAIN_SYSTEM_SWIFT_SNAPSHOTS=1` - Enable Swift development snapshot updates (default: stable releases only)

## 📋 Supported Tools

### Package Managers

- 🍺 **Homebrew** - macOS package manager
- 📦 **MacPorts** - Alternative package manager (can be installed from source)
- ❄️ **Nix** - Functional package manager
- 🛒 **mas** - Mac App Store CLI
- 🐍 **Conda/Miniforge** - Python package manager
- 📦 **pipx** - Isolated Python applications

### Languages & Version Managers

- 🐍 **Python** (pyenv) - Multiple Python versions
- 📗 **Node.js** (nvm) - Node version management
- 💎 **Ruby** (chruby) - Ruby version management
- 🦀 **Rust** (rustup) - Rust toolchain manager
- 🕊️ **Swift** (swiftly) - Swift toolchain manager
- 🐹 **Go** - Go programming language
- ☕ **Java** - Java runtime detection
- 🔷 **.NET** - .NET SDK and tools

### Databases

- 🗄️ **MySQL** - Database server detection
- 🍃 **MongoDB** - NoSQL database detection
- 🐘 **PostgreSQL** - Relational database detection

### Other Tools

- 🐳 **Docker** - Container platform
- 🔨 **C/C++** - Via Xcode Command Line Tools

## 🎨 Terminal

The setup includes a beautiful terminal configuration with:

- **Oh My Zsh** - Framework for managing Zsh configuration
- **Powerlevel10k** - Fast and highly customizable prompt theme
- **Syntax Highlighting** - Real-time command syntax highlighting
- **Autosuggestions** - Suggests commands as you type based on history
- **FZF** - Fuzzy finder for command history and file navigation

### Ghostty Terminal Setup (Optional)

To get the exact same terminal design as shown in the preview:

1. Install Ghostty: `brew install --cask ghostty`
2. Create config directory: `mkdir -p ~/.config/ghostty`
3. Copy config: `cp "Ghostty config.txt" ~/.config/ghostty/config`
4. Copy background image: `cp background/terminal-background.png ~/.config/ghostty/terminal-background.png`

See `Ghostty config.txt` for the full configuration.

## ❓ FAQ

### Will this modify my project files?

No! This tool only updates **global/system packages**. Project-specific files (e.g., `package.json`, `go.mod`, `requirements.txt`) are never modified. It's a system maintenance tool, not a project dependency manager.

### Is it safe to run in CI/CD?

Yes! Set `NONINTERACTIVE=1` or `CI=1` to automatically skip all prompts and potentially destructive operations. The project is designed to be safe for automated runs.

### Does it work on both Intel and Apple Silicon?

Yes! The project automatically detects your Mac architecture and uses the correct paths (e.g., `/opt/homebrew` for Apple Silicon, `/usr/local` for Intel).

### What if I don't have Homebrew/MacPorts/Nix installed?

No problem! The `update` command gracefully skips missing tools and refers to `install.sh` for system package managers (Homebrew, MacPorts, Nix, mas) or `dev-tools.sh` for language tools (pyenv, nvm, chruby, rustup, swiftly, Go, Java, .NET).

### Can I customize the cleanup behavior?

Yes! Use environment variables like `MAINTAIN_SYSTEM_CLEAN_PYENV=0` to disable cleanup, or `MAINTAIN_SYSTEM_PYENV_KEEP="3.11.8"` to keep specific versions. See the [Configuration](#configuration) section for all options.

## 🤝 Contributing

Contributions are welcome! Before submitting a PR:

1. Run `./quick-test.sh` to verify syntax
2. Ensure ShellCheck passes
3. Verify no secrets are included
4. Test on both Intel and Apple Silicon Macs

**CI/CD**: ShellCheck, Gitleaks (secrets), Trivy (security), syntax checks, comprehensive macOS functionality tests. See `.github/workflows/` for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This is a personal setup configuration. Use at your own risk and always do your own research before applying system-wide changes.

---

**⭐ If this project helped you, please consider giving it a star! ⭐**

[![GitHub stars](https://img.shields.io/github/stars/26zl/MacOS_Basic_Setup?style=social&label=Star)](https://github.com/26zl/MacOS_Basic_Setup/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/26zl/MacOS_Basic_Setup?style=social&label=Fork)](https://github.com/26zl/MacOS_Basic_Setup/fork)

**Note**: This configuration works on both Intel and Apple Silicon Macs.

Made with ❤️ for the macOS developer community
