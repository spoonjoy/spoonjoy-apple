#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
VERIFIER = ROOT.join("scripts/verify-release-ownership-handoff.rb")
TASK_ROOT = ROOT.join("worker/tasks/2026-07-16-0856-doing-audit-release-train")
RELEASE_SCHEMA = TASK_ROOT.join("outbound-owner-release.schema.json")
ACK_SCHEMA = TASK_ROOT.join("receiver-ack.schema.json")
RELEASE_RELATIVE_PATH = "worker/tasks/2026-07-16-0856-doing-audit-release-train/outbound-owner-release.json"
UPSTREAM_ACK_RELATIVE_PATH = "worker/tasks/2026-07-16-0856-doing-audit-release-train/receiver-ack.json"
OUTBOUND_REPOSITORY = "spoonjoy/spoonjoy-apple"
DELIVERY_REPOSITORY = "spoonjoy/spoonjoy-delivery"
OUTBOUND_REF = "refs/heads/main"
LEDGER_REF = "refs/heads/release-ledger"
DELIVERY_ACK_REF = "refs/heads/main"
OUTBOUND_COMMIT = "1" * 40
LEDGER_COMMIT = "2" * 40
DELIVERY_ACK_COMMIT = "3" * 40
UPSTREAM_ACK_COMMIT = "4" * 40
DRIFT_COMMIT = "5" * 40
AUTHORITY_POLICY_COMMIT = "a" * 40
ROOT_AUTHORITY_EVENT_COMMIT = "b" * 40
AUTHORITY_POLICY_PATH = "policy/delivery-authority-v1.json"
ROOT_AUTHORITY_EVENT_PATH = "ledger/events/root-authority-installed.json"
RECEIVER_TASK_ID = "019f5c80-bbe0-76a1-82eb-b0c715d035e7"
RECEIVER_DESK_TASK = "spoonjoy/cross-client-delivery"
LEDGER_APP_ID = 424_242

class ContractCheckFailure < StandardError; end

def fail_check(message)
  raise ContractCheckFailure, message
end

def canonical_json(value)
  case value
  when Hash
    "{" + value.keys.sort.map { |key| "#{JSON.generate(key)}:#{canonical_json(value.fetch(key))}" }.join(",") + "}"
  when Array
    "[" + value.map { |item| canonical_json(item) }.join(",") + "]"
  else
    JSON.generate(value)
  end
end

def sha256(value)
  Digest::SHA256.hexdigest(value)
end

def pretty_json(value)
  JSON.pretty_generate(value) + "\n"
end

def deep_copy(value)
  Marshal.load(Marshal.dump(value))
end

def authority_policy_document
  {
    "schemaVersion" => 1,
    "policyType" => "DeliveryAuthorityPolicy",
    "ledger" => { "githubAppID" => LEDGER_APP_ID }
  }
end

def authority_policy_bytes
  pretty_json(authority_policy_document)
end

def root_authority_event_document
  {
    "schemaVersion" => 1,
    "eventType" => "RootAuthorityInstalled",
    "payload" => {
      "authorityPolicyCommit" => AUTHORITY_POLICY_COMMIT,
      "authorityPolicyPath" => AUTHORITY_POLICY_PATH,
      "authorityPolicySHA256" => sha256(authority_policy_bytes),
      "ledgerAppID" => LEDGER_APP_ID
    }
  }
end

def root_authority_event_bytes
  pretty_json(root_authority_event_document)
end

