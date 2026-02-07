# Troubleshooting

Common installation and runtime issues.

## Ubuntu 24.04: `EXDEV: cross-device link not permitted` during `/plugin install`

### Symptom

Plugin installation fails with an error similar to:

```
EXDEV: cross-device link not permitted, rename '.../.claude/plugins/cache/...' -> '/tmp/claude-plugin-temp-...'
```

### Why it happens

Claude Code's plugin installer attempts to move a plugin directory from `~/.claude/...` into `/tmp/...` using `rename()`.
On many Linux systems (including Ubuntu 24.04), `/tmp` is mounted as `tmpfs` (a different filesystem/device), so cross-device `rename()` fails with `EXDEV`.

### Fix (recommended)

Set a temporary directory on the same filesystem as your `~/.claude` (usually under `$HOME`) and start Claude Code from that environment:

```bash
mkdir -p "$HOME/.claude/tmp"
TMPDIR="$HOME/.claude/tmp" claude
```

Then retry:

```text
/plugin install claude-notifications-go@claude-notifications-go
```

### Diagnostics (optional)

```bash
df -T "$HOME" /tmp
mount | grep -E ' on /tmp | on /home '
```

If `/tmp` is `tmpfs` (or otherwise on a different device) and `$HOME` is on `ext4/btrfs/...`, the error is expected without the `TMPDIR` workaround.

## Windows: install issues related to `%TEMP%` / `%TMP%` location

If your temp directory is on a different drive than your user profile (or where Claude stores plugin cache), you may see similar cross-device move issues.

### Fix

Make sure `%TEMP%` and `%TMP%` point to a directory on the same drive as `%USERPROFILE%` (or where Claude stores its plugin directories), then restart your terminal/app.

