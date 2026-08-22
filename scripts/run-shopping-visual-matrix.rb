#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require "pathname"
require "shellwords"
require_relative "shopping-visual-matrix"

ROOT = Pathname.new(__dir__).join("..").expand_path
VALIDATOR = ROOT.join("scripts/validate-shopping-visual-cell.rb")
MODES = %w[dry-run capture validate].freeze
options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: run-shopping-visual-matrix.rb --manifest PATH --artifact-base PATH --mode dry-run|capture|validate"
  parser.on("--manifest PATH") { |value| options[:manifest] = value }
  parser.on("--artifact-base PATH") { |value| options[:artifact_base] = value }
  parser.on("--mode MODE") { |value| options[:mode] = value }
end.parse!

def validate_exact_artifact_sets!(contracts, artifact_base)
  base = Pathname.new(artifact_base).expand_path
  expected = {
    png: contracts.map { |contract| contract.dig("artifactPaths", "png") }.sort,
    manifest: contracts.map { |contract| contract.fetch("cellManifestPath") }.sort,
    proof: contracts.map { |contract| contract.dig("artifactPaths", "accessibilityProof") }.sort,
    log: contracts.map { |contract| contract.dig("artifactPaths", "screenshotLog") }.sort
  }
  actual = {
    png: Dir[base.join("**/screenshots/*.png").to_s].sort,
    manifest: Dir[base.join("**/shopping-visual-cell.json").to_s].sort,
    proof: Dir[base.join("**/apple/*-accessibility-proof-*.json").to_s].sort,
    log: Dir[base.join("**/apple/*-screenshots.log").to_s].sort
  }
  expected.each do |kind, paths|
    next if actual.fetch(kind) == paths

    missing = paths - actual.fetch(kind)
    extra = actual.fetch(kind) - paths
    raise ShoppingVisualMatrix::ValidationError, "#{kind} artifact set mismatch; missing=#{missing.inspect} extra=#{extra.inspect}"
  end
end

begin
  %i[manifest artifact_base mode].each do |key|
    raise ShoppingVisualMatrix::ValidationError, "missing --#{key.to_s.tr("_", "-")}" unless options[key]
  end
  raise ShoppingVisualMatrix::ValidationError, "mode must be one of #{MODES.join(", ")}" unless MODES.include?(options.fetch(:mode))
  matrix = ShoppingVisualMatrix.load!(options.fetch(:manifest), repository_root: ROOT)
  artifact_base = Pathname.new(options.fetch(:artifact_base)).expand_path.cleanpath
  raise ShoppingVisualMatrix::ValidationError, "artifact base must not be filesystem root" if artifact_base.root?
  rows = matrix.fetch("rows")
  contracts = rows.map { |row| ShoppingVisualMatrix.cell_contract(row, matrix: matrix, artifact_base: artifact_base) }

  case options.fetch(:mode)
  when "dry-run"
    contracts.each { |contract| puts Shellwords.join(contract.dig("manifest", "argv")) }
  when "capture"
    rows.zip(contracts).each do |row, contract|
      root = Pathname.new(contract.dig("manifest", "artifactRoot"))
      FileUtils.mkdir_p(root)
      raise ShoppingVisualMatrix::ValidationError, "artifact root resolved outside artifact base" unless root.realpath.to_s.start_with?("#{artifact_base.realpath}/")
      cell_path = Pathname.new(contract.fetch("cellManifestPath"))
      if cell_path.file?
        resume_validator_argv = [
          "ruby", VALIDATOR.to_s,
          "--manifest", Pathname.new(options.fetch(:manifest)).expand_path.to_s,
          "--row-id", row.fetch("id"),
          "--artifact-base", artifact_base.to_s,
          "--cell-manifest", cell_path.to_s
        ]
        if system(*resume_validator_argv, chdir: ROOT.to_s)
          puts "shopping visual cell #{row.fetch("id")} resumed"
          next
        end
      end
      argv = contract.dig("manifest", "argv")
      raise ShoppingVisualMatrix::ValidationError, "capture failed for #{row.fetch("id")}" unless system(*argv, chdir: ROOT.to_s)
      cell_path.write(JSON.pretty_generate(contract.fetch("manifest")) + "\n")
      validator_argv = [
        "ruby", VALIDATOR.to_s,
        "--manifest", Pathname.new(options.fetch(:manifest)).expand_path.to_s,
        "--row-id", row.fetch("id"),
        "--artifact-base", artifact_base.to_s,
        "--cell-manifest", cell_path.to_s
      ]
      raise ShoppingVisualMatrix::ValidationError, "cell validation failed for #{row.fetch("id")}" unless system(*validator_argv, chdir: ROOT.to_s)
    end
    validate_exact_artifact_sets!(contracts, artifact_base)
  when "validate"
    contracts.each do |contract|
      row_id = contract.dig("manifest", "rowID")
      validator_argv = [
        "ruby", VALIDATOR.to_s,
        "--manifest", Pathname.new(options.fetch(:manifest)).expand_path.to_s,
        "--row-id", row_id,
        "--artifact-base", artifact_base.to_s,
        "--cell-manifest", contract.fetch("cellManifestPath")
      ]
      raise ShoppingVisualMatrix::ValidationError, "cell validation failed for #{row_id}" unless system(*validator_argv, chdir: ROOT.to_s)
    end
    validate_exact_artifact_sets!(contracts, artifact_base)
  end
  puts "shopping visual matrix #{options.fetch(:mode)} ok (#{rows.length} rows)"
rescue ShoppingVisualMatrix::ValidationError, Errno::ENOENT => error
  warn "shopping visual matrix failed: #{error.message}"
  exit 1
end
