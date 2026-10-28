import SwiftUI
import WidgetKit

@main
struct SpoonjoyCookTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        // The whole cook session: step, checklist and timers, while cook mode is open.
        SpoonjoyCookSessionLiveActivity()
#if canImport(AlarmKit)
        // Each step timer's own alarm countdown, which keeps running after cook mode closes.
        SpoonjoyCookTimerLiveActivity()
#endif
    }
}
