import CoreLocation
import Foundation

@MainActor
final class SimulationService {
    var onLocation: ((CLLocation) -> Void)?

    private var task: Task<Void, Never>?
    private var t: Double = 0
    private var lat = 37.3346
    private var lon = -122.0090

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.step()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func step() {
        t += 1
        let heading = 0.7 * sin(t * 0.11) + 0.5 * sin(t * 0.037) + 0.3 * sin(t * 0.53)
        let speed = 3.0 + 0.5 * sin(t * 0.4)
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = 111_320.0 * cos(lat * .pi / 180)
        lat += speed * cos(heading) / metersPerDegLat
        lon += speed * sin(heading) / metersPerDegLon
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: 10,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: heading * 180 / .pi,
            speed: speed,
            timestamp: Date()
        )
        onLocation?(location)
    }
}
