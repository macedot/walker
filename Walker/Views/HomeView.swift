import SwiftData
import SwiftUI

struct HomeView: View {
    @State private var difficulty: Difficulty = .normal
    @State private var simulated = false
    @State private var showGame = false
    @State private var showHowTo = false
    @Query(sort: \RunRecord.date, order: .reverse)
    private var records: [RunRecord]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.walkerBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        statsRow
                        difficultyPicker
                        simulationToggle
                        startButton
                        howToButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("WALKER")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showGame) {
                GameView(difficulty: difficulty, simulated: simulated)
            }
            .sheet(isPresented: $showHowTo) {
                HowToPlayView()
            }
            .onAppear {
                simulated = LocationService().shouldDefaultToSimulation
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "skull.fill")
                .font(.system(size: 56))
                .foregroundStyle(.bloodRed)
            Text("OUTRUN THE HORDE")
                .font(.headline)
                .foregroundStyle(.secondary)
                .tracking(3)
        }
        .padding(.top, 20)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell("Runs", "\(records.count)")
            statCell("Distance", Format.distance(records.reduce(0) { $0 + $1.distanceMeters }))
            statCell("Kills", "\(records.reduce(0) { $0 + $1.kills })")
        }
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .panel()
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Difficulty")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Difficulty", selection: $difficulty) {
                ForEach(Difficulty.allCases) { d in
                    Text(d.label).tag(d)
                }
            }
            .pickerStyle(.segmented)
        }
        .panel()
    }

    private var simulationToggle: some View {
        Toggle(isOn: $simulated) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Simulation mode")
                    .font(.subheadline)
                Text("Moves a virtual runner. No GPS needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.toxicGreen)
        .panel()
    }

    private var startButton: some View {
        Button {
            showGame = true
        } label: {
            Label("START RUN", systemImage: "figure.run")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.bloodRed, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var howToButton: some View {
        Button {
            showHowTo = true
        } label: {
            Label("How to play", systemImage: "questionmark.circle")
                .font(.subheadline)
        }
        .foregroundStyle(.secondary)
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    private let rules: [(String, String, String)] = [
        ("figure.run", "Head start", "You get a head start before the horde spawns behind you on the path you just ran. Keep moving — they follow your trail."),
        ("skull.fill", "Shoot", "Tap red skulls near you to shoot them. You start with only 3 bullets."),
        ("shippingbox.fill", "Ammo crates", "Pick up crates on your path to gain +3 bullets."),
        ("hourglass", "Hourglasses", "Grab an hourglass to slow the whole horde down for 30 seconds."),
        ("bolt.fill", "Charge", "Your charge meter fills as you run. Spend a full charge to SHOVE the horde back when they get close."),
        ("heart.slash.fill", "Caught", "If a zombie gets within 15m, you're done. Survive as long as you can."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(rules, id: \.1) { rule in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: rule.0)
                                .font(.title2)
                                .foregroundStyle(.bloodRed)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.1)
                                    .font(.headline)
                                Text(rule.2)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .panel()
                    }
                }
                .padding(20)
            }
            .background(Color.walkerBg)
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
