#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-16-1754-doing-siri-full-access-parity"
report_path=""
server_log_path=""
vault_path=""
web_repo="${SPOONJOY_WEB_REPO:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-root)
      artifact_root="$2"
      shift 2
      ;;
    --report)
      report_path="$2"
      shift 2
      ;;
    --server-log)
      server_log_path="$2"
      shift 2
      ;;
    --vault-file)
      vault_path="$2"
      shift 2
      ;;
    --web-repo)
      web_repo="$2"
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

apple_dir="$artifact_root/apple"
mkdir -p "$apple_dir"
report_path="${report_path:-$apple_dir/matrix-native-password-dogfood-report.json}"
server_log_path="${server_log_path:-$apple_dir/matrix-native-password-dogfood-server.log}"
vault_path="${vault_path:-$apple_dir/matrix-native-password-dogfood-vault.json}"
mkdir -p "$(dirname "$report_path")" "$(dirname "$server_log_path")" "$(dirname "$vault_path")"

resolve_web_repo() {
  if [[ -n "$web_repo" ]]; then
    if [[ ! -f "$web_repo/scripts/native-dogfood-api-server.ts" ]]; then
      printf 'SPOONJOY_WEB_REPO/--web-repo does not point at a Spoonjoy web repo with scripts/native-dogfood-api-server.ts: %s\n' "$web_repo" >&2
      exit 2
    fi
    (cd "$web_repo" && pwd)
    return
  fi

  local candidate
  for candidate in \
    "../spoonjoy-v2-native-password-dogfood" \
    "../spoonjoy-v2" \
    "/Users/arimendelow/Projects/spoonjoy-v2-native-password-dogfood" \
    "/Users/arimendelow/Projects/spoonjoy-v2"
  do
    if [[ -f "$candidate/scripts/native-dogfood-api-server.ts" ]]; then
      (cd "$candidate" && pwd)
      return
    fi
  done

  printf 'Could not find Spoonjoy web repo. Pass --web-repo or set SPOONJOY_WEB_REPO.\n' >&2
  exit 2
}

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/spoonjoy-native-dogfood-api.XXXXXX")"
server_pid=""
terminate_process_tree() {
  local pid="$1"
  local child
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    terminate_process_tree "$child"
  done
  kill "$pid" >/dev/null 2>&1 || true
}

cleanup() {
  if [[ -n "$server_pid" ]]; then
    terminate_process_tree "$server_pid"
    sleep 0.2
    kill -9 "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

web_repo="$(resolve_web_repo)"
db_path="$work_dir/native-dogfood.sqlite"
base_url=""
identifier="codex-native-dogfood-$(date +%s)-$$@example.com"
username="native_dogfood_$(date +%s)_$$"
password="$(ruby -rsecurerandom -e 'print SecureRandom.hex(24)')"
password_file="$work_dir/native-dogfood-password.txt"
(umask 077 && printf '%s' "$password" > "$password_file")

: > "$server_log_path"
{
  printf 'web_repo=%s\n' "$web_repo"
  printf 'database=%s\n' "$db_path"
} >> "$server_log_path"

if [[ -f "$web_repo/prisma/test.db" ]]; then
  cp "$web_repo/prisma/test.db" "$db_path"
  printf 'database_template=%s\n' "$web_repo/prisma/test.db" >> "$server_log_path"
elif [[ -f "$web_repo/prisma/dev.db" ]]; then
  cp "$web_repo/prisma/dev.db" "$db_path"
  printf 'database_template=%s\n' "$web_repo/prisma/dev.db" >> "$server_log_path"
else
  (
    cd "$web_repo"
    DATABASE_URL="file:$db_path" \
    SPOONJOY_FORCE_SQLITE_LOCAL_DB=1 \
    SPOONJOY_NATIVE_DOGFOOD_API=1 \
    pnpm exec prisma migrate deploy
  ) >> "$server_log_path" 2>&1
fi

port="$(ruby -rsocket -e 'server = TCPServer.new("127.0.0.1", 0); puts server.addr[1]; server.close')"
base_url="http://127.0.0.1:$port"

(
  cd "$web_repo"
  DATABASE_URL="file:$db_path" \
  SPOONJOY_FORCE_SQLITE_LOCAL_DB=1 \
  SPOONJOY_NATIVE_DOGFOOD_API=1 \
  SPOONJOY_NATIVE_ENVIRONMENT=local \
  SPOONJOY_NATIVE_DOGFOOD_IDENTIFIER="$identifier" \
  SPOONJOY_NATIVE_DOGFOOD_USERNAME="$username" \
  SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE="$password_file" \
  pnpm exec tsx scripts/native-dogfood-api-server.ts --host 127.0.0.1 --port "$port"
) >> "$server_log_path" 2>&1 &
server_pid="$!"

for _ in {1..100}; do
  if curl -fsS "$base_url/api/v1/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
curl -fsS "$base_url/api/v1/health" >/dev/null

bad_credentials_body="$work_dir/bad-credentials.json"
bad_status="$(
  curl -sS -o "$bad_credentials_body" -w '%{http_code}' \
    -X POST "$base_url/api/v1/auth/password/native" \
    -H 'Content-Type: application/json' \
    -d "{\"emailOrUsername\":\"$identifier\",\"password\":\"wrongPassword\"}"
)"
if [[ "$bad_status" != "401" ]]; then
  printf 'Expected native password endpoint to reject bad credentials with 401, got %s.\n' "$bad_status" >&2
  cat "$bad_credentials_body" >&2
  exit 1
fi

rm -f "$report_path" "$vault_path"
SPOONJOY_NATIVE_DOGFOOD_IDENTIFIER="$identifier" \
SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE="$password_file" \
SPOONJOY_NATIVE_DOGFOOD_SCRATCH="${SPOONJOY_NATIVE_DOGFOOD_SCRATCH:-.build/native-dogfood}" \
scripts/dogfood-native-password-auth.sh \
  --base-url "$base_url" \
  --identifier "$identifier" \
  --vault-file "$vault_path" \
  --report "$report_path"

ruby -rjson -e '
  report_path, vault_path, expected_base_url = ARGV
  report = JSON.parse(File.read(report_path))
  failures = []
  failures << "ok must be true" unless report["ok"] == true
  failures << "baseURL must match local Spoonjoy API" unless report["baseURL"] == expected_base_url
  failures << "tokenType must be Bearer" unless report["tokenType"] == "Bearer"
  failures << "scopeCount must be 6" unless report["scopeCount"] == 6
  failures << "syncEnvironment must be local" unless report["syncEnvironment"] == "local"
  failures << "syncEntryCount must be positive" unless report["syncEntryCount"].to_i.positive?
  failures << "wroteVault must be true" unless report["wroteVault"] == true
  failures << "vault file missing" unless File.file?(vault_path)
  abort(failures.join("\n")) if failures.any?
' "$report_path" "$vault_path" "$base_url"

rm -f "$vault_path"
printf 'native password dogfood ok against real Spoonjoy API: %s\n' "$report_path"
