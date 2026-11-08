# frozen_string_literal: true

require "cgi"
require "fileutils"
require "json"

# Builds the web/native parity contact sheet: each canonical screen, on each device, in each scheme, with the web
# shot (spoonjoy-v2's parity.desktop.journey.ts) beside the native one (ParityJourneys and DuoParityJourney). Shots
# are named parity-<screen>-<device>-<scheme>.png on both sides. A side with no shot gets a grey panel, labelled in
# index.html, so a gap is visible on the sheet instead of a pair silently disappearing.
module ParitySheet
  SCREENS = %w[kitchen recipe cook-step shopping cookbooks cookbook chef sign-in kitchen-empty sheet-add-to-list].freeze
  DEVICES = %w[iphone duo-open ipad desktop].freeze
  SCHEMES = %w[light dark].freeze
  # The outer display is off while the Duo is open, so an open-Duo shot only counts from the inner display.
  INNER_DEVICES = %w[duo-open].freeze
  # Known gaps, with the reason the sheet shows instead of "not captured".
  GAPS = {
    ["web", "sheet-add-to-list"] => "Add to list is one tap, no sheet",
    ["native", "desktop"] => "no Mac parity journey yet"
  }.freeze
  PANEL_SIZE = "900x1200"
  SHOT_HEIGHT = "x1200"

  NAME = /\Aparity-(?<screen>.+)-(?<device>#{DEVICES.join("|")})-(?<scheme>#{SCHEMES.join("|")})(?<inner>-inner)?(?:_\d+_[0-9A-Fa-f-]+)?\.png\z/

  Pair = Struct.new(:screen, :device, :scheme, :web, :native) do
    def key
      "#{screen}-#{device}-#{scheme}"
    end

    def complete?
      !web.nil? && !native.nil?
    end

    def file_name
      "#{key}.jpg"
    end
  end

  module_function

  def canonical_keys
    SCREENS.product(DEVICES, SCHEMES).map { |parts| parts.join("-") }
  end

  # [key, :plain | :inner] for a parity shot's file name, or nil for anything else.
  def shot_key(name)
    match = NAME.match(File.basename(name))
    return nil unless match && SCREENS.include?(match[:screen])

    ["#{match[:screen]}-#{match[:device]}-#{match[:scheme]}", match[:inner] ? :inner : :plain]
  end

  # { key => path } from shot paths; for the open Duo only the inner display counts, elsewhere only the plain shot.
  def index(paths)
    select(paths.map { |path| [File.basename(path), path] })
  end

  # { key => path } from an `xcrun xcresulttool export attachments` folder, whose manifest.json maps each exported
  # file to the attachment's name plus "_<index>_<UUID>".
  def index_export(dir)
    manifest = JSON.parse(File.read(File.join(dir, "manifest.json")))
    entries = manifest.flat_map { |test| test.fetch("attachments", []) }.map do |attachment|
      [attachment.fetch("suggestedHumanReadableName"), File.join(dir, attachment.fetch("exportedFileName"))]
    end
    select(entries)
  end

  def select(entries)
    entries.each_with_object({}) do |(name, path), found|
      key, kind = shot_key(name)
      next unless key

      wanted = inner?(key) ? :inner : :plain
      found[key] = path if kind == wanted
    end
  end

  def inner?(key)
    INNER_DEVICES.any? { |device| key.include?("-#{device}-") }
  end

  # The file name `index` reads back as `key`.
  def shot_file_name(key)
    inner?(key) ? "parity-#{key}-inner.png" : "parity-#{key}.png"
  end

  # Keys of the light shots in `index` whose dark shot is byte-identical: the scheme never switched.
  def unswitched_schemes(index)
    index.keys.select { |key| key.end_with?("-light") }.sort.select do |light|
      dark = index[light.sub(/-light\z/, "-dark")]
      dark && FileUtils.compare_file(index[light], dark)
    end
  end

  # Copies each shot of `index` into `dir` under its canonical name, for the parity-shots artifact. Returns the copies.
  def collect(index, dir)
    FileUtils.mkdir_p(dir)
    index.sort.map do |key, path|
      destination = File.join(dir, shot_file_name(key))
      FileUtils.cp(path, destination)
      destination
    end
  end

  def pairs(web:, native:)
    SCREENS.product(DEVICES, SCHEMES).map do |screen, device, scheme|
      key = "#{screen}-#{device}-#{scheme}"
      Pair.new(screen, device, scheme, web[key], native[key])
    end
  end

  def gap_label(side, screen, device = nil)
    "#{side}: #{GAPS[[side, screen]] || GAPS[[side, device]] || "not captured"}"
  end

  # The `magick` argv that sets web (left) beside native (right), each scaled to one height, with a plain grey panel
  # for a missing side. It draws no text, because ImageMagick without Freetype or Ghostscript cannot; index.html labels
  # every pair and every gap.
  def compose_command(pair, output)
    ["magick", "-background", "white", *side(pair.web), *side(pair.native), "+append", "-quality", "85", output]
  end

  def side(path)
    return ["(", path, "-resize", SHOT_HEIGHT, ")"] if path

    ["(", "-size", PANEL_SIZE, "xc:#d9d9d9", ")"]
  end

  def index_html(pairs, title:)
    complete = pairs.count(&:complete?)
    figures = pairs.map do |pair|
      state = pair.complete? ? "both sides" : [pair.web ? nil : gap_label("web", pair.screen, pair.device), pair.native ? nil : gap_label("native", pair.screen, pair.device)].compact.join("; ")
      <<~HTML
        <figure id="#{h(pair.key)}"><a href="#{h(pair.file_name)}"><img loading="lazy" src="#{h(pair.file_name)}" alt="#{h(pair.key)}"></a><figcaption>#{h(pair.key)} · #{h(state)}</figcaption></figure>
      HTML
    end
    <<~HTML
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{h(title)}</title>
      <style>
      body { font: 14px -apple-system, system-ui, sans-serif; margin: 16px; background: #fff; color: #111; }
      main { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 16px; }
      img { width: 100%; height: auto; border: 1px solid #ddd; }
      figure { margin: 0; }
      </style>
      </head>
      <body>
      <h1>#{h(title)}</h1>
      <p>#{complete} of #{pairs.size} pairs complete. Web on the left, native on the right.</p>
      <main>
      #{figures.join}</main>
      </body>
      </html>
    HTML
  end

  def h(text)
    CGI.escapeHTML(text.to_s)
  end
end
