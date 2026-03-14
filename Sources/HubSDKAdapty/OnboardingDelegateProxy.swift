import Adapty
import AdaptyUI
import UIKit

// MARK: - OnboardingAction

/// Represents all possible actions from an Adapty onboarding flow.
///
/// Use this enum in your action handler to respond to user interactions
/// within the onboarding screens.
public enum OnboardingAction: Sendable {
    
    /// The user tapped a button with the "Close" action.
    case close(AdaptyOnboardingsCloseAction)
    
    /// The user tapped a button with a custom action ID.
    case custom(AdaptyOnboardingsCustomAction)
    
    /// The user tapped a button that opens a paywall.
    /// The `actionId` typically corresponds to a paywall placement ID.
    case openPaywall(AdaptyOnboardingsOpenPaywallAction)
    
    /// The user interacted with an input element (quiz, text field, date picker).
    case stateUpdated(AdaptyOnboardingsStateUpdatedAction)
    
    /// The onboarding finished loading and is ready for display.
    case didFinishLoading
    
    /// An analytics event occurred during the onboarding flow.
    case analytics(AdaptyOnboardingsAnalyticsEvent)
    
    /// An error occurred while presenting the onboarding.
    case error(AdaptyUIError)
}

// MARK: - OnboardingDelegateProxy

/// A delegate proxy that bridges `AdaptyOnboardingControllerDelegate` callbacks
/// into a single closure-based API.
///
/// This class simplifies onboarding event handling by routing all delegate methods
/// through a unified `OnboardingAction` handler and an optional placeholder provider.
///
/// ## Example
///
/// ```swift
/// let proxy = OnboardingDelegateProxy(
///     onAction: { action in
///         switch action {
///         case .close:
///             dismiss(animated: true)
///         case .openPaywall(let paywallAction):
///             openPaywall(placementId: paywallAction.actionId)
///         default:
///             break
///         }
///     },
///     placeholder: {
///         let view = UIView()
///         view.backgroundColor = .black
///         return view
///     }
/// )
/// ```
public final class OnboardingDelegateProxy: NSObject, AdaptyOnboardingControllerDelegate, @unchecked Sendable {
    
    /// The closure invoked for every onboarding action.
    public let onAction: @MainActor @Sendable (OnboardingAction) -> Void
    
    /// An optional closure that provides a placeholder view while the onboarding loads.
    public let placeholder: (@MainActor @Sendable () -> UIView?)?
    
    /// Creates a new delegate proxy.
    ///
    /// - Parameters:
    ///   - onAction: A closure called on the main thread for every onboarding event.
    ///   - placeholder: An optional closure returning a view to display during loading.
    public init(
        onAction: @MainActor @Sendable @escaping (OnboardingAction) -> Void,
        placeholder: (@MainActor @Sendable () -> UIView?)? = nil
    ) {
        self.onAction = onAction
        self.placeholder = placeholder
    }
    
    // MARK: - AdaptyOnboardingControllerDelegate
    
    public func onboardingController(
        _ controller: AdaptyOnboardingController,
        onCloseAction action: AdaptyOnboardingsCloseAction
    ) {
        Task { @MainActor in onAction(.close(action)) }
    }
    
    public func onboardingController(
        _ controller: AdaptyOnboardingController,
        onCustomAction action: AdaptyOnboardingsCustomAction
    ) {
        Task { @MainActor in onAction(.custom(action)) }
    }
    
    public func onboardingController(
        _ controller: AdaptyOnboardingController,
        onPaywallAction action: AdaptyOnboardingsOpenPaywallAction
    ) {
        Task { @MainActor in onAction(.openPaywall(action)) }
    }
    
    public func onboardingController(
        _ controller: AdaptyOnboardingController,
        onStateUpdatedAction action: AdaptyOnboardingsStateUpdatedAction
    ) {
        Task { @MainActor in onAction(.stateUpdated(action)) }
    }
    
    public func onboardingController(
        _ controller: AdaptyOnboardingController,
        didFinishLoading action: OnboardingsDidFinishLoadingAction
    ) {
        Task { @MainActor in onAction(.didFinishLoading) }
    }
    
    public func onboardingController(
        _ controller: AdaptyOnboardingController,
        onAnalyticsEvent event: AdaptyOnboardingsAnalyticsEvent
    ) {
        Task { @MainActor in onAction(.analytics(event)) }
    }
    
    public func onboardingController(
        _ controller: AdaptyOnboardingController,
        didFailWithError error: AdaptyUIError
    ) {
        Task { @MainActor in onAction(.error(error)) }
    }
    
    public func onboardingsControllerLoadingPlaceholder(
        _ controller: AdaptyOnboardingController
    ) -> UIView? {
        // Synchronous call — placeholder must return immediately
        if let placeholder {
            return MainActor.assumeIsolated { placeholder() }
        }
        return nil
    }
}