def release_document
  {
    "schemaVersion" => 1,
    "releaseTaskID" => "019f2e25-2fc3-75b2-8ba3-335f3777115a",
    "receiverTaskID" => RECEIVER_TASK_ID,
    "receiverDeskTask" => RECEIVER_DESK_TASK,
    "createdAt" => "2026-07-21T08:00:00Z",
    "web" => {
      "sha" => "6" * 40,
      "tree" => "7" * 40,
      "workerDeploymentID" => "7d78e10e-0610-4d94-9dec-7079904a8eaa",
      "productionDeployRunID" => "29793583588"
    },
    "native" => {
      "sha" => "8" * 40,
      "mainRunID" => "29537952711",
      "testFlight" => {
        "appID" => "6787505444",
        "buildID" => "build-identifier",
        "betaDetailID" => "beta-detail-identifier",
        "groupID" => "31d60f58-aef9-4d44-b047-3a1f0dc61b5e",
        "version" => "1.0",
        "buildNumber" => "99",
        "internalAttached" => true,
        "externalGroupIDs" => [],
        "testersNotified" => true
      }
    },
    "provider" => {
      "appleCallbackMode" => "legacy-form-post",
      "state" => "terminal",
      "proofArtifact" => "evidence/provider-proof.json"
    },
    "handoffAuthority" => {
      "repository" => DELIVERY_REPOSITORY,
      "ledgerAppID" => LEDGER_APP_ID,
      "policy" => {
        "ref" => DELIVERY_ACK_REF,
        "commit" => AUTHORITY_POLICY_COMMIT,
        "path" => AUTHORITY_POLICY_PATH,
        "sha256" => sha256(authority_policy_bytes)
      },
      "rootEvent" => {
        "ref" => LEDGER_REF,
        "commit" => ROOT_AUTHORITY_EVENT_COMMIT,
        "path" => ROOT_AUTHORITY_EVENT_PATH,
        "sha256" => sha256(root_authority_event_bytes)
      }
    },
    "zeroInFlightWebMutations" => true,
    "zeroInFlightNativeMutations" => true,
    "zeroInFlightProviderMutations" => true,
    "residualBlockers" => [],
    "ownership" => {
      "webSourceOwner" => RECEIVER_TASK_ID,
      "nativeSourceOwner" => RECEIVER_TASK_ID,
      "providerOwner" => RECEIVER_TASK_ID,
      "testFlightOwner" => RECEIVER_TASK_ID,
      "artifactOwner" => RECEIVER_DESK_TASK,
      "webCleanupOwner" => RECEIVER_TASK_ID,
      "nativeCleanupOwner" => RECEIVER_TASK_ID,
      "worktrees" => [
        {
          "path" => "/Users/example/spoonjoy-apple",
          "repo" => "spoonjoy-apple",
          "head" => "8" * 40,
          "owner" => RECEIVER_TASK_ID,
          "disposition" => "retained"
        }
      ]
    },
    "evidence" => {
      "indexPath" => "worker/tasks/release/evidence-index.md",
      "indexSHA256" => "9" * 64,
      "closureArtifactPath" => "evidence/release-closure.json",
      "closureArtifactSHA256" => "a" * 64
    }
  }
end

def fixture_documents
  release = release_document
  release_bytes = pretty_json(release)
  release_digest = sha256(release_bytes)
  ledger_payload = {
    "ledgerAppID" => LEDGER_APP_ID,
    "outboundReleaseSHA256" => release_digest,
    "receiverTaskID" => RECEIVER_TASK_ID,
    "receiverDeskTask" => RECEIVER_DESK_TASK
  }
  ledger_event = {
    "schemaVersion" => 1,
    "eventType" => "ReceiverAcknowledged",
    "payload" => ledger_payload,
    "actorID" => "16390116"
  }
  ledger_bytes = pretty_json(ledger_event)
  ack = {
    "schemaVersion" => 1,
    "eventType" => "ReceiverAcknowledged",
    "outboundRelease" => {
      "repository" => OUTBOUND_REPOSITORY,
      "commit" => OUTBOUND_COMMIT,
      "path" => RELEASE_RELATIVE_PATH,
      "sha256" => release_digest
    },
    "ledgerEvent" => {
      "repository" => DELIVERY_REPOSITORY,
      "ref" => LEDGER_REF,
      "commit" => LEDGER_COMMIT,
      "payloadPath" => "ledger/events/receiver-acknowledged.json",
      "payloadSHA256" => sha256(canonical_json(ledger_payload)),
      "appID" => LEDGER_APP_ID
    },
    "receiver" => {
      "taskID" => RECEIVER_TASK_ID,
      "deskTask" => RECEIVER_DESK_TASK
    },
    "protectedOutbound" => deep_copy(release)
  }
  ack_bytes = pretty_json(ack)
  delivery_ack_path = "records/handoffs/#{release_digest}/receiver-ack.json"

  [release, release_bytes, ledger_event, ledger_bytes, ack, ack_bytes, delivery_ack_path]
end

def expected_main_checks(repository)
  case repository
  when OUTBOUND_REPOSITORY
    ["Swift tests", "Native scenario verifier", "App bundle", "Coverage"].map do |context|
      { "context" => context, "app_id" => 15_368 }
    end
  when DELIVERY_REPOSITORY
    [{ "context" => "CI", "app_id" => 15_368 }]
  else
    fail_check("no expected main checks for #{repository}")
  end
end

def classic_protection(repository)
  {
    "allow_force_pushes" => { "enabled" => false },
    "allow_deletions" => { "enabled" => false },
    "enforce_admins" => { "enabled" => true },
    "required_pull_request_reviews" => {
      "required_approving_review_count" => 1,
      "bypass_pull_request_allowances" => {
        "users" => [],
        "teams" => [],
        "apps" => []
      }
    },
    "required_status_checks" => {
      "strict" => true,
      "checks" => expected_main_checks(repository)
    },
    "restrictions" => {
      "users" => [],
      "teams" => [],
      "apps" => []
    }
  }
end

