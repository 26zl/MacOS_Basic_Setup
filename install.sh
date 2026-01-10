#!/usr/bin/env zsh

# macOS Development Environment Setup - Installation Script

set +e  # Allow optional components to fail (will be set per function)

echo "🚀 macOS Development Environment Setup - Installation"
echo "======================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
install_warnings=0

warn() {
  ((install_warnings++))
  echo "${YELLOW}⚠️  $1${NC}"
}

# Ask user for confirmation with input validation
_ask_user() {
  local prompt="$1"
  local default="${2:-N}"
  
  # Validate inputs
  [[ -z "$prompt" ]] && { echo "${RED}Error: _ask_user called without prompt${NC}" >&2; return 1; }
  [[ "$default" != "Y" && "$default" != "N" ]] && default="N"
  
  # In CI/non-interactive mode, automatically answer "yes" to all prompts
  # This simulates a user answering "yes" to everything
  # Allow FORCE_INTERACTIVE=1 to run real prompts in CI (e.g., yes-piped tests)
  if [[ -n "${FORCE_INTERACTIVE:-}" ]]; then
    : # Proceed to prompt
  elif [[ -n "${NONINTERACTIVE:-}" ]] || [[ -n "${CI:-}" ]]; then
    echo "$prompt [Auto: yes]"
    return 0
  fi
  
  echo -n "$prompt "
  if [[ "$default" == "Y" ]]; then
    echo -n "[Y/n]: "
  else
    echo -n "[y/N]: "
  fi
  
  # Read input with validation
  local response=""
  IFS= read -r response || return 1
  
  # Sanitize input: remove leading/trailing whitespace, limit length
  response=$(echo "$response" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ ${#response} -gt 10 ]] && response="${response:0:10}"  # Limit to 10 chars
  
  # Validate: only allow y, Y, n, N, yes, Yes, YES, no, No, NO, or empty
  if [[ -n "$response" ]] && [[ ! "$response" =~ ^[YyNn]$ ]] && [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]] && [[ ! "$response" =~ ^[Nn][Oo]$ ]]; then
    echo "${RED}Invalid input. Please enter y/n/yes/no or press Enter for default.${NC}" >&2
    return 1
  fi
  
  if [[ -z "$response" ]]; then
    response="$default"
  fi
  
  case "$response" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
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

# Detect repository root directory (where install.sh is located)
# This is saved early so it's available even after directory changes
_detect_repo_root() {
  local repo_root=""
  
  # Method 1: Use zsh-specific variable (works in zsh)
  if [[ -n "${(%):-%x}" ]]; then
    repo_root="$(cd "$(dirname "${(%):-%x}")" && pwd)" 2>/dev/null || repo_root=""
  fi
  
  # Method 2: Use $0 if method 1 failed
  if [[ -z "$repo_root" ]] || [[ ! -d "$repo_root" ]]; then
    if [[ -n "${0}" ]] && [[ -f "${0}" ]]; then
      repo_root="$(cd "$(dirname "${0}")" && pwd)" 2>/dev/null || repo_root=""
    fi
  fi
  
  # Method 3: Search from current directory up for maintain-system.sh
  if [[ -z "$repo_root" ]] || [[ ! -f "$repo_root/maintain-system.sh" ]]; then
    local search_dir="$(pwd)"
    local max_iterations=50
    local iteration=0
    while [[ "$search_dir" != "/" ]] && [[ $iteration -lt $max_iterations ]]; do
      if [[ -f "$search_dir/maintain-system.sh" ]]; then
        repo_root="$search_dir"
        break
      fi
      local parent_dir="$(dirname "$search_dir")"
      # Safety check: if parent_dir is same as search_dir, we're stuck
      if [[ "$parent_dir" == "$search_dir" ]]; then
        break
      fi
      search_dir="$parent_dir"
      ((iteration++))
    done
  fi
  
  echo "$repo_root"
}

REPO_ROOT="$(_detect_repo_root)"

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
    echo ""
    echo "${YELLOW}⚠️  IMPORTANT: Homebrew is required for this setup${NC}"
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
      echo "  ${RED}ERROR:${NC} Homebrew is required for this setup. Please install it manually:"
      echo "  ${BLUE}INFO:${NC} /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
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
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc; then
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
    # Update HOMEBREW_PREFIX in case it was just installed
    HOMEBREW_PREFIX="$(_detect_brew_prefix)"
    
    if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
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
    # Update HOMEBREW_PREFIX in case it was just installed
    HOMEBREW_PREFIX="$(_detect_brew_prefix)"
    
    if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
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
      local original_dir="$(pwd)"  # Save original directory safely
      
      echo "  Installing MacPorts ${macports_version} from source..."
      echo "  Downloading ${macports_tarball}..."
      
      if ! cd "$temp_dir" 2>/dev/null; then
        echo "  ${RED}❌ Failed to create temporary directory${NC}"
        rm -rf "$temp_dir" 2>/dev/null || true
        return 1
      fi
      
      if curl -fsSL -o "$macports_tarball" "$macports_url"; then
        echo "  Extracting source code..."
        if tar xf "$macports_tarball"; then
          if ! cd "MacPorts-${macports_version}" 2>/dev/null; then
            echo "  ${RED}❌ Failed to navigate to source directory${NC}"
            cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
            rm -rf "$temp_dir" 2>/dev/null || true
            return 1
          fi
          
          echo "  Configuring MacPorts..."
          # In CI/non-interactive mode, suppress verbose output
          if [[ -n "${NONINTERACTIVE:-}" ]] || [[ -n "${CI:-}" ]]; then
            if ./configure >/dev/null 2>&1; then
              echo "  Configuration complete"
              echo "  Building MacPorts (this may take a while)..."
              if make >/dev/null 2>&1; then
                echo "  Build complete"
                echo "  Installing MacPorts (requires sudo)..."
                if sudo make install >/dev/null 2>&1; then
                  echo ""
                  echo "${GREEN}✅ MacPorts installed successfully${NC}"
                  echo "  ${BLUE}INFO:${NC} Please open a new terminal window for PATH changes to take effect"
                  echo "  ${BLUE}INFO:${NC} Then run: sudo port selfupdate"
                else
                  echo "  ${RED}❌ MacPorts installation failed (make install)${NC}"
                  cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
                  rm -rf "$temp_dir" 2>/dev/null || true
                  return 1
                fi
              else
                echo "  ${RED}❌ MacPorts build failed (make)${NC}"
                cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
                rm -rf "$temp_dir" 2>/dev/null || true
                return 1
              fi
            else
              echo "  ${RED}❌ MacPorts configuration failed (configure)${NC}"
              cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
              rm -rf "$temp_dir" 2>/dev/null || true
              return 1
            fi
          else
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
                  cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
                  rm -rf "$temp_dir" 2>/dev/null || true
                  return 1
                fi
              else
                echo "  ${RED}❌ MacPorts build failed (make)${NC}"
                cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
                rm -rf "$temp_dir" 2>/dev/null || true
                return 1
              fi
            else
              echo "  ${RED}❌ MacPorts configuration failed (configure)${NC}"
              cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
              rm -rf "$temp_dir" 2>/dev/null || true
              return 1
            fi
          fi
        else
          echo "  ${RED}❌ Failed to extract MacPorts source${NC}"
          cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
          rm -rf "$temp_dir" 2>/dev/null || true
          return 1
        fi
      else
        echo "  ${RED}❌ Failed to download MacPorts source${NC}"
        echo "  ${BLUE}INFO:${NC} Visit: https://www.macports.org/install.php for manual installation"
        cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
        rm -rf "$temp_dir" 2>/dev/null || true
        return 1
      fi
      
      # Cleanup - return to original directory safely
      cd "$original_dir" 2>/dev/null || cd "$HOME" 2>/dev/null || true
      rm -rf "$temp_dir" 2>/dev/null || true
    else
      echo "${YELLOW}⚠️  Skipping MacPorts installation${NC}"
    fi
  else
    echo "${GREEN}✅ MacPorts already installed${NC}"
  fi
}

# Function to install Nix
install_nix() {
  # Check if Nix is already installed (multiple ways to detect)
  if command -v nix >/dev/null 2>&1 || [[ -d /nix ]] || [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
    if [[ -d /nix ]] || [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
      echo "${GREEN}✅ Nix detected (may need PATH setup)${NC}"
    else
      echo "${GREEN}✅ Nix already installed${NC}"
    fi
    return 0
  fi
  
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
    
    # Save current directory and ensure we're in a stable location
    local original_dir="$(pwd)"
    local stable_dir="${HOME:-/tmp}"
    
    # Change to stable directory to avoid "cannot get cwd" errors
    cd "$stable_dir" || cd /tmp || {
      echo "  ${RED}❌ Failed to change to stable directory${NC}"
      return 1
    }
    
    # Run Nix installer and capture exit code
    local install_exit=0
    sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon || install_exit=$?
    
    # Return to original directory
    cd "$original_dir" 2>/dev/null || true
    
    # Check if Nix was actually installed, even if installer reported failure
    # (Sometimes the installer fails at the end but Nix is still installed)
    if command -v nix >/dev/null 2>&1 || [[ -d /nix ]] || [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
      echo ""
      echo "${GREEN}✅ Nix installed successfully${NC}"
      echo "  ${BLUE}INFO:${NC} Restart your terminal or run: reload"
      echo "  ${BLUE}INFO:${NC} Then run: ./scripts/nix-macos-maintenance.sh ensure-path"
      return 0
    elif [[ $install_exit -eq 0 ]]; then
      # Installer reported success but Nix not found - might need PATH setup
      echo ""
      echo "${YELLOW}⚠️  Nix installer completed, but Nix not found in PATH${NC}"
      echo "  ${BLUE}INFO:${NC} This may be normal - try restarting your terminal"
      echo "  ${BLUE}INFO:${NC} Or run: reload"
      return 0
    else
      echo ""
      echo "${RED}❌ Nix installation failed${NC}"
      echo "  ${BLUE}INFO:${NC} Visit: https://nixos.org/download.html for manual installation"
      echo "  ${BLUE}INFO:${NC} If installation was interrupted, you may need to clean up before retrying"
      return 1
    fi
  else
    echo "${YELLOW}⚠️  Skipping Nix installation${NC}"
    return 0
  fi
}

# Function to setup maintain-system script
setup_maintain_system() {
  local local_bin="${XDG_DATA_HOME:-$HOME/.local/share}/../bin"
  [[ -d "$local_bin" ]] || local_bin="$HOME/.local/bin"
  
  echo "${YELLOW}📦 Setting up maintain-system script...${NC}"
  mkdir -p "$local_bin"
  
  # Use REPO_ROOT that was detected at script start
  # If REPO_ROOT is not set or maintain-system.sh not found there, try to detect again
  local script_dir="$REPO_ROOT"
  
  if [[ -z "$script_dir" ]] || [[ ! -f "$script_dir/maintain-system.sh" ]]; then
    # Fallback: try to detect again (in case REPO_ROOT wasn't set correctly)
    script_dir="$(_detect_repo_root)"
  fi
  
  # Final check and installation
  if [[ -n "$script_dir" ]] && [[ -f "$script_dir/maintain-system.sh" ]]; then
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
    echo "${RED}❌ Error: maintain-system.sh not found${NC}"
    echo "  REPO_ROOT: ${REPO_ROOT:-not set}"
    echo "  Searched in: $script_dir"
    echo "  Current directory: $(pwd)"
    echo "  Attempted methods: REPO_ROOT variable, fallback detection"
    if [[ -n "$script_dir" ]] && [[ -d "$script_dir" ]]; then
      echo "  Contents of $script_dir/:"
      ls -la "$script_dir/" 2>/dev/null | head -10 || true
    fi
    echo "  Files in current directory:"
    find . -maxdepth 1 -type f \( -name '*maintain*' -o -name '*install*' \) -exec ls -la {} + 2>/dev/null || true
    exit 1
  fi
}

# Function to setup Nix PATH
setup_nix_path() {
  # Check if Nix is installed
  if [[ -d /nix ]] && [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
    echo "${YELLOW}📦 Setting up Nix PATH...${NC}"
    
    # Use REPO_ROOT that was detected at script start
    local script_dir="$REPO_ROOT"
    
    # Fallback: try to detect again if REPO_ROOT not set or file not found
    if [[ -z "$script_dir" ]] || [[ ! -f "$script_dir/scripts/nix-macos-maintenance.sh" ]]; then
      script_dir="$(_detect_repo_root)"
    fi
    
    if [[ -n "$script_dir" ]] && [[ -f "$script_dir/scripts/nix-macos-maintenance.sh" ]]; then
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
  echo "${YELLOW}📦 Setting up PATH cleanup in .zprofile...${NC}"
  echo "  ${BLUE}INFO:${NC} .zprofile is used by login shells to set up PATH"
  echo "  ${BLUE}INFO:${NC} This ensures Homebrew and other tools are available in all shell sessions"
  
  # Check if PATH cleanup already exists
  if [[ -f "$HOME/.zprofile" ]] && grep -q "FINAL PATH CLEANUP (FOR .ZPROFILE)" "$HOME/.zprofile"; then
    echo "${GREEN}✅ PATH cleanup already configured in .zprofile${NC}"
    return 0
  fi
  
  # Backup .zprofile if it exists
  if [[ -f "$HOME/.zprofile" ]]; then
    local zprofile_backup="$HOME/.zprofile.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$HOME/.zprofile" "$zprofile_backup"
    echo "  ${BLUE}INFO:${NC} Backed up existing .zprofile to $zprofile_backup"
  fi
  
  # Ensure .zprofile exists (create empty file if it doesn't exist)
  touch "$HOME/.zprofile"
  
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

# Add MacPorts to PATH if installed
if [[ -d /opt/local/bin ]] && [[ -x /opt/local/bin/port ]]; then
  case ":$PATH:" in
    *":/opt/local/bin:"*) ;;
    *) export PATH="/opt/local/bin:/opt/local/sbin:$PATH" ;;
  esac
fi

# Add Nix to PATH if installed
if [[ -d /nix ]] && [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
  fi
fi

# Final PATH reordering: Ensure Homebrew is ALWAYS first, even after Nix
# Nix may add paths that come before Homebrew, so we re-apply Homebrew first
HOMEBREW_PREFIX="$(_detect_brew_prefix)"
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  {
    # Remove Homebrew paths from current PATH
    cleaned_path=$(echo "$PATH" | tr ':' '\n' | grep -v "^$HOMEBREW_PREFIX/bin$" | grep -v "^$HOMEBREW_PREFIX/sbin$" | tr '\n' ':' | sed 's/:$//' 2>/dev/null)
    # Rebuild PATH with Homebrew ABSOLUTELY FIRST, then others
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
  
  # Use REPO_ROOT that was detected at script start
  local script_dir="$REPO_ROOT"
  
  # Fallback: try to detect again if REPO_ROOT not set or file not found
  if [[ -z "$script_dir" ]] || [[ ! -f "$script_dir/zsh.sh" ]]; then
    script_dir="$(_detect_repo_root)"
  fi
  
  if [[ -n "$script_dir" ]] && [[ -f "$script_dir/zsh.sh" ]]; then
    echo "${YELLOW}📦 Installing zsh configuration...${NC}"
    cp "$script_dir/zsh.sh" "$HOME/.zshrc"
    echo "${GREEN}✅ zsh configuration installed${NC}"
  else
    echo "${RED}❌ Error: zsh.sh not found in $script_dir${NC}"
    echo "  REPO_ROOT: ${REPO_ROOT:-not set}"
    exit 1
  fi
}

# Function to refresh environment immediately after installation
# This ensures PATH and other variables are updated in the current shell session
# Critical for CI/non-interactive mode where commands are run immediately after installation
refresh_environment() {
  echo "${YELLOW}📦 Refreshing environment...${NC}"
  
  # Update HOMEBREW_PREFIX detection
  HOMEBREW_PREFIX="$(_detect_brew_prefix)"
  
  # Update PATH based on .zprofile configuration without sourcing the entire file
  # This avoids executing potentially problematic commands in non-interactive mode
  # We manually apply the PATH cleanup logic instead of sourcing .zprofile
  
  # Update PATH immediately based on what should be in .zprofile
  local local_bin="${XDG_DATA_HOME:-$HOME/.local/share}/../bin"
  [[ -d "$local_bin" ]] || local_bin="$HOME/.local/bin"
  
  if [[ -n "$HOMEBREW_PREFIX" ]]; then
    # Remove Homebrew paths from current PATH temporarily
    local cleaned_path=$(echo "$PATH" | tr ':' '\n' | grep -v "^$HOMEBREW_PREFIX/bin$" | grep -v "^$HOMEBREW_PREFIX/sbin$" | grep -v "^$local_bin$" | tr '\n' ':' | sed 's/:$//' 2>/dev/null)
    # Rebuild PATH with Homebrew first, then ~/.local/bin, then others
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$local_bin:$cleaned_path"
  else
    # No Homebrew, just ensure ~/.local/bin is in PATH
    case ":$PATH:" in
      *":$local_bin:"*) ;;
      *) export PATH="$local_bin:$PATH" ;;
    esac
  fi
  
  # Add MacPorts to PATH if installed
  if [[ -d /opt/local/bin ]] && [[ -x /opt/local/bin/port ]]; then
    case ":$PATH:" in
      *":/opt/local/bin:"*) ;;
      *) export PATH="/opt/local/bin:/opt/local/sbin:$PATH" ;;
    esac
  fi
  
  # Add Nix to PATH if installed
  if [[ -d /nix ]] && [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
      source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
    fi
  fi
  
  # Verify critical commands are now available
  local missing_commands=()
  if [[ -n "$HOMEBREW_PREFIX" ]] && ! command -v brew >/dev/null 2>&1; then
    # Try to add brew to PATH if it exists but isn't found
    if [[ -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
      export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
    fi
  fi
  
  # Check maintain-system
  if ! command -v maintain-system >/dev/null 2>&1; then
    local maintain_system_path="$local_bin/maintain-system"
    if [[ -x "$maintain_system_path" ]]; then
      # It exists but isn't in PATH yet - PATH should have been updated above
      # Just verify it's accessible
      if [[ -x "$maintain_system_path" ]]; then
        : # Command exists, PATH should work now
      fi
    fi
  fi
  
  echo "${GREEN}✅ Environment refreshed${NC}"
  
  # In CI/non-interactive mode, verify critical commands are available
  if [[ -n "${NONINTERACTIVE:-}" ]] || [[ -n "${CI:-}" ]]; then
    local verified=0
    if command -v brew >/dev/null 2>&1; then
      ((verified++))
    fi
    if command -v maintain-system >/dev/null 2>&1 || [[ -x "$local_bin/maintain-system" ]]; then
      ((verified++))
    fi
    if [[ $verified -gt 0 ]]; then
      echo "  ${BLUE}INFO:${NC} Critical commands verified in current shell session"
    fi
  fi
}

# Main installation
main() {
  echo ""
  echo "Starting installation..."
  echo ""
  
  # Critical installations (must succeed)
  set -e
  install_xcode_clt || { echo "${RED}❌ Critical: Xcode Command Line Tools installation failed${NC}"; exit 1; }
  install_homebrew || { echo "${RED}❌ Critical: Homebrew installation failed${NC}"; exit 1; }
  setup_maintain_system || { echo "${RED}❌ Critical: maintain-system script installation failed${NC}"; exit 1; }
  setup_zprofile_path_cleanup || { echo "${RED}❌ Critical: PATH cleanup setup failed${NC}"; exit 1; }
  install_zsh_config || { echo "${RED}❌ Critical: zsh configuration installation failed${NC}"; exit 1; }
  refresh_environment || { echo "${RED}❌ Critical: Environment refresh failed${NC}"; exit 1; }
  
  # Optional installations (can fail)
  set +e
  install_oh_my_zsh || warn "Oh My Zsh installation failed"
  install_powerlevel10k || warn "Powerlevel10k installation failed"
  install_zsh_plugins || warn "ZSH plugins installation failed"
  install_fzf || warn "FZF installation failed"
  install_mas || warn "mas installation failed"
  install_macports || warn "MacPorts installation failed or was skipped"
  install_nix || warn "Nix installation failed or was skipped"
  setup_nix_path || warn "Nix PATH setup failed"
  
  echo ""
  if [[ $install_warnings -gt 0 ]]; then
    echo "${YELLOW}⚠️  Installation completed with $install_warnings warning(s)${NC}"
  else
    echo "${GREEN}✅ Installation complete!${NC}"
  fi
  echo ""
  echo "Next steps:"
  echo "  1. Run: source ~/.zshrc"
  echo "     (This loads the 'reload' and 'reloadzsh' aliases and other shell configurations)"
  echo "  2. (Optional) Install development tools:"
  echo "     - Run './dev-tools.sh' to install language version managers and language runtimes"
  echo "     - This includes: Conda, pipx, pyenv, nvm, chruby, rustup, swiftly, Go, Java, .NET"
  echo "  3. Then you can use:"
  echo "     - reload     : Updates both .zprofile and .zshrc (recommended for full refresh)"
  echo "     - reloadzsh  : Updates only .zshrc (for quick shell config reload)"
  echo "  4. Or simply restart your terminal"
  echo "  5. Run 'p10k configure' to customize your Powerlevel10k theme (optional)"
  echo "  6. Run 'update' to update all your tools"
  echo ""
  echo "Available commands:"
  echo "  - reload     : Reload both .zprofile and .zshrc (updates PATH and shell config)"
  echo "  - reloadzsh  : Reload only .zshrc (updates shell config, faster)"
  echo "  - update     : Update all tools, package managers, and language runtimes"
  echo "  - verify     : Check status of all installed tools"
  echo "  - versions   : Display versions of all tools"
  echo ""
  
  # In CI/non-interactive mode, verify that commands are immediately available
  if [[ -n "${NONINTERACTIVE:-}" ]] || [[ -n "${CI:-}" ]]; then
    echo ""
    echo "${BLUE}INFO:${NC} Environment has been refreshed - commands should be available immediately"
    echo "${BLUE}INFO:${NC} Testing critical commands..."
    
    if command -v brew >/dev/null 2>&1; then
      echo "  ✅ brew is available"
    else
      echo "  ⚠️  brew not found in PATH (may need shell restart)"
    fi
    
    local local_bin="${XDG_DATA_HOME:-$HOME/.local/share}/../bin"
    [[ -d "$local_bin" ]] || local_bin="$HOME/.local/bin"
    
    if command -v maintain-system >/dev/null 2>&1 || [[ -x "$local_bin/maintain-system" ]]; then
      echo "  ✅ maintain-system is available"
    else
      echo "  ⚠️  maintain-system not found (may need shell restart)"
    fi
    
    if command -v port >/dev/null 2>&1; then
      echo "  ✅ port (MacPorts) is available"
    fi
    
    if command -v nix >/dev/null 2>&1 || [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
      echo "  ✅ nix is available"
    fi
  fi
  echo ""
}

# Run main function
main
