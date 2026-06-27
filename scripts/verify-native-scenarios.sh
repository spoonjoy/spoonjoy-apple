#!/usr/bin/env bash
set -euo pipefail

stage="final"
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)
      if [[ $# -lt 2 || "$2" == --* ]]; then
        echo "Missing value for --stage." >&2
        exit 2
      fi
      stage="$2"
      shift 2
      ;;
    --output)
      if [[ $# -lt 2 || "$2" == --* ]]; then
        echo "Missing value for --output." >&2
        exit 2
      fi
      output="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument $1." >&2
      exit 2
      ;;
  esac
done

if [[ -z "$output" ]]; then
  output="$(mktemp "${TMPDIR:-/tmp}/spoonjoy-scenario-${stage}.XXXXXX").json"
fi

swift_args=(run)
if [[ -n "${SPOONJOY_SCENARIO_SCRATCH_PATH:-}" ]]; then
  swift_args+=(--scratch-path "$SPOONJOY_SCENARIO_SCRATCH_PATH")
fi
swift_args+=(-Xswiftc -warnings-as-errors SpoonjoyScenarioVerifier --stage "$stage" --output "$output")

swift "${swift_args[@]}"

ruby -rjson - "$output" "$stage" <<'RUBY'
path = ARGV.fetch(0)
stage = ARGV.fetch(1)
report = JSON.parse(File.read(path))
checks = report.fetch("checks")
capabilities = report.fetch("nativeCapabilities")

allowed_pending = case stage
                  when "bootstrap"
                    ["native metadata", "app surfaces"]
                  when "native-metadata"
                    ["app surfaces"]
                  when "surfaces"
                    []
                  else
                    []
                  end

failed_checks = checks.select { |check| check.fetch("status") == "fail" }
pending_checks = checks.select { |check| check.fetch("status") == "pending" }
unauthorized_pending = pending_checks.reject { |check| allowed_pending.include?(check.fetch("name")) }
required_capability_keys = %w[
  appIntents
  spotlightIndexedTypes
  searchableScopes
  shareActions
  offlineFlows
  associatedDomains
  urlSchemes
  deepLinkRoutes
]
empty_required_capabilities = stage == "bootstrap" ? [] : required_capability_keys.select do |key|
  capabilities.fetch(key).empty?
end

unless report.fetch("ok")
  warn "scenario report ok=false for #{stage}"
end

failed_checks.each do |check|
  warn "scenario check failed: #{check.fetch("name")}: #{check.fetch("detail")}"
end

unauthorized_pending.each do |check|
  warn "scenario check pending without allowance: #{check.fetch("name")}: #{check.fetch("detail")}"
end

empty_required_capabilities.each do |key|
  warn "native capability array is empty: #{key}"
end

if !report.fetch("ok") || failed_checks.any? || unauthorized_pending.any? || empty_required_capabilities.any?
  exit 1
end
RUBY

echo "native scenario verification ok: ${stage}"
