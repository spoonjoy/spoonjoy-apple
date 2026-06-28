import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native recipe editor parity")
struct RecipeEditorParityTests {
    fileprivate static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("draft hydrates from recipe and exposes owner-only editing affordances")
    func draftHydratesFromRecipeAndExposesOwnerOnlyEditingAffordances() throws {
        let recipe = recipeEditorRecipe()
        let editor = RecipeEditorViewModel(
            mode: .edit(recipe: recipe, currentChefID: "chef_ari"),
            connectivity: .online,
            now: Self.now
        )

        #expect(editor.route == .recipeEditor(id: "recipe_lemon_pantry_pasta"))
        #expect(editor.isOwner)
        #expect(editor.draft.recipeID == "recipe_lemon_pantry_pasta")
        #expect(editor.draft.title == "Lemon Pantry Pasta")
        #expect(editor.draft.description == "Bright pantry pasta with lemon, garlic, and parmesan.")
        #expect(editor.draft.servings == "4")
        #expect(editor.draft.steps.map(\.id) == ["step_boil", "step_finish"])
        #expect(editor.draft.steps[0].ingredients.map(\.id) == ["ingredient_spaghetti"])
        #expect(editor.draft.steps[1].outputStepNums == [1])
        #expect(editor.ownerTools.map(\.id) == ["save", "delete"])
        #expect(editor.deleteConfirmationTitle == "Delete Lemon Pantry Pasta?")
        #expect(editor.offlineIndicator.display == .synced)
        #expect(editor.conflictBanner == nil)

        let nonOwner = RecipeEditorViewModel(
            mode: .edit(recipe: recipe, currentChefID: "chef_jules"),
            connectivity: .online,
            now: Self.now
        )
        #expect(!nonOwner.isOwner)
        #expect(nonOwner.ownerTools.isEmpty)
        #expect(nonOwner.blockingMessage == "Only ari can edit this recipe.")

        var orphanedCreateDraft = RecipeEditorDraft.blank(currentChefID: "chef_ari")
        orphanedCreateDraft.currentChefID = "chef_jules"
        let orphanedCreate = RecipeEditorViewModel(
            mode: .create(currentChefID: "chef_ari", draft: RecipeEditorDraft.blank(currentChefID: "chef_ari")),
            connectivity: .online,
            now: Self.now
        ).updatingDraft(orphanedCreateDraft)
        #expect(orphanedCreate.blockingMessage == "Only the recipe owner can edit this recipe.")

        let blockedActions: [RecipeEditorAction] = [
            .save(clientMutationID: "cm_non_owner"),
            .deleteRecipe(clientMutationID: "cm_non_owner_delete", confirmation: .confirmed),
            .createStep(
                clientMutationID: "cm_non_owner_step_create",
                step: RecipeEditorStepDraft(
                    id: "local_step_non_owner",
                    stepNum: 3,
                    title: "Serve",
                    description: "Serve hot.",
                    duration: nil,
                    ingredients: [],
                    outputStepNums: [2]
                )
            ),
            .updateStep(
                stepID: "step_finish",
                clientMutationID: "cm_non_owner_step_update",
                title: "Finish pasta",
                description: "Toss pasta with sauce.",
                duration: 180,
                outputStepNums: [1]
            ),
            .deleteStep(stepID: "step_boil", clientMutationID: "cm_non_owner_step_delete", confirmation: .confirmed),
            .reorderStep(stepID: "step_finish", toStepNum: 1, clientMutationID: "cm_non_owner_step_reorder"),
            .addIngredient(
                stepID: "step_finish",
                clientMutationID: "cm_non_owner_ingredient_add",
                ingredient: RecipeEditorIngredientDraft(id: "local_non_owner_ingredient", name: "parmesan", quantity: 0.5, unit: "cup")
            ),
            .deleteIngredient(
                stepID: "step_finish",
                ingredientID: "ingredient_lemon",
                clientMutationID: "cm_non_owner_ingredient_delete",
                confirmation: .confirmed
            ),
            .replaceOutputUses(inputStepID: "step_finish", outputStepNums: [1], clientMutationID: "cm_non_owner_dependencies")
        ]
        for action in blockedActions {
            let plan = try nonOwner.plan(action)
            #expect(plan.blockedReason == "Only ari can edit this recipe.")
            #expect(plan.remoteRequestBuilder == nil)
            #expect(plan.queuedMutation == nil)
            #expect(plan.offlineFallbackMutation == nil)
        }
    }

