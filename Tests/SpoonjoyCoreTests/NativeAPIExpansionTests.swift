import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native expanded REST v1 request builders")
struct NativeAPIExpansionTests {
    @Test("discovery and generated contract requests are anonymous exact GETs")
    func discoveryAndGeneratedContractRequestsAreAnonymousExactGETs() throws {
        let root = try APIDiscoveryRequests.root()
            .urlRequest(configuration: Self.privateConfiguration)
        let health = try APIDiscoveryRequests.health()
            .urlRequest(configuration: Self.privateConfiguration)
        let openAPI = try APIDiscoveryRequests.openAPI()
            .urlRequest(configuration: Self.privateConfiguration)
        let sdkOpenAPI = try APIDiscoveryRequests.sdkOpenAPI()
            .urlRequest(configuration: Self.privateConfiguration)
        let connectorOpenAPI = try APIDiscoveryRequests.connectorOpenAPI()
            .urlRequest(configuration: Self.privateConfiguration)
        let docsHandoffURL = try APIDiscoveryRequests.docsHandoffURL(baseURL: Self.privateConfiguration.baseURL)
        let loopbackDocsHandoffURL = try APIDiscoveryRequests.docsHandoffURL(
            baseURL: URL(string: "http://[::1]:8080/from/oauth?code=abc#callback")!
        )
        let discovery = try APIEnvelope<APIDiscoveryResponse>.decode(Self.discoveryEnvelope)

        assertRequest(root, method: .get, path: "/api/v1", authorization: nil)
        assertRequest(health, method: .get, path: "/api/v1/health", authorization: nil)
        assertRequest(openAPI, method: .get, path: "/api/v1/openapi.json", authorization: nil)
        assertRequest(sdkOpenAPI, method: .get, path: "/api/v1/openapi.sdk.json", authorization: nil)
        assertRequest(connectorOpenAPI, method: .get, path: "/api/v1/openapi.connector.json", authorization: nil)
        #expect(docsHandoffURL.absoluteString == "https://spoonjoy.app/api")
        #expect(loopbackDocsHandoffURL.absoluteString == "http://[::1]:8080/api")
        #expect(throws: APIRequestBuildError.self) {
            _ = try APIDiscoveryRequests.docsHandoffURL(
                baseURL: URL(dataRepresentation: Data("http://[::1".utf8), relativeTo: nil)!
            )
        }
        #expect(discovery.data.docsURL.absoluteString == "https://spoonjoy.app/api")
        #expect(discovery.data.openAPIPath == "/api/v1/openapi.json")
        #expect(discovery.data.sdkOpenAPIPath == "/api/v1/openapi.sdk.json")
        #expect(discovery.data.connectorOpenAPIPath == "/api/v1/openapi.connector.json")
        #expect(root.body == nil)
        #expect(health.body == nil)
        #expect(openAPI.body == nil)
        #expect(sdkOpenAPI.body == nil)
        #expect(connectorOpenAPI.body == nil)
    }

    @Test("public catalog reads stay anonymous by default and carry public cache policy")
    func publicCatalogReadsStayAnonymousByDefaultAndCarryPublicCachePolicy() throws {
        let recipeList = try PublicCatalogRequests.listRecipes(
            query: "lemon pasta",
            limit: 20,
            cursor: PaginationCursor(rawValue: "v1.recipe.cursor")
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let recipeDetail = try PublicCatalogRequests.recipeDetail(id: "recipe/lemon")
            .urlRequest(configuration: Self.privateConfiguration)
        let cookbookList = try PublicCatalogRequests.listCookbooks(
            query: "weeknight",
            limit: 15,
            cursor: PaginationCursor(rawValue: "v1.cookbook.cursor")
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let cookbookDetail = try PublicCatalogRequests.cookbookDetail(id: "cookbook/week")
            .urlRequest(configuration: Self.privateConfiguration)

        assertRequest(
            recipeList,
            method: .get,
            path: "/api/v1/recipes",
            authorization: nil,
            queryItems: [
                URLQueryItem(name: "query", value: "lemon pasta"),
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "cursor", value: "v1.recipe.cursor")
            ],
            responseCachePolicy: .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300)
        )
        assertRequest(
            recipeDetail,
            method: .get,
            path: "/api/v1/recipes/recipe%2Flemon",
            authorization: nil,
            responseCachePolicy: .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300)
        )
        assertRequest(
            cookbookList,
            method: .get,
            path: "/api/v1/cookbooks",
            authorization: nil,
            queryItems: [
                URLQueryItem(name: "query", value: "weeknight"),
                URLQueryItem(name: "limit", value: "15"),
                URLQueryItem(name: "cursor", value: "v1.cookbook.cursor")
            ],
            responseCachePolicy: .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300)
        )
        assertRequest(
            cookbookDetail,
            method: .get,
            path: "/api/v1/cookbooks/cookbook%2Fweek",
            authorization: nil,
            responseCachePolicy: .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300)
        )
        #expect(recipeList.body == nil)
        #expect(recipeDetail.body == nil)
        #expect(cookbookList.body == nil)
        #expect(cookbookDetail.body == nil)
    }

    @Test("private account sync token and APNs requests use bearer auth and exact paths")
    func privateAccountSyncTokenAndAPNSRequestsUseBearerAuthAndExactPaths() throws {
        let currentAccount = try PrivateAccountRequests.currentAccount()
            .urlRequest(configuration: Self.privateConfiguration)
        let kitchen = try PrivateAccountRequests.kitchen()
            .urlRequest(configuration: Self.privateConfiguration)
        let notificationPreferences = try PrivateAccountRequests.notificationPreferences()
            .urlRequest(configuration: Self.privateConfiguration)
        let connections = try PrivateAccountRequests.connections()
            .urlRequest(configuration: Self.privateConfiguration)
        let sync = try PrivateSyncRequests.sync(
            cursor: PaginationCursor(rawValue: "v1.native.cursor"),
            limit: 75
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let listTokens = try TokenCredentialRequests.listTokens()
            .urlRequest(configuration: Self.privateConfiguration)
        let revokeToken = try TokenCredentialRequests.revokeToken(credentialID: "cred/with spaces")
            .urlRequest(configuration: Self.privateConfiguration)
        let revokeAPNS = try PrivateAccountRequests.revokeAPNSDevice(deviceID: "device/ios 1")
            .urlRequest(configuration: Self.privateConfiguration)
        let disconnect = try PrivateAccountRequests.disconnectConnection(connectionID: "oauth/cm client")
            .urlRequest(configuration: Self.privateConfiguration)

        assertRequest(currentAccount, method: .get, path: "/api/v1/me", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        assertRequest(kitchen, method: .get, path: "/api/v1/me/kitchen", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        assertRequest(notificationPreferences, method: .get, path: "/api/v1/me/notification-preferences", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        assertRequest(connections, method: .get, path: "/api/v1/me/connections", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        assertRequest(
            sync,
            method: .get,
            path: "/api/v1/me/sync",
            authorization: "Bearer sj_private_token",
            queryItems: [
                URLQueryItem(name: "limit", value: "75"),
                URLQueryItem(name: "cursor", value: "v1.native.cursor")
            ],
            responseCachePolicy: .privateNoStore
        )
        assertRequest(listTokens, method: .get, path: "/api/v1/tokens", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        assertRequest(revokeToken, method: .delete, path: "/api/v1/tokens/cred%2Fwith%20spaces", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        assertRequest(revokeAPNS, method: .delete, path: "/api/v1/me/apns-devices/device%2Fios%201", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        assertRequest(disconnect, method: .delete, path: "/api/v1/me/connections/oauth%2Fcm%20client", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        #expect(currentAccount.body == nil)
        #expect(kitchen.body == nil)
        #expect(notificationPreferences.body == nil)
        #expect(connections.body == nil)
        #expect(sync.body == nil)
        #expect(listTokens.body == nil)
        #expect(revokeToken.body == nil)
        #expect(revokeAPNS.body == nil)
        #expect(disconnect.body == nil)
    }

    @Test("profile notification token and APNs mutations encode JSON or multipart bodies")
    func profileNotificationTokenAndAPNSMutationsEncodeExpectedBodies() throws {
        let updateProfile = try PrivateAccountRequests.updateProfile(
            email: "ari@example.com",
            username: "ari"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let uploadPhoto = try PrivateAccountRequests.uploadProfilePhoto(
            photo: UploadFile(
                fileName: "profile.jpg",
                contentType: "image/jpeg",
                data: Data([0xFF, 0xD8, 0xFF])
            )
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let removePhoto = try PrivateAccountRequests.removeProfilePhoto()
            .urlRequest(configuration: Self.privateConfiguration)
        let updateNotifications = try PrivateAccountRequests.updateNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let registerAPNS = try PrivateAccountRequests.registerAPNSDevice(
            deviceID: "ios-device-1",
            platform: NativeAPNSPlatform.ios,
            environment: APNSEnvironment.development,
            token: "apns-token-value",
            deviceName: "Ari's iPhone",
            appVersion: "1.0.0"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let createToken = try TokenCredentialRequests.createToken(
            name: "Kitchen display",
            scopes: ["shopping_list:read", "shopping_list:write"]
        )
        .urlRequest(configuration: Self.privateConfiguration)

        assertJSONRequest(updateProfile, method: .patch, path: "/api/v1/me", expected: [
            "email": "ari@example.com",
            "username": "ari"
        ])
        try assertMultipartRequest(
            uploadPhoto,
            method: .post,
            path: "/api/v1/me/photo",
            fileField: "photo",
            fileName: "profile.jpg",
            contentType: "image/jpeg",
            data: Data([0xFF, 0xD8, 0xFF])
        )
        assertRequest(removePhoto, method: .delete, path: "/api/v1/me/photo", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        #expect(removePhoto.body == nil)
        assertJSONRequest(updateNotifications, method: .patch, path: "/api/v1/me/notification-preferences", expected: [
            "notifySpoonOnMyRecipe": true,
            "notifyForkOfMyRecipe": false,
            "notifyCookbookSaveOfMine": true,
            "notifyFellowChefOriginCook": false
        ])
        assertJSONRequest(registerAPNS, method: .post, path: "/api/v1/me/apns-devices", expected: [
            "deviceId": "ios-device-1",
            "platform": "ios",
            "environment": "development",
            "token": "apns-token-value",
            "deviceName": "Ari's iPhone",
            "appVersion": "1.0.0"
        ])
        assertJSONRequest(createToken, method: .post, path: "/api/v1/tokens", expected: [
            "name": "Kitchen display",
            "scopes": ["shopping_list:read", "shopping_list:write"]
        ])
    }

    @Test("multipart builders reject unsafe header values and use unique boundaries")
    func multipartBuildersRejectUnsafeHeaderValuesAndUseUniqueBoundaries() throws {
        let photo = UploadFile(
            fileName: "profile.jpg",
            contentType: "image/jpeg",
            data: Data([0xFF, 0xD8, 0xFF])
        )
        let first = try PrivateAccountRequests.uploadProfilePhoto(photo: photo)
            .urlRequest(configuration: Self.privateConfiguration)
        let second = try PrivateAccountRequests.uploadProfilePhoto(photo: photo)
            .urlRequest(configuration: Self.privateConfiguration)

        let firstContentType = try #require(first.headers["Content-Type"])
        let secondContentType = try #require(second.headers["Content-Type"])
        #expect(firstContentType.hasPrefix("multipart/form-data; boundary="))
        #expect(secondContentType.hasPrefix("multipart/form-data; boundary="))
        #expect(firstContentType != secondContentType)
        try assertMultipartRequest(
            first,
            method: .post,
            path: "/api/v1/me/photo",
            fileField: "photo",
            fileName: "profile.jpg",
            contentType: "image/jpeg",
            data: Data([0xFF, 0xD8, 0xFF])
        )

        #expect(throws: APIRequestBuildError.self) {
            _ = try PrivateAccountRequests.uploadProfilePhoto(
                photo: UploadFile(
                    fileName: "profile\"\r\nX-Injected: true.jpg",
                    contentType: "image/jpeg",
                    data: Data([0xFF])
                )
            )
        }
        #expect(throws: APIRequestBuildError.self) {
            _ = try PrivateAccountRequests.uploadProfilePhoto(
                photo: UploadFile(
                    fileName: "profile.jpg",
                    contentType: "image/jpeg\r\nX-Injected: true",
                    data: Data([0xFF])
                )
            )
        }
    }

    @Test("optional public profile and search requests omit bearer by default but can include it")
    func optionalPublicProfileAndSearchRequestsOmitBearerByDefaultButCanIncludeIt() throws {
        let anonymousProfile = try PublicProfileRequests.profile(identifier: "ari/space")
            .urlRequest(configuration: Self.privateConfiguration)
        let visitors = try PublicProfileRequests.kitchenVisitors(identifier: "ari", page: 2, limit: 30)
            .urlRequest(configuration: Self.privateConfiguration)
        let fellowChefs = try PublicProfileRequests.fellowChefs(identifier: "ari", page: 3, limit: 15)
            .urlRequest(configuration: Self.privateConfiguration, authorization: APIAuthorizationPolicy.includeBearerToken)
        let search = try SearchRequests.search(
            query: "lemon pasta",
            scope: SearchScope.shoppingList,
            limit: 12
        )
        .urlRequest(configuration: Self.privateConfiguration, authorization: APIAuthorizationPolicy.includeBearerToken)

        assertRequest(anonymousProfile, method: .get, path: "/api/v1/users/ari%2Fspace", authorization: nil, responseCachePolicy: .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300))
        assertRequest(
            visitors,
            method: .get,
            path: "/api/v1/users/ari/kitchen-visitors",
            authorization: nil,
            queryItems: [
                URLQueryItem(name: "page", value: "2"),
                URLQueryItem(name: "limit", value: "30")
            ],
            responseCachePolicy: .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300)
        )
        assertRequest(
            fellowChefs,
            method: .get,
            path: "/api/v1/users/ari/fellow-chefs",
            authorization: "Bearer sj_private_token",
            queryItems: [
                URLQueryItem(name: "page", value: "3"),
                URLQueryItem(name: "limit", value: "15")
            ],
            responseCachePolicy: .privateNoStore
        )
        assertRequest(
            search,
            method: .get,
            path: "/api/v1/search",
            authorization: "Bearer sj_private_token",
            queryItems: [
                URLQueryItem(name: "q", value: "lemon pasta"),
                URLQueryItem(name: "scope", value: "shopping-list"),
                URLQueryItem(name: "limit", value: "12")
            ],
            responseCachePolicy: .privateNoStore
        )
        #expect(anonymousProfile.body == nil)
        #expect(visitors.body == nil)
        #expect(fellowChefs.body == nil)
        #expect(search.body == nil)
    }

    @Test("recipe write and step builders encode idempotent JSON and delete fallback forms")
    func recipeWriteAndStepBuildersEncodeIdempotentJSONAndDeleteFallbackForms() throws {
        let createRecipe = try RecipeWriteRequests.createRecipe(
            clientMutationID: "recipe-create-1",
            title: "Lemon Pasta",
            description: "Bright pantry pasta",
            servings: "4",
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: Optional<String>.none,
                    description: "Boil pasta.",
                    duration: 10,
                    ingredients: [
                        RecipeIngredientDraft(quantity: 1, unit: "lb", name: "pasta")
                    ],
                    outputStepNums: []
                )
            ]
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let updateRecipe = try RecipeWriteRequests.updateRecipe(
            id: "recipe/one",
            clientMutationID: "recipe-update-1",
            title: "Lemon Pasta Plus",
            description: Optional<String>.none,
            servings: "6"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let deleteRecipe = try RecipeWriteRequests.deleteRecipe(
            id: "recipe/one",
            clientMutationID: "recipe-delete-1",
            idempotency: MutationIdempotency.query
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let forkRecipe = try RecipeWriteRequests.forkRecipe(
            id: "recipe/one",
            clientMutationID: "recipe-fork-1",
            titleOverride: "My Lemon Pasta"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let createStep = try RecipeStepRequests.createStep(
            recipeID: "recipe/one",
            clientMutationID: "step-create-1",
            stepNum: 2,
            stepTitle: "Sauce",
            description: "Toss everything.",
            duration: 3,
            ingredients: [],
            outputStepNums: [1]
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let updateStep = try RecipeStepRequests.updateStep(
            recipeID: "recipe/one",
            stepID: "step/two",
            clientMutationID: "step-update-1",
            stepTitle: Optional<String>.none,
            description: "Toss until glossy.",
            duration: Optional<Int>.none,
            outputStepNums: [1]
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let deleteStep = try RecipeStepRequests.deleteStep(
            recipeID: "recipe/one",
            stepID: "step/two",
            clientMutationID: "step-delete-1",
            idempotency: MutationIdempotency.body
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let reorderStep = try RecipeStepRequests.reorderStep(
            recipeID: "recipe/one",
            clientMutationID: "step-reorder-1",
            stepID: "step/two",
            toStepNum: 1
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let createIngredient = try RecipeStepRequests.createIngredient(
            recipeID: "recipe/one",
            stepID: "step/two",
            clientMutationID: "ingredient-create-1",
            quantity: 2,
            unit: "cloves",
            name: "garlic"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let deleteIngredient = try RecipeStepRequests.deleteIngredient(
            recipeID: "recipe/one",
            stepID: "step/two",
            ingredientID: "ingredient/garlic",
            clientMutationID: "ingredient-delete-1",
            idempotency: MutationIdempotency.header
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let replaceOutputUses = try RecipeStepRequests.replaceOutputUses(
            recipeID: "recipe/one",
            clientMutationID: "step-output-1",
            inputStepID: "step/two",
            outputStepNums: [1, 3]
        )
        .urlRequest(configuration: Self.privateConfiguration)

        assertJSONRequest(createRecipe, method: .post, path: "/api/v1/recipes", expected: [
            "clientMutationId": "recipe-create-1",
            "title": "Lemon Pasta",
            "description": "Bright pantry pasta",
            "servings": "4",
            "steps": [[
                "stepNum": 1,
                "stepTitle": NSNull(),
                "description": "Boil pasta.",
                "duration": 10,
                "ingredients": [[
                    "quantity": 1,
                    "unit": "lb",
                    "name": "pasta"
                ]],
                "outputStepNums": []
            ]]
        ])
        assertJSONRequest(updateRecipe, method: .patch, path: "/api/v1/recipes/recipe%2Fone", expected: [
            "clientMutationId": "recipe-update-1",
            "title": "Lemon Pasta Plus",
            "description": NSNull(),
            "servings": "6"
        ])
        assertRequest(
            deleteRecipe,
            method: .delete,
            path: "/api/v1/recipes/recipe%2Fone",
            authorization: "Bearer sj_private_token",
            queryItems: [URLQueryItem(name: "clientMutationId", value: "recipe-delete-1")],
            responseCachePolicy: .privateNoStore
        )
        #expect(deleteRecipe.body == nil)
        assertJSONRequest(forkRecipe, method: .post, path: "/api/v1/recipes/recipe%2Fone/fork", expected: [
            "clientMutationId": "recipe-fork-1",
            "title": "My Lemon Pasta"
        ])
        assertJSONRequest(createStep, method: .post, path: "/api/v1/recipes/recipe%2Fone/steps", expected: [
            "clientMutationId": "step-create-1",
            "stepNum": 2,
            "stepTitle": "Sauce",
            "description": "Toss everything.",
            "duration": 3,
            "ingredients": [],
            "outputStepNums": [1]
        ])
        assertJSONRequest(updateStep, method: .patch, path: "/api/v1/recipes/recipe%2Fone/steps/step%2Ftwo", expected: [
            "clientMutationId": "step-update-1",
            "stepTitle": NSNull(),
            "description": "Toss until glossy.",
            "duration": NSNull(),
            "outputStepNums": [1]
        ])
        assertJSONRequest(deleteStep, method: .delete, path: "/api/v1/recipes/recipe%2Fone/steps/step%2Ftwo", expected: [
            "clientMutationId": "step-delete-1"
        ])
        assertJSONRequest(reorderStep, method: .post, path: "/api/v1/recipes/recipe%2Fone/steps/reorder", expected: [
            "clientMutationId": "step-reorder-1",
            "stepId": "step/two",
            "toStepNum": 1
        ])
        assertJSONRequest(createIngredient, method: .post, path: "/api/v1/recipes/recipe%2Fone/steps/step%2Ftwo/ingredients", expected: [
            "clientMutationId": "ingredient-create-1",
            "quantity": 2,
            "unit": "cloves",
            "name": "garlic"
        ])
        assertRequest(
            deleteIngredient,
            method: .delete,
            path: "/api/v1/recipes/recipe%2Fone/steps/step%2Ftwo/ingredients/ingredient%2Fgarlic",
            authorization: "Bearer sj_private_token",
            extraHeaders: ["X-Client-Mutation-Id": "ingredient-delete-1"],
            responseCachePolicy: .privateNoStore
        )
        #expect(deleteIngredient.headers["X-Client-Mutation-Id"] == "ingredient-delete-1")
        #expect(deleteIngredient.body == nil)
        assertJSONRequest(replaceOutputUses, method: .put, path: "/api/v1/recipes/recipe%2Fone/step-output-uses", expected: [
            "clientMutationId": "step-output-1",
            "inputStepId": "step/two",
            "outputStepNums": [1, 3]
        ])
    }

    @Test("recipe cover and spoon builders cover multipart JSON and optional public list auth")
    func recipeCoverAndSpoonBuildersCoverMultipartJSONAndOptionalPublicListAuth() throws {
        let coverUpload = try RecipeCoverRequests.uploadImage(
            recipeID: "recipe/one",
            image: UploadFile(fileName: "cover.png", contentType: "image/png", data: Data([0x89, 0x50, 0x4E, 0x47])),
            clientMutationID: "cover-upload-1",
            activate: true,
            generateEditorial: false
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let coverList = try RecipeCoverRequests.listCovers(
            recipeID: "recipe/one",
            includeArchived: true,
            limit: 40,
            offset: 20
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let createCover = try RecipeCoverRequests.createFromImageURL(
            recipeID: "recipe/one",
            clientMutationID: "cover-url-1",
            imageURL: "/photos/recipes/chef_1/uploads/raw.png",
            activate: false,
            generateEditorial: true
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let activateCover = try RecipeCoverRequests.activate(
            recipeID: "recipe/one",
            coverID: "cover/raw",
            clientMutationID: "cover-activate-1",
            variant: RecipeCoverAPIVariant.stylized
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let archiveCover = try RecipeCoverRequests.archive(
            recipeID: "recipe/one",
            coverID: "cover/raw",
            clientMutationID: "cover-archive-1",
            replacementCoverID: "cover/replacement",
            replacementVariant: RecipeCoverAPIVariant.image,
            confirmNoCover: false,
            deleteSafeObjects: true,
            idempotency: MutationIdempotency.query
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let regenerate = try RecipeCoverRequests.regenerate(
            recipeID: "recipe/one",
            clientMutationID: "cover-regen-1",
            coverID: "cover/editorial",
            activateWhenReady: true
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let fromSpoon = try RecipeCoverRequests.createFromSpoon(
            recipeID: "recipe/one",
            spoonID: "spoon/cooked",
            clientMutationID: "cover-spoon-1",
            activate: true,
            generateEditorial: true
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let spoonList = try RecipeSpoonRequests.listSpoons(
            recipeID: "recipe/one",
            cursor: PaginationCursor(rawValue: "spoon.cursor"),
            limit: 20
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let spoonCreate = try RecipeSpoonRequests.createSpoon(
            recipeID: "recipe/one",
            clientMutationID: "spoon-create-1",
            note: "Loved it.",
            nextTime: Optional<String>.none,
            cookedAt: "2026-06-24T18:00:00.000Z",
            photoURL: "/photos/spoons/chef_1/recipe_1/cooked.jpg",
            useAsRecipeCover: true
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let spoonPhotoCreate = try RecipeSpoonRequests.createSpoon(
            recipeID: "recipe/one",
            photo: UploadFile(fileName: "spoon.webp", contentType: "image/webp", data: Data([0x52, 0x49, 0x46, 0x46])),
            clientMutationID: "spoon-photo-1",
            note: "Photo cook.",
            nextTime: "more lemon",
            cookedAt: Optional<String>.none,
            useAsRecipeCover: false
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let spoonUpdate = try RecipeSpoonRequests.updateSpoon(
            recipeID: "recipe/one",
            spoonID: "spoon/cooked",
            clientMutationID: "spoon-update-1",
            note: Optional<String>.none,
            nextTime: "more lemon",
            cookedAt: "2026-06-24T19:00:00.000Z",
            photoURL: "/photos/spoons/chef_1/recipe_1/updated.jpg"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let spoonDelete = try RecipeSpoonRequests.deleteSpoon(
            recipeID: "recipe/one",
            spoonID: "spoon/cooked",
            clientMutationID: "spoon-delete-1",
            idempotency: MutationIdempotency.header
        )
        .urlRequest(configuration: Self.privateConfiguration)

        try assertMultipartRequest(
            coverUpload,
            method: .post,
            path: "/api/v1/recipes/recipe%2Fone/image",
            fileField: "image",
            fileName: "cover.png",
            contentType: "image/png",
            data: Data([0x89, 0x50, 0x4E, 0x47]),
            fields: [
                "clientMutationId": "cover-upload-1",
                "activate": "true",
                "generateEditorial": "false"
            ]
        )
        assertRequest(
            coverList,
            method: .get,
            path: "/api/v1/recipes/recipe%2Fone/covers",
            authorization: "Bearer sj_private_token",
            queryItems: [
                URLQueryItem(name: "includeArchived", value: "true"),
                URLQueryItem(name: "limit", value: "40"),
                URLQueryItem(name: "offset", value: "20")
            ],
            responseCachePolicy: .privateNoStore
        )
        assertJSONRequest(createCover, method: .post, path: "/api/v1/recipes/recipe%2Fone/covers", expected: [
            "clientMutationId": "cover-url-1",
            "imageUrl": "/photos/recipes/chef_1/uploads/raw.png",
            "activate": false,
            "generateEditorial": true
        ])
        assertJSONRequest(activateCover, method: .patch, path: "/api/v1/recipes/recipe%2Fone/covers/cover%2Fraw", expected: [
            "clientMutationId": "cover-activate-1",
            "variant": "stylized"
        ])
        assertRequest(
            archiveCover,
            method: .delete,
            path: "/api/v1/recipes/recipe%2Fone/covers/cover%2Fraw",
            authorization: "Bearer sj_private_token",
            extraHeaders: ["Content-Type": "application/json"],
            queryItems: [URLQueryItem(name: "clientMutationId", value: "cover-archive-1")],
            expectsBody: true,
            responseCachePolicy: .privateNoStore
        )
        #expect(NSDictionary(dictionary: try jsonBody(from: archiveCover)).isEqual(to: [
            "replacementCoverId": "cover/replacement",
            "replacementVariant": "image",
            "confirmNoCover": false,
            "deleteSafeObjects": true
        ]))
        assertJSONRequest(regenerate, method: .post, path: "/api/v1/recipes/recipe%2Fone/covers/regenerate", expected: [
            "clientMutationId": "cover-regen-1",
            "coverId": "cover/editorial",
            "activateWhenReady": true
        ])
        assertJSONRequest(fromSpoon, method: .post, path: "/api/v1/recipes/recipe%2Fone/covers/from-spoon/spoon%2Fcooked", expected: [
            "clientMutationId": "cover-spoon-1",
            "activate": true,
            "generateEditorial": true
        ])
        assertRequest(
            spoonList,
            method: .get,
            path: "/api/v1/recipes/recipe%2Fone/spoons",
            authorization: nil,
            queryItems: [
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "cursor", value: "spoon.cursor")
            ],
            responseCachePolicy: .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300)
        )
        assertJSONRequest(spoonCreate, method: .post, path: "/api/v1/recipes/recipe%2Fone/spoons", expected: [
            "clientMutationId": "spoon-create-1",
            "note": "Loved it.",
            "nextTime": NSNull(),
            "cookedAt": "2026-06-24T18:00:00.000Z",
            "photoUrl": "/photos/spoons/chef_1/recipe_1/cooked.jpg",
            "useAsRecipeCover": true
        ])
        try assertMultipartRequest(
            spoonPhotoCreate,
            method: .post,
            path: "/api/v1/recipes/recipe%2Fone/spoons",
            fileField: "photo",
            fileName: "spoon.webp",
            contentType: "image/webp",
            data: Data([0x52, 0x49, 0x46, 0x46]),
            fields: [
                "clientMutationId": "spoon-photo-1",
                "note": "Photo cook.",
                "nextTime": "more lemon",
                "useAsRecipeCover": "false"
            ]
        )
        #expect(spoonPhotoCreate.bodyString?.contains(#"name="cookedAt""#) == false)
        assertJSONRequest(spoonUpdate, method: .patch, path: "/api/v1/recipes/recipe%2Fone/spoons/spoon%2Fcooked", expected: [
            "clientMutationId": "spoon-update-1",
            "note": NSNull(),
            "nextTime": "more lemon",
            "cookedAt": "2026-06-24T19:00:00.000Z",
            "photoUrl": "/photos/spoons/chef_1/recipe_1/updated.jpg"
        ])
        assertRequest(
            spoonDelete,
            method: .delete,
            path: "/api/v1/recipes/recipe%2Fone/spoons/spoon%2Fcooked",
            authorization: "Bearer sj_private_token",
            extraHeaders: ["X-Client-Mutation-Id": "spoon-delete-1"],
            responseCachePolicy: .privateNoStore
        )
        #expect(spoonDelete.headers["X-Client-Mutation-Id"] == "spoon-delete-1")
        #expect(spoonDelete.body == nil)
    }

    @Test("cookbook and shopping parity builders encode idempotent bodies")
    func cookbookAndShoppingParityBuildersEncodeIdempotentBodies() throws {
        let readShopping = try ShoppingListRequests.readShoppingList()
            .urlRequest(configuration: Self.privateConfiguration)
        let syncShopping = try ShoppingListRequests.syncShoppingList(
            cursor: ShoppingSyncCursor(rawValue: "v1.shopping.cursor"),
            limit: 50
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let addShoppingItem = try ShoppingListRequests.addItem(
            name: "Eggs",
            quantity: 12,
            unit: "each",
            categoryKey: "dairy",
            iconKey: "egg",
            clientMutationID: "shopping-add-item-1"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let checkShoppingItem = try ShoppingListRequests.setItemChecked(
            id: "item/eggs",
            checked: true,
            clientMutationID: "shopping-check-item-1"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let deleteShoppingItem = try ShoppingListRequests.deleteItem(
            id: "item/eggs",
            clientMutationID: "shopping-delete-item-1",
            idempotency: .header
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let createCookbook = try CookbookWriteRequests.createCookbook(
            clientMutationID: "cookbook-create-1",
            title: "Weeknights"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let updateCookbook = try CookbookWriteRequests.updateCookbook(
            id: "cookbook/week",
            clientMutationID: "cookbook-update-1",
            title: "Dinner Parties"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let deleteCookbook = try CookbookWriteRequests.deleteCookbook(
            id: "cookbook/week",
            clientMutationID: "cookbook-delete-1",
            idempotency: MutationIdempotency.query
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let addRecipe = try CookbookWriteRequests.addRecipe(
            cookbookID: "cookbook/week",
            recipeID: "recipe/lemon",
            clientMutationID: "cookbook-add-recipe-1"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let removeRecipe = try CookbookWriteRequests.removeRecipe(
            cookbookID: "cookbook/week",
            recipeID: "recipe/lemon",
            clientMutationID: "cookbook-remove-recipe-1",
            idempotency: MutationIdempotency.body
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let addFromRecipe = try ShoppingListRequests.addIngredientsFromRecipe(
            recipeID: "recipe/lemon",
            scaleFactor: 1.5,
            clientMutationID: "shopping-add-recipe-1"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let clearCompleted = try ShoppingListRequests.clearCompleted(
            clientMutationID: "shopping-clear-completed-1"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let clearAll = try ShoppingListRequests.clearAll(
            clientMutationID: "shopping-clear-all-1"
        )
        .urlRequest(configuration: Self.privateConfiguration)

        assertRequest(readShopping, method: .get, path: "/api/v1/shopping-list", authorization: "Bearer sj_private_token", responseCachePolicy: .privateNoStore)
        #expect(readShopping.body == nil)
        assertRequest(
            syncShopping,
            method: .get,
            path: "/api/v1/shopping-list/sync",
            authorization: "Bearer sj_private_token",
            queryItems: [
                URLQueryItem(name: "limit", value: "50"),
                URLQueryItem(name: "cursor", value: "v1.shopping.cursor")
            ],
            responseCachePolicy: .privateNoStore
        )
        assertJSONRequest(addShoppingItem, method: .post, path: "/api/v1/shopping-list/items", expected: [
            "clientMutationId": "shopping-add-item-1",
            "name": "Eggs",
            "quantity": 12,
            "unit": "each",
            "categoryKey": "dairy",
            "iconKey": "egg"
        ])
        assertJSONRequest(checkShoppingItem, method: .patch, path: "/api/v1/shopping-list/items/item%2Feggs", expected: [
            "clientMutationId": "shopping-check-item-1",
            "checked": true
        ])
        assertRequest(
            deleteShoppingItem,
            method: .delete,
            path: "/api/v1/shopping-list/items/item%2Feggs",
            authorization: "Bearer sj_private_token",
            extraHeaders: ["X-Client-Mutation-Id": "shopping-delete-item-1"],
            responseCachePolicy: .privateNoStore
        )
        #expect(deleteShoppingItem.headers["X-Client-Mutation-Id"] == "shopping-delete-item-1")
        #expect(deleteShoppingItem.body == nil)
        assertJSONRequest(createCookbook, method: .post, path: "/api/v1/cookbooks", expected: [
            "clientMutationId": "cookbook-create-1",
            "title": "Weeknights"
        ])
        assertJSONRequest(updateCookbook, method: .patch, path: "/api/v1/cookbooks/cookbook%2Fweek", expected: [
            "clientMutationId": "cookbook-update-1",
            "title": "Dinner Parties"
        ])
        assertRequest(
            deleteCookbook,
            method: .delete,
            path: "/api/v1/cookbooks/cookbook%2Fweek",
            authorization: "Bearer sj_private_token",
            queryItems: [URLQueryItem(name: "clientMutationId", value: "cookbook-delete-1")],
            responseCachePolicy: .privateNoStore
        )
        #expect(deleteCookbook.body == nil)
        assertJSONRequest(addRecipe, method: .post, path: "/api/v1/cookbooks/cookbook%2Fweek/recipes/recipe%2Flemon", expected: [
            "clientMutationId": "cookbook-add-recipe-1"
        ])
        assertJSONRequest(removeRecipe, method: .delete, path: "/api/v1/cookbooks/cookbook%2Fweek/recipes/recipe%2Flemon", expected: [
            "clientMutationId": "cookbook-remove-recipe-1"
        ])
        assertJSONRequest(addFromRecipe, method: .post, path: "/api/v1/shopping-list/add-from-recipe", expected: [
            "clientMutationId": "shopping-add-recipe-1",
            "recipeId": "recipe/lemon",
            "scaleFactor": 1.5
        ])
        assertJSONRequest(clearCompleted, method: .post, path: "/api/v1/shopping-list/clear-completed", expected: [
            "clientMutationId": "shopping-clear-completed-1"
        ])
        assertJSONRequest(clearAll, method: .post, path: "/api/v1/shopping-list/clear-all", expected: [
            "clientMutationId": "shopping-clear-all-1"
        ])
    }

    @Test("recipe import builders preserve source variants in idempotent JSON bodies")
    func recipeImportBuildersPreserveSourceVariantsInIdempotentJSONBodies() throws {
        let importURL = try RecipeImportRequests.importURL(
            clientMutationID: "import-url-1",
            url: URL(string: "https://example.com/recipes/lemon-pasta")!
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let importText = try RecipeImportRequests.importText(
            clientMutationID: "import-text-1",
            text: "Lemon pasta\\nBoil pasta.",
            sourceURL: URL(string: "https://captures.example/lemon")!
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let importJSONLD = try RecipeImportRequests.importJSONLD(
            clientMutationID: "import-jsonld-1",
            jsonLD: JSONValue.object([
                "@context": JSONValue.string("https://schema.org"),
                "@type": JSONValue.string("Recipe"),
                "name": JSONValue.string("Native JSON-LD Soup")
            ]),
            sourceURL: Optional<URL>.none
        )
        .urlRequest(configuration: Self.privateConfiguration)
        let importVideo = try RecipeImportRequests.importVideoURL(
            clientMutationID: "import-video-1",
            url: URL(string: "https://www.youtube.com/watch?v=codex")!
        )
        .urlRequest(configuration: Self.privateConfiguration)

        assertJSONRequest(importURL, method: .post, path: "/api/v1/recipes/import", expected: [
            "clientMutationId": "import-url-1",
            "source": [
                "type": "url",
                "url": "https://example.com/recipes/lemon-pasta"
            ]
        ])
        assertJSONRequest(importText, method: .post, path: "/api/v1/recipes/import", expected: [
            "clientMutationId": "import-text-1",
            "source": [
                "type": "text",
                "text": "Lemon pasta\\nBoil pasta.",
                "url": "https://captures.example/lemon"
            ]
        ])
        assertJSONRequest(importJSONLD, method: .post, path: "/api/v1/recipes/import", expected: [
            "clientMutationId": "import-jsonld-1",
            "source": [
                "type": "json-ld",
                "jsonLd": [
                    "@context": "https://schema.org",
                    "@type": "Recipe",
                    "name": "Native JSON-LD Soup"
                ],
                "url": NSNull()
            ]
        ])
        assertJSONRequest(importVideo, method: .post, path: "/api/v1/recipes/import", expected: [
            "clientMutationId": "import-video-1",
            "source": [
                "type": "video-url",
                "url": "https://www.youtube.com/watch?v=codex"
            ]
        ])
    }

    @Test("API error envelopes preserve structured details for native recovery decisions")
    func apiErrorEnvelopesPreserveStructuredDetailsForNativeRecoveryDecisions() throws {
        let result = try APIEnvelope<RecipeImportResponse>.decodeResult(Self.recipeImportErrorEnvelope)

        switch result {
        case .success:
            throw TestFailure("Expected recipe import error envelope.")
        case .failure(let error):
            #expect(error.requestID == "req_import_blocked")
            #expect(error.code == "validation_error")
            #expect(error.status == 400)
            #expect(error.details["importCode"] == JSONValue.string("fetch-blocked"))
            #expect(error.details["fieldErrors"] == JSONValue.object(["source.url": JSONValue.string("Cannot fetch private network URLs")]))
        }
    }

    @Test("coverage edges preserve nullable JSON idempotency multipart and import contracts")
    func coverageEdgesPreserveNullableJSONIdempotencyMultipartAndImportContracts() throws {
        let jsonValues: [JSONValue] = [
            .object([
                "array": .array([.number(1), .bool(true), .null, .string("native")]),
                "object": .object(["count": .number(2)])
            ]),
            .array([.string("recipe"), .number(4.5), .bool(false), .null]),
            .string("spoonjoy"),
            .number(42),
            .bool(true),
            .null
        ]
        for value in jsonValues {
            let encoded = try JSONEncoder().encode(value)
            #expect(try JSONDecoder().decode(JSONValue.self, from: encoded) == value)
        }
        #expect(JSONValue.number(42).intValue == 42)
        #expect(JSONValue.number(42.5).intValue == nil)
        #expect(JSONValue.string("42").intValue == nil)

        let decodedJSONValue = try JSONDecoder().decode(
            JSONValue.self,
            from: Data(
                """
                {
                  "array": [1, true, null, "native"],
                  "bool": false,
                  "number": 3.5,
                  "object": { "name": "Soup" }
                }
                """.utf8
            )
        )
        #expect(decodedJSONValue == .object([
            "array": .array([.number(1), .bool(true), .null, .string("native")]),
            "bool": .bool(false),
            "number": .number(3.5),
            "object": .object(["name": .string("Soup")])
        ]))
        let convertedJSON = APIRequestSupport.jsonObject(from: decodedJSONValue)
        #expect(NSDictionary(dictionary: convertedJSON as? [String: Any] ?? [:]).isEqual(to: [
            "array": [1.0, true, NSNull(), "native"],
            "bool": false,
            "number": 3.5,
            "object": ["name": "Soup"]
        ]))

        let createRecipeWithNulls = try RecipeWriteRequests.createRecipe(
            clientMutationID: "recipe-create-nulls",
            title: "Pantry Soup",
            description: Optional<String>.none,
            servings: Optional<String>.none,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Simmer",
                    description: "Simmer everything.",
                    duration: Optional<Int>.none,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: Optional<String>.none, name: "broth")],
                    outputStepNums: []
                )
            ]
        )
        .urlRequest(configuration: Self.privateConfiguration)
        assertJSONRequest(createRecipeWithNulls, method: .post, path: "/api/v1/recipes", expected: [
            "clientMutationId": "recipe-create-nulls",
            "title": "Pantry Soup",
            "description": NSNull(),
            "servings": NSNull(),
            "steps": [[
                "stepNum": 1,
                "stepTitle": "Simmer",
                "description": "Simmer everything.",
                "duration": NSNull(),
                "ingredients": [[
                    "quantity": 1,
                    "name": "broth"
                ]],
                "outputStepNums": []
            ]]
        ])

        let updateRecipeWithNulls = try RecipeWriteRequests.updateRecipe(
            id: "recipe/pantry",
            clientMutationID: "recipe-update-nulls",
            title: "Pantry Soup Plus",
            description: "Still simple.",
            servings: Optional<String>.none
        )
        .urlRequest(configuration: Self.privateConfiguration)
        assertJSONRequest(updateRecipeWithNulls, method: .patch, path: "/api/v1/recipes/recipe%2Fpantry", expected: [
            "clientMutationId": "recipe-update-nulls",
            "title": "Pantry Soup Plus",
            "description": "Still simple.",
            "servings": NSNull()
        ])

        let createStepWithNulls = try RecipeStepRequests.createStep(
            recipeID: "recipe/pantry",
            clientMutationID: "step-create-nulls",
            stepNum: 2,
            stepTitle: Optional<String>.none,
            description: "Season.",
            duration: Optional<Int>.none,
            ingredients: [RecipeIngredientDraft(quantity: 2, unit: Optional<String>.none, name: "salt")],
            outputStepNums: []
        )
        .urlRequest(configuration: Self.privateConfiguration)
        assertJSONRequest(createStepWithNulls, method: .post, path: "/api/v1/recipes/recipe%2Fpantry/steps", expected: [
            "clientMutationId": "step-create-nulls",
            "stepNum": 2,
            "stepTitle": NSNull(),
            "description": "Season.",
            "duration": NSNull(),
            "ingredients": [[
                "quantity": 2,
                "name": "salt"
            ]],
            "outputStepNums": []
        ])

        let archiveHeader = try RecipeCoverRequests.archive(
            recipeID: "recipe/pantry",
            coverID: "cover/old",
            clientMutationID: "cover-archive-header",
            replacementCoverID: "cover/new",
            replacementVariant: .stylized,
            confirmNoCover: true,
            deleteSafeObjects: false,
            idempotency: .header
        )
        .urlRequest(configuration: Self.privateConfiguration)
        assertRequest(
            archiveHeader,
            method: .delete,
            path: "/api/v1/recipes/recipe%2Fpantry/covers/cover%2Fold",
            authorization: "Bearer sj_private_token",
            extraHeaders: [
                "Content-Type": "application/json",
                "X-Client-Mutation-Id": "cover-archive-header"
            ],
            expectsBody: true,
            responseCachePolicy: .privateNoStore
        )
        #expect(NSDictionary(dictionary: try jsonBody(from: archiveHeader)).isEqual(to: [
            "replacementCoverId": "cover/new",
            "replacementVariant": "stylized",
            "confirmNoCover": true,
            "deleteSafeObjects": false
        ]))

        let archiveBody = try RecipeCoverRequests.archive(
            recipeID: "recipe/pantry",
            coverID: "cover/old",
            clientMutationID: "cover-archive-body",
            replacementCoverID: "cover/new",
            replacementVariant: .image,
            confirmNoCover: false,
            deleteSafeObjects: true,
            idempotency: .body
        )
        .urlRequest(configuration: Self.privateConfiguration)
        assertJSONRequest(archiveBody, method: .delete, path: "/api/v1/recipes/recipe%2Fpantry/covers/cover%2Fold", expected: [
            "clientMutationId": "cover-archive-body",
            "replacementCoverId": "cover/new",
            "replacementVariant": "image",
            "confirmNoCover": false,
            "deleteSafeObjects": true
        ])

        let spoonCreateWithNulls = try RecipeSpoonRequests.createSpoon(
            recipeID: "recipe/pantry",
            clientMutationID: "spoon-create-nulls",
            note: Optional<String>.none,
            nextTime: "more acid",
            cookedAt: Optional<String>.none,
            photoURL: "/photos/spoons/pantry.jpg",
            useAsRecipeCover: false
        )
        .urlRequest(configuration: Self.privateConfiguration)
        assertJSONRequest(spoonCreateWithNulls, method: .post, path: "/api/v1/recipes/recipe%2Fpantry/spoons", expected: [
            "clientMutationId": "spoon-create-nulls",
            "note": NSNull(),
            "nextTime": "more acid",
            "cookedAt": NSNull(),
            "photoUrl": "/photos/spoons/pantry.jpg",
            "useAsRecipeCover": false
        ])

        let spoonPhotoWithCookedAt = try RecipeSpoonRequests.createSpoon(
            recipeID: "recipe/pantry",
            photo: UploadFile(fileName: "pantry.jpg", contentType: "image/jpeg", data: Data([0xFF, 0xD8])),
            clientMutationID: "spoon-photo-cooked-at",
            note: Optional<String>.none,
            nextTime: Optional<String>.none,
            cookedAt: "2026-06-25T03:00:00.000Z",
            useAsRecipeCover: true
        )
        .urlRequest(configuration: Self.privateConfiguration)
        try assertMultipartRequest(
            spoonPhotoWithCookedAt,
            method: .post,
            path: "/api/v1/recipes/recipe%2Fpantry/spoons",
            fileField: "photo",
            fileName: "pantry.jpg",
            contentType: "image/jpeg",
            data: Data([0xFF, 0xD8]),
            fields: [
                "clientMutationId": "spoon-photo-cooked-at",
                "cookedAt": "2026-06-25T03:00:00.000Z",
                "useAsRecipeCover": "true"
            ]
        )

        let spoonUpdateWithNulls = try RecipeSpoonRequests.updateSpoon(
            recipeID: "recipe/pantry",
            spoonID: "spoon/one",
            clientMutationID: "spoon-update-nulls",
            note: "Still good.",
            nextTime: Optional<String>.none,
            cookedAt: Optional<String>.none,
            photoURL: "/photos/spoons/pantry-updated.jpg"
        )
        .urlRequest(configuration: Self.privateConfiguration)
        assertJSONRequest(spoonUpdateWithNulls, method: .patch, path: "/api/v1/recipes/recipe%2Fpantry/spoons/spoon%2Fone", expected: [
            "clientMutationId": "spoon-update-nulls",
            "note": "Still good.",
            "nextTime": NSNull(),
            "cookedAt": NSNull(),
            "photoUrl": "/photos/spoons/pantry-updated.jpg"
        ])

        let importTextWithoutURL = try RecipeImportRequests.importText(
            clientMutationID: "import-text-no-url",
            text: "Soup\\nSeason to taste.",
            sourceURL: Optional<URL>.none
        )
        .urlRequest(configuration: Self.privateConfiguration)
        assertJSONRequest(importTextWithoutURL, method: .post, path: "/api/v1/recipes/import", expected: [
            "clientMutationId": "import-text-no-url",
            "source": [
                "type": "text",
                "text": "Soup\\nSeason to taste."
            ]
        ])

        let importResponse = try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
            """
            {
              "importCode": "provider-secret",
              "blockers": [
                {
                  "capability": "ProviderSecret",
                  "missing": null,
                  "retryAfterSeconds": 30,
                  "ownerAction": true
                }
              ]
            }
            """.utf8
        ))
        #expect(importResponse.recipe == nil)
        #expect(importResponse.importCode == "provider-secret")
        #expect(importResponse.blockers == [
            .object([
                "capability": .string("ProviderSecret"),
                "missing": .null,
                "retryAfterSeconds": .number(30),
                "ownerAction": .bool(true)
            ])
        ])

        let collidingFile = UploadFile(
            fileName: "valid.bin",
            contentType: "application/octet-stream",
            data: Data("file-collision".utf8)
        )
        #expect(APIRequestSupport.multipartBoundary(
            file: collidingFile,
            fields: ["note": "field-collision"],
            candidates: ["file-collision", "field-collision", "safe-boundary"]
        ) == "safe-boundary")
        let fallbackBoundary = APIRequestSupport.multipartBoundary(
            file: collidingFile,
            fields: ["note": "field-collision"],
            candidates: ["file-collision", "field-collision"]
        )
        #expect(fallbackBoundary.hasPrefix("SpoonjoyBoundary-"))
        #expect(fallbackBoundary != "file-collision")
        #expect(fallbackBoundary != "field-collision")
        #expect(throws: APIRequestBuildError.self) {
            _ = try APIRequestSupport.privateMultipart(
                method: .post,
                pathComponents: ["api", "v1", "unsafe"],
                fileField: "",
                file: collidingFile
            )
        }
        #expect(throws: APIRequestBuildError.self) {
            _ = try APIRequestSupport.privateMultipart(
                method: .post,
                pathComponents: ["api", "v1", "unsafe"],
                fileField: "file",
                file: collidingFile,
                fields: ["bad\u{7F}": "value"]
            )
        }
    }

    private static let privateConfiguration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    private static let discoveryEnvelope = Data(
        """
        {
          "ok": true,
          "requestId": "req_discovery",
          "data": {
            "app": "spoonjoy",
            "version": "v1",
            "status": "ok",
            "docsUrl": "https://spoonjoy.app/api",
            "openapiUrl": "/api/v1/openapi.json",
            "sdkOpenapiUrl": "/api/v1/openapi.sdk.json",
            "connectorOpenapiUrl": "/api/v1/openapi.connector.json"
          }
        }
        """.utf8
    )

    private static let recipeImportErrorEnvelope = Data(
        """
        {
          "ok": false,
          "requestId": "req_import_blocked",
          "error": {
            "code": "validation_error",
            "message": "Import URL is blocked",
            "status": 400,
            "details": {
              "importCode": "fetch-blocked",
              "fieldErrors": {
                "source.url": "Cannot fetch private network URLs"
              }
            }
          }
        }
        """.utf8
    )
}

private func assertRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    authorization: String?,
    extraHeaders: [String: String] = [:],
    queryItems: [URLQueryItem] = [],
    expectsBody: Bool = false,
    responseCachePolicy: APIResponseCachePolicy? = nil
) {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.queryItems == queryItems)
    var expectedHeaders = ["Accept": "application/json"]
    if let authorization {
        expectedHeaders["Authorization"] = authorization
    }
    for (name, value) in extraHeaders {
        expectedHeaders[name] = value
    }
    #expect(request.headers == expectedHeaders)
    if expectsBody {
        #expect(request.body != nil)
    } else {
        #expect(request.body == nil)
    }
    if let responseCachePolicy {
        #expect(request.responseCachePolicy == responseCachePolicy)
    }
}

private func assertJSONRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    expected: [String: Any]
) {
    assertRequest(
        request,
        method: method,
        path: path,
        authorization: "Bearer sj_private_token",
        extraHeaders: ["Content-Type": "application/json"],
        expectsBody: true,
        responseCachePolicy: .privateNoStore
    )
    #expect(request.queryItems.isEmpty)
    #expect(NSDictionary(dictionary: (try? jsonBody(from: request)) ?? [:]).isEqual(to: expected))
}

private func assertMultipartRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    fileField: String,
    fileName: String,
    contentType: String,
    data: Data,
    fields: [String: String] = [:]
) throws {
    let multipartContentType = try #require(request.headers["Content-Type"])
    #expect(multipartContentType.hasPrefix("multipart/form-data; boundary="))
    assertRequest(
        request,
        method: method,
        path: path,
        authorization: "Bearer sj_private_token",
        extraHeaders: ["Content-Type": multipartContentType],
        expectsBody: true,
        responseCachePolicy: .privateNoStore
    )
    #expect(request.queryItems.isEmpty)
    let parts = try multipartParts(in: request)
    #expect(parts.count == fields.count + 1)
    let filePart = try multipartPart(named: fileField, parts: parts)
    #expect(filePart.headers["Content-Disposition"] == #"form-data; name="\#(fileField)"; filename="\#(fileName)""#)
    #expect(filePart.headers["Content-Type"] == contentType)
    #expect(filePart.body == data)
    for (name, value) in fields {
        let fieldPart = try multipartPart(named: name, parts: parts)
        #expect(fieldPart.headers["Content-Disposition"] == #"form-data; name="\#(name)""#)
        #expect(fieldPart.body == Data(value.utf8))
    }
}

private func multipartParts(in request: APIRequest) throws -> [MultipartPart] {
    let contentType = try #require(request.headers["Content-Type"])
    let boundaryPrefix = "multipart/form-data; boundary="
    #expect(contentType.hasPrefix(boundaryPrefix))
    let boundary = contentType
        .dropFirst(boundaryPrefix.count)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    let body = try #require(request.body)
    return try parseMultipart(body: body, boundary: String(boundary))
}

private func parseMultipart(body: Data, boundary: String) throws -> [MultipartPart] {
    let openingBoundary = Data("--\(boundary)\r\n".utf8)
    let nextBoundary = Data("\r\n--\(boundary)".utf8)
    let closeBoundary = Data("--".utf8)
    let nextPartBoundary = Data("\r\n".utf8)
    let headerSeparator = Data("\r\n\r\n".utf8)
    let closingWithCRLF = Data("\r\n--\(boundary)--\r\n".utf8)
    let closingWithoutCRLF = Data("\r\n--\(boundary)--".utf8)

    guard body.starts(with: openingBoundary) else {
        throw TestFailure("Multipart body is missing opening boundary.")
    }
    guard body.ends(with: closingWithCRLF) || body.ends(with: closingWithoutCRLF) else {
        throw TestFailure("Multipart body is missing closing boundary.")
    }

    var cursor = openingBoundary.count
    var parts: [MultipartPart] = []
    while cursor < body.count {
        let searchRange = cursor..<body.count
        guard let headerRange = body.range(of: headerSeparator, in: searchRange) else {
            throw TestFailure("Multipart part is missing header terminator.")
        }
        let headerData = Data(body[cursor..<headerRange.lowerBound])
        let headerString = try #require(String(data: headerData, encoding: .utf8))
        let bodyStart = headerRange.upperBound
        guard let boundaryRange = body.range(of: nextBoundary, in: bodyStart..<body.count) else {
            throw TestFailure("Multipart part is missing trailing boundary.")
        }

        parts.append(MultipartPart(
            headers: parseMultipartHeaders(headerString),
            body: Data(body[bodyStart..<boundaryRange.lowerBound])
        ))

        let afterBoundary = boundaryRange.upperBound
        let remaining = body[afterBoundary..<body.count]
        if remaining.starts(with: closeBoundary) {
            let trailerStart = afterBoundary + closeBoundary.count
            let trailer = Data(body[trailerStart..<body.count])
            guard trailer.isEmpty || trailer == nextPartBoundary else {
                throw TestFailure("Multipart closing boundary has unexpected trailing bytes.")
            }
            break
        }
        guard remaining.starts(with: nextPartBoundary) else {
            throw TestFailure("Multipart boundary is not followed by CRLF or close marker.")
        }
        cursor = afterBoundary + nextPartBoundary.count
    }

    return parts
}

private func parseMultipartHeaders(_ headerString: String) -> [String: String] {
    var headers: [String: String] = [:]
    for line in headerString.components(separatedBy: "\r\n") {
        let pieces = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard pieces.count == 2 else {
            continue
        }
        headers[String(pieces[0])] = String(pieces[1]).trimmingCharacters(in: .whitespaces)
    }
    return headers
}

private func multipartPart(named name: String, parts: [MultipartPart]) throws -> MultipartPart {
    let disposition = "form-data; name=\"\(name)\""
    return try #require(parts.first { part in
        part.headers["Content-Disposition"] == disposition
            || part.headers["Content-Disposition"]?.hasPrefix("\(disposition);") == true
    })
}

private struct MultipartPart: Equatable {
    let headers: [String: String]
    let body: Data
}

private func jsonBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private extension APIRequest {
    var bodyString: String? {
        guard let body else {
            return nil
        }
        return String(data: body, encoding: .isoLatin1)
    }
}

private extension Data {
    func ends(with suffix: Data) -> Bool {
        count >= suffix.count && self.suffix(suffix.count).elementsEqual(suffix)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
