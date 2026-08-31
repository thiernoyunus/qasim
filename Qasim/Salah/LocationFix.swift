import CoreLocation
import Foundation

@MainActor
final class LocationFix: NSObject, CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var placeName = ""
    var status = "Waiting for location"
    var denied = false

    var onChange: (() -> Void)?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        denied = false
        status = "Finding you…"
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            denied = true
            status = "Location is off. Turn it on in System Settings → Privacy → Location Services."
            onChange?()
        default:
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let spot = locations.last else { return }
        let coord = spot.coordinate
        Task { @MainActor in
            self.coordinate = coord
            self.status = "Got your location"
            self.reverse(spot)
            self.onChange?()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if self.coordinate == nil {
                self.status = "Couldn't find you. Try again."
            }
            self.onChange?()
        }
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            denied = true
            self.status = "Location is off. Pick a city or type your masjid times."
            onChange?()
        case .notDetermined:
            break
        default:
            denied = false
            manager.requestLocation()
        }
    }

    private func reverse(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] marks, _ in
            Task { @MainActor in
                guard let self else { return }
                if let mark = marks?.first {
                    let city = mark.locality ?? mark.subAdministrativeArea ?? mark.administrativeArea
                    let bits = [city, mark.administrativeArea].compactMap { $0 }
                    if !bits.isEmpty {
                        self.placeName = bits.joined(separator: ", ")
                        self.status = "Times for \(self.placeName)"
                    }
                }
                self.onChange?()
            }
        }
    }
}
