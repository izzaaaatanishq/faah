# Faah zsh Plugin

Faah's VS Code extension uses VS Code terminal shell execution APIs. This zsh plugin is the shell-native companion: it plays the Faah sound when an interactive command exits with a non-zero status.

The zsh plugin is exit-code based. It does not inspect every command's stdout/stderr stream; the VS Code extension remains the right place for regex output matching.

## Install

From this repo checkout:

```zsh
source /path/to/faah/zsh/faah.zsh
```

For a permanent install, add that line to `~/.zshrc`.
Put it near the end of `~/.zshrc` so shell frameworks and themes do not overwrite the hook arrays after Faah loads.

## Commands

```zsh
faah-enable
faah-disable
faah-snooze 15
faah-clear-snooze
faah-test
faah-status
```

`faah-status` should show `Hooks: installed`. If it shows `Hooks: missing`, run `faah-enable` or move the `source` line later in `~/.zshrc`.

## Configuration

Set these before sourcing `zsh/faah.zsh`, or later in the same shell:

```zsh
export FAAH_SOUND_PATH=/path/to/faah.wav
export FAAH_VOLUME_PERCENT=70
export FAAH_COOLDOWN_SECONDS=1.5
export FAAH_MIN_DURATION_SECONDS=0
export FAAH_IGNORE_EXIT_CODES="130"
export FAAH_IGNORE_COMMAND_REGEX='^(grep|test|\\[)'
export FAAH_QUIET_HOURS="22:00-07:00"
```

Audio playback uses the first available player from: `afplay`, `paplay`, `ffplay`, `mpv`, `cvlc`, `mplayer`, `mpg123`, `mpg321`, `play`, or `aplay`. Override detection with `FAAH_PLAYER`.

When using this inside the VS Code integrated terminal, avoid enabling both the zsh plugin and VS Code terminal monitoring unless you want duplicate alerts.
