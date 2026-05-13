# Faah

Faah is a small zsh plugin that plays an alert sound when an interactive command exits with a non-zero status.

It is meant for the tiny moments where a command fails while your attention has already wandered somewhere else.

## Install

Source the plugin from this checkout:

```zsh
source /path/to/faah/zsh/faah.zsh
```

For a permanent install, add the source line near the end of `~/.zshrc`:

```zsh
source /path/to/faah/zsh/faah.zsh
```

Then restart zsh or run:

```zsh
source ~/.zshrc
```

## Check Setup

```zsh
faah-status
```

You should see `Hooks: installed`. If hooks are missing, run:

```zsh
faah-enable
```

Then test an error:

```zsh
false
```

## Commands

```zsh
faah-enable
faah-disable
faah-snooze 15
faah-clear-snooze
faah-test
faah-status
```

## Configuration

Set these before or after sourcing `zsh/faah.zsh`:

```zsh
export FAAH_SOUND_PATH=/path/to/faah.wav
export FAAH_VOLUME_PERCENT=70
export FAAH_COOLDOWN_SECONDS=1.5
export FAAH_MIN_DURATION_SECONDS=0
export FAAH_IGNORE_EXIT_CODES="130"
export FAAH_IGNORE_COMMAND_REGEX='^(grep|test|\\[)'
export FAAH_QUIET_HOURS="22:00-07:00"
```

Audio playback uses the first available player from `afplay`, `paplay`, `ffplay`, `mpv`, `cvlc`, `mplayer`, `mpg123`, `mpg321`, `play`, or `aplay`. Override detection with `FAAH_PLAYER`.

## Notes

Faah alerts on command exit status. A command that prints the word `error` but exits with status `0` will not trigger an alert.

## License

MIT
