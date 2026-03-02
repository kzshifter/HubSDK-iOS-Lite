import Adapty
import UIKit

// MARK: - HubLocalPaywallDelegate

/// A delegate for handling user interactions within a local paywall.
///
/// The local paywall view controller uses this delegate to **request** actions.
/// The coordinator performs the actual purchase/restore operations and reports
/// results back via `HubLocalPaywallStateDelegate`.
///
/// This separation ensures that all purchase logic is centralized in the coordinator,
/// while the local paywall only manages its UI.
public protocol HubLocalPaywallDelegate: AnyObject {
    
    /// Called when the user taps a purchase button.
    ///
    /// The coordinator will execute the purchase and report the result
    /// back to the view controller via `HubLocalPaywallStateDelegate`.
    ///
    /// - Parameter product: The product the user wants to purchase.
    func localPaywallDidRequestPurchase(product: AdaptyPaywallProduct)
    
    /// Called when the user taps the restore button.
    ///
    /// The coordinator will execute the restore and report the result
    /// back to the view controller via `HubLocalPaywallStateDelegate`.
    func localPaywallDidRequestRestore()
    
    /// Called when the user taps close or swipes to dismiss.
    func localPaywallDidRequestClose()
}

// MARK: - HubLocalPaywallStateDelegate

/// A delegate the coordinator uses to report operation results back to the local paywall.
///
/// Implement this in your local paywall view controller to update UI
/// in response to purchase/restore lifecycle events (success, failure).
public protocol HubLocalPaywallStateDelegate: AnyObject {
    
    /// Called when a purchase completes.
    ///
    /// Use this to update UI based on the result. If `closeOnSuccess` is enabled,
    /// the coordinator will dismiss the paywall automatically after this call.
    ///
    /// - Parameter result: The purchase result (check `isPurchaseSuccess`).
    func localPaywallDidFinishPurchase(result: AdaptyPurchaseResult)
    
    /// Called when a purchase fails.
    ///
    /// - Parameter error: The error that occurred.
    func localPaywallDidFailPurchase(error: Error)
    
    /// Called when a restore completes.
    ///
    /// - Parameter entry: The access entry with the restored subscription status.
    func localPaywallDidFinishRestore(entry: AccessEntry)
    
    /// Called when a restore fails.
    ///
    /// - Parameter error: The error that occurred.
    func localPaywallDidFailRestore(error: Error)
}

// MARK: - Default Implementations

public extension HubLocalPaywallStateDelegate {
    func localPaywallDidFinishPurchase(result: AdaptyPurchaseResult) {}
    func localPaywallDidFailPurchase(error: Error) {}
    func localPaywallDidFinishRestore(entry: AccessEntry) {}
    func localPaywallDidFailRestore(error: Error) {}
}

// MARK: - HubLocalPaywallProvider

/// A protocol for providing local paywall view controllers.
///
/// Implement this protocol in your app to supply custom paywall implementations
/// for placements that use local (non-builder) paywalls.
///
/// ## Example Implementation
///
/// ```swift
/// final class AppPaywallProvider: HubLocalPaywallProvider {
///
///     func paywallViewController(
///         for identifier: String,
///         products: [AdaptyPaywallProduct],
///         delegate: HubLocalPaywallDelegate
///     ) -> (UIViewController & HubLocalPaywallStateDelegate)? {
///         switch identifier {
///         case "main":
///             return MainPaywallViewController(
///                 products: products,
///                 delegate: delegate
///             )
///         case "settings":
///             return SettingsPaywallViewController(
///                 products: products,
///                 delegate: delegate
///             )
///         default:
///             return nil
///         }
///     }
/// }
/// ```
public protocol HubLocalPaywallProvider: AnyObject {
    
    /// Creates a view controller for the specified local paywall.
    ///
    /// The returned view controller must conform to `HubLocalPaywallStateDelegate`
    /// so the coordinator can report purchase/restore results back to update the UI.
    ///
    /// - Parameters:
    ///   - identifier: The paywall identifier from remote configuration.
    ///   - products: The products available for purchase.
    ///   - delegate: The delegate for requesting actions (purchase, restore, close).
    /// - Returns: A configured view controller, or `nil` if the identifier is not recognized.
    func paywallViewController(
        for identifier: String,
        products: [AdaptyPaywallProduct],
        delegate: HubLocalPaywallDelegate
    ) -> (UIViewController & HubLocalPaywallStateDelegate)?
}
