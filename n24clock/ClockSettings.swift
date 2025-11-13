import Foundation
import Combine

final class ClockSettings: ObservableObject {
    private let storageKey = "BiologicalClockParameters"
    private var isNormalizingParameters = false

    @Published var parameters: BiologicalClockParameters? {
        didSet {
            guard !isNormalizingParameters else {
                persist()
                return
            }

            if let params = parameters {
                let normalized = params.ensuringSleepPreferences()
                if normalized != params {
                    isNormalizingParameters = true
                    parameters = normalized
                    isNormalizingParameters = false
                    return
                }
            }

            persist()
        }
    }

    init() {
        parameters = Self.load(from: storageKey)
    }

    func reset() {
        parameters = nil
    }

    private func persist() {
        guard let parameters else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }

        if let data = try? JSONEncoder().encode(parameters) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func load(from key: String) -> BiologicalClockParameters? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        guard let decoded = try? JSONDecoder().decode(BiologicalClockParameters.self, from: data) else { return nil }
        return decoded.ensuringSleepPreferences()
    }
}
