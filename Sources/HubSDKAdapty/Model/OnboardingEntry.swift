import Adapty
import AdaptyUI
import Foundation

// MARK: - OnboardingEntry

/// A container representing a fetched onboarding with its configuration.
///
/// This type encapsulates all data needed to present an Adapty onboarding,
/// including the raw onboarding object and its UI configuration.
///
/// ## Usage
///
/// ```swift
/// let entry = try await adapty.onboardingEntry(for: "onboarding_placement")
/// let controller = try entry.makeController(delegate: self)
/// present(controller, animated: true)
/// ```
public struct OnboardingEntry: Sendable {
    
    /// The placement identifier this onboarding was fetched from.
    public let placementId: String
    
    /// The raw Adapty onboarding object.
    public let onboarding: AdaptyOnboarding
    
    /// The UI configuration used to render the onboarding.
    public let configuration: AdaptyUI.OnboardingConfiguration
}