def protected_main_ruleset(id: 1, enforcement: "active", bypass_actors: [])
  {
    "id" => id,
    "name" => "ProtectedMainV1",
    "target" => "branch",
    "enforcement" => enforcement,
    "bypass_actors" => bypass_actors,
    "conditions" => {
      "ref_name" => {
        "include" => ["refs/heads/main"],
        "exclude" => []
      }
    },
    "rules" => [
      { "type" => "deletion" },
      { "type" => "non_fast_forward" },
      {
        "type" => "pull_request",
        "parameters" => { "required_approving_review_count" => 1 }
      },
      {
        "type" => "required_status_checks",
        "parameters" => {
          "strict_required_status_checks_policy" => true,
          "required_status_checks" => [
            { "context" => "CI", "integration_id" => 15_368 }
          ]
        }
      }
    ]
  }
end

def protected_ledger_ruleset(id: 10, app_id: LEDGER_APP_ID, bypass_actors: nil)
  {
    "id" => id,
    "name" => "ProtectedLedgerV1",
    "target" => "branch",
    "enforcement" => "active",
    "bypass_actors" => bypass_actors || [
      { "actor_id" => app_id, "actor_type" => "Integration", "bypass_mode" => "always" }
    ],
    "conditions" => {
      "ref_name" => {
        "include" => ["refs/heads/release-ledger"],
        "exclude" => []
      }
    },
    "rules" => [
      { "type" => "update" },
      { "type" => "deletion" },
      { "type" => "non_fast_forward" }
    ]
  }
end

def repository_fixture(release_bytes:, ledger_bytes:, ack_bytes:, delivery_ack_path:)
  {
    "repositories" => {
      OUTBOUND_REPOSITORY => {
        "defaultBranch" => "main",
        "refs" => {
          OUTBOUND_REF => UPSTREAM_ACK_COMMIT
        },
        "protections" => {
          OUTBOUND_REF => classic_protection(OUTBOUND_REPOSITORY)
        },
        "rulesets" => [],
        "commits" => {
          OUTBOUND_COMMIT => {
            "ancestors" => [],
            "files" => { RELEASE_RELATIVE_PATH => release_bytes }
          },
          UPSTREAM_ACK_COMMIT => {
            "ancestors" => [OUTBOUND_COMMIT],
            "files" => { UPSTREAM_ACK_RELATIVE_PATH => ack_bytes }
          },
          DRIFT_COMMIT => {
            "ancestors" => [OUTBOUND_COMMIT, UPSTREAM_ACK_COMMIT],
            "files" => {}
          }
        }
      },
      DELIVERY_REPOSITORY => {
        "defaultBranch" => "main",
        "refs" => {
          LEDGER_REF => LEDGER_COMMIT,
          DELIVERY_ACK_REF => DELIVERY_ACK_COMMIT
        },
        "protections" => {
          DELIVERY_ACK_REF => classic_protection(DELIVERY_REPOSITORY)
        },
        "rulesets" => [protected_ledger_ruleset],
        "commits" => {
          LEDGER_COMMIT => {
            "ancestors" => [ROOT_AUTHORITY_EVENT_COMMIT],
            "files" => { "ledger/events/receiver-acknowledged.json" => ledger_bytes }
          },
          ROOT_AUTHORITY_EVENT_COMMIT => {
            "ancestors" => [],
            "files" => { ROOT_AUTHORITY_EVENT_PATH => root_authority_event_bytes }
          },
          AUTHORITY_POLICY_COMMIT => {
            "ancestors" => [],
            "files" => { AUTHORITY_POLICY_PATH => authority_policy_bytes }
          },
          DELIVERY_ACK_COMMIT => {
            "ancestors" => [AUTHORITY_POLICY_COMMIT],
            "files" => { delivery_ack_path => ack_bytes }
          },
          DRIFT_COMMIT => {
            "ancestors" => [DELIVERY_ACK_COMMIT],
            "files" => {}
          }
        }
      }
    },
    "driftRefs" => {},
    "driftProtections" => {},
    "driftRulesets" => {}
  }
end

