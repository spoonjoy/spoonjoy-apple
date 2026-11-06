# frozen_string_literal: true

# Run: ruby scripts/test/ouro_ui_pin_test.rb
require "minitest/autorun"
require_relative "../lib/ouro_ui_pin"

class OuroUIPinTest < Minitest::Test
  def package(requirement)
    %(dependencies: [\n    .package(url: "https://github.com/ourostack/ouro-ui-apple.git", #{requirement})\n])
  end

  def test_a_release_is_an_exact_version
    assert_equal({ "kind" => "exactVersion", "version" => "0.2.1" }, OuroUIPin.requirement(package(%(exact: "0.2.1"))))
  end

  def test_a_release_candidate_is_an_exact_version
    assert_equal({ "kind" => "exactVersion", "version" => "0.3.0-rc.2" }, OuroUIPin.requirement(package(%(exact: "0.3.0-rc.2"))))
  end

  def test_a_full_commit_is_a_revision
    sha = "3f448500423e9f05acf31c9f52902776b56b7c6e"
    assert_equal({ "kind" => "revision", "revision" => sha }, OuroUIPin.requirement(package(%(revision: "#{sha}"))))
  end

  def test_anything_that_can_move_is_refused
    assert_nil OuroUIPin.requirement(package(%(branch: "main")))
    assert_nil OuroUIPin.requirement(package(%(from: "0.2.1")))
    assert_nil OuroUIPin.requirement(package(%(revision: "3f44850")))
    assert_nil OuroUIPin.requirement(package(%(exact: "0.3")))
    assert_nil OuroUIPin.requirement(package(%("0.2.1"..."0.3.0")))
  end

  def test_the_repository_pin_is_exact
    assert OuroUIPin.requirement(File.read(File.expand_path("../../Package.swift", __dir__)))
  end
end
