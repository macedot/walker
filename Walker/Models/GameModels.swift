import CoreLocation
import MapKit

enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: "Jogger"
        case .normal: "Runner"
        case .hard: "Survivor"
        }
    }

    var zombieSpeed: Double {
        switch self {
        case .easy: 2.0
        case .normal: 2.4
        case .hard: 2.8
        }
    }

    var hordeSize: Int {
        switch self {
        case .easy: 4
        case .normal: 6
        case .hard: 8
        }
    }

    var headStart: TimeInterval {
        switch self {
        case .easy: 75
        case .normal: 60
        case .hard: 50
        }
    }

    var trickleInterval: TimeInterval {
        switch self {
        case .easy: 50
        case .normal: 35
        case .hard: 25
        }
    }
}

enum PickupKind: String, Codable, Identifiable {
    case ammo
    case hourglass

    var id: String { rawValue }
}

struct TrailPoint {
    var coordinate: CLLocationCoordinate2D
    var cumDist: Double
}

final class Zombie: Identifiable {
    let id = UUID()
    var progress: Double
    var stunnedUntil: Date?

    init(progress: Double) {
        self.progress = progress
    }
}

struct Pickup: Identifiable {
    let id = UUID()
    let kind: PickupKind
    let coordinate: CLLocationCoordinate2D
}

enum GamePhase: Equatable {
    case idle
    case headStart
    case running
    case paused
    case over
}

struct RunResult: Equatable {
    var survived: Bool
    var duration: TimeInterval
    var distanceMeters: Double
    var kills: Int
    var difficulty: Difficulty
    var date: Date
}

struct Geo {
    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        MKMapPoint(a).distance(to: MKMapPoint(b))
    }

    static func interpolate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ f: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * f,
            longitude: a.longitude + (b.longitude - a.longitude) * f
        )
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
