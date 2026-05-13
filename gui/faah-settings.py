#!/usr/bin/env python3
"""Small Tkinter settings window for the Faah zsh plugin."""

from __future__ import annotations

import argparse
import os
import re
import shlex
import subprocess
from pathlib import Path
from tkinter import (
    BooleanVar,
    IntVar,
    StringVar,
    TclError,
    Tk,
    filedialog,
    messagebox,
)
from tkinter import ttk


CONFIG_KEYS = [
    "_FAAH_ENABLED",
    "_FAAH_ALERT_ON_EXIT_CODE",
    "_FAAH_SOUND_PATH",
    "_FAAH_VOLUME_PERCENT",
    "_FAAH_COOLDOWN_SECONDS",
    "_FAAH_MIN_DURATION_SECONDS",
    "_FAAH_IGNORE_EXIT_CODES",
    "_FAAH_IGNORE_COMMAND_REGEX",
]

DEFAULTS = {
    "_FAAH_ENABLED": "1",
    "_FAAH_ALERT_ON_EXIT_CODE": "1",
    "_FAAH_SOUND_PATH": "",
    "_FAAH_VOLUME_PERCENT": "70",
    "_FAAH_COOLDOWN_SECONDS": "1.5",
    "_FAAH_MIN_DURATION_SECONDS": "0",
    "_FAAH_IGNORE_EXIT_CODES": "130",
    "_FAAH_IGNORE_COMMAND_REGEX": "",
}

EXIT_CODES_RE = re.compile(r"^\s*\d+(\s*[, ]\s*\d+)*\s*$")
WAV_SUFFIX = ".wav"


def default_config_file() -> Path:
    config_home = os.environ.get("XDG_CONFIG_HOME")
    if config_home:
        return Path(config_home).expanduser() / "faah" / "faah.env"

    return Path.home() / ".config" / "faah" / "faah.env"


def unquote_shell_value(value: str) -> str:
    try:
        parts = shlex.split(value, comments=False, posix=True)
    except ValueError:
        return value.strip().strip("\"'")

    return parts[0] if parts else ""


def load_config(path: Path) -> dict[str, str]:
    values = DEFAULTS.copy()
    if not path.is_file():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        if "=" not in line:
            continue
        key, raw_value = line.split("=", 1)
        key = key.strip()
        if key in values:
            values[key] = unquote_shell_value(raw_value.strip())

    return values


def initial_values(path: Path) -> dict[str, str]:
    return load_config(path)


def shell_bool(value: str) -> bool:
    return value.strip().lower() not in {"0", "false", "no", "off", "disabled"}


def bool_text(value: bool) -> str:
    return "1" if value else "0"


def normalize_exit_codes(value: str) -> str:
    codes = [part for part in re.split(r"[, ]+", value.strip()) if part]
    return " ".join(codes)


