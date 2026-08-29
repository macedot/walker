import SwiftUI

struct GameOverView: View {
    let result: RunResult
    let onRetry: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 22) {
                titleIcon
                VStack(spacing: 6) {
                    Text(result.survived ? "YOU MADE IT OUT" : "THE HORDE GOT YOU")
                        .font(.title2.bold())
                        .tracking(2)
                        .foregroundStyle(result.survived ? .toxicGreen : .bloodRed)
                    Text(result.survived
                        ? "You ended the run alive. Respect."
                        : "Survived \(Format.duration(result.duration)) before they caught you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCell("Time", Format.duration(result.duration))
                    statCell("Distance", Format.distance(result.distanceMeters))
                    statCell("Kills", "\(result.kills)")
                    statCell("Pace", Format.pace(meters: result.distanceMeters, seconds: result.duration))
                }
                VStack(spacing: 10) {
                    Button {
                        onRetry()
                    } label: {
                        Label("Run again", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.bloodRed, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button {
                        onHome()
                    } label: {
                        Text("Home")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.walkerPanel, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                Text("Saved to history")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(28)
        }
    }

    private var titleIcon: some View {
        Image(systemName: result.survived ? "figure.run" : "skull.fill")
            .font(.system(size: 64))
            .foregroundStyle(result.survived ? .toxicGreen : .bloodRed)
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .panel()
    }
}
