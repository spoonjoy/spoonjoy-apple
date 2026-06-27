import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("URLSession API transport")
struct APITransportTests {
    @Test("URLSession transport builds URLRequests and decodes successful envelopes")
    func transportBuildsURLRequestsAndDecodesSuccessEnvelopes() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(requestID: "req_transport_success", name: "Lemon pantry")
                ))
            ]
        )
        let transport = URLSessionAPITransport(session: session)
        let request = APIRequestBuilder(
            method: .patch,
            pathComponents: ["api", "v1", "profile"],
            queryItems: [
                URLQueryItem(name: "include", value: "preferences"),
                URLQueryItem(name: "device", value: "iPhone 26")
            ],
            headers: ["Content-Type": "application/json", "X-Client-Mutation-Id": "profile-update-1"],
            body: Data(#"{"displayName":"Ari"}"#.utf8),
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: .privateNoStore
        )

        let envelope = try await transport.send(
            request,
            configuration: Self.configuration(bearerToken: "sj_access_original"),
            decode: TransportPayload.self
        )
        let capturedRequest = try #require(await session.capturedRequests().first)

        #expect(envelope.requestID == "req_transport_success")
        #expect(envelope.data == TransportPayload(name: "Lemon pantry"))
        #expect(capturedRequest.httpMethod == "PATCH")
        #expect(capturedRequest.url?.absoluteString == "https://spoonjoy.app/api/v1/profile?include=preferences&device=iPhone%2026")
        #expect(capturedRequest.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(capturedRequest.value(forHTTPHeaderField: "Authorization") == "Bearer sj_access_original")
        #expect(capturedRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(capturedRequest.value(forHTTPHeaderField: "X-Client-Mutation-Id") == "profile-update-1")
        #expect(capturedRequest.httpBody == Data(#"{"displayName":"Ari"}"#.utf8))
        #expect(capturedRequest.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test("transport preserves already encoded path segments exactly once")
    func transportPreservesAlreadyEncodedPathSegmentsExactlyOnce() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(requestID: "req_encoded_path", name: "Encoded path")
                ))
            ]
        )
        let transport = URLSessionAPITransport(session: session)
        let request = APIRequestBuilder(
            method: .get,
            pathComponents: ["api", "v1", "recipes", "recipe/with spaces/été"],
            queryItems: [URLQueryItem(name: "include", value: "chef profile")],
            defaultAuthorization: .omit,
            responseCachePolicy: .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300)
        )

        _ = try await transport.send(
            request,
            configuration: Self.configuration(bearerToken: "sj_access_unused"),
            decode: TransportPayload.self
        )
        let capturedRequest = try #require(await session.capturedRequests().first)

        #expect(capturedRequest.url?.absoluteString == "https://spoonjoy.app/api/v1/recipes/recipe%2Fwith%20spaces%2F%C3%A9t%C3%A9?include=chef%20profile")
        #expect(capturedRequest.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(capturedRequest.cachePolicy == .useProtocolCachePolicy)
    }

    @Test("URLSession native sync transport applies bootstrap data and classifies mutation HTTP failures")
    func urlSessionNativeSyncTransportAppliesBootstrapDataAndClassifiesMutationHTTPFailures() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.nativeSyncEnvelope(
                        requestID: "req_sync_bootstrap",
                        resourceID: "profile_ari",
                        nextCursor: "v1.after"
                    )
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(requestID: "req_sync_success", name: "queued")
                )),
                .success(Self.response(
                    statusCode: 401,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_sync_auth",
                        code: "unauthorized",
                        message: "Sign in again.",
                        status: 401
                    )
                )),
                .success(Self.response(
                    statusCode: 409,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_sync_conflict",
                        code: "conflict",
                        message: "Shopping item changed elsewhere.",
                        status: 409
                    )
                )),
                .success(Self.response(
                    statusCode: 400,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_sync_bad_request",
                        code: "bad_request",
                        message: "Invalid mutation.",
                        status: 400
                    )
                )),
                .success(Self.response(
                    statusCode: 503,
                    headers: ["Content-Type": "application/json", "Retry-After": "6"],
                    body: Self.errorEnvelope(
                        requestID: "req_sync_retry",
                        code: "origin_busy",
                        message: "Try again shortly.",
                        status: 503
                    )
                )),
                .success(Self.response(
                    statusCode: 409,
                    headers: ["Content-Type": "application/json", "Retry-After": "5"],
                    body: Self.errorEnvelope(
                        requestID: "req_sync_idempotency",
                        code: "idempotency_in_progress",
                        message: "Mutation is still in progress.",
                        status: 409
                    )
                )),
                .success(Self.response(
                    statusCode: 503,
                    headers: ["Content-Type": "text/plain"],
                    body: Data("busy".utf8)
                )),
                .failure(TransportFixtureError.boom)
            ]
        )
        let transport = URLSessionNativeSyncTransport(
            apiTransport: URLSessionAPITransport(session: session)
        )
        let configuration = Self.configuration(bearerToken: "sj_access_native")
        let bootstrapRequest = try NativeSyncBootstrapRequest.defaultRequest(cursor: nil)
            .urlRequest(configuration: configuration)

        let bootstrap = try await transport.bootstrap(
            request: bootstrapRequest,
            configuration: configuration
        )
        guard case .syncData(let syncData) = bootstrap else {
            Issue.record("Expected native sync bootstrap to return decoded sync data")
            return
        }

        let success = try await transport.send(
            .shoppingAddItem(
                name: "grapefruit",
                quantity: 1,
                unit: "each",
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_success",
                createdAt: "2026-06-16T11:59:00.000Z"
            ),
            configuration: configuration
        )
        let authFailure = try await transport.send(
            .shoppingAddItem(
                name: "mint",
                quantity: 1,
                unit: "bunch",
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_auth",
                createdAt: "2026-06-16T11:59:30.000Z"
            ),
            configuration: configuration
        )
        let conflict = try await transport.send(
            .shoppingAddItem(
                name: "lemons",
                quantity: 3,
                unit: "each",
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_conflict",
                createdAt: "2026-06-16T12:00:00.000Z"
            ),
            configuration: configuration
        )
        do {
            _ = try await transport.send(
                .shoppingAddItem(
                    name: "bad mutation",
                    quantity: 1,
                    unit: "each",
                    categoryKey: nil,
                    iconKey: nil,
                    clientMutationID: "cm_bad_request",
                    createdAt: "2026-06-16T12:00:30.000Z"
                ),
                configuration: configuration
            )
            Issue.record("Expected non-retryable sync mutation to throw")
        } catch let error as APITransportError {
            #expect(error.statusCode == 400)
            #expect(error.apiError?.message == "Invalid mutation.")
        }
        let retry = try await transport.send(
            .shoppingAddItem(
                name: "limes",
                quantity: 2,
                unit: "each",
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_retry",
                createdAt: "2026-06-16T12:01:00.000Z"
            ),
            configuration: configuration
        )
        let idempotencyRetry = try await transport.send(
            .shoppingAddItem(
                name: "oranges",
                quantity: 4,
                unit: "each",
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_idempotency_retry",
                createdAt: "2026-06-16T12:02:00.000Z"
            ),
            configuration: configuration
        )
        let defaultRetry = try await transport.send(
            .shoppingAddItem(
                name: "pears",
                quantity: 2,
                unit: "each",
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_default_retry",
                createdAt: "2026-06-16T12:03:00.000Z"
            ),
            configuration: configuration
        )
        let networkRetry = try await transport.send(
            .shoppingAddItem(
                name: "shallots",
                quantity: 3,
                unit: "each",
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_network_retry",
                createdAt: "2026-06-16T12:04:00.000Z"
            ),
            configuration: configuration
        )
        let capturedRequests = await session.capturedRequests()

        #expect(syncData.entries.map(\.resourceID) == ["profile_ari"])
        #expect(syncData.nextCursor?.rawValue == "v1.after")
        #expect(success == .success(serverRevision: nil))
        #expect(authFailure == .authFailure(message: "Sign in again."))
        #expect(conflict == .conflict(kind: .validation, serverRevision: nil, message: "Shopping item changed elsewhere."))
        #expect(retry == .retry(afterSeconds: 6, message: "Try again shortly."))
        #expect(idempotencyRetry == .retry(afterSeconds: 5, message: "Mutation is still in progress."))
        #expect(defaultRetry == .retry(afterSeconds: NativeSyncRetrySchedule().baseDelaySeconds(forRetryCount: 0), message: "HTTP 503 returned a non-JSON response."))
        #expect(networkRetry == .retry(afterSeconds: NativeSyncRetrySchedule().baseDelaySeconds(forRetryCount: 0), message: "Native sync request failed."))
        #expect(capturedRequests.map(\.httpMethod) == ["GET", "POST", "POST", "POST", "POST", "POST", "POST", "POST", "POST"])
        #expect(capturedRequests[0].url?.absoluteString == "https://spoonjoy.app/api/v1/me/sync?limit=20")
        #expect(capturedRequests[1].url?.absoluteString == "https://spoonjoy.app/api/v1/shopping-list/items")
        #expect(capturedRequests[1].value(forHTTPHeaderField: "Authorization") == "Bearer sj_access_native")
        #expect(capturedRequests[5].value(forHTTPHeaderField: "X-Client-Mutation-Id") == nil)
    }

    @Test("URLSession native sync transport returns typed recipe import blockers")
    func urlSessionNativeSyncTransportReturnsTypedRecipeImportBlockers() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.recipeImportProviderSecretBlockerEnvelope(requestID: "req_import_blocked")
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let result = try await transport.send(
            .recipeImportSubmit(
                source: .url(URL(string: "https://example.com/provider-blocked-recipe")!),
                clientMutationID: "cm_import_blocked",
                createdAt: "2026-06-16T12:05:00.000Z"
            ),
            configuration: Self.configuration(bearerToken: "sj_access_native")
        )
        let capturedRequest = try #require(await session.capturedRequests().first)

        #expect(result == .blocked(
            .providerSecret(resourceID: "recipe-import"),
            message: "ProviderSecret is required before Spoonjoy can finish this import."
        ))
        #expect(capturedRequest.httpMethod == "POST")
        #expect(capturedRequest.url?.absoluteString == "https://spoonjoy.app/api/v1/recipes/import")
    }

    @Test("URLSession native sync transport drains accepted recipe imports without blockers")
    func urlSessionNativeSyncTransportDrainsAcceptedRecipeImportsWithoutBlockers() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.recipeImportAcceptedEnvelope(requestID: "req_import_accepted")
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let result = try await transport.send(
            .recipeImportSubmit(
                source: .url(URL(string: "https://example.com/accepted-import")!),
                clientMutationID: "cm_import_accepted",
                createdAt: "2026-06-16T12:05:30.000Z"
            ),
            configuration: Self.configuration(bearerToken: "sj_access_native")
        )

        #expect(result == .success(serverRevision: nil))
    }

    @Test("URLSession native sync transport extracts recipe editor id remaps from success envelopes")
    func urlSessionNativeSyncTransportExtractsRecipeEditorIDRemapsFromSuccessEnvelopes() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_recipe_create",
                        data: """
                        {
                          "created": true,
                          "recipe": {
                            "id": "recipe_server_created",
                            "steps": [
                              {
                                "id": "step_server_first",
                                "stepNum": 1,
                                "ingredients": [
                                  { "id": "ingredient_server_apple", "name": "apple", "quantity": 1, "unit": "whole" },
                                  { "id": "ingredient_server_zucchini", "name": "zucchini", "quantity": 2, "unit": "cup" }
                                ]
                              },
                              {
                                "id": "step_server_second",
                                "stepNum": 2,
                                "ingredients": [
                                  { "id": "ingredient_server_butter", "name": "butter", "quantity": 1, "unit": "tbsp" }
                                ]
                              }
                            ]
                          },
                          "mutation": { "clientMutationId": "cm_recipe_create", "replayed": false }
                        }
                        """
                    )
                )),
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_step_create",
                        data: """
                        {
                          "created": true,
                          "step": {
                            "id": "step_server_created",
                            "ingredients": [
                              { "id": "ingredient_server_basil", "name": "basil", "quantity": 2, "unit": "leaf" },
                              { "id": "ingredient_server_salt", "name": "salt", "quantity": 1, "unit": "pinch" }
                            ]
                          },
                          "mutation": { "clientMutationId": "cm_step_create", "replayed": false }
                        }
                        """
                    )
                )),
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_ingredient_add",
                        data: """
                        {
                          "created": true,
                          "ingredient": { "id": "ingredient_server_created" },
                          "mutation": { "clientMutationId": "cm_ingredient_add", "replayed": false }
                        }
                        """
                    )
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let createRecipe = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_recipe_create",
            title: "Offline Toast",
            description: nil,
            servings: nil,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Prep",
                    description: "Prep.",
                    duration: nil,
                    ingredients: [
                        RecipeIngredientDraft(quantity: 2, unit: "cup", name: "zucchini"),
                        RecipeIngredientDraft(quantity: 1, unit: "whole", name: "apple")
                    ],
                    outputStepNums: []
                ),
                RecipeStepDraft(stepNum: 2, stepTitle: "Serve", description: "Serve.", duration: nil, ingredients: [RecipeIngredientDraft(quantity: 1, unit: "tbsp", name: "butter")], outputStepNums: [])
            ],
            createdAt: "2026-06-16T12:00:00.000Z"
        )
        let createStep = try NativeQueuedMutation.recipeStepCreate(
            recipeID: "recipe_server_created",
            clientMutationID: "cm_step_create",
            stepNum: 3,
            stepTitle: "Garnish",
            description: "Garnish.",
            duration: nil,
            ingredients: [
                RecipeIngredientDraft(quantity: 1, unit: "pinch", name: "salt"),
                RecipeIngredientDraft(quantity: 2, unit: "leaf", name: "basil")
            ],
            outputStepNums: [],
            createdAt: "2026-06-16T12:01:00.000Z"
        )
        let addIngredient = try NativeQueuedMutation.recipeIngredientAdd(
            recipeID: "recipe_server_created",
            stepID: "step_server_created",
            clientMutationID: "cm_ingredient_add",
            quantity: 1,
            unit: "tbsp",
            name: "butter",
            createdAt: "2026-06-16T12:02:00.000Z"
        )

        let createRecipeResult = try await transport.send(createRecipe, configuration: Self.configuration(bearerToken: "sj_access_native"))
        let createStepResult = try await transport.send(createStep, configuration: Self.configuration(bearerToken: "sj_access_native"))
        let addIngredientResult = try await transport.send(addIngredient, configuration: Self.configuration(bearerToken: "sj_access_native"))

        #expect(createRecipeResult == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "recipe_local_cm_recipe_create", serverID: "recipe_server_created"),
            NativeSyncIDRemap(localID: "step_local_cm_recipe_create_1", serverID: "step_server_first"),
            NativeSyncIDRemap(localID: "ingredient_local_cm_recipe_create_1_1", serverID: "ingredient_server_zucchini"),
            NativeSyncIDRemap(localID: "ingredient_local_cm_recipe_create_1_2", serverID: "ingredient_server_apple"),
            NativeSyncIDRemap(localID: "step_local_cm_recipe_create_2", serverID: "step_server_second"),
            NativeSyncIDRemap(localID: "ingredient_local_cm_recipe_create_2_1", serverID: "ingredient_server_butter")
        ]))
        #expect(createStepResult == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "step_local_cm_step_create", serverID: "step_server_created"),
            NativeSyncIDRemap(localID: "ingredient_local_cm_step_create_1", serverID: "ingredient_server_salt"),
            NativeSyncIDRemap(localID: "ingredient_local_cm_step_create_2", serverID: "ingredient_server_basil")
        ]))
        #expect(addIngredientResult == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "ingredient_local_cm_ingredient_add", serverID: "ingredient_server_created")
        ]))
    }

    @Test("URLSession native sync transport extracts shopping add item id remaps")
    func urlSessionNativeSyncTransportExtractsShoppingAddItemIDRemaps() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_shopping_add",
                        data: """
                        {
                          "created": true,
                          "updated": false,
                          "item": {
                            "id": "item_server_limes",
                            "name": "limes",
                            "quantity": 4,
                            "unit": "each",
                            "checked": false,
                            "checkedAt": null,
                            "deletedAt": null,
                            "categoryKey": "produce",
                            "iconKey": "lemon",
                            "sortIndex": 1,
                            "updatedAt": "2026-06-16T12:00:00.000Z"
                          },
                          "mutation": { "clientMutationId": "cm_shopping_add_limes", "replayed": false }
                        }
                        """
                    )
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let addItem = NativeQueuedMutation.shoppingAddItem(
            name: "limes",
            quantity: 4,
            unit: "each",
            categoryKey: "produce",
            iconKey: "lemon",
            clientMutationID: "cm_shopping_add_limes",
            createdAt: "2026-06-16T12:00:00.000Z"
        )

        #expect(try await transport.send(addItem, configuration: Self.configuration(bearerToken: "sj_access_native")) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "item_local_cm_shopping_add_limes", serverID: "item_server_limes")
        ]))
    }

    @Test("URLSession native sync transport extracts shopping add-from-recipe item id remaps")
    func urlSessionNativeSyncTransportExtractsShoppingAddFromRecipeItemIDRemaps() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_shopping_recipe",
                        data: """
                        {
                          "recipe": { "id": "recipe_lemon_pasta", "title": "Lemon Pasta" },
                          "created": 2,
                          "updated": 0,
                          "items": [
                            {
                              "id": "item_server_lemons",
                              "name": "lemons",
                              "quantity": 2,
                              "unit": "each",
                              "checked": false,
                              "checkedAt": null,
                              "deletedAt": null,
                              "categoryKey": null,
                              "iconKey": null,
                              "sortIndex": 1,
                              "updatedAt": "2026-06-16T12:00:00.000Z"
                            },
                            {
                              "id": "item_server_pasta",
                              "name": "pasta",
                              "quantity": 8,
                              "unit": "oz",
                              "checked": false,
                              "checkedAt": null,
                              "deletedAt": null,
                              "categoryKey": null,
                              "iconKey": null,
                              "sortIndex": 2,
                              "updatedAt": "2026-06-16T12:00:00.000Z"
                            }
                          ],
                          "mutation": { "clientMutationId": "cm_shopping_recipe", "replayed": false }
                        }
                        """
                    )
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let addFromRecipe = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_lemon_pasta",
            scaleFactor: 2,
            recipeIngredients: [
                RecipeIngredient(id: "ingredient_pasta", name: "pasta", quantity: 4, unit: "oz"),
                RecipeIngredient(id: "ingredient_lemons", name: "lemons", quantity: 1, unit: "each")
            ],
            clientMutationID: "cm_shopping_recipe",
            createdAt: "2026-06-16T12:00:00.000Z"
        )

        #expect(try await transport.send(addFromRecipe, configuration: Self.configuration(bearerToken: "sj_access_native")) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "item_local_cm_shopping_recipe-ingredient-1", serverID: "item_server_pasta"),
            NativeSyncIDRemap(localID: "item_local_cm_shopping_recipe-ingredient-2", serverID: "item_server_lemons")
        ]))
        let request = try #require(await session.capturedRequests().first)
        let requestBody = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(requestBody.contains(#""recipeId":"recipe_lemon_pasta""#))
        #expect(requestBody.contains(#""scaleFactor":2"#))
        #expect(requestBody.contains("shoppingRecipeIngredients") == false)
        #expect(requestBody.contains("serverItemIds") == false)
    }

    @Test("URLSession native sync transport remaps duplicate recipe ingredients to coalesced shopping row")
    func urlSessionNativeSyncTransportRemapsDuplicateRecipeIngredientsToCoalescedShoppingRow() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_shopping_recipe_duplicates",
                        data: """
                        {
                          "recipe": { "id": "recipe_duplicate_sugar", "title": "Layer Cake" },
                          "created": 1,
                          "updated": 1,
                          "items": [
                            {
                              "id": "item_server_sugar",
                              "name": "sugar",
                              "quantity": 3,
                              "unit": "cup",
                              "checked": false,
                              "checkedAt": null,
                              "deletedAt": null,
                              "categoryKey": null,
                              "iconKey": null,
                              "sortIndex": 1,
                              "updatedAt": "2026-06-16T12:00:00.000Z"
                            }
                          ],
                          "mutation": { "clientMutationId": "cm_shopping_duplicate_recipe", "replayed": false }
                        }
                        """
                    )
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let addFromRecipe = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_duplicate_sugar",
            scaleFactor: 2,
            recipeIngredients: [
                RecipeIngredient(id: "ingredient_sugar_a", name: "sugar", quantity: 1, unit: "cup"),
                RecipeIngredient(id: "ingredient_sugar_b", name: "sugar", quantity: 0.5, unit: "cup")
            ],
            clientMutationID: "cm_shopping_duplicate_recipe",
            createdAt: "2026-06-16T12:00:00.000Z"
        )

        #expect(try await transport.send(addFromRecipe, configuration: Self.configuration(bearerToken: "sj_access_native")) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "item_local_cm_shopping_duplicate_recipe-ingredient-1", serverID: "item_server_sugar"),
            NativeSyncIDRemap(localID: "item_local_cm_shopping_duplicate_recipe-ingredient-2", serverID: "item_server_sugar")
        ]))
    }

    @Test("URLSession native sync transport fails closed for unstable shopping recipe remaps")
    func urlSessionNativeSyncTransportFailsClosedForUnstableShoppingRecipeRemaps() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_shopping_recipe_no_descriptors",
                        data: """
                        {
                          "items": [
                            { "id": "item_server_first", "name": "first", "quantity": 1, "unit": null },
                            { "id": "item_server_second", "name": "second", "quantity": 2, "unit": "each" }
                          ]
                        }
                        """
                    )
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_shopping_recipe_malformed_descriptors",
                        data: #"{ "items": [{ "id": "item_server_sugar", "name": "sugar", "quantity": 1, "unit": "cup" }] }"#
                    )
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_shopping_recipe_single_mismatch",
                        data: #"{ "items": [{ "id": "item_server_sugar", "name": "sugar", "quantity": 4, "unit": "cup" }] }"#
                    )
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_shopping_recipe_mixed_mismatch",
                        data: #"{ "items": [{ "id": "item_server_sugar", "name": "sugar", "quantity": 4, "unit": "cup" }] }"#
                    )
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_shopping_recipe_aggregate_mismatch",
                        data: #"{ "items": [{ "id": "item_server_sugar", "name": "sugar", "quantity": 4, "unit": "cup" }] }"#
                    )
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_shopping_recipe_blank_unit",
                        data: #"{ "items": [{ "id": "item_server_blank_unit", "name": "sugar", "quantity": 1, "unit": null }] }"#
                    )
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(requestID: "req_shopping_clear_empty", data: #"{}"#)
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let configuration = Self.configuration(bearerToken: "sj_access_native")
        let noDescriptors = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_no_descriptors",
            scaleFactor: 1,
            clientMutationID: "cm_no_descriptors",
            createdAt: "2026-06-16T12:00:00.000Z"
        )
        let malformedDescriptors = try Self.decodedMutation(
            type: .shoppingAddFromRecipe,
            fields: [
                "recipeId": "recipe_malformed_descriptors",
                "scaleFactor": 1,
                "shoppingRecipeIngredients": [
                    ["name": "sugar", "unit": "cup"],
                    ["quantity": 1, "unit": "cup"]
                ]
            ]
        )
        let singleMismatch = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_single_mismatch",
            scaleFactor: 1,
            recipeIngredients: [
                RecipeIngredient(id: "ingredient_sugar", name: "sugar", quantity: 1, unit: "cup")
            ],
            clientMutationID: "cm_single_mismatch",
            createdAt: "2026-06-16T12:01:00.000Z"
        )
        let mixedMismatch = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_mixed_mismatch",
            scaleFactor: 1,
            recipeIngredients: [
                RecipeIngredient(id: "ingredient_sugar", name: "sugar", quantity: 1, unit: "cup"),
                RecipeIngredient(id: "ingredient_flour", name: "flour", quantity: 1, unit: "cup")
            ],
            clientMutationID: "cm_mixed_mismatch",
            createdAt: "2026-06-16T12:02:00.000Z"
        )
        let aggregateMismatch = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_aggregate_mismatch",
            scaleFactor: 1,
            recipeIngredients: [
                RecipeIngredient(id: "ingredient_sugar_a", name: "sugar", quantity: 1, unit: "cup"),
                RecipeIngredient(id: "ingredient_sugar_b", name: "sugar", quantity: 2, unit: "cup")
            ],
            clientMutationID: "cm_aggregate_mismatch",
            createdAt: "2026-06-16T12:03:00.000Z"
        )
        let blankUnitMatch = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_blank_unit",
            scaleFactor: 1,
            recipeIngredients: [
                RecipeIngredient(id: "ingredient_sugar_blank_unit", name: "sugar", quantity: 1, unit: "   ")
            ],
            clientMutationID: "cm_blank_unit",
            createdAt: "2026-06-16T12:04:00.000Z"
        )
        let clearAll = NativeQueuedMutation.shoppingClearAll(
            clientMutationID: "cm_clear_remap_empty",
            createdAt: "2026-06-16T12:05:00.000Z"
        )

        #expect(try await transport.send(noDescriptors, configuration: configuration) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "item_local_cm_no_descriptors-ingredient-1", serverID: "item_server_first"),
            NativeSyncIDRemap(localID: "item_local_cm_no_descriptors-ingredient-2", serverID: "item_server_second")
        ]))
        #expect(try await transport.send(malformedDescriptors, configuration: configuration) == .success(serverRevision: nil, idRemaps: []))
        #expect(try await transport.send(singleMismatch, configuration: configuration) == .success(serverRevision: nil, idRemaps: []))
        #expect(try await transport.send(mixedMismatch, configuration: configuration) == .success(serverRevision: nil, idRemaps: []))
        #expect(try await transport.send(aggregateMismatch, configuration: configuration) == .success(serverRevision: nil, idRemaps: []))
        #expect(try await transport.send(blankUnitMatch, configuration: configuration) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "item_local_cm_blank_unit-ingredient-1", serverID: "item_server_blank_unit")
        ]))
        #expect(try await transport.send(clearAll, configuration: configuration) == .success(serverRevision: nil, idRemaps: []))
    }

    @Test("URLSession native sync transport extracts top-level recipe editor id remaps")
    func urlSessionNativeSyncTransportExtractsTopLevelRecipeEditorIDRemaps() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_recipe_top_level",
                        data: #"{ "created": true, "recipeId": "recipe_server_top_level" }"#
                    )
                )),
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_step_top_level",
                        data: #"{ "created": true, "recipeId": "recipe_server_top_level", "stepId": "step_server_top_level" }"#
                    )
                )),
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_ingredient_top_level",
                        data: #"{ "created": true, "recipeId": "recipe_server_top_level", "stepId": "step_server_top_level", "ingredientId": "ingredient_server_top_level" }"#
                    )
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let configuration = Self.configuration(bearerToken: "sj_access_native")
        let createRecipe = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_recipe_top_level",
            title: "Top-level Toast",
            description: nil,
            servings: nil,
            steps: [RecipeStepDraft(stepNum: 1, stepTitle: "Prep", description: "Prep.", duration: nil, ingredients: [], outputStepNums: [])],
            createdAt: "2026-06-16T12:00:00.000Z"
        )
        let createStep = try NativeQueuedMutation.recipeStepCreate(
            recipeID: "recipe_server_top_level",
            clientMutationID: "cm_step_top_level",
            stepNum: 2,
            stepTitle: "Serve",
            description: "Serve.",
            duration: nil,
            ingredients: [],
            outputStepNums: [1],
            createdAt: "2026-06-16T12:01:00.000Z"
        )
        let addIngredient = try NativeQueuedMutation.recipeIngredientAdd(
            recipeID: "recipe_server_top_level",
            stepID: "step_server_top_level",
            clientMutationID: "cm_ingredient_top_level",
            quantity: 1,
            unit: "pinch",
            name: "salt",
            createdAt: "2026-06-16T12:02:00.000Z"
        )

        #expect(try await transport.send(createRecipe, configuration: configuration) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "recipe_local_cm_recipe_top_level", serverID: "recipe_server_top_level")
        ]))
        #expect(try await transport.send(createStep, configuration: configuration) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "step_local_cm_step_top_level", serverID: "step_server_top_level")
        ]))
        #expect(try await transport.send(addIngredient, configuration: configuration) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "ingredient_local_cm_ingredient_top_level", serverID: "ingredient_server_top_level")
        ]))
    }

    @Test("URLSession native sync transport skips malformed blank and identity id remaps")
    func urlSessionNativeSyncTransportSkipsMalformedBlankAndIdentityIDRemaps() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_recipe_missing_shape",
                        data: #"{ "created": true, "mutation": { "clientMutationId": "cm_recipe_missing_shape" } }"#
                    )
                )),
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_recipe_identity_shape",
                        data: """
                        {
                          "created": true,
                          "recipe": {
                            "id": "recipe_local_cm_recipe_identity",
                            "steps": [
                              { "id": " " },
                              "not-a-step-object",
                              {}
                            ]
                          }
                        }
                        """
                    )
                )),
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_step_missing_shape",
                        data: #"{ "created": true, "mutation": { "clientMutationId": "cm_step_missing_shape" } }"#
                    )
                )),
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_step_malformed_shape",
                        data: """
                        {
                          "created": true,
                          "step": {
                            "ingredients": [
                              { "id": "ingredient_server_valid", "name": "salt", "quantity": 1, "unit": "pinch" },
                              "not-an-ingredient-object",
                              {}
                            ]
                          }
                        }
                        """
                    )
                )),
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_ingredient_missing_shape",
                        data: #"{ "created": true, "ingredient": {} }"#
                    )
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let configuration = Self.configuration(bearerToken: "sj_access_native")
        let missingRecipe = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_recipe_missing_shape",
            title: "Missing shape",
            description: nil,
            servings: nil,
            steps: [],
            createdAt: "2026-06-16T12:03:00.000Z"
        )
        let identityRecipe = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_recipe_identity",
            title: "Identity shape",
            description: nil,
            servings: nil,
            steps: [
                RecipeStepDraft(stepNum: 1, stepTitle: "Prep", description: "Prep.", duration: nil, ingredients: [], outputStepNums: []),
                RecipeStepDraft(stepNum: 2, stepTitle: "Cook", description: "Cook.", duration: nil, ingredients: [], outputStepNums: []),
                RecipeStepDraft(stepNum: 3, stepTitle: "Serve", description: "Serve.", duration: nil, ingredients: [], outputStepNums: [])
            ],
            createdAt: "2026-06-16T12:04:00.000Z"
        )
        let missingStep = try NativeQueuedMutation.recipeStepCreate(
            recipeID: "recipe_server_created",
            clientMutationID: "cm_step_missing_shape",
            stepNum: 4,
            stepTitle: "Finish",
            description: "Finish.",
            duration: nil,
            ingredients: [
                RecipeIngredientDraft(quantity: 1, unit: "pinch", name: "salt"),
                RecipeIngredientDraft(quantity: 2, unit: "leaf", name: "basil"),
                RecipeIngredientDraft(quantity: 3, unit: "drop", name: "oil")
            ],
            outputStepNums: [],
            createdAt: "2026-06-16T12:05:00.000Z"
        )
        let malformedStep = try NativeQueuedMutation.recipeStepCreate(
            recipeID: "recipe_server_created",
            clientMutationID: "cm_step_malformed_shape",
            stepNum: 5,
            stepTitle: "Garnish",
            description: "Garnish.",
            duration: nil,
            ingredients: [
                RecipeIngredientDraft(quantity: 1, unit: "pinch", name: "salt"),
                RecipeIngredientDraft(quantity: 2, unit: "leaf", name: "basil"),
                RecipeIngredientDraft(quantity: 3, unit: "drop", name: "oil")
            ],
            outputStepNums: [],
            createdAt: "2026-06-16T12:05:30.000Z"
        )
        let malformedIngredient = try NativeQueuedMutation.recipeIngredientAdd(
            recipeID: "recipe_server_created",
            stepID: "step_server_created",
            clientMutationID: "cm_ingredient_missing_shape",
            quantity: 1,
            unit: "tbsp",
            name: "butter",
            createdAt: "2026-06-16T12:06:00.000Z"
        )

        #expect(try await transport.send(missingRecipe, configuration: configuration) == .success(serverRevision: nil, idRemaps: []))
        #expect(try await transport.send(identityRecipe, configuration: configuration) == .success(serverRevision: nil, idRemaps: []))
        #expect(try await transport.send(missingStep, configuration: configuration) == .success(serverRevision: nil, idRemaps: []))
        #expect(try await transport.send(malformedStep, configuration: configuration) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "ingredient_local_cm_step_malformed_shape_1", serverID: "ingredient_server_valid")
        ]))
        #expect(try await transport.send(malformedIngredient, configuration: configuration) == .success(serverRevision: nil, idRemaps: []))
    }

    @Test("URLSession native sync transport remaps only identifiable recipe create ingredients")
    func urlSessionNativeSyncTransportRemapsOnlyIdentifiableRecipeCreateIngredients() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 201,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(
                        requestID: "req_recipe_partial_remaps",
                        data: """
                        {
                          "created": true,
                          "recipe": {
                            "id": "recipe_server_decode",
                            "steps": [
                              {
                                "id": "step_server_nonobject",
                                "stepNum": 1,
                                "ingredients": [
                                  { "id": "ingredient_server_ignored", "name": "salt", "quantity": 1, "unit": "pinch" }
                                ]
                              },
                              {
                                "id": "step_server_matching",
                                "stepNum": 2,
                                "ingredients": [
                                  { "id": "ingredient_server_oil", "name": "oil", "quantity": 2, "unit": "tbsp" }
                                ]
                              },
                              {
                                "id": "step_server_extra",
                                "stepNum": 3,
                                "ingredients": [
                                  { "id": "ingredient_server_extra", "name": "extra", "quantity": 1, "unit": "pinch" }
                                ]
                              }
                            ]
                          },
                          "mutation": { "clientMutationId": "cm_decode", "replayed": false }
                        }
                        """
                    )
                ))
            ]
        )
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let mutation = try Self.decodedMutation(
            type: .recipeCreate,
            fields: [
                "title": "Decoded Recipe",
                "steps": [
                    "not-a-step-object",
                    [
                        "ingredients": [
                            ["name": "   ", "quantity": 1, "unit": "pinch"],
                            ["name": "salt", "unit": "pinch"],
                            ["ingredientName": "Oil", "quantity": 2, "unit": "TBSP"]
                        ]
                    ]
                ]
            ]
        )

        #expect(try await transport.send(mutation, configuration: Self.configuration(bearerToken: "sj_access_native")) == .success(serverRevision: nil, idRemaps: [
            NativeSyncIDRemap(localID: "recipe_local_cm_decode", serverID: "recipe_server_decode"),
            NativeSyncIDRemap(localID: "step_local_cm_decode_1", serverID: "step_server_nonobject"),
            NativeSyncIDRemap(localID: "step_local_cm_decode_2", serverID: "step_server_matching"),
            NativeSyncIDRemap(localID: "ingredient_local_cm_decode_2_3", serverID: "ingredient_server_oil")
        ]))
    }

    @Test("API error envelopes preserve request IDs details and retry decisions")
    func apiErrorEnvelopesPreserveRequestIDsDetailsAndRetryDecisions() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 429,
                    headers: ["Content-Type": "application/json", "Retry-After": "9"],
                    body: Self.errorEnvelope(
                        requestID: "req_rate_limited",
                        code: "rate_limited",
                        message: "Slow down",
                        status: 429,
                        details: #""retryAfterSeconds": 3, "limit": "write-mutations""#
                    )
                ))
            ]
        )
        let transport = URLSessionAPITransport(session: session)

        do {
            _ = try await transport.send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected rate-limited API response to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_rate_limited")
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: 9))
            #expect(error.apiError == APIError(
                requestID: "req_rate_limited",
                code: "rate_limited",
                message: "Slow down",
                status: 429,
                retryAfterSeconds: 9,
                details: [
                    "retryAfterSeconds": .number(3),
                    "limit": .string("write-mutations")
                ]
            ))
        }
    }

    @Test("ordinary server error envelopes preserve full API error fields")
    func ordinaryServerErrorEnvelopesPreserveFullAPIErrorFields() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 503,
                    headers: ["Content-Type": "application/json", "Retry-After": "7"],
                    body: Self.errorEnvelope(
                        requestID: "req_origin_down",
                        code: "database_unavailable",
                        message: "Try again soon",
                        status: 503,
                        details: #""region": "iad", "retryClass": "transient""#
                    )
                ))
            ]
        )
        let transport = URLSessionAPITransport(session: session)

        do {
            _ = try await transport.send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected server error envelope to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_origin_down")
            #expect(error.statusCode == 503)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: 7))
            #expect(error.apiError == APIError(
                requestID: "req_origin_down",
                code: "database_unavailable",
                message: "Try again soon",
                status: 503,
                retryAfterSeconds: 7,
                details: [
                    "region": .string("iad"),
                    "retryClass": .string("transient")
                ]
            ))
        }
    }

    @Test("HTTP failure status wins over successful JSON envelopes")
    func httpFailureStatusWinsOverSuccessfulJSONEnvelopes() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 503,
                    headers: ["Content-Type": "application/json", "Retry-After": "4"],
                    body: Self.successEnvelope(requestID: "req_false_success", name: "Not really ok")
                ))
            ]
        )
        let transport = URLSessionAPITransport(session: session)

        do {
            _ = try await transport.send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected non-2xx success envelope to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_false_success")
            #expect(error.statusCode == 503)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: 4))
            #expect(error.apiError == APIError(
                requestID: "req_false_success",
                code: "http_status_503",
                message: "HTTP 503 returned a successful API envelope.",
                status: 503,
                retryAfterSeconds: 4
            ))
        }
    }

    @Test("401 responses refresh configuration and replay authenticated requests once")
    func unauthorizedResponsesRefreshConfigurationAndReplayAuthenticatedRequestsOnce() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 401,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_expired_token",
                        code: "invalid_token",
                        message: "Refresh required",
                        status: 401
                    )
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(requestID: "req_after_refresh", name: "Fresh spoon")
                ))
            ]
        )
        let refresher = RecordingAuthenticationRefresher(
            refreshedConfiguration: Self.configuration(bearerToken: "sj_access_refreshed")
        )
        let transport = URLSessionAPITransport(session: session, authenticationRefresher: refresher)

        let replayedRequest = Self.privateMutationRequest()

        let envelope = try await transport.send(
            replayedRequest,
            configuration: Self.configuration(bearerToken: "sj_access_expired"),
            decode: TransportPayload.self
        )
        let requests = await session.capturedRequests()
        let refreshCalls = await refresher.capturedErrors()
        let firstRequest = try #require(requests.first)
        let secondRequest = try #require(requests.dropFirst().first)

        #expect(envelope.requestID == "req_after_refresh")
        #expect(envelope.data == TransportPayload(name: "Fresh spoon"))
        #expect(requests.count == 2)
        #expect(firstRequest.httpMethod == "POST")
        #expect(secondRequest.httpMethod == firstRequest.httpMethod)
        #expect(secondRequest.url == firstRequest.url)
        #expect(secondRequest.cachePolicy == firstRequest.cachePolicy)
        #expect(secondRequest.httpBody == firstRequest.httpBody)
        #expect(firstRequest.url?.absoluteString == "https://spoonjoy.app/api/v1/spoons?source=siri")
        #expect(firstRequest.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(firstRequest.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(secondRequest.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(firstRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(secondRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(firstRequest.value(forHTTPHeaderField: "X-Client-Mutation-Id") == "spoon-siri-1")
        #expect(secondRequest.value(forHTTPHeaderField: "X-Client-Mutation-Id") == "spoon-siri-1")
        #expect(firstRequest.value(forHTTPHeaderField: "Authorization") == "Bearer sj_access_expired")
        #expect(secondRequest.value(forHTTPHeaderField: "Authorization") == "Bearer sj_access_refreshed")
        #expect(refreshCalls == [
            APIError(
                requestID: "req_expired_token",
                code: "invalid_token",
                message: "Refresh required",
                status: 401
            )
        ])
    }

    @Test("a second 401 after refresh is surfaced instead of looping")
    func secondUnauthorizedResponseAfterRefreshIsSurfacedInsteadOfLooping() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 401,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_expired_token",
                        code: "invalid_token",
                        message: "Refresh required",
                        status: 401
                    )
                )),
                .success(Self.response(
                    statusCode: 401,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_still_invalid",
                        code: "invalid_token",
                        message: "Still invalid",
                        status: 401
                    )
                ))
            ]
        )
        let refresher = RecordingAuthenticationRefresher(
            refreshedConfiguration: Self.configuration(bearerToken: "sj_access_refreshed")
        )
        let transport = URLSessionAPITransport(session: session, authenticationRefresher: refresher)

        do {
            _ = try await transport.send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access_expired"),
                decode: TransportPayload.self
            )
            Issue.record("Expected second unauthorized response to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_still_invalid")
            #expect(error.retryDecision == .refreshAuthentication)
            #expect(error.apiError?.code == "invalid_token")
            #expect(await session.capturedRequests().count == 2)
            #expect(await refresher.capturedErrors().count == 1)
        }
    }

    @Test("bare and malformed 401 responses refresh and replay authenticated requests once")
    func bareAndMalformedUnauthorizedResponsesRefreshAndReplayOnce() async throws {
        let nonJSONSession = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 401,
                    headers: ["Content-Type": "text/plain", "X-Request-Id": "req_bare_auth"],
                    body: Data("expired".utf8)
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(requestID: "req_after_bare_refresh", name: "Bare refreshed")
                ))
            ]
        )
        let nonJSONRefresher = RecordingAuthenticationRefresher(
            refreshedConfiguration: Self.configuration(bearerToken: "sj_access_after_bare")
        )
        let nonJSONEnvelope = try await URLSessionAPITransport(
            session: nonJSONSession,
            authenticationRefresher: nonJSONRefresher
        )
        .send(
            Self.privateMutationRequest(),
            configuration: Self.configuration(bearerToken: "sj_access_expired"),
            decode: TransportPayload.self
        )
        let nonJSONRequests = await nonJSONSession.capturedRequests()
        let nonJSONRefreshErrors = await nonJSONRefresher.capturedErrors()

        #expect(nonJSONEnvelope.requestID == "req_after_bare_refresh")
        #expect(nonJSONRequests.count == 2)
        #expect(nonJSONRequests.map { $0.value(forHTTPHeaderField: "Authorization") } == [
            "Bearer sj_access_expired",
            "Bearer sj_access_after_bare"
        ])
        #expect(nonJSONRefreshErrors == [
            APIError(
                requestID: "req_bare_auth",
                code: "http_status_401",
                message: "HTTP 401 returned a non-JSON response.",
                status: 401
            )
        ])

        let malformedJSONSession = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 401,
                    headers: ["Content-Type": "application/json", "X-Request-Id": "req_malformed_auth"],
                    body: Data(#"{"ok": false,"#.utf8)
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(requestID: "req_after_malformed_refresh", name: "Malformed refreshed")
                ))
            ]
        )
        let malformedJSONRefresher = RecordingAuthenticationRefresher(
            refreshedConfiguration: Self.configuration(bearerToken: "sj_access_after_malformed")
        )
        let malformedJSONEnvelope = try await URLSessionAPITransport(
            session: malformedJSONSession,
            authenticationRefresher: malformedJSONRefresher
        )
        .send(
            Self.privateMutationRequest(),
            configuration: Self.configuration(bearerToken: "sj_access_expired"),
            decode: TransportPayload.self
        )
        let malformedJSONRequests = await malformedJSONSession.capturedRequests()
        let malformedJSONRefreshErrors = await malformedJSONRefresher.capturedErrors()

        #expect(malformedJSONEnvelope.requestID == "req_after_malformed_refresh")
        #expect(malformedJSONRequests.count == 2)
        #expect(malformedJSONRequests.map { $0.value(forHTTPHeaderField: "Authorization") } == [
            "Bearer sj_access_expired",
            "Bearer sj_access_after_malformed"
        ])
        #expect(malformedJSONRefreshErrors == [
            APIError(
                requestID: "req_malformed_auth",
                code: "http_status_401",
                message: "HTTP 401 returned a malformed JSON response.",
                status: 401
            )
        ])
    }

    @Test("non JSON and malformed JSON failures retain status and request id context")
    func nonJSONAndMalformedJSONFailuresRetainContext() async throws {
        let nonJSONSession = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 502,
                    headers: ["Content-Type": "text/html", "X-Request-Id": "req_edge_html"],
                    body: Data("<html>bad gateway</html>".utf8)
                ))
            ]
        )
        let malformedJSONSession = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json", "X-Request-Id": "req_bad_json"],
                    body: Data(#"{"ok": true, "requestId": "req_bad_json", "data":"#.utf8)
                ))
            ]
        )

        do {
            _ = try await URLSessionAPITransport(session: nonJSONSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected non-JSON response to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_edge_html")
            #expect(error.statusCode == 502)
            #expect(error.isNonJSONResponse)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: nil))
        }

        do {
            _ = try await URLSessionAPITransport(session: malformedJSONSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected malformed JSON response to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_bad_json")
            #expect(error.statusCode == 200)
            #expect(error.isMalformedJSONResponse)
            #expect(error.retryDecision == .doNotRetry)
        }
    }

    @Test("offline failures and cancellations are classified distinctly")
    func offlineFailuresAndCancellationsAreClassifiedDistinctly() async throws {
        let directOfflineSession = RecordingURLSession(responses: [.failure(URLError(.notConnectedToInternet))])
        let offlineSession = RecordingURLSession(responses: [.failure(URLError(.notConnectedToInternet))])
        let cancelledSession = RecordingURLSession(responses: [.failure(URLError(.cancelled))])
        let taskCancelledSession = RecordingURLSession(responses: [.failure(CancellationError())])

        do {
            _ = try await URLSessionAPITransport(session: directOfflineSession).send(
                try Self.privateReadRequest().urlRequest(configuration: Self.configuration(bearerToken: "sj_access")),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected direct offline URL error to throw")
        } catch let error as APITransportError {
            #expect(error.isOffline)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: nil))
            #expect(error.requestID == nil)
        }

        do {
            _ = try await URLSessionAPITransport(session: offlineSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected offline URL error to throw")
        } catch let error as APITransportError {
            #expect(error.isOffline)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: nil))
            #expect(error.requestID == nil)
        }

        do {
            _ = try await URLSessionAPITransport(session: cancelledSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected cancelled URL error to throw")
        } catch let error as APITransportError {
            #expect(error.isCancelled)
            #expect(error.retryDecision == .doNotRetry)
            #expect(error.requestID == nil)
        }

        do {
            _ = try await URLSessionAPITransport(session: taskCancelledSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected task cancellation to throw")
        } catch let error as APITransportError {
            #expect(error.isCancelled)
            #expect(error.retryDecision == .doNotRetry)
            #expect(error.requestID == nil)
        }
    }

    @Test("transport classifies non HTTP network and retry-after edge responses")
    func transportClassifiesNonHTTPNetworkAndRetryAfterEdgeResponses() async throws {
        let invalidURLSession = RecordingURLSession(
            responses: [.failure(TransportFixtureError.unexpectedRequest)]
        )
        do {
            _ = try await URLSessionAPITransport(session: invalidURLSession).send(
                Self.privateReadRequest(),
                configuration: APIClientConfiguration(
                    baseURL: URL(string: "mailto:spoonjoy")!,
                    bearerToken: "sj_access"
                ),
                decode: TransportPayload.self
            )
            Issue.record("Expected invalid base URL to throw")
        } catch let error as APITransportError {
            #expect(error.kind == .invalidRequestURL)
            #expect(error.retryDecision == .doNotRetry)
            #expect(await invalidURLSession.capturedRequests().isEmpty)
        }

        let nonHTTPSession = RecordingURLSession(
            responses: [
                .success((
                    Data("not http".utf8),
                    URLResponse(
                        url: URL(string: "https://spoonjoy.app/api/v1/shopping-list")!,
                        mimeType: nil,
                        expectedContentLength: 0,
                        textEncodingName: nil
                    )
                ))
            ]
        )
        do {
            _ = try await URLSessionAPITransport(session: nonHTTPSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected non-HTTP response to throw")
        } catch let error as APITransportError {
            #expect(error.kind == .nonHTTPResponse)
            #expect(error.retryDecision == .doNotRetry)
        }

        let arbitraryFailureSession = RecordingURLSession(responses: [.failure(TransportFixtureError.boom)])
        do {
            _ = try await URLSessionAPITransport(session: arbitraryFailureSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected arbitrary network failure to throw")
        } catch let error as APITransportError {
            #expect(error.kind == .networkFailure)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: nil))
        }

        let urlFallbackFailureSession = RecordingURLSession(responses: [.failure(URLError(.badServerResponse))])
        do {
            _ = try await URLSessionAPITransport(session: urlFallbackFailureSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected non-offline URL failure to throw")
        } catch let error as APITransportError {
            #expect(error.kind == .networkFailure)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: nil))
        }

        let noContentTypeRateLimit = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 429,
                    headers: ["Retry-After": "5", "X-Request-Id": "req_missing_content_type"],
                    body: Data("rate limited".utf8)
                ))
            ]
        )
        do {
            _ = try await URLSessionAPITransport(session: noContentTypeRateLimit).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected missing content-type 429 to throw")
        } catch let error as APITransportError {
            #expect(error.kind == .nonJSONResponse)
            #expect(error.requestID == "req_missing_content_type")
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: 5))
        }

        let httpDateRetryAfter = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 503,
                    headers: [
                        "Content-Type": "text/plain",
                        "Retry-After": "Wed, 31 Dec 2099 23:59:59 GMT"
                    ],
                    body: Data("try later".utf8)
                ))
            ]
        )
        do {
            _ = try await URLSessionAPITransport(session: httpDateRetryAfter).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected HTTP-date retry-after response to throw")
        } catch let error as APITransportError {
            if case .retrySameRequest(let afterSeconds) = error.retryDecision {
                #expect((afterSeconds ?? 0) > 0)
            } else {
                Issue.record("Expected retry decision for HTTP-date Retry-After")
            }
        }

        let invalidRetryAfter = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 503,
                    headers: ["Content-Type": "text/plain", "Retry-After": "eventually"],
                    body: Data("try later".utf8)
                ))
            ]
        )
        do {
            _ = try await URLSessionAPITransport(session: invalidRetryAfter).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected invalid retry-after response to throw")
        } catch let error as APITransportError {
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: nil))
        }
    }

    private static func privateReadRequest() -> APIRequestBuilder {
        APIRequestBuilder(
            method: .get,
            pathComponents: ["api", "v1", "shopping-list"],
            queryItems: [],
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: .privateNoStore
        )
    }

    private static func privateMutationRequest() -> APIRequestBuilder {
        APIRequestBuilder(
            method: .post,
            pathComponents: ["api", "v1", "spoons"],
            queryItems: [URLQueryItem(name: "source", value: "siri")],
            headers: [
                "Content-Type": "application/json",
                "X-Client-Mutation-Id": "spoon-siri-1"
            ],
            body: Data(#"{"recipeId":"recipe_lemon","spooned":true}"#.utf8),
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: .privateNoStore
        )
    }

    private static func configuration(bearerToken: String) -> APIClientConfiguration {
        APIClientConfiguration(
            baseURL: URL(string: "https://spoonjoy.app")!,
            bearerToken: bearerToken
        )
    }

    private static func response(
        statusCode: Int,
        headers: [String: String],
        body: Data
    ) -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: URL(string: "https://spoonjoy.app/api/v1/shopping-list")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (body, response)
    }

    private static func successEnvelope(requestID: String, name: String) -> Data {
        successEnvelope(requestID: requestID, data: #"{ "name": "\#(name)" }"#)
    }

    private static func successEnvelope(requestID: String, data: String) -> Data {
        Data(
            """
            {
              "ok": true,
              "requestId": "\(requestID)",
              "data": \(data)
            }
            """.utf8
        )
    }

    private static func nativeSyncEnvelope(requestID: String, resourceID: String, nextCursor: String) -> Data {
        Data(
            """
            {
              "ok": true,
              "requestId": "\(requestID)",
              "data": {
                "freshness": {
                  "accountId": "chef_ari",
                  "environment": "production",
                  "schemaVersion": 1,
                  "sourceEndpoint": "/api/v1/me/sync",
                  "generatedAt": "2026-06-16T12:00:00.000Z",
                  "lastValidatedAt": "2026-06-16T12:00:00.000Z"
                },
                "entries": [
                  {
                    "action": "upsert",
                    "kind": "profile",
                    "resourceId": "\(resourceID)",
                    "updatedAt": "2026-06-16T12:00:00.000Z",
                    "payload": { "username": "ari" },
                    "tombstone": null
                  }
                ],
                "nextCursor": "\(nextCursor)",
                "hasMore": false
              }
            }
            """.utf8
        )
    }

    private static func recipeImportProviderSecretBlockerEnvelope(requestID: String) -> Data {
        successEnvelope(
            requestID: requestID,
            data: """
            {
              "recipe": null,
              "importCode": "provider_secret_required",
              "blockers": [
                {
                  "capability": "ProviderSecret",
                  "provider": "openai",
                  "resource": "recipe-import"
                }
              ]
            }
            """
        )
    }

    private static func recipeImportAcceptedEnvelope(requestID: String) -> Data {
        successEnvelope(
            requestID: requestID,
            data: """
            {
              "recipe": null,
              "importCode": "accepted",
              "blockers": [
                {
                  "capability": "AlreadyHandled",
                  "resource": "ignored"
                }
              ]
            }
            """
        )
    }

    private static func errorEnvelope(
        requestID: String,
        code: String,
        message: String,
        status: Int,
        details: String? = nil
    ) -> Data {
        let detailsObject = details.map { ", \"details\": { \($0) }" } ?? ""
        return Data(
            """
            {
              "ok": false,
              "requestId": "\(requestID)",
              "error": {
                "code": "\(code)",
                "message": "\(message)",
                "status": \(status)\(detailsObject)
              }
            }
            """.utf8
        )
    }

    private static func decodedMutation(type: NativeQueuedMutationKind, fields: [String: Any]) throws -> NativeQueuedMutation {
        var kind = fields
        kind["type"] = type.rawValue
        return try JSONDecoder().decode(
            NativeQueuedMutation.self,
            from: JSONSerialization.data(withJSONObject: [
                "schemaVersion": 1,
                "id": "native:cm_decode",
                "clientMutationId": "cm_decode",
                "createdAt": "2026-06-16T12:00:00.000Z",
                "retryCount": 0,
                "kind": kind
            ])
        )
    }
}

private struct TransportPayload: Decodable, Equatable, Sendable {
    let name: String
}

private enum TransportFixtureError: Error {
    case boom
    case unexpectedRequest
}

private actor RecordingURLSession: URLSessionPerforming {
    private var responses: [Result<(Data, URLResponse), Error>]
    private var requests: [URLRequest] = []

    init(responses: [Result<(Data, URLResponse), Error>]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }

        let response = responses.removeFirst()
        return try response.get()
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }
}

private actor RecordingAuthenticationRefresher: APIAuthenticationRefresher {
    private let refreshedConfiguration: APIClientConfiguration
    private var errors: [APIError] = []

    init(refreshedConfiguration: APIClientConfiguration) {
        self.refreshedConfiguration = refreshedConfiguration
    }

    func refreshedConfiguration(
        after error: APIError,
        configuration: APIClientConfiguration
    ) async throws -> APIClientConfiguration {
        errors.append(error)
        #expect(configuration.bearerToken == "sj_access_expired")
        return refreshedConfiguration
    }

    func capturedErrors() -> [APIError] {
        errors
    }
}
