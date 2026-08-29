import AudioToolbox
import SwiftUI
import UIKit

@MainActor
final class AudioService {
    static let shared = AudioService()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    func play(_ event: GameEngine.GameEvent) {
        switch event {
        case .zombieKilled:
            impactHeavy.impactOccurred()
            AudioServicesPlaySystemSound(1104)
        case .ammoCollected:
            impactLight.impactOccurred()
            AudioServicesPlaySystemSound(1117)
        case .hourglassCollected:
            impactLight.impactOccurred()
            AudioServicesPlaySystemSound(1114)
        case .shoved:
            impactHeavy.impactOccurred()
            AudioServicesPlaySystemSound(1102)
        case .hordeSpawned:
            notification.notificationOccurred(.warning)
            AudioServicesPlaySystemSound(1050)
        case .caught:
            notification.notificationOccurred(.error)
            AudioServicesPlaySystemSound(1053)
        }
    }

    func shotMissed() {
        impactLight.impactOccurred()
        AudioServicesPlaySystemSound(1103)
    }

    func heartbeat() {
        impactLight.impactOccurred()
    }
}
