#!/usr/bin/env zsh
# Quick test script for the project

echo "=== Quick Test ==="
echo "1. Testing syntax..."
zsh -n install.sh && echo "✅ install.sh OK" || echo "❌ install.sh FAILED"
zsh -n zsh.sh && echo "✅ zsh.sh OK" || echo "❌ zsh.sh FAILED"
zsh -n maintain-system.sh && echo "✅ maintain-system.sh OK" || echo "❌ maintain-system.sh FAILED"

echo ""
echo "2. Testing file existence..."
[[ -f install.sh ]] && echo "✅ install.sh exists" || echo "❌ install.sh missing"
[[ -f zsh.sh ]] && echo "✅ zsh.sh exists" || echo "❌ zsh.sh missing"
[[ -f maintain-system.sh ]] && echo "✅ maintain-system.sh exists" || echo "❌ maintain-system.sh missing"

echo ""
echo "3. Testing maintain-system script..."
get_maintain_system_path() {
  local local_bin="${XDG_DATA_HOME:-$HOME/.local/share}/../bin"
  [[ -d "$local_bin" ]] || local_bin="$HOME/.local/bin"

  if [[ -x "$local_bin/maintain-system" ]]; then
    echo "$local_bin/maintain-system"
    return 0
  fi

  if command -v maintain-system >/dev/null 2>&1; then
    command -v maintain-system
    return 0
  fi

  return 1
}

maintain_system_path="$(get_maintain_system_path || true)"
if [[ -n "$maintain_system_path" ]]; then
  "$maintain_system_path" versions > /dev/null 2>&1 && echo "✅ maintain-system works ($maintain_system_path)" || echo "❌ maintain-system failed ($maintain_system_path)"
else
  echo "⚠️  maintain-system not installed (run ./install.sh first)"
fi

echo ""
echo "=== Test Complete ==="
