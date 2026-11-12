# frozen_string_literal: true

require "json"
require "open3"
require "tmpdir"

# Finds the iOS and Mac builds TestFlight (.github/workflows/testflight.yml) published from one source commit. Each
# TestFlight run is named "TestFlight <sha>" and uploads one publish summary per platform, written only once App
# Store Connect has marked that build VALID. Staging or submitting both platforms reads them here.
module ReleaseTrainBuilds
  class Error < StandardError; end

  SUMMARIES = {
    "IOS" => ["testflight-publish-artifacts-%s", "testflight-publish-summary.json"],
    "MAC_OS" => ["mac-app-store-publish-artifacts-%s", "mac-app-store-publish-summary.json"]
  }.freeze
  NAMES = { "IOS" => "iOS", "MAC_OS" => "macOS" }.freeze

  # The runs that uploaded a publish summary for sha, newest first.
  def self.candidate_runs(runs)
    runs.uniq { |run| run["id"] }.sort_by { |run| run["created_at"].to_s }.reverse
  end

  # {"runId", "IOS" => {buildNumber, buildId}, "MAC_OS" => {...}} from the newest run that published both, else Error.
  # artifacts answers runs(sha) ([{id, created_at}] of runs holding a summary artifact for sha) and
  # summary(run_id, artifact, file) (parsed JSON, or nil when the run has no such artifact).
  def self.find(sha, artifacts)
    reasons = []
    candidates = candidate_runs(artifacts.runs(sha))
    reasons << "No TestFlight run uploaded a publish summary for it." if candidates.empty?
    candidates.each do |run|
      builds = {}
      problems = SUMMARIES.filter_map do |platform, (artifact, file)|
        summary = artifacts.summary(run["id"], format(artifact, sha), file)
        problem = summary_problem(summary, platform, sha)
        builds[platform] = summary.slice("buildNumber", "buildId") unless problem
        problem
      end
      return { "runId" => run["id"] }.merge(builds) if problems.empty?

      reasons << "Run #{run['id']}: #{problems.join('; ')}."
    end
    raise Error, "No TestFlight run published both an iOS and a Mac build from #{sha}. #{reasons.join(' ')} " \
                 "Dispatch TestFlight for this commit, then try again."
  end

  def self.summary_problem(summary, platform, sha)
    name = NAMES.fetch(platform)
    return "no #{name} summary" if summary.nil?
    return "#{name} summary is for #{summary['sourceSha']}" unless summary["sourceSha"] == sha
    return "#{name} summary has no build" if summary["buildNumber"].to_s.empty? || summary["buildId"].to_s.empty?

    state = summary["processingState"]
    "#{name} build #{summary['buildNumber']} is #{state}, not VALID" if state && state != "VALID"
  end

  # Reads publish summary artifacts with the gh CLI (GH_TOKEN with actions: read). Artifacts are found by name, so
  # any run within artifact retention (90 days) counts, release branch runs included.
  class GitHubArtifacts
    def initialize(repository)
      @repository = repository
    end

    def runs(sha)
      SUMMARIES.values.flat_map do |artifact, _file|
        body = gh("api", "repos/#{@repository}/actions/artifacts?name=#{format(artifact, sha)}&per_page=100")
        JSON.parse(body).fetch("artifacts").reject { |row| row["expired"] }.map do |row|
          { "id" => row.dig("workflow_run", "id"), "created_at" => row["created_at"] }
        end
      end
    end

    def summary(run_id, artifact, file)
      listed = JSON.parse(gh("api", "repos/#{@repository}/actions/runs/#{run_id}/artifacts?name=#{artifact}"))
      return nil if listed.fetch("artifacts").none? { |row| !row["expired"] }

      Dir.mktmpdir("release-train-builds") do |dir|
        gh("run", "download", run_id.to_s, "-R", @repository, "-n", artifact, "-D", dir)
        path = File.join(dir, file)
        return nil unless File.file?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        raise Error, "Run #{run_id} #{artifact}/#{file} is not JSON: #{e.message}"
      end
    end

    private

    def gh(*args)
      out, err, status = Open3.capture3("gh", *args)
      raise Error, "gh #{args.first(2).join(' ')} failed: #{err.strip}" unless status.success?

      out
    end
  end
end
