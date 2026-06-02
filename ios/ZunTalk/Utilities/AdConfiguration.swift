import Foundation

enum AdConfiguration {
    static var bannerAdUnitID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_AD_UNIT_ID") as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