FAKE_GH = <<~'RUBY'
  #!/usr/bin/env ruby
  require "base64"
  require "json"
  require "uri"

  fixture = JSON.parse(File.read(ENV.fetch("FAKE_GH_FIXTURE")))
  state_path = ENV.fetch("FAKE_GH_STATE")
  state = File.exist?(state_path) ? JSON.parse(File.read(state_path)) : {}
  abort "expected gh api" unless ARGV.shift == "api"
  if ARGV[0] == "--method"
    ARGV.shift
    abort "only GET is supported" unless ARGV.shift == "GET"
  end
  endpoint = ARGV.shift
  fields = ARGV.each_slice(2).to_h
  match = endpoint.match(%r{\Arepos/([^/]+/[^/]+)(?:/(.*))?\z}) or abort "bad endpoint #{endpoint}"
  repository = match[1]
  path = match[2].to_s
  repo = fixture.fetch("repositories").fetch(repository)

  response = case path
             when ""
               { "default_branch" => repo.fetch("defaultBranch") }
             when %r{\Agit/commits/([0-9a-f]{40})\z}
               sha = Regexp.last_match(1)
               abort "commit not found" unless repo.fetch("commits").key?(sha)
               { "sha" => sha }
             when %r{\Agit/ref/(.+)\z}
               ref = "refs/#{URI.decode_www_form_component(Regexp.last_match(1))}"
               key = "#{repository}|#{ref}"
               sequence = fixture.fetch("driftRefs", {}).fetch(key, nil)
               if sequence
                 index = state.fetch(key, 0)
                 sha = sequence.fetch([index, sequence.length - 1].min)
                 state[key] = index + 1
                 File.write(state_path, JSON.generate(state))
               else
                 sha = repo.fetch("refs").fetch(ref)
               end
               { "ref" => ref, "object" => { "type" => "commit", "sha" => sha } }
             when %r{\Abranches/(.+)/protection\z}
               branch = URI.decode_www_form_component(Regexp.last_match(1))
               ref = "refs/heads/#{branch}"
               key = "#{repository}|#{ref}"
               sequence = fixture.fetch("driftProtections", {}).fetch(key, nil)
               if sequence
                 state_key = "protection|#{key}"
                 index = state.fetch(state_key, 0)
                 protection = sequence.fetch([index, sequence.length - 1].min)
                 state[state_key] = index + 1
                 File.write(state_path, JSON.generate(state))
               else
                 protection = repo.fetch("protections", {})[ref]
               end
               unless protection
                 puts JSON.generate({ "message" => "Branch not protected", "status" => 404 })
                 exit 1
               end
               protection
             when "rulesets"
               sequence = fixture.fetch("driftRulesets", {}).fetch(repository, nil)
               if sequence
                 state_key = "rulesets|#{repository}"
                 index = state.fetch(state_key, 0)
                 rulesets = sequence.fetch([index, sequence.length - 1].min)
                 state[state_key] = index + 1
                 File.write(state_path, JSON.generate(state))
               else
                 rulesets = repo.fetch("rulesets", [])
               end
               rulesets.map do |ruleset|
                 ruleset.slice("id", "name", "target", "enforcement")
               end
             when %r{\Arulesets/(\d+)\z}
               id = Regexp.last_match(1).to_i
               repo.fetch("rulesets", []).find { |ruleset| ruleset.fetch("id") == id } || abort("ruleset not found")
             when %r{\Acompare/([0-9a-f]{40})\.\.\.([0-9a-f]{40})\z}
               base = Regexp.last_match(1)
               head = Regexp.last_match(2)
               commit = repo.fetch("commits").fetch(head)
               if base == head
                 { "status" => "identical", "merge_base_commit" => { "sha" => base } }
               elsif commit.fetch("ancestors").include?(base)
                 { "status" => "ahead", "merge_base_commit" => { "sha" => base } }
               else
                 { "status" => "diverged", "merge_base_commit" => { "sha" => head } }
               end
             when %r{\Acontents/(.+)\z}
               file_path = URI.decode_www_form_component(Regexp.last_match(1))
               commit = fields.fetch("-f").sub("ref=", "")
               content = repo.fetch("commits").fetch(commit).fetch("files").fetch(file_path)
               {
                 "type" => "file",
                 "path" => file_path,
                 "encoding" => "base64",
                 "content" => Base64.strict_encode64(content)
               }
             else
               abort "unsupported endpoint #{endpoint}"
             end

  puts JSON.generate(response)
RUBY

