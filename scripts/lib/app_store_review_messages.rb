# frozen_string_literal: true

require "cgi"
require_relative "app_store_listing"

# Reads what App Review said about a submission. The public API reports review submission states; the message text
# lives in Resolution Center, which Apple does not document. This tries the observed Resolution Center paths on both
# hosts with the same API key and reports each HTTP outcome, so a reader learns which route works today.
module AppStoreReviewMessages
  HOSTS = ["https://api.appstoreconnect.apple.com", "https://appstoreconnect.apple.com/iris"].freeze

  # App Review writes messages as HTML. Returns readable text with paragraph breaks kept.
  def self.plain_text(html)
    text = html.to_s.gsub(%r{<br\s*/?>|</p>|</li>|</div>}i, "\n").gsub(/<li[^>]*>/i, "- ").gsub(/<[^>]+>/, "")
    CGI.unescapeHTML(text).gsub(/[ \t]+/, " ").gsub(/ *\n */, "\n").gsub(/\n{3,}/, "\n\n").strip
  end

  # Candidate thread listings, most specific first.
  def self.thread_urls(app_id:, submission_ids:)
    HOSTS.flat_map do |host|
      submission_ids.map { |id| "#{host}/v1/resolutionCenterThreads?filter[reviewSubmission]=#{id}" } +
        ["#{host}/v1/apps/#{app_id}/resolutionCenterThreads"]
    end
  end

  # Picks the submissions worth reading: anything App Review has answered or is holding.
  def self.answered(submissions)
    submissions.select { |s| %w[UNRESOLVED_ISSUES COMPLETE CANCELING].include?(s.dig("attributes", "state")) }
  end

  class Reader
    def initialize(client, app_id:, platform:, log: $stdout)
      @client = client
      @app_id = app_id
      @platform = platform
      @log = log
    end

    def submissions
      @client.get("/v1/reviewSubmissions", "filter[app]" => @app_id, "filter[platform]" => @platform,
                                           "limit" => 20)["data"]
    end

    def run
      subs = submissions
      @log.puts "Review submissions (#{@platform}):"
      subs.each do |s|
        a = s["attributes"] || {}
        @log.puts "- #{s['id']}: #{a['state']} submitted #{a['submittedDate']}"
      end
      ids = AppStoreReviewMessages.answered(subs).map { |s| s["id"] }
      AppStoreReviewMessages.thread_urls(app_id: @app_id, submission_ids: ids).each do |url|
        threads = try(url)
        next unless threads

        threads.fetch("data", []).each { |thread| print_thread(url, thread) }
        return true
      end
      @log.puts "No Resolution Center route answered with this API key. Read the message in the App Store Connect web app."
      false
    end

    private

    def try(url)
      body = @client.get(url)
      @log.puts "OK #{url}"
      body
    rescue AppStoreListing::Error => e
      @log.puts "No #{url}: #{e.message[0, 200]}"
      nil
    end

    def print_thread(thread_url, thread)
      base = thread_url[%r{\A.*?/v1}]
      @log.puts "Thread #{thread['id']} (#{thread.dig('attributes', 'threadType')}, #{thread.dig('attributes', 'state')})"
      messages = try("#{base}/resolutionCenterThreads/#{thread['id']}/resolutionCenterMessages?include=rejections")
      return unless messages

      messages.fetch("data", []).each do |m|
        @log.puts "--- #{m.dig('attributes', 'createdDate')}"
        @log.puts AppStoreReviewMessages.plain_text(m.dig("attributes", "messageBody"))
      end
      messages.fetch("included", []).select { |i| i["type"] == "reviewRejections" }.each do |r|
        @log.puts "Rejection: #{JSON.generate(r['attributes'])}"
      end
    end
  end
end
