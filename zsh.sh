#!/usr/bin/env zsh

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
export ZSH_THEME="powerlevel10k/powerlevel10k"
export plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

source "$ZSH/oh-my-zsh.sh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ================================ PATH =====================================
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
# Clean PATH of duplicates and prioritize Homebrew
_clean_path() {
  local path_array=($(echo "$PATH" | tr ':' '\n'))
  local unique_paths=()
  local seen_paths=()
  local homebrew_paths=()
  local system_paths=()
  local other_paths=()
  
  # Detect Homebrew prefix
  local brew_prefix
  brew_prefix="$(_detect_brew_prefix)"
  
  for path_entry in "${path_array[@]}"; do
    [[ -z "$path_entry" ]] && continue
    
    # Normalize path (resolve ~ and remove trailing slashes)
    local normalized_path="${path_entry/#\~/$HOME}"
    normalized_path="${normalized_path%/}"
    
    # Check for duplicates
    local is_duplicate=false
    for seen_path in "${seen_paths[@]}"; do
      if [[ "$normalized_path" == "$seen_path" ]]; then
        is_duplicate=true
        break
      fi
    done
    
    if [[ "$is_duplicate" == false ]]; then
      seen_paths+=("$normalized_path")
      
      # Categorize paths: Homebrew first, system paths last, others in between
      # Check both normalized and original path for Homebrew
      if [[ -n "$brew_prefix" ]]; then
        if [[ "$normalized_path" == "$brew_prefix/bin" || "$normalized_path" == "$brew_prefix/sbin" ]] || \
           [[ "$path_entry" == "$brew_prefix/bin" || "$path_entry" == "$brew_prefix/sbin" ]]; then
          homebrew_paths+=("$path_entry")
        elif [[ "$normalized_path" == "/usr/bin" || "$normalized_path" == "/usr/sbin" || "$normalized_path" == "/bin" || "$normalized_path" == "/sbin" ]] || \
             [[ "$path_entry" == "/usr/bin" || "$path_entry" == "/usr/sbin" || "$path_entry" == "/bin" || "$path_entry" == "/sbin" ]]; then
          system_paths+=("$path_entry")
        else
          other_paths+=("$path_entry")
        fi
      else
        # No Homebrew, just categorize system vs others
        if [[ "$normalized_path" == "/usr/bin" || "$normalized_path" == "/usr/sbin" || "$normalized_path" == "/bin" || "$normalized_path" == "/sbin" ]] || \
           [[ "$path_entry" == "/usr/bin" || "$path_entry" == "/usr/sbin" || "$path_entry" == "/bin" || "$path_entry" == "/sbin" ]]; then
          system_paths+=("$path_entry")
        else
          other_paths+=("$path_entry")
        fi
      fi
    fi
  done
  
  # Rebuild PATH: Homebrew first, then others, then system paths
  unique_paths=("${homebrew_paths[@]}" "${other_paths[@]}" "${system_paths[@]}")
  
  # Join unique paths
  printf "%s:" "${unique_paths[@]}" | sed 's/:$//'
}

# Add path to PATH only if not already present
_add_to_path() {
  local new_path="$1"
  [[ -z "$new_path" ]] && return 0
  
  # Normalize the path (resolve ~ and remove trailing slashes)
  local normalized_new="${new_path/#\~/$HOME}"
  normalized_new="${normalized_new%/}"
  
  # Check if path is already in PATH
  local path_array=($(echo "$PATH" | tr ':' '\n'))
  for path_entry in "${path_array[@]}"; do
    [[ -z "$path_entry" ]] && continue
    local normalized_entry="${path_entry/#\~/$HOME}"
    normalized_entry="${normalized_entry%/}"
    if [[ "$normalized_entry" == "$normalized_new" ]]; then
      return 0  # Already in PATH, skip
    fi
  done
  
  # Not found, add it
  export PATH="$new_path:$PATH"
}

HOMEBREW_PREFIX="$(_detect_brew_prefix)"
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  _add_to_path "$HOMEBREW_PREFIX/bin"
  _add_to_path "$HOMEBREW_PREFIX/sbin"
