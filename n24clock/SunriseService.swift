import Combine
import CoreLocation
import Foundation

@MainActor
final class SunriseService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastKnownLocation: CLLocation?
    @Published private(set) var lastError: Error?

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 500
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        self.manager.delegate = self
    }

    func start() {
        requestAuthorizationIfNeeded()
        refreshLocationIfPossible()
    }

    func refreshLocationIfPossible() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func nextSunrise(after date: Date) -> Date? {
        guard let coordinate = lastKnownLocation?.coordinate else { return nil }
        return SunriseSunsetCalculator.nextSunrise(for: coordinate, from: date, timeZone: .current)
    }

    private func requestAuthorizationIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }
}

extension SunriseService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus.isAuthorizedForWhenInUse {
            refreshLocationIfPossible()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            lastKnownLocation = location
            lastError = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        lastError = error
    }
}

private extension CLAuthorizationStatus {
    var isAuthorizedForWhenInUse: Bool {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }
}

struct SunriseSunsetCalculator {
    static func nextSunrise(for coordinate: CLLocationCoordinate2D, from date: Date, timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if let sunriseToday = sunrise(for: coordinate, on: date, timeZone: timeZone), sunriseToday > date {
            return sunriseToday
        }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
        return sunrise(for: coordinate, on: tomorrow, timeZone: timeZone)
    }

    static func sunrise(for coordinate: CLLocationCoordinate2D, on date: Date, timeZone: TimeZone) -> Date? {
        solarEvent(for: coordinate, date: date, timeZone: timeZone, isSunrise: true)
    }

    static func sunset(for coordinate: CLLocationCoordinate2D, on date: Date, timeZone: TimeZone) -> Date? {
        solarEvent(for: coordinate, date: date, timeZone: timeZone, isSunrise: false)
    }

    private static func solarEvent(for coordinate: CLLocationCoordinate2D,
                                   date: Date,
                                   timeZone: TimeZone,
                                   isSunrise: Bool) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: date)
        guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: dayStart) else { return nil }

        let zenith = 90.833
        let lngHour = coordinate.longitude / 15.0
        let approxTime = Double(dayOfYear) + ((isSunrise ? 6.0 : 18.0) - lngHour) / 24.0
        let meanAnomaly = 0.9856 * approxTime - 3.289

        var trueLongitude = meanAnomaly
            + 1.916 * sin(meanAnomaly.degreesToRadians)
            + 0.020 * sin(2 * meanAnomaly.degreesToRadians)
            + 282.634
        trueLongitude = trueLongitude.normalizedDegrees

        var rightAscension = atan(0.91764 * tan(trueLongitude.degreesToRadians)).radiansToDegrees
        rightAscension = rightAscension.normalizedDegrees

        let rightAscensionQuadrant = floor(rightAscension / 90.0)
        let longitudeQuadrant = floor(trueLongitude / 90.0)
        rightAscension += (longitudeQuadrant - rightAscensionQuadrant) * 90.0
        rightAscension /= 15.0

        let sinDeclination = 0.39782 * sin(trueLongitude.degreesToRadians)
        let cosDeclination = cos(asin(sinDeclination))
        let cosHourAngleNumerator = cos(zenith.degreesToRadians) - sinDeclination * sin(coordinate.latitude.degreesToRadians)
        let cosHourAngleDenominator = cosDeclination * cos(coordinate.latitude.degreesToRadians)
        let cosHourAngle = cosHourAngleNumerator / cosHourAngleDenominator

        guard (-1)...1 ~= cosHourAngle else { return nil }

        var hourAngle = acos(cosHourAngle).radiansToDegrees
        hourAngle = isSunrise ? (360.0 - hourAngle) : hourAngle
        hourAngle /= 15.0

        let localMeanTime = hourAngle + rightAscension - 0.06571 * approxTime - 6.622
        var universalTime = localMeanTime - lngHour
        universalTime = universalTime.normalizedHours

        let timeZoneOffsetHours = Double(timeZone.secondsFromGMT(for: dayStart)) / 3600.0
        var localHours = universalTime + timeZoneOffsetHours
        var dayOffset = 0
        while localHours < 0 { localHours += 24; dayOffset -= 1 }
        while localHours >= 24 { localHours -= 24; dayOffset += 1 }

        guard let adjustedDay = calendar.date(byAdding: .day, value: dayOffset, to: dayStart) else { return nil }
        let seconds = localHours * 3600
        return adjustedDay.addingTimeInterval(seconds)
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
    var normalizedDegrees: Double {
        var value = self.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }
    var normalizedHours: Double {
        var value = self.truncatingRemainder(dividingBy: 24)
        if value < 0 { value += 24 }
        return value
    }
}
