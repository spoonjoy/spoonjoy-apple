#!/usr/bin/env bash
# Usage: self-hosted-journey-account.sh --base-url http://localhost:PORT --out FILE
#
# Signs up one account on the throwaway Spoonjoy server the Self-hosted server job runs on the runner, and writes it
# as the journey accounts file (the shape journey-qa-accounts.sh writes). The server and its data go with the runner,
# so there is nothing to rotate or clean up. Only a localhost server is accepted, never QA or production.
# The password never appears in argv: curl and jq read it from a 0600 file, and it is masked before anything else.
set -euo pipefail
umask 077

fail() {
  echo "::error::$*" >&2
  exit 1
}

usage() {
  echo "usage: self-hosted-journey-account.sh --base-url http://localhost:PORT --out FILE" >&2
  exit 2
}

base_url=""
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) [[ $# -ge 2 ]] || usage; base_url="${2%/}"; shift 2 ;;
    --out) [[ $# -ge 2 ]] || usage; out="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$base_url" && -n "$out" ]] || usage
[[ "$base_url" =~ ^http://localhost:[0-9]{1,5}$ ]] ||
  fail "a self-hosted journey account is only made on a server on this runner (http://localhost:PORT); refusing $base_url"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/self-hosted-journey-account.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

password_file="$work_dir/password"
password="$(openssl rand -hex 24)"
[[ "$password" =~ ^[0-9a-f]{48}$ ]] || fail "openssl did not return a 48-character hex password"
echo "::add-mask::$password"
printf '%s' "$password" > "$password_file"
unset password

token="r${GITHUB_RUN_ID:-0}a${GITHUB_RUN_ATTEMPT:-0}x$(openssl rand -hex 3)"
username="codex_native_${token}_1"
email="codex-native-${token}-1@example.com"

# The server's first account is its admin, and always may sign up.
result="$(curl --silent --show-error --max-time 30 -o /dev/null -w '%{http_code} %{redirect_url}' \
  --data-urlencode "email=$email" \
  --data-urlencode "username=$username" \
  --data-urlencode "password@$password_file" \
  --data-urlencode "confirmPassword@$password_file" \
  "$base_url/signup?redirectTo=%2Frecipes")" || fail "the sign-up request to $base_url did not complete"
status="${result%% *}"
redirect="${result#* }"
[[ "$status" == "302" && "$redirect" == */recipes ]] ||
  fail "sign-up on $base_url returned HTTP $status (redirect ${redirect:-none}) instead of a redirect to /recipes"

mkdir -p "$(dirname "$out")"
jq -n --arg token "$token" --arg email "$email" --arg username "$username" --rawfile password "$password_file" \
  '{runToken: $token, accounts: [{email: $email, username: $username, password: $password}]}' > "$out"
chmod 600 "$out"
echo "Created self-hosted journey account $username"
