# laplap

**laplap** is a tiny macOS utility that locks your keyboard, trackpad, and
mouse — so a cat on the desk can't type, click, or scroll. Screen stays on,
input goes nowhere. Press **CMD 6 times within 10 seconds (CMD×6)** to unlock,
or just kill the process.

Built with Swift and SwiftPM. Zero external dependencies. No daemon, no
background process, no persistence — input returns the moment the process
exits.

## Installation

### Quick install

```sh
./install.sh
```

Builds the release binary and installs it to `~/.local/bin/laplap`, falling
back to `/usr/local/bin/laplap` when `~/.local/bin` is not writable. Re-running
it simply overwrites the previous install (idempotent). No Homebrew, no code
signing, no daemon.

### Manual build

```sh
swift build -c release
# binary is at .build/release/laplap
.build/release/laplap cat
```

Tests:

```sh
swift test
```

## Usage

```
laplap <mode>
```

| Mode        | What it does |
|-------------|--------------|
| `laplap cat`    | Locks keyboard, trackpad, and external mouse. The screen stays visible. Unlock with CMD×6 or kill the process. |
| `laplap clean`  | Same input lock behind a fullscreen black overlay with centered exit instructions and a hidden cursor. Unlock with CMD×6. |
| `laplap settings` | Opens **System Settings → Privacy & Security → Accessibility** and prints step-by-step grant guidance. |
| `laplap --help` | Shows usage. |

### Unlocking

Press **Command 6 times within 10 seconds** (CMD×6). The lock also releases
immediately if the process is terminated.

## Requirements

- **macOS 13+** (Ventura or later)
- **Accessibility permission**

laplap intercepts input with a `CGEventTap`, which macOS requires the
**Accessibility** permission for. On first run it raises the system prompt; if
you decline, it opens the System Settings privacy pane and waits up to 60
seconds for you to grant access before giving up.

Grant it manually in **System Settings → Privacy & Security → Accessibility**
(toggle laplap — or your terminal app — ON). Or run:

```sh
laplap settings
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0    | Lock released (CMD×6 or signal), or help shown |
| 1    | Could not open System Settings |
| 2    | Usage error (no mode, or unknown mode) |
| 3    | Accessibility permission not granted |

## How it works

laplap installs a low-level `CGEventTap` that consumes keyboard and mouse
events — nothing reaches the system while the lock is active. It is a plain
foreground process with **zero dependencies** and **no daemon**: input returns
the instant the process exits, and nothing persists between runs.

## Safety

laplap **never stores, logs, or transmits your keystrokes**. It only consumes
them to keep them from reaching the system, and it forgets everything the
moment you unlock.
