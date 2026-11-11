# frozen_string_literal: true

# Publish only from green: a commit goes to TestFlight or the App Store only after its own Native push run on that
# branch passed every check main's branch protection requires. TestFlight's candidate verifier and the gate in
# front of "Stage App Store listing" and "Submit for App Review" both read this list.
module GreenCommit
  # Native's jobs for the required checks on main, by name. Keep in step with the branch protection and AGENTS.md.
  REQUIRED_CHECKS = [
    "Swift tests",
    "Native scenario verifier",
    "App bundle",
    "Contracts",
    "Reins journeys"
  ].freeze
  # Release branches cut before Reins journeys existed (release/1.0-resubmit) have no such job; there it may be
  # absent, never skipped or failed. main always needs every check.
  ADDED_LATER = ["Reins journeys"].freeze
  NATIVE_WORKFLOW_PATH = ".github/workflows/native.yml"
  SHA = /\A[0-9a-f]{40}\z/.freeze
  BRANCH = %r{\A(main|release/[0-9][0-9A-Za-z.-]*)\z}.freeze

  class NotGreen < StandardError; end

  # The latest Native push run for sha on branch, from the workflow runs API's "workflow_runs".
  def self.latest_run(runs, sha:, branch:)
    exact = Array(runs).select do |run|
      run["head_sha"] == sha && run["head_branch"] == branch && run["event"] == "push" && run["path"] == NATIVE_WORKFLOW_PATH
    end
    raise NotGreen, "#{sha} has no Native push run on #{branch}; publish only a commit that landed there" if exact.empty?

    exact.max_by { |run| [run["run_number"].to_i, run["run_attempt"].to_i, run["id"].to_i] }
  end

  # The checks a branch's Native run must carry.
  def self.required_for(branch, jobs)
    return REQUIRED_CHECKS if branch == "main"

    names = Array(jobs).map { |job| job["name"] }
    REQUIRED_CHECKS.reject { |name| ADDED_LATER.include?(name) && !names.include?(name) }
  end

  # Raises NotGreen unless the run finished green and every required check in it passed.
  def self.require_green!(run, jobs, required: required_for(run["head_branch"], jobs))
    unless run["status"] == "completed" && run["conclusion"] == "success"
      raise NotGreen, "Native run #{run['id']} for #{run['head_sha']} is #{run['status']}/#{run['conclusion'] || 'pending'}, not green"
    end

    required.each do |name|
      matching = Array(jobs).select { |job| job["name"] == name }
      raise NotGreen, "Native run #{run['id']} has no #{name} job" if matching.empty?
      raise NotGreen, "Native run #{run['id']} has #{matching.length} #{name} jobs" if matching.length > 1

      job = matching.first
      next if job["status"] == "completed" && job["conclusion"] == "success"

      raise NotGreen, "#{name} did not pass in Native run #{run['id']} (#{job['conclusion'] || job['status']})"
    end
    run
  end
end
