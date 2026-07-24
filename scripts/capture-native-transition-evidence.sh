#!/usr/bin/env bash
set -euo pipefail

artifact_root="${SPOONJOY_NATIVE_ARTIFACT_ROOT:-artifacts/apple/native-screenshot-matrix}"
unit_slug="matrix"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-root)
      artifact_root="$2"
      shift 2
      ;;
    --unit-slug)
      unit_slug="$2"
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

apple_dir="$artifact_root/apple"
evidence_path="$apple_dir/${unit_slug}-transition-evidence.json"
log_path="$apple_dir/${unit_slug}-transition-evidence.log"
blocker_path="$apple_dir/${unit_slug}-transition-evidence-blocker.json"
test_filter='NativeSearchSurfaceTests.pendingSearchSuppressesEmptyState|RecipeCatalogDetailTests.recipeDetailPublishesBeforeCookHistoryEnrichment'
command_display="swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter $test_filter"

mkdir -p "$apple_dir"
rm -f "$evidence_path" "$log_path" "$blocker_path"

source_sha="$(git rev-parse HEAD)"
source_tree="$(git rev-parse 'HEAD^{tree}')"

if ! git diff --quiet || ! git diff --cached --quiet; then
  reason="Transition evidence requires a clean exact-source checkout."
  ruby -rjson -e '
    path, reason = ARGV
    File.write(path, JSON.pretty_generate({
      "blocked" => true,
      "capability" => "NativeTransitionEvidence",
      "reason" => reason,
      "ownerAction" => "Commit the exact native source, then rerun transition evidence capture."
    }) + "\n")
  ' "$blocker_path" "$reason"
  printf '%s\n' "$reason" >&2
  exit 1
fi

set +e
swift test \
  --disable-xctest \
  --parallel \
  -Xswiftc -warnings-as-errors \
  --filter "$test_filter" \
  > "$log_path" 2>&1
test_status=$?
set -e

if [[ "$test_status" -ne 0 ]]; then
  ruby -rjson -e '
    path, command, output_path, status = ARGV
    File.write(path, JSON.pretty_generate({
      "blocked" => true,
      "capability" => "NativeTransitionEvidence",
      "command" => command,
      "outputPath" => output_path,
      "exitStatus" => Integer(status),
      "reason" => "The exact-source pending-to-content transition tests failed.",
      "ownerAction" => "Inspect the transition evidence log, repair the native loading behavior, and rerun the matrix."
    }) + "\n")
  ' "$blocker_path" "$command_display" "$log_path" "$test_status"
  cat "$log_path" >&2
  exit "$test_status"
fi

ruby -rjson -rdigest -rpathname -rtime -e '
  output_path, log_path, command, source_sha, source_tree = ARGV
  payload = {
    "schemaVersion" => 1,
    "ok" => true,
    "sourceSha" => source_sha,
    "sourceTree" => source_tree,
    "command" => command,
    "log" => {
      "path" => Pathname.new(log_path).relative_path_from(Pathname.new(File.dirname(File.dirname(output_path)))).to_s,
      "bytes" => File.size(log_path),
      "sha256" => Digest::SHA256.file(log_path).hexdigest
    },
    "contracts" => [
      {
        "id" => "search-pending-suppresses-empty-state",
        "test" => "NativeSearchSurfaceTests.pendingSearchSuppressesEmptyState",
        "assertion" => "A live query has an explicit pending model with no empty or error verdict."
      },
      {
        "id" => "recipe-publishes-before-cook-history",
        "test" => "RecipeCatalogDetailTests.recipeDetailPublishesBeforeCookHistoryEnrichment",
        "assertion" => "Recipe content is published while the controlled cook-history repository remains suspended."
      }
    ],
    "generatedAt" => Time.now.utc.iso8601
  }
  File.write(output_path, JSON.pretty_generate(payload) + "\n")
' "$evidence_path" "$log_path" "$command_display" "$source_sha" "$source_tree"

printf 'native transition evidence captured: %s\n' "$evidence_path"
