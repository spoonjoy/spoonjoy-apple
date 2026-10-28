# frozen_string_literal: true

# Run: ruby scripts/test/app_store_submission_diagnostics_test.rb
require "minitest/autorun"
require "stringio"
require_relative "../lib/app_store_submission_diagnostics"

class AppStoreSubmissionDiagnosticsTest < Minitest::Test
  class FakeClient
    RESPONSES = {
      "/v1/apps/1/appStoreVersions" => { "data" => [{ "id" => "v1", "attributes" => { "appStoreState" => "PREPARE_FOR_SUBMISSION", "versionString" => "1.0", "copyright" => "x" } }] },
      "/v1/appStoreVersions/v1/build" => { "data" => { "id" => "b1", "attributes" => { "version" => "104", "processingState" => "VALID", "iconAssetToken" => {} } } },
      "/v1/apps/1/appInfos" => { "data" => [{ "id" => "i1", "attributes" => { "state" => "WAITING_FOR_REVIEW" } }] },
      "/v1/reviewSubmissions" => { "data" => [{ "id" => "s1", "attributes" => { "platform" => "IOS", "state" => "UNRESOLVED_ISSUES", "submittedDate" => "d" } }] },
      "/v1/reviewSubmissions/s1/items" => { "data" => [{ "id" => "it1", "attributes" => { "state" => "REJECTED" },
                                                          "relationships" => { "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => "v1" } },
                                                                               "appEvent" => { "data" => nil } } }] }
    }.freeze

    def get(path, _query = {})
      RESPONSES.fetch(path)
    end
  end

  def test_prints_version_build_app_info_and_submission_items
    log = StringIO.new
    AppStoreSubmissionDiagnostics::Reader.new(FakeClient.new, app_id: "1", platform: "IOS", version_string: "1.0", log: log).run
    out = log.string
    assert_includes out, 'Version v1: {"appStoreState":"PREPARE_FOR_SUBMISSION","versionString":"1.0"}'
    assert_includes out, 'Build b1: {"version":"104","processingState":"VALID"}'
    assert_includes out, 'App info i1: {"state":"WAITING_FOR_REVIEW"}'
    assert_includes out, "Submission s1: IOS UNRESOLVED_ISSUES submitted d"
    assert_includes out, '  item it1: {"state":"REJECTED"} appStoreVersion=v1'
    refute_includes out, "copyright"
  end

  def test_reports_a_version_with_no_build
    client = FakeClient.new
    def client.get(path, query = {})
      return { "data" => nil } if path == "/v1/appStoreVersions/v1/build"
      return { "data" => [] } if path == "/v1/reviewSubmissions"

      super
    end
    log = StringIO.new
    AppStoreSubmissionDiagnostics::Reader.new(client, app_id: "1", platform: "IOS", version_string: "1.0", log: log).run
    assert_includes log.string, "Build: none attached"
  end
end
