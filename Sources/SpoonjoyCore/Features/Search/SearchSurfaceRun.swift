import Foundation

/// One live search, as the Search tab runs it: the request, and what came back. `PlatformNavigationView` and Ouro
/// Reins both run a search through this, then show `NativeShellContentState.searchSurfaceViewModel(after:state:cachedPage:)`.
public enum SearchSurfaceRun: Equatable, Sendable {
    /// A newer search replaced this one: nothing changes on screen.
    case cancelled
    case page(SearchSurfacePage)
    case failed(SearchSurfaceRepositoryError)

    /// The 20 results the Search tab asks for.
    public static let limit = 20

    public static func run(_ state: SearchState, in repository: any SearchSurfaceRepository) async -> SearchSurfaceRun {
        do {
            return .page(try await repository.search(request: SearchSurfaceRequest(query: state.query, scope: state.scope, limit: limit)))
        } catch SearchSurfaceRepositoryError.cancelled {
            return .cancelled
        } catch let error as SearchSurfaceRepositoryError {
            return .failed(error)
        } catch {
            return .failed(.searchFailed(message: String(describing: error)))
        }
    }
}

extension NativeShellContentState {
    /// What Search shows after a run: the page, or the error over `cachedPage`, what this device had saved for the same
    /// search when the run started. Nil for a cancelled run.
    public func searchSurfaceViewModel(after run: SearchSurfaceRun, state: SearchState, cachedPage: SearchSurfacePage?) -> SearchSurfaceViewModel? {
        switch run {
        case .cancelled:
            nil
        case .page(let page):
            performSearch(page: page, state: state)
        case .failed(let error):
            performSearch(error: error, state: state, cachedPage: cachedPage)
        }
    }
}