def write_config(path: Path, values: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Faah zsh settings. Edit with `faah-settings`.",
        "# This file is sourced by zsh, so values are shell-quoted.",
        "",
    ]
    for key in CONFIG_KEYS:
        lines.append(f"{key}={shlex.quote(values.get(key, DEFAULTS[key]))}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


class FaahSettingsWindow:
    def __init__(self, root: Tk, config_path: Path, plugin_root: Path) -> None:
        self.root = root
        self.config_path = config_path
        self.plugin_root = plugin_root
        self.values = initial_values(config_path)

        self.enabled = BooleanVar(value=shell_bool(self.values["_FAAH_ENABLED"]))
        self.alert_on_exit = BooleanVar(
            value=shell_bool(self.values["_FAAH_ALERT_ON_EXIT_CODE"])
        )
        self.sound_path = StringVar(value=self.values["_FAAH_SOUND_PATH"])
        self.volume = IntVar(value=self.safe_int(self.values["_FAAH_VOLUME_PERCENT"], 70))
        self.cooldown = StringVar(value=self.values["_FAAH_COOLDOWN_SECONDS"])
        self.min_duration = StringVar(value=self.values["_FAAH_MIN_DURATION_SECONDS"])
        self.ignore_exit_codes = StringVar(value=self.values["_FAAH_IGNORE_EXIT_CODES"])
        self.ignore_command_regex = StringVar(
            value=self.values["_FAAH_IGNORE_COMMAND_REGEX"]
        )
        self.status_text = StringVar(value=f"Settings file: {self.config_path}")

        self.build()

    @staticmethod
    def safe_int(value: str, fallback: int) -> int:
        try:
            return max(0, min(100, int(float(value))))
        except ValueError:
            return fallback

    def build(self) -> None:
        self.root.title("Faah Settings")
        self.root.minsize(560, 560)

        frame = ttk.Frame(self.root, padding=18)
        frame.grid(row=0, column=0, sticky="nsew")
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        frame.columnconfigure(1, weight=1)

        title = ttk.Label(frame, text="Faah Settings", font=("", 18, "bold"))
        title.grid(row=0, column=0, columnspan=3, sticky="w", pady=(0, 12))

        ttk.Checkbutton(frame, text="Enable alerts", variable=self.enabled).grid(
            row=1, column=0, columnspan=3, sticky="w"
        )
        ttk.Checkbutton(
            frame,
            text="Alert on non-zero command exit status",
            variable=self.alert_on_exit,
        ).grid(row=2, column=0, columnspan=3, sticky="w", pady=(0, 12))

        self.entry_row(frame, 3, "Sound file", self.sound_path)
        ttk.Button(frame, text="Browse", command=self.browse_sound).grid(
            row=3, column=2, sticky="ew", padx=(8, 0)
        )

        ttk.Label(frame, text="Volume").grid(row=4, column=0, sticky="w", pady=(12, 4))
        volume_frame = ttk.Frame(frame)
        volume_frame.grid(row=4, column=1, columnspan=2, sticky="ew", pady=(12, 4))
        volume_frame.columnconfigure(0, weight=1)
        ttk.Scale(
            volume_frame,
            from_=0,
            to=100,
            orient="horizontal",
            variable=self.volume,
        ).grid(row=0, column=0, sticky="ew")
        ttk.Spinbox(
            volume_frame,
            from_=0,
            to=100,
            textvariable=self.volume,
            width=5,
        ).grid(row=0, column=1, sticky="e", padx=(8, 0))

        self.entry_row(frame, 5, "Cooldown seconds", self.cooldown)
        self.entry_row(frame, 6, "Minimum duration", self.min_duration)
        self.entry_row(frame, 7, "Ignored exit codes", self.ignore_exit_codes)
        self.entry_row(frame, 8, "Ignore command regex", self.ignore_command_regex)

        buttons = ttk.Frame(frame)
        buttons.grid(row=9, column=0, columnspan=3, sticky="ew", pady=(22, 8))
        buttons.columnconfigure(0, weight=1)
        ttk.Button(buttons, text="Test Sound", command=self.test_sound).grid(
            row=0, column=0, sticky="w"
        )
        ttk.Button(buttons, text="Save", command=self.save).grid(
            row=0, column=1, sticky="e", padx=(8, 0)
        )
        ttk.Button(buttons, text="Save & Close", command=self.save_and_close).grid(
            row=0, column=2, sticky="e", padx=(8, 0)
        )

        ttk.Label(frame, textvariable=self.status_text, foreground="#555").grid(
            row=10, column=0, columnspan=3, sticky="w", pady=(10, 0)
        )

        for child in frame.winfo_children():
            child.grid_configure(pady=4)

    def entry_row(
        self, frame: ttk.Frame, row: int, label: str, variable: StringVar
    ) -> None:
        ttk.Label(frame, text=label).grid(row=row, column=0, sticky="w")
        ttk.Entry(frame, textvariable=variable).grid(
            row=row, column=1, columnspan=2, sticky="ew"
        )

    def browse_sound(self) -> None:
        path = filedialog.askopenfilename(
            title="Choose alert sound",
            filetypes=[
                ("WAV files", "*.wav *.WAV"),
            ],
        )
        if path:
            self.sound_path.set(path)

    def validate(self) -> dict[str, str] | None:
        sound_path = self.sound_path.get().strip()
        if sound_path:
            resolved_sound_path = Path(sound_path).expanduser()
            if resolved_sound_path.suffix.lower() != WAV_SUFFIX:
                messagebox.showerror("Invalid Sound File", "Only .wav files are allowed.")
                return None
            if not resolved_sound_path.is_file():
                messagebox.showerror(
                    "Invalid Sound File", "The selected sound file does not exist."
                )
                return None

        cooldown = self.cooldown.get().strip()
        min_duration = self.min_duration.get().strip()
        for label, value in [
            ("Cooldown seconds", cooldown),
            ("Minimum duration", min_duration),
        ]:
            try:
                if float(value) < 0:
                    raise ValueError
            except ValueError:
                messagebox.showerror("Invalid Number", f"{label} must be 0 or higher.")
                return None

        ignored = self.ignore_exit_codes.get().strip()
        if ignored and not EXIT_CODES_RE.match(ignored):
            messagebox.showerror(
                "Invalid Exit Codes",
                "Ignored exit codes must be numbers separated by spaces or commas.",
            )
            return None

        try:
            volume = max(0, min(100, int(float(self.volume.get()))))
        except (TclError, ValueError):
            messagebox.showerror("Invalid Volume", "Volume must be a number from 0 to 100.")
            return None

        return {
            "_FAAH_ENABLED": bool_text(self.enabled.get()),
            "_FAAH_ALERT_ON_EXIT_CODE": bool_text(self.alert_on_exit.get()),
            "_FAAH_SOUND_PATH": sound_path,
            "_FAAH_VOLUME_PERCENT": str(volume),
            "_FAAH_COOLDOWN_SECONDS": cooldown,
            "_FAAH_MIN_DURATION_SECONDS": min_duration,
            "_FAAH_IGNORE_EXIT_CODES": normalize_exit_codes(ignored),
            "_FAAH_IGNORE_COMMAND_REGEX": self.ignore_command_regex.get().strip(),
        }

    def save(self) -> bool:
        values = self.validate()
        if values is None:
            return False

        try:
            write_config(self.config_path, values)
        except OSError as exc:
            messagebox.showerror("Save Failed", str(exc))
            return False

        self.status_text.set(f"Saved: {self.config_path}")
        return True

    def save_and_close(self) -> None:
        if self.save():
            self.root.destroy()

    def test_sound(self) -> None:
        if not self.save():
            return

        plugin_file = self.plugin_root / "zsh" / "faah.zsh"
        if not plugin_file.is_file():
            messagebox.showerror("Test Failed", f"Plugin file not found: {plugin_file}")
            return

        command = (
            f"_FAAH_CONFIG_FILE={shlex.quote(str(self.config_path))}; "
            f"source {shlex.quote(str(plugin_file))}; "
            "_faah_load_config; _faah_play"
        )
        try:
            subprocess.Popen(
                ["zsh", "-fc", command],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError as exc:
            messagebox.showerror("Test Failed", str(exc))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Open the Faah settings GUI.")
    parser.add_argument("--check", action="store_true", help="Validate imports and exit.")
    parser.add_argument(
        "--config",
        type=Path,
        default=default_config_file(),
        help="Settings file to read and write.",
    )
    parser.add_argument(
        "--plugin-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Faah checkout root.",
    )
    parser.add_argument(
        "--print-config",
        action="store_true",
        help="Print the resolved settings file path and exit.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config_path = args.config.expanduser()
    plugin_root = args.plugin_root.expanduser()

    if args.check:
        print("faah-settings ok")
        return 0

    if args.print_config:
        print(config_path)
        return 0

    root = Tk()
    FaahSettingsWindow(root, config_path, plugin_root)
    root.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
