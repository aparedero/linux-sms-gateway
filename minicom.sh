#!/usr/bin/env bash

set -u

LOGFILE="minicom.log"

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

  if [[ ${#message} -gt 140 ]]; then
    print_error "Message length (${#message}) exceeds 140 characters."
    exit 1
  fi

  if ! printf '%s' "$message" | grep -qE '^[a-zA-Z0-9 .,:;!?()-]*$'; then
    print_error "Message contains unsupported characters. Allowed: letters, numbers, spaces, and punctuation . , : ; ! ? ( ) -"
    exit 1
  fi
}

probe_port() {
  local port="$1"
  printf 'AT\r' > "$port"
  sleep 1
  if timeout 2 cat "$port" | grep -q "OK"; then
    return 0
  fi
  return 1
}

free_port() {
  local port="$1"
  local pids
  pids="$(lsof "$port" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)"

  if [[ -z "$pids" ]]; then
    return 0
  fi

  print_info "Port $port is busy. Attempting to stop blocking processes."
  local pid
  for pid in $pids; do
    if ! sudo kill -TERM "$pid" 2>/dev/null; then
      print_error "Could not send SIGTERM to PID $pid for $port."
    fi
  done

  sleep 1

  for pid in $pids; do
    if kill -0 "$pid" 2>/dev/null; then
      if ! sudo kill -KILL "$pid" 2>/dev/null; then
        print_error "Could not force stop PID $pid for $port."
      fi
    fi
  done
}

send_sms() {
  local number="$1"
  shift
  local message="$*"

  validate_phone "$number"
  validate_message "$message"

  local selected_port=""
  local port

  print_info "Searching for GSM modem port under /dev/ttyUSB*."
  for port in /dev/ttyUSB*; do
    [[ -e "$port" ]] || continue

    free_port "$port"

    print_info "Probing port $port with AT command."
    if probe_port "$port"; then
      selected_port="$port"
      print_info "Port $port accepted AT command."
      break
    else
      print_error "Port $port did not return an OK response to AT command."
    fi
  done

  if [[ -z "$selected_port" ]]; then
    print_error "No usable GSM modem port found. Ensure modem is connected, permissions are correct, and no process blocks the serial device."
    exit 1
  fi

  {
    printf 'AT\r'
    sleep 1
    printf 'AT+CMGF=1\r'
    sleep 1
    printf 'AT+CMGS="%s"\r' "$number"
    sleep 1
    printf '%s\x1A' "$message"
    sleep 5
  } > "$selected_port"

  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  {
    echo "[$timestamp] SMS send"
    echo "Port: $selected_port"
    echo "To: $number"
    echo "Message: $message"
    echo
  } >> "$LOGFILE"

  print_info "SMS send flow completed and logged in $LOGFILE."
}

main() {
  require_command lsof
  require_command timeout
  require_command sudo

  if [[ "$#" -lt 2 ]]; then
    print_error "Invalid usage."
    echo "Usage: $0 +34XXXXXXXXX \"Message text\""
    echo "Note: this script only supports sending SMS."
    exit 1
  fi

  send_sms "$@"
}

main "$@"
