# frozen_string_literal: true

# Run: ruby scripts/test/review_demo_kitchen_test.rb
require "minitest/autorun"
require "stringio"
require_relative "../lib/review_demo_kitchen"

class ReviewDemoKitchenTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def kitchen
    JSON.parse(File.read(File.join(ROOT, "distribution/app-store/review-demo-kitchen.json")))
  end

  def test_checked_in_kitchen_is_valid
    assert_equal [], ReviewDemoKitchen.validate(kitchen)
  end

  def test_rejects_duplicate_ingredients_bad_durations_and_dangling_references
    bad = kitchen
    galette = bad["chefs"]["demo"]["recipes"].first
    galette["steps"][1]["ingredients"] << { "quantity" => 1, "unit" => "tbsp", "name" => "Plain Flour" }
    galette["steps"][0]["duration"] = 2.5
    bad["chefs"]["demo"]["cookbooks"][0]["recipes"] << "missing"
    bad["cooks"] << { "by" => "demo", "recipe" => "friend.nope", "note" => "x" }
    errors = ReviewDemoKitchen.validate(bad)
    assert(errors.any? { |e| e.include?("ingredient plain flour appears 2 times") }, errors.inspect)
    assert(errors.any? { |e| e.include?("duration must be a positive whole number") })
    assert(errors.any? { |e| e.include?("missing is not one of demo's recipes") })
    assert(errors.any? { |e| e.include?("friend.nope: no such recipe") })
  end

  # A fake spoonjoy.app that keeps state, so the seeder can run twice against it.
  class FakeApi
    attr_reader :writes, :base, :covers

    def initialize
      @base = URI("https://spoonjoy.test")
      @users = {}
      @recipes = []
      @cookbooks = []
      @spoons = []
      @shopping = Hash.new { |hash, key| hash[key] = [] }
      @covers = Hash.new { |hash, key| hash[key] = { "covers" => [], "activeCover" => nil } }
      @writes = []
    end

    def form(path, fields)
      @writes << "signup"
      return 400 if @users.key?(fields["username"])

      @users[fields["username"]] = fields["password"]
      302
    end

    def json(method, path, token: nil, body: nil, ok: [200, 201])
      @writes << "#{method} #{path.sub(/\?.*/, '')}" unless method == :get || path.include?("/auth/")
      uri = URI(path)
      query = URI.decode_www_form(uri.query.to_s).to_h
      case [method, uri.path]
      in [:post, "/api/v1/auth/password/native"]
        user = body["emailOrUsername"]
        @users[user] == body["password"] ? [201, { "data" => { "access_token" => "token-#{user}" } }] : [401, {}]
      in [:get, %r{\A/api/v1/users/(.+)\z}]
        [@users.key?(Regexp.last_match(1)) ? 200 : 404, {}]
      in [:get, "/api/v1/recipes"]
        [200, { "data" => { "recipes" => @recipes.select { |r| r["title"].include?(query["q"]) } } }]
      in [:post, "/api/v1/recipes"]
        recipe = { "id" => "r#{@recipes.length}", "title" => body["title"], "chef" => { "username" => user(token) }, "attribution" => { "sourceRecipe" => nil } }
        @recipes << recipe
        [201, { "data" => { "recipe" => recipe } }]
      in [:post, %r{\A/api/v1/recipes/(r\d+)/fork\z}]
        recipe = { "id" => "r#{@recipes.length}", "title" => body["title"], "chef" => { "username" => user(token) },
                   "attribution" => { "sourceRecipe" => { "id" => Regexp.last_match(1) } } }
        @recipes << recipe
        [201, { "data" => { "recipe" => recipe } }]
      in [:get, "/api/v1/cookbooks"]
        [200, { "data" => { "cookbooks" => @cookbooks } }]
      in [:post, "/api/v1/cookbooks"]
        cookbook = { "id" => "c#{@cookbooks.length}", "title" => body["title"], "chef" => { "username" => user(token) }, "recipes" => [] }
        @cookbooks << cookbook
        [201, { "data" => { "cookbook" => cookbook } }]
      in [:get, %r{\A/api/v1/cookbooks/(c\d+)\z}]
        cookbook = @cookbooks.find { |c| c["id"] == Regexp.last_match(1) }
        [200, { "data" => { "cookbook" => { "recipes" => cookbook["recipes"].map { |id| { "id" => id } } } } }]
      in [:post, %r{\A/api/v1/cookbooks/(c\d+)/recipes/(r\d+)\z}]
        @cookbooks.find { |c| c["id"] == Regexp.last_match(1) }["recipes"] << Regexp.last_match(2)
        [201, {}]
      in [:get, "/api/v1/shopping-list"]
        [200, { "data" => { "shoppingList" => { "items" => @shopping[user(token)] } } }]
      in [:post, "/api/v1/shopping-list/items"]
        @shopping[user(token)] << { "id" => "i#{@shopping[user(token)].length}", "name" => body["name"], "checked" => false }
        [201, {}]
      in [:patch, %r{\A/api/v1/shopping-list/items/(i\d+)\z}]
        @shopping[user(token)].find { |i| i["id"] == Regexp.last_match(1) }["checked"] = body["checked"]
        [200, {}]
      in [:get, %r{\A/api/v1/recipes/(r\d+)/spoons\z}]
        [200, { "data" => { "spoons" => @spoons.select { |s| s["recipeId"] == Regexp.last_match(1) } } }]
      in [:get, %r{\A/api/v1/recipes/(r\d+)/covers\z}]
        state = @covers[Regexp.last_match(1)]
        state["polls"] = state["polls"].to_i + 1
        state["onPoll"]&.call(state)
        [200, { "data" => state.slice("covers", "activeCover") }]
      in [:post, %r{\A/api/v1/recipes/(r\d+)/covers/generate\z}]
        state = @covers[Regexp.last_match(1)]
        cover = { "id" => "cv#{state['covers'].length}", "generationStatus" => "ready", "displayUrl" => "https://spoonjoy.test/cover.jpg",
                  "prompt" => body["promptAddition"] }
        state["covers"] << cover
        state["activeCover"] = cover if body["activateWhenReady"]
        [201, {}]
      in [:patch, %r{\A/api/v1/recipes/(r\d+)/covers/(cv\d+)\z}]
        state = @covers[Regexp.last_match(1)]
        state["activeCover"] = state["covers"].find { |c| c["id"] == Regexp.last_match(2) }
        [200, {}]
      in [:post, %r{\A/api/v1/recipes/(r\d+)/spoons\z}]
        @spoons << { "recipeId" => Regexp.last_match(1), "note" => body["note"], "chef" => { "username" => user(token) } }
        [201, {}]
      end
    end

    def user(token)
      token.delete_prefix("token-")
    end
  end

  def env
    { "SPOONJOY_REVIEW_DEMO_USERNAME" => "johnnyappleseed", "SPOONJOY_REVIEW_DEMO_PASSWORD" => "demo-pass-123",
      "SPOONJOY_REVIEW_FRIEND_USERNAME" => "timstestkitchen", "SPOONJOY_REVIEW_FRIEND_PASSWORD" => "friend-pass-456" }
  end

  def test_seeds_once_then_changes_nothing_and_never_prints_passwords
    api = FakeApi.new
    out = StringIO.new
    first = ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: out).run
    assert_operator first, :>, 20
    assert_includes api.writes, "post /api/v1/recipes/r0/fork", "the demo chef forks the friend's crumble"
    writes_after_first = api.writes.length
    second = ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: out).run
    assert_equal 0, second
    assert_equal writes_after_first, api.writes.length
    refute_includes out.string, "demo-pass-123"
    refute_includes out.string, "friend-pass-456"
    assert_includes out.string, "https://spoonjoy.test/users/johnnyappleseed"
  end

  def test_every_recipe_and_fork_gets_one_ai_cover_with_its_prompt
    api = FakeApi.new
    ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: StringIO.new).run
    generated = api.writes.grep(%r{/covers/generate\z})
    assert_equal 9, generated.length, "7 demo recipes, the friend's crumble and the fork"
    assert(api.covers.values.all? { |state| state["activeCover"] })
    assert(api.covers.values.all? { |state| state["covers"].first["prompt"].to_s.length.positive? })
  end

  def test_waits_for_an_in_flight_cover_and_switches_on_a_finished_inactive_one
    api = FakeApi.new
    out = StringIO.new
    ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: out).run
    # r0 is mid-generation and finishes on a later poll; r1 has a finished cover nobody switched on.
    processing = { "id" => "cv9", "generationStatus" => "processing" }
    api.covers["r0"] = { "covers" => [processing], "activeCover" => nil,
                         "onPoll" => ->(state) { state["activeCover"] = processing if state["polls"] > 2 } }
    api.covers["r1"] = { "covers" => [{ "id" => "cv0", "generationStatus" => "ready", "displayUrl" => "u", "stylizedImageUrl" => "s" }], "activeCover" => nil }
    naps = []
    before = api.writes.length
    changes = ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: out, sleeper: ->(s) { naps << s }).run
    assert_equal 1, changes
    assert_equal ["patch /api/v1/recipes/r1/covers/cv0"], api.writes.drop(before)
    assert_equal [10], naps
    assert_includes out.string, "Cover ready for Brown Butter Apple Crumble"
  end

  def test_a_cover_that_fails_to_generate_fails_the_run
    api = FakeApi.new
    ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: StringIO.new).run
    failed = { "id" => "cv9", "generationStatus" => "processing" }
    api.covers["r0"] = { "covers" => [failed], "activeCover" => nil,
                         "onPoll" => ->(state) { failed["generationStatus"] = "failed" if state["polls"] > 1 } }
    error = assert_raises(ReviewDemoKitchen::Error) do
      ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: StringIO.new, sleeper: ->(_) {}).run
    end
    assert_match(/Cover generation for Brown Butter Apple Crumble/, error.message)
  end

  class StubbedHttp < ReviewDemoKitchen::Http
    def initialize(responses)
      super("https://spoonjoy.test")
      @responses = responses
    end

    private

    def perform(_request)
      status, body = @responses.shift
      Struct.new(:code, :body).new(status.to_s, JSON.generate(body))
    end

    def backoff(*); end
  end

  def test_http_accepts_any_status_retries_rate_limits_and_raises_otherwise
    assert_equal 404, StubbedHttp.new([[404, {}]]).json(:get, "/api/v1/users/x", ok: :any).first
    status, body = StubbedHttp.new([[429, {}], [201, { "data" => { "id" => 1 } }]]).json(:post, "/api/v1/recipes", body: {})
    assert_equal [201, 1], [status, body.dig("data", "id")]
    error = assert_raises(ReviewDemoKitchen::Error) do
      StubbedHttp.new([[422, { "error" => { "code" => "validation_error", "message" => "Bad" } }]]).json(:post, "/x", body: {})
    end
    assert_includes error.message, "422: validation_error Bad"
  end

  def test_existing_account_with_another_password_fails_clearly
    api = FakeApi.new
    api.form("/signup", { "username" => "timstestkitchen", "password" => "something-else" })
    error = assert_raises(ReviewDemoKitchen::Error) do
      ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: StringIO.new).run
    end
    assert_includes error.message, "timstestkitchen exists but its password does not match"
    refute_includes error.message, "friend-pass-456"
  end
end
