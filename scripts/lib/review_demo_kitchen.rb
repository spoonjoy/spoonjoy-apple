# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"

# Seeds the App Review demo kitchen on spoonjoy.app from distribution/app-store/review-demo-kitchen.json.
# Every write is preceded by a read, so a run against a complete kitchen changes nothing, and a run after
# the account was deleted recreates it. Passwords come from the environment and are never printed.
module ReviewDemoKitchen
  USERNAME = /\A[A-Za-z0-9._-]{3,50}\z/

  module_function

  # Problems that would make the API reject the kitchen, found without the network.
  def validate(kitchen)
    errors = []
    chefs = kitchen.fetch("chefs")
    recipe_keys = {}
    chefs.each do |chef_key, chef|
      errors << "#{chef_key}: email is missing" unless chef["email"].to_s.include?("@")
      %w[usernameEnv passwordEnv].each { |field| errors << "#{chef_key}: #{field} is missing" if chef[field].to_s.empty? }
      titles = []
      Array(chef["recipes"]).each do |recipe|
        label = "#{chef_key}.#{recipe['key']}"
        recipe_keys[label] = true
        titles << recipe["title"]
        errors << "#{label}: title must be 1-200 characters" unless (1..200).cover?(recipe["title"].to_s.strip.length)
        errors << "#{label}: description is over 2,000 characters" if recipe["description"].to_s.length > 2000
        errors << "#{label}: needs at least one step" if Array(recipe["steps"]).empty?
        names = []
        Array(recipe["steps"]).each_with_index do |step, index|
          where = "#{label} step #{index + 1}"
          errors << "#{where}: description is required" if step["description"].to_s.strip.empty?
          duration = step["duration"]
          errors << "#{where}: duration must be a positive whole number of minutes" unless duration.nil? || (duration.is_a?(Integer) && duration.positive?)
          Array(step["ingredients"]).each do |ingredient|
            names << ingredient["name"].to_s.strip.downcase
            errors << "#{where}: #{ingredient['name']} needs a unit" if ingredient["unit"].to_s.strip.empty?
            quantity = ingredient["quantity"]
            errors << "#{where}: #{ingredient['name']} quantity must be 0.001-99999" unless quantity.is_a?(Numeric) && quantity >= 0.001 && quantity <= 99_999
          end
        end
        names.tally.each { |name, count| errors << "#{label}: ingredient #{name} appears #{count} times" if count > 1 }
      end
      Array(chef["forks"]).each do |fork|
        recipe_keys["#{chef_key}.#{fork['key']}"] = true
        titles << fork["title"]
      end
      titles.tally.each { |title, count| errors << "#{chef_key}: title #{title} is used #{count} times" if count > 1 }
    end
    chefs.each do |chef_key, chef|
      Array(chef["forks"]).each do |fork|
        errors << "#{chef_key}.#{fork['key']}: fork source #{fork['from']} is not a recipe" unless recipe_keys[fork["from"]]
      end
      Array(chef["cookbooks"]).each do |cookbook|
        cookbook["recipes"].each do |key|
          errors << "cookbook #{cookbook['title']}: #{key} is not one of #{chef_key}'s recipes" unless recipe_keys["#{chef_key}.#{key}"]
        end
      end
    end
    Array(kitchen["cooks"]).each do |cook|
      errors << "cook by #{cook['by']}: no such chef" unless chefs.key?(cook["by"])
      errors << "cook on #{cook['recipe']}: no such recipe" unless recipe_keys[cook["recipe"]]
    end
    errors
  end

  class Error < StandardError; end

  class Http
    attr_reader :base

    def initialize(base)
      @base = URI(base)
    end

    def json(method, path, token: nil, body: nil, ok: [200, 201])
      attempts = 0
      loop do
        attempts += 1
        request = Net::HTTP.const_get(method.capitalize).new(URI.join(@base, path))
        request["Accept"] = "application/json"
        request["Authorization"] = "Bearer #{token}" if token
        if body
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(body)
        end
        response = perform(request)
        parsed = response.body.to_s.empty? ? {} : (JSON.parse(response.body) rescue { "raw" => response.body[0, 200] })
        status = response.code.to_i
        if retryable?(status) && attempts < 6
          backoff(parsed, attempts)
          next
        end
        return [status, parsed] if ok == :any || ok.include?(status)
        raise Error, "#{method.upcase} #{path} returned #{status}: #{error_text(parsed)}"
      end
    end

    def form(path, fields)
      attempts = 0
      loop do
        attempts += 1
        request = Net::HTTP::Post.new(URI.join(@base, path))
        request.set_form_data(fields)
        response = perform(request)
        status = response.code.to_i
        if retryable?(status) && attempts < 6
          backoff({}, attempts)
          next
        end
        return status
      end
    end

    private

    def perform(request)
      Net::HTTP.start(@base.host, @base.port, use_ssl: @base.scheme == "https", read_timeout: 60) { |http| http.request(request) }
    end

    def retryable?(status)
      [429, 502, 503, 504].include?(status)
    end

    def backoff(parsed, attempts)
      hinted = parsed.dig("error", "details", "retryAfterSeconds").to_i
      sleep([hinted, 2**attempts].max.clamp(1, 60))
    end

    def error_text(parsed)
      error = parsed["error"]
      return parsed.to_s[0, 300] unless error.is_a?(Hash)

      [error["code"], error["message"], error["details"]&.to_json].compact.join(" ")
    end
  end

  class Seeder
    attr_reader :log

    def initialize(kitchen:, http:, env:, out: $stdout)
      @kitchen = kitchen
      @http = http
      @env = env
      @out = out
      @tokens = {}
      @usernames = {}
      @recipe_ids = {}
      @changes = 0
    end

    def run
      # The friend chef goes first: the demo chef forks the friend's recipe.
      order = @kitchen["chefs"].keys.sort_by { |key| Array(@kitchen["chefs"][key]["forks"]).empty? ? 0 : 1 }
      order.each do |chef_key|
        chef = @kitchen["chefs"][chef_key]
        sign_in_or_create(chef_key, chef)
        Array(chef["recipes"]).each { |recipe| ensure_recipe(chef_key, recipe) }
      end
      order.each do |chef_key|
        chef = @kitchen["chefs"][chef_key]
        Array(chef["forks"]).each { |fork| ensure_fork(chef_key, fork) }
        Array(chef["cookbooks"]).each { |cookbook| ensure_cookbook(chef_key, cookbook) }
        ensure_shopping_list(chef_key, chef["shoppingList"]) if chef["shoppingList"]
      end
      Array(@kitchen["cooks"]).each { |cook| ensure_cook(cook) }
      say "#{@changes} change(s). Kitchens: #{@usernames.values.map { |name| "#{@http.base}/users/#{name}" }.join(', ')}"
      @changes
    end

    private

    def say(line)
      @out.puts(line)
    end

    def mutation_id
      "review-demo-#{SecureRandom.uuid}"
    end

    def secret(name)
      value = @env[name].to_s
      raise Error, "#{name} is not set" if value.empty?

      value
    end

    def sign_in_or_create(chef_key, chef)
      username = secret(chef["usernameEnv"])
      password = secret(chef["passwordEnv"])
      raise Error, "#{chef['usernameEnv']} is not a valid Spoonjoy username" unless username.match?(USERNAME)

      @usernames[chef_key] = username
      token = sign_in(username, password)
      unless token
        status, = @http.json(:get, "/api/v1/users/#{URI.encode_www_form_component(username)}", ok: :any)
        if status == 200
          raise Error, "#{username} exists but its password does not match #{chef['passwordEnv']}. Reset the password on spoonjoy.app or delete the account, then run again."
        end

        signup_status = @http.form("/signup?redirectTo=%2Frecipes", {
          "email" => chef["email"], "username" => username, "password" => password, "confirmPassword" => password
        })
        raise Error, "Creating #{username} failed with status #{signup_status} (is #{chef['email']} already used by another account?)" unless [302, 303].include?(signup_status)

        @changes += 1
        say "Created account #{username}"
        token = sign_in(username, password)
        raise Error, "#{username} was created but sign-in failed" unless token
      end
      @tokens[chef_key] = token
      say "Signed in as #{username}"
    end

    def sign_in(username, password)
      status, body = @http.json(:post, "/api/v1/auth/password/native",
                                body: { "emailOrUsername" => username, "password" => password }, ok: [201, 401])
      status == 201 ? body.dig("data", "access_token") : nil
    end

    def find_recipes(chef_key, title)
      _, body = @http.json(:get, "/api/v1/recipes?limit=50&q=#{URI.encode_www_form_component(title)}", token: @tokens[chef_key])
      Array(body.dig("data", "recipes")).select do |recipe|
        recipe["title"] == title && recipe.dig("chef", "username") == @usernames[chef_key]
      end
    end

    def ensure_recipe(chef_key, recipe)
      existing = find_recipes(chef_key, recipe["title"]).first
      if existing
        @recipe_ids["#{chef_key}.#{recipe['key']}"] = existing["id"]
        return
      end

      body = recipe.slice("title", "description", "servings").merge(
        "clientMutationId" => mutation_id,
        "steps" => recipe["steps"].map { |step| step.slice("stepTitle", "description", "duration", "ingredients") }
      )
      _, created = @http.json(:post, "/api/v1/recipes", token: @tokens[chef_key], body: body)
      @recipe_ids["#{chef_key}.#{recipe['key']}"] = created.dig("data", "recipe", "id")
      @changes += 1
      say "Created recipe #{recipe['title']} for #{@usernames[chef_key]}"
    end

    def ensure_fork(chef_key, fork)
      source_id = @recipe_ids.fetch(fork["from"])
      existing = find_recipes(chef_key, fork["title"]).find { |recipe| recipe.dig("attribution", "sourceRecipe", "id") == source_id }
      if existing
        @recipe_ids["#{chef_key}.#{fork['key']}"] = existing["id"]
        return
      end

      _, forked = @http.json(:post, "/api/v1/recipes/#{source_id}/fork", token: @tokens[chef_key],
                                                                        body: { "clientMutationId" => mutation_id, "title" => fork["title"] })
      @recipe_ids["#{chef_key}.#{fork['key']}"] = forked.dig("data", "recipe", "id")
      @changes += 1
      say "#{@usernames[chef_key]} forked #{fork['from']} as #{fork['title']}"
    end

    def ensure_cookbook(chef_key, cookbook)
      token = @tokens[chef_key]
      _, list = @http.json(:get, "/api/v1/cookbooks?limit=50&q=#{URI.encode_www_form_component(cookbook['title'])}", token: token)
      found = Array(list.dig("data", "cookbooks")).find do |entry|
        entry["title"] == cookbook["title"] && entry.dig("chef", "username") == @usernames[chef_key]
      end
      if found
        id = found["id"]
        _, detail = @http.json(:get, "/api/v1/cookbooks/#{id}", token: token)
        present = Array(detail.dig("data", "cookbook", "recipes")).map { |recipe| recipe["id"] }
      else
        _, created = @http.json(:post, "/api/v1/cookbooks", token: token, body: { "clientMutationId" => mutation_id, "title" => cookbook["title"] })
        id = created.dig("data", "cookbook", "id")
        present = []
        @changes += 1
        say "Created cookbook #{cookbook['title']}"
      end
      cookbook["recipes"].each do |key|
        recipe_id = @recipe_ids.fetch("#{chef_key}.#{key}")
        next if present.include?(recipe_id)

        @http.json(:post, "/api/v1/cookbooks/#{id}/recipes/#{recipe_id}", token: token, body: { "clientMutationId" => mutation_id })
        @changes += 1
        say "Added #{key} to #{cookbook['title']}"
      end
    end

    def shopping_items(token)
      _, body = @http.json(:get, "/api/v1/shopping-list", token: token)
      Array(body.dig("data", "shoppingList", "items"))
    end

    def item_name(item)
      (item["name"] || item.dig("ingredient", "name")).to_s.downcase
    end

    def ensure_shopping_list(chef_key, wanted)
      token = @tokens[chef_key]
      items = shopping_items(token)
      wanted.each do |entry|
        next if items.any? { |item| item_name(item) == entry["name"].downcase }

        @http.json(:post, "/api/v1/shopping-list/items", token: token, body: {
          "clientMutationId" => mutation_id, "name" => entry["name"], "quantity" => entry["quantity"], "unit" => entry["unit"]
        })
        @changes += 1
        say "Added #{entry['name']} to the shopping list"
      end
      items = shopping_items(token)
      wanted.each do |entry|
        item = items.find { |candidate| item_name(candidate) == entry["name"].downcase }
        next if item.nil? || item["checked"] == entry["checked"]

        @http.json(:patch, "/api/v1/shopping-list/items/#{item['id']}", token: token,
                                                                      body: { "clientMutationId" => mutation_id, "checked" => entry["checked"] })
        @changes += 1
        say "Marked #{entry['name']} #{entry['checked'] ? 'checked' : 'unchecked'}"
      end
    end

    def ensure_cook(cook)
      recipe_id = @recipe_ids.fetch(cook["recipe"])
      username = @usernames.fetch(cook["by"])
      _, list = @http.json(:get, "/api/v1/recipes/#{recipe_id}/spoons?limit=50", token: @tokens[cook["by"]])
      done = Array(list.dig("data", "spoons")).any? { |spoon| spoon.dig("chef", "username") == username && spoon["note"] == cook["note"] }
      return if done

      @http.json(:post, "/api/v1/recipes/#{recipe_id}/spoons", token: @tokens[cook["by"]], body: {
        "clientMutationId" => mutation_id, "note" => cook["note"], "nextTime" => cook["nextTime"]
      })
      @changes += 1
      say "#{username} logged a cook of #{cook['recipe']}"
    end
  end
end
