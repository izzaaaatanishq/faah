# Faah for zsh: alert when an interactive command exits non-zero.
# Source this file from .zshrc.

autoload -Uz add-zsh-hook
zmodload zsh/datetime 2>/dev/null

if typeset -f _faah_preexec >/dev/null; then
  add-zsh-hook -d preexec _faah_preexec 2>/dev/null
  add-zsh-hook -d precmd _faah_precmd 2>/dev/null
fi

typeset -g _FAAH_PLUGIN_DIR="${${(%):-%x}:A:h}"
typeset -g _FAAH_LAST_COMMAND=""
typeset -gi _FAAH_COMMAND_RUNNING=0
typeset -gF _FAAH_COMMAND_STARTED_AT=0
typeset -gF _FAAH_LAST_ALERT_AT=0
typeset -gF _FAAH_SNOOZE_UNTIL=0
typeset -g _FAAH_LAST_INVALID_SOUND_WARNING_PATH=""
typeset -g _FAAH_CONFIG_FILE="${_FAAH_CONFIG_FILE:-}"
typeset -g _FAAH_ENABLED="${_FAAH_ENABLED:-1}"
typeset -g _FAAH_ALERT_ON_EXIT_CODE="${_FAAH_ALERT_ON_EXIT_CODE:-1}"
typeset -g _FAAH_SOUND_PATH="${_FAAH_SOUND_PATH:-}"
typeset -g _FAAH_VOLUME_PERCENT="${_FAAH_VOLUME_PERCENT:-70}"
typeset -g _FAAH_COOLDOWN_SECONDS="${_FAAH_COOLDOWN_SECONDS:-1.5}"
typeset -g _FAAH_MIN_DURATION_SECONDS="${_FAAH_MIN_DURATION_SECONDS:-0}"
typeset -g _FAAH_IGNORE_EXIT_CODES="130"
typeset -g _FAAH_IGNORE_COMMAND_REGEX=""

_faah_config_file() {
  if [[ -n "$_FAAH_CONFIG_FILE" ]]; then
    print -r -- "$_FAAH_CONFIG_FILE"
    return 0
  fi

  if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    print -r -- "${XDG_CONFIG_HOME}/faah/faah.env"
    return 0
  fi

  print -r -- "${HOME:-.}/.config/faah/faah.env"
}

_faah_clear_public_settings() {
  unset FAAH_ENABLED
  unset FAAH_ALERT_ON_EXIT_CODE
  unset FAAH_SOUND_PATH
  unset FAAH_VOLUME
  unset FAAH_VOLUME_PERCENT
  unset FAAH_COOLDOWN_SECONDS
  unset FAAH_MIN_DURATION_SECONDS
  unset FAAH_PLAYER
  unset FAAH_CONFIG_FILE
}

_faah_load_config() {
  local config_file="$(_faah_config_file)"
  if [[ ! -r "$config_file" ]]; then
    _faah_clear_public_settings
    return 0
  fi

  source "$config_file" 2>/dev/null || {
    print -u2 -r -- "faah: failed to load config: $config_file"
    return 1
  }

  _faah_clear_public_settings
}

_faah_bool_enabled() {
  local value="${1:-1}"
  case "${value:l}" in
    0|false|no|off|disabled) return 1 ;;
    *) return 0 ;;
  esac
}

_faah_number_or_default() {
  local value="$1"
  local fallback="$2"
  local numeric_regex='^[0-9]+([.][0-9]+)?$'

  if [[ "$value" =~ $numeric_regex ]]; then
    print -r -- "$value"
    return 0
  fi

  print -r -- "$fallback"
}

_faah_now() {
  if (( ${+EPOCHREALTIME} )); then
    print -r -- "$EPOCHREALTIME"
    return 0
  fi

  if (( ${+EPOCHSECONDS} )); then
    print -r -- "$EPOCHSECONDS"
    return 0
  fi

  date +%s
}

_faah_default_sound_path() {
  local repo_sound="${_FAAH_PLUGIN_DIR:h}/media/faah.wav"
  if [[ -r "$repo_sound" ]]; then
    print -r -- "$repo_sound"
    return 0
  fi

  print -r -- "${_FAAH_PLUGIN_DIR}/faah.wav"
}

_faah_is_wav_path() {
  [[ "${1:l}" == *.wav ]]
}

_faah_sound_path() {
  if [[ -n "$_FAAH_SOUND_PATH" ]]; then
    if _faah_is_wav_path "$_FAAH_SOUND_PATH"; then
      print -r -- "$_FAAH_SOUND_PATH"
      return 0
    fi
  fi

  _faah_default_sound_path
}

_faah_warn_invalid_sound_path_once() {
  [[ -n "$_FAAH_SOUND_PATH" ]] || return 0
  _faah_is_wav_path "$_FAAH_SOUND_PATH" && return 0
  [[ "$_FAAH_LAST_INVALID_SOUND_WARNING_PATH" == "$_FAAH_SOUND_PATH" ]] && return 0

  _FAAH_LAST_INVALID_SOUND_WARNING_PATH="$_FAAH_SOUND_PATH"
  print -u2 -r -- "faah: custom sound path must point to a .wav file. Using default sound."
}

