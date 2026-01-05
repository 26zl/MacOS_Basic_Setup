#!/usr/bin/env zsh

# maintain-system - Standalone system and dev environment maintenance script
# Usage: maintain-system [update|verify|versions]

# ================================ SYSTEM COMPATIBILITY ====================

_check_macos_compatibility() {
  # Verify we're running on macOS
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script is designed for macOS only"
    return 1
  fi
  
  # Detect architecture
  local arch=""
  case "$(uname -m)" in
    x86_64) arch="Intel" ;;
    arm64) arch="Apple Silicon" ;;
    *) arch="Unknown" ;;
  esac
  
  echo "[macOS] Detected: macOS ($arch)"
  
  # Check for Homebrew
  local HOMEBREW_PREFIX="$(_detect_brew_prefix)"
  if [[ -z "$HOMEBREW_PREFIX" ]]; then
    echo "  WARNING: Homebrew not detected - some features may not work"
  else
    echo "  Homebrew found at: $HOMEBREW_PREFIX"
  fi
  
  # Check available disk space
  if command -v df >/dev/null 2>&1; then
    local available_space=$(df -h . | awk 'NR==2 {print $4}' | sed 's/[^0-9.]//g')
    if [[ -n "$available_space" && "$available_space" -lt 1 ]]; then
      echo "  WARNING: Low disk space detected ($available_space GB available)"
    fi
  fi
}

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

_is_disabled() {
  local value="${1:-}"
  case "${value:l}" in
    0|false|no|off|disable|disabled)
      return 0
      ;;
  esac
  return 1
}

# ================================ RUBY GEM COMPATIBILITY ===================

