#!/usr/bin/env zsh

# macOS Development Environment Setup - Installation Script

# Don't exit on error - continue even if some optional components fail
set +e

echo "🚀 macOS Development Environment Setup - Installation"
echo "======================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
install_warnings=0

warn() {
  ((install_warnings++))
  echo "${YELLOW}⚠️  $1${NC}"
}

# Ask user for confirmation
_ask_user() {
  local prompt="$1"
  local default="${2:-N}"
  
  # Skip prompts in non-interactive mode
  if [[ -n "${NONINTERACTIVE:-}" ]] || [[ -n "${CI:-}" ]]; then
    return 1
  fi
  
  echo -n "$prompt "
  if [[ "$default" == "Y" ]]; then
    echo -n "[Y/n]: "
  else
    echo -n "[y/N]: "
  fi
  
  read -r response
  if [[ -z "$response" ]]; then
    response="$default"
  fi
  
  case "$response" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

# Check if running on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "${RED}❌ Error: This script is designed for macOS only${NC}"
  exit 1
fi

# Detect Homebrew installation prefix
_detect_brew_prefix() {
  if [[ -d /opt/homebrew ]]; then
    echo /opt/homebrew
  elif [[ -d /usr/local/Homebrew ]]; then
    echo /usr/local
  else
    echo ""
  fi
}

HOMEBREW_PREFIX="$(_detect_brew_prefix)"


# Function to install Xcode Command Line Tools (required)
install_xcode_clt() {
  # Check if Xcode Command Line Tools are installed
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "${YELLOW}⚠️  IMPORTANT: Xcode Command Line Tools are required${NC}"
    echo "  ${BLUE}INFO:${NC} Xcode Command Line Tools include essential development tools"
    echo "  ${BLUE}INFO:${NC} This includes: Git, clang, make, and other build tools"
    echo ""
    echo "  Installing Xcode Command Line Tools..."
    echo "  ${BLUE}INFO:${NC} A dialog will appear - please click 'Install' and wait for completion"
    echo ""
    
    if xcode-select --install 2>/dev/null; then
      echo "${GREEN}✅ Xcode Command Line Tools installation started${NC}"
      echo "${YELLOW}⚠️  Please complete the installation dialog and run this script again${NC}"
      echo "  ${BLUE}INFO:${NC} After installation completes, run: ./install.sh"
      exit 0
    else
      echo "${RED}❌ Failed to start Xcode Command Line Tools installation${NC}"
      echo "  ${BLUE}INFO:${NC} Please install manually: xcode-select --install"
      echo "  ${BLUE}INFO:${NC} Or download from: https://developer.apple.com/download/all/"
      exit 1
    fi
  else
    echo "${GREEN}✅ Xcode Command Line Tools already installed${NC}"
    local clt_path=$(xcode-select -p 2>/dev/null || echo "")
    if [[ -n "$clt_path" ]]; then
      echo "  ${BLUE}INFO:${NC} Installed at: $clt_path"
    fi
  fi
  
  # Verify Git is available (should be included in Xcode CLT)
  if ! command -v git >/dev/null 2>&1; then
    echo "${RED}❌ Git not found after Xcode Command Line Tools installation${NC}"
    echo "  ${BLUE}INFO:${NC} This should not happen - Git is included in Xcode CLT"
    echo "  ${BLUE}INFO:${NC} Please verify Xcode CLT installation: xcode-select -p"
    exit 1
  else
    echo "${GREEN}✅ Git found: $(git --version)${NC}"
  fi
}

# Function to install Homebrew if not present
install_homebrew() {
  if [[ -z "$HOMEBREW_PREFIX" ]]; then
    if _ask_user "${YELLOW}📦 Homebrew not found. Install Homebrew?" "Y"; then
      echo ""
      echo "${YELLOW}⚠️  IMPORTANT: Please follow the Homebrew installation carefully${NC}"
      echo "  ${BLUE}INFO:${NC} The installer may prompt you for:"
      echo "    - Your password (for sudo)"
      echo "    - Confirmation to install Xcode Command Line Tools (if not installed)"
      echo "    - Additional setup steps"
      echo ""
      echo "  ${BLUE}INFO:${NC} Please read all messages from the installer and follow instructions"
      echo "  ${BLUE}INFO:${NC} The installation process will be shown below:"
      echo ""
      echo "  Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      HOMEBREW_PREFIX="$(_detect_brew_prefix)"
      if [[ -n "$HOMEBREW_PREFIX" ]]; then
        echo ""
        echo "${GREEN}✅ Homebrew installed successfully${NC}"
      else
        echo ""
        echo "${RED}❌ Failed to install Homebrew${NC}"
        exit 1
      fi
    else
      echo "${YELLOW}⚠️  Skipping Homebrew installation${NC}"
      echo "  ${BLUE}INFO:${NC} You can install it later by running: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
  else
    echo "${GREEN}✅ Homebrew found at: $HOMEBREW_PREFIX${NC}"
  fi
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "${YELLOW}📦 Installing Oh My Zsh...${NC}"
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
      echo "${GREEN}✅ Oh My Zsh installed${NC}"
    else
      warn "Oh My Zsh installation failed"
    fi
  else
    echo "${GREEN}✅ Oh My Zsh already installed${NC}"
  fi
}

# Function to install Powerlevel10k theme
install_powerlevel10k() {
  local p10k_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [[ ! -d "$p10k_dir" ]]; then
    echo "${YELLOW}📦 Installing Powerlevel10k theme...${NC}"
    if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"; then
      echo "${GREEN}✅ Powerlevel10k installed${NC}"
    else
      warn "Powerlevel10k installation failed"
    fi
  else
    echo "${GREEN}✅ Powerlevel10k already installed${NC}"
  fi
}

# Function to install ZSH plugins
install_zsh_plugins() {
  local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
  
  # zsh-syntax-highlighting
  if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
    echo "${YELLOW}📦 Installing zsh-syntax-highlighting...${NC}"
    if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"; then
      echo "${GREEN}✅ zsh-syntax-highlighting installed${NC}"
    else
      warn "zsh-syntax-highlighting installation failed"
    fi
  else
    echo "${GREEN}✅ zsh-syntax-highlighting already installed${NC}"
  fi
  
  # zsh-autosuggestions
  if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
    echo "${YELLOW}📦 Installing zsh-autosuggestions...${NC}"
    if git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugins_dir/zsh-autosuggestions"; then
      echo "${GREEN}✅ zsh-autosuggestions installed${NC}"
    else
      warn "zsh-autosuggestions installation failed"
    fi
  else
    echo "${GREEN}✅ zsh-autosuggestions already installed${NC}"
  fi
}

# Function to install FZF
install_fzf() {
  if ! command -v fzf >/dev/null 2>&1; then
    if [[ -n "$HOMEBREW_PREFIX" ]]; then
      echo "${YELLOW}📦 Installing FZF via Homebrew...${NC}"
      if "$HOMEBREW_PREFIX/bin/brew" install fzf; then
        echo "${GREEN}✅ FZF installed${NC}"
      else
        warn "FZF installation failed (try: brew install fzf)"
      fi
    else
      warn "FZF not found. Install it manually: brew install fzf"
    fi
  else
    echo "${GREEN}✅ FZF already installed${NC}"
  fi
}

# Function to install mas (Mac App Store CLI)
install_mas() {
  if ! command -v mas >/dev/null 2>&1; then
    if [[ -n "$HOMEBREW_PREFIX" ]] && command -v brew >/dev/null 2>&1; then
      if _ask_user "${YELLOW}📦 mas (Mac App Store CLI) not found. Install mas via Homebrew?" "Y"; then
        echo "  Installing mas via Homebrew..."
        if "$HOMEBREW_PREFIX/bin/brew" install mas; then
          echo "${GREEN}✅ mas installed${NC}"
          echo "  ${BLUE}INFO:${NC} Sign in to App Store to use mas: open -a 'App Store'"
        else
          warn "mas installation failed (try: brew install mas)"
        fi
      else
        echo "${YELLOW}⚠️  Skipping mas installation${NC}"
      fi
    else
      if [[ -z "$HOMEBREW_PREFIX" ]]; then
        echo "${YELLOW}⚠️  mas requires Homebrew. Install Homebrew first.${NC}"
      else
        warn "mas not found. Install it manually: brew install mas"
      fi
    fi
  else
    echo "${GREEN}✅ mas already installed${NC}"
  fi
}

# Function to install MacPorts
install_macports() {
  if ! command -v port >/dev/null 2>&1; then
    if _ask_user "${YELLOW}📦 MacPorts not found. Install MacPorts?" "N"; then
      echo ""
      echo "${YELLOW}⚠️  IMPORTANT: Please follow the MacPorts installation carefully${NC}"
      echo "  ${BLUE}INFO:${NC} This will install MacPorts from source via CLI"
      echo "  ${BLUE}INFO:${NC} The installation may prompt you for:"
      echo "    - Your password (for sudo)"
      echo "    - Confirmation to install Xcode Command Line Tools (if not installed)"
      echo "    - Agreement to Xcode license (if Xcode is installed)"
      echo ""
      echo "  ${BLUE}INFO:${NC} Please read all messages and follow instructions carefully"
      echo "  ${BLUE}INFO:${NC} The installation process will be shown below:"
      echo ""
      
      # Check for Xcode Command Line Tools (should already be installed, but verify)
      if ! xcode-select -p >/dev/null 2>&1; then
        echo "  ${RED}❌ Xcode Command Line Tools are required for MacPorts${NC}"
        echo "  ${BLUE}INFO:${NC} Xcode CLT should have been installed earlier in the installation process"
        echo "  ${BLUE}INFO:${NC} Please run: xcode-select --install"
        echo "  ${BLUE}INFO:${NC} Then run this script again to continue with MacPorts installation"
        return 1
      else
        echo "  ${GREEN}✅ Xcode Command Line Tools found${NC}"
      fi
      
      # Agree to Xcode license if needed
      if command -v xcodebuild >/dev/null 2>&1; then
        echo "  Checking Xcode license agreement..."
        if ! sudo xcodebuild -license check >/dev/null 2>&1; then
          echo "  ${YELLOW}⚠️  Xcode license agreement required${NC}"
          echo "  ${BLUE}INFO:${NC} You may be prompted to accept the license"
          sudo xcodebuild -license accept 2>/dev/null || {
            echo "  ${YELLOW}⚠️  License acceptance may require manual confirmation${NC}"
          }
        fi
      fi
      
      # Get latest MacPorts version
      echo "  Fetching latest MacPorts version..."
      local macports_version="2.11.6"  # Default fallback
      local latest_url
      latest_url=$(curl -s https://distfiles.macports.org/MacPorts/ | grep -oE 'MacPorts-[0-9]+\.[0-9]+\.[0-9]+\.tar\.bz2' | sort -V | tail -1 || echo "")
      if [[ -n "$latest_url" ]]; then
        macports_version=$(echo "$latest_url" | sed 's/MacPorts-\(.*\)\.tar\.bz2/\1/')
      fi
      
      local macports_tarball="MacPorts-${macports_version}.tar.bz2"
      local macports_url="https://distfiles.macports.org/MacPorts/${macports_tarball}"
      local temp_dir=$(mktemp -d)
      
      echo "  Installing MacPorts ${macports_version} from source..."
      echo "  Downloading ${macports_tarball}..."
      
      cd "$temp_dir" || {
        echo "  ${RED}❌ Failed to create temporary directory${NC}"
        return 1
      }
      
      if curl -fsSL -o "$macports_tarball" "$macports_url"; then
        echo "  Extracting source code..."
        if tar xf "$macports_tarball"; then
          cd "MacPorts-${macports_version}" || {
            echo "  ${RED}❌ Failed to navigate to source directory${NC}"
            cd - >/dev/null || true
            rm -rf "$temp_dir"
            return 1
          }
          
          echo "  Configuring MacPorts..."
          if ./configure; then
            echo "  Building MacPorts (this may take a while)..."
            if make; then
              echo "  Installing MacPorts (requires sudo)..."
              if sudo make install; then
                echo ""
                echo "${GREEN}✅ MacPorts installed successfully${NC}"
                echo "  ${BLUE}INFO:${NC} Please open a new terminal window for PATH changes to take effect"
                echo "  ${BLUE}INFO:${NC} Then run: sudo port selfupdate"
              else
                echo "  ${RED}❌ MacPorts installation failed (make install)${NC}"
                cd - >/dev/null || true
                rm -rf "$temp_dir"
                return 1
              fi
            else
              echo "  ${RED}❌ MacPorts build failed (make)${NC}"
              cd - >/dev/null || true
              rm -rf "$temp_dir"
              return 1
            fi
          else
            echo "  ${RED}❌ MacPorts configuration failed (configure)${NC}"
            cd - >/dev/null || true
            rm -rf "$temp_dir"
            return 1
          fi
        else
          echo "  ${RED}❌ Failed to extract MacPorts source${NC}"
          rm -rf "$temp_dir"
          return 1
        fi
      else
        echo "  ${RED}❌ Failed to download MacPorts source${NC}"
        echo "  ${BLUE}INFO:${NC} Visit: https://www.macports.org/install.php for manual installation"
        rm -rf "$temp_dir"
        return 1
      fi
      
      # Cleanup
      cd - >/dev/null || true
      rm -rf "$temp_dir"
    else
      echo "${YELLOW}⚠️  Skipping MacPorts installation${NC}"
    fi
  else
    echo "${GREEN}✅ MacPorts already installed${NC}"
  fi
}

# Function to install Nix
install_nix() {
  if ! command -v nix >/dev/null 2>&1 && ! [[ -d /nix ]] && ! [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
    if _ask_user "${YELLOW}📦 Nix not found. Install Nix?" "N"; then
      echo ""
      echo "${YELLOW}⚠️  IMPORTANT: Please follow the Nix installation carefully${NC}"
      echo "  ${BLUE}INFO:${NC} The installer may prompt you for:"
      echo "    - Your password (for sudo)"
      echo "    - Confirmation to create /nix directory"
      echo "    - Additional setup steps"
      echo ""
      echo "  ${BLUE}INFO:${NC} Please read all messages from the installer and follow instructions"
      echo "  ${BLUE}INFO:${NC} The installation process will be shown below:"
      echo ""
      echo "  Installing Nix..."
      echo "  ${BLUE}INFO:${NC} This will run the official Nix installer"
      echo ""
      if sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon; then
        echo ""
        echo "${GREEN}✅ Nix installed successfully${NC}"
        echo "  ${BLUE}INFO:${NC} Restart your terminal or run: source ~/.zprofile"
        echo "  ${BLUE}INFO:${NC} Then run: ./scripts/nix-macos-maintenance.sh ensure-path"
      else
        echo ""
        echo "${RED}❌ Nix installation failed${NC}"
        echo "  ${BLUE}INFO:${NC} Visit: https://nixos.org/download.html for manual installation"
        echo "  ${BLUE}INFO:${NC} If installation was interrupted, you may need to clean up before retrying"
      fi
    else
      echo "${YELLOW}⚠️  Skipping Nix installation${NC}"
    fi
  else
    if [[ -d /nix ]] || [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
      echo "${GREEN}✅ Nix detected (may need PATH setup)${NC}"
    else
      echo "${GREEN}✅ Nix already installed${NC}"
    fi
  fi
}

# Function to setup maintain-system script
setup_maintain_system() {
  local local_bin="${XDG_DATA_HOME:-$HOME/.local/share}/../bin"
  [[ -d "$local_bin" ]] || local_bin="$HOME/.local/bin"
  
  echo "${YELLOW}📦 Setting up maintain-system script...${NC}"
  mkdir -p "$local_bin"
  
  # Get the directory where this script is located
  local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
  
  if [[ -f "$script_dir/maintain-system.sh" ]]; then
    cp "$script_dir/maintain-system.sh" "$local_bin/maintain-system"
    chmod +x "$local_bin/maintain-system"
    
    # Verify installation
    if [[ -x "$local_bin/maintain-system" ]]; then
      # Normalize path for display (remove ../ if present)
      local display_path="$local_bin/maintain-system"
      [[ "$display_path" == *"/../"* ]] && display_path="$(cd "$local_bin" && pwd)/maintain-system"
      echo "${GREEN}✅ maintain-system script installed to $display_path${NC}"
    else
      echo "${RED}❌ Error: maintain-system was copied but is not executable${NC}"
      exit 1
    fi
  else
    echo "${RED}❌ Error: maintain-system.sh not found in $script_dir${NC}"
    echo "  Looking for: $script_dir/maintain-system.sh"
    echo "  Current directory: $(pwd)"
    ls -la "$script_dir/" | head -10 || true
    exit 1
  fi
}

# Function to setup Nix PATH
setup_nix_path() {
  # Check if Nix is installed
  if [[ -d /nix ]] && [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
    echo "${YELLOW}📦 Setting up Nix PATH...${NC}"
    
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    
    if [[ -f "$script_dir/scripts/nix-macos-maintenance.sh" ]]; then
      if "$script_dir/scripts/nix-macos-maintenance.sh" ensure-path >/dev/null 2>&1; then
        echo "${GREEN}✅ Nix PATH configured${NC}"
      else
        warn "Nix PATH setup had issues (run manually: ./scripts/nix-macos-maintenance.sh ensure-path)"
      fi
    else
      warn "Nix maintenance script not found (Nix PATH may need manual setup)"
    fi
  else
    echo "${YELLOW}ℹ️  Nix not detected - skipping Nix PATH setup${NC}"
  fi
}

# Function to setup PATH cleanup in .zprofile
setup_zprofile_path_cleanup() {
  if [[ -z "$HOMEBREW_PREFIX" ]]; then
    return 0  # No Homebrew, skip
  fi
  
  echo "${YELLOW}📦 Setting up PATH cleanup in .zprofile...${NC}"
  
  # Check if PATH cleanup already exists
  if [[ -f "$HOME/.zprofile" ]] && grep -q "FINAL PATH CLEANUP (FOR .ZPROFILE)" "$HOME/.zprofile"; then
    echo "${GREEN}✅ PATH cleanup already configured in .zprofile${NC}"
    return 0
  fi
  
  # Backup .zprofile if it exists
  if [[ -f "$HOME/.zprofile" ]]; then
    local zprofile_backup="$HOME/.zprofile.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$HOME/.zprofile" "$zprofile_backup"
  fi
  
  # Append PATH cleanup to .zprofile
  cat >> "$HOME/.zprofile" << 'ZPROFILE_EOF'

# ================================ FINAL PATH CLEANUP (FOR .ZPROFILE) =======================
# This must be at the very end of .zprofile to fix PATH order after all tools have loaded
# Ensures Homebrew paths come before /usr/bin and ~/.local/bin is included
# Managed by macOS Development Environment Setup
_detect_brew_prefix() {
  if [[ -d /opt/homebrew ]]; then
    echo /opt/homebrew
  elif [[ -d /usr/local/Homebrew ]]; then
    echo /usr/local
  else
    echo ""
  fi
}

# Ensure ~/.local/bin (or XDG_DATA_HOME/../bin) is in PATH
local_bin="${XDG_DATA_HOME:-$HOME/.local/share}/../bin"
[[ -d "$local_bin" ]] || local_bin="$HOME/.local/bin"

HOMEBREW_PREFIX="$(_detect_brew_prefix)"
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  # Remove Homebrew paths from current PATH temporarily
  # Suppress all output to avoid Powerlevel10k instant prompt warnings
  # Use command grouping to avoid variable output
  {
    cleaned_path=$(echo "$PATH" | tr ':' '\n' | grep -v "^$HOMEBREW_PREFIX/bin$" | grep -v "^$HOMEBREW_PREFIX/sbin$" | grep -v "^$local_bin$" | tr '\n' ':' | sed 's/:$//' 2>/dev/null)
    # Rebuild PATH with Homebrew first, then ~/.local/bin, then others, then system paths
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$local_bin:$cleaned_path"
  } >/dev/null 2>&1
else
  # No Homebrew, just ensure ~/.local/bin is in PATH
  {
    case ":$PATH:" in
      *":$local_bin:"*) ;;
      *) export PATH="$local_bin:$PATH" ;;
    esac
  } >/dev/null 2>&1
fi
ZPROFILE_EOF

  echo "${GREEN}✅ PATH cleanup configured in .zprofile${NC}"
}

# Function to backup and install zsh config
install_zsh_config() {
  local zshrc_backup="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
  
  if [[ -f "$HOME/.zshrc" ]]; then
    echo "${YELLOW}📦 Backing up existing .zshrc to $zshrc_backup...${NC}"
    cp "$HOME/.zshrc" "$zshrc_backup"
    echo "${GREEN}✅ Backup created${NC}"
  fi
  
  # Get the directory where this script is located
  local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
  
  if [[ -f "$script_dir/zsh.sh" ]]; then
    echo "${YELLOW}📦 Installing zsh configuration...${NC}"
    cp "$script_dir/zsh.sh" "$HOME/.zshrc"
    echo "${GREEN}✅ zsh configuration installed${NC}"
  else
    echo "${RED}❌ Error: zsh.sh not found in $script_dir${NC}"
    exit 1
  fi
}

# Main installation
main() {
  echo ""
  echo "Starting installation..."
  echo ""
  
  # Install Xcode Command Line Tools (required - includes Git)
  install_xcode_clt
  
  # Install Homebrew if needed
  install_homebrew
  
  # Install Oh My Zsh
  install_oh_my_zsh
  
  # Install Powerlevel10k theme
  install_powerlevel10k
  
  # Install ZSH plugins
  install_zsh_plugins
  
  # Install FZF
  install_fzf
  
  # Install mas (Mac App Store CLI)
  install_mas
  
  # Install MacPorts (optional)
  install_macports
  
  # Install Nix (optional)
  install_nix
  
  # Setup maintain-system script
  setup_maintain_system
  
  # Setup Nix PATH (if Nix is installed)
  setup_nix_path
  
  # Setup PATH cleanup in .zprofile (ensures Homebrew comes before /usr/bin)
  setup_zprofile_path_cleanup
  
  # Install zsh config
  install_zsh_config
  
  echo ""
  if [[ $install_warnings -gt 0 ]]; then
    echo "${YELLOW}⚠️  Installation completed with $install_warnings warning(s)${NC}"
  else
    echo "${GREEN}✅ Installation complete!${NC}"
  fi
  echo ""
  echo "Next steps:"
  echo "  1. Restart your terminal or run: source ~/.zshrc"
  echo "  2. Run 'p10k configure' to customize your Powerlevel10k theme (optional)"
  echo "  3. Run 'update' to update all your tools"
  echo ""
  echo "Available commands:"
  echo "  - update    : Update all tools, package managers, and language runtimes"
  echo "  - verify    : Check status of all installed tools"
  echo "  - versions  : Display versions of all tools"
  echo ""
}

# Run main function
main
