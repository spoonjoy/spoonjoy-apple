#!/usr/bin/env bash
set -o pipefail

export BUNDLE_WITHOUT="${BUNDLE_WITHOUT:-advisory}"

bundle check 2>&1 | ruby -ne '
  next if $_.start_with?("Your RubyGems version ") && $_.include?("required_ruby_version")
  print
'

exit "${PIPESTATUS[0]}"