    @Test("create draft plans exact online create request")
    func createDraftPlansExactOnlineCreateRequest() throws {
        let editor = RecipeEditorViewModel(
            mode: .create(currentChefID: "chef_ari", draft: recipeCreateDraft()),
            connectivity: .online,
            now: Self.now
        )

        #expect(editor.route == .recipeEditor(id: nil))
        #expect(editor.isOwner)
        #expect(editor.ownerTools.map(\.id) == ["save"])

        let create = try editor.plan(.save(clientMutationID: "cm_create"))
        let request = try remoteRequest(from: create)
        try assertJSONRequest(request, method: .post, path: "/api/v1/recipes", expected: [
            "clientMutationId": "cm_create",
            "title": "Garlic Toast",
            "description": "Crispy, buttery toast.",
            "servings": "2",
            "steps": [[
                "stepTitle": "Toast bread",
                "description": "Toast bread until crisp.",
                "duration": 300,
                "ingredients": [[
                    "quantity": 2,
                    "unit": "slice",
                    "name": "bread"
                ]],
                "outputStepNums": []
            ], [
                "stepTitle": "Serve toast",
                "description": "Plate toast with butter.",
                "duration": NSNull(),
                "ingredients": [],
                "outputStepNums": [1]
            ]]
        ])
        #expect(create.queuedMutation == nil)
        #expect(create.offlineFallbackMutation?.queueableKind == .recipeCreate)
    }

