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
    bad["chefs"]["demo"]["recipes"][1]["coverPhoto"] = "missing.jpg"
    bad["chefs"]["demo"]["forks"][0]["coverPhoto"] = "../secrets.jpg"
    errors = ReviewDemoKitchen.validate(bad)
    assert(errors.any? { |e| e.include?("ingredient plain flour appears 2 times") }, errors.inspect)
    assert(errors.any? { |e| e.include?("duration must be a positive whole number") })
    assert(errors.any? { |e| e.include?("missing is not one of demo's recipes") })
    assert(errors.any? { |e| e.include?("friend.nope: no such recipe") })
    assert(errors.any? { |e| e.include?("demo.tatin: coverPhoto missing.jpg is not in") })
    assert(errors.any? { |e| e.include?("demo.crumbleFork: coverPhoto ../secrets.jpg is not in") })
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
      @cooking = {}
    end

    attr_reader :cooking

    # Starts a cook of recipe_id with one ingredient checked, as cook mode would leave it.
    def start_cook(recipe_id)
      @cooking[recipe_id] = { "attemptId" => "a-#{recipe_id}", "revision" => 0, "checked" => ["ing-#{recipe_id}", "out-#{recipe_id}"] }
    end

    def form(path, fields)
      @writes << "signup"
      return 400 if @users.key?(fields["username"])

      @users[fields["username"]] = fields["password"]
      302
    end

    def upload(path, token:, fields:, file:)
      @writes << "upload #{path}"
      recipe_id = path[%r{/recipes/(r\d+)/image\z}, 1]
      state = @covers[recipe_id]
      cover = { "id" => "cv#{state['covers'].length}", "generationStatus" => fields["generateEditorial"] ? "processing" : "none",
                "displayUrl" => "https://spoonjoy.test/#{File.basename(file)}", "file" => file }
      state["covers"] << cover
      state["activeCover"] = cover if fields["activateWhenReady"]
      [201, {}]
    end

    def json(method, path, token: nil, body: nil, ok: [200, 201])
      @writes << "#{method} #{path.sub(/\?.*/, '')}" unless method == :get || path.include?("/auth/")
      uri = URI(path)
      query = URI.decode_www_form(uri.query.to_s).to_h
      case [method, uri.path]
      in [:post, "/api/v1/auth/password/native"]
        user = body["emailOrUsername"]
        data = { "access_token" => "token-#{user}", "refresh_token" => "refresh-#{user}", "token_type" => "Bearer", "expires_in" => 900,
                 "scope" => "kitchen:read kitchen:write", "client_id" => "spoonjoy-apple-native:abc", "userId" => "u-#{user}" }
        @users[user] == body["password"] ? [201, { "data" => data }] : [401, {}]
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
      in [:get, "/api/v1/cooking-now"]
        [200, { "data" => { "recipes" => @cooking.keys.map { |id| { "recipe" => @recipes.find { |r| r["id"] == id }.slice("id", "title") } } } }]
      in [:get, %r{\A/api/v1/recipes/(r\d+)\z}]
        id = Regexp.last_match(1)
        [200, { "data" => { "recipe" => { "id" => id, "steps" => [{ "ingredients" => [] }, { "ingredients" => [{ "id" => "ing-#{id}" }] }] } } }]
      in [:get, %r{\A/api/cook-sessions/(r\d+)\z}]
        session = @cooking[Regexp.last_match(1)]
        [200, { "state" => session && { "attemptId" => session["attemptId"], "revision" => session["revision"] } }]
      in [:patch, %r{\A/api/cook-sessions/(r\d+)\z}]
        id = Regexp.last_match(1)
        session = @cooking.fetch(id)
        return [409, {}] unless body["attemptId"] == session["attemptId"] && body["expectedRevision"] == session["revision"]

        before = session["checked"]
        changes = body["changes"]
        session["checked"] = changes.fetch("checkedIngredientIds", session["checked"].grep(/\Aing-/)) +
                             changes.fetch("checkedStepOutputIds", session["checked"].grep(/\Aout-/))
        session["revision"] += 1
        state = { "attemptId" => session["attemptId"], "revision" => session["revision"] }
        @cooking.delete(id) if before.any? && session["checked"].empty?
        [200, { "state" => state }]
      in [:get, %r{\A/api/v1/recipes/(r\d+)/spoons\z}]
        [200, { "data" => { "spoons" => @spoons.select { |s| s["recipeId"] == Regexp.last_match(1) } } }]
      in [:get, %r{\A/api/v1/recipes/(r\d+)/covers\z}]
        [200, { "data" => @covers[Regexp.last_match(1)].slice("covers", "activeCover") }]
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

  def test_every_recipe_and_fork_gets_its_own_photo_as_is_and_switched_on
    api = FakeApi.new
    ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: StringIO.new).run
    assert_equal 9, api.writes.grep(%r{\Aupload /api/v1/recipes/r\d+/image\z}).length, "7 demo recipes, the friend's crumble and the fork"
    active = api.covers.values.map { |state| state["activeCover"] }
    assert(active.all? { |cover| cover && cover["generationStatus"] == "none" }, "uploaded without an AI restyle")
    files = active.map { |cover| cover["file"] }
    assert_equal files.uniq, files, "no two recipes share a photo"
    assert(files.all? { |file| File.file?(file) })
  end

  def test_a_recipe_without_an_active_cover_gets_its_photo_again
    api = FakeApi.new
    ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: StringIO.new).run
    api.covers["r1"]["activeCover"] = nil
    before = api.writes.length
    changes = ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: StringIO.new).run
    assert_equal 1, changes
    assert_equal ["upload /api/v1/recipes/r1/image"], api.writes.drop(before)
  end

  def test_store_scenes_signs_a_debug_app_in_as_the_demo_chef_and_links_its_screens
    api = FakeApi.new
    seeder = ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: StringIO.new)
    seeder.run
    scenes = seeder.store_scenes(now: Time.at(978_307_200))
    session = scenes.dig("session", "session")
    assert_equal "spoonjoy-apple-native:abc", scenes.dig("session", "clientID")
    assert_equal({ "clientID" => "spoonjoy-apple-native:abc", "accessToken" => "token-johnnyappleseed", "refreshToken" => "refresh-johnnyappleseed",
                   "tokenType" => "Bearer", "scope" => "kitchen:read kitchen:write", "accountID" => "u-johnnyappleseed",
                   "expiresAt" => 900.0, "serverOrigin" => "https://spoonjoy.test" }, session)
    # The friend's crumble is r0, so the demo chef's galette is r1.
    assert_equal "spoonjoy://recipes/r1/cook", scenes.dig("links", "cook")
    assert_match %r{\Aspoonjoy://cookbooks/c\d+\z}, scenes.dig("links", "cookbook")
  end

  def test_a_recipe_left_under_cooking_now_is_cleared
    api = FakeApi.new
    seeder = -> { ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: api, env: env, out: StringIO.new).run }
    seeder.call
    api.start_cook("r1")
    seeder.call
    assert_empty api.cooking
    assert_equal 2, api.writes.count("patch /api/cook-sessions/r1")
    assert_equal 0, seeder.call
  end

  def test_http_upload_sends_the_fields_and_the_jpeg_as_multipart
    sent = nil
    http = StubbedHttp.new([])
    http.define_singleton_method(:perform) do |request|
      sent = request
      Struct.new(:code, :body).new("201", "{}")
    end
    photo = File.join(ReviewDemoKitchen::COVERS_DIR, "tatin.jpg")
    http.upload("/api/v1/recipes/r1/image", token: "t", fields: { "generateEditorial" => false }, file: photo)
    assert_equal "Bearer t", sent["Authorization"]
    wire = StringIO.new
    sent.exec(Net::BufferedIO.new(wire), "1.1", sent.path)
    body = wire.string.b
    assert_match(/name="generateEditorial"\r\n\r\nfalse\r\n/, body)
    assert_match(/name="photo"; filename="tatin.jpg"\r\nContent-Type: image\/jpeg/, body)
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
