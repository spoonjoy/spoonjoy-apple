#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
CANONICAL = ROOT.join("worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml")
LIBRARY = ROOT.join("scripts/shopping-visual-matrix.rb")
RUNNER = ROOT.join("scripts/run-shopping-visual-matrix.rb")

def assert(condition, message)
  raise message unless condition
end

assert(LIBRARY.file?, "missing shared shopping visual matrix validator")
assert(RUNNER.file?, "missing shopping visual matrix runner")
require LIBRARY.to_s

matrix = ShoppingVisualMatrix.load!(CANONICAL, repository_root: ROOT)
assert(matrix.fetch("rows").length == 62, "canonical matrix must contain 62 rows")
platform_counts = matrix.fetch("rows").group_by { |row| row.fetch("platform") }.transform_values(&:length)
assert(platform_counts == { "iphone" => 22, "ipad" => 20, "macos" => 20 }, "platform counts drifted")

def rejected?(source, canonical_source, label)
  Dir.mktmpdir("shopping-matrix-contract") do |directory|
    root = Pathname.new(directory)
    path = root.join(ShoppingVisualMatrix::CANONICAL_RELATIVE_PATH)
    path.dirname.mkpath
    path.write(source)
    begin
      ShoppingVisualMatrix.load!(path, repository_root: root)
    rescue ShoppingVisualMatrix::ValidationError
      return true
    end
  end
  warn "accepted invalid matrix case: #{label}"
  false
end

canonical_source = CANONICAL.read
mutations = {
  "alias" => "defaults: &defaults { platform: iphone }\ncopy: *defaults\n" + canonical_source,
  "extra top-level key" => canonical_source.sub("schemaVersion: 1\n", "schemaVersion: 1\nunexpected: true\n"),
  "extra row key" => canonical_source.sub("args: [", "unexpected: true, args: ["),
  "wrong row count" => canonical_source.sub("expectedRows: 62", "expectedRows: 61"),
  "wrong artifact count" => canonical_source.sub("png: 62", "png: 61"),
  "invalid value" => canonical_source.sub("platform: iphone", "platform: watchos"),
  "duplicate id" => canonical_source.sub("id: ip-basket-default", "id: ip-need-default"),
  "duplicate slug" => canonical_source.sub("unitSlug: shopping-ip-basket-default", "unitSlug: shopping-ip-need-default"),
  "duplicate root" => canonical_source.sub("artifactRoot: visual/ip-basket-default", "artifactRoot: visual/ip-need-default"),
  "argv drift" => canonical_source.sub("--shopping-mode, need", "--shopping-mode, all"),
  "path traversal" => canonical_source.sub("artifactRoot: visual/ip-need-default", "artifactRoot: ../ip-need-default")
}
mutations.each { |label, source| assert(rejected?(source, canonical_source, label), label) }

Dir.mktmpdir("shopping-matrix-artifacts") do |artifact_base|
  stdout, stderr, status = Open3.capture3(
    "ruby", RUNNER.to_s,
    "--manifest", CANONICAL.to_s,
    "--artifact-base", artifact_base,
    "--mode", "dry-run",
    chdir: ROOT.to_s
  )
  assert(status.success?, "dry-run failed:\n#{stdout}\n#{stderr}")
  commands = stdout.lines.grep(/^scripts\/capture-native-screenshots\.sh /)
  assert(commands.length == 62, "dry-run must emit exactly 62 capture commands")
  assert(Dir.children(artifact_base).empty?, "dry-run must not write artifacts")
end

Dir.mktmpdir("shopping-matrix-validation") do |artifact_base_string|
  artifact_base = Pathname.new(artifact_base_string)
  matrix.fetch("rows").each do |row|
    contract = ShoppingVisualMatrix.cell_contract(row, matrix: matrix, artifact_base: artifact_base)
    contract.fetch("artifactPaths").each_value do |path_string|
      path = Pathname.new(path_string)
      path.dirname.mkpath
      path.binwrite(path.extname == ".png" ? "png" : "evidence\n")
    end
    Pathname.new(contract.fetch("cellManifestPath")).write(JSON.pretty_generate(contract.fetch("manifest")) + "\n")
  end
  _stdout, stderr, status = Open3.capture3(
    "ruby", RUNNER.to_s,
    "--manifest", CANONICAL.to_s,
    "--artifact-base", artifact_base.to_s,
    "--mode", "validate",
    chdir: ROOT.to_s
  )
  assert(status.success?, "complete 62-cell validation failed: #{stderr}")

  extra_png = artifact_base.join("visual/ip-need-default/screenshots/absent-platform.png")
  extra_png.binwrite("extra")
  _stdout, _stderr, extra_status = Open3.capture3(
    "ruby", RUNNER.to_s,
    "--manifest", CANONICAL.to_s,
    "--artifact-base", artifact_base.to_s,
    "--mode", "validate",
    chdir: ROOT.to_s
  )
  assert(!extra_status.success?, "extra platform screenshot must fail exact artifact counts")
end

puts "shopping visual matrix contract ok"
