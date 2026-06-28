import Foundation

public enum DeepLinkManifest {
    public static let webDomain = "spoonjoy.app"
    public static let associatedDomains = ["applinks:spoonjoy.app"]
    public static let urlSchemes = ["spoonjoy"]
    public static let routes = [
        "https://spoonjoy.app/",
        "https://spoonjoy.app/recipes",
        "https://spoonjoy.app/recipes/{id}",
        "https://spoonjoy.app/recipes/{id}/edit",
        "https://spoonjoy.app/recipes/{id}#cook",
        "https://spoonjoy.app/recipes/{id}?mode=cook",
        "https://spoonjoy.app/cookbooks",
        "https://spoonjoy.app/cookbooks/{id}",
        "https://spoonjoy.app/users/{identifier}",
        "https://spoonjoy.app/users/{identifier}/fellow-chefs?page={page}",
        "https://spoonjoy.app/users/{identifier}/kitchen-visitors?page={page}",
        "https://spoonjoy.app/shopping-list",
        "https://spoonjoy.app/search",
        "https://spoonjoy.app/search?q={query}&scope={all|recipes|cookbooks|chefs|shopping-list}",
        "https://spoonjoy.app/recipes/new",
        "https://spoonjoy.app/account/settings",
        "spoonjoy://kitchen",
        "spoonjoy://recipes",
        "spoonjoy://recipes/{id}",
        "spoonjoy://recipes/{id}/edit",
        "spoonjoy://recipes/{id}/covers",
        "spoonjoy://recipes/{id}/cook",
        "spoonjoy://recipes/new/edit",
        "spoonjoy://cookbooks",
        "spoonjoy://cookbooks/{id}",
        "spoonjoy://users/{identifier}",
        "spoonjoy://users/{identifier}/fellow-chefs?page={page}",
        "spoonjoy://users/{identifier}/kitchen-visitors?page={page}",
        "spoonjoy://shopping-list",
        "spoonjoy://search",
        "spoonjoy://search?q={query}&scope={all|recipes|cookbooks|chefs|shopping-list}",
        "spoonjoy://capture",
        "spoonjoy://settings"
    ]
}
