# 🚀 macOS Development Environment Setup

[![Checks](https://github.com/26zl/MacOS_Basic_Setup/workflows/Checks/badge.svg)](https://github.com/26zl/MacOS_Basic_Setup/actions)
[![Security Scan](https://github.com/26zl/MacOS_Basic_Setup/workflows/Security%20Scan/badge.svg)](https://github.com/26zl/MacOS_Basic_Setup/actions)
[![macOS Test](https://github.com/26zl/MacOS_Basic_Setup/workflows/macOS%20Test/badge.svg)](https://github.com/26zl/MacOS_Basic_Setup/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**One-command setup** for a complete macOS development environment with automated tool management.

![Terminal preview](background/image.png)

## 🚀 Quick Start

```bash
git clone https://github.com/26zl/MacOS_Basic_Setup.git
cd MacOS_Basic_Setup
./install.sh        # Installs shell setup and system package managers
./dev-tools.sh      # Installs language tools (optional)
source ~/.zshrc
```

**Daily usage:**

```bash
update    # Update all tools
verify    # Check status
versions  # Show versions
```

## ✨ Features

- ⚡ **One Command Updates**: Update Homebrew, Python, Node.js, Ruby, Rust, Go, Swift, .NET, and more
- 🎨 **Beautiful Terminal**: Powerlevel10k, syntax highlighting, autosuggestions
- 🛡️ **Safe & Smart**: Protects system files, graceful error handling
- 📦 **Multi-Language**: Python (pyenv), Node.js (nvm), Ruby (chruby), Rust (rustup), Swift (swiftly), Go, Java, .NET
- 🤖 **CI/CD Safe**: Non-interactive mode support

## Installation

### Basic Setup

```bash
./install.sh
source ~/.zshrc
```

**Installs**: Xcode CLT, Git, Homebrew, Oh My Zsh, Powerlevel10k, ZSH plugins, maintain-system script

**Optional**: MacPorts, mas, Nix, FZF (interactive prompts)

### Development Tools

```bash
./dev-tools.sh          # Interactive installation
./dev-tools.sh check    # Dry-run
./dev-tools.sh test     # Test detection
```

**Installs**: Conda, pipx, pyenv, nvm, chruby, rustup, swiftly, Go, Java, .NET

## Usage

### Commands

- `update` - Update all tools, package managers, and language runtimes
- `verify` - Check status of all installed tools
- `versions` - Display versions of all tools

### What Gets Updated

**Package Managers**: Homebrew, MacPorts, Nix, mas, Conda, pipx

**Languages**: Python (pyenv), Node.js (nvm), Ruby (chruby), Rust (rustup), Swift (swiftly), Go, Java, .NET

**Global Packages**: npm, Cargo, Go tools, Python packages, RubyGems

**Note**: Only global/system packages are updated. Project files (`package.json`, `go.mod`, etc.) are never modified.

### Configuration

Environment variables:

- `MAINTAIN_SYSTEM_CLEAN_PYENV=0` - Disable Python cleanup
- `MAINTAIN_SYSTEM_CLEAN_NVM=0` - Disable Node.js cleanup
- `MAINTAIN_SYSTEM_CLEAN_CHRUBY=0` - Disable Ruby cleanup
- `MAINTAIN_SYSTEM_PYENV_KEEP="3.11.8,3.10.14"` - Keep specific Python versions
- `MAINTAIN_SYSTEM_NVM_KEEP="v18.19.1"` - Keep specific Node.js versions
- `MAINTAIN_SYSTEM_CHRUBY_KEEP="ruby-3.4.6"` - Keep specific Ruby versions
- `MAINTAIN_SYSTEM_SWIFT_SNAPSHOTS=1` - Enable Swift snapshots

## 📋 Supported Tools

**Package Managers**: Homebrew, MacPorts, Nix, mas, Conda, pipx

**Languages**: Python (pyenv), Node.js (nvm), Ruby (chruby), Rust (rustup), Swift (swiftly), Go, Java, .NET

**Databases**: MySQL, MongoDB, PostgreSQL (detection only)

**Other**: Docker, C/C++ (via Xcode CLT)

## 🎨 Terminal

Pre-configured with Oh My Zsh, Powerlevel10k, syntax highlighting, autosuggestions, and FZF.

### Ghostty Setup (Optional)

```bash
brew install --cask ghostty
mkdir -p ~/.config/ghostty
cp "Ghostty config.txt" ~/.config/ghostty/config
cp background/terminal-background.png ~/.config/ghostty/terminal-background.png
```

## ❓ FAQ

**Will this modify my project files?**  
No! Only global/system packages are updated. Project files are never modified.

**Is it safe for CI/CD?**  
Yes! Set `NONINTERACTIVE=1` or `CI=1` for automated runs.

**Does it work on Intel and Apple Silicon?**  
Yes! Automatically detects architecture.

**What if tools are missing?**  
The `update` command gracefully skips missing tools and shows installation instructions.

## Security

**Security Features**:

- ✅ Input validation and sanitization
- ✅ Selective error handling
- ✅ Safe directory navigation
- ✅ HTTPS-only downloads with TLS verification

**Note**: Scripts download external content. Review scripts before running for maximum security.

## 🤝 Contributing

1. Run `./quick-test.sh` to verify syntax
2. Ensure ShellCheck passes
3. Test on both Intel and Apple Silicon Macs

**CI/CD**: ShellCheck, Gitleaks, Trivy, syntax checks, comprehensive macOS tests.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

### ⭐ If this project helped you, please consider giving it a star! ⭐

[![GitHub stars](https://img.shields.io/github/stars/26zl/MacOS_Basic_Setup?style=social&label=Star)](https://github.com/26zl/MacOS_Basic_Setup/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/26zl/MacOS_Basic_Setup?style=social&label=Fork)](https://github.com/26zl/MacOS_Basic_Setup/fork)

Made with ❤️ for the macOS developer community
