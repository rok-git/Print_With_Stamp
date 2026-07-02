#!/bin/zsh
set -euo pipefail

config_dir="${PRINT_WITH_STAMP_CONFIG_DIR:-$HOME/.config/print-with-stamp}"
config_path="${PRINT_WITH_STAMP_CONFIG:-}"
command_path="${PRINT_WITH_STAMP_COMMAND:-}"

show_error() {
  local message="$1"
  /usr/bin/osascript -e "display alert \"Print With Stamp\" message \"$message\"" >/dev/null 2>&1 || print -u2 "$message"
}

current_modifiers() {
  if ! command -v swift >/dev/null 2>&1; then
    return 0
  fi

  swift - 2>/dev/null <<'SWIFT' || true
import CoreGraphics
import Foundation

let flags = CGEventSource.flagsState(.combinedSessionState)
var modifiers: [String] = []

if flags.contains(.maskShift) {
    modifiers.append("shift")
}
if flags.contains(.maskAlternate) {
    modifiers.append("option")
}
if flags.contains(.maskControl) {
    modifiers.append("control")
}
if flags.contains(.maskCommand) {
    modifiers.append("command")
}

print(modifiers.joined(separator: " "))
SWIFT
}

selected_config_path() {
  if [[ -n "$config_path" ]]; then
    print -r -- "$config_path"
    return 0
  fi

  local default_config="$config_dir/options"
  local modifiers=(${(z)"$(current_modifiers)"})
  local modifier

  for modifier in option shift control command; do
    if (( ${modifiers[(Ie)$modifier]} )); then
      local modifier_config="$config_dir/options.$modifier"
      if [[ -f "$modifier_config" ]]; then
        print -r -- "$modifier_config"
        return 0
      fi
    fi
  done

  print -r -- "$default_config"
}

if [[ $# -eq 0 ]]; then
  show_error "PDF file was not provided."
  exit 1
fi

config_path="$(selected_config_path)"

if [[ ! -f "$config_path" ]]; then
  show_error "Config file was not found: $config_path"
  exit 1
fi

config_options=()
line_number=0
while IFS= read -r line || [[ -n "$line" ]]; do
  ((line_number += 1))
  trimmed="${line#"${line%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

  if [[ -z "$trimmed" || "$trimmed" == \#* ]]; then
    continue
  fi

  # Split like zsh command syntax, then remove quotes preserved by ${(z)...}.
  parsed_options=(${(z)line})
  parsed_options=("${(@Q)parsed_options}")
  if [[ ${#parsed_options[@]} -eq 0 ]]; then
    show_error "Config line $line_number could not be parsed: $line"
    exit 1
  fi

  config_options+=("${parsed_options[@]}")
done < "$config_path"

if [[ -z "$command_path" ]]; then
  if [[ -x "$HOME/bin/print-with-stamp" ]]; then
    command_path="$HOME/bin/print-with-stamp"
  else
    command_path="$(command -v print-with-stamp || true)"
  fi
fi

if [[ -z "$command_path" || ! -x "$command_path" ]]; then
  show_error "print-with-stamp command was not found. Install it or set PRINT_WITH_STAMP_COMMAND."
  exit 1
fi

for input_path in "$@"; do
  if [[ ! -f "$input_path" ]]; then
    show_error "File was not found: $input_path"
    exit 1
  fi

  if [[ "${input_path:e:l}" != "pdf" ]]; then
    show_error "Selected file is not a PDF: $input_path"
    exit 1
  fi

  "$command_path" "$input_path" "${config_options[@]}"
done
