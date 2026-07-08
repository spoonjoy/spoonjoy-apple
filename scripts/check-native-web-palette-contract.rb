#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
DEFAULT_WEB_CSS = ROOT.join("docs/source/spoonjoy-v2-tailwind-colors.css")
DEFAULT_NATIVE_THEME = ROOT.join("Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift")

options = {
  web_css: DEFAULT_WEB_CSS,
  native_theme: DEFAULT_NATIVE_THEME
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/check-native-web-palette-contract.rb [options]"
  parser.on("--web-css PATH", "Pinned Spoonjoy web CSS token source") { |path| options[:web_css] = Pathname.new(path).expand_path }
  parser.on("--native-theme PATH", "Native KitchenTableTheme source") { |path| options[:native_theme] = Pathname.new(path).expand_path }
end.parse!

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def display_path(path)
  expanded = Pathname.new(path).expand_path
  expanded.to_s.start_with?("#{ROOT}/") ? expanded.relative_path_from(ROOT).to_s : expanded.to_s
end

def assert_file(path)
  fail_check("#{display_path(path)} is missing") unless path.file?
end

web_css = options.fetch(:web_css)
native_theme = options.fetch(:native_theme)
assert_file(web_css)
assert_file(native_theme)

web_tokens = web_css.read.scan(/--(sj-[a-z-]+):\s*(#[0-9a-fA-F]{6});/).to_h do |name, value|
  [name, value.delete_prefix("#").upcase]
end

required_mapping = {
  "sj-bone" => "bone",
  "sj-bone-lift" => "paper",
  "sj-vellum" => "vellum",
  "sj-charcoal" => "charcoal",
  "sj-charcoal-soft" => "inkMuted",
  "sj-brass" => "brass",
  "sj-action" => "action",
  "sj-action-deep" => "actionDeep",
  "sj-tomato" => "tomato",
  "sj-herb" => "herb",
  "sj-photo-charcoal" => "photoCharcoal"
}.freeze

missing_web_tokens = required_mapping.keys.reject { |token| web_tokens.key?(token) }
fail_check("#{display_path(web_css)} missing web tokens: #{missing_web_tokens.join(", ")}") unless missing_web_tokens.empty?

native_content = native_theme.read
required_mapping.each do |web_token, native_name|
  expected_hex = web_tokens.fetch(web_token)
  pattern = /static\s+let\s+#{Regexp.escape(native_name)}\s*=\s*webColor\(0x#{expected_hex}\)\s*\/\/\s*--#{Regexp.escape(web_token)}\b/
  next if native_content.match?(pattern)

  fail_check("#{display_path(native_theme)} must map #{native_name} to --#{web_token} ##{expected_hex}")
end

raw_color_literals = native_content.scan(/Color\s*\(\s*red:/m).length
fail_check("#{display_path(native_theme)} should define raw RGB only inside webColor helper") unless raw_color_literals == 1
fail_check("#{display_path(native_theme)} must not contain the old yellow offline palette") if native_content.match?(/F6E9CF|0\.97,\s*green:\s*0\.95/)

puts "native web palette contract ok"
