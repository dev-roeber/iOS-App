#if canImport(SwiftUI)
import SwiftUI

public enum LGRecordState: Equatable {
    case ready
    case recording
    case paused
}

@available(iOS 26.0, *)
public struct LGRecordButton: View {
    @Binding public var state: LGRecordState
    public var onStart: () -> Void
    public var onStop: () -> Void
    public var onPause: () -> Void
    public var onResume: () -> Void
    public var onLap: () -> Void

    @Namespace private var namespace

    public init(
        state: Binding<LGRecordState>,
        onStart: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onLap: @escaping () -> Void
    ) {
        self._state = state
        self.onStart = onStart
        self.onStop = onStop
        self.onPause = onPause
        self.onResume = onResume
        self.onLap = onLap
    }

    public var body: some View {
        GlassEffectContainer(spacing: 24) {
            HStack(spacing: 16) {
                if state == .recording {
                    sideButton(icon: "flag.fill", a11y: "Runde", action: onLap)
                        .glassEffectID("left", in: namespace)
                }
                mainButton
                    .glassEffectID("main", in: namespace)
                if state == .recording {
                    sideButton(icon: "pause.fill", a11y: "Pause", action: pause)
                        .glassEffectID("right", in: namespace)
                }
            }
        }
        .animation(.bouncy(duration: 0.4), value: state)
    }

    @ViewBuilder
    private var mainButton: some View {
        switch state {
        case .ready:
            Button {
                withAnimation(.bouncy(duration: 0.4)) {
                    onStart()
                    state = .recording
                }
            } label: {
                Label("Aufnahme starten", systemImage: "record.circle.fill")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .frame(minHeight: 56)
            }
            .buttonStyle(.glassProminent)
            .tint(.red)
            .controlSize(.extraLarge)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("live.recording.primaryAction")
        case .recording:
            Button {
                withAnimation(.bouncy(duration: 0.4)) {
                    onStop()
                    state = .ready
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 72, height: 72)
            }
            .buttonStyle(.glassProminent)
            .tint(.red)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Aufnahme stoppen")
            .accessibilityIdentifier("live.recording.stopAction")
        case .paused:
            Button {
                withAnimation(.bouncy(duration: 0.4)) {
                    onResume()
                    state = .recording
                }
            } label: {
                Label("Fortsetzen", systemImage: "play.fill")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .frame(minHeight: 56)
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .controlSize(.extraLarge)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("live.recording.resumeAction")
        }
    }

    private func sideButton(icon: String, a11y: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(a11y)
    }

    private func pause() {
        withAnimation(.bouncy(duration: 0.4)) {
            onPause()
            state = .paused
        }
    }
}
#endif
