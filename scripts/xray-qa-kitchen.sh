#!/usr/bin/env bash
# Signs the App Intents X-ray's disposable QA chef in and gives its kitchen something for Siri to find.
#
#   xray-qa-kitchen.sh --accounts FILE --vault OUT
#
# FILE is what `scripts/journey-qa-accounts.sh create --count 1` wrote. The chef signs in with the native password
# flow (scripts/dogfood-native-password-auth.sh), which writes OUT: the session vault a debug build reads from
# Library/Application Support/Spoonjoy/debug-auth-session.json. Then, as that chef, it creates two recipes, a cookbook
# holding one of them and a shopping-list item, so every query the X-ray runs has something to suggest.
#
# QA only: the server is fixed, as in journey-qa-accounts.sh. The password and the access token are masked and never
# reach argv; curl reads the token from a 0600 header file.
set -euo pipefail
umask 077

readonly QA_BASE_URL="https://spoonjoy-v2-qa.mendelow-studio.workers.dev"

accounts=""
vault=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --accounts) accounts="$2"; shift 2 ;;
    --vault) vault="$2"; shift 2 ;;
    *) echo "usage: xray-qa-kitchen.sh --accounts FILE --vault OUT" >&2; exit 2 ;;
  esac
done
[[ -s "$accounts" && -n "$vault" ]] || { echo "usage: xray-qa-kitchen.sh --accounts FILE --vault OUT" >&2; exit 2; }

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/xray-qa-kitchen.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

username="$(jq -er '.accounts[0].username' "$accounts")"
case "$username" in codex_native_*) ;; *) echo "::error::xray-qa-kitchen signs in only disposable codex_native_* accounts" >&2; exit 1 ;; esac
jq -j '.accounts[0].password' "$accounts" > "$work_dir/password"
echo "::add-mask::$(cat "$work_dir/password")"

mkdir -p "$(dirname "$vault")"
# A cold `swift run` builds SpoonjoyCore first, which takes longer than the wrapper's 180-second default on a runner.
SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE="$work_dir/password" SPOONJOY_NATIVE_DOGFOOD_TIMEOUT_SECONDS=900 \
  scripts/dogfood-native-password-auth.sh --base-url "$QA_BASE_URL" --identifier "$username" --vault-file "$vault" > "$work_dir/dogfood.log" 2>&1 \
  || { tail -20 "$work_dir/dogfood.log" >&2; echo "::error::the X-ray chef could not sign in to QA" >&2; exit 1; }
[[ -s "$vault" ]] || { tail -20 "$work_dir/dogfood.log" >&2; echo "::error::signing in wrote no session vault" >&2; exit 1; }

token="$(jq -er '.session.accessToken' "$vault")"
echo "::add-mask::$token"
printf 'Authorization: Bearer %s\n' "$token" > "$work_dir/auth-header"
unset token

# POSTs JSON as the chef and prints the response body; fails on any status but 2xx.
post() {
  local path="$1" body="$2" status
  status="$(curl -sS -o "$work_dir/response.json" -w '%{http_code}' -X POST "$QA_BASE_URL$path" \
    -H @"$work_dir/auth-header" -H 'Content-Type: application/json' --data "$body")"
  [[ "$status" == 2* ]] || { echo "::error::QA answered HTTP $status for POST $path: $(head -c 300 "$work_dir/response.json")" >&2; exit 1; }
  cat "$work_dir/response.json"
}

mutation() { printf 'xray-%s' "$(uuidgen | tr '[:upper:]' '[:lower:]')"; }

recipe() {
  jq -n --arg id "$(mutation)" --arg title "$1" --arg servings "$2" --arg step "$3" --arg ingredient "$4" \
    '{clientMutationId: $id, title: $title, description: "A synthetic recipe for the App Intents X-ray.", servings: $servings,
      steps: [{stepTitle: null, description: $step, duration: null, ingredients: [{quantity: 2, unit: "cups", name: $ingredient}]}]}'
}

pasta="$(post /api/v1/recipes "$(recipe "Lemon Pantry Pasta" "4" "Boil the pasta, then toss it with lemon and oil." "pasta")" | jq -er '.data.recipe.id')"
post /api/v1/recipes "$(recipe "Weeknight Tomato Soup" "2" "Simmer the tomatoes with stock for twenty minutes." "tomatoes")" > /dev/null
cookbook_response="$(post /api/v1/cookbooks "$(jq -n --arg id "$(mutation)" '{clientMutationId: $id, title: "X-ray Weeknights"}')")"
cookbook="$(jq -er '.data.cookbook.id // .data.id' <<< "$cookbook_response")"
post "/api/v1/cookbooks/$cookbook/recipes/$pasta" "$(jq -n --arg id "$(mutation)" '{clientMutationId: $id}')" > /dev/null
post /api/v1/shopping-list/items "$(jq -n --arg id "$(mutation)" '{clientMutationId: $id, name: "Lemons", quantity: 3}')" > /dev/null

echo "Signed in $username on QA with 2 recipes, a cookbook and a shopping-list item"