_faah_select_player() {
  local player
  for player in afplay paplay ffplay mpv cvlc mplayer mpg123 mpg321 play aplay; do
    if (( $+commands[$player] )); then
      print -r -- "$player"
      return 0
    fi
  done

  return 1
}

_faah_clamped_volume() {
  local raw_value="${_FAAH_VOLUME_PERCENT:-70}"
  local value=100
  local numeric_regex='^-?[0-9]+([.][0-9]+)?$'

  if [[ "$raw_value" =~ $numeric_regex ]]; then
    value="$raw_value"
  fi

  if (( value < 0 )); then
    print -r -- 0
  elif (( value > 100 )); then
    print -r -- 100
  else
    print -r -- "${value%.*}"
  fi
}

_faah_play() {
  _faah_warn_invalid_sound_path_once

  local sound_path="$(_faah_sound_path)"
  if [[ ! -r "$sound_path" ]]; then
    print -u2 -r -- "faah: sound file not found: $sound_path"
    return 1
  fi

  local volume="$(_faah_clamped_volume)"
  (( volume <= 0 )) && return 0

  local player
  player="$(_faah_select_player)" || {
    print -u2 -r -- "faah: no audio player found. Install afplay, paplay, ffplay, mpv, mpg123, sox/play, or aplay."
    return 1
  }

  local -a args
  local ratio
  ratio="$(printf "%.2f" "$(( volume / 100.0 ))")"

  case "$player" in
    afplay)
      args=(-v "$ratio" "$sound_path")
      ;;
    paplay)
      args=(--volume="$(( volume * 65536 / 100 ))" "$sound_path")
      ;;
    ffplay)
      args=(-nodisp -autoexit -loglevel quiet -volume "$volume" "$sound_path")
      ;;
    mpv)
      args=(--no-video --really-quiet --volume="$volume" "$sound_path")
      ;;
    cvlc)
      args=(--play-and-exit --gain "$ratio" "$sound_path")
      ;;
    mplayer)
      args=(-really-quiet -volume "$volume" "$sound_path")
      ;;
    mpg123|mpg321)
      args=(-q -f "$(( volume * 32768 / 100 ))" "$sound_path")
      ;;
    play)
      args=(-q "$sound_path" vol "$ratio")
      ;;
    *)
      args=("$sound_path")
      ;;
  esac

  "$player" "${args[@]}" >/dev/null 2>&1 &!
}

_faah_exit_code_ignored() {
  local exit_status="$1"
  local ignored="$_FAAH_IGNORE_EXIT_CODES"
  local normalized="${ignored//,/ }"
  local code

  for code in ${(s: :)normalized}; do
    [[ "$code" == "$exit_status" ]] && return 0
  done

  return 1
}

_faah_command_ignored() {
  [[ -z "$_FAAH_IGNORE_COMMAND_REGEX" ]] && return 1
  [[ "$1" =~ $_FAAH_IGNORE_COMMAND_REGEX ]]
}

_faah_should_alert() {
  local exit_status="$1"
  local command_text="$2"
  local started_at="$3"
  local now cooldown min_duration

  _faah_bool_enabled "$_FAAH_ENABLED" || return 1
  _faah_bool_enabled "$_FAAH_ALERT_ON_EXIT_CODE" || return 1
  (( exit_status == 0 )) && return 1
  _faah_exit_code_ignored "$exit_status" && return 1
  _faah_command_ignored "$command_text" && return 1

  now="$(_faah_now)"

  if (( _FAAH_SNOOZE_UNTIL > now )); then
    return 1
  fi

  cooldown="$(_faah_number_or_default "$_FAAH_COOLDOWN_SECONDS" 1.5)"
  if (( now - _FAAH_LAST_ALERT_AT < cooldown )); then
    return 1
  fi

  min_duration="$(_faah_number_or_default "$_FAAH_MIN_DURATION_SECONDS" 0)"
  if (( min_duration > 0 && now - started_at < min_duration )); then
    return 1
  fi

  _FAAH_LAST_ALERT_AT="$now"
  return 0
}

_faah_preexec() {
  _FAAH_LAST_COMMAND="$1"
  _FAAH_COMMAND_STARTED_AT="$(_faah_now)"
  _FAAH_COMMAND_RUNNING=1
}

_faah_precmd() {
  local last_status=$?

  if (( _FAAH_COMMAND_RUNNING )); then
    _FAAH_COMMAND_RUNNING=0
    if _faah_should_alert "$last_status" "$_FAAH_LAST_COMMAND" "$_FAAH_COMMAND_STARTED_AT"; then
      _faah_play
    fi
  fi

  return "$last_status"
}