    @Test("draft change planner emits nested recipe editor actions without dropping visible form edits")
    func draftChangePlannerEmitsNestedRecipeEditorActionsWithoutDroppingVisibleFormEdits() throws {
        let original = RecipeEditorDraft(recipe: recipeEditorRecipe(), currentChefID: "chef_ari")
        var draft = original
        draft.title = "Lemon Pantry Pasta, edited"
        draft.description = "A brighter weeknight pasta."
        draft.steps = [
            RecipeEditorStepDraft(
                id: "step_finish",
                stepNum: 1,
                title: "Finish pasta",
                description: "Toss pasta with lemon, garlic, and parmesan.",
                duration: 240,
                ingredients: [
                    RecipeEditorIngredientDraft(id: "ingredient_lemon", name: "lemon juice", quantity: 2, unit: "tbsp"),
                    RecipeEditorIngredientDraft(id: "local_parmesan", name: "parmesan", quantity: 0.5, unit: "cup")
                ],
                outputStepNums: []
            ),
            RecipeEditorStepDraft(
                id: "step_boil",
                stepNum: 2,
                title: "Boil pasta",
                description: "Boil spaghetti until al dente.",
                duration: 600,
                ingredients: [],
                outputStepNums: []
            ),
            RecipeEditorStepDraft(
                id: "local_step_serve",
                stepNum: 3,
                title: "Serve",
                description: "Serve hot.",
                duration: nil,
                ingredients: [
                    RecipeEditorIngredientDraft(id: "local_basil", name: "basil", quantity: 3, unit: "leaf")
                ],
                outputStepNums: []
            )
        ]

        let actions = RecipeEditorDraftChangePlanner.actions(
            original: original,
            draft: draft,
            clientMutationID: { "cm_\($0)" }
        )

        #expect(actions == [
            .save(clientMutationID: "cm_recipe-save"),
            .deleteIngredient(
                stepID: "step_boil",
                ingredientID: "ingredient_spaghetti",
                clientMutationID: "cm_delete-ingredient-ingredient_spaghetti",
                confirmation: .confirmed
            ),
            .reorderStep(
                stepID: "step_finish",
                toStepNum: 1,
                clientMutationID: "cm_reorder-step-step_finish-1"
            ),
            .updateStep(
                stepID: "step_finish",
                clientMutationID: "cm_update-step-step_finish",
                title: "Finish pasta",
                description: "Toss pasta with lemon, garlic, and parmesan.",
                duration: 240,
                outputStepNums: []
            ),
            .deleteIngredient(
                stepID: "step_finish",
                ingredientID: "ingredient_lemon",
                clientMutationID: "cm_replace-delete-ingredient-ingredient_lemon",
                confirmation: .confirmed
            ),
            .addIngredient(
                stepID: "step_finish",
                clientMutationID: "cm_replace-add-ingredient-step_finish-ingredient_lemon",
                ingredient: RecipeEditorIngredientDraft(id: "ingredient_lemon", name: "lemon juice", quantity: 2, unit: "tbsp")
            ),
            .addIngredient(
                stepID: "step_finish",
                clientMutationID: "cm_add-ingredient-step_finish-local_parmesan",
                ingredient: RecipeEditorIngredientDraft(id: "local_parmesan", name: "parmesan", quantity: 0.5, unit: "cup")
            ),
            .reorderStep(
                stepID: "step_boil",
                toStepNum: 2,
                clientMutationID: "cm_reorder-step-step_boil-2"
            ),
            .createStep(
                clientMutationID: "cm_create-step-local_step_serve",
                step: RecipeEditorStepDraft(
                    id: "local_step_serve",
                    stepNum: 3,
                    title: "Serve",
                    description: "Serve hot.",
                    duration: nil,
                    ingredients: [
                        RecipeEditorIngredientDraft(id: "local_basil", name: "basil", quantity: 3, unit: "leaf")
                    ],
                    outputStepNums: []
                )
            )
        ])

        let createOnlyActions = RecipeEditorDraftChangePlanner.actions(
            original: RecipeEditorDraft.blank(currentChefID: "chef_ari"),
            draft: recipeCreateDraft(),
            clientMutationID: { "cm_\($0)" }
        )
        #expect(createOnlyActions == [.save(clientMutationID: "cm_recipe-save")])

        var deletedStepDraft = original
        deletedStepDraft.steps.removeAll { $0.id == "step_boil" }
        let deletedStepActions = RecipeEditorDraftChangePlanner.actions(
            original: original,
            draft: deletedStepDraft,
            clientMutationID: { "cm_\($0)" }
        )
        #expect(deletedStepActions.contains(.deleteStep(
            stepID: "step_boil",
            clientMutationID: "cm_delete-step-step_boil",
            confirmation: .confirmed
        )))
        #expect(!deletedStepActions.contains(.deleteIngredient(
            stepID: "step_boil",
            ingredientID: "ingredient_spaghetti",
            clientMutationID: "cm_delete-ingredient-ingredient_spaghetti",
            confirmation: .confirmed
        )))

        var invalidReplacementDraft = original
        invalidReplacementDraft.steps[1].ingredients[0].name = " "
        invalidReplacementDraft.steps[1].ingredients[0].quantity = 0
        let invalidReplacementActions = RecipeEditorDraftChangePlanner.actions(
            original: original,
            draft: invalidReplacementDraft,
            clientMutationID: { "cm_\($0)" }
        )
        #expect(invalidReplacementActions.first == .save(clientMutationID: "cm_recipe-save"))
        let invalidReplacementAddIndex = try #require(invalidReplacementActions.firstIndex(of: .addIngredient(
            stepID: "step_finish",
            clientMutationID: "cm_replace-add-ingredient-step_finish-ingredient_lemon",
            ingredient: RecipeEditorIngredientDraft(id: "ingredient_lemon", name: " ", quantity: 0, unit: "each")
        )))
        let invalidReplacementDeleteIndex = try #require(invalidReplacementActions.firstIndex(of: .deleteIngredient(
            stepID: "step_finish",
            ingredientID: "ingredient_lemon",
            clientMutationID: "cm_replace-delete-ingredient-ingredient_lemon",
            confirmation: .confirmed
        )))
        #expect(invalidReplacementDeleteIndex < invalidReplacementAddIndex)
        let invalidReplacementEditor = RecipeEditorViewModel(
            mode: .edit(recipe: recipeEditorRecipe(), currentChefID: "chef_ari"),
            connectivity: .online,
            now: Self.now
        )
        .updatingDraft(invalidReplacementDraft)
        #expect(try invalidReplacementEditor.plan(.save(clientMutationID: "cm_recipe-save")).blockedReason == "Name every ingredient.")
    }

    @Test("draft renumbering preserves output dependency identity across reorders")
    func draftRenumberingPreservesOutputDependencyIdentityAcrossReorders() {
        var draft = RecipeEditorDraft(
            recipeID: "recipe_layers",
            currentChefID: "chef_ari",
            title: "Layered Toast",
            description: nil,
            servings: nil,
            steps: [
                RecipeEditorStepDraft(id: "step_a", stepNum: 1, title: "A", description: "Make A.", duration: nil, ingredients: [], outputStepNums: []),
                RecipeEditorStepDraft(id: "step_b", stepNum: 2, title: "B", description: "Make B.", duration: nil, ingredients: [], outputStepNums: [1]),
                RecipeEditorStepDraft(id: "step_c", stepNum: 3, title: "C", description: "Make C.", duration: nil, ingredients: [], outputStepNums: [])
            ]
        )

        draft.steps = [draft.steps[2], draft.steps[0], draft.steps[1]]
        draft.renumberStepsPreservingOutputIdentities()

        #expect(draft.steps.map(\.id) == ["step_c", "step_a", "step_b"])
        #expect(draft.steps.map(\.stepNum) == [1, 2, 3])
        #expect(draft.steps[2].outputStepNums == [2])

        draft.steps = [draft.steps[2], draft.steps[0], draft.steps[1]]
        draft.renumberStepsPreservingOutputIdentities()
        #expect(draft.steps.map(\.id) == ["step_b", "step_c", "step_a"])
        #expect(draft.steps[0].outputStepNums.isEmpty)

        draft.steps[1].outputStepNums = [99]
        draft.renumberStepsPreservingOutputIdentities()
        #expect(draft.steps[1].outputStepNums.isEmpty)
    }

    @Test("recipe editor actions expose their client mutation id")
    func recipeEditorActionsExposeTheirClientMutationID() {
        let step = RecipeEditorStepDraft(
            id: "local_step",
            stepNum: 1,
            title: "Serve",
            description: "Serve warm.",
            duration: nil,
            ingredients: [],
            outputStepNums: []
        )
        let ingredient = RecipeEditorIngredientDraft(id: "local_ingredient", name: "basil", quantity: 3, unit: "leaf")
        let actions: [RecipeEditorAction] = [
            .save(clientMutationID: "cm_save"),
            .createStep(clientMutationID: "cm_create_step", step: step),
            .updateStep(stepID: "step_one", clientMutationID: "cm_update_step", title: nil, description: "Stir.", duration: nil, outputStepNums: []),
            .deleteStep(stepID: "step_one", clientMutationID: "cm_delete_step", confirmation: .confirmed),
            .reorderStep(stepID: "step_one", toStepNum: 2, clientMutationID: "cm_reorder_step"),
            .addIngredient(stepID: "step_one", clientMutationID: "cm_add_ingredient", ingredient: ingredient),
            .deleteIngredient(stepID: "step_one", ingredientID: "ingredient_one", clientMutationID: "cm_delete_ingredient", confirmation: .confirmed),
            .replaceOutputUses(inputStepID: "step_two", outputStepNums: [1], clientMutationID: "cm_replace_output"),
            .deleteRecipe(clientMutationID: "cm_delete_recipe", confirmation: .confirmed)
        ]

        #expect(actions.map(\.clientMutationID) == [
            "cm_save",
            "cm_create_step",
            "cm_update_step",
            "cm_delete_step",
            "cm_reorder_step",
            "cm_add_ingredient",
            "cm_delete_ingredient",
            "cm_replace_output",
            "cm_delete_recipe"
        ])
    }

    @Test("draft validation blocks empty titles missing steps invalid ingredients and unsafe dependencies")
    func draftValidationBlocksEmptyTitlesMissingStepsInvalidIngredientsAndUnsafeDependencies() throws {
        var draft = RecipeEditorDraft.blank(currentChefID: "chef_ari")
        draft.title = " \n "
        draft.steps = []
        #expect(RecipeEditorValidator.validate(draft).map(\.message) == [
            "Add a recipe title.",
            "Add at least one step."
        ])

        draft.title = "Pantry Pasta"
        draft.steps = [
            RecipeEditorStepDraft(
                id: "step_finish",
                stepNum: 1,
                title: "Finish",
                description: " ",
                duration: nil,
                ingredients: [
                    RecipeEditorIngredientDraft(id: "ingredient_lemon", name: " ", quantity: 0, unit: nil)
                ],
                outputStepNums: [2]
            )
        ]

        #expect(RecipeEditorValidator.validate(draft).map(\.message) == [
            "Describe every step.",
            "Choose a unit for ingredient.",
            "Name every ingredient.",
            "Use a quantity between 0.001 and 99,999 for ingredient.",
            "Step 1 cannot use output from future step 2."
        ])

        draft.steps[0].ingredients = [
            RecipeEditorIngredientDraft(id: "ingredient_too_small", name: "salt", quantity: 0.0009, unit: "tsp"),
            RecipeEditorIngredientDraft(id: "ingredient_too_big", name: "flour", quantity: 100_000, unit: "g"),
            RecipeEditorIngredientDraft(id: "ingredient_invalid", name: "water", quantity: .infinity, unit: "ml"),
            RecipeEditorIngredientDraft(id: "ingredient_blank_invalid", name: " ", quantity: .infinity, unit: "ml")
        ]
        draft.description = "   "
        draft.steps[0].description = "Mix."
        draft.steps[0].outputStepNums = []
        #expect(RecipeEditorValidator.validate(draft).map(\.message) == [
            "Name every ingredient.",
            "Use a quantity between 0.001 and 99,999 for salt.",
            "Use a quantity between 0.001 and 99,999 for flour.",
            "Use a valid quantity for water.",
            "Use a valid quantity for ingredient."
        ])
        #expect(draft.descriptionForRequest == nil)
    }

    @Test("edge states block unsafe editor actions and expose queued recipe work")
    func edgeStatesBlockUnsafeEditorActionsAndExposeQueuedRecipeWork() throws {
        let recipe = recipeEditorRecipe()
        let shoppingMutation = NativeQueuedMutation.shoppingAddItem(
            name: "lemons",
            quantity: 2,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_shopping",
            createdAt: Self.now()
        )
        let recipeMutation = NativeQueuedMutation.recipeUpdate(
            recipeID: recipe.id,
            clientMutationID: "cm_existing_recipe",
            title: recipe.title,
            description: recipe.description,
            servings: recipe.servings,
            createdAt: Self.now()
        )
        let queuedEditor = RecipeEditorViewModel(
            mode: .edit(recipe: recipe, currentChefID: "chef_ari"),
            connectivity: .online,
            queuedRecipeMutations: [shoppingMutation, recipeMutation],
            now: Self.now
        )

        #expect(queuedEditor.offlineIndicator.display == .queuedWork(count: 1, oldestClientMutationID: "cm_existing_recipe"))

        let editor = RecipeEditorViewModel(
            mode: .edit(recipe: recipe, currentChefID: "chef_ari"),
            connectivity: .online,
            now: Self.now
        )
        #expect(try editor.plan(.deleteStep(
            stepID: "step_boil",
            clientMutationID: "cm_step_delete_blocked",
            confirmation: .notConfirmed
        )).blockedReason == "Confirm before deleting this step.")
        #expect(try editor.plan(.deleteIngredient(
            stepID: "step_finish",
            ingredientID: "ingredient_lemon",
            clientMutationID: "cm_ingredient_delete_blocked",
            confirmation: .notConfirmed
        )).blockedReason == "Confirm before deleting this ingredient.")

        var invalidDraft = recipeCreateDraft()
        invalidDraft.title = " "
        let invalidEditor = RecipeEditorViewModel(
            mode: .create(currentChefID: "chef_ari", draft: recipeCreateDraft()),
            connectivity: .online,
            now: Self.now
        )
        .updatingDraft(invalidDraft)

        #expect(!invalidEditor.canSubmit)
        #expect(try invalidEditor.plan(.save(clientMutationID: "cm_invalid_save")).blockedReason == "Add a recipe title.")

        let createEditor = RecipeEditorViewModel(
            mode: .create(currentChefID: "chef_ari", draft: recipeCreateDraft()),
            connectivity: .online,
            now: Self.now
        )
        #expect(throws: RecipeEditorPlanningError.missingRecipeID) {
            try createEditor.plan(.createStep(
                clientMutationID: "cm_missing_recipe_step",
                step: RecipeEditorStepDraft(
                    id: "local_missing_recipe_step",
                    stepNum: 2,
                    title: "Serve",
                    description: "Serve warm.",
                    duration: nil,
                    ingredients: [],
                    outputStepNums: []
                )
            ))
        }
    }

    @Test("online editor plans exact REST requests for recipe step ingredient and dependency edits")
    func onlineEditorPlansExactRESTRequestsForRecipeStepIngredientAndDependencyEdits() throws {
        let editor = RecipeEditorViewModel(
            mode: .edit(recipe: recipeEditorRecipe(), currentChefID: "chef_ari"),
            connectivity: .online,
            now: Self.now
        )

        let save = try editor.plan(.save(clientMutationID: "cm_update"))
        let deleteRecipe = try editor.plan(.deleteRecipe(clientMutationID: "cm_delete", confirmation: .confirmed))
        let createStep = try editor.plan(.createStep(
            clientMutationID: "cm_step_create",
            step: RecipeEditorStepDraft(
                id: "local_step_3",
                stepNum: 3,
                title: "Serve",
                description: "Serve hot.",
                duration: nil,
                ingredients: [
                    RecipeEditorIngredientDraft(id: "local_basil", name: "basil", quantity: 3, unit: "leaf")
                ],
                outputStepNums: [2]
            )
        ))
        let updateStep = try editor.plan(.updateStep(
            stepID: "step_finish",
            clientMutationID: "cm_step_update",
            title: "Finish pasta",
            description: "Toss pasta with sauce.",
            duration: 180,
            outputStepNums: [1]
        ))
        let deleteStep = try editor.plan(.deleteStep(
            stepID: "step_boil",
            clientMutationID: "cm_step_delete",
            confirmation: .confirmed
        ))
        let reorderStep = try editor.plan(.reorderStep(
            stepID: "step_finish",
            toStepNum: 1,
            clientMutationID: "cm_step_reorder"
        ))
        let addIngredient = try editor.plan(.addIngredient(
            stepID: "step_finish",
            clientMutationID: "cm_ingredient_add",
            ingredient: RecipeEditorIngredientDraft(id: "local_ingredient", name: "parmesan", quantity: 0.5, unit: "cup")
        ))
        let deleteIngredient = try editor.plan(.deleteIngredient(
            stepID: "step_finish",
            ingredientID: "ingredient_lemon",
            clientMutationID: "cm_ingredient_delete",
            confirmation: .confirmed
        ))
        let replaceDependencies = try editor.plan(.replaceOutputUses(
            inputStepID: "step_finish",
            outputStepNums: [1],
            clientMutationID: "cm_dependencies"
        ))

        try assertJSONRequest(try remoteRequest(from: save), method: .patch, path: "/api/v1/recipes/recipe_lemon_pantry_pasta", expected: [
            "clientMutationId": "cm_update",
            "title": "Lemon Pantry Pasta",
            "description": "Bright pantry pasta with lemon, garlic, and parmesan.",
            "servings": "4"
        ])
        assertRequest(
            try remoteRequest(from: deleteRecipe),
            method: .delete,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta",
            queryItems: [URLQueryItem(name: "clientMutationId", value: "cm_delete")],
            expectsBody: false
        )
        try assertJSONRequest(try remoteRequest(from: createStep), method: .post, path: "/api/v1/recipes/recipe_lemon_pantry_pasta/steps", expected: [
            "clientMutationId": "cm_step_create",
            "stepNum": 3,
            "stepTitle": "Serve",
            "description": "Serve hot.",
            "duration": NSNull(),
            "ingredients": [[
                "quantity": 3,
                "unit": "leaf",
                "name": "basil"
            ]],
            "outputStepNums": [2]
        ])
        try assertJSONRequest(try remoteRequest(from: updateStep), method: .patch, path: "/api/v1/recipes/recipe_lemon_pantry_pasta/steps/step_finish", expected: [
            "clientMutationId": "cm_step_update",
            "stepTitle": "Finish pasta",
            "description": "Toss pasta with sauce.",
            "duration": 180,
            "outputStepNums": [1]
        ])
        try assertJSONRequest(try remoteRequest(from: deleteStep), method: .delete, path: "/api/v1/recipes/recipe_lemon_pantry_pasta/steps/step_boil", expected: [
            "clientMutationId": "cm_step_delete"
        ])
        try assertJSONRequest(try remoteRequest(from: reorderStep), method: .post, path: "/api/v1/recipes/recipe_lemon_pantry_pasta/steps/reorder", expected: [
            "clientMutationId": "cm_step_reorder",
            "stepId": "step_finish",
            "toStepNum": 1
        ])
        try assertJSONRequest(try remoteRequest(from: addIngredient), method: .post, path: "/api/v1/recipes/recipe_lemon_pantry_pasta/steps/step_finish/ingredients", expected: [
            "clientMutationId": "cm_ingredient_add",
            "quantity": 0.5,
            "unit": "cup",
            "name": "parmesan"
        ])
        assertRequest(
            try remoteRequest(from: deleteIngredient),
            method: .delete,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta/steps/step_finish/ingredients/ingredient_lemon",
            extraHeaders: ["X-Client-Mutation-Id": "cm_ingredient_delete"],
            expectsBody: false
        )
        try assertJSONRequest(try remoteRequest(from: replaceDependencies), method: .put, path: "/api/v1/recipes/recipe_lemon_pantry_pasta/step-output-uses", expected: [
            "clientMutationId": "cm_dependencies",
            "inputStepId": "step_finish",
            "outputStepNums": [1]
        ])

        #expect(save.queuedMutation == nil)
        #expect(deleteRecipe.queuedMutation == nil)
        #expect(createStep.queuedMutation == nil)
        #expect(save.offlineFallbackMutation?.queueableKind == .recipeUpdate)
        #expect(save.offlineFallbackMutation?.recipeID == "recipe_lemon_pantry_pasta")
        #expect(deleteRecipe.offlineFallbackMutation?.queueableKind == .recipeDelete)
        #expect(createStep.offlineFallbackMutation?.queueableKind == .recipeStepCreate)
        #expect(addIngredient.successRoute == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
    }

    @Test("offline editor queues every allowed recipe mutation with stable dependency keys")
    func offlineEditorQueuesEveryAllowedRecipeMutationWithStableDependencyKeys() throws {
        let createEditor = RecipeEditorViewModel(
            mode: .create(currentChefID: "chef_ari", draft: recipeCreateDraft()),
            connectivity: .offline,
            now: Self.now
        )
        let editor = RecipeEditorViewModel(
            mode: .edit(recipe: recipeEditorRecipe(), currentChefID: "chef_ari"),
            connectivity: .offline,
            now: Self.now
        )

        let createRecipe = try createEditor.plan(.save(clientMutationID: "cm_create_offline"))
        let save = try editor.plan(.save(clientMutationID: "cm_update_offline"))
        let deleteRecipe = try editor.plan(.deleteRecipe(clientMutationID: "cm_delete_offline", confirmation: .confirmed))
        let createStep = try editor.plan(.createStep(
            clientMutationID: "cm_step_create_offline",
            step: RecipeEditorStepDraft(
                id: "local_step_3",
                stepNum: 3,
                title: "Serve",
                description: "Serve hot.",
                duration: nil,
                ingredients: [],
                outputStepNums: [2]
            )
        ))
        let updateStep = try editor.plan(.updateStep(
            stepID: "step_finish",
            clientMutationID: "cm_step_update_offline",
            title: "Finish pasta",
            description: "Toss pasta with sauce.",
            duration: 180,
            outputStepNums: [1]
        ))
        let deleteStep = try editor.plan(.deleteStep(stepID: "step_boil", clientMutationID: "cm_step_delete_offline", confirmation: .confirmed))
        let reorderStep = try editor.plan(.reorderStep(stepID: "step_finish", toStepNum: 1, clientMutationID: "cm_step_reorder_offline"))
        let addIngredient = try editor.plan(.addIngredient(
            stepID: "step_finish",
            clientMutationID: "cm_ingredient_add_offline",
            ingredient: RecipeEditorIngredientDraft(id: "local_ingredient", name: "parmesan", quantity: 0.5, unit: "cup")
        ))
        let deleteIngredient = try editor.plan(.deleteIngredient(
            stepID: "step_finish",
            ingredientID: "ingredient_lemon",
            clientMutationID: "cm_ingredient_delete_offline",
            confirmation: .confirmed
        ))
        let dependencies = try editor.plan(.replaceOutputUses(
            inputStepID: "step_finish",
            outputStepNums: [1],
            clientMutationID: "cm_dependencies_offline"
        ))

        let queuedPlans = [
            createRecipe,
            save,
            deleteRecipe,
            createStep,
            updateStep,
            deleteStep,
            reorderStep,
            addIngredient,
            deleteIngredient,
            dependencies
        ]
        #expect(queuedPlans.allSatisfy { $0.remoteRequestBuilder == nil })
        #expect(queuedPlans.compactMap(\.queuedMutation?.queueableKind) == [
            .recipeCreate,
            .recipeUpdate,
            .recipeDelete,
            .recipeStepCreate,
            .recipeStepUpdate,
            .recipeStepDelete,
            .recipeStepReorder,
            .recipeIngredientAdd,
            .recipeIngredientDelete,
            .recipeOutputUsesReplace
        ])
        #expect(createRecipe.queuedMutation?.dependencyKey == "recipe:new:cm_create_offline")
        #expect([
            save,
            deleteRecipe,
            createStep,
            updateStep,
            deleteStep,
            reorderStep,
            addIngredient,
            deleteIngredient,
            dependencies
        ].compactMap(\.queuedMutation?.dependencyKey) == Array(repeating: "recipe:recipe_lemon_pantry_pasta", count: 9))

        let editQueuedMutations = [
            save,
            deleteRecipe,
            createStep,
            updateStep,
            deleteStep,
            reorderStep,
            addIngredient,
            deleteIngredient,
            dependencies
        ].compactMap(\.queuedMutation)
        #expect(editQueuedMutations.count == 9)
        #expect(OfflineIndicatorDisplay.queuedWork(
            count: editQueuedMutations.count,
            oldestClientMutationID: editQueuedMutations.first?.clientMutationID
        ) == .queuedWork(count: 9, oldestClientMutationID: "cm_update_offline"))

        let unconfirmedDelete = try editor.plan(.deleteRecipe(clientMutationID: "cm_delete_blocked", confirmation: .notConfirmed))
        #expect(unconfirmedDelete.blockedReason == "Confirm before deleting this recipe.")
        #expect(unconfirmedDelete.queuedMutation == nil)
    }

    @Test("conflict display pauses submit and exposes review choices")
    func conflictDisplayPausesSubmitAndExposesReviewChoices() throws {
        let conflict = RecipeEditorConflict(
            resourceID: "recipe_lemon_pantry_pasta",
            serverRevision: .updatedAt("2026-06-25T12:40:00.000Z"),
            localClientMutationID: "cm_update_offline",
            message: "This recipe changed on another device."
        )
        let editor = RecipeEditorViewModel(
            mode: .edit(recipe: recipeEditorRecipe(), currentChefID: "chef_ari"),
            connectivity: .online,
            conflict: conflict,
            now: Self.now
        )

        #expect(editor.canSubmit == false)
        #expect(editor.conflictBanner?.title == "Recipe changed elsewhere")
        #expect(editor.conflictBanner?.message == "This recipe changed on another device.")
        #expect(editor.conflictBanner?.primaryAction == .reviewServerVersion)
        #expect(editor.conflictBanner?.secondaryAction == .discardLocalChange)
        #expect(editor.conflictBanner?.discardActionTitle == "Discard Local Edit")
        #expect(try editor.plan(.save(clientMutationID: "cm_blocked_conflict")).blockedReason == "Resolve the recipe conflict before saving.")

        let discardedConflictEditor = editor.replacingConflict(nil)
        #expect(discardedConflictEditor.canSubmit)
        #expect(try discardedConflictEditor.plan(.save(clientMutationID: "cm_discarded_conflict")).blockedReason == nil)

        let queuedRecipeEdit = NativeQueuedMutation.recipeUpdate(
            recipeID: "recipe_lemon_pantry_pasta",
            clientMutationID: "cm_update_offline",
            title: "Local pasta",
            description: nil,
            servings: nil,
            createdAt: Self.now()
        )
        let dependentRecipeEdit = try NativeQueuedMutation.recipeStepCreate(
            recipeID: "recipe_lemon_pantry_pasta",
            clientMutationID: "cm_step_after_conflict",
            stepNum: 3,
            stepTitle: "Serve",
            description: "Serve warm.",
            duration: nil,
            ingredients: [],
            outputStepNums: [1],
            createdAt: Self.now()
        )
        let unrelatedRecipeEdit = NativeQueuedMutation.recipeUpdate(
            recipeID: "recipe_elsewhere",
            clientMutationID: "cm_unrelated_recipe",
            title: "Other recipe",
            description: nil,
            servings: nil,
            createdAt: Self.now()
        )
        let scopedConflictEditor = RecipeEditorViewModel(
            mode: .edit(recipe: recipeEditorRecipe(), currentChefID: "chef_ari"),
            connectivity: .online,
            conflict: conflict,
            queuedRecipeMutations: [queuedRecipeEdit, dependentRecipeEdit, unrelatedRecipeEdit],
            now: Self.now
        )
        #expect(scopedConflictEditor.conflictBanner?.discardActionTitle == "Discard 2 Queued Edits")
        #expect(scopedConflictEditor.conflictBanner?.message == "This recipe changed on another device. Discarding will remove 2 queued edits for this recipe.")

        let createConflict = RecipeEditorConflict(
            resourceID: "recipe_local_cm_create_offline",
            serverRevision: nil,
            localClientMutationID: "cm_create_offline",
            message: "New recipe conflicted."
        )
        let createMutation = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_create_offline",
            title: "Local Toast",
            description: nil,
            servings: nil,
            steps: [RecipeStepDraft(stepNum: 1, stepTitle: nil, description: "Toast.", duration: nil, ingredients: [RecipeIngredientDraft(quantity: 1, unit: "slice", name: "bread")], outputStepNums: [])],
            createdAt: Self.now()
        )
        let dependentLocalRecipeEdit = NativeQueuedMutation.recipeUpdate(
            recipeID: "recipe_local_cm_create_offline",
            clientMutationID: "cm_created_recipe_update",
            title: "Local Toast Plus",
            description: nil,
            servings: nil,
            createdAt: Self.now()
        )
        let createConflictEditor = RecipeEditorViewModel(
            mode: .create(currentChefID: "chef_ari", draft: recipeCreateDraft()),
            connectivity: .online,
            conflict: createConflict,
            queuedRecipeMutations: [createMutation, dependentLocalRecipeEdit],
            now: Self.now
        )
        #expect(createConflictEditor.conflictBanner?.discardActionTitle == "Discard 2 Queued Edits")
    }

    private static func now() -> String {
        "2026-06-25T12:30:00.000Z"
    }
}