def write_fixture(root, mutate: nil)
  release, release_bytes, ledger_event, ledger_bytes, ack, ack_bytes, delivery_ack_path = fixture_documents
  fixture = repository_fixture(
    release_bytes: release_bytes,
    ledger_bytes: ledger_bytes,
    ack_bytes: ack_bytes,
    delivery_ack_path: delivery_ack_path
  )
  documents = {
    release: release,
    release_bytes: release_bytes,
    ledger_event: ledger_event,
    ledger_bytes: ledger_bytes,
    ack: ack,
    ack_bytes: ack_bytes,
    delivery_ack_path: delivery_ack_path,
    fixture: fixture
  }
  original_release_bytes = release_bytes
  original_ledger_bytes = ledger_bytes
  original_ack_bytes = ack_bytes
  mutate&.call(documents)

  documents[:release_bytes] = pretty_json(documents[:release]) if documents[:release_bytes] == original_release_bytes
  documents[:ledger_bytes] = pretty_json(documents[:ledger_event]) if documents[:ledger_bytes] == original_ledger_bytes
  documents[:ack_bytes] = pretty_json(documents[:ack]) if documents[:ack_bytes] == original_ack_bytes

  upstream = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY).fetch("commits")
  delivery = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY).fetch("commits")
  if upstream.key?(OUTBOUND_COMMIT) && upstream.fetch(OUTBOUND_COMMIT).fetch("files")[RELEASE_RELATIVE_PATH] == original_release_bytes
    upstream.fetch(OUTBOUND_COMMIT).fetch("files")[RELEASE_RELATIVE_PATH] = documents.fetch(:release_bytes)
  end
  if delivery.key?(LEDGER_COMMIT) && delivery.fetch(LEDGER_COMMIT).fetch("files")["ledger/events/receiver-acknowledged.json"] == original_ledger_bytes
    delivery.fetch(LEDGER_COMMIT).fetch("files")["ledger/events/receiver-acknowledged.json"] = documents.fetch(:ledger_bytes)
  end
  if delivery.fetch(DELIVERY_ACK_COMMIT).fetch("files")[delivery_ack_path] == original_ack_bytes
    delivery.fetch(DELIVERY_ACK_COMMIT).fetch("files")[delivery_ack_path] = documents.fetch(:ack_bytes)
  end
  if upstream.fetch(UPSTREAM_ACK_COMMIT).fetch("files")[UPSTREAM_ACK_RELATIVE_PATH] == original_ack_bytes
    upstream.fetch(UPSTREAM_ACK_COMMIT).fetch("files")[UPSTREAM_ACK_RELATIVE_PATH] = documents.fetch(:ack_bytes)
  end

  release_path = root.join("outbound-owner-release.json")
  ack_path = root.join("receiver-ack.json")
  fixture_path = root.join("remote.json")
  state_path = root.join("remote-state.json")
  release_path.write(documents[:release_bytes])
  ack_path.write(documents[:ack_bytes])
  fixture_path.write(JSON.pretty_generate(documents[:fixture]) + "\n")
  state_path.write("{}\n")

  [documents, release_path, ack_path, fixture_path, state_path]
end

def verifier_arguments(release_path:, ack_path:, delivery_ack_path:, output_path:)
  [
    "--release", release_path.to_s,
    "--ack", ack_path.to_s,
    "--delivery-ack-commit", DELIVERY_ACK_COMMIT,
    "--delivery-ack-path", delivery_ack_path,
    "--upstream-ack-commit", UPSTREAM_ACK_COMMIT,
    "--upstream-ack-path", UPSTREAM_ACK_RELATIVE_PATH,
    "--output", output_path.to_s
  ]
end

def run_verifier(root, mutate: nil)
  documents, release_path, ack_path, fixture_path, state_path = write_fixture(root, mutate: mutate)
  bin = root.join("bin")
  FileUtils.mkdir_p(bin)
  gh = bin.join("gh")
  gh.write(FAKE_GH)
  FileUtils.chmod(0o755, gh)
  output_path = root.join("ownership-proof.json")
  env = {
    "PATH" => "#{bin}:#{ENV.fetch("PATH")}",
    "FAKE_GH_FIXTURE" => fixture_path.to_s,
    "FAKE_GH_STATE" => state_path.to_s
  }
  stdout, stderr, status = Open3.capture3(
    env,
    RbConfig.ruby,
    "-w",
    VERIFIER.to_s,
    *verifier_arguments(
      release_path: release_path,
      ack_path: ack_path,
      delivery_ack_path: documents.fetch(:delivery_ack_path),
      output_path: output_path
    )
  )
  [stdout, stderr, status, output_path]
end

def expect_success(label, mutate: nil)
  Dir.mktmpdir("spoonjoy-handoff-contract") do |directory|
    stdout, stderr, status, output_path = run_verifier(Pathname.new(directory), mutate: mutate)
    fail_check("#{label}: expected success\n#{stdout}\n#{stderr}") unless status.success?
    fail_check("#{label}: emitted warnings\n#{stderr}") unless stderr.empty?
    fail_check("#{label}: did not write proof") unless output_path.file?
    proof = JSON.parse(output_path.read)
    fail_check("#{label}: proof was not verified") unless proof["verified"] == true
  end
end

def expect_failure(label, expected_message, mutate:)
  Dir.mktmpdir("spoonjoy-handoff-contract") do |directory|
    stdout, stderr, status, output_path = run_verifier(Pathname.new(directory), mutate: mutate)
    fail_check("#{label}: unexpectedly succeeded\n#{stdout}") if status.success?
    combined = "#{stdout}\n#{stderr}"
    fail_check("#{label}: missing #{expected_message.inspect}\n#{combined}") unless combined.include?(expected_message)
    fail_check("#{label}: wrote proof after failure") if output_path.exist?
  end
end

