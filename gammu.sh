#!/usr/bin/env bash

set -u

LOGFILE="gammu.log"

print_error() {
  echo "ERROR: $*" >&2
}

print_info() {
  echo "INFO: $*"
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    print_error "Required command '$cmd' is not available in PATH."
    exit 127
  fi
}

validate_phone() {
  local number="$1"
  if [[ ! "$number" =~ ^\+34[0-9]{9}$ ]]; then
    print_error "Invalid phone number '$number'. Expected format: +34 followed by 9 digits (example: +34600111222)."
    exit 1
  fi
}

validate_message() {
  local message="$1"
  if [[ -z "$message" || "$message" =~ ^[[:space:]]*$ ]]; then
    print_error "Message cannot be empty or whitespace only."
    exit 1
  fi

  if ! printf '%s' "$message" | grep -qE "^[a-zA-Z0-9 áéíóúÁÉÍÓÚñÑ.,:;!?¿¡()\"'-]*$"; then
    print_error "Message contains unsupported characters. Allowed: letters, numbers, spaces, and punctuation . , : ; ! ? ¿ ¡ ( ) \" ' -"
    exit 1
  fi
}

read_and_delete_sms() {
  print_info "Reading all SMS from modem with Gammu."

  local timestamp tmpfile deleted_count location fnum delete_output
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$timestamp | SMS read started" >> "$LOGFILE"

  tmpfile="$(mktemp)"
  if ! gammu getallsms > "$tmpfile" 2>&1; then
    print_error "Failed to read SMS using 'gammu getallsms'. Output follows:"
    cat "$tmpfile" >&2
    cat "$tmpfile" >> "$LOGFILE"
    rm -f "$tmpfile"
    exit 1
  fi

  cat "$tmpfile"
  cat "$tmpfile" >> "$LOGFILE"

  deleted_count=0

  while IFS= read -r line; do
    location="$(echo "$line" | sed -n 's/^Location \([0-9]\+\),.*/\1/p')"
    if [[ -z "$location" ]]; then
      continue
    fi

    for fnum in 0 1 2 3; do
      delete_output="$(gammu deletesms "$fnum" "$location" 2>&1 || true)"
      if echo "$delete_output" | grep -qi "Deleted"; then
        print_info "Deleted SMS at location $location using folder $fnum."
        echo "$(date '+%Y-%m-%d %H:%M:%S') | SMS deleted | Folder: $fnum | Location: $location" >> "$LOGFILE"
        deleted_count=$((deleted_count + 1))
        break
      fi
    done
  done < <(grep -E '^Location [0-9]+,' "$tmpfile")

  rm -f "$tmpfile"

  print_info "Read and delete operation completed. Total messages deleted: $deleted_count"
}

send_sms() {
  local number="$1"
  shift
  local message="$*"

  validate_phone "$number"
  validate_message "$message"

  print_info "Sending SMS using Gammu. Ensure ~/.gammurc is configured correctly."

  local output exit_code status ref
  output="$(gammu sendsms TEXT "$number" -text "$message" 2>&1)"
  exit_code=$?

  if echo "$output" | grep -q "OK, message reference="; then
    status="OK"
    ref="$(echo "$output" | grep -o "message reference=[0-9]*" | cut -d= -f2)"
  else
    status="ERROR"
    ref="N/A"
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') | Number: $number | Status: $status | Ref: $ref | ExitCode: $exit_code | Message: $message" >> "$LOGFILE"

  if [[ "$status" != "OK" ]]; then
    print_error "SMS sending failed. Command output follows:"
    echo "$output" >&2
    exit 1
  fi

  echo "$output"
}

main() {
  require_command gammu

  if [[ "$#" -eq 0 ]]; then
    read_and_delete_sms
  elif [[ "$#" -lt 2 ]]; then
    print_error "Invalid usage."
    echo "Usage:"
    echo "  $0 <phone_number> <message>   # Send SMS"
    echo "  $0                            # Read and delete received SMS"
    exit 1
  else
    send_sms "$@"
  fi
}

main "$@"