private func recipeCreateDraft() -> RecipeEditorDraft {
    var draft = RecipeEditorDraft.blank(currentChefID: "chef_ari")
    draft.title = "Garlic Toast"
    draft.description = "Crispy, buttery toast."
    draft.servings = "2"
    draft.steps = [
            RecipeEditorStepDraft(
                id: "local_step_1",
                stepNum: 1,
                title: "Toast bread",
            description: "Toast bread until crisp.",
            duration: 300,
            ingredients: [
                RecipeEditorIngredientDraft(id: "local_bread", name: "bread", quantity: 2, unit: "slice")
                ],
                outputStepNums: []
            ),
            RecipeEditorStepDraft(
                id: "local_step_2",
                stepNum: 2,
                title: "Serve toast",
                description: "Plate toast with butter.",
                duration: nil,
                ingredients: [],
                outputStepNums: [1]
            )
        ]
    return draft
}

private func recipeEditorRecipe() -> Recipe {
    Recipe(
        id: "recipe_lemon_pantry_pasta",
        title: "Lemon Pantry Pasta",
        description: "Bright pantry pasta with lemon, garlic, and parmesan.",
        servings: "4",
        chef: ChefSummary(id: "chef_ari", username: "ari"),
        coverImageURL: nil,
        coverProvenanceLabel: nil,
        coverSourceType: nil,
        coverVariant: nil,
        href: "/recipes/recipe_lemon_pantry_pasta",
        canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta")!,
        attribution: RecipeAttribution(
            creditText: "Lemon Pantry Pasta by ari on Spoonjoy",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta")!,
            sourceURLRaw: nil,
            sourceHost: nil,
            sourceRecipe: nil
        ),
        createdAt: "2026-06-25T12:00:00.000Z",
        updatedAt: "2026-06-25T12:20:00.000Z",
        steps: [
            RecipeStep(
                id: "step_boil",
                stepNum: 1,
                stepTitle: "Boil pasta",
                description: "Boil spaghetti until al dente.",
                duration: 600,
                ingredients: [
                    RecipeIngredient(id: "ingredient_spaghetti", name: "spaghetti", quantity: 1, unit: "lb")
                ]
            ),
            RecipeStep(
                id: "step_finish",
                stepNum: 2,
                stepTitle: "Finish",
                description: "Toss pasta with lemon and garlic.",
                duration: 180,
                ingredients: [
                    RecipeIngredient(id: "ingredient_lemon", name: "lemon", quantity: 1, unit: "each")
                ],
                usingSteps: [
                    RecipeStepOutputUse(
                        id: "use_boil",
                        inputStepNum: 2,
                        outputStepNum: 1,
                        outputOfStep: RecipeStepOutputReference(stepNum: 1, stepTitle: "Boil pasta")
                    )
                ]
            )
        ],
        cookbooks: []
    )
}

