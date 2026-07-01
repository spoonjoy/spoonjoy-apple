#!/usr/bin/env bash
set -euo pipefail

base_url="${SPOONJOY_API_BASE_URL:-http://localhost:5173}"
identifier="${SPOONJOY_NATIVE_DOGFOOD_IDENTIFIER:-}"
vault_file="${SPOONJOY_NATIVE_DOGFOOD_VAULT:-}"
report="${SPOONJOY_NATIVE_DOGFOOD_REPORT:-}"
temporary_vault_dir=""
password_file="${SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE:-}"
temporary_password_dir=""
swift_pid=""

terminate_process_tree() {
  local pid="$1"
  local child
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    terminate_process_tree "$child"
  done
  kill "$pid" >/dev/null 2>&1 || true
}

cleanup() {
  if [[ -n "$swift_pid" ]] && kill -0 "$swift_pid" >/dev/null 2>&1; then
    terminate_process_tree "$swift_pid"
    sleep 0.2
    kill -9 "$swift_pid" >/dev/null 2>&1 || true
  fi
  [[ -n "$temporary_vault_dir" ]] && rm -rf "$temporary_vault_dir"
  [[ -n "$temporary_password_dir" ]] && rm -rf "$temporary_password_dir"
  return 0
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      base_url="$2"
      shift 2
      ;;
    --identifier)
      identifier="$2"
      shift 2
      ;;
    --vault-file)
      vault_file="$2"
      shift 2
      ;;
    --report)
      report="$2"
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$password_file" ]]; then
  if [[ -z "${SPOONJOY_NATIVE_DOGFOOD_PASSWORD:-}" ]]; then
    printf 'Set SPOONJOY_NATIVE_DOGFOOD_PASSWORD or SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE in the environment; --password is intentionally unsupported so secrets do not appear in process arguments.\n' >&2
    exit 2
  fi
  temporary_password_dir="$(mktemp -d "${TMPDIR:-/tmp}/spoonjoy-native-dogfood-secret.XXXXXX")"
  chmod 700 "$temporary_password_dir"
  password_file="$temporary_password_dir/password.txt"
  (umask 077 && printf '%s' "$SPOONJOY_NATIVE_DOGFOOD_PASSWORD" > "$password_file")
elif [[ ! -s "$password_file" ]]; then
  printf 'SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE must point at a non-empty password file: %s\n' "$password_file" >&2
  exit 2
fi

export SPOONJOY_API_BASE_URL="$base_url"
export SPOONJOY_NATIVE_DOGFOOD_IDENTIFIER="$identifier"
export SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE="$password_file"
unset SPOONJOY_NATIVE_DOGFOOD_PASSWORD

args=()
if [[ -z "$vault_file" ]]; then
  temporary_vault_dir="$(mktemp -d "${TMPDIR:-/tmp}/spoonjoy-native-dogfood.XXXXXX")"
  vault_file="$temporary_vault_dir/debug-auth-session.json"
fi
mkdir -p "$(dirname "$vault_file")"
export SPOONJOY_NATIVE_DOGFOOD_VAULT="$vault_file"
if [[ -n "$report" ]]; then
  mkdir -p "$(dirname "$report")"
  args+=(--report "$report")
fi

scratch="${SPOONJOY_NATIVE_DOGFOOD_SCRATCH:-.build/native-dogfood}"
timeout_seconds="${SPOONJOY_NATIVE_DOGFOOD_TIMEOUT_SECONDS:-180}"
swift run --scratch-path "$scratch" -Xswiftc -warnings-as-errors SpoonjoyNativeDogfood "${args[@]}" &
swift_pid="$!"
deadline=$((SECONDS + timeout_seconds))
while kill -0 "$swift_pid" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    printf 'Spoonjoy native dogfood timed out after %s seconds.\n' "$timeout_seconds" >&2
    terminate_process_tree "$swift_pid"
    sleep 0.2
    kill -9 "$swift_pid" >/dev/null 2>&1 || true
    wait "$swift_pid" >/dev/null 2>&1 || true
    swift_pid=""
    exit 124
  fi
  sleep 1
done

set +e
wait "$swift_pid"
status="$?"
set -e
swift_pid=""
exit "$status"
