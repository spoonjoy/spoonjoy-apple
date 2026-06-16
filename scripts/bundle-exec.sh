#!/usr/bin/env bash
set -o pipefail

bundle exec "$@" 2>&1 | ruby -ne '
  next if $_.start_with?("Your RubyGems version ") && $_.include?("required_ruby_version")
  print
'

exit "${PIPESTATUS[0]}"
