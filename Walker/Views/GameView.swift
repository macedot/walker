import MapKit
import SwiftData
import SwiftUI

struct GameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var engine: GameEngine
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var followPlayer = true
    @State private var saved = false

    private let locationService = LocationService()

    init(difficulty: Difficulty, simulated: Bool) {
        let engine = GameEngine(difficulty: difficulty)
        engine.isSimulated = simulated
        _engine = State(initialValue: engine)
    }

    var body: some View {
        ZStack {
            map
            hudOverlay
            if engine.phase == .headStart {
                HeadStartOverlay(seconds: engine.headStartRemaining)
            }
            if engine.phase == .paused {
                pauseOverlay
            }
            if let result = engine.result {
                GameOverView(result: result, onRetry: {
                    saved = false
                    engine.restart(difficulty: result.difficulty, simulated: engine.isSimulated)
                }, onHome: {
                    dismiss()
                })
                .transition(.opacity)
            }
        }
        .background(Color.walkerBg)
        .onAppear {
            engine.attach(locationService)
            engine.start()
        }
        .onDisappear {
            if engine.result == nil {
                engine.endRun()
            }
        }
        .onChange(of: engine.playerCoord) { _, coord in
            guard followPlayer, engine.hasPosition else { return }
            camera = .camera(MapCamera(centerCoordinate: coord, distance: 320))
        }
        .onChange(of: engine.lastEvent) { _, event in
            if let event {
                AudioService.shared.play(event)
            }
        }
        .onChange(of: engine.result) { oldValue, newValue in
            if newValue != nil, !saved, let result = newValue {
                saved = true
                modelContext.insert(RunRecord(
                    date: result.date,
                    survived: result.survived,
                    duration: result.duration,
                    distanceMeters: result.distanceMeters,
                    kills: result.kills,
                    difficulty: result.difficulty
                ))
            }
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: [.pan, .zoom]) {
                MapPolyline(coordinates: engine.trail.map(\.coordinate))
                    .stroke(.bloodRed.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                if engine.hasPosition {
                    Annotation("", coordinate: engine.playerCoord) {
                        PlayerMarker()
                    }
                }
                ForEach(engine.zombies) { zombie in
                    Annotation("", coordinate: zombie.coordinate(in: engine)) {
                        ZombieMarker()
                    }
                }
                ForEach(engine.pickups) { pickup in
                    Annotation("", coordinate: pickup.coordinate) {
                        PickupMarker(kind: pickup.kind)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .including([]), showsTraffic: false))
            .mapControlVisibility(.hidden)
            .ignoresSafeArea()
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard let coord = proxy.convert(value.location, from: .global) else { return }
                        engine.shoot(at: coord)
                        if !engine.lastShotHit {
                            AudioService.shared.shotMissed()
                        }
                    }
            )
        }
    }

    private var hudOverlay: some View {
        VStack {
            topBar
            hordeIndicator
                .padding(.top, 8)
            Spacer()
            if engine.phase == .running {
                shoveButton
                    .padding(.bottom, 8)
            }
            bottomBar
        }
        .padding(16)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            hudCell(icon: "timer", value: Format.duration(engine.elapsed))
            hudCell(icon: "point.topleft.down.curvedto.point.bottomright.up", value: Format.distance(engine.totalDistance))
            hudCell(icon: "speedometer", value: Format.pace(meters: engine.totalDistance, seconds: engine.elapsed))
            Button {
                withAnimation {
                    followPlayer = true
                }
            } label: {
                Image(systemName: followPlayer ? "location.fill" : "location.slash")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func hudCell(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var hordeIndicator: some View {
        if engine.phase == .running, let nearest = engine.nearestZombieDistance {
            let danger = nearest < 60
            HStack(spacing: 8) {
                Image(systemName: "skull.fill")
                Text("HORDE \(Int(max(0, nearest)))m")
                    .monospacedDigit()
                if Date() < (engine.slowUntil ?? .distantPast) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(.amberWarn)
                }
            }
            .font(.callout.weight(.bold))
            .foregroundStyle(danger ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background((danger ? Color.bloodRed : Color.walkerPanel).opacity(0.9), in: Capsule())
            .overlay(Capsule().strokeBorder(danger ? Color.white.opacity(0.4) : Color.walkerPanelStroke))
            .symbolEffect(.pulse, options: .repeating, isActive: danger)
            .animation(.easeInOut(duration: 0.3), value: danger)
        }
    }

    private var shoveButton: some View {
        VStack(spacing: 6) {
            Button {
                engine.shove()
            } label: {
                Image(systemName: "wind")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(
                        engine.canShove ? Color.toxicGreen : Color.walkerPanel.opacity(0.85),
                        in: Circle()
                    )
                    .overlay(Circle().strokeBorder(Color.walkerPanelStroke))
            }
            .disabled(!engine.canShove)
            .symbolEffect(.bounce, options: .repeating, value: engine.canShove)

            ChargeMeter(charge: engine.charge)
                .frame(width: 120, height: 10)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            BulletCounter(bullets: engine.bullets)
                .panel()
            Button {
                withAnimation {
                    engine.togglePause()
                }
            } label: {
                Image(systemName: engine.phase == .paused ? "play.fill" : "pause.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("pauseToggle")
            Button {
                engine.endRun()
            } label: {
                Text("END")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 52)
                    .background(Color.bloodRed, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                Text("PAUSED")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .tracking(4)
                Text("The horde is waiting...")
                    .foregroundStyle(.secondary)
                Button("Resume") {
                    withAnimation {
                        engine.togglePause()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct PlayerMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.25))
                .frame(width: 34, height: 34)
            Image(systemName: "figure.run")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .padding(6)
                .background(Color.cyan, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .cyan.opacity(0.7), radius: 6)
        }
        .symbolEffect(.pulse, options: .repeating)
    }
}

private struct ZombieMarker: View {
    var body: some View {
        Image(systemName: "skull.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(Color.bloodRed, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
            .shadow(color: .bloodRed.opacity(0.6), radius: 6)
            .symbolEffect(.pulse, options: .repeating)
    }
}

private struct PickupMarker: View {
    let kind: PickupKind

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(7)
            .background(color, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.5)))
            .shadow(radius: 4)
    }

    private var icon: String {
        switch kind {
        case .ammo: "shippingbox.fill"
        case .hourglass: "hourglass"
        }
    }

    private var color: Color {
        switch kind {
        case .ammo: .brown
        case .hourglass: .amberWarn
        }
    }
}

private struct BulletCounter: View {
    let bullets: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                ForEach(0..<max(bullets, 1), id: \.self) { _ in
                    Capsule()
                        .fill(Color.amberWarn)
                        .frame(width: 5, height: 18)
                }
                if bullets == 0 {
                    Text("EMPTY")
                        .font(.caption2.bold())
                        .foregroundStyle(.bloodRed)
                }
            }
            Text("\(bullets)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct ChargeMeter: View {
    let charge: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.walkerPanel.opacity(0.9))
                Capsule()
                    .fill(charge >= 100 ? Color.toxicGreen : Color.amberWarn)
                    .frame(width: max(6, geo.size.width * charge / 100))
                Text(charge >= 100 ? "SHOVE READY" : "CHARGE \(Int(charge))%")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
        }
        .overlay(Capsule().strokeBorder(Color.walkerPanelStroke))
        .animation(.easeInOut(duration: 0.2), value: charge)
    }
}

private struct HeadStartOverlay: View {
    let seconds: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("HEAD START")
                    .font(.title3.bold())
                    .tracking(6)
                    .foregroundStyle(.white)
                Text("\(Int(ceil(seconds)))")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .foregroundStyle(.bloodRed)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("The horde spawns where you've been.\nDon't stop running.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .allowsHitTesting(false)
    }
}
