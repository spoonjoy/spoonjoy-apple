#!/usr/bin/env bash
# Spoonjoy's actions must match their one declaration (actions/SOURCE.md):
#   1. the vendored generator and its claims are the Ouro UI core release SOURCE.md names, by sha256;
#   2. actions/spoonjoy.actions.mts is spoonjoy-v2's file at the pinned commit, byte for byte;
#   3. actions/generated is exactly what that generator makes from that declaration.
# Needs Node 22.18 or later (it runs the .mts generator directly) and curl.
set -euo pipefail
cd "$(dirname "$0")/.."

source_value() {
  local value
  value="$(sed -n "s/^- $1: //p" actions/SOURCE.md)"
  [[ -n "$value" ]] || { echo "actions/SOURCE.md has no '$1:' line" >&2; exit 1; }
  printf '%s' "$value"
}

sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }

expect_sha() {
  local path="$1" want="$2" got
  got="$(sha256 "$path")"
  if [[ "$got" != "$want" ]]; then
    echo "::error file=$path::$path is sha256 $got; actions/SOURCE.md pins $want" >&2
    exit 1
  fi
  echo "ok: $path is $want"
}

expect_sha tools/ouro-actions/ouro-actions.mts "$(source_value generator-sha256)"
expect_sha tools/ouro-actions/actions.claims.json "$(source_value claims-sha256)"
expect_sha actions/spoonjoy.actions.mts "$(source_value declaration-sha256)"

repo="$(source_value declaration-repo)"
path="$(source_value declaration-path)"
commit="$(source_value declaration-commit)"
if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error file=actions/SOURCE.md::declaration-commit must be a full spoonjoy-v2 commit on main, not '$commit'" >&2
  exit 1
fi
upstream="$(mktemp)"
trap 'rm -f "$upstream"' EXIT
curl --fail --silent --show-error --location --retry 3 \
  "https://raw.githubusercontent.com/$repo/$commit/$path" --output "$upstream"
if ! cmp -s "$upstream" actions/spoonjoy.actions.mts; then
  echo "::error file=actions/spoonjoy.actions.mts::actions/spoonjoy.actions.mts differs from $repo $path at $commit" >&2
  diff -u "$upstream" actions/spoonjoy.actions.mts >&2 || true
  exit 1
fi
echo "ok: actions/spoonjoy.actions.mts equals $repo@$commit:$path"

node tools/ouro-actions/ouro-actions.mts check actions/spoonjoy.actions.mts actions/generated
