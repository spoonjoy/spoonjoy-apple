#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "pathname"
require_relative "shopping-visual-matrix"

ROOT = Pathname.new(__dir__).join("..").expand_path
options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: validate-shopping-visual-cell.rb --manifest PATH --row-id ID --artifact-base PATH --cell-manifest PATH"
  parser.on("--manifest PATH") { |value| options[:manifest] = value }
  parser.on("--row-id ID") { |value| options[:row_id] = value }
  parser.on("--artifact-base PATH") { |value| options[:artifact_base] = value }
  parser.on("--cell-manifest PATH") { |value| options[:cell_manifest] = value }
end.parse!

begin
  %i[manifest row_id artifact_base cell_manifest].each do |key|
    raise ShoppingVisualMatrix::ValidationError, "missing --#{key.to_s.tr("_", "-")}" unless options[key]
  end
  matrix = ShoppingVisualMatrix.load!(options.fetch(:manifest), repository_root: ROOT)
  row = matrix.fetch("rows").find { |candidate| candidate.fetch("id") == options.fetch(:row_id) }
  raise ShoppingVisualMatrix::ValidationError, "unknown canonical row #{options.fetch(:row_id)}" unless row

  ShoppingVisualMatrix.validate_resolved_artifact_root!(row, artifact_base: options.fetch(:artifact_base))
  contract = ShoppingVisualMatrix.cell_contract(row, matrix: matrix, artifact_base: options.fetch(:artifact_base))
  cell_path = Pathname.new(options.fetch(:cell_manifest)).expand_path.cleanpath
  expected_cell_path = Pathname.new(contract.fetch("cellManifestPath"))
  raise ShoppingVisualMatrix::ValidationError, "cell manifest path does not match canonical row" unless cell_path == expected_cell_path
  raise ShoppingVisualMatrix::ValidationError, "cell manifest must be a regular file" unless cell_path.file? && !cell_path.symlink?
  candidate = JSON.parse(cell_path.binread)
  ShoppingVisualMatrix.validate_cell_manifest!(candidate, contract.fetch("manifest"))

  contract.fetch("artifactPaths").each do |kind, path_string|
    path = Pathname.new(path_string)
    raise ShoppingVisualMatrix::ValidationError, "missing or empty #{kind} artifact #{path}" unless path.file? && path.size.positive? && !path.symlink?
  end
  puts "shopping visual cell #{row.fetch("id")} ok"
rescue JSON::ParserError, ShoppingVisualMatrix::ValidationError => error
  warn "shopping visual cell validation failed: #{error.message}"
  exit 1
end
