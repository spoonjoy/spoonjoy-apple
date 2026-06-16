#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-15-2314-doing-native-app-skeleton"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-root)
      artifact_root="$2"
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

mkdir -p "$artifact_root"
matrix_path="$artifact_root/validation-matrix.json"

required_hooks=(
  "scripts/fail-on-warning.rb"
  "scripts/enforce-swift-coverage.rb"
  "scripts/verify-native-scenarios.sh"
  "scripts/check-xcode-project-contract.rb"
  "scripts/check-xcode-generator-contract.rb"
  "scripts/check-native-design-language.rb"
  "scripts/check-kitchen-recipe-surfaces.rb"
  "scripts/check-cook-shopping-surfaces.rb"
  "scripts/check-search-capture-settings-surfaces.rb"
  "scripts/check-launch-screenshot-contract.rb"
  "scripts/smoke-macos.sh"
  "scripts/smoke-ios-simulator.sh"
  "scripts/capture-native-screenshots.sh"
  "scripts/validate-design-review.rb"
  "scripts/validate-aasa.rb"
)

missing_hooks=()
for hook in "${required_hooks[@]}"; do
  if [[ ! -f "$hook" ]]; then
    missing_hooks+=("$hook")
  fi
done

if [[ "${#missing_hooks[@]}" -gt 0 ]]; then
  printf 'Native local matrix is missing required hook(s):\n' >&2
  printf ' - %s\n' "${missing_hooks[@]}" >&2
  exit 1
fi

printf 'Native local matrix preflight passed; implementation must write %s.\n' "$matrix_path" >&2
exit 1
