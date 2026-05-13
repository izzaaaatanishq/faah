# Faah

> A small, fast zsh plugin that plays an alert sound when an interactive command exits with a non-zero status.

Perfect for those moments when you're focused elsewhere and a long-running command fails silently.

## Features

- 🔊 Automatic alert sounds for failed commands
- ⚡ Minimal performance overhead
- 🎵 Customizable sound files (WAV format)
- 🎚️ Configurable alert volume and cooldown
- 🎯 GUI settings window for easy configuration
- 🔇 Snooze functionality to temporarily disable alerts
- 🔌 Easy installation with Oh My Zsh or standalone

## Prerequisites

- `zsh` shell
- One of the following audio players: `afplay`, `paplay`, `ffplay`, `mpv`, `cvlc`, `mplayer`, `mpg123`, `mpg321`, `play`, or `aplay`
- Python 3.9+ (for GUI settings, optional)

## Installation

### Oh My Zsh (Recommended)

Clone this repository to your Oh My Zsh custom plugins directory:

```zsh
git clone https://github.com/izzaaaatanishq/faah.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/faah
```

Add `faah` to your plugins list in `~/.zshrc`:

```zsh
plugins=(... faah)
```

Restart zsh:

```zsh
source ~/.zshrc
```

## Quick Start

### Verify Installation

```zsh
faah-status
```

You should see `Hooks: installed`. If hooks are missing, enable them:

```zsh
faah-enable
```

### Test It

Trigger a failed command to hear the alert:

```zsh
false
```

## Commands

| Command | Description |
|---------|-------------|
| `faah-enable` | Enable alerts and install hooks |
| `faah-disable` | Disable alerts and remove hooks |
| `faah-status` | Show current status and configuration |
| `faah-settings` | Open GUI settings window |
| `faah-reload-config` | Reload configuration from file |
| `faah-snooze <seconds>` | Temporarily disable alerts (e.g., `faah-snooze 300`) |
| `faah-clear-snooze` | Re-enable alerts after snoozing |
| `faah-test` | Play the alert sound |

## Configuration

### Using the GUI

Open the settings window:

```zsh
faah-settings
```

Available settings:
- **Enable alerts**: Toggle alerts on/off
- **Alert on exit status**: Alert when commands fail (exit code ≠ 0)
- **Sound file**: Path to a `.wav` audio file
- **Volume**: Alert volume (0-100%)
- **Cooldown**: Minimum time between alerts (seconds)
- **Minimum duration**: Only alert for commands running longer than this (seconds)

Settings are saved to `~/.config/faah/faah.env` and automatically reloaded.

### Manual Configuration

Edit `~/.config/faah/faah.env` directly:

```zsh
_FAAH_ENABLED=1
_FAAH_ALERT_ON_EXIT_CODE=1
_FAAH_SOUND_PATH="/path/to/sound.wav"
_FAAH_VOLUME_PERCENT=70
_FAAH_COOLDOWN_SECONDS=1.5
_FAAH_MIN_DURATION_SECONDS=0
```

Reload your shell to apply changes:

```zsh
faah-reload-config
```

### Sound Files

Only `.wav` format audio files are supported. Some options:
- Use system alert sounds
- Convert MP3/OGG to WAV: `ffmpeg -i input.mp3 output.wav`
- Create your own or find free sounds from resources like [Freesound.org](https://freesound.org)

## Troubleshooting

### Plugin not found

Ensure the plugin directory structure is correct:
- Oh My Zsh: `~/.oh-my-zsh/custom/plugins/faah/faah.plugin.zsh`
- Manual: `~/path/to/faah/zsh/faah.zsh`

### No sound playing

1. Test audio system: `faah-test`
2. Verify sound file exists and is valid WAV
3. Check volume isn't muted: `faah-settings` and verify volume > 0
4. Verify an audio player is installed: Run `which afplay paplay ffplay mpv` to test

### Hooks not installed

Run:

```zsh
faah-enable
```

Check status:

```zsh
faah-status
```

### Sound plays for every command

Adjust the `Minimum duration` setting in `faah-settings` to only alert for longer-running commands.

## How It Works

Faah uses zsh hook functions (`preexec` and `precmd`) to:
1. Capture when commands start
2. Track their exit status
3. Calculate command duration
4. Play an alert sound if conditions are met

## Notes

- Alerts are based on **exit status**, not output. A command that prints "error" but exits with status `0` won't trigger an alert.
- Ignored exit codes and command patterns are hardcoded to prevent accidental disabling of alerts.
- The plugin has minimal performance impact (~1-2ms per command).

## License

MIT

