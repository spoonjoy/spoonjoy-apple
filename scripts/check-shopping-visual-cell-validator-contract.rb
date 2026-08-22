#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
CANONICAL = ROOT.join("worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml")
LIBRARY = ROOT.join("scripts/shopping-visual-matrix.rb")
VALIDATOR = ROOT.join("scripts/validate-shopping-visual-cell.rb")

def assert(condition, message)
  raise message unless condition
end

assert(LIBRARY.file?, "missing shared shopping visual matrix validator")
assert(VALIDATOR.file?, "missing shopping visual cell validator")
require LIBRARY.to_s

def run_validator(row_id, artifact_base, cell_path)
  Open3.capture3(
    "ruby", VALIDATOR.to_s,
    "--manifest", CANONICAL.to_s,
    "--row-id", row_id,
    "--artifact-base", artifact_base.to_s,
    "--cell-manifest", cell_path.to_s,
    chdir: ROOT.to_s
  )
end

Dir.mktmpdir("shopping-cell-contract") do |directory|
  artifact_base = Pathname.new(directory).join("artifacts")
  matrix = ShoppingVisualMatrix.load!(CANONICAL, repository_root: ROOT)
  rows = matrix.fetch("rows").first(2)
  cells = {}

  rows.each do |row|
    contract = ShoppingVisualMatrix.cell_contract(row, matrix: matrix, artifact_base: artifact_base)
    contract.fetch("artifactPaths").each_value do |path_string|
      path = Pathname.new(path_string)
      path.dirname.mkpath
      path.binwrite(path.extname == ".png" ? "png" : "proof\n")
    end
    cell_path = Pathname.new(contract.fetch("cellManifestPath"))
    cell_path.write(JSON.pretty_generate(contract.fetch("manifest")) + "\n")
    cells[row.fetch("id")] = [cell_path, contract.fetch("manifest")]
    _stdout, stderr, status = run_validator(row.fetch("id"), artifact_base, cell_path)
    assert(status.success?, "valid #{row.fetch("id")} cell failed: #{stderr}")
  end

  first_id, second_id = rows.map { |row| row.fetch("id") }
  first_path, first_manifest = cells.fetch(first_id)
  second_path, second_manifest = cells.fetch(second_id)

  first_path.write(JSON.pretty_generate(second_manifest) + "\n")
  _stdout, _stderr, status = run_validator(first_id, artifact_base, first_path)
  assert(!status.success?, "swapped row manifest must fail")
  first_path.write(JSON.pretty_generate(first_manifest) + "\n")

  mutations = {
    "row id" => ->(value) { value["rowID"] = second_id },
    "unit slug" => ->(value) { value["unitSlug"] += "-wrong" },
    "artifact root" => ->(value) { value["artifactRoot"] += "-wrong" },
    "argv" => ->(value) { value["argv"] = value.fetch("argv") + ["--extra"] },
    "selected platform" => ->(value) { value["selectedPlatform"] = "macos" },
    "png path" => ->(value) { value["pngPath"] += ".wrong" },
    "accessibility proof path" => ->(value) { value["accessibilityProofPath"] += ".wrong" },
    "screenshot log path" => ->(value) { value["screenshotLogPath"] += ".wrong" },
    "state" => ->(value) { value["state"]["mode"] = "basket" },
    "size" => ->(value) { value["size"]["dynamicType"] = "accessibility5" },
    "unknown key" => ->(value) { value["desktopScreenshot"] = "fabricated.png" }
  }

  mutations.each do |label, mutation|
    candidate = Marshal.load(Marshal.dump(first_manifest))
    mutation.call(candidate)
    first_path.write(JSON.pretty_generate(candidate) + "\n")
    _stdout, _stderr, candidate_status = run_validator(first_id, artifact_base, first_path)
    assert(!candidate_status.success?, "#{label} mismatch must fail")
  end
end

puts "shopping visual cell validator contract ok"
