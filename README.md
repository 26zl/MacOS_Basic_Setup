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
- Multi-language support (Python, Node.js, Ruby, Rust, Go, Java)
- Beautiful terminal with Powerlevel10k theme
- Security tools and best practices
- Database support (MySQL, MongoDB, PostgreSQL)

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
- **Performance Optimized** - Lazy loading, efficient PATH management, smart caching

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

**Installs**: Homebrew, Oh My Zsh, Powerlevel10k, ZSH plugins, FZF, maintain-system script, zsh config

## Usage

After installation, you have three main commands:

```bash
update    # Update all tools, package managers, and language runtimes
verify    # Check status of all installed tools
versions  # Display versions of all tools
```

### Nix Maintenance (macOS)

Nix maintenance is integrated: `update` handles packages, store cleanup, CLI upgrades, and compaudit fixes. `verify` shows daemon status, packages, and flakes.

### Swift/Swiftly Support

Swift toolchain management via `swiftly`:
- Automatically detects and activates installed Swift versions (releases and snapshots)
- Updates to latest stable release by default
- Supports development snapshots when `MAINTAIN_SYSTEM_SWIFT_SNAPSHOTS=1` is set
- Snapshots are marked with `[snapshot]` in `verify` and `versions` output

### Prerequisites

`update` gracefully skips missing tools. Missing package managers (MacPorts, Nix, Conda, pipx) and version managers (pyenv, nvm, chruby, rustup, swiftly) are skipped. Homebrew will auto-install if missing (via `update` command). Go and Java require manual installation.

### Configuration

Customize with environment variables:
- `MAINTAIN_SYSTEM_GO_PROJECTS=1` - Update go.mod in current directory
- `MAINTAIN_SYSTEM_FIX_RUBY_GEMS=0` - Disable Ruby gem auto-fix
- `MAINTAIN_SYSTEM_CLEAN_PYENV=0` - Disable Python cleanup
- `MAINTAIN_SYSTEM_CLEAN_NVM=0` - Disable Node.js cleanup
- `MAINTAIN_SYSTEM_CLEAN_CHRUBY=0` - Disable Ruby cleanup
- `MAINTAIN_SYSTEM_PYENV_KEEP="3.11.8,3.10.14"` - Keep specific Python versions
- `MAINTAIN_SYSTEM_NVM_KEEP="v18.19.1"` - Keep specific Node.js versions
- `MAINTAIN_SYSTEM_CHRUBY_KEEP="ruby-3.4.6"` - Keep specific Ruby versions
- `MAINTAIN_SYSTEM_SWIFT_SNAPSHOTS=1` - Enable Swift development snapshot updates (default: stable releases only)

## Supported Tools

**Package Managers**: Homebrew, MacPorts, Nix, Conda/Miniforge, pipx  
**Languages**: Python (pyenv), Node.js (nvm), Ruby (chruby), Rust (rustup), Swift (swiftly), Go, Java  
**Databases**: MySQL, MongoDB, PostgreSQL  
**Other**: Docker, C/C++ (via Xcode)

## Terminal

Includes: Oh My Zsh, Powerlevel10k, syntax highlighting, autosuggestions, FZF. Optional Ghostty config included - see `Ghostty config.txt`.

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