fi
# Use XDG_DATA_HOME if set, otherwise fall back to ~/.local/bin
local_bin="${XDG_DATA_HOME:-$HOME/.local/share}/../bin"
[[ -d "$local_bin" ]] || local_bin="$HOME/.local/bin"
_add_to_path "$local_bin"

# ================================ chruby/Ruby ===============================
for _chruby_path in \
  "/opt/homebrew/opt/chruby/share/chruby/chruby.sh" \
  "/usr/local/opt/chruby/share/chruby/chruby.sh" \
  "/usr/local/share/chruby/chruby.sh" \
  "$HOME/.local/share/chruby/chruby.sh"
do
  [[ -f "$_chruby_path" ]] && { . "$_chruby_path" 2>/dev/null || true; break; }
done
unset _chruby_path
for _chruby_auto in \
  "/opt/homebrew/opt/chruby/share/chruby/auto.sh" \
  "/usr/local/opt/chruby/share/chruby/auto.sh" \
  "/usr/local/share/chruby/auto.sh"
do
  [[ -f "$_chruby_auto" ]] && { . "$_chruby_auto" 2>/dev/null || true; break; }
done
unset _chruby_auto

# Activate latest installed Ruby 
# Ruby installation is handled by 'update' command, not during shell startup
if command -v chruby >/dev/null 2>&1; then
  _ruby_target=$(chruby 2>/dev/null | sed -E 's/^[* ]+//' | grep -E '^ruby-[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)
  [[ -n "$_ruby_target" ]] && chruby "$_ruby_target" 2>/dev/null || true
  unset _ruby_target
fi
_setup_gem_path() {
  if ! command -v ruby >/dev/null 2>&1; then return 0; fi
  local engine api
  engine=$(ruby -e 'print defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"' 2>/dev/null)
  api=$(ruby -e 'require "rbconfig"; print RbConfig::CONFIG["ruby_version"]' 2>/dev/null)
  [[ -z "$engine" || -z "$api" ]] && return 0
  export GEM_HOME="$HOME/.gem/$engine/$api"
  export GEM_PATH="$GEM_HOME"
  _add_to_path "$GEM_HOME/bin"
}
_setup_gem_path
autoload -Uz add-zsh-hook
add-zsh-hook precmd _setup_gem_path

# ================================== pyenv ==================================
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
[[ -d "$PYENV_ROOT/bin" ]] && _add_to_path "$PYENV_ROOT/bin"

# Fix corrupted pyenv shim if it exists
if [[ -f "$PYENV_ROOT/shims/.pyenv-shim" ]]; then
  rm -f "$PYENV_ROOT/shims/.pyenv-shim" 2>/dev/null || true
fi

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)" 2>/dev/null
  if [[ -s "$PYENV_ROOT/plugins/pyenv-virtualenv/bin/pyenv-virtualenv" ]]; then
    eval "$(pyenv virtualenv-init -)" 2>/dev/null
  fi
  
  # Set PIPX_DEFAULT_PYTHON for pipx to work with symlinked pyenv versions
  # Also ensuring 'python' symlink exists in pyenv version
  _set_pipx_python() {
    local active_python=$(pyenv which python3 2>/dev/null || pyenv which python 2>/dev/null || command -v python3 2>/dev/null || echo "")
    if [[ -n "$active_python" ]]; then
      # Resolve symlinks to get the actual Python binary
      local resolved_python=$(cd -P "$(dirname "$active_python")" 2>/dev/null && pwd)/$(basename "$active_python")
      # If resolved path doesn't exist, try to find python3.x dynamically, python3, or python
      if [[ ! -f "$resolved_python" ]]; then
        local python_dir=$(dirname "$active_python")
        local found_python=""
        # First try python3 (most common)
        if [[ -f "$python_dir/python3" ]]; then
          found_python="$python_dir/python3"
        # Then try to find highest python3.x version dynamically
        else
          # Use globbing to find python3.x versions
          local python_versions=()
          for f in "$python_dir"/python3.[0-9]*; do
            [[ -f "$f" && "$f" =~ python3\.[0-9]+$ ]] && python_versions+=("$f")
          done
          if [[ ${#python_versions[@]} -gt 0 ]]; then
            # Sort versions and get the highest
            IFS=$'\n' sorted=($(sort -V <<<"${python_versions[*]}"))
            found_python="${sorted[-1]}"
          fi
        fi
        # Fallback to python if nothing else found
        if [[ -z "$found_python" && -f "$python_dir/python" ]]; then
          found_python="$python_dir/python"
        fi
        if [[ -n "$found_python" && -f "$found_python" ]]; then
          resolved_python="$found_python"
        else
          resolved_python="$active_python"
        fi
      fi
      export PIPX_DEFAULT_PYTHON="$resolved_python"
      
      # Create 'python' symlink in pyenv version (needed for pipx)
      local current_version=$(pyenv version-name 2>/dev/null || echo "")
      if [[ -n "$current_version" && "$current_version" != "system" ]]; then
        local pyenv_bin_dir="$PYENV_ROOT/versions/$current_version/bin"
        if [[ -d "$pyenv_bin_dir" || -L "$pyenv_bin_dir" ]]; then
          # Resolve symlink to actual bin directory
          local actual_bin_dir=$(cd -P "$pyenv_bin_dir" 2>/dev/null && pwd)
          if [[ -n "$actual_bin_dir" && -f "$actual_bin_dir/python3" && ! -f "$actual_bin_dir/python" ]]; then
            ln -sf python3 "$actual_bin_dir/python" 2>/dev/null || true
          fi
        fi
      fi
    fi
  }
  _set_pipx_python
  unset -f _set_pipx_python
fi

# ================================== nvm ====================================
# Lazy load NVM to speed up shell startup
# NVM is only sourced when nvm, node, or npm is actually invoked
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

nvm() {
  unset -f nvm node npm
  [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"
  nvm "$@"
}

node() {
  unset -f nvm node npm
  [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
  nvm use default > /dev/null 2>&1 || true
  node "$@"
}

npm() {
  unset -f nvm node npm
  [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
  nvm use default > /dev/null 2>&1 || true
  npm "$@"
}

# ================================= Rust ====================================
[[ -s "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# ================================ conda/miniforge ===========================
# Initialize conda/miniforge if installed but not already in PATH
if ! command -v conda >/dev/null 2>&1; then
  HOMEBREW_PREFIX="$(_detect_brew_prefix)"
  conda_paths=(
    "$HOME/miniforge3/bin/conda"
    "$HOME/miniforge/bin/conda"
    "$HOME/anaconda3/bin/conda"
    "$HOME/anaconda/bin/conda"
    "$HOMEBREW_PREFIX/Caskroom/miniforge/base/bin/conda"
    "$HOMEBREW_PREFIX/Caskroom/anaconda/base/bin/conda"
    "/usr/local/miniforge3/bin/conda"
    "/usr/local/anaconda3/bin/conda"
  )
  
  for conda_path in "${conda_paths[@]}"; do
    if [[ -f "$conda_path" ]]; then
      # Initialize conda for this shell
      # Uses zsh parameter expansion instead of dirname command
      eval "$("${conda_path%/*}/conda" shell.zsh hook 2>/dev/null)" || true
      break
    fi
  done
fi

# ================================ ALIASES ==================================
if command -v colorls >/dev/null 2>&1; then
  alias ls='colorls'
else
  alias ls='ls -G'
fi
alias myip="curl -s ifconfig.me"
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
alias reloadzsh="source ${ZDOTDIR:-$HOME}/.zshrc"
if command -v cot >/dev/null 2>&1; then
  alias change="cot ${ZDOTDIR:-$HOME}/.zshrc"
fi

# MySQL aliases - detect MySQL installation dynamically
_detect_mysql_path() {
  # Check common MySQL installation locations
  local mysql_paths=(
    "$(brew --prefix mysql 2>/dev/null)/support-files/mysql.server"
    "$(brew --prefix mariadb 2>/dev/null)/support-files/mysql.server"
    "/usr/local/mysql/support-files/mysql.server"
    "/opt/homebrew/opt/mysql/support-files/mysql.server"
    "/opt/homebrew/opt/mariadb/support-files/mysql.server"
  )
  
  for path in "${mysql_paths[@]}"; do
    if [[ -f "$path" ]]; then
      # Use zsh parameter expansion instead of dirname command
      echo "${path%/*}"
    return 0
    fi
  done
  
  # Try to find via mysql command
  if command -v mysql >/dev/null 2>&1; then
    local mysql_bin=$(command -v mysql)
    # Use zsh parameter expansion: remove /bin/mysql to get base directory
    local mysql_dir="${mysql_bin%/*/*}"
    if [[ -f "$mysql_dir/support-files/mysql.server" ]]; then
      echo "$mysql_dir"
  return 0
    fi
  fi
  
  echo ""
}

mysql_support_dir="$(_detect_mysql_path)"
if [[ -n "$mysql_support_dir" && -f "$mysql_support_dir/support-files/mysql.server" ]]; then
  alias mysqlstart="sudo $mysql_support_dir/support-files/mysql.server start"
  alias mysqlstop="sudo $mysql_support_dir/support-files/mysql.server stop"
  alias mysqlstatus="sudo $mysql_support_dir/support-files/mysql.server status"
  alias mysqlrestart="sudo $mysql_support_dir/support-files/mysql.server restart"
fi
alias mysqlconnect="mysql -u root -p"

# OpenJDK - detect dynamically
_detect_openjdk_path() {
  local HOMEBREW_PREFIX="$(_detect_brew_prefix)"
  local openjdk_paths=(
    "$HOMEBREW_PREFIX/opt/openjdk/bin"
    "$HOMEBREW_PREFIX/opt/openjdk@*/bin"
    "/usr/libexec/java_home"
  )
  
  for path in "${openjdk_paths[@]}"; do
    if [[ -d "$path" ]]; then
      echo "$path"
    return 0
    fi
  done
  
  # Try via java_home
  if command -v /usr/libexec/java_home >/dev/null 2>&1; then
    local java_home=$(/usr/libexec/java_home 2>/dev/null)
    if [[ -n "$java_home" && -d "$java_home/bin" ]]; then
      echo "$java_home/bin"
      return 0
    fi
  fi
  
        echo ""
}

openjdk_path="$(_detect_openjdk_path)"
if [[ -n "$openjdk_path" && -d "$openjdk_path" ]]; then
  _add_to_path "$openjdk_path"
fi

# ================================ UPDATE ===================================
# Update, verify, and versions functions have been moved to a standalone script
# to keep .zshrc lean and to improve shell startup performance.
# Alias to the maintain-system script:
# Uses XDG_DATA_HOME if set, otherwise fall back to ~/.local/bin
maintain_system_bin="${XDG_DATA_HOME:-$HOME/.local/share}/../bin/maintain-system"
[[ -x "$maintain_system_bin" ]] || maintain_system_bin="$HOME/.local/bin/maintain-system"
if [[ -x "$maintain_system_bin" ]]; then
  alias update="$maintain_system_bin update"
  alias verify="$maintain_system_bin verify"
  alias versions="$maintain_system_bin versions"
fi

# ================================ Swiftly ===================================
# Source swiftly env if available 
if [[ -f "$HOME/.swiftly/env.sh" ]]; then
  source "$HOME/.swiftly/env.sh" 2>/dev/null || true
fi

# ================================ FZF ======================================
fzf_config="${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf.zsh"
[[ -f "$fzf_config" ]] || fzf_config="$HOME/.fzf.zsh"
[[ -f "$fzf_config" ]] && source "$fzf_config"

# ================================ FINAL PATH CLEANUP =======================
# Clean PATH at the very end to catch any duplicates added by plugins or tools
# Final PATH cleanup (must be last)
# Explicitly ensure Homebrew paths come first, then rebuild PATH
# Suppress all output to avoid Powerlevel10k instant prompt warnings
HOMEBREW_PREFIX="$(_detect_brew_prefix)"
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  # Remove Homebrew paths from current PATH temporarily
  # Use command grouping to avoid variable output
  {
    cleaned_path=$(echo "$PATH" | tr ':' '\n' | grep -v "^$HOMEBREW_PREFIX/bin$" | grep -v "^$HOMEBREW_PREFIX/sbin$" | tr '\n' ':' | sed 's/:$//' 2>/dev/null)
    # Rebuild PATH with Homebrew first
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$cleaned_path"
  } >/dev/null 2>&1
else
  # No Homebrew, just clean normally
  export PATH="$(_clean_path)" >/dev/null 2>&1
fi