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

### Oh My Zsh

Clone this repository to your Oh My Zsh custom plugins directory:

```zsh
git clone https://github.com/kiron0/faah.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/faah
```

Then add `faah` to your plugins list in `~/.zshrc`:

```zsh
plugins=(... faah)
```

Restart zsh or run:

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
faah-settings
faah-reload-config
faah-snooze 15
faah-clear-snooze
faah-test
faah-status
```

`faah-settings` opens a small GUI window for changing settings. It saves to `~/.config/faah/faah.env` by default, then reloads the current shell after the window closes.

## Configuration

Faah uses defaults from `zsh/faah.zsh` until you save settings from the GUI.

```zsh
faah-settings
```

The GUI saves to `~/.config/faah/faah.env`. The plugin reloads that file on startup and after the GUI closes.

Audio playback auto-detects the first available player from `afplay`, `paplay`, `ffplay`, `mpv`, `cvlc`, `mplayer`, `mpg123`, `mpg321`, `play`, or `aplay`.

Only `.wav` sound files are allowed.

## Notes

Faah alerts on command exit status. A command that prints the word `error` but exits with status `0` will not trigger an alert.

## License

MIT
