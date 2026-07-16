#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "json"
require "open-uri"
require "open3"
require "optparse"
require "pathname"
require "shellwords"
require "tempfile"
require "tmpdir"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path
DEFAULT_POLICY = ROOT.join("security/native-advisory-pipeline.yml")
DEFAULT_ALLOWLIST = ROOT.join("security/native-advisory-allowlist.yml")
DEFAULT_GEMFILE_LOCK = ROOT.join("Gemfile.lock")
DEFAULT_OUTPUT = ROOT.join("artifacts/apple/ruby-advisory-report.json")
ADVISORY_BUNDLE_ENV = { "BUNDLE_WITHOUT" => "" }.freeze

def fail_scan(message, output_path: nil, status: "scanner_failed", details: {})
  warn "FAIL: #{message}"
  write_report(output_path, status, message, details) if output_path
  exit 1
end

def write_report(path, status, message, details = {})
  return unless path

  output = Pathname.new(path)
  FileUtils.mkdir_p(output.dirname)
  report = {
    ok: status == "pass",
    status: status,
    message: message,
    details: details,
    generatedAt: Time.now.utc.iso8601
  }
  output.write(JSON.pretty_generate(report) + "\n")
end

def load_yaml_file(path, label)
  fail_scan("#{label} is missing: #{path}") unless path.file?
  YAML.safe_load(path.read, permitted_classes: [Date], aliases: false) || {}
rescue Psych::SyntaxError => e
  fail_scan("#{label} is invalid YAML: #{e.message}")
end

def validate_allowlist(path, max_days:, today: Date.today)
  config = load_yaml_file(path, "allowlist")
  advisories = config.fetch("advisories") { fail_scan("allowlist missing advisories key: #{path}") }
  fail_scan("allowlist advisories must be an array") unless advisories.is_a?(Array)

  advisories.map.with_index do |entry, index|
    fail_scan("allowlist entry #{index + 1} must be a mapping") unless entry.is_a?(Hash)
    %w[id gem reason owner expires_on].each do |key|
      value = entry[key]
      fail_scan("allowlist entry #{index + 1} missing #{key}") if value.nil? || value.to_s.strip.empty?
    end

    expires_on = begin
      Date.iso8601(entry.fetch("expires_on").to_s)
    rescue Date::Error
      fail_scan("allowlist entry #{entry.fetch("id")} has non-ISO expires_on")
    end

    fail_scan("allowlist entry #{entry.fetch("id")} expired on #{expires_on}") unless expires_on > today
    fail_scan("allowlist entry #{entry.fetch("id")} expires beyond #{max_days} days") if expires_on > today + max_days

    entry.merge("expires_on" => expires_on.iso8601)
  end
end

def verify_installed_scanner(policy, skip_gem_sha:)
  scanner = policy.fetch("scanner")
  expected_name = scanner.fetch("name")
  expected_version = scanner.fetch("version").to_s
  expected_sha = scanner.fetch("gem_sha256")
  fail_scan("unsupported scanner #{expected_name.inspect}") unless expected_name == "bundler-audit"

  stdout, stderr, status = Open3.capture3(ADVISORY_BUNDLE_ENV, "bundle", "exec", "bundle-audit", "version", chdir: ROOT.to_s)
  fail_scan("bundler-audit version check failed", details: { stdout: stdout, stderr: stderr, exitStatus: status.exitstatus }) unless status.success?
  actual_version = stdout[/\d+(?:\.\d+)+/]
  fail_scan("bundler-audit version #{actual_version.inspect} did not match #{expected_version}") unless actual_version == expected_version

  return if skip_gem_sha

  Dir.mktmpdir("spoonjoy-bundler-audit-gem") do |dir|
    stdout, stderr, status = Open3.capture3("gem", "fetch", expected_name, "--version", expected_version, chdir: dir)
    fail_scan("failed to fetch scanner gem for SHA verification", details: { stdout: stdout, stderr: stderr, exitStatus: status.exitstatus }) unless status.success?
    gem_path = Pathname.new(dir).join("#{expected_name}-#{expected_version}.gem")
    fail_scan("scanner gem fetch did not produce #{gem_path.basename}") unless gem_path.file?
    actual_sha = Digest::SHA256.file(gem_path).hexdigest
    fail_scan("scanner gem SHA mismatch", details: { expected: expected_sha, actual: actual_sha }) unless actual_sha == expected_sha
  end
