import Foundation
import Synchronization

/// The one sync store for an app directory in this process.
///
/// The app scene, every App Intent and every App Entity query share it. A `FileBackedNativeSyncStore` reads its file
/// once and then writes its whole in-memory copy, so two instances on one file overwrite each other's queue: an edit
/// queued by Siri would be dropped by the app's next save, or the reverse. App Intents run in the app's own process
/// (the app has no intents extension), so one instance per process is enough.
public enum NativeProcessSyncStore {
    public static let syncStoreFileName = "native-sync-store.json"
    public static let stagedMediaDirectoryName = "native-staged-media"

    private static let stores = Mutex<[String: FileBackedNativeSyncStore]>([:])

    /// The shared store for `appDirectory`, opened on first use. If the file cannot be opened, returns a store that
    /// reports the failure on every call, and tries again on the next request instead of caching the failure.
    public static func shared(appDirectory: URL) -> any NativeSyncStore {
        let fileURL = appDirectory.appendingPathComponent(syncStoreFileName)
        let key = fileURL.standardizedFileURL.path
        return stores.withLock { stores -> any NativeSyncStore in
            if let store = stores[key] {
                return store
            }
            do {
                let store = try FileBackedNativeSyncStore(
                    fileURL: fileURL,
                    mediaResolver: stagedMediaDirectory(appDirectory: appDirectory)
                )
                stores[key] = store
                return store
            } catch {
                return UnavailableNativeSyncStore(message: "Could not open Spoonjoy sync store: \(error)")
            }
        }
    }

    /// Where queued photos wait for upload, next to the sync store.
    public static func stagedMediaDirectory(appDirectory: URL) -> NativeStagedMediaDirectory {
        NativeStagedMediaDirectory(
            directoryURL: appDirectory.appendingPathComponent(stagedMediaDirectoryName, isDirectory: true)
        )
    }
}
