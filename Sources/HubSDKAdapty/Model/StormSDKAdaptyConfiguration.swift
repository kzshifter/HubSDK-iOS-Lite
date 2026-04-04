import Adapty
import Foundation

// MARK: - HubSDKAdaptyConfiguration

public struct HubSDKAdaptyConfiguration: Sendable {

    let apiKey: String
    let placementIdentifers: [String]
    let accessLevels: [AccessLevel]
    let logLevel: AdaptyLog.Level?
    let chinaClusterEnable: Bool
    let fallbackName: String?
    let languageCode: String

    public init(
        apiKey: String,
        placementIdentifers: [String],
        accessLevels: [AccessLevel],
        logLevel: AdaptyLog.Level? = nil,
        chinaClusterEnable: Bool = true,
        fallbackName: String? = nil,
        languageCode: String = Locale.current.languageCode ?? "en"
    ) {
        self.apiKey = apiKey
        self.placementIdentifers = placementIdentifers
        self.accessLevels = accessLevels
        self.chinaClusterEnable = chinaClusterEnable
        self.logLevel = logLevel
        self.fallbackName = fallbackName
        self.languageCode = languageCode
    }
}

@available(*, deprecated, renamed: "HubSDKAdaptyConfiguration")
public typealias StormSDKAdaptyConfiguration = HubSDKAdaptyConfiguration