end

def prepare_advisory_database(policy)
  database = policy.fetch("advisory_database")
  repository = database.fetch("repository")
  ref = database.fetch("ref")
  dir = Pathname.new(Dir.mktmpdir("spoonjoy-ruby-advisory-db"))

  stdout, stderr, status = Open3.capture3("git", "init", "--quiet", dir.to_s)
  fail_scan("failed to initialize advisory database checkout", details: { stdout: stdout, stderr: stderr, exitStatus: status.exitstatus }) unless status.success?
  stdout, stderr, status = Open3.capture3("git", "-C", dir.to_s, "remote", "add", "origin", repository)
  fail_scan("failed to configure advisory database remote", details: { stdout: stdout, stderr: stderr, exitStatus: status.exitstatus }) unless status.success?
  stdout, stderr, status = Open3.capture3("git", "-C", dir.to_s, "fetch", "--depth", "1", "origin", ref)
  fail_scan("failed to fetch pinned ruby-advisory-db ref", details: { repository: repository, ref: ref, stdout: stdout, stderr: stderr, exitStatus: status.exitstatus }) unless status.success?
  stdout, stderr, status = Open3.capture3("git", "-C", dir.to_s, "checkout", "--quiet", "FETCH_HEAD")
  fail_scan("failed to checkout pinned ruby-advisory-db ref", details: { repository: repository, ref: ref, stdout: stdout, stderr: stderr, exitStatus: status.exitstatus }) unless status.success?
  actual = Open3.capture3("git", "-C", dir.to_s, "rev-parse", "HEAD").first.strip
  fail_scan("ruby-advisory-db SHA mismatch", details: { expected: ref, actual: actual }) unless actual == ref

  dir
end

def run_scanner(command_words, gemfile_lock, ignored_ids, database_dir:)
  Tempfile.create(["ruby-advisory-report", ".json"]) do |scanner_report|
    scan_dir = gemfile_lock.dirname
    args = command_words + [
      "check",
      scan_dir.to_s,
      "--no-update",
      "--format",
      "json",
      "--output",
      scanner_report.path,
      "--gemfile-lock",
      gemfile_lock.basename.to_s
    ]
    args.concat(["--database", database_dir.to_s]) if database_dir
    ignored_ids.each { |id| args.concat(["--ignore", id]) }

    stdout, stderr, status = Open3.capture3(ADVISORY_BUNDLE_ENV, *args, chdir: ROOT.to_s)
    report_text = scanner_report.size.positive? ? scanner_report.read : ""
    [status.exitstatus || 1, stdout, stderr, report_text, args.shelljoin]
  end
end

def classify_failure(exit_code, stdout, stderr, report_text)
  combined = [stdout, stderr, report_text].join("\n")
  return "actionable_findings" if exit_code == 1 && combined.match?(/(Unpatched versions found|Insecure Source URI found|"advisories"\s*:)/i)

  "scanner_failed"
end