_faah_install_hooks() {
  autoload -Uz add-zsh-hook
  add-zsh-hook -d preexec _faah_preexec 2>/dev/null
  add-zsh-hook -d precmd _faah_precmd 2>/dev/null

  preexec_functions=(_faah_preexec ${preexec_functions:#_faah_preexec})
  precmd_functions=(_faah_precmd ${precmd_functions:#_faah_precmd})
}

_faah_uninstall_hooks() {
  autoload -Uz add-zsh-hook
  add-zsh-hook -d preexec _faah_preexec 2>/dev/null
  add-zsh-hook -d precmd _faah_precmd 2>/dev/null
  preexec_functions=(${preexec_functions:#_faah_preexec})
  precmd_functions=(${precmd_functions:#_faah_precmd})
}

_faah_write_config() {
  local config_file="$(_faah_config_file)"
  local temp_file
  mkdir -p "${config_file:h}"
  temp_file=$(mktemp "${config_file}.tmp.XXXXXX") || return 1

  if [[ -f "$config_file" ]]; then
    local line
    local had_enabled=0

    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        export\ _FAAH_ENABLED=* )
          print -r -- "export _FAAH_ENABLED=$_FAAH_ENABLED" ; had_enabled=1 ;;
        _FAAH_ENABLED=* )
          print -r -- "_FAAH_ENABLED=$_FAAH_ENABLED" ; had_enabled=1 ;;
        *)
          print -r -- "$line" ;;
      esac
    done < "$config_file" > "$temp_file"

    if (( had_enabled == 0 )); then
      print -r -- "_FAAH_ENABLED=$_FAAH_ENABLED" >> "$temp_file"
    fi
  else
    cat > "$temp_file" << EOF
# Faah zsh settings
_FAAH_ENABLED=$_FAAH_ENABLED
EOF
  fi

  mv "$temp_file" "$config_file"
}

_faah_hook_state() {
  local has_preexec=0
  local has_precmd=0

  (( ${preexec_functions[(Ie)_faah_preexec]} > 0 )) && has_preexec=1
  (( ${precmd_functions[(Ie)_faah_precmd]} > 0 )) && has_precmd=1

  if (( has_preexec && has_precmd )); then
    print -r -- "installed"
  else
    print -r -- "missing"
  fi
}

faah-enable() {
  typeset -g _FAAH_ENABLED=1
  _faah_write_config
  _faah_install_hooks
  print -r -- "✓ Faah alerts enabled globally."
}

faah-disable() {
  typeset -g _FAAH_ENABLED=0
  _faah_write_config
  _faah_uninstall_hooks
  print -r -- "✓ Faah alerts disabled globally."
}

faah-snooze() {
  local minutes="$(_faah_number_or_default "${1:-15}" 15)"
  local now="$(_faah_now)"
  _FAAH_SNOOZE_UNTIL="$(( now + minutes * 60 ))"
  print -r -- "Faah zsh alerts snoozed for ${minutes} minute(s)."
}

faah-clear-snooze() {
  _FAAH_SNOOZE_UNTIL=0
  print -r -- "Faah zsh snooze cleared."
}

faah-reload-config() {
  _faah_load_config
  _faah_install_hooks
  print -r -- "Faah settings reloaded from $(_faah_config_file)."
}

faah-settings() {
  local gui_script="${_FAAH_PLUGIN_DIR:h}/gui/faah-settings.py"
  local config_file="$(_faah_config_file)"
  local exit_code

  if [[ ! -r "$gui_script" ]]; then
    print -u2 -r -- "faah: settings GUI not found: $gui_script"
    return 1
  fi

  if (( !$+commands[python3] )); then
    print -u2 -r -- "faah: python3 is required to open the settings GUI."
    return 1
  fi

  python3 "$gui_script" \
    --config "$config_file" \
    --plugin-root "${_FAAH_PLUGIN_DIR:h}" \
    "$@"
  exit_code=$?

  if (( exit_code == 0 )); then
    _faah_load_config
    _faah_install_hooks
  fi

  return "$exit_code"
}

faah-test() {
  _faah_play
}

faah-status() {
  local state="enabled"
  _faah_bool_enabled "$_FAAH_ENABLED" || state="disabled"

  print -r -- "Faah zsh plugin: $state"
  print -r -- "Hooks: $(_faah_hook_state)"
  print -r -- "Config: $(_faah_config_file)"
  print -r -- "preexec_functions: ${preexec_functions:-<empty>}"
  print -r -- "precmd_functions: ${precmd_functions:-<empty>}"
  print -r -- "Sound: $(_faah_sound_path)"
  print -r -- "Player: $(_faah_select_player 2>/dev/null || print -r -- unavailable)"
  print -r -- "Cooldown: ${_FAAH_COOLDOWN_SECONDS:-1.5}s"
  print -r -- "Minimum duration: ${_FAAH_MIN_DURATION_SECONDS:-0}s"
  print -r -- "Ignored exit codes: ${_FAAH_IGNORE_EXIT_CODES}"
  return 0
}

_faah_load_config
_faah_install_hooks
