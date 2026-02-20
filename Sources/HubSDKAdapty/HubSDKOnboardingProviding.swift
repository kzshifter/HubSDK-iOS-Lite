import Adapty
import AdaptyUI
import Foundation
import HubIntegrationCore
import UIKit

// MARK: - HubSDKAdaptyProviding + Onboarding

/// Extension adding onboarding fetch and presentation capabilities to the protocol.
///
/// All methods follow the same patterns as existing placement/paywall methods:
/// - Async/await as primary API
/// - Synchronous access via cached snapshot
/// - Completion handler variants for UIKit compatibility
public extension HubSDKAdaptyProviding {
    // Default implementations are intentionally left out of the protocol extension
    // to enforce implementation in the conforming actor.
}

/// Protocol methods for onboarding support.
///
/// Add these to `HubSDKAdaptyProviding` when ready to merge.
public protocol HubSDKOnboardingProviding: Sendable {
    
    // MARK: Onboarding Fetch (Async)
    
    /// Fetches an onboarding and its UI configuration for the given placement.
    ///
    /// This method performs two sequential calls:
    /// 1. `Adapty.getOnboarding(placementId:)` to fetch the onboarding data.
    /// 2. `AdaptyUI.getOnboardingConfiguration(forOnboarding:)` to prepare the UI config.
    ///
    /// For best performance, call this early to give images time to download.
    ///
    /// - Parameters:
    ///   - placementId: The placement identifier from the Adapty Dashboard.
    ///   - locale: Optional locale code (e.g., `"en"`, `"pt-br"`). Defaults to SDK config's `languageCode`.
    /// - Returns: An `OnboardingEntry` containing the onboarding and its configuration.
    /// - Throws: `HubSDKError.notInitialized` if SDK is not ready.
    /// - Throws: `HubSDKError.onboardingFetchFailed` if fetching fails.
    /// - Throws: `HubSDKError.onboardingConfigurationFailed` if UI config creation fails.
    func onboardingEntry(
        for placementId: String,
        locale: String?
    ) async throws -> OnboardingEntry
    
    /// Fetches an onboarding for the default audience (All Users).
    ///
    /// Use this for faster loading when personalization is not needed.
    /// See Adapty docs for limitations of `getOnboardingForDefaultAudience`.
    ///
    /// - Parameters:
    ///   - placementId: The placement identifier.
    ///   - locale: Optional locale code. Defaults to SDK config's `languageCode`.
    /// - Returns: An `OnboardingEntry` for the default audience.
    /// - Throws: `HubSDKError.notInitialized` if SDK is not ready.
    func onboardingEntryForDefaultAudience(
        for placementId: String,
        locale: String?
    ) async throws -> OnboardingEntry
    
    // MARK: Onboarding Presentation (UIKit)
    
    /// Creates an `AdaptyOnboardingController` ready for presentation.
    ///
    /// This is a convenience method that combines fetching and controller creation.
    ///
    /// - Parameters:
    ///   - placementId: The placement identifier.
    ///   - delegate: The delegate to receive onboarding events.
    ///   - locale: Optional locale code.
    /// - Returns: A configured `AdaptyOnboardingController`.
    /// - Throws: `HubSDKError` if fetching or configuration fails.
    @MainActor
    func onboardingController(
        for placementId: String,
        delegate: AdaptyOnboardingControllerDelegate,
        locale: String?
    ) async throws -> AdaptyOnboardingController
    
    /// Creates an `AdaptyOnboardingController` with a closure-based action handler.
    ///
    /// Uses `OnboardingDelegateProxy` internally for simplified event handling.
    ///
    /// - Parameters:
    ///   - placementId: The placement identifier.
    ///   - locale: Optional locale code.
    ///   - placeholder: Optional closure providing a loading placeholder view.
    ///   - onAction: Closure called for each onboarding action.
    /// - Returns: A tuple of the controller and its delegate proxy (retain the proxy!).
    /// - Throws: `HubSDKError` if fetching or configuration fails.
    @MainActor
    func onboardingController(
        for placementId: String,
        locale: String?,
        placeholder: (@MainActor @Sendable () -> UIView?)?,
        onAction: @MainActor @Sendable @escaping (OnboardingAction) -> Void
    ) async throws -> (AdaptyOnboardingController, OnboardingDelegateProxy)
    
    // MARK: Completion Handler Variants
    
    /// Fetches an onboarding entry with a completion handler.
    ///
    /// - Parameters:
    ///   - placementId: The placement identifier.
    ///   - locale: Optional locale code.
    ///   - completion: Called on the main thread with the result.
    func onboardingEntry(
        for placementId: String,
        locale: String?,
        completion: @MainActor @Sendable @escaping (Result<OnboardingEntry, Error>) -> Void
    )
}

// MARK: - Default Parameter Values

public extension HubSDKOnboardingProviding {
    
    func onboardingEntry(for placementId: String) async throws -> OnboardingEntry {
        try await onboardingEntry(for: placementId, locale: nil)
    }
    
    func onboardingEntryForDefaultAudience(for placementId: String) async throws -> OnboardingEntry {
        try await onboardingEntryForDefaultAudience(for: placementId, locale: nil)
    }
    
    @MainActor
    func onboardingController(
        for placementId: String,
        delegate: AdaptyOnboardingControllerDelegate
    ) async throws -> AdaptyOnboardingController {
        try await onboardingController(for: placementId, delegate: delegate, locale: nil)
    }
    
    @MainActor
    func onboardingController(
        for placementId: String,
        onAction: @MainActor @Sendable @escaping (OnboardingAction) -> Void
    ) async throws -> (AdaptyOnboardingController, OnboardingDelegateProxy) {
        try await onboardingController(for: placementId, locale: nil, placeholder: nil, onAction: onAction)
    }
    
    func onboardingEntry(
        for placementId: String,
        completion: @MainActor @Sendable @escaping (Result<OnboardingEntry, Error>) -> Void
    ) {
        onboardingEntry(for: placementId, locale: nil, completion: completion)
    }
}
