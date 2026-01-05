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


# Function to install Homebrew if not present
install_homebrew() {
  if [[ -z "$HOMEBREW_PREFIX" ]]; then
    echo "${YELLOW}📦 Homebrew not found. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    HOMEBREW_PREFIX="$(_detect_brew_prefix)"
    if [[ -n "$HOMEBREW_PREFIX" ]]; then
      echo "${GREEN}✅ Homebrew installed successfully${NC}"
    else
      echo "${RED}❌ Failed to install Homebrew${NC}"
      exit 1
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
        # Normalize path for display (remove ../ if present)
        local display_path="$local_bin/maintain-system"
        [[ "$display_path" == *"/../"* ]] && display_path="$(cd "$local_bin" && pwd)/maintain-system"
        echo "${GREEN}✅ maintain-system script installed to $display_path${NC}"
  else
    echo "${RED}❌ Error: maintain-system.sh not found in $script_dir${NC}"
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
# Ensures Homebrew paths come before /usr/bin
# Managed by macOS Development Environment Setup
_detect_brew_prefix_zprofile() {
  if [[ -d /opt/homebrew ]]; then
    echo /opt/homebrew
  elif [[ -d /usr/local/Homebrew ]]; then
    echo /usr/local
  else
    echo ""
  fi
}

HOMEBREW_PREFIX="$(_detect_brew_prefix_zprofile)"
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  # Remove Homebrew paths from current PATH temporarily
  # Suppress all output to avoid Powerlevel10k instant prompt warnings
  # Use anonymous function to avoid variable output
  () {
    local cleaned_path
    cleaned_path=$(echo "$PATH" | tr ':' '\n' | grep -v "^$HOMEBREW_PREFIX/bin$" | grep -v "^$HOMEBREW_PREFIX/sbin$" | tr '\n' ':' | sed 's/:$//' 2>/dev/null)
    # Rebuild PATH with Homebrew first, then others, then system paths
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$cleaned_path"
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
