import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("App Entity web links and properties")
struct NativeEntityWebLinkTests {
    @Test("recipes and cookbooks link to their public spoonjoy.app page")
    func publicObjectsLinkToTheirPublicPage() {
        #expect(NativeEntityWebLink.url(for: .recipeDetail(id: "recipe_1", presentation: .detail)).absoluteString == "https://spoonjoy.app/recipes/recipe_1")
        #expect(NativeEntityWebLink.url(for: .recipeDetail(id: "recipe_1", presentation: .cook)).absoluteString == "https://spoonjoy.app/recipes/recipe_1")
        #expect(NativeEntityWebLink.url(for: .cookbookDetail(id: "cookbook_1")).absoluteString == "https://spoonjoy.app/cookbooks/cookbook_1")
    }

    @Test("shared text gives back the recipe its spoonjoy.app link names")
    func sharedTextNamesItsRecipe() {
        let link = NativeEntityWebLink.url(for: .recipeDetail(id: "cmwtc4iex00012uovqfv02uv6", presentation: .detail)).absoluteString
        #expect(NativeEntityWebLink.recipeID(inSharedText: "Lemon Pantry Pasta by ari\n\(link)") == "cmwtc4iex00012uovqfv02uv6")
        #expect(NativeEntityWebLink.recipeID(inSharedText: "see https://example.com/recipes/x then \(link)") == "cmwtc4iex00012uovqfv02uv6")
        #expect(NativeEntityWebLink.recipeID(inSharedText: "https://spoonjoy.app/cookbooks/cookbook_1") == nil)
        #expect(NativeEntityWebLink.recipeID(inSharedText: "no link here") == nil)
    }

    @Test("private things link to the page that shows them to their signed-in owner")
    func privateThingsLinkToTheOwnersPage() {
        #expect(NativeEntityWebLink.url(for: .shoppingList).absoluteString == "https://spoonjoy.app/shopping-list")
        #expect(NativeEntityWebLink.url(for: .settings).absoluteString == "https://spoonjoy.app/account/settings")
        #expect(NativeEntityWebLink.url(for: .profile(identifier: "ari")).absoluteString == "https://spoonjoy.app/users/ari")
        #expect(NativeEntityWebLink.url(for: .capture).absoluteString == "https://spoonjoy.app/recipes/new")
        #expect(NativeEntityWebLink.url(for: .search(query: "pasta", scope: .all)).absoluteString == "https://spoonjoy.app/search")
    }

    @Test("every route has a spoonjoy.app page, including the ones the public policy usually answers")
    func everyRouteHasAPage() {
        let pages: [(AppRoute, String)] = [
            (.kitchen, "/"),
            (.unknownLink, "/"),
            (.recipes, "/recipes"),
            (.everyoneRecipes, "/recipes"),
            (.savedRecipes, "/saved-recipes"),
            (.recipeDetail(id: "r1", presentation: .detail), "/recipes/r1"),
            (.recipeEditor(id: "r1"), "/recipes/r1"),
            (.recipeCoverControls(id: "r1"), "/recipes/r1"),
            (.recipeEditor(id: nil), "/recipes/new"),
            (.capture, "/recipes/new"),
            (.cookbooks, "/cookbooks"),
            (.cookbookDetail(id: "c1"), "/cookbooks/c1"),
            (.chefs, "/chefs"),
            (.profile(identifier: "ari"), "/users/ari"),
            (.profileGraph(identifier: "ari", direction: .fellowChefs, page: 2), "/users/ari"),
            (.shoppingList, "/shopping-list"),
            (.search(query: "pasta", scope: .recipes), "/search"),
            (.settings, "/account/settings")
        ]
        for (route, path) in pages {
            #expect(NativeEntityWebLink.path(for: route) == path, "\(route)")
            #expect(NativeEntityWebLink.url(for: route).host() == "spoonjoy.app", "\(route)")
        }
    }

    @Test("an identifier can't add a path segment or leave spoonjoy.app")
    func identifiersStayOneSegment() {
        let url = NativeEntityWebLink.url(for: .profile(identifier: "../evil.example/x?y#z"))
        #expect(url.host == "spoonjoy.app")
        #expect(url.absoluteString == "https://spoonjoy.app/users/..%2Fevil.example%2Fx%3Fy%23z")
        #expect(url.query == nil)
        #expect(url.fragment == nil)
    }

    @Test("a recipe entity carries its servings, step count and cookbooks")
    func recipeDescriptorCarriesWhatAPersonAsksAbout() throws {
        let recipeCatalog = try RecipeFixtureCatalog.decodeFromBundle()
        let lemon = try #require(recipeCatalog.recipe(id: "recipe_lemon_pantry_pasta"))
        let descriptor = try RecipeEntityDescriptor(recipe: lemon)
        #expect(descriptor.stepCount == lemon.steps.count)
        #expect(descriptor.stepCount > 0)
        #expect(descriptor.cookbookTitles == lemon.cookbooks.map(\.title))
        if let servings = lemon.servings, !servings.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            #expect(descriptor.servings == servings.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            #expect(descriptor.servings == nil)
        }
        #expect(RecipeEntityDescriptor.placeholder.stepCount == 0)
        #expect(RecipeEntityDescriptor.placeholder.cookbookTitles.isEmpty)
    }
}

@Suite("App Entity property values")
struct NativeEntityPropertyValueTests {
    @Test("a cook log's date reads the server's timestamp, with or without fractional seconds")
    func cookedDateReadsServerTimestamps() throws {
        let withFraction = try #require(Self.spoon(cookedAt: "2026-06-02T18:30:00.000Z").cookedDate)
        let plain = try #require(Self.spoon(cookedAt: "2026-06-02T18:30:00Z").cookedDate)
        #expect(withFraction == plain)
        #expect(withFraction.timeIntervalSince1970 == 1_780_425_000)
        #expect(Self.spoon(cookedAt: nil).cookedDate == nil)
        #expect(Self.spoon(cookedAt: "  ").cookedDate == nil)
        #expect(Self.spoon(cookedAt: "last Tuesday").cookedDate == nil)
    }

    @Test("every capture source has a plain label")
    func captureSourcesHavePlainLabels() {
        #expect(CaptureDraftSource.cameraImage.label == "Camera")
        #expect(CaptureDraftSource.jsonLD.label == "Web page")
        #expect(Set([CaptureDraftSource.text, .url, .image, .cameraImage, .photoLibraryImage, .shareSheetURL, .jsonLD, .videoURL].map(\.label)).count == 6)
    }

    private static func spoon(cookedAt: String?) -> SpoonEntityDescriptor {
        let placeholder = SpoonEntityDescriptor.placeholder
        return SpoonEntityDescriptor(
            id: placeholder.id,
            spoonID: placeholder.spoonID,
            recipeID: placeholder.recipeID,
            recipeTitle: placeholder.recipeTitle,
            chefID: placeholder.chefID,
            chefUsername: placeholder.chefUsername,
            title: placeholder.title,
            subtitle: placeholder.subtitle,
            disambiguationLabel: placeholder.disambiguationLabel,
            route: placeholder.route,
            photoURL: placeholder.photoURL,
            note: placeholder.note,
            nextTime: placeholder.nextTime,
            cookedAt: cookedAt,
            transferValue: placeholder.transferValue
        )
    }
}
