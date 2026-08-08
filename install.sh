#!/usr/bin/env bash
set -euo pipefail

# laplap installer: builds the release binary and installs it to
# ~/.local/bin/laplap, falling back to /usr/local/bin/laplap when
# ~/.local/bin is not writable. Idempotent: re-running overwrites
# the prior install. No Homebrew, no signing, no daemon.

swift build -c release

# --show-bin-path resolves the arch-specific build dir
# (.build/release or .build/arm64-apple-macosx/release).
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/laplap"

if [ ! -x "$BIN_PATH" ]; then
  echo "error: build did not produce a binary at $BIN_PATH" >&2
  exit 1
fi

install_dir="$HOME/.local/bin"
if ! mkdir -p "$install_dir" 2>/dev/null || [ ! -w "$install_dir" ]; then
  if [ -w /usr/local/bin ]; then
    install_dir=/usr/local/bin
  else
    echo "error: no writable install location (tried $HOME/.local/bin and /usr/local/bin)" >&2
    echo "hint: install manually, or add write permission to one of those directories" >&2
    exit 1
  fi
fi

mkdir -p "$install_dir"
cp "$BIN_PATH" "$install_dir/laplap"
chmod +x "$install_dir/laplap"

echo "Installed laplap to $install_dir/laplap"
echo
echo "First run: grant Accessibility permission when macOS prompts"
echo "(System Settings → Privacy & Security → Accessibility)."
echo "To unlock a lock: press Command 6 times within 10 seconds (CMD×6)."
