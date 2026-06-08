import ComposableArchitecture
import RunCraftModels
import SwiftUI
import VDOTEngine

/// On-wrist root view. Three states:
/// - loading: spinner
/// - rest day or no session: explanatory text
/// - regular session: session-type chip, target distance/duration, pace range,
///   and a prominent Start button that pushes the workout to the native
///   Workout app via WorkoutKit.
public struct WatchView: View {
    @Bindable public var store: StoreOf<WatchAppFeature>

    public init(store: StoreOf<WatchAppFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if store.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(.top, 32)
                } else if let session = store.todaySession {
                    sessionCard(session)
                } else {
                    emptyState
                }

                if let message = store.lastError {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .navigationTitle("Today")
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func sessionCard(_ session: PlannedSession) -> some View {
        VStack(spacing: 10) {
            sessionTypeChip(session.sessionType)

            if let km = session.targetDistanceKm, km > 0 {
                metricRow(value: km.formatted(.number.precision(.fractionLength(0...1))), unit: "km")
            } else if let min = session.targetDurationMin, min > 0 {
                metricRow(value: "\(min)", unit: "min")
            }

            if let range = store.state.todayPaceRange {
                Text(range.formatted())
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if session.sessionType != .rest {
                Button {
                    store.send(.startWorkoutTapped)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No session today")
                .font(.headline)
            Text("Open RunCraft on iPhone to set up a plan.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private func sessionTypeChip(_ type: SessionType) -> some View {
        Text(type.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color(for: type).opacity(0.25))
            )
            .foregroundStyle(color(for: type))
    }

    @ViewBuilder
    private func metricRow(value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text(unit)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func color(for type: SessionType) -> Color {
        switch type {
        case .easy:       .green
        case .long:       .mint
        case .tempo:      .yellow
        case .interval:   .red
        case .repetition: .orange
        case .rest:       .gray
        }
    }
}
