#!/bin/zsh
set -euo pipefail

config_path="${PRINT_WITH_STAMP_CONFIG:-$HOME/.config/print-with-stamp/options}"
command_path="${PRINT_WITH_STAMP_COMMAND:-}"

show_error() {
  local message="$1"
  /usr/bin/osascript -e "display alert \"Print With Stamp\" message \"$message\"" >/dev/null 2>&1 || print -u2 "$message"
}

if [[ $# -eq 0 ]]; then
  show_error "PDF file was not provided."
  exit 1
fi

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
