import SwiftUI
import WidgetKit

@main
struct SpoonjoyCookTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
#if canImport(AlarmKit)
        SpoonjoyCookTimerLiveActivity()
#endif
    }
}
