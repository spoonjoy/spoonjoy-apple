#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-16-1754-doing-siri-full-access-parity"
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
routes_dir="$artifact_root/screenshot-routes"
results_path="$apple_dir/${unit_slug}-route-matrix.jsonl"
summary_path="$apple_dir/${unit_slug}-route-matrix.json"

mkdir -p "$apple_dir" "$routes_dir"
rm -rf "$routes_dir"
mkdir -p "$routes_dir"
rm -f "$results_path" "$summary_path"

record_route() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local status="$4"
  local command="$5"
  ruby -rjson -e '
    results_path, name, route, route_root, status, command = ARGV
    def artifact(path, relative_path)
      absolute = File.join(path, relative_path)
      {
        "path" => absolute,
        "exists" => File.file?(absolute),
        "bytes" => File.file?(absolute) ? File.size(absolute) : nil
      }
    end
    design_review = artifact(route_root, "design-review.json")
    design_review_blocked = artifact(route_root, "design-review-blocked.json")
    row = {
      "name" => name,
      "route" => route,
      "artifactRoot" => route_root,
      "status" => status,
      "command" => command,
      "blocked" => design_review_blocked.fetch("exists"),
      "missingDesignReview" => !design_review.fetch("exists") && !design_review_blocked.fetch("exists"),
      "designReview" => design_review,
      "designReviewBlocked" => design_review_blocked,
      "iosScreenshot" => artifact(route_root, "screenshots/ios-mobile.png"),
      "macosScreenshot" => artifact(route_root, "screenshots/macos-desktop.png")
    }
    File.open(results_path, "a") { |file| file.puts(JSON.generate(row)) }
  ' "$results_path" "$name" "$route" "$route_root" "$status" "$command"
}

summarize_routes() {
  ruby -rjson -rtime -e '
    results_path, summary_path = ARGV
    rows = File.file?(results_path) ? File.readlines(results_path).map { |line| JSON.parse(line) } : []
    missing = rows.select { |row| row["missingDesignReview"] }
    blocked = rows.select { |row| row["blocked"] }
    failed = rows.select { |row| row["status"] != "pass" }
    ok = missing.empty? && blocked.empty? && failed.empty?
    File.write(summary_path, JSON.pretty_generate({
      "ok" => ok,
      "fullyValidated" => ok,
      "generatedAt" => Time.now.utc.iso8601,
      "routeCount" => rows.length,
      "routes" => rows,
      "failedRoutes" => failed.map { |row| row["name"] },
      "blockedRoutes" => blocked.map { |row| row["name"] },
      "missingDesignReviewRoutes" => missing.map { |row| row["name"] }
    }) + "\n")
    exit(ok ? 0 : 1)
  ' "$results_path" "$summary_path"
}

capture_route() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local route_slug="$4"
  local command="scripts/capture-native-screenshots.sh --artifact-root $route_root --unit-slug $route_slug --route $route"
  local command_status=0
  local status="pass"

  mkdir -p "$route_root"
  printf 'capturing native route %s (%s)\n' "$name" "$route"
  scripts/capture-native-screenshots.sh --artifact-root "$route_root" --unit-slug "$route_slug" --route "$route" || command_status=$?

  if [[ -f "$route_root/design-review-blocked.json" ]]; then
    status="blocked"
  elif [[ ! -f "$route_root/design-review.json" ]]; then
    status="fail"
  elif [[ "$command_status" -ne 0 ]]; then
    status="fail"
  fi

  record_route "$name" "$route" "$route_root" "$status" "$command"
  find "$route_root" -maxdepth 1 -type d -name 'DerivedData-*' -prune -exec rm -rf {} +

  [[ "$status" == "pass" ]]
}

overall_status=0
routes=(
  "kitchen|kitchen|$artifact_root|$unit_slug"
  "recipes|recipes|$routes_dir/recipes|$unit_slug-recipes"
  "recipe-detail|recipe-detail|$routes_dir/recipe-detail|$unit_slug-recipe-detail"
  "cook-mode|cook-mode|$routes_dir/cook-mode|$unit_slug-cook-mode"
  "cookbooks|cookbooks|$routes_dir/cookbooks|$unit_slug-cookbooks"
  "shopping-list|shopping-list|$routes_dir/shopping-list|$unit_slug-shopping-list"
  "search|search|$routes_dir/search|$unit_slug-search"
  "capture|capture|$routes_dir/capture|$unit_slug-capture"
  "settings|settings|$routes_dir/settings|$unit_slug-settings"
  "settings-notifications|settings|$routes_dir/settings-notifications|$unit_slug-settings-notifications"
)

for entry in "${routes[@]}"; do
  IFS="|" read -r name route route_root route_slug <<< "$entry"
  capture_route "$name" "$route" "$route_root" "$route_slug" || overall_status=1
done

summarize_routes || overall_status=1
printf 'native screenshot route matrix complete: %s\n' "$summary_path"
exit "$overall_status"
