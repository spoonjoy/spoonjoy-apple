# frozen_string_literal: true

require_relative "app_store_listing"

# Reads what Apple knows about crashes in one App Store version's builds: Xcode Organizer diagnostic signatures and
# their logs (GET /v1/builds/{id}/diagnosticSignatures, GET /v1/diagnosticSignatures/{id}/logs) and TestFlight crash
# feedback (GET /v1/apps/{id}/betaFeedbackCrashSubmissions, GET /v1/betaFeedbackCrashSubmissions/{id}/crashLog).
#
# The repository is public, so this prints only what a diagnosis needs: OS, device model, build, the exception and
# the crashing thread's frames. It never prints tester names, emails, comments or device identifiers.
module AppStoreCrashDiagnostics
  MAX_FRAMES = 25
  # Crash report lines worth keeping outside the crashing thread.
  CRASH_HEADER = /\A(Hardware Model|OS Version|Version|Exception Type|Exception Codes|Exception Reason|Termination Reason|Triggered by Thread|Crashed Thread):/

  # The first call stack of a diagnostic log, flattened along its first child at each level (the hottest path).
  def self.frames(call_stack_tree)
    stack = Array(call_stack_tree).first&.fetch("callStacks", [])&.first
    frame = stack && Array(stack["callStackRootFrames"]).first
    lines = []
    while frame && lines.size < MAX_FRAMES
      symbol = frame["symbol"] || "+#{frame['offsetIntoBinaryTextSegment']}"
      lines << "#{frame['binaryName']} #{symbol}"
      frame = Array(frame["subFrames"]).first
    end
    lines
  end

  # The exception lines and the crashing thread's frames from a crash report's text.
  def self.crash_excerpt(text)
    lines = text.to_s.lines.map(&:rstrip)
    header = lines.grep(CRASH_HEADER)
    start = lines.index { |line| line.match?(/\AThread \d+( name: .*)? Crashed:/) || line.match?(/\AThread \d+ Crashed::/) }
    thread = []
    if start
      thread = lines[start..].take_while.with_index { |line, i| i.zero? || !line.strip.empty? }.first(MAX_FRAMES + 1)
    end
    header + thread
  end

  class Reader
    def initialize(client, app_id:, platform:, version_string:, log: $stdout)
      @client = client
      @app_id = app_id
      @platform = platform
      @version_string = version_string
      @log = log
    end

    def builds
      @client.get_all("/v1/builds", "filter[app]" => @app_id, "filter[preReleaseVersion.version]" => @version_string,
                                    "filter[preReleaseVersion.platform]" => @platform)
    end

    def run
      found = builds
      @log.puts "#{@platform} #{@version_string} builds: #{found.map { |b| b.dig('attributes', 'version') }.join(', ')}"
      ids = found.to_h { |b| [b["id"], b.dig("attributes", "version")] }
      ids.each { |id, number| report_signatures(id, number) }
      report_feedback(ids)
    end

    private

    def try(path, query = {})
      @client.get(path, query)
    rescue AppStoreListing::Error => e
      @log.puts "No #{path}: #{e.message[0, 200]}"
      nil
    end

    def report_signatures(build_id, number)
      body = try("/v1/builds/#{build_id}/diagnosticSignatures")
      return unless body

      signatures = body.fetch("data", [])
      @log.puts "Build #{number}: #{signatures.size} diagnostic signature(s)"
      signatures.each do |signature|
        a = signature["attributes"] || {}
        @log.puts "- #{a['diagnosticType']} weight #{a['weight']}: #{a['signature']}"
        logs = try("/v1/diagnosticSignatures/#{signature['id']}/logs")
        Array(logs&.fetch("productData", nil)).each do |product|
          Array(product["diagnosticLogs"]).first(3).each do |entry|
            meta = entry["diagnosticMetaData"] || {}
            @log.puts "  #{meta['deviceType']} #{meta['osVersion']} build #{meta['buildVersion']}"
            AppStoreCrashDiagnostics.frames(entry["callStackTree"]).each { |line| @log.puts "    #{line}" }
          end
        end
      end
    end

    def report_feedback(build_numbers)
      submissions = try("/v1/apps/#{@app_id}/betaFeedbackCrashSubmissions", "limit" => 50)
      return unless submissions

      items = submissions.fetch("data", [])
      @log.puts "TestFlight crash feedback: #{items.size} submission(s)"
      items.each do |item|
        a = item["attributes"] || {}
        build_id = item.dig("relationships", "build", "data", "id")
        @log.puts "- #{a['createdDate']} #{a['deviceModel']} #{a['osVersion']} build #{build_numbers.fetch(build_id, build_id || '?')}"
        crash = try("/v1/betaFeedbackCrashSubmissions/#{item['id']}/crashLog")
        AppStoreCrashDiagnostics.crash_excerpt(crash&.dig("data", "attributes", "logText")).each { |line| @log.puts "    #{line}" }
      end
    end
  end
end
