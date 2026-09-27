#!/usr/bin/env bash
# Creates, retires and audits the disposable QA accounts that native journeys sign in with.
#
#   create --base-url URL --count N --out FILE   sign up N codex-native-* accounts through QA's /signup form
#   rotate --base-url URL --accounts FILE        change every account's password to a value nobody keeps,
#                                                then prove the old password no longer signs in
#   scan --accounts FILE PATH...                 fail if any account password appears in a log or result bundle
#
# Passwords never appear in argv: curl and jq read them from 0600 files in a private temp directory.
# Every password is masked with ::add-mask:: before anything else touches it.
set -euo pipefail
umask 077

readonly SUCCESS_TEXT="Your password has been changed successfully"
# Journey accounts live only on the QA mirror; QA's cleanup is the only thing that ever deletes them.
readonly QA_BASE_URL="https://spoonjoy-v2-qa.mendelow-studio.workers.dev"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/journey-qa-accounts.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

usage() {
  echo "usage: journey-qa-accounts.sh create --base-url URL --count N --out FILE" >&2
  echo "       journey-qa-accounts.sh rotate --base-url URL --accounts FILE" >&2
  echo "       journey-qa-accounts.sh scan --accounts FILE PATH..." >&2
  exit 2
}

fail() {
  echo "::error::$1" >&2
  exit 1
}

new_password() {
  local password
  password="$(openssl rand -hex 24)"
  [[ "$password" =~ ^[0-9a-f]{48}$ ]] || fail "openssl did not return a 48-character hex password"
  echo "::add-mask::$password"
  printf '%s' "$password" > "$1"
}

require_qa_base_url() {
  [[ -n "$base_url" ]] || usage
  [[ "$base_url" == "$QA_BASE_URL" ]] ||
    fail "journey accounts may only be created or rotated on the QA mirror ($QA_BASE_URL); refusing $base_url"
}

post_form() {
  # post_form OUTPUT URL [curl args...]; prints "<status> <redirect url>".
  local output="$1" url="$2"
  shift 2
  curl --silent --show-error --max-time 30 -o "$output" -w '%{http_code} %{redirect_url}' "$@" "$url"
}

command="${1:-}"
[[ -n "$command" ]] || usage
shift

