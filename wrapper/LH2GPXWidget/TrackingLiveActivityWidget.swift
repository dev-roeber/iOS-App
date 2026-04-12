#if canImport(WidgetKit) && canImport(SwiftUI)
import WidgetKit
import SwiftUI
import ActivityKit
import LocationHistoryConsumerAppSupport

// MARK: - Lock Screen / Notification Banner View

@available(iOS 16.2, *)
private struct TrackingLockScreenView: View {
    let context: ActivityViewContext<TrackingAttributes>

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "location.north.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating)

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
                        Label("\(context.state.pointCount)", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "location.fill.viewfinder")
                    .foregroundStyle(.accentColor)
            } compactTrailing: {
                Text(context.state.formattedDistance)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            } minimal: {
                Image(systemName: "location.fill.viewfinder")
                    .foregroundStyle(.accentColor)
            }
            .widgetURL(URL(string: "lh2gpx://live"))
            .keylineTint(.accentColor)
        }
    }
}
#endif
