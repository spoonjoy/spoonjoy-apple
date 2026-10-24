import Foundation
import SpoonjoyCore

/// Real recipes for the screenshot journeys, so a layout is judged on the titles, photos, ingredient notes and step
/// lengths a chef actually has. Each run signs in to an account of its own, so no run token is needed in the titles.
/// The web API stores ingredient names lowercased, so lookups match them ignoring case.
enum JourneyRecipes {
    static let pastaTitle = "Lemon Pantry Pasta"
    /// An ingredient of the pasta's first step and one of its second, for telling which step cook mode is on.
    static let pastaStepOneIngredient = "kosher salt"
    static let pastaStepTwoIngredient = "panko breadcrumbs"
    static let pastaStepCount = 5

    static let chickpeasTitle = "Crispy Chickpeas with Dill Yogurt"
    static let chickpeasStepCount = 4

    static let pastaDescription = "Spaghetti tossed with lemon, garlic and pecorino under a crunch of toasted crumbs. Pantry staples, twenty-five minutes."

    static let pastaSteps = [
        RecipeStepDraft(
            stepNum: 1,
            stepTitle: "Salt the water",
            description: "Bring a large pot of water to a rolling boil and salt it until it tastes like the sea.",
            duration: nil,
            ingredients: [RecipeIngredientDraft(quantity: 1, unit: "tbsp", name: "kosher salt, for the pasta water")],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 2,
            stepTitle: "Toast the crumbs",
            description: "Warm half the oil in a wide skillet over medium heat. Add the panko with a pinch of salt and stir until deep golden and fragrant, about 4 minutes, then tip onto a plate.",
            duration: 4,
            ingredients: [
                RecipeIngredientDraft(quantity: 0.5, unit: "cup", name: "panko breadcrumbs"),
                RecipeIngredientDraft(quantity: 4, unit: "tbsp", name: "extra-virgin olive oil, divided")
            ],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 3,
            stepTitle: "Bloom the garlic",
            description: "Wipe out the skillet, add the rest of the oil, the garlic and the chili flakes, and cook gently until the garlic is pale gold, about 2 minutes. Take the pan off the heat.",
            duration: 2,
            ingredients: [
                RecipeIngredientDraft(quantity: 4, unit: nil, name: "garlic cloves, thinly sliced"),
                RecipeIngredientDraft(quantity: 0.5, unit: "tsp", name: "red chili flakes")
            ],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 4,
            stepTitle: "Cook the spaghetti",
            description: "Cook the spaghetti a minute shy of al dente. Scoop out a mug of the starchy water before you drain it.",
            duration: 9,
            ingredients: [RecipeIngredientDraft(quantity: 12, unit: "oz", name: "spaghetti")],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 5,
            stepTitle: "Toss and finish",
            description: "Add the pasta to the skillet with the lemon zest and juice, the butter and a splash of pasta water. Toss over low heat until glossy, fold in the pecorino and basil, and scatter the crumbs over the top.",
            duration: nil,
            ingredients: [
                RecipeIngredientDraft(quantity: 2, unit: nil, name: "lemons, zested and juiced"),
                RecipeIngredientDraft(quantity: 2, unit: "tbsp", name: "unsalted butter, cubed"),
                RecipeIngredientDraft(quantity: 1, unit: "cup", name: "pecorino romano, finely grated"),
                RecipeIngredientDraft(quantity: 0.5, unit: "cup", name: "basil leaves, torn")
            ],
            outputStepNums: []
        )
    ]

    static let chickpeasDescription = "Smoky roasted chickpeas over a cool garlic and dill yogurt. A snack, a side or dinner with flatbread."

    static let chickpeasSteps = [
        RecipeStepDraft(
            stepNum: 1,
            stepTitle: "Dry the chickpeas",
            description: "Heat the oven to 425°F. Rinse the chickpeas, then pat them very dry with a clean towel, slipping off any loose skins.",
            duration: nil,
            ingredients: [RecipeIngredientDraft(quantity: 2, unit: "can", name: "chickpeas, drained and rinsed")],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 2,
            stepTitle: "Roast until crisp",
            description: "Toss the chickpeas with the oil, paprika and cumin on a sheet pan. Roast, shaking the pan once, until crisp and deeply browned.",
            duration: 28,
            ingredients: [
                RecipeIngredientDraft(quantity: 3, unit: "tbsp", name: "olive oil"),
                RecipeIngredientDraft(quantity: 1, unit: "tsp", name: "smoked paprika"),
                RecipeIngredientDraft(quantity: 1, unit: "tsp", name: "ground cumin")
            ],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 3,
            stepTitle: "Make the dill yogurt",
            description: "Stir the yogurt with the garlic, half the lemon juice and the dill, and season it well with salt.",
            duration: nil,
            ingredients: [
                RecipeIngredientDraft(quantity: 1.5, unit: "cup", name: "greek yogurt"),
                RecipeIngredientDraft(quantity: 1, unit: nil, name: "garlic clove, finely grated"),
                RecipeIngredientDraft(quantity: 0.25, unit: "cup", name: "dill, chopped")
            ],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 4,
            stepTitle: "Serve",
            description: "Spread the yogurt in a shallow bowl, pile the hot chickpeas on top and finish with the rest of the lemon and a pinch of flaky salt.",
            duration: nil,
            ingredients: [
                RecipeIngredientDraft(quantity: 1, unit: nil, name: "lemon, juiced"),
                RecipeIngredientDraft(quantity: 1, unit: "tsp", name: "flaky sea salt")
            ],
            outputStepNums: []
        )
    ]

    /// The pasta's photo is the app's own sample image; the chickpeas' is the web Test Kitchen's. The simulator
    /// reads both from the checkout the journey was built from.
    static func pastaPhoto() throws -> UploadFile {
        try photo("Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png", type: "image/png")
    }

    static func chickpeasPhoto() throws -> UploadFile {
        try photo("Apps/Spoonjoy/Journeys/Fixtures/crispy-chickpeas.jpg", type: "image/jpeg")
    }

    private static func photo(_ relativePath: String, type: String) throws -> UploadFile {
        let checkout = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Support
            .deletingLastPathComponent() // Journeys
            .deletingLastPathComponent() // Spoonjoy
            .deletingLastPathComponent() // Apps
            .deletingLastPathComponent()
        let url = checkout.appendingPathComponent(relativePath)
        return UploadFile(fileName: url.lastPathComponent, contentType: type, data: try Data(contentsOf: url))
    }
}
