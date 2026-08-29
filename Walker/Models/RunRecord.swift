import Foundation
import SwiftData

@Model
final class RunRecord {
    var date: Date
    var survived: Bool
    var duration: TimeInterval
    var distanceMeters: Double
    var kills: Int
    var difficultyRaw: String

    var difficulty: Difficulty {
        get { Difficulty(rawValue: difficultyRaw) ?? .normal }
        set { difficultyRaw = newValue.rawValue }
    }

    init(date: Date, survived: Bool, duration: TimeInterval, distanceMeters: Double, kills: Int, difficulty: Difficulty) {
        self.date = date
        self.survived = survived
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.kills = kills
        self.difficultyRaw = difficulty.rawValue
    }
}