def run_self_test!
  Dir.mktmpdir("spoonjoy-advisory-fixtures") do |dir|
    root = Pathname.new(dir)
    lock = root.join("Gemfile.lock")
    lock.write("GEM\n  specs:\n    rack (1.6.0)\n\nPLATFORMS\n  ruby\n\nDEPENDENCIES\n  rack\n\nBUNDLED WITH\n   2.4.22\n")
    allowlist = root.join("allowlist.yml")
    allowlist.write("advisories: []\n")
    expired = root.join("expired.yml")
    expired.write("advisories:\n  - id: CVE-2099-0001\n    gem: rack\n    reason: fixture\n    owner: security\n    expires_on: 2000-01-01\n")

    fake_network = root.join("fake-network.rb")
    fake_network.write("#!/usr/bin/env ruby\nwarn 'failed to update ruby-advisory-db'\nexit 2\n")
    fake_finding = root.join("fake-finding.rb")
    fake_finding.write(<<~RUBY)
      #!/usr/bin/env ruby
      require "json"
      output = ARGV[ARGV.index("--output") + 1]
      File.write(output, JSON.generate({ "advisories" => [{ "id" => "CVE-2099-0001", "gem" => "rack" }] }))
      warn "Unpatched versions found!"
      exit 1
    RUBY
    [fake_network, fake_finding].each { |path| path.chmod(0o755) }

    [
      ["missing lock", ["--gemfile-lock", root.join("missing.lock").to_s, "--allowlist", allowlist.to_s, "--skip-pin-verification", "--scanner-command", "ruby #{fake_network}"], "Gemfile.lock is missing"],
      ["network failure", ["--gemfile-lock", lock.to_s, "--allowlist", allowlist.to_s, "--skip-pin-verification", "--scanner-command", "ruby #{fake_network}"], "scanner_failed"],
      ["actionable finding", ["--gemfile-lock", lock.to_s, "--allowlist", allowlist.to_s, "--skip-pin-verification", "--scanner-command", "ruby #{fake_finding}"], "actionable_findings"],
      ["expired allowlist", ["--gemfile-lock", lock.to_s, "--allowlist", expired.to_s, "--skip-pin-verification", "--scanner-command", "ruby #{fake_network}"], "expired"]
    ].each do |name, args, expected|
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, __FILE__, *args)
      unless !status.success? && [stdout, stderr].join("\n").include?(expected)
        warn "self-test #{name} did not fail with #{expected}"
        warn "STDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
        exit 1
      end
    end
  end

  puts "native advisory scanner fixture tests ok"
end

options = {
  policy: DEFAULT_POLICY,
  allowlist: DEFAULT_ALLOWLIST,
  gemfile_lock: DEFAULT_GEMFILE_LOCK,
  output: DEFAULT_OUTPUT,
  scanner_command: "bundle exec bundle-audit",
  skip_pin_verification: false,
  self_test: false
}

OptionParser.new do |parser|
  parser.banner = "Usage: scan-ruby-advisories.rb [options]"
  parser.on("--policy PATH") { |value| options[:policy] = Pathname.new(value) }
  parser.on("--allowlist PATH") { |value| options[:allowlist] = Pathname.new(value) }
  parser.on("--gemfile-lock PATH") { |value| options[:gemfile_lock] = Pathname.new(value) }
  parser.on("--output PATH") { |value| options[:output] = Pathname.new(value) }
  parser.on("--scanner-command CMD") { |value| options[:scanner_command] = value }
  parser.on("--skip-pin-verification") { options[:skip_pin_verification] = true }
  parser.on("--self-test-fixtures") { options[:self_test] = true }
end.parse!

if options[:self_test]
  run_self_test!
  exit 0
end

gemfile_lock = options.fetch(:gemfile_lock).expand_path
output = options.fetch(:output).expand_path
policy = load_yaml_file(options.fetch(:policy).expand_path, "policy")
max_days = policy.fetch("allowlist").fetch("max_days").to_i

fail_scan("Gemfile.lock is missing: #{gemfile_lock}", output_path: output, status: "missing_lockfile") unless gemfile_lock.file?
verify_installed_scanner(policy, skip_gem_sha: false) unless options.fetch(:skip_pin_verification)
allowlist_entries = validate_allowlist(options.fetch(:allowlist).expand_path, max_days: max_days)
ignored_ids = allowlist_entries.map { |entry| entry.fetch("id") }
database_dir = options.fetch(:skip_pin_verification) ? nil : prepare_advisory_database(policy)
exit_code, stdout, stderr, report_text, command = run_scanner(Shellwords.split(options.fetch(:scanner_command)), gemfile_lock, ignored_ids, database_dir: database_dir)

if exit_code.zero?
  write_report(output, "pass", "ruby advisory scan ok", {
    command: command,
    gemfileLock: gemfile_lock.relative_path_from(ROOT).to_s,
    allowlistedAdvisories: ignored_ids,
    scannerReport: report_text.empty? ? nil : JSON.parse(report_text)
  })
  puts "ruby advisory scan ok"
  exit 0
end

status = classify_failure(exit_code, stdout, stderr, report_text)
fail_scan("ruby advisory scan failed with #{status}", output_path: output, status: status, details: {
  command: command,
  exitStatus: exit_code,
  stdout: stdout,
  stderr: stderr,
  scannerReport: report_text
})
