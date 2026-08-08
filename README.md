# laplap

macOS keyboard-lock utility: locks the keyboard, trackpad, and mouse so a cat
cannot type. Input returns the moment the process exits (no daemon, no
persistence).

## Usage

```sh
swift build -c release
~/.local/bin/laplap cat    # or the release binary path
```

`laplap cat` blocks all input until Command is pressed 6 times within 10
seconds (CMD×6), or until the process is killed.

## Permissions

laplap needs **Accessibility** permission to intercept input. On first run it
raises the system prompt; if you decline, it opens the System Settings privacy
pane and waits up to 60 seconds for you to grant access before giving up.

Grant it in **System Settings → Privacy & Security → Accessibility**.

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | Lock released (CMD×6 or signal) or help shown |
| 2    | Usage error (no mode, or unknown mode) |
| 3    | Accessibility permission not granted |
