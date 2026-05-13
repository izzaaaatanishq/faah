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

_faah_sound_path() {
  if [[ -n "${FAAH_SOUND_PATH:-}" ]]; then
    print -r -- "$FAAH_SOUND_PATH"
    return 0
  fi

  local repo_sound="${_FAAH_PLUGIN_DIR:h}/media/faah.wav"
  if [[ -r "$repo_sound" ]]; then
    print -r -- "$repo_sound"
    return 0
  fi

  print -r -- "${_FAAH_PLUGIN_DIR}/faah.wav"
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
  local raw_value="${FAAH_VOLUME_PERCENT:-${FAAH_VOLUME:-70}}"
  local value=70
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
  local sound_path="$(_faah_sound_path)"
  if [[ ! -r "$sound_path" ]]; then
    print -u2 -r -- "faah: sound file not found: $sound_path"
    return 1
  fi

  local volume="$(_faah_clamped_volume)"
  (( volume <= 0 )) && return 0

  local player="${FAAH_PLAYER:-}"
  if [[ -z "$player" ]]; then
    player="$(_faah_select_player)" || {
      print -u2 -r -- "faah: no audio player found. Install afplay, paplay, ffplay, mpv, mpg123, sox/play, or aplay."
      return 1
    }
  elif (( !$+commands[$player] )) && [[ ! -x "$player" ]]; then
    print -u2 -r -- "faah: configured audio player not found: $player"
    return 1
  fi

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
  local ignored="${FAAH_IGNORE_EXIT_CODES:-130}"
  local normalized="${ignored//,/ }"
  local code

  for code in ${(s: :)normalized}; do
    [[ "$code" == "$exit_status" ]] && return 0
  done

  return 1
}

_faah_command_ignored() {
  [[ -z "${FAAH_IGNORE_COMMAND_REGEX:-}" ]] && return 1
  [[ "$1" =~ $FAAH_IGNORE_COMMAND_REGEX ]]
}

_faah_time_to_minutes() {
  local value="$1"
  local time_regex='^([01]?[0-9]|2[0-3]):[0-5][0-9]$'
  [[ "$value" =~ $time_regex ]] || return 1

  local hours="${value%%:*}"
  local minutes="${value#*:}"
  print -r -- "$(( 10#$hours * 60 + 10#$minutes ))"
}

_faah_current_minutes() {
  local current_time
  if (( ${+builtins[strftime]} && ${+EPOCHSECONDS} )); then
    strftime -s current_time "%H:%M" "$EPOCHSECONDS"
  else
    current_time="$(date +%H:%M)"
  fi

  _faah_time_to_minutes "$current_time"
}

_faah_quiet_hours_active() {
  local range="${FAAH_QUIET_HOURS:-}"
  [[ -z "$range" ]] && return 1

  local start_time="${range%-*}"
  local end_time="${range#*-}"
  [[ "$start_time" == "$range" || -z "$start_time" || -z "$end_time" ]] && return 1

  local start_minutes end_minutes now_minutes
  start_minutes="$(_faah_time_to_minutes "$start_time")" || return 1
  end_minutes="$(_faah_time_to_minutes "$end_time")" || return 1
  now_minutes="$(_faah_current_minutes)" || return 1

  if (( start_minutes == end_minutes )); then
    return 0
  fi

  if (( start_minutes < end_minutes )); then
    (( now_minutes >= start_minutes && now_minutes < end_minutes ))
    return $?
  fi

  (( now_minutes >= start_minutes || now_minutes < end_minutes ))
}

_faah_should_alert() {
  local exit_status="$1"
  local command_text="$2"
  local started_at="$3"
  local now cooldown min_duration

  _faah_bool_enabled "${FAAH_ENABLED:-1}" || return 1
  _faah_bool_enabled "${FAAH_ALERT_ON_EXIT_CODE:-1}" || return 1
  (( exit_status == 0 )) && return 1
  _faah_exit_code_ignored "$exit_status" && return 1
  _faah_command_ignored "$command_text" && return 1
  _faah_quiet_hours_active && return 1

  now="$(_faah_now)"

  if (( _FAAH_SNOOZE_UNTIL > now )); then
    return 1
  fi

  cooldown="$(_faah_number_or_default "${FAAH_COOLDOWN_SECONDS:-1.5}" 1.5)"
  if (( now - _FAAH_LAST_ALERT_AT < cooldown )); then
    return 1
  fi

  min_duration="$(_faah_number_or_default "${FAAH_MIN_DURATION_SECONDS:-0}" 0)"
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
  typeset -g FAAH_ENABLED=1
  _faah_install_hooks
  print -r -- "Faah zsh alerts enabled."
}

faah-disable() {
  typeset -g FAAH_ENABLED=0
  print -r -- "Faah zsh alerts disabled."
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

faah-test() {
  _faah_play
}

faah-status() {
  local state="enabled"
  _faah_bool_enabled "${FAAH_ENABLED:-1}" || state="disabled"

  print -r -- "Faah zsh plugin: $state"
  print -r -- "Hooks: $(_faah_hook_state)"
  print -r -- "preexec_functions: ${preexec_functions:-<empty>}"
  print -r -- "precmd_functions: ${precmd_functions:-<empty>}"
  print -r -- "Sound: $(_faah_sound_path)"
  print -r -- "Player: ${FAAH_PLAYER:-$(_faah_select_player 2>/dev/null || print -r -- unavailable)}"
  print -r -- "Cooldown: ${FAAH_COOLDOWN_SECONDS:-1.5}s"
  print -r -- "Minimum duration: ${FAAH_MIN_DURATION_SECONDS:-0}s"
  print -r -- "Ignored exit codes: ${FAAH_IGNORE_EXIT_CODES:-130}"
  [[ -n "${FAAH_QUIET_HOURS:-}" ]] && print -r -- "Quiet hours: $FAAH_QUIET_HOURS"
  return 0
}

_faah_install_hooks
