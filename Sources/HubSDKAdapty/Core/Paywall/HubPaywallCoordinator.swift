import Adapty
import AdaptyUI
import Foundation
import HubIntegrationCore
import UIKit

// MARK: - HubPaywallCoordinatorDelegate

/// A delegate for receiving paywall lifecycle and transaction events.
///
/// All methods have default empty implementations, so conforming types
/// only need to implement the events they care about.
public protocol HubPaywallCoordinatorDelegate: AnyObject {
    
    /// Called when the paywall is dismissed by the user or programmatically.
    func paywallCoordinator(_ coordinator: HubPaywallCoordinator, didPerformAction action: HubPaywallCoordinator.Action)
}


// MARK: - HubPaywallCoordinator

/// A unified coordinator for fetching, presenting, and managing Adapty paywalls.
///
/// Handles both builder (remote) and local paywalls, purchase/restore flows,
/// analytics logging, and dismiss logic in a single class.
///
/// ## Usage with closure
///
/// ```swift
/// let coordinator = HubPaywallCoordinator(sdk: adaptyCore)
///
/// try await coordinator.show(
///     placementId: "premium_paywall",
///     from: viewController,
///     config: .init(presentType: .present, closeOnSuccess: true)
/// ) { action in
///     switch action {
///     case .close:
///         print("Paywall closed")
///     case .purchase(let result):
///         print("Purchase: \(result)")
///     case .restore(let entry):
///         print("Restore: \(entry)")
///     }
/// }
/// ```
///
/// ## Usage with delegate
///
/// ```swift
/// let coordinator = HubPaywallCoordinator(sdk: adaptyCore)
/// coordinator.delegate = self
///
/// try await coordinator.show(
///     placementId: "premium_paywall",
///     from: viewController,
///     config: .init(presentType: .present)
/// )
/// ```
@MainActor
public final class HubPaywallCoordinator {
    
    // MARK: - Action
    
    /// Represents all possible outcomes from a paywall flow.
    public enum Action {
        /// The paywall was dismissed (user tapped close or dismiss was called programmatically).
        case close
        
        /// A purchase completed (success or cancellation — check `result.isPurchaseSuccess`).
        case purchase(result: AdaptyPurchaseResult)
        
        /// A purchase failed with an error.
        case purchaseFailed(product: any AdaptyPaywallProduct, error: AdaptyError)
        
        /// A restore completed.
        case restore(entry: AccessEntry)
        
        /// A restore failed with an error.
        case restoreFailed(error: AdaptyError)
    }
    
    public typealias ActionHandler = (Action) -> Void
    
    // MARK: - Properties
    
    private let sdk: any HubSDKAdaptyProviding & Sendable
    private let localPaywallProvider: (any HubLocalPaywallProvider)?
    
    private var presentedViewController: UIViewController?
    private var currentEntry: PlacementEntry?
    private var currentPresentConfig: HubPaywallPresentConfiguration?
    private var actionHandler: ActionHandler?
    
    /// Optional delegate for receiving paywall events.
    /// Can be used instead of or alongside the closure-based `actionHandler`.
    public weak var delegate: HubPaywallCoordinatorDelegate?
    
    // MARK: - Init
    
    /// Creates a new paywall coordinator.
    ///
    /// - Parameters:
    ///   - sdk: The HubSDK instance for Adapty operations.
    ///   - localPaywallProvider: Optional provider for local (non-builder) paywall view controllers.
    public init(
        sdk: any HubSDKAdaptyProviding & Sendable,
        localPaywallProvider: (any HubLocalPaywallProvider)? = nil
    ) {
        self.sdk = sdk
        self.localPaywallProvider = localPaywallProvider
    }
    
    // MARK: - Show
    
    /// Fetches and presents the appropriate paywall for the specified placement.
    ///
    /// Determines whether to show a builder or local paywall based on the placement
    /// configuration, then presents it using the specified presentation config.
    ///
    /// - Parameters:
    ///   - placementId: The placement identifier from the Adapty Dashboard.
    ///   - viewController: The view controller to present from.
    ///   - config: Presentation configuration (present/push, animation, dismiss behavior).
    ///   - onAction: Optional closure called for each paywall action (close, purchase, restore).
    /// - Throws: `HubSDKError.notInitialized` if SDK is not ready.
    /// - Throws: `HubSDKError.placementNotFound` if placement does not exist.
    /// - Throws: `HubSDKError.localPaywallProviderNotSet` if local paywall required but no provider set.
    /// - Throws: `HubSDKError.localPaywallNotFound` if local paywall identifier not found.
    public func show(
        placementId: String,
        from viewController: UIViewController,
        config: HubPaywallPresentConfiguration,
        onAction: ActionHandler? = nil
    ) async throws {
        self.actionHandler = onAction
        self.currentPresentConfig = config
        
        let entry = try await sdk.placementEntryAsync(with: placementId)
        self.currentEntry = entry
        
        switch entry.identifier {
        case .builder:
            try await showBuilderPaywall(entry: entry, from: viewController, config: config)
        case .local(let identifier):
            await sdk.logPaywall(with: entry.paywall)
            try showLocalPaywall(identifier: identifier, entry: entry, from: viewController, config: config)
        }
    }
    
    // MARK: - Dismiss
    
