import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class GameEngine {
    let config: Difficulty

    private(set) var phase: GamePhase = .idle
    private(set) var playerCoord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    private(set) var hasPosition = false
    private(set) var trail: [TrailPoint] = []
    private(set) var totalDistance: Double = 0
    private(set) var zombies: [Zombie] = []
    private(set) var pickups: [Pickup] = []
    private(set) var bullets = 3
    private(set) var kills = 0
    private(set) var charge = 0.0
    private(set) var slowUntil: Date?
    private(set) var elapsed: TimeInterval = 0
    private(set) var headStartRemaining: TimeInterval = 0
    private(set) var nearestZombieDistance: Double?
    private(set) var result: RunResult?
    private(set) var lastShotHit = false
    private(set) var lastEvent: GameEvent?

    var isSimulated = false

    private var locationService: LocationService?
    private var tickTimer: Timer?
    private var lastTick: Date?
    private var trickleNext: TimeInterval = 0
    private var pickupNext: TimeInterval = 0

    private enum Tuning {
        static let trailMinStep: Double = 2
        static let catchRadius: Double = 15
        static let shootRange: Double = 130
        static let tapRadius: Double = 30
        static let pickupRadius: Double = 15
        static let pickupSpawnInterval: TimeInterval = 40
        static let maxPickups = 3
        static let maxBullets = 9
        static let shovePushBack: Double = 80
        static let shoveStun: TimeInterval = 5
        static let slowFactor = 0.5
        static let slowDuration: TimeInterval = 30
        static let chargePerMeter = 0.2
        static let maxZombies = 15
    }

    enum GameEvent: Equatable {
        case zombieKilled
        case ammoCollected
        case hourglassCollected
        case shoved
        case hordeSpawned
        case caught
    }

    init(difficulty: Difficulty) {
        config = difficulty
        headStartRemaining = difficulty.headStart
    }

    func attach(_ service: LocationService) {
        locationService = service
        service.onLocation = { [weak self] location in
            self?.handleLocation(location)
        }
    }

    func start() {
        guard phase == .idle else { return }
        phase = .headStart
        locationService?.start(simulated: isSimulated)
        startTicking()
    }

    func togglePause() {
        switch phase {
        case .running, .headStart:
            phase = .paused
            tickTimer?.invalidate()
            tickTimer = nil
            locationService?.pause()
        case .paused:
            phase = trail.count < 2 ? .headStart : .running
            locationService?.resume()
            lastTick = nil
            startTicking()
        default:
            break
        }
    }

    func endRun() {
        guard phase != .over else { return }
        finish(survived: true)
    }

    func shoot(at coordinate: CLLocationCoordinate2D) {
        guard phase == .running, bullets > 0 else { return }
        guard let target = zombies
            .filter({ Geo.distance(playerCoord, $0.coordinate(in: self)) <= Tuning.shootRange })
            .min(by: { Geo.distance(coordinate, $0.coordinate(in: self)) < Geo.distance(coordinate, $1.coordinate(in: self)) }),
            Geo.distance(coordinate, target.coordinate(in: self)) <= Tuning.tapRadius
        else {
            bullets -= 1
            lastShotHit = false
            return
        }
        zombies.removeAll { $0.id == target.id }
        bullets -= 1
        kills += 1
        lastShotHit = true
        lastEvent = .zombieKilled
    }

    var canShove: Bool {
        phase == .running && charge >= 100
    }

    func shove() {
        guard canShove else { return }
        charge = 0
        let now = Date()
        for zombie in zombies {
            zombie.progress = max(0, zombie.progress - Tuning.shovePushBack)
            zombie.stunnedUntil = now.addingTimeInterval(Tuning.shoveStun)
        }
        lastEvent = .shoved
    }

    func restart(difficulty: Difficulty? = nil, simulated: Bool) {
        tickTimer?.invalidate()
        tickTimer = nil
        locationService?.stop()
        resetInternalState()
        start()
    }

    private func resetInternalState() {
        phase = .idle
        trail = []
        totalDistance = 0
        zombies = []
        pickups = []
        bullets = 3
        kills = 0
        charge = 0
        slowUntil = nil
        elapsed = 0
        headStartRemaining = config.headStart
        nearestZombieDistance = nil
        result = nil
        lastEvent = nil
        lastTick = nil
        trickleNext = 0
        pickupNext = 0
    }

    private func startTicking() {
        lastTick = nil
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func tick() {
        guard phase == .running || phase == .headStart else { return }
        let now = Date()
        let dt = lastTick.map { now.timeIntervalSince($0) } ?? 0.25
        lastTick = now
        elapsed += dt

        if phase == .headStart {
            headStartRemaining = max(0, config.headStart - elapsed)
            if headStartRemaining <= 0 {
                spawnHorde()
                phase = .running
            }
            return
        }

        advanceZombies(dt: dt, now: now)
        checkCatch()
        spawnTrickle()
        spawnPickups(now: now)
        collectPickups()
    }

    private func handleLocation(_ location: CLLocation) {
        guard phase == .headStart || phase == .running || phase == .idle else { return }
        let coordinate = location.coordinate
        playerCoord = coordinate
        hasPosition = true

        if let last = trail.last {
            let d = Geo.distance(last.coordinate, coordinate)
            guard d >= Tuning.trailMinStep else { return }
            totalDistance = last.cumDist + d
            trail.append(TrailPoint(coordinate: coordinate, cumDist: totalDistance))
            charge = min(100, charge + d * Tuning.chargePerMeter)
        } else {
            totalDistance = 0
            trail.append(TrailPoint(coordinate: coordinate, cumDist: 0))
        }
    }

    private func spawnHorde() {
        guard !trail.isEmpty else { return }
        let base = max(0, totalDistance - 30)
        for i in 0..<config.hordeSize {
            let behind = 30 + Double(i) * 25 + Double.random(in: 0..<20)
            zombies.append(Zombie(progress: max(0, base - behind)))
        }
        trickleNext = elapsed + config.trickleInterval
        pickupNext = elapsed + 15
        lastEvent = .hordeSpawned
    }

    private func advanceZombies(dt: TimeInterval, now: Date) {
        let slowActive = now < (slowUntil ?? .distantPast)
        let factor = slowActive ? Tuning.slowFactor : 1
        for zombie in zombies {
            if now < (zombie.stunnedUntil ?? .distantPast) { continue }
            zombie.progress += config.zombieSpeed * factor * dt
        }
        zombies.sort { $0.progress > $1.progress }
        nearestZombieDistance = zombies.first.map { totalDistance - $0.progress }
    }

    private func checkCatch() {
        if let nearest = nearestZombieDistance, nearest <= Tuning.catchRadius {
            lastEvent = .caught
            finish(survived: false)
        }
    }

    private func spawnTrickle() {
        guard elapsed >= trickleNext, zombies.count < Tuning.maxZombies else { return }
        trickleNext = elapsed + config.trickleInterval
        zombies.append(Zombie(progress: 0))
    }

    private func spawnPickups(now: Date) {
        guard elapsed >= pickupNext, pickups.count < Tuning.maxPickups else { return }
        pickupNext = elapsed + Tuning.pickupSpawnInterval
        guard trail.count >= 2 else { return }
        let a = trail[trail.count - 2].coordinate
        let b = trail[trail.count - 1].coordinate
        guard Geo.distance(a, b) >= 10 else { return }
        let aheadDistance = 30 + Double.random(in: 0..<40)
        let bearing = atan2(b.longitude - a.longitude, b.latitude - a.latitude)
        let dLat = aheadDistance * cos(bearing) / 111_320
        let dLon = aheadDistance * sin(bearing) / (111_320 * cos(b.latitude * .pi / 180))
        let coord = CLLocationCoordinate2D(latitude: b.latitude + dLat, longitude: b.longitude + dLon)
        let kind: PickupKind = bullets <= 3 ? .ammo : (Bool.random() ? .ammo : .hourglass)
        pickups.append(Pickup(kind: kind, coordinate: coord))
    }

    private func collectPickups() {
        guard !pickups.isEmpty else { return }
        var collected: [Pickup] = []
        pickups.removeAll { pickup in
            if Geo.distance(playerCoord, pickup.coordinate) <= Tuning.pickupRadius {
                collected.append(pickup)
                return true
            }
            return false
        }
        for pickup in collected {
            switch pickup.kind {
            case .ammo:
                bullets = min(Tuning.maxBullets, bullets + 3)
                lastEvent = .ammoCollected
            case .hourglass:
                slowUntil = Date().addingTimeInterval(Tuning.slowDuration)
                lastEvent = .hourglassCollected
            }
        }
    }

    private func finish(survived: Bool) {
        guard phase != .over else { return }
        phase = .over
        tickTimer?.invalidate()
        tickTimer = nil
        locationService?.stop()
        result = RunResult(
            survived: survived,
            duration: elapsed,
            distanceMeters: totalDistance,
            kills: kills,
            difficulty: config,
            date: Date()
        )
    }
}

@MainActor
extension Zombie {
    func coordinate(in engine: GameEngine) -> CLLocationCoordinate2D {
        engine.coordinate(at: progress)
    }
}

extension GameEngine {
    func coordinate(at progress: Double) -> CLLocationCoordinate2D {
        guard trail.count >= 2 else { return playerCoord }
        let target = min(max(progress, 0), totalDistance)
        guard target < totalDistance else { return playerCoord }
        var lo = 0
        var hi = trail.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if trail[mid].cumDist <= target {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        let a = trail[lo]
        let b = trail[min(lo + 1, trail.count - 1)]
        let seg = b.cumDist - a.cumDist
        let f = seg > 0 ? (target - a.cumDist) / seg : 0
        return Geo.interpolate(a.coordinate, b.coordinate, f)
    }
}