private func remoteRequest(from plan: RecipeEditorMutationPlan) throws -> APIRequest {
    guard let builder = plan.remoteRequestBuilder else {
        throw RecipeEditorParityTestFailure("Expected an online editor mutation to provide a remote request builder.")
    }
    return try builder.urlRequest(configuration: RecipeEditorParityTests.configuration)
}

private func assertJSONRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    expected: [String: Any]
) throws {
    assertRequest(
        request,
        method: method,
        path: path,
        extraHeaders: ["Content-Type": "application/json"],
        expectsBody: true
    )
    #expect(request.queryItems.isEmpty)
    #expect(NSDictionary(dictionary: try jsonBody(from: request)).isEqual(to: expected))
}

private func assertRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    queryItems: [URLQueryItem] = [],
    extraHeaders: [String: String] = [:],
    expectsBody: Bool
) {
    #expect(request.method == method)
    #expect(request.url.path == path)
    #expect(request.queryItems == queryItems)
    #expect(request.headers == [
        "Accept": "application/json",
        "Authorization": "Bearer sj_private_token"
    ].merging(extraHeaders) { _, newValue in newValue })
    #expect(request.responseCachePolicy == .privateNoStore)
    if expectsBody {
        #expect(request.body != nil)
    } else {
        #expect(request.body == nil)
    }
}

private func jsonBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private struct RecipeEditorParityTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