    /// Dismisses the currently presented paywall.
    ///
    /// Respects the `dismissEnable` flag from the presentation configuration.
    /// Uses the same presentation type (present/push) to determine how to dismiss.
    public func dismiss() {
        guard currentPresentConfig?.dismissEnable ?? true else { return }
        
        let animated = currentPresentConfig?.animationEnable ?? false
        
        switch currentPresentConfig?.presentType {
        case .present, .none:
            presentedViewController?.dismiss(animated: animated)
        case .push:
            presentedViewController?.navigationController?.popViewController(animated: animated)
        }
    }
    
    // MARK: - Private: Presentation
    
    private func showBuilderPaywall(
        entry: PlacementEntry,
        from viewController: UIViewController,
        config: HubPaywallPresentConfiguration
    ) async throws {
        let paywallConfig = try await AdaptyUI.getPaywallConfiguration(forPaywall: entry.paywall)
        let controller = try AdaptyUI.paywallController(with: paywallConfig, delegate: self)
        
        presentedViewController = controller
        presentViewController(controller, from: viewController, config: config)
    }
    
    private func showLocalPaywall(
        identifier: String,
        entry: PlacementEntry,
        from viewController: UIViewController,
        config: HubPaywallPresentConfiguration
    ) throws {
        guard let provider = localPaywallProvider else {
            throw HubSDKError.localPaywallProviderNotSet
        }
        
        guard let controller = provider.paywallViewController(
            for: identifier,
            products: entry.products,
            delegate: self
        ) else {
            throw HubSDKError.localPaywallNotFound(identifier)
        }
        
        presentedViewController = controller
        presentViewController(controller, from: viewController, config: config)
    }
    
    private func presentViewController(
        _ child: UIViewController,
        from presenter: UIViewController,
        config: HubPaywallPresentConfiguration
    ) {
        switch config.presentType {
        case .present:
            child.modalPresentationStyle = .fullScreen
            presenter.present(child, animated: config.animationEnable)
            
        case .push:
            if let nav = presenter as? UINavigationController {
                nav.pushViewController(child, animated: config.animationEnable)
            } else if let nav = presenter.navigationController {
                nav.pushViewController(child, animated: config.animationEnable)
            } else {
                assertionFailure("[HubSDK] Push requested but no UINavigationController available")
                child.modalPresentationStyle = .fullScreen
                presenter.present(child, animated: config.animationEnable)
            }
        }
    }
    
    // MARK: - Private: Action Dispatch
    
    /// Single point for dispatching all actions through both closure and delegate.
    private func dispatch(_ action: Action) {
        actionHandler?(action)
        delegate?.paywallCoordinator(self, didPerformAction: action)
    }
    
    /// Handles auto-close logic after successful purchase or restore.
    private func handleSuccessIfNeeded() {
        guard currentPresentConfig?.closeOnSuccess ?? true else { return }
        dismiss()
        dispatch(.close)
        dispose()
    }
    
    private func dispose() {
        presentedViewController = nil
        currentEntry = nil
        currentPresentConfig = nil
        actionHandler = nil
    }
    
    // MARK: - Private: Validation
    
    private func handlePurchaseResult(_ result: AdaptyPurchaseResult, product: any AdaptyPaywallProduct) {
        dispatch(.purchase(result: result))
        
        if result.isPurchaseSuccess {
            let amount = product.price
            let currencyCode = product.currencyCode ?? ""
            HubEventBus.shared.publish(.successPurchase(amount: amount.doubleValue, currency: currencyCode))
            handleSuccessIfNeeded()
        }
    }
    
    private func handleRestore() {
        Task {
            let entry = await sdk.validateSubscription()
            dispatch(.restore(entry: entry))
            
            if entry.isActive {
                handleSuccessIfNeeded()
            }
        }
    }
}

// MARK: - AdaptyPaywallControllerDelegate (Builder Paywalls)

extension HubPaywallCoordinator: AdaptyPaywallControllerDelegate {
    
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didPerform action: AdaptyUI.Action
    ) {
        switch action {
        case .close:
            dismiss()
            dispatch(.close)
            dispose()
        default:
            break
        }
    }
    
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFinishPurchase product: any AdaptyPaywallProduct,
        purchaseResult: AdaptyPurchaseResult
    ) {
        handlePurchaseResult(purchaseResult, product: product)
    }
    
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFinishRestoreWith profile: AdaptyProfile
    ) {
        handleRestore()
    }
    
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFailPurchase product: any AdaptyPaywallProduct,
        error: AdaptyError
    ) {
        dispatch(.purchaseFailed(product: product, error: error))
    }
    
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFailRestoreWith error: AdaptyError
    ) {
        dispatch(.restoreFailed(error: error))
    }
}

// MARK: - HubLocalPaywallDelegate (Local Paywalls)

extension HubPaywallCoordinator: @preconcurrency HubLocalPaywallDelegate {
    
    public func purchaseLocalPaywallFinish(_ result: AdaptyPurchaseResult, product: AdaptyPaywallProduct) {
        handlePurchaseResult(result, product: product)
    }
    
    public func restoreLocalPaywallFinish(_ profile: AdaptyProfile) {
        handleRestore()
    }
    
    public func closeLocalPaywallAction() {
        dismiss()
        dispatch(.close)
        dispose()
    }
}