base_url=""
count=""
out=""
accounts=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) [[ $# -ge 2 ]] || usage; base_url="${2%/}"; shift 2 ;;
    --count) [[ $# -ge 2 ]] || usage; count="$2"; shift 2 ;;
    --out) [[ $# -ge 2 ]] || usage; out="$2"; shift 2 ;;
    --accounts) [[ $# -ge 2 ]] || usage; accounts="$2"; shift 2 ;;
    --*) usage ;;
    *) break ;;
  esac
done

create_accounts() {
  [[ -n "$out" && "$count" =~ ^[1-9][0-9]*$ ]] || usage
  require_qa_base_url
  [[ "${GITHUB_RUN_ID:-}" =~ ^[0-9]+$ && "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]+$ ]] ||
    fail "GITHUB_RUN_ID and GITHUB_RUN_ATTEMPT must be set to build the run token"

  local token
  token="r${GITHUB_RUN_ID}a${GITHUB_RUN_ATTEMPT}x$(openssl rand -hex 3)"
  [[ "$token" =~ ^[a-z0-9]+$ ]] || fail "run token must be lowercase letters and digits"

  mkdir -p "$(dirname "$out")"
  local draft="$work_dir/accounts.json"
  jq -n --arg token "$token" '{runToken: $token, accounts: []}' > "$draft"
  cp "$draft" "$out"
  chmod 600 "$out"

  local n password_file email username result status redirect
  for ((n = 1; n <= count; n++)); do
    password_file="$work_dir/password-$n"
    new_password "$password_file"
    email="codex-native-${token}-${n}@example.com"
    username="codex_native_${token}_${n}"

    result="$(post_form /dev/null "$base_url/signup" \
      --data-urlencode "email=$email" \
      --data-urlencode "username=$username" \
      --data-urlencode "password@$password_file" \
      --data-urlencode "confirmPassword@$password_file")" ||
      fail "QA signup request for journey account $n did not complete"
    status="${result%% *}"
    redirect="${result#* }"
    [[ "$status" == "302" && "$redirect" == */recipes ]] ||
      fail "QA signup for journey account $n returned HTTP $status instead of a redirect to /recipes"

    # Record each account as soon as it exists so rotation can retire it even if a later signup fails.
    jq --arg email "$email" --arg username "$username" --rawfile password "$password_file" \
      '.accounts += [{email: $email, username: $username, password: $password}]' "$draft" > "$draft.next"
    mv "$draft.next" "$draft"
    cp "$draft" "$out"
    chmod 600 "$out"
    echo "Created journey account $username"
  done
  echo "Journey run token: $token"
}

rotate_account() {
  local index="$1" username old_file new_file jar result status body probe
  username="$(jq -r ".accounts[$index].username" "$accounts")"
  old_file="$work_dir/old-$index"
  new_file="$work_dir/new-$index"
  jar="$work_dir/cookies-$index"
  body="$work_dir/change-$index.html"
  probe="$work_dir/probe-$index.json"

  jq -j ".accounts[$index].password" "$accounts" > "$old_file" || return 1
  echo "::add-mask::$(cat "$old_file")"
  new_password "$new_file" || return 1

  result="$(post_form /dev/null "$base_url/login" -c "$jar" \
    --data-urlencode "identifier=$username" \
    --data-urlencode "password@$old_file")" || { echo "::error::login request for $username did not complete" >&2; return 1; }
  status="${result%% *}"
  [[ "$status" == "302" ]] || { echo "::error::login for $username returned HTTP $status instead of 302" >&2; return 1; }

  result="$(post_form "$body" "$base_url/account/settings" -b "$jar" -c "$jar" \
    --data-urlencode "intent=changePassword" \
    --data-urlencode "currentPassword@$old_file" \
    --data-urlencode "newPassword@$new_file" \
    --data-urlencode "confirmPassword@$new_file")" || { echo "::error::password change request for $username did not complete" >&2; return 1; }
  status="${result%% *}"
  [[ "$status" == "200" ]] || { echo "::error::password change for $username returned HTTP $status instead of 200" >&2; return 1; }
  grep -F -q "$SUCCESS_TEXT" "$body" || { echo "::error::password change for $username did not confirm success" >&2; return 1; }

  jq -cn --arg id "$username" --rawfile password "$old_file" '{emailOrUsername: $id, password: $password}' > "$probe" || return 1
  result="$(post_form /dev/null "$base_url/api/v1/auth/password/native" \
    -H "Content-Type: application/json" \
    --data-binary "@$probe")" || { echo "::error::old-password probe for $username did not complete" >&2; return 1; }
  status="${result%% *}"
  [[ "$status" == "401" ]] || { echo "::error::old password for $username still answered HTTP $status instead of 401" >&2; return 1; }

  rm -f "$old_file" "$new_file" "$jar" "$body" "$probe"
  echo "Rotated journey account $username; its old password is rejected"
}

rotate_accounts() {
  [[ -n "$accounts" ]] || usage
  require_qa_base_url
  if [[ ! -f "$accounts" ]]; then
    echo "no journey accounts to rotate"
    return 0
  fi

  local total index failures=0
  total="$(jq '.accounts | length' "$accounts")"
  for ((index = 0; index < total; index++)); do
    rotate_account "$index" || failures=$((failures + 1))
  done
  [[ "$failures" -eq 0 ]] || fail "$failures journey account(s) could not be rotated"
  echo "Rotated $total journey account(s)"
}

export_result_bundle() {
  # Writes every text view of an .xcresult bundle into $2 so the scan can read it.
  local bundle="$1" export_dir="$2" availability log_types log_type test_ids test_id
  mkdir -p "$export_dir/attachments" "$export_dir/diagnostics" || return 1
  availability="$(xcrun xcresulttool get content-availability --path "$bundle")" || return 1
  log_types="$(jq -r '.logs[]' <<< "$availability")" || return 1
  for log_type in $log_types; do
    xcrun xcresulttool get log --type "$log_type" --path "$bundle" > "$export_dir/log-$log_type.json" || return 1
  done
  if [[ "$(jq -r '.hasTestResults' <<< "$availability")" == "true" ]]; then
    xcrun xcresulttool get test-results summary --path "$bundle" > "$export_dir/summary.json" || return 1
    xcrun xcresulttool get test-results tests --path "$bundle" > "$export_dir/tests.json" || return 1
    test_ids="$(jq -r '[.. | objects | select(.nodeType? == "Test Case") | (.nodeIdentifierURL // .nodeIdentifier)] | unique | .[]' "$export_dir/tests.json")" || return 1
    while IFS= read -r test_id; do
      [[ -n "$test_id" ]] || continue
      xcrun xcresulttool get test-results activities --test-id "$test_id" --path "$bundle" >> "$export_dir/activities.json" || return 1
    done <<< "$test_ids"
    xcrun xcresulttool export attachments --path "$bundle" --output-path "$export_dir/attachments" > /dev/null || return 1
  fi
  if [[ "$(jq -r '.hasDiagnostics' <<< "$availability")" == "true" ]]; then
    xcrun xcresulttool export diagnostics --path "$bundle" --output-path "$export_dir/diagnostics" > /dev/null || return 1
  fi
}

contains_secret() {
  # contains_secret SECRETS PATH: 0 when a secret is present, 1 when it is not; any grep error fails the run.
  local status=0
  grep -r -a -F -q -f "$1" "$2" || status=$?
  [[ "$status" -le 1 ]] || fail "could not read $2 to scan it for credentials"
  return "$status"
}

scan_paths() {
  [[ -n "$accounts" && $# -gt 0 ]] || usage
  if [[ ! -f "$accounts" ]]; then
    echo "no journey accounts to scan for"
    return 0
  fi

  local secrets="$work_dir/secrets" path index=0 found=0 export_dir
  jq -r '.accounts[].password' "$accounts" > "$secrets"
  if [[ ! -s "$secrets" ]]; then
    echo "no journey passwords to scan for"
    return 0
  fi

  for path in "$@"; do
    if [[ ! -e "$path" ]]; then
      echo "Skipped $path (not present)"
      continue
    fi
    index=$((index + 1))
    if contains_secret "$secrets" "$path"; then
      echo "::error::journey account password found in $path" >&2
      found=1
      continue
    fi
    if [[ -d "$path" && "$path" == *.xcresult ]]; then
      export_dir="$work_dir/export-$index"
      export_result_bundle "$path" "$export_dir" || fail "could not export $path to scan it for credentials"
      if contains_secret "$secrets" "$export_dir"; then
        echo "::error::journey account password found inside $path" >&2
        found=1
        continue
      fi
    fi
    echo "Scanned $path: no journey password found"
  done
  [[ "$found" -eq 0 ]] || fail "credential text found in journey artifacts; nothing may be uploaded"
}

case "$command" in
  create) create_accounts ;;
  rotate) rotate_accounts ;;
  scan) scan_paths "$@" ;;
  *) usage ;;
esac
