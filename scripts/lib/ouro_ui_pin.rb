# frozen_string_literal: true

# The exact ouro-ui-apple pin in Package.swift, as the Xcode project's package requirement. Package.swift pins a release
# (`exact: "0.3.0"`, prereleases included) or, until the release carrying a change is tagged, a full commit
# (`revision: "<40 hex>"`). Both are exact; a branch or a range is refused.
module OuroUIPin
  URL = "https://github.com/ourostack/ouro-ui-apple.git"

  def self.requirement(package_swift)
    pattern = /\.package\(url: "#{Regexp.escape(URL)}", (exact|revision): "([^"]+)"\)/
    match = package_swift.match(pattern)
    return nil unless match

    kind, value = match.captures
    if kind == "exact" && value.match?(/\A\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?\z/)
      { "kind" => "exactVersion", "version" => value }
    elsif kind == "revision" && value.match?(/\A[0-9a-f]{40}\z/)
      { "kind" => "revision", "revision" => value }
    end
  end
end
