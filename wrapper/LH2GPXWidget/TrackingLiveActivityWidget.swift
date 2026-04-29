#if canImport(WidgetKit) && canImport(SwiftUI)
import WidgetKit
import SwiftUI
import ActivityKit
import LocationHistoryConsumerAppSupport

// MARK: - Lock Screen / Notification Banner View

@available(iOS 16.2, *)
private struct TrackingLockScreenView: View {
    let context: ActivityViewContext<TrackingAttributes>
    private var selectedDisplay: DynamicIslandCompactDisplay {
        WidgetDataStore.loadDynamicIslandCompactDisplay()
    }

    private var primaryValue: LiveActivityValuePresentation {
        LiveActivityValueFormatter.presentation(
            for: selectedDisplay,
            status: context.state,
            startTime: context.attributes.startTime
        )
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "location.north.fill")
                .font(.title2)
                .foregroundStyle(.white)
                // symbolEffect requires iOS 17+; omitted for 16.2 compat

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.trackName.isEmpty ? WidgetStr.liveTrack : context.attributes.trackName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(primaryValue.text, systemImage: primaryValue.systemImageName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if selectedDisplay != .points {
                        Label(WidgetStr.pointsCount(context.state.pointCount), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    if selectedDisplay != .uploadStatus, context.state.uploadState != .disabled {
                        Label(context.state.uploadState.localizedName, systemImage: context.state.uploadState.systemImageName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(LiveActivityValueFormatter.formattedElapsed(since: context.attributes.startTime))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                Text(WidgetStr.elapsed)
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

    private func selectedDisplay() -> DynamicIslandCompactDisplay {
        WidgetDataStore.loadDynamicIslandCompactDisplay()
    }

    private func primaryValue(for context: ActivityViewContext<TrackingAttributes>) -> LiveActivityValuePresentation {
        LiveActivityValueFormatter.presentation(
            for: selectedDisplay(),
            status: context.state,
            startTime: context.attributes.startTime
        )
    }

    @ViewBuilder
    private func compactTrailingView(context: ActivityViewContext<TrackingAttributes>) -> some View {
        Text(primaryValue(for: context).compactText)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    @ViewBuilder
    private func minimalView(context: ActivityViewContext<TrackingAttributes>) -> some View {
        let display = selectedDisplay()
        let primary = primaryValue(for: context)
        let imageName = context.state.isPaused
            ? "pause.circle.fill"
            : (display == .uploadStatus ? primary.systemImageName : primary.systemImageName)
        Image(systemName: imageName)
            .foregroundStyle(context.state.isPaused ? .orange : Color.accentColor)
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackingAttributes.self) { context in
            TrackingLockScreenView(context: context)
        } dynamicIsland: { context in
            let primary = primaryValue(for: context)
            return DynamicIsland {
                // MARK: Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Label(primary.text, systemImage: primary.systemImageName)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(LiveActivityValueFormatter.formattedElapsed(since: context.attributes.startTime))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.trackName.isEmpty ? WidgetStr.liveTrack : context.attributes.trackName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()

                        // Paused indicator
                        if context.state.isPaused {
                            Text("⏸ \(WidgetStr.paused)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.orange)
                        }

                        if context.state.uploadState != .disabled {
                            Text(context.state.uploadState.localizedName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(context.state.uploadState == .failed ? .red : .blue)
                                .padding(.leading, 4)
                        }

                        if selectedDisplay() != .points {
                            Label(WidgetStr.pointsCount(context.state.pointCount), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 4)
                        }

                        if selectedDisplay() != .distance {
                            Label(context.state.formattedDistance, systemImage: "ruler")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "location.fill.viewfinder")
                    .foregroundStyle(context.state.isPaused ? .orange : Color.accentColor)
            } compactTrailing: {
                compactTrailingView(context: context)
            } minimal: {
                minimalView(context: context)
            }
            .widgetURL(URL(string: "lh2gpx://live"))
            .keylineTint(Color.accentColor)
        }
    }
}
#endif