begin
  [VERIFIER, RELEASE_SCHEMA, ACK_SCHEMA].each do |path|
    fail_check("missing #{path.relative_path_from(ROOT)}") unless path.file?
  end

  doing = TASK_ROOT.sub_ext(".md").read
  evidence_index = TASK_ROOT.join("evidence-index.md").read
  workflow = ROOT.join(".github/workflows/native.yml").read
  local_matrix = ROOT.join("scripts/validate-native-local.sh").read
  [doing, evidence_index].each do |document|
    fail_check("legacy owner-release.json path remains") if document.match?(/(?<!outbound-)owner-release\.json/)
    fail_check("protected main acknowledgment contract is undocumented") unless document.include?("protected `refs/heads/main`")
    fail_check("effective GitHub protection proof is undocumented") unless document.include?("effective GitHub")
    fail_check("ProtectedMainV1 contract is undocumented") unless document.include?("ProtectedMainV1")
    fail_check("ProtectedLedgerV1 contract is undocumented") unless document.include?("ProtectedLedgerV1")
  end
  [VERIFIER.read].each do |source|
    fail_check("stale unprotected acknowledgment ref remains") if source.include?("refs/heads/records-r0")
    fail_check("stale unprotected outbound ref remains") if source.include?("refs/heads/worker/audit-release-train")
  end
  gate_command = "ruby -w scripts/check-release-ownership-handoff-contract.rb"
  fail_check("protected Native workflow does not run the warning-clean handoff contract") unless workflow.include?(gate_command)
  fail_check("local validation matrix does not run the warning-clean handoff contract") unless local_matrix.include?(gate_command)

  expect_success("valid two-sided acyclic handoff")

  expect_success("delivery main protected by an effective ruleset", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    repo.fetch("protections").delete(DELIVERY_ACK_REF)
    repo.fetch("rulesets") << protected_main_ruleset
  end)

  expect_failure("unprotected outbound main", "has no ProtectedMainV1 protection layer", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    repo.fetch("protections").delete(OUTBOUND_REF)
  end)

  expect_failure("unprotected delivery main", "has no ProtectedMainV1 protection layer", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    repo.fetch("protections").delete(DELIVERY_ACK_REF)
  end)

  expect_failure("unprotected delivery ledger", "has no ProtectedLedgerV1 ruleset", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    repo.fetch("rulesets").reject! { |ruleset| ruleset.fetch("name") == "ProtectedLedgerV1" }
  end)

  expect_failure("wrong dedicated ledger App", "requires exactly the dedicated ledger App bypass", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    actor = repo.fetch("rulesets").find { |ruleset| ruleset.fetch("name") == "ProtectedLedgerV1" }
      .fetch("bypass_actors").first
    actor["actor_id"] = LEDGER_APP_ID + 1
  end)

  expect_failure("extra ledger App bypass", "requires exactly the dedicated ledger App bypass", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    actors = repo.fetch("rulesets").find { |ruleset| ruleset.fetch("name") == "ProtectedLedgerV1" }
      .fetch("bypass_actors")
    actors << { "actor_id" => LEDGER_APP_ID + 1, "actor_type" => "Integration", "bypass_mode" => "always" }
  end)

  %w[RepositoryRole Team OrganizationAdmin].each do |actor_type|
    expect_failure("ledger #{actor_type} bypass", "forbids broad role, team, user, or administrator bypass", mutate: lambda do |documents|
      repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
      actors = repo.fetch("rulesets").find { |ruleset| ruleset.fetch("name") == "ProtectedLedgerV1" }
        .fetch("bypass_actors")
      actors << { "actor_id" => 1, "actor_type" => actor_type, "bypass_mode" => "always" }
    end)
  end

  expect_failure("ordinary ledger direct-write path", "forbids an ordinary writer or direct update path", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    rules = repo.fetch("rulesets").find { |ruleset| ruleset.fetch("name") == "ProtectedLedgerV1" }
      .fetch("rules")
    rules.reject! { |rule| rule.fetch("type") == "update" }
  end)

  expect_failure("coherent ledger App substitution", "source-anchored ledger App ID", mutate: lambda do |documents|
    substituted_app_id = LEDGER_APP_ID + 1
    documents.fetch(:ack).fetch("ledgerEvent")["appID"] = substituted_app_id
    payload = documents.fetch(:ledger_event).fetch("payload")
    payload["ledgerAppID"] = substituted_app_id
    documents.fetch(:ack).fetch("ledgerEvent")["payloadSHA256"] = sha256(canonical_json(payload))
    delivery = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    delivery.fetch("commits").fetch(LEDGER_COMMIT).fetch("files")["ledger/events/receiver-acknowledged.json"] = pretty_json(documents.fetch(:ledger_event))
    actor = delivery.fetch("rulesets").find { |ruleset| ruleset.fetch("name") == "ProtectedLedgerV1" }
      .fetch("bypass_actors").first
    actor["actor_id"] = substituted_app_id
  end)

  expect_failure("mutable protected main", "does not block force pushes and deletion", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    repo.fetch("protections").fetch(DELIVERY_ACK_REF).fetch("allow_force_pushes")["enabled"] = true
  end)

  %w[evaluate disabled].each do |enforcement|
    expect_failure("#{enforcement} matching ruleset", "is not active", mutate: lambda do |documents|
      repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
      repo.fetch("rulesets") << protected_main_ruleset(id: 2, enforcement: enforcement)
    end)
  end

  expect_failure("permissive classic user bypass", "forbids broad role, team, user, or administrator bypass", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    allowances = repo.fetch("protections").fetch(OUTBOUND_REF)
      .fetch("required_pull_request_reviews").fetch("bypass_pull_request_allowances")
    allowances.fetch("users") << { "id" => 7, "login" => "bypass-user" }
  end)

  expect_failure("permissive ruleset team bypass", "forbids broad role, team, user, or administrator bypass", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    repo.fetch("rulesets") << protected_main_ruleset(
      id: 3,
      bypass_actors: [{ "actor_id" => 8, "actor_type" => "Team", "bypass_mode" => "always" }]
    )
  end)

  expect_failure("missing pull request rule", "requires pull requests with at least one approval", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    repo.fetch("protections").fetch(OUTBOUND_REF).delete("required_pull_request_reviews")
  end)

  expect_failure("non-strict required checks", "requires strict required status checks", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    repo.fetch("protections").fetch(OUTBOUND_REF).fetch("required_status_checks")["strict"] = false
  end)

  expect_failure("missing required-check rule", "requires status checks", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    repo.fetch("protections").fetch(OUTBOUND_REF).delete("required_status_checks")
  end)

  expect_failure("empty required-check set", "requires at least one named status check", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    repo.fetch("protections").fetch(OUTBOUND_REF).fetch("required_status_checks")["checks"] = []
  end)

  expect_failure("any-source required check", "forbids any-source or missing-source required checks", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    check = repo.fetch("protections").fetch(OUTBOUND_REF).fetch("required_status_checks").fetch("checks").first
    check["app_id"] = nil
  end)

  expect_failure("missing required-check source", "forbids any-source or missing-source required checks", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    check = repo.fetch("protections").fetch(OUTBOUND_REF).fetch("required_status_checks").fetch("checks").first
    check.delete("app_id")
  end)

  expect_failure("wrong positive required-check App", "repository-specific expected check App allowlist", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    check = repo.fetch("protections").fetch(OUTBOUND_REF).fetch("required_status_checks").fetch("checks").first
    check["app_id"] = 99_999
  end)

  expect_failure("spoof required check context", "repository-specific expected check App allowlist", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    checks = repo.fetch("protections").fetch(OUTBOUND_REF).fetch("required_status_checks").fetch("checks")
    checks << { "context" => "Swift tests spoof", "app_id" => 15_368 }
  end)

  expect_failure("missing expected required check", "repository-specific expected check App allowlist", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    checks = repo.fetch("protections").fetch(OUTBOUND_REF).fetch("required_status_checks").fetch("checks")
    checks.pop
  end)

  expect_failure("mid-verification protection drift", "rule digest changed during verification", mutate: lambda do |documents|
    key = "#{OUTBOUND_REPOSITORY}|#{OUTBOUND_REF}"
    before = classic_protection(OUTBOUND_REPOSITORY)
    after = deep_copy(before)
    after.fetch("required_pull_request_reviews")["required_approving_review_count"] = 2
    documents.fetch(:fixture).fetch("driftProtections")[key] = [before, after]
  end)

  expect_failure("self-referential delivery commit", "unknown property deliveryProjectionCommit", mutate: lambda do |documents|
    documents.fetch(:ack)["deliveryProjectionCommit"] = DELIVERY_ACK_COMMIT
  end)

  expect_failure("self-referential upstream commit", "unknown property upstreamCopyCommit", mutate: lambda do |documents|
    documents.fetch(:ack)["upstreamCopyCommit"] = UPSTREAM_ACK_COMMIT
  end)

  expect_failure("mismatched protected field", "protected outbound field native differs", mutate: lambda do |documents|
    documents.fetch(:ack).fetch("protectedOutbound").fetch("native")["mainRunID"] = "1"
  end)

  expect_failure("wrong receiver task", "$.receiver.taskID must equal", mutate: lambda do |documents|
    documents.fetch(:ack).fetch("receiver")["taskID"] = "00000000-0000-0000-0000-000000000000"
  end)

  expect_failure("invalid outbound release schema", "$.native.testFlight.externalGroupIDs must contain at most 0 items", mutate: lambda do |documents|
    documents.fetch(:release).fetch("native").fetch("testFlight")["externalGroupIDs"] = ["external-group"]
  end)

  expect_failure("case-variant mutable placeholder", "$.provider.proofArtifact must match pattern", mutate: lambda do |documents|
    documents.fetch(:release).fetch("provider")["proofArtifact"] = "Pending"
  end)

  expect_failure("inferred placeholder", "$.web.workerDeploymentID must match pattern", mutate: lambda do |documents|
    documents.fetch(:release).fetch("web")["workerDeploymentID"] = "inferred-from-main"
  end)

  expect_failure("noncanonical outbound release path", "$.outboundRelease.path must equal", mutate: lambda do |documents|
    documents.fetch(:ack).fetch("outboundRelease")["path"] = "owner-release.json"
  end)

  expect_failure("mutable outbound commit", "must match pattern", mutate: lambda do |documents|
    documents.fetch(:ack).fetch("outboundRelease")["commit"] = "latest"
  end)

  expect_failure("wrong ledger event type", "ledger event type must be ReceiverAcknowledged", mutate: lambda do |documents|
    documents.fetch(:ledger_event)["eventType"] = "ReleaseSetPublished"
    documents[:fixture].fetch("repositories").fetch(DELIVERY_REPOSITORY).fetch("commits").fetch(LEDGER_COMMIT).fetch("files")["ledger/events/receiver-acknowledged.json"] = pretty_json(documents.fetch(:ledger_event))
  end)

  expect_failure("wrong ledger payload digest", "ledger payload SHA-256 does not match", mutate: lambda do |documents|
    documents.fetch(:ack).fetch("ledgerEvent")["payloadSHA256"] = "b" * 64
  end)

  expect_failure("ledger payload field ambiguity", "ledger event payload fields do not match", mutate: lambda do |documents|
    payload = documents.fetch(:ledger_event).fetch("payload")
    payload["deliveryProjectionCommit"] = DELIVERY_ACK_COMMIT
    documents.fetch(:ack).fetch("ledgerEvent")["payloadSHA256"] = sha256(canonical_json(payload))
  end)

  expect_failure("ledger payload receiver mismatch", "ledger payload receiver task ID does not match", mutate: lambda do |documents|
    payload = documents.fetch(:ledger_event).fetch("payload")
    payload["receiverTaskID"] = "00000000-0000-0000-0000-000000000000"
    documents.fetch(:ack).fetch("ledgerEvent")["payloadSHA256"] = sha256(canonical_json(payload))
  end)

  expect_failure("unreachable outbound commit", "remote commit is unreachable", mutate: lambda do |documents|
    documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY).fetch("commits").delete(OUTBOUND_COMMIT)
  end)

  expect_failure("unreachable ledger commit", "remote commit is unreachable", mutate: lambda do |documents|
    documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY).fetch("commits").delete(LEDGER_COMMIT)
  end)

  expect_failure("branch-only delivery projection", "is not reachable from protected ref", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    repo.fetch("refs")[DELIVERY_ACK_REF] = DRIFT_COMMIT
    repo.fetch("commits").fetch(DRIFT_COMMIT)["ancestors"] = []
  end)

  expect_failure("mutable protected ref", "changed during verification", mutate: lambda do |documents|
    key = "#{DELIVERY_REPOSITORY}|#{DELIVERY_ACK_REF}"
    documents.fetch(:fixture).fetch("driftRefs")[key] = [DELIVERY_ACK_COMMIT, DRIFT_COMMIT]
  end)

  expect_failure("delivery tree content mismatch", "delivery acknowledgment tree SHA-256 does not match", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(DELIVERY_REPOSITORY)
    path = documents.fetch(:delivery_ack_path)
    repo.fetch("commits").fetch(DELIVERY_ACK_COMMIT).fetch("files")[path] = "{}\n"
  end)

  expect_failure("upstream tree content mismatch", "upstream acknowledgment tree SHA-256 does not match", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    repo.fetch("commits").fetch(UPSTREAM_ACK_COMMIT).fetch("files")[UPSTREAM_ACK_RELATIVE_PATH] = "{}\n"
  end)

  expect_failure("outbound tree content mismatch", "outbound release tree SHA-256 does not match", mutate: lambda do |documents|
    repo = documents.fetch(:fixture).fetch("repositories").fetch(OUTBOUND_REPOSITORY)
    repo.fetch("commits").fetch(OUTBOUND_COMMIT).fetch("files")[RELEASE_RELATIVE_PATH] = "{}\n"
  end)

  expect_failure("duplicate acknowledgment key", "duplicate JSON key schemaVersion", mutate: lambda do |documents|
    documents[:ack_bytes] = documents.fetch(:ack_bytes).sub("{\n", "{\n  \"schemaVersion\": 1,\n")
  end)

  puts "release ownership handoff contract ok"
rescue ContractCheckFailure => error
  warn "FAIL: #{error.message}"
  exit 1
end
