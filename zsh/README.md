# Faah zsh Plugin

This directory contains the shell plugin entry point.

```zsh
source /path/to/faah/zsh/faah.zsh
```

The plugin uses zsh `preexec` and `precmd` hooks to detect when an interactive command exits with a non-zero status.

Run `faah-settings` after sourcing the plugin to open the settings GUI.

For full setup and configuration, see the root [README.md](../README.md).
