#if canImport(SwiftUI)
import SwiftUI

// MARK: - LHExportStepIndicator

/// Linear 4-step progress indicator for the Export checkout flow.
/// Steps are Auswahl / Format / Inhalt / Fertig (localised labels passed by caller).
public struct LHExportStepIndicator: View {

    public enum Step: Int, CaseIterable {
        case selection = 0, format = 1, content = 2, done = 3

        var accessibilityID: String {
            switch self {
            case .selection: "selection"
            case .format:    "format"
            case .content:   "content"
            case .done:      "done"
            }
        }
    }

    let labels: [String]
    let currentStep: Step

    public init(labels: [String], currentStep: Step) {
        self.labels      = labels
        self.currentStep = currentStep
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Step.allCases.enumerated()), id: \.offset) { index, step in
                stepNode(step: step, index: index)
                if index < Step.allCases.count - 1 {
                    connector(completed: index < currentStep.rawValue)
                }
            }
        }
    }

    @ViewBuilder
    private func stepNode(step: Step, index: Int) -> some View {
        let isDone   = step.rawValue < currentStep.rawValue
        let isActive = step.rawValue == currentStep.rawValue
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isDone   ? LH2GPXTheme.successGreen  :
                          isActive ? LH2GPXTheme.primaryBlue   :
                                     LH2GPXTheme.chipBackground)
                    .frame(width: 24, height: 24)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }
            Text(index < labels.count ? labels[index] : "")
                .font(.caption2)
                .foregroundStyle(isActive || isDone ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityIdentifier("export.step.\(step.accessibilityID)")
    }

    @ViewBuilder
    private func connector(completed: Bool) -> some View {
        Rectangle()
            .fill(completed ? LH2GPXTheme.primaryBlue.opacity(0.4) : LH2GPXTheme.separator)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
    }
}

// MARK: - LHExportBottomBar

/// Sticky bottom bar for the Export checkout flow.
/// Shows a compact selection + format summary on the left and the primary
/// Export button on the right. When the button is disabled the reason is
/// shown below the row.
public struct LHExportBottomBar: View {

    let summary:        String
    let buttonTitle:    String
    let isEnabled:      Bool
    let disabledReason: String?
    let onExport:       () -> Void

    public init(
        summary:        String,
        buttonTitle:    String,
        isEnabled:      Bool,
        disabledReason: String?,
        onExport:       @escaping () -> Void
    ) {
        self.summary        = summary
        self.buttonTitle    = buttonTitle
        self.isEnabled      = isEnabled
        self.disabledReason = disabledReason
        self.onExport       = onExport
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    if !summary.isEmpty {
                        Label(summary, systemImage: "doc.badge.ellipsis")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .accessibilityIdentifier("export.summary")
                    }
                    Spacer(minLength: 0)
                    Button(action: onExport) {
                        Label(buttonTitle, systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isEnabled)
                    .accessibilityIdentifier("export.primaryButton")
                }
                if let disabledReason, !isEnabled {
                    Label(disabledReason, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("export.disabledReason")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .accessibilityIdentifier("export.bottomBar")
    }
}

// MARK: - LHExportFilterDisclosure

/// Collapsible disclosure card wrapping the advanced export filter controls.
/// Shows an "Active" badge and orange accent when any filter is in use.
public struct LHExportFilterDisclosure<Content: View>: View {

    let title:    String
    let isActive: Bool
    @State private var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    public init(
        title:          String,
        isActive:       Bool,
        startsExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title        = title
        self.isActive     = isActive
        self._isExpanded  = State(initialValue: startsExpanded)
        self.content      = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isActive
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(isActive ? Color.orange : Color.secondary)
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    if isActive {
                        LHStatusChip(title: "Active", systemImage: "checkmark", color: .orange)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.horizontal, 16)
                    content().padding(16)
                }
            }
        }
        .background(LH2GPXTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isActive ? Color.orange.opacity(0.3) : LH2GPXTheme.cardBorder,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("export.advancedFilters")
    }
}

#endif
