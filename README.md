# macOS Development Environment Setup

[![CI](https://github.com/26zl/MacOS_Basic_Setup/workflows/CI/badge.svg)](https://github.com/26zl/MacOS_Basic_Setup/actions)
[![Security Scan](https://github.com/26zl/MacOS_Basic_Setup/workflows/Security%20Scan/badge.svg)](https://github.com/26zl/MacOS_Basic_Setup/actions)
[![macOS Test](https://github.com/26zl/MacOS_Basic_Setup/workflows/macOS%20Test/badge.svg)](https://github.com/26zl/MacOS_Basic_Setup/actions)

> **One-command setup** for a complete macOS development environment with automated tool management, security best practices, and a beautiful terminal experience.

![Terminal preview](background/image.png)

## Quick Start

Get up and running in 2 minutes:

```bash
git clone https://github.com/26zl/MacOS_Basic_Setup.git
cd MacOS_Basic_Setup
./install.sh
source ~/.zshrc
```

That's it! You now have:

- Automated tool updates (`update` command)
- Multi-language support (Python, Node.js, Ruby, Rust, Go, Swift, Java)
- Beautiful terminal with Powerlevel10k theme
- Security recommendations and best practices
- Database status checks (MySQL, MongoDB, PostgreSQL)

**Daily usage:**

```bash
update    # Update all tools, package managers, and runtimes
verify    # Check status of all installed tools
versions  # Display versions of all tools
```

## Features

- **One Command Updates** - Update Homebrew, MacPorts, Nix, Python, Node.js, Ruby, Rust, Go, Swift with `update`
- **Multi-Language Support** - Python (pyenv), Node.js (nvm), Ruby (chruby), Rust (rustup), Swift (swiftly), Go, Java
- **Package Managers** - Homebrew, MacPorts, Nix, Conda, pipx, npm, gem, cargo
- **Beautiful Terminal** - Oh My Zsh with Powerlevel10k, syntax highlighting, autosuggestions
- **Performance Optimized** - Lazy loading and PATH cleanup for faster shell startup
- **System Protection** - Automatically detects and protects macOS system Python/Ruby from modification
- **Permanent Configuration** - Go toolchain upgrades via Homebrew are made permanent via `.zprofile`

## Installation

### Quick Install (Recommended)

The installation script handles everything automatically:

```bash
git clone https://github.com/26zl/MacOS_Basic_Setup.git
cd MacOS_Basic_Setup
./install.sh
source ~/.zshrc
```

**Security Note**: The installation script downloads external scripts (Homebrew, Oh My Zsh). For maximum security, review `install.sh` before running or install manually.

**Installs**: Homebrew (if missing), Git (if missing), Oh My Zsh, Powerlevel10k, ZSH plugins, FZF, maintain-system script, zsh config

## Usage

After installation, you have three main commands:

```bash
update    # Update all tools, package managers, and language runtimes
verify    # Check status of all installed tools
versions  # Display versions of all tools
```

### What Gets Updated

**Package Managers:**

- Homebrew (packages, cleanup, doctor check) - auto-installs if missing
- MacPorts (ports tree, packages, cleanup)
- Nix (profile/env updates, store cleanup, CLI upgrade checks, compaudit fixes)
- Conda/Miniforge (conda and packages)
- pipx (all installed packages)

**Languages & Version Managers:**

- Python (pyenv) - upgrades to latest, removes old versions, updates pip/setuptools/wheel (skips for system/Homebrew Python)
- Node.js (nvm) - ensures latest LTS, removes old versions, updates global npm packages
- Ruby (chruby) - installs latest, removes old versions, updates gems (skips for system Ruby)
- Rust (rustup) - updates toolchains, sets stable as default, updates components
- Swift (swiftly) - updates swiftly, installs/updates to latest stable release
- Go - updates via Homebrew when brew-installed; otherwise shows latest release info and links
- Java - version detection (manual installation required)

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
- Project-specific files (e.g., `go.mod`, `package.json`, `requirements.txt`) are **not** updated - this is a system maintenance tool, not a project dependency manager
- Database servers are detected and reported; this project does not install or upgrade databases for you

### Nix Maintenance (macOS)

Nix maintenance is integrated: `update` handles profile/env updates, store cleanup, CLI upgrade checks (manual command), and compaudit fixes. `verify` shows daemon status (running/stopped). `versions` shows package counts.

### Prerequisites

`update` gracefully skips missing tools. Missing package managers (MacPorts, Nix, Conda, pipx) and version managers (pyenv, nvm, chruby, rustup, swiftly) are skipped. Homebrew and Git are auto-installed by `install.sh` if missing. Homebrew will also auto-install if missing when running `update`. Go and Java require manual installation.

### File Paths

All file paths follow standard public installation locations with fallback mechanisms:

- **System paths**: `/usr/bin`, `/usr/sbin`, `/bin`, `/sbin`, `/usr/libexec` (standard macOS)
- **Homebrew**: Dynamically detected via `_detect_brew_prefix()` (`/opt/homebrew` for Apple Silicon, `/usr/local` for Intel)
- **Nix**: Standard paths (`/nix`, `/nix/var/nix/profiles/default/bin/nix`)
- **Tools with fallbacks**: MySQL (`/usr/local/mysql`, Homebrew), Conda (`/usr/local/miniforge3`, `$HOME/miniforge3`, Homebrew), chruby (`/usr/local/share/chruby`, Homebrew, `$HOME/.local/share/chruby`), OpenJDK (Homebrew, `/usr/libexec/java_home`)

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

## Supported Tools

**Package Managers**: Homebrew, MacPorts, Nix, Conda/Miniforge, pipx

**Languages**: Python (pyenv), Node.js (nvm), Ruby (chruby), Rust (rustup), Swift (swiftly), Go, Java

**Databases**: MySQL, MongoDB, PostgreSQL

**Other**: Docker, C/C++ (via Xcode)

## Terminal

Includes: Oh My Zsh, Powerlevel10k, syntax highlighting, autosuggestions, FZF.

### Ghostty Terminal Setup

To get the exact same terminal design as shown in the preview:

1. **Install Ghostty** (if not already installed):

   ```bash
   brew install --cask ghostty
   ```

2. **Copy the configuration file**:

   ```bash
   cp "Ghostty config.txt" ~/.config/ghostty/config
   ```

3. **Set up the background image**:
   - Place the background image from `background/image.png` in a location of your choice (e.g., `~/Pictures/terminal-bg.png`)
   - Update the `background-image` path in `~/.config/ghostty/config` to point to your image location
   - Or simply copy the entire `background/` directory and reference it from the config

The Ghostty config includes:

- Dark theme with custom colors
- Background image support
- Optimized font settings
- Custom window behavior

See `Ghostty config.txt` for the full configuration.

## Security

Recommended tools: [Objective-See](https://objective-see.org/tools.html) (Lulu, KnockKnock, Dylib Scanner, Oversight). Guides: [macOS Security Guide](https://github.com/drduh/macOS-Security-and-Privacy-Guide), [Privacy Guide](https://anonymousplanet.org/guide/).

## Useful Tools

**Cybersecurity Tools**: Install via Homebrew/MacPorts/Nix for easy maintenance. For Python tools, use `pipx` instead of `pip` for isolation.

**Virtualization**: VMware Fusion Professional 25H2, UTM

**System Cleanup**: [Mole](https://github.com/tw93/Mole) (`brew install mole`) - deep clean, app uninstaller, disk analyzer

**Utilities**: [Pearcleaner](https://github.com/alienator88/Pearcleaner), [Keka](https://github.com/aonez/Keka), [Maccy](https://github.com/p0deje/Maccy), [Ice](https://github.com/jordanbaird/Ice), [BetterDisplay](https://github.com/waydabber/BetterDisplay)

**System Cleanup Tips** (use with caution):

- Clear cache: `~/Library/Caches`
- Clear logs: `/var/log` (safer: `sudo log collect --last 1d`)
- Remove languages: `/Library/Languages` (keep primary + English)

## Tips

**macOS**: `Cmd + Space` (Spotlight), `Cmd + Shift + .` (show hidden files), `Ctrl + R` (history search), `Cmd + K` (clear terminal)

**Development**: Use FZF for navigation, virtual environments for Python, `nvm` for Node.js versions

**Maintenance**: Run `update` weekly, use `df -h` or Mole for disk space, run `p10k configure` to customize prompt

**Troubleshooting**: Check PATH with `echo $PATH`, run `update` to fix broken symlinks

## Requirements

macOS (Intel or Apple Silicon), Zsh, internet connection. Homebrew and Git are auto-installed by `install.sh` if missing. Homebrew will also auto-install if missing when running `update`.

## Testing

```bash
./quick-test.sh  # Quick syntax test
./install.sh     # Full test (backup ~/.zshrc first!)
```

## Contributing

Contributions welcome! Before submitting a PR: run `./quick-test.sh`, ensure ShellCheck passes, verify no secrets, test on Intel and Apple Silicon.

**CI/CD**: ShellCheck, Gitleaks (secrets), Trivy (security), syntax checks, macOS functionality tests. See `.github/workflows/` for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This is a personal setup configuration. Use at your own risk and always do your own research before applying system-wide changes.

---

**Note**: This configuration works on both Intel and Apple Silicon Macs.
