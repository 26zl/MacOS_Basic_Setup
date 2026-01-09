#!/usr/bin/env zsh
# Quick test script for the project

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# Track if any test fails
test_failed=0

echo "${GREEN}=== Quick Test ===${NC}"
echo "1. Testing syntax..."
if zsh -n install.sh; then
  echo "✅ install.sh OK"
else
  echo "❌ install.sh FAILED"
  test_failed=1
fi

if zsh -n zsh.sh; then
  echo "✅ zsh.sh OK"
else
  echo "❌ zsh.sh FAILED"
  test_failed=1
fi

if zsh -n maintain-system.sh; then
  echo "✅ maintain-system.sh OK"
else
  echo "❌ maintain-system.sh FAILED"
  test_failed=1
fi

echo ""
echo "2. Testing file existence..."
if [[ -f install.sh ]]; then
  echo "✅ install.sh exists"
else
  echo "❌ install.sh missing"
  test_failed=1
fi

if [[ -f zsh.sh ]]; then
  echo "✅ zsh.sh exists"
else
  echo "❌ zsh.sh missing"
  test_failed=1
fi

if [[ -f maintain-system.sh ]]; then
  echo "✅ maintain-system.sh exists"
else
  echo "❌ maintain-system.sh missing"
  test_failed=1
fi

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
  if "$maintain_system_path" versions > /dev/null 2>&1; then
    echo "✅ maintain-system works ($maintain_system_path)"
  else
    echo "❌ maintain-system failed ($maintain_system_path)"
    test_failed=1
  fi
else
  echo "⚠️  maintain-system not installed (run ./install.sh first)"
  # This is a warning, not a failure, so don't set test_failed
fi

echo ""
if [[ $test_failed -eq 0 ]]; then
  echo "${GREEN}=== Test Complete ===${NC}"
  exit 0
else
  echo "${RED}=== Test Complete (with failures) ===${NC}"
  exit 1
fi
