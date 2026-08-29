import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class LocationService: NSObject, ObservableObject {
    var onLocation: ((CLLocation) -> Void)?

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isUpdating = false

    private let manager = CLLocationManager()
    private var simulation: SimulationService?
    private var lastRealLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    var shouldDefaultToSimulation: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    func start(simulated: Bool) {
        guard !isUpdating else { return }
        isUpdating = true
        if simulated {
            let sim = SimulationService()
            sim.onLocation = { [weak self] location in
                self?.onLocation?(location)
            }
            simulation = sim
            sim.start()
        } else {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                beginRealUpdates()
            default:
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    private func beginRealUpdates() {
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 2
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil,
           manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
        manager.startUpdatingLocation()
    }

    func pause() {
        simulation?.stop()
        manager.stopUpdatingLocation()
    }

    func resume() {
        guard isUpdating else { return }
        if simulation != nil {
            simulation?.start()
        } else {
            manager.startUpdatingLocation()
        }
    }

    func stop() {
        isUpdating = false
        simulation?.stop()
        simulation = nil
        manager.stopUpdatingLocation()
    }

    private func handle(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 100 else { return }
        lastRealLocation = location
        onLocation?(location)
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if self.isUpdating, status == .authorizedWhenInUse
                || status == .authorizedAlways {
                self.beginRealUpdates()
            }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locations.forEach { self.handle($0) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
