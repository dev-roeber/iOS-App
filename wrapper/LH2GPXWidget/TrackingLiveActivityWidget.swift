#if canImport(WidgetKit) && canImport(SwiftUI)
import WidgetKit
import SwiftUI
import ActivityKit
import LocationHistoryConsumerAppSupport

// MARK: - Lock Screen / Notification Banner View

@available(iOS 16.2, *)
private struct TrackingLockScreenView: View {
    let context: ActivityViewContext<TrackingAttributes>

    /// Pace in min/km, computed from distance and elapsed time. nil if not yet meaningful.
    private var paceString: String? {
        let elapsed = Date().timeIntervalSince(context.attributes.startTime)
        let km = context.state.distanceMeters / 1000
        guard km >= 0.1, elapsed > 0 else { return nil }
        let minPerKm = (elapsed / 60) / km
        guard minPerKm < 99 else { return nil }
        let minutes = Int(minPerKm)
        let seconds = Int((minPerKm - Double(minutes)) * 60)
        return String(format: "%d'%02d\"/km", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "location.north.fill")
                .font(.title2)
                .foregroundStyle(.white)
                // symbolEffect requires iOS 17+; omitted for 16.2 compat

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.trackName.isEmpty ? "Live Track" : context.attributes.trackName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(context.state.formattedDistance, systemImage: "ruler")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))

                    Label("\(context.state.pointCount) pts", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))

                    if let pace = paceString {
                        Label(pace, systemImage: "speedometer")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(context.attributes.startTime, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                Text("elapsed")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.gradient)
        )
    }
}

// MARK: - Widget Configuration

@available(iOS 16.2, *)
struct TrackingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackingAttributes.self) { context in
            TrackingLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.formattedDistance, systemImage: "location.north.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(context.attributes.startTime, style: .timer)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.trackName.isEmpty ? "Live Track" : context.attributes.trackName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()

                        // Paused indicator
                        if context.state.isPaused {
                            Text("⏸ Pausiert")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.orange)
                        }

                        // Upload queue badge
                        if context.state.uploadQueueCount > 0 {
                            Text("↑ \(context.state.uploadQueueCount)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.blue)
                                .padding(.leading, 4)
                        }

                        Label("\(context.state.pointCount)", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 4)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "location.fill.viewfinder")
                    .foregroundStyle(context.state.isPaused ? .orange : Color.accentColor)
            } compactTrailing: {
                Text(context.state.formattedDistance)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "location.fill.viewfinder")
                    .foregroundStyle(context.state.isPaused ? .orange : Color.accentColor)
            }
            .widgetURL(URL(string: "lh2gpx://live"))
            .keylineTint(Color.accentColor)
        }
    }
}
#endif