_fix_all_ruby_gems() {
  echo "[Ruby] Auto-fixing Ruby gems for compatibility..."
  
  if ! command -v ruby >/dev/null 2>&1; then
    echo "  ERROR: Ruby not found, skipping gem fix"
    return 1
  fi
  
  local current_ruby="$(ruby -v | cut -d' ' -f2)"
  echo "  Current Ruby version: $current_ruby"
  
  # Get all installed gems
  local installed_gems=($(gem list --no-versions 2>/dev/null || true))
  
  if [[ ${#installed_gems[@]} -eq 0 ]]; then
    echo "  No gems found to check"
    return 0
  fi
  
  echo "  Checking ${#installed_gems[@]} installed gems..."
  
  local fixed_count=0
  local problematic_gems=()
  local working_gems=0
  
  
  # Check each gem for issues
  for gem in "${installed_gems[@]}"; do
    # Skip default gems that can't be uninstalled
    if gem list "$gem" | grep -q "default"; then
      ((working_gems++))
      continue
    fi
    
    # Check if gem executable exists and works
    local gem_executable=""
    local executable_path=""
    if executable_path="$(gem contents "$gem" 2>/dev/null | grep -E "(bin/|exe/)" | head -n1)"; then
      gem_executable="$(basename "$executable_path")"
    fi
    
    # Check if gem is problematic
    local is_problematic=false
    
    # Check if gem has executables and test them
    if [[ -n "$gem_executable" ]]; then
      # Check if executable is in PATH
      if command -v "$gem_executable" >/dev/null 2>&1; then
        # Test if the executable actually works
        if ! "$gem_executable" --version >/dev/null 2>&1 && ! "$gem_executable" -v >/dev/null 2>&1 && ! "$gem_executable" --help >/dev/null 2>&1; then
          is_problematic=true
          echo "  DETECTED: $gem executable is broken"
        else
          ((working_gems++))
        fi
      else
        # Executable not in PATH - might be problematic
        is_problematic=true
        echo "  DETECTED: $gem executable not found in PATH"
      fi
    else
      # Gems without executables are considered working
      ((working_gems++))
    fi
    
    if [[ "$is_problematic" == true ]]; then
      # Check if gem is already in problematic_gems array
      local already_listed=false
      for existing_gem in "${problematic_gems[@]}"; do
        if [[ "$existing_gem" == "$gem" ]]; then
          already_listed=true
          break
        fi
      done
      
      if [[ "$already_listed" == false ]]; then
        problematic_gems+=("$gem")
      fi
      
      echo "  FIXING: $gem..."
      
      # Uninstall and reinstall (non-interactive)
      gem uninstall "$gem" --ignore-dependencies --force --no-user-install 2>/dev/null || true
      if gem install "$gem" --no-user-install 2>/dev/null; then
        ((fixed_count++))
        echo "    SUCCESS: Fixed $gem"
      else
        echo "    WARNING: Failed to fix $gem"
      fi
    fi
  done
  
  # Reinstall gems from Gemfile if it exists
  if [[ -f "Gemfile" ]]; then
    echo "  BUNDLE: Reinstalling gems from Gemfile..."
    bundle install 2>/dev/null || echo "    WARNING: Bundle install failed"
  fi
  
  # Clear gem cache
  echo "  CLEANUP: Clearing gem cache..."
  gem cleanup 2>/dev/null || true
  
  if [[ $fixed_count -gt 0 ]]; then
    echo "  SUCCESS: Fixed $fixed_count problematic gems ($working_gems working properly)"
  else
    echo "  SUCCESS: All $working_gems gems are working properly"
  fi
  
  # Refresh command hash table after gem changes
  hash -r 2>/dev/null || true
}

# ================================ PYTHON COMPATIBILITY =====================

_check_python_package_compatibility() {
  local current_python="$1"
  local target_python="$2"
  local package_name="$3"
  
  # Check if package has Python version requirements
  local requirements=""
  if command -v pip >/dev/null 2>&1; then
    requirements="$(pip show "$package_name" 2>/dev/null | grep -i "requires-python" | cut -d: -f2 | tr -d ' ' || true)"
  fi
  
  if [[ -n "$requirements" ]]; then
    # Simple check for Python version requirements (can be extended for more complex parsing)
    if [[ "$requirements" == *"<"* ]] || [[ "$requirements" == *">"* ]] || [[ "$requirements" == *"!="* ]]; then
      echo "  WARNING: $package_name has Python version requirements: $requirements"
      return 1
    fi
  fi
  
  return 0
}

_check_python_upgrade_compatibility() {
  local current_python="$1"
  local target_python="$2"
  
  echo "[Python] Checking package compatibility before upgrade..."
  local incompatible_packages=()
  
  # Check regular pip packages
  if command -v pip >/dev/null 2>&1; then
    local installed_packages="$(pip list --format=freeze 2>/dev/null | cut -d= -f1 || true)"
    if [[ -n "$installed_packages" ]]; then
      echo "  Checking pip packages..."
      while IFS= read -r package; do
        [[ -z "$package" ]] && continue
        if ! _check_python_package_compatibility "$current_python" "$target_python" "$package"; then
          incompatible_packages+=("$package")
        fi
      done <<< "$installed_packages"
    fi
  fi
  
  # Check pipx packages (isolated in their own venvs, generally safe)
  if command -v pipx >/dev/null 2>&1; then
    local pipx_packages="$(pipx list --short 2>/dev/null | grep -v '^$' || true)"
    if [[ -n "$pipx_packages" ]]; then
      local pipx_count=$(echo "$pipx_packages" | wc -l | tr -d ' ')
      echo "  Checking pipx packages... ($pipx_count packages found)"
      # pipx packages are isolated, safe to upgrade Python
      echo "  INFO: pipx packages are isolated and should be safe to upgrade Python"
    fi
  fi
  
  # Report results
  if [[ ${#incompatible_packages[@]} -gt 0 ]]; then
    echo "  ERROR: Incompatible packages found:"
    for package in "${incompatible_packages[@]}"; do
      echo "    - pip: $package"
    done
    echo "  WARNING: Python upgrade skipped to avoid breaking packages"
    return 1
  else
    echo "  SUCCESS: All packages are compatible with new Python version"
    return 0
  fi
}

# ================================ PYENV HELPERS =============================

_pyenv_latest_available() {
  # Cache the result to avoid slow network calls
  local cache_file="${PYENV_ROOT:=$HOME/.pyenv}/.latest_available_cache"
  local cache_age="${PYENV_CACHE_AGE:-86400}"  # Default 24 hours, configurable via PYENV_CACHE_AGE env var
  
  # Check if cache exists and is recent
  if [[ -f "$cache_file" ]]; then
    local cache_time=$(stat -f "%m" "$cache_file" 2>/dev/null || stat -c "%Y" "$cache_file" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))
    
    if [[ $age -lt $cache_age ]]; then
      cat "$cache_file" 2>/dev/null && return 0
    fi
  fi
  
  # Fetch latest available (slow operation)
  local latest=$(pyenv install --list 2>/dev/null | sed 's/^[[:space:]]*//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)
  
  # Cache the result
  [[ -n "$latest" ]] && echo "$latest" > "$cache_file" 2>/dev/null || true
  
  echo "$latest"
}

_pyenv_latest_installed() {
  local PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  pyenv versions --bare 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1
}

_pyenv_activate_latest() {
  local PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  local HOMEBREW_PREFIX="$(_detect_brew_prefix)"
  
  command -v pyenv >/dev/null 2>&1 || return 1
  local target="${1:-$(_pyenv_latest_available)}"
  [[ -n "$target" ]] || return 1
  
  # Check if version is already installed (multiple methods for robustness)
  local is_installed=false
  
  # Method 1: Check via pyenv versions command
  if pyenv versions --bare 2>/dev/null | grep -qE "^[[:space:]]*${target}[[:space:]]*$"; then
    is_installed=true
  fi
  
  # Method 2: Check if version directory exists (more reliable)
  if [[ -d "$PYENV_ROOT/versions/$target" ]]; then
    is_installed=true
  fi
  
  if [[ "$is_installed" == false ]]; then
    # Try to install via Homebrew first (much faster - uses pre-built binaries)
    local major_version=$(echo "$target" | cut -d. -f1)
    local minor_version=$(echo "$target" | cut -d. -f2)
    local brew_python_formula=""
    local brew_installed=false
    
    # Check if Homebrew is available
    if [[ -n "$HOMEBREW_PREFIX" ]] && command -v brew >/dev/null 2>&1; then
      # Try different Homebrew Python formula names (most specific first)
      for formula in "python@${major_version}.${minor_version}" "python@${major_version}" "python"; do
        # Check if formula exists and is installable
        if brew info "$formula" >/dev/null 2>&1 && ! brew info "$formula" 2>/dev/null | grep -q "Not installed"; then
          brew_python_formula="$formula"
          # Check if it's already installed
          if brew list "$formula" >/dev/null 2>&1; then
            brew_installed=true
          fi
          break
        elif brew list "$formula" >/dev/null 2>&1; then
          # Formula is installed even if info check failed
          brew_python_formula="$formula"
          brew_installed=true
          break
        fi
      done
      
      if [[ -n "$brew_python_formula" ]]; then
        if [[ "$brew_installed" == false ]]; then
          echo "  Installing Python $target via Homebrew (fast - pre-built binaries)..." >&2
          if brew install "$brew_python_formula" 2>/dev/null; then
            brew_installed=true
          else
            echo "  WARNING: Homebrew installation failed, will try pyenv install instead" >&2
            brew_installed=false
          fi
        else
          echo "  Found existing Homebrew Python installation: $brew_python_formula" >&2
        fi
        
        if [[ "$brew_installed" == true ]] || brew list "$brew_python_formula" >/dev/null 2>&1; then
          # Link Homebrew Python to pyenv (with safety checks)
          local brew_python_path=""
          
          # Try multiple paths to find Homebrew Python
          if [[ -d "$HOMEBREW_PREFIX/opt/$brew_python_formula/bin" ]]; then
            brew_python_path="$HOMEBREW_PREFIX/opt/$brew_python_formula"
          elif [[ -L "$HOMEBREW_PREFIX/opt/$brew_python_formula" ]]; then
            # Follow symlink if opt is a symlink (macOS readlink doesn't support -f, use cd -P instead)
            brew_python_path=$(cd -P "$HOMEBREW_PREFIX/opt/$brew_python_formula" 2>/dev/null && pwd || echo "")
            [[ -z "$brew_python_path" ]] && brew_python_path="$HOMEBREW_PREFIX/opt/$brew_python_formula"
          elif [[ -d "$HOMEBREW_PREFIX/Cellar/$brew_python_formula" ]]; then
            # Find the latest version in Cellar
            brew_python_path=$(ls -td "$HOMEBREW_PREFIX/Cellar/$brew_python_formula"/*/bin 2>/dev/null | head -1 | sed 's|/bin$||')
          fi
          
          # Verify python3 exists 
          if [[ -n "$brew_python_path" && -e "$brew_python_path/bin/python3" ]]; then
            # Verify the version matches 
            local brew_version=$("$brew_python_path/bin/python3" --version 2>/dev/null | cut -d' ' -f2 || echo "")
            if [[ -n "$brew_version" ]]; then
              # Extract major.minor from both versions for comparison
              local target_major_minor="${target%.*}"
              local brew_major_minor="${brew_version%.*}"
              
              # Accept if major.minor matches (e.g., 3.14.x matches 3.14.2)
              if [[ "$brew_major_minor" == "$target_major_minor" ]]; then
                local symlink_path="$PYENV_ROOT/versions/$target"
                if [[ -L "$symlink_path" ]]; then
                  # Check if symlink is broken
                  if [[ ! -e "$symlink_path" ]]; then
                    echo "  WARNING: Broken symlink detected, removing..." >&2
                    rm -f "$symlink_path" 2>/dev/null || true
                  elif [[ "$(readlink "$symlink_path")" != "$brew_python_path" ]]; then
                    # Symlink points to wrong location, update it
                    echo "  Updating symlink to point to current Homebrew Python ($brew_version)..." >&2
                    rm -f "$symlink_path" 2>/dev/null || true
                    mkdir -p "$PYENV_ROOT/versions" 2>/dev/null || true
                    ln -sf "$brew_python_path" "$symlink_path" 2>/dev/null || true
                  else
                    # Symlink is valid and points to correct location
                    is_installed=true
                  fi
                else
                  # Create new symlink
                  echo "  Linking Homebrew Python $brew_version as pyenv $target..." >&2
                  mkdir -p "$PYENV_ROOT/versions" 2>/dev/null || true
                  ln -sf "$brew_python_path" "$symlink_path" 2>/dev/null || true
                fi
                
                if [[ "$is_installed" == false ]]; then
                  # Verify symlink was created successfully
                  if [[ -L "$symlink_path" && -e "$symlink_path" ]]; then
                    pyenv rehash 2>/dev/null || true
                    is_installed=true
                    echo "  SUCCESS: Using Homebrew Python $brew_version (close match to $target)" >&2
                  fi
                else
                  pyenv rehash 2>/dev/null || true
                fi
              else
                echo "  INFO: Homebrew Python version $brew_version doesn't match $target (need $target_major_minor.x)" >&2
              fi
            fi
          fi
        fi
      fi
    fi
    
    # If Homebrew installation didn't work, fall back to pyenv install (slower - compiles from source)
    if [[ "$is_installed" == false ]]; then
      echo "  Installing Python $target via pyenv (this may take several minutes - compiling from source)..." >&2
      pyenv install "$target" || return 1
      pyenv rehash 2>/dev/null || true
    fi
  fi
  
  # Activate the version
  pyenv global "$target" || return 1
  pyenv rehash >/dev/null 2>&1 || true
  
  # Ensure 'python' symlink exists in pyenv version (needed for pipx and other tools)
  local pyenv_bin_dir="$PYENV_ROOT/versions/$target/bin"
  if [[ -d "$pyenv_bin_dir" ]]; then
    # If python doesn't exist but python3 does, create a symlink
    if [[ ! -f "$pyenv_bin_dir/python" ]] && [[ -f "$pyenv_bin_dir/python3" ]]; then
      # For symlinked Homebrew Python, we need to create python symlink pointing to python3
      if [[ -L "$pyenv_bin_dir" ]] || [[ -L "$PYENV_ROOT/versions/$target" ]]; then
        # Follow symlink to find actual bin directory
        local actual_bin_dir=$(cd -P "$pyenv_bin_dir" 2>/dev/null && pwd)
        if [[ -n "$actual_bin_dir" && -f "$actual_bin_dir/python3" && ! -f "$actual_bin_dir/python" ]]; then
          ln -sf python3 "$actual_bin_dir/python" 2>/dev/null || true
        fi
      else
        # Regular pyenv installation
        ln -sf python3 "$pyenv_bin_dir/python" 2>/dev/null || true
      fi
    fi
  fi
  
  printf "%s" "$target"
}

# ================================ CHRUBY HELPERS =============================

_chruby_latest_available() {
  # Cache the result to avoid slow network calls
  local rubies_root="${RUBIES_ROOT:-$HOME/.rubies}"
  local cache_file="$rubies_root/.latest_available_cache"
  local cache_age="${RUBY_CACHE_AGE:-86400}"  # Default 24 hours, configurable via RUBY_CACHE_AGE env var
  
  # Check if cache exists and is recent
  if [[ -f "$cache_file" ]]; then
    local cache_time=$(stat -f "%m" "$cache_file" 2>/dev/null || stat -c "%Y" "$cache_file" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))
    
    if [[ $age -lt $cache_age ]]; then
      cat "$cache_file" 2>/dev/null && return 0
    fi
  fi
  
  # Fetch latest available (slow operation)
  local latest=""
  if command -v ruby-install >/dev/null 2>&1; then
    latest="$(ruby-install --list ruby 2>/dev/null | awk '/^ruby [0-9]+\.[0-9]+\.[0-9]+$/ {print $2}' | sort -V | tail -n1)"
  fi
  
  # Cache the result
  [[ -n "$latest" ]] && echo "$latest" > "$cache_file" 2>/dev/null || true
  
  echo "$latest"
}

_chruby_latest_installed() {
  command -v chruby >/dev/null 2>&1 || return 1
  chruby 2>/dev/null | sed -E 's/^[* ]+//' | grep -E '^ruby-[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1
}

_chruby_install_latest() {
  command -v chruby >/dev/null 2>&1 || return 1
  command -v ruby-install >/dev/null 2>&1 || return 1
  local latest
  latest="$(_chruby_latest_available)"
  [[ -n "$latest" ]] || return 1
  if ! chruby 2>/dev/null | sed -E 's/^[* ]+//' | grep -qx "ruby-$latest"; then
    ruby-install ruby "$latest" || return 1
  fi
  echo "ruby-$latest"
}

# ================================ GO HELPERS ==================================

_go_update_toolchain() {
  command -v go >/dev/null 2>&1 || return 1
  
  echo "[Go] Updating Go toolchain and packages..."
  
  # Get current version
  local current_version=$(go version | awk '{print $3}' | sed 's/go//')
  echo "  Current: Go $current_version"
  
  local go_errors=()
  
  # Update Go itself - try multiple methods
  # Method 1: If installed via Homebrew
  if command -v brew >/dev/null 2>&1 && brew list go >/dev/null 2>&1; then
    echo "  Updating Go via Homebrew..."
    if brew upgrade go 2>/dev/null; then
      local new_version=$(go version | awk '{print $3}' | sed 's/go//')
      echo "  SUCCESS: Updated to Go $new_version"
    else
      go_errors+=("homebrew_upgrade")
      echo "  WARNING: Homebrew upgrade failed"
    fi
  else
    # Method 2: Use go install to update (Go 1.17+)
    echo "  Checking for Go updates via go install..."
    if go install golang.org/dl/go@latest 2>/dev/null; then
      # Try to download latest version
      local latest_go=$(go list -m -f '{{.Version}}' golang.org/dl/go@latest 2>/dev/null || echo "")
      if [[ -n "$latest_go" ]]; then
        echo "  INFO: Latest Go version available: $latest_go"
        echo "  INFO: Run 'go install golang.org/dl/go${latest_go#go}@latest' to install"
      fi
    fi
  fi
  
  # Update Go modules using Go's native tools (go mod, go get)
  echo "  Updating Go modules and dependencies..."
  local go_project_updates="${MAINTAIN_SYSTEM_GO_PROJECTS:-0}"
  
  # Update modules in current directory if go.mod exists
  if [[ -f "go.mod" ]]; then
    if [[ "$go_project_updates" == "1" ]]; then
      echo "    Updating dependencies in go.mod..."
      # Use go get -u to update all dependencies
      if go get -u ./...; then
        echo "    Dependencies updated"
      else
        go_errors+=("go_get")
        echo "    WARNING: go get -u failed"
      fi
      
      # Run go mod tidy to clean up go.mod and go.sum
      echo "    Running go mod tidy..."
      if go mod tidy; then
        echo "    go.mod cleaned up"
      else
        go_errors+=("mod_tidy")
        echo "    WARNING: go mod tidy failed"
      fi
      
      # Run go mod download to ensure all dependencies are downloaded
      echo "    Downloading module dependencies..."
      if go mod download; then
        echo "    Modules downloaded"
      else
        go_errors+=("mod_download")
        echo "    WARNING: go mod download failed"
      fi
    else
      echo "    INFO: go.mod found, but project updates are disabled"
      echo "    INFO: Set MAINTAIN_SYSTEM_GO_PROJECTS=1 to update project dependencies"
    fi
  else
    echo "    INFO: No go.mod found in current directory"
    echo "    INFO: Go modules are project-specific - run 'update' in your Go project directories"
  fi
  
  # Update all globally installed Go tools
  echo "  Checking for globally installed Go tools..."
  
  # Find Go binary directories
  local go_bin_dirs=()
  local gobin=$(go env GOBIN 2>/dev/null || echo "")
  local gopath=$(go env GOPATH 2>/dev/null || echo "")
  local home_go_bin="$HOME/go/bin"
  
  # Collect all possible Go binary directories
  [[ -n "$gobin" && -d "$gobin" ]] && go_bin_dirs+=("$gobin")
  [[ -n "$gopath" && -d "$gopath/bin" ]] && go_bin_dirs+=("$gopath/bin")
  [[ -d "$home_go_bin" ]] && go_bin_dirs+=("$home_go_bin")
  
  if [[ ${#go_bin_dirs[@]} -eq 0 ]]; then
    echo "    INFO: No Go binary directories found"
  else
    local tools_found=0
    local tools_updated=0
    local tools_failed=0
    local tools_skipped=0
    
    # Find all binaries in Go bin directories
    for bin_dir in "${go_bin_dirs[@]}"; do
      if [[ -d "$bin_dir" ]]; then
        while IFS= read -r binary; do
          [[ -z "$binary" ]] && continue
          [[ ! -f "$binary" ]] && continue
          [[ ! -x "$binary" ]] && continue
          
          local tool_name=$(basename "$binary")
          
          # Skip if it's the go binary itself
          [[ "$tool_name" == "go" ]] && continue
          
          # Try to get module path from binary using go version -m
          local module_path=""
          local module_info=$(go version -m "$binary" 2>/dev/null | grep -E "^[[:space:]]*mod[[:space:]]+" | head -1 || echo "")
          
          if [[ -n "$module_info" ]]; then
            # Extract module path (format: "mod    path/to/module    version")
            module_path=$(echo "$module_info" | awk '{print $2}')
          fi
          
          # If we couldn't get module path, skip this tool
          if [[ -z "$module_path" ]]; then
            ((tools_skipped++))
            continue
          fi
          
          # Skip standard library modules
          if [[ "$module_path" == std* ]] || [[ "$module_path" == cmd/* ]] || [[ "$module_path" == "main" ]]; then
            ((tools_skipped++))
            continue
          fi
          
          ((tools_found++))
          echo "    Checking $tool_name ($module_path)..."
          
          # Try to update the tool by trying different common paths
          local updated=false
          
          # Try 1: Direct module path (if it's already a command path)
          if go install "${module_path}@latest" 2>/dev/null; then
            updated=true
          else
            # Try 2: Module path + /cmd/toolname
            if go install "${module_path}/cmd/${tool_name}@latest" 2>/dev/null; then
              updated=true
            else
              # Try 3: Module path + /toolname
              if go install "${module_path}/${tool_name}@latest" 2>/dev/null; then
                updated=true
              fi
            fi
          fi
          
          if [[ "$updated" == true ]]; then
            ((tools_updated++))
            echo "      SUCCESS: Updated $tool_name"
          else
            ((tools_failed++))
            echo "      WARNING: Could not determine install path for $tool_name"
          fi
        done < <(find "$bin_dir" -maxdepth 1 -type f -perm +111 2>/dev/null)
      fi
    done
    
    if [[ $tools_found -eq 0 ]]; then
      echo "    INFO: No Go tools found in Go binary directories"
    else
      echo "    Found $tools_found Go tools, updated $tools_updated, failed $tools_failed, skipped $tools_skipped"
    fi
  fi
  
  if [[ ${#go_errors[@]} -gt 0 ]]; then
    echo "  Go issues: ${go_errors[*]}"
    return 1
  else
    echo "  SUCCESS: Go toolchain and packages updated"
    return 0
  fi
}

_cargo_update_packages() {
  command -v cargo >/dev/null 2>&1 || return 1
  
  echo "[Cargo] Upgrading globally installed packages..."
  
  # Get list of installed packages
  local installed_packages=$(cargo install --list 2>/dev/null | grep -E '^[a-z]' | awk '{print $1}')
  
  if [[ -z "$installed_packages" ]]; then
    echo "  INFO: No globally installed cargo packages found"
    return 0
  fi
  
  local total=$(echo "$installed_packages" | wc -l)
  local updated=0
  local failed=0
  
  echo "  Found $total globally installed packages"
  
  # Update each package
  while IFS= read -r package; do
    [[ -z "$package" ]] && continue
    echo "  Upgrading $package..."
    if cargo install --force "$package" 2>/dev/null >/dev/null; then
      ((updated++))
    else
      ((failed++))
      echo "    WARNING: Failed to upgrade $package"
    fi
  done <<< "$installed_packages"
  
  if [[ $failed -eq 0 ]]; then
    echo "  SUCCESS: Updated $updated packages"
    return 0
  else
    echo "  PARTIAL: Updated $updated packages, $failed failed"
    return 1
  fi
}

# ================================ UPDATE ===================================

update() {
  echo "==> Update started $(date)"
  
  # Check macOS compatibility
  if ! _check_macos_compatibility; then
    echo "ERROR: This script requires macOS"
    return 1
  fi
  
  local HOMEBREW_PREFIX="$(_detect_brew_prefix)"

  if command -v brew >/dev/null 2>&1; then
    echo "[Homebrew] update/upgrade/cleanup..."
    local brew_errors=()
    
    if brew update 2>/dev/null; then
      echo "  Homebrew updated successfully"
    else
      brew_errors+=("update")
      echo "  WARNING: Homebrew update failed"
    fi
    
    if brew upgrade 2>/dev/null; then
      echo "  Homebrew packages upgraded successfully"
    else
      brew_errors+=("upgrade")
      echo "  WARNING: Some Homebrew packages failed to upgrade"
    fi
    
    brew cleanup 2>/dev/null || brew_errors+=("cleanup")
    brew cleanup -s 2>/dev/null || true
    
    if brew doctor 2>/dev/null; then
      echo "  Homebrew doctor check passed"
    else
      brew_errors+=("doctor")
      echo "  WARNING: brew doctor reported issues"
    fi
    
    # Report summary of Homebrew issues
    if [[ ${#brew_errors[@]} -gt 0 ]]; then
      echo "  Homebrew issues: ${brew_errors[*]}"
      echo "  Consider running: brew doctor for detailed diagnostics"
    fi
  else
    echo "[Homebrew] Not installed, skipping..."
  fi

  if command -v port >/dev/null 2>&1; then
    echo "[MacPorts] sudo required; you may be prompted..."
    local port_errors=()
    
    if sudo port -v selfupdate 2>/dev/null; then
      echo "  MacPorts updated successfully"
    else
      port_errors+=("selfupdate")
      echo "  WARNING: MacPorts selfupdate failed"
    fi
    
    if sudo port -N upgrade outdated 2>/dev/null; then
      echo "  MacPorts packages upgraded successfully"
    else
      port_errors+=("upgrade")
      echo "  WARNING: Some MacPorts packages failed to upgrade"
    fi
    
    sudo port reclaim -f --disable-reminders 2>/dev/null || port_errors+=("reclaim")
    (cd /tmp && sudo port clean --all installed) 2>/dev/null || port_errors+=("clean")
    
    # Report summary of MacPorts issues
    if [[ ${#port_errors[@]} -gt 0 ]]; then
      echo "  MacPorts issues: ${port_errors[*]}"
    fi
  fi

  local pybin=""
  local pyenv_target=""
  local current_python=""
  local PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  
  # Get current Python version before upgrade
  if command -v pyenv >/dev/null 2>&1; then
    current_python="$(pyenv version-name 2>/dev/null || true)"
  else
    current_python="$(python3 -V 2>/dev/null | cut -d' ' -f2 || python -V 2>/dev/null | cut -d' ' -f2 || true)"
  fi
  
  if command -v pyenv >/dev/null 2>&1; then
    # First check installed versions (fast) before checking available (slow)
    local latest_installed="$(_pyenv_latest_installed)"
    local latest_available=""
    
    # Normalize current_python (handle empty or "system")
    [[ -z "$current_python" || "$current_python" == "system" ]] && current_python=""
    
    # If we have a latest installed version, use it as baseline
    if [[ -n "$latest_installed" ]]; then
      # Check if we need to activate the latest installed version
      if [[ -z "$current_python" || "$current_python" != "$latest_installed" ]]; then
        echo "[pyenv] Current: ${current_python:-system}, Latest installed: $latest_installed"
        # Activate latest installed immediately (fast)
        if pyenv_target="$(_pyenv_activate_latest "$latest_installed" 2>/dev/null)"; then
          echo "[pyenv] Activated: $pyenv_target"
          pybin="$(pyenv which python 2>/dev/null || true)"
          current_python="$pyenv_target"
        fi
      fi
      
      # Now check if there's a newer version available (may be slow, but cached)
      # Only check cache first to avoid unnecessary network calls
      local cache_file="$PYENV_ROOT/.latest_available_cache"
      if [[ -f "$cache_file" ]]; then
        local cached_latest=$(cat "$cache_file" 2>/dev/null)
        # If cache shows a newer version than installed, fetch fresh to confirm
        if [[ -n "$cached_latest" && "$cached_latest" != "$latest_installed" ]]; then
          latest_available="$(_pyenv_latest_available)"
        else
          # Cache suggests we're up to date, use installed version
          latest_available="$latest_installed"
        fi
      else
        # No cache yet - check available versions (will create cache)
        latest_available="$(_pyenv_latest_available)"
      fi
    else
      # No installed versions - check what's available (may be slow, but cached)
      latest_available="$(_pyenv_latest_available)"
    fi
    
    if [[ -n "$latest_available" && "$current_python" != "$latest_available" ]]; then
      echo "[pyenv] Current: ${current_python:-system}, Latest available: $latest_available"
      
      # Check compatibility before upgrade
      if ! _check_python_upgrade_compatibility "$current_python" "$latest_available"; then
        echo ""
        echo "WARNING: Some packages may be broken by Python upgrade!"
        echo "   This may affect global pip packages and pipx packages."
        echo ""
        read -q "? Do you want to continue with Python upgrade? (y/N): " && echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          echo "[pyenv] Continuing with Python upgrade..."
          if pyenv_target="$(_pyenv_activate_latest "$latest_available")"; then
            echo "[pyenv] Using $pyenv_target"
            pybin="$(pyenv which python 2>/dev/null || true)"
          else
            echo "[pyenv] Could not activate latest Python (continuing)."
            pybin="$(pyenv which python 2>/dev/null || true)"
          fi
        else
          echo "[pyenv] Python upgrade cancelled by user"
          pyenv_target="$current_python"
          pybin="$(pyenv which python 2>/dev/null || true)"
        fi
      else
        echo "[pyenv] Activating latest Python..."
        if pyenv_target="$(_pyenv_activate_latest "$latest_available")"; then
          echo "[pyenv] Using $pyenv_target"
          pybin="$(pyenv which python 2>/dev/null || true)"
        else
          echo "[pyenv] Could not activate latest Python (continuing)."
          pybin="$(pyenv which python 2>/dev/null || true)"
        fi
      fi
    else
      echo "[pyenv] Already using latest Python: $current_python"
      pyenv_target="$current_python"
      pybin="$(pyenv which python 2>/dev/null || true)"
    fi
  fi
  [[ -z "$pybin" ]] && pybin="$(command -v python3 || command -v python || true)"
  if [[ -n "$pybin" ]]; then
    echo "[Python] Upgrading pip/setuptools/wheel and global packages..."
    local python_errors=()
    
    # Check if Python is a symlink to Homebrew (read-only, skip pip upgrades)
    local pyenv_version_dir=""
    if command -v pyenv >/dev/null 2>&1; then
      local current_pyenv_version=$(pyenv version-name 2>/dev/null || echo "")
      if [[ -n "$current_pyenv_version" && "$current_pyenv_version" != "system" ]]; then
        pyenv_version_dir="${PYENV_ROOT:-$HOME/.pyenv}/versions/$current_pyenv_version"
        if [[ -L "$pyenv_version_dir" ]]; then
          echo "  INFO: Python is symlinked to Homebrew (read-only), skipping pip/setuptools/wheel upgrade"
          echo "  INFO: Homebrew manages these packages - use 'brew upgrade python@X' to update"
        else
          # Regular pyenv installation - can upgrade pip
          if "$pybin" -m ensurepip --upgrade 2>/dev/null; then
            echo "  ensurepip upgraded successfully"
          else
            python_errors+=("ensurepip")
            echo "  WARNING: ensurepip upgrade failed"
          fi
          
          if "$pybin" -m pip install --upgrade pip setuptools wheel 2>/dev/null; then
            echo "  pip/setuptools/wheel upgraded successfully"
          else
            python_errors+=("pip_upgrade")
            echo "  WARNING: pip/setuptools/wheel upgrade failed"
          fi
        fi
      else
        # System Python or no pyenv - try to upgrade
        if "$pybin" -m ensurepip --upgrade 2>/dev/null; then
          echo "  ensurepip upgraded successfully"
        else
          python_errors+=("ensurepip")
          echo "  WARNING: ensurepip upgrade failed"
        fi
        
        if "$pybin" -m pip install --upgrade pip setuptools wheel 2>/dev/null; then
          echo "  pip/setuptools/wheel upgraded successfully"
        else
          python_errors+=("pip_upgrade")
          echo "  WARNING: pip/setuptools/wheel upgrade failed"
        fi
      fi
    else
      # No pyenv - try to upgrade
      if "$pybin" -m ensurepip --upgrade 2>/dev/null; then
        echo "  ensurepip upgraded successfully"
      else
        python_errors+=("ensurepip")
        echo "  WARNING: ensurepip upgrade failed"
      fi
      
      if "$pybin" -m pip install --upgrade pip setuptools wheel 2>/dev/null; then
        echo "  pip/setuptools/wheel upgraded successfully"
      else
        python_errors+=("pip_upgrade")
        echo "  WARNING: pip/setuptools/wheel upgrade failed"
      fi
    fi
    
    if command -v pipx >/dev/null 2>&1; then
      echo "[pipx] Upgrading all packages..."
      
      # Set the default Python for pipx if needed
      # For symlinked pyenv versions, we need to use the actual Python binary, not the symlink
      if [[ -n "$pybin" ]]; then
        local actual_python="$pybin"
        
        # If pybin is a symlink (pyenv shim), resolve it to the actual binary
        if [[ -L "$pybin" ]] || [[ "$pybin" == *"/.pyenv/shims/"* ]]; then
          # Get the actual Python path by following symlinks
          actual_python=$(cd -P "$(dirname "$pybin")" 2>/dev/null && pwd)/$(basename "$pybin")
          # If that didn't work, try using python3 directly
          if [[ ! -f "$actual_python" ]]; then
            actual_python=$(command -v python3 2>/dev/null || echo "$pybin")
          fi
        fi
        
        # For Homebrew Python symlinks, find the actual binary
        if [[ -L "$actual_python" ]]; then
          local resolved_python=$(cd -P "$(dirname "$actual_python")" 2>/dev/null && pwd)/$(basename "$actual_python")
          if [[ -f "$resolved_python" ]]; then
            actual_python="$resolved_python"
          fi
        fi
        
        # Ensure we have a valid Python binary (try python3.14, python3, or python)
        if [[ ! -f "$actual_python" ]]; then
          local python_dir=$(dirname "$actual_python")
          if [[ -f "$python_dir/python3.14" ]]; then
            actual_python="$python_dir/python3.14"
          elif [[ -f "$python_dir/python3" ]]; then
            actual_python="$python_dir/python3"
          elif [[ -f "$python_dir/python" ]]; then
            actual_python="$python_dir/python"
          fi
        fi
        
        export PIPX_DEFAULT_PYTHON="$actual_python"
        echo "  Using Python: $actual_python"
      fi
      
      # Try to upgrade all pipx packages
      local pipx_output
      pipx_output="$(pipx upgrade-all --verbose 2>&1)"
      local pipx_exit_code=$?
      
      if [[ $pipx_exit_code -eq 0 ]]; then
        echo "  pipx packages upgraded successfully"
      else
        python_errors+=("pipx")
        echo "  WARNING: pipx upgrade failed (exit code: $pipx_exit_code)"
        
        # Try to identify specific issues
        if [[ "$pipx_output" == *"No packages to upgrade"* ]]; then
          echo "  INFO: No pipx packages need upgrading"
        elif [[ "$pipx_output" == *"error"* ]] || [[ "$pipx_output" == *"Error"* ]]; then
          echo "  ERROR: pipx encountered errors during upgrade"
          echo "  Consider running: pipx upgrade-all --force"
        else
          echo "  INFO: pipx upgrade completed with warnings"
        fi
        
        # Try force upgrade as fallback
        echo "  ATTEMPTING: Force upgrade as fallback..."
        if pipx upgrade-all --force 2>/dev/null; then
          echo "  SUCCESS: pipx packages upgraded with force"
          # Remove pipx from errors if force upgrade succeeded
          python_errors=("${python_errors[@]/pipx}")
        else
          echo "  WARNING: Force upgrade also failed"
        fi
      fi
    fi
    
    # Update miniforge/conda packages
    if command -v conda >/dev/null 2>&1; then
      echo "[conda/miniforge] Updating conda and packages..."
      local conda_errors=()
      
      # Update conda itself first
      if conda update -n base -c defaults conda -y 2>/dev/null; then
        echo "  conda updated successfully"
      else
        conda_errors+=("conda_update")
        echo "  WARNING: conda update failed"
      fi
      
      # Update all packages in base environment
      if conda update --all -y 2>/dev/null; then
        echo "  conda packages updated successfully"
      else
        conda_errors+=("conda_packages")
        echo "  WARNING: Some conda packages failed to update"
      fi
      
      # Clean conda cache
      conda clean --all -y 2>/dev/null || conda_errors+=("conda_clean")
      
      # Report summary of conda issues
      if [[ ${#conda_errors[@]} -gt 0 ]]; then
        echo "  conda issues: ${conda_errors[*]}"
      fi
    else
      # Miniforge installed but not initialized in PATH - detect dynamically
      local miniforge_path=""
      local HOMEBREW_PREFIX="$(_detect_brew_prefix)"
      local conda_paths=(
        "$HOME/miniforge3/bin/conda"
        "$HOME/miniforge/bin/conda"
        "$HOME/anaconda3/bin/conda"
        "$HOME/anaconda/bin/conda"
        "$HOMEBREW_PREFIX/Caskroom/miniforge/base/bin/conda"
        "$HOMEBREW_PREFIX/Caskroom/anaconda/base/bin/conda"
        "/usr/local/miniforge3/bin/conda"
        "/usr/local/anaconda3/bin/conda"
      )
      
      for path in "${conda_paths[@]}"; do
        if [[ -f "$path" ]]; then
          # Use zsh parameter expansion instead of dirname command
          miniforge_path="${path%/*}"
          break
        fi
      done
      
      if [[ -n "$miniforge_path" ]]; then
        echo "[miniforge] Initializing and updating miniforge..."
        # Initialize conda for this shell
        eval "$("$miniforge_path/conda" shell.zsh hook 2>/dev/null)" || true
        
        if command -v conda >/dev/null 2>&1; then
          local conda_errors=()
          
          # Update conda itself first
          if conda update -n base -c defaults conda -y 2>/dev/null; then
            echo "  conda updated successfully"
          else
            conda_errors+=("conda_update")
            echo "  WARNING: conda update failed"
          fi
          
          # Update all packages in base environment
          if conda update --all -y 2>/dev/null; then
            echo "  conda packages updated successfully"
          else
            conda_errors+=("conda_packages")
            echo "  WARNING: Some conda packages failed to update"
          fi
          
          # Clean conda cache
          conda clean --all -y 2>/dev/null || conda_errors+=("conda_clean")
          
          # Report summary of conda issues
          if [[ ${#conda_errors[@]} -gt 0 ]]; then
            echo "  conda issues: ${conda_errors[*]}"
          fi
        fi
      fi
    fi
    
    # Upgrade global packages with better error handling (skip if symlink to Homebrew)
    if [[ -z "$pyenv_version_dir" || ! -L "$pyenv_version_dir" ]]; then
      local outdated_packages
      outdated_packages="$("$pybin" -m pip list --outdated --format=freeze 2>/dev/null | cut -d= -f1 || true)"
      if [[ -n "$outdated_packages" ]]; then
        echo "  Upgrading global packages..."
        local failed_packages=()
        while IFS= read -r package; do
          [[ -z "$package" ]] && continue
          if ! "$pybin" -m pip install -U "$package" 2>/dev/null; then
            failed_packages+=("$package")
          fi
        done <<< "$outdated_packages"
        
        if [[ ${#failed_packages[@]} -gt 0 ]]; then
          python_errors+=("global_packages")
          echo "  WARNING: Failed to upgrade: ${failed_packages[*]}"
        else
          echo "  Global packages upgraded successfully"
        fi
      fi
    else
      echo "  INFO: Skipping global packages upgrade (Homebrew-managed Python)"
    fi
    
    # Report summary of Python issues
    if [[ ${#python_errors[@]} -gt 0 ]]; then
      echo "  Python issues: ${python_errors[*]}"
    fi
    
    # Refresh command hash table after Python package updates
    hash -r 2>/dev/null || true
  fi
  
  if command -v pyenv >/dev/null 2>&1 && [[ -n "$pyenv_target" && "$pyenv_target" != "system" ]]; then
    if _is_disabled "${MAINTAIN_SYSTEM_CLEAN_PYENV:-}"; then
      echo "[pyenv] Cleanup disabled; set MAINTAIN_SYSTEM_CLEAN_PYENV=1 or unset to enable"
    else
      local keep_list_raw="${MAINTAIN_SYSTEM_PYENV_KEEP:-}"
      keep_list_raw="${keep_list_raw//,/ }"
      local versions_to_keep=("$pyenv_target" "system")

      if [[ -n "$keep_list_raw" ]]; then
        local keep_entry=""
        for keep_entry in ${=keep_list_raw}; do
          versions_to_keep+=("$keep_entry")
        done
      fi

      echo "[pyenv] Removing old versions (keeping $pyenv_target and any in MAINTAIN_SYSTEM_PYENV_KEEP)..."
      pyenv versions --bare 2>/dev/null | while read -r ver; do
        [[ -z "$ver" ]] && continue
        local should_keep=false
        local keep_ver=""
        for keep_ver in "${versions_to_keep[@]}"; do
          [[ "$ver" == "$keep_ver" ]] && should_keep=true && break
        done
        [[ "$should_keep" == true ]] && continue
        echo "  removing $ver"
        pyenv uninstall -f "$ver" || echo "  WARNING: Failed to remove $ver"
      done
      pyenv rehash 2>/dev/null || true
    fi
  fi

  echo "[Node] Ensuring latest LTS..."
  if command -v nvm >/dev/null 2>&1; then
    local prev_nvm="$(nvm current 2>/dev/null || true)"
    nvm install --lts --latest-npm || true
    nvm alias default 'lts/*' || true
    nvm use default || true
    if [[ -n "$prev_nvm" && "$prev_nvm" != "system" ]]; then
      nvm reinstall-packages "$prev_nvm" || true
    fi
    local active_nvm="$(nvm current 2>/dev/null || true)"
    if [[ -n "$active_nvm" && "$active_nvm" != "system" ]]; then
      if _is_disabled "${MAINTAIN_SYSTEM_CLEAN_NVM:-}"; then
        echo "[nvm] Cleanup disabled; set MAINTAIN_SYSTEM_CLEAN_NVM=1 or unset to enable"
      else
        local keep_list_raw="${MAINTAIN_SYSTEM_NVM_KEEP:-}"
        keep_list_raw="${keep_list_raw//,/ }"
        local keep_versions=("$active_nvm")

        if [[ -n "$keep_list_raw" ]]; then
          local keep_entry=""
          for keep_entry in ${=keep_list_raw}; do
            [[ "$keep_entry" == v* ]] || keep_entry="v$keep_entry"
            keep_versions+=("$keep_entry")
          done
        fi

        echo "[nvm] Removing older Node versions (keeping $active_nvm and any in MAINTAIN_SYSTEM_NVM_KEEP)..."
        # Get only actually installed versions dynamically
        # nvm ls shows only installed versions (not remote/available versions)
        while IFS= read -r ver; do
          [[ -z "$ver" ]] && continue
          local should_keep=false
          local keep_ver=""
          for keep_ver in "${keep_versions[@]}"; do
            if [[ "$ver" == "$keep_ver" ]]; then
              should_keep=true
              break
            fi
          done
          [[ "$should_keep" == true ]] && continue
          echo "  removing $ver"
          nvm uninstall "$ver" || echo "  WARNING: Failed to remove $ver"
        done < <(nvm ls --no-colors --no-alias 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sort -u)
      fi
    fi
  elif command -v brew >/dev/null 2>&1 && brew list node >/dev/null 2>&1; then
    brew upgrade node || true
  fi
  
  if command -v npm >/dev/null 2>&1; then
    npm install -g npm || true
    npm update -g || true
    
    # Refresh command hash table after Node.js package updates
    hash -r 2>/dev/null || true
  fi

  local chruby_target=""
  
  if command -v gem >/dev/null 2>&1; then
    echo "[RubyGems] Updating and cleaning gems..."
    gem update --silent || true
    gem cleanup || true
  fi
  
  if command -v chruby >/dev/null 2>&1; then
    echo "[chruby] Ensuring latest Ruby is active..."
    if chruby_target="$(_chruby_install_latest 2>/dev/null)"; then
      echo "[chruby] Installed and activated: $chruby_target"
    else
      chruby_target="$(_chruby_latest_installed 2>/dev/null || true)"
      if [[ -n "$chruby_target" ]]; then
        echo "[chruby] Activating existing: $chruby_target"
        chruby "$chruby_target" >/dev/null 2>&1 || echo "[chruby] Failed to activate $chruby_target"
      else
        echo "[chruby] No Ruby versions found, installing latest..."
        if command -v ruby-install >/dev/null 2>&1; then
          local latest_ruby="$(_chruby_latest_available)"
          if [[ -n "$latest_ruby" ]]; then
            echo "[chruby] Installing ruby-$latest_ruby..."
            ruby-install ruby "$latest_ruby" && chruby_target="ruby-$latest_ruby"
            chruby "$chruby_target" >/dev/null 2>&1 || echo "[chruby] Failed to activate $chruby_target"
          fi
        else
          echo "[chruby] ruby-install not found, cannot install Ruby"
        fi
      fi
    fi
    
    # Auto-fix Ruby gems by default allow opt-out
    if _is_disabled "${MAINTAIN_SYSTEM_FIX_RUBY_GEMS:-}"; then
      echo "[Ruby] Gem auto-fix disabled; set MAINTAIN_SYSTEM_FIX_RUBY_GEMS=1 or unset to enable"
    else
      _fix_all_ruby_gems
    fi
  fi
  
  if command -v chruby >/dev/null 2>&1 && [[ -n "$chruby_target" ]]; then
    local rubies_root="$HOME/.rubies"
    if [[ -d "$rubies_root" ]]; then
      if _is_disabled "${MAINTAIN_SYSTEM_CLEAN_CHRUBY:-}"; then
        echo "[chruby] Cleanup disabled; set MAINTAIN_SYSTEM_CLEAN_CHRUBY=1 or unset to enable"
      else
        local keep_list_raw="${MAINTAIN_SYSTEM_CHRUBY_KEEP:-}"
        keep_list_raw="${keep_list_raw//,/ }"
        local keep_versions=("$chruby_target")

        if [[ -n "$keep_list_raw" ]]; then
          local keep_entry=""
          for keep_entry in ${=keep_list_raw}; do
            [[ "$keep_entry" == ruby-* ]] || keep_entry="ruby-$keep_entry"
            keep_versions+=("$keep_entry")
          done
        fi

        echo "[chruby] Removing old rubies (keeping $chruby_target and any in MAINTAIN_SYSTEM_CHRUBY_KEEP)..."
        for dir in "$rubies_root"/ruby-*; do
          [[ -d "$dir" ]] || continue
          local ruby_version="${dir##*/}"
          local should_keep=false
          local keep_ver=""
          for keep_ver in "${keep_versions[@]}"; do
            if [[ "$ruby_version" == "$keep_ver" ]]; then
              should_keep=true
              break
            fi
          done
          [[ "$should_keep" == true ]] && continue
          echo "  removing $ruby_version"
          rm -rf "$dir" || echo "  WARNING: Failed to remove $ruby_version"
        done
      fi
    fi
  fi

  # Go
  if command -v go >/dev/null 2>&1; then
    _go_update_toolchain || true
  fi

  # Swift
  if command -v swiftly >/dev/null 2>&1; then
    echo "[Swift] Updating Swift toolchain via swiftly..."
    
    # Check if swiftly is initialized
    if [[ -z "${SWIFTLY_HOME_DIR:-}" ]] && [[ ! -f "$HOME/.swiftly/env.sh" ]]; then
      echo "  INFO: swiftly not initialized, initializing..."
      if ~/.swiftly/bin/swiftly init --quiet-shell-followup 2>/dev/null; then
        if [[ -f "$HOME/.swiftly/env.sh" ]]; then
          source "$HOME/.swiftly/env.sh" 2>/dev/null || true
          hash -r 2>/dev/null || true
          echo "  SUCCESS: swiftly initialized"
        fi
      else
        echo "  WARNING: swiftly initialization failed"
      fi
    fi
    
    # Update swiftly itself
    echo "  Updating swiftly..."
    # swiftly self-update can be interactive, redirect stdin to /dev/null after piping responses
    if { printf "y\ny\ny\ny\ny\n"; cat /dev/null; } | swiftly self-update >/dev/null 2>&1; then
      echo "  swiftly updated successfully"
    else
      echo "  WARNING: swiftly self-update failed (may require manual intervention)"
    fi
    
    # swiftly list shows "(in use)" for release toolchains and "(default)" for snapshots
    local current_swift=""
    # Check for release toolchain (in use)
    current_swift="$(swiftly list 2>/dev/null | grep -E '\(in use\)' | sed 's/Swift //' | sed 's/ (in use).*//' | awk '{print $1}' || echo "")"
    # If no release toolchain active, check for snapshot (default)
    if [[ -z "$current_swift" ]]; then
      current_swift="$(swiftly list 2>/dev/null | grep -E '\(default\)' | sed 's/.* //' | sed 's/ (default).*//' | awk '{print $1}' || echo "")"
    fi
    if [[ -n "$current_swift" ]]; then
      echo "  Current: Swift $current_swift"
      
      # Check if current version is a snapshot
      local is_snapshot=false
      if [[ "$current_swift" == *"snapshot"* ]] || [[ "$current_swift" == *"main"* ]] || [[ "$current_swift" == *"release"* ]]; then
        is_snapshot=true
        echo "  INFO: Current version is a snapshot/development build"
      fi
      
      # Get latest stable release 
      # swiftly list-available outputs "Swift X.Y.Z" format, we need the version number
      local latest_stable="$(swiftly list-available 2>/dev/null | grep -E '^Swift [0-9]+\.[0-9]+\.[0-9]+' | head -n1 | awk '{print $2}' || echo "")"
      
      # Get latest snapshot if user wants snapshots (optional, can be controlled via env var)
      local latest_snapshot=""
      if [[ "${MAINTAIN_SYSTEM_SWIFT_SNAPSHOTS:-0}" == "1" ]]; then
        # swiftly list-available outputs snapshot names, extract version (usually 2nd field)
        latest_snapshot="$(swiftly list-available 2>/dev/null | grep -E "(main-snapshot|release.*snapshot)" | head -n1 | awk '{print $2}' || echo "")"
      fi
      
      # Determine target version (prefer stable unless snapshot is explicitly requested)
      local target_version=""
      if [[ -n "$latest_stable" && "$latest_stable" != "$current_swift" ]]; then
        target_version="$latest_stable"
      elif [[ -n "$latest_snapshot" && "$latest_snapshot" != "$current_swift" && "$is_snapshot" == "true" ]]; then
        target_version="$latest_snapshot"
      fi
      
      if [[ -n "$target_version" ]]; then
        echo "  Latest available: Swift $target_version"
        if echo "y" | swiftly install "$target_version" --global-default 2>/dev/null; then
          echo "  SUCCESS: Updated to Swift $target_version"
          hash -r 2>/dev/null || true
        else
          echo "  WARNING: Failed to install Swift $target_version"
        fi
      else
        echo "  Swift is up to date ($current_swift)"
      fi
      
      # Check for newer snapshots (informational only)
      if [[ "$is_snapshot" == "false" && -n "$latest_snapshot" ]]; then
        echo "  INFO: Development snapshot available: $latest_snapshot (set MAINTAIN_SYSTEM_SWIFT_SNAPSHOTS=1 to enable)"
      fi
    else
      echo "  INFO: No Swift version active via swiftly"
      # Check if any Swift version (release or snapshot) is installed but not active
      local installed_swift=""
      # Check for release toolchain first
      installed_swift="$(swiftly list 2>/dev/null | grep -E '^Swift [0-9]+\.[0-9]+\.[0-9]+' | head -n1 | sed 's/Swift //' | awk '{print $1}' || echo "")"
      # If no release, check for snapshot
      if [[ -z "$installed_swift" ]]; then
        installed_swift="$(swiftly list 2>/dev/null | grep -E 'snapshot' | grep -v 'Installed snapshot' | head -n1 | awk '{print $1}' || echo "")"
      fi
      if [[ -n "$installed_swift" ]]; then
        echo "  INFO: Swift $installed_swift is installed but not active, activating..."
        if echo "y" | swiftly use "$installed_swift" --global-default 2>/dev/null; then
          echo "  SUCCESS: Activated Swift $installed_swift"
          hash -r 2>/dev/null || true
        else
          echo "  WARNING: Failed to activate Swift $installed_swift"
        fi
      else
        # Try to install latest stable if no version is installed
        # swiftly list-available outputs "Swift X.Y.Z" format, we need the version number
        local latest_stable="$(swiftly list-available 2>/dev/null | grep -E '^Swift [0-9]+\.[0-9]+\.[0-9]+' | head -n1 | awk '{print $2}' || echo "")"
        if [[ -n "$latest_stable" && "$latest_stable" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
          echo "  INFO: Latest stable available: Swift $latest_stable"
          echo "  INFO: Run 'swiftly install $latest_stable' to install"
        else
          echo "  INFO: Run 'swiftly list-available' to see available Swift versions"
        fi
      fi
    fi
  elif command -v swift >/dev/null 2>&1; then
    echo "[Swift] Swift found (system or Homebrew installation)"
    local swift_version="$(swift --version 2>/dev/null | head -n1 | sed 's/.*version //' | cut -d' ' -f1 || echo "unknown")"
    echo "  Current: Swift $swift_version"
    # If installed via Homebrew, try to update
    if command -v brew >/dev/null 2>&1 && brew list swift >/dev/null 2>&1; then
      echo "  Updating Swift via Homebrew..."
      if brew upgrade swift 2>/dev/null; then
        local new_version="$(swift --version 2>/dev/null | head -n1 | sed 's/.*version //' | cut -d' ' -f1 || echo "unknown")"
        echo "  SUCCESS: Updated to Swift $new_version"
      else
        echo "  WARNING: Homebrew Swift update failed"
      fi
    else
      echo "  INFO: Swift is system-installed (update via Xcode or install swiftly for version management)"
      echo "  INFO: Install swiftly: curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg && installer -pkg swiftly.pkg -target CurrentUserHomeDirectory"
    fi
  else
    echo "[Swift] Swift not found"
    echo "  INFO: Install swiftly: curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg && installer -pkg swiftly.pkg -target CurrentUserHomeDirectory"
  fi

  # Rust - use rustup for comprehensive updates
  if command -v rustup >/dev/null 2>&1; then
    echo "[Rust] Updating Rust toolchain and components via rustup..."
    local rust_errors=()
    
    # Update rustup itself first
    echo "  Updating rustup..."
    if rustup self update 2>/dev/null; then
      echo "    rustup updated successfully"
    else
      rust_errors+=("rustup_self")
      echo "    WARNING: rustup self update failed"
    fi
    
    # Update all installed toolchains
    echo "  Updating all Rust toolchains..."
    if rustup update 2>/dev/null; then
      echo "    Toolchains updated successfully"
    else
      rust_errors+=("toolchains")
      echo "    WARNING: Toolchain update failed"
    fi

    # Set default toolchain to stable
    echo "  Setting default toolchain to stable..."
    rustup default stable 2>/dev/null || rust_errors+=("default_toolchain")
    
    # Add common rustup components if not already installed
    echo "  Ensuring rustup components are installed..."
    if rustup component add rustfmt clippy 2>/dev/null; then
      echo "    Components added/updated"
    fi
    
    # Report Rust issues
    if [[ ${#rust_errors[@]} -gt 0 ]]; then
      echo "  Rust issues: ${rust_errors[*]}"
    fi
  fi

  # Cargo (Rust package manager) - update globally installed packages
  if command -v cargo >/dev/null 2>&1; then
    _cargo_update_packages || true
  fi

  # Nix - integrated update with smart preview and cleanup
  if command -v nix >/dev/null 2>&1; then
    echo "[Nix] Updating packages..."
    local nix_errors=()
    
    # Update nix profile packages
    local profile_count
    profile_count=$(nix profile list 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    if [[ "$profile_count" -gt 0 ]]; then
      if nix profile upgrade --all 2>/dev/null; then
        echo "  nix profile packages updated successfully"
      else
        nix_errors+=("profile")
        echo "  WARNING: nix profile update failed"
      fi
    fi
    
    # Update nix-env packages
    local env_count
    env_count=$(nix-env -q 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    if [[ "$env_count" -gt 0 ]]; then
      if nix-env -u '*' 2>/dev/null; then
        echo "  nix-env packages updated successfully"
      else
        nix_errors+=("nix-env")
        echo "  WARNING: nix-env update failed"
      fi
    fi
    
    # Cleanup Nix store (gc + optimise)
    echo "  Cleaning Nix store..."
    local gc_output
    gc_output=$(nix store gc 2>&1 || echo "")
    if [[ -n "$gc_output" ]]; then
      local freed_space
      freed_space=$(echo "$gc_output" | grep -iE "(freed|removed|deleted).*[0-9]+.*(bytes|KB|MB|GB)" | head -1 || echo "")
      if [[ -n "$freed_space" ]]; then
        echo "  Nix store cleaned: $freed_space"
      else
        echo "  Nix store cleaned successfully"
      fi
    else
      nix_errors+=("gc")
      echo "  WARNING: Nix store cleanup failed"
    fi
    
    # Optimise store
    if nix store optimise 2>/dev/null; then
      echo "  Nix store optimised successfully"
    else
      echo "  WARNING: Nix store optimisation had issues (may require sudo)"
    fi
    
    # Smart Nix CLI upgrade check (preview and auto-skip downgrades)
    echo "  Checking for Nix CLI updates..."
    local current_nix_version
    current_nix_version=$(nix --version 2>/dev/null | head -n1 | sed 's/nix (Nix) //' || echo "")
    
    if [[ -n "$current_nix_version" && "$current_nix_version" != "not in PATH" && "$current_nix_version" != "unknown" ]]; then
      # Run preview (dry-run) to check target version
      local upgrade_preview
      upgrade_preview=$(sudo -H nix upgrade-nix --dry-run --profile /nix/var/nix/profiles/default 2>&1 || echo "")
      
      if [[ -n "$upgrade_preview" ]]; then
        # Parse target version from preview output
        local target_version
        target_version=$(echo "$upgrade_preview" | grep -iE "would upgrade to version|upgrade to" | sed -E 's/.*[vV]?([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -1 || echo "")
        
        # Only process if we have a valid target version (suppress debug output)
        if [[ -n "$target_version" && "$target_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$target_version" != "$current_nix_version" ]]; then
          # Compare versions
          local current_major current_minor current_patch
          local target_major target_minor target_patch
          
          IFS='.' read -r current_major current_minor current_patch <<< "$current_nix_version"
          IFS='.' read -r target_major target_minor target_patch <<< "$target_version"
          
          # Normalize patch version
          [[ -z "$current_patch" ]] && current_patch=0
          [[ -z "$target_patch" ]] && target_patch=0
          
          # Check if it's a downgrade
          local is_downgrade=false
          if [[ "$current_major" -gt "$target_major" ]] || \
             ([[ "$current_major" -eq "$target_major" ]] && [[ "$current_minor" -gt "$target_minor" ]]) || \
             ([[ "$current_major" -eq "$target_major" ]] && [[ "$current_minor" -eq "$target_minor" ]] && [[ "$current_patch" -gt "$target_patch" ]]); then
            is_downgrade=true
          fi
          
          if [[ "$is_downgrade" == "true" ]]; then
            echo "  WARNING: Nix CLI upgrade skipped: would downgrade ($current_nix_version -> $target_version)"
            echo "  nix upgrade-nix follows nixpkgs fallback and may be older than installed Nix"
          else
            echo "  INFO: Nix CLI upgrade available: $current_nix_version -> $target_version"
            echo "  To upgrade: sudo -H nix upgrade-nix --profile /nix/var/nix/profiles/default"
          fi
        elif [[ -z "$target_version" ]]; then
          echo "  Nix CLI is up to date ($current_nix_version)"
        else
          echo "  Nix CLI is up to date ($current_nix_version)"
        fi
      else
        echo "  Could not check Nix CLI upgrade (preview requires sudo or nix not properly configured)"
      fi
    else
      echo "  Could not determine current Nix version"
    fi
    
    # Fix Oh My Zsh compaudit issues if present
    if command -v compaudit >/dev/null 2>&1; then
      local insecure_dirs
      insecure_dirs=$(compaudit 2>&1 || true)
      if [[ -n "$insecure_dirs" ]]; then
        echo "  Fixing Oh My Zsh insecure completion directories..."
        if echo "$insecure_dirs" | xargs -I {} chmod g-w,o-w {} 2>/dev/null; then
          echo "  Oh My Zsh permissions fixed"
        else
          echo "  WARNING: Could not fix Oh My Zsh permissions (may require sudo)"
        fi
      fi
    fi
    
    if [[ ${#nix_errors[@]} -gt 0 ]]; then
      echo "  Nix issues: ${nix_errors[*]}"
    fi
  fi

  hash -r 2>/dev/null || true
  echo "==> Update finished $(date)"
}

# ================================ VERIFY ===================================

verify() {
  echo "==> Verify $(date)"
  local ok warn miss
  ok()   { printf "%-15s OK (%s)\n" "$1" "$2"; }
  warn() { printf "%-15s WARN (%s)\n" "$1" "$2"; }
  miss() { printf "%-15s Not installed\n" "$1"; }

  if command -v ruby >/dev/null 2>&1; then
    ok "Ruby" "$(ruby -v)"
    command -v gem >/dev/null 2>&1 && ok "Gem" "$(gem -v)"
    if command -v chruby >/dev/null 2>&1; then
      local chruby_version="$(chruby --version 2>/dev/null | head -n1)"
      if [[ -n "$chruby_version" ]]; then
        ok "chruby" "$chruby_version"
      else
        ok "chruby" "installed"
      fi
    fi
  else
    if command -v chruby >/dev/null 2>&1; then
      warn "Ruby" "not installed (run 'update' to install)"
    else
      miss "Ruby"
    fi
  fi

  local pybin="$(command -v python3 || command -v python || true)"
  if [[ -n "$pybin" ]]; then
    ok "Python" "$("$pybin" -V 2>/dev/null)"
    # Check for pip (try pip, pip3, or python3 -m pip)
    local pip_cmd=""
    if command -v pip >/dev/null 2>&1; then
      pip_cmd="pip"
    elif command -v pip3 >/dev/null 2>&1; then
      pip_cmd="pip3"
    elif "$pybin" -m pip --version >/dev/null 2>&1; then
      pip_cmd="$pybin -m pip"
    fi
    if [[ -n "$pip_cmd" ]]; then
      ok "pip" "$($pip_cmd --version 2>/dev/null | head -n1 || echo "available")"
    else
      warn "pip" "not in PATH"
    fi
    if command -v pyenv >/dev/null 2>&1; then
      local active_py="$(pyenv version-name 2>/dev/null || true)"
      local latest_py="$(_pyenv_latest_installed)"
      [[ -n "$latest_py" && "$active_py" == "$latest_py" ]] && ok "pyenv" "active $active_py" || warn "pyenv" "active ${active_py:-unknown}; latest ${latest_py:-unknown}"
    fi
  else
    if command -v pyenv >/dev/null 2>&1; then
      warn "Python" "not installed (run 'update' to install)"
    else
      miss "Python"
    fi
  fi

  if command -v node >/dev/null 2>&1; then
    ok "Node" "$(node -v)"
    command -v npm >/dev/null 2>&1 && ok "npm" "$(npm -v)" || warn "npm" "not in PATH"
    if command -v nvm >/dev/null 2>&1; then
      local current="$(nvm current 2>/dev/null || true)"
      local defv="$(nvm version default 2>/dev/null || true)"
      [[ -n "$defv" && "$current" == "$defv" ]] && ok "nvm" "current $current" || warn "nvm" "current ${current:-N/A}; default ${defv:-N/A}"
    fi
  else
    if command -v nvm >/dev/null 2>&1; then
      warn "Node" "not installed (run 'update' to install)"
    else
      miss "Node"
    fi
  fi

  if command -v rustc >/dev/null 2>&1; then
    ok "Rust" "$(rustc -V)"
  else
    if command -v rustup >/dev/null 2>&1; then
      warn "Rust" "not installed (run 'update' to install)"
    else
      miss "Rust"
    fi
  fi
  if command -v rustup >/dev/null 2>&1; then
    local active="$(rustup show active-toolchain 2>/dev/null | head -n1)"
    [[ "$active" == stable* ]] && ok "rustup" "$active" || warn "rustup" "$active"
  fi

  # Swift
  if command -v swift >/dev/null 2>&1; then
    local swift_version="$(swift --version 2>/dev/null | head -n1 | sed 's/.*version //' | cut -d' ' -f1 || echo "unknown")"
    local swift_source=""
    
    # Check if Swift is from swiftly
    if command -v swiftly >/dev/null 2>&1; then
      # swiftly list shows "(in use)" for active version, not "*"
      local swiftly_current="$(swiftly list 2>/dev/null | grep -E '\(in use\)' | sed 's/Swift //' | sed 's/ (in use).*//' | awk '{print $1}' || echo "")"
      if [[ -n "$swiftly_current" ]]; then
        swift_source=" (swiftly: $swiftly_current)"
        # Check if it's a snapshot
        if [[ "$swiftly_current" == *"snapshot"* ]] || [[ "$swiftly_current" == *"main"* ]]; then
          swift_source="${swift_source} [snapshot]"
        fi
        ok "Swift" "$swift_version$swift_source"
        ok "swiftly" "active $swiftly_current"
      else
        local swiftly_installed="$(swiftly list 2>/dev/null | head -n1 || echo "")"
        if [[ -n "$swiftly_installed" ]]; then
          ok "Swift" "$swift_version (system/Homebrew, swiftly installed but not active)"
          ok "swiftly" "installed (no active version)"
        else
          ok "Swift" "$swift_version (system/Homebrew)"
          warn "swiftly" "installed but no versions installed"
        fi
      fi
    else
      ok "Swift" "$swift_version (system/Homebrew)"
    fi
  else
    if command -v swiftly >/dev/null 2>&1; then
      warn "Swift" "not installed (run 'update' to install)"
      local swiftly_installed="$(swiftly list 2>/dev/null | head -n1 || echo "")"
      [[ -n "$swiftly_installed" ]] && warn "swiftly" "installed but Swift not in PATH" || warn "swiftly" "installed but not initialized"
    else
      miss "Swift"
    fi
  fi

  command -v go   >/dev/null 2>&1 && ok "Go"   "$(go version)" || miss "Go"
  command -v java >/dev/null 2>&1 && ok "Java" "$(java -version 2>&1 | head -n1)" || miss "Java"
  command -v clang >/dev/null 2>&1 && ok "Clang" "$(clang --version | head -n1)" || miss "Clang"
  command -v gcc  >/dev/null 2>&1 && ok "GCC"  "$(gcc --version | head -n1)" || warn "GCC" "not found"
  
  # Detect MySQL dynamically
  local mysql_found=false
  if command -v mysql >/dev/null 2>&1; then
    ok "MySQL" "$(mysql --version)"
    mysql_found=true
  else
    # Check common MySQL installation locations
    local mysql_paths=(
      "$(brew --prefix mysql 2>/dev/null)/bin/mysql"
      "$(brew --prefix mariadb 2>/dev/null)/bin/mysql"
      "/usr/local/mysql/bin/mysql"
      "/opt/homebrew/opt/mysql/bin/mysql"
      "/opt/homebrew/opt/mariadb/bin/mysql"
    )
    
    for mysql_path in "${mysql_paths[@]}"; do
      if [[ -x "$mysql_path" ]]; then
        ok "MySQL" "$("$mysql_path" --version)"
        mysql_found=true
        break
      fi
    done
    
    if [[ "$mysql_found" == false ]]; then
      warn "MySQL" "not found"
    fi
  fi

  if command -v docker >/dev/null 2>&1; then
    ok "Docker" "$(docker -v)"
    if command -v docker-compose >/dev/null 2>&1; then
      ok "Compose" "$(docker-compose -v)"
    elif docker compose version >/dev/null 2>&1; then
      ok "Compose" "$(docker compose version | head -n1)"
    else
      warn "Compose" "not found"
    fi
  else
    miss "Docker"
  fi

  command -v brew >/dev/null 2>&1 && ok "Homebrew" "$(brew --version | head -n1)" || miss "Homebrew"
  command -v port  >/dev/null 2>&1 && ok "MacPorts" "$(port version)" || warn "MacPorts" "not installed"
  
  # Nix - comprehensive status check
  if command -v nix >/dev/null 2>&1; then
    local nix_version="$(nix --version 2>/dev/null | head -n1 | sed 's/nix (Nix) //' || echo "unknown")"
    local nix_status=""
    
    # Check installation completeness
    if [[ -d /nix ]] && [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
      # Check daemon
      if pgrep -x nix-daemon >/dev/null 2>&1; then
        nix_status=" (daemon running)"
      else
        nix_status=" (daemon not running)"
      fi
      
      # Check for packages
      local profile_count
      profile_count=$(nix profile list 2>/dev/null | wc -l | tr -d ' ' || echo "0")
      local env_count
      env_count=$(nix-env -q 2>/dev/null | wc -l | tr -d ' ' || echo "0")
      
      if [[ "$profile_count" -gt 0 ]] || [[ "$env_count" -gt 0 ]]; then
        local pkg_info=""
        [[ "$profile_count" -gt 0 ]] && pkg_info="${pkg_info}profile:$profile_count "
        [[ "$env_count" -gt 0 ]] && pkg_info="${pkg_info}env:$env_count"
        nix_status="${nix_status} [${pkg_info}]"
      fi
      
      ok "Nix" "$nix_version$nix_status"
    else
      warn "Nix" "$nix_version (installation incomplete)"
    fi
  else
    # Check if Nix is installed but not in PATH
    if [[ -d /nix ]] && [[ -f /nix/var/nix/profiles/default/bin/nix ]]; then
      warn "Nix" "installed but not in PATH (run: ./scripts/nix-macos-maintenance.sh ensure-path or reinstall)"
    else
      miss "Nix"
    fi
  fi
  
  if command -v mongod >/dev/null 2>&1; then
    local mongodb_version="$(mongod --version 2>/dev/null | head -n1 | sed 's/db version //' || echo "unknown")"
    local mongodb_status="stopped"
    if pgrep -x mongod >/dev/null 2>&1; then
      mongodb_status="running"
    fi
    ok "MongoDB" "$mongodb_version ($mongodb_status)"
  else
    miss "MongoDB"
  fi
  
  if command -v psql >/dev/null 2>&1; then
    local postgres_version="$(psql --version 2>/dev/null | sed 's/psql (PostgreSQL) //' | sed 's/ .*//' || echo "unknown")"
    local postgres_status="stopped"
    if pgrep -x postgres >/dev/null 2>&1; then
      postgres_status="running"
    fi
    ok "PostgreSQL" "$postgres_version ($postgres_status)"
  else
    miss "PostgreSQL"
  fi
  
  echo "==> Verify done"
}

# ================================ VERSIONS ===================================

versions() {
  echo "================== TOOL VERSIONS =================="
  command -v ruby >/dev/null 2>&1 && echo "Ruby ........... $(ruby -v)" || echo "Ruby ........... not installed"
  command -v gem  >/dev/null 2>&1 && echo "Gem ............ $(gem -v)" || true
  if command -v chruby >/dev/null 2>&1; then
    local chruby_version="$(chruby --version 2>/dev/null | head -n1)"
    if [[ -n "$chruby_version" ]]; then
      echo "chruby ......... $chruby_version"
    else
      echo "chruby ......... installed"
    fi
  fi

  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    echo "Python ......... $(python3 -V 2>/dev/null || python -V 2>/dev/null)"
    command -v pip  >/dev/null 2>&1 && echo "pip ............ $(pip -V | awk '{print $2}')" || true
    command -v pyenv >/dev/null 2>&1 && echo "pyenv .......... $(pyenv version-name 2>/dev/null)" || true
  else
    echo "Python ......... not installed"
  fi

  if command -v node >/dev/null 2>&1; then
    echo "Node.js ........ $(node -v)"
    command -v npm >/dev/null 2>&1 && echo "npm ............ $(npm -v)" || true
    command -v nvm >/dev/null 2>&1 && echo "nvm ............ $(nvm current 2>/dev/null)" || true
  else
    echo "Node.js ........ not installed"
  fi

  command -v rustc >/dev/null 2>&1 && echo "Rust ........... $(rustc -V)" || echo "Rust ........... not installed"
  command -v rustup >/dev/null 2>&1 && echo "rustup ......... $(rustup show active-toolchain 2>/dev/null | head -n1)" || true
  
  if command -v swift >/dev/null 2>&1; then
    local swift_version="$(swift --version 2>/dev/null | head -n1 | sed 's/.*version //' | cut -d' ' -f1 || echo "unknown")"
    local swift_info="$swift_version"
    
    if command -v swiftly >/dev/null 2>&1; then
      # swiftly list shows "(in use)" for active version, not "*"
      local swiftly_current="$(swiftly list 2>/dev/null | grep -E '\(in use\)' | sed 's/Swift //' | sed 's/ (in use).*//' | awk '{print $1}' || echo "")"
      if [[ -n "$swiftly_current" ]]; then
        swift_info="$swift_version (swiftly: $swiftly_current)"
        # Check if it's a snapshot
        if [[ "$swiftly_current" == *"snapshot"* ]] || [[ "$swiftly_current" == *"main"* ]]; then
          swift_info="${swift_info} [snapshot]"
        fi
        echo "Swift .......... $swift_info"
        echo "swiftly ........ active $swiftly_current"
      else
        local swiftly_installed="$(swiftly list 2>/dev/null | head -n1 || echo "")"
        if [[ -n "$swiftly_installed" ]]; then
          echo "Swift .......... $swift_version (system/Homebrew, swiftly installed)"
          echo "swiftly ........ installed (no active version)"
        else
          echo "Swift .......... $swift_version (system/Homebrew)"
          echo "swiftly ........ installed (not initialized)"
        fi
      fi
    else
      echo "Swift .......... $swift_version (system/Homebrew)"
    fi
  else
    echo "Swift .......... not installed"
    if command -v swiftly >/dev/null 2>&1; then
      local swiftly_installed
      swiftly_installed="$(swiftly list 2>/dev/null | head -n1 || echo "")"
      [[ -n "$swiftly_installed" ]] && echo "swiftly ........ installed (Swift not in PATH)" || echo "swiftly ........ installed (not initialized)"
    fi
  fi
  
  command -v go   >/dev/null 2>&1 && echo "Go ............. $(go version)" || echo "Go ............. not installed"
  command -v java >/dev/null 2>&1 && echo "Java ........... $(java -version 2>&1 | head -n1)" || echo "Java ........... not installed"
  command -v clang >/dev/null 2>&1 && echo "Clang .......... $(clang --version | head -n1)" || echo "Clang .......... not installed"
  command -v gcc  >/dev/null 2>&1 && echo "GCC ............ $(gcc --version | head -n1)" || echo "GCC ............ not installed"

  # Detect MySQL dynamically
  local mysql_found=false
  if command -v mysql >/dev/null 2>&1; then
    echo "MySQL .......... $(mysql --version)"
    mysql_found=true
  else
    # Check common MySQL installation locations
    local mysql_paths=(
      "$(brew --prefix mysql 2>/dev/null)/bin/mysql"
      "$(brew --prefix mariadb 2>/dev/null)/bin/mysql"
      "/usr/local/mysql/bin/mysql"
      "/opt/homebrew/opt/mysql/bin/mysql"
      "/opt/homebrew/opt/mariadb/bin/mysql"
    )
    
    for mysql_path in "${mysql_paths[@]}"; do
      if [[ -x "$mysql_path" ]]; then
        echo "MySQL .......... $("$mysql_path" --version)"
        mysql_found=true
        break
      fi
    done
    
    if [[ "$mysql_found" == false ]]; then
      echo "MySQL .......... not installed"
    fi
  fi

  if command -v docker >/dev/null 2>&1; then
    echo "Docker ......... $(docker -v)"
    if command -v docker-compose >/dev/null 2>&1; then
      echo "Compose ........ $(docker-compose -v)"
    elif docker compose version >/dev/null 2>&1; then
      echo "Compose ........ $(docker compose version | head -n1)"
    fi
  else
    echo "Docker ......... not installed"
  fi

  command -v brew >/dev/null 2>&1 && echo "Homebrew ....... $(brew --version | head -n1)" || echo "Homebrew ....... not installed"
  command -v port >/dev/null 2>&1 && echo "MacPorts ....... $(port version)" || echo "MacPorts ....... not installed"
  
  # Nix
  if command -v nix >/dev/null 2>&1; then
    local nix_version
    nix_version="$(nix --version 2>/dev/null | head -n1 | sed 's/nix (Nix) //' || echo "unknown")"
    echo "Nix ............. $nix_version"
  else
    echo "Nix ............. not installed"
  fi
  
  if command -v mongod >/dev/null 2>&1; then
    local mongodb_version
    mongodb_version="$(mongod --version 2>/dev/null | head -n1 | sed 's/db version //' || echo "unknown")"
    local mongodb_status="stopped"
    if pgrep -x mongod >/dev/null 2>&1; then
      mongodb_status="running"
    fi
    echo "MongoDB ........ $mongodb_version ($mongodb_status)"
  else
    echo "MongoDB ........ not installed"
  fi
  
  if command -v psql >/dev/null 2>&1; then
    local postgres_version
    postgres_version="$(psql --version 2>/dev/null | sed 's/psql (PostgreSQL) //' | sed 's/ .*//' || echo "unknown")"
    local postgres_status="stopped"
    if pgrep -x postgres >/dev/null 2>&1; then
      postgres_status="running"
    fi
    echo "PostgreSQL ..... $postgres_version ($postgres_status)"
  else
    echo "PostgreSQL ..... not installed"
  fi
  
  echo "==================================================="
}

# ================================ MAIN =====================================
# Dispatch based on command argument
case "${1:-}" in
  update)
    update
    ;;
  verify)
    verify
    ;;
  versions)
    versions
    ;;
  *)
    echo "Usage: maintain-system [update|verify|versions]"
    echo ""
    echo "Commands:"
    echo "  update   - Update Homebrew, Python, Node.js, Ruby, Rust, and other tools"
    echo "  verify   - Verify installed tools and their versions"
    echo "  versions - Display detailed version information for all tools"
    echo ""
    echo "Optional environment variables:"
    echo "  MAINTAIN_SYSTEM_GO_PROJECTS=1           Update go.mod dependencies in current directory"
    echo "  MAINTAIN_SYSTEM_FIX_RUBY_GEMS=0|disabled Disable Ruby gem auto-fix"
    echo "  MAINTAIN_SYSTEM_CLEAN_PYENV=0|disabled  Disable pyenv cleanup (MAINTAIN_SYSTEM_PYENV_KEEP=...)"
    echo "  MAINTAIN_SYSTEM_CLEAN_NVM=0|disabled    Disable Node cleanup (MAINTAIN_SYSTEM_NVM_KEEP=...)"
    echo "  MAINTAIN_SYSTEM_CLEAN_CHRUBY=0|disabled Disable chruby cleanup (MAINTAIN_SYSTEM_CHRUBY_KEEP=...)"
    echo "  MAINTAIN_SYSTEM_SWIFT_SNAPSHOTS=1       Enable Swift development snapshot updates"
    exit 1
    ;;
esac
